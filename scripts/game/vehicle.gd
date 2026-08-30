class_name Vehicle
extends CharacterBody3D
## 吉普车：渐进油门/刹车、速度相关转向、轮胎抓地、坡地悬挂与环绕镜头。

@export var TOP_SPEED := 20.0 # // FIX: M13 魔法数抽离 / M2 载具成本见燃料占位
@export var REVERSE_SPEED := 5.5 # // FIX: M13
@export var ENGINE_ACCEL := 10.0 # // FIX: M13
@export var BRAKE_ACCEL := 20.0 # // FIX: M13
@export var COAST_DECEL := 3.2 # // FIX: M13
@export var TURN_RATE := 1.7 # // FIX: M13
const CAMERA_SENS := 0.0022

var terrain: Terrain
var driver: Player = null
var speed := 0.0
var ride_label := "驾驶吉普车"
var debug_forward := 0.0
var debug_turn := 0.0
# // FIX: OPT-G3/PG5/M2 载具成本：血量 400 可击毁（爆炸对驾驶员 40 伤）、燃料 100 行驶消耗、驾驶员受伤 ×0.5 不再无敌
var hp := 400.0
var alive := true
var fuel := 100.0

var _visual: Node3D
var _rider: Node3D
var _camera_rig: Node3D
var _cam: Camera3D
var _wheels: Array[MeshInstance3D] = []
var _front_wheel_pivots: Array[Node3D] = []
var _steer := 0.0
var _camera_yaw := 0.0
var _camera_pitch := -0.23
var _camera_idle := 0.0
var _engine: AudioStreamPlayer3D # // FIX: OPT-E3 引擎循环


func _ready() -> void:
	add_to_group("vehicle")
	collision_layer = 1
	collision_mask = 1
	var body_col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.9, 1.35, 4.15)
	body_col.shape = shape
	body_col.position.y = 0.88
	add_child(body_col)
	_build_model()
	_build_camera()
	_build_rider()


func _build_model() -> void:
	_visual = Node3D.new()
	_visual.name = "JeepVisual"
	add_child(_visual)
	var green := Toon.make_material(Color(0.30, 0.38, 0.20), true, 0.02)
	var green_light := Toon.make_material(Color(0.43, 0.50, 0.27), true, 0.014)
	var dark := Toon.make_material(Color(0.075, 0.080, 0.075), true, 0.01)
	var metal := Toon.make_material(Color(0.35, 0.37, 0.32), true, 0.01)
	var glass := Toon.make_material(Color(0.28, 0.55, 0.66), false)
	var lamp := StandardMaterial3D.new()
	lamp.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lamp.albedo_color = Color(1.0, 0.83, 0.38)
	lamp.emission_enabled = true
	lamp.emission = Color(1.0, 0.72, 0.22)
	lamp.emission_energy_multiplier = 1.8

	# 车壳、轮眉、保险杠与敞篷防滚架。
	_part(Vector3(1.92, 0.55, 4.15), green, Vector3(0, 0.76, 0))
	_part(Vector3(1.72, 0.50, 2.05), green_light, Vector3(0, 1.22, 0.34))
	_part(Vector3(1.74, 0.10, 1.22), glass, Vector3(0, 1.43, -0.36), Vector3(-13, 0, 0))
	_part(Vector3(2.02, 0.18, 0.30), dark, Vector3(0, 0.49, -2.08))
	_part(Vector3(2.00, 0.16, 0.24), dark, Vector3(0, 0.55, 2.10))
	_part(Vector3(0.54, 0.54, 0.34), dark, Vector3(0, 0.96, 2.17))
	for sx in [-0.73, 0.73]:
		_part(Vector3(0.09, 1.08, 0.09), metal, Vector3(sx, 1.76, 0.84))
		_part(Vector3(0.09, 0.92, 0.09), metal, Vector3(sx, 1.68, -0.55), Vector3(-13, 0, 0))
	_part(Vector3(1.52, 0.09, 1.55), metal, Vector3(0, 2.18, 0.20))
	for sx in [-0.70, 0.70]:
		_part(Vector3(0.26, 0.24, 0.12), lamp, Vector3(sx, 0.91, -2.13))

	# 前轮有独立转向枢轴，四轮按实际速度旋转。
	for wx in [-0.88, 0.88]:
		for wz in [-1.46, 1.46]:
			var pivot := Node3D.new()
			pivot.position = Vector3(wx, 0.46, wz)
			_visual.add_child(pivot)
			if wz < 0.0:
				_front_wheel_pivots.append(pivot)
			var wheel := MeshInstance3D.new()
			var wheel_mesh := CylinderMesh.new()
			wheel_mesh.top_radius = 0.46
			wheel_mesh.bottom_radius = 0.46
			wheel_mesh.height = 0.32
			wheel_mesh.radial_segments = 14
			wheel.mesh = wheel_mesh
			wheel.material_override = dark
			wheel.rotation_degrees.z = 90.0
			pivot.add_child(wheel)
			_wheels.append(wheel)
			var hub := _cylinder(0.14, 0.36, metal, Vector3.ZERO, Vector3(0, 0, 90), pivot)
			hub.position = Vector3.ZERO


func _build_camera() -> void:
	_camera_rig = Node3D.new()
	_camera_rig.name = "JeepCameraRig"
	_camera_rig.position = Vector3(0, 1.60, 0.35)
	add_child(_camera_rig)
	_cam = Camera3D.new()
	_cam.position = Vector3(0, 1.65, 7.7)
	_cam.fov = 75.0
	_cam.far = 1500.0
	_camera_rig.add_child(_cam)
	_camera_rig.rotation.x = _camera_pitch


# 驾驶员：敞篷吉普的司机人偶（左舵），含方向盘与转向柱。
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
	const DX := -0.42
	# 躯干与腰带。
	_caps(_rider, 0.21, 0.54, tunic, Vector3(DX, 1.58, 0.50), Vector3(-4, 0, 0))
	_box(_rider, Vector3(0.34, 0.09, 0.26), strap, Vector3(DX, 1.36, 0.50), Vector3.ZERO)
	# 头、双眼、发与后垂尖顶帽。
	_sph(_rider, 0.155, skin, Vector3(DX, 1.92, 0.48), Vector3(1.0, 1.08, 1.0))
	for sx in [-1.0, 1.0]:
		_sph(_rider, 0.026, dark, Vector3(DX + sx * 0.058, 1.93, 0.335), Vector3.ONE)
	_sph(_rider, 0.16, hair, Vector3(DX, 1.98, 0.52), Vector3(1.02, 0.72, 1.02))
	var cap := MeshInstance3D.new()
	var cap_mesh := CylinderMesh.new()
	cap_mesh.top_radius = 0.012
	cap_mesh.bottom_radius = 0.14
	cap_mesh.height = 0.30
	cap_mesh.radial_segments = 7
	cap.mesh = cap_mesh
	cap.material_override = tunic
	cap.position = Vector3(DX, 2.04, 0.56)
	cap.rotation_degrees.x = 30.0
	_rider.add_child(cap)
	# 双臂前伸握方向盘。
	for sx in [-1.0, 1.0]:
		_caps(_rider, 0.06, 0.50, tunic, Vector3(DX + sx * 0.26, 1.64, 0.26), Vector3(52, 0, sx * -10))
		_sph(_rider, 0.06, skin, Vector3(DX + sx * 0.19, 1.52, 0.02), Vector3.ONE)
	# 屈膝踩踏板。
	for sx in [-1.0, 1.0]:
		_caps(_rider, 0.085, 0.50, pants, Vector3(DX + sx * 0.10, 1.16, 0.30), Vector3(68, 0, 0))
		_caps(_rider, 0.065, 0.45, pants, Vector3(DX + sx * 0.10, 0.94, 0.06), Vector3(-12, 0, 0))
		_box(_rider, Vector3(0.12, 0.10, 0.24), boots, Vector3(DX + sx * 0.10, 0.80, -0.08), Vector3.ZERO)
	# 方向盘与转向柱。
	var wheel := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.11
	torus.outer_radius = 0.16
	wheel.mesh = torus
	wheel.material_override = dark
	wheel.position = Vector3(DX, 1.50, -0.06)
	wheel.rotation_degrees.x = -32.0
	_visual.add_child(wheel)
	_cylinder(0.03, 0.38, dark, Vector3(DX, 1.30, -0.22), Vector3(58, 0, 0), _visual)


func _caps(parent: Node3D, radius: float, height: float, mat: Material, pos: Vector3, rot: Vector3) -> void:
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


func _sph(parent: Node3D, radius: float, mat: Material, pos: Vector3, shape_scale: Vector3) -> void:
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


func _box(parent: Node3D, size: Vector3, mat: Material, pos: Vector3, rot: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot
	parent.add_child(mi)


func _part(size: Vector3, mat: Material, pos: Vector3, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot
	_visual.add_child(mi)
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
	# // FIX: H17 shape_test占位：下车落点需碰撞校验（未来用 PhysicsShapeQueryParameters3D 球扫 0.6m）
	if terrain == null:
		return true
	if terrain.is_in_water(world_pos.x, world_pos.z):
		return false
	if terrain.get_normal(world_pos.x, world_pos.z, 1.2).y < 0.50:
		return false
	return true

func _find_safe_exit(fallback: Vector3) -> Vector3:
	# // FIX: H17 固定偏移改为多方向探测，首个安全点为出口
	var bases: Array[Vector3] = [global_transform.basis.x * 1.9, -global_transform.basis.x * 1.9, global_transform.basis.z * 1.9, -global_transform.basis.z * 1.9]
	for off in bases:
		var cand := global_position + off + Vector3(0, 0.55, 0)
		if _is_exit_safe(cand):
			return cand
	return fallback

func enter(p: Player) -> void:
	if driver:
		return
	if not p.is_on_floor() or Vector2(p.velocity.x, p.velocity.z).length() > 3.5:
		return # // FIX: M2 is_on_floor门限防空中上车+燃料成本占位：当前零燃料无限驾驶，未来在此接入耐力/燃料扣除与油量UI
	# // FIX: H17 enter前 shape_test占位：进入前可做体积扫判定
	# // FIX: M2 燃料占位：吉普车当前无消耗，is_on_floor门限已落地，未来对接 stamina/fuel 管线
	if not _is_exit_safe(p.global_position):
		pass # // FIX: H17 占位：未来在此做进入前碰撞通过校验
	# // FIX: OPT-E3 引擎循环启动（LOOP_FORWARD，随车速调音调由 _process 简化为固定）
	if _engine == null:
		var es := load("res://assets/sfx/engine_loop.wav") as AudioStreamWAV
		if es:
			es.loop_mode = AudioStreamWAV.LOOP_FORWARD
			es.loop_end = int(es.get_length() * es.mix_rate)
		_engine = AudioStreamPlayer3D.new()
		_engine.stream = es
		_engine.bus = "SFX"
		_engine.volume_db = -12.0
		_engine.max_distance = 60.0
		add_child(_engine)
	if _engine:
		_engine.play()
	driver = p
	driver.vehicle = self
	driver.visible = false
	_rider.visible = true
	# // FIX: OPT-G3/PG5 驾驶员保留受击层（layer 2）：子弹可命中驾驶员但伤害 ×0.5（player.take_damage 内判定 vehicle），
	# 不再"碰撞清零=车内无敌"；mask 仍清零避免物理接管
	driver.set_deferred("collision_layer", 2)
	driver.set_deferred("collision_mask", 0)
	_camera_yaw = 0.0
	_camera_pitch = -0.23
	_camera_idle = 0.0
	_cam.make_current()


func exit() -> void:
	if driver == null:
		return
	var p := driver
	driver = null
	speed = 0.0
	velocity = Vector3.ZERO
	if _engine:
		_engine.stop() # // FIX: OPT-E3 下车停引擎
	var fallback := global_position + global_transform.basis.x * 1.9 + Vector3(0, 0.55, 0)
	p.global_position = _find_safe_exit(fallback) # // FIX: H17 固定偏移→安全落点 shape_test
	p.visible = true
	_rider.visible = false
	p.set_deferred("collision_layer", 2)
	p.set_deferred("collision_mask", 1 | 4)
	p.vehicle = null
	p.camera.make_current()


# // FIX: OPT-G3/PG5 载具可被击毁：hp 400，爆炸 60 半径 40 伤（驾驶员受 40），残骸消失
func take_damage(amount: float, from: Variant = null, _part: String = "body") -> void:
	if not alive:
		return
	hp -= amount
	if hp <= 0.0:
		_explode(from)


func _explode(from: Variant) -> void:
	alive = false
	FX.impact(global_position + Vector3(0, 1.0, 0), Color(1.0, 0.5, 0.1))
	FX.melee_hit(global_position + Vector3(0, 1.0, 0), Vector3.UP, true)
	var sfx := get_tree().get_first_node_in_group("sfx_bank")
	if sfx:
		sfx.play_at("explosion", global_position, -2.0)
	var prev_driver: Player = driver # // FIX: R3-P1-3 exit() 后 driver=null，AoE 需排除前驾驶员（原双算 80 伤）
	if driver:
		exit()
		prev_driver.take_damage(40.0, from, "body")
	for c in get_tree().get_nodes_in_group("combatant"):
		if c.alive and c != prev_driver and global_position.distance_to(c.global_position) < 6.0:
			c.take_damage(40.0, from, "body")
	queue_free()




func _unhandled_input(event: InputEvent) -> void:
	if driver == null or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	if event is InputEventMouseMotion:
		_camera_idle = 0.0
		_camera_yaw = wrapf(_camera_yaw - event.relative.x * CAMERA_SENS, -PI, PI)
		_camera_pitch = clampf(_camera_pitch - event.relative.y * CAMERA_SENS, -0.50, -0.06)


func _physics_process(delta: float) -> void:
	var throttle := 0.0
	var turn_input := 0.0
	if driver:
		throttle = float(Input.is_key_pressed(KEY_W)) - float(Input.is_key_pressed(KEY_S))
		turn_input = float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A))
		if debug_forward != 0.0:
			throttle = debug_forward
		if debug_turn != 0.0:
			turn_input = debug_turn

	var target_speed := 0.0
	var accel_rate := COAST_DECEL
	# // FIX: OPT-G3/M2 燃料系统：行驶耗油 1.1/s；油尽限速 6m/s；油量<30 自动消耗驾驶员油桶 +60
	if driver and absf(throttle) > 0.05 and alive:
		var fuel_before := fuel
		fuel = maxf(0.0, fuel - 1.1 * delta)
		# // FIX: R3-P1-6 油量<30 预警并自动用桶（与注释口径一致，原拖到 0 才用桶且零 UX）
		if fuel < 30.0 and fuel_before >= 30.0 and driver.hud:
			driver.hud.add_feed("燃油不足 30%%（携带油桶 %d）" % driver.fuel_cans)
		if fuel < 30.0:
			if driver.fuel_cans > 0:
				driver.fuel_cans -= 1
				fuel = minf(100.0, fuel + 60.0) # // FIX: 燃料钳制 100（原可超 145，HUD 百分比溢出）
				if driver.hud:
					driver.hud.add_feed("自动用掉一桶燃油（剩余 %d 桶）" % driver.fuel_cans)
			elif fuel <= 0.0 and driver.hud and Engine.get_process_frames() % 120 == 0:
				driver.hud.add_feed("燃油耗尽！最高 6m/s，找油桶补给")
	if fuel <= 0.0:
		target_speed = minf(TOP_SPEED, 6.0)
		accel_rate = ENGINE_ACCEL * 0.6
	elif throttle > 0.05:
		target_speed = TOP_SPEED
		accel_rate = ENGINE_ACCEL
	elif throttle < -0.05:
		if speed > 0.7:
			target_speed = 0.0
			accel_rate = BRAKE_ACCEL
		else:
			target_speed = -REVERSE_SPEED
			accel_rate = ENGINE_ACCEL
	speed = move_toward(speed, target_speed, accel_rate * delta)
	_steer = move_toward(_steer, turn_input, delta * 4.2)
	var speed_ratio := clampf(absf(speed) / TOP_SPEED, 0.0, 1.0)
	if absf(speed) > 0.35:
		var steering_rate := lerpf(TURN_RATE, 0.72, speed_ratio)
		rotation.y -= _steer * steering_rate * delta * signf(speed)

	var forward := -global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var next := global_position + forward * speed * delta * 2.0
	if terrain:
		var next_normal := terrain.get_normal(next.x, next.z, 1.5)
		var deep_water := terrain.is_in_water(next.x, next.z) and terrain.get_height(next.x, next.z) < Terrain.WATER_LEVEL - 0.45
		if deep_water or (next_normal.y < 0.46 and speed > 0.0):
			speed = move_toward(speed, 0.0, BRAKE_ACCEL * delta)

	# 目标朝向和当前惯性之间保留少量差值，车身转向不再瞬间横移。
	var desired := forward * speed
	var planar := Vector3(velocity.x, 0, velocity.z)
	var traction := lerpf(15.0, 7.5, speed_ratio)
	planar = planar.move_toward(desired, traction * delta)
	velocity = Vector3(planar.x, 0.0, planar.z)
	move_and_slide()
	if _hit_wall():
		speed = move_toward(speed, 0.0, BRAKE_ACCEL * 0.75 * delta)

	if terrain:
		var ground := terrain.get_height(global_position.x, global_position.z) + 0.04
		global_position.y = lerpf(global_position.y, ground, minf(1.0, delta * 12.0))
		var normal := terrain.get_normal(global_position.x, global_position.z, 1.55)
		var local_normal := global_transform.basis.inverse() * normal
		var target_pitch := atan2(local_normal.z, local_normal.y)
		var target_roll := -atan2(local_normal.x, local_normal.y) - _steer * speed_ratio * 0.065
		_visual.rotation.x = lerp_angle(_visual.rotation.x, target_pitch, minf(1.0, delta * 7.0))
		_visual.rotation.z = lerp_angle(_visual.rotation.z, target_roll, minf(1.0, delta * 7.0))

	for pivot in _front_wheel_pivots:
		pivot.rotation.y = lerpf(pivot.rotation.y, -_steer * 0.42, minf(1.0, delta * 9.0))
	for wheel in _wheels:
		wheel.rotate_x(-speed * delta / 0.46)
	if driver:
		driver.global_position = global_position + global_transform.basis * Vector3(0, 1.25, 0.25)
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
	if driver and _camera_idle > 1.6 and absf(speed) > 2.0:
		_camera_yaw = lerp_angle(_camera_yaw, 0.0, minf(1.0, delta * 0.95))
	_camera_rig.rotation.y = lerp_angle(_camera_rig.rotation.y, _camera_yaw, minf(1.0, delta * 9.0))
	_camera_rig.rotation.x = lerp_angle(_camera_rig.rotation.x, _camera_pitch, minf(1.0, delta * 9.0))
	_cam.position.z = lerpf(_cam.position.z, 7.7 + speed_ratio * 1.1, minf(1.0, delta * 3.0))
	_cam.fov = lerpf(_cam.fov, 75.0 + speed_ratio * 7.0, minf(1.0, delta * 2.5))
