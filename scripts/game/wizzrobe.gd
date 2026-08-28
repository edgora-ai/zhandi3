class_name Wizzrobe
extends CharacterBody3D
## 维佐法师：悬浮施法者。保持中距游走、火球术攻击；玩家近身或受击时闪现逃脱。

var terrain: Terrain
var player: Player
var alive := true
var hp := 40.0
var display_name := "维佐法师"

var _home := Vector3.ZERO
var _cast_cd := 1.5
var _tp_cd := 0.0
var _strafe := 1.0
var _anim := 0.0
var _glb: Node3D
var _ap: AnimationPlayer
var _cur_anim := ""
var _anim_hold := 0.0


static func create(parent: Node, p_terrain: Terrain, p_player: Player, pos: Vector3) -> Wizzrobe:
	var w := Wizzrobe.new()
	w.terrain = p_terrain
	w.player = p_player
	parent.add_child(w)
	w.global_position = pos
	w._home = pos
	return w


func _ready() -> void:
	add_to_group("wild_enemy")
	collision_layer = 4
	collision_mask = 0
	var col := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.36
	shape.height = 1.5
	col.shape = shape
	col.position.y = 0.75
	add_child(col)
	_try_glb_visual()


func _try_glb_visual() -> bool:
	if not ResourceLoader.exists("res://assets/models/wizzrobe.glb"):
		return false
	var scene_res := load("res://assets/models/wizzrobe.glb") as PackedScene
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
	_play(&"hover")
	return true


func _play(clip: StringName) -> void:
	if _ap == null or _cur_anim == clip:
		return
	if _ap.has_animation(clip):
		var anim_res := _ap.get_animation(clip)
		if anim_res and anim_res.loop_mode == Animation.LOOP_NONE and not (clip in [&"cast", &"hit", &"die"]):
			anim_res.loop_mode = Animation.LOOP_LINEAR
		_cur_anim = clip
		_ap.play(clip)


func take_damage(amount: float, from: Variant = null, _part_name: String = "body") -> void:
	if not alive:
		return
	hp -= amount
	DamageNumber.spawn_at(get_tree().current_scene, global_position + Vector3(0, 1.9, 0), str(int(amount)), Color(1.0, 0.85, 0.25))
	if hp <= 0.0:
		alive = false
		if from and from.get("kills") != null:
			from.kills += 1
		if from and from.has_method("give_rupees"):
			from.give_rupees(8)
		_play(&"die")
		collision_layer = 0
		Loot.spawn(get_tree().current_scene, global_position, "meat", "", 2, 1)
		Loot.spawn(get_tree().current_scene, global_position + Vector3(0.5, 0, 0), "seed", "", 1, 2)
		Loot.spawn(get_tree().current_scene, global_position + Vector3(-0.5, 0, 0.3), "monster_part", "", 3, 1)
		await get_tree().create_timer(0.8).timeout
		if is_inside_tree() and not is_queued_for_deletion(): queue_free()
		return
	_play(&"hit")
	_anim_hold = 0.3
	# 受击 35% 概率闪现逃脱。
	if randf() < 0.35 and _tp_cd <= 0.0:
		_teleport()


func _cast() -> void:
	_cast_cd = 3.0
	_play(&"cast")
	_anim_hold = 0.55
	var from := global_position + Vector3(0.55, 1.62, 0) - global_transform.basis.x * 0.55
	var target := player.global_position + Vector3(0, 1.0, 0)
	var dir := (target - from).normalized()
	var projectile := WildProjectile.new()
	projectile.configure("fire", dir * 16.0, 14.0, self)
	get_tree().current_scene.add_child(projectile)
	projectile.global_position = from + dir * 0.6


func _teleport() -> void:
	_tp_cd = 2.5
	FX.impact(global_position + Vector3(0, 1.0, 0))
	var offset := Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized() * randf_range(8.0, 12.0)
	var next := global_position + offset
	global_position = Vector3(next.x, terrain.get_height(next.x, next.z) + 1.5, next.z)
	FX.impact(global_position + Vector3(0, 1.0, 0))
	DamageNumber.spawn_at(get_tree().current_scene, global_position + Vector3(0, 2.0, 0), "闪现!", Color(0.85, 0.50, 1.0))


func _physics_process(delta: float) -> void:
	if not alive or player == null or terrain == null:
		return
	_anim += delta
	_anim_hold = maxf(0.0, _anim_hold - delta)
	_cast_cd = maxf(0.0, _cast_cd - delta)
	_tp_cd = maxf(0.0, _tp_cd - delta)
	var to_player := player.global_position - global_position
	to_player.y = 0.0
	var dist := to_player.length()
	# 悬浮贴地 1.5m。
	var gy := terrain.get_height(global_position.x, global_position.z) + 1.5
	global_position.y = lerpf(global_position.y, gy, delta * 3.0)
	# 中距游走：远则近、近则退、中距侧移。
	var dir := to_player.normalized()
	if dist > 14.0:
		velocity.x = dir.x * 3.5
		velocity.z = dir.z * 3.5
	elif dist < 8.0:
		velocity.x = -dir.x * 4.0
		velocity.z = -dir.z * 4.0
		if dist < 6.0 and _tp_cd <= 0.0:
			_teleport()
	else:
		if randf() < delta * 0.3:
			_strafe = -_strafe
		var tangent := dir.cross(Vector3.UP).normalized() * _strafe
		velocity.x = tangent.x * 1.6
		velocity.z = tangent.z * 1.6
	velocity.y = 0.0
	move_and_slide()
	global_position.y = lerpf(global_position.y, gy, delta * 3.0)
	if dist < 30.0:
		rotation.y = lerp_angle(rotation.y, atan2(dir.x, dir.z) + PI, delta * 5.0)
	# 施法与悬停动画。
	if dist < 22.0 and _cast_cd <= 0.0 and player.alive:
		_cast()
	if _ap and _anim_hold <= 0.0:
		_play(&"hover")
