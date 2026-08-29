class_name Props
extends Node3D
## 风格化植被与岩石：程序化树木（阔叶/针叶）、噪声岩石、MultiMesh 草

const TREE_COUNT := 330
const ROCK_COUNT := 70
const GRASS_COUNT := 160000
const FLOWER_COUNT := 900
const BUSH_COUNT := 110

const TRUNK_COLOR := Color(0.42, 0.30, 0.19)
const ROCK_COLOR := Color(0.52, 0.55, 0.58)

var _rng := RandomNumberGenerator.new()
var _canopy_shader_mat: ShaderMaterial
var _pine_shader_mat: ShaderMaterial
var _pine_snow_shader_mat: ShaderMaterial
var _grass_shader_mat: ShaderMaterial
var _flower_instance: MultiMeshInstance3D
var _card_mesh: ArrayMesh
var _card_dirs: Array[Vector3] = []
var _broadleaf_transforms: Array[Transform3D] = []
var _broadleaf_colors: Array[Color] = []
var _pine_transforms: Array[Transform3D] = []
var _pine_snow_transforms: Array[Transform3D] = []
var _pine_snow_colors: Array[Color] = []
var _pine_colors: Array[Color] = []
var _broad_mm: MultiMesh
var _pine_mm: MultiMesh
var _pine_snow_mm: MultiMesh
var _terrain: Terrain
var _canopy_ranges: Dictionary = {}   # Tree node -> [broad_start, broad_count, pine_start, pine_count]

const CANOPY_CARDS := 16 # // FIX: R4-16 冠层透天缝收敛（原 12 卡近看剪纸球）


func generate(terrain: Terrain, rng_seed: int = 20260718) -> void:
	_rng.seed = rng_seed
	_terrain = terrain
	var t0 := Time.get_ticks_msec()
	# 阔叶树冠/灌木：程序化叶簇贴图 + 广告牌卡片 shader
	_canopy_shader_mat = ShaderMaterial.new()
	_canopy_shader_mat.shader = load("res://assets/shaders/canopy.gdshader")
	_canopy_shader_mat.set_shader_parameter("u_leaf", TexGen.leaf_cluster())
	# 松树专用：冷色针叶 ramp
	_pine_shader_mat = ShaderMaterial.new()
	_pine_shader_mat.shader = load("res://assets/shaders/canopy.gdshader")
	_pine_shader_mat.set_shader_parameter("u_leaf", TexGen.leaf_cluster(77))
	_pine_shader_mat.set_shader_parameter("color_shadow", Color(0.05, 0.16, 0.13))
	_pine_shader_mat.set_shader_parameter("color_mid", Color(0.12, 0.32, 0.24))
	_pine_shader_mat.set_shader_parameter("color_high", Color(0.24, 0.48, 0.30))
	# 雪挂松树专用：雪原高海拔卡片换浅蓝白配色，不受季节调色影响。
	_pine_snow_shader_mat = ShaderMaterial.new()
	_pine_snow_shader_mat.shader = load("res://assets/shaders/canopy.gdshader")
	_pine_snow_shader_mat.set_shader_parameter("u_leaf", TexGen.leaf_cluster(77))
	_pine_snow_shader_mat.set_shader_parameter("color_shadow", Color(0.50, 0.58, 0.62))
	_pine_snow_shader_mat.set_shader_parameter("color_mid", Color(0.68, 0.75, 0.79))
	_pine_snow_shader_mat.set_shader_parameter("color_high", Color(0.86, 0.91, 0.95))
	_build_card_mesh()
	_scatter_forest(terrain)
	print("[props_t] forest %dms" % (Time.get_ticks_msec() - t0))
	_scatter(terrain, ROCK_COUNT, Callable(self, "_make_rock"), 0.70, 1.4)
	_scatter(terrain, BUSH_COUNT, Callable(self, "_make_bush"), 0.78, 1.35)
	_build_card_multimesh("BroadleafCards", _broadleaf_transforms, _broadleaf_colors, _canopy_shader_mat)
	_build_card_multimesh("PineCards", _pine_transforms, _pine_colors, _pine_shader_mat)
	_build_card_multimesh("PineSnowCards", _pine_snow_transforms, _pine_snow_colors, _pine_snow_shader_mat)
	print("[props_t] rocks+bushes+cards +%dms" % (Time.get_ticks_msec() - t0))
	_scatter_grass(terrain)
	print("[props_t] grass +%dms" % (Time.get_ticks_msec() - t0))
	_scatter_flowers(terrain)
	print("[props_t] flowers +%dms" % (Time.get_ticks_msec() - t0))


# 指向太阳的方向（与 main.gd 主光一致：rotation -48°, -35°）
func _sun_dir_to() -> Vector3:
	return -(Basis.from_euler(Vector3(deg_to_rad(-48.0), deg_to_rad(-35.0), 0.0)) * Vector3(0, 0, -1))


# 斐波那契球面方向 + 所有树冠共享的一张四边形卡片
func _build_card_mesh() -> void:
	_card_dirs.clear()
	for i in range(CANOPY_CARDS):
		var y := 1.0 - (float(i) / (CANOPY_CARDS - 1)) * 2.0
		var r := sqrt(maxf(0.0, 1.0 - y * y))
		var th := 2.399963 * i
		var dir := Vector3(cos(th) * r, y, sin(th) * r).normalized()
		_card_dirs.append(dir)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([
		Vector3(-0.5, -0.5, 0), Vector3(0.5, -0.5, 0),
		Vector3(0.5, 0.5, 0), Vector3(-0.5, 0.5, 0)])
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([
		Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3])
	_card_mesh = ArrayMesh.new()
	_card_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)


# 树冠先记录局部实例，待整棵树随机旋转/缩放后一次写入 MultiMesh
func _queue_leaf_cards(parent: Node3D, center: Vector3, radius: float, pine: bool = false) -> void:
	var cards: Array = parent.get_meta("leaf_cards", [])
	for dir in _card_dirs:
		cards.append({
			"position": center + dir * radius * 0.45,
			"scale": radius * 1.15 * _rng.randf_range(0.85, 1.1),
			"direction": dir,
			"pine": pine,
		})
	parent.set_meta("leaf_cards", cards)


func _collect_leaf_cards(node: Node3D) -> void:
	if not node.has_meta("leaf_cards"):
		return
	var cards: Array = node.get_meta("leaf_cards")
	var broad_start := _broadleaf_transforms.size()
	var pine_start := _pine_transforms.size()
	var psnow_start := _pine_snow_transforms.size()
	var broad_count := 0
	var pine_count := 0
	var psnow_count := 0
	for card in cards:
		var pos: Vector3 = card["position"]
		var scale_value: float = card["scale"]
		var dir: Vector3 = card["direction"]
		var local := Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * scale_value), pos)
		var instance_transform := node.transform * local
		var world_dir := (node.transform.basis * dir).normalized()
		var light := clampf(world_dir.dot(_sun_dir_to()) * 0.5 + 0.5, 0.0, 1.0)
		if card["pine"]:
			# 逐卡片判定雪原权重：高海拔的冠层卡片挂雪，同棵树自然上白下绿。
			var wp: Vector3 = instance_transform.origin
			if _terrain != null and _terrain.snowland_factor(wp.x, wp.z, wp.y, 16.0, 34.0) > 0.35:
				_pine_snow_transforms.append(instance_transform)
				_pine_snow_colors.append(Color(light, light, light, 1.0))
				psnow_count += 1
			else:
				_pine_transforms.append(instance_transform)
				_pine_colors.append(Color(light, light, light, 1.0))
				pine_count += 1
		else:
			_broadleaf_transforms.append(instance_transform)
			_broadleaf_colors.append(Color(light, light, light, 1.0))
			broad_count += 1
	node.remove_meta("leaf_cards")
	if node.name.begins_with("Tree"):
		_canopy_ranges[node] = [broad_start, broad_count, pine_start, pine_count, psnow_start, psnow_count]


# 砍树：把该树的所有树冠卡片实例缩放至 0（MultiMesh 不重建，开销固定）。
func chop_canopy(node: Node3D) -> void:
	if not _canopy_ranges.has(node):
		return
	var r: Array = _canopy_ranges[node]
	var zero := Transform3D(Basis().scaled(Vector3.ZERO), Vector3.ZERO)
	for i in range(int(r[1])):
		_broad_mm.set_instance_transform(int(r[0]) + i, zero)
	for i in range(int(r[3])):
		_pine_mm.set_instance_transform(int(r[2]) + i, zero)
	if r.size() >= 6 and _pine_snow_mm != null:
		for i in range(int(r[5])):
			_pine_snow_mm.set_instance_transform(int(r[4]) + i, zero)


# 倒伏完成：原地留木桩，旁边掉一根可拾取的木材。
func finish_chop(node: Node3D) -> void:
	var stump := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.24
	mesh.bottom_radius = 0.30
	mesh.height = 0.5
	mesh.radial_segments = 7
	stump.mesh = mesh
	stump.material_override = Toon.make_material(TRUNK_COLOR.lightened(0.05), true, 0.02)
	stump.position = node.position + Vector3(0, 0.25, 0)
	add_child(stump)
	Loot.spawn(get_tree().current_scene, node.global_position + Vector3(0.7, 0.25, 0.3), "wood", "", 1, 1)


func _build_card_multimesh(name: String, transforms: Array[Transform3D], colors: Array[Color], mat: ShaderMaterial) -> void:
	if transforms.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = _card_mesh
	mm.instance_count = transforms.size()
	for i in range(transforms.size()):
		mm.set_instance_transform(i, transforms[i])
		mm.set_instance_color(i, colors[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = name
	mmi.multimesh = mm
	mmi.material_override = mat
	# // FIX: OPT-F5/TA6 冠层卡片开投影：森林地表有树影斑驳（草/花仍关闭，控影子预算）
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if "Cards" in name else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)
	if name == "BroadleafCards":
		_broad_mm = mm
	elif name == "PineSnowCards":
		_pine_snow_mm = mm
	else:
		_pine_mm = mm


func _scatter_forest(terrain: Terrain) -> void:
	# 60% 树木聚成若干片林子，其余散生（原创旷野式的疏林草原）
	var centers: Array[Vector3] = []
	for i in range(9):
		var c := _rand_point(terrain, 0.72)
		if _usable(terrain, c, 0.86):
			centers.append(c)
	var placed := 0
	var attempts := 0
	while placed < TREE_COUNT and attempts < TREE_COUNT * 25:
		attempts += 1
		var p: Vector3
		if placed < TREE_COUNT * 0.6 and not centers.is_empty():
			var c: Vector3 = centers[_rng.randi_range(0, centers.size() - 1)]
			var off := Vector3(_rng.randf_range(-1, 1), 0, _rng.randf_range(-1, 1)).normalized() * _rng.randf_range(4.0, 26.0)
			p = c + off
			p.y = terrain.get_height_baked(p.x, p.z)
		else:
			p = _rand_point(terrain)
		if not _usable(terrain, p, 0.86):
			continue
		_place(Callable(self, "_make_tree"), p, 1.0)
		placed += 1


func _rand_point(terrain: Terrain, margin: float = 0.88) -> Vector3:
	var x := _rng.randf_range(-Terrain.HALF * margin, Terrain.HALF * margin)
	var z := _rng.randf_range(-Terrain.HALF * margin, Terrain.HALF * margin)
	return Vector3(x, terrain.get_height_baked(x, z), z)


func _usable(terrain: Terrain, p: Vector3, min_ny: float) -> bool:
	if p.y < Terrain.WATER_LEVEL + 0.8:
		return false
	# 树线：高山带（>26m 灰岩雪线）不长植被；初始高原与丘陵都有树
	if p.y > 26.0:
		return false
	return terrain.get_normal_baked(p.x, p.z).y > min_ny


func _scatter(terrain: Terrain, count: int, factory: Callable, min_ny: float, max_scale: float) -> void:
	var placed := 0
	var attempts := 0
	while placed < count and attempts < count * 20:
		attempts += 1
		var p := _rand_point(terrain)
		if not _usable(terrain, p, min_ny):
			continue
		_place(factory, p, max_scale)
		placed += 1


func _place(factory: Callable, p: Vector3, max_scale: float) -> void:
	var node: Node3D = factory.call()
	node.position = p
	node.rotation.y = _rng.randf_range(0.0, TAU)
	var s := _rng.randf_range(0.75, max_scale)
	node.scale = Vector3(s, s * _rng.randf_range(0.9, 1.15), s)
	_collect_leaf_cards(node)
	if node.get_child_count() > 0:
		add_child(node)
	else:
		node.free()


# ---------- 树木 ----------

func _make_tree() -> Node3D:
	var roll := _rng.randf()
	if roll < 0.08:
		return _make_bigtree()
	if roll < 0.20:
		return _make_birch()
	if roll < 0.62:
		return _make_broadleaf()
	return _make_pine()


# 白桦：白色横纹细干 + 高处疏冠，林地里的颜色对比树种。
func _make_birch() -> Node3D:
	var t := Node3D.new()
	t.name = "TreeBirch"
	var bark := Toon.make_material(Color(0.88, 0.87, 0.82), true, 0.014)
	var band := Toon.make_material(Color(0.15, 0.14, 0.13), true, 0.006)
	var trunk := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.10
	cm.bottom_radius = 0.16
	cm.height = 4.6
	cm.radial_segments = 7
	trunk.mesh = cm
	trunk.material_override = bark
	trunk.position.y = 2.3
	t.add_child(trunk)
	for i in range(3):
		var ring := MeshInstance3D.new()
		var rm := CylinderMesh.new()
		rm.top_radius = 0.115
		rm.bottom_radius = 0.125
		rm.height = 0.09
		rm.radial_segments = 7
		ring.mesh = rm
		ring.material_override = band
		ring.position.y = 0.9 + float(i) * 1.15 + _rng.randf_range(-0.2, 0.2)
		t.add_child(ring)
	# 顶端一根斜枝与稀疏长冠。
	var branch := MeshInstance3D.new()
	var bm := CylinderMesh.new()
	bm.top_radius = 0.05
	bm.bottom_radius = 0.08
	bm.height = 1.4
	bm.radial_segments = 5
	branch.mesh = bm
	branch.material_override = bark
	branch.position = Vector3(0.4, 3.6, 0)
	branch.rotation.z = -0.6
	t.add_child(branch)
	_queue_leaf_cards(t, Vector3(0, 5.1, 0), _rng.randf_range(0.9, 1.2))
	_queue_leaf_cards(t, Vector3(0.9, 4.4, 0.3), _rng.randf_range(0.6, 0.85))
	_queue_leaf_cards(t, Vector3(-0.6, 4.5, -0.3), _rng.randf_range(0.55, 0.8))
	_add_trunk_collision(t, 0.28, 4.2)
	return t


func _make_broadleaf() -> Node3D:
	var t := Node3D.new()
	t.name = "TreeBroadleaf"
	# 微弯的双段树干：加高到 4m+，让“爬树”真的有高度。
	var trunk_mat := Toon.make_material(TRUNK_COLOR.lightened(0.10), true, 0.02)
	var lean := Vector3(_rng.randf_range(-0.3, 0.3), 0, _rng.randf_range(-0.3, 0.3))
	var t1 := MeshInstance3D.new()
	var c1 := CylinderMesh.new()
	c1.top_radius = 0.17
	c1.bottom_radius = 0.28
	c1.height = 2.6
	c1.radial_segments = 6
	t1.mesh = c1
	t1.material_override = trunk_mat
	t1.position.y = 1.3
	t.add_child(t1)
	var t2 := MeshInstance3D.new()
	var c2 := CylinderMesh.new()
	c2.top_radius = 0.09
	c2.bottom_radius = 0.17
	c2.height = 2.2
	c2.radial_segments = 6
	t2.mesh = c2
	t2.material_override = trunk_mat
	t2.position = Vector3(lean.x * 0.5, 3.4, lean.z * 0.5)
	t2.rotation = Vector3(lean.z * 0.3, 0, -lean.x * 0.3)
	t.add_child(t2)

	# 蓬松树冠：叶簇卡片球（不再是实心球），每棵树的位置/大小都带随机。
	_queue_leaf_cards(t, Vector3(lean.x, 5.0, lean.z), _rng.randf_range(1.7, 2.2))
	_queue_leaf_cards(t, Vector3(lean.x + _rng.randf_range(0.8, 1.4), 4.1 + _rng.randf_range(-0.2, 0.4), lean.z + _rng.randf_range(-0.5, 0.7)), _rng.randf_range(1.0, 1.4))
	_queue_leaf_cards(t, Vector3(lean.x - _rng.randf_range(0.8, 1.3), 4.2 + _rng.randf_range(-0.3, 0.3), lean.z - _rng.randf_range(0.3, 0.8)), _rng.randf_range(0.9, 1.3))
	# 一半概率长出一根侧枝，枝头带小叶簇，树形不再千篇一律。
	if _rng.randf() < 0.55:
		var branch_dir := _rng.randf_range(0.0, TAU)
		var branch := MeshInstance3D.new()
		var bm := CylinderMesh.new()
		bm.top_radius = 0.06
		bm.bottom_radius = 0.11
		bm.height = 1.9
		bm.radial_segments = 5
		branch.mesh = bm
		branch.material_override = trunk_mat
		branch.position = Vector3(cos(branch_dir) * 0.7, 3.0, sin(branch_dir) * 0.7)
		branch.rotation = Vector3(sin(branch_dir) * 0.9, 0, cos(branch_dir) * 0.9)
		t.add_child(branch)
		_queue_leaf_cards(t, Vector3(cos(branch_dir) * 1.5, 4.0, sin(branch_dir) * 1.5), _rng.randf_range(0.7, 1.0))
	_add_trunk_collision(t, 0.35, 3.4)
	return t


# 8% 概率生成大树：粗双段树干 + 五大簇树冠，是林子中的锚点。
func _make_bigtree() -> Node3D:
	var t := Node3D.new()
	t.name = "TreeBig"
	var trunk_mat := Toon.make_material(TRUNK_COLOR.darkened(0.08), true, 0.018) # // FIX: OPT-F7/TA10 道具规范宽
	var t1 := MeshInstance3D.new()
	var c1 := CylinderMesh.new()
	c1.top_radius = 0.42
	c1.bottom_radius = 0.62
	c1.height = 3.6
	c1.radial_segments = 8
	t1.mesh = c1
	t1.material_override = trunk_mat
	t1.position.y = 1.8
	t.add_child(t1)
	var t2 := MeshInstance3D.new()
	var c2 := CylinderMesh.new()
	c2.top_radius = 0.26
	c2.bottom_radius = 0.42
	c2.height = 3.0
	c2.radial_segments = 8
	t2.mesh = c2
	t2.material_override = trunk_mat
	t2.position.y = 4.9
	t.add_child(t2)
	# 根部膨大与两根高枝。
	for i in range(3):
		var a := float(i) * TAU / 3.0 + _rng.randf_range(-0.3, 0.3)
		var root := MeshInstance3D.new()
		var rm := CylinderMesh.new()
		rm.top_radius = 0.14
		rm.bottom_radius = 0.30
		rm.height = 1.2
		rm.radial_segments = 6
		root.mesh = rm
		root.material_override = trunk_mat
		root.position = Vector3(cos(a) * 0.55, 0.45, sin(a) * 0.55)
		root.rotation = Vector3(sin(a) * 0.5, 0, -cos(a) * 0.5)
		t.add_child(root)
	_queue_leaf_cards(t, Vector3(0, 7.2, 0), _rng.randf_range(2.2, 2.7))
	_queue_leaf_cards(t, Vector3(2.1, 6.0, 0.8), _rng.randf_range(1.6, 2.1))
	_queue_leaf_cards(t, Vector3(-2.0, 6.1, -0.7), _rng.randf_range(1.6, 2.1))
	_queue_leaf_cards(t, Vector3(0.6, 5.6, -1.9), _rng.randf_range(1.4, 1.9))
	_queue_leaf_cards(t, Vector3(-0.7, 5.7, 2.0), _rng.randf_range(1.4, 1.9))
	_add_trunk_collision(t, 0.62, 6.0)
	return t


func _make_pine() -> Node3D:
	var t := Node3D.new()
	t.name = "TreePine"
	var trunk := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.12
	cm.bottom_radius = 0.24
	cm.height = 3.2
	cm.radial_segments = 6
	trunk.mesh = cm
	trunk.material_override = Toon.make_material(TRUNK_COLOR, true, 0.02)
	trunk.position.y = 1.6
	t.add_child(trunk)

	# 针叶卡片塔：三层递减 + 塔尖
	_queue_leaf_cards(t, Vector3(0, 3.3, 0), 1.30, true)
	_queue_leaf_cards(t, Vector3(0, 4.5, 0), 1.00, true)
	_queue_leaf_cards(t, Vector3(0, 5.6, 0), 0.70, true)
	_queue_leaf_cards(t, Vector3(0, 6.5, 0), 0.40, true)
	_add_trunk_collision(t, 0.35, 3.2)
	return t


func _make_bush() -> Node3D:
	var b := Node3D.new()
	b.name = "Bush"
	_queue_leaf_cards(b, Vector3(0, 0.6, 0), 0.85)
	if _rng.randf() < 0.6:
		_queue_leaf_cards(b, Vector3(_rng.randf_range(-0.4, 0.4), 0.45, _rng.randf_range(-0.4, 0.4)), 0.55)
	return b


func _add_trunk_collision(t: Node3D, radius: float, height: float) -> void:
	# 树干碰撞体 = 可砍伐组件：射击/攻击树干两次即可砍倒这棵树。
	var body := ChoppableTree.new()
	body.configure(t, self, radius, height)
	t.add_child(body)


# ---------- 岩石 ----------

func _make_rock() -> Node3D:
	var t := Node3D.new()
	t.name = "Rock"
	var base := SphereMesh.new()
	base.radius = 1.0
	base.height = 1.6
	base.radial_segments = 7
	base.rings = 4
	var arrays: Array = base.get_mesh_arrays()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var rock_noise := FastNoiseLite.new()
	rock_noise.seed = _rng.randi()
	rock_noise.frequency = 1.2
	for i in range(verts.size()):
		var v := verts[i]
		var d := 1.0 + rock_noise.get_noise_3d(v.x, v.y, v.z) * 0.35
		verts[i] = v * d
	arrays[Mesh.ARRAY_VERTEX] = verts
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var col_tint := ROCK_COLOR.lerp(Color(0.62, 0.58, 0.50), _rng.randf() * 0.5)
	mi.material_override = Toon.make_material(col_tint, true, 0.02) # // FIX: OPT-F7/TA10 岩石描边 0.03→0.02
	mi.position.y = 0.35
	t.add_child(mi)

	var body := StaticBody3D.new()
	body.collision_layer = 1
	var col := CollisionShape3D.new()
	col.shape = mesh.create_trimesh_shape()
	col.position.y = 0.35
	body.add_child(col)
	t.add_child(body)
	return t


# ---------- 草（MultiMesh + 风摆着色器） ----------

func _scatter_grass(terrain: Terrain) -> void:
	var tuft := _make_blade_mesh()
	_grass_shader_mat = ShaderMaterial.new()
	_grass_shader_mat.shader = load("res://assets/shaders/grass.gdshader")
	_grass_shader_mat.set_shader_parameter("u_blade", TexGen.grass_blades())
	# // FIX: OPT-F6b/TA7 草分块：50m 网格桶装，每块独立 MultiMeshInstance + visibility_range 60m 淡出
	# （单节点 MultiMesh 的 visibility_range 是整节点级，必须分块才能做距离淡出）
	var _chunk := 50.0
	var _chunks: Dictionary = {} # Vector2i -> PackedVector3Array（可长草点）
	# 预筛可长草网格：坡度/树线/水线/草甸噪声一次过，之后只从合格点抽样，不再大规模拒绝采样。
	var spots: Array[Vector3] = []
	var step := 2.0
	var half := Terrain.HALF * 0.90
	var gx := -half
	while gx < half:
		var gz := -half
		while gz < half:
			var px := gx + _rng.randf_range(0.0, step)
			var pz := gz + _rng.randf_range(0.0, step)
			var py := terrain.get_height_baked(px, pz)
			gz += step
			if py < Terrain.WATER_LEVEL + 1.3 or py > 26.0:
				continue
			# // FIX: R4-H6b 草过滤与地面干斑同源同向（原 < -0.05 与地面 >0.30 干斑方向相反，错位加深色斑感）
			if terrain.get_patch_baked(px, pz) > 0.30:
				continue
			if terrain.get_normal_baked(px, pz).y <= 0.78:
				continue
			# // FIX: OPT-F6/TA7 路面 4.2m 与沙滩带内不种草（原草长在路中央/河滩）
			if terrain.is_near_road(px, pz):
				continue
			var key := Vector2i(int(floor(px / _chunk)), int(floor(pz / _chunk)))
			if not _chunks.has(key):
				_chunks[key] = PackedVector3Array()
			_chunks[key].append(Vector3(px, py, pz))
		gx += step
	# 每块限量采样（总量不超 GRASS_COUNT），独立 MultiMesh + 距离淡出
	var per_chunk_budget: int = maxi(64, GRASS_COUNT / maxi(1, _chunks.size()))
	var placed := 0
	for key in _chunks.keys():
		var pts: PackedVector3Array = _chunks[key]
		var chunk_origin := Vector3(key.x * _chunk, 0, key.y * _chunk) # // FIX: 声明前移到实例变换之前
		var cmm := MultiMesh.new()
		cmm.transform_format = MultiMesh.TRANSFORM_3D
		cmm.use_colors = true
		cmm.mesh = tuft
		var n := mini(per_chunk_budget, pts.size() * 8) # 块内可重复抽样，保持原密度
		cmm.instance_count = n
		for i in range(n):
			var p: Vector3 = pts[_rng.randi_range(0, pts.size() - 1)]
			var basis := Basis(Vector3.UP, _rng.randf_range(0.0, TAU))
			basis = basis.scaled(Vector3.ONE * _rng.randf_range(0.8, 1.35))
			# // FIX: 实例变换用块内局部坐标（节点在 chunk_origin，世界坐标会被二次偏移飘上天）
			cmm.set_instance_transform(i, Transform3D(basis, p - chunk_origin))
			var tint := Color(1, 1, 1).lerp(Color(0.95, 1.0, 0.6), _rng.randf() * 0.6)
			cmm.set_instance_color(i, tint)
		var cmi := MultiMeshInstance3D.new()
		cmi.name = "Grass_%d_%d" % [key.x, key.y]
		cmi.multimesh = cmm
		cmi.material_override = _grass_shader_mat
		cmi.position = chunk_origin
		cmi.visibility_range_end = 60.0
		cmi.visibility_range_end_margin = 12.0 # // FIX: R3-TA3 硬切→渐隐带（原 60m 圆周瞬时消失）
		cmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		cmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(cmi)
		placed += n
	print("[props] grass chunks=%d placed=%d" % [_chunks.size(), placed])


func _scatter_flowers(terrain: Terrain) -> void:
	# 点缀花丛：交叉卡片，白/黄/粉
	var card := _make_flower_mesh()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = card
	mm.instance_count = FLOWER_COUNT
	var petals := [Color(1.0, 1.0, 0.95), Color(1.0, 0.9, 0.3), Color(1.0, 0.6, 0.7), Color(0.8, 0.6, 1.0)]
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = TexGen.flower()
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	mat.alpha_scissor_threshold = 0.5
	mat.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	mat.specular_mode = BaseMaterial3D.SPECULAR_TOON
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var placed := 0
	var attempts := 0
	while placed < FLOWER_COUNT and attempts < FLOWER_COUNT * 10:
		attempts += 1
		var p := _rand_point(terrain, 0.85)
		if not _usable(terrain, p, 0.80):
			continue
		if terrain.profile == "wild" and terrain.flower_region_factor(p.x, p.z, p.y) > 0.2:
			continue
		var basis := Basis(Vector3.UP, _rng.randf_range(0.0, TAU))
		basis = basis.scaled(Vector3.ONE * _rng.randf_range(0.5, 0.8))
		mm.set_instance_transform(placed, Transform3D(basis, p))
		mm.set_instance_color(placed, petals[_rng.randi_range(0, petals.size() - 1)])
		placed += 1
	mm.instance_count = placed
	_flower_instance = MultiMeshInstance3D.new()
	_flower_instance.name = "Flowers"
	_flower_instance.multimesh = mm
	_flower_instance.material_override = mat
	_flower_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_flower_instance)


func set_season_palette(grass_shadow: Color, grass_dark: Color, grass_light: Color, leaf_shadow: Color, leaf_mid: Color, leaf_high: Color, pine_shadow: Color, pine_mid: Color, pine_high: Color, flowers_visible: bool) -> void:
	if _grass_shader_mat:
		_grass_shader_mat.set_shader_parameter("color_shadow", grass_shadow)
		_grass_shader_mat.set_shader_parameter("color_dark", grass_dark)
		_grass_shader_mat.set_shader_parameter("color_light", grass_light)
	if _canopy_shader_mat:
		_canopy_shader_mat.set_shader_parameter("color_shadow", leaf_shadow)
		_canopy_shader_mat.set_shader_parameter("color_mid", leaf_mid)
		_canopy_shader_mat.set_shader_parameter("color_high", leaf_high)
	if _pine_shader_mat:
		_pine_shader_mat.set_shader_parameter("color_shadow", pine_shadow)
		_pine_shader_mat.set_shader_parameter("color_mid", pine_mid)
		_pine_shader_mat.set_shader_parameter("color_high", pine_high)
	if _flower_instance:
		_flower_instance.visible = flowers_visible


func _make_blade_mesh() -> ArrayMesh:
	# 草丛卡片：3 片互成 60° 的面片，贴多叶片贴图，UV.y 顶部为 1（风摆/色带权重）
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var w := 0.38
	var h := 0.55
	for q in range(3):
		var ang := q * PI / 3.0
		var dir := Vector3(cos(ang), 0, sin(ang)) * w
		var b := verts.size()
		verts.append(-dir)
		verts.append(dir)
		verts.append(dir + Vector3(0, h, 0))
		verts.append(-dir + Vector3(0, h, 0))
		uvs.append(Vector2(0, 0))
		uvs.append(Vector2(1, 0))
		uvs.append(Vector2(1, 1))
		uvs.append(Vector2(0, 1))
		indices.append_array([b, b + 1, b + 2, b, b + 2, b + 3])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _make_flower_mesh() -> ArrayMesh:
	# 两片交叉方卡片，UV.y 顶部为 1
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var w := 0.22
	var h := 0.5
	for q in range(2):
		var ang := q * PI * 0.5
		var dir := Vector3(cos(ang), 0, sin(ang)) * w
		var b := verts.size()
		verts.append(-dir)
		verts.append(dir)
		verts.append(dir + Vector3(0, h, 0))
		verts.append(-dir + Vector3(0, h, 0))
		uvs.append(Vector2(0, 0))
		uvs.append(Vector2(1, 0))
		uvs.append(Vector2(1, 1))
		uvs.append(Vector2(0, 1))
		indices.append_array([b, b + 1, b + 2, b, b + 2, b + 3])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
