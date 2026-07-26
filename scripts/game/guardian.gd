class_name Guardian
extends CharacterBody3D
## 古代守卫：六足步行巡逻，锁定玩家后红色激光追踪 2.2 秒并发射毁灭光束。

var terrain: Terrain
var player: Player
var alive := true
var hp := 150.0
var display_name := "古代守卫"
var damage_mult := 1.0
var kills := 0

var _home := Vector3.ZERO
var _wander := Vector3.ZERO
var _think := 0.0
var _charge := -1.0
var _cooldown := 0.0
var _anim := 0.0
var _eye: MeshInstance3D
var _eye_mat: StandardMaterial3D
var _laser: MeshInstance3D
var _legs: Array[Node3D] = []

const SIGHT := 40.0
const CHARGE_TIME := 2.2
const BEAM_DAMAGE := 30.0


func setup(p_terrain: Terrain, p_player: Player) -> void:
	terrain = p_terrain
	player = p_player


func _ready() -> void:
	add_to_group("wild_enemy")
	collision_layer = 4
	collision_mask = 1
	_home = global_position
	_wander = _home
	var col := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 1.0
	col.shape = shape
	col.position.y = 1.0
	add_child(col)
	_build_model()


func _build_model() -> void:
	var shell := Toon.make_material(Color(0.62, 0.65, 0.68), true, 0.018)
	var dark := Toon.make_material(Color(0.10, 0.11, 0.13), true, 0.010)
	_sphere(self, 1.0, shell, Vector3(0, 1.05, 0), Vector3(1.15, 0.75, 1.15))
	_sphere(self, 0.55, dark, Vector3(0, 0.85, -0.62), Vector3(1.0, 0.8, 0.9))
	_eye_mat = StandardMaterial3D.new()
	_eye_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_eye_mat.albedo_color = Color(0.10, 0.90, 0.85)
	_eye_mat.emission_enabled = true
	_eye_mat.emission = Color(0.05, 0.95, 0.85)
	_eye_mat.emission_energy_multiplier = 2.4
	_eye = MeshInstance3D.new()
	var eye_mesh := SphereMesh.new()
	eye_mesh.radius = 0.26
	eye_mesh.height = 0.52
	eye_mesh.radial_segments = 12
	eye_mesh.rings = 7
	_eye.mesh = eye_mesh
	_eye.material_override = _eye_mat
	_eye.position = Vector3(0, 0.95, -0.85)
	add_child(_eye)
	# 六条腿三段式。
	for i in range(6):
		var a := float(i) * TAU / 6.0
		var leg := Node3D.new()
		leg.position = Vector3(cos(a) * 0.8, 0.9, sin(a) * 0.8)
		add_child(leg)
		_legs.append(leg)
		var upper := MeshInstance3D.new()
		var um := CylinderMesh.new()
		um.top_radius = 0.09
		um.bottom_radius = 0.07
		um.height = 1.0
		um.radial_segments = 6
		upper.mesh = um
		upper.material_override = dark
		upper.position = Vector3(cos(a) * 0.35, -0.25, sin(a) * 0.35)
		upper.rotation_degrees = Vector3(sin(a) * 38.0, 0, -cos(a) * 38.0)
		leg.add_child(upper)
		var lower := MeshInstance3D.new()
		var lm := CylinderMesh.new()
		lm.top_radius = 0.06
		lm.bottom_radius = 0.015
		lm.height = 0.95
		lm.radial_segments = 6
		lower.mesh = lm
		lower.material_override = shell
		lower.position = Vector3(cos(a) * 0.62, -0.85, sin(a) * 0.62)
		lower.rotation_degrees = Vector3(-sin(a) * 18.0, 0, cos(a) * 18.0)
		leg.add_child(lower)
	# 激光束（瞄准时显示的红色细束）。
	_laser = MeshInstance3D.new()
	var laser_mesh := CylinderMesh.new()
	laser_mesh.top_radius = 0.015
	laser_mesh.bottom_radius = 0.015
	laser_mesh.height = 1.0
	laser_mesh.radial_segments = 5
	_laser.mesh = laser_mesh
	var laser_mat := StandardMaterial3D.new()
	laser_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	laser_mat.albedo_color = Color(1.0, 0.12, 0.10, 0.85)
	laser_mat.emission_enabled = true
	laser_mat.emission = Color(1.0, 0.08, 0.06)
	laser_mat.emission_energy_multiplier = 2.5
	laser_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_laser.material_override = laser_mat
	_laser.visible = false
	add_child(_laser)
	# 顶部小圆帽：守卫穹顶的收束件。
	var cap := MeshInstance3D.new()
	var cap_mesh := CylinderMesh.new()
	cap_mesh.top_radius = 0.10
	cap_mesh.bottom_radius = 0.20
	cap_mesh.height = 0.14
	cap_mesh.radial_segments = 10
	cap.mesh = cap_mesh
	cap.material_override = dark
	cap.position = Vector3(0, 1.84, 0)
	add_child(cap)


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


func take_damage(amount: float, from: Variant = null, _part_name: String = "body") -> void:
	if not alive:
		return
	hp -= amount
	DamageNumber.spawn_at(get_tree().current_scene, global_position + Vector3(0, 2.0, 0), str(int(amount)), Color(1.0, 0.85, 0.25))
	if hp <= 0.0:
		alive = false
		if from and from.get("kills") != null:
			from.kills += 1
		Loot.spawn(get_tree().current_scene, global_position, "armor", "", 50, 2)
		Loot.spawn(get_tree().current_scene, global_position + Vector3(0.8, 0, 0.5), "ammo", "", 90, 2)
		DamageNumber.spawn_at(get_tree().current_scene, global_position + Vector3(0, 2.2, 0), "击破!", Color(1.0, 0.55, 0.20))
		queue_free()


func _physics_process(delta: float) -> void:
	if not alive or player == null or terrain == null:
		return
	_cooldown = maxf(0.0, _cooldown - delta)
	_anim += delta
	var to_player := player.global_position - global_position
	to_player.y = 0.0
	var dist := to_player.length()
	# 瞄准与充能：激光追踪，充能满即发射。
	if _charge >= 0.0:
		_charge += delta
		_aim_laser()
		if _charge >= CHARGE_TIME:
			_fire_beam()
		_charge = -1.0
		_cooldown = 4.0
		_laser.visible = false
		_eye_mat.emission = Color(0.05, 0.95, 0.85)
		_eye_mat.albedo_color = Color(0.10, 0.90, 0.85)
	elif dist < SIGHT and _cooldown <= 0.0 and player.alive:
		_charge = 0.0
		_laser.visible = true
		_eye_mat.emission = Color(1.0, 0.10, 0.08)
		_eye_mat.albedo_color = Color(1.0, 0.15, 0.12)
	# 巡逻：充能时定住。
	if _charge < 0.0:
		_think -= delta
		if _think <= 0.0:
			_think = randf_range(2.5, 4.5)
			_wander = _home + Vector3(randf_range(-10, 10), 0, randf_range(-10, 10))
		var dir := _wander - global_position
		dir.y = 0.0
		if dir.length() > 1.2:
			dir = dir.normalized()
			velocity.x = dir.x * 1.6
			velocity.z = dir.z * 1.6
			rotation.y = lerp_angle(rotation.y, atan2(dir.x, dir.z) + PI, delta * 3.0)
		else:
			velocity.x = 0.0
			velocity.z = 0.0
	else:
		velocity.x = 0.0
		velocity.z = 0.0
		rotation.y = lerp_angle(rotation.y, atan2(to_player.x, to_player.z) + PI, delta * 2.5)
	velocity.y = -4.0
	move_and_slide()
	global_position.y = terrain.get_height(global_position.x, global_position.z) + 0.05
	var stride := clampf(Vector2(velocity.x, velocity.z).length() / 2.0, 0.0, 1.0) * 0.3
	for i in range(_legs.size()):
		_legs[i].rotation.x = sin(_anim * 6.0 + float(i) * PI * 0.67) * stride


func _aim_laser() -> void:
	var from := global_position + Vector3(0, 0.95, 0)
	var to := player.global_position + Vector3(0, 1.0, 0)
	var dir := to - from
	var length := dir.length()
	_laser.position = to_local(from) + dir * 0.5
	var q := Quaternion(Vector3.UP, dir.normalized())
	_laser.quaternion = q
	_laser.scale = Vector3(1.0, length, 1.0)


func _fire_beam() -> void:
	var from := global_position + Vector3(0, 0.95, 0)
	var to := player.global_position + Vector3(0, 1.0, 0)
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from, to, 1 | 2)
	var result := space.intersect_ray(query)
	FX.tracer(from, to)
	if not result.is_empty() and result.collider == player:
		player.take_damage(BEAM_DAMAGE, self)
