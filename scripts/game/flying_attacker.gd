class_name FlyingAttacker
extends CharacterBody3D
## 古代飞行攻击器：悬浮侧移、旋翼动画和远程能量射击。

var terrain: Terrain
var player: Player
var alive := true
var hp := 95.0
var display_name := "古代飞行攻击器"
var damage_mult := 1.0
var kills := 0

var _home := Vector3.ZERO
var _time := 0.0
var _shot_cooldown := 1.5
var _windup := -1.0 # // FIX: R2-B4 开火前摇计时
var _rotors: Array[Node3D] = []


func setup(p_terrain: Terrain, p_player: Player) -> void:
	terrain = p_terrain
	player = p_player


func _ready() -> void:
	add_to_group("wild_enemy")
	collision_layer = 4
	collision_mask = 0
	_home = global_position
	var col := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.9
	col.shape = shape
	add_child(col)
	_build_model()


func _build_model() -> void:
	var stone := Toon.make_material(Color(0.24, 0.30, 0.31), true, 0.018)
	var bronze := Toon.make_material(Color(0.56, 0.37, 0.16), true, 0.012)
	var dark := Toon.make_material(Color(0.08, 0.10, 0.105), true, 0.008)
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = Color(0.04, 0.92, 0.95)
	glow.emission_enabled = true
	glow.emission = glow.albedo_color
	glow.emission_energy_multiplier = 3.0
	_sphere(0.82, stone, Vector3.ZERO, Vector3(1.0, 0.62, 1.0))
	_sphere(0.36, glow, Vector3(0, -0.08, -0.64), Vector3(1.0, 1.0, 0.55))
	for i in range(4):
		var angle := float(i) * PI * 0.5
		var arm := _part(Vector3(0.16, 0.12, 2.5), bronze, Vector3(sin(angle) * 1.08, 0, cos(angle) * 1.08))
		arm.rotation.y = angle
		var rotor := Node3D.new()
		rotor.position = Vector3(sin(angle) * 2.05, 0, cos(angle) * 2.05)
		add_child(rotor)
		_rotors.append(rotor)
		_part(Vector3(2.1, 0.05, 0.16), dark, Vector3.ZERO, rotor)
		_part(Vector3(0.16, 0.05, 2.1), dark, Vector3.ZERO, rotor)
		_sphere_at(rotor, 0.18, glow, Vector3.ZERO, Vector3.ONE)
	for i in range(5):
		var rune := _part(Vector3(0.08, 0.06, 0.42), glow, Vector3(sin(i * TAU / 5.0) * 0.58, 0.48, cos(i * TAU / 5.0) * 0.58))
		rune.rotation.y = i * TAU / 5.0


func _part(size: Vector3, mat: Material, pos: Vector3, parent: Node3D = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	(parent if parent else self).add_child(mi)
	return mi


func _sphere(radius: float, mat: Material, pos: Vector3, shape_scale: Vector3) -> MeshInstance3D:
	return _sphere_at(self, radius, mat, pos, shape_scale)


func _sphere_at(parent: Node3D, radius: float, mat: Material, pos: Vector3, shape_scale: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 10
	mesh.rings = 6
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.scale = shape_scale
	parent.add_child(mi)
	return mi


func get_hit_part(_shape_idx: int) -> String:
	return "body"


func take_damage(amount: float, from: Variant = null, _part_name: String = "body") -> void:
	if not alive:
		return
	hp -= amount
	DamageNumber.spawn_at(get_tree().current_scene, global_position + Vector3(0, 1.2, 0), str(int(amount)), Color(1.0, 0.85, 0.25))
	if hp <= 0.0:
		alive = false
		if from and from.get("kills") != null:
			from.kills += 1
		Loot.spawn(get_tree().current_scene, global_position, "ammo", "", 90, 2)
		queue_free()


func _physics_process(delta: float) -> void:
	if not alive or player == null:
		return
	_time += delta
	_shot_cooldown -= delta
	for rotor in _rotors:
		rotor.rotation.y += delta * 13.0
	var distance := global_position.distance_to(player.global_position)
	var target := _home + Vector3(sin(_time * 0.7) * 12.0, 8.0 + sin(_time * 1.3) * 2.0, cos(_time * 0.55) * 12.0)
	if distance < 72.0:
		var away := (global_position - player.global_position)
		away.y = 0.0
		if away.length() < 18.0:
			target += away.normalized() * 14.0
		if _shot_cooldown <= 0.0:
			# // FIX: R2-B4/CB13b 原零前摇瞬发无音效：0.45s 前摇+充能音+LoS（与投石/守卫同标准）
			_shot_cooldown = 2.2
			_windup = 0.45
			var _sfx_c := get_tree().get_first_node_in_group("sfx_bank")
			if _sfx_c:
				_sfx_c.play_at("enemy_charge", global_position, -8.0, 1.25)
		if _windup > 0.0:
			_windup -= delta
			# // FIX: R2-B4 发射前 LoS：坡后/墙后不再盲射
			if _windup <= 0.0 and player:
				var q := PhysicsRayQueryParameters3D.create(global_position, player.global_position + Vector3(0, 1.0, 0), 1, [get_rid()])
				if get_world_3d().direct_space_state.intersect_ray(q).is_empty():
					_shoot()
	global_position = global_position.lerp(target, minf(1.0, delta * 1.25))
	look_at(player.global_position + Vector3(0, 1.0, 0), Vector3.UP)


func _shoot() -> void:
	var origin := global_position - global_transform.basis.z * 0.9
	var direction := (player.global_position + Vector3(0, 1.0, 0) - origin).normalized()
	var projectile := WildProjectile.new()
	projectile.configure("energy", direction * 19.0, 15.0, self)
	get_tree().current_scene.add_child(projectile)
	projectile.global_position = origin
