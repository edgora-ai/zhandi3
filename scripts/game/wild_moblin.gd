class_name WildMoblin
extends CharacterBody3D
## 莫布林：大体型慢速重击。长前摇举棒（眼睛变红）→ 猛击，是给格挡/闪避喂招的敌人。

var terrain: Terrain
var player: Player
var alive := true
var hp := 180.0
var display_name := "莫布林"
var damage_mult := 1.0
var kills := 0

var _home := Vector3.ZERO
var _wander := Vector3.ZERO
var _think := 0.0
var _windup := -1.0
var _recover := 0.0
var _anim := 0.0
var _eye_l: MeshInstance3D
var _eye_r: MeshInstance3D
var _club_arm: Node3D
var _club: MeshInstance3D
var _legs: Array[Node3D] = []
var _flash := 0.0

const WINDUP_TIME := 0.9
const SMASH_RANGE := 2.8
const SMASH_DAMAGE := 35.0
const SIGHT := 26.0


func setup(p_terrain: Terrain, p_player: Player) -> void:
	terrain = p_terrain
	player = p_player


func _ready() -> void:
	add_to_group("wild_enemy")
	collision_layer = 4
	collision_mask = 1
	_home = global_position
	_wander = _home
	var col := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.75
	shape.height = 2.3
	col.shape = shape
	col.position.y = 1.1
	add_child(col)
	_build_model()


func _build_model() -> void:
	var skin := Toon.make_material(Color(0.62, 0.22, 0.14), true, 0.018)
	var belly := Toon.make_material(Color(0.85, 0.62, 0.35), true, 0.012)
	var dark := Toon.make_material(Color(0.10, 0.08, 0.07), true, 0.008)
	var bone := Toon.make_material(Color(0.90, 0.82, 0.60), true, 0.006)
	# 大肚圆身、小头、独角。
	_sphere(self, 0.95, skin, Vector3(0, 1.25, 0), Vector3(1.0, 1.1, 0.9))
	_sphere(self, 0.62, belly, Vector3(0, 1.15, -0.55), Vector3(0.9, 1.0, 0.55))
	_sphere(self, 0.42, skin, Vector3(0, 2.25, -0.1), Vector3(1.05, 0.9, 0.95))
	var horn := MeshInstance3D.new()
	var hm := CylinderMesh.new()
	hm.top_radius = 0.02
	hm.bottom_radius = 0.10
	hm.height = 0.55
	hm.radial_segments = 7
	horn.mesh = hm
	horn.material_override = bone
	horn.position = Vector3(0, 2.62, -0.1)
	add_child(horn)
	var eye_mat := StandardMaterial3D.new()
	eye_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	eye_mat.albedo_color = Color(1.0, 0.85, 0.20)
	eye_mat.emission_enabled = true
	eye_mat.emission = Color(1.0, 0.75, 0.10)
	eye_mat.emission_energy_multiplier = 1.6
	_eye_l = _sphere(self, 0.07, eye_mat, Vector3(-0.16, 2.30, -0.44), Vector3.ONE)
	_eye_r = _sphere(self, 0.07, eye_mat, Vector3(0.16, 2.30, -0.44), Vector3.ONE)
	# 持棒右臂：高举猛击的枢轴。
	_club_arm = Node3D.new()
	_club_arm.position = Vector3(0.85, 1.75, 0)
	add_child(_club_arm)
	var arm_mesh := MeshInstance3D.new()
	var am := CapsuleMesh.new()
	am.radius = 0.22
	am.height = 1.1
	am.radial_segments = 8
	am.rings = 4
	arm_mesh.mesh = am
	arm_mesh.material_override = skin
	arm_mesh.position = Vector3(0, -0.45, 0)
	_club_arm.add_child(arm_mesh)
	_club = MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.16
	cm.bottom_radius = 0.10
	cm.height = 1.6
	cm.radial_segments = 7
	_club.mesh = cm
	_club.material_override = dark
	_club.position = Vector3(0, -1.1, -0.15)
	_club.rotation_degrees.x = 20.0
	_club_arm.add_child(_club)
	# 左臂与两条短腿。
	var arm_l := MeshInstance3D.new()
	arm_l.mesh = am
	arm_l.material_override = skin
	arm_l.position = Vector3(-0.85, 1.30, 0)
	add_child(arm_l)
	for sx in [-0.38, 0.38]:
		var leg := Node3D.new()
		leg.position = Vector3(sx, 0.55, 0)
		add_child(leg)
		_legs.append(leg)
		var lm := MeshInstance3D.new()
		var lmm := CapsuleMesh.new()
		lmm.radius = 0.20
		lmm.height = 0.9
		lmm.radial_segments = 7
		lmm.rings = 4
		lm.mesh = lmm
		lm.material_override = skin
		lm.position.y = -0.35
		leg.add_child(lm)


func _sphere(parent: Node3D, radius: float, mat: Material, pos: Vector3, shape_scale: Vector3) -> MeshInstance3D:
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


func take_damage(amount: float, from: Variant = null, _part_name: String = "body") -> void:
	if not alive:
		return
	hp -= amount
	_flash = 0.14
	DamageNumber.spawn_at(get_tree().current_scene, global_position + Vector3(0, 2.8, 0), str(int(amount)), Color(1.0, 0.85, 0.25))
	if hp <= 0.0:
		alive = false
		if from and from.get("kills") != null:
			from.kills += 1
		Loot.spawn(get_tree().current_scene, global_position + Vector3(0, 0.2, 0), "meat", "", 3, 1)
		Loot.spawn(get_tree().current_scene, global_position + Vector3(0.6, 0.2, 0.4), "wood", "", 2, 1)
		DamageNumber.spawn_at(get_tree().current_scene, global_position + Vector3(0, 2.8, 0), "击破!", Color(1.0, 0.55, 0.20))
		queue_free()


func _physics_process(delta: float) -> void:
	if not alive or player == null or terrain == null:
		return
	_anim += delta
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta)
		scale = Vector3.ONE * (1.0 + _flash * 0.8)
	var to_player := player.global_position - global_position
	to_player.y = 0.0
	var dist := to_player.length()
	# 前摇：举棒定住、眼放红光，给玩家 0.9s 反应窗口。
	if _windup >= 0.0:
		_windup += delta
		_club_arm.rotation.x = lerpf(_club_arm.rotation.x, -2.4, delta * 6.0)
		_eye_l.scale = Vector3.ONE * (1.0 + sin(_anim * 20.0) * 0.3)
		_eye_r.scale = _eye_l.scale
		if _windup >= WINDUP_TIME:
			_smash()
			_windup = -1.0
			_recover = 1.2
	else:
		_club_arm.rotation.x = lerpf(_club_arm.rotation.x, 0.2, delta * 4.0)
		_eye_l.scale = Vector3.ONE
		_eye_r.scale = Vector3.ONE
		_recover = maxf(0.0, _recover - delta)
		if dist < SIGHT and player.alive:
			if dist < SMASH_RANGE * 0.75 and _recover <= 0.0:
				_windup = 0.0
			else:
				var dir := to_player.normalized()
				velocity.x = dir.x * 3.4
				velocity.z = dir.z * 3.4
				rotation.y = lerp_angle(rotation.y, atan2(dir.x, dir.z) + PI, delta * 4.0)
		else:
			_think -= delta
			if _think <= 0.0:
				_think = randf_range(2.0, 4.0)
				_wander = _home + Vector3(randf_range(-8, 8), 0, randf_range(-8, 8))
			var dir2 := _wander - global_position
			dir2.y = 0.0
			if dir2.length() > 1.2:
				dir2 = dir2.normalized()
				velocity.x = dir2.x * 2.0
				velocity.z = dir2.z * 2.0
				rotation.y = lerp_angle(rotation.y, atan2(dir2.x, dir2.z) + PI, delta * 3.0)
			else:
				velocity.x = 0.0
				velocity.z = 0.0
	if _windup >= 0.0:
		velocity.x = 0.0
		velocity.z = 0.0
	velocity.y = -4.0
	move_and_slide()
	global_position.y = terrain.get_height(global_position.x, global_position.z) + 0.05
	var stride := clampf(Vector2(velocity.x, velocity.z).length() / 3.4, 0.0, 1.0) * 0.4
	for i in range(_legs.size()):
		_legs[i].rotation.x = sin(_anim * 5.5 + i * PI) * stride


func _smash() -> void:
	_club_arm.rotation.x = 0.8
	# 猛击：范围内伤害+击退，可被格挡/闪避反制。
	if player.global_position.distance_to(global_position) < SMASH_RANGE and player.alive:
		player.take_damage(SMASH_DAMAGE, self)
		if player.alive:
			var push := (player.global_position - global_position)
			push.y = 0.0
			player.velocity += push.normalized() * 6.0 + Vector3(0, 3.0, 0)
	FX.impact(global_position + Vector3(0, 0.2, 0) + -global_transform.basis.z * 1.8)
