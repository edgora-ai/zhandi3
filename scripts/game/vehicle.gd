class_name Vehicle
extends CharacterBody3D
## 吉普车：F 上/下车，W/S 油门倒车，A/D 转向，贴地形行驶

const TOP_SPEED := 13.0
const REVERSE_SPEED := 5.0
const ACCEL := 14.0
const TURN := 1.5

var terrain: Terrain
var driver: Player = null
var speed := 0.0

var _cam: Camera3D


func _ready() -> void:
	add_to_group("vehicle")
	collision_layer = 1
	collision_mask = 1
	var body_col := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(1.9, 1.3, 4.1)
	body_col.shape = bs
	body_col.position.y = 0.85
	add_child(body_col)

	var green := Toon.make_material(Color(0.32, 0.38, 0.24), true, 0.02)
	var dark := Toon.make_material(Color(0.16, 0.16, 0.16), true, 0.01)
	var glass := Toon.make_material(Color(0.45, 0.60, 0.68), false)
	# 车壳
	_bp(Vector3(1.9, 0.55, 4.2), green, Vector3(0, 0.72, 0))
	_bp(Vector3(1.7, 0.5, 2.1), green, Vector3(0, 1.22, 0.35))
	_bp(Vector3(1.72, 0.28, 1.2), glass, Vector3(0, 1.28, -0.30))  # 前挡风
	_bp(Vector3(1.5, 0.08, 2.2), dark, Vector3(0, 1.52, 0.35))     # 车顶
	_bp(Vector3(2.0, 0.18, 0.3), dark, Vector3(0, 0.50, -2.05))    # 前杠
	_bp(Vector3(0.5, 0.3, 0.4), dark, Vector3(0, 0.95, 2.05))      # 备胎
	# 车轮
	for wx in [-0.85, 0.85]:
		for wz in [-1.45, 1.45]:
			var wheel := MeshInstance3D.new()
			var wm := CylinderMesh.new()
			wm.top_radius = 0.42
			wm.bottom_radius = 0.42
			wm.height = 0.3
			wm.radial_segments = 10
			wheel.mesh = wm
			wheel.material_override = dark
			wheel.rotation_degrees.z = 90.0
			wheel.position = Vector3(wx, 0.42, wz)
			add_child(wheel)

	_cam = Camera3D.new()
	_cam.position = Vector3(0, 3.4, 8.2)
	_cam.rotation_degrees.x = -16.0
	_cam.far = 1500.0
	add_child(_cam)


func _bp(size: Vector3, mat: Material, pos: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = mat
	mi.position = pos
	add_child(mi)


func enter(p: Player) -> void:
	driver = p
	driver.vehicle = self
	driver.visible = false
	driver.set_deferred("collision_layer", 0)
	driver.set_deferred("collision_mask", 0)
	_cam.make_current()


func exit() -> void:
	var p := driver
	driver = null
	speed = 0.0
	var side := global_transform.basis.x * 1.8
	p.global_position = global_position + side + Vector3(0, 0.6, 0)
	p.visible = true
	p.set_deferred("collision_layer", 2)
	p.set_deferred("collision_mask", 1 | 4)
	p.vehicle = null
	p.camera.make_current()


func _physics_process(delta: float) -> void:
	if driver:
		var f := float(Input.is_key_pressed(KEY_W)) - float(Input.is_key_pressed(KEY_S))
		var r := float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A))
		var target := f * (TOP_SPEED if f > 0.0 else REVERSE_SPEED)
		speed = move_toward(speed, target, ACCEL * delta)
		if absf(speed) > 0.5:
			rotation.y -= r * TURN * delta * signf(speed)
		velocity = -global_transform.basis.z * speed
		# 贴地形：高度直接吸附，保留水平碰撞滑动
		var th := terrain.get_height(global_position.x, global_position.z) + 0.45
		global_position.y = lerpf(global_position.y, th, delta * 10.0)
		velocity.y = 0.0
		driver.global_position = global_position + Vector3(0, 1.0, 0)
		driver.rotation.y = rotation.y
		move_and_slide()
	elif not is_on_floor():
		velocity.y -= 22.0 * delta
		move_and_slide()
