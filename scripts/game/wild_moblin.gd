class_name WildMoblin
extends CharacterBody3D
const MOBLIN_GLB = preload("res://assets/models/moblin.glb")  # // FIX: AUD-P0-4 preload
## 莫布林：大体型慢速重击。长前摇举棒（眼睛变红）→ 猛击，是给格挡/闪避喂招的敌人。

var terrain: Terrain
var player: Player
var alive := true
var hp := 180.0
var display_name := "莫布林"
var damage_mult := 1.0
var kills := 0

var _home := Vector3.ZERO
var _wander := Vector3.ZERO
var _think := 0.0
var _windup := -1.0
var _recover := 0.0
var _anim := 0.0
var _eye_l: MeshInstance3D
var _eye_r: MeshInstance3D
var _club_arm: Node3D
var _club: MeshInstance3D
var _legs: Array[Node3D] = []
var _flash := 0.0
var _glb: Node3D
var _ap: AnimationPlayer
var _cur_anim := ""
var _anim_hold := 0.0
var _attack_cue: MeshInstance3D
var _stagger_t := 0.0
var _knockback := Vector3.ZERO
var _death_t := -1.0

const WINDUP_TIME := 0.9
const SMASH_RANGE := 2.8
const SMASH_DAMAGE := 35.0
const SIGHT := 26.0


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
	var shape := CapsuleShape3D.new()
	shape.radius = 0.75
	shape.height = 2.3
	col.shape = shape
	col.position.y = 1.1
	add_child(col)
	if not _try_glb_visual():
		_build_model()
	_attack_cue = FX.attack_ring(self, 1.45, Color(1.0, 0.24, 0.08, 0.78))


# glb 视觉：Blender 管线生成的蒙皮模型与战斗动画；缺失时回退到程序化模型。
func _try_glb_visual() -> bool:
	if not ResourceLoader.exists("res://assets/models/moblin.glb"):
		return false
	var scene_res := MOBLIN_GLB as PackedScene
	if scene_res == null:
		return false
	_glb = scene_res.instantiate()
	add_child(_glb)
	Toon.apply_to_glb(_glb) # // FIX: OPT-F1/TA1 glb 卡通化重染（描边+色带）
	_ap = _glb.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _ap != null:
		_ap.playback_default_blend_time = 0.12
	if _ap == null:
		_glb.queue_free()
		_glb = null
		return false
	_play(&"idle")
	return true


func apply_melee_impulse(direction: Vector3, strength: float, heavy: bool = false) -> void:
	if not alive:
		return
	var push := direction
	push.y = 0.0
	if push.length_squared() < 0.01:
		return
	_stagger_t = 0.58 if heavy else 0.34
	_knockback = push.normalized() * strength * (0.62 if heavy else 0.42)
	_windup = -1.0
	_recover = maxf(_recover, _stagger_t + 0.25)
	if _attack_cue:
		_attack_cue.visible = false
	_play(&"hit")
	_anim_hold = _stagger_t


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
	var skin := Toon.make_material(Color(0.62, 0.22, 0.14), true, 0.018)
	var belly := Toon.make_material(Color(0.85, 0.62, 0.35), true, 0.012)
	var dark := Toon.make_material(Color(0.10, 0.08, 0.07), true, 0.008)
	var bone := Toon.make_material(Color(0.90, 0.82, 0.60), true, 0.006)
	# 大肚圆身、小头、独角。
	_sphere(self, 0.95, skin, Vector3(0, 1.25, 0), Vector3(1.0, 1.1, 0.9))
	_sphere(self, 0.62, belly, Vector3(0, 1.15, -0.55), Vector3(0.9, 1.0, 0.55))
	_sphere(self, 0.42, skin, Vector3(0, 2.25, -0.1), Vector3(1.05, 0.9, 0.95))
	var horn := MeshInstance3D.new()
	var hm := CylinderMesh.new()
	hm.top_radius = 0.02
	hm.bottom_radius = 0.10
	hm.height = 0.55
	hm.radial_segments = 7
	horn.mesh = hm
	horn.material_override = bone
	horn.position = Vector3(0, 2.62, -0.1)
	add_child(horn)
	# 长尖耳与咧嘴獠牙：波克布林式的头部识别。
	for sx in [-1.0, 1.0]:
		var ear := MeshInstance3D.new()
		var em := CylinderMesh.new()
		em.top_radius = 0.015
		em.bottom_radius = 0.085
		em.height = 0.48
		em.radial_segments = 6
		ear.mesh = em
		ear.material_override = skin
		ear.position = Vector3(sx * 0.44, 2.30, -0.08)
		ear.rotation_degrees.z = sx * -78.0
		add_child(ear)
	var mouth := MeshInstance3D.new()
	var mm := BoxMesh.new()
	mm.size = Vector3(0.30, 0.09, 0.05)
	mouth.mesh = mm
	mouth.material_override = dark
	mouth.position = Vector3(0, 2.12, -0.50)
	add_child(mouth)
	for i in range(3):
		var tooth := MeshInstance3D.new()
		var tm := BoxMesh.new()
		tm.size = Vector3(0.05, 0.07, 0.03)
		tooth.mesh = tm
		tooth.material_override = bone
		tooth.position = Vector3(-0.08 + i * 0.08, 2.145, -0.515)
		add_child(tooth)
	var eye_mat := StandardMaterial3D.new()
	eye_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	eye_mat.albedo_color = Color(1.0, 0.85, 0.20)
	eye_mat.emission_enabled = true
	eye_mat.emission = Color(1.0, 0.75, 0.10)
	eye_mat.emission_energy_multiplier = 1.6
	_eye_l = _sphere(self, 0.07, eye_mat, Vector3(-0.16, 2.30, -0.50), Vector3.ONE) # // FIX: OPT-F9/TA17 眼睛贴出头面（原 -0.44 嵌入）
	_eye_r = _sphere(self, 0.07, eye_mat, Vector3(0.16, 2.30, -0.50), Vector3.ONE)
	# 持棒右臂：高举猛击的枢轴。
	_club_arm = Node3D.new()
	_club_arm.position = Vector3(0.85, 1.75, 0)
	add_child(_club_arm)
	var arm_mesh := MeshInstance3D.new()
	var am := CapsuleMesh.new()
	am.radius = 0.22
	am.height = 1.1
	am.radial_segments = 8
	am.rings = 4
	arm_mesh.mesh = am
	arm_mesh.material_override = skin
	arm_mesh.position = Vector3(0, -0.45, 0)
	_club_arm.add_child(arm_mesh)
	_club = MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.16
	cm.bottom_radius = 0.10
	cm.height = 1.6
	cm.radial_segments = 7
	_club.mesh = cm
	_club.material_override = dark
	_club.position = Vector3(0, -1.1, -0.15)
	_club.rotation_degrees.x = 20.0
	_club_arm.add_child(_club)
	# 左臂与两条短腿。
	var arm_l := MeshInstance3D.new()
	arm_l.mesh = am
	arm_l.material_override = skin
	arm_l.position = Vector3(-0.85, 1.30, 0)
	add_child(arm_l)
	for sx in [-0.38, 0.38]:
		var leg := Node3D.new()
		leg.position = Vector3(sx, 0.55, 0)
		add_child(leg)
		_legs.append(leg)
		var lm := MeshInstance3D.new()
		var lmm := CapsuleMesh.new()
		lmm.radius = 0.20
		lmm.height = 0.9
		lmm.radial_segments = 7
		lmm.rings = 4
		lm.mesh = lmm
		lm.material_override = skin
		lm.position.y = -0.35
		leg.add_child(lm)


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
	_flash = 0.14
	_play(&"hit")
	_anim_hold = 0.30
	DamageNumber.spawn_at(get_tree().current_scene, global_position + Vector3(0, 2.8, 0), str(int(amount)), Color(1.0, 0.85, 0.25))
	if hp > 0.0:
		return
	alive = false
	if from and from.get("kills") != null:
		from.kills += 1
	if from and from.has_method("give_rupees"):
		from.give_rupees(5)
	Loot.spawn(get_tree().current_scene, global_position + Vector3(0, 0.2, 0), "meat", "", 3, 1)
	Loot.spawn(get_tree().current_scene, global_position + Vector3(0.6, 0.2, 0.4), "wood", "", 2, 1)
	Loot.spawn(get_tree().current_scene, global_position + Vector3(-0.5, 0.2, 0.3), "monster_part", "", 2, 1)
	DamageNumber.spawn_at(get_tree().current_scene, global_position + Vector3(0, 2.8, 0), "击破!", Color(1.0, 0.55, 0.20))
	var scene := get_tree().current_scene
	if scene and scene.has_method("_on_moblin_killed"):
		scene._on_moblin_killed(from)
	_play(&"die")
	collision_layer = 0
	collision_mask = 0
	if _attack_cue:
		_attack_cue.visible = false
	_death_t = 0.0


func _physics_process(delta: float) -> void:
	if _death_t >= 0.0:
		_death_t += delta
		if _ap == null:
			rotation.z = lerpf(rotation.z, 1.48, minf(1.0, delta * 5.0))
		if _death_t > 1.25:
			queue_free()
		return
	if not alive or player == null or terrain == null:
		return
	_anim += delta
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta)
		scale = Vector3.ONE * (1.0 + _flash * 0.8)
	var to_player := player.global_position - global_position
	to_player.y = 0.0
	var dist := to_player.length()
	if _stagger_t > 0.0:
		_stagger_t = maxf(0.0, _stagger_t - delta)
		velocity.x = _knockback.x
		velocity.z = _knockback.z
		velocity.y = -4.0
		_knockback = _knockback.move_toward(Vector3.ZERO, delta * 10.0)
		move_and_slide()
		global_position.y = terrain.get_height(global_position.x, global_position.z) + 0.05
		return
	# 前摇：举棒定住、眼放红光，给玩家 0.9s 反应窗口。
	if _windup >= 0.0:
		_windup += delta
		if _attack_cue:
			_attack_cue.visible = true
			var cue_phase := clampf(_windup / WINDUP_TIME, 0.0, 1.0)
			_attack_cue.scale = Vector3.ONE * lerpf(1.30, 0.72, cue_phase) * (1.0 + sin(_anim * 18.0) * 0.05)
		if _club_arm:
			_club_arm.rotation.x = lerpf(_club_arm.rotation.x, -2.4, delta * 6.0)
		if _eye_l:
			_eye_l.scale = Vector3.ONE * (1.0 + sin(_anim * 20.0) * 0.3)
			_eye_r.scale = _eye_l.scale
		if _windup >= WINDUP_TIME:
			_smash()
			_windup = -1.0
			_recover = 1.2
	else:
		if _attack_cue:
			_attack_cue.visible = false
		if _club_arm:
			_club_arm.rotation.x = lerpf(_club_arm.rotation.x, 0.2, delta * 4.0)
		if _eye_l:
			_eye_l.scale = Vector3.ONE
			_eye_r.scale = Vector3.ONE
		_recover = maxf(0.0, _recover - delta)
		if dist < SIGHT and player.alive:
			if dist < SMASH_RANGE * 0.75 and _recover <= 0.0:
				_windup = 0.0
				_play(&"windup")
				var sfx := get_tree().get_first_node_in_group("sfx_bank")
				if sfx:
					sfx.play_at("enemy_charge", global_position + Vector3(0, 1.5, 0), -7.0, 0.82)
			else:
				var dir := to_player.normalized()
				velocity.x = dir.x * 3.4
				velocity.z = dir.z * 3.4
				rotation.y = lerp_angle(rotation.y, atan2(dir.x, dir.z) + PI, delta * 4.0)
		else:
			_think -= delta
			if _think <= 0.0:
				_think = randf_range(2.0, 4.0)
				_wander = _home + Vector3(randf_range(-8, 8), 0, randf_range(-8, 8))
			var dir2 := _wander - global_position
			dir2.y = 0.0
			if dir2.length() > 1.2:
				dir2 = dir2.normalized()
				velocity.x = dir2.x * 2.0
				velocity.z = dir2.z * 2.0
				rotation.y = lerp_angle(rotation.y, atan2(dir2.x, dir2.z) + PI, delta * 3.0)
			else:
				velocity.x = 0.0
				velocity.z = 0.0
	if _windup >= 0.0:
		velocity.x = 0.0
		velocity.z = 0.0
	velocity.y = -4.0
	move_and_slide()
	global_position.y = terrain.get_height(global_position.x, global_position.z) + 0.05
	var stride := clampf(Vector2(velocity.x, velocity.z).length() / 3.4, 0.0, 1.0) * 0.4
	for i in range(_legs.size()):
		_legs[i].rotation.x = sin(_anim * 5.5 + i * PI) * stride
	_anim_hold = maxf(0.0, _anim_hold - delta)
	if _ap and _anim_hold <= 0.0:
		if _windup >= 0.0:
			pass
		elif Vector2(velocity.x, velocity.z).length() > 0.3:
			_play(&"walk")
		else:
			_play(&"idle")


func _smash() -> void:
	if _club_arm:
		_club_arm.rotation.x = 0.8
	_play(&"smash")
	_anim_hold = 0.45
	if _attack_cue:
		_attack_cue.visible = false
	# 猛击：范围内伤害+击退，可被格挡/闪避反制。
	if player.global_position.distance_to(global_position) < SMASH_RANGE and player.alive:
		player.take_damage(SMASH_DAMAGE, self)
		if player.alive:
			var push := (player.global_position - global_position)
			push.y = 0.0
			player.velocity += push.normalized() * 6.0 + Vector3(0, 3.0, 0)
	FX.impact(global_position + Vector3(0, 0.2, 0) + -global_transform.basis.z * 1.8)
	var sfx := get_tree().get_first_node_in_group("sfx_bank")
	if sfx:
		sfx.play_at("heavy_impact", global_position, -3.0, 0.78)