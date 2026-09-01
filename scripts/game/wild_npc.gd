class_name WildNPC
extends CharacterBody3D
const VILLAGER_GLB = preload("res://assets/models/villager.glb")  # // FIX: AUD-P0-4 preload
## 友好的旅人 NPC：在地标附近停留或小范围游走，靠近时可按 E 交谈。

var terrain: Terrain
var player: Player
var npc_name := "旅人"
var lines: Array[String] = []
var quest_id := ""
var coat := Color(0.45, 0.32, 0.55)
var hat_style := 0   # 0 草帽 / 1 尖帽 / 2 头巾

var _line_index := 0
var _home := Vector3.ZERO
var _target := Vector3.ZERO
var _think := 0.0
var _anim := 0.0
var _talk_cd := 0.0
var _visual: Node3D
var _arm_l: Node3D
var _arm_r: Node3D
var _elbow_l: Node3D
var _elbow_r: Node3D
var _leg_l: Node3D
var _leg_r: Node3D
var _head: Node3D
var patrol: Array[Vector3] = []
var _patrol_i := 0
var _cower_t := 0.0
var _sleep_t := 0.0
var _gesture_t := 0.0
var _glb: Node3D
var _ap: AnimationPlayer
var _cur_anim := ""


func setup(p_terrain: Terrain, p_player: Player, p_name: String, p_lines: Array[String], p_coat: Color, p_hat: int) -> void:
	terrain = p_terrain
	player = p_player
	npc_name = p_name
	lines = p_lines
	coat = p_coat
	hat_style = p_hat


func _ready() -> void:
	add_to_group("npc")
	collision_layer = 4
	collision_mask = 1
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.34
	cap.height = 1.65
	col.shape = cap
	col.position.y = 0.85
	add_child(col)
	_home = global_position
	_target = _home
	if not _try_glb_visual():
		_build_model()


# glb 视觉：Blender 管线生成的蒙皮村民与动画；缺失时回退到程序化模型。
func _try_glb_visual() -> bool:
	if not ResourceLoader.exists("res://assets/models/villager.glb"):
		return false
	var scene_res := VILLAGER_GLB as PackedScene
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
	# 帽子三选一：0 草帽 / 1 尖帽 / 2 头巾。
	var hat_names := ["hat_straw", "hat_point", "hat_bandana"]
	for i in range(hat_names.size()):
		var hat_node := _glb.find_child(hat_names[i], true, false)
		if hat_node:
			hat_node.visible = (i == hat_style)
	# 上衣按 NPC 配色上色（Blender 材质名 villager_tunic 的面）。
	for mi in _glb.find_children("*", "MeshInstance3D", true, false):
		var mesh_inst := mi as MeshInstance3D
		if mesh_inst == null or mesh_inst.mesh == null:
			continue
		for s in range(mesh_inst.mesh.get_surface_count()):
			var mat_res := mesh_inst.mesh.surface_get_material(s)
			if mat_res and mat_res.resource_name == "villager_tunic":
				mesh_inst.set_surface_override_material(s, Toon.make_material(coat, true, 0.014))
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
	_visual = Node3D.new()
	add_child(_visual)
	var coat_mat := Toon.make_material(coat, true, 0.014)
	var coat_dark := Toon.make_material(coat.darkened(0.25), true, 0.010)
	var skin := Toon.make_material(Color(0.92, 0.72, 0.55), true, 0.010)
	var dark := Toon.make_material(Color(0.16, 0.12, 0.10), true, 0.008)
	var straw := Toon.make_material(Color(0.85, 0.70, 0.35), true, 0.010)
	var pants := Toon.make_material(Color(0.42, 0.33, 0.24), true, 0.010)
	var boots := Toon.make_material(Color(0.24, 0.17, 0.11), true, 0.008)
	var belt_mat := Toon.make_material(Color(0.30, 0.20, 0.12), true, 0.008)
	var white := Toon.make_material(Color(0.96, 0.96, 0.94), false)
	var mouth_mat := Toon.make_material(Color(0.50, 0.22, 0.18), false)
	var blush_mat := Toon.make_material(Color(0.95, 0.55, 0.50), false)
	# 发色按帽子款式区分，让村民外观有辨识度。
	var hair_cols := [Color(0.35, 0.22, 0.12), Color(0.55, 0.42, 0.28), Color(0.20, 0.15, 0.12)]
	var hair := Toon.make_material(hair_cols[hat_style % hair_cols.size()], true, 0.008)

	# 腿与靴：长袍下露出小腿和脚，行走时左右摆动。
	_leg_l = _make_leg(Vector3(-0.13, 0.62, 0), pants, boots)
	_leg_r = _make_leg(Vector3(0.13, 0.62, 0), pants, boots)

	# 长袍：上身筒身 + 外扩裙摆 + 腰带扣 + 立领。
	_capsule(_visual, 0.30, 0.78, coat_mat, Vector3(0, 1.28, 0))
	_cone(_visual, 0.28, 0.46, 0.62, coat_mat, Vector3(0, 0.66, 0))
	_cylinder(_visual, 0.325, 0.10, belt_mat, Vector3(0, 0.98, 0))
	var buckle := MeshInstance3D.new()
	var buckle_mesh := BoxMesh.new()
	buckle_mesh.size = Vector3(0.09, 0.07, 0.03)
	buckle.mesh = buckle_mesh
	buckle.material_override = Toon.make_material(Color(0.80, 0.62, 0.25), false)
	buckle.position = Vector3(0, 0.98, -0.315)
	_visual.add_child(buckle)
	_cylinder(_visual, 0.24, 0.10, coat_dark, Vector3(0, 1.62, 0))
	# 肩挎包。
	_sphere(_visual, 0.16, dark, Vector3(0.30, 0.95, 0.22), Vector3(0.8, 1.0, 0.6))

	# 头部独立枢轴：脸、头发、帽子都挂在 _head 上，能转头看人。
	_head = Node3D.new()
	_head.position = Vector3(0, 1.70, 0)
	_visual.add_child(_head)
	_sphere(_head, 0.23, skin, Vector3(0, 0.10, 0), Vector3(1.0, 1.05, 1.0))
	# 后发与两鬓：帽子下露出发量，避免“秃头套帽”。
	_sphere(_head, 0.21, hair, Vector3(0, 0.14, 0.09), Vector3(0.92, 0.85, 0.75))
	_sphere(_head, 0.09, hair, Vector3(-0.19, 0.04, 0.05), Vector3(0.6, 1.1, 0.7))
	_sphere(_head, 0.09, hair, Vector3(0.19, 0.04, 0.05), Vector3(0.6, 1.1, 0.7))
	# 耳朵。
	_sphere(_head, 0.045, skin, Vector3(-0.225, 0.08, 0.0), Vector3(0.5, 0.9, 0.7))
	_sphere(_head, 0.045, skin, Vector3(0.225, 0.08, 0.0), Vector3(0.5, 0.9, 0.7))
	# 鼻子用肤色小凸点（深色大鼻会读成动物吻部）。
	_sphere(_head, 0.045, Toon.make_material(Color(0.88, 0.64, 0.48), false), Vector3(0, 0.05, -0.225), Vector3(0.8, 0.9, 0.7))
	# 眼白 + 瞳孔 + 高光点：大比例眼睛加高光是卡通角色“有脸”的关键。
	for sx in [-1.0, 1.0]:
		_sphere(_head, 0.052, white, Vector3(sx * 0.088, 0.12, -0.185), Vector3(1.0, 1.35, 0.55))
		_sphere(_head, 0.027, dark, Vector3(sx * 0.088, 0.115, -0.213), Vector3(1.0, 1.35, 0.45))
		_sphere(_head, 0.011, white, Vector3(sx * 0.078, 0.15, -0.224), Vector3.ONE)
		var brow_mi := MeshInstance3D.new()
		var brow_mesh := BoxMesh.new()
		brow_mesh.size = Vector3(0.075, 0.018, 0.02)
		brow_mi.mesh = brow_mesh
		brow_mi.material_override = dark
		brow_mi.position = Vector3(sx * 0.088, 0.215, -0.19)
		brow_mi.rotation_degrees.z = sx * -8.0
		_head.add_child(brow_mi)
	# 微笑嘴与腮红。
	_sphere(_head, 0.035, mouth_mat, Vector3(0, -0.02, -0.212), Vector3(1.4, 0.4, 0.3))
	_sphere(_head, 0.038, blush_mat, Vector3(-0.15, 0.045, -0.172), Vector3(1.0, 0.65, 0.35))
	_sphere(_head, 0.038, blush_mat, Vector3(0.15, 0.045, -0.172), Vector3(1.0, 0.65, 0.35))
	match hat_style:
		0:  # 草帽
			_cylinder(_head, 0.38, 0.06, straw, Vector3(0, 0.30, 0))
			_cylinder(_head, 0.16, 0.14, straw, Vector3(0, 0.38, 0))
		1:  # 尖顶帽
			_cone(_head, 0.02, 0.30, 0.55, coat_mat, Vector3(0, 0.52, 0))
		2:  # 头巾 + 马尾
			_sphere(_head, 0.25, Toon.make_material(coat.darkened(0.15), true, 0.010), Vector3(0, 0.18, 0), Vector3(1.05, 0.7, 1.05))
			_sphere(_head, 0.08, hair, Vector3(0, 0.02, 0.24), Vector3(0.7, 1.5, 0.7))
	# 手臂：肩/肘两级枢轴带手掌，自然下垂时肘部微弯。
	var arm_l := _make_arm(Vector3(-0.34, 1.48, 0), coat_mat, skin)
	_arm_l = arm_l[0]
	_elbow_l = arm_l[1]
	var arm_r := _make_arm(Vector3(0.34, 1.48, 0), coat_mat, skin)
	_arm_r = arm_r[0]
	_elbow_r = arm_r[1]
	_elbow_l.rotation.x = -0.30
	_elbow_r.rotation.x = -0.30


# 手臂 = 肩枢轴（上臂）+ 肘枢轴（前臂+手掌），返回 [肩, 肘]。
func _make_arm(pivot: Vector3, coat_mat: Material, skin: Material) -> Array:
	var shoulder := Node3D.new()
	shoulder.position = pivot
	_visual.add_child(shoulder)
	_sphere(shoulder, 0.10, coat_mat, Vector3.ZERO, Vector3(1.1, 0.8, 1.1))
	_capsule(shoulder, 0.072, 0.30, coat_mat, Vector3(0, -0.15, 0))
	var elbow := Node3D.new()
	elbow.position = Vector3(0, -0.30, 0)
	shoulder.add_child(elbow)
	_capsule(elbow, 0.062, 0.28, coat_mat, Vector3(0, -0.13, 0))
	_sphere(elbow, 0.075, skin, Vector3(0, -0.29, 0))
	return [shoulder, elbow]


# 腿 = 髋枢轴（小腿+靴），返回髋枢轴。
func _make_leg(pivot: Vector3, pants: Material, boots: Material) -> Node3D:
	var hip := Node3D.new()
	hip.position = pivot
	_visual.add_child(hip)
	_capsule(hip, 0.085, 0.46, pants, Vector3(0, -0.26, 0))
	var boot := MeshInstance3D.new()
	var boot_mesh := BoxMesh.new()
	boot_mesh.size = Vector3(0.15, 0.14, 0.26)
	boot.mesh = boot_mesh
	boot.material_override = boots
	boot.position = Vector3(0, -0.54, -0.04)
	hip.add_child(boot)
	return hip


func _capsule(parent: Node3D, radius: float, height: float, mat: Material, pos: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	mesh.radial_segments = 9
	mesh.rings = 4
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)


func _sphere(parent: Node3D, radius: float, mat: Material, pos: Vector3, shape_scale: Vector3 = Vector3.ONE) -> void:
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


func _cylinder(parent: Node3D, radius: float, height: float, mat: Material, pos: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 10
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)


func _cone(parent: Node3D, top: float, bottom: float, height: float, mat: Material, pos: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	mesh.radial_segments = 8
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)


func talk() -> void:
	var scene := get_tree().current_scene
	if quest_id != "" and scene and scene.has_method("_on_npc_talk"):
		scene._on_npc_talk(self)
		_talk_cd = 0.4
		_gesture_t = 1.8
		return
	if _talk_cd > 0.0 or lines.is_empty():
		return
	_talk_cd = 1.2
	_gesture_t = 1.8
	if scene and scene.get("hud") != null:
		scene.hud.add_feed("%s：%s" % [npc_name, lines[_line_index]])
	_line_index = (_line_index + 1) % lines.size()


func _physics_process(delta: float) -> void:
	_talk_cd = maxf(0.0, _talk_cd - delta)
	_anim += delta
	# 夜间作息：入夜后回到落脚点站着打盹，偶尔冒 Zzz。
	var scene_dn := get_tree().current_scene
	if scene_dn and scene_dn.get("daynight") != null and scene_dn.daynight.is_night() and patrol.is_empty():
		velocity.x = 0.0
		velocity.z = 0.0
		velocity.y = -4.0
		move_and_slide()
		if terrain:
			global_position.y = terrain.get_height(global_position.x, global_position.z)
		_play(&"sleep")
		if _visual:
			_visual.rotation.x = lerpf(_visual.rotation.x, 0.16, delta * 2.0)
		_sleep_t -= delta
		if _sleep_t <= 0.0:
			_sleep_t = 6.0
			DamageNumber.spawn_at(get_tree().current_scene, global_position + Vector3(0, 2.1, 0), "Zzz", Color(0.75, 0.85, 1.0))
		return
	if _visual:
		_visual.rotation.x = lerpf(_visual.rotation.x, 0.0, delta * 2.0)
	# 受惊：附近开枪或怪物靠近时抱头蹲下，过几秒才恢复。
	var scared := false
	if player and player.weapon and Time.get_ticks_msec() - player.weapon.last_shot_msec < 300 and global_position.distance_to(player.global_position) < 10.0:
		scared = true
	for enemy in get_tree().get_nodes_in_group("wild_enemy"):
		if enemy.alive and enemy.global_position.distance_to(global_position) < 10.0:
			scared = true
			break
	if scared:
		_cower_t = 2.6
	if _cower_t > 0.0:
		_cower_t -= delta
		velocity.x = 0.0
		velocity.z = 0.0
		velocity.y = -4.0
		move_and_slide()
		if terrain:
			global_position.y = terrain.get_height(global_position.x, global_position.z)
		_play(&"cower")
		if _visual:
			_visual.scale = _visual.scale.lerp(Vector3.ONE * 0.82, delta * 6.0)
			_head.rotation.x = lerpf(_head.rotation.x, 0.45, delta * 6.0)
			_arm_l.rotation.z = lerpf(_arm_l.rotation.z, 2.2, delta * 6.0)
			_arm_r.rotation.z = lerpf(_arm_r.rotation.z, -2.2, delta * 6.0)
		return
	if _visual:
		_visual.scale = _visual.scale.lerp(Vector3.ONE, delta * 4.0)
		_head.rotation.x = lerpf(_head.rotation.x, 0.0, delta * 4.0)
		_arm_l.rotation.z = lerpf(_arm_l.rotation.z, 0.0, delta * 4.0)
		_arm_r.rotation.z = lerpf(_arm_r.rotation.z, 0.0, delta * 4.0)
	var to_player := Vector3.ZERO
	if player:
		to_player = player.global_position - global_position
		to_player.y = 0.0
	# 行商：有巡逻路线时沿路往返。
	if not patrol.is_empty() and to_player.length() >= 7.0:
		var target: Vector3 = patrol[_patrol_i]
		var dir := target - global_position
		dir.y = 0.0
		if dir.length() < 1.4:
			_patrol_i = (_patrol_i + 1) % patrol.size()
		else:
			dir = dir.normalized()
			velocity.x = dir.x * 1.35
			velocity.z = dir.z * 1.35
			rotation.y = lerp_angle(rotation.y, atan2(dir.x, dir.z) + PI, delta * 3.5)
		velocity.y = -4.0
		move_and_slide()
		if terrain:
			global_position.y = terrain.get_height(global_position.x, global_position.z)
		_play(&"walk")
		if _visual:
			_visual.position.y = sin(_anim * 1.8) * 0.02
			var p_swing := sin(_anim * 4.6) * 0.3
			_arm_l.rotation.x = p_swing
			_arm_r.rotation.x = -p_swing
			_leg_l.rotation.x = sin(_anim * 4.6) * 0.5
			_leg_r.rotation.x = -sin(_anim * 4.6) * 0.5
		return
	# 玩家靠近时面向玩家；否则在落脚点 4m 内游走。
	if to_player.length() < 7.0:
		rotation.y = lerp_angle(rotation.y, atan2(to_player.x, to_player.z) + PI, delta * 4.0)
		velocity.x = 0.0
		velocity.z = 0.0
		if _head:
			_head.rotation.y = lerp_angle(_head.rotation.y, wrapf(atan2(to_player.x, to_player.z) + PI - rotation.y, -PI, PI) * 0.6, delta * 5.0)
	else:
		if _head:
			_head.rotation.y = lerp_angle(_head.rotation.y, sin(_anim * 0.45) * 0.35, delta * 1.5)
		_think -= delta
		if _think <= 0.0:
			_think = randf_range(3.0, 6.0)
			_target = _home + Vector3(randf_range(-4, 4), 0, randf_range(-4, 4))
		var dir := _target - global_position
		dir.y = 0.0
		if dir.length() > 0.6:
			dir = dir.normalized()
			velocity.x = dir.x * 1.1
			velocity.z = dir.z * 1.1
			rotation.y = lerp_angle(rotation.y, atan2(dir.x, dir.z) + PI, delta * 3.0)
		else:
			velocity.x = 0.0
			velocity.z = 0.0
	velocity.y = -4.0
	move_and_slide()
	if terrain:
		global_position.y = terrain.get_height(global_position.x, global_position.z)
	# glb 路径由骨骼动画驱动：说话/行走/站立分别选剪辑。
	var moving := Vector2(velocity.x, velocity.z).length() > 0.2
	if _ap:
		if _gesture_t > 0.0:
			_play(&"talk")
		elif moving:
			_play(&"walk")
		else:
			_play(&"idle")
	# 呼吸感与四肢摆动（程序化回退路径）。
	if _visual:
		_visual.position.y = sin(_anim * 1.8) * 0.02
		var swing := sin(_anim * 3.2) * (0.25 if moving else 0.05)
		_arm_l.rotation.x = swing
		_arm_r.rotation.x = -swing
		var leg_target := sin(_anim * 4.6) * (0.5 if moving else 0.0)
		_leg_l.rotation.x = lerpf(_leg_l.rotation.x, leg_target, delta * 10.0)
		_leg_r.rotation.x = lerpf(_leg_r.rotation.x, -leg_target, delta * 10.0)
	# 交谈手势：说话时抬起右手比划、头随语气轻点。
	if _gesture_t > 0.0:
		_gesture_t -= delta
		if _visual:
			_arm_r.rotation.x = -1.15 + sin(_anim * 7.0) * 0.18
			_head.rotation.x = sin(_anim * 3.5) * 0.06