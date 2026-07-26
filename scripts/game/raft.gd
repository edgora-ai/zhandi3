class_name Raft
extends CharacterBody3D
## 木筏：河边按 F 乘上，W/S 前后、A/D 转向，浮在水面代步过河。

const SPEED := 6.5
const TURN := 1.4

var driver: Player = null
var ride_label := "乘木筏"
var debug_forward := 0.0

var _camera: Camera3D


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
	velocity = Vector3.ZERO
	p.global_position = global_position + global_transform.basis.x * 1.8 + Vector3(0, 0.5, 0)
	p.visible = true
	p.set_deferred("collision_layer", 2)
	p.set_deferred("collision_mask", 1 | 4)
	p.vehicle = null
	p.camera.make_current()


func _physics_process(delta: float) -> void:
	if driver:
		var f := float(Input.is_key_pressed(KEY_W)) - float(Input.is_key_pressed(KEY_S))
		var r := float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A))
		if debug_forward != 0.0:
			f = debug_forward
		var target := f * SPEED
		var cur := Vector2(velocity.x, velocity.z).length() * signf(velocity.dot(-global_transform.basis.z))
		cur = move_toward(cur, target, 4.0 * delta)
		rotation.y -= r * TURN * delta * (1.0 if cur >= 0.0 else -1.0)
		var forward := -global_transform.basis.z
		forward.y = 0.0
		velocity = forward.normalized() * cur
		# 木筏只在水面走：前方是岸就减速停下。
		var terrain: Terrain = get_tree().current_scene.get("terrain") as Terrain
		if terrain:
			var next := global_position + velocity * delta * 1.5
			if terrain.get_height(next.x, next.z) > Terrain.WATER_LEVEL + 0.1:
				velocity = Vector3.ZERO
		move_and_slide()
		global_position.y = Terrain.WATER_LEVEL + 0.05
		driver.global_position = global_position + Vector3(0, 0.7, 0)
		driver.rotation.y = rotation.y
