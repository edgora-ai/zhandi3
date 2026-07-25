class_name WildNPC
extends CharacterBody3D
## 友好的旅人 NPC：在地标附近停留或小范围游走，靠近时可按 E 交谈。

var terrain: Terrain
var player: Player
var npc_name := "旅人"
var lines: Array[String] = []
var coat := Color(0.45, 0.32, 0.55)
var hat_style := 0   # 0 草帽 / 1 尖帽 / 2 头巾

var _line_index := 0
var _home := Vector3.ZERO
var _target := Vector3.ZERO
var _think := 0.0
var _anim := 0.0
var _talk_cd := 0.0
var _visual: Node3D
var _arm_l: Node3D
var _arm_r: Node3D


func setup(p_terrain: Terrain, p_player: Player, p_name: String, p_lines: Array[String], p_coat: Color, p_hat: int) -> void:
	terrain = p_terrain
	player = p_player
	npc_name = p_name
	lines = p_lines
	coat = p_coat
	hat_style = p_hat


func _ready() -> void:
	add_to_group("npc")
	collision_layer = 4
	collision_mask = 1
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.34
	cap.height = 1.65
	col.shape = cap
	col.position.y = 0.85
	add_child(col)
	_home = global_position
	_target = _home
	_build_model()


func _build_model() -> void:
	_visual = Node3D.new()
	add_child(_visual)
	var coat_mat := Toon.make_material(coat, true, 0.014)
	var skin := Toon.make_material(Color(0.92, 0.72, 0.55), true, 0.010)
	var dark := Toon.make_material(Color(0.16, 0.12, 0.10), true, 0.008)
	var straw := Toon.make_material(Color(0.85, 0.70, 0.35), true, 0.010)
	# 长袍身体、头、肩挎包。
	_capsule(_visual, 0.34, 1.15, coat_mat, Vector3(0, 0.95, 0))
	_sphere(_visual, 0.24, skin, Vector3(0, 1.72, 0), Vector3(1.0, 1.05, 1.0))
	_sphere(_visual, 0.10, dark, Vector3(0, 1.68, -0.21), Vector3(1.0, 0.5, 0.6))
	for sx in [-1.0, 1.0]:
		_sphere(_visual, 0.028, dark, Vector3(sx * 0.09, 1.76, -0.20), Vector3.ONE)
	match hat_style:
		0:  # 草帽
			_cylinder(_visual, 0.38, 0.06, straw, Vector3(0, 1.92, 0))
			_cylinder(_visual, 0.16, 0.14, straw, Vector3(0, 2.00, 0))
		1:  # 尖顶帽
			_cone(_visual, 0.02, 0.30, 0.55, coat_mat, Vector3(0, 2.14, 0))
		2:  # 头巾
			_sphere(_visual, 0.25, Toon.make_material(coat.darkened(0.15), true, 0.010), Vector3(0, 1.80, 0), Vector3(1.05, 0.7, 1.05))
	_arm_l = _limb(Vector3(-0.38, 1.30, 0), coat_mat)
	_arm_r = _limb(Vector3(0.38, 1.30, 0), coat_mat)
	_sphere(_visual, 0.16, dark, Vector3(0.30, 0.85, 0.22), Vector3(0.8, 1.0, 0.6))


func _limb(pos: Vector3, mat: Material) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = pos
	_visual.add_child(pivot)
	_capsule(pivot, 0.09, 0.62, mat, Vector3(0, -0.28, 0))
	return pivot


func _capsule(parent: Node3D, radius: float, height: float, mat: Material, pos: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	mesh.radial_segments = 9
	mesh.rings = 4
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)


func _sphere(parent: Node3D, radius: float, mat: Material, pos: Vector3, shape_scale: Vector3 = Vector3.ONE) -> void:
	var mi := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 9
	mesh.rings = 5
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.scale = shape_scale
	parent.add_child(mi)


func _cylinder(parent: Node3D, radius: float, height: float, mat: Material, pos: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 10
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)


func _cone(parent: Node3D, top: float, bottom: float, height: float, mat: Material, pos: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	mesh.radial_segments = 8
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)


func talk() -> void:
	if _talk_cd > 0.0 or lines.is_empty():
		return
	_talk_cd = 1.2
	var scene := get_tree().current_scene
	if scene and scene.get("hud") != null:
		scene.hud.add_feed("%s：%s" % [npc_name, lines[_line_index]])
	_line_index = (_line_index + 1) % lines.size()


func _physics_process(delta: float) -> void:
	_talk_cd = maxf(0.0, _talk_cd - delta)
	_anim += delta
	var to_player := Vector3.ZERO
	if player:
		to_player = player.global_position - global_position
		to_player.y = 0.0
	# 玩家靠近时面向玩家；否则在落脚点 4m 内游走。
	if to_player.length() < 7.0:
		rotation.y = lerp_angle(rotation.y, atan2(to_player.x, to_player.z), delta * 4.0)
		velocity.x = 0.0
		velocity.z = 0.0
	else:
		_think -= delta
		if _think <= 0.0:
			_think = randf_range(3.0, 6.0)
			_target = _home + Vector3(randf_range(-4, 4), 0, randf_range(-4, 4))
		var dir := _target - global_position
		dir.y = 0.0
		if dir.length() > 0.6:
			dir = dir.normalized()
			velocity.x = dir.x * 1.1
			velocity.z = dir.z * 1.1
			rotation.y = lerp_angle(rotation.y, atan2(dir.x, dir.z), delta * 3.0)
		else:
			velocity.x = 0.0
			velocity.z = 0.0
	velocity.y = -4.0
	move_and_slide()
	if terrain:
		global_position.y = terrain.get_height(global_position.x, global_position.z)
	# 呼吸感与手臂摆动。
	_visual.position.y = sin(_anim * 1.8) * 0.02
	var swing := sin(_anim * 3.2) * (0.25 if Vector2(velocity.x, velocity.z).length() > 0.2 else 0.05)
	_arm_l.rotation.x = swing
	_arm_r.rotation.x = -swing
