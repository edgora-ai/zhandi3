class_name Player
extends CharacterBody3D
## FPS 玩家：移动/视角/空降/伤害/武器槽/拾取

signal died(victim, killer)
signal health_changed(hp: float, armor: float)
signal damaged(amount: float)
signal landed
signal grenade_thrown(left: int)

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
var nearby_vehicle: Vehicle = null
var input_locked := false    # 结算画面锁定：禁止点击重捕获鼠标
var debug_move := 0.0        # 自动化测试用：强制前进输入
var prone := false           # 趴下：更慢更稳
var vehicle: Vehicle = null  # 驾驶中
var smoke_count := 3
var _ladder: Area3D = null
var _col: CollisionShape3D


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
	_col = col

	# 梯子探测
	var det := Area3D.new()
	var dc := CollisionShape3D.new()
	var ds := SphereShape3D.new()
	ds.radius = 0.9
	dc.shape = ds
	dc.position.y = 1.0
	det.add_child(dc)
	add_child(det)
	det.area_entered.connect(func(a: Area3D) -> void:
		if a.is_in_group("ladder"):
			_ladder = a
	)
	det.area_exited.connect(func(a: Area3D) -> void:
		if a == _ladder:
			_ladder = null
	)

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
		if vehicle and event.physical_keycode != KEY_F:
			return  # 驾驶中只响应下车
		match event.physical_keycode:
			KEY_ESCAPE:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED
			KEY_R:
				weapon.start_reload()
			KEY_E:
				_try_pickup()
			KEY_C:
				_toggle_prone()
			KEY_G:
				_throw_smoke()
			KEY_F:
				_toggle_vehicle()
			KEY_1:
				switch_slot(0)
			KEY_2:
				switch_slot(1)


func _toggle_prone() -> void:
	prone = not prone
	if prone:
		_col.shape.height = 0.9
		_col.position.y = 0.45
	else:
		_col.shape.height = 1.7
		_col.position.y = 0.85


func _throw_smoke() -> void:
	if smoke_count <= 0:
		return
	smoke_count -= 1
	var g := SmokeGrenade.new()
	get_parent().add_child(g)
	var dir := get_aim_dir()
	g.global_position = camera.global_position + dir * 0.6 - Vector3(0, 0.1, 0)
	g.linear_velocity = dir * 13.0 + Vector3(0, 3.5, 0)
	grenade_thrown.emit(smoke_count)


func _toggle_vehicle() -> void:
	if vehicle:
		vehicle.exit()
	elif nearby_vehicle:
		nearby_vehicle.enter(self)


func _physics_process(delta: float) -> void:
	if not alive:
		return
	if vehicle:
		return  # 驾驶中：移动由车辆接管
	# 趴下时相机压低
	camera.position.y = lerpf(camera.position.y, 0.55 if prone else 1.58, delta * 8.0)
	var f := float(Input.is_key_pressed(KEY_W)) - float(Input.is_key_pressed(KEY_S))
	if debug_move != 0.0:
		f = debug_move
	var r := float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A))
	var wish := (global_transform.basis * Vector3(r, 0.0, -f))
	wish.y = 0.0
	wish = wish.normalized()

	var speed := WALK_SPEED
	if Input.is_key_pressed(KEY_SHIFT) and f > 0.0 and not weapon.is_ads and not prone:
		speed = SPRINT_SPEED
	if weapon.is_ads:
		speed *= 0.55
	if prone:
		speed *= 0.35

	var accel := ACCEL if is_on_floor() else AIR_ACCEL
	var hv := Vector3(velocity.x, 0.0, velocity.z)
	hv = hv.move_toward(wish * speed, accel * delta)
	velocity.x = hv.x
	velocity.z = hv.z

	if _ladder and f > 0.0:
		# 攀爬：W 沿梯子上升
		velocity.y = 3.2
	elif _ladder:
		velocity.y = 0.0
	elif is_on_floor():
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
	nearby_vehicle = null
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
	var best_v := 4.0
	for v in get_tree().get_nodes_in_group("vehicle"):
		var d := global_position.distance_to(v.global_position)
		if d < best_v:
			best_v = d
			nearby_vehicle = v


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
