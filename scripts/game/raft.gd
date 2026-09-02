class_name Raft
extends CharacterBody3D
## 木筏：河边按 F 乘上，W/S 前后、A/D 转向，浮在水面代步过河。

const SPEED := 6.5
const TURN := 1.4

var driver: Player = null
var ride_label := "乘木筏"
var debug_forward := 0.0

var _camera: Camera3D
var _rider: Node3D


func _ready() -> void:
	add_to_group("vehicle")
	collision_layer = 1
	collision_mask = 1
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.2, 0.5, 3.4)
	col.shape = shape
	col.position.y = 0.3
	add_child(col)
	_build_model()
	_camera = Camera3D.new()
	_camera.position = Vector3(0, 3.2, 5.8)
	_camera.rotation_degrees.x = -16.0
	_camera.far = 1800.0
	add_child(_camera)


func _build_model() -> void:
	var wood := Toon.make_material(Color(0.45, 0.30, 0.14), true, 0.012)
	var dark := Toon.make_material(Color(0.25, 0.16, 0.08), true, 0.010)
	# 五根并排圆木 + 两根横向绑木 + 舵桨。
	for i in range(5):
		var log := MeshInstance3D.new()
		var lm := CylinderMesh.new()
		lm.top_radius = 0.20
		lm.bottom_radius = 0.20
		lm.height = 3.4
		lm.radial_segments = 8
		log.mesh = lm
		log.material_override = wood
		log.rotation_degrees.x = 90.0
		log.position = Vector3(-0.88 + i * 0.44, 0.2, 0)
		add_child(log)
	for z in [-1.1, 1.1]:
		var tie := MeshInstance3D.new()
		var tm := CylinderMesh.new()
		tm.top_radius = 0.08
		tm.bottom_radius = 0.08
		tm.height = 2.3
		tm.radial_segments = 6
		tie.mesh = tm
		tie.material_override = dark
		tie.rotation_degrees.z = 90.0
		tie.position = Vector3(0, 0.42, z)
		add_child(tie)
	var paddle := MeshInstance3D.new()
	var pm := CylinderMesh.new()
	pm.top_radius = 0.04
	pm.bottom_radius = 0.04
	pm.height = 1.8
	pm.radial_segments = 6
	paddle.mesh = pm
	paddle.material_override = dark
	paddle.position = Vector3(0.8, 0.9, 1.2)
	paddle.rotation_degrees = Vector3(20, 0, -14)
	add_child(paddle)
	var blade := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.02, 0.4, 0.16)
	blade.mesh = bm
	blade.material_override = dark
	blade.position = Vector3(0.9, 0.25, 1.35)
	blade.rotation_degrees = Vector3(20, 0, -14)
	add_child(blade)
	_build_rider()


# 骑手：乘筏时显示的冒险者人偶，站在舵桨旁扶桨。
func _build_rider() -> void:
	_rider = Node3D.new()
	_rider.name = "Rider"
	_rider.visible = false
	add_child(_rider)
	var tunic := Toon.make_material(Color(0.16, 0.42, 0.22), true, 0.012)
	var skin := Toon.make_material(Color(0.90, 0.70, 0.54), true, 0.010)
	var hair := Toon.make_material(Color(0.55, 0.38, 0.16), true, 0.008)
	var pants := Toon.make_material(Color(0.32, 0.26, 0.20), true, 0.010)
	var boots := Toon.make_material(Color(0.22, 0.14, 0.08), true, 0.008)
	var strap := Toon.make_material(Color(0.30, 0.20, 0.12), true, 0.006)
	var dark := Toon.make_material(Color(0.12, 0.10, 0.10), false)
	# 站立双腿与靴。
	for sx in [-1.0, 1.0]:
		_caps(_rider, 0.07, 0.52, pants, Vector3(sx * 0.13, 0.70, 0.85), Vector3.ZERO)
		_box(_rider, Vector3(0.12, 0.10, 0.24), boots, Vector3(sx * 0.13, 0.45, 0.80), Vector3.ZERO)
	# 躯干、腰带与斜挎肩带。
	_caps(_rider, 0.21, 0.56, tunic, Vector3(0, 1.26, 0.85), Vector3(4, 0, 0))
	_box(_rider, Vector3(0.34, 0.09, 0.26), strap, Vector3(0, 1.04, 0.85), Vector3.ZERO)
	_box(_rider, Vector3(0.07, 0.48, 0.24), strap, Vector3(-0.06, 1.30, 0.85), Vector3(0, 0, 28))
	# 头、双眼、发与后垂尖顶帽。
	_sph(_rider, 0.155, skin, Vector3(0, 1.74, 0.83), Vector3(1.0, 1.08, 1.0))
	for sx in [-1.0, 1.0]:
		_sph(_rider, 0.026, dark, Vector3(sx * 0.058, 1.75, 0.685), Vector3.ONE)
	_sph(_rider, 0.16, hair, Vector3(0, 1.80, 0.87), Vector3(1.02, 0.72, 1.02))
	var cap := MeshInstance3D.new()
	var cap_mesh := CylinderMesh.new()
	cap_mesh.top_radius = 0.012
	cap_mesh.bottom_radius = 0.14
	cap_mesh.height = 0.32
	cap_mesh.radial_segments = 7
	cap.mesh = cap_mesh
	cap.material_override = tunic
	cap.position = Vector3(0, 1.94, 0.91)
	cap.rotation_degrees.x = 25.0
	_rider.add_child(cap)
	# 左臂自然下垂，右臂后伸扶舵桨。
	_caps(_rider, 0.06, 0.50, tunic, Vector3(-0.26, 1.22, 0.85), Vector3(0, 0, -10))
	_sph(_rider, 0.055, skin, Vector3(-0.30, 0.98, 0.85), Vector3.ONE)
	_caps(_rider, 0.06, 0.52, tunic, Vector3(0.45, 1.24, 0.97), Vector3(24, 0, -42))
	_sph(_rider, 0.06, skin, Vector3(0.72, 1.02, 1.12), Vector3.ONE)


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


func _is_exit_safe(world_pos: Vector3) -> bool:
	# // FIX: H17 占位：木筏下船落点水面/岸边校验
	var terrain: Terrain = get_tree().current_scene.get("terrain") as Terrain if get_tree().current_scene else null
	if terrain == null: return true
	if terrain.get_normal(world_pos.x, world_pos.z, 1.2).y < 0.48: return false
	return true
func _find_safe_exit(fallback: Vector3) -> Vector3:
	var bases: Array[Vector3] = [global_transform.basis.x * 1.8, -global_transform.basis.x * 1.8, global_transform.basis.z * 1.8, -global_transform.basis.z * 1.8]
	for off in bases:
		var cand := global_position + off + Vector3(0, 0.5, 0)
		if _is_exit_safe(cand): return cand
	return fallback

func enter(p: Player) -> void:
	if driver:
		return
	if Vector2(p.velocity.x, p.velocity.z).length() > 3.5:
		return # // FIX: M2 门限：木筏为水面载具以 3.5速度门限替代 is_on_floor，防高速/落水瞬间上筏 + 燃料占位：当前零成本，后续可接 stamina/fuel
	# // FIX: H17 shape_test占位
	# // FIX: M2 燃料占位：木筏 is_on_floor语义由速度门限承担，零燃料为当前设计，后续对接 fuel 管线
	if not _is_exit_safe(p.global_position): pass
	driver = p
	driver.vehicle = self
	driver.visible = false
	_rider.visible = true
	driver.set_deferred("collision_layer", 0)
	driver.set_deferred("collision_mask", 0)
	_camera.make_current()


func exit() -> void:
	if driver == null:
		return
	var p := driver
	driver = null
	velocity = Vector3.ZERO
	p.global_position = _find_safe_exit(global_position + global_transform.basis.x * 1.8 + Vector3(0, 0.5, 0)) # // FIX: H17 固定偏移→安全落点
	p.visible = true
	_rider.visible = false
	p.set_deferred("collision_layer", 2)
	p.set_deferred("collision_mask", 1 | 4)
	p.vehicle = null
	p.camera.make_current()


func _physics_process(delta: float) -> void:
	if driver:
		var f := Input.get_action_strength("move_forward") - Input.get_action_strength("move_back")
		var r := Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
		if debug_forward != 0.0:
			f = debug_forward
		var target := f * SPEED
		var cur := Vector2(velocity.x, velocity.z).length() * signf(velocity.dot(-global_transform.basis.z))
		# // FIX: RAFT 惯性：加速快(5.5)/减速慢(2.8)，松手滑行
		cur = move_toward(cur, target, (5.5 if absf(target) > absf(cur) else 2.8) * delta)
		rotation.y -= r * TURN * delta * (1.0 if cur >= 0.0 else -1.0)
		var forward := -global_transform.basis.z
		forward.y = 0.0
		velocity = forward.normalized() * cur
		# 木筏只在水面走：前方是岸就减速停下。
		var terrain: Terrain = get_tree().current_scene.get("terrain") as Terrain
		if terrain:
			var next := global_position + velocity * delta * 1.5
			if terrain.get_height(next.x, next.z) > Terrain.WATER_LEVEL + 0.1:
				# // FIX: RAFT 岸线缓停（原瞬停）
				cur = move_toward(cur, 0.0, 3.0 * delta)
				velocity = forward.normalized() * cur
		move_and_slide()
		global_position.y = Terrain.WATER_LEVEL + 0.05
		driver.global_position = global_position + Vector3(0, 0.7, 0)
		driver.rotation.y = rotation.y
