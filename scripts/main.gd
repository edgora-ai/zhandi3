extends Node3D
## 游戏总控：环境、世界生成、比赛流程（空降 → 搜刮 → 缩圈/占点 → 吃鸡）

const BOT_COUNT := 23
const BOT_NAMES := ["战虎", "孤狼", "夜莺", "雷霆", "幽灵", "猎鹰", "毒蝎", "雪豹", "黑曜", "赤狐", "苍狼", "飞鹰", "铁壁", "疾风", "灰烬", "寒鸦", "断刃", "追猎", "重锤", "影袭", "怒涛", "磐石", "烈阳"]

var terrain: Terrain
var props: Props
var player: Player
var hud: HUD
var zone: Zone
var sfx: SfxBank
var capture_points: Array[CapturePoint] = []

var match_over := false
var total_combatants := BOT_COUNT + 1
var _buff_acc := 0.0

var _shot_path := ""
var _shot_frames := -1
var _sim := false
var _sim_acc := 0.0
var _ft_bot: Bot = null
var _ft_frames := -1
var _mt := -1
var _mt_start := Vector3.ZERO


func _ready() -> void:
	_setup_environment()
	terrain = Terrain.new()
	terrain.name = "Terrain"
	add_child(terrain)
	props = Props.new()
	props.name = "Props"
	add_child(props)
	props.generate(terrain)

	zone = Zone.new()
	zone.name = "Zone"
	add_child(zone)

	sfx = SfxBank.new()
	sfx.name = "SfxBank"
	sfx.add_to_group("sfx_bank")
	add_child(sfx)
	zone.shrinking_changed.connect(func(sh: bool) -> void:
		if sh:
			sfx.play("zone_alarm", -4.0)
	)

	var rng := RandomNumberGenerator.new()
	rng.randomize()
	_spawn_player(rng)
	_spawn_bots(rng)
	_spawn_capture_points(rng)
	_spawn_loot_field(rng)
	zone.start(10.0)

	var args := OS.get_cmdline_user_args()
	if args.has("--ground"):
		player.global_position.y = terrain.get_height(player.global_position.x, player.global_position.z) + 1.0
	if args.has("--arm"):
		player.give_weapon("rifle")
	_sim = args.has("--sim")
	if args.has("--endtest"):
		hud.show_end(false, 12, 3, 24)
	if args.has("--firetest") and args.has("--ground") and args.has("--arm"):
		_ft_bot = Bot.new()
		add_child(_ft_bot)
		var fwd := -player.global_transform.basis.z
		fwd.y = 0.0
		fwd = fwd.normalized()
		var p := player.global_position + fwd * 12.0
		p.y = terrain.get_height(p.x, p.z)
		_ft_bot.setup("测试兵", zone, terrain, p)
		_ft_bot.global_position = p + Vector3(0, 0.2, 0)
		_ft_frames = 0
	if args.has("--movetest") and args.has("--ground"):
		_mt = 0
	_setup_screenshot_mode()


func find_land_point(rng: RandomNumberGenerator, margin: float = 0.62) -> Vector3:
	for i in range(200):
		var x := rng.randf_range(-Terrain.HALF * margin, Terrain.HALF * margin)
		var z := rng.randf_range(-Terrain.HALF * margin, Terrain.HALF * margin)
		var y := terrain.get_height(x, z)
		if y > Terrain.WATER_LEVEL + 1.0 and terrain.get_normal(x, z).y > 0.82:
			return Vector3(x, y, z)
	return Vector3(0, terrain.get_height(0, 0), 0)


func _alive_count() -> int:
	var n := 0
	for c in get_tree().get_nodes_in_group("combatant"):
		if c.alive:
			n += 1
	return n


# ---------- 生成 ----------

func _spawn_player(rng: RandomNumberGenerator) -> void:
	player = Player.new()
	player.name = "Player"
	add_child(player)
	var land := find_land_point(rng)
	player.global_position = land + Vector3(0, 130, 0)
	player.died.connect(_on_combatant_died)

	hud = HUD.new()
	add_child(hud)
	player.health_changed.connect(hud.set_health)
	player.damaged.connect(func(_a: float) -> void: hud.flash_damage())
	player.weapon.ammo_changed.connect(hud.set_ammo)
	player.weapon.fired.connect(func() -> void: sfx.play("shot_" + player.weapon.weapon_id, -2.0))
	player.weapon.hit_landed.connect(func() -> void: sfx.play("hit", -8.0))
	hud.set_health(player.hp, player.armor)
	hud.set_weapon_name("徒手")
	hud.set_ammo_text("--")
	hud.set_alive(total_combatants)
	hud.set_kills(0)

	# 落点保底物资：一把步枪 + 护甲
	var g := land + Vector3(rng.randf_range(-4, 4), 0, rng.randf_range(-4, 4))
	g.y = terrain.get_height(g.x, g.z) + 0.1
	Loot.spawn(self, g, "weapon", "rifle", 0, 2)
	var a := land + Vector3(rng.randf_range(-5, 5), 0, rng.randf_range(-5, 5))
	a.y = terrain.get_height(a.x, a.z) + 0.1
	Loot.spawn(self, a, "armor", "", 25, 1)


func _spawn_bots(rng: RandomNumberGenerator) -> void:
	for i in range(BOT_COUNT):
		var bot := Bot.new()
		bot.name = "Bot_%s" % BOT_NAMES[i]
		add_child(bot)
		var land := find_land_point(rng, 0.8)
		bot.setup(BOT_NAMES[i], zone, terrain, land)
		bot.global_position = land + Vector3(rng.randf_range(-20, 20), rng.randf_range(120.0, 170.0), rng.randf_range(-20, 20))
		bot.rotation.y = rng.randf_range(0, TAU)
		bot.died.connect(_on_combatant_died)
		bot.weapon.fired.connect(func() -> void: sfx.play_at("shot_" + bot.weapon.weapon_id, bot.global_position, -10.0))


func _spawn_capture_points(rng: RandomNumberGenerator) -> void:
	var names := ["A", "B", "C"]
	var spots: Array[Vector3] = []
	var guard := 0
	while spots.size() < 3 and guard < 100:
		guard += 1
		var p := find_land_point(rng, 0.6)
		var ok := true
		for s in spots:
			if s.distance_to(p) < 90.0:
				ok = false
				break
		if ok:
			spots.append(p)
	for i in range(spots.size()):
		var cp := CapturePoint.new()
		cp.name = "Capture_%s" % names[i]
		cp.point_name = names[i]
		add_child(cp)
		cp.global_position = spots[i]
		cp.owner_changed.connect(_on_capture_changed)
		capture_points.append(cp)


func _spawn_loot_field(rng: RandomNumberGenerator) -> void:
	# 6 个物资点 + 全图散刷
	for p in range(6):
		var center := find_land_point(rng, 0.7)
		var count := rng.randi_range(9, 13)
		for i in range(count):
			var off := Vector3(rng.randf_range(-13, 13), 0, rng.randf_range(-13, 13))
			_drop_loot_at(rng, center + off)
	for i in range(24):
		_drop_loot_at(rng, find_land_point(rng, 0.8))


func _drop_loot_at(rng: RandomNumberGenerator, pos: Vector3) -> void:
	pos.y = terrain.get_height(pos.x, pos.z)
	if pos.y < Terrain.WATER_LEVEL + 0.5:
		return
	pos.y += 0.1
	var roll := rng.randf()
	if roll < 0.45:
		var w := rng.randf()
		if w < 0.40:
			Loot.spawn(self, pos, "weapon", "smg", 0, 1)
		elif w < 0.80:
			Loot.spawn(self, pos, "weapon", "rifle", 0, 2)
		else:
			Loot.spawn(self, pos, "weapon", "dmr", 0, 3)
	elif roll < 0.63:
		var amt := 50 if rng.randf() < 0.4 else 25
		Loot.spawn(self, pos, "armor", "", amt, 2 if amt == 50 else 1)
	elif roll < 0.81:
		Loot.spawn(self, pos, "medkit", "", 60 if rng.randf() < 0.5 else 40, 1)
	else:
		Loot.spawn(self, pos, "ammo", "", 90 if rng.randf() < 0.4 else 45, 1)


# ---------- 比赛事件 ----------

func _on_combatant_died(victim: Variant, killer: Variant) -> void:
	var killer_name := "毒圈"
	if killer != null:
		killer_name = "你" if killer == player else killer.display_name
	var victim_name: String = "你" if victim == player else victim.display_name
	hud.add_feed("%s 淘汰了 %s" % [killer_name, victim_name])
	hud.set_alive(_alive_count())
	hud.set_kills(player.kills)

	if victim == player:
		match_over = true
		sfx.play("defeat", -2.0)
		var rank := _alive_count() + 1
		get_tree().create_timer(1.5).timeout.connect(func() -> void:
			hud.show_end(false, rank, player.kills, total_combatants)
		)
		return
	if not match_over and _alive_count() == 1 and player.alive:
		match_over = true
		player.input_locked = true
		sfx.play("victory", -2.0)
		hud.show_end(true, 1, player.kills, total_combatants)


func _on_capture_changed(point: CapturePoint, new_owner: Variant) -> void:
	var n: String = "你" if new_owner == player else new_owner.display_name
	hud.add_feed("%s 占领了据点 %s" % [n, point.point_name])
	if new_owner == player:
		sfx.play("capture", -3.0)


func _recompute_buffs() -> void:
	for c in get_tree().get_nodes_in_group("combatant"):
		if c.alive:
			c.damage_mult = 1.0
			c.regen_rate = 0.0
	for cp in capture_points:
		if cp.owner_body and cp.owner_body.alive:
			cp.owner_body.damage_mult *= 1.1
			cp.owner_body.regen_rate += 3.0


func _unhandled_input(event: InputEvent) -> void:
	if match_over and event is InputEventKey and event.pressed and event.physical_keycode == KEY_R:
		get_tree().reload_current_scene()


# 窗口失去焦点（Cmd+Space、切应用、手势误触）时自动暂停，切回继续，
# 避免输入全断、角色定在原地任人宰割，看起来像"卡死"
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		if match_over or player == null or not player.alive or get_tree().paused:
			return
		get_tree().paused = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		hud.show_pause()
	elif what == NOTIFICATION_WM_WINDOW_FOCUS_IN:
		if not get_tree().paused:
			return
		get_tree().paused = false
		hud.hide_pause()
		if player and player.alive and not match_over:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _process(delta: float) -> void:
	if _shot_frames >= 0:
		_shot_frames -= 1
		if _shot_frames == 0:
			var img := get_viewport().get_texture().get_image()
			var err := img.save_png(_shot_path)
			print("screenshot saved: ", _shot_path, " err=", err)
			get_tree().quit()
		return
	if player == null or hud == null:
		return

	for c in _clouds:
		c.position.x += 1.6 * delta
		if c.position.x > 460.0:
			c.position.x = -460.0

	if _ft_frames >= 0:
		_ft_frames += 1
		if _ft_bot:
			var chest: Vector3 = _ft_bot.global_position + Vector3(0, 1.0, 0)
			var d: Vector3 = (chest - player.camera.global_position).normalized()
			player.rotation.y = atan2(-d.x, -d.z)
			player.pitch = asin(clampf(d.y, -1.0, 1.0))
			player.camera.rotation.x = player.pitch
			if _ft_frames % 12 == 3:
				player.weapon.pull_trigger()
			if _ft_frames % 30 == 0:
				print("[firetest] bot_hp=%.1f armor=%.1f alive=%s" % [_ft_bot.hp, _ft_bot.armor, str(_ft_bot.alive)])
		if _ft_frames >= 200:
			print("[firetest] done")
			_ft_frames = -1

	if _mt >= 0:
		_mt += 1
		if _mt == 20:
			_mt_start = player.global_position
			player.debug_move = 1.0
		elif _mt == 110:
			player.debug_move = 0.0
			var d := player.global_position - _mt_start
			print("[movetest] 前进90帧 水平位移=%.2f m  pos=%s" % [Vector2(d.x, d.z).length(), str(player.global_position)])
		elif _mt == 130:
			print("[movetest] done")
			_mt = -1

	_buff_acc += delta
	if _buff_acc >= 0.5:
		_buff_acc = 0.0
		_recompute_buffs()

	if _sim:
		_sim_acc += delta
		if _sim_acc >= 10.0:
			_sim_acc = 0.0
			print("[sim] frame=%d alive=%d zone_r=%d phase=%d match_over=%s" % [Engine.get_process_frames(), _alive_count(), int(zone.radius), zone.phase, str(match_over)])
		if _sim_acc >= 10.0:
			_sim_acc = 0.0
			print("[sim] frame=%d alive=%d zone_r=%d phase=%d match_over=%s" % [Engine.get_process_frames(), _alive_count(), int(zone.radius), zone.phase, str(match_over)])

	if not player.alive:
		return
	hud.set_spread(6.0 + player.weapon.current_spread() * 9.0)
	hud.set_crosshair_visible(player.weapon.weapon_id != "")
	if player.nearby_loot:
		hud.set_interact("按 E 拾取  " + player.nearby_loot.describe())
	else:
		hud.set_interact("")
	hud.set_weapon_name(player.weapon.label())
	if player.weapon.weapon_id == "":
		hud.set_ammo_text("--")
	hud.set_zone_text(zone.status_text())
	if zone.active and zone.is_outside(player.global_position):
		hud.set_danger(true)
	# 占点提示
	var shown := false
	for cp in capture_points:
		var st: Array = cp.hud_status(player)
		if st[1] >= 0.0:
			hud.set_capture(st[0], st[1])
			shown = true
			break
	if not shown:
		hud.set_capture("", -1.0)


func _setup_environment() -> void:
	var env := Environment.new()
	var sky := Sky.new()
	var psm := ProceduralSkyMaterial.new()
	psm.sky_top_color = Color(0.24, 0.56, 0.95)
	psm.sky_horizon_color = Color(0.78, 0.89, 0.96)
	psm.ground_bottom_color = Color(0.32, 0.42, 0.30)
	psm.ground_horizon_color = Color(0.72, 0.84, 0.80)
	psm.sun_curve = 0.09
	sky.sky_material = psm
	env.sky = sky
	env.background_mode = Environment.BG_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.5
	# 卡通渲染用 Linear 保持颜色饱和（ACES 会把亮色洗白）
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.tonemap_exposure = 1.0
	# 远景蓝色大气雾（旷野之息的空气感）
	env.fog_enabled = true
	env.fog_light_color = Color(0.68, 0.80, 0.92)
	env.fog_light_energy = 0.8
	env.fog_density = 0.0009
	env.fog_sky_affect = 0.2
	# 轻微泛光，让天空和水面更通透
	env.glow_enabled = true
	env.glow_intensity = 0.2
	env.glow_strength = 0.6
	env.glow_bloom = 0.05
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.light_color = Color(1.0, 0.93, 0.78)
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 250.0
	sun.shadow_bias = 0.03
	sun.rotation_degrees = Vector3(-48.0, -35.0, 0.0)
	add_child(sun)

	_spawn_clouds()


var _clouds: Array[Node3D] = []

func _spawn_clouds() -> void:
	# 扁平大朵白云，缓慢漂移（旷野之息招牌天空）
	var rng := RandomNumberGenerator.new()
	rng.seed = 88
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 1.0, 1.0, 0.88)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.disable_fog = true
	for i in range(14):
		var cloud := Node3D.new()
		cloud.position = Vector3(rng.randf_range(-420, 420), rng.randf_range(115, 155), rng.randf_range(-420, 420))
		for j in range(rng.randi_range(3, 5)):
			var puff := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = rng.randf_range(7.0, 15.0)
			sm.height = sm.radius * 2.0
			sm.radial_segments = 8
			sm.rings = 4
			puff.mesh = sm
			puff.material_override = mat
			puff.position = Vector3(rng.randf_range(-16, 16), rng.randf_range(-2, 2), rng.randf_range(-7, 7))
			puff.scale = Vector3(1.5, 0.42, 1.0)
			puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			cloud.add_child(puff)
		add_child(cloud)
		_clouds.append(cloud)


# ---------- 截图模式（供自动化验证画面） ----------

func _setup_screenshot_mode() -> void:
	var args := OS.get_cmdline_user_args()
	var i := args.find("--screenshot")
	if i < 0 or i + 1 >= args.size():
		return
	_shot_path = args[i + 1]
	var frames := 40
	var fi := args.find("--frames")
	if fi >= 0 and fi + 1 < args.size():
		frames = maxi(1, args[fi + 1].to_int())
	var ci := args.find("--cam")
	if ci < 0 or ci + 1 >= args.size():
		# 无 --cam 参数时用玩家视角截图
		_shot_frames = frames
		return
	var cam := Camera3D.new()
	cam.name = "ShotCamera"
	var pos := Vector3(70.0, 30.0, 100.0)
	var target := Vector3(0.0, 8.0, 0.0)
	var parts := args[ci + 1].split(",")
	if parts.size() == 6:
		pos = Vector3(parts[0].to_float(), parts[1].to_float(), parts[2].to_float())
		target = Vector3(parts[3].to_float(), parts[4].to_float(), parts[5].to_float())
	cam.position = pos
	cam.look_at_from_position(pos, target, Vector3.UP)
	cam.far = 2000.0
	add_child(cam)
	cam.make_current()
	_shot_frames = frames
