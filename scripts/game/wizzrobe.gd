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
var _cast_windup := -1.0 # // FIX: R2-B4 施法前摇计时
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
	w.position = pos
	w._home = pos
	parent.add_child(w)
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
	Toon.apply_to_glb(_glb) # // FIX: OPT-F1/TA1 glb 卡通化重染（描边+色带）
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
	var _sfx_w := get_tree().get_first_node_in_group("sfx_bank")
	if _sfx_w:
		_sfx_w.play_at("explosion", global_position + Vector3(0, 1.6, 0), -6.0, 1.12)
	_anim_hold = 0.55
	var from := global_position + Vector3(0.55, 1.62, 0) - global_transform.basis.x * 0.55
	var target := player.global_position + Vector3(0, 1.0, 0)
	var dir := (target - from).normalized()
	var projectile := WildProjectile.new()
	projectile.configure("fire", dir * 16.0, 14.0, self)
	get_tree().current_scene.add_child(projectile)
	projectile.global_position = from + dir * 0.6


func _is_teleport_safe(pos: Vector3) -> bool:
	# // FIX: H18 shape_test占位：落点需通过物理空间碰撞校验，避免穿墙/落水/陡坡
	if terrain == null:
		return true
	if terrain.is_in_water(pos.x, pos.z):
		return false
	if terrain.get_normal(pos.x, pos.z, 1.2).y < 0.52:
		return false
	# shape_test占位：未来用 PhysicsShapeQueryParameters3D 扫落点球体积
	return true

func _teleport() -> void:
	_tp_cd = 2.5
	FX.impact(global_position + Vector3(0, 1.0, 0))
	var _sfx_tp := get_tree().get_first_node_in_group("sfx_bank")
	if _sfx_tp:
		_sfx_tp.play_at("stasis", global_position + Vector3(0, 1.0, 0), -7.0)
	var next := Vector3.ZERO
	var found := false
	for i in range(5):
		var offset := Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized() * randf_range(8.0, 12.0)
		var cand := global_position + offset
		cand = Vector3(cand.x, terrain.get_height(cand.x, cand.z) + 1.5, cand.z)
		if _is_teleport_safe(cand):
			next = cand
			found = true
			break
	if not found:
		return # // FIX: H18 无安全落点则取消闪现，避免直写碰撞体内
	global_position = next
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
		# // FIX: R2-B4/CB13c 原瞬发无前摇：0.45s 前摇+充能音+LoS（坡后不再盲射）
		_cast_cd = 3.2
		_cast_windup = 0.45
		var _sfx_w := get_tree().get_first_node_in_group("sfx_bank")
		if _sfx_w:
			_sfx_w.play_at("enemy_charge", global_position + Vector3(0, 1.4, 0), -8.0, 1.35)
	if _cast_windup > 0.0:
		_cast_windup -= delta
		if _cast_windup <= 0.0 and dist < 26.0 and player.alive:
			var q := PhysicsRayQueryParameters3D.create(global_position + Vector3(0, 1.4, 0), player.global_position + Vector3(0, 1.0, 0), 1, [get_rid()])
			if get_world_3d().direct_space_state.intersect_ray(q).is_empty():
				_cast()
	if _ap and _anim_hold <= 0.0:
		_play(&"hover")
