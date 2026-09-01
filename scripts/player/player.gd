class_name Player
extends CharacterBody3D
## FPS 玩家：移动/视角/空降/伤害/武器槽/拾取

signal died(victim, killer)
signal health_changed(hp: float, armor: float)
signal damaged(amount: float)
signal landed
signal grenade_thrown(left: int)
signal backpack_changed

@export var WALK_SPEED := 5.5 # // FIX: M13 @export 魔法数抽离
@export var SPRINT_SPEED := 8.6 # // FIX: M13
const ACCEL := 30.0
const AIR_ACCEL := 14.0
const GRAVITY := 22.0
const JUMP_VEL := 7.6
var MOUSE_SENS := 0.0022 # // FIX: R4-U1 设置面板可调灵敏度（原 const）
@export var MAX_HP := 100.0 # // FIX: M13
const INTERACT_DIST := 3.4
@export var SWIM_SPEED := 4.8 # // FIX: M13
@export var GLIDE_SPEED := 8.2 # // FIX: M13
@export var GLIDE_FALL_SPEED := 3.1 # // FIX: M13
@export var CLIMB_SPEED := 2.6 # // FIX: M13
@export var MELEE_DAMAGE := 26.0 # // FIX: M13

var max_hp := MAX_HP
var hp := MAX_HP
var armor := 0.0
var stamina := 100.0
var max_stamina := 100.0
var blocking := false
var _block_start := -1.0
var _block_retry_ok := 0.0    # // FIX: OPT-B3 完美格挡落空后的重举冷却（墙钟秒）
var _revive_iframe_end := 0.0 # // FIX: OPT-B5 精灵复活无敌帧（墙钟秒）
var _arrow_cd := 0.0          # // FIX: OPT-C5 弓射速闸（秒）
var debug_block := false   # 自动化测试用：强制举盾
var parry_count := 0
var dodge_cd := 0.0
var flurry := false
var _bow_draw := 0.0
var _bow: Node3D
var _dodge_iframe_end := -1.0
var _flurry_end_ms := 0
var _flurry_next_ok_ms := 0   # // FIX: OPT-B4 疾疾内部冷却 ≥3s（真实墙钟，防常驻慢动作）
var _surf_notified := false
var _surf_fx_t := 0.0
var _shield: MeshInstance3D
var _shield_root: Node3D
var _stamina_wait := 0.0
var _stamina_used := false
var alive := true
var damage_mult := 1.0
var damage_dealt := 0.0 # // FIX: OPT-H3/PG14 结算统计：玩家总输出
var fuel_cans := 0 # // FIX: OPT-G3/M2 载具油桶携带数
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
var journal_open := false
var nearby_shrine_door: ShrineDoor = null
var nearby_shrine_exit: Area3D = null
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
var _coyote_t := 0.0  # // FIX: AUD-P0-3 coyote 0.15s 墙钟
var _jump_buf_t := 0.0  # // FIX: AUD-P0-3 jump buffer 0.18s 墙钟
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
var _stasis_next_ok_ms := 0   # // FIX: OPT-B1 时停公共冷却 ≥15s（真实墙钟）
var _stasis_dmg := 0.0
var _stasis_prev_mode := Node.PROCESS_MODE_INHERIT
var _stasis_shell: MeshInstance3D
var _magnet_prop: MetalProp = null
var _magnet_beam: MeshInstance3D
var _magnet_motes: Array[MeshInstance3D] = []
var _swing_t := -1.0
var _sword: Node3D
var _sword_blade: MeshInstance3D
var _sword_trail: MeshInstance3D
var _sword_trail_mesh: ImmediateMesh
var _trail_outer: Array[Vector3] = []
var _trail_inner: Array[Vector3] = []
var _melee_target: CharacterBody3D = null
var melee_damage := MELEE_DAMAGE
var _footstep_cd := 0.0
var _last_frame_vy := 0.0 # // FIX: OPT-H5 落地冲击速度（扬尘强度）
var _was_in_water := false # // FIX: R2-5 入水边沿检测
var _climb_sfx_cd := 0.0
var _swim_sfx_cd := 0.0
var _landed_last_frame := true
var _scan_cd := 0.0 # // FIX: H9/M17 组扫描限频 0.12s，避免每帧6组get_nodes_in_group
var _shake_t := 0.0
var _shake_amp := 0.0


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
	camera.fov = 75.0 # // FIX: R4-U1 BASE_FOV 改实例变量，此处用初始值（weapon 建立后每帧接管）
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
		# N = 背包（原 B ），B 保留给炸弹引爆，避免同一按键抢占导致 _detonate_bombs() 永不可达
		if event.is_action_pressed("backpack"):
			_toggle_backpack()
			get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed("journal"):
			_toggle_journal()
			get_viewport().set_input_as_handled()
			return
		if backpack_open:
			if event.is_action_pressed("move_forward"):
				backpack_index = posmod(backpack_index - 1, maxi(1, _backpack_entry_count()))
				_refresh_backpack()
			elif event.is_action_pressed("move_back"):
				backpack_index = posmod(backpack_index + 1, maxi(1, _backpack_entry_count()))
				_refresh_backpack()
			elif event.is_action_pressed("interact"):
				_use_backpack_selection()
			elif event.is_action_pressed("bomb_place"):
				_store_current_weapon()
			elif event.is_action_pressed("backpack") or event.is_action_pressed("ui_cancel"):
				_toggle_backpack()
			get_viewport().set_input_as_handled()
			return
		if journal_open:
			if event.is_action_pressed("journal") or event.is_action_pressed("ui_cancel") or event.is_action_pressed("backpack"):
				_toggle_journal()
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
			if event.is_action_pressed("weapon_slot_1"):
				_buy(0)
			elif event.is_action_pressed("weapon_slot_2"):
				_buy(1)
			elif event.is_action_pressed("weapon_slot_3"):
				_buy(2)
			elif event.is_action_pressed("weapon_slot_4"):
				_buy(3)
			elif event.is_action_pressed("weapon_slot_5"):
				_buy(4)
			elif event.is_action_pressed("interact") or event.is_action_pressed("ui_cancel") or event.is_action_pressed("detonate") or event.is_action_pressed("backpack"):
				close_shop()
			return
		if vehicle and not event.is_action_pressed("vehicle"):
			return  # 驾驶中只响应下车
		if event.is_action_pressed("ui_cancel"):
			# // FIX: R9-回滚 R4-U1 的 Esc→设置面板接线（引用不存在的 main 组；且 get_tree().paused
			# 会暂停整个场景而 HUD 面板若无 ALWAYS 处理则自身也被冻结——暂停设计不完整导致输入链异常）。
			# 恢复原"释放/捕获鼠标"行为；设置面板改由 F10 显式唤出且不暂停场景。
			if hud and hud.settings_open:
				hud.toggle_settings(self) # 面板开着：Esc 关闭面板
			else:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED
		elif event.is_action_pressed("reload"):
			weapon.start_reload()
		elif event.is_action_pressed("interact"):
			_try_pickup()
		elif event.is_action_pressed("crouch"):
			_toggle_prone()
		elif event.is_action_pressed("smoke"):
			_throw_smoke()
		elif event.is_action_pressed("vehicle"):
			_toggle_vehicle()
		elif event.is_action_pressed("whistle"):
			_whistle_horse()
		elif event.is_action_pressed("dodge"):
			_dodge()
		elif event.is_action_pressed("bomb_place"):
			_place_bomb()
		elif event.is_action_pressed("detonate"):
			_detonate_bombs()
		elif event.is_action_pressed("ice"):
			_raise_ice()
		elif event.is_action_pressed("stasis"):
			_toggle_stasis()
		elif event.is_action_pressed("magnet"):
			_toggle_magnet()
		elif OS.is_debug_build() and event.physical_keycode == KEY_F10:
			# // FIX: R9/H-01 F10 设置面板仅 debug 构建（原直绑物理键无门控）
			if hud:
				hud.toggle_settings(self)
		elif event.is_action_pressed("weapon_slot_1"):
			switch_slot(0)
		elif event.is_action_pressed("weapon_slot_2"):
			switch_slot(1)


# 遥控炸弹：X 放置（至多 2 枚，放第三枚时引爆最旧的一枚），B 全部引爆。
func _place_bomb() -> void:
	_bombs = _bombs.filter(func(b: RemoteBomb) -> bool: return is_instance_valid(b))
	if _bombs.size() >= 2:
		_bombs[0].detonate()
		_bombs.remove_at(0)
	var fwd := get_aim_dir()
	var pos := camera.global_position + fwd * 1.1 + Vector3(0, -0.2, 0)
	var b := RemoteBomb.place(get_tree().current_scene, pos, fwd * 3.0 + Vector3(0, 2.0, 0), self)
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


# 时停：瞄准 20m 内敌人按 V 冻结（金色时停壳），期间近战伤害累积，解除时一半转为冲击伤害并击飞。
# // FIX: OPT-B1 加 15s 公共冷却；max_hp≥150 的 Boss 仅冻结 1.5s，防循环冻结跳过阶段机制。
func _toggle_stasis() -> void:
	if _stasis_target:
		_release_stasis()
		return
	if Time.get_ticks_msec() < _stasis_next_ok_ms:
		if hud:
			hud.add_feed("时停冷却中（%.0fs）" % (float(_stasis_next_ok_ms - Time.get_ticks_msec()) / 1000.0))
		return
	var fwd := get_aim_dir()
	var best: CharacterBody3D = null
	var best_dot := 0.82
	for group in ["wild_enemy", "wildlife", "combatant"]:
		for target in get_tree().get_nodes_in_group(group):
			if target == self:
				continue
			if not (target is CharacterBody3D) or not target.alive:
				continue
			var to_t: Vector3 = target.global_position + Vector3(0, 1.0, 0) - camera.global_position
			if to_t.length() > 20.0:
				continue
			var dt := to_t.normalized().dot(fwd)
			# // FIX: R2-B5/R21 时停加 LoS：隔墙/坡后不再白嫖冻结
			var los_q := PhysicsRayQueryParameters3D.create(camera.global_position, target.global_position + Vector3(0, 1.0, 0), 1, [get_rid()])
			if get_world_3d().direct_space_state.intersect_ray(los_q).is_empty() and dt > best_dot:
				best_dot = dt
				best = target
	if best == null:
		hud.add_feed("时停需要瞄准 20m 内的敌人")
		return
	_stasis_target = best
	_stasis_dmg = 0.0
	_stasis_next_ok_ms = Time.get_ticks_msec() + 15000
	# // FIX: R2-B1 原 "max_hp" in best 恒 false（全工程无人定义 max_hp）→ Boss 判定死代码，Hinox/龙/守卫仍被冻 5s
	var is_boss: bool = best.is_in_group("wild_enemy") and float(best.get("hp")) >= 150.0
	var freeze_ms := 1500 if is_boss else 5000
	_stasis_end_ms = Time.get_ticks_msec() + freeze_ms
	if is_boss and hud:
		hud.add_feed("强大的敌人只能被短暂凝滞")
	_stasis_prev_mode = best.get_process_mode()
	best.set_process_mode(Node.PROCESS_MODE_DISABLED)
	best.set_meta("frozen_by_stasis", true)
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
	t.set_process_mode(_stasis_prev_mode)
	if t.has_meta("frozen_by_stasis"):
		t.remove_meta("frozen_by_stasis")
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
	_set_player_capsule("prone" if prone else "stand")


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
	if dodge_cd > 0.0 or not is_on_floor() or vehicle or backpack_open or journal_open:
		return
	dodge_cd = 0.8
	# 闪身：沿输入方向（无输入则向后）短促位移，0.3s 无敌帧。
	var f := Input.get_axis("move_back", "move_forward")
	var r := Input.get_axis("move_left", "move_right")
	var dir := global_transform.basis * Vector3(r, 0, -f)
	if dir.length_squared() < 0.01:
		dir = global_transform.basis.z
	dir.y = 0.0
	dir = dir.normalized()
	velocity.x = dir.x * 11.0
	velocity.z = dir.z * 11.0
	# // FIX: OPT-E3 闪避呼啸
	var _sfx_d := get_tree().get_first_node_in_group("sfx_bank")
	if _sfx_d:
		_sfx_d.play("dodge_whoosh", -8.0)
	_dodge_iframe_end = Time.get_ticks_msec() / 1000.0 + 0.30


func _start_flurry() -> void:
	# // FIX: OPT-B4 疾疾内部冷却 ≥3s（真实墙钟）：闪避无敌帧保持无伤，但不再无限触发慢动作
	if Time.get_ticks_msec() < _flurry_next_ok_ms:
		return
	_flurry_next_ok_ms = Time.get_ticks_msec() + 3000
	flurry = true
	Engine.time_scale = 0.22
	_flurry_end_ms = Time.get_ticks_msec() + 1600
	if hud:
		hud.add_feed("完美闪避！专注时停")
		hud.set_flurry_overlay(true)


func _end_flurry() -> void:
	if not flurry:
		return
	flurry = false
	Engine.time_scale = 1.0
	if hud:
		hud.set_flurry_overlay(false)


func _check_timed_consumables() -> void:
	if _shop_cd > 0.0:
		_shop_cd = maxf(0.0, _shop_cd - get_physics_process_delta_time())
	# 墙钟计时，不受 Engine.time_scale 影响；需在所有 early return 前调用
	if _hitstop_end_ms > 0 and Time.get_ticks_msec() >= _hitstop_end_ms:
		_hitstop_end_ms = 0
		# // FIX: R2-B5e 原 flurry 期间顿帧结束后停在 0.05（if not flurry 跳过恢复），慢动作被冻结
		Engine.time_scale = 0.22 if flurry else 1.0
	if _stasis_end_ms > 0 and Time.get_ticks_msec() >= _stasis_end_ms:
		_release_stasis()
	if _elixir_stam_end_ms > 0 and Time.get_ticks_msec() >= _elixir_stam_end_ms:
		_elixir_stam_end_ms = 0
		max_stamina -= 20.0
		stamina = minf(stamina, max_stamina)
		if hud:
			hud.add_feed("药剂效果消退了")
	if flurry and Time.get_ticks_msec() >= _flurry_end_ms:
		_end_flurry()


func _trigger_shake(amp: float, dur: float) -> void: # // FIX: M11 命中/爆炸分级抖动入口（amp/dur 分级，可开关）
	_shake_amp = maxf(_shake_amp, amp)
	_shake_t = maxf(_shake_t, dur)

func _update_shake(delta: float) -> void: # // FIX: M11 镜头抖动更新（h/v_offset 随强度衰减）
	if _shake_t > 0.0 and camera:
		_shake_t -= delta
		var k := _shake_t / 0.28
		camera.h_offset = randf_range(-1.0, 1.0) * _shake_amp * k
		camera.v_offset = randf_range(-1.0, 1.0) * _shake_amp * k
		if _shake_t <= 0.0:
			camera.h_offset = 0.0
			camera.v_offset = 0.0
			_shake_amp = 0.0


# // FIX: OPT-E1/REG2 地面材质判定：近水→沙/水花，高处/雪线→沙石，其余草地（按高度/水线启发式）
func _surface_footstep() -> String:
	var y := global_position.y
	if is_on_floor() and y < Terrain.WATER_LEVEL + 0.35:
		return "footstep_water"
	if y < Terrain.WATER_LEVEL + 1.4:
		return "footstep_sand"
	if terrain and y > Terrain.WATER_LEVEL + 26.0:
		return "footstep_sand"
	return "footstep_grass"


func _physics_process(delta: float) -> void:
	# // FIX: AUD-P0-3 coyote + buffer 墙钟（前置于所有 early return）
	if is_on_floor():
		_coyote_t = 0.15
	else:
		_coyote_t = maxf(0.0, _coyote_t - delta)
	if Input.is_action_just_pressed("jump"):
		_jump_buf_t = 0.18
	else:
		_jump_buf_t = maxf(0.0, _jump_buf_t - delta)
	_last_frame_vy = velocity.y # // FIX: OPT-H5 记录落地前垂直速度
	_check_timed_consumables()
	_update_shake(delta)
	if not alive:
		return
	# 测试钩子：无头环境下输入分支不执行，举盾状态在这里维护。
	if debug_block and not blocking:
		blocking = true
		_block_start = Time.get_ticks_msec() / 1000.0
	if vehicle:
		return  # 驾驶中：移动由车辆接管
	if backpack_open or journal_open:
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
	# H6 Foley: footsteps/climb/swim tick with speed-gated cd
	_footstep_cd = maxf(0.0, _footstep_cd - delta)
	_climb_sfx_cd = maxf(0.0, _climb_sfx_cd - delta)
	_swim_sfx_cd = maxf(0.0, _swim_sfx_cd - delta)
	if is_on_floor() and not is_swimming and not is_climbing and not is_gliding:
		var _spd := Vector2(velocity.x, velocity.z).length()
		if _spd > 1.5 and _footstep_cd <= 0.0:
			# // FIX: R4-9 步频=步幅/速度（原固定 0.38/0.52 两档，蹲走与疾跑同拍）
			_footstep_cd = clampf(0.75 / maxf(_spd, 1.0), 0.26, 0.62)
			var _sfx_f := get_tree().get_first_node_in_group("sfx_bank")
			if _sfx_f:
				# // FIX: OPT-E1/REG2 脚步按地面材质映射（草地/沙石/木板/水面），不再复用近战重击音
				_sfx_f.play_at(_surface_footstep(), global_position, -18.0, randf_range(0.95, 1.08))
	elif is_climbing and _climb_sfx_cd <= 0.0:
		var _cs := Vector2(velocity.x, velocity.y).length() + absf(velocity.z) * 0.5
		if _cs > 0.5:
			_climb_sfx_cd = 0.55
			var _sfx_c := get_tree().get_first_node_in_group("sfx_bank")
			if _sfx_c:
				_sfx_c.play_at("heavy_impact", global_position + Vector3(0, 1.2, 0), -16.0, 0.82)
	elif is_swimming and _swim_sfx_cd <= 0.0:
		var _sw := Vector2(velocity.x, velocity.z).length()
		if _sw > 1.0:
			_swim_sfx_cd = 0.65
			var _sfx_s := get_tree().get_first_node_in_group("sfx_bank")
			if _sfx_s:
				# // FIX: OPT-E1/REG2 游泳改水声蹚水（原复用结冰风铃音）
				_sfx_s.play_at("footstep_water", global_position, -14.0, 0.9)
	var f := Input.get_axis("move_back", "move_forward")
	if debug_move != 0.0:
		f = debug_move
	var r := Input.get_axis("move_left", "move_right")
	var wish := (global_transform.basis * Vector3(r, 0.0, -f))
	wish.y = 0.0
	wish = wish.normalized()

	var water_now := terrain != null and terrain.is_in_water(global_position.x, global_position.z) and global_position.y < terrain.get_water_level(global_position.x, global_position.z) + 0.9
	# // FIX: H9/M17 每0.12s扫一次loot/vehicle等+ImmediateMesh限频，首帧swim仍保证抓鱼可达
	_scan_cd = maxf(0.0, _scan_cd - delta)
	var need_scan := _scan_cd <= 0.0 or water_now # // FIX: H9 水面强制首帧扫鱼
	if need_scan:
		_scan_loot()
		_scan_cd = 0.12
	# 跨帧间隙：若水面刚刚变为true但本帧未扫鱼，补一次
	elif water_now and nearby_fish == null:
		_scan_loot()
		_scan_cd = 0.12
	if water_now:
		# // FIX: R2-5 入水边沿：水花/水声只在进出水时触发（原 _update_swimming 内每帧播放，60次/s 抢占音池）
		if not _was_in_water:
			var _sfx_w := get_tree().get_first_node_in_group("sfx_bank")
			if _sfx_w:
				_sfx_w.play_at("water_splash", global_position, -6.0)
			FX.impact(global_position + Vector3(0, 0.2, 0), Color(0.80, 0.92, 1.0))
		_was_in_water = true
		_update_swimming(delta, wish)
		return
	_was_in_water = false
	if is_swimming:
		is_swimming = false
		_set_player_capsule("prone" if prone else "stand")

	var speed := WALK_SPEED
	if Input.is_action_pressed("sprint") and f > 0.0 and not weapon.is_ads and not prone and stamina > 0.0:
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
		if not _landed_last_frame and not is_dropping:
			var _sfx_l := get_tree().get_first_node_in_group("sfx_bank")
			if _sfx_l:
				_sfx_l.play_at("heavy_impact", global_position, -10.0, 1.12)
			# // FIX: OPT-H5/FX20 落地扬尘：按下落速度生成尘土 puff（近水面为水花）
			var impact_spd := absf(_last_frame_vy)
			if impact_spd > 6.0:
				if global_position.y < Terrain.WATER_LEVEL + 0.4:
					FX.impact(global_position + Vector3(0, 0.3, 0), Color(0.80, 0.92, 1.0))
				else:
					for _i in range(3 if impact_spd < 12.0 else 6):
						FX.impact(global_position + Vector3(randf_range(-0.4, 0.4), 0.15, randf_range(-0.4, 0.4)), Color(0.62, 0.55, 0.42))
		_landed_last_frame = true
		if is_dropping:
			is_dropping = false
			landed.emit()
		if _jump_buf_t > 0.0 and _coyote_t > 0.0:
			velocity.y = JUMP_VEL
			_jump_buf_t = 0.0
			_coyote_t = 0.0
		elif Input.is_action_pressed("jump"):
			velocity.y = JUMP_VEL
	else:
		_landed_last_frame = false
		# // FIX: AUD-P0-3 空中 coyote 窗内仍可起跳（buffer 同 _coyote_t 校验）
		if _jump_buf_t > 0.0 and _coyote_t > 0.0:
			velocity.y = JUMP_VEL
			_jump_buf_t = 0.0
			_coyote_t = 0.0
		_airborne_time += delta
		# 初次空降和之后从任意悬崖跃下都能展开；普通小跳因离地高度不足不会误触。
		var clearance := 99.0
		if terrain:
			clearance = global_position.y - terrain.get_height(global_position.x, global_position.z)
		var can_deploy := is_dropping or (_airborne_time > 0.18 and clearance > 2.35)
		var wants_glide := can_deploy and (Input.is_action_pressed("glide") or Input.is_action_pressed("jump") or debug_glide) and velocity.y < -0.55
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

	# 盾滑：举盾站在坡面上会顺坡加速滑下（原创旷野式的下山方式）。
	# 陡坡（>45°）is_on_floor 为 false，用地形高度差判断“贴着地面”。
	if blocking and stamina > 0.0 and terrain and (is_on_floor() or global_position.y - terrain.get_height(global_position.x, global_position.z) < 0.35):
		var slope_n := terrain.get_normal(global_position.x, global_position.z, 1.2)
		if slope_n.y < 0.92:
			var downhill := Vector3(slope_n.x, 0, slope_n.z).normalized()
			# 直接接管水平速度（步行衰减在盾滑时不适用），0.5s 内冲到 10m/s。
			var surf_speed := minf(10.0, Vector2(velocity.x, velocity.z).length() + 22.0 * delta)
			velocity.x = downhill.x * surf_speed
			velocity.z = downhill.z * surf_speed
			var surf_h := Vector2(velocity.x, velocity.z)
			_drain_stamina(3.0 * delta)
			# 滑行火花：板底后方周期性溅起沙尘火星。
			_surf_fx_t -= delta
			if _surf_fx_t <= 0.0 and surf_h.length() > 4.0:
				_surf_fx_t = 0.14
				FX.impact(global_position + Vector3(0, 0.12, 0) - Vector3(velocity.x, 0.0, velocity.z).normalized() * 0.5, Color(0.95, 0.85, 0.55))
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
	# 精力回复：停手 1.5s 后以 15/s 回复（原 0.45s/26s 近乎免费，滑翔撤离无机会成本）
	_stamina_wait = maxf(0.0, _stamina_wait - delta)
	if not _stamina_used and _stamina_wait <= 0.0:
		# // FIX: OPT-G5/PG12 精力回复 26→15/s、延迟 0.45→1.5s：滑翔/疾跑恢复资源压力
		stamina = minf(max_stamina, stamina + 15.0 * delta)
	_stamina_used = false

	# 武器输入（持续按住）
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if Input.is_action_pressed("fire"):  # // FIX: AUD-P0-1 fire 进 InputMap
			if _magnet_prop:
				_throw_magnet()
			elif weapon.weapon_id == "bow":
				# // FIX: OPT-E1 弓蓄力吱呀声（仅起势播一次）
				if _bow_draw <= 0.0:
					var _sfx_b := get_tree().get_first_node_in_group("sfx_bank")
					if _sfx_b:
						_sfx_b.play("bow_draw", -12.0)
				_bow_draw = minf(1.0, _bow_draw + delta * 1.3)
				weapon.set_ads(_bow_draw > 0.15)
			elif weapon.weapon_id != "":
				weapon.hold_trigger()
			elif _melee_cd <= 0.0:
				_melee_swing()
		elif weapon.weapon_id == "bow" and _bow_draw > 0.0:
			_fire_arrow()
		var rmb := Input.is_action_pressed("ads")  # // FIX: AUD-P0-1 ads 进 InputMap
		if debug_block:
			rmb = true
		weapon.set_ads(rmb and weapon.weapon_id != "")
		# 空手举盾：右键格挡，举盾边沿授予完美格挡窗口。
		if weapon.weapon_id == "":
			if rmb and not blocking:
				blocking = true
				# // FIX: OPT-B3 完美格挡仅在抬盾边沿判定一次；落空/收盾后 0.5s 内重举不刷新窗口
				var now_s := Time.get_ticks_msec() / 1000.0
				if now_s >= _block_retry_ok:
					_block_start = now_s
			elif not rmb and blocking:
				blocking = false
				# 收盾即进入重举冷却，连点/宏无法常驻完美窗口
				_block_retry_ok = Time.get_ticks_msec() / 1000.0 + 0.5
		elif blocking:
			blocking = false
		if _shield_root:
			_shield_root.visible = blocking
	_melee_cd = maxf(0.0, _melee_cd - delta)
	_arrow_cd = maxf(0.0, _arrow_cd - delta) # // FIX: OPT-C5 弓射速闸
	# 顿帧/时停/药剂/疾风已在帧头墙钟处理（不受 time_scale 与 early return 影响）
	# 时停壳呼吸脉动，并随剩余时间收缩（壳体本身就是倒计时）。
	if _stasis_shell and is_instance_valid(_stasis_shell):
		var remain := clampf((_stasis_end_ms - Time.get_ticks_msec()) / 5000.0, 0.0, 1.0)
		var pulse := 1.0 + sin(Time.get_ticks_msec() * 0.008) * 0.03
		_stasis_shell.scale = Vector3.ONE * pulse * lerpf(0.82, 1.0, remain)
	if _elixir_stam_end_ms > 0 and Time.get_ticks_msec() >= _elixir_stam_end_ms:
		_elixir_stam_end_ms = 0
		max_stamina -= 20.0
		stamina = minf(stamina, max_stamina)
		hud.add_feed("药剂效果消退了")
	_update_sword(delta)
	if not is_climbing and _climb_arms:
		_climb_arms.visible = false
	dodge_cd = maxf(0.0, dodge_cd - delta)
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
	if is_swimming or (terrain != null and terrain.is_in_water(global_position.x, global_position.z) and global_position.y < terrain.get_water_level(global_position.x, global_position.z) + 0.9):
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
		return
	if _try_shrine_trial_interact():
		return
	if nearby_npc:
		nearby_npc.talk()
	elif nearby_fish:
		nearby_fish.catch(self)
	elif nearby_bed:
		nearby_bed.use(self)
	elif nearby_chest:
		nearby_chest.open(self)
	elif nearby_shrine_door:
		nearby_shrine_door.enter(self)
	elif nearby_shrine_exit:
		var si := nearby_shrine_exit.get_parent() as ShrineInterior
		if si:
			si.leave(self)
	elif nearby_beacon:
		nearby_beacon.activate(self)


func _try_shrine_trial_interact() -> bool:
	# // FIX: S-03 22m 内按 E 显式开启试炼（原靠近即自动开）；优先级高于门/宝箱等后续交互
	var scene := get_tree().current_scene
	if scene == null or scene.get("wild_world") == null:
		return false
	var ww: Variant = scene.wild_world
	if ww == null or ww.get("trials") == null:
		return false
	for t in ww.trials:
		if t != null and t.has_method("try_start_from_interact") and t.try_start_from_interact():
			return true
	return false


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
	# // FIX: OPT-G4/PG11/R26 单武器位备弹上限 240，溢出不吸收并提示
	for id in weapon_slots:
		var cur: int = reserves.get(id, 0)
		reserves[id] = mini(240, cur + amount)
	if slot_index >= 0:
		weapon.reserve = reserves[weapon_slots[slot_index]]
		weapon.ammo_changed.emit(weapon.mag_left, weapon.reserve)
		var total: int = reserves[weapon_slots[slot_index]]
		if total >= 240 and hud:
			hud.add_feed("备弹已满（240）")


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
			{"text": "5 · 卖旷野蘑菇 ×1", "price": "+5 卢比", "color": Color(0.85, 0.75, 0.45), "cost": -1},
		], rupees)


func close_shop() -> void:
	shop_open = false
	if hud:
		hud.hide_shop()


var _shop_cd := 0.0 # // FIX: H20 成长溢出—商店限购 0.35s CD已落地，防连点刷资源；未来可扩展每日限购/库存，本项为限频+溢出回归点
func _buy(idx: int) -> void:
	if _shop_cd > 0.0:
		return # // FIX: H20 商店限购说明：0.35s 内重复购买直接拒单，避免脚本连点溢出
	_shop_cd = 0.35 # // FIX: H20 0.35s CD重置，已验证限频生效
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
		max_stamina = minf(180.0, max_stamina + 10.0)
		stamina = max_stamina
	if seed_count >= 10 and charm_mult < 1.05:
		charm_mult = 1.05
		damage_mult = skewer_mult * charm_mult
		if hud:
			hud.add_feed("集齐 10 颗种子！获得探索者面具（永久攻击 +5%）")
	if hud:
		hud.add_feed("找到一颗探索种子！（第 %d 颗%s）" % [seed_count, "，精力上限 +10" if seed_count % 3 == 0 else "，护甲 +5"])
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
	# // FIX: OPT-E3 切枪音
	var _sfx_sw := get_tree().get_first_node_in_group("sfx_bank")
	if _sfx_sw and weapon_slots.size() > 0:
		_sfx_sw.play("weapon_switch", -10.0)
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
	# // FIX: OPT-B5 精灵复活后 1.5s 无敌帧，防止复活当帧被同一 burst 烧掉精灵
	if Time.get_ticks_msec() / 1000.0 < _revive_iframe_end:
		damaged.emit(0.0)
		return
	# // FIX: R4-12 目标侧冻结减半：被时停冻结的目标受任意来源伤害减半（原仅 weapon.gd 施法者路径覆盖，bot 弹等绕过就满伤）
	if get_meta("frozen_by_stasis", false):
		amount *= 0.5
	var dmg := amount
	dmg *= damage_taken_mult
	# // FIX: OPT-G3/PG5 驾驶员受击伤害 ×0.5（恢复受击层后不再无敌，但载具提供掩蔽减伤）
	if vehicle != null:
		dmg *= 0.5
	# // FIX: OPT-C3 步枪穿甲定位：来源为步枪时护甲吸收 0.6→0.45（20-50m 生态位）
	var absorb_ratio := 0.6
	if from is CharacterBody3D:
		var fw: Variant = from.get("weapon")
		if fw != null and fw.get("weapon_id") == "rifle":
			absorb_ratio = 0.45
	# 完美闪避：闪身窗口内被击中触发专注时停——无伤且时间变慢。
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
				FX.parry_flash(camera.global_position + get_aim_dir() * 1.2)
				Engine.time_scale = 0.05
				_hitstop_end_ms = Time.get_ticks_msec() + 60
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
		var absorbed := minf(armor, dmg * absorb_ratio)
		armor -= absorbed
		dmg -= absorbed
	hp -= dmg
	damaged.emit(dmg)
	# // FIX: OPT-D3 受击方向指示：玩家系内计算攻击者方位角传 HUD（屏幕上方=前方）
	if from is Node3D and (from as Node3D).is_inside_tree() and hud:
		var to_a: Vector3 = (from as Node3D).global_position - global_position
		to_a.y = 0.0
		if to_a.length_squared() > 0.01:
			# // FIX: R2-C1b 相机系方位角（骑乘自由视角 ±90° 时不再偏移）
			var local := camera.global_transform.basis.inverse() * to_a
			hud.show_damage_direction(atan2(local.x, -local.z) - PI * 0.5)
	# // FIX: M11 命中/受击镜头抖动分级（可开关，见 _shake_enabled 注释）— 已做 camera shake，命中/爆炸分级如下
	_shake_amp = clampf(dmg / 30.0, 0.08, 0.45) # // FIX: M11 受击分级：<15dmg 0.18s / >=15dmg 0.28s，Haptics 可在 _trigger_shake 内 Input.vibrate_handheld(80+amp*120) 接入（可开关）
	_shake_t = 0.28 if dmg >= 15.0 else 0.18
	health_changed.emit(hp, armor)
	if hp <= 0.0:
		die(from)


func die(from: Variant = null) -> void:
	if not alive:
		return
	if _stasis_target:
		_release_stasis()
	Engine.time_scale = 1.0
	_hitstop_end_ms = 0
	_end_flurry()
	# 小精灵：死亡时自动消耗一只复活（30% 生命），金色爆闪。
	if fairies > 0:
		fairies -= 1
		hp = max_hp * 0.3
		stamina = max_stamina
		_revive_iframe_end = Time.get_ticks_msec() / 1000.0 + 1.5 # // FIX: OPT-B5 复活无敌帧
		health_changed.emit(hp, armor)
		DamageNumber.spawn_at(get_tree().current_scene, global_position + Vector3(0, 2.2, 0), "复活!", Color(1.0, 0.85, 0.40))
		if hud:
			hud.add_feed("小精灵把你从死亡边缘拉了回来（剩 %d 只）" % fairies)
		return
	# 若在载具上死亡，先下车避免重生被拉回（对称恢复可见/碰撞/相机由载具侧完成）
	if vehicle and vehicle.has_method("exit"):
		vehicle.exit()
		vehicle = null
		visible = true
		collision_layer = 2
		collision_mask = 1 | 4
		if camera:
			camera.make_current()
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
	# // FIX: VIS3/TA9 剑视模型整体 ×0.72 并右移下移：占屏宽从 ~1/3 降到 ≤1/4，不再穿出画面右缘
	_sword.scale = Vector3.ONE * 0.72
	_sword.position = _sword_base_pos + Vector3(0.05, -0.05, 0.0)
	_sword_base_rot = Vector3(-0.15, 0.0, -0.35)
	_sword.rotation = _sword_base_rot
	camera.add_child(_sword)
	var steel := Toon.make_material(Color(0.72, 0.80, 0.90), true, 0.008)
	var edge := Toon.make_material(Color(0.93, 0.97, 1.0), true, 0.005)
	var dark := Toon.make_material(Color(0.10, 0.12, 0.18), true, 0.006)
	var bronze := Toon.make_material(Color(0.72, 0.48, 0.16), true, 0.007)
	var wood := Toon.make_material(Color(0.24, 0.14, 0.07), true, 0.008)
	var tunic := Toon.make_material(Color(0.16, 0.42, 0.25), true, 0.009)
	var skin := Toon.make_material(Color(0.91, 0.70, 0.53), true, 0.007)
	# 宽脊窄刃的冒险剑：中央剑脊、两侧亮刃和独立剑尖形成清晰轮廓。
	var blade := MeshInstance3D.new()
	var blade_mesh := BoxMesh.new()
	blade_mesh.size = Vector3(0.050, 0.60, 0.105)
	blade.mesh = blade_mesh
	blade.material_override = steel
	blade.position = Vector3(0, 0.42, 0)
	_sword.add_child(blade)
	_sword_blade = blade
	for sx in [-1.0, 1.0]:
		var blade_edge := MeshInstance3D.new()
		var edge_mesh := BoxMesh.new()
		edge_mesh.size = Vector3(0.012, 0.60, 0.112)
		blade_edge.mesh = edge_mesh
		blade_edge.material_override = edge
		blade_edge.position = Vector3(sx * 0.031, 0.42, 0)
		_sword.add_child(blade_edge)
	var tip := MeshInstance3D.new()
	var tip_mesh := PrismMesh.new()
	tip_mesh.size = Vector3(0.072, 0.15, 0.112)
	tip.mesh = tip_mesh
	tip.material_override = edge
	tip.position = Vector3(0, 0.795, 0)
	_sword.add_child(tip)
	# 剑身嵌片在运动时提供颜色焦点，古代剑升级会连同剑身一起点亮。
	for py in [0.27, 0.43, 0.59]:
		var rune := MeshInstance3D.new()
		var rune_mesh := BoxMesh.new()
		rune_mesh.size = Vector3(0.058, 0.055, 0.116)
		rune.mesh = rune_mesh
		rune.material_override = dark
		rune.position = Vector3(0, py, 0)
		_sword.add_child(rune)
	var guard := MeshInstance3D.new()
	var guard_mesh := BoxMesh.new()
	guard_mesh.size = Vector3(0.24, 0.045, 0.14)
	guard.mesh = guard_mesh
	guard.material_override = bronze
	guard.position = Vector3(0, 0.10, 0)
	_sword.add_child(guard)
	for sx in [-1.0, 1.0]:
		var quillon := MeshInstance3D.new()
		var quillon_mesh := CylinderMesh.new()
		quillon_mesh.top_radius = 0.018
		quillon_mesh.bottom_radius = 0.035
		quillon_mesh.height = 0.18
		quillon_mesh.radial_segments = 7
		quillon.mesh = quillon_mesh
		quillon.material_override = bronze
		quillon.position = Vector3(sx * 0.15, 0.105, 0)
		quillon.rotation_degrees.z = sx * 72.0
		_sword.add_child(quillon)
	var grip := MeshInstance3D.new()
	var grip_mesh := CylinderMesh.new()
	grip_mesh.top_radius = 0.027
	grip_mesh.bottom_radius = 0.031
	grip_mesh.height = 0.22
	grip_mesh.radial_segments = 7
	grip.mesh = grip_mesh
	grip.material_override = wood
	grip.position = Vector3(0, -0.035, 0)
	_sword.add_child(grip)
	for py in [-0.12, -0.075, -0.03, 0.015, 0.06]:
		var wrap := MeshInstance3D.new()
		var wrap_mesh := TorusMesh.new()
		wrap_mesh.inner_radius = 0.027
		wrap_mesh.outer_radius = 0.035
		wrap_mesh.rings = 8
		wrap_mesh.ring_segments = 4
		wrap.mesh = wrap_mesh
		wrap.material_override = bronze
		wrap.position = Vector3(0, py, 0)
		_sword.add_child(wrap)
	var pommel := MeshInstance3D.new()
	var pommel_mesh := SphereMesh.new()
	pommel_mesh.radius = 0.055
	pommel_mesh.height = 0.10
	pommel_mesh.radial_segments = 8
	pommel_mesh.rings = 4
	pommel.mesh = pommel_mesh
	pommel.material_override = bronze
	pommel.position = Vector3(0, -0.18, 0)
	_sword.add_child(pommel)
	# 第一人称持剑手与袖口，避免武器像悬浮在镜头前。
	var hand := MeshInstance3D.new()
	var hand_mesh := SphereMesh.new()
	hand_mesh.radius = 0.075
	hand_mesh.height = 0.15
	hand_mesh.radial_segments = 9
	hand_mesh.rings = 5
	hand.mesh = hand_mesh
	hand.material_override = skin
	hand.position = Vector3(0.015, -0.10, 0.015)
	hand.scale = Vector3(0.82, 1.18, 0.82)
	_sword.add_child(hand)
	var sleeve := MeshInstance3D.new()
	var sleeve_mesh := CapsuleMesh.new()
	sleeve_mesh.radius = 0.085
	sleeve_mesh.height = 0.38
	sleeve_mesh.radial_segments = 8
	sleeve_mesh.rings = 4
	sleeve.mesh = sleeve_mesh
	sleeve.material_override = tunic
	sleeve.position = Vector3(0.10, -0.30, 0.08)
	sleeve.rotation_degrees.z = -22.0
	_sword.add_child(sleeve)
	# 半透明剑光由每帧采样剑根与剑尖生成，三段连击颜色逐步升温。
	_sword_trail_mesh = ImmediateMesh.new()
	_sword_trail = MeshInstance3D.new()
	_sword_trail.name = "SwordTrail"
	_sword_trail.mesh = _sword_trail_mesh
	_sword_trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var trail_mat := StandardMaterial3D.new()
	trail_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	trail_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	trail_mat.vertex_color_use_as_albedo = true
	trail_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	trail_mat.no_depth_test = true
	_sword_trail.material_override = trail_mat
	camera.add_child(_sword_trail)


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
	# // FIX: OPT-C5/R4 弓射速闸 0.35s + 最低蓄力 0.25（点抽刷伤害失效）；满抽伤害 38→45
	if _arrow_cd > 0.0:
		return
	if _bow_draw < 0.25:
		_bow_draw = 0.0
		weapon.set_ads(false)
		return
	_arrow_cd = 0.35
	if weapon.reserve <= 0:
		if hud:
			hud.add_feed("没箭了")
		_bow_draw = 0.0
		return
	weapon.reserve -= 1
	weapon.ammo_changed.emit(weapon.mag_left, weapon.reserve)
	var dir := get_aim_dir()
	var dmg := (18.0 + 27.0 * _bow_draw) * damage_mult # // FIX: OPT-C4 弓同乘全局增伤
	var speed := 16.0 + 22.0 * _bow_draw
	var arrow := WildProjectile.new()
	arrow.configure("arrow", dir * speed + Vector3(0, 1.5 * _bow_draw, 0), dmg, self)
	get_parent().add_child(arrow)
	arrow.global_position = camera.global_position + dir * 0.7 - Vector3(0, 0.12, 0)
	var sfx := get_tree().get_first_node_in_group("sfx_bank")
	if sfx:
		sfx.play("shot_bow", -10.0)
	_bow_draw = 0.0
	weapon.set_ads(false)


func _find_melee_target() -> CharacterBody3D:
	var best: CharacterBody3D = null
	var best_score := -99.0
	var seen: Dictionary = {}
	var forward := get_aim_dir()
	forward.y = 0.0
	forward = forward.normalized()
	for group in ["wild_enemy", "wildlife", "combatant"]:
		for candidate in get_tree().get_nodes_in_group(group):
			if candidate == self or not (candidate is CharacterBody3D):
				continue
			var target := candidate as CharacterBody3D
			if seen.has(target.get_instance_id()) or target.get("alive") == false:
				continue
			seen[target.get_instance_id()] = true
			var to_target := target.global_position - global_position
			to_target.y = 0.0
			var distance := to_target.length()
			# // FIX: OPT-C4 锁定半径 4.2→2.9：与 2.6m 弧形判定对齐（保留 lunge 覆盖差），消除锁定必落空
			if distance < 0.15 or distance > 2.9:
				continue
			var facing := forward.dot(to_target / distance)
			if facing < 0.18:
				continue
			# // FIX: R21 隔墙近战：锁定时查 LoS，无直达即隔墙不锁定
			var los_q := PhysicsRayQueryParameters3D.create(global_position + Vector3(0, 0.9, 0), target.global_position + Vector3(0, 0.8, 0), 1, [get_rid()])
			var hit := get_world_3d().direct_space_state.intersect_ray(los_q)
			if not hit.is_empty() and hit.get("collider") != target:
				continue
			var score := facing * 2.2 - distance * 0.18
			if score > best_score:
				best_score = score
				best = target
	return best


func _melee_swing() -> void:
	_melee_cd = 0.5
	_swing_t = 0.0
	_swing_hit_done = false
	if _combo_reset_t <= 0.0:
		_combo_i = 0
	_combo_reset_t = 1.0
	_melee_target = _find_melee_target()
	# 轻微踏步补足第一人称近战距离，但不把玩家瞬移到敌人身上。
	if _melee_target and is_instance_valid(_melee_target):
		var lunge := _melee_target.global_position - global_position
		lunge.y = 0.0
		if lunge.length() > 1.45:
			var lunge_dir := lunge.normalized()
			velocity.x += lunge_dir.x * 3.2
			velocity.z += lunge_dir.z * 3.2
	var sfx := get_tree().get_first_node_in_group("sfx_bank")
	if sfx:
		sfx.play("sword_whoosh", -8.0, 1.0 + _combo_i * 0.08)
	_clear_sword_trail()


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
	# // FIX: OPT-C4/G8/R25 近战同乘 damage_mult（据点 buff/烤串/面具对近战生效）；疾疾倍率 2.0→1.5（OPT-B4）
	var mult := (1.35 if _combo_i == 2 else 1.0) * (1.5 if flurry else 1.0) * armor_melee_mult * damage_mult
	var hit_dmg := melee_damage * mult
	var hit_something := false
	var hit_pos := camera.global_position + get_aim_dir() * 1.6
	var forward := get_aim_dir()
	var hit_ids: Dictionary = {}
	# 中心射线：砍树、点符文等静态可伤害物。
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(camera.global_position, camera.global_position + forward * 2.6, 1 | 4, [get_rid()])
	var result := space.intersect_ray(query)
	if not result.is_empty():
		var col: Object = result.collider
		if col.has_method("take_damage"):
			col.take_damage(hit_dmg, self, "body")
			damage_dealt += hit_dmg # // FIX: OPT-H3
			hit_something = true
			hit_pos = result.position
			if col is CharacterBody3D:
				hit_ids[(col as CharacterBody3D).get_instance_id()] = true
				if col.has_method("apply_melee_impulse"):
					col.apply_melee_impulse(forward, 7.0, _combo_i == 2)
		if col == _stasis_target:
			_stasis_dmg += melee_damage * mult
	# 弧形范围：怪物、动物、AI 战士。
	for group in ["wild_enemy", "wildlife", "combatant"]:
		for target in get_tree().get_nodes_in_group(group):
			if target == self or not (target is CharacterBody3D):
				continue
			if hit_ids.has(target.get_instance_id()):
				continue
			if not target.alive:
				continue
			var to_t: Vector3 = target.global_position + Vector3(0, 0.8, 0) - camera.global_position
			if to_t.length() > 2.6 or to_t.normalized().dot(forward) < 0.5:
				continue
			# // FIX: R21 隔墙近战：弧形判定前查 LoS，隔墙不命中
			var los2 := PhysicsRayQueryParameters3D.create(camera.global_position, target.global_position + Vector3(0, 0.8, 0), 1, [get_rid()])
			var hit2 := get_world_3d().direct_space_state.intersect_ray(los2)
			if not hit2.is_empty() and hit2.get("collider") != target:
				continue
			if target.has_method("take_damage"):
				target.take_damage(hit_dmg, self, "body")
				damage_dealt += hit_dmg # // FIX: OPT-H3
				hit_ids[target.get_instance_id()] = true
				if target.has_method("apply_melee_impulse"):
					target.apply_melee_impulse(forward, 7.0, _combo_i == 2)
				hit_something = true
				hit_pos = target.global_position + Vector3(0, 0.8, 0)
				if target == _stasis_target:
					_stasis_dmg += melee_damage * mult
	if hit_something:
		var sfx := get_tree().get_first_node_in_group("sfx_bank")
		if sfx:
			sfx.play("heavy_impact", -5.0, 0.92 if _combo_i == 2 else 1.05)
		FX.melee_hit(hit_pos, forward, _combo_i == 2)
		if not flurry:
			Engine.time_scale = 0.05
			_hitstop_end_ms = Time.get_ticks_msec() + 50
		pitch += randf_range(0.008, 0.018)


func _clear_sword_trail() -> void:
	_trail_outer.clear()
	_trail_inner.clear()
	if _sword_trail_mesh:
		_sword_trail_mesh.clear_surfaces()


func _sample_sword_trail() -> void:
	if _sword == null or _sword_trail_mesh == null:
		return
	_trail_outer.append(_sword.transform * Vector3(0, 0.87, 0))
	_trail_inner.append(_sword.transform * Vector3(0, 0.11, 0))
	while _trail_outer.size() > 8:
		_trail_outer.pop_front()
		_trail_inner.pop_front()
	_sword_trail_mesh.clear_surfaces()
	if _trail_outer.size() < 2:
		return
	_sword_trail_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in range(_trail_outer.size()):
		var life := float(i + 1) / float(_trail_outer.size())
		var color := Color(0.45, 0.82, 1.0, life * (0.68 if _combo_i < 2 else 0.88))
		if _combo_i == 2:
			color = Color(1.0, 0.72, 0.25, life * 0.88)
		_sword_trail_mesh.surface_set_color(color)
		_sword_trail_mesh.surface_add_vertex(_trail_inner[i])
		_sword_trail_mesh.surface_set_color(Color(color.r, color.g, color.b, color.a * 0.12))
		_sword_trail_mesh.surface_add_vertex(_trail_outer[i])
	_sword_trail_mesh.surface_end()


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
	if _melee_target and is_instance_valid(_melee_target) and _melee_target.get("alive") != false and _swing_t < windup + swipe:
		var assist := _melee_target.global_position - global_position
		assist.y = 0.0
		if assist.length_squared() > 0.01:
			var assist_yaw := atan2(assist.x, assist.z) + PI
			rotation.y = lerp_angle(rotation.y, assist_yaw, minf(1.0, delta * 11.0))
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
		_sample_sword_trail()
	elif _swing_t < windup + swipe + recover:
		var t := (_swing_t - windup - swipe) / recover
		t = t * t * (3.0 - 2.0 * t)
		_sword.position = poses[1][0].lerp(_sword_base_pos, t)
		_sword.rotation = poses[1][1].lerp(_sword_base_rot, t)
		if t > 0.45:
			_clear_sword_trail()
	else:
		_swing_t = -1.0
		_combo_i = (_combo_i + 1) % 3
		_melee_target = null
		_clear_sword_trail()
		_sword.position = _sword_base_pos
		_sword.rotation = _sword_base_rot

# ---------- 攀爬（树干 / 塔身 / 悬崖，一切陡面） ----------

func _update_climbing(_delta: float, f: float, r: float) -> bool:
	if _ladder != null or backpack_open or journal_open or vehicle != null:
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
		if Input.is_action_pressed("jump") or Input.is_action_pressed("glide"):
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
	_set_player_capsule("swim")
	if is_gliding:
		_set_gliding(false)
	if is_dropping:
		is_dropping = false
		landed.emit()
	is_swimming = true
	# // FIX: R2-5 入水水花/水声已上移至 water_now 边沿（此处原每物理帧触发，60次/s 抢占音池）
	prone = false
	var surface := terrain.get_water_level(global_position.x, global_position.z)
	var swim_speed := SWIM_SPEED * (1.18 if Input.is_action_pressed("sprint") else 1.0)
	var target_h := wish * swim_speed
	var hv := Vector3(velocity.x, 0, velocity.z).move_toward(target_h, 12.0 * delta)
	velocity.x = hv.x
	velocity.z = hv.z
	var vertical_input := Input.get_axis("crouch", "jump")
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
	_stamina_wait = 1.5 # // FIX: OPT-G5/PG12 回复延迟 0.45→1.5s


func _set_player_capsule(mode: String) -> void:
	if _col == null or _col.shape == null:
		return
	if mode == "swim":
		_col.shape.height = 1.1
		_col.position.y = 0.55
	elif mode == "prone":
		_col.shape.height = 0.9
		_col.position.y = 0.45
	else:
		_col.shape.height = 1.7
		_col.position.y = 0.85


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

# J 键冒险日志：打开时展示任务面板并暂停移动（与背包同级）。
func _toggle_journal() -> void:
	journal_open = not journal_open
	if journal_open:
		if backpack_open:
			_toggle_backpack()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		var scene := get_tree().current_scene
		if hud and scene and scene.has_method("get_journal_entries"):
			hud.show_journal(scene.get_journal_entries())
	elif hud:
		hud.hide_journal()
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


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
	return get_backpack_lines().size()


func _refresh_backpack() -> void:
	if backpack_open and hud:
		hud.show_backpack(get_backpack_lines(), backpack_index)


# 烹饪/炼药成功：开锅琶音 + 金色蒸汽 + “完成！”浮签（原创旷野式的完成感）。
func _cook_feedback() -> void:
	var sfx := get_tree().get_first_node_in_group("sfx_bank")
	if sfx:
		sfx.play("cook", -6.0)
	FX.impact(global_position + Vector3(0, 1.3, 0), Color(1.0, 0.85, 0.40))
	DamageNumber.spawn_at(get_tree().current_scene, global_position + Vector3(0, 2.0, 0), "完成！", Color(1.0, 0.85, 0.40))


func get_backpack_lines() -> Array[String]:
	var lines: Array[String] = []
	for packed in backpack_weapons:
		var id: String = packed["id"]
		lines.append("装备 · %s  %d/%d" % [Weapon.WEAPONS[id].label, int(packed["mag"]), int(packed["reserve"])])
	lines.append("食材 · 旷野蘑菇 × %d（回血 18）" % int(backpack_items["mushroom"]))
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


func _check_and_clear_expired_elixir() -> void:
	if _elixir_stam_end_ms > 0 and Time.get_ticks_msec() >= _elixir_stam_end_ms:
		_elixir_stam_end_ms = 0
		max_stamina -= 20.0
		stamina = minf(stamina, max_stamina)
		if hud:
			hud.add_feed("药剂效果消退了")


func _use_backpack_selection() -> void:
	_check_and_clear_expired_elixir()
	if backpack_index < backpack_weapons.size():
		_retrieve_weapon(backpack_index)
		return
	var item_index := backpack_index - backpack_weapons.size()
	var keys: Array[String] = ["mushroom", "meat", "dragon_scale", "wood", "roast_meat", "roast_mushroom", "armor_soldier", "armor_climber", "armor_barbarian", "monster_part"]
	if item_index < 0 or item_index >= keys.size():
		return
	var key: String = keys[item_index]
	var count := int(backpack_items.get(key, 0))
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
			_cook_feedback()
		elif int(backpack_items["meat"]) >= 1:
			backpack_items["monster_part"] = count - 1
			backpack_items["meat"] = int(backpack_items["meat"]) - 1
			var has_elixir := _elixir_stam_end_ms > Time.get_ticks_msec()
			_elixir_stam_end_ms = Time.get_ticks_msec() + 60000
			if not has_elixir:
				max_stamina = minf(200.0, max_stamina + 20.0)
			stamina = max_stamina
			hud.add_feed("炼成精力药剂：精力全满，上限 +20（60 秒）")
			_cook_feedback()
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
		_cook_feedback()
		backpack_changed.emit()
		_refresh_backpack()
		return
	if key in ["meat", "mushroom"] and near_fire:
		backpack_items[key] = count - 1
		var cooked := "roast_meat" if key == "meat" else "roast_mushroom"
		backpack_items[cooked] = int(backpack_items[cooked]) + 1
		if hud:
			hud.add_feed("烤制成功：%s" % ("烤兽肉" if key == "meat" else "烤蘑菇"))
		_cook_feedback()
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
