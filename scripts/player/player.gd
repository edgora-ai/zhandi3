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
const CLIMB_SPEED := 2.6

var max_hp := MAX_HP
var hp := MAX_HP
var armor := 0.0
var stamina := 100.0
var max_stamina := 100.0
var blocking := false
var _block_start := -1.0
var debug_block := false   # 自动化测试用：强制举盾
var parry_count := 0
var dodge_cd := 0.0
var flurry := false
var _bow_draw := 0.0
var _bow: Node3D
var _dodge_iframe_end := -1.0
var _flurry_end_ms := 0
var _surf_notified := false
var _shield: MeshInstance3D
var _shield_root: Node3D
var _stamina_wait := 0.0
var _stamina_used := false
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
var nearby_npc: Node = null
var nearby_fish: Node = null
var nearby_bed: Node = null
var nearby_chest: Node = null
var nearby_beacon: Node = null
var equipped_armor := ""
var damage_taken_mult := 1.0
var climb_speed_mult := 1.0
var climb_stamina_mult := 1.0
var armor_melee_mult := 1.0
var rupees := 0
var shop_open := false
var _elixir_stam_end_ms := 0
var _climb_arms: Node3D
var _climb_arm_l: Node3D
var _climb_arm_r: Node3D
var _glide_arms: Node3D
var _climb_phase := 0.0
var bonded_horse: Horse = null
var input_locked := false    # 结算画面锁定：禁止点击重捕获鼠标
var debug_move := 0.0        # 自动化测试用：强制前进输入
var debug_glide := false     # 自动化测试用：强制展开斗篷
var prone := false           # 趴下：更慢更稳
var vehicle: Node = null     # 吉普/马/摩托共用骑乘接口
var smoke_count := 3
var is_swimming := false
var is_gliding := false
var is_climbing := false
var backpack_open := false
var backpack_index := 0
var backpack_weapons: Array[Dictionary] = []
var backpack_items := {"mushroom": 0, "meat": 0, "dragon_scale": 0, "wood": 0, "roast_meat": 0, "roast_mushroom": 0}
var seed_count := 0
var fairies := 1
var skewer_mult := 1.0
var charm_mult := 1.0
var _skewer_t := 0.0
var _ladder: Area3D = null
var _col: CollisionShape3D
var _glider: Node3D
var _airborne_time := 0.0
var _glider_open := 0.0
var _melee_cd := 0.0
var _combo_i := 0
var _combo_reset_t := 0.0
var _swing_hit_done := false
var _hitstop_end_ms := 0
var _bombs: Array[RemoteBomb] = []
var _bomb_hint_done := false
var _pillars: Array[IcePillar] = []
var _stasis_target: CharacterBody3D = null
var _stasis_end_ms := 0
var _stasis_dmg := 0.0
var _stasis_shell: MeshInstance3D
var _magnet_prop: MetalProp = null
var _magnet_beam: MeshInstance3D
var _magnet_motes: Array[MeshInstance3D] = []
var _swing_t := -1.0
var _sword: Node3D
var _sword_blade: MeshInstance3D
var melee_damage := 26.0


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
	# 允许走上 0.5m 以内的台阶（塔梯/城堡台阶/桥头引桥）。
	floor_snap_length = 0.5

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
	_build_glide_arms()
	_build_sword()
	_build_shield()
	_build_bow()
	_build_climb_arms()

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
		if shop_open:
			match event.physical_keycode:
				KEY_1:
					_buy(0)
				KEY_2:
					_buy(1)
				KEY_3:
					_buy(2)
				KEY_4:
					_buy(3)
				KEY_5:
					_buy(4)
				KEY_E, KEY_ESCAPE, KEY_B:
					close_shop()
			return
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
			KEY_H:
				_whistle_horse()
			KEY_Q:
				_dodge()
			KEY_X:
				_place_bomb()
			KEY_B:
				_detonate_bombs()
			KEY_T:
				_raise_ice()
			KEY_V:
				_toggle_stasis()
			KEY_Z:
				_toggle_magnet()
			KEY_1:
				switch_slot(0)
			KEY_2:
				switch_slot(1)


# 遥控炸弹：X 放置（至多 2 枚，放第三枚时引爆最旧的一枚），B 全部引爆。
func _place_bomb() -> void:
	_bombs = _bombs.filter(func(b: RemoteBomb) -> bool: return is_instance_valid(b))
	if _bombs.size() >= 2:
		_bombs[0].detonate()
		_bombs.remove_at(0)
	var fwd := get_aim_dir()
	var pos := camera.global_position + fwd * 1.1 + Vector3(0, -0.2, 0)
	var b := RemoteBomb.place(get_tree().current_scene, pos, fwd * 3.0 + Vector3(0, 2.0, 0))
	_bombs.append(b)
	if not _bomb_hint_done:
		_bomb_hint_done = true
		hud.add_feed("遥控炸弹：X 放置（至多 2 枚），B 引爆")


func _detonate_bombs() -> void:
	_bombs = _bombs.filter(func(b: RemoteBomb) -> bool: return is_instance_valid(b))
	for b in _bombs:
		b.detonate()
	_bombs.clear()


# 制冰：瞄准水面按 T 升起冰柱（至多 3 根，超出顶替最旧），可站立渡河。
func _raise_ice() -> void:
	if terrain == null:
		return
	_pillars = _pillars.filter(func(p: IcePillar) -> bool: return is_instance_valid(p))
	var origin := camera.global_position
	var fwd := get_aim_dir()
	var spot := Vector3.ZERO
	var bed_y := 0.0
	var found := false
	for i in range(48):
		var p := origin + fwd * (0.5 * i)
		if terrain.is_in_water(p.x, p.z) and p.y <= Terrain.WATER_LEVEL + 0.35:
			spot = Vector3(p.x, Terrain.WATER_LEVEL, p.z)
			bed_y = terrain.get_height(p.x, p.z)
			found = true
			break
	if not found:
		hud.add_feed("制冰需要瞄准水面")
		return
	var h := Terrain.WATER_LEVEL + 1.0 - bed_y
	if h > 4.5:
		hud.add_feed("水太深，冰柱够不到底")
		return
	if _pillars.size() >= 3:
		_pillars[0].shatter()
		_pillars.remove_at(0)
	var pillar := IcePillar.create(get_tree().current_scene, Vector3(spot.x, bed_y, spot.z), h)
	_pillars.append(pillar)
	var sfx := get_tree().get_first_node_in_group("sfx_bank")
	if sfx:
		sfx.play_at("freeze", spot, -6.0)


# 时停：瞄准 20m 内敌人按 V 冻结 5 秒（金色时停壳），期间近战伤害累积，解除时一半转为冲击伤害并击飞。
func _toggle_stasis() -> void:
	if _stasis_target:
		_release_stasis()
		return
	var fwd := get_aim_dir()
	var best: CharacterBody3D = null
	var best_dot := 0.82
	for group in ["wild_enemy", "wildlife", "combatant"]:
		for target in get_tree().get_nodes_in_group(group):
			if not (target is CharacterBody3D) or not target.alive:
				continue
			var to_t: Vector3 = target.global_position + Vector3(0, 1.0, 0) - camera.global_position
			if to_t.length() > 20.0:
				continue
			var dt := to_t.normalized().dot(fwd)
			if dt > best_dot:
				best_dot = dt
				best = target
	if best == null:
		hud.add_feed("时停需要瞄准 20m 内的敌人")
		return
	_stasis_target = best
	_stasis_dmg = 0.0
	_stasis_end_ms = Time.get_ticks_msec() + 5000
	best.set_process_mode(Node.PROCESS_MODE_DISABLED)
	_stasis_shell = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 1.3
	sm.height = 2.6
	sm.radial_segments = 12
	sm.rings = 7
	_stasis_shell.mesh = sm
	var smat := StandardMaterial3D.new()
	smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smat.albedo_color = Color(1.0, 0.85, 0.25, 0.22)
	smat.emission_enabled = true
	smat.emission = Color(1.0, 0.80, 0.15)
	smat.emission_energy_multiplier = 1.2
	smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_stasis_shell.material_override = smat
	best.add_child(_stasis_shell)
	_stasis_shell.position.y = 1.0
	DamageNumber.spawn_at(get_tree().current_scene, best.global_position + Vector3(0, 2.2, 0), "时停!", Color(1.0, 0.85, 0.30))
	var sfx := get_tree().get_first_node_in_group("sfx_bank")
	if sfx:
		sfx.play_at("stasis", best.global_position, -5.0)


func _release_stasis() -> void:
	var t := _stasis_target
	_stasis_target = null
	_stasis_end_ms = 0
	if is_instance_valid(_stasis_shell):
		_stasis_shell.queue_free()
	_stasis_shell = null
	if t == null or not is_instance_valid(t):
		return
	t.set_process_mode(Node.PROCESS_MODE_INHERIT)
	if t.alive and _stasis_dmg > 0.0:
		var dir := t.global_position - global_position
		dir.y = 0.0
		dir = dir.normalized() if dir.length_squared() > 0.01 else Vector3.FORWARD
		t.velocity += dir * 4.0 + Vector3(0, 3.5, 0)
		t.take_damage(_stasis_dmg * 0.5, self, "body")
	_stasis_dmg = 0.0


# 磁力：瞄准 16m 内金属块按 Z 吸附，视线搬运，Z 放下，左键投掷（高速撞敌有伤害）。
func _toggle_magnet() -> void:
	if _magnet_prop:
		_release_magnet(get_aim_dir() * 4.0)
		return
	var fwd := get_aim_dir()
	var best: MetalProp = null
	var best_dot := 0.80
	for prop in get_tree().get_nodes_in_group("metal_prop"):
		var to_p: Vector3 = prop.global_position - camera.global_position
		if to_p.length() > 16.0:
			continue
		var dt := to_p.normalized().dot(fwd)
		if dt > best_dot:
			best_dot = dt
			best = prop as MetalProp
	if best == null:
		hud.add_feed("磁力需要瞄准 16m 内的金属块")
		return
	_magnet_prop = best
	hud.add_feed("磁力吸附中：移动视线搬运，Z 放下，左键投掷")
	_magnet_beam = MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.055
	cm.bottom_radius = 0.055
	cm.height = 1.0
	cm.radial_segments = 6
	_magnet_beam.mesh = cm
	var bmat := StandardMaterial3D.new()
	bmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bmat.albedo_color = Color(0.10, 0.85, 0.80, 0.7)
	bmat.emission_enabled = true
	bmat.emission = Color(0.05, 0.90, 0.80)
	bmat.emission_energy_multiplier = 2.8
	bmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_magnet_beam.material_override = bmat
	get_tree().current_scene.add_child(_magnet_beam)
	# 三颗沿光束滑动的能量微粒，让磁力链接有"流动感"。
	for i in range(3):
		var mote := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.05
		sm.height = 0.10
		sm.radial_segments = 8
		sm.rings = 5
		mote.mesh = sm
		mote.material_override = bmat
		get_tree().current_scene.add_child(mote)
		_magnet_motes.append(mote)


func _release_magnet(impulse: Vector3) -> void:
	if _magnet_prop and is_instance_valid(_magnet_prop):
		_magnet_prop.magnet_release(impulse)
	_magnet_prop = null
	if is_instance_valid(_magnet_beam):
		_magnet_beam.queue_free()
	_magnet_beam = null
	for mote in _magnet_motes:
		if is_instance_valid(mote):
			mote.queue_free()
	_magnet_motes.clear()


func _throw_magnet() -> void:
	_release_magnet(get_aim_dir() * 14.0 + Vector3(0, 5.0, 0))
	var sfx := get_tree().get_first_node_in_group("sfx_bank")
	if sfx:
		sfx.play("hit", -8.0)


func _update_magnet_beam() -> void:
	if _magnet_beam == null or _magnet_prop == null:
		return
	var from := camera.global_position - Vector3(0, 0.25, 0) + get_aim_dir() * 0.6
	var to := _magnet_prop.global_position
	var d := to - from
	if d.length_squared() < 0.01:
		return
	_magnet_beam.global_transform = Transform3D(Basis(Quaternion(Vector3.UP, d.normalized())), (from + to) * 0.5)
	_magnet_beam.scale = Vector3(1.0, d.length(), 1.0)
	var flow := Time.get_ticks_msec() * 0.0012
	for i in range(_magnet_motes.size()):
		var mote := _magnet_motes[i]
		if is_instance_valid(mote):
			var tt := fposmod(flow + float(i) / 3.0, 1.0)
			mote.global_position = from.lerp(to, tt)


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


func _whistle_horse() -> void:
	var best: Horse = null
	var best_d := 45.0
	# 绑定马优先：无论多远都会跑来；没有绑定马才唤最近的野马。
	if bonded_horse and is_instance_valid(bonded_horse) and bonded_horse.driver == null and global_position.distance_to(bonded_horse.global_position) < 220.0:
		best = bonded_horse
		best_d = 0.0
	for candidate in get_tree().get_nodes_in_group("vehicle"):
		if candidate is Horse:
			var h := candidate as Horse
			var d := global_position.distance_to(h.global_position)
			if best == null and d < best_d and h.driver == null:
				best_d = d
				best = h
	if best:
		best.whistle_call(self)
		if hud:
			hud.add_feed("你吹了声口哨，%s 正在跑来" % "马儿")
	elif hud:
		hud.add_feed("你吹了声口哨，附近没有马回应")


func _dodge() -> void:
	if dodge_cd > 0.0 or not is_on_floor() or vehicle or backpack_open:
		return
	dodge_cd = 0.8
	# 闪身：沿输入方向（无输入则向后）短促位移，0.3s 无敌帧。
	var f := float(Input.is_key_pressed(KEY_W)) - float(Input.is_key_pressed(KEY_S))
	var r := float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A))
	var dir := global_transform.basis * Vector3(r, 0, -f)
	if dir.length_squared() < 0.01:
		dir = global_transform.basis.z
	dir.y = 0.0
	dir = dir.normalized()
	velocity.x = dir.x * 11.0
	velocity.z = dir.z * 11.0
	_dodge_iframe_end = Time.get_ticks_msec() / 1000.0 + 0.30


func _start_flurry() -> void:
	flurry = true
	Engine.time_scale = 0.22
	_flurry_end_ms = Time.get_ticks_msec() + 1600
	if hud:
		hud.add_feed("完美闪避！林克时间")


func _end_flurry() -> void:
	if not flurry:
		return
	flurry = false
	Engine.time_scale = 1.0


func _physics_process(delta: float) -> void:
	if not alive:
		return
	# 测试钩子：无头环境下输入分支不执行，举盾状态在这里维护。
	if debug_block and not blocking:
		blocking = true
		_block_start = Time.get_ticks_msec() / 1000.0
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
	# 磁力持握：金属块软跟随视线前方 5m，超距自动脱手。
	if _magnet_prop:
		if not is_instance_valid(_magnet_prop) or _magnet_prop.global_position.distance_to(global_position) > 20.0:
			_release_magnet(Vector3.ZERO)
		else:
			_magnet_prop.magnet_hold(camera.global_position + get_aim_dir() * 5.0)
			_update_magnet_beam()
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
	if Input.is_key_pressed(KEY_SHIFT) and f > 0.0 and not weapon.is_ads and not prone and stamina > 0.0:
		speed = SPRINT_SPEED
		_drain_stamina(9.0 * delta)
	if weapon.is_ads:
		speed *= 0.55
	if prone:
		speed *= 0.35
	if blocking:
		speed *= 0.5

	var accel := ACCEL if is_on_floor() else AIR_ACCEL
	var hv := Vector3(velocity.x, 0.0, velocity.z)
	hv = hv.move_toward(wish * speed, accel * delta)
	velocity.x = hv.x
	velocity.z = hv.z

	if _update_climbing(delta, f, r):
		# 攀爬中：速度由攀爬逻辑设置（W/S 上下、A/D 横移、Space 蹬离）
		pass
		_update_climb_arms(delta)
	elif _ladder and f > 0.0:
		# 攀爬：W 沿梯子上升
		velocity.y = 3.2
	elif _ladder:
		velocity.y = 0.0
	elif is_on_floor():
		_airborne_time = 0.0
		if is_dropping:
			is_dropping = false
			landed.emit()
		if Input.is_key_pressed(KEY_SPACE):
			velocity.y = JUMP_VEL
	else:
		_airborne_time += delta
		# 初次空降和之后从任意悬崖跃下都能展开；普通小跳因离地高度不足不会误触。
		var clearance := 99.0
		if terrain:
			clearance = global_position.y - terrain.get_height(global_position.x, global_position.z)
		var can_deploy := is_dropping or (_airborne_time > 0.18 and clearance > 2.35)
		var wants_glide := can_deploy and (Input.is_key_pressed(KEY_SPACE) or debug_glide) and velocity.y < -0.55
		_set_gliding(wants_glide)
		if is_gliding:
			_drain_stamina(5.0 * delta)
			if stamina <= 0.0:
				_set_gliding(false)
			# 旷野式滑翔：始终向前飘；W 俯冲提速但下降更快，S 减速缓降，A/D 转向。
			var glide_forward := -global_transform.basis.z
			glide_forward.y = 0.0
			glide_forward = glide_forward.normalized()
			var glide_dir := glide_forward
			var glide_speed := GLIDE_SPEED * 0.72
			var fall_speed := GLIDE_FALL_SPEED
			if wish.length_squared() > 0.01:
				glide_dir = wish
				if f > 0.0:
					glide_speed = GLIDE_SPEED * 1.18
					fall_speed = GLIDE_FALL_SPEED * 1.30
				elif f < 0.0:
					glide_speed = GLIDE_SPEED * 0.45
					fall_speed = GLIDE_FALL_SPEED * 0.80
			var glide_target := glide_dir * glide_speed
			var glide_h := Vector3(velocity.x, 0, velocity.z).move_toward(glide_target, AIR_ACCEL * 0.85 * delta)
			velocity.x = glide_h.x
			velocity.z = glide_h.z
			velocity.y = move_toward(velocity.y, -fall_speed, GRAVITY * 1.5 * delta)
			velocity.y = maxf(velocity.y, -fall_speed * 1.15)
		else:
			velocity.y = maxf(velocity.y - GRAVITY * delta, -30.0)
	_update_glider_visual(delta)

	# 盾滑：举盾站在坡面上会顺坡加速滑下（旷野之息式的下山方式）。
	# 陡坡（>45°）is_on_floor 为 false，用地形高度差判断“贴着地面”。
	if blocking and terrain and (is_on_floor() or global_position.y - terrain.get_height(global_position.x, global_position.z) < 0.35):
		var slope_n := terrain.get_normal(global_position.x, global_position.z, 1.2)
		if slope_n.y < 0.92:
			var downhill := Vector3(slope_n.x, 0, slope_n.z).normalized()
			# 直接接管水平速度（步行衰减在盾滑时不适用），0.5s 内冲到 10m/s。
			var surf_speed := minf(10.0, Vector2(velocity.x, velocity.z).length() + 22.0 * delta)
			velocity.x = downhill.x * surf_speed
			velocity.z = downhill.z * surf_speed
			var surf_h := Vector2(velocity.x, velocity.z)
			_drain_stamina(3.0 * delta)
			if not _surf_notified and surf_h.length() > 6.0:
				_surf_notified = true
				if hud:
					hud.add_feed("盾牌滑行！")
		elif _surf_notified:
			_surf_notified = false
	move_and_slide()
	if is_on_floor() and is_gliding:
		_set_gliding(false)
	# 自动上台阶：被低矮台基（驿站石基/神庙平台/断柱/台阶接缝）挡住时抬上去。
	if f > 0.05 and not is_climbing and not prone:
		_try_step_up()

	# 占领点回血
	if regen_rate > 0.0 and hp < max_hp:
		hp = minf(max_hp, hp + regen_rate * delta)
		health_changed.emit(hp, armor)
	# 精力回复：本帧无消耗且过了短暂延迟后快速回满。
	_stamina_wait = maxf(0.0, _stamina_wait - delta)
	if not _stamina_used and _stamina_wait <= 0.0:
		stamina = minf(max_stamina, stamina + 26.0 * delta)
	_stamina_used = false

	# 武器输入（持续按住）
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			if _magnet_prop:
				_throw_magnet()
			elif false:
				pass
			if weapon.weapon_id == "bow":
				_bow_draw = minf(1.0, _bow_draw + delta * 1.3)
				weapon.set_ads(_bow_draw > 0.15)
			elif weapon.weapon_id != "":
				weapon.hold_trigger()
			elif _melee_cd <= 0.0:
				_melee_swing()
		elif weapon.weapon_id == "bow" and _bow_draw > 0.0:
			_fire_arrow()
		var rmb := Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
		if debug_block:
			rmb = true
		weapon.set_ads(rmb and weapon.weapon_id != "")
		# 空手举盾：右键格挡，举盾瞬间为完美格挡窗口。
		if weapon.weapon_id == "":
			if rmb and not blocking:
				blocking = true
				_block_start = Time.get_ticks_msec() / 1000.0
			elif not rmb and blocking:
				blocking = false
		elif blocking:
			blocking = false
		if _shield_root:
			_shield_root.visible = blocking
	_scan_loot()
	_melee_cd = maxf(0.0, _melee_cd - delta)
	# 顿帧恢复：墙钟计时，不受 time_scale 影响。
	if _hitstop_end_ms > 0 and Time.get_ticks_msec() >= _hitstop_end_ms:
		_hitstop_end_ms = 0
		if not flurry:
			Engine.time_scale = 1.0
	if _stasis_end_ms > 0 and Time.get_ticks_msec() >= _stasis_end_ms:
		_release_stasis()
	if _elixir_stam_end_ms > 0 and Time.get_ticks_msec() >= _elixir_stam_end_ms:
		_elixir_stam_end_ms = 0
		max_stamina -= 20.0
		stamina = minf(stamina, max_stamina)
		hud.add_feed("药剂效果消退了")
	_update_sword(delta)
	if not is_climbing and _climb_arms:
		_climb_arms.visible = false
	dodge_cd = maxf(0.0, dodge_cd - delta)
	if flurry and Time.get_ticks_msec() >= _flurry_end_ms:
		_end_flurry()
	# 烤串增益倒计时。
	if _skewer_t > 0.0:
		_skewer_t -= delta
		if _skewer_t <= 0.0:
			skewer_mult = 1.0
			damage_mult = 1.0
			if hud:
				hud.add_feed("烤串的劲头过去了")


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
	nearby_npc = null
	var best_n := 3.2
	for candidate_n in get_tree().get_nodes_in_group("npc"):
		var n: Node = candidate_n
		var d_n := global_position.distance_to(n.global_position)
		if d_n < best_n:
			best_n = d_n
			nearby_npc = n
	nearby_fish = null
	if is_swimming:
		var best_f := 2.6
		for candidate_f in get_tree().get_nodes_in_group("fish"):
			var fs: Node = candidate_f
			if not fs.available:
				continue
			var d_f := global_position.distance_to(fs.global_position)
			if d_f < best_f:
				best_f = d_f
				nearby_fish = fs
	nearby_bed = null
	var best_b := 2.6
	for candidate_b in get_tree().get_nodes_in_group("bed"):
		var b: Node = candidate_b
		var d_b := global_position.distance_to(b.global_position)
		if d_b < best_b:
			best_b = d_b
			nearby_bed = b
	nearby_chest = null
	var best_c := 2.6
	for candidate_c in get_tree().get_nodes_in_group("loot_chest"):
		var c: Node = candidate_c
		if c.opened:
			continue
		var d_c := global_position.distance_to(c.global_position)
		if d_c < best_c:
			best_c = d_c
			nearby_chest = c
	nearby_beacon = null
	var best_wb := 2.8
	for candidate_wb in get_tree().get_nodes_in_group("warp_beacon"):
		var wb: Node = candidate_wb
		if not wb.is_available():
			continue
		var d_wb := global_position.distance_to(wb.global_position)
		if d_wb < best_wb:
			best_wb = d_wb
			nearby_beacon = wb


func _try_pickup() -> void:
	if nearby_loot and not nearby_loot.consumed:
		nearby_loot.apply_to(self)
	elif nearby_npc:
		nearby_npc.talk()
	elif nearby_fish:
		nearby_fish.catch(self)
	elif nearby_bed:
		nearby_bed.use(self)
	elif nearby_chest:
		nearby_chest.open(self)
	elif nearby_beacon:
		nearby_beacon.activate(self)


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


# 卢比：敌人掉落，行商处消费。
func give_rupees(n: int) -> void:
	rupees += n
	if hud:
		hud.set_rupees(rupees)


# 多戈商店：箭矢/烤肉/生命药水三样。
func open_shop() -> void:
	shop_open = true
	if hud:
		hud.show_shop([
			{"text": "1 · 箭矢 ×10", "price": "15 卢比", "color": Color(0.60, 0.78, 0.95), "cost": 15},
			{"text": "2 · 烤兽肉 ×1", "price": "12 卢比", "color": Color(0.95, 0.65, 0.40), "cost": 12},
			{"text": "3 · 生命药水（回满血）", "price": "25 卢比", "color": Color(0.95, 0.45, 0.50), "cost": 25},
			{"text": "4 · 卖兽肉 ×1", "price": "+8 卢比", "color": Color(0.95, 0.65, 0.40), "cost": -1},
			{"text": "5 · 卖海拉鲁蘑菇 ×1", "price": "+5 卢比", "color": Color(0.85, 0.75, 0.45), "cost": -1},
		], rupees)


func close_shop() -> void:
	shop_open = false
	if hud:
		hud.hide_shop()


func _buy(idx: int) -> void:
	var prices := [15, 12, 25]
	# 出售端：卖兽肉 +8、卖蘑菇 +5。
	if idx == 3:
		if int(backpack_items["meat"]) <= 0:
			hud.add_feed("没有兽肉可卖")
			return
		backpack_items["meat"] = int(backpack_items["meat"]) - 1
		give_rupees(8)
		hud.add_feed("卖出兽肉，+8 卢比")
		_refresh_backpack()
		open_shop()
		return
	if idx == 4:
		if int(backpack_items["mushroom"]) <= 0:
			hud.add_feed("没有蘑菇可卖")
			return
		backpack_items["mushroom"] = int(backpack_items["mushroom"]) - 1
		give_rupees(5)
		hud.add_feed("卖出蘑菇，+5 卢比")
		_refresh_backpack()
		open_shop()
		return
	if rupees < prices[idx]:
		if hud:
			hud.add_feed("卢比不够了……")
		return
	rupees -= prices[idx]
	match idx:
		0:
			give_ammo(10)
			hud.add_feed("买了 10 支箭")
		1:
			give_item("roast_meat", 1)
			hud.add_feed("买了烤兽肉")
			_refresh_backpack()
		2:
			hp = max_hp
			health_changed.emit(hp, armor)
			hud.add_feed("喝下药水，血回满了")
	hud.set_rupees(rupees)
	open_shop()


func give_item(kind: String, amount: int) -> void:
	if not backpack_items.has(kind):
		backpack_items[kind] = 0
	backpack_items[kind] = int(backpack_items[kind]) + amount
	backpack_changed.emit()


func collect_seed() -> void:
	seed_count += 1
	armor = minf(100.0, armor + 5.0)
	health_changed.emit(hp, armor)
	if seed_count % 3 == 0:
		max_stamina += 10.0
		stamina = max_stamina
	if seed_count >= 10 and charm_mult < 1.05:
		charm_mult = 1.05
		damage_mult = skewer_mult * charm_mult
		if hud:
			hud.add_feed("集齐 10 颗种子！获得呀哈哈面具（永久攻击 +5%）")
	if hud:
		hud.add_feed("找到一颗海拉鲁种子！（第 %d 颗%s）" % [seed_count, "，精力上限 +10" if seed_count % 3 == 0 else "，护甲 +5"])
	_refresh_backpack()


func collect_orb() -> void:
	max_hp += 10.0
	hp = max_hp
	health_changed.emit(hp, armor)
	if hud:
		hud.add_feed("精灵宝珠融入身体：生命上限 +10（当前 %d）" % int(max_hp))


func equip_master_sword() -> void:
	melee_damage = 42.0
	if _sword_blade:
		var gold := StandardMaterial3D.new()
		gold.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		gold.albedo_color = Color(0.95, 0.85, 0.45)
		gold.emission_enabled = true
		gold.emission = Color(0.9, 0.75, 0.3)
		gold.emission_energy_multiplier = 1.4
		_sword_blade.material_override = gold
	if hud:
		hud.add_feed("获得古代剑！近战伤害提升至 %d" % int(melee_damage))


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
	dmg *= damage_taken_mult
	# 完美闪避：闪身窗口内被击中触发林克时间——无伤且时间变慢。
	if Time.get_ticks_msec() / 1000.0 < _dodge_iframe_end:
		_start_flurry()
		damaged.emit(0.0)
		return
	# 盾牌格挡：面向攻击者时伤害减到 1/4 并耗精力；举盾瞬间（0.18s 内）为完美格挡，无伤反震。
	if blocking and from != null and from is Node3D:
		var to_attacker: Vector3 = (from as Node3D).global_position - global_position
		to_attacker.y = 0.0
		if to_attacker.length_squared() > 0.01 and to_attacker.normalized().dot(-global_transform.basis.z) > 0.25:
			if Time.get_ticks_msec() / 1000.0 - _block_start < 0.18:
				# 完美格挡守卫光束：直接弹回，守卫自毁。
				if from is Guardian:
					from.take_damage(150.0, self, "body")
					parry_count += 1
					if hud:
						hud.add_feed("弹反光束！")
					damaged.emit(0.0)
					return
				if from.has_method("take_damage"):
					from.take_damage(12.0, self, "body")
				if hud:
					hud.add_feed("完美格挡！")
				damaged.emit(0.0)
				return
			if stamina > 0.0:
				dmg *= 0.25
				_drain_stamina(10.0)
				if hud and dmg >= 8.0:
					hud.add_feed("格挡住了攻击")
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
	_end_flurry()
	# 小精灵：死亡时自动消耗一只复活（30% 生命），金色爆闪。
	if fairies > 0:
		fairies -= 1
		hp = max_hp * 0.3
		stamina = max_stamina
		health_changed.emit(hp, armor)
		DamageNumber.spawn_at(get_tree().current_scene, global_position + Vector3(0, 2.2, 0), "复活!", Color(1.0, 0.85, 0.40))
		if hud:
			hud.add_feed("小精灵把你从死亡边缘拉了回来（剩 %d 只）" % fairies)
		return
	alive = false
	hp = 0.0
	if from and from.get("kills") != null:
		from.kills += 1
	died.emit(self, from)


# ---------- 游泳 / 滑翔 ----------

# ---------- 近战挥剑（空手时左键） ----------

var _sword_base_pos := Vector3(0.30, -0.28, -0.55)
var _sword_base_rot := Vector3.ZERO

func _build_sword() -> void:
	_sword = Node3D.new()
	_sword.name = "Sword"
	_sword.position = _sword_base_pos
	_sword_base_rot = Vector3(-0.15, 0.0, -0.35)
	_sword.rotation = _sword_base_rot
	camera.add_child(_sword)
	var steel := Toon.make_material(Color(0.78, 0.82, 0.88), true, 0.008)
	var dark := Toon.make_material(Color(0.14, 0.13, 0.15), true, 0.006)
	var wood := Toon.make_material(Color(0.35, 0.22, 0.10), true, 0.008)
	var blade := MeshInstance3D.new()
	var blade_mesh := BoxMesh.new()
	blade_mesh.size = Vector3(0.035, 0.62, 0.085)
	blade.mesh = blade_mesh
	blade.material_override = steel
	blade.position = Vector3(0, 0.42, 0)
	_sword.add_child(blade)
	_sword_blade = blade
	var tip := MeshInstance3D.new()
	var tip_mesh := PrismMesh.new()
	tip_mesh.size = Vector3(0.035, 0.12, 0.085)
	tip.mesh = tip_mesh
	tip.material_override = steel
	tip.position = Vector3(0, 0.79, 0)
	_sword.add_child(tip)
	var guard := MeshInstance3D.new()
	var guard_mesh := BoxMesh.new()
	guard_mesh.size = Vector3(0.16, 0.035, 0.12)
	guard.mesh = guard_mesh
	guard.material_override = dark
	guard.position = Vector3(0, 0.10, 0)
	_sword.add_child(guard)
	var grip := MeshInstance3D.new()
	var grip_mesh := CylinderMesh.new()
	grip_mesh.top_radius = 0.022
	grip_mesh.bottom_radius = 0.026
	grip_mesh.height = 0.20
	grip_mesh.radial_segments = 7
	grip.mesh = grip_mesh
	grip.material_override = wood
	grip.position = Vector3(0, -0.02, 0)
	_sword.add_child(grip)


func _build_shield() -> void:
	# 木圆盾：空手举盾（右键）时显示在左侧镜头位。
	var shield_root := Node3D.new()
	shield_root.position = Vector3(-0.28, -0.26, -0.5)
	shield_root.rotation_degrees = Vector3(-8, 18, 0)
	camera.add_child(shield_root)
	_shield = MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.26
	disc.bottom_radius = 0.26
	disc.height = 0.035
	disc.radial_segments = 16
	_shield.mesh = disc
	_shield.material_override = Toon.make_material(Color(0.48, 0.32, 0.15), true, 0.010)
	_shield.rotation_degrees.x = 90.0
	shield_root.add_child(_shield)
	var boss := MeshInstance3D.new()
	var boss_mesh := SphereMesh.new()
	boss_mesh.radius = 0.07
	boss_mesh.height = 0.14
	boss_mesh.radial_segments = 8
	boss_mesh.rings = 5
	boss.mesh = boss_mesh
	boss.material_override = Toon.make_material(Color(0.60, 0.44, 0.16), true, 0.008)
	boss.position = Vector3(0, 0, -0.04)
	shield_root.add_child(boss)
	_shield_root = shield_root
	_shield_root.visible = false


# 第一人称攀爬手臂：贴墙攀爬时可见的双手（绿袖+手掌），只在 is_climbing 时显示。
func _build_climb_arms() -> void:
	_climb_arms = Node3D.new()
	_climb_arms.name = "ClimbArms"
	_climb_arms.visible = false
	camera.add_child(_climb_arms)
	var tunic := Toon.make_material(Color(0.16, 0.42, 0.22), true, 0.010)
	var skin := Toon.make_material(Color(0.90, 0.70, 0.54), true, 0.008)
	_climb_arm_l = _make_climb_arm(Vector3(-0.26, -0.34, -0.52), tunic, skin)
	_climb_arm_r = _make_climb_arm(Vector3(0.26, -0.34, -0.52), tunic, skin)


func _make_climb_arm(pos: Vector3, tunic: Material, skin: Material) -> Node3D:
	var arm := Node3D.new()
	arm.position = pos
	arm.rotation_degrees = Vector3(-52.0, 0.0, 0.0)
	_climb_arms.add_child(arm)
	var forearm := MeshInstance3D.new()
	var fm := CapsuleMesh.new()
	fm.radius = 0.055
	fm.height = 0.30
	fm.radial_segments = 8
	fm.rings = 4
	forearm.mesh = fm
	forearm.material_override = tunic
	arm.add_child(forearm)
	var hand := MeshInstance3D.new()
	var hm := SphereMesh.new()
	hm.radius = 0.065
	hm.height = 0.13
	hm.radial_segments = 8
	hm.rings = 5
	hand.mesh = hm
	hand.material_override = skin
	hand.position = Vector3(0, 0.19, 0)
	arm.add_child(hand)
	return arm


# 攀爬动画：双手交替上攀，移动越快交替越快，带侧移摆动。
func _update_climb_arms(delta: float) -> void:
	_climb_arms.visible = true
	var rate := 1.1 + clampf(velocity.length() * 0.8, 0.0, 1.6)
	_climb_phase += delta * rate
	var grab := sin(_climb_phase * TAU)
	var sway := sin(_climb_phase * PI) * 0.02
	_climb_arm_l.position = Vector3(-0.26 + sway, -0.34 + maxf(0.0, grab) * 0.13, -0.52)
	_climb_arm_r.position = Vector3(0.26 + sway, -0.34 + maxf(0.0, -grab) * 0.13, -0.52)


# 第一人称滑翔握杆手：双手握在伞下横杆两端，小臂伸出画面下缘（与攀爬手臂同风格）。
func _build_glide_arms() -> void:
	_glide_arms = Node3D.new()
	_glide_arms.name = "GlideArms"
	_glide_arms.visible = false
	camera.add_child(_glide_arms)
	var tunic := Toon.make_material(Color(0.16, 0.42, 0.22), true, 0.010)
	var skin := Toon.make_material(Color(0.90, 0.70, 0.54), true, 0.008)
	for sx in [-1.0, 1.0]:
		var hand_pos := Vector3(sx * 0.44, -0.47, -1.50)
		var root_pos := Vector3(sx * 0.26, -0.80, -0.62)
		var dir := (root_pos - hand_pos).normalized()
		var arm := Node3D.new()
		arm.position = (hand_pos + root_pos) * 0.5
		arm.basis = Basis(Quaternion(Vector3.UP, dir))
		_glide_arms.add_child(arm)
		var forearm := MeshInstance3D.new()
		var fm := CapsuleMesh.new()
		fm.radius = 0.062
		fm.height = 0.92
		fm.radial_segments = 8
		fm.rings = 4
		forearm.mesh = fm
		forearm.material_override = tunic
		arm.add_child(forearm)
		var hand := MeshInstance3D.new()
		var hm := SphereMesh.new()
		hm.radius = 0.09
		hm.height = 0.18
		hm.height = 0.15
		hm.radial_segments = 8
		hm.rings = 5
		hand.mesh = hm
		hand.material_override = skin
		hand.position = hand_pos
		_glide_arms.add_child(hand)


func _build_bow() -> void:
	# 猎弓视模型：装配猎弓时显示在左下镜头位。
	_bow = Node3D.new()
	_bow.position = Vector3(-0.26, -0.24, -0.55)
	_bow.rotation_degrees = Vector3(0, 14, 0)
	_bow.visible = false
	camera.add_child(_bow)
	var wood := Toon.make_material(Color(0.50, 0.30, 0.13), true, 0.010)
	for sign in [-1.0, 1.0]:
		var limb := MeshInstance3D.new()
		var lm := CylinderMesh.new()
		lm.top_radius = 0.015
		lm.bottom_radius = 0.022
		lm.height = 0.42
		lm.radial_segments = 6
		limb.mesh = lm
		limb.material_override = wood
		limb.position = Vector3(0, sign * 0.24, -0.04)
		limb.rotation_degrees.x = sign * 32.0
		_bow.add_child(limb)
	var grip := MeshInstance3D.new()
	var gm := CylinderMesh.new()
	gm.top_radius = 0.022
	gm.bottom_radius = 0.024
	gm.height = 0.16
	gm.radial_segments = 7
	grip.mesh = gm
	grip.material_override = Toon.make_material(Color(0.30, 0.18, 0.08), true, 0.008)
	_bow.add_child(grip)
	var string := MeshInstance3D.new()
	var sm := CylinderMesh.new()
	sm.top_radius = 0.004
	sm.bottom_radius = 0.004
	sm.height = 0.78
	sm.radial_segments = 4
	string.mesh = sm
	string.material_override = Toon.make_material(Color(0.85, 0.85, 0.80), false)
	string.position = Vector3(0, 0, 0.05)
	_bow.add_child(string)


func _fire_arrow() -> void:
	if weapon.reserve <= 0:
		if hud:
			hud.add_feed("没箭了")
		_bow_draw = 0.0
		return
	weapon.reserve -= 1
	weapon.ammo_changed.emit(weapon.mag_left, weapon.reserve)
	var dir := get_aim_dir()
	var speed := 16.0 + 22.0 * _bow_draw
	var arrow := WildProjectile.new()
	arrow.configure("arrow", dir * speed + Vector3(0, 1.5 * _bow_draw, 0), 16.0 + 22.0 * _bow_draw, self)
	get_parent().add_child(arrow)
	arrow.global_position = camera.global_position + dir * 0.7 - Vector3(0, 0.12, 0)
	var sfx := get_tree().get_first_node_in_group("sfx_bank")
	if sfx:
		sfx.play("hit", -10.0)
	_bow_draw = 0.0
	weapon.set_ads(false)


func _melee_swing() -> void:
	_melee_cd = 0.5
	_swing_t = 0.0
	_swing_hit_done = false
	if _combo_reset_t <= 0.0:
		_combo_i = 0
	_combo_reset_t = 1.0


# 连段姿态：每段 [蓄力 pose, 挥击 pose]（视模空间位置+欧拉角）。
func _combo_poses() -> Array:
	match _combo_i:
		0:  # 右横扫
			return [[Vector3(0.38, -0.24, -0.52), Vector3(0.1, -0.5, 0.5)], [Vector3(-0.05, -0.30, -0.62), Vector3(-0.3, 0.6, -1.7)]]
		1:  # 左回扫
			return [[Vector3(0.05, -0.30, -0.58), Vector3(-0.3, 0.7, -1.5)], [Vector3(0.45, -0.22, -0.50), Vector3(0.15, -0.6, 0.9)]]
		_:  # 过顶劈砍
			return [[Vector3(0.34, -0.05, -0.45), Vector3(-1.2, 0.1, 0.2)], [Vector3(0.26, -0.48, -0.66), Vector3(0.5, 0.0, 0.1)]]
	return [[_sword_base_pos, _sword_base_rot], [_sword_base_pos, _sword_base_rot]]


# 挥击阶段生效的近战判定与命中反馈（顿帧 + 镜头微震 + 火花）。
func _apply_melee_hit() -> void:
	var mult := (1.35 if _combo_i == 2 else 1.0) * (2.0 if flurry else 1.0) * armor_melee_mult
	var hit_something := false
	var hit_pos := camera.global_position + get_aim_dir() * 1.6
	var forward := get_aim_dir()
	# 中心射线：砍树、点符文等静态可伤害物。
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(camera.global_position, camera.global_position + forward * 2.6, 1 | 4, [get_rid()])
	var result := space.intersect_ray(query)
	if not result.is_empty():
		var col: Object = result.collider
		if col.has_method("take_damage"):
			col.take_damage(melee_damage * mult, self, "body")
			hit_something = true
		hit_pos = result.position
		if col == _stasis_target:
			_stasis_dmg += melee_damage * mult
	# 弧形范围：怪物、动物、AI 战士。
	for group in ["wild_enemy", "wildlife", "combatant"]:
		for target in get_tree().get_nodes_in_group(group):
			if target == self or not (target is CharacterBody3D):
				continue
			if not target.alive:
				continue
			var to_t: Vector3 = target.global_position + Vector3(0, 0.8, 0) - camera.global_position
			if to_t.length() > 2.6 or to_t.normalized().dot(forward) < 0.5:
				continue
			if target.has_method("take_damage"):
				target.take_damage(melee_damage * mult, self, "body")
				hit_something = true
				hit_pos = target.global_position + Vector3(0, 0.8, 0)
				if target == _stasis_target:
					_stasis_dmg += melee_damage * mult
	if hit_something:
		var sfx := get_tree().get_first_node_in_group("sfx_bank")
		if sfx:
			sfx.play("hit", -6.0)
		FX.impact(hit_pos)
		if not flurry:
			Engine.time_scale = 0.05
			_hitstop_end_ms = Time.get_ticks_msec() + 50
		pitch += randf_range(0.008, 0.018)


func _update_sword(delta: float) -> void:
	if _sword == null:
		return
	_sword.visible = weapon.weapon_id == "" and not is_gliding
	if _bow:
		_bow.visible = weapon.weapon_id == "bow" and not is_gliding
	if _swing_t < 0.0:
		return
	_swing_t += delta
	_combo_reset_t = maxf(0.0, _combo_reset_t - delta)
	# 三段式：蓄力(0.07/0.09s 缓入) → 挥击(0.10s 快速) → 收势(0.22s 缓出)；进入挥击帧结算伤害。
	var windup := 0.07 if _combo_i < 2 else 0.09
	var swipe := 0.10
	var recover := 0.22
	var poses := _combo_poses()
	if _swing_t < windup:
		var t := 1.0 - pow(1.0 - _swing_t / windup, 2.0)
		_sword.position = _sword_base_pos.lerp(poses[0][0], t)
		_sword.rotation = _sword_base_rot.lerp(poses[0][1], t)
	elif _swing_t < windup + swipe:
		if not _swing_hit_done:
			_swing_hit_done = true
			_apply_melee_hit()
		var t := (_swing_t - windup) / swipe
		_sword.position = poses[0][0].lerp(poses[1][0], t)
		_sword.rotation = poses[0][1].lerp(poses[1][1], t)
	elif _swing_t < windup + swipe + recover:
		var t := (_swing_t - windup - swipe) / recover
		t = t * t * (3.0 - 2.0 * t)
		_sword.position = poses[1][0].lerp(_sword_base_pos, t)
		_sword.rotation = poses[1][1].lerp(_sword_base_rot, t)
	else:
		_swing_t = -1.0
		_combo_i = (_combo_i + 1) % 3
		_sword.position = _sword_base_pos
		_sword.rotation = _sword_base_rot

# ---------- 攀爬（树干 / 塔身 / 悬崖，一切陡面） ----------

func _update_climbing(_delta: float, f: float, r: float) -> bool:
	if _ladder != null or backpack_open or vehicle != null:
		is_climbing = false
		return false
	var space := get_world_3d().direct_space_state
	var facing := -global_transform.basis.z
	facing.y = 0.0
	facing = facing.normalized()
	var chest := global_position + Vector3(0, 1.15, 0)
	var hit := _ray_to_wall(space, chest, facing, 0.95)
	if is_climbing:
		if hit.is_empty():
			# 胸口已越过顶沿：向前上方翻越。
			velocity = facing * 2.4 + Vector3.UP * 3.2
			is_climbing = false
			return false
		var n: Vector3 = hit["normal"]
		n.y = 0.0
		if n.length_squared() < 0.01:
			n = -facing
		n = n.normalized()
		if f < -0.05 and is_on_floor():
			is_climbing = false
			return false
		if Input.is_key_pressed(KEY_SPACE):
			velocity = n * 4.2 + Vector3.UP * 3.0
			is_climbing = false
			return false
		# 攀爬耗精力：静止缓耗、移动快耗，耗尽后滑落。
		_drain_stamina((5.0 + 7.0 * (absf(f) + absf(r))) * _delta * climb_stamina_mult)
		if stamina <= 0.0:
			velocity = n * 1.5 + Vector3(0, -3.0, 0)
			is_climbing = false
			if hud:
				hud.add_feed("精力耗尽，滑下来了！")
			return false
		var side := n.cross(Vector3.UP).normalized()
		velocity = Vector3.UP * f * CLIMB_SPEED * climb_speed_mult + side * r * CLIMB_SPEED * climb_speed_mult * 0.75 - n * 0.8
		return true
	# 进入攀爬：朝陡面推 W（树干、塔身、悬崖、石壁均可）。
	if f > 0.05 and not hit.is_empty():
		var n2: Vector3 = hit["normal"]
		if n2.y < 0.45:
			is_climbing = true
			if is_gliding:
				_set_gliding(false)
			velocity = Vector3.UP * CLIMB_SPEED * climb_speed_mult * 0.8 - n2 * 0.8
			return true
	return false


func _ray_to_wall(space: PhysicsDirectSpaceState3D, from: Vector3, dir: Vector3, dist: float) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from, from + dir * dist, 1, [get_rid()])
	query.collide_with_areas = false
	return space.intersect_ray(query)


# 前进被挡且前方 0.62m 内有可站的面：把身体抬上台阶（Godot 胶囊不会自动上垂直台阶）。
func _try_step_up() -> void:
	var after := Vector2(get_real_velocity().x, get_real_velocity().z).length()
	if OS.get_cmdline_user_args().has("--stepdebug") and Engine.get_process_frames() % 10 == 0:
		print("[stepdbg] after=%.2f pos=%s" % [after, str(global_position)])
	# 正在推前进但几乎没动 = 被矮台挡住（加速度模型下贴墙速度只有 0.5m/s，不能设速度阈值）
	if after > 0.35:
		return
	var facing := -global_transform.basis.z
	facing.y = 0.0
	facing = facing.normalized()
	var space := get_world_3d().direct_space_state
	var from := global_position + facing * 0.55 + Vector3(0, 0.72, 0)
	var query := PhysicsRayQueryParameters3D.create(from, from + Vector3(0, -0.95, 0), 1, [get_rid()])
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		if OS.get_cmdline_user_args().has("--stepdebug"):
			print("[stepdbg] ray miss at %s" % str(from))
		return
	var rise: float = (hit["position"] as Vector3).y - global_position.y
	if rise > 0.05 and rise <= 0.68:
		if OS.get_cmdline_user_args().has("--stepdebug"):
			print("[stepdbg] STEP rise=%.2f" % rise)
		global_position.y = (hit["position"] as Vector3).y + 0.03
		global_position += facing * 0.22


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
	if enabled and not is_gliding:
		_glider_open = 0.0
	is_gliding = enabled
	if _glider:
		_glider.visible = enabled
	if _glide_arms:
		_glide_arms.visible = enabled
	if weapon:
		weapon.visible = not enabled


func _drain_stamina(amount: float) -> void:
	stamina = maxf(0.0, stamina - amount)
	_stamina_used = true
	_stamina_wait = 0.45


func _update_glider_visual(delta: float) -> void:
	if _glider == null:
		return
	if is_gliding:
		_glider_open = move_toward(_glider_open, 1.0, delta * 7.5)
		var ease := smoothstep(0.0, 1.0, _glider_open)
		_glider.scale = Vector3(lerpf(0.56, 1.0, ease), lerpf(0.18, 1.0, ease), lerpf(0.72, 1.0, ease))
		_glider.rotation.z = sin(Time.get_ticks_msec() * 0.0023) * 0.018
		if _glide_arms:
			_glide_arms.rotation.z = sin(Time.get_ticks_msec() * 0.0023) * 0.02
			_glide_arms.position.y = sin(Time.get_ticks_msec() * 0.0017) * 0.012
	else:
		_glider_open = 0.0


func _build_glider() -> void:
	_glider = Node3D.new()
	_glider.name = "Paraglider"
	# 置于第一人称镜头的前上方，展开后能看见伞缘、握杆和绳索，而不是在镜头背后浮空。
	_glider.position = Vector3(0, 2.75, -1.65)
	_glider.visible = false
	add_child(_glider)
	var cloth := Toon.make_material(Color(0.92, 0.64, 0.16), true, 0.01)
	var cloth_dark := Toon.make_material(Color(0.68, 0.20, 0.10), true, 0.01)
	var trim := Toon.make_material(Color(0.10, 0.40, 0.50), true, 0.008)
	var rope := Toon.make_material(Color(0.24, 0.17, 0.10), false)
	var wood := Toon.make_material(Color(0.42, 0.24, 0.09), true, 0.008)
	for i in range(9):
		var panel := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.56, 0.085, 1.18)
		panel.mesh = mesh
		panel.material_override = cloth_dark if i in [0, 4, 8] else cloth
		panel.position = Vector3((i - 4) * 0.43, -absf(float(i - 4)) * 0.065, absf(float(i - 4)) * 0.020)
		panel.rotation_degrees.z = float(i - 4) * -4.8
		_glider.add_child(panel)
		# 分段青色纹样和前缘木骨让伞面不再像一排黄色方砖。
		var stripe := MeshInstance3D.new()
		var stripe_mesh := BoxMesh.new()
		stripe_mesh.size = Vector3(0.45, 0.025, 0.13)
		stripe.mesh = stripe_mesh
		stripe.material_override = trim
		stripe.position = panel.position + Vector3(0, 0.055, -0.34)
		stripe.rotation_degrees.z = panel.rotation_degrees.z
		_glider.add_child(stripe)
	_glider_part(Vector3(3.78, 0.09, 0.10), wood, Vector3(0, -0.20, -0.56), Vector3.ZERO)
	_glider_part(Vector3(0.92, 0.09, 0.12), wood, Vector3(0, -1.65, 0.05), Vector3.ZERO)
	_glider_part(Vector3(0.44, 0.18, 0.08), trim, Vector3(0, 0.13, -0.73), Vector3.ZERO)
	for sx in [-1.0, 1.0]:
		for z in [-0.48, 0.48]:
			var canopy_point := Vector3(sx * 1.78, -0.15, z * 0.82)
			var hand_point := Vector3(sx * 0.38, -1.65, 0.05 + z * 0.10)
			_glider_line(canopy_point, hand_point, rope)


func _glider_part(size: Vector3, mat: Material, pos: Vector3, rot: Vector3) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	part.mesh = mesh
	part.material_override = mat
	part.position = pos
	part.rotation_degrees = rot
	_glider.add_child(part)
	return part


func _glider_line(a: Vector3, b: Vector3, mat: Material) -> void:
	var direction := b - a
	var line := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.014
	mesh.bottom_radius = 0.014
	mesh.height = direction.length()
	mesh.radial_segments = 5
	line.mesh = mesh
	line.material_override = mat
	line.position = (a + b) * 0.5
	line.quaternion = Quaternion(Vector3.UP, direction.normalized())
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
	return backpack_weapons.size() + 6


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
	lines.append("材料 · 木材 × %d（护甲 8）" % int(backpack_items["wood"]))
	lines.append("料理 · 烤兽肉 × %d（回血 55）" % int(backpack_items["roast_meat"]))
	lines.append("料理 · 烤蘑菇 × %d（回血 28+护甲 4）" % int(backpack_items["roast_mushroom"]))
	lines.append("防具 · 士兵铠甲 × %d（受伤 -20%%）%s" % [int(backpack_items.get("armor_soldier", 0)), "（已装备）" if equipped_armor == "armor_soldier" else ""])
	lines.append("防具 · 攀爬者手套 × %d（攀爬增效）%s" % [int(backpack_items.get("armor_climber", 0)), "（已装备）" if equipped_armor == "armor_climber" else ""])
	lines.append("防具 · 蛮族护符 × %d（近战 +20%%）%s" % [int(backpack_items.get("armor_barbarian", 0)), "（已装备）" if equipped_armor == "armor_barbarian" else ""])
	lines.append("材料 · 怪物材料 × %d（火堆炼药：+蘑菇力量药剂 / +兽肉精力药剂）" % int(backpack_items.get("monster_part", 0)))
	return lines


func _use_backpack_selection() -> void:
	if backpack_index < backpack_weapons.size():
		_retrieve_weapon(backpack_index)
		return
	var item_index := backpack_index - backpack_weapons.size()
	var key: String = ["mushroom", "meat", "dragon_scale", "wood", "roast_meat", "roast_mushroom", "armor_soldier", "armor_climber", "armor_barbarian", "monster_part"][item_index]
	var count := int(backpack_items[key])
	if count <= 0:
		return
	# 防具：使用即装备（不消耗），三套效果互斥。
	if key in ["armor_soldier", "armor_climber", "armor_barbarian"]:
		equipped_armor = key
		damage_taken_mult = 0.8 if key == "armor_soldier" else 1.0
		climb_speed_mult = 1.4 if key == "armor_climber" else 1.0
		climb_stamina_mult = 0.5 if key == "armor_climber" else 1.0
		armor_melee_mult = 1.2 if key == "armor_barbarian" else 1.0
		var armor_labels := {"armor_soldier": "士兵铠甲（受伤 -20%）", "armor_climber": "攀爬者手套（攀爬增效）", "armor_barbarian": "蛮族护符（近战 +20%）"}
		if hud:
			hud.add_feed("已装备：" + str(armor_labels[key]))
		backpack_changed.emit()
		_refresh_backpack()
		return
	# 篝火烹饪：站在火堆旁使用生食材会烤成料理（回复更强）。
	var scene := get_tree().current_scene
	var near_fire := false
	if scene and scene.get("wild_world") != null:
		near_fire = scene.wild_world.is_near_campfire(global_position, 4.0)
	# 烤串：火堆旁兽肉+蘑菇各一，换 90 秒攻击 +25%。
	# 炼药：火堆旁怪物材料+蘑菇=力量药剂（60s +15%），+兽肉=精力药剂（全满+临时上限 20）。
	if key == "monster_part":
		if not near_fire:
			hud.add_feed("怪物材料要在火堆旁炼药")
			return
		if int(backpack_items["mushroom"]) >= 1:
			backpack_items["monster_part"] = count - 1
			backpack_items["mushroom"] = int(backpack_items["mushroom"]) - 1
			skewer_mult = 1.15
			_skewer_t = 60.0
			damage_mult = 1.15
			hud.add_feed("炼成力量药剂：60 秒攻击 +15%")
		elif int(backpack_items["meat"]) >= 1:
			backpack_items["monster_part"] = count - 1
			backpack_items["meat"] = int(backpack_items["meat"]) - 1
			_elixir_stam_end_ms = Time.get_ticks_msec() + 60000
			max_stamina += 20.0
			stamina = max_stamina
			hud.add_feed("炼成精力药剂：精力全满，上限 +20（60 秒）")
		else:
			hud.add_feed("炼药需要蘑菇或兽肉做药引")
			return
		backpack_changed.emit()
		_refresh_backpack()
		return
	if key == "meat" and near_fire and int(backpack_items["mushroom"]) >= 1:
		backpack_items["meat"] = count - 1
		backpack_items["mushroom"] = int(backpack_items["mushroom"]) - 1
		skewer_mult = 1.25
		_skewer_t = 90.0
		damage_mult = 1.25
		if hud:
			hud.add_feed("烤了肉串：90 秒攻击 +25%")
		backpack_changed.emit()
		_refresh_backpack()
		return
	if key in ["meat", "mushroom"] and near_fire:
		backpack_items[key] = count - 1
		var cooked := "roast_meat" if key == "meat" else "roast_mushroom"
		backpack_items[cooked] = int(backpack_items[cooked]) + 1
		if hud:
			hud.add_feed("烤制成功：%s" % ("烤兽肉" if key == "meat" else "烤蘑菇"))
		backpack_changed.emit()
		_refresh_backpack()
		return
	backpack_items[key] = count - 1
	if key == "dragon_scale":
		armor = minf(100.0, armor + 35.0)
	elif key == "wood":
		armor = minf(100.0, armor + 8.0)
	elif key == "roast_meat":
		hp = minf(max_hp, hp + 55.0)
		stamina = max_stamina
	elif key == "roast_mushroom":
		hp = minf(max_hp, hp + 28.0)
		armor = minf(100.0, armor + 4.0)
		stamina = minf(max_stamina, stamina + 40.0)
	else:
		hp = minf(max_hp, hp + (18.0 if key == "mushroom" else 30.0))
		if key == "mushroom":
			stamina = minf(max_stamina, stamina + 25.0)
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
