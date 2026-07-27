class_name WildLizalfos
extends CharacterBody3D
## 蜥蜴战士：环绕游走的高速敌人，冷不丁突进扑咬，中距吐舌。

var terrain: Terrain
var player: Player
var alive := true
var hp := 70.0
var display_name := "蜥蜴战士"
var damage_mult := 1.0
var kills := 0

var _home := Vector3.ZERO
var _think := 0.0
var _dash_cd := 0.0
var _dash_t := 0.0
var _glb: Node3D
var _ap: AnimationPlayer
var _cur_anim := ""
var _anim_hold := 0.0
var _strafe_dir := 1.0
var _anim := 0.0
var _legs: Array[Node3D] = []
var _tail: MeshInstance3D
var _flash := 0.0

const SIGHT := 30.0
const DASH_CD := 3.2
const DASH_TIME := 0.38


func setup(p_terrain: Terrain, p_player: Player) -> void:
	terrain = p_terrain
	player = p_player


func _ready() -> void:
	add_to_group("wild_enemy")
	collision_layer = 4
	collision_mask = 1
	_home = global_position
	var col := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.42
	shape.height = 1.5
	col.shape = shape
	col.position.y = 0.7
	add_child(col)
	if not _try_glb_visual():
		_build_model()


# glb 视觉：Blender 管线生成的蒙皮蜥蜴与动画；缺失时回退到程序化模型。
func _try_glb_visual() -> bool:
	if not ResourceLoader.exists("res://assets/models/lizalfos.glb"):
		return false
	var scene_res := load("res://assets/models/lizalfos.glb") as PackedScene
	if scene_res == null:
		return false
	_glb = scene_res.instantiate()
	add_child(_glb)
	_ap = _glb.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _ap == null:
		_glb.queue_free()
		_glb = null
		return false
	_play(&"idle")
	return true


func _play(clip: StringName) -> void:
	if _ap == null or _cur_anim == clip:
		return
	if _ap.has_animation(clip):
		# glTF 导入的动画默认不循环（loop_mode=0），持续状态剪辑手动开循环。
		var anim_res := _ap.get_animation(clip)
		if anim_res and anim_res.loop_mode == Animation.LOOP_NONE and not (clip in [&"windup", &"smash", &"hit", &"die", &"buck", &"dash", &"attack"]):
			anim_res.loop_mode = Animation.LOOP_LINEAR
		_cur_anim = clip
		_ap.play(clip)


func _build_model() -> void:
	var skin := Toon.make_material(Color(0.35, 0.62, 0.30), true, 0.016)
	var belly := Toon.make_material(Color(0.82, 0.78, 0.50), true, 0.010)
	var dark := Toon.make_material(Color(0.10, 0.12, 0.08), true, 0.008)
	# 前伏的长身体、背鳍、长尾。
	_sphere(self, 0.48, skin, Vector3(0, 0.72, 0.1), Vector3(0.9, 0.75, 1.5))
	_sphere(self, 0.34, belly, Vector3(0, 0.62, -0.35), Vector3(0.8, 0.65, 1.1))
	_sphere(self, 0.30, skin, Vector3(0, 0.92, -0.72), Vector3(0.9, 0.8, 1.15))
	_sphere(self, 0.10, dark, Vector3(0, 0.86, -1.02), Vector3(1.2, 0.6, 0.9))
	for sx in [-1.0, 1.0]:
		_sphere(self, 0.045, dark, Vector3(sx * 0.14, 0.98, -0.90), Vector3.ONE)
	for i in range(4):
		var fin := MeshInstance3D.new()
		var fm := BoxMesh.new()
		fm.size = Vector3(0.06, 0.30 - i * 0.04, 0.14)
		fin.mesh = fm
		fin.material_override = dark
		fin.position = Vector3(0, 1.06 - i * 0.06, -0.25 + i * 0.28)
		fin.rotation_degrees.x = -18.0
		add_child(fin)
	_tail = _capsule_part(self, 0.12, 1.3, skin, Vector3(0, 0.62, 1.05))
	_tail.rotation_degrees.x = 70.0
	# 后掠双角、前肢与爪：蜥蜴战士的剪影与抓握感。
	for sx in [-1.0, 1.0]:
		var horn := MeshInstance3D.new()
		var hm := CylinderMesh.new()
		hm.top_radius = 0.012
		hm.bottom_radius = 0.05
		hm.height = 0.42
		hm.radial_segments = 6
		horn.mesh = hm
		horn.material_override = belly
		horn.position = Vector3(sx * 0.12, 1.10, -0.60)
		horn.rotation_degrees = Vector3(-62.0, 0.0, sx * -14.0)
		add_child(horn)
		var arm := MeshInstance3D.new()
		var am := CapsuleMesh.new()
		am.radius = 0.065
		am.height = 0.52
		am.radial_segments = 7
		am.rings = 4
		arm.mesh = am
		arm.material_override = skin
		arm.position = Vector3(sx * 0.40, 0.66, -0.18)
		arm.rotation_degrees = Vector3(24.0, 0.0, sx * 10.0)
		add_child(arm)
		var claw := MeshInstance3D.new()
		var cm2 := BoxMesh.new()
		cm2.size = Vector3(0.10, 0.06, 0.14)
		claw.mesh = cm2
		claw.material_override = dark
		claw.position = Vector3(sx * 0.43, 0.40, -0.26)
		add_child(claw)
	for sx in [-0.28, 0.28]:
		var leg := Node3D.new()
		leg.position = Vector3(sx, 0.45, 0.15)
		add_child(leg)
		_legs.append(leg)
		_capsule_part(leg, 0.10, 0.6, skin, Vector3(0, -0.25, 0))


func _sphere(parent: Node3D, radius: float, mat: Material, pos: Vector3, shape_scale: Vector3) -> MeshInstance3D:
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


func _capsule_part(parent: Node3D, radius: float, height: float, mat: Material, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	mesh.radial_segments = 8
	mesh.rings = 4
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi


func take_damage(amount: float, from: Variant = null, _part_name: String = "body") -> void:
	if not alive:
		return
	hp -= amount
	_flash = 0.14
	_play(&"hit")
	_anim_hold = 0.30
	DamageNumber.spawn_at(get_tree().current_scene, global_position + Vector3(0, 1.8, 0), str(int(amount)), Color(1.0, 0.85, 0.25))
	if hp <= 0.0:
		alive = false
	if from and from.get("kills") != null:
		from.kills += 1
	if from and from.has_method("give_rupees"):
		from.give_rupees(4)
		Loot.spawn(get_tree().current_scene, global_position + Vector3(0, 0.2, 0), "meat", "", 2, 1)
		Loot.spawn(get_tree().current_scene, global_position + Vector3(0.5, 0.2, 0.3), "monster_part", "", 2, 1)
		DamageNumber.spawn_at(get_tree().current_scene, global_position + Vector3(0, 1.8, 0), "击破!", Color(1.0, 0.55, 0.20))
		if _ap:
			_play(&"die")
			collision_layer = 0
			collision_mask = 0
			await get_tree().create_timer(0.8).timeout
		queue_free()


func _physics_process(delta: float) -> void:
	if not alive or player == null or terrain == null:
		return
	_anim += delta
	_dash_cd = maxf(0.0, _dash_cd - delta)
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta)
		scale = Vector3.ONE * (1.0 + _flash * 1.2)
	var to_player := player.global_position - global_position
	to_player.y = 0.0
	var dist := to_player.length()
	var dir := to_player.normalized()
	if dist > SIGHT or not player.alive:
		velocity.x = 0.0
		velocity.z = 0.0
	elif _dash_t > 0.0:
		# 突进中：高速前扑。
		_dash_t -= delta
		velocity.x = dir.x * 11.0
		velocity.z = dir.z * 11.0
		if dist < 1.3:
			player.take_damage(16.0, self)
			_dash_t = 0.0
	else:
		# 环绕游走，冷却好了就突进。
		var tangent := dir.cross(Vector3.UP).normalized() * _strafe_dir
		_think -= delta
		if _think <= 0.0:
			_think = randf_range(1.0, 2.2)
			if randf() < 0.3:
				_strafe_dir = -_strafe_dir
		var want := tangent * 5.5
		if dist > 12.0:
			want = dir * 7.5
		elif dist < 6.0:
			want = tangent * 5.5 - dir * 2.0
		velocity.x = want.x
		velocity.z = want.z
		rotation.y = lerp_angle(rotation.y, atan2(dir.x, dir.z) + PI, delta * 8.0)
		if _dash_cd <= 0.0 and dist < 9.0:
			_dash_t = DASH_TIME
			_dash_cd = DASH_CD
			_play(&"dash")
	velocity.y = -4.0
	move_and_slide()
	global_position.y = terrain.get_height(global_position.x, global_position.z) + 0.05
	var stride := clampf(Vector2(velocity.x, velocity.z).length() / 8.0, 0.0, 1.0) * 0.7
	for i in range(_legs.size()):
		_legs[i].rotation.x = sin(_anim * 11.0 + i * PI) * stride
	if _tail:
		_tail.rotation.y = sin(_anim * 4.0) * 0.4
	_anim_hold = maxf(0.0, _anim_hold - delta)
	if _ap and _anim_hold <= 0.0:
		if _dash_t > 0.0:
			pass
		elif Vector2(velocity.x, velocity.z).length() > 0.3:
			_play(&"strafe")
		else:
			_play(&"idle")
