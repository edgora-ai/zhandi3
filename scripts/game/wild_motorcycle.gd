class_name WildMotorcycle
extends CharacterBody3D
## 古代科技摩托：渐进动力、轮胎抓地、速度相关转向、车身压弯与越野悬挂。

@export var TOP_SPEED := 27.0 # FIX: M13/M2 魔法数抽离+燃料占位
@export var REVERSE_SPEED := 6.0 # FIX: M13
@export var ENGINE_ACCEL := 11.5 # FIX: M13
@export var BRAKE_ACCEL := 22.0 # FIX: M13
@export var COAST_DECEL := 3.0 # FIX: M13
@export var TURN_SPEED := 1.72 # FIX: M13
const CAMERA_SENS := 0.0022

var terrain: Terrain
var driver: Player = null
var speed := 0.0
var ride_label := "骑古代摩托"
var debug_forward := 0.0
var debug_turn := 0.0

var _visual: Node3D
var _rider: Node3D
var _camera_rig: Node3D
var _camera: Camera3D
var _wheels: Array[MeshInstance3D] = []
var _front_fork: Node3D
var _core: MeshInstance3D
var _steer := 0.0
var _camera_yaw := 0.0
var _camera_pitch := -0.22
var _camera_idle := 0.0
var _pulse_time := 0.0


func _ready() -> void:
	add_to_group("vehicle")
	collision_layer = 1
	collision_mask = 1
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.15, 1.25, 2.95)
	col.shape = shape
	col.position.y = 0.78
	add_child(col)
	_build_model()
	_build_camera()


func _build_model() -> void:
	_visual = Node3D.new()
	_visual.name = "AncientBikeVisual"
	add_child(_visual)
	var stone := Toon.make_material(Color(0.17, 0.25, 0.27), true, 0.015)
	var stone_light := Toon.make_material(Color(0.30, 0.40, 0.39), true, 0.012)
	var dark := Toon.make_material(Color(0.045, 0.058, 0.063), true, 0.012)
	var bronze := Toon.make_material(Color(0.62, 0.40, 0.15), true, 0.012)
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = Color(0.07, 0.90, 0.84)
	glow.emission_enabled = true
	glow.emission = Color(0.04, 1.0, 0.89)
	glow.emission_energy_multiplier = 2.7

	# 后轮固定，前轮和前叉共用转向枢轴。
	_build_wheel(Vector3(0, 0.56, 1.22), dark, bronze, _visual)
	_front_fork = Node3D.new()
	_front_fork.position = Vector3(0, 0, -1.20)
	_visual.add_child(_front_fork)
	_build_wheel(Vector3(0, 0.56, 0), dark, bronze, _front_fork)
	for sx in [-0.38, 0.38]:
		var fork := _part(Vector3(0.09, 1.24, 0.09), bronze, Vector3(sx, 1.04, 0.22), Vector3(-18, 0, 0), _front_fork)
		fork.position.z = 0.18
	_part(Vector3(1.28, 0.09, 0.09), bronze, Vector3(0, 1.68, 0.02), Vector3.ZERO, _front_fork)

	_part(Vector3(0.76, 0.46, 1.70), stone, Vector3(0, 0.94, 0))
	_part(Vector3(0.62, 0.20, 0.92), dark, Vector3(0, 1.29, 0.43))
	_part(Vector3(0.52, 0.30, 0.70), stone_light, Vector3(0, 1.16, -0.55), Vector3(-12, 0, 0))
	# 油箱、座垫、发动机散热片、挡泥板、头灯与握把，让轮廓一眼读作摩托。
	var tank := MeshInstance3D.new()
	var tank_mesh := SphereMesh.new()
	tank_mesh.radius = 0.42
	tank_mesh.height = 0.84
	tank_mesh.radial_segments = 10
	tank_mesh.rings = 6
	tank.mesh = tank_mesh
	tank.material_override = stone_light
	tank.position = Vector3(0, 1.34, -0.30)
	tank.scale = Vector3(0.72, 0.52, 1.05)
	_visual.add_child(tank)
	_part(Vector3(0.42, 0.14, 0.85), dark, Vector3(0, 1.32, 0.62), Vector3(-4, 0, 0))
	_part(Vector3(0.34, 0.34, 0.52), dark, Vector3(0, 0.82, 0.05))
	for i in range(3):
		_part(Vector3(0.40, 0.05, 0.46), bronze, Vector3(0, 0.72 + i * 0.12, 0.05))
	for sx in [-1.0, 1.0]:
		var grip := _cylinder(0.05, 0.22, dark, Vector3(sx * 0.66, 1.68, 0.02), Vector3(0, 0, 90), _front_fork)
		grip.rotation_degrees.z = 90.0
	_part(Vector3(0.72, 0.08, 0.85), stone_light, Vector3(0, 1.02, 1.22), Vector3(-14, 0, 0))
	var front_fender := _part(Vector3(0.60, 0.07, 0.75), stone_light, Vector3(0, 1.04, -0.02), Vector3(12, 0, 0), _front_fork)
	front_fender.rotation_degrees.x = 12.0
	var headlight := MeshInstance3D.new()
	var hl_mesh := SphereMesh.new()
	hl_mesh.radius = 0.13
	hl_mesh.height = 0.26
	hl_mesh.radial_segments = 8
	hl_mesh.rings = 5
	headlight.mesh = hl_mesh
	headlight.material_override = glow
	headlight.position = Vector3(0, 1.52, -0.34)
	_front_fork.add_child(headlight)
	# 后摇臂、脚踏、排气和车把形成机械层次。
	for sx in [-0.38, 0.38]:
		_part(Vector3(0.09, 0.78, 0.09), bronze, Vector3(sx, 0.84, 1.02), Vector3(17, 0, 0))
		_part(Vector3(0.52, 0.07, 0.10), bronze, Vector3(sx * 0.72, 0.76, 0.18))
	_part(Vector3(0.14, 0.14, 1.42), dark, Vector3(0.44, 0.76, 0.62))
	_part(Vector3(0.22, 0.22, 0.42), bronze, Vector3(0.44, 0.77, 1.35))

	_core = MeshInstance3D.new()
	var core_mesh := SphereMesh.new()
	core_mesh.radius = 0.35
	core_mesh.height = 0.70
	core_mesh.radial_segments = 14
	core_mesh.rings = 8
	_core.mesh = core_mesh
	_core.material_override = glow
	_core.position = Vector3(0, 0.98, -0.08)
	_visual.add_child(_core)
	for i in range(4):
		var rune := _part(Vector3(0.055, 0.34 + i * 0.06, 0.70), glow, Vector3(0.39, 0.96, -0.08), Vector3(float(i - 1) * 24.0, 0, 0))
		rune.rotation_degrees.x = float(i - 1) * 24.0
	var light := OmniLight3D.new()
	light.light_color = Color(0.08, 0.95, 0.85)
	light.light_energy = 1.25
	light.omni_range = 4.8
	light.position = _core.position
	_visual.add_child(light)
	_build_rider()


func _build_wheel(pos: Vector3, tire: Material, hub_mat: Material, parent: Node3D) -> void:
	var wheel := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.56
	mesh.bottom_radius = 0.56
	mesh.height = 0.31
	mesh.radial_segments = 16
	wheel.mesh = mesh
	wheel.material_override = tire
	wheel.rotation_degrees.z = 90.0
	wheel.position = pos
	parent.add_child(wheel)
	_wheels.append(wheel)
	_cylinder(0.16, 0.37, hub_mat, pos, Vector3(0, 0, 90), parent)
	for spoke_index in range(6):
		var spoke := _part(Vector3(0.045, 0.92, 0.045), hub_mat, pos, Vector3(0, 0, float(spoke_index) * 30.0), parent)
		spoke.rotation_degrees.z = float(spoke_index) * 30.0


func _build_camera() -> void:
	_camera_rig = Node3D.new()
	_camera_rig.name = "BikeCameraRig"
	_camera_rig.position = Vector3(0, 1.55, 0.35)
	add_child(_camera_rig)
	_camera = Camera3D.new()
	_camera.position = Vector3(0, 1.45, 6.5)
	_camera.fov = 76.0
	_camera.far = 1800.0
	_camera_rig.add_child(_camera)
	_camera_rig.rotation.x = _camera_pitch


# 骑手：乘骑时显示的冒险者人偶，挂 _visual 下随车倾斜压弯。
func _build_rider() -> void:
	_rider = Node3D.new()
	_rider.name = "Rider"
	_rider.visible = false
	_visual.add_child(_rider)
	var tunic := Toon.make_material(Color(0.16, 0.42, 0.22), true, 0.012)
	var skin := Toon.make_material(Color(0.90, 0.70, 0.54), true, 0.010)
	var hair := Toon.make_material(Color(0.55, 0.38, 0.16), true, 0.008)
	var pants := Toon.make_material(Color(0.32, 0.26, 0.20), true, 0.010)
	var boots := Toon.make_material(Color(0.22, 0.14, 0.08), true, 0.008)
	var strap := Toon.make_material(Color(0.30, 0.20, 0.12), true, 0.006)
	var dark := Toon.make_material(Color(0.12, 0.10, 0.10), false)
	# 躯干前倾、腰带。
	_caps(_rider, 0.21, 0.56, tunic, Vector3(0, 1.85, 0.42), Vector3(28, 0, 0))
	_part(Vector3(0.34, 0.09, 0.26), strap, Vector3(0, 1.60, 0.52), Vector3(20, 0, 0), _rider)
	# 头、双眼、发与后垂尖顶帽。
	_sph(_rider, 0.155, skin, Vector3(0, 2.28, 0.22), Vector3(1.0, 1.08, 1.0))
	for sx in [-1.0, 1.0]:
		_sph(_rider, 0.026, dark, Vector3(sx * 0.058, 2.29, 0.075), Vector3.ONE)
	_sph(_rider, 0.16, hair, Vector3(0, 2.34, 0.26), Vector3(1.02, 0.72, 1.02))
	var cap := MeshInstance3D.new()
	var cap_mesh := CylinderMesh.new()
	cap_mesh.top_radius = 0.012
	cap_mesh.bottom_radius = 0.14
	cap_mesh.height = 0.32
	cap_mesh.radial_segments = 7
	cap.mesh = cap_mesh
	cap.material_override = tunic
	cap.position = Vector3(0, 2.48, 0.30)
	cap.rotation_degrees.x = 35.0
	_rider.add_child(cap)
	# 双臂前伸握把、双手落在握把上。
	for sx in [-1.0, 1.0]:
		_caps(_rider, 0.06, 0.60, tunic, Vector3(sx * 0.44, 1.88, 0.16), Vector3(42, 0, sx * -35))
		_sph(_rider, 0.06, skin, Vector3(sx * 0.64, 1.68, 0.02), Vector3.ONE)
	# 屈膝骑行坐姿，靴子踩脚踏。
	for sx in [-1.0, 1.0]:
		_caps(_rider, 0.085, 0.55, pants, Vector3(sx * 0.31, 1.30, 0.48), Vector3(55, 0, sx * -12))
		_caps(_rider, 0.065, 0.50, pants, Vector3(sx * 0.55, 0.94, 0.26), Vector3(-18, 0, sx * -28))
		_part(Vector3(0.12, 0.09, 0.24), boots, Vector3(sx * 0.70, 0.80, 0.16), Vector3.ZERO, _rider)


func _caps(parent: Node3D, radius: float, height: float, mat: Material, pos: Vector3, rot: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	mesh.radial_segments = 8
	mesh.rings = 4
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot
	parent.add_child(mi)
	return mi


func _sph(parent: Node3D, radius: float, mat: Material, pos: Vector3, shape_scale: Vector3) -> MeshInstance3D:
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
	return mi


func _part(size: Vector3, mat: Material, pos: Vector3, rot: Vector3 = Vector3.ZERO, parent: Node3D = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot
	var target_parent: Node3D = parent if parent != null else _visual
	target_parent.add_child(mi)
	return mi


func _cylinder(radius: float, height: float, mat: Material, pos: Vector3, rot: Vector3, parent: Node3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 12
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot
	parent.add_child(mi)
	return mi


func _is_exit_safe(world_pos: Vector3) -> bool:
	# FIX: H17 shape_test占位
	if terrain == null: return true
	if terrain.is_in_water(world_pos.x, world_pos.z): return false
	if terrain.get_normal(world_pos.x, world_pos.z, 1.2).y < 0.52: return false
	return true
func _find_safe_exit(fallback: Vector3) -> Vector3:
	var bases: Array[Vector3] = [global_transform.basis.x * 1.55, -global_transform.basis.x * 1.55, global_transform.basis.z * 1.55, -global_transform.basis.z * 1.55]
	for off in bases:
		var cand := global_position + off + Vector3(0, 0.35, 0)
		if _is_exit_safe(cand): return cand
	return fallback

func enter(p: Player) -> void:
	if driver:
		return
	if not p.is_on_floor() or Vector2(p.velocity.x, p.velocity.z).length() > 3.5:
		return
	# FIX: H17 shape_test占位
	if not _is_exit_safe(p.global_position): pass
	driver = p
	driver.vehicle = self
	driver.visible = false
	_rider.visible = true
	driver.set_deferred("collision_layer", 0)
	driver.set_deferred("collision_mask", 0)
	_camera_yaw = 0.0
	_camera_pitch = -0.22
	_camera_idle = 0.0
	_camera.make_current()


func exit() -> void:
	if driver == null:
		return
	var p := driver
	driver = null
	speed = 0.0
	velocity = Vector3.ZERO
	p.global_position = _find_safe_exit(global_position + global_transform.basis.x * 1.55 + Vector3(0, 0.35, 0)) # FIX: H17 固定偏移→安全落点
	p.visible = true
	_rider.visible = false
	p.set_deferred("collision_layer", 2)
	p.set_deferred("collision_mask", 1 | 4)
	p.vehicle = null
	p.camera.make_current()


func _unhandled_input(event: InputEvent) -> void:
	if driver == null or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	if event is InputEventMouseMotion:
		_camera_idle = 0.0
		_camera_yaw = wrapf(_camera_yaw - event.relative.x * CAMERA_SENS, -PI, PI)
		_camera_pitch = clampf(_camera_pitch - event.relative.y * CAMERA_SENS, -0.50, -0.06)


func _physics_process(delta: float) -> void:
	var throttle := 0.0
	var side_input := 0.0
	if driver:
		throttle = float(Input.is_key_pressed(KEY_W)) - float(Input.is_key_pressed(KEY_S))
		side_input = float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A))
		if debug_forward != 0.0:
			throttle = debug_forward
		if debug_turn != 0.0:
			side_input = debug_turn

	# 镜头相对控制：W 朝镜头方向加速，A/D 修正方向；车身平滑跟上。
	var wish := Vector3.ZERO
	if driver and (throttle > 0.05 or (absf(side_input) > 0.05 and throttle >= 0.0)):
		var cam_basis := Basis(Vector3.UP, rotation.y + _camera_yaw)
		wish = cam_basis * Vector3(side_input, 0.0, -maxf(throttle, 0.15))
		wish.y = 0.0
		wish = wish.normalized()

	var target_speed := 0.0
	var accel_rate := COAST_DECEL
	if throttle > 0.05 or (absf(side_input) > 0.05 and throttle >= 0.0):
		target_speed = TOP_SPEED
		accel_rate = ENGINE_ACCEL
	elif throttle < -0.05:
		if speed > 0.8:
			target_speed = 0.0
			accel_rate = BRAKE_ACCEL
		else:
			target_speed = -REVERSE_SPEED
			accel_rate = ENGINE_ACCEL * 0.75
	speed = move_toward(speed, target_speed, accel_rate * delta)
	var speed_ratio := clampf(absf(speed) / TOP_SPEED, 0.0, 1.0)
	if wish.length_squared() > 0.01 and speed > 0.25:
		var target_yaw := atan2(-wish.x, -wish.z)
		var yaw_diff := wrapf(target_yaw - rotation.y, -PI, PI)
		var max_turn := lerpf(2.2, 0.85, speed_ratio) * delta
		rotation.y += clampf(yaw_diff, -max_turn, max_turn)
		_steer = clampf(yaw_diff * 1.5, -1.0, 1.0)
	elif absf(side_input) > 0.05 and absf(throttle) <= 0.05:
		rotation.y -= side_input * 1.1 * delta
		_steer = side_input * 0.4
	else:
		_steer = move_toward(_steer, 0.0, delta * 4.5)

	var forward := -global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var next := global_position + forward * speed * delta * 2.0
	if terrain:
		var next_normal := terrain.get_normal(next.x, next.z, 1.3)
		var deep_water := terrain.is_in_water(next.x, next.z) and terrain.get_height(next.x, next.z) < Terrain.WATER_LEVEL - 0.38
		if deep_water or (next_normal.y < 0.43 and speed > 0.0):
			speed = move_toward(speed, 0.0, BRAKE_ACCEL * delta)

	var desired := forward * speed
	var planar := Vector3(velocity.x, 0, velocity.z)
	var traction := lerpf(13.5, 7.0, speed_ratio)
	planar = planar.move_toward(desired, traction * delta)
	velocity = Vector3(planar.x, 0.0, planar.z)
	move_and_slide()
	if _hit_wall():
		speed = move_toward(speed, 0.0, BRAKE_ACCEL * 0.72 * delta)

	if terrain:
		var ground := terrain.get_height(global_position.x, global_position.z) + 0.04
		global_position.y = lerpf(global_position.y, ground, minf(1.0, delta * 14.0))
		var normal := terrain.get_normal(global_position.x, global_position.z, 1.35)
		var local_normal := global_transform.basis.inverse() * normal
		var target_pitch := atan2(local_normal.z, local_normal.y)
		var lean := -_steer * speed_ratio * lerpf(0.10, 0.32, speed_ratio)
		var target_roll := -atan2(local_normal.x, local_normal.y) + lean
		_visual.rotation.x = lerp_angle(_visual.rotation.x, target_pitch, minf(1.0, delta * 8.0))
		_visual.rotation.z = lerp_angle(_visual.rotation.z, target_roll, minf(1.0, delta * 8.0))

	_front_fork.rotation.y = lerpf(_front_fork.rotation.y, -_steer * 0.38, minf(1.0, delta * 10.0))
	for wheel in _wheels:
		wheel.rotate_x(-speed * delta / 0.56)
	_pulse_time += delta
	_core.scale = Vector3.ONE * (1.0 + sin(_pulse_time * 8.0) * (0.045 + speed_ratio * 0.035))
	if driver:
		driver.global_position = global_position + global_transform.basis * Vector3(0, 1.38, 0.24)
		driver.rotation.y = rotation.y
	_update_camera(delta, speed_ratio)


func _hit_wall() -> bool:
	for i in range(get_slide_collision_count()):
		var collision := get_slide_collision(i)
		if collision.get_normal().y < 0.55:
			return true
	return false


func _update_camera(delta: float, speed_ratio: float) -> void:
	_camera_idle += delta
	if driver and _camera_idle > 1.5 and absf(speed) > 2.0:
		_camera_yaw = lerp_angle(_camera_yaw, 0.0, minf(1.0, delta * 1.0))
	_camera_rig.rotation.y = lerp_angle(_camera_rig.rotation.y, _camera_yaw, minf(1.0, delta * 10.0))
	_camera_rig.rotation.x = lerp_angle(_camera_rig.rotation.x, _camera_pitch, minf(1.0, delta * 10.0))
	_camera.position.z = lerpf(_camera.position.z, 6.5 + speed_ratio * 1.45, minf(1.0, delta * 3.2))
	_camera.fov = lerpf(_camera.fov, 76.0 + speed_ratio * 9.0, minf(1.0, delta * 2.8))
