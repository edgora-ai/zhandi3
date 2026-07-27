class_name Stal
extends CharacterBody3D
## 骷髅夜袭：夜间破土而出的白骨兵。本体被击碎后散架，头颅蹦跳继续咬人。
## mode 为 body（完整骷髅）或 skull（蹦跳头颅）。白天潜伏于地下。

var terrain: Terrain
var player: Player
var alive := true
var hp := 25.0
var mode := "body"
var display_name := "骷髅"

var _home := Vector3.ZERO
var _state := "roost"  # roost/rise/active/crumble（skull 模式不用）
var _state_t := 0.0
var _attack_cd := 0.0
var _anim := 0.0
var _hop_cd := 0.0
var _glb: Node3D
var _ap: AnimationPlayer
var _cur_anim := ""
var _visual: Node3D


static func create_body(parent: Node, p_terrain: Terrain, p_player: Player, pos: Vector3) -> Stal:
	var s := Stal.new()
	s.terrain = p_terrain
	s.player = p_player
	s._home = pos
	parent.add_child(s)
	s.global_position = pos + Vector3(0, -2.0, 0)
	s.visible = false
	return s


static func create_skull(parent: Node, p_terrain: Terrain, p_player: Player, pos: Vector3) -> Stal:
	var s := Stal.new()
	s.terrain = p_terrain
	s.player = p_player
	s.mode = "skull"
	s.hp = 5.0
	s.display_name = "骷髅头"
	parent.add_child(s)
	s.global_position = pos
	return s


func _ready() -> void:
	add_to_group("wild_enemy")
	collision_layer = 4
	collision_mask = 1
	var col := CollisionShape3D.new()
	if mode == "skull":
		var shape := SphereShape3D.new()
		shape.radius = 0.24
		col.shape = shape
		col.position.y = 0.24
		add_child(col)
		_build_skull_visual()
	else:
		var shape := CapsuleShape3D.new()
		shape.radius = 0.32
		shape.height = 1.5
		col.shape = shape
		col.position.y = 0.75
		add_child(col)
		_try_glb_visual()


func _try_glb_visual() -> bool:
	if not ResourceLoader.exists("res://assets/models/skeleton.glb"):
		return false
	var scene_res := load("res://assets/models/skeleton.glb") as PackedScene
	if scene_res == null:
		return false
	_glb = scene_res.instantiate()
	add_child(_glb)
	_ap = _glb.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _ap == null:
		_glb.queue_free()
		_glb = null
		return false
	return true


func _play(clip: StringName) -> void:
	if _ap == null or _cur_anim == clip:
		return
	if _ap.has_animation(clip):
		var anim_res := _ap.get_animation(clip)
		if anim_res and anim_res.loop_mode == Animation.LOOP_NONE and not (clip in [&"rise", &"attack", &"crumble"]):
			anim_res.loop_mode = Animation.LOOP_LINEAR
		_cur_anim = clip
		_ap.play(clip)


# 蹦跳头颅的程序化模型。
func _build_skull_visual() -> void:
	_visual = Node3D.new()
	add_child(_visual)
	var bone := Toon.make_material(Color(0.82, 0.80, 0.72), true, 0.012)
	var bone_d := Toon.make_material(Color(0.55, 0.52, 0.45), true, 0.008)
	var dark := Toon.make_material(Color(0.08, 0.07, 0.06), false)
	var skull := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.18
	sm.height = 0.36
	sm.radial_segments = 10
	sm.rings = 6
	skull.mesh = sm
	skull.material_override = bone
	skull.position.y = 0.20
	_visual.add_child(skull)
	for sx in [-1.0, 1.0]:
		var socket := MeshInstance3D.new()
		var em := SphereMesh.new()
		em.radius = 0.038
		em.height = 0.07
		em.radial_segments = 7
		socket.mesh = em
		socket.material_override = dark
		socket.position = Vector3(sx * 0.065, 0.23, -0.155)
		_visual.add_child(socket)
	var jaw := MeshInstance3D.new()
	var jm := BoxMesh.new()
	jm.size = Vector3(0.15, 0.06, 0.07)
	jaw.mesh = jm
	jaw.material_override = bone_d
	jaw.position = Vector3(0, 0.08, -0.10)
	_visual.add_child(jaw)


func take_damage(amount: float, from: Variant = null, _part_name: String = "body") -> void:
	if not alive:
		return
	if mode == "body" and _state != "active":
		return  # 潜伏/出土期无敌
	hp -= amount
	DamageNumber.spawn_at(get_tree().current_scene, global_position + Vector3(0, 1.6 if mode == "body" else 0.6, 0), str(int(amount)), Color(1.0, 0.85, 0.25))
	if hp <= 0.0:
		_die(from)


func _die(from: Variant) -> void:
	alive = false
	if from and from.get("kills") != null:
		from.kills += 1
	if from and from.has_method("give_rupees"):
		from.give_rupees(2 if mode == "skull" else 3)
	var scene := get_tree().current_scene
	if mode == "skull":
		Loot.spawn(scene, global_position, "wood", "", 2, 1)
		Loot.spawn(scene, global_position + Vector3(0.4, 0, 0), "meat", "", 1, 1)
		queue_free()
		return
	# 本体散架：播 crumble 并放出蹦跳头颅。
	_state = "crumble"
	_state_t = 0.85
	_play(&"crumble")
	var skull := Stal.create_skull(get_parent(), terrain, player, global_position + Vector3(0, 0.4, 0))
	skull.velocity = Vector3(randf_range(-2, 2), 4.0, randf_range(-2, 2))
	DamageNumber.spawn_at(scene, global_position + Vector3(0, 1.8, 0), "散架!", Color(0.85, 0.82, 0.70))


func _physics_process(delta: float) -> void:
	if not alive or player == null:
		return
	_anim += delta
	# 蹦跳头颅：快速小跳逼近，落地压弹。
	if mode == "skull":
		_hop_cd = maxf(0.0, _hop_cd - delta)
		var to_p := player.global_position - global_position
		to_p.y = 0.0
		if is_on_floor():
			velocity.x = move_toward(velocity.x, 0.0, delta * 8.0)
			velocity.z = move_toward(velocity.z, 0.0, delta * 8.0)
			if _hop_cd <= 0.0 and to_p.length() < 16.0 and player.alive:
				velocity = to_p.normalized() * 3.4 + Vector3(0, 4.4, 0)
				_hop_cd = 0.55 + randf() * 0.25
				rotation.y = atan2(to_p.normalized().x, to_p.normalized().z) + PI
		velocity.y = maxf(velocity.y - 12.0 * delta, -14.0)
		move_and_slide()
		if to_p.length() < 0.8 and player.alive and _hop_cd > 0.0:
			player.take_damage(4.0, self)
			_hop_cd = 1.0
		var sq := 1.0 + clampf(velocity.y * 0.05, -0.2, 0.25)
		_visual.scale = _visual.scale.lerp(Vector3(2.0 - sq, sq, 2.0 - sq) * 0.5 + Vector3.ONE * 0.5, delta * 10.0)
		return
	# 本体：昼夜作息驱动状态机。
	var scene_dn := get_tree().current_scene
	var night := true
	if scene_dn and scene_dn.get("daynight") != null:
		night = scene_dn.daynight.is_night()
	if not night:
		if _state != "roost":
			_state = "roost"
			visible = false
			velocity = Vector3.ZERO
			global_position = _home + Vector3(0, -2.0, 0)
			_cur_anim = ""
		return
	if _state == "roost":
		# 夜幕降临：破土而出。
		_state = "rise"
		_state_t = 1.25
		visible = true
		global_position = _home
		_cur_anim = ""
		_play(&"rise")
		DamageNumber.spawn_at(get_tree().current_scene, global_position + Vector3(0, 1.5, 0), "!", Color(0.85, 0.82, 0.70))
		return
	if _state == "rise":
		_state_t -= delta
		if _state_t <= 0.0:
			_state = "active"
		return
	if _state == "crumble":
		_state_t -= delta
		if _state_t <= 0.0:
			queue_free()
		return
	# active：僵硬拖步逼近，近身双爪撕抓。
	_attack_cd = maxf(0.0, _attack_cd - delta)
	var to_player := player.global_position - global_position
	to_player.y = 0.0
	var dist := to_player.length()
	if dist < 20.0 and player.alive:
		var dir := to_player.normalized()
		if dist > 1.5:
			velocity.x = dir.x * 2.0
			velocity.z = dir.z * 2.0
			rotation.y = lerp_angle(rotation.y, atan2(dir.x, dir.z) + PI, delta * 4.0)
		else:
			velocity.x = 0.0
			velocity.z = 0.0
			if _attack_cd <= 0.0:
				_attack_cd = 1.2
				_play(&"attack")
				player.take_damage(8.0, self)
	else:
		velocity.x = 0.0
		velocity.z = 0.0
	velocity.y = -4.0
	move_and_slide()
	if terrain:
		global_position.y = terrain.get_height(global_position.x, global_position.z) + 0.05
	if _ap and _state == "active":
		if Vector2(velocity.x, velocity.z).length() > 0.3:
			_play(&"walk")
