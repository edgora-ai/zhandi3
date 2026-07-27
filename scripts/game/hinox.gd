class_name Hinox
extends CharacterBody3D
## 西诺克斯独眼巨人：沉睡的巨型 Boss。惊醒后跺地猛砸、远程投石；独眼是弱点，
## 命中眼睛双倍伤害并触发护目跪地硬直。

var terrain: Terrain
var player: Player
var alive := true
var hp := 320.0
var display_name := "西诺克斯"

var _home := Vector3.ZERO
var _state := "sleep"  # sleep/wake/active/stagger/die
var _state_t := 0.0
var _attack_cd := 0.0
var _throw_cd := 0.0
var _strike_t := -1.0  # >=0 表示跺地/投石已在途中，计时到点结算
var _strike_kind := ""
var _anim := 0.0
var _glb: Node3D
var _ap: AnimationPlayer
var _cur_anim := ""
var _anim_hold := 0.0
var _snore_t := 0.0
var _breath_t := 0.0


static func create(parent: Node, p_terrain: Terrain, p_player: Player, pos: Vector3) -> Hinox:
	var h := Hinox.new()
	h.terrain = p_terrain
	h.player = p_player
	parent.add_child(h)
	h.global_position = pos
	h._home = pos
	return h


func _ready() -> void:
	add_to_group("wild_enemy")
	collision_layer = 4
	collision_mask = 1
	# 躯干碰撞（shape 0）与独眼弱点球（shape 1）。
	var col := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 1.7
	shape.height = 4.2
	col.shape = shape
	col.position.y = 2.2
	add_child(col)
	var eye_col := CollisionShape3D.new()
	var eye_shape := SphereShape3D.new()
	eye_shape.radius = 0.55
	eye_col.shape = eye_shape
	eye_col.position = Vector3(0, 3.35, -1.55)
	add_child(eye_col)
	if not _try_glb_visual():
		return
	_play(&"sleep")


func get_hit_part(shape_idx: int) -> String:
	return "eye" if shape_idx == 1 else "body"


func _try_glb_visual() -> bool:
	if not ResourceLoader.exists("res://assets/models/hinox.glb"):
		return false
	var scene_res := load("res://assets/models/hinox.glb") as PackedScene
	if scene_res == null:
		return false
	_glb = scene_res.instantiate()
	add_child(_glb)
	_ap = _glb.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _ap != null:
		_ap.playback_default_blend_time = 0.12
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
		if anim_res and anim_res.loop_mode == Animation.LOOP_NONE and not (clip in [&"wake", &"stomp", &"throw", &"stagger", &"hit", &"die"]):
			anim_res.loop_mode = Animation.LOOP_LINEAR
		_cur_anim = clip
		_ap.play(clip)


func take_damage(amount: float, from: Variant = null, part_name: String = "body") -> void:
	if not alive:
		return
	var dmg := amount
	if part_name == "eye":
		dmg *= 2.0
	hp -= dmg
	DamageNumber.spawn_at(get_tree().current_scene, global_position + Vector3(0, 4.6, 0), str(int(dmg)) + ("!" if part_name == "eye" else ""), Color(1.0, 0.75, 0.25) if part_name == "eye" else Color(1.0, 0.85, 0.25))
	if hp <= 0.0:
		alive = false
		if from and from.get("kills") != null:
			from.kills += 1
		if from and from.has_method("give_rupees"):
			from.give_rupees(15)
		_state = "die"
		_play(&"die")
		collision_layer = 0
		Loot.spawn(get_tree().current_scene, global_position, "meat", "", 5, 2)
		Loot.spawn(get_tree().current_scene, global_position + Vector3(1.2, 0, 0), "seed", "", 2, 2)
		Loot.spawn(get_tree().current_scene, global_position + Vector3(-1.2, 0, 0.5), "monster_part", "", 4, 1)
		DamageNumber.spawn_at(get_tree().current_scene, global_position + Vector3(0, 5.0, 0), "巨人倒下!", Color(1.0, 0.55, 0.20))
		await get_tree().create_timer(1.4).timeout
		queue_free()
		return
	# 睡眠中被打出醒；眼睛命中触发护目硬直。
	if _state == "sleep":
		_wake()
		return
	if part_name == "eye" and _state == "active":
		_state = "stagger"
		_state_t = 1.5
		_strike_t = -1.0
		_play(&"stagger")
		DamageNumber.spawn_at(get_tree().current_scene, global_position + Vector3(0, 5.0, 0), "命中眼睛!", Color(1.0, 0.60, 0.15))
		return
	_play(&"hit")
	_anim_hold = 0.25


func _wake() -> void:
	_state = "wake"
	_state_t = 1.0
	if _glb:
		_glb.scale = Vector3.ONE
	_cur_anim = ""
	_play(&"wake")
	DamageNumber.spawn_at(get_tree().current_scene, global_position + Vector3(0, 4.5, 0), "!!", Color(1.0, 0.4, 0.15))
	var scene := get_tree().current_scene
	if scene and scene.get("hud") != null:
		scene.hud.add_feed("西诺克斯醒了！快躲开它的跺地和投石")


func _physics_process(delta: float) -> void:
	if not alive or player == null or terrain == null:
		return
	_anim += delta
	_anim_hold = maxf(0.0, _anim_hold - delta)
	_attack_cd = maxf(0.0, _attack_cd - delta)
	_throw_cd = maxf(0.0, _throw_cd - delta)
	var to_player := player.global_position - global_position
	to_player.y = 0.0
	var dist := to_player.length()
	# 出手结算：跺地/投石到点执行。
	if _strike_t >= 0.0:
		_strike_t -= delta
		if _strike_t < 0.0:
			if _strike_kind == "stomp":
				FX.impact(global_position + Vector3(0, 0.2, -2.2))
				if dist < 4.2 and player.alive:
					player.take_damage(25.0, self)
					if player.alive:
						var push := (player.global_position - global_position)
						push.y = 0.0
						player.velocity += push.normalized() * 7.0 + Vector3(0, 4.0, 0)
			elif _strike_kind == "throw":
				var from := global_position + Vector3(0, 3.6, 0)
				var dir := (player.global_position + Vector3(0, 1.0, 0) - from).normalized()
				var rock := WildProjectile.new()
				rock.configure("rock", dir * 20.0, 20.0, self)
				get_tree().current_scene.add_child(rock)
				rock.global_position = from + dir * 1.5
	if _state == "sleep":
		velocity.x = 0.0
		velocity.z = 0.0
		velocity.y = -4.0
		move_and_slide()
		# 睡眠可读性：肚皮缓慢起伏 + 周期性飘出鼾声 Z 字，远看是活物而不是黑石头。
		_breath_t += delta
		if _glb:
			_glb.scale = Vector3.ONE * (1.0 + sin(_breath_t * 1.35) * 0.018)
		_snore_t -= delta
		if _snore_t <= 0.0:
			_snore_t = 1.5
			var scene := get_tree().current_scene
			if scene:
				DamageNumber.spawn_at(scene, global_position + Vector3(randf_range(-0.4, 0.4), 4.3, -0.4), "Z", Color(0.72, 0.82, 1.0))
		if dist < 14.0 and player.alive:
			_wake()
		return
	if _state == "wake":
		_state_t -= delta
		if _state_t <= 0.0:
			_state = "active"
		return
	if _state == "stagger":
		_state_t -= delta
		velocity.x = 0.0
		velocity.z = 0.0
		velocity.y = -4.0
		move_and_slide()
		if _state_t <= 0.0:
			_state = "active"
		return
	if _state != "active":
		return
	# 激活：慢速逼近，近身跺地，中远程投石。
	if not player.alive:
		velocity.x = 0.0
		velocity.z = 0.0
	elif dist > 4.0:
		var dir := to_player.normalized()
		velocity.x = dir.x * 1.3
		velocity.z = dir.z * 1.3
		rotation.y = lerp_angle(rotation.y, atan2(dir.x, dir.z) + PI, delta * 2.5)
		if dist > 10.0 and dist < 30.0 and _throw_cd <= 0.0:
			_throw_cd = 4.5
			_strike_kind = "throw"
			_strike_t = 0.55
			_play(&"throw")
			_anim_hold = 0.7
	else:
		velocity.x = 0.0
		velocity.z = 0.0
		if _attack_cd <= 0.0:
			_attack_cd = 2.6
			_strike_kind = "stomp"
			_strike_t = 0.42
			_play(&"stomp")
			_anim_hold = 0.6
	velocity.y = -6.0
	move_and_slide()
	global_position.y = terrain.get_height(global_position.x, global_position.z)
	if _ap and _anim_hold <= 0.0 and _strike_t < 0.0:
		_play(&"walk")
