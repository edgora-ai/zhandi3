class_name WildDragon
extends CharacterBody3D
## 山岳巨龙：沿火山环飞，展翼摆尾，并向靠近的玩家喷射连续火焰。

var player: Player
var center := Vector3.ZERO
var alive := true
var hp := 420.0
var display_name := "赤焰巨龙"
var damage_mult := 1.0
var kills := 0

var _time := 0.0
var _fire_cooldown := 2.0
var _wing_left: Node3D
var _wing_right: Node3D
var _tail_segments: Array[Node3D] = []


func setup(p_player: Player, p_center: Vector3) -> void:
	player = p_player
	center = p_center


func _ready() -> void:
	add_to_group("wild_enemy")
	collision_layer = 4
	collision_mask = 0
	var col := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 1.35
	shape.height = 7.5
	col.shape = shape
	col.rotation_degrees.x = 90.0
	add_child(col)
	_build_model()


func _build_model() -> void:
	var scale_mat := Toon.make_material(Color(0.54, 0.08, 0.045), true, 0.035)
	var belly := Toon.make_material(Color(0.92, 0.42, 0.12), true, 0.02)
	var horn := Toon.make_material(Color(0.30, 0.19, 0.12), true, 0.012)
	var membrane := Toon.make_material(Color(0.76, 0.16, 0.075), true, 0.018)
	_capsule(self, 1.15, 6.2, scale_mat, Vector3.ZERO, Vector3(90, 0, 0), Vector3(1.0, 1.0, 1.1))
	for i in range(6):
		_sphere(self, 0.78 - i * 0.055, scale_mat, Vector3(0, 0.28 + i * 0.28, -2.65 - i * 0.62), Vector3(1.0, 1.0, 1.2))
	_sphere(self, 1.02, scale_mat, Vector3(0, 1.75, -6.25), Vector3(1.2, 0.9, 1.25))
	_sphere(self, 0.62, belly, Vector3(0, 1.52, -7.12), Vector3(1.0, 0.68, 1.45))
	for sx in [-1.0, 1.0]:
		_sphere(self, 0.11, horn, Vector3(sx * 0.48, 1.96, -7.18), Vector3.ONE)
		var head_horn := _capsule(self, 0.12, 1.3, horn, Vector3(sx * 0.52, 2.48, -6.35), Vector3(-20, 0, sx * -22), Vector3.ONE)
		head_horn.rotation_degrees.z = sx * -22.0
	# 背刺贯穿颈背和尾根。
	for i in range(11):
		var spike := _part(Vector3(0.18, 0.72 - i * 0.025, 0.42), horn, Vector3(0, 1.2, -4.5 + i * 0.72), self)
		spike.rotation_degrees.x = -18.0
	_wing_left = _make_wing(-1.0, membrane, horn)
	_wing_right = _make_wing(1.0, membrane, horn)
	var tail_parent: Node3D = self
	for i in range(8):
		var joint := Node3D.new()
		joint.position = Vector3(0, 0, 0.72 if i == 0 else 0.62)
		tail_parent.add_child(joint)
		_tail_segments.append(joint)
		_capsule(joint, 0.55 - i * 0.052, 1.15, scale_mat, Vector3(0, 0, 0.55), Vector3(90, 0, 0), Vector3.ONE)
		tail_parent = joint


func _make_wing(side: float, membrane: Material, bone: Material) -> Node3D:
	var wing := Node3D.new()
	wing.position = Vector3(side * 0.9, 0.65, -0.6)
	add_child(wing)
	var main_bone := _part(Vector3(6.0, 0.20, 0.22), bone, Vector3(side * 2.85, 0, 0), wing)
	main_bone.rotation_degrees.z = side * -8.0
	for i in range(4):
		var finger := _part(Vector3(4.7 - i * 0.50, 0.11, 0.13), bone, Vector3(side * (2.65 - i * 0.08), 0, 0.72 + i * 0.72), wing)
		finger.rotation_degrees.y = side * (20.0 + i * 8.0)
		var cloth := _part(Vector3(4.55 - i * 0.46, 0.05, 1.38), membrane, Vector3(side * (2.55 - i * 0.06), -0.04, 0.48 + i * 0.72), wing)
		cloth.rotation_degrees.y = side * (10.0 + i * 7.0)
	return wing


func _part(size: Vector3, mat: Material, pos: Vector3, parent: Node3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi


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


func _capsule(parent: Node3D, radius: float, height: float, mat: Material, pos: Vector3, rot: Vector3, shape_scale: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	mesh.radial_segments = 9
	mesh.rings = 4
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot
	mi.scale = shape_scale
	parent.add_child(mi)
	return mi


func get_hit_part(_shape_idx: int) -> String:
	return "body"


func take_damage(amount: float, from: Variant = null, _part_name: String = "body") -> void:
	if not alive:
		return
	hp -= amount
	if hp <= 0.0:
		alive = false
		if from and from.get("kills") != null:
			from.kills += 1
		Loot.spawn(get_tree().current_scene, global_position, "dragon_scale", "", 1, 3)
		for i in range(4):
			Loot.spawn(get_tree().current_scene, global_position + Vector3(randf_range(-2, 2), 0, randf_range(-2, 2)), "meat", "", 2, 2)
		queue_free()


func _physics_process(delta: float) -> void:
	if not alive or player == null:
		return
	_time += delta
	_fire_cooldown -= delta
	var angle := _time * 0.16
	var next := center + Vector3(cos(angle) * 42.0, 45.0 + sin(_time * 0.43) * 9.0, sin(angle) * 42.0)
	var forward := (next - global_position).normalized()
	global_position = global_position.lerp(next, minf(1.0, delta * 1.6))
	if forward.length_squared() > 0.01:
		look_at(global_position + forward, Vector3.UP)
	_wing_left.rotation.z = sin(_time * 2.4) * 0.42 - 0.08
	_wing_right.rotation.z = -sin(_time * 2.4) * 0.42 + 0.08
	for i in range(_tail_segments.size()):
		_tail_segments[i].rotation.y = sin(_time * 1.8 - i * 0.42) * (0.10 + i * 0.018)
	if global_position.distance_to(player.global_position) < 145.0 and _fire_cooldown <= 0.0:
		_breathe_fire()
		_fire_cooldown = 3.4


func _breathe_fire() -> void:
	var mouth := global_position + -global_transform.basis.z * 7.1 + Vector3(0, 1.5, 0)
	var target := player.global_position + Vector3(0, 0.8, 0)
	for i in range(5):
		var direction := (target - mouth).normalized()
		direction = direction.rotated(Vector3.UP, (i - 2) * 0.035)
		var projectile := WildProjectile.new()
		projectile.configure("fire", direction * (18.0 + i * 0.8), 18.0, self)
		get_tree().current_scene.add_child(projectile)
		projectile.global_position = mouth + direction * float(i) * 0.32
