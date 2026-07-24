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
var _path: StandardMaterial3D
var _ancient: StandardMaterial3D
var _fire: StandardMaterial3D
var _lava: StandardMaterial3D
var _flames: Array[MeshInstance3D] = []
var _camp_positions: Array[Vector3] = []
var _time := 0.0


func generate(p_terrain: Terrain, p_player: Player) -> void:
	terrain = p_terrain
	player = p_player
	_build_materials()
	_build_shrine(Vector3(-112, terrain.get_height(-112, 92), 92), 0.15)
	_build_shrine(_ground(Vector3(105, 0, 25)), -0.8)
	_build_stable(Vector3(-72, terrain.get_height(-72, 21), 21))
	_build_temple_ruins(Vector3(18, terrain.get_height(18, -94), -94))
	_build_river_bridge(18.0)
	_build_road(Vector3(-72, 0, 21), Vector3(-10, 0, 18), 28)
	_build_road(Vector3(-105, 0, 82), Vector3(-72, 0, 26), 22)
	_build_river_life()
	_build_volcano_caldera()
	_spawn_campfires()
	_spawn_mounts()
	_spawn_mushrooms()
	_spawn_monsters()
	_spawn_animals()
	_spawn_dragon()
	_spawn_flying_attackers()
	print("[wild] shrines=2 stable=1 monsters=8 wildlife=19 horses=4 dragon=1 flyers=3")


func _build_materials() -> void:
	_stone = Toon.make_material(Color(0.64, 0.65, 0.57), true, 0.018)
	_stone_dark = Toon.make_material(Color(0.29, 0.34, 0.34), true, 0.014)
	_wood = Toon.make_material(Color(0.48, 0.29, 0.13), true, 0.014)
	_wood_dark = Toon.make_material(Color(0.22, 0.13, 0.075), true, 0.012)
	_cloth = Toon.make_material(Color(0.84, 0.72, 0.43), true, 0.012)
	_roof = Toon.make_material(Color(0.44, 0.12, 0.075), true, 0.016)
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


func _build_shrine(world_pos: Vector3, yaw: float) -> void:
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
	# 十二边石室与椭圆穹顶取代方盒主体，远处也能辨认古代神庙轮廓。
	_cylinder(3.55, 4.5, _stone, Vector3(0, 2.9, 0.35), shrine, Vector3.ZERO, 12)
	_sphere(3.48, _stone, Vector3(0, 5.15, 0.35), shrine, Vector3(1.0, 0.46, 1.0))
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
	# 顶部同心圆盘和四根弯角用圆柱与斜梁组合。
	_cylinder(2.25, 0.28, _stone_dark, Vector3(0, 6.42, 0.3), shrine)
	_cylinder(1.72, 0.16, _ancient, Vector3(0, 6.59, 0.3), shrine)
	for i in range(8):
		var angle := i * TAU / 8.0
		var p := Vector3(sin(angle) * 2.4, 7.12, cos(angle) * 2.4 + 0.3)
		var fin := _part(Vector3(0.28, 1.65, 0.18), _stone_dark, p, shrine)
		fin.rotation.y = angle
		fin.rotation.z = sin(angle) * 0.24
	var light := OmniLight3D.new()
	light.light_color = Color(0.04, 0.95, 0.83)
	light.light_energy = 1.5
	light.omni_range = 13.0
	light.position = Vector3(0, 3.2, -2.7)
	shrine.add_child(light)


func _build_stable(world_pos: Vector3) -> void:
	var stable := Node3D.new()
	stable.name = "HighlandStable"
	stable.position = world_pos
	stable.rotation.y = -0.25
	add_child(stable)
	var body := _body(stable)
	# 厚石基、开放木架和巨大红布屋顶构成驿站标志轮廓。
	_part(Vector3(15.5, 0.35, 12.5), _stone_dark, Vector3(0, 0.02, 0), stable)
	_box_collision(body, Vector3(15.5, 0.35, 12.5), Vector3(0, 0.02, 0))
	for sx in [-6.6, -2.2, 2.2, 6.6]:
		for sz in [-4.8, 4.8]:
			_part(Vector3(0.34, 4.8, 0.34), _wood_dark, Vector3(sx, 2.4, sz), stable)
			_box_collision(body, Vector3(0.34, 4.8, 0.34), Vector3(sx, 2.4, sz))
	for sx in [-1.0, 1.0]:
		_part(Vector3(8.6, 0.30, 12.8), _roof, Vector3(sx * 3.55, 5.15, 0), stable, Vector3(0, 0, sx * 25.0))
	_part(Vector3(0.45, 0.45, 13.1), _wood_dark, Vector3(0, 6.95, 0), stable)
	# 旅店内核、柜台、马槽、灯笼和悬挂马头招牌。
	_part(Vector3(7.0, 2.8, 4.8), _cloth, Vector3(0, 1.55, 1.6), stable)
	_box_collision(body, Vector3(7.0, 2.8, 4.8), Vector3(0, 1.55, 1.6))
	_part(Vector3(6.4, 0.85, 0.75), _wood, Vector3(0, 0.62, -1.15), stable)
	for sx in [-5.3, 5.3]:
		_part(Vector3(2.1, 0.72, 0.85), _wood, Vector3(sx, 0.55, 2.5), stable)
		for i in range(3):
			_part(Vector3(0.12, 1.5, 0.12), _wood_dark, Vector3(sx - 0.8 + i * 0.8, 1.1, 4.15), stable)
	var sign := Node3D.new()
	sign.position = Vector3(0, 6.1, -6.1)
	stable.add_child(sign)
	_sphere(0.62, _cloth, Vector3.ZERO, sign, Vector3(1.0, 0.82, 1.0))
	_sphere(0.34, _wood, Vector3(0, 0.08, -0.55), sign, Vector3(0.85, 0.75, 1.2))
	for sx in [-1.0, 1.0]:
		_part(Vector3(0.16, 0.65, 0.12), _wood, Vector3(sx * 0.31, 0.55, -0.20), sign, Vector3(0, 0, sx * -18.0))
		var lantern := _sphere(0.22, _ancient, Vector3(sx * 5.8, 3.6, -4.7), stable)
		lantern.scale = Vector3(0.72, 1.25, 0.72)


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
	for i in range(5):
		var rubble := _part(Vector3(1.2 + i * 0.15, 0.65, 0.9), _stone, Vector3(-5 + i * 2.4, 0.28, -12 + sin(i) * 1.5), temple)
		rubble.rotation_degrees = Vector3(randf_range(-12, 12), randf_range(0, 180), randf_range(-10, 10))


func _build_river_bridge(z: float) -> void:
	var x := sin(z * 0.021) * 24.0 - 8.0 + sin(z * 0.049) * 7.0
	var bridge := Node3D.new()
	bridge.name = "HyliaBridge"
	bridge.position = Vector3(x, Terrain.WATER_LEVEL + 2.1, z)
	bridge.rotation.y = PI * 0.5
	add_child(bridge)
	var body := _body(bridge)
	for i in range(13):
		_part(Vector3(2.2, 0.18, 1.6), _wood, Vector3(0, 0, -9.6 + i * 1.6), bridge)
	_box_collision(body, Vector3(2.2, 0.22, 21.0), Vector3(0, 0, 0))
	for side in [-1.0, 1.0]:
		for i in range(6):
			_part(Vector3(0.16, 1.25, 0.16), _wood_dark, Vector3(side * 1.12, 0.55, -8.0 + i * 3.2), bridge)
		_part(Vector3(0.12, 0.12, 20.4), _wood_dark, Vector3(side * 1.12, 1.05, 0), bridge)


func _build_road(a: Vector3, b: Vector3, count: int) -> void:
	for i in range(count):
		var t := float(i) / maxf(1.0, count - 1.0)
		var p := a.lerp(b, t)
		p.y = terrain.get_height(p.x, p.z) + 0.035
		var tile := _part(Vector3(3.2, 0.07, 2.2), _path, p, self)
		tile.rotation.y = atan2(b.x - a.x, b.z - a.z)
		tile.scale.x = 0.85 + sin(i * 2.3) * 0.08


func _build_river_life() -> void:
	var reed_mat := Toon.make_material(Color(0.36, 0.57, 0.16), false)
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
		var x := river_x + side * rng.randf_range(7.2, 10.8)
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
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.48, 0.14)
	light.light_energy = 2.1
	light.omni_range = 9.0
	light.position = Vector3(0, 1.0, 0)
	camp.add_child(light)


func _spawn_mounts() -> void:
	var horse_points := [Vector3(-78, 0, 12), Vector3(-66, 0, 8), Vector3(-86, 0, 28), Vector3(31, 0, 36)]
	for p in horse_points:
		var horse := Horse.new()
		horse.terrain = terrain
		add_child(horse)
		horse.global_position = _ground(p, 0.08)
		horse.rotation.y = randf_range(0, TAU)
	var bike := WildMotorcycle.new()
	bike.terrain = terrain
	add_child(bike)
	bike.global_position = _ground(Vector3(-103, 0, 78), 0.08)
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
	for p in points:
		var monster := WildMonster.new()
		monster.setup(terrain, player)
		add_child(monster)
		monster.global_position = _ground(p, 0.05)
		monster.rotation.y = randf_range(0, TAU)


func _spawn_animals() -> void:
	var specs := [
		["boar", Vector3(-34, 0, 72)], ["boar", Vector3(23, 0, 108)], ["boar", Vector3(87, 0, 12)], ["boar", Vector3(-121, 0, -38)], ["boar", Vector3(145, 0, 55)],
		["wolf", Vector3(-116, 0, -86)], ["wolf", Vector3(-128, 0, -96)], ["wolf", Vector3(104, 0, -47)], ["wolf", Vector3(112, 0, -55)],
		["bear", Vector3(-174, 0, -110)], ["bear", Vector3(176, 0, -28)],
		["bird", Vector3(-88, 0, 54)], ["bird", Vector3(-12, 0, 24)], ["bird", Vector3(74, 0, 96)], ["bird", Vector3(132, 0, 32)], ["bird", Vector3(-142, 0, -48)], ["bird", Vector3(42, 0, -114)], ["bird", Vector3(166, 0, -92)], ["bird", Vector3(-35, 0, -128)],
	]
	for entry in specs:
		var kind: String = entry[0]
		var p: Vector3 = entry[1]
		var creature := WildCreature.new()
		creature.setup(kind, terrain, player)
		add_child(creature)
		var altitude := 8.0 if kind == "bird" else 0.05
		creature.global_position = _ground(p, altitude)
		creature.rotation.y = randf_range(0, TAU)


func _spawn_dragon() -> void:
	var p := Vector3(164, terrain.get_height(164, -145) + 12.0, -145)
	var dragon := WildDragon.new()
	dragon.setup(player, p)
	add_child(dragon)
	dragon.global_position = p + Vector3(66, 42, 0)


func _spawn_flying_attackers() -> void:
	for p in [Vector3(22, 0, -70), Vector3(116, 0, -80), Vector3(-128, 0, 70)]:
		var attacker := FlyingAttacker.new()
		attacker.setup(terrain, player)
		add_child(attacker)
		attacker.global_position = _ground(p, 9.0)


func get_region_name(pos: Vector3) -> String:
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
			if player.global_position.distance_to(p) < 3.2 and player.hp < Player.MAX_HP:
				player.hp = minf(Player.MAX_HP, player.hp + delta * 4.0)
				player.health_changed.emit(player.hp, player.armor)
