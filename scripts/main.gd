extends Node3D
## 游戏总控：环境、世界生成、比赛流程（空降 → 搜刮 → 缩圈/占点 → 吃鸡）

const BOT_COUNT := 23
const BOT_NAMES := ["战虎", "孤狼", "夜莺", "雷霆", "幽灵", "猎鹰", "毒蝎", "雪豹", "黑曜", "赤狐", "苍狼", "飞鹰", "铁壁", "疾风", "灰烬", "寒鸦", "断刃", "追猎", "重锤", "影袭", "怒涛", "磐石", "烈阳"]
const INSTANCE_LOCK := "user://zhandi3_game.pid"
const MAP_SELECTION := "user://selected_map.txt"

var terrain: Terrain
var props: Props
var buildings: Buildings
var wild_world: WildWorld
var seasons: SeasonSystem
var daynight: DayNight
var weather: Weather
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
var _reloadtest := false
var _smoketest := false
var _owns_instance_lock := false
var _focus_pause_owned := false
var _focus_recovery_timer: Timer
var _focus_recovery_test_frame := -1
var _focus_recovery_test_pending := false
var _env: Environment
var _sky_mat: ProceduralSkyMaterial
var _sun: DirectionalLight3D
var _fill: DirectionalLight3D
var _rim: DirectionalLight3D
var _season_test_frame := -1
var _map_id := "battlefield"
var _map_menu_open := false
var warp_points: Array[Dictionary] = []
var _map_from_cli := false
var _show_initial_map_menu := false
var _map_pause_owned := false
var _wild_test_frame := -1
var _wild_test_height := 0.0
var _wild_test_horse_start := Vector3.ZERO
var _wild_test_bike_start := Vector3.ZERO
var _wild_test_jeep_start := Vector3.ZERO
var _wild_test_jeep_yaw := 0.0
var _wild_test_jeep_peak_speed := 0.0
var _wild_test_loot_before := 0
var _wild_test_stamina := 0.0
var _wild_test_surf_start := Vector3.ZERO
var _wild_test_moblin: WildMoblin = null
var _wild_test_parry_hp := 0.0
var quest_states := {"mushroom3": 0, "moblin2": 0, "scale1": 0, "escort": 0}
var _escort_npc: WildNPC = null
var _stasis_test_mob: WildMoblin = null
var _stasis_test_pos := Vector3.ZERO
var _stasis_test_hp := 0.0
var _elixir_test_stam := 0.0
var _quest_mushroom_base := 0
var _quest_moblin_kills := 0
var _wild_test_hp := 0.0
var _music_check_t := 0.0
var _thundertest_frame := -1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var boot_t0 := Time.get_ticks_msec()
	if not _acquire_instance_lock():
		get_tree().quit()
		return
	tree_exiting.connect(_release_instance_lock)
	var args := OS.get_cmdline_user_args()
	_map_id = _resolve_map(args)
	_map_from_cli = args.find("--map") >= 0
	_show_initial_map_menu = args.has("--mapmenutest") or (not args.has("--wildtest") and not _map_from_cli and not FileAccess.file_exists(MAP_SELECTION) and DisplayServer.get_name() != "headless")
	total_combatants = 9 if _map_id == "wild" else BOT_COUNT + 1
	_setup_environment()
	print("[boot_t] environment %dms" % (Time.get_ticks_msec() - boot_t0))
	terrain = Terrain.new()
	terrain.name = "Terrain"
	terrain.configure(_map_id)
	add_child(terrain)
	print("[boot_t] terrain +%dms" % (Time.get_ticks_msec() - boot_t0))
	props = Props.new()
	props.name = "Props"
	add_child(props)
	if not args.has("--noveg"):
		props.generate(terrain)
	print("[boot_t] env+terrain+props %dms" % (Time.get_ticks_msec() - boot_t0))
	buildings = Buildings.new()
	buildings.name = "Buildings"
	add_child(buildings)
	if not args.has("--noworld") and _map_id == "battlefield":
		buildings.generate(terrain)

	zone = Zone.new()
	zone.name = "Zone"
	add_child(zone)
	zone.visible = _map_id == "battlefield"

	sfx = SfxBank.new()
	sfx.name = "SfxBank"
	sfx.add_to_group("sfx_bank")
	add_child(sfx)
	zone.shrinking_changed.connect(func(sh: bool) -> void:
		if sh:
			sfx.play("zone_alarm", -4.0)
	)
	if DisplayServer.get_name() != "headless":
		sfx.start_ambience()

	var rng := RandomNumberGenerator.new()
	var si := args.find("--seed")
	if si >= 0 and si + 1 < args.size():
		rng.seed = args[si + 1].to_int()
	else:
		rng.randomize()
	_spawn_player(rng)
	seasons = SeasonSystem.new()
	seasons.name = "SeasonSystem"
	add_child(seasons)
	seasons.season_changed.connect(func(_season_name: String, display_name: String) -> void:
		hud.add_feed("季节切换：%s" % display_name)
	)
	var initial_season := "spring"
	var season_i := args.find("--season")
	if season_i >= 0 and season_i + 1 < args.size():
		initial_season = args[season_i + 1]
	seasons.setup(terrain, props, buildings, player, initial_season)
	daynight = DayNight.new()
	daynight.name = "DayNight"
	add_child(daynight)
	daynight.setup(_env, _sky_mat, _sun, _fill, _rim)
	daynight.blood_moon_started.connect(_on_blood_moon)
	weather = Weather.new()
	weather.name = "Weather"
	add_child(weather)
	weather.setup(terrain, player, _env)
	if args.has("--rain"):
		weather.force_rain(true)
	if args.has("--thundertest") and weather:
		weather.force_rain(true)
		_thundertest_frame = 0
	if args.has("--night"):
		daynight.t = 0.8
		daynight._apply()
	if args.has("--bloodmoon"):
		daynight._night_index = 2
		daynight.t = 0.799
		daynight.advance(0.02)
	if not args.has("--noworld") and _map_id == "battlefield":
		_spawn_bots(rng)
		_spawn_capture_points(rng)
		_spawn_loot_field(rng)
	elif not args.has("--noworld"):
		wild_world = WildWorld.new()
		wild_world.name = "WildWorld"
		add_child(wild_world)
		wild_world.generate(terrain, player)
		print("[boot_t] wild_world.generate +%dms" % (Time.get_ticks_msec() - boot_t0))
		_spawn_wild_bots(rng)
	if _map_id == "battlefield":
		zone.start(10.0)
	else:
		hud.set_alive_text("阔野探索")
		hud.set_kills(0)
	if args.has("--ground"):
		player.global_position.y = terrain.get_height(player.global_position.x, player.global_position.z) + 1.0
	if args.has("--arm"):
		player.give_weapon("rifle")
	_sim = args.has("--sim")
	_reloadtest = args.has("--reloadtest")
	_smoketest = args.has("--smoketest")
	if args.has("--focusrecoverytest"):
		_focus_recovery_test_frame = 0
	if args.has("--seasontest"):
		_season_test_frame = 0
	if args.has("--feedtest"):
		for i in range(12):
			hud.add_feed("播报上限回归 %02d" % i)
		print("[feedtest] items=%d expected=%d" % [hud.feed_item_count(), HUD.MAX_FEED_ITEMS])
	if args.has("--wildtest"):
		_wild_test_frame = 0
	if args.has("--backpacktest"):
		player.give_weapon("rifle")
		player.give_weapon("smg")
		player.give_weapon("dmr")
		player.give_item("mushroom", 4)
		player.give_item("meat", 3)
		player.give_item("dragon_scale", 1)
		call_deferred("_open_backpack_test")
	if args.has("--shoptest"):
		player.rupees = 65
		call_deferred("_open_shop_test")
	if args.has("--endtest"):
		hud.show_end(false, 12, 3, 24)
	if args.has("--ridertest") and _map_id == "wild":
		var rt_horse := get_tree().get_first_node_in_group("vehicle") as Horse
		if rt_horse:
			rt_horse.bonded = true
			player.global_position = rt_horse.global_position + Vector3(1.2, 0, 0)
			rt_horse.enter(player)
			rt_horse.debug_forward = 0.6
	if args.has("--biketest") and _map_id == "wild":
		var rt_bike := get_tree().get_first_node_in_group("vehicle") as WildMotorcycle
		if rt_bike:
			player.global_position = rt_bike.global_position + Vector3(1.2, 0, 0)
			rt_bike.enter(player)
			rt_bike.debug_forward = 0.5
	if args.has("--koroktest") and terrain:
		var kpos := player.global_position - player.global_transform.basis.z * 2.5
		kpos.y = terrain.get_height(kpos.x, kpos.z)
		Korok.spawn(self, kpos, player.global_position)
	if args.has("--melleetest"):
		player._melee_swing()
	if args.has("--climbtest") and terrain:
		player.global_position = Vector3(-129.3, terrain.get_height(-129.3, 109) + 0.1, 109)
		player.rotation.y = atan2(-132.0 - player.global_position.x, 109.0 - player.global_position.z) + PI
		player.debug_move = 1.0
	if args.has("--snowtest") and weather:
		weather.snowing = true
		weather.snow_strength = 1.0
	if args.has("--glidetest") and terrain:
		player.global_position = Vector3(-86, terrain.get_height(-86, 92) + 18.0, 92)
		player.rotation.y = 2.4
		player.debug_glide = true
	if args.has("--bombtest"):
		player._place_bomb()
	if args.has("--cryonistest") and terrain:
		var wspot := Vector3.ZERO
		for xi in range(-60, 61, 2):
			if terrain.is_in_water(float(xi), 50.0):
				wspot = Vector3(float(xi), Terrain.WATER_LEVEL, 50.0)
				break
		if wspot != Vector3.ZERO:
			player.global_position = wspot + Vector3(0, 1.5, 5.0)
			var wdir2 := (wspot - player.camera.global_position).normalized()
			player.rotation.y = atan2(wdir2.x, wdir2.z) + PI
			player.pitch = -0.2
			player.camera.rotation.x = -0.2
			player._raise_ice()
	if args.has("--magnesistest"):
		var mtp := get_tree().get_first_node_in_group("metal_prop") as MetalProp
		if mtp and terrain:
			mtp.global_position = Vector3(-72, terrain.get_height(-72, 21) + 0.5, 21)
			mtp.linear_velocity = Vector3.ZERO
			player.global_position = mtp.global_position + Vector3(0, 0, 7.0)
			var mdir2 := (mtp.global_position - player.camera.global_position).normalized()
			player.rotation.y = atan2(mdir2.x, mdir2.z) + PI
			player.pitch = -0.05
			player.camera.rotation.x = -0.05
			player._toggle_magnet()
	if args.has("--keesetest") and daynight:
		daynight.t = 0.8
	if args.has("--stasistest") and _map_id == "wild":
		var stm := get_tree().get_first_node_in_group("wild_enemy") as WildMoblin
		if stm:
			player.global_position = stm.global_position + Vector3(0, 0, 5.0)
			var sdir := (stm.global_position - player.camera.global_position).normalized()
			player.rotation.y = atan2(sdir.x, sdir.z) + PI
			player.pitch = -0.05
			player.camera.rotation.x = -0.05
			player._toggle_stasis()
	if args.has("--flurrytest"):
		player._start_flurry()
	if args.has("--dietest"):
		player.fairies = 0
		player.take_damage(9999.0, null)
	if args.has("--journaltest"):
		player._toggle_journal()
	if args.has("--shrineintest") and wild_world:
		var st: ShrineTrial = wild_world.trials[0]
		for rune in st._runes:
			rune.take_damage(10.0, player)
		var sdoor := get_tree().get_first_node_in_group("shrine_door") as ShrineDoor
		if sdoor:
			sdoor.enter(player)
			get_tree().create_timer(1.0).timeout.connect(func() -> void: sdoor.interior.leave(player))
	if args.has("--cracktest") and terrain:
		player.global_position = Vector3(-88, terrain.get_height(-88, 92) + 0.5, 92)
		var cdir := (Vector3(-95, terrain.get_height(-95, 92) + 1.0, 92) - player.global_position).normalized()
		player.rotation.y = atan2(cdir.x, cdir.z) + PI
		player._place_bomb()
		get_tree().create_timer(1.2).timeout.connect(player._detonate_bombs)
	if args.has("--dragontest") and terrain:
		player.global_position = Vector3(150, terrain.get_height(150, -128) + 1.0, -128)
		player.rotation.y = atan2(164.0 - 150.0, -145.0 + 128.0) + PI
	if args.has("--hinoxtest") and terrain:
		player.global_position = Vector3(63, terrain.get_height(63, 52) + 0.5, 52)
		player.rotation.y = atan2(70.0 - 63.0, 45.0 - 52.0) + PI
	if args.has("--pilottest") and terrain:
		var pilot_scene: PackedScene = load("res://assets/models/pilot_npc.glb")
		if pilot_scene:
			var pilot := pilot_scene.instantiate()
			add_child(pilot)
			var ppos := player.global_position - player.global_transform.basis.z * 3.0
			ppos.y = terrain.get_height(ppos.x, ppos.z)
			pilot.global_position = ppos
			var look := player.global_position - ppos
			look.y = 0.0
			if look.length_squared() > 0.01:
				pilot.rotation.y = atan2(look.normalized().x, look.normalized().z) + PI
			var anim := pilot.find_child("AnimationPlayer", true, false) as AnimationPlayer
			if anim and not anim.get_animation_list().is_empty():
				anim.play(anim.get_animation_list()[0])
			print("[pilot] anims=%s loop=%s" % [str(anim.get_animation_list() if anim else []), str(anim.get_animation(anim.get_animation_list()[0]).loop_mode if anim and not anim.get_animation_list().is_empty() else -1)])
	if args.has("--moblintest") and _map_id == "wild":
		var mb: WildMoblin = null
		for enemy in get_tree().get_nodes_in_group("wild_enemy"):
			if enemy is WildMoblin and enemy.alive:
				mb = enemy as WildMoblin
				break
		if mb:
			var test_ground := Vector3(-22.0, terrain.get_height(-22.0, 104.0) + 0.05, 104.0)
			mb.global_position = test_ground
			mb._home = test_ground
			player.global_position = test_ground + Vector3(0, 0, 4.0)
			var to_mb := mb.global_position - player.global_position
			player.rotation.y = atan2(to_mb.x, to_mb.z) + PI
			player.pitch = -0.08
			player.camera.rotation.x = -0.08
			var to_player := player.global_position - mb.global_position
			mb.rotation.y = atan2(to_player.x, to_player.z) + PI
			mb._windup = 0.0
			mb._play(&"windup")
	if args.has("--liztest") and _map_id == "wild":
		var liz: WildLizalfos = null
		for enemy in get_tree().get_nodes_in_group("wild_enemy"):
			if enemy is WildLizalfos and enemy.alive:
				liz = enemy as WildLizalfos
				break
		if liz:
			var liz_ground := Vector3(-22.0, terrain.get_height(-22.0, 104.0) + 0.05, 104.0)
			liz.global_position = liz_ground
			liz._home = liz_ground
			player.global_position = liz_ground + Vector3(0, 0, 4.0)
			var to_liz := liz.global_position - player.global_position
			player.rotation.y = atan2(to_liz.x, to_liz.z) + PI
			player.pitch = -0.14
			player.camera.rotation.x = -0.14
			var liz_to_player := player.global_position - liz.global_position
			liz.rotation.y = atan2(liz_to_player.x, liz_to_player.z) + PI
			liz._dash_windup = 0.0
			liz._play(&"prepare")
	if args.has("--jeeptest"):
		var rt_jeep := get_tree().get_first_node_in_group("vehicle") as Vehicle
		if rt_jeep:
			player.global_position = rt_jeep.global_position + Vector3(1.2, 0, 0)
			rt_jeep.enter(player)
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
	_setup_focus_recovery()
	_setup_screenshot_mode()
	if _show_initial_map_menu:
		call_deferred("_toggle_map_menu")
	print("[boot] map=%s nodes=%d objs=%d mem=%dMB" % [_map_id, Performance.get_monitor(Performance.OBJECT_NODE_COUNT), Performance.get_monitor(Performance.OBJECT_COUNT), int(Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0)])


func _resolve_map(args: PackedStringArray) -> String:
	var map_index := args.find("--map")
	if map_index >= 0 and map_index + 1 < args.size():
		return "wild" if args[map_index + 1] in ["wild", "hyrule", "open"] else "battlefield"
	if args.has("--wildtest"):
		return "wild"
	if DisplayServer.get_name() == "headless":
		return "battlefield"
	if FileAccess.file_exists(MAP_SELECTION):
		var file := FileAccess.open(MAP_SELECTION, FileAccess.READ)
		if file:
			var saved := file.get_as_text().strip_edges()
			if saved in ["battlefield", "wild"]:
				return saved
	return "battlefield"


func _thundertest_fire(tpos: Vector3) -> void:
	weather._spawn_bolt(tpos)


func _tick_thundertest() -> void:
	if _thundertest_frame < 0:
		return
	_thundertest_frame += 1
	if _thundertest_frame == 80:
		_thundertest_frame = -1
		var fwd := -player.global_transform.basis.z
		fwd.y = 0.0
		var tpos := player.global_position + fwd.normalized() * 14.0
		tpos.y = terrain.get_height(tpos.x, tpos.z)
		weather._spawn_bolt(tpos)


func _open_backpack_test() -> void:
	if player and not player.backpack_open:
		player._toggle_backpack()


func _open_shop_test() -> void:
	if player:
		player.open_shop()


func _acquire_instance_lock() -> bool:
	if DisplayServer.get_name() == "headless" or OS.get_cmdline_user_args().has("--screenshot"):
		# 无头/截图自动化（测试/截图）不占用单实例锁，避免与正在试玩的窗口实例冲突。
		_owns_instance_lock = false
		return true
	var current := OS.get_process_id()
	if FileAccess.file_exists(INSTANCE_LOCK):
		var existing := FileAccess.open(INSTANCE_LOCK, FileAccess.READ)
		if existing:
			var other := existing.get_as_text().to_int()
			if other > 0 and other != current and OS.is_process_running(other):
				print("[startup] another game instance is running: pid=", other)
				return false
	var lock := FileAccess.open(INSTANCE_LOCK, FileAccess.WRITE)
	if lock:
		lock.store_string(str(current))
		_owns_instance_lock = true
	return true


func _release_instance_lock() -> void:
	if not _owns_instance_lock:
		return
	var existing := FileAccess.open(INSTANCE_LOCK, FileAccess.READ)
	if existing and existing.get_as_text().to_int() == OS.get_process_id():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(INSTANCE_LOCK))
	_owns_instance_lock = false


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
	if _map_id == "wild":
		land = Vector3(-138, terrain.get_height(-138, 108), 108)
	player.terrain = terrain
	player.global_position = land + Vector3(0, 92 if _map_id == "wild" else 130, 0)
	player.died.connect(_on_combatant_died)

	hud = HUD.new()
	add_child(hud)
	player.hud = hud
	player.health_changed.connect(hud.set_health)
	player.damaged.connect(func(_a: float) -> void: hud.flash_damage())
	player.weapon.ammo_changed.connect(hud.set_ammo)
	player.weapon.fired.connect(func() -> void: sfx.play("shot_" + player.weapon.weapon_id, -2.0))
	player.weapon.hit_landed.connect(func() -> void: sfx.play("hit", -8.0))
	player.grenade_thrown.connect(func(left: int) -> void: hud.add_feed("掷出烟雾弹（剩 %d）" % left))
	hud.set_health(player.hp, player.armor)
	hud.set_weapon_name("波克剑")
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
	if _map_id == "wild":
		Loot.spawn(self, land + Vector3(-2.5, 0.15, 2.0), "mushroom", "", 3, 1)


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


# 阔野地图的 8 名 AI 战士：分布到各区域上空降落，形成完整大逃杀对抗。
func _spawn_wild_bots(rng: RandomNumberGenerator) -> void:
	var drops := [
		Vector3(-60, 0, 40), Vector3(60, 0, 80), Vector3(100, 0, 30), Vector3(20, 0, -80),
		Vector3(-120, 0, -50), Vector3(140, 0, -110), Vector3(-40, 0, 100), Vector3(90, 0, -30),
	]
	for i in range(drops.size()):
		var bot := Bot.new()
		bot.name = "WildBot_%s" % BOT_NAMES[i]
		add_child(bot)
		var land: Vector3 = drops[i]
		land.y = terrain.get_height(land.x, land.z)
		bot.setup(BOT_NAMES[i], zone, terrain, land)
		bot.global_position = land + Vector3(rng.randf_range(-12, 12), rng.randf_range(70.0, 120.0), rng.randf_range(-12, 12))
		bot.rotation.y = rng.randf_range(0.0, TAU)
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
	print("[capture] spots: ", spots)
	for i in range(spots.size()):
		var cp := CapturePoint.new()
		cp.name = "Capture_%s" % names[i]
		cp.point_name = names[i]
		add_child(cp)
		cp.global_position = spots[i]
		cp.owner_changed.connect(_on_capture_changed)
		capture_points.append(cp)
		buildings.fortify(spots[i])


func _spawn_loot_field(rng: RandomNumberGenerator) -> void:
	# 物资聚集在村庄（建筑内/周边），另加 2 个野点 + 全图散刷
	var clusters: Array[Vector3] = []
	clusters.append_array(buildings.village_centers)
	for i in range(2):
		clusters.append(find_land_point(rng, 0.7))
	for center in clusters:
		var count := rng.randi_range(9, 13)
		for i in range(count):
			var off := Vector3(rng.randf_range(-14, 14), 0, rng.randf_range(-14, 14))
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
		if _map_id == "wild":
			# 旷野之息式死亡：不终局，红闪“你死了”，2.2 秒后在最近神庙满血重生。
			sfx.play("defeat", -2.0)
			hud.show_death_screen()
			get_tree().create_timer(2.2).timeout.connect(_respawn_wild_player)
			return
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


# 旷野模式重生：回到最近的神庙入口，满血满精力，世界状态照旧。
func _respawn_wild_player() -> void:
	if _map_id != "wild" or player.alive:
		return
	var spot := Vector3(-122, 0, 98)
	var best_d := INF
	if wild_world:
		for shrine in wild_world.find_children("AncientShrine*", "Node3D", true, false):
			var d2 := (shrine as Node3D).global_position.distance_squared_to(player.global_position)
			if d2 < best_d:
				best_d = d2
				spot = (shrine as Node3D).global_transform * Vector3(0, 0.4, -9.0)
	player.alive = true
	player.hp = player.max_hp
	player.stamina = player.max_stamina
	player.velocity = Vector3.ZERO
	player.blocking = false
	if player.is_gliding:
		player._set_gliding(false)
	player.global_position = Vector3(spot.x, terrain.get_height(spot.x, spot.z) + 0.5, spot.z)
	player.health_changed.emit(player.hp, player.armor)
	hud.hide_death_screen()
	hud.add_feed("你在神庙前苏醒过来")


func _on_capture_changed(point: CapturePoint, new_owner: Variant) -> void:
	var n: String = "你" if new_owner == player else new_owner.display_name
	hud.add_feed("%s 占领了据点 %s" % [n, point.point_name])
	if new_owner == player:
		sfx.play("capture", -3.0)


func _on_blood_moon() -> void:
	hud.add_feed("血月升起……怪物苏醒了")
	sfx.play("zone_alarm", -2.0)
	if wild_world:
		var count := wild_world.respawn_monsters()
		print("[bloodmoon] respawned=%d" % count)


# ---------- 任务链 ----------

func _on_npc_talk(npc: Node) -> void:
	var qid: String = npc.quest_id
	var state: int = quest_states.get(qid, 0)
	var npc_name: String = npc.npc_name
	match qid:
		"mushroom3":
			match state:
				0:
					quest_states[qid] = 1
					_quest_mushroom_base = int(player.backpack_items["mushroom"])
					hud.add_feed("%s：最近蘑菇不够用了，帮我摘 3 个海拉鲁蘑菇好吗？（任务：蘑菇 0/3）" % npc_name)
				1:
					var got := int(player.backpack_items["mushroom"]) - _quest_mushroom_base
					if got >= 3:
						quest_states[qid] = 3
						player.armor = minf(100.0, player.armor + 25.0)
						player.health_changed.emit(player.hp, player.armor)
						hud.add_feed("%s：太感谢了！这些蘑菇够吃几天了（奖励：护甲 +25）" % npc_name)
					else:
						hud.add_feed("%s：蘑菇还差 %d 个，河边芦苇丛里最多。" % [npc_name, 3 - got])
				3:
					hud.add_feed("%s：有你在，驿站的日子好过多了。" % npc_name)
		"moblin2":
			match state:
				0:
					quest_states[qid] = 1
					_quest_moblin_kills = 0
					hud.add_feed("%s：莫布林最近老在城外晃，帮我教训它们两顿！（任务：莫布林 0/2）" % npc_name)
				1:
					if _quest_moblin_kills >= 2:
						quest_states[qid] = 3
						Loot.spawn(self, player.global_position + Vector3(0, 0.5, 0), "orb", "", 1, 3)
						hud.add_feed("%s：好样的！这是守军的谢礼（奖励：精灵宝珠）" % npc_name)
					else:
						hud.add_feed("%s：还差 %d 只，它们块头大但前摇长，盾反伺候。" % [npc_name, 2 - _quest_moblin_kills])
				3:
					hud.add_feed("%s：城堡一带现在安全多了。" % npc_name)
		"scale1":
			match state:
				0:
					quest_states[qid] = 1
					hud.add_feed("%s：我需要一片龙鳞做研究，火山上那条龙最近很活跃。（任务：龙鳞 0/1）" % npc_name)
				1:
					if int(player.backpack_items["dragon_scale"]) >= 1:
						player.backpack_items["dragon_scale"] = int(player.backpack_items["dragon_scale"]) - 1
						quest_states[qid] = 3
						player.max_stamina += 10.0
						player.stamina = player.max_stamina
						hud.add_feed("%s：完美的样本！这是给你的回礼（奖励：精力上限 +10）" % npc_name)
					else:
						hud.add_feed("%s：龙鳞只能从火山巨龙的掉落里拿，小心它的俯冲。" % npc_name)
				3:
					hud.add_feed("%s：这片龙鳞够我写三篇论文了。" % npc_name)
		"escort":
			match state:
				0:
					quest_states[qid] = 1
					_escort_npc = npc as WildNPC
					hud.add_feed("%s：陪我走到海利亚大桥东头吧，这段路最近不太平。（护送出发）" % npc_name)
				1:
					hud.add_feed("%s：跟紧我，过了桥就安全了。" % npc_name)
				3:
					hud.add_feed("%s：一路顺风，朋友。" % npc_name)
			# 护送任务接过后，行商随时开店。
			if quest_states[qid] >= 1:
				player.open_shop()


# 测绘塔顶水晶激活：注册传送点。
func _activate_warp(p_name: String, pos: Vector3) -> void:
	warp_points.append({"name": p_name, "pos": pos})
	hud.add_feed("测绘点已激活：%s（M 地图可传送）" % p_name)
	if sfx:
		sfx.play("capture", -4.0)


func _on_moblin_killed(from: Variant) -> void:
	if quest_states.get("moblin2", 0) == 1 and from == player:
		_quest_moblin_kills += 1
		hud.add_feed("任务进度：莫布林 %d/2" % mini(_quest_moblin_kills, 2))


func _on_dragon_killed(from: Variant) -> void:
	if from != player or match_over:
		return
	match_over = true
	player.input_locked = true
	sfx.play("victory", -2.0)
	var quest_done := 0
	for q in quest_states.values():
		if int(q) == 3:
			quest_done += 1
	var lines: Array[String] = [
		"焚天者已被讨伐",
		"海拉鲁种子  %d / 10+" % player.seed_count,
		"完成任务  %d / %d" % [quest_done, quest_states.size()],
		"弹反  %d 次    击败  %d" % [player.parry_count, player.kills],
	]
	hud.show_quest_end("讨 伐 成 功", lines)


# 冒险日志条目：主线/支线/试炼的静态描述 + 动态状态与进度（J 键面板的数据源）。
func get_journal_entries() -> Array:
	var entries: Array = []
	var dragon_alive := false
	for d in get_tree().get_nodes_in_group("wild_enemy"):
		if d is WildDragon and d.get("alive"):
			dragon_alive = true
			break
	entries.append({"name": "焚天之怒（主线）", "desc": "讨伐火山口的焚天巨龙", "state": 1 if dragon_alive else 3, "progress": "进行中" if dragon_alive else "已讨伐"})
	entries.append({"name": "蘑菇茶歇", "desc": "驿站老板想要 3 朵海拉鲁蘑菇", "state": quest_states.get("mushroom3", 0), "progress": _quest_progress_text("mushroom3")})
	entries.append({"name": "谷地除害", "desc": "讨伐 2 只莫布林（它们前摇长，盾反伺候）", "state": quest_states.get("moblin2", 0), "progress": _quest_progress_text("moblin2")})
	entries.append({"name": "学者的样本", "desc": "给遗迹学者带回一片巨龙鳞", "state": quest_states.get("scale1", 0), "progress": _quest_progress_text("scale1")})
	entries.append({"name": "一路顺风", "desc": "护送行商到海利亚大桥东头", "state": quest_states.get("escort", 0), "progress": _quest_progress_text("escort")})
	var shrine_done := 0
	if wild_world:
		for t in wild_world.trials:
			if t.completed:
				shrine_done += 1
	entries.append({"name": "神庙试炼", "desc": "解开四座古代神庙的试炼", "state": 3 if shrine_done >= 4 else (1 if shrine_done > 0 else 0), "progress": "%d/4" % shrine_done})
	return entries


func _quest_progress_text(qid: String) -> String:
	match quest_states.get(qid, 0):
		0:
			return "未接取"
		3:
			return "已完成"
	if qid == "mushroom3":
		var got := int(player.backpack_items["mushroom"]) - _quest_mushroom_base
		return "%d/3" % clampi(got, 0, 3)
	if qid == "moblin2":
		return "%d/2" % mini(_quest_moblin_kills, 2)
	if qid == "scale1":
		return "%d/1" % mini(int(player.backpack_items["dragon_scale"]), 1)
	return "进行中"


func quest_status_text() -> String:
	if quest_states.get("mushroom3", 0) == 1:
		var got := int(player.backpack_items["mushroom"]) - _quest_mushroom_base
		return "任务：蘑菇 %d/3" % clampi(got, 0, 3)
	if quest_states.get("moblin2", 0) == 1:
		return "任务：莫布林 %d/2" % mini(_quest_moblin_kills, 2)
	if quest_states.get("scale1", 0) == 1:
		return "任务：龙鳞 %d/1" % mini(int(player.backpack_items["dragon_scale"]), 1)
	if quest_states.get("escort", 0) == 1:
		return "任务：护送行商"
	return ""


func _update_escort_quest() -> void:
	if quest_states.get("escort", 0) != 1 or _escort_npc == null:
		return
	# 行商巡逻到桥段（路径索引 ≥3）且玩家在 12m 内，护送完成。
	if _escort_npc._patrol_i >= 3 and player.global_position.distance_to(_escort_npc.global_position) < 12.0:
		quest_states["escort"] = 3
		Loot.spawn(self, _escort_npc.global_position + Vector3(0, 0.5, 0), "ammo", "", 90, 2)
		hud.add_feed("行商多戈：到了！这些弹药你拿着防身（奖励：弹药 90）")


func _recompute_buffs() -> void:
	for c in get_tree().get_nodes_in_group("combatant"):
		if c.alive:
			var skewer_value: Variant = c.get("skewer_mult")
			var charm_value: Variant = c.get("charm_mult")
			var base := (float(skewer_value) if skewer_value != null else 1.0) * (float(charm_value) if charm_value != null else 1.0)
			var has_point := false
			for cp in capture_points:
				if cp.owner_body == c and c.alive:
					has_point = true
					break
			c.damage_mult = base * (1.1 if has_point else 1.0)
			c.regen_rate = 3.0 if has_point else 0.0


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_M:
			_toggle_map_menu()
			get_viewport().set_input_as_handled()
			return
		if _map_menu_open:
			if event.physical_keycode == KEY_1:
				_select_map("battlefield")
			elif event.physical_keycode == KEY_2:
				_select_map("wild")
			elif event.physical_keycode >= KEY_3 and event.physical_keycode <= KEY_5:
				var wi := int(event.physical_keycode - KEY_3)
				if wi < warp_points.size():
					_toggle_map_menu()
					player.global_position = (warp_points[wi]["pos"] as Vector3) + Vector3(0, 0.5, 0)
					hud.add_feed("传送：%s" % str(warp_points[wi]["name"]))
				else:
					hud.add_feed("这个传送位还没有激活的测绘点")
			get_viewport().set_input_as_handled()
			return
		if event.physical_keycode == KEY_T and daynight:
			daynight.advance(1.0)
			hud.add_feed("时间流转：%s" % daynight.phase_name())
			get_viewport().set_input_as_handled()
			return
	if match_over and event is InputEventKey and event.pressed and event.physical_keycode == KEY_R:
		get_tree().reload_current_scene()


func _toggle_map_menu() -> void:
	if hud == null:
		return
	_map_menu_open = not _map_menu_open
	if _map_menu_open:
		hud.show_map_selector(_map_id)
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		if not get_tree().paused:
			_map_pause_owned = true
			get_tree().paused = true
			if sfx:
				sfx.set_streams_paused(true)
		if not warp_points.is_empty():
			var names: Array[String] = []
			for i in range(warp_points.size()):
				names.append("%d %s" % [i + 3, str(warp_points[i]["name"])])
			hud.add_feed("可传送：" + "　".join(names))
	else:
		hud.hide_map_selector()
		if _map_pause_owned:
			_map_pause_owned = false
			get_tree().paused = false
			if sfx:
				sfx.set_streams_paused(false)
		if player and player.alive and not player.backpack_open:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _select_map(next_map: String) -> void:
	if _map_from_cli and next_map != _map_id:
		hud.add_feed("当前由命令行 --map 锁定地图")
		_toggle_map_menu()
		return
	var file := FileAccess.open(MAP_SELECTION, FileAccess.WRITE)
	if file:
		file.store_string(next_map)
	if next_map == _map_id:
		_toggle_map_menu()
		return
	if _map_menu_open:
		_toggle_map_menu()
	_map_id = next_map
	get_tree().reload_current_scene()


# 窗口失去焦点（Cmd+Space、切应用、手势误触）时自动暂停，切回继续。
# macOS 偶尔会漏发 WINDOW_FOCUS_IN，因此另有 ALWAYS Timer 轮询兜底，
# 避免场景树永久停在 paused、但音频线程仍播放，看起来像"卡死"。
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_pause_for_focus()
	elif what == NOTIFICATION_WM_WINDOW_FOCUS_IN or what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_resume_from_focus_pause()


func _setup_focus_recovery() -> void:
	_focus_recovery_timer = Timer.new()
	_focus_recovery_timer.name = "FocusRecoveryTimer"
	_focus_recovery_timer.process_mode = Node.PROCESS_MODE_ALWAYS
	_focus_recovery_timer.wait_time = 0.25
	_focus_recovery_timer.timeout.connect(_poll_focus_recovery)
	add_child(_focus_recovery_timer)
	_focus_recovery_timer.start()


func _pause_for_focus() -> void:
	if _focus_pause_owned or match_over or player == null or not player.alive or get_tree().paused:
		return
	_focus_pause_owned = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if sfx:
		sfx.set_streams_paused(true)
	if hud:
		hud.show_pause()
	get_tree().paused = true
	print("[focus] paused after focus loss")


func _resume_from_focus_pause() -> void:
	# 只恢复由本节点发起的暂停，不能覆盖其他系统未来可能增加的暂停状态。
	if not _focus_pause_owned:
		return
	_focus_pause_owned = false
	get_tree().paused = false
	if hud:
		hud.hide_pause()
	if sfx:
		sfx.set_streams_paused(false)
	if player and player.alive and not match_over:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	print("[focus] resumed")


func _poll_focus_recovery() -> void:
	if _focus_recovery_test_pending:
		_focus_recovery_test_pending = false
		print("[focustest] ALWAYS timer ticked while the scene tree was paused")
		_resume_from_focus_pause()
		return
	if _focus_pause_owned and DisplayServer.window_is_focused():
		_resume_from_focus_pause()


func _process(delta: float) -> void:
	# 昼夜音乐：每秒检查一次昼夜状态，入夜/天明交叉切换配乐。
	_music_check_t -= delta
	if _music_check_t <= 0.0:
		_music_check_t = 1.0
		if daynight and sfx:
			sfx.set_night_music(daynight.is_night())
	_tick_thundertest()
	if _wild_test_frame >= 0:
		_update_wild_test()
	if _season_test_frame >= 0:
		_season_test_frame += 1
		if _season_test_frame in [20, 40, 60]:
			seasons.cycle_season()
		elif _season_test_frame == 80:
			print("[seasontest] done at ", seasons.current_season)
			_season_test_frame = -1
	if _focus_recovery_test_frame >= 0:
		_focus_recovery_test_frame += 1
		if _focus_recovery_test_frame == 20:
			_focus_recovery_test_frame = -1
			_focus_recovery_test_pending = true
			print("[focustest] simulating a lost focus-in notification")
			_pause_for_focus()
	if _smoketest and Engine.get_process_frames() == 30:
		player._throw_smoke()
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

	if _reloadtest and Engine.get_process_frames() % 240 == 0 and Engine.get_process_frames() > 0:
		print("[reloadtest] reloading scene")
		get_tree().reload_current_scene()
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
	_update_escort_quest()

	if _sim:
		_sim_acc += delta
		if _sim_acc >= 10.0:
			_sim_acc = 0.0
			print("[sim] frame=%d map=%s alive=%d zone_r=%d phase=%d match_over=%s nodes=%d objs=%d res=%d mem=%dMB" % [Engine.get_process_frames(), _map_id, _alive_count(), int(zone.radius), zone.phase, str(match_over), Performance.get_monitor(Performance.OBJECT_NODE_COUNT), Performance.get_monitor(Performance.OBJECT_COUNT), Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT), int(Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0)])

	if not player.alive:
		return
	hud.set_stamina(player.stamina / player.max_stamina)
	hud.update_minimap(player)
	hud.set_spread(6.0 + player.weapon.current_spread() * 9.0)
	hud.set_crosshair_visible(player.weapon.weapon_id != "")
	if player.nearby_loot:
		hud.set_interact("按 E 拾取  " + player.nearby_loot.describe())
	elif player.vehicle:
		hud.set_interact("按 F 下车")
	elif player.nearby_vehicle:
		var ride_value: Variant = player.nearby_vehicle.get("ride_label")
		var ride_text := str(ride_value) if ride_value != null else "驾驶吉普车"
		hud.set_interact("按 F %s" % ride_text)
	elif player.nearby_npc:
		hud.set_interact("按 E 与%s交谈" % str(player.nearby_npc.get("npc_name")))
	elif player.nearby_fish:
		hud.set_interact("按 E 抓鱼")
	elif player.nearby_bed:
		hud.set_interact("按 E 睡到天亮")
	elif player.nearby_shrine_door:
		hud.set_interact("按 E 进入神庙")
	elif player.nearby_shrine_exit:
		hud.set_interact("按 E 离开神庙")
	else:
		hud.set_interact("")
	hud.set_weapon_name(player.weapon.label())
	if player.weapon.weapon_id == "":
		hud.set_ammo_text("--")
	if _map_id == "wild" and wild_world:
		var state := ""
		if player.is_swimming:
			state = " · 游泳（Space 上浮 / C 下潜）"
		elif player.is_climbing:
			state = " · 攀爬中（W/S 上下 · Space 蹬离）"
		elif player.is_gliding:
			state = " · 滑翔伞展开（W 俯冲 / S 减速）"
		elif player.vehicle:
			state = " · 骑乘中"
		elif not player.is_on_floor() and player.velocity.y < -0.55:
			state = " · 按住 Space 展开滑翔伞"
		hud.set_zone_text(wild_world.get_region_name(player.global_position))
		hud.set_world_state("海拉鲁阔野 · %s%s\nM 地图  ·  B 背包  ·  F 骑乘  ·  H 口哨  ·  T 时光" % [daynight.phase_name() if daynight else "", state])
		var quest_text := quest_status_text()
		if quest_text != "":
			hud.set_world_state("海拉鲁阔野 · %s%s\n%s\nM 地图  ·  B 背包  ·  F 骑乘  ·  H 口哨  ·  T 时光" % [daynight.phase_name() if daynight else "", state, quest_text])
	else:
		hud.set_zone_text(zone.status_text())
		hud.set_world_state("群岛战场\nM 地图选择")
		hud.set_danger(zone.active and zone.is_outside(player.global_position))
	# 占点提示
	var shown := false
	if _map_id == "wild" and wild_world:
		for trial in wild_world.trials:
			var ts: Array = trial.hud_status(player.global_position)
			if ts[1] >= 0.0:
				hud.set_capture(ts[0], ts[1])
				shown = true
				break
		# 巨龙血条：接近火山巨龙时显示（试炼条优先）。
		if not shown:
			for enemy in get_tree().get_nodes_in_group("wild_enemy"):
				if enemy is WildDragon and enemy.alive and enemy.global_position.distance_to(player.global_position) < 110.0:
					hud.set_capture("火山巨龙", enemy.hp / 260.0)
					shown = true
					break
	for cp in capture_points:
		var st: Array = cp.hud_status(player)
		if st[1] >= 0.0:
			hud.set_capture(st[0], st[1])
			shown = true
			break
	if not shown:
		hud.set_capture("", -1.0)


func _update_wild_test() -> void:
	_wild_test_frame += 1
	match _wild_test_frame:
		10:
			player.give_weapon("rifle")
			player.give_weapon("smg")
			player.give_weapon("dmr")
			player.give_item("mushroom", 3)
			player.give_item("meat", 2)
			print("[wildtest] backpack weapons=%d mushrooms=%d meat=%d" % [player.backpack_weapons.size(), int(player.backpack_items["mushroom"]), int(player.backpack_items["meat"])])
		12:
			player._retrieve_weapon(0)
			print("[wildtest] backpack retrieve current=%s stored=%d" % [player.weapon.weapon_id, player.backpack_weapons.size()])
		20:
			var river_z := 0.0
			var river_x := sin(river_z * 0.021) * 24.0 - 8.0 + sin(river_z * 0.049) * 7.0
			player.global_position = Vector3(river_x, Terrain.WATER_LEVEL - 1.7, river_z)
			player.velocity = Vector3.ZERO
			player.is_dropping = false
		80:
			print("[wildtest] swim active=%s y=%.2f surface=%.2f" % [str(player.is_swimming), player.global_position.y, terrain.get_water_level()])
			player.global_position = Vector3(-112, terrain.get_height(-112, 92) + 38.0, 92)
			player.velocity = Vector3(0, -20, 0)
			# 专门覆盖“已经落地后从悬崖跃下仍能展开”，不再只测开局空降。
			player.is_dropping = false
			player.debug_glide = true
			_wild_test_height = player.global_position.y
		145:
			print("[wildtest] cliff_glide active=%s visual=%s fall=%.2f vy=%.2f" % [str(player.is_gliding), str(player._glider.visible), _wild_test_height - player.global_position.y, player.velocity.y])
			player.debug_glide = false
			var horse := get_tree().get_first_node_in_group("vehicle") as Horse
			if horse:
				horse.bonded = true
				player.global_position = horse.global_position + Vector3(1, 0, 0)
				horse.enter(player)
				horse.debug_forward = 1.0
				_wild_test_horse_start = horse.global_position
		220:
			var horse := player.vehicle as Horse
			if horse:
				print("[wildtest] horse moved=%.2f mounted=%s" % [_wild_test_horse_start.distance_to(horse.global_position), str(horse.driver == player)])
				horse.debug_forward = 0.0
				horse.exit()
			player.global_position = Vector3(-22, terrain.get_height(-22, 104) + 0.1, 104)
			player.collision_layer = 2
			player.collision_mask = 1 | 4
			_wild_test_parry_hp = player.hp
			# 种子里程碑回归：第 3 颗种子精力上限 +10。
			var stam_before := player.max_stamina
			player.collect_seed()
			player.collect_seed()
			player.collect_seed()
			print("[wildtest] seed_milestone %.0f->%.0f" % [stam_before, player.max_stamina])
			var enemy := get_tree().get_first_node_in_group("wild_enemy") as WildMonster
			if enemy:
				var enemy_pos := player.global_position + Vector3(0, 0, -9)
				enemy_pos.y = terrain.get_height(enemy_pos.x, enemy_pos.z) + 0.05
				enemy.global_position = enemy_pos
				enemy._throw_at_player()
		300:
			var projectiles := get_tree().get_nodes_in_group("wild_projectile")
			var projectile_pos := Vector3.ZERO
			if not projectiles.is_empty():
				var remaining: Node3D = projectiles[0]
				projectile_pos = remaining.global_position
			print("[wildtest] projectile in_flight remaining=%d sample_pos=%s" % [projectiles.size(), str(projectile_pos)])
			var before := get_tree().get_nodes_in_group("loot").size()
			var creature := get_tree().get_first_node_in_group("wildlife") as WildCreature
			if creature:
				creature.take_damage(999.0, player)
			print("[wildtest] meat_drop before=%d after=%d" % [before, get_tree().get_nodes_in_group("loot").size()])
			var monster := get_tree().get_first_node_in_group("wild_enemy") as WildMonster
			if monster:
				var loot_before_m := get_tree().get_nodes_in_group("loot").size()
				monster.take_damage(999.0, player)
				print("[wildtest] monster dead=%s loot_delta=%d" % [str(not monster.alive), get_tree().get_nodes_in_group("loot").size() - loot_before_m])
		310:
			var tree_body := _find_choppable()
			_wild_test_loot_before = get_tree().get_nodes_in_group("loot").size()
			if tree_body:
				tree_body.take_damage(12.0, player)
				tree_body.take_damage(12.0, player)
				print("[wildtest] tree_chop falling=%s" % str(tree_body._falling))
		350:
			print("[wildtest] projectile damage=%.1f" % [_wild_test_hp - player.hp])
			var bike: WildMotorcycle = null
			for candidate in get_tree().get_nodes_in_group("vehicle"):
				if candidate is WildMotorcycle:
					bike = candidate as WildMotorcycle
					break
			if bike:
				player.global_position = bike.global_position + Vector3(1, 0, 0)
				bike.enter(player)
				bike.debug_forward = 1.0
				_wild_test_bike_start = bike.global_position
		430:
			var bike := player.vehicle as WildMotorcycle
			if bike:
				print("[wildtest] motorcycle moved=%.2f mounted=%s" % [_wild_test_bike_start.distance_to(bike.global_position), str(bike.driver == player)])
				bike.debug_forward = 0.0
				bike.exit()
			print("[wildtest] tree_wood loot_delta=%d" % [get_tree().get_nodes_in_group("loot").size() - _wild_test_loot_before])
		431:
			# 近战回归：空手挥剑应命中 2.6m 内怪物。
			var m2: WildMonster = null
			for e in get_tree().get_nodes_in_group("wild_enemy"):
				if e is WildMonster and e.alive:
					m2 = e as WildMonster
					break
			if m2 and m2.alive:
				player.global_position = m2.global_position + Vector3(0, 0.1, 2.0)
				var to_m: Vector3 = m2.global_position - player.global_position
				player.rotation.y = atan2(to_m.x, to_m.z) + PI
				player.pitch = 0.0
				player.camera.rotation.x = 0.0
				var m2_hp := m2.hp
				player._melee_swing()
				player._update_sword(0.08)
				player._update_sword(0.05)
				var dbg_dot: float = ((m2.global_position + Vector3(0, 0.8, 0)) - player.camera.global_position).normalized().dot(player.get_aim_dir())
				print("[wildtest] melee monster_hp %.0f->%.0f dot=%.2f dist=%.2f" % [m2_hp, m2.hp, dbg_dot, player.global_position.distance_to(m2.global_position)])
			# 临时生成吉普，覆盖加速、转弯和制动；测试完成后立即从树中移除。
			# 遥控炸弹回归：引爆对怪物造成衰减伤害，近距玩家被击退（炸弹跳）。
			var bm2: WildMonster = null
			for e in get_tree().get_nodes_in_group("wild_enemy"):
				if e is WildMonster and e.alive:
					bm2 = e as WildMonster
					break
			if bm2:
				var bp := bm2.global_position + Vector3(1.5, 0.3, 0)
				var bomb := RemoteBomb.place(self, bp, Vector3.ZERO, player)
				var bm_hp: float = bm2.hp
				player.alive = true
				player.global_position = bp + Vector3(2.0, 0, 0)
				var pv: Vector3 = player.velocity
				bomb.detonate()
				print("[wildtest] bomb monster_hp %.0f->%.0f knock=%.1f" % [bm_hp, bm2.hp, (player.velocity - pv).length()])
			# 制冰回归：对水面连升四根冰柱，最多保留三根。
			var water_spot := Vector3.ZERO
			for xi in range(-60, 61, 2):
				if terrain.is_in_water(float(xi), 50.0):
					water_spot = Vector3(float(xi), Terrain.WATER_LEVEL, 50.0)
					break
			if water_spot != Vector3.ZERO:
				player.global_position = water_spot + Vector3(0, 1.5, 4.0)
				var wdir := (water_spot - player.camera.global_position).normalized()
				player.rotation.y = atan2(wdir.x, wdir.z) + PI
				player.pitch = -0.25
				player.camera.rotation.x = -0.25
				player._raise_ice()
				player._raise_ice()
				player._raise_ice()
				player._raise_ice()
				print("[wildtest] cryonis pillars=%d" % player._pillars.size())
			# 时停回归：冻结莫布林（470 帧解除并结算冲击伤害）。
			_stasis_test_mob = null
			for e in get_tree().get_nodes_in_group("wild_enemy"):
				if e is WildMoblin and e.alive:
					_stasis_test_mob = e as WildMoblin
					break
			if _stasis_test_mob:
				player.global_position = _stasis_test_mob.global_position + Vector3(0, 0, 8.0)
				var sdir := (_stasis_test_mob.global_position - player.camera.global_position).normalized()
				player.rotation.y = atan2(sdir.x, sdir.z) + PI
				player.pitch = 0.0
				player.camera.rotation.x = 0.0
				player._toggle_stasis()
				_stasis_test_pos = _stasis_test_mob.global_position
				_stasis_test_hp = _stasis_test_mob.hp
			# 磁力回归：吸附判定、拉力与投掷冲量（速度赋值同步读取，无需跨帧）。
			var mp := get_tree().get_first_node_in_group("metal_prop") as MetalProp
			if mp:
				mp.global_position = Vector3(-72, terrain.get_height(-72, 21) + 0.5, 21)
				mp.linear_velocity = Vector3.ZERO
				player.global_position = mp.global_position + Vector3(0, 0, 6.0)
				var mdir := (mp.global_position - player.camera.global_position).normalized()
				player.rotation.y = atan2(mdir.x, mdir.z) + PI
				player.pitch = 0.0
				player.camera.rotation.x = 0.0
				player._toggle_magnet()
				var grabbed := player._magnet_prop == mp
				mp.magnet_hold(player.camera.global_position + player.get_aim_dir() * 5.0)
				var pull_speed: float = mp.linear_velocity.length()
				player._throw_magnet()
				print("[wildtest] magnesis grab=%s pull=%.1f throw=%.1f" % [str(grabbed), pull_speed, mp.linear_velocity.length()])
			# 丘丘回归：大只死亡分裂两只小只，小只死亡掉蘑菇。
			var cbig := Chuchu.create(self, terrain, player, player.global_position + Vector3(2, 0, 0))
			var small_before := 0
			for e in get_tree().get_nodes_in_group("wild_enemy"):
				if e is Chuchu and e.small:
					small_before += 1
			cbig.take_damage(999.0, player)
			var small_after := 0
			for e2 in get_tree().get_nodes_in_group("wild_enemy"):
				if e2 is Chuchu and e2.small:
					small_after += 1
			var loot_before := get_tree().get_nodes_in_group("loot").size()
			for e3 in get_tree().get_nodes_in_group("wild_enemy"):
				if e3 is Chuchu and e3.small:
					e3.take_damage(999.0, player)
			print("[wildtest] chuchu split %d->%d loot_delta=%d" % [small_before, small_after, get_tree().get_nodes_in_group("loot").size() - loot_before])
			# 夜蝠回归：夜间强制俯冲应命中玩家，击杀死亡。
			if daynight:
				daynight.t = 0.8
			var kb := Keese.new()
			kb.setup(terrain, player, player.global_position + Vector3(0, 0.5, 0))
			add_child(kb)
			player.alive = true
			var khp := player.hp
			kb._dive_dir = Vector3.DOWN
			kb._dive_t = 1.0
			# 贴身起跳一次：接触判定（dist<0.9）应在首个物理调用即命中。
			kb._physics_process(0.1)
			var dove_hit := player.hp < khp
			kb.take_damage(999.0, player)
			print("[wildtest] keese dive_hit=%s dead=%s" % [str(dove_hit), str(not kb.alive)])
			# 骷髅回归：夜间破土→激活→撕抓→散架出头颅。
			var st := Stal.create_body(self, terrain, player, player.global_position + Vector3(2, 0, 0))
			st._physics_process(0.1)
			var rose := st._state == "rise"
			st._physics_process(1.4)
			var act := st._state == "active"
			st.global_position = player.global_position + Vector3(1.2, 0, 0)
			st._attack_cd = 0.0
			player.alive = true
			var shp := player.hp
			st._physics_process(0.3)
			var clawed := player.hp < shp
			var skull_before := 0
			for e in get_tree().get_nodes_in_group("wild_enemy"):
				if e is Stal and e.mode == "skull":
					skull_before += 1
			st.take_damage(999.0, player)
			var skull_after := 0
			for e2 in get_tree().get_nodes_in_group("wild_enemy"):
				if e2 is Stal and e2.mode == "skull":
					skull_after += 1
			print("[wildtest] stal rose=%s active=%s claw=%s skull %d->%d" % [str(rose), str(act), str(clawed), skull_before, skull_after])
			# 法师回归：施法产生火弹、近身闪现拉开距离。
			var wz := Wizzrobe.create(self, terrain, player, player.global_position + Vector3(10, 0, 0))
			var proj_before := get_tree().get_nodes_in_group("wild_projectile").size()
			wz._cast_cd = 0.0
			player.alive = true
			wz._physics_process(0.1)
			var cast_ok := get_tree().get_nodes_in_group("wild_projectile").size() > proj_before
			var wpos: Vector3 = wz.global_position
			wz._tp_cd = 0.0
			player.global_position = wpos + Vector3(3, 0, 0)
			wz._physics_process(0.1)
			var tp_dist: float = wz.global_position.distance_to(wpos)
			wz.take_damage(999.0, player)
			print("[wildtest] wizzrobe cast=%s tp=%.1f dead=%s" % [str(cast_ok), tp_dist, str(not wz.alive)])
			# 宝箱与防具回归：开箱得防具、装备三套效果互斥生效。
			var ch := LootChest.create(self, player.global_position + Vector3(1.2, 0, 0), "armor_soldier")
			ch.open(player)
			var got_armor := int(player.backpack_items.get("armor_soldier", 0))
			player.backpack_index = player.backpack_weapons.size() + 6
			player._use_backpack_selection()
			var soldier_ok := player.equipped_armor == "armor_soldier" and player.damage_taken_mult < 0.9
			player.give_item("armor_barbarian", 1)
			player.backpack_index = player.backpack_weapons.size() + 8
			player._use_backpack_selection()
			var barb_ok := player.equipped_armor == "armor_barbarian" and player.armor_melee_mult > 1.1 and player.damage_taken_mult > 0.9
			print("[wildtest] armor_chest got=%d soldier=%s barbarian=%s" % [got_armor, str(soldier_ok), str(barb_ok)])
			# 经济回归：杀怪掉卢比、商店购买扣款发货、余额不足拒售。
			var rp0 := player.rupees
			var rp_mob: WildMoblin = null
			for e in get_tree().get_nodes_in_group("wild_enemy"):
				if e is WildMoblin and e.alive:
					rp_mob = e as WildMoblin
					break
			if rp_mob:
				var survival_hp := rp_mob.hp
				var survival_kills := player.kills
				var survival_loot := get_tree().get_nodes_in_group("loot").size()
				rp_mob.take_damage(10.0, player)
				var nonlethal_ok := rp_mob.alive and is_equal_approx(rp_mob.hp, survival_hp - 10.0) and player.kills == survival_kills and get_tree().get_nodes_in_group("loot").size() == survival_loot
				rp_mob.apply_melee_impulse(Vector3(1, 0, 0), 7.0, true)
				print("[wildtest] combat nonlethal=%s stagger=%.2f" % [str(nonlethal_ok), rp_mob._stagger_t])
				rp_mob.take_damage(999.0, player)
			var rp1 := player.rupees
			player.rupees = 20
			var ammo0 := 0
			for wid in player.weapon_slots:
				ammo0 += int(player.reserves.get(wid, 0))
			player._buy(0)
			var ammo1 := 0
			for wid2 in player.weapon_slots:
				ammo1 += int(player.reserves.get(wid2, 0))
			player._buy(2)
			print("[wildtest] shop rupees %d->%d(+kill) ammo +%d spent=%d->%d reject=%s" % [rp0, rp1, ammo1 - ammo0, 20, player.rupees, str(player.rupees == 5)])
			# 出售与绑定召回回归：卖肉换卢比、绑定马远距离口哨召回。
			player.backpack_items["meat"] = 2
			var rp_sell0 := player.rupees
			player._buy(3)
			var sell_ok := int(player.backpack_items["meat"]) == 1 and player.rupees == rp_sell0 + 8
			var rc_horse := get_tree().get_first_node_in_group("vehicle") as Horse
			var recall_ok := false
			if rc_horse:
				rc_horse.bonded = true
				player.global_position = rc_horse.global_position + Vector3(1, 0, 0)
				rc_horse.enter(player)
				rc_horse.exit()
				player.global_position = rc_horse.global_position + Vector3(0, 0, 120.0)
				player._whistle_horse()
				recall_ok = rc_horse._call_target == player
			print("[wildtest] sell_meat=%s bonded_recall=%s" % [str(sell_ok), str(recall_ok)])
			# 巨人回归：惊醒、跺地 AOE、眼睛双倍+硬直、远程投石。
			var hx := Hinox.create(self, terrain, player, player.global_position + Vector3(6, 0, 0))
			player.alive = true
			hx._physics_process(0.1)
			var woke := hx._state == "wake"
			hx._physics_process(1.1)
			var act2 := hx._state == "active"
			player.global_position = hx.global_position + Vector3(2, 0, 0)
			hx._attack_cd = 0.0
			hx._physics_process(0.05)
			var stomping := hx._strike_kind == "stomp" and hx._strike_t > 0.0
			var hhp := player.hp
			hx._physics_process(0.45)
			var stomped := player.hp < hhp
			var ehp := hx.hp
			hx.take_damage(10.0, player, "eye")
			var eye_mult := absf(ehp - hx.hp - 20.0) < 0.01
			var stag := hx._state == "stagger"
			hx._state = "active"
			player.global_position = hx.global_position + Vector3(15, 0, 0)
			hx._throw_cd = 0.0
			var p_before := get_tree().get_nodes_in_group("wild_projectile").size()
			hx._physics_process(0.05)
			hx._physics_process(0.6)
			var thrown := get_tree().get_nodes_in_group("wild_projectile").size() > p_before
			hx.take_damage(9999.0, player)
			print("[wildtest] hinox woke=%s active=%s stomp=%s->%s eye2x=%s stag=%s throw=%s" % [str(woke), str(act2), str(stomping), str(stomped), str(eye_mult), str(stag), str(thrown)])
			# 传送回归：激活水晶注册、传送落点正确。
			var wb := WarpBeacon.create(self, player.global_position + Vector3(1.5, 0, 0), "测试塔")
			wb.activate(player)
			var warp_reg := warp_points.size() > 0
			var pre_pos := player.global_position
			player.global_position = Vector3(150, 20, 150)
			player.global_position = (warp_points[0]["pos"] as Vector3) + Vector3(0, 0.5, 0)
			var teleported := player.global_position.distance_to(pre_pos) < 3.0
			print("[wildtest] warp reg=%s teleport=%s" % [str(warp_reg), str(teleported)])
			# 药剂回归：火堆旁材料+蘑菇=力量药剂、+兽肉=精力药剂。
			player.global_position = Vector3(-67, terrain.get_height(-67, 16), 16) + Vector3(1.5, 0, 0)
			player.backpack_items["monster_part"] = 2
			player.backpack_items["mushroom"] = 1
			player.backpack_items["meat"] = 1
			player.backpack_index = player.backpack_weapons.size() + 9
			player._use_backpack_selection()
			var power_ok := player.skewer_mult > 1.1 and int(player.backpack_items.get("monster_part", 0)) == 1
			_elixir_test_stam = player.max_stamina
			player.backpack_items["monster_part"] = 1
			player._use_backpack_selection()
			var stam_ok := player.max_stamina == _elixir_test_stam + 20.0 and player._elixir_stam_end_ms > 0
			player._elixir_stam_end_ms = 1
			print("[wildtest] elixir power=%s stam=%s" % [str(power_ok), str(stam_ok)])
			# 雪天回归：雪山地区降水触发为雪而非雨，雪幕可见。
			player.global_position = Vector3(-120, terrain.get_height(-120, -90), -90)
			weather.raining = false
			weather.snowing = false
			weather._state_t = 999.0
			weather._process(0.1)
			var snow_ok := weather.snowing and not weather.raining
			weather.snow_strength = 0.5
			weather._process(0.1)
			var snow_vis := weather._snow_mm.visible
			weather.snowing = false
			weather.snow_strength = 0.0
			print("[wildtest] snow region_snow=%s flakes=%s" % [str(snow_ok), str(snow_vis)])
			var jeep := Vehicle.new()
			jeep.terrain = terrain
			add_child(jeep)
			jeep.global_position = Vector3(-52, terrain.get_height(-52, 48) + 0.04, 48)
			jeep.rotation.y = 0.2
			player.global_position = jeep.global_position + Vector3(1.5, 0, 0)
			jeep.enter(player)
			jeep.debug_forward = 1.0
			jeep.debug_turn = 0.42
			_wild_test_jeep_start = jeep.global_position
			_wild_test_jeep_yaw = jeep.rotation.y
		470:
			var jeep := player.vehicle as Vehicle
			if jeep:
				_wild_test_jeep_peak_speed = jeep.speed
				jeep.debug_forward = -1.0
			# 时停回归（下半）：冻结跨帧零位移，解除结算冲击伤害。
			if _stasis_test_mob:
				player._stasis_dmg = 20.0
				player._release_stasis()
				print("[wildtest] stasis moved=%.2f hp %.0f->%.0f" % [_stasis_test_mob.global_position.distance_to(_stasis_test_pos), _stasis_test_hp, _stasis_test_mob.hp])
				_stasis_test_mob = null
		490:
			var jeep := player.vehicle as Vehicle
			if jeep:
				print("[wildtest] jeep moved=%.2f turn=%.1fdeg peak=%.2f braked=%.2f" % [_wild_test_jeep_start.distance_to(jeep.global_position), rad_to_deg(absf(angle_difference(_wild_test_jeep_yaw, jeep.rotation.y))), _wild_test_jeep_peak_speed, jeep.speed])
				jeep.debug_forward = 0.0
				jeep.debug_turn = 0.0
				jeep.exit()
				remove_child(jeep)
				jeep.queue_free()
			# 城堡大门台阶回归：步行穿过城墙门洞走上基座平台。
			player.global_position = Vector3(1.5, 30.3, -142.5)
			player.rotation.y = PI
			player.velocity = Vector3.ZERO
			player.debug_move = 1.0
			_wild_test_height = player.global_position.y
		590:
			player.debug_move = 0.0
			print("[wildtest] castle_stairs start_y=%.2f end_y=%.2f climbed=%.2f" % [_wild_test_height, player.global_position.y, player.global_position.y - _wild_test_height])
			# 药剂到期恢复（下半）：下车后恢复已触发，上限应回落。
			print("[wildtest] elixir_expire max_stam %.0f->%.0f" % [_elixir_test_stam + 20.0, player.max_stamina])
			# 攀爬回归：贴着测绘塔墙面推前进，应进入攀爬并升高。
			player.global_position = Vector3(-129.3, terrain.get_height(-129.3, 109) + 0.1, 109)
			player.rotation.y = PI * 0.5
			player.velocity = Vector3.ZERO
			player.debug_move = 1.0
			_wild_test_height = player.global_position.y
		680:
			player.debug_move = 0.0
			print("[wildtest] tower_climb start_y=%.2f end_y=%.2f climbing=%s rose=%.2f" % [_wild_test_height, player.global_position.y, str(player.is_climbing), player.global_position.y - _wild_test_height])
			_wild_test_stamina = player.stamina
			# 自动上台阶回归：走向驿站 0.37m 石基，应直接迈上去。
			player.global_position = Vector3(-87.0, terrain.get_height(-87.0, 21) + 0.1, 21)
			player.rotation.y = -PI * 0.5
			player.velocity = Vector3.ZERO
			player.debug_move = 1.0
			_wild_test_height = player.global_position.y
		720:
			player.debug_move = 0.0
			print("[wildtest] stable_step start_y=%.2f end_y=%.2f rose=%.2f" % [_wild_test_height, player.global_position.y, player.global_position.y - _wild_test_height])
			var weapon_loot := 0
			var ammo_loot := 0
			for item in get_tree().get_nodes_in_group("loot"):
				if item.kind == "weapon":
					weapon_loot += 1
				elif item.kind == "ammo":
					ammo_loot += 1
			print("[wildtest] wild_loot weapons=%d ammo=%d npcs=%d" % [weapon_loot, ammo_loot, get_tree().get_nodes_in_group("npc").size()])
			# 烹饪回归：火堆旁使用生兽肉应烤成烤兽肉；种子数量检查。
			player.give_item("meat", 1)
			player.backpack_items["mushroom"] = 0
			var camp: Vector3 = wild_world._camp_positions[0]
			player.global_position = camp + Vector3(1.5, 0, 0)
			player.backpack_index = player.backpack_weapons.size() + 1
			player._use_backpack_selection()
			var seed_loot := 0
			for item in get_tree().get_nodes_in_group("loot"):
				if item.kind == "seed":
					seed_loot += 1
			print("[wildtest] cooking roast_meat=%d seeds=%d" % [int(player.backpack_items["roast_meat"]), seed_loot])
			# 神庙试炼回归：射中全部符文应完成并产出精灵宝珠，拾取后生命上限 +10。
			var trial: ShrineTrial = wild_world.trials[0]
			player.global_position = trial.global_position + Vector3(0, 0, -8)
			var max_hp_before := player.max_hp
			for rune in trial._runes:
				rune.take_damage(10.0, player)
			var orb: Loot = null
			for item in get_tree().get_nodes_in_group("loot"):
				if item.kind == "orb":
					orb = item
					break
			if orb:
				orb.apply_to(player)
			print("[wildtest] shrine_trial completed=%s orb=%s max_hp %.0f->%.0f" % [str(trial.completed), str(orb != null), max_hp_before, player.max_hp])
			# 昼夜回归：推进时间应改变光照与阶段名。
			var energy_before := _sun.light_energy
			daynight.advance(13.0)
			print("[wildtest] daynight phase=%s night=%s sun_energy %.2f->%.2f" % [daynight.phase_name(), str(daynight.is_night()), energy_before, _sun.light_energy])
			# 血月回归：第三夜入夜触发血月并补齐怪物。
			daynight._night_index = 2
			daynight.t = 0.799
			var enemy_before := get_tree().get_nodes_in_group("wild_enemy").size()
			daynight.advance(0.05)
			var enemy_after := get_tree().get_nodes_in_group("wild_enemy").size()
			print("[wildtest] bloodmoon active=%s enemies %d->%d" % [str(daynight.blood_moon), enemy_before, enemy_after])
			# 呀哈哈谜题回归：风车命中产出种子。
			var prop := get_tree().get_first_node_in_group("korok") as KorokProp
			var seed_before := 0
			for item in get_tree().get_nodes_in_group("loot"):
				if item.kind == "seed":
					seed_before += 1
			if prop:
				prop.take_damage(5.0, player)
			var seed_after := 0
			for item in get_tree().get_nodes_in_group("loot"):
				if item.kind == "seed":
					seed_after += 1
			print("[wildtest] korok hit=%s seeds %d->%d" % [str(prop != null and prop.consumed), seed_before, seed_after])
			print("[wildtest] stamina after_climb=%.0f regen_to=%.0f" % [_wild_test_stamina, player.stamina])
			# 天气回归：强制下雨后雨强上升；守卫可被击杀并掉落补给。
			# 盾牌回归：格挡减伤 75%，完美格挡无伤反震。
			var test_enemy := get_tree().get_first_node_in_group("wild_enemy") as Node3D
			if test_enemy:
				test_enemy.global_position = player.global_position - player.global_transform.basis.z * 3.0
				player.blocking = true
				player._block_start = Time.get_ticks_msec() / 1000.0 - 1.0
				var hp_before_block := player.hp
				player.take_damage(20.0, test_enemy)
				var dmg_blocked := hp_before_block - player.hp
				hp_before_block = player.hp
				player._block_start = Time.get_ticks_msec() / 1000.0
				player.take_damage(20.0, test_enemy)
				var dmg_parry := hp_before_block - player.hp
				player.blocking = false
				print("[wildtest] shield blocked=%.0f parry=%.0f" % [dmg_blocked, dmg_parry])
			weather.force_rain(true)
			for i in range(60):
				weather._process(1.0 / 60.0)
			var guardian: Guardian = null
			for candidate in get_tree().get_nodes_in_group("wild_enemy"):
				if candidate is Guardian:
					guardian = candidate as Guardian
					break
			var loot_before_g := get_tree().get_nodes_in_group("loot").size()
			var guardian_dead := false
			if guardian:
				guardian.take_damage(999.0, player)
				guardian_dead = not guardian.alive
			print("[wildtest] weather rain=%.2f guardian dead=%s loot_delta=%d" % [weather.rain_strength, str(guardian_dead), get_tree().get_nodes_in_group("loot").size() - loot_before_g])
			# 精灵复活回归：死亡消耗一只精灵复活；火盆试炼可完成。
			player.fairies = 1
			player.hp = 5.0
			player.take_damage(999.0, null)
			print("[wildtest] fairy alive=%s hp=%.0f fairies=%d" % [str(player.alive), player.hp, player.fairies])
			var torch_trial: ShrineTrial = wild_world.trials[1]
			player.global_position = torch_trial.global_position + Vector3(0, 0, -8)
			for rune in torch_trial._runes:
				rune.take_damage(10.0, player)
			print("[wildtest] torch_trial completed=%s" % str(torch_trial.completed))
			# 古代剑回归：拾取后近战伤害 42。
			var sword_loot: Loot = null
			for item in get_tree().get_nodes_in_group("loot"):
				if item.kind == "master_sword":
					sword_loot = item
					break
			if sword_loot:
				sword_loot.apply_to(player)
			print("[wildtest] master_sword melee_damage=%.0f" % player.melee_damage)
			# 压力板回归：站上后计时完成。
			var plate_trial: ShrineTrial = wild_world.trials[2]
			player.global_position = plate_trial._plate.global_position
			plate_trial._plate_t = 3.95
			plate_trial._process(0.1)
			print("[wildtest] plate_trial completed=%s" % str(plate_trial.completed))
			# 盾滑回归：高原边缘坡面举盾应加速下滑。
			player.global_position = Vector3(-174, terrain.get_height(-174, 92) + 0.1, 92)
			player.velocity = Vector3.ZERO
			player.weapon.set_weapon("")
			player.debug_block = true
			_wild_test_surf_start = player.global_position
			print("[wildtest] done nodes=%d mem=%dMB" % [Performance.get_monitor(Performance.OBJECT_NODE_COUNT), int(Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0)])
			_wild_test_frame = 739
		756:
			player.debug_block = false
			player.blocking = false
			var surf_d := player.global_position - _wild_test_surf_start
			print("[wildtest] shield_surf moved=%.2f speed=%.1f" % [Vector2(surf_d.x, surf_d.z).length(), Vector2(player.velocity.x, player.velocity.z).length()])
			# 林克时间回归：闪避窗口内被击中触发慢动作且无伤。
			player._dodge_iframe_end = Time.get_ticks_msec() / 1000.0 + 0.3
			var hp_f := player.hp
			player.take_damage(20.0, get_tree().get_first_node_in_group("wild_enemy"))
			print("[wildtest] flurry active=%s dmg=%.0f timescale=%.2f" % [str(player.flurry), hp_f - player.hp, Engine.time_scale])
			player._end_flurry()
			# 抓鱼与石头阵回归。
			var fish := get_tree().get_first_node_in_group("fish") as FishSpot
			var meat_f := int(player.backpack_items["meat"])
			if fish:
				fish.catch(player)
			var circle := get_tree().get_first_node_in_group("rock_circle") as RockCircle
			if circle:
				player.global_position = circle.global_position + circle._gap_pos
				circle._process(1.1)
			print("[wildtest] fish meat=%d circle=%s" % [int(player.backpack_items["meat"]) - meat_f, str(circle.completed if circle else false)])
			# 莫布林回归：前摇结束后猛击命中；烤串加攻。
			for e in get_tree().get_nodes_in_group("wild_enemy"):
				if e is WildMoblin:
					_wild_test_moblin = e as WildMoblin
					break
			var moblin := _wild_test_moblin
			if moblin:
				player._dodge_iframe_end = -1.0
				player.alive = true
				player.hp = player.max_hp
				player.global_position = moblin.global_position + Vector3(0, 0, 2.0)
				player.velocity = Vector3.ZERO
				var hp_m := player.hp
				moblin._windup = 0.89
				moblin._physics_process(0.05)
				print("[wildtest] moblin smash dmg=%.0f" % [hp_m - player.hp])
			player.give_item("meat", 1)
			player.give_item("mushroom", 1)
			player.global_position = wild_world._camp_positions[0] + Vector3(1.5, 0, 0)
			player.backpack_index = player.backpack_weapons.size() + 1
			player._use_backpack_selection()
			print("[wildtest] skewer mult=%.2f t=%.0f" % [player.skewer_mult, player._skewer_t])
			# 床铺回归：睡觉回满并进入清晨；蜥蜴战士存在。
			var bed := get_tree().get_first_node_in_group("bed") as BedSpot
			player.hp = 40.0
			if bed:
				bed.use(player)
			var liz_count := 0
			for e in get_tree().get_nodes_in_group("wild_enemy"):
				if e is WildLizalfos:
					liz_count += 1
			print("[wildtest] bed hp=%.0f phase=%s lizalfos=%d" % [player.hp, daynight.phase_name(), liz_count])
			# 弓箭回归：满拉弓射出箭矢，稍后检查命中。
			if _wild_test_moblin:
				player.weapon.set_weapon("bow")
				player.global_position = _wild_test_moblin.global_position + Vector3(0, 0, 15)
				var to_m3: Vector3 = _wild_test_moblin.global_position - player.global_position
				player.rotation.y = atan2(to_m3.x, to_m3.z) + PI
				player.pitch = 0.0
				player.camera.rotation.x = 0.0
				player._bow_draw = 1.0
				_wild_test_hp = _wild_test_moblin.hp
				player._fire_arrow()
				print("[wildtest] bow reserve=%d" % player.weapon.reserve)
			# 弹反回归：举盾面向来石应将其弹回且不伤血（放在弓箭之后，避免传送冲突）。
			player.weapon.set_weapon("")
			player.debug_block = true
			player._dodge_iframe_end = -1.0
			var rock := WildProjectile.new()
			add_child(rock)
			rock.configure("rock", player.global_transform.basis.z * 12.0, 12.0, null)
			rock.global_position = player.global_position - player.global_transform.basis.z * 3.0 + Vector3(0, 1.0, 0)
			_wild_test_parry_hp = player.hp
			# 守卫光束弹反回归：完美格挡窗口内受光束，守卫自毁。
			player.debug_block = true
			player._block_start = Time.get_ticks_msec() / 1000.0
			player.alive = true
			player.hp = player.max_hp
			player.blocking = true
			var g2: Guardian = null
			for e in get_tree().get_nodes_in_group("wild_enemy"):
				if e is Guardian:
					g2 = e as Guardian
					break
			if g2:
				player.take_damage(30.0, g2)
				print("[wildtest] beam_parry guardian_alive=%s" % str(g2.alive))
			# 木筏回归：上筏前行一段。
			var raft: Raft = null
			for v in get_tree().get_nodes_in_group("vehicle"):
				if v is Raft:
					raft = v as Raft
					break
			if raft:
				player.global_position = raft.global_position + Vector3(1.0, 0, 0)
				raft.enter(player)
				raft.debug_forward = 1.0
				_wild_test_surf_start = raft.global_position
			# 任务回归：蘑菇任务接取-采集-交付。
			var npc0: WildNPC = null
			for n in get_tree().get_nodes_in_group("npc"):
				if n.quest_id == "mushroom3":
					npc0 = n
					break
			var armor_before := player.armor
			if npc0:
				player.backpack_items["mushroom"] = 0
				npc0.talk()
				player.give_item("mushroom", 3)
				npc0.talk()
			print("[wildtest] quest state=%d armor=%.0f->%.0f" % [quest_states["mushroom3"], armor_before, player.armor])
			# NPC 面向回归：脸朝 -Z 的模型必须正对玩家（防背身 bug），新模型应带腿枢轴。
			if npc0:
				player.global_position = npc0.global_position + Vector3(0, 0, 3.0)
				for i in range(40):
					npc0._physics_process(0.1)
				var npc_to_p: Vector3 = (player.global_position - npc0.global_position).normalized()
				var npc_fwd: Vector3 = -npc0.global_transform.basis.z
				print("[wildtest] npc_facing dot=%.2f legs=%s" % [npc_fwd.dot(npc_to_p), str(npc0._leg_l != null or npc0._glb != null)])
			# 龙鳞任务回归：交付龙鳞得精力上限。
			var npc1: WildNPC = null
			for n in get_tree().get_nodes_in_group("npc"):
				if n.quest_id == "scale1":
					npc1 = n
					break
			var stam_before := player.max_stamina
			if npc1:
				npc1.talk()
				player.give_item("dragon_scale", 1)
				npc1.talk()
			# 护送回归：接受后行商到达桥段且玩家随行，判定完成。
			var merchant: WildNPC = null
			for n in get_tree().get_nodes_in_group("npc"):
				if n.quest_id == "escort":
					merchant = n
					break
			if merchant:
				merchant.talk()
				merchant._patrol_i = 3
				player.global_position = merchant.global_position + Vector3(1.5, 0, 0)
				_update_escort_quest()
			print("[wildtest] scale_quest=%d stam=%.0f->%.0f escort=%d" % [quest_states["scale1"], stam_before, player.max_stamina, quest_states["escort"]])
			# 血月全类型苏醒回归；呀哈哈面具回归。
			var enemies_before := get_tree().get_nodes_in_group("wild_enemy").size()
			var respawned := wild_world.respawn_monsters()
			player.seed_count = 9
			player.collect_seed()
			print("[wildtest] bloodmoon_full respawned=%d enemies %d->%d charm=%.2f" % [respawned, enemies_before, get_tree().get_nodes_in_group("wild_enemy").size(), player.charm_mult])
			# 跳水环与推球试炼回归。
			var dring := get_tree().get_first_node_in_group("dive_ring") as DiveRing
			player.is_swimming = true
			if dring:
				player.global_position = dring.global_position
				dring._process(0.1)
			player.is_swimming = false
			var btrial: ShrineTrial = wild_world.trials[3]
			if btrial.mode == "ball":
				btrial._ball.global_position = btrial.global_position + btrial._socket
				btrial._process(0.1)
			print("[wildtest] dive_ring=%s ball_trial=%s" % [str(dring.completed if dring else false), str(btrial.completed)])
			# 花径回归：顺序触碰全部花朵出种子。
			var trail := get_tree().get_first_node_in_group("flower_trail") as FlowerTrail
			if trail:
				var guard := 0
				while not trail.completed and guard < 8:
					guard += 1
					player.global_position = trail.global_position + trail._flowers[trail._next].position
					trail._process(0.1)
				print("[wildtest] flower_trail completed=%s" % str(trail.completed))
			_wild_test_frame = 757
		790:
			print("[wildtest] parry hp_delta=%.0f count=%d" % [_wild_test_parry_hp - player.hp, player.parry_count])
			var raft: Raft = null
			for v in get_tree().get_nodes_in_group("vehicle"):
				if v is Raft:
					raft = v as Raft
					break
			if raft:
				print("[wildtest] raft moved=%.2f" % [_wild_test_surf_start.distance_to(raft.global_position)])
				raft.debug_forward = 0.0
				raft.exit()
			if _wild_test_moblin:
				print("[wildtest] bow_hit dmg=%.0f" % [_wild_test_hp - _wild_test_moblin.hp])
			print("[wildtest] end nodes=%d" % Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
			# 讨伐结局回归：玩家击杀焚天者触发讨伐结算。
			var dragon: WildDragon = null
			for e in get_tree().get_nodes_in_group("wild_enemy"):
				if e is WildDragon:
					dragon = e as WildDragon
					break
			if dragon:
				dragon.take_damage(999.0, player)
			print("[wildtest] dragon_end match_over=%s" % str(match_over))
			_wild_test_frame = -1


func _find_choppable() -> ChoppableTree:
	if props == null:
		return null
	for child in props.get_children():
		if child.name.begins_with("Tree"):
			for sub in child.get_children():
				if sub is ChoppableTree:
					return sub as ChoppableTree
	return null


func _setup_environment() -> void:
	var env := Environment.new()
	_env = env
	if OS.get_cmdline_user_args().has("--flatsky"):
		env.background_mode = Environment.BG_CLEAR_COLOR
		var we0 := WorldEnvironment.new()
		we0.environment = env
		add_child(we0)
		return
	var sky := Sky.new()
	var psm := ProceduralSkyMaterial.new()
	_sky_mat = psm
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

	# 三灯架设（参考 Elemental-Serenity）：暖色主光 + 天蓝补光 + 暖橙轮廓光
	var sun := DirectionalLight3D.new()
	_sun = sun
	sun.name = "Sun"
	sun.light_color = Color(1.0, 0.957, 0.902)
	sun.light_energy = 1.15
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 250.0
	sun.shadow_bias = 0.03
	sun.rotation_degrees = Vector3(-48.0, -35.0, 0.0)
	add_child(sun)

	var fill := DirectionalLight3D.new()
	_fill = fill
	fill.name = "FillLight"
	fill.light_color = Color(0.53, 0.81, 0.92)
	fill.light_energy = 0.42
	fill.shadow_enabled = false
	fill.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY   # 不在天上画太阳盘
	fill.rotation_degrees = Vector3(-22.0, 145.0, 0.0)
	add_child(fill)

	var rim := DirectionalLight3D.new()
	_rim = rim
	rim.name = "RimLight"
	rim.light_color = Color(1.0, 0.84, 0.64)
	rim.light_energy = 0.35
	rim.shadow_enabled = false
	rim.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	rim.rotation_degrees = Vector3(-62.0, 190.0, 0.0)
	add_child(rim)

	_spawn_clouds()


var _clouds: Array[Node3D] = []

func _spawn_clouds() -> void:
	if OS.get_cmdline_user_args().has("--noclouds"):
		return
	# 扁平大朵白云，缓慢漂移（旷野之息招牌天空）
	var rng := RandomNumberGenerator.new()
	rng.seed = 88
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 1.0, 1.0, 0.88)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.disable_fog = true
	for i in range(22):
		var cloud := Node3D.new()
		cloud.position = Vector3(rng.randf_range(-460, 460), rng.randf_range(105, 160), rng.randf_range(-460, 460))
		for j in range(rng.randi_range(3, 5)):
			var puff := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = rng.randf_range(10.0, 22.0)
			sm.height = sm.radius * 2.0
			sm.radial_segments = 8
			sm.rings = 4
			puff.mesh = sm
			puff.material_override = mat
			puff.position = Vector3(rng.randf_range(-22, 22), rng.randf_range(-2.5, 2.5), rng.randf_range(-9, 9))
			puff.scale = Vector3(1.6, 0.38, 1.0)
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
