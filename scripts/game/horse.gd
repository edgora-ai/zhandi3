class_name Horse
extends CharacterBody3D
## 程序化马匹：可骑乘、慢行/疾驰、坡地贴合与四肢步态。

const WALK_SPEED := 7.5
const GALLOP_SPEED := 15.5
const ACCEL := 11.0
const TURN_SPEED := 1.65

var terrain: Terrain
var driver: Player = null
var speed := 0.0
var ride_label := "骑马"
var debug_forward := 0.0

var _camera: Camera3D
var _legs: Array[Node3D] = []
var _anim_time := 0.0


func _ready() -> void:
	add_to_group("vehicle")
	collision_layer = 1
	collision_mask = 1
	_build_collision()
	_build_model()


func _build_collision() -> void:
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.0, 1.8, 2.7)
	col.shape = box
	col.position = Vector3(0, 1.15, 0)
	add_child(col)


func _build_model() -> void:
	var coat := Toon.make_material(Color(0.48, 0.25, 0.11), true, 0.018)
	var coat_light := Toon.make_material(Color(0.68, 0.40, 0.18), true, 0.014)
	var dark := Toon.make_material(Color(0.12, 0.075, 0.045), true, 0.01)
	var leather := Toon.make_material(Color(0.22, 0.12, 0.07), true, 0.012)
	var cloth := Toon.make_material(Color(0.12, 0.42, 0.48), true, 0.012)
	# 胸腹体块、肩胛和臀部，轮廓比单一胶囊更接近马体。
	_capsule(self, 0.53, 2.25, coat, Vector3(0, 1.45, 0), Vector3(90, 0, 0), Vector3(1.0, 1.0, 1.12))
	_sphere(self, 0.62, coat_light, Vector3(0, 1.52, -0.62), Vector3(1.0, 1.05, 1.1))
	_sphere(self, 0.58, coat, Vector3(0, 1.48, 0.72), Vector3(1.0, 1.0, 1.08))
	# 斜颈、长脸、口鼻与耳朵。
	var neck := _capsule(self, 0.31, 1.35, coat_light, Vector3(0, 2.05, -1.0), Vector3(-34, 0, 0), Vector3.ONE)
	neck.rotation_degrees.x = -34.0
	_capsule(self, 0.25, 0.92, coat_light, Vector3(0, 2.62, -1.43), Vector3(70, 0, 0), Vector3(0.9, 0.9, 1.0))
	_sphere(self, 0.27, coat_light, Vector3(0, 2.63, -1.72), Vector3(1.0, 0.85, 1.35))
	_sphere(self, 0.18, dark, Vector3(0, 2.57, -1.94), Vector3(1.15, 0.72, 0.8))
	for sx in [-1.0, 1.0]:
		_sphere(self, 0.045, dark, Vector3(sx * 0.22, 2.76, -1.78), Vector3.ONE)
		var ear := _part(Vector3(0.11, 0.38, 0.10), coat, Vector3(sx * 0.16, 3.02, -1.53), self)
		ear.rotation_degrees.z = sx * -12.0
	# 鬃毛由连续深色片组成，形成清晰锯齿轮廓。
	for i in range(7):
		var mane := _part(Vector3(0.10, 0.32, 0.34), dark, Vector3(0, 2.75 - i * 0.18, -1.28 + i * 0.16), self)
		mane.rotation_degrees.x = -18.0
	# 马鞍、鞍毯、腹带与缰绳。
	_part(Vector3(0.92, 0.09, 1.35), cloth, Vector3(0, 2.02, 0.12), self)
	_part(Vector3(0.72, 0.22, 0.88), leather, Vector3(0, 2.14, 0.08), self)
	_part(Vector3(0.09, 1.25, 0.10), leather, Vector3(0.48, 1.62, 0.1), self)
	_part(Vector3(0.09, 1.25, 0.10), leather, Vector3(-0.48, 1.62, 0.1), self)
	# 四腿各有上下两段与深色马蹄，枢轴用于步态动画。
	for sx in [-0.36, 0.36]:
		for sz in [-0.78, 0.78]:
			var leg := Node3D.new()
			leg.position = Vector3(sx, 1.35, sz)
			add_child(leg)
			_legs.append(leg)
			_capsule(leg, 0.115, 0.78, coat_light if sz < 0 else coat, Vector3(0, -0.34, 0), Vector3.ZERO, Vector3.ONE)
			_capsule(leg, 0.09, 0.72, coat, Vector3(0, -0.98, 0.03), Vector3.ZERO, Vector3.ONE)
			_part(Vector3(0.25, 0.16, 0.34), dark, Vector3(0, -1.36, -0.04), leg)
	# 尾巴用逐段收细的胶囊形成自然下垂曲线。
	for i in range(5):
		var tail := _capsule(self, 0.12 - i * 0.012, 0.52, dark, Vector3(0, 1.56 - i * 0.28, 1.38 + i * 0.12), Vector3(20 + i * 7, 0, 0), Vector3.ONE)
		tail.rotation_degrees.x = 20.0 + i * 7.0

	_camera = Camera3D.new()
	_camera.position = Vector3(0, 3.8, 6.5)
	_camera.rotation_degrees.x = -14.0
	_camera.far = 1800.0
	add_child(_camera)


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


func enter(p: Player) -> void:
	if driver:
		return
	driver = p
	driver.vehicle = self
	driver.visible = false
	driver.set_deferred("collision_layer", 0)
	driver.set_deferred("collision_mask", 0)
	_camera.make_current()


func exit() -> void:
	if driver == null:
		return
	var p := driver
	driver = null
	speed = 0.0
	p.global_position = global_position + global_transform.basis.x * 1.5 + Vector3(0, 0.4, 0)
	p.visible = true
	p.set_deferred("collision_layer", 2)
	p.set_deferred("collision_mask", 1 | 4)
	p.vehicle = null
	p.camera.make_current()


func _physics_process(delta: float) -> void:
	var input_forward := 0.0
	var input_turn := 0.0
	if driver:
		input_forward = float(Input.is_key_pressed(KEY_W)) - float(Input.is_key_pressed(KEY_S))
		if debug_forward != 0.0:
			input_forward = debug_forward
		input_turn = float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A))
		var max_speed := GALLOP_SPEED if Input.is_key_pressed(KEY_SHIFT) else WALK_SPEED
		var target := input_forward * max_speed
		speed = move_toward(speed, target, ACCEL * delta)
		if absf(speed) > 0.35:
			rotation.y -= input_turn * TURN_SPEED * delta * signf(speed)
	else:
		speed = move_toward(speed, 0.0, ACCEL * delta)
	var forward := -global_transform.basis.z
	var next := global_position + forward * speed * delta
	if terrain and terrain.is_in_water(next.x, next.z) and terrain.get_height(next.x, next.z) < Terrain.WATER_LEVEL - 0.8:
		speed = move_toward(speed, 0.0, ACCEL * 2.0 * delta)
	velocity = forward * speed
	velocity.y = 0.0
	move_and_slide()
	if terrain:
		var ground := terrain.get_height(global_position.x, global_position.z) + 0.08
		global_position.y = lerpf(global_position.y, ground, minf(1.0, delta * 12.0))
		var normal := terrain.get_normal(global_position.x, global_position.z, 1.4)
		rotation.x = lerpf(rotation.x, atan2(normal.z, normal.y), delta * 5.0)
		rotation.z = lerpf(rotation.z, -atan2(normal.x, normal.y), delta * 5.0)
	if driver:
		driver.global_position = global_position + Vector3(0, 1.9, 0)
		driver.rotation.y = rotation.y
	_animate_legs(delta)


func _animate_legs(delta: float) -> void:
	_anim_time += delta * (2.2 + absf(speed) * 0.8)
	var amount := clampf(absf(speed) / GALLOP_SPEED, 0.0, 1.0) * 0.72
	for i in range(_legs.size()):
		var phase := 0.0 if i in [0, 3] else PI
		_legs[i].rotation.x = sin(_anim_time + phase) * amount
