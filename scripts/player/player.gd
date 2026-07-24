class_name Player
extends CharacterBody3D
## FPS 玩家：移动/视角/空降/伤害/武器槽/拾取

signal died(victim, killer)
signal health_changed(hp: float, armor: float)
signal damaged(amount: float)
signal landed
signal grenade_thrown(left: int)
signal backpack_changed

const WALK_SPEED := 5.5
const SPRINT_SPEED := 8.6
const ACCEL := 30.0
const AIR_ACCEL := 14.0
const GRAVITY := 22.0
const JUMP_VEL := 7.6
const MOUSE_SENS := 0.0022
const MAX_HP := 100.0
const INTERACT_DIST := 3.4
const SWIM_SPEED := 4.8
const GLIDE_SPEED := 8.2
const GLIDE_FALL_SPEED := 3.1

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
var terrain: Terrain
var hud: HUD
var pitch := 0.0
var weapon_slots: Array[String] = []
var slot_index := -1
var mags := {}
var reserves := {}
var nearby_loot: Loot = null
var nearby_vehicle: Node = null
var input_locked := false    # 结算画面锁定：禁止点击重捕获鼠标
var debug_move := 0.0        # 自动化测试用：强制前进输入
var debug_glide := false     # 自动化测试用：强制展开斗篷
var prone := false           # 趴下：更慢更稳
var vehicle: Node = null     # 吉普/马/摩托共用骑乘接口
var smoke_count := 3
var is_swimming := false
var is_gliding := false
var backpack_open := false
var backpack_index := 0
var backpack_weapons: Array[Dictionary] = []
var backpack_items := {"mushroom": 0, "meat": 0, "dragon_scale": 0}
var _ladder: Area3D = null
var _col: CollisionShape3D
var _glider: Node3D


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
	_build_glider()

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
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_B:
			_toggle_backpack()
			get_viewport().set_input_as_handled()
			return
		if backpack_open:
			match event.physical_keycode:
				KEY_UP, KEY_W:
					backpack_index = posmod(backpack_index - 1, maxi(1, _backpack_entry_count()))
					_refresh_backpack()
				KEY_DOWN, KEY_S:
					backpack_index = posmod(backpack_index + 1, maxi(1, _backpack_entry_count()))
					_refresh_backpack()
				KEY_ENTER, KEY_E:
					_use_backpack_selection()
				KEY_X:
					_store_current_weapon()
				KEY_ESCAPE:
					_toggle_backpack()
			get_viewport().set_input_as_handled()
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
	if backpack_open:
		velocity.x = move_toward(velocity.x, 0.0, delta * ACCEL)
		velocity.z = move_toward(velocity.z, 0.0, delta * ACCEL)
		if not is_on_floor():
			velocity.y = maxf(velocity.y - GRAVITY * delta, -20.0)
		move_and_slide()
		return
	# 趴下时相机压低
	camera.position.y = lerpf(camera.position.y, 0.55 if prone else 1.58, delta * 8.0)
	var f := float(Input.is_key_pressed(KEY_W)) - float(Input.is_key_pressed(KEY_S))
	if debug_move != 0.0:
		f = debug_move
	var r := float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A))
	var wish := (global_transform.basis * Vector3(r, 0.0, -f))
	wish.y = 0.0
	wish = wish.normalized()

	var water_now := terrain != null and terrain.is_in_water(global_position.x, global_position.z) and global_position.y < terrain.get_water_level(global_position.x, global_position.z) + 0.9
	if water_now:
		_update_swimming(delta, wish)
		return
	if is_swimming:
		is_swimming = false

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
		var wants_glide := is_dropping and (Input.is_key_pressed(KEY_SPACE) or debug_glide) and velocity.y < -0.4
		_set_gliding(wants_glide)
		if is_gliding:
			var glide_target := wish * GLIDE_SPEED
			var glide_h := Vector3(velocity.x, 0, velocity.z).move_toward(glide_target, AIR_ACCEL * 0.75 * delta)
			velocity.x = glide_h.x
			velocity.z = glide_h.z
			velocity.y = move_toward(velocity.y, -GLIDE_FALL_SPEED, GRAVITY * 1.5 * delta)
			velocity.y = maxf(velocity.y, -GLIDE_FALL_SPEED)
		else:
			velocity.y = maxf(velocity.y - GRAVITY * delta, -30.0)

	move_and_slide()
	if is_on_floor() and is_gliding:
		_set_gliding(false)

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
	for candidate in get_tree().get_nodes_in_group("vehicle"):
		var v: Node = candidate
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
		# 装备栏已满时收入背包，避免拾取新装备时无提示覆盖当前武器。
		backpack_weapons.append({"id": id, "mag": Weapon.WEAPONS[id].mag, "reserve": Weapon.WEAPONS[id].start_reserve})
		backpack_changed.emit()
		_refresh_backpack()


func give_ammo(amount: int) -> void:
	for id in weapon_slots:
		reserves[id] = reserves.get(id, 0) + amount
	if slot_index >= 0:
		weapon.reserve = reserves[weapon_slots[slot_index]]
		weapon.ammo_changed.emit(weapon.mag_left, weapon.reserve)


func give_item(kind: String, amount: int) -> void:
	if not backpack_items.has(kind):
		backpack_items[kind] = 0
	backpack_items[kind] = int(backpack_items[kind]) + amount
	backpack_changed.emit()
	_refresh_backpack()


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


# ---------- 游泳 / 滑翔 ----------

func _update_swimming(delta: float, wish: Vector3) -> void:
	if is_gliding:
		_set_gliding(false)
	if is_dropping:
		is_dropping = false
		landed.emit()
	is_swimming = true
	prone = false
	var surface := terrain.get_water_level(global_position.x, global_position.z)
	var swim_speed := SWIM_SPEED * (1.18 if Input.is_key_pressed(KEY_SHIFT) else 1.0)
	var target_h := wish * swim_speed
	var hv := Vector3(velocity.x, 0, velocity.z).move_toward(target_h, 12.0 * delta)
	velocity.x = hv.x
	velocity.z = hv.z
	var vertical_input := float(Input.is_key_pressed(KEY_SPACE)) - float(Input.is_key_pressed(KEY_C))
	if absf(vertical_input) > 0.01:
		velocity.y = move_toward(velocity.y, vertical_input * 3.2, 9.0 * delta)
	else:
		# 角色原点在脚底附近，让相机稳定露出水面而身体保留在水中。
		var target_y := surface - 1.18
		velocity.y = clampf((target_y - global_position.y) * 4.5, -2.5, 2.5)
	move_and_slide()


func _set_gliding(enabled: bool) -> void:
	is_gliding = enabled
	if _glider:
		_glider.visible = enabled


func _build_glider() -> void:
	_glider = Node3D.new()
	_glider.name = "Paraglider"
	_glider.position = Vector3(0, 2.45, 0.35)
	_glider.visible = false
	add_child(_glider)
	var cloth := Toon.make_material(Color(0.88, 0.67, 0.22), true, 0.01)
	var trim := Toon.make_material(Color(0.18, 0.42, 0.48), true, 0.008)
	var rope := Toon.make_material(Color(0.24, 0.17, 0.10), false)
	for i in range(7):
		var panel := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.92, 0.10, 1.35)
		panel.mesh = mesh
		panel.material_override = cloth if i % 2 == 0 else trim
		panel.position = Vector3((i - 3) * 0.72, -absf(float(i - 3)) * 0.11, 0)
		panel.rotation_degrees.z = float(i - 3) * -5.5
		_glider.add_child(panel)
	for sx in [-1.0, 1.0]:
		for z in [-0.45, 0.45]:
			var line := MeshInstance3D.new()
			var line_mesh := CylinderMesh.new()
			line_mesh.top_radius = 0.012
			line_mesh.bottom_radius = 0.012
			line_mesh.height = 2.5
			line_mesh.radial_segments = 5
			line.mesh = line_mesh
			line.material_override = rope
			line.position = Vector3(sx * 1.9, -1.05, z)
			line.rotation_degrees.z = sx * 28.0
			_glider.add_child(line)


# ---------- 背包 ----------

func _toggle_backpack() -> void:
	backpack_open = not backpack_open
	if backpack_open:
		backpack_index = clampi(backpack_index, 0, maxi(0, _backpack_entry_count() - 1))
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_refresh_backpack()
	elif hud:
		hud.hide_backpack()
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _backpack_entry_count() -> int:
	return backpack_weapons.size() + 3


func _refresh_backpack() -> void:
	if backpack_open and hud:
		hud.show_backpack(get_backpack_lines(), backpack_index)


func get_backpack_lines() -> Array[String]:
	var lines: Array[String] = []
	for packed in backpack_weapons:
		var id: String = packed["id"]
		lines.append("装备 · %s  %d/%d" % [Weapon.WEAPONS[id].label, int(packed["mag"]), int(packed["reserve"])])
	lines.append("食材 · 海拉鲁蘑菇 × %d（回血 18）" % int(backpack_items["mushroom"]))
	lines.append("食材 · 兽肉 × %d（回血 30）" % int(backpack_items["meat"]))
	lines.append("珍品 · 龙鳞 × %d（护甲 35）" % int(backpack_items["dragon_scale"]))
	return lines


func _use_backpack_selection() -> void:
	if backpack_index < backpack_weapons.size():
		_retrieve_weapon(backpack_index)
		return
	var item_index := backpack_index - backpack_weapons.size()
	var key: String = ["mushroom", "meat", "dragon_scale"][item_index]
	var count := int(backpack_items[key])
	if count <= 0:
		return
	backpack_items[key] = count - 1
	if key == "dragon_scale":
		armor = minf(100.0, armor + 35.0)
	else:
		hp = minf(MAX_HP, hp + (18.0 if key == "mushroom" else 30.0))
	health_changed.emit(hp, armor)
	backpack_changed.emit()
	_refresh_backpack()


func _store_current_weapon() -> void:
	if slot_index < 0 or weapon.weapon_id == "":
		return
	var old_slot := slot_index
	var id := weapon_slots[old_slot]
	backpack_weapons.append({"id": id, "mag": weapon.mag_left, "reserve": weapon.reserve})
	weapon_slots.remove_at(old_slot)
	if weapon_slots.is_empty():
		slot_index = -1
		weapon.set_weapon("")
	else:
		slot_index = -1
		switch_slot(mini(old_slot, weapon_slots.size() - 1))
	backpack_index = backpack_weapons.size() - 1
	backpack_changed.emit()
	_refresh_backpack()


func _retrieve_weapon(index: int) -> void:
	if index < 0 or index >= backpack_weapons.size():
		return
	var packed: Dictionary = backpack_weapons[index]
	backpack_weapons.remove_at(index)
	var id: String = packed["id"]
	if id in weapon_slots:
		reserves[id] = int(reserves.get(id, 0)) + int(packed["reserve"])
		switch_slot(weapon_slots.find(id))
		weapon.reserve = reserves[id]
		weapon.ammo_changed.emit(weapon.mag_left, weapon.reserve)
	elif weapon_slots.size() < 2:
		weapon_slots.append(id)
		mags[id] = int(packed["mag"])
		reserves[id] = int(packed["reserve"])
		switch_slot(weapon_slots.size() - 1)
	else:
		var current_id := weapon_slots[slot_index]
		backpack_weapons.append({"id": current_id, "mag": weapon.mag_left, "reserve": weapon.reserve})
		weapon_slots[slot_index] = id
		mags[id] = int(packed["mag"])
		reserves[id] = int(packed["reserve"])
		weapon.set_weapon(id, mags[id], reserves[id])
	backpack_index = clampi(backpack_index, 0, maxi(0, _backpack_entry_count() - 1))
	backpack_changed.emit()
	_refresh_backpack()
