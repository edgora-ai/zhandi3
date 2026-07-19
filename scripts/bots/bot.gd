class_name Bot
extends CharacterBody3D
## AI 战士：空降 → 搜刮 → 跑圈/占点 → 交战。贴地移动 + 简单避障，无限后备弹药

signal died(victim, killer)

enum State { DROP, LOOT, ROTATE, FIGHT, CAPTURE }

const MAX_HP := 100.0
const WALK := 4.2
const RUN := 6.4
const GRAVITY := 22.0
const SIGHT_RANGE := 65.0
const FIGHT_DIST := 20.0

var hp := MAX_HP
var armor := 0.0
var alive := true
var damage_mult := 1.0
var regen_rate := 0.0
var display_name := "Bot"
var kills := 0
var skill := 1.0               # 越大越准（误差乘数）
var zone: Zone
var terrain: Terrain

var state := State.DROP
var weapon: Weapon
var move_target := Vector3.ZERO
var aim_target: CharacterBody3D = null
var target_loot: Loot = null
var capture_goal: CapturePoint = null

var _think := 0.0
var _lose_sight := 0.0
var _burst_left := 0
var _burst_pause := 0.0
var _strafe_dir := 1.0
var _head_index := 1
var _corpse_t := -1.0


func setup(p_name: String, p_zone: Zone, p_terrain: Terrain, drop_to: Vector3) -> void:
	display_name = p_name
	zone = p_zone
	terrain = p_terrain
	move_target = drop_to
	skill = randf_range(0.7, 1.5)


func _ready() -> void:
	add_to_group("combatant")
	collision_layer = 4
	collision_mask = 1 | 2 | 4
	var body_col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.36
	cap.height = 1.45
	body_col.shape = cap
	body_col.position.y = 0.72
	add_child(body_col)
	var head_col := CollisionShape3D.new()
	var hs := SphereShape3D.new()
	hs.radius = 0.26
	head_col.shape = hs
	head_col.position.y = 1.56
	add_child(head_col)
	_head_index = head_col.get_index()
	_build_visual()

	weapon = Weapon.new()
	add_child(weapon)
	weapon.setup(self, false)
	weapon.set_weapon("")
	_think = randf() * 0.3


func _build_visual() -> void:
	var palette := [Color(0.55, 0.35, 0.20), Color(0.40, 0.45, 0.30), Color(0.30, 0.35, 0.50), Color(0.50, 0.25, 0.25), Color(0.45, 0.40, 0.25), Color(0.35, 0.45, 0.48)]
	var jacket: Color = palette[randi_range(0, palette.size() - 1)]

	var body := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = 0.34
	cm.height = 1.15
	cm.radial_segments = 8
	body.mesh = cm
	body.material_override = Toon.make_material(jacket, true, 0.015)
	body.position.y = 0.82
	add_child(body)

	var head := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.23
	sm.height = 0.42
	sm.radial_segments = 8
	sm.rings = 4
	head.mesh = sm
	head.material_override = Toon.make_material(Color(0.87, 0.70, 0.55), true, 0.015)
	head.position.y = 1.56
	add_child(head)

	var helmet := MeshInstance3D.new()
	var hm := SphereMesh.new()
	hm.radius = 0.26
	hm.height = 0.34
	hm.radial_segments = 8
	hm.rings = 4
	helmet.mesh = hm
	helmet.material_override = Toon.make_material(jacket.darkened(0.35), true, 0.015)
	helmet.position.y = 1.64
	add_child(helmet)

	var gun := MeshInstance3D.new()
	var gb := BoxMesh.new()
	gb.size = Vector3(0.08, 0.12, 0.62)
	gun.mesh = gb
	gun.material_override = Toon.make_material(Color(0.14, 0.15, 0.17), true, 0.008)
	gun.position = Vector3(0.32, 1.22, -0.22)
	add_child(gun)


func get_aim_origin() -> Vector3:
	return global_position + Vector3(0, 1.5, 0)


func get_aim_dir() -> Vector3:
	if aim_target and aim_target.alive:
		var chest: Vector3 = aim_target.global_position + Vector3(0, 1.1, 0)
		var d: Vector3 = (chest - get_aim_origin()).normalized()
		var dist := get_aim_origin().distance_to(chest)
		var e := deg_to_rad(1.8 * skill * (1.0 + dist * 0.015))
		d = d.rotated(Vector3.UP, randf_range(-e, e))
		var side := d.cross(Vector3.UP)
		if side.length() > 0.01:
			d = d.rotated(side.normalized(), randf_range(-e, e) * 0.6)
		return d.normalized()
	return -global_transform.basis.z


func get_hit_part(shape_idx: int) -> String:
	return "head" if shape_idx == _head_index else "body"


func give_weapon(id: String) -> void:
	if weapon.weapon_id != "":
		return
	weapon.set_weapon(id, Weapon.WEAPONS[id].mag, 999)


func give_ammo(_amount: int) -> void:
	weapon.reserve = 999


# ---------- 感知与决策 ----------

func _think_tick() -> void:
	if not alive:
		return
	# 感知最近可见敌人
	var enemy := _find_visible_enemy()
	if enemy:
		if state != State.FIGHT:
			_strafe_dir = 1.0 if randf() < 0.5 else -1.0
		state = State.FIGHT
		aim_target = enemy
		_lose_sight = 0.0
		return
	if state == State.FIGHT:
		_lose_sight += 0.3
		if _lose_sight > 2.5:
			state = State.ROTATE
			aim_target = null
		return

	# 非战斗决策：跑圈 > 找枪 > 占点 > 游荡
	var pos2 := Vector2(global_position.x, global_position.z)
	var outside := zone.active and pos2.distance_to(zone.center) > zone.radius * 0.97
	if outside:
		state = State.ROTATE
		move_target = _random_point_in_zone()
		return
	if weapon.weapon_id == "":
		var loot := _find_nearest_loot("weapon")
		if loot:
			state = State.LOOT
			target_loot = loot
			return
	if state != State.CAPTURE and randf() < 0.15:
		var cp := _find_capture_point()
		if cp:
			state = State.CAPTURE
			capture_goal = cp
			move_target = cp.global_position
			return
	if state == State.LOOT and (target_loot == null or target_loot.consumed):
		state = State.ROTATE
	if state in [State.ROTATE, State.CAPTURE, State.DROP]:
		if global_position.distance_to(move_target) < 3.0 or state == State.DROP:
			# 到达后小范围游荡
			state = State.ROTATE
			move_target = global_position + Vector3(randf_range(-14, 14), 0, randf_range(-14, 14))


func _find_visible_enemy() -> CharacterBody3D:
	var best: CharacterBody3D = null
	var best_d := SIGHT_RANGE
	var eye := get_aim_origin()
	var fwd := -global_transform.basis.z
	for c in get_tree().get_nodes_in_group("combatant"):
		if c == self or not c.alive:
			continue
		var d := global_position.distance_to(c.global_position)
		if d > best_d:
			continue
		var to_c: Vector3 = (c.global_position - global_position).normalized()
		if d > 8.0 and fwd.dot(to_c) < 0.0:
			continue
		var target_eye: Vector3 = c.global_position + Vector3(0, 1.4, 0)
		var query := PhysicsRayQueryParameters3D.create(eye, target_eye, 1 | 2 | 4, [get_rid()])
		var result := get_world_3d().direct_space_state.intersect_ray(query)
		if not result.is_empty() and result.collider == c:
			best = c
			best_d = d
	return best


func _find_nearest_loot(kind: String) -> Loot:
	var best: Loot = null
	var best_d := 90.0
	for item in get_tree().get_nodes_in_group("loot"):
		if item.consumed or item.kind != kind:
			continue
		var d := global_position.distance_to(item.global_position)
		if d < best_d:
			best = item
			best_d = d
	return best


func _find_capture_point() -> CapturePoint:
	var best: CapturePoint = null
	var best_d := 130.0
	for cp in get_tree().get_nodes_in_group("capture_point"):
		if cp.owner_body == self:
			continue
		var d := global_position.distance_to(cp.global_position)
		if d < best_d:
			best = cp
			best_d = d
	return best


func _random_point_in_zone() -> Vector3:
	var ang := randf() * TAU
	var r := randf() * zone.radius * 0.7
	var x: float = zone.center.x + cos(ang) * r
	var z: float = zone.center.y + sin(ang) * r
	return Vector3(x, terrain.get_height(x, z), z)


# ---------- 每帧行为 ----------

func _physics_process(delta: float) -> void:
	if not alive:
		_update_corpse(delta)
		return
	_think -= delta
	if _think <= 0.0:
		_think = 0.3
		_think_tick()

	var move_dir := Vector3.ZERO
	var speed := WALK
	match state:
		State.DROP:
			move_dir = (move_target - global_position)
			move_dir.y = 0
			move_dir = move_dir.normalized()
			speed = 7.0
			if is_on_floor():
				state = State.LOOT
		State.FIGHT:
			move_dir = _fight_move()
			speed = WALK
			_fight_fire(delta)
		State.LOOT:
			if target_loot and not target_loot.consumed:
				move_dir = _seek(target_loot.global_position)
				speed = RUN
				if global_position.distance_to(target_loot.global_position) < 1.8:
					target_loot.apply_to(self)
			else:
				state = State.ROTATE
		State.ROTATE, State.CAPTURE:
			move_dir = _seek(move_target)
			speed = RUN

	if move_dir != Vector3.ZERO:
		move_dir = _avoid_obstacles(move_dir)
	var hv := Vector3(velocity.x, 0, velocity.z)
	hv = hv.move_toward(move_dir * speed, 22.0 * delta)
	velocity.x = hv.x
	velocity.z = hv.z
	if not is_on_floor():
		velocity.y = maxf(velocity.y - GRAVITY * delta, -30.0)
	move_and_slide()

	# 朝向
	var face := move_dir
	if state == State.FIGHT and aim_target:
		face = (aim_target.global_position - global_position)
		face.y = 0
	if face.length_squared() > 0.01:
		var target_yaw: float = atan2(face.normalized().x, face.normalized().z) + PI
		rotation.y = lerp_angle(rotation.y, target_yaw, delta * 8.0)

	if regen_rate > 0.0 and hp < MAX_HP:
		hp = minf(MAX_HP, hp + regen_rate * delta)


func _seek(target: Vector3) -> Vector3:
	var d := target - global_position
	d.y = 0
	if d.length() < 0.5:
		return Vector3.ZERO
	return d.normalized()


func _fight_move() -> Vector3:
	if not aim_target:
		return Vector3.ZERO
	var to_t := aim_target.global_position - global_position
	to_t.y = 0
	var dist := to_t.length()
	var fwd := to_t.normalized()
	var side := fwd.cross(Vector3.UP) * _strafe_dir
	var move := side
	if dist > FIGHT_DIST + 10.0:
		move = (side * 0.6 + fwd * 0.8).normalized()
	elif dist < FIGHT_DIST - 8.0:
		move = (side * 0.6 - fwd * 0.8).normalized()
	if randf() < 0.01:
		_strafe_dir *= -1.0
	return move


func _fight_fire(delta: float) -> void:
	if not aim_target or not aim_target.alive or weapon.weapon_id == "":
		return
	if weapon.mag_left <= 0:
		weapon.start_reload()
		return
	var dist := global_position.distance_to(aim_target.global_position)
	if dist > weapon.data.range * 0.85:
		return
	if _burst_pause > 0.0:
		_burst_pause -= delta
		return
	if _burst_left <= 0:
		_burst_left = randi_range(3, 6)
		_burst_pause = randf_range(0.35, 0.9) * skill
		return
	# 只有大致朝向目标时才开火
	var fwd := -global_transform.basis.z
	var to_t: Vector3 = (aim_target.global_position - global_position).normalized()
	if fwd.dot(to_t) > 0.85:
		weapon.pull_trigger()
		_burst_left -= 1


func _avoid_obstacles(dir: Vector3) -> Vector3:
	var from := global_position + Vector3(0, 0.9, 0)
	if not _blocked(from, dir):
		return dir
	var left := dir.rotated(Vector3.UP, 0.7)
	if not _blocked(from, left):
		return left
	var right := dir.rotated(Vector3.UP, -0.7)
	if not _blocked(from, right):
		return right
	return dir.rotated(Vector3.UP, 1.5)


func _blocked(from: Vector3, dir: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(from, from + dir * 2.2, 1, [get_rid()])
	return not get_world_3d().direct_space_state.intersect_ray(query).is_empty()


# ---------- 伤害与死亡 ----------

func take_damage(amount: float, from: Variant = null, _part: String = "body") -> void:
	if not alive:
		return
	var dmg := amount
	if armor > 0.0:
		var absorbed := minf(armor, dmg * 0.6)
		armor -= absorbed
		dmg -= absorbed
	hp -= dmg
	# 被打会反击：立即察觉攻击者
	if from is CharacterBody3D and from.alive and state != State.FIGHT:
		state = State.FIGHT
		aim_target = from
		_lose_sight = 0.0
	if hp <= 0.0:
		die(from)


func die(from: Variant = null) -> void:
	if not alive:
		return
	alive = false
	hp = 0.0
	if from and from.get("kills") != null:
		from.kills += 1
	_corpse_t = 0.0
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)
	_drop_loot()
	died.emit(self, from)


func _drop_loot() -> void:
	var pos := global_position
	pos.y = terrain.get_height(pos.x, pos.z) + 0.1
	if weapon.weapon_id != "":
		Loot.spawn(get_parent(), pos + Vector3(0.5, 0, 0), "weapon", weapon.weapon_id, 0, 2)
	if randf() < 0.35:
		Loot.spawn(get_parent(), pos + Vector3(-0.5, 0, 0), "medkit", "", 50, 1)


func _update_corpse(delta: float) -> void:
	if _corpse_t < 0.0:
		return
	_corpse_t += delta
	if _corpse_t < 0.4:
		rotation.z = lerp_angle(rotation.z, PI * 0.5, delta * 10.0)
	elif _corpse_t > 6.0:
		position.y -= delta * 0.4
		if _corpse_t > 8.0:
			_corpse_t = -1.0
			queue_free()
