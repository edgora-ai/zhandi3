class_name Horse
extends CharacterBody3D
## 程序化马匹：马体比例、分段步态、渐进转向、坡地抓地与可环绕骑乘镜头。

const WALK_SPEED := 9.0
const GALLOP_SPEED := 19.0
const REVERSE_SPEED := 3.2
const ACCEL := 10.0
const BRAKE := 16.0
const COAST_DECEL := 4.0
const TURN_SPEED := 1.85
const CAMERA_SENS := 0.0022

var terrain: Terrain
var driver: Player = null
var speed := 0.0
var ride_label := "骑马"
var debug_forward := 0.0
var debug_turn := 0.0

# 生成前可覆盖，让马群不再像同一个模型复制出来。
var coat_color := Color(0.43, 0.20, 0.075)
var coat_light_color := Color(0.62, 0.34, 0.13)
var mane_color := Color(0.095, 0.055, 0.032)
var marking_color := Color(0.90, 0.82, 0.64)

var _visual: Node3D
var _camera_rig: Node3D
var _camera: Camera3D
var _leg_roots: Array[Node3D] = []
var _lower_legs: Array[Node3D] = []
var _leg_phases: Array[float] = []
var _tail_root: Node3D
var _anim_time := 0.0
var _steer := 0.0
var _camera_yaw := 0.0
var _camera_pitch := -0.22
var _camera_idle := 0.0
var _head_node: Node3D
var bonded := false
var _rider: Node3D
var _buck_t := 0.0
var _graze_t := 0.0
var _call_target: Player = null
var _call_t := 0.0


func whistle_call(p: Player) -> void:
	if driver:
		return
	_call_target = p
	_call_t = 25.0


func _ready() -> void:
	add_to_group("vehicle")
	collision_layer = 1
	collision_mask = 1
	_build_collision()
	_build_model()
	_build_camera()


func _build_collision() -> void:
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.15, 2.15, 3.25)
	col.shape = box
	col.position = Vector3(0, 1.35, -0.08)
	add_child(col)


func _build_model() -> void:
	_visual = Node3D.new()
	_visual.name = "HorseVisual"
	add_child(_visual)
	var coat := Toon.make_material(coat_color, true, 0.018)
	var coat_light := Toon.make_material(coat_light_color, true, 0.014)
	var dark := Toon.make_material(mane_color, true, 0.012)
	var marking := Toon.make_material(marking_color, true, 0.010)
	var leather := Toon.make_material(Color(0.19, 0.095, 0.045), true, 0.012)
	var brass := Toon.make_material(Color(0.72, 0.48, 0.16), true, 0.009)
	var cloth := Toon.make_material(Color(0.08, 0.39, 0.49), true, 0.012)

	# 高而修长的躯干、深胸和圆润后躯，轮廓与鹿/羊式短身拉开差异。
	_capsule(_visual, 0.61, 2.98, coat, Vector3(0, 2.02, 0.02), Vector3(90, 0, 0), Vector3(1.0, 1.0, 1.04))
	_sphere(_visual, 0.66, coat_light, Vector3(0, 2.04, -0.80), Vector3(0.96, 1.07, 1.02))
	_sphere(_visual, 0.70, coat, Vector3(0, 2.04, 0.82), Vector3(1.0, 1.0, 1.08))
	_sphere(_visual, 0.40, marking, Vector3(0, 2.27, -0.88), Vector3(1.02, 0.75, 0.72))
	# 大腿/肩胛肌群与胸口，让四肢从身体里“长出来”而不是插在外壳上。
	for sx in [-1.0, 1.0]:
		_sphere(_visual, 0.34, coat_light, Vector3(sx * 0.48, 1.90, -0.82), Vector3(0.75, 1.15, 1.0))
		_sphere(_visual, 0.38, coat, Vector3(sx * 0.46, 1.88, 0.84), Vector3(0.72, 1.2, 1.05))
	_sphere(_visual, 0.30, coat_light, Vector3(0, 1.66, -1.10), Vector3(0.8, 1.0, 0.7))

	# 颈部向前上方抬起；头部是手工楔形网格，笔直收分的长脸是“马感”的核心轮廓。
	_capsule(_visual, 0.43, 1.68, coat_light, Vector3(0, 2.60, -1.38), Vector3(-62, 0, 0), Vector3(1.0, 1.0, 0.96))
	var head := Node3D.new()
	head.name = "Head"
	head.position = Vector3(0, 3.12, -2.00)
	head.rotation_degrees.x = -12.0
	_visual.add_child(head)
	_head_node = head
	_wedge(head, 0.21, 0.27, 0.105, 0.16, 1.32, coat_light)
	# 额前流星、双眼、短耳与鼻孔。
	_part(Vector3(0.09, 0.30, 0.045), marking, Vector3(0, 0.16, -0.62), head, Vector3(18, 0, 0))
	for sx in [-1.0, 1.0]:
		_sphere(head, 0.050, dark, Vector3(sx * 0.185, 0.10, -0.55), Vector3.ONE)
		_sphere(head, 0.028, marking, Vector3(sx * 0.198, 0.115, -0.575), Vector3.ONE)
		_cone(head, 0.015, 0.10, 0.26, coat, Vector3(sx * 0.125, 0.40, -0.06), Vector3(0, 0, sx * -10.0), 7)
		_sphere(head, 0.024, dark, Vector3(sx * 0.055, -0.16, -1.31), Vector3(1.0, 0.62, 0.75))
	_sphere(head, 0.075, dark, Vector3(0, -0.185, -1.29), Vector3(1.45, 0.55, 0.5))

	# 鬃毛像一条立式脊冠沿颈背延伸，尾巴由根部到末端逐渐加粗再收束。
	for i in range(8):
		var t := float(i) / 7.0
		var mane := _part(Vector3(0.07, 0.42, 0.36), dark, Vector3(0, lerpf(3.48, 2.84, t), lerpf(-1.80, -0.40, t)), _visual)
		mane.rotation_degrees.x = -28.0
	_tail_root = Node3D.new()
	_tail_root.position = Vector3(0, 2.22, 1.40)
	_visual.add_child(_tail_root)
	_capsule(_tail_root, 0.145, 1.58, dark, Vector3(0, -0.69, 0.31), Vector3(-24, 0, 0), Vector3.ONE)
	_sphere(_tail_root, 0.25, dark, Vector3(0, -1.47, 0.66), Vector3(0.72, 1.48, 0.78))

	# 鞍毯、前后鞍桥、腹带、脚蹬与缰绳。
	_part(Vector3(1.08, 0.10, 1.58), cloth, Vector3(0, 2.66, 0.16), _visual)
	_part(Vector3(0.82, 0.25, 1.02), leather, Vector3(0, 2.81, 0.12), _visual)
	for z in [-0.38, 0.58]:
		_part(Vector3(0.88, 0.31, 0.14), leather, Vector3(0, 2.95, z), _visual)
	for sx in [-1.0, 1.0]:
		_part(Vector3(0.075, 1.36, 0.10), leather, Vector3(sx * 0.52, 2.02, 0.12), _visual)
		_part(Vector3(0.10, 0.38, 0.20), brass, Vector3(sx * 0.58, 1.57, 0.18), _visual)
		var rein := _part(Vector3(0.035, 0.035, 2.25), leather, Vector3(sx * 0.31, 2.96, -1.18), _visual)
		rein.rotation_degrees.x = -10.0

	# 四腿分为上腿、膝下段和蹄，前后关节拥有独立枢轴。
	for z_index in range(2):
		for x_index in range(2):
			var sx := -0.43 if x_index == 0 else 0.43
			var sz := -0.86 if z_index == 0 else 0.86
			var leg := Node3D.new()
			leg.position = Vector3(sx, 1.72, sz)
			_visual.add_child(leg)
			_leg_roots.append(leg)
			_leg_phases.append(0.0 if (x_index + z_index) % 2 == 0 else PI)
			_capsule(leg, 0.145, 0.88, coat_light if z_index == 0 else coat, Vector3(0, -0.36, 0), Vector3.ZERO, Vector3.ONE)
			var knee := Node3D.new()
			knee.position = Vector3(0, -0.72, 0)
			leg.add_child(knee)
			_lower_legs.append(knee)
			_capsule(knee, 0.105, 0.82, coat, Vector3(0, -0.37, 0.025), Vector3.ZERO, Vector3.ONE)
			_part(Vector3(0.20, 0.14, 0.26), dark, Vector3(0, -0.68, -0.02), knee, Vector3(6, 0, 0))
			_part(Vector3(0.29, 0.18, 0.40), dark, Vector3(0, -0.82, -0.055), knee, Vector3(6, 0, 0))
	_build_rider()


# 骑手：乘骑时显示的冒险者人偶（绿衣尖帽），挂在 _visual 下随马体起伏。
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
	# 躯干、腰带与斜挎肩带，轻微前倾。
	_capsule(_rider, 0.21, 0.56, tunic, Vector3(0, 3.34, 0.10), Vector3(8, 0, 0), Vector3.ONE)
	_part(Vector3(0.34, 0.09, 0.26), strap, Vector3(0, 3.10, 0.10), _rider)
	_part(Vector3(0.07, 0.48, 0.24), strap, Vector3(-0.06, 3.38, 0.10), _rider, Vector3(0, 0, 28))
	# 头部：脸、双眼、发髻与后垂尖顶软帽。
	_sphere(_rider, 0.155, skin, Vector3(0, 3.80, 0.06), Vector3(1.0, 1.08, 1.0))
	for sx in [-1.0, 1.0]:
		_sphere(_rider, 0.026, dark, Vector3(sx * 0.058, 3.81, -0.085), Vector3.ONE)
	_sphere(_rider, 0.16, hair, Vector3(0, 3.86, 0.10), Vector3(1.02, 0.72, 1.02))
	_cone(_rider, 0.012, 0.14, 0.32, tunic, Vector3(0, 4.02, 0.14), Vector3(22, 0, 0), 7)
	# 双臂前伸握缰。
	for sx in [-1.0, 1.0]:
		_capsule(_rider, 0.06, 0.42, tunic, Vector3(sx * 0.26, 3.34, -0.06), Vector3(-52, 0, sx * -8), Vector3.ONE)
		_sphere(_rider, 0.055, skin, Vector3(sx * 0.27, 3.20, -0.24), Vector3.ONE)
	# 双腿跨坐、踩蹬。
	for sx in [-1.0, 1.0]:
		_capsule(_rider, 0.085, 0.46, pants, Vector3(sx * 0.30, 2.92, 0.14), Vector3(20, 0, sx * -38), Vector3.ONE)
		_capsule(_rider, 0.065, 0.42, pants, Vector3(sx * 0.50, 2.38, 0.16), Vector3(-12, 0, sx * -6), Vector3.ONE)
		_part(Vector3(0.12, 0.10, 0.24), boots, Vector3(sx * 0.53, 2.13, 0.10), _rider)


func _build_camera() -> void:
	_camera_rig = Node3D.new()
	_camera_rig.name = "RidingCameraRig"
	_camera_rig.position = Vector3(0, 2.05, 0.45)
	add_child(_camera_rig)
	_camera = Camera3D.new()
	_camera.position = Vector3(0, 1.25, 6.7)
	_camera.fov = 75.0
	_camera.far = 1800.0
	_camera_rig.add_child(_camera)
	_camera_rig.rotation.x = _camera_pitch


func _part(size: Vector3, mat: Material, pos: Vector3, parent: Node3D, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot
	parent.add_child(mi)
	return mi


func _sphere(parent: Node3D, radius: float, mat: Material, pos: Vector3, shape_scale: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 12
	mesh.rings = 7
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
	mesh.radial_segments = 10
	mesh.rings = 5
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot
	mi.scale = shape_scale
	parent.add_child(mi)
	return mi


func _cone(parent: Node3D, top_radius: float, bottom_radius: float, height: float, mat: Material, pos: Vector3, rot: Vector3, segments: int) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = top_radius
	mesh.bottom_radius = bottom_radius
	mesh.height = height
	mesh.radial_segments = segments
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot
	parent.add_child(mi)
	return mi


# 手工楔形棱柱：后脑宽、鼻梁窄且略下沉，形成马特有的笔直长脸。
func _wedge(parent: Node3D, half_w: float, half_h: float, front_w: float, front_h: float, length: float, mat: Material) -> MeshInstance3D:
	var drop := 0.09
	var b0 := Vector3(-half_w, -half_h, 0)
	var b1 := Vector3(half_w, -half_h, 0)
	var b2 := Vector3(half_w, half_h, 0)
	var b3 := Vector3(-half_w, half_h, 0)
	var f0 := Vector3(-front_w, -front_h - drop, -length)
	var f1 := Vector3(front_w, -front_h - drop, -length)
	var f2 := Vector3(front_w, front_h - drop, -length)
	var f3 := Vector3(-front_w, front_h - drop, -length)
	# Godot 前向面为顺时针绕序；法线取 -cross 指向楔形外侧。
	var tris: Array = [
		[b0, b3, b2], [b0, b2, b1],
		[f0, f1, f2], [f0, f2, f3],
		[b3, f3, f2], [b3, f2, b2],
		[b0, b1, f1], [b0, f1, f0],
		[b0, f0, f3], [b0, f3, b3],
		[b1, b2, f2], [b1, f2, f1],
	]
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	for tri in tris:
		var a: Vector3 = tri[0]
		var b: Vector3 = tri[1]
		var c: Vector3 = tri[2]
		var n := -((b - a).cross(c - b)).normalized()
		for v in [a, b, c]:
			verts.append(v)
			normals.append(n)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	parent.add_child(mi)
	return mi


func enter(p: Player) -> void:
	if driver:
		return
	# 驯服：未亲近的马第一次被骑可能尥蹶子把人甩下来；安抚一次后永久温顺。
	if not bonded and randf() < 0.45:
		bonded = true
		_buck_t = 0.9
		p.velocity = global_transform.basis.z * 3.0 + Vector3(0, 2.5, 0)
		var scene := get_tree().current_scene
		if scene and scene.get("hud") != null:
			scene.hud.add_feed("马匹受惊把你甩了下来！再靠近试试")
		return
	bonded = true
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
	var side := global_transform.basis.x * 1.7
	p.global_position = global_position + side + Vector3(0, 0.35, 0)
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
		_camera_pitch = clampf(_camera_pitch - event.relative.y * CAMERA_SENS, -0.52, -0.06)


func _physics_process(delta: float) -> void:
	# 尥蹶子：后仰抖动，期间不能骑。
	if _buck_t > 0.0:
		_buck_t -= delta
		_visual.rotation.x = lerpf(_visual.rotation.x, -0.55 if _buck_t > 0.35 else 0.0, delta * 8.0)
		_visual.rotation.z = sin(_buck_t * 30.0) * 0.05
		speed = 0.0
		velocity = Vector3.ZERO
		move_and_slide()
		return
	# 口哨召唤：无人骑乘时朝玩家小跑过来，靠近后停下。
	if driver == null and _call_target != null:
		_call_t -= delta
		var to_p := _call_target.global_position - global_position
		to_p.y = 0.0
		if to_p.length() < 4.0 or _call_t <= 0.0:
			_call_target = null
		else:
			var dir := to_p.normalized()
			speed = move_toward(speed, 4.5, ACCEL * delta)
			rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), delta * 4.0)
			velocity = dir * speed
			move_and_slide()
			if terrain:
				global_position.y = lerpf(global_position.y, terrain.get_height(global_position.x, global_position.z) + 0.06, minf(1.0, delta * 13.0))
			_animate_gait(delta, clampf(speed / GALLOP_SPEED, 0.0, 1.0))
			return
	var input_forward := 0.0
	var input_side := 0.0
	var galloping := false
	if driver:
		input_forward = float(Input.is_key_pressed(KEY_W)) - float(Input.is_key_pressed(KEY_S))
		input_side = float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A))
		galloping = Input.is_key_pressed(KEY_SHIFT)
		if debug_forward != 0.0:
			input_forward = debug_forward
		if debug_turn != 0.0:
			input_side = debug_turn

	# 镜头相对控制：W 让马朝镜头朝向走，A/D 左右修正；马体平滑转向目标方向。
	var wish := Vector3.ZERO
	if driver and (input_forward > 0.05 or (absf(input_side) > 0.05 and input_forward >= 0.0)):
		var cam_basis := Basis(Vector3.UP, rotation.y + _camera_yaw)
		wish = cam_basis * Vector3(input_side, 0.0, -maxf(input_forward, 0.15))
		wish.y = 0.0
		wish = wish.normalized()

	var target_speed := 0.0
	var accel_rate := COAST_DECEL
	if input_forward > 0.05 or (absf(input_side) > 0.05 and input_forward >= 0.0):
		target_speed = GALLOP_SPEED if galloping else WALK_SPEED
		accel_rate = ACCEL
	elif input_forward < -0.05:
		if speed > 0.55:
			target_speed = 0.0
			accel_rate = BRAKE
		else:
			target_speed = -REVERSE_SPEED
			accel_rate = ACCEL * 0.7
	speed = move_toward(speed, target_speed, accel_rate * delta)
	var speed_ratio := clampf(absf(speed) / GALLOP_SPEED, 0.0, 1.0)
	if wish.length_squared() > 0.01 and speed > 0.2:
		var target_yaw := atan2(-wish.x, -wish.z)
		var yaw_diff := wrapf(target_yaw - rotation.y, -PI, PI)
		var max_turn := lerpf(2.6, 1.0, speed_ratio) * delta
		rotation.y += clampf(yaw_diff, -max_turn, max_turn)
		_steer = clampf(yaw_diff * 1.6, -1.0, 1.0)
	elif absf(input_side) > 0.05 and absf(input_forward) <= 0.05:
		# 原地转身：站立时 A/D 直接调头。
		rotation.y -= input_side * 1.4 * delta
		_steer = input_side * 0.5
	else:
		_steer = move_toward(_steer, 0.0, delta * 4.0)

	var forward := -global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()
	# 道路自动跟随：松手骑行时贴近道路中线（旷野之息式的“马会看路”）。
	if driver and absf(input_forward) <= 0.05 and absf(input_side) <= 0.05 and speed > 2.0:
		var follow := _nearest_road()
		if follow["dist"] < 7.0:
			var road_dir: Vector3 = follow["dir"]
			if road_dir.dot(forward) < 0.0:
				road_dir = -road_dir
			rotation.y = lerp_angle(rotation.y, atan2(-road_dir.x, -road_dir.z), minf(1.0, delta * 1.1))
	var next := global_position + forward * speed * delta * 1.8
	if terrain:
		var next_normal := terrain.get_normal(next.x, next.z, 1.2)
		var deep_water := terrain.is_in_water(next.x, next.z) and terrain.get_height(next.x, next.z) < Terrain.WATER_LEVEL - 0.75
		if deep_water or (next_normal.y < 0.48 and speed > 0.0):
			speed = move_toward(speed, 0.0, BRAKE * delta)

	var desired := forward * speed
	var planar := Vector3(velocity.x, 0, velocity.z)
	var grip := lerpf(7.0, 12.0, speed_ratio)
	planar = planar.move_toward(desired, grip * delta)
	velocity = Vector3(planar.x, 0.0, planar.z)
	move_and_slide()
	if _hit_wall():
		speed = move_toward(speed, 0.0, BRAKE * 0.7 * delta)

	if terrain:
		var ground := terrain.get_height(global_position.x, global_position.z) + 0.06
		global_position.y = lerpf(global_position.y, ground, minf(1.0, delta * 13.0))
		var normal := terrain.get_normal(global_position.x, global_position.z, 1.25)
		var local_normal := global_transform.basis.inverse() * normal
		var target_pitch := atan2(local_normal.z, local_normal.y)
		var target_roll := -atan2(local_normal.x, local_normal.y) - _steer * speed_ratio * 0.08
		_visual.rotation.x = lerp_angle(_visual.rotation.x, target_pitch, minf(1.0, delta * 6.0))
		_visual.rotation.z = lerp_angle(_visual.rotation.z, target_roll, minf(1.0, delta * 6.0))

	if driver:
		driver.global_position = global_position + global_transform.basis * Vector3(0, 2.75, 0.12)
		driver.rotation.y = rotation.y
	_update_camera(delta, speed_ratio)
	_animate_gait(delta, speed_ratio)


func _nearest_road() -> Dictionary:
	var best_d := 9999.0
	var best_dir := Vector3.ZERO
	var p := Vector2(global_position.x, global_position.z)
	for segment in Terrain.WILD_ROADS:
		var a: Vector2 = segment[0]
		var b: Vector2 = segment[1]
		var ab := b - a
		var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)
		var d := p.distance_to(a + ab * t)
		if d < best_d:
			best_d = d
			var abn := ab.normalized()
			best_dir = Vector3(abn.x, 0, abn.y)
	return {"dir": best_dir, "dist": best_d}


func _hit_wall() -> bool:
	for i in range(get_slide_collision_count()):
		var collision := get_slide_collision(i)
		if collision.get_normal().y < 0.55:
			return true
	return false


func _update_camera(delta: float, speed_ratio: float) -> void:
	if _camera_rig == null:
		return
	_camera_idle += delta
	if driver and _camera_idle > 1.8 and absf(speed) > 2.0:
		_camera_yaw = lerp_angle(_camera_yaw, 0.0, minf(1.0, delta * 0.8))
	_camera_rig.rotation.y = lerp_angle(_camera_rig.rotation.y, _camera_yaw, minf(1.0, delta * 9.0))
	_camera_rig.rotation.x = lerp_angle(_camera_rig.rotation.x, _camera_pitch, minf(1.0, delta * 9.0))
	_camera.position.z = lerpf(_camera.position.z, 6.7 + speed_ratio * 1.25, minf(1.0, delta * 3.0))
	_camera.fov = lerpf(_camera.fov, 75.0 + speed_ratio * 7.0, minf(1.0, delta * 2.5))


func _animate_gait(delta: float, speed_ratio: float) -> void:
	var actual_speed := Vector2(velocity.x, velocity.z).length()
	# 步态分级：慢步低频小摆 / 快步弹震 / 疾驰大步悬浮，频率随档位跳变。
	var freq := 5.0
	var amp_mul := 0.6
	if speed_ratio > 0.75:
		freq = 11.0
		amp_mul = 1.0
	elif speed_ratio > 0.4:
		freq = 8.0
		amp_mul = 0.8
	if actual_speed > 0.08:
		_anim_time += delta * freq
	var amount := smoothstep(0.02, 0.35, speed_ratio) * 0.72 * amp_mul
	for i in range(_leg_roots.size()):
		var wave := sin(_anim_time + _leg_phases[i])
		_leg_roots[i].rotation.x = wave * amount
		_lower_legs[i].rotation.x = maxf(0.0, -wave) * 0.58 * speed_ratio
	var bob := absf(sin(_anim_time)) * 0.10 * speed_ratio * amp_mul
	_visual.position.y = lerpf(_visual.position.y, bob, minf(1.0, delta * 10.0))
	# 头部随步态点头；无人骑乘且静置时周期性低头吃草。
	if _head_node:
		if driver or actual_speed > 0.5:
			_head_node.rotation.x = -0.21 + sin(_anim_time) * (0.05 + speed_ratio * 0.09)
	if _tail_root:
		_tail_root.rotation.y = sin(_anim_time * 0.47) * (0.10 + speed_ratio * 0.16)
	_graze_t += delta
	if driver == null and actual_speed < 0.2 and _head_node:
		var grazing := fmod(_graze_t, 9.0) > 6.2
		_head_node.rotation.x = lerpf(_head_node.rotation.x, 0.85 if grazing else -0.21, delta * 2.0)
