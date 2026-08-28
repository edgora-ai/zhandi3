class_name WildWorld
extends Node3D
## 阔野地图内容总成：神庙、驿站、遗迹、桥梁、火堆、骑乘物、生态与敌人。

var terrain: Terrain
var player: Player

var _stone: StandardMaterial3D
var _stone_dark: StandardMaterial3D
var _wood: StandardMaterial3D
var _wood_dark: StandardMaterial3D
var _cloth: StandardMaterial3D
var _roof: StandardMaterial3D
var _roof_trim: StandardMaterial3D
var _plaster: StandardMaterial3D
var _castle_blue: StandardMaterial3D
var _path: StandardMaterial3D
var _ancient: StandardMaterial3D
var _fire: StandardMaterial3D
var _lava: StandardMaterial3D
var _flames: Array[MeshInstance3D] = []
var _camp_positions: Array[Vector3] = []
var trials: Array[ShrineTrial] = []
var _time := 0.0
var _monster_points: Array = []
var _animal_specs: Array = []
var _moblin_points: Array = []
var _liz_points: Array = []
var _guardian_points: Array = []
# Phase3 血月扩展占位 (P5/D7)：后期类型用空数组 + _enemy_near 分支，保证 Phase3 可验证且不改现行为
var _chuchu_points: Array = []
var _keese_points: Array = []
var _stal_points: Array = []
var _wizzrobe_points: Array = []
var _hinox_points: Array = []
var _flyer_points: Array = []
var _dragon_points: Array = []


func generate(p_terrain: Terrain, p_player: Player) -> void:
	terrain = p_terrain
	player = p_player
	_build_materials()
	var shrine0 := _build_shrine(Vector3(-112, terrain.get_height(-112, 92), 92), 0.15)
	_link_shrine_interior(shrine0, 0)
	var shrine1 := _build_shrine(_ground(Vector3(105, 0, 25)), -0.8, true)
	_link_shrine_interior(shrine1, 1)
	var shrine2 := _build_shrine(_ground(Vector3(-140, 0, -110)), 2.2, "plate")
	_link_shrine_interior(shrine2, 2)
	var shrine3 := _build_shrine(_ground(Vector3(55, 0, -30)), -0.4, "ball")
	_link_shrine_interior(shrine3, 3)
	_build_stable(Vector3(-72, terrain.get_height(-72, 21), 21))
	_build_temple_ruins(Vector3(18, terrain.get_height(18, -94), -94))
	_build_river_bridge(18.0)
	_build_ancient_tower(_ground(Vector3(-132, 0, 109)), 15.5)
	_build_ancient_tower(_ground(Vector3(72, 0, 116)), 18.0)
	_build_ancient_tower(_ground(Vector3(-132, 0, -78)), 17.0)
	_build_castle(Vector3(4, terrain.get_height(4, -124), -124))
	_build_signposts()
	_build_paddock(_ground(Vector3(-56, 0, 30)))
	_build_wagon(_ground(Vector3(-63, 0, 13)), 1.2)
	_build_road_lanterns()
	_build_fallen_columns()
	_spawn_butterflies()
	_build_rock_spires()
	_build_river_life()
	_build_volcano_caldera()
	_spawn_campfires()
	_spawn_mounts()
	_spawn_mushrooms()
	_spawn_monsters()
	_spawn_animals()
	_spawn_dragon()
	_spawn_flying_attackers()
	_build_region_ambience()
	# 两台古代守卫：遗迹与城堡各一台。
	for gp in [Vector3(26, 0, -88), Vector3(-6, 0, -116)]:
		_guardian_points.append(gp)
		var guardian := Guardian.new()
		guardian.setup(terrain, player)
		guardian.position = _ground(gp, 0.05)
		add_child(guardian)
	# 三只莫布林：草原/谷地/营地外围的重击手。
	for mp in [Vector3(30, 0, 60), Vector3(-60, 0, -20), Vector3(120, 0, -40)]:
		_moblin_points.append(mp)
		var moblin := WildMoblin.new()
		moblin.setup(terrain, player)
		moblin.position = _ground(mp, 0.05)
		add_child(moblin)
	_spawn_npcs()
	# 三块磁力金属块：压力板神庙、城堡门前、遗迹旁，供磁力搬运与投掷。
	for mp in [Vector3(-136, 0, -104), Vector3(6, 0, -108), Vector3(30, 0, -84)]:
		MetalProp.create(self, _ground(mp, 0.45))
	# 丘丘果冻群：河滩与林缘四只大只（死亡分裂）。
	_chuchu_points = [Vector3(-40, 0, 45), Vector3(15, 0, 70), Vector3(-90, 0, -30), Vector3(60, 0, 40)]
	for cp in _chuchu_points:
		Chuchu.create(self, terrain, player, _ground(cp, 0.05))
	# 夜行蝙蝠两窝：遗迹与北林（夜间盘旋俯冲，白天蛰伏）。
	_keese_points = [Vector3(26, 0, -88), Vector3(-100, 0, -60)]
	for kp in _keese_points:
		for i in range(3):
			var bat := Keese.new()
			bat.setup(terrain, player, _ground(kp, 6.0) + Vector3(randf_range(-3, 3), randf_range(0, 2), randf_range(-3, 3)))
			add_child(bat)
	# 骷髅坟场：遗迹三具、城堡外两具（夜间破土，白天潜伏）。
	_stal_points = [Vector3(28, 0, -86), Vector3(23, 0, -91), Vector3(30, 0, -90), Vector3(2, 0, -100), Vector3(-4, 0, -103)]
	for sp in _stal_points:
		Stal.create_body(self, terrain, player, _ground(sp, 0.05))
	# 维佐法师两名：火山山麓与北谷（悬浮施法、近身闪现）。
	_wizzrobe_points = [Vector3(95, 0, -60), Vector3(-60, 0, -120)]
	for wp in _wizzrobe_points:
		Wizzrobe.create(self, terrain, player, _ground(wp, 1.5))
	# 三座防具宝箱：城堡庭院（士兵）、测绘塔下（攀爬者）、火山口（蛮族）。
	LootChest.create(self, _ground(Vector3(4, 0, -116), 0.0), "armor_soldier", 0.4)
	LootChest.create(self, _ground(Vector3(-128, 0, 106), 0.0), "armor_climber", -0.6)
	LootChest.create(self, _ground(Vector3(152, 0, -138), 0.0), "armor_barbarian", 2.2)
	# 西诺克斯两头：双子山谷与北林缘（沉睡巨人，靠近惊醒）。
	_hinox_points = [Vector3(70, 0, 45), Vector3(-80, 0, -60)]
	for hp in _hinox_points:
		Hinox.create(self, terrain, player, _ground(hp, 0.0))
	# 三座测绘塔顶传送水晶（激活后 M 地图传送）。
	WarpBeacon.create(self, _ground(Vector3(-132, 0, 109)) + Vector3(0, 16.5, 0), "高原塔")
	WarpBeacon.create(self, _ground(Vector3(72, 0, 116)) + Vector3(0, 19.0, 0), "双子塔")
	WarpBeacon.create(self, _ground(Vector3(-132, 0, -78)) + Vector3(0, 18.0, 0), "雪原塔")
	# 桥西码头木筏。
	# 裂岩洞窟与两块碎石：双子谷口岩壁上的炸岩秘宝（精灵宝珠），另两处材料小奖励。
	CrackedWall.create(self, _ground(Vector3(-95, 0, 92)), PI * 0.5, Vector3(4.5, 3.2, 1.0), "orb")
	CrackedWall.create(self, _ground(Vector3(22, 0, -82)), 0.9, Vector3(2.4, 1.8, 1.6), "monster_part")
	CrackedWall.create(self, _ground(Vector3(-38, 0, 58)), 2.2, Vector3(2.2, 1.6, 1.5), "meat")
	var raft_z := 18.0
	var raft_x := sin(raft_z * 0.021) * 24.0 - 8.0 + sin(raft_z * 0.049) * 7.0 - 12.0
	var raft := Raft.new()
	raft.position = Vector3(raft_x, Terrain.WATER_LEVEL + 0.05, raft_z + 2.0)
	add_child(raft)
	# 两只蜥蜴战士：草原与河滩的高速袭扰者。
	for lp in [Vector3(-30, 0, 75), Vector3(55, 0, -20)]:
		_liz_points.append(lp)
		var liz := WildLizalfos.new()
		liz.setup(terrain, player)
		liz.position = _ground(lp, 0.05)
		add_child(liz)
	_spawn_wild_loot()
	_spawn_fish_and_circles()
	_build_home(_ground(Vector3(-122, 0, 98)))
	_spawn_korok_props()
	_build_monster_camp(Vector3(60, 0, 86), 0.6)
	_build_monster_camp(Vector3(-128, 0, -58), -0.9)
	_build_forest_floor()
	_build_volcano_basalt()
	_build_snow_rocks()
	print("[wild] shrines=4 stable=1 bridge=1 towers=3 castle=1 monsters=8 wildlife=19 horses=4 npcs=4 dragon=1 flyers=3")


func _build_materials() -> void:
	_stone = Toon.make_material(Color(0.64, 0.65, 0.57), true, 0.018)
	_stone_dark = Toon.make_material(Color(0.29, 0.34, 0.34), true, 0.014)
	_wood = Toon.make_material(Color(0.48, 0.29, 0.13), true, 0.014)
	_wood_dark = Toon.make_material(Color(0.22, 0.13, 0.075), true, 0.012)
	_cloth = Toon.make_material(Color(0.84, 0.72, 0.43), true, 0.012)
	_roof = Toon.make_material(Color(0.44, 0.12, 0.075), true, 0.016)
	_roof_trim = Toon.make_material(Color(0.77, 0.32, 0.12), true, 0.013)
	_plaster = Toon.make_material(Color(0.82, 0.72, 0.52), true, 0.012)
	_castle_blue = Toon.make_material(Color(0.15, 0.30, 0.56), true, 0.014)
	_path = Toon.make_material(Color(0.68, 0.59, 0.39), false)
	_ancient = StandardMaterial3D.new()
	_ancient.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ancient.albedo_color = Color(0.045, 0.90, 0.82)
	_ancient.emission_enabled = true
	_ancient.emission = Color(0.02, 0.96, 0.84)
	_ancient.emission_energy_multiplier = 2.6
	_fire = StandardMaterial3D.new()
	_fire.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_fire.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_fire.albedo_color = Color(1.0, 0.27, 0.025, 0.90)
	_fire.emission_enabled = true
	_fire.emission = Color(1.0, 0.16, 0.015)
	_fire.emission_energy_multiplier = 3.0
	_lava = StandardMaterial3D.new()
	_lava.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_lava.albedo_color = Color(1.0, 0.18, 0.015)
	_lava.emission_enabled = true
	_lava.emission = Color(1.0, 0.09, 0.01)
	_lava.emission_energy_multiplier = 3.5


func _ground(p: Vector3, offset: float = 0.0) -> Vector3:
	p.y = terrain.get_height(p.x, p.z) + offset
	return p


func _part(size: Vector3, mat: Material, pos: Vector3, parent: Node3D, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot
	parent.add_child(mi)
	return mi


func _cylinder(radius: float, height: float, mat: Material, pos: Vector3, parent: Node3D, rot: Vector3 = Vector3.ZERO, segments: int = 12) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = segments
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot
	parent.add_child(mi)
	return mi


func _frustum(top_radius: float, bottom_radius: float, height: float, mat: Material, pos: Vector3, parent: Node3D, segments: int = 16) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = top_radius
	mesh.bottom_radius = bottom_radius
	mesh.height = height
	mesh.radial_segments = segments
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi


func _sphere(radius: float, mat: Material, pos: Vector3, parent: Node3D, shape_scale: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 10
	mesh.rings = 6
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.scale = shape_scale
	parent.add_child(mi)
	return mi


func _body(parent: Node3D) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	parent.add_child(body)
	return body


func _box_collision(body: StaticBody3D, size: Vector3, pos: Vector3, rot: Vector3 = Vector3.ZERO) -> void:
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	col.position = pos
	col.rotation_degrees = rot
	body.add_child(col)


func _cylinder_collision(body: StaticBody3D, radius: float, height: float, pos: Vector3, rot_deg: Vector3 = Vector3.ZERO) -> void:
	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = height
	col.shape = shape
	col.position = pos
	col.rotation_degrees = rot_deg
	body.add_child(col)


func _build_shrine(world_pos: Vector3, yaw: float, trial_mode: Variant = "rune") -> Node3D:
	var shrine := Node3D.new()
	shrine.name = "AncientShrine"
	shrine.position = world_pos
	shrine.rotation.y = yaw
	add_child(shrine)
	var body := _body(shrine)
	# 三层八角基台用缩进石阶营造重量，入口前留出完整动线。
	for i in range(3):
		var size := 10.5 - i * 1.2
		_part(Vector3(size, 0.42, size), _stone_dark if i == 0 else _stone, Vector3(0, i * 0.38 - 0.18, 0), shrine)
		_box_collision(body, Vector3(size, 0.42, size), Vector3(0, i * 0.38 - 0.18, 0))
	# 正门前台阶：从地面走上三层基台。
	_staircase(shrine, body, Vector3(0, 0.30, -7.6), 3.0, 4.4, 0.8, 0.0, _stone, 4)
	# 十二边石室与椭圆穹顶取代方盒主体，远处也能辨认古代神庙轮廓。
	_cylinder(3.55, 4.5, _stone, Vector3(0, 2.9, 0.35), shrine, Vector3.ZERO, 12)
	# 穹顶用三段圆台堆出圆弧：法线干净受光均匀，远看是浅色石殿而不是黑块。
	_frustum(2.95, 3.52, 0.56, _stone, Vector3(0, 5.42, 0.35), shrine, 16)
	_frustum(2.05, 2.95, 0.50, _stone, Vector3(0, 5.94, 0.35), shrine, 16)
	_frustum(0.70, 2.05, 0.42, _stone, Vector3(0, 6.38, 0.35), shrine, 16)
	_box_collision(body, Vector3(6.4, 4.2, 6.8), Vector3(0, 2.75, 0.35))
	for sx in [-1.0, 1.0]:
		_part(Vector3(1.1, 3.8, 6.9), _stone_dark, Vector3(sx * 3.45, 2.65, 0.35), shrine, Vector3(0, 0, sx * -10.0))
		for y in range(4):
			_part(Vector3(0.10, 0.62, 5.4 - y * 0.3), _ancient, Vector3(sx * 3.28, 1.2 + y * 0.85, 0.45), shrine)
	# 环绕石室的竖向符文和腰线打破大面积素面。
	for i in range(12):
		var angle := i * TAU / 12.0
		var rune_pos := Vector3(sin(angle) * 3.52, 3.0, cos(angle) * 3.52 + 0.35)
		var rune := _part(Vector3(0.10, 2.25, 0.12), _ancient, rune_pos, shrine)
		rune.rotation.y = angle
		var belt := _part(Vector3(0.50, 0.12, 0.16), _stone_dark, Vector3(sin(angle) * 3.58, 1.25, cos(angle) * 3.58 + 0.35), shrine)
		belt.rotation.y = angle
	# 门洞用发光门片和深色外框表达可进入的古代装置。
	_part(Vector3(2.3, 3.2, 0.22), _stone_dark, Vector3(0, 2.1, -3.15), shrine)
	_part(Vector3(1.45, 2.45, 0.10), _ancient, Vector3(0, 1.95, -3.29), shrine)
	for sx in [-1.0, 1.0]:
		_part(Vector3(0.26, 3.6, 0.38), _stone_dark, Vector3(sx * 1.15, 2.15, -3.35), shrine)
	_part(Vector3(2.6, 0.28, 0.40), _stone_dark, Vector3(0, 3.88, -3.35), shrine)
	# 神庙试炼：限时射符文的解谜入口。
	var trial := ShrineTrial.new()
	trial.setup(player, trial_mode)
	shrine.add_child(trial)
	trials.append(trial)
	# 顶部同心圆盘和四根弯角用圆柱与斜梁组合。
	_cylinder(2.25, 0.28, _stone_dark, Vector3(0, 6.68, 0.3), shrine)
	_cylinder(1.72, 0.16, _ancient, Vector3(0, 6.85, 0.3), shrine)
	# 四根浅色石角向外张开、角尖带青光：剪影是张开的古代花冠，而不是实心黑塔尖。
	for i in range(4):
		var angle := i * TAU / 4.0
		var p := Vector3(sin(angle) * 2.55, 7.38, cos(angle) * 2.55 + 0.3)
		var fin := _part(Vector3(0.34, 1.95, 0.24), _stone, p, shrine)
		fin.rotation = Vector3(0.38, angle, 0.0)
		var tip := _part(Vector3(0.36, 0.26, 0.26), _ancient, p + Vector3(sin(angle) * 0.40, 0.92, cos(angle) * 0.40), shrine)
		tip.rotation = Vector3(0.38, angle, 0.0)
	var light := OmniLight3D.new()
	light.light_color = Color(0.04, 0.95, 0.83)
	light.light_energy = 1.5
	light.omni_range = 13.0
	light.position = Vector3(0, 3.2, -2.7)
	shrine.add_child(light)
	return shrine


# 每座神庙挂一间地底石室：试炼完成开门，精灵宝珠在室内的导师台座上。
func _link_shrine_interior(shrine: Node3D, idx: int) -> void:
	var trial: ShrineTrial = trials[idx]
	var door_world: Vector3 = shrine.global_transform * Vector3(0, 0.4, -5.6)
	var interior := ShrineInterior.create(self, Vector3(700.0 + idx * 40.0, -60.0, 700.0), trial, door_world)
	ShrineDoor.create(shrine, Vector3(0, 0.6, -4.6), trial, interior)


func _build_stable(world_pos: Vector3) -> void:
	var stable := Node3D.new()
	stable.name = "HighlandStable"
	stable.position = world_pos
	stable.rotation.y = -0.25
	add_child(stable)
	var body := _body(stable)
	# 26 米圆形石基、环形客栈和巨大帐篷顶共同形成远处可识别的驿站体量。
	_cylinder(13.2, 0.38, _stone_dark, Vector3(0, 0.05, 0), stable, Vector3.ZERO, 24)
	_cylinder(12.65, 0.16, _stone, Vector3(0, 0.29, 0), stable, Vector3.ZERO, 24)
	_cylinder_collision(body, 13.0, 0.42, Vector3(0, 0.08, 0))
	# 中央旅店用分段墙围成，正面留出真正的入口和柜台，不再是一只封闭方盒。
	for i in range(18):
		if i in [8, 9, 10]:
			continue
		var angle := float(i) * TAU / 18.0
		var wall_pos := Vector3(sin(angle) * 5.30, 1.92, cos(angle) * 5.30)
		var wall := _part(Vector3(1.92, 3.30, 0.38), _plaster, wall_pos, stable)
		wall.rotation.y = angle
		_box_collision(body, Vector3(1.92, 3.30, 0.38), wall_pos, Vector3(0, rad_to_deg(angle), 0))
		_part(Vector3(1.96, 0.18, 0.46), _wood_dark, wall_pos + Vector3(0, 1.48, 0), stable, Vector3(0, rad_to_deg(angle), 0))
	# 入口门框、接待柜台、厨房烟囱和两侧住宿小间。
	for sx in [-1.0, 1.0]:
		_part(Vector3(0.34, 3.45, 0.42), _wood_dark, Vector3(sx * 1.72, 1.94, -5.22), stable)
		_part(Vector3(3.1, 2.30, 3.25), _cloth, Vector3(sx * 8.1, 1.45, 2.45), stable)
		_box_collision(body, Vector3(3.1, 2.30, 3.25), Vector3(sx * 8.1, 1.45, 2.45))
		var annex_roof := _part(Vector3(3.7, 0.24, 4.0), _roof_trim, Vector3(sx * 8.1, 2.84, 2.45), stable, Vector3(0, 0, sx * 8.0))
		annex_roof.rotation_degrees.z = sx * 8.0
	_part(Vector3(4.2, 1.02, 0.80), _wood, Vector3(0, 0.86, -4.72), stable)
	_box_collision(body, Vector3(4.2, 1.02, 0.80), Vector3(0, 0.86, -4.72))
	_part(Vector3(0.76, 5.4, 0.76), _stone_dark, Vector3(3.45, 3.2, 2.9), stable)
	_part(Vector3(1.08, 0.34, 1.08), _roof_trim, Vector3(3.45, 6.02, 2.9), stable)

	# 外圈十六根承重柱、交叉斜撑和围绕旅店的可用廊道。
	for i in range(16):
		var angle := float(i) * TAU / 16.0
		var post_pos := Vector3(sin(angle) * 10.65, 2.26, cos(angle) * 10.65)
		_part(Vector3(0.38, 4.25, 0.38), _wood_dark, post_pos, stable)
		_box_collision(body, Vector3(0.38, 4.25, 0.38), post_pos)
		var brace := _part(Vector3(0.22, 2.55, 0.22), _wood, post_pos + Vector3(0, 1.05, 0), stable)
		brace.rotation.y = angle
		brace.rotation.z = -0.52 if i % 2 == 0 else 0.52
	# 巨大的十八边帐篷屋顶、亮色檐带和顶冠取代两块薄板顶棚。
	_frustum(3.55, 12.85, 4.25, _roof, Vector3(0, 6.25, 0), stable, 18)
	_cylinder(12.88, 0.20, _roof_trim, Vector3(0, 4.10, 0), stable, Vector3.ZERO, 24)
	_cylinder(3.65, 0.28, _roof_trim, Vector3(0, 8.42, 0), stable, Vector3.ZERO, 18)
	_frustum(0.55, 3.20, 1.45, _roof_trim, Vector3(0, 9.12, 0), stable, 16)
	# 顶部马首招牌放大到两层楼高：奶白长脸 + 深色鬃毛鼻口，百米外也是导航剪影。
	var crest := Node3D.new()
	crest.position = Vector3(0, 10.1, -0.15)
	stable.add_child(crest)
	var crest_neck := _part(Vector3(1.50, 3.05, 1.62), _wood_dark, Vector3(0, 0.95, 0), crest, Vector3(-38, 0, 0))
	crest_neck.rotation_degrees.x = -38.0
	_sphere(1.42, _cloth, Vector3(0, 2.48, -1.50), crest, Vector3(0.82, 0.70, 1.52))
	_sphere(0.78, _cloth, Vector3(0, 2.14, -3.08), crest, Vector3(0.95, 0.62, 1.28))
	_sphere(0.42, _wood_dark, Vector3(0, 2.02, -3.62), crest, Vector3(0.90, 0.55, 0.90))
	var mane := _part(Vector3(0.42, 1.15, 1.35), _wood_dark, Vector3(0, 3.10, -0.55), crest, Vector3(-32, 0, 0))
	mane.rotation_degrees.x = -32.0
	for sx in [-1.0, 1.0]:
		var ear := _part(Vector3(0.31, 0.84, 0.27), _wood_dark, Vector3(sx * 0.57, 3.85, -1.28), crest)
		ear.rotation_degrees.z = sx * -13.0

	# 马槽、拴马栏、长凳、货箱与灯笼让廊下具备功能，而不是空壳。
	for sx in [-8.2, 8.2]:
		_part(Vector3(3.25, 0.68, 0.92), _wood, Vector3(sx, 0.70, -4.25), stable)
		for j in range(4):
			_part(Vector3(0.14, 1.55, 0.14), _wood_dark, Vector3(sx - 1.35 + j * 0.9, 1.02, -6.20), stable)
		_part(Vector3(3.05, 0.12, 0.14), _wood_dark, Vector3(sx, 1.43, -6.20), stable)
	for z in [4.85, 7.15]:
		_part(Vector3(2.4, 0.20, 0.68), _wood, Vector3(-7.25, 0.62, z), stable)
		_part(Vector3(1.15, 1.15, 1.15), _wood_dark, Vector3(7.65, 0.84, z), stable)
	for i in range(8):
		var angle := float(i) * TAU / 8.0 + PI / 8.0
		var lantern_pos := Vector3(sin(angle) * 9.75, 3.45, cos(angle) * 9.75)
		var lantern := _sphere(0.24, _ancient, lantern_pos, stable, Vector3(0.72, 1.30, 0.72))
		lantern.scale = Vector3(0.72, 1.30, 0.72)
		if i in [3, 4]:
			var light := OmniLight3D.new()
			light.light_color = Color(1.0, 0.58, 0.22)
			light.light_energy = 0.75
			light.omni_range = 8.0
			light.position = lantern_pos
			stable.add_child(light)


func _build_temple_ruins(world_pos: Vector3) -> void:
	var temple := Node3D.new()
	temple.name = "TimeTempleRuins"
	temple.position = world_pos
	add_child(temple)
	var body := _body(temple)
	_part(Vector3(20, 0.5, 28), _stone_dark, Vector3(0, -0.15, 0), temple)
	_box_collision(body, Vector3(20, 0.5, 28), Vector3(0, -0.15, 0))
	# 双排残柱、半塌主殿、彩窗和钟楼保留古老礼拜堂的纵深轴线。
	for side in [-1.0, 1.0]:
		for i in range(6):
			var height := 5.8 - (1.5 if i in [1, 5] else 0.0)
			_cylinder(0.52, height, _stone, Vector3(side * 6.5, height * 0.5, -9.5 + i * 3.7), temple, Vector3.ZERO, 10)
			_cylinder(0.72, 0.28, _stone_dark, Vector3(side * 6.5, 0.16, -9.5 + i * 3.7), temple)
			_cylinder(0.68, 0.30, _stone_dark, Vector3(side * 6.5, height, -9.5 + i * 3.7), temple)
	_part(Vector3(14.0, 7.8, 0.55), _stone, Vector3(0, 3.9, 11.5), temple)
	_box_collision(body, Vector3(14.0, 7.8, 0.55), Vector3(0, 3.9, 11.5))
	_part(Vector3(5.0, 8.8, 4.8), _stone_dark, Vector3(0, 4.4, 9.5), temple)
	_box_collision(body, Vector3(5.0, 8.8, 4.8), Vector3(0, 4.4, 9.5))
	_cylinder(1.35, 0.18, _ancient, Vector3(0, 5.0, 6.98), temple, Vector3(90, 0, 0), 18)
	# 双钟塔、破损尖顶、门廊和高窗把遗迹从灰色方盒提升为可辨认的区域中心。
	for side in [-1.0, 1.0]:
		_cylinder(2.05, 9.6, _stone_dark, Vector3(side * 7.15, 4.8, 9.2), temple, Vector3.ZERO, 10)
		_cylinder(2.35, 0.40, _stone, Vector3(side * 7.15, 9.72, 9.2), temple, Vector3.ZERO, 10)
		_frustum(0.18, 2.18, 3.5 if side < 0.0 else 2.45, _roof, Vector3(side * 7.15, 11.65 if side < 0.0 else 11.12, 9.2), temple, 10)
		for window_y in [3.4, 6.6]:
			_part(Vector3(0.82, 1.65, 0.12), _ancient, Vector3(side * 7.15, window_y, 7.11), temple)
	_part(Vector3(5.2, 1.15, 2.2), _stone, Vector3(0, 1.05, 6.55), temple)
	for side in [-1.0, 1.0]:
		_part(Vector3(0.55, 4.8, 0.72), _stone_dark, Vector3(side * 2.30, 2.65, 6.45), temple)
	_part(Vector3(5.15, 0.55, 0.78), _stone_dark, Vector3(0, 5.0, 6.45), temple)
	_frustum(0.16, 1.30, 4.2, _roof_trim, Vector3(0, 11.25, 9.45), temple, 8)
	# 残存侧墙和断裂横梁给纵深轴线增加多层遮挡。
	for z in [-7.8, -0.5, 5.2]:
		for side in [-1.0, 1.0]:
			_part(Vector3(0.48, 4.2, 3.4), _stone, Vector3(side * 8.6, 2.1, z), temple)
			var beam := _part(Vector3(5.8, 0.42, 0.46), _wood_dark, Vector3(side * 5.7, 4.35, z), temple)
			beam.rotation_degrees.z = side * (8.0 if z < 0.0 else -6.0)
	for i in range(5):
		var rubble := _part(Vector3(1.2 + i * 0.15, 0.65, 0.9), _stone, Vector3(-5 + i * 2.4, 0.28, -12 + sin(i) * 1.5), temple)
		rubble.rotation_degrees = Vector3(randf_range(-12, 12), randf_range(0, 180), randf_range(-10, 10))
	# 废墟藤蔓：断墙与柱面上爬回的绿色植物，让废墟“被时间占领”。
	var ivy := Toon.make_material(Color(0.22, 0.48, 0.12), true, 0.006)
	var ivy_spots := [
		Vector3(-6.5, 1.6, -9.5), Vector3(-6.4, 3.4, -5.8), Vector3(6.5, 2.2, -2.1),
		Vector3(6.5, 4.0, 1.6), Vector3(-6.5, 1.2, 5.3), Vector3(-3.4, 2.8, 11.2),
		Vector3(7.15, 3.1, 7.05), Vector3(-7.15, 5.2, 7.05),
	]
	for spot in ivy_spots:
		var patch := _sphere(randf_range(0.45, 0.8), ivy, spot, temple, Vector3(1.0, randf_range(1.2, 1.9), 0.35))
		patch.rotation_degrees.y = randf_range(0, 180)
		var drip := _part(Vector3(0.10, randf_range(0.8, 1.5), 0.08), ivy, spot + Vector3(0, -0.9, 0.05), temple)
		drip.rotation_degrees.z = randf_range(-8, 8)


func _build_river_bridge(z: float) -> void:
	var x := sin(z * 0.021) * 24.0 - 8.0 + sin(z * 0.049) * 7.0
	var bridge := Node3D.new()
	bridge.name = "HyliaBridge"
	bridge.position = Vector3(x, Terrain.WATER_LEVEL + 2.25, z)
	bridge.rotation.y = PI * 0.5
	add_child(bridge)
	var body := _body(bridge)
	# 44 米长、7.2 米宽的缓拱石桥，可同时容纳马匹和载具双向通过。
	const SEGMENTS := 23
	const SEGMENT_LENGTH := 2.0
	for i in range(SEGMENTS):
		var t := (float(i) - float(SEGMENTS - 1) * 0.5) / (float(SEGMENTS - 1) * 0.5)
		var arch_y := (1.0 - t * t) * 0.78
		var segment_z := (float(i) - float(SEGMENTS - 1) * 0.5) * SEGMENT_LENGTH
		var deck_pos := Vector3(0, arch_y, segment_z)
		_part(Vector3(7.2, 0.42, 2.06), _stone, deck_pos, bridge)
		_part(Vector3(6.45, 0.09, 1.88), _path, deck_pos + Vector3(0, 0.255, 0), bridge)
		_box_collision(body, Vector3(7.2, 0.44, 2.06), deck_pos)
		for side in [-1.0, 1.0]:
			var rail_pos := deck_pos + Vector3(side * 3.42, 0.62, 0)
			_part(Vector3(0.38, 0.92, 2.06), _stone_dark, rail_pos, bridge)
			_box_collision(body, Vector3(0.38, 0.92, 2.06), rail_pos)
	# 水中三组厚桥墩和外挑基座承担重量，避免桥面像悬浮木板。
	for pier_z in [-10.0, 0.0, 10.0]:
		_part(Vector3(8.3, 0.48, 2.8), _stone_dark, Vector3(0, -3.48, pier_z), bridge)
		for side in [-1.0, 1.0]:
			_part(Vector3(1.45, 7.0, 2.15), _stone_dark, Vector3(side * 2.65, -0.08, pier_z), bridge)
			_part(Vector3(2.0, 0.45, 2.65), _stone, Vector3(side * 2.65, -3.15, pier_z), bridge)
	# 两端门塔、中央灯柱、横梁和暖色旗帜构成大桥的远景轮廓。
	for gate_z in [-20.0, 20.0]:
		for side in [-1.0, 1.0]:
			var tower_x: float = float(side) * 4.05
			_cylinder(0.92, 5.4, _stone_dark, Vector3(tower_x, 2.55, gate_z), bridge, Vector3.ZERO, 10)
			_cylinder(1.18, 0.36, _stone, Vector3(tower_x, 5.38, gate_z), bridge, Vector3.ZERO, 10)
			_frustum(0.10, 1.10, 1.55, _roof_trim, Vector3(tower_x, 6.28, gate_z), bridge, 10)
			_part(Vector3(0.10, 2.25, 1.25), _roof_trim, Vector3(tower_x - side * 0.98, 4.05, gate_z), bridge, Vector3(0, 0, side * 7.0))
		_part(Vector3(7.7, 0.46, 0.50), _stone_dark, Vector3(0, 4.55, gate_z), bridge)
	for side in [-1.0, 1.0]:
		for center_z in [-6.0, 6.0]:
			_cylinder(0.34, 3.25, _stone_dark, Vector3(side * 3.52, 2.12, center_z), bridge, Vector3.ZERO, 8)
			var lamp := _sphere(0.27, _ancient, Vector3(side * 3.52, 3.88, center_z), bridge, Vector3(0.75, 1.15, 0.75))
			lamp.scale = Vector3(0.75, 1.15, 0.75)
	# 两端引桥台阶：桥面比岸低 2~3m，用石阶从岸边接到桥面，步行与骑马都能上下。
	for end_sign in [-1.0, 1.0]:
		var out_world: Vector3 = bridge.transform * Vector3(0, 0, float(end_sign) * 29.0)
		var ground_y := terrain.get_height(out_world.x, out_world.z)
		var deck_top := bridge.position.y + 0.21
		var drop := ground_y - deck_top
		if drop > 0.35:
			var ramp_center := Vector3(0, (deck_top + ground_y) * 0.5 - bridge.position.y - 0.12, float(end_sign) * 26.0)
			_staircase(bridge, body, ramp_center, 7.2, 7.6, drop, 0.0 if end_sign > 0 else 180.0, _stone)


func _build_road(a: Vector3, b: Vector3, count: int) -> void:
	return  # 道路已改为地形顶点色绘制（Terrain.WILD_ROADS），保留函数以兼容旧调用


# 楼梯 = 一条可走碰撞斜坡 + 若干纯视觉踏面。胶囊体可靠滑上斜坡，踏面负责“楼梯感”。
func _staircase(parent: Node3D, body: StaticBody3D, center: Vector3, width: float, length: float, rise: float, yaw_deg: float, mat: Material = null, treads: int = 0) -> void:
	var material := mat if mat != null else _stone
	var pitch := rad_to_deg(atan2(rise, length))
	var ramp := _part(Vector3(width, 0.30, sqrt(length * length + rise * rise) + 0.35), material, center, parent)
	ramp.rotation_degrees = Vector3(-pitch, yaw_deg, 0)
	var ramp_col := CollisionShape3D.new()
	var ramp_shape := BoxShape3D.new()
	ramp_shape.size = Vector3(width, 0.30, sqrt(length * length + rise * rise) + 0.35)
	ramp_col.shape = ramp_shape
	ramp_col.position = center
	ramp_col.rotation_degrees = Vector3(-pitch, yaw_deg, 0)
	body.add_child(ramp_col)
	# 沿坡面逐级摆踏面条，纯视觉。
	var yaw_rad := deg_to_rad(yaw_deg)
	var up_dir := Vector3(sin(yaw_rad), 0, cos(yaw_rad))
	var tread_count := treads if treads > 0 else int(rise / 0.30)
	for i in range(tread_count):
		var t := (float(i) + 0.5) / float(tread_count)
		var tread_pos := center + up_dir * (lerpf(-length * 0.5, length * 0.5, t)) + Vector3(0, lerpf(-rise * 0.5, rise * 0.5, t) + 0.22, 0)
		var tread := _part(Vector3(width, 0.13, length / float(tread_count) * 0.72), material, tread_pos, parent)
		tread.rotation_degrees.y = yaw_deg


func _build_signposts() -> void:
	_signpost(Vector3(-18.5, 0, 21.5), 0.5)
	_signpost(Vector3(31.5, 0, 21.0), -2.6)
	_signpost(Vector3(-69.5, 0, 27.5), -0.9)
	_signpost(Vector3(13.5, 0, -75.5), 2.9)
	_signpost(Vector3(-102.5, 0, 79.5), 0.9)


func _signpost(p: Vector3, yaw: float) -> void:
	var post := Node3D.new()
	post.name = "Signpost"
	post.position = _ground(p)
	post.rotation.y = yaw
	add_child(post)
	var body := _body(post)
	_part(Vector3(0.17, 2.6, 0.17), _wood_dark, Vector3(0, 1.3, 0), post)
	_box_collision(body, Vector3(0.17, 2.6, 0.17), Vector3(0, 1.3, 0))
	var board_a := _part(Vector3(1.75, 0.34, 0.08), _wood, Vector3(0.62, 2.12, 0), post)
	board_a.rotation.y = 0.12
	_part(Vector3(0.34, 0.34, 0.08), _wood, Vector3(1.62, 2.12, 0), post, Vector3(0, 0, 45))
	var board_b := _part(Vector3(1.45, 0.30, 0.08), _wood, Vector3(-0.48, 1.68, 0), post)
	board_b.rotation.y = PI + 0.22
	_part(Vector3(0.30, 0.30, 0.08), _wood, Vector3(-1.32, 1.68, 0), post, Vector3(0, 0, 45))


func _build_paddock(center: Vector3) -> void:
	var paddock := Node3D.new()
	paddock.name = "StablePaddock"
	paddock.position = center
	paddock.rotation.y = -0.25
	add_child(paddock)
	var body := _body(paddock)
	# 围栏：16×10 的马场，南侧留 3m 门洞。
	const HALF_X := 8.0
	const HALF_Z := 5.0
	for i in range(9):
		var x := lerpf(-HALF_X, HALF_X, float(i) / 8.0)
		for z in [-HALF_Z, HALF_Z]:
			if z > 0.0 and absf(x) < 1.8:
				continue
			_part(Vector3(0.15, 1.15, 0.15), _wood_dark, Vector3(x, 0.57, z), paddock)
	for i in range(6):
		var z := lerpf(-HALF_Z, HALF_Z, float(i) / 5.0)
		for x in [-HALF_X, HALF_X]:
			_part(Vector3(0.15, 1.15, 0.15), _wood_dark, Vector3(x, 0.57, z), paddock)
	for rail_y in [0.55, 0.95]:
		_part(Vector3(HALF_X * 2.0, 0.09, 0.09), _wood, Vector3(0, rail_y, -HALF_Z), paddock)
		_part(Vector3(HALF_X * 0.72, 0.09, 0.09), _wood, Vector3(-HALF_X * 0.64, rail_y, HALF_Z), paddock)
		_part(Vector3(HALF_X * 0.72, 0.09, 0.09), _wood, Vector3(HALF_X * 0.64, rail_y, HALF_Z), paddock)
		_part(Vector3(0.09, 0.09, HALF_Z * 2.0), _wood, Vector3(-HALF_X, rail_y, 0), paddock)
		_part(Vector3(0.09, 0.09, HALF_Z * 2.0), _wood, Vector3(HALF_X, rail_y, 0), paddock)
	_box_collision(body, Vector3(HALF_X * 2.0, 1.0, 0.2), Vector3(0, 0.5, -HALF_Z))
	_box_collision(body, Vector3(0.2, 1.0, HALF_Z * 2.0), Vector3(-HALF_X, 0.5, 0))
	_box_collision(body, Vector3(0.2, 1.0, HALF_Z * 2.0), Vector3(HALF_X, 0.5, 0))
	# 干草垛与散草。
	var hay := Toon.make_material(Color(0.85, 0.70, 0.30), true, 0.012)
	for i in range(3):
		var bale := _cylinder(0.72, 1.25, hay, Vector3(-4.5 + i * 3.4, 0.72, -1.8 + float(i % 2) * 2.6), paddock, Vector3(0, 0, 90), 12)
		bale.rotation.y = float(i) * 0.7
	_sphere(0.9, hay, Vector3(4.2, 0.35, 2.2), paddock, Vector3(1.2, 0.45, 1.0))


func _build_wagon(p: Vector3, yaw: float) -> void:
	var wagon := Node3D.new()
	wagon.name = "Wagon"
	wagon.position = p
	wagon.rotation.y = yaw
	add_child(wagon)
	var body := _body(wagon)
	_part(Vector3(2.1, 0.28, 3.6), _wood, Vector3(0, 0.95, 0), wagon)
	_box_collision(body, Vector3(2.1, 0.9, 3.6), Vector3(0, 0.95, 0))
	for sx in [-1.0, 1.0]:
		_part(Vector3(0.12, 0.55, 3.6), _wood_dark, Vector3(sx * 1.0, 1.35, 0), wagon)
		_part(Vector3(0.10, 0.10, 2.6), _wood_dark, Vector3(sx * 0.55, 0.85, -2.9), wagon, Vector3(14, 0, 0))
		for z in [-1.15, 1.15]:
			_cylinder(0.68, 0.16, _wood_dark, Vector3(sx * 1.12, 0.68, z), wagon, Vector3(0, 0, 90), 12)
			_cylinder(0.16, 0.22, _wood, Vector3(sx * 1.12, 0.68, z), wagon, Vector3(0, 0, 90), 8)
	_part(Vector3(1.9, 0.5, 0.12), _wood_dark, Vector3(0, 1.35, 1.74), wagon)
	# 车上散放几只货箱与一卷布。
	_part(Vector3(0.7, 0.7, 0.7), _wood_dark, Vector3(-0.4, 1.45, 0.6), wagon, Vector3(0, 18, 0))
	_cylinder(0.35, 1.3, _cloth, Vector3(0.35, 1.35, -0.8), wagon, Vector3(90, 0, 0), 10)


func _build_road_lanterns() -> void:
	# 沿命名道路每 ~22m 放一盏石灯，只覆盖驿站与桥附近的几段。
	var cover := [
		[Vector2(-72, 21), Vector2(-15.5, 18)],
		[Vector2(-15.5, 18), Vector2(28.5, 18)],
		[Vector2(-105, 82), Vector2(-72, 26)],
		[Vector2(12, -78), Vector2(4, -112)],
	]
	var stone_lamp := Toon.make_material(Color(0.52, 0.55, 0.50), true, 0.012)
	for segment in cover:
		var a: Vector2 = segment[0]
		var b: Vector2 = segment[1]
		var length := a.distance_to(b)
		var count := int(length / 22.0)
		for i in range(1, count + 1):
			var t := float(i) / float(count + 1)
			var p2 := a.lerp(b, t)
			var dir := (b - a).normalized()
			var side := Vector2(-dir.y, dir.x) * (4.6 if i % 2 == 0 else -4.6)
			var p := Vector3(p2.x + side.x, 0, p2.y + side.y)
			p = _ground(p)
			if p.y < Terrain.WATER_LEVEL + 0.5:
				continue
			var lamp := Node3D.new()
			lamp.name = "RoadLantern"
			lamp.position = p
			add_child(lamp)
			_cylinder(0.16, 1.9, stone_lamp, Vector3(0, 0.95, 0), lamp, Vector3.ZERO, 8)
			_part(Vector3(0.5, 0.12, 0.5), stone_lamp, Vector3(0, 1.92, 0), lamp)
			_sphere(0.20, _ancient, Vector3(0, 2.18, 0), lamp, Vector3(0.8, 1.1, 0.8))
			_part(Vector3(0.62, 0.10, 0.62), stone_lamp, Vector3(0, 2.46, 0), lamp)


func _build_fallen_columns() -> void:
	# 通往遗迹的路上散落断裂立柱与柱头，提示这里曾经有建筑。
	var spots := [
		[Vector3(-2, 0, -58), 0.7, 3.6], [Vector3(6, 0, -66), -0.4, 4.4],
		[Vector3(-9, 0, -70), 1.9, 2.8], [Vector3(14, 0, -82), 2.6, 5.0],
		[Vector3(24, 0, -88), -1.1, 3.2],
	]
	for entry in spots:
		var p: Vector3 = entry[0]
		var yaw: float = entry[1]
		var length: float = entry[2]
		var ruin := Node3D.new()
		ruin.position = _ground(p, 0.35)
		ruin.rotation.y = yaw
		add_child(ruin)
		_cylinder(0.55, length, _stone, Vector3.ZERO, ruin, Vector3(0, 0, 90), 10)
		_part(Vector3(1.3, 0.5, 1.3), _stone_dark, Vector3(length * 0.5 + 0.4, 0, 0), ruin, Vector3(0, 0, 8))
		if yaw > 1.0:
			_part(Vector3(1.1, 0.9, 1.1), _stone, Vector3(-length * 0.5 - 0.5, -0.1, 0.4), ruin, Vector3(0, 24, 0))


var _butterflies: Array[Node3D] = []
var _butterfly_anchors: Array[Vector3] = []

# 竖向岩石尖峰群：打破草原的平坦轮廓，也可攀爬。
func _build_rock_spires() -> void:
	var spots := [
		[Vector3(58, 0, 52), 3.2, 12.0], [Vector3(71, 0, 47), 2.2, 8.5], [Vector3(92, 0, 44), 3.8, 15.0],
		[Vector3(-38, 0, 30), 2.4, 9.0], [Vector3(-22, 0, 44), 1.8, 6.5], [Vector3(36, 0, 12), 2.8, 10.5],
		[Vector3(-118, 0, 60), 3.0, 11.0], [Vector3(-95, 0, 45), 2.0, 7.5],
		[Vector3(24, 0, -52), 2.6, 9.5], [Vector3(-48, 0, -52), 3.4, 13.0],
		[Vector3(120, 0, 62), 3.0, 10.0], [Vector3(-160, 0, -40), 2.4, 8.0],
	]
	for entry in spots:
		var p: Vector3 = entry[0]
		var radius: float = entry[1]
		var height: float = entry[2]
		var spire := Node3D.new()
		spire.name = "RockSpire"
		spire.position = _ground(p, -0.3)
		spire.rotation.y = randf_range(0.0, TAU)
		add_child(spire)
		var body := _body(spire)
		_frustum(radius * 0.55, radius, height, _stone_dark, Vector3(0, height * 0.5, 0), spire, 9)
		_cylinder_collision(body, radius * 0.8, height, Vector3(0, height * 0.5, 0))
		_sphere(radius * 0.62, _stone, Vector3(0, height + radius * 0.15, 0), spire, Vector3(1.0, 0.55, 1.0))
		if radius > 2.6:
			_frustum(radius * 0.32, radius * 0.58, height * 0.55, _stone, Vector3(radius * 0.8, height * 0.26, 0), spire, 8)


func _spawn_butterflies() -> void:
	var wing_mat := StandardMaterial3D.new()
	wing_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	wing_mat.albedo_color = Color(1.0, 0.85, 0.30)
	var wing_mat2 := StandardMaterial3D.new()
	wing_mat2.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	wing_mat2.albedo_color = Color(0.95, 0.98, 1.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5150
	for i in range(12):
		var anchor := Vector3(rng.randf_range(-120, 100), 0, rng.randf_range(-60, 110))
		anchor = _ground(anchor, 1.2)
		if anchor.y < Terrain.WATER_LEVEL + 1.0:
			anchor.y = Terrain.WATER_LEVEL + 1.5
		var b := Node3D.new()
		b.position = anchor
		add_child(b)
		var mat := wing_mat if i % 3 != 0 else wing_mat2
		for sx in [-1.0, 1.0]:
			var wing := _part(Vector3(0.16, 0.015, 0.11), mat, Vector3(sx * 0.09, 0, 0), b)
			wing.name = "WingL" if sx < 0.0 else "WingR"
		_part(Vector3(0.035, 0.035, 0.12), _wood_dark, Vector3.ZERO, b)
		_butterflies.append(b)
		_butterfly_anchors.append(anchor)


func _build_ancient_tower(world_pos: Vector3, tower_height: float) -> void:
	var tower := Node3D.new()
	tower.name = "AncientSurveyTower"
	tower.position = world_pos
	add_child(tower)
	var body := _body(tower)
	# 阶梯石基、收分塔身、环形观景台和发光冠顶形成跨区域导航地标。
	for i in range(3):
		var radius := 3.9 - float(i) * 0.55
		_cylinder(radius, 0.42, _stone_dark if i == 0 else _stone, Vector3(0, 0.20 + i * 0.37, 0), tower, Vector3.ZERO, 12)
	_cylinder_collision(body, 3.8, 1.1, Vector3(0, 0.55, 0))
	_frustum(1.28, 1.85, tower_height, _stone_dark, Vector3(0, tower_height * 0.5 + 0.9, 0), tower, 12)
	_cylinder_collision(body, 1.65, tower_height, Vector3(0, tower_height * 0.5 + 0.9, 0))
	for ring_index in range(5):
		var ring_y := 3.1 + float(ring_index) * (tower_height - 3.2) / 4.0
		_cylinder(1.92 - float(ring_index) * 0.08, 0.20, _ancient, Vector3(0, ring_y, 0), tower, Vector3.ZERO, 12)
		for spoke_index in range(4):
			var angle := float(spoke_index) * PI * 0.5 + float(ring_index) * 0.35
			var brace := _part(Vector3(0.16, 2.7, 0.16), _wood_dark, Vector3(sin(angle) * 1.58, ring_y - 1.15, cos(angle) * 1.58), tower)
			brace.rotation.y = angle
			brace.rotation.z = 0.34 if spoke_index % 2 == 0 else -0.34
	var top_y := tower_height + 1.05
	_cylinder(4.25, 0.42, _stone_dark, Vector3(0, top_y, 0), tower, Vector3.ZERO, 16)
	_cylinder(3.72, 0.16, _path, Vector3(0, top_y + 0.29, 0), tower, Vector3.ZERO, 16)
	_cylinder_collision(body, 4.1, 0.62, Vector3(0, top_y + 0.18, 0))
	for i in range(8):
		var angle := float(i) * TAU / 8.0
		var post_pos := Vector3(sin(angle) * 3.55, top_y + 1.35, cos(angle) * 3.55)
		_part(Vector3(0.20, 2.45, 0.20), _stone_dark, post_pos, tower)
		var fin := _part(Vector3(0.22, 1.75, 0.18), _roof_trim, post_pos + Vector3(0, 1.85, 0), tower)
		fin.rotation.y = angle
		fin.rotation.z = sin(angle) * 0.18
	_cylinder(1.35, 0.30, _ancient, Vector3(0, top_y + 2.75, 0), tower, Vector3.ZERO, 14)
	var beacon := _sphere(0.62, _ancient, Vector3(0, top_y + 3.25, 0), tower, Vector3(1.0, 1.35, 1.0))
	beacon.scale = Vector3(1.0, 1.35, 1.0)
	var light := OmniLight3D.new()
	light.light_color = Color(0.05, 0.94, 0.85)
	light.light_energy = 1.7
	light.omni_range = 15.0
	light.position = Vector3(0, top_y + 3.0, 0)
	tower.add_child(light)
	# 外侧螺旋梯：从地面一路盘到顶部观景台。碰撞是连续分段斜坡，踏面提供楼梯视觉。
	var start_a := PI * 0.5
	var stair_start := 1.16
	var stair_end := top_y + 0.42
	var stair_count := int((stair_end - stair_start) / 0.32)
	var entry_center := Vector3(sin(start_a) * 4.6, 0.50, cos(start_a) * 4.6)
	_staircase(tower, body, entry_center, 1.7, 3.2, 1.16, rad_to_deg(start_a + PI), _stone, 4)
	var total_a := 1.6 * TAU
	for i in range(stair_count):
		var a := start_a + total_a * (float(i) + 0.5) / float(stair_count)
		var seg_rise := (stair_end - stair_start) / float(stair_count)
		var seg_len := 3.35 * (total_a / float(stair_count)) + 0.45
		var seg_center := Vector3(sin(a) * 3.35, lerpf(stair_start, stair_end, (float(i) + 0.5) / float(stair_count)) - 0.10, cos(a) * 3.35)
		_staircase(tower, body, seg_center, 1.6, seg_len, seg_rise, rad_to_deg(a + PI * 0.5), _stone, 1)


func _build_castle(world_pos: Vector3) -> void:
	var castle := Node3D.new()
	castle.name = "HyruleCastle"
	castle.position = world_pos
	castle.rotation.y = 0.12
	add_child(castle)
	var body := _body(castle)
	# 环形城墙与基座：远看是一条粗重的天际线底座。
	_part(Vector3(30, 2.4, 22), _stone_dark, Vector3(0, 1.0, 0), castle)
	_box_collision(body, Vector3(30, 2.4, 22), Vector3(0, 1.0, 0))
	for i in range(8):
		var t := float(i) / 7.0
		if absf(lerpf(-14.0, 14.0, t)) > 3.2:
			_part(Vector3(2.0, 3.4, 2.0), _stone, Vector3(lerpf(-14.0, 14.0, t), 3.2, -10.4), castle)
		_part(Vector3(2.0, 3.4, 2.0), _stone, Vector3(lerpf(-14.0, 14.0, t), 3.2, 10.4), castle)
	for i in range(5):
		var t := float(i) / 4.0
		_part(Vector3(2.0, 3.4, 2.0), _stone, Vector3(-14.4, 3.2, lerpf(-8.2, 8.2, t)), castle)
		_part(Vector3(2.0, 3.4, 2.0), _stone, Vector3(14.4, 3.2, lerpf(-8.2, 8.2, t)), castle)
	# 主堡：白色主体、蓝色大屋顶和高耸中央尖塔是旷野城堡的识别核心。
	_part(Vector3(11.5, 13.0, 10.0), _plaster, Vector3(0, 8.6, 1.0), castle)
	_box_collision(body, Vector3(11.5, 13.0, 10.0), Vector3(0, 8.6, 1.0))
	_part(Vector3(12.5, 0.9, 11.0), _stone_dark, Vector3(0, 15.4, 1.0), castle)
	_frustum(1.6, 8.2, 6.5, _castle_blue, Vector3(0, 19.0, 1.0), castle, 4)
	_part(Vector3(2.6, 12.5, 2.6), _plaster, Vector3(0, 27.0, 1.0), castle)
	_frustum(0.12, 1.9, 4.6, _castle_blue, Vector3(0, 35.5, 1.0), castle, 8)
	# 主堡立面细节：横向石带压边、成排窄窗（隔扇暖光），近看不再是素板。
	for wy in [6.2, 9.6, 13.0]:
		_part(Vector3(11.9, 0.32, 10.4), _stone_dark, Vector3(0, wy, 1.0), castle)
	for ix in range(4):
		for iy in range(3):
			var wx := -3.9 + ix * 2.6
			var wy2 := 7.4 + iy * 3.2
			var lit := (ix + iy) % 3 == 0
			_part(Vector3(0.55, 1.35, 0.18), _ancient if lit else _stone_dark, Vector3(wx, wy2, -4.06), castle)
	# 四座蓝色尖顶角塔拉开横向轮廓。
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var tx: float = float(sx) * 9.2
			var tz: float = 1.0 + float(sz) * 6.4
			_cylinder(2.1, 9.5, _plaster, Vector3(tx, 6.8, tz), castle, Vector3.ZERO, 10)
			_cylinder(2.45, 0.5, _stone_dark, Vector3(tx, 11.75, tz), castle, Vector3.ZERO, 10)
			_frustum(0.10, 2.3, 5.2, _castle_blue, Vector3(tx, 14.6, tz), castle, 10)
			# 角塔窄窗与中部环带，打破光塔素面。
			_cylinder(2.18, 0.3, _stone_dark, Vector3(tx, 8.0, tz), castle, Vector3.ZERO, 10)
			for wi in range(2):
				var wlit := (wi + int(sx + sz)) % 2 == 0
				var wpos := Vector3(tx + float(sx) * 2.12, 5.6 + wi * 2.6, tz)
				var win := _part(Vector3(0.18, 1.15, 0.48), _ancient if wlit else _stone_dark, wpos, castle)
				win.rotation.y = PI * 0.5
	# 正门、发光长窗与两侧旗帜。
	_part(Vector3(4.4, 5.6, 0.6), _stone_dark, Vector3(0, 4.2, -4.35), castle)
	_part(Vector3(3.0, 4.4, 0.3), _wood_dark, Vector3(0, 3.6, -4.55), castle)
	# 城墙门洞石拱与纹章：出入城堡的正式门面。
	for sx in [-1.0, 1.0]:
		_part(Vector3(1.25, 4.6, 1.25), _stone, Vector3(sx * 2.7, 3.1, -10.4), castle)
	_part(Vector3(6.6, 1.05, 1.45), _stone, Vector3(0, 5.85, -10.4), castle)
	_cylinder(0.85, 0.16, _castle_blue, Vector3(0, 7.05, -10.85), castle, Vector3(90, 0, 0), 12)
	_cylinder(0.45, 0.18, _ancient, Vector3(0, 7.05, -10.92), castle, Vector3(90, 0, 0), 12)
	# 大门前台阶：从地面穿过城墙门洞走上基座平台。
	_staircase(castle, body, Vector3(0, 1.0, -14.3), 5.2, 7.0, 2.2, 0.0, _stone, 7)
	for sx in [-1.0, 1.0]:
		for i in range(3):
			_part(Vector3(0.62, 2.2, 0.14), _ancient, Vector3(sx * 3.4, 7.0 + i * 3.4, -3.95), castle)
		_part(Vector3(0.12, 2.6, 1.35), _castle_blue, Vector3(sx * 5.9, 12.4, -4.15), castle)


func _build_river_life() -> void:
	var reed_mat := Toon.make_material(Color(0.40, 0.60, 0.17), false)
	var reed_mesh := BoxMesh.new()
	reed_mesh.size = Vector3(0.05, 1.15, 0.09)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = reed_mesh
	mm.instance_count = 260
	var rng := RandomNumberGenerator.new()
	rng.seed = 7321
	for i in range(mm.instance_count):
		var z := rng.randf_range(-210.0, 210.0)
		var river_x := sin(z * 0.021) * 24.0 - 8.0 + sin(z * 0.049) * 7.0
		var side := -1.0 if i % 2 == 0 else 1.0
		var x := river_x + side * rng.randf_range(10.0, 14.5)
		var y := terrain.get_height(x, z) + 0.55
		var basis := Basis(Vector3.UP, rng.randf_range(0, TAU)).scaled(Vector3.ONE * rng.randf_range(0.7, 1.25))
		mm.set_instance_transform(i, Transform3D(basis, Vector3(x, y, z)))
	var reeds := MultiMeshInstance3D.new()
	reeds.name = "RiverReeds"
	reeds.multimesh = mm
	reeds.material_override = reed_mat
	reeds.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(reeds)


func _build_volcano_caldera() -> void:
	var crater := Node3D.new()
	crater.name = "DeathMountainCaldera"
	crater.position = Vector3(164, terrain.get_height(164, -145) + 0.20, -145)
	add_child(crater)
	_cylinder(13.5, 0.24, _lava, Vector3.ZERO, crater, Vector3.ZERO, 28)
	_cylinder(8.2, 0.30, _fire, Vector3(0, 0.18, 0), crater, Vector3.ZERO, 24)
	for i in range(14):
		var angle := i * TAU / 14.0
		var rock := _sphere(1.4 + sin(i * 2.1) * 0.35, _stone_dark, Vector3(sin(angle) * 14.5, 0.8 + (i % 3) * 0.3, cos(angle) * 14.5), crater, Vector3(1.2, 0.8, 1.0))
		rock.rotation.y = angle
	var glow := OmniLight3D.new()
	glow.light_color = Color(1.0, 0.22, 0.04)
	glow.light_energy = 3.2
	glow.omni_range = 38.0
	glow.position.y = 3.0
	crater.add_child(glow)


func _spawn_campfires() -> void:
	var points := [Vector3(-67, 0, 16), Vector3(56, 0, 82), Vector3(137, 0, -112), Vector3(-156, 0, -80), Vector3(14, 0, -77)]
	for raw in points:
		_build_campfire(_ground(raw))


func _build_campfire(world_pos: Vector3) -> void:
	var camp := Node3D.new()
	camp.position = world_pos
	add_child(camp)
	_camp_positions.append(world_pos)
	for i in range(9):
		var angle := i * TAU / 9.0
		_sphere(0.24, _stone_dark, Vector3(sin(angle) * 0.72, 0.18, cos(angle) * 0.72), camp, Vector3(1.1, 0.75, 1.0))
	for i in range(3):
		var log := _cylinder(0.13, 1.35, _wood_dark, Vector3(0, 0.26, 0), camp, Vector3(90, 0, i * 60.0), 8)
		log.rotation.y = i * PI / 3.0
	var flame := _sphere(0.48, _fire, Vector3(0, 0.78, 0), camp, Vector3(0.65, 1.35, 0.65))
	_flames.append(flame)
	# 三脚架炊锅：每个火堆都是一处可以想象的“做饭点”。
	for i in range(3):
		var a := float(i) * TAU / 3.0
		var stick := _cylinder(0.045, 1.5, _wood_dark, Vector3(cos(a) * 0.42, 0.72, sin(a) * 0.42), camp, Vector3(0, 0, 0), 6)
		stick.rotation_degrees = Vector3(sin(a) * 22.0, 0, -cos(a) * 22.0)
	_cylinder(0.02, 0.35, _wood_dark, Vector3(0, 1.28, 0), camp, Vector3.ZERO, 6)
	_sphere(0.30, _stone_dark, Vector3(0, 1.02, 0), camp, Vector3(1.0, 0.82, 1.0))
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.48, 0.14)
	light.light_energy = 2.1
	light.omni_range = 9.0
	light.position = Vector3(0, 1.0, 0)
	camp.add_child(light)


func _spawn_mounts() -> void:
	var horse_points: Array[Vector3] = [Vector3(-84, 0, 8), Vector3(-59, 0, 10), Vector3(-88, 0, 30), Vector3(31, 0, 36)]
	var coats: Array[Color] = [Color(0.39, 0.17, 0.055), Color(0.16, 0.12, 0.095), Color(0.69, 0.56, 0.36), Color(0.34, 0.21, 0.12)]
	var lights: Array[Color] = [Color(0.60, 0.31, 0.10), Color(0.29, 0.24, 0.20), Color(0.82, 0.70, 0.48), Color(0.53, 0.34, 0.18)]
	var manes: Array[Color] = [Color(0.07, 0.04, 0.025), Color(0.035, 0.032, 0.030), Color(0.34, 0.25, 0.15), Color(0.06, 0.042, 0.03)]
	for i in range(horse_points.size()):
		var horse := Horse.new()
		horse.terrain = terrain
		horse.coat_color = coats[i]
		horse.coat_light_color = lights[i]
		horse.mane_color = manes[i]
		horse.marking_color = Color(0.92, 0.86, 0.72) if i != 1 else Color(0.48, 0.44, 0.38)
		horse.position = _ground(horse_points[i], 0.06)
		add_child(horse)
		horse.rotation.y = float(i) * 1.37 + 0.35
	var bike := WildMotorcycle.new()
	bike.terrain = terrain
	bike.position = _ground(Vector3(-103, 0, 78), 0.08)
	add_child(bike)
	bike.rotation.y = -0.3


func _spawn_mushrooms() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 22017
	for i in range(32):
		var p := Vector3(rng.randf_range(-190, 190), 0, rng.randf_range(-190, 190))
		p = _ground(p, 0.08)
		if p.y > Terrain.WATER_LEVEL + 0.8 and terrain.get_normal(p.x, p.z).y > 0.82:
			Loot.spawn(get_tree().current_scene, p, "mushroom", "", 1, 1)


func _spawn_monsters() -> void:
	var points := [Vector3(-42, 0, 48), Vector3(48, 0, 93), Vector3(118, 0, -74), Vector3(135, 0, -102), Vector3(-138, 0, -72), Vector3(-150, 0, -64), Vector3(45, 0, -70), Vector3(28, 0, -82)]
	_monster_points = points
	for p in points:
		var monster := WildMonster.new()
		monster.setup(terrain, player)
		monster.position = _ground(p, 0.05)
		add_child(monster)
		monster.rotation.y = randf_range(0, TAU)


# 血月苏醒：按原刷新点补齐已被击杀的怪物与动物（12m 内已有活口则跳过）。
func respawn_monsters() -> int:
	var respawned := 0
	for p in _monster_points:
		var occupied := false
		for e in get_tree().get_nodes_in_group("wild_enemy"):
			if not e.alive or not e.get_script() or e.get_script().resource_path.get_file().get_basename() != "wild_monster":
				continue
			if e.global_position.distance_to(_ground(p, 0.05)) < 12.0:
				occupied = true
				break
		if not occupied:
			var monster := WildMonster.new()
			monster.setup(terrain, player)
			monster.position = _ground(p, 0.05)
			add_child(monster)
			monster.rotation.y = randf_range(0, TAU)
			respawned += 1
	for entry in _animal_specs:
		var kind: String = entry[0]
		var p2: Vector3 = entry[1]
		var occupied2 := false
		for c in get_tree().get_nodes_in_group("wildlife"):
			if not c.alive or c.get("species") != kind:
				continue
			if c.global_position.distance_to(_ground(p2, 0.05)) < 12.0:
				occupied2 = true
				break
		if not occupied2:
			var creature := WildCreature.new()
			creature.setup(kind, terrain, player)
			var altitude := 8.0 if kind == "bird" else 0.05
			creature.position = _ground(p2, altitude)
			add_child(creature)
			creature.rotation.y = randf_range(0, TAU)
			respawned += 1
	# 莫布林/蜥蜴战士/古代守卫同样按刷新点补齐（同类判活，避免邻类抑制）。
	for mp in _moblin_points:
		if not _enemy_near(mp, 12.0, "wild_moblin"):
			var moblin := WildMoblin.new()
			moblin.setup(terrain, player)
			moblin.position = _ground(mp, 0.05)
			add_child(moblin)
			moblin.rotation.y = randf_range(0, TAU)
			respawned += 1
	for lp in _liz_points:
		if not _enemy_near(lp, 12.0, "wild_lizalfos"):
			var liz := WildLizalfos.new()
			liz.setup(terrain, player)
			liz.position = _ground(lp, 0.05)
			add_child(liz)
			liz.rotation.y = randf_range(0, TAU)
			respawned += 1
	for gp in _guardian_points:
		if not _enemy_near(gp, 14.0, "guardian"):
			var guardian := Guardian.new()
			guardian.setup(terrain, player)
			guardian.position = _ground(gp, 0.05)
			add_child(guardian)
			respawned += 1
	# Phase3 血月扩展占位：Stal/Keese/Wizzrobe/Chuchu/Hinox/Flyer/Dragon 各走 _enemy_near 分支，保证未来扩展可 headless 验证
	for cp in _chuchu_points:
		if not _enemy_near(cp, 12.0, "chuchu"):
			Chuchu.create(self, terrain, player, _ground(cp, 0.05))
			respawned += 1
	for kp in _keese_points:
		if not _enemy_near(kp, 12.0, "keese"):
			for i in range(3):
				var bat := Keese.new()
				bat.setup(terrain, player, _ground(kp, 6.0) + Vector3(randf_range(-3, 3), randf_range(0, 2), randf_range(-3, 3)))
				add_child(bat)
				respawned += 1
	for sp in _stal_points:
		if not _enemy_near(sp, 12.0, "stal"):
			Stal.create_body(self, terrain, player, _ground(sp, 0.05))
			respawned += 1
	for wp in _wizzrobe_points:
		if not _enemy_near(wp, 12.0, "wizzrobe"):
			Wizzrobe.create(self, terrain, player, _ground(wp, 1.5))
			respawned += 1
	for hp in _hinox_points:
		if not _enemy_near(hp, 14.0, "hinox"):
			Hinox.create(self, terrain, player, _ground(hp, 0.0))
			respawned += 1
	for fp in _flyer_points:
		if not _enemy_near(fp, 14.0, "flying_attacker"):
			var attacker := FlyingAttacker.new()
			attacker.setup(terrain, player)
			attacker.position = _ground(fp, 9.0)
			add_child(attacker)
			respawned += 1
	for dp in _dragon_points:
		if not _enemy_near(dp, 18.0, "wild_dragon"):
			# 巨龙单例；血月期间若被击败则单点补位
			var p := Vector3(164, terrain.get_height(164, -145) + 12.0, -145)
			var dragon := WildDragon.new()
			dragon.setup(player, p)
			dragon.position = p + Vector3(66, 42, 0)
			add_child(dragon)
			respawned += 1
	return respawned


func _enemy_near(p: Vector3, radius: float, type_filter: String = "") -> bool:
	var ground_p := _ground(p, 0.05)
	for e in get_tree().get_nodes_in_group("wild_enemy"):
		if not e.alive or e.global_position.distance_to(ground_p) >= radius:
			continue
		if type_filter != "" and e.get_script() and e.get_script().resource_path.get_file().get_basename() != type_filter:
			continue
		return true
	return false


# 河鱼与石头阵呀哈哈。
func _spawn_fish_and_circles() -> void:
	for i in range(6):
		var z := -120.0 + i * 48.0
		var x := sin(z * 0.021) * 24.0 - 8.0 + sin(z * 0.049) * 7.0
		var fish := FishSpot.new()
		fish.player = player
		fish.position = Vector3(x, Terrain.WATER_LEVEL - 0.5, z)
		add_child(fish)
	var circle_spots := [Vector3(-60, 0, 55), Vector3(95, 0, 15), Vector3(-20, 0, -88), Vector3(-135, 0, 35)]
	for i in range(circle_spots.size()):
		var circle := RockCircle.new()
		circle.configure(player, float(i) * 1.7 + 0.4)
		circle.position = _ground(circle_spots[i], 0.02)
		add_child(circle)
	# 两条花径呀哈哈。
	var trail1 := FlowerTrail.new()
	add_child(trail1)
	trail1.configure(player, [_ground(Vector3(-80, 0, 40), 0.5), _ground(Vector3(-70, 0, 45), 0.5), _ground(Vector3(-60, 0, 50), 0.5), _ground(Vector3(-50, 0, 55), 0.5), _ground(Vector3(-40, 0, 60), 0.5)])
	var trail2 := FlowerTrail.new()
	add_child(trail2)
	trail2.configure(player, [_ground(Vector3(90, 0, 60), 0.5), _ground(Vector3(100, 0, 65), 0.5), _ground(Vector3(110, 0, 70), 0.5)])
	# 两处跳水环呀哈哈。
	for rz in [-60.0, 70.0]:
		var rx := sin(rz * 0.021) * 24.0 - 8.0 + sin(rz * 0.049) * 7.0
		var ring := DiveRing.new()
		ring.configure(player)
		ring.position = Vector3(rx, Terrain.WATER_LEVEL + 0.02, rz)
		add_child(ring)


# 林克之家：高原上的小屋与床铺，睡到天亮回满状态。
func _build_home(world_pos: Vector3) -> void:
	var home := Node3D.new()
	home.name = "LinksHouse"
	home.position = world_pos
	home.rotation.y = 0.5
	add_child(home)
	var body := _body(home)
	# 石基、三面墙与正面开口。
	_part(Vector3(7.0, 0.4, 6.0), _stone_dark, Vector3(0, 0.2, 0), home)
	_box_collision(body, Vector3(7.0, 0.4, 6.0), Vector3(0, 0.2, 0))
	_part(Vector3(6.6, 2.6, 0.35), _plaster, Vector3(0, 1.5, 2.85), home)
	_part(Vector3(0.35, 2.6, 5.6), _plaster, Vector3(-3.15, 1.5, 0), home)
	_part(Vector3(0.35, 2.6, 5.6), _plaster, Vector3(3.15, 1.5, 0), home)
	_box_collision(body, Vector3(6.6, 2.6, 0.35), Vector3(0, 1.5, 2.85))
	_box_collision(body, Vector3(0.35, 2.6, 5.6), Vector3(-3.15, 1.5, 0))
	_box_collision(body, Vector3(0.35, 2.6, 5.6), Vector3(3.15, 1.5, 0))
	# 人字屋顶、屋脊与烟囱。
	for sx in [-1.0, 1.0]:
		_part(Vector3(4.0, 0.26, 6.6), _roof, Vector3(sx * 1.75, 3.55, 0), home, Vector3(0, 0, sx * 26.0))
	_part(Vector3(0.4, 0.4, 6.8), _wood_dark, Vector3(0, 4.35, 0), home)
	_part(Vector3(0.7, 1.8, 0.7), _stone_dark, Vector3(2.2, 4.2, 1.8), home)
	# 床铺、木桌、灯笼与小菜圃。
	_part(Vector3(2.2, 0.4, 1.2), _wood, Vector3(-1.9, 0.6, 1.9), home)
	_part(Vector3(2.0, 0.18, 1.0), _cloth, Vector3(-1.9, 0.88, 1.9), home)
	_part(Vector3(0.5, 0.22, 0.9), Toon.make_material(Color(0.95, 0.92, 0.82), true, 0.008), Vector3(-2.65, 0.92, 1.9), home)
	var bed := BedSpot.new()
	bed.add_to_group("bed")
	bed.position = home.transform * Vector3(-1.9, 0.9, 1.9)
	add_child(bed)
	_part(Vector3(1.4, 0.8, 0.9), _wood_dark, Vector3(1.8, 0.6, 2.2), home)
	var lantern := _sphere(0.20, _ancient, Vector3(0, 2.2, 1.2), home)
	lantern.scale = Vector3(0.7, 1.2, 0.7)
	for i in range(4):
		_part(Vector3(0.3, 0.25, 0.3), Toon.make_material(Color(0.35, 0.60, 0.20), true, 0.006), Vector3(-3.9 + float(i % 2) * 0.5, 0.15, -1.5 + float(i / 2) * 0.5), home)


# 呀哈哈式小谜题：三座风车 + 四块可疑怪石，打中即出种子。
func _spawn_korok_props() -> void:
	var pinwheels := [Vector3(-95, 0, 60), Vector3(40, 0, 55), Vector3(20, 0, -60)]
	var rocks := [Vector3(-120, 0, 45), Vector3(75, 0, 95), Vector3(-30, 0, -50), Vector3(150, 0, -60)]
	for p in pinwheels:
		var prop := KorokProp.new()
		prop.configure("pinwheel")
		prop.position = _ground(p, 0.02)
		add_child(prop)
	for p in rocks:
		var prop := KorokProp.new()
		prop.configure("rock")
		prop.position = _ground(p, 0.02)
		add_child(prop)


# 怪物营地：帐篷、火堆、木箱、尖桩围栏与守军，内有值钱补给。
func _build_monster_camp(p: Vector3, yaw: float) -> void:
	var camp := Node3D.new()
	camp.name = "MonsterCamp"
	camp.position = _ground(p)
	camp.rotation.y = yaw
	add_child(camp)
	var body := _body(camp)
	# 两座布帐篷。
	for sx in [-3.4, 3.4]:
		var tent := Node3D.new()
		tent.position = Vector3(sx, 0, -2.2)
		tent.rotation.y = sx * 0.2
		camp.add_child(tent)
		_frustum(0.06, 1.9, 2.4, _cloth, Vector3(0, 1.2, 0), tent, 6)
		_cylinder(0.05, 2.6, _wood_dark, Vector3(0, 1.3, 0), tent, Vector3.ZERO, 6)
		_box_collision(body, Vector3(2.8, 2.2, 2.8), tent.position)
	# 中央火堆与木箱堆。
	_build_campfire(camp.transform * Vector3(0, 0, 1.2))
	for i in range(3):
		_part(Vector3(0.8, 0.8, 0.8), _wood_dark, Vector3(1.8 + i * 0.9, 0.4, 2.8 - float(i % 2) * 0.7), camp, Vector3(0, float(i) * 12.0, 0))
	# 尖桩围栏（留入口）。
	for i in range(10):
		var a := float(i) * TAU / 10.0
		if i in [0, 1]:
			continue
		var post := _cylinder(0.09, 2.0, _wood_dark, Vector3(cos(a) * 6.0, 0.85, sin(a) * 6.0), camp, Vector3(0, 0, cos(a) * 24.0), 6)
		post.rotation_degrees.z = cos(a) * 24.0
		post.rotation_degrees.x = -sin(a) * 24.0
	# 守军与补给箱。
	for off in [Vector3(-1.5, 0, 0.5), Vector3(2.0, 0, -0.5)]:
		var monster := WildMonster.new()
		monster.setup(terrain, player)
		monster.position = camp.transform * off
		add_child(monster)
		monster.rotation.y = randf_range(0, TAU)
	Loot.spawn(get_tree().current_scene, camp.transform * Vector3(0.5, 0.3, 3.4), "armor", "", 50, 2)
	Loot.spawn(get_tree().current_scene, camp.transform * Vector3(-0.5, 0.3, 3.4), "ammo", "", 90, 2)


# 林地地面：倒木、蘑菇圈与蕨类丛，让森林从“树+草”变成有地面叙事的林子。
func _build_forest_floor() -> void:
	var bark := Toon.make_material(Color(0.35, 0.24, 0.13), true, 0.012)
	var moss := Toon.make_material(Color(0.30, 0.50, 0.16), true, 0.008)
	var rng := RandomNumberGenerator.new()
	rng.seed = 9021
	# 倒木：横躺的带苔树干，端口有年轮。
	for i in range(10):
		var p := Vector3(rng.randf_range(-140, 120), 0, rng.randf_range(-60, 120))
		p = _ground(p, 0.3)
		if p.y < Terrain.WATER_LEVEL + 0.6 or p.y > 18.0 or terrain.get_normal(p.x, p.z).y < 0.8:
			continue
		var log := Node3D.new()
		log.position = p
		log.rotation.y = rng.randf_range(0, TAU)
		add_child(log)
		var body := _body(log)
		var length := rng.randf_range(2.6, 4.5)
		_cylinder(rng.randf_range(0.24, 0.34), length, bark, Vector3(0, 0, 0), log, Vector3(0, 0, 90), 8)
		_cylinder_collision(body, 0.32, length, Vector3.ZERO, Vector3(0, 0, 90))
		_sphere(0.26, moss, Vector3(0, 0.24, 0), log, Vector3(1.4, 0.4, 0.9))
		var ring := _cylinder(0.20, 0.05, Toon.make_material(Color(0.62, 0.48, 0.28), true, 0.006), Vector3(length * 0.5, 0, 0), log, Vector3(0, 0, 90), 8)
		ring.rotation_degrees.z = 90.0
	# 蘑菇圈：一圈小蘑菇，中心微光，是“仙女环”式的林地彩蛋。
	for c in range(6):
		var center := Vector3(rng.randf_range(-120, 100), 0, rng.randf_range(-40, 100))
		center = _ground(center, 0.05)
		if center.y < Terrain.WATER_LEVEL + 0.6 or center.y > 16.0:
			continue
		var fairy := Node3D.new()
		fairy.position = center
		add_child(fairy)
		for i in range(9):
			var a := float(i) * TAU / 9.0
			var mp := Vector3(cos(a) * 1.5, 0, sin(a) * 1.5)
			_cylinder(0.05, 0.18, _cloth, mp + Vector3(0, 0.09, 0), fairy, Vector3.ZERO, 6)
			_sphere(0.13, _roof_trim, mp + Vector3(0, 0.22, 0), fairy, Vector3(1.0, 0.6, 1.0))
		var glow := _sphere(0.10, _ancient, Vector3(0, 0.15, 0), fairy, Vector3.ONE)
		glow.scale = Vector3.ONE * 0.8
	# 蕨类：三片交叉薄面一丛，MultiMesh 一次渲染。
	var fern_mesh := _make_fern_mesh()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = fern_mesh
	mm.instance_count = 320
	var fern_mat := Toon.make_material(Color(0.24, 0.46, 0.15), false)
	for i in range(mm.instance_count):
		var p2 := Vector3(rng.randf_range(-150, 130), 0, rng.randf_range(-90, 130))
		p2 = _ground(p2, 0.02)
		if p2.y < Terrain.WATER_LEVEL + 0.5 or p2.y > 17.0:
			p2.y = Terrain.WATER_LEVEL + 1.0
		var basis := Basis(Vector3.UP, rng.randf_range(0, TAU)).scaled(Vector3.ONE * rng.randf_range(0.7, 1.3))
		mm.set_instance_transform(i, Transform3D(basis, p2))
	var ferns := MultiMeshInstance3D.new()
	ferns.name = "Ferns"
	ferns.multimesh = mm
	ferns.material_override = fern_mat
	ferns.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ferns)


func _make_fern_mesh() -> ArrayMesh:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	for i in range(3):
		var a := float(i) * PI / 3.0
		var dir := Vector3(cos(a), 0, sin(a))
		var side := Vector3(-dir.z, 0, dir.x) * 0.45
		var base := Vector3.ZERO
		var tip := dir * 0.9 + Vector3(0, 0.55, 0)
		# 每片是一个弯曲感的三角叶片（两面可见）。
		verts.append_array([base - side * 0.15, base + side * 0.15, tip, base + side * 0.15, base - side * 0.15, tip])
		for j in range(6):
			normals.append(Vector3.UP)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


# 火山口外圈的玄武岩六棱柱群，高低错落。
func _build_volcano_basalt() -> void:
	var basalt := Toon.make_material(Color(0.16, 0.13, 0.12), true, 0.016)
	var rng := RandomNumberGenerator.new()
	rng.seed = 6604
	for i in range(16):
		var a := float(i) * TAU / 16.0 + rng.randf_range(-0.1, 0.1)
		var r := rng.randf_range(20.0, 30.0)
		var p := Vector3(164 + cos(a) * r, 0, -145 + sin(a) * r)
		p = _ground(p, -0.4)
		var height := rng.randf_range(2.5, 7.0)
		var col := Node3D.new()
		col.position = p
		col.rotation.y = a
		add_child(col)
		var body := _body(col)
		_frustum(rng.randf_range(0.5, 0.7), rng.randf_range(0.7, 0.9), height, basalt, Vector3(0, height * 0.5, 0), col, 6)
		_cylinder_collision(body, 0.7, height, Vector3(0, height * 0.5, 0))


# 雪线上的白顶岩石。
func _build_snow_rocks() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3317
	var snow_mat := Toon.make_material(Color(0.85, 0.90, 0.94), true, 0.010)
	for i in range(8):
		var p := Vector3(-166 + rng.randf_range(-45, 45), 0, -142 + rng.randf_range(-40, 45))
		p = _ground(p, 0.1)
		if p.y < 14.0:
			continue
		var rock := Node3D.new()
		rock.position = p
		rock.rotation.y = rng.randf_range(0, TAU)
		add_child(rock)
		var body := _body(rock)
		var r := rng.randf_range(0.9, 1.8)
		_sphere(r, _stone_dark, Vector3(0, r * 0.3, 0), rock, Vector3(1.0, 0.75, 0.9))
		_cylinder_collision(body, r * 0.85, r * 1.2, Vector3(0, r * 0.5, 0))
		_sphere(r * 0.85, snow_mat, Vector3(0, r * 0.72, 0), rock, Vector3(1.05, 0.32, 0.95))


func _spawn_animals() -> void:
	var specs := [
		["boar", Vector3(-34, 0, 72)], ["boar", Vector3(23, 0, 108)], ["boar", Vector3(87, 0, 12)], ["boar", Vector3(-121, 0, -38)], ["boar", Vector3(145, 0, 55)],
		["wolf", Vector3(-116, 0, -86)], ["wolf", Vector3(-128, 0, -96)], ["wolf", Vector3(104, 0, -47)], ["wolf", Vector3(112, 0, -55)],
		["bear", Vector3(-174, 0, -110)], ["bear", Vector3(176, 0, -28)],
		["bird", Vector3(-88, 0, 54)], ["bird", Vector3(-12, 0, 24)], ["bird", Vector3(74, 0, 96)], ["bird", Vector3(132, 0, 32)], ["bird", Vector3(-142, 0, -48)], ["bird", Vector3(42, 0, -114)], ["bird", Vector3(166, 0, -92)], ["bird", Vector3(-35, 0, -128)],
	]
	_animal_specs = specs
	for entry in specs:
		var kind: String = entry[0]
		var p: Vector3 = entry[1]
		var creature := WildCreature.new()
		creature.setup(kind, terrain, player)
		var altitude := 8.0 if kind == "bird" else 0.05
		creature.position = _ground(p, altitude)
		add_child(creature)
		creature.rotation.y = randf_range(0, TAU)


func _spawn_dragon() -> void:
	var p := Vector3(164, terrain.get_height(164, -145) + 12.0, -145)
	_dragon_points = [Vector3(230, 0, -145)]
	var dragon := WildDragon.new()
	dragon.setup(player, p)
	dragon.position = p + Vector3(66, 42, 0)
	add_child(dragon)


func _spawn_flying_attackers() -> void:
	_flyer_points = [Vector3(22, 0, -70), Vector3(116, 0, -80), Vector3(-128, 0, 70)]
	for p in _flyer_points:
		var attacker := FlyingAttacker.new()
		attacker.setup(terrain, player)
		attacker.position = _ground(p, 9.0)
		add_child(attacker)


# 地区性 3D 循环环境声：火山低鸣、雪原风吼，靠近地区时自然浮现。
func _build_region_ambience() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var volc := _make_region_loop("res://assets/sfx/volcano.wav", Vector3(164, terrain.get_height(164, -145) + 30.0, -145), -10.0, 80.0)
	add_child(volc)
	volc.play()
	var wind := _make_region_loop("res://assets/sfx/snowwind.wav", Vector3(-166, terrain.get_height(-166, -142) + 40.0, -142), -12.0, 110.0)
	add_child(wind)
	wind.play()
	tree_exiting.connect(func() -> void:
		for p in [volc, wind]:
			p.stop()
			p.stream = null
	)


func _make_region_loop(path: String, pos: Vector3, vol_db: float, unit: float) -> AudioStreamPlayer3D:
	var stream: AudioStreamWAV = load(path)
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = int(stream.get_length() * stream.mix_rate)
	var p := AudioStreamPlayer3D.new()
	p.bus = "Ambience"
	p.stream = stream
	p.volume_db = vol_db
	p.unit_size = unit
	p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	p.max_distance = unit * 2.2 # FIX: M10 地区声与 SFX 同模型(INVERSE)，此处 max=2.2*unit 为环境声宽场，SFX 为 90/18 已统一
	p.position = pos
	return p


func _spawn_npcs() -> void:
	var specs := [
		[Vector3(-70.5, 0, 24.5), "驿站老板", ["骑马过河小心深水，马匹不会游泳。", "北边海利亚大桥是过河的正道。", "山上的测绘塔能爬上去，顶上视野极好。"], Color(0.55, 0.35, 0.20), 0],
		[Vector3(103.0, 0, 27.0), "火山研究员", ["奥尔汀的巨龙其实怕射手步枪。", "这座神庙的符文我研究了三年。", "双子山谷的野猪脾气很差，绕开走。"], Color(0.25, 0.45, 0.55), 1],
		[Vector3(2.5, 0, -134.5), "城堡卫兵", ["城堡平台上有守军留下的装备。", "遗迹那边的断柱可以当掩体。", "滑翔伞从城墙一跃而下最省力。"], Color(0.35, 0.38, 0.50), 2],
		[Vector3(30.5, 0, 20.5), "旅行商人", ["桥两头的石阶是前人修的，别小看它们。", "河滩的芦苇荡里常有蘑菇。", "森林里的树砍倒有木材，木材能换护甲。"], Color(0.45, 0.55, 0.25), 0],
	]
	for i in range(specs.size()):
		var spec: Array = specs[i]
		var npc := WildNPC.new()
		var lines_value: Array[String] = []
		for line in spec[2]:
			lines_value.append(str(line))
		npc.setup(terrain, player, str(spec[1]), lines_value, spec[3], int(spec[4]))
		if i == 0:
			npc.quest_id = "mushroom3"
		elif i == 2:
			npc.quest_id = "moblin2"
		elif i == 1:
			npc.quest_id = "scale1"
		npc.position = _ground(spec[0], 0.02)
		add_child(npc)
		npc.rotation.y = randf_range(0.0, TAU)
	# 行商：沿道路在驿站与海利亚大桥之间往返（旷野之息式的流动商人）。
	var merchant := WildNPC.new()
	merchant.setup(terrain, player, "行商多戈", ["这条商路我走了十年，桥修好后好走多了。", "驿站收兽肉，蘑菇在河滩芦苇边最多。", "马上了路会自己认路，你尽管看风景。"], Color(0.60, 0.42, 0.20), 0)
	merchant.position = _ground(Vector3(-40, 0, 20), 0.02)
	merchant.quest_id = "escort"
	merchant.patrol = [Vector3(-70, 0, 21.5), Vector3(-40, 0, 20), Vector3(-15.5, 0, 18.5), Vector3(6, 0, 18), Vector3(-15.5, 0, 18.5), Vector3(-40, 0, 20)]
	add_child(merchant)


func _spawn_wild_loot() -> void:
	var scene := get_tree().current_scene
	# 武器：驿站步枪、遗迹冲锋枪、城堡射手步枪、一塔顶射手步枪（攀爬奖励）、二神庙冲锋枪。
	Loot.spawn(scene, _ground(Vector3(-73.5, 0, 17.5), 0.55), "weapon", "rifle", 0, 2)
	Loot.spawn(scene, _ground(Vector3(18, 0, -96), 0.6), "weapon", "smg", 0, 1)
	Loot.spawn(scene, _ground(Vector3(4, 0, -121), 32.35 - terrain.get_height(4, -121)), "weapon", "dmr", 0, 3)
	Loot.spawn(scene, _ground(Vector3(-132, 0, 109), 17.1), "weapon", "dmr", 0, 3)
	Loot.spawn(scene, _ground(Vector3(106, 0, 28), 0.6), "weapon", "smg", 0, 1)
	# 猎弓：遗迹门口与高原古树下各一把。
	Loot.spawn(scene, _ground(Vector3(16, 0, -92), 0.6), "weapon", "bow", 0, 2)
	Loot.spawn(scene, _ground(Vector3(-143, 0, 98), 0.6), "weapon", "bow", 0, 2)
	# 弹药：五处营地、驿站、城堡、桥头、二塔顶。
	for c in _camp_positions:
		Loot.spawn(scene, c + Vector3(1.2, 0.1, 0.6), "ammo", "", 45, 1)
	Loot.spawn(scene, _ground(Vector3(-70, 0, 18), 0.55), "ammo", "", 90, 2)
	Loot.spawn(scene, _ground(Vector3(2, 0, -126), 32.35 - terrain.get_height(2, -126)), "ammo", "", 90, 2)
	Loot.spawn(scene, _ground(Vector3(-14, 0, 21), 0.1), "ammo", "", 45, 1)
	Loot.spawn(scene, _ground(Vector3(72, 0, 116), 19.6), "ammo", "", 90, 2)
	# 医疗包与护甲：神庙、驿站、城堡、三塔顶。
	Loot.spawn(scene, _ground(Vector3(-110, 0, 89), 0.6), "medkit", "", 60, 1)
	Loot.spawn(scene, _ground(Vector3(104, 0, 23), 0.6), "medkit", "", 40, 1)
	Loot.spawn(scene, _ground(Vector3(-75, 0, 23), 0.55), "medkit", "", 40, 1)
	Loot.spawn(scene, _ground(Vector3(6, 0, -118), 32.35 - terrain.get_height(6, -118)), "medkit", "", 60, 1)
	Loot.spawn(scene, _ground(Vector3(5, 0, -123), 32.35 - terrain.get_height(5, -123)), "armor", "", 50, 2)
	Loot.spawn(scene, _ground(Vector3(-132, 0, -78), 18.6), "armor", "", 50, 2)
	Loot.spawn(scene, _ground(Vector3(20, 0, -91), 0.6), "armor", "", 25, 1)
	# 呀哈哈式探索种子：藏在峰顶、遗迹、雪线、火山口等“专门走过去”的位置。
	var seed_spots := [
		Vector3(63, 0, 72), Vector3(-140, 0, 120), Vector3(18, 0, -100), Vector3(-150, 0, -128),
		Vector3(150, 0, -132), Vector3(-50, 0, 62), Vector3(58, 0, 52), Vector3(-20, 0, 8),
		Vector3(105, 0, 40), Vector3(-95, 0, -30),
	]
	for spot in seed_spots:
		var p := _ground(spot, 0.5)
		if spot == Vector3(58, 0, 52):
			p.y += 12.4   # 岩石尖峰顶
		Loot.spawn(scene, p, "seed", "", 1, 3)
	# 两只可捕捉的小精灵：高原古树下与双子山谷深处。
	Loot.spawn(scene, _ground(Vector3(-142, 0, 96), 0.9), "fairy", "", 1, 3)
	Loot.spawn(scene, _ground(Vector3(82, 0, 66), 0.9), "fairy", "", 1, 3)
	# 古代剑：城堡平台最深处的奖励。
	Loot.spawn(scene, _ground(Vector3(4, 0, -120), 32.5 - terrain.get_height(4, -120)), "master_sword", "", 1, 3)


func get_region_name(pos: Vector3) -> String:
	return _region_name_impl(pos)


func is_near_campfire(pos: Vector3, radius: float = 4.0) -> bool:
	for p in _camp_positions:
		if pos.distance_to(p) < radius:
			return true
	return false


func _region_name_impl(pos: Vector3) -> String:
	if Vector2(pos.x, pos.z).distance_to(Vector2(4, -124)) < 42.0:
		return "海拉鲁城堡"
	if Vector2(pos.x, pos.z).distance_to(Vector2(164, -145)) < 80.0:
		return "奥尔汀火山"
	if Vector2(pos.x, pos.z).distance_to(Vector2(-166, -142)) < 90.0:
		return "海布拉雪山"
	if pos.z > 48.0 and pos.x < -42.0:
		return "初始高原"
	if pos.z > 40.0 and pos.x > 32.0:
		return "双子山谷"
	if pos.z < -60.0 and absf(pos.x) < 78.0:
		return "中央遗迹"
	if terrain.is_in_water(pos.x, pos.z):
		return "海利亚河"
	return "中央草原"


func _process(delta: float) -> void:
	_time += delta
	for i in range(_flames.size()):
		var flame := _flames[i]
		if is_instance_valid(flame):
			flame.scale = Vector3(0.58 + sin(_time * 8.0 + i) * 0.10, 1.2 + sin(_time * 11.0 + i * 2.1) * 0.18, 0.58 + cos(_time * 7.0 + i) * 0.08)
	if player and player.alive:
		for p in _camp_positions:
			if player.global_position.distance_to(p) < 3.2 and player.hp < player.max_hp:
				player.hp = minf(player.max_hp, player.hp + delta * 4.0)
				player.health_changed.emit(player.hp, player.armor)
	for i in range(_butterflies.size()):
		var b := _butterflies[i]
		if not is_instance_valid(b):
			continue
		var anchor := _butterfly_anchors[i]
		b.position = anchor + Vector3(sin(_time * 0.7 + i * 1.7) * 2.4, sin(_time * 1.9 + i * 2.3) * 0.5, cos(_time * 0.9 + i * 1.3) * 2.4)
		b.rotation.y = _time * 0.7 + float(i)
		var flap := sin(_time * 16.0 + float(i) * 2.0) * 0.85
		var wing_l := b.get_node_or_null("WingL") as MeshInstance3D
		var wing_r := b.get_node_or_null("WingR") as MeshInstance3D
		if wing_l:
			wing_l.rotation.z = flap
		if wing_r:
			wing_r.rotation.z = -flap
