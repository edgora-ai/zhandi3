class_name Keese
extends CharacterBody3D
## 夜行蝙蝠：夜间绕巢盘旋，周期性俯冲袭扰玩家；白天归巢蛰伏。一击即死，小概率掉兽肉。

var terrain: Terrain
var player: Player
var alive := true
var hp := 8.0
var display_name := "夜蝠"

var _home := Vector3.ZERO
var _angle := 0.0
var _dive_t := 0.0
var _dive_cd := 0.0
var _dive_dir := Vector3.ZERO
var _roosting := false
var _glb: Node3D
var _ap: AnimationPlayer
var _cur_anim := ""
var _anim_hold := 0.0


func setup(p_terrain: Terrain, p_player: Player, pos: Vector3) -> void:
	terrain = p_terrain
	player = p_player
	_home = pos


func _ready() -> void:
	add_to_group("wild_enemy")
	collision_layer = 4
	collision_mask = 0
	global_position = _home
	var col := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.3
	col.shape = shape
	add_child(col)
	if not _try_glb_visual():
		pass  # keese 必有 glb；缺失时保持空壳（行为仍可用）


func _try_glb_visual() -> bool:
	if not ResourceLoader.exists("res://assets/models/keese.glb"):
		return false
	var scene_res := load("res://assets/models/keese.glb") as PackedScene
	if scene_res == null:
		return false
	_glb = scene_res.instantiate()
	add_child(_glb)
	_ap = _glb.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _ap == null:
		_glb.queue_free()
		_glb = null
		return false
	_play(&"flap")
	return true


func _play(clip: StringName) -> void:
	if _ap == null or _cur_anim == clip:
		return
	if _ap.has_animation(clip):
		var anim_res := _ap.get_animation(clip)
		if anim_res and anim_res.loop_mode == Animation.LOOP_NONE and not (clip in [&"hit", &"dive"]):
			anim_res.loop_mode = Animation.LOOP_LINEAR
		_cur_anim = clip
		_ap.play(clip)


func take_damage(amount: float, from: Variant = null, _part_name: String = "body") -> void:
	if not alive or _roosting:
		return
	hp -= amount
	_play(&"hit")
	_anim_hold = 0.25
	DamageNumber.spawn_at(get_tree().current_scene, global_position + Vector3(0, 0.5, 0), str(int(amount)), Color(1.0, 0.85, 0.25))
	if hp <= 0.0:
		alive = false
		if from and from.get("kills") != null:
			from.kills += 1
		if randf() < 0.3:
			Loot.spawn(get_tree().current_scene, global_position, "meat", "", 1, 1)
		queue_free()


func _physics_process(delta: float) -> void:
	if not alive or player == null:
		return
	_anim_hold = maxf(0.0, _anim_hold - delta)
	var scene_dn := get_tree().current_scene
	var night := true
	if scene_dn and scene_dn.get("daynight") != null:
		night = scene_dn.daynight.is_night()
	# 白天蛰伏：隐形、悬停巢点、不可交互。
	if not night:
		if not _roosting:
			_roosting = true
			visible = false
			velocity = Vector3.ZERO
			global_position = _home
		return
	if _roosting:
		_roosting = false
		visible = true
	var to_player := player.global_position - global_position
	var dist := to_player.length()
	_dive_cd = maxf(0.0, _dive_cd - delta)
	if _dive_t > 0.0:
		# 俯冲袭扰：直线扑向玩家，接触即伤并拉升脱离。
		_dive_t -= delta
		velocity = _dive_dir * 9.0
		_play(&"dive")
		if dist < 0.9 and player.alive:
			player.take_damage(5.0, self)
			_dive_t = 0.0
			velocity = -_dive_dir * 4.0 + Vector3(0, 5.0, 0)
		elif _dive_t <= 0.0:
			velocity = Vector3(0, 4.0, 0)
	else:
		# 绕巢盘旋：半径 6-10m，高度起伏。
		_angle += delta * 0.55
		var orbit := _home + Vector3(cos(_angle) * 8.0, sin(_angle * 1.7) * 2.0, sin(_angle) * 8.0)
		velocity = velocity.lerp((orbit - global_position) * 1.6, delta * 2.5)
		if _dive_cd <= 0.0 and dist < 14.0 and player.alive:
			_dive_dir = (player.global_position + Vector3(0, 0.8, 0) - global_position).normalized()
			_dive_t = 1.2
			_dive_cd = randf_range(4.0, 7.0)
	move_and_slide()
	if velocity.length_squared() > 0.2 and absf(velocity.normalized().dot(Vector3.UP)) < 0.98:
		look_at(global_position + velocity, Vector3.UP)
	if _ap and _anim_hold <= 0.0 and _dive_t <= 0.0:
		_play(&"flap")
