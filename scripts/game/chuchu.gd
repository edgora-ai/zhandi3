class_name Chuchu
extends CharacterBody3D
## 丘丘果冻：半透明胶质魔物，蹦跳逼近玩家撞击。大只死亡分裂成两只小只，小只死亡掉蘑菇。

var terrain: Terrain
var player: Player
var alive := true
var hp := 30.0
var small := false
var display_name := "丘丘"

var _home := Vector3.ZERO
var _hop_cd := 0.0
var _bump_cd := 0.0
var _anim := 0.0
var _squash := 0.0
var _visual: Node3D


static func create(parent: Node, p_terrain: Terrain, p_player: Player, pos: Vector3, p_small: bool = false) -> Chuchu:
	var c := Chuchu.new()
	c.terrain = p_terrain
	c.player = p_player
	c.small = p_small
	parent.add_child(c)
	c.global_position = pos
	return c


func _ready() -> void:
	add_to_group("wild_enemy")
	collision_layer = 4
	collision_mask = 1
	_home = global_position
	if small:
		hp = 10.0
	var col := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.32 if small else 0.55
	col.shape = shape
	col.position.y = shape.radius
	add_child(col)
	_build_model()


func _build_model() -> void:
	_visual = Node3D.new()
	add_child(_visual)
	var r := 0.32 if small else 0.55
	var jelly := StandardMaterial3D.new()
	jelly.albedo_color = Color(0.25, 0.75, 0.55, 0.62)
	jelly.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	jelly.roughness = 0.25
	jelly.emission_enabled = true
	jelly.emission = Color(0.15, 0.55, 0.40)
	jelly.emission_energy_multiplier = 0.5
	var body := MeshInstance3D.new()
	var bm := SphereMesh.new()
	bm.radius = r
	bm.height = r * 1.9
	bm.radial_segments = 12
	bm.rings = 7
	body.mesh = bm
	body.material_override = jelly
	body.position.y = r
	_visual.add_child(body)
	# 内核与双眼。
	var core := MeshInstance3D.new()
	var cm := SphereMesh.new()
	cm.radius = r * 0.38
	cm.height = r * 0.72
	cm.radial_segments = 9
	cm.rings = 5
	core.mesh = cm
	var cmat := StandardMaterial3D.new()
	cmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cmat.albedo_color = Color(0.55, 1.0, 0.80)
	cmat.emission_enabled = true
	cmat.emission = Color(0.35, 1.0, 0.70)
	cmat.emission_energy_multiplier = 1.8
	core.material_override = cmat
	core.position = Vector3(0, r * 1.05, 0)
	_visual.add_child(core)
	var eye_mat := Toon.make_material(Color(0.06, 0.10, 0.08), false)
	for sx in [-1.0, 1.0]:
		var eye := MeshInstance3D.new()
		var em := SphereMesh.new()
		em.radius = r * 0.14
		em.height = r * 0.26
		em.radial_segments = 7
		em.rings = 4
		eye.mesh = em
		eye.material_override = eye_mat
		eye.position = Vector3(sx * r * 0.38, r * 1.15, -r * 0.82)
		_visual.add_child(eye)


func take_damage(amount: float, from: Variant = null, _part_name: String = "body") -> void:
	if not alive:
		return
	hp -= amount
	_squash = 0.35
	DamageNumber.spawn_at(get_tree().current_scene, global_position + Vector3(0, 1.0, 0), str(int(amount)), Color(1.0, 0.85, 0.25))
	if hp <= 0.0:
		_die(from)


func _die(from: Variant) -> void:
	alive = false
	if from and from.get("kills") != null:
		from.kills += 1
	if from and from.has_method("give_rupees"):
		from.give_rupees(1 if small else 2)
	var scene := get_tree().current_scene
	if small:
		Loot.spawn(scene, global_position + Vector3(0, 0.3, 0), "mushroom", "", 1, 1)
	else:
		# 大只分裂成两只小只。
		for sx in [-1.0, 1.0]:
			var c := Chuchu.create(get_parent(), terrain, player, global_position + Vector3(sx * 0.8, 0.2, 0), true)
			c.velocity = Vector3(sx * 2.5, 3.5, 0)
		DamageNumber.spawn_at(scene, global_position + Vector3(0, 1.2, 0), "分裂!", Color(0.55, 1.0, 0.75))
	queue_free()


func _physics_process(delta: float) -> void:
	if not alive or player == null or terrain == null:
		return
	_anim += delta
	_hop_cd = maxf(0.0, _hop_cd - delta)
	_bump_cd = maxf(0.0, _bump_cd - delta)
	_squash = maxf(0.0, _squash - delta)
	var to_player := player.global_position - global_position
	to_player.y = 0.0
	var dist := to_player.length()
	# 蹦跳：落地时起跳，朝玩家方向抛物。
	if is_on_floor():
		velocity.x = move_toward(velocity.x, 0.0, delta * 8.0)
		velocity.z = move_toward(velocity.z, 0.0, delta * 8.0)
		if _hop_cd <= 0.0 and dist < 16.0 and player.alive:
			var dir := to_player.normalized()
			var next := global_position + dir * 2.2
			if not terrain.is_in_water(next.x, next.z):
				velocity = dir * (2.6 if small else 3.4) + Vector3(0, 4.2 if small else 5.2, 0)
				_hop_cd = (0.55 if small else 0.8) + randf() * 0.3
				rotation.y = atan2(dir.x, dir.z) + PI
	velocity.y = maxf(velocity.y - 12.0 * delta, -14.0)
	move_and_slide()
	if terrain:
		global_position.y = maxf(global_position.y, terrain.get_height(global_position.x, global_position.z))
	# 撞击伤害。
	if dist < (0.9 if small else 1.2) and _bump_cd <= 0.0 and player.alive:
		player.take_damage(3.0 if small else 6.0, self)
		_bump_cd = 1.0
	# 挤压拉伸：落地压扁、空中拉长、受击鼓胀。
	var stretch := clampf(velocity.y * 0.06, -0.22, 0.30)
	var land_squash := 0.25 if is_on_floor() else 0.0
	var hit_bulge := _squash * 0.8
	var sy := 1.0 + stretch - land_squash + hit_bulge
	var sxz := 1.0 - stretch * 0.5 + land_squash * 0.45 - hit_bulge * 0.2
	_visual.scale = _visual.scale.lerp(Vector3(sxz, sy, sxz), delta * 10.0)
