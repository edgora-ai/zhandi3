class_name WildMotorcycle
extends CharacterBody3D
## 古代科技摩托：可骑乘、快速越野、发光能量核心与悬挂姿态。

const TOP_SPEED := 24.0
const REVERSE_SPEED := 7.0
const ACCEL := 18.0
const TURN_SPEED := 1.85

var terrain: Terrain
var driver: Player = null
var speed := 0.0
var ride_label := "骑古代摩托"
var debug_forward := 0.0

var _camera: Camera3D
var _wheels: Array[MeshInstance3D] = []
var _core: MeshInstance3D


func _ready() -> void:
	add_to_group("vehicle")
	collision_layer = 1
	collision_mask = 1
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.2, 1.2, 2.9)
	col.shape = shape
	col.position.y = 0.75
	add_child(col)
	_build_model()


func _build_model() -> void:
	var stone := Toon.make_material(Color(0.19, 0.25, 0.27), true, 0.015)
	var dark := Toon.make_material(Color(0.055, 0.07, 0.075), true, 0.012)
	var bronze := Toon.make_material(Color(0.58, 0.38, 0.16), true, 0.012)
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = Color(0.08, 0.88, 0.82)
	glow.emission_enabled = true
	glow.emission = Color(0.05, 1.0, 0.88)
	glow.emission_energy_multiplier = 2.5
	for z in [-1.2, 1.2]:
		var wheel := MeshInstance3D.new()
		var wm := CylinderMesh.new()
		wm.top_radius = 0.53
		wm.bottom_radius = 0.53
		wm.height = 0.30
		wm.radial_segments = 14
		wheel.mesh = wm
		wheel.material_override = dark
		wheel.rotation_degrees.z = 90.0
		wheel.position = Vector3(0, 0.55, z)
		add_child(wheel)
		_wheels.append(wheel)
		_cylinder(0.14, 0.42, bronze, Vector3(0, 0.55, z), Vector3(0, 0, 90))
		for spoke in range(6):
			var bar := _part(Vector3(0.05, 0.86, 0.05), bronze, Vector3(0, 0.55, z))
			bar.rotation_degrees.z = float(spoke) * 30.0
	_part(Vector3(0.72, 0.44, 1.65), stone, Vector3(0, 0.92, 0))
	_part(Vector3(0.58, 0.18, 0.85), dark, Vector3(0, 1.25, 0.42))
	# 前后叉、把手、脚踏和排气管形成机械层次。
	for sx in [-0.38, 0.38]:
		var fork := _part(Vector3(0.09, 1.22, 0.09), bronze, Vector3(sx, 1.03, -0.93))
		fork.rotation_degrees.x = -18.0
		_part(Vector3(0.08, 0.68, 0.08), bronze, Vector3(sx, 0.82, 1.05))
	_part(Vector3(1.25, 0.09, 0.09), bronze, Vector3(0, 1.66, -1.08))
	_part(Vector3(1.05, 0.08, 0.12), bronze, Vector3(0, 0.82, 0.15))
	_part(Vector3(0.13, 0.13, 1.35), dark, Vector3(0.42, 0.75, 0.62))
	_core = MeshInstance3D.new()
	var core_mesh := SphereMesh.new()
	core_mesh.radius = 0.33
	core_mesh.height = 0.66
	core_mesh.radial_segments = 12
	core_mesh.rings = 7
	_core.mesh = core_mesh
	_core.material_override = glow
	_core.position = Vector3(0, 0.95, -0.08)
	add_child(_core)
	for i in range(3):
		var rune := _part(Vector3(0.05, 0.34 + i * 0.08, 0.68), glow, Vector3(0.37 + i * 0.018, 0.92, -0.08))
		rune.rotation_degrees.x = float(i - 1) * 28.0
	var light := OmniLight3D.new()
	light.light_color = Color(0.08, 0.95, 0.85)
	light.light_energy = 1.2
	light.omni_range = 4.5
	light.position = _core.position
	add_child(light)
	_camera = Camera3D.new()
	_camera.position = Vector3(0, 3.0, 6.0)
	_camera.rotation_degrees.x = -13.0
	_camera.far = 1800.0
	add_child(_camera)


func _part(size: Vector3, mat: Material, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	add_child(mi)
	return mi


func _cylinder(radius: float, height: float, mat: Material, pos: Vector3, rot: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 10
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot
	add_child(mi)
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
	var forward_input := 0.0
	var turn_input := 0.0
	if driver:
		forward_input = float(Input.is_key_pressed(KEY_W)) - float(Input.is_key_pressed(KEY_S))
		if debug_forward != 0.0:
			forward_input = debug_forward
		turn_input = float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A))
	var target := forward_input * (TOP_SPEED if forward_input >= 0.0 else REVERSE_SPEED)
	speed = move_toward(speed, target, ACCEL * delta)
	if absf(speed) > 0.45:
		rotation.y -= turn_input * TURN_SPEED * delta * signf(speed)
	var forward := -global_transform.basis.z
	var next := global_position + forward * speed * delta
	if terrain and terrain.is_in_water(next.x, next.z) and terrain.get_height(next.x, next.z) < Terrain.WATER_LEVEL - 0.4:
		speed = move_toward(speed, 0.0, ACCEL * 3.0 * delta)
	velocity = forward * speed
	velocity.y = 0.0
	move_and_slide()
	if terrain:
		var ground := terrain.get_height(global_position.x, global_position.z) + 0.08
		global_position.y = lerpf(global_position.y, ground, minf(1.0, delta * 14.0))
		var normal := terrain.get_normal(global_position.x, global_position.z, 1.8)
		rotation.x = lerpf(rotation.x, atan2(normal.z, normal.y), delta * 6.0)
		rotation.z = lerpf(rotation.z, -atan2(normal.x, normal.y) - turn_input * minf(absf(speed) / TOP_SPEED, 1.0) * 0.14, delta * 6.0)
	for wheel in _wheels:
		wheel.rotate_x(speed * delta * 1.9)
	_core.scale = Vector3.ONE * (1.0 + sin(Time.get_ticks_msec() * 0.008) * 0.055)
	if driver:
		driver.global_position = global_position + Vector3(0, 1.35, 0)
		driver.rotation.y = rotation.y
