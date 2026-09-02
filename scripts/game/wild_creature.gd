class_name WildCreature
extends CharacterBody3D
const WILD_CREATURE_PRELOADS := {"bear":"res://assets/models/bear.glb","boar":"res://assets/models/boar.glb","wolf":"res://assets/models/wolf.glb"}  # // FIX: AUD-P0-4 preload map

var species := "boar"
var terrain: Terrain
var player: Player
var alive := true
var hp := 40.0
var display_name := "野猪"
var damage_mult := 1.0
var kills := 0

var _move_target := Vector3.ZERO
var _think_time := 0.0
var _attack_cooldown := 0.0
var _anim_time := 0.0
var _legs: Array[Node3D] = []
var _wings: Array[Node3D] = []
var _home := Vector3.ZERO
var _alert_left := -1.0
var _flee_lock := 0.0  # // FIX: FLEE 逃跑锚点锁定（防每 1.2-2.8s 乱转向）
var _alerted := false
var _glb: Node3D
var _ap: AnimationPlayer
var _cur_anim := ""
var _anim_hold := 0.0
var _call_cd := 0.0
var _ai_timer := 0.0
var _shadow_originals: Dictionary = {}
var _shadows_disabled := false
var _shadow_cache_ready := false
var _cached_pack_near := false
var _cached_night := false
var _cached_aggressive := false


func setup(p_species: String, p_terrain: Terrain, p_player: Player) -> void:
	species = p_species
	terrain = p_terrain
	player = p_player
	match species:
		"wolf":
			hp = 48.0
			display_name = "狼"
		"bear":
			hp = 130.0
			display_name = "熊"
		"bird":
			hp = 16.0
			display_name = "山鸟"
		_:
			hp = 62.0
			display_name = "野猪"


func _ready() -> void:
	add_to_group("wildlife")
	collision_layer = 4
	collision_mask = 1
	_home = global_position
	_move_target = global_position
	_build_collision()
	if not _try_glb_visual():
		_build_model()
	_build_shadow_cache()


func _build_collision() -> void:
	var body_col := CollisionShape3D.new()
	var head_col := CollisionShape3D.new()
	match species:
		"bear":
			var body := CapsuleShape3D.new()
			body.radius = 0.90
			body.height = 2.20
			body_col.shape = body
			body_col.position = Vector3(0, 1.18, 0.20)
			body_col.rotation_degrees = Vector3(90, 0, 0)
			var head := SphereShape3D.new()
			head.radius = 0.68
			head_col.shape = head
			head_col.position = Vector3(0, 1.67, -1.05)
		"wolf":
			var body := CapsuleShape3D.new()
			body.radius = 0.40
			body.height = 1.50
			body_col.shape = body
			body_col.position = Vector3(0, 0.84, 0.0)
			body_col.rotation_degrees = Vector3(90, 0, 0)
			var head := SphereShape3D.new()
			head.radius = 0.38
			head_col.shape = head
			head_col.position = Vector3(0, 1.26, -1.12)
		"bird":
			var body := CapsuleShape3D.new()
			body.radius = 0.18
			body.height = 0.45
			body_col.shape = body
			body_col.position = Vector3(0, 0.32, 0.0)
			body_col.rotation_degrees = Vector3(90, 0, 0)
			var head := SphereShape3D.new()
			head.radius = 0.15
			head_col.shape = head
			head_col.position = Vector3(0, 0.36, -0.30)
		_:
			var body := CapsuleShape3D.new()
			body.radius = 0.55
			body.height = 1.85
			body_col.shape = body
			body_col.position = Vector3(0, 0.76, 0.02)
			body_col.rotation_degrees = Vector3(90, 0, 0)
			var head := SphereShape3D.new()
			head.radius = 0.42
			head_col.shape = head
			head_col.position = Vector3(0, 0.82, -1.13)
	add_child(body_col)
	add_child(head_col)


func _try_glb_visual() -> bool:
	var path := "res://assets/models/%s.glb" % species
	if not ResourceLoader.exists(path):
		return false
	var scene_res := load(path) as PackedScene
	if scene_res == null:
		return false
	_glb = scene_res.instantiate()
	add_child(_glb)
	Toon.apply_to_glb(_glb)
	_ap = _glb.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _ap != null:
		_ap.playback_default_blend_time = 0.12
	if _ap == null:
		_glb.queue_free()
		_glb = null
		return false
	_play(&"idle")
	return true


func _play(clip: StringName) -> void:
	if _ap == null:
		return
	if _cur_anim == clip:
		var is_one := not (clip == &"idle" or clip == &"walk" or clip == &"run")
		if is_one and _ap.speed_scale != 1.0:
			_ap.speed_scale = 1.0
		return
	if not _ap.has_animation(clip):
		return
	var anim_res := _ap.get_animation(clip)
	if anim_res and anim_res.loop_mode == Animation.LOOP_NONE and not (clip in [&"windup", &"smash", &"hit", &"die", &"buck", &"dash", &"attack"]):
		anim_res.loop_mode = Animation.LOOP_LINEAR
	_cur_anim = clip
	_ap.play(clip)
	var one_shot := not (clip == &"idle" or clip == &"walk" or clip == &"run")
	if one_shot:
		_ap.speed_scale = 1.0


func _get_ai_interval(dist: float) -> float:
	if dist <= 40.0:
		return 0.08
	elif dist <= 80.0:
		return 0.35
	return 0.90


func _build_shadow_cache() -> void:
	if _shadow_cache_ready:
		return
	for mi in find_children("*", "MeshInstance3D", true, false):
		var mesh_inst := mi as MeshInstance3D
		if mesh_inst != null and not _shadow_originals.has(mesh_inst):
			_shadow_originals[mesh_inst] = mesh_inst.cast_shadow
	_shadow_cache_ready = true


func _apply_lod(dist: float) -> void:
	if not _shadow_cache_ready:
		_build_shadow_cache()
	var far := dist > 80.0
	if far and not _shadows_disabled:
		for key in _shadow_originals.keys():
			if is_instance_valid(key):
				(key as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_shadows_disabled = true
		if _ap:
			_ap.active = false
	elif not far and _shadows_disabled:
		for key in _shadow_originals.keys():
			if is_instance_valid(key):
				(key as MeshInstance3D).cast_shadow = _shadow_originals[key] as int
		_shadows_disabled = false
		if _ap:
			_ap.active = true


func _build_model() -> void:
	match species:
		"wolf":
			_build_wolf()
		"bear":
			_build_bear()
		"bird":
			_build_bird()
		_:
			_build_boar()


func _build_boar() -> void:
	var fur := Toon.make_material(Color(0.30, 0.20, 0.14), true, 0.014)
	var mane := Toon.make_material(Color(0.13, 0.10, 0.075), true, 0.01)
	var tusk := Toon.make_material(Color(0.92, 0.83, 0.60), true, 0.006)
	_sphere(self, 0.55, fur, Vector3(0, 0.78, 0), Vector3(0.92, 0.82, 1.45))
	_sphere(self, 0.38, fur, Vector3(0, 0.78, -0.72), Vector3(1.0, 0.85, 1.1))
	_sphere(self, 0.24, mane, Vector3(0, 0.70, -1.02), Vector3(1.15, 0.72, 1.0))
	for sx in [-1.0, 1.0]:
		var tusk_part := _capsule(self, 0.045, 0.38, tusk, Vector3(sx * 0.23, 0.64, -1.14))
		tusk_part.rotation_degrees = Vector3(52, 0, sx * 28)
		var ear := _part(Vector3(0.18, 0.28, 0.08), fur, Vector3(sx * 0.31, 1.08, -0.72), self)
		ear.rotation_degrees.z = sx * -20.0
	for i in range(7):
		var bristle := _part(Vector3(0.07, 0.26, 0.15), mane, Vector3(0, 1.24, -0.35 + i * 0.15), self)
		bristle.rotation_degrees.x = float(i - 3) * 3.0
	for sx in [-1.0, 1.0]:
		_sphere(self, 0.05, mane, Vector3(sx * 0.19, 0.86, -1.06), Vector3.ONE)
	var tail := _capsule(self, 0.05, 0.34, fur, Vector3(0, 0.90, 0.82))
	tail.rotation_degrees.x = -42.0
	_sphere(self, 0.07, mane, Vector3(0, 1.04, 0.94), Vector3.ONE)
	_add_four_legs(fur, mane, 0.58, 0.36, 0.52)


func _build_wolf() -> void:
	var fur := Toon.make_material(Color(0.42, 0.46, 0.44), true, 0.014)
	var light := Toon.make_material(Color(0.70, 0.72, 0.65), true, 0.01)
	var dark := Toon.make_material(Color(0.12, 0.14, 0.14), true, 0.008)
	_sphere(self, 0.42, fur, Vector3(0, 0.82, 0.0), Vector3(0.85, 0.82, 1.55))
	var neck := _capsule(self, 0.25, 0.78, fur, Vector3(0, 1.04, -0.58))
	neck.rotation_degrees.x = 55.0
	_sphere(self, 0.31, fur, Vector3(0, 1.24, -0.82), Vector3(1.0, 0.95, 1.1))
	_sphere(self, 0.18, light, Vector3(0, 1.12, -1.12), Vector3(1.0, 0.7, 1.45))
	_sphere(self, 0.075, dark, Vector3(0, 1.14, -1.34), Vector3.ONE)
	for sx in [-1.0, 1.0]:
		var ear := _part(Vector3(0.16, 0.42, 0.10), fur, Vector3(sx * 0.22, 1.59, -0.83), self)
		ear.rotation_degrees.z = sx * -10.0
		_sphere(self, 0.035, dark, Vector3(sx * 0.12, 1.31, -1.08), Vector3.ONE)
	_add_four_legs(fur, dark, 0.64, 0.28, 0.58)
	var tail := _capsule(self, 0.13, 1.0, fur, Vector3(0, 0.96, 0.96))
	tail.rotation_degrees.x = -58.0


func _build_bear() -> void:
	var fur := Toon.make_material(Color(0.29, 0.18, 0.105), true, 0.02)
	var muzzle := Toon.make_material(Color(0.58, 0.42, 0.26), true, 0.012)
	var dark := Toon.make_material(Color(0.07, 0.055, 0.045), true, 0.008)
	_sphere(self, 0.84, fur, Vector3(0, 1.18, 0.15), Vector3(1.0, 1.08, 1.25))
	_sphere(self, 0.57, fur, Vector3(0, 1.62, -0.72), Vector3(1.0, 1.0, 1.05))
	_sphere(self, 0.31, muzzle, Vector3(0, 1.46, -1.18), Vector3(1.2, 0.72, 1.15))
	_sphere(self, 0.10, dark, Vector3(0, 1.58, -1.45), Vector3(1.1, 0.7, 0.8))
	for sx in [-1.0, 1.0]:
		_sphere(self, 0.20, fur, Vector3(sx * 0.45, 2.04, -0.67), Vector3.ONE)
		_sphere(self, 0.045, dark, Vector3(sx * 0.20, 1.73, -1.12), Vector3.ONE)
	_sphere(self, 0.16, fur, Vector3(0, 1.30, 1.22), Vector3.ONE)
	_add_four_legs(fur, dark, 0.78, 0.44, 0.72)


func _build_bird() -> void:
	var blue := Toon.make_material(Color(0.16, 0.43, 0.60), true, 0.008)
	var cream := Toon.make_material(Color(0.90, 0.78, 0.50), true, 0.006)
	var dark := Toon.make_material(Color(0.08, 0.10, 0.12), true, 0.004)
	_sphere(self, 0.22, blue, Vector3.ZERO, Vector3(0.9, 0.85, 1.3))
	_sphere(self, 0.16, blue, Vector3(0, 0.13, -0.28), Vector3.ONE)
	var beak := _part(Vector3(0.09, 0.07, 0.28), cream, Vector3(0, 0.10, -0.48), self)
	beak.rotation_degrees.x = 8.0
	for sx in [-1.0, 1.0]:
		_sphere(self, 0.028, dark, Vector3(sx * 0.10, 0.18, -0.40), Vector3.ONE)
		var wing := Node3D.new()
		wing.position = Vector3(sx * 0.18, 0.02, 0)
		add_child(wing)
		_wings.append(wing)
		var feather := _part(Vector3(0.78, 0.045, 0.34), blue, Vector3(sx * 0.36, 0, 0.08), wing)
		feather.rotation_degrees.y = sx * -12.0
	for i in range(3):
		var tail := _part(Vector3(0.10, 0.035, 0.52), blue, Vector3((i - 1) * 0.09, 0, 0.47), self)
		tail.rotation_degrees.x = -8.0


func _add_four_legs(mat: Material, hoof: Material, y: float, x: float, z: float) -> void:
	for sx in [-x, x]:
		for sz in [-z, z]:
			var leg := Node3D.new()
			leg.position = Vector3(sx, y, sz)
			add_child(leg)
			_legs.append(leg)
			var leg_h := 0.62 if species != "bear" else 0.82
			_capsule(leg, 0.105 if species != "bear" else 0.17, leg_h, mat, Vector3(0, -0.30, 0))
			var hoof_size := Vector3(0.17, 0.10, 0.19) if species != "bear" else Vector3(0.26, 0.13, 0.28)
			_part(hoof_size, hoof, Vector3(0, -0.25 - leg_h * 0.5, -0.03), leg)


func _part(size: Vector3, mat: Material, pos: Vector3, parent: Node3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi


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


func _capsule(parent: Node3D, radius: float, height: float, mat: Material, pos: Vector3) -> MeshInstance3D:
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


func get_hit_part(shape_idx: int) -> String:
	return "head" if shape_idx == 1 else "body"


func take_damage(amount: float, from: Variant = null, _part_name: String = "body") -> void:
	if not alive:
		return
	hp -= amount
	if is_inside_tree() and get_tree() != null and get_tree().current_scene != null:
		DamageNumber.spawn_at(get_tree().current_scene, global_position + Vector3(0, 1.4, 0), str(int(amount)), Color(1.0, 0.85, 0.25))
	_play(&"hit")
	_anim_hold = 0.30
	if from == player and species != "bird" and is_instance_valid(player) and from != null:
		_move_target = player.global_position
	if hp <= 0.0:
		_die(from)


func _die(from: Variant) -> void:
	alive = false
	if from and from.get("kills") != null:
		from.kills += 1
	if from and from.has_method("give_rupees"):
		from.give_rupees(5 if species == "bear" else 2 if species == "wolf" else 1)
	var meat_count := 1 if species == "bird" else 4 if species == "bear" else 2
	Loot.spawn(get_tree().current_scene, global_position + Vector3(0, 0.25, 0), "meat", "", meat_count, 1)
	collision_layer = 0
	collision_mask = 0
	if _ap and _ap.has_animation(&"die"):
		_play(&"die")
	else:
		# // FIX: DIE 无死亡剪辑时侧躺倒地（原停在站姿=“卡住”），0.9s 后回收
		var tw_d := create_tween()
		tw_d.tween_property(self, "rotation:x", -PI * 0.5, 0.35).set_trans(Tween.TRANS_SINE)
		tw_d.parallel().tween_property(self, "position:y", global_position.y - 0.25, 0.35)
	await get_tree().create_timer(0.9).timeout
	if is_inside_tree() and not is_queued_for_deletion():
		queue_free()


func _physics_process(delta: float) -> void:
	_call_cd -= delta
	if not alive:
		return
	if terrain == null or player == null or not is_instance_valid(player) or not is_instance_valid(terrain):
		return
	var distance := global_position.distance_to(player.global_position)
	var interval := _get_ai_interval(distance)
	_apply_lod(distance)
	if _ai_timer > interval:
		_ai_timer = interval
	_ai_timer -= delta
	var do_ai := _ai_timer <= 0.0
	if do_ai:
		_ai_timer = interval
		if _call_cd <= 0.0:
			_call_cd = randf_range(8.0, 20.0)
			var sname := "animal_pig"
			if species == "wolf":
				sname = "animal_wolf"
			elif species == "bear":
				sname = "animal_bear"
			elif species == "bird":
				sname = "animal_bird"
			if is_instance_valid(player) and global_position.distance_to(player.global_position) < 60.0:
				var sfx := get_tree().get_first_node_in_group("sfx_bank")
				if sfx:
					sfx.play_at(sname, global_position, -10.0, randf_range(0.9, 1.1))
	if species == "bird":
		_update_bird(delta, distance, interval, do_ai)
		return
	_attack_cooldown = maxf(0.0, _attack_cooldown - delta)
	_anim_time += delta
	var is_far := distance > 80.0
	var pack_near := _cached_pack_near
	var night := _cached_night
	var aggressive := _cached_aggressive
	if do_ai:
		pack_near = false
		if species == "wolf":
			for other in get_tree().get_nodes_in_group("wildlife"):
				if other != self and is_instance_valid(other) and other.alive and other.species == "wolf" and other.global_position.distance_to(global_position) < 18.0:
					pack_near = true
					break
		night = false
		var scene := get_tree().current_scene
		if scene and scene.get("daynight") != null:
			night = scene.daynight.is_night()
		aggressive = (species == "bear" and distance < 18.0) or (species == "wolf" and ((pack_near and distance < 24.0) or distance < 10.0 or (night and distance < 18.0)))
		_cached_pack_near = pack_near
		_cached_night = night
		_cached_aggressive = aggressive
	var notice_radius := 12.0 if species == "boar" else 18.0 if species == "wolf" else 14.0
	if distance > 26.0:
		_alerted = false
	if do_ai and not _alerted and not aggressive and distance < notice_radius and _alert_left < 0.0:
		_alert_left = randf_range(0.9, 1.4)
		_alerted = true
		DamageNumber.spawn_at(get_tree().current_scene, global_position + Vector3(0, 1.6 if species != "bear" else 2.4, 0), "!", Color(1.0, 1.0, 1.0))
	if _alert_left >= 0.0:
		_alert_left -= delta
		var to_player := (player.global_position - global_position)
		to_player.y = 0.0
		if to_player.length_squared() > 0.01:
			rotation.y = lerp_angle(rotation.y, atan2(to_player.normalized().x, to_player.normalized().z) + PI, delta * 10.0)
		velocity.x = 0.0
		velocity.z = 0.0
		velocity.y = -4.0
		move_and_slide()
		if terrain:
			global_position.y = terrain.get_height(global_position.x, global_position.z) + 0.05
		rotation.x = lerpf(rotation.x, -0.14, delta * 8.0)
		if _alert_left < 0.0 and aggressive:
			_move_target = player.global_position
		return
	rotation.x = lerpf(rotation.x, 0.0, delta * 6.0)
	_think_time -= delta
	_flee_lock = maxf(0.0, _flee_lock - delta)  # // FIX: FLEE
	if _think_time < 0.0:
		_think_time = 0.0
	if do_ai and _think_time <= 0.0:
		_think_time = randf_range(1.2, 2.8)
		if aggressive:
			_move_target = player.global_position
		elif distance < 15.0:
			# // FIX: FLEE 逃跑方向一次确定并锁 4s（玩家移动不再导致每周期乱转向）；目标钳在 home 60m 内避免越逃越远
			if _flee_lock <= 0.0 or _move_target.distance_to(global_position) < 2.0:
				var flee_dir := (global_position - player.global_position)
				flee_dir.y = 0.0
				if flee_dir.length_squared() < 0.01:
					flee_dir = Vector3(randf_range(-1,1), 0, randf_range(-1,1))
				flee_dir = flee_dir.normalized()
				var cand := global_position + flee_dir * randf_range(20.0, 30.0)
				var to_home := cand - _home
				if to_home.length() > 60.0:
					cand = _home + to_home.normalized() * 55.0
				_move_target = cand
				_flee_lock = 4.0
		else:
			_move_target = _home + Vector3(randf_range(-18, 18), 0, randf_range(-18, 18))
	var direction := _move_target - global_position
	direction.y = 0.0
	var move_speed := 0.0
	if direction.length() > 1.0:
		direction = direction.normalized()
		move_speed = 7.2 if aggressive else 4.5 if species == "wolf" else 3.5
		var next := global_position + direction * move_speed * delta
		if terrain.is_in_water(next.x, next.z):
			direction = direction.rotated(Vector3.UP, 1.5)
		velocity.x = direction.x * move_speed
		velocity.z = direction.z * move_speed
		var yaw := atan2(direction.x, direction.z) + PI
		rotation.y = lerp_angle(rotation.y, yaw, delta * 7.0)
	else:
		velocity.x = move_toward(velocity.x, 0.0, delta * 10.0)
		velocity.z = move_toward(velocity.z, 0.0, delta * 10.0)
	velocity.y = -4.0
	if terrain and species != "bird":
		var next := global_position + Vector3(velocity.x, 0, velocity.z) * delta * 2.0
		if terrain.is_in_water(next.x, next.z) and terrain.get_height(next.x, next.z) < Terrain.WATER_LEVEL - 0.3:
			velocity.x = 0.0
			velocity.z = 0.0
	move_and_slide()
	if terrain:
		global_position.y = terrain.get_height(global_position.x, global_position.z) + 0.05
	if aggressive and distance < (2.2 if species == "bear" else 1.6) and _attack_cooldown <= 0.0 and is_instance_valid(player) and player.alive:
		player.take_damage(22.0 if species == "bear" else 11.0, self)
		_attack_cooldown = 1.15
		_play(&"attack")
		_anim_hold = 0.5
	var horiz_speed := Vector2(velocity.x, velocity.z).length()
	if _ap != null and _ap.active:
		_anim_hold = maxf(0.0, _anim_hold - delta)
		if _anim_hold <= 0.0:
			if horiz_speed > 0.3:
				if _ap.has_animation(&"run") and horiz_speed > 4.2:
					if _cur_anim != &"run":
						_play(&"run")
					if _cur_anim == &"run":
						_ap.speed_scale = clampf(horiz_speed / 5.5, 0.8, 1.6)
				else:
					if _cur_anim != &"walk":
						_play(&"walk")
					if _cur_anim == &"walk":
						_ap.speed_scale = clampf(horiz_speed / 3.2, 0.7, 1.6)
			else:
				if _cur_anim != &"idle":
					_play(&"idle")
				if _ap:
					_ap.speed_scale = 1.0
	else:
		_anim_hold = maxf(0.0, _anim_hold - delta)
		if _ap == null and not is_far:
			var stride := clampf(horiz_speed / 7.0, 0.0, 1.0) * 0.65
			for i in range(_legs.size()):
				_legs[i].rotation.x = sin(_anim_time * 9.0 + (0.0 if i in [0, 3] else PI)) * stride


func _update_bird(delta: float, distance: float = -1.0, _interval: float = 0.08, do_ai: bool = true) -> void:
	var dist := distance
	if dist < 0.0 and is_instance_valid(player):
		dist = global_position.distance_to(player.global_position)
	var is_far := dist > 80.0
	if do_ai:
		_think_time -= delta
		if _think_time <= 0.0:
			_think_time = randf_range(2.0, 4.0)
			if is_instance_valid(player):
				var away := (global_position - player.global_position).normalized() if global_position.distance_to(player.global_position) < 14.0 else Vector3.ZERO
				_move_target = _home + Vector3(randf_range(-25, 25), randf_range(6, 13), randf_range(-25, 25)) + away * 20.0
			else:
				_move_target = _home + Vector3(randf_range(-25, 25), randf_range(6, 13), randf_range(-25, 25))
	else:
		_think_time -= delta
	var direction := (_move_target - global_position).normalized()
	velocity = velocity.lerp(direction * 8.5, delta * 2.2)
	move_and_slide()
	if terrain:
		global_position.y = maxf(global_position.y, terrain.get_height(global_position.x, global_position.z) + 2.0)
	if velocity.length_squared() > 0.1:
		var forward := velocity.normalized()
		if absf(forward.dot(Vector3.UP)) < 0.98:
			look_at(global_position + velocity, Vector3.UP)
	if _ap != null and _ap.active:
		_anim_time += delta
		_anim_hold = maxf(0.0, _anim_hold - delta)
		if _anim_hold <= 0.0:
			var horiz := Vector2(velocity.x, velocity.z).length()
			if horiz > 0.3:
				if _ap.has_animation(&"run") and horiz > 4.5:
					if _cur_anim != &"run":
						_play(&"run")
					if _cur_anim == &"run":
						_ap.speed_scale = clampf(horiz / 5.5, 0.8, 1.6)
				else:
					if _cur_anim != &"walk":
						_play(&"walk")
					if _cur_anim == &"walk":
						_ap.speed_scale = clampf(horiz / 3.2, 0.7, 1.6)
			else:
				if _cur_anim != &"idle":
					_play(&"idle")
				if _ap:
					_ap.speed_scale = 1.0
	elif _ap == null and not is_far:
		_anim_time += delta
		for i in range(_wings.size()):
			_wings[i].rotation.z = sin(_anim_time * 13.0) * 0.75 * (-1.0 if i == 0 else 1.0)