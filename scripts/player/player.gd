class_name Player
extends CharacterBody3D
## FPS 玩家：移动/视角/空降/伤害/武器槽/拾取

signal died(victim, killer)
signal health_changed(hp: float, armor: float)
signal damaged(amount: float)
signal landed

const WALK_SPEED := 5.5
const SPRINT_SPEED := 8.6
const ACCEL := 30.0
const AIR_ACCEL := 14.0
const GRAVITY := 22.0
const JUMP_VEL := 7.6
const MOUSE_SENS := 0.0022
const MAX_HP := 100.0
const INTERACT_DIST := 3.4

var hp := MAX_HP
var armor := 0.0
var alive := true
var damage_mult := 1.0
var regen_rate := 0.0
var display_name := "玩家"
var kills := 0
var is_dropping := true

var camera: Camera3D
var weapon: Weapon
var pitch := 0.0
var weapon_slots: Array[String] = []
var slot_index := -1
var mags := {}
var reserves := {}
var nearby_loot: Loot = null
var input_locked := false    # 结算画面锁定：禁止点击重捕获鼠标
var debug_move := 0.0        # 自动化测试用：强制前进输入


func _ready() -> void:
	add_to_group("combatant")
	collision_layer = 2
	collision_mask = 1 | 4
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.38
	cap.height = 1.7
	col.shape = cap
	col.position.y = 0.85
	add_child(col)

	camera = Camera3D.new()
	camera.position.y = 1.58
	camera.fov = Weapon.BASE_FOV
	camera.far = 1500.0
	camera.current = true
	add_child(camera)

	weapon = Weapon.new()
	camera.add_child(weapon)
	weapon.setup(self, true)

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func add_recoil(deg: float) -> void:
	pitch = clampf(pitch + deg_to_rad(deg), -1.45, 1.45)
	camera.rotation.x = pitch
	rotate_y(randf_range(-0.3, 0.3) * deg_to_rad(deg))


func get_aim_origin() -> Vector3:
	return camera.global_position


func get_aim_dir() -> Vector3:
	return -camera.global_transform.basis.z


func _unhandled_input(event: InputEvent) -> void:
	if not alive:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * MOUSE_SENS)
		pitch = clampf(pitch - event.relative.y * MOUSE_SENS * (0.7 if weapon.is_ads else 1.0), -1.45, 1.45)
		camera.rotation.x = pitch
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
				weapon.pull_trigger()
			elif not input_locked:
				# 捕获丢失（Esc/焦点切换）后点击左键重新捕获，这次点击不开枪
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_ESCAPE:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED
			KEY_R:
				weapon.start_reload()
			KEY_E:
				_try_pickup()
			KEY_1:
				switch_slot(0)
			KEY_2:
				switch_slot(1)


func _physics_process(delta: float) -> void:
	if not alive:
		return
	var f := float(Input.is_key_pressed(KEY_W)) - float(Input.is_key_pressed(KEY_S))
	if debug_move != 0.0:
		f = debug_move
	var r := float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A))
	var wish := (global_transform.basis * Vector3(r, 0.0, -f))
	wish.y = 0.0
	wish = wish.normalized()

	var speed := WALK_SPEED
	if Input.is_key_pressed(KEY_SHIFT) and f > 0.0 and not weapon.is_ads:
		speed = SPRINT_SPEED
	if weapon.is_ads:
		speed *= 0.55

	var accel := ACCEL if is_on_floor() else AIR_ACCEL
	var hv := Vector3(velocity.x, 0.0, velocity.z)
	hv = hv.move_toward(wish * speed, accel * delta)
	velocity.x = hv.x
	velocity.z = hv.z

	if is_on_floor():
		if is_dropping:
			is_dropping = false
			landed.emit()
		if Input.is_key_pressed(KEY_SPACE):
			velocity.y = JUMP_VEL
	else:
		velocity.y = maxf(velocity.y - GRAVITY * delta, -30.0)

	move_and_slide()

	# 占领点回血
	if regen_rate > 0.0 and hp < MAX_HP:
		hp = minf(MAX_HP, hp + regen_rate * delta)
		health_changed.emit(hp, armor)

	# 武器输入（持续按住）
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			weapon.hold_trigger()
		weapon.set_ads(Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT))
	_scan_loot()


func _scan_loot() -> void:
	nearby_loot = null
	var best := INTERACT_DIST
	for item in get_tree().get_nodes_in_group("loot"):
		if item.consumed:
			continue
		var d := global_position.distance_to(item.global_position)
		if d < best:
			# 需在视野前方大致范围内
			var to_item: Vector3 = (item.global_position - camera.global_position).normalized()
			if to_item.dot(get_aim_dir()) > 0.35 or d < 1.6:
				best = d
				nearby_loot = item


func _try_pickup() -> void:
	if nearby_loot and not nearby_loot.consumed:
		nearby_loot.apply_to(self)


func give_weapon(id: String) -> void:
	if id in weapon_slots:
		reserves[id] = reserves.get(id, 0) + Weapon.WEAPONS[id].start_reserve * 0.5
		if weapon_slots[slot_index] == id:
			weapon.reserve = reserves[id]
			weapon.ammo_changed.emit(weapon.mag_left, weapon.reserve)
		return
	if weapon_slots.size() < 2:
		weapon_slots.append(id)
		mags[id] = Weapon.WEAPONS[id].mag
		reserves[id] = Weapon.WEAPONS[id].start_reserve
		switch_slot(weapon_slots.size() - 1)
	else:
		# 替换当前槽
		var cur := slot_index
		weapon_slots[cur] = id
		mags[id] = Weapon.WEAPONS[id].mag
		reserves[id] = Weapon.WEAPONS[id].start_reserve
		switch_slot(cur)


func give_ammo(amount: int) -> void:
	for id in weapon_slots:
		reserves[id] = reserves.get(id, 0) + amount
	if slot_index >= 0:
		weapon.reserve = reserves[weapon_slots[slot_index]]
		weapon.ammo_changed.emit(weapon.mag_left, weapon.reserve)


func switch_slot(i: int) -> void:
	if i < 0 or i >= weapon_slots.size() or i == slot_index:
		return
	if slot_index >= 0:
		mags[weapon_slots[slot_index]] = weapon.mag_left
		reserves[weapon_slots[slot_index]] = weapon.reserve
	slot_index = i
	var id: String = weapon_slots[i]
	weapon.set_weapon(id, mags[id], reserves[id])


func take_damage(amount: float, from: Variant = null, _part: String = "body") -> void:
	if not alive:
		return
	var dmg := amount
	if armor > 0.0:
		var absorbed := minf(armor, dmg * 0.6)
		armor -= absorbed
		dmg -= absorbed
	hp -= dmg
	damaged.emit(dmg)
	health_changed.emit(hp, armor)
	if hp <= 0.0:
		die(from)


func die(from: Variant = null) -> void:
	if not alive:
		return
	alive = false
	hp = 0.0
	if from and from.get("kills") != null:
		from.kills += 1
	died.emit(self, from)
