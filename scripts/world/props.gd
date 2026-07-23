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
var _grass_shader_mat: ShaderMaterial
var _flower_instance: MultiMeshInstance3D
var _card_mesh: ArrayMesh
var _card_dirs: Array[Vector3] = []
var _broadleaf_transforms: Array[Transform3D] = []
var _broadleaf_colors: Array[Color] = []
var _pine_transforms: Array[Transform3D] = []
var _pine_colors: Array[Color] = []

const CANOPY_CARDS := 12


func generate(terrain: Terrain, rng_seed: int = 20260718) -> void:
	_rng.seed = rng_seed
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
	_build_card_mesh()
	_scatter_forest(terrain)
	_scatter(terrain, ROCK_COUNT, Callable(self, "_make_rock"), 0.70, 1.4)
	_scatter(terrain, BUSH_COUNT, Callable(self, "_make_bush"), 0.78, 1.35)
	_build_card_multimesh("BroadleafCards", _broadleaf_transforms, _broadleaf_colors, _canopy_shader_mat)
	_build_card_multimesh("PineCards", _pine_transforms, _pine_colors, _pine_shader_mat)
	_scatter_grass(terrain)
	_scatter_flowers(terrain)


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
	for card in cards:
		var pos: Vector3 = card["position"]
		var scale_value: float = card["scale"]
		var dir: Vector3 = card["direction"]
		var local := Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * scale_value), pos)
		var instance_transform := node.transform * local
		var world_dir := (node.transform.basis * dir).normalized()
		var light := clampf(world_dir.dot(_sun_dir_to()) * 0.5 + 0.5, 0.0, 1.0)
		if card["pine"]:
			_pine_transforms.append(instance_transform)
			_pine_colors.append(Color(light, light, light, 1.0))
		else:
			_broadleaf_transforms.append(instance_transform)
			_broadleaf_colors.append(Color(light, light, light, 1.0))
	node.remove_meta("leaf_cards")


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
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)


func _scatter_forest(terrain: Terrain) -> void:
	# 60% 树木聚成若干片林子，其余散生（旷野之息式的疏林草原）
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
			p.y = terrain.get_height(p.x, p.z)
		else:
			p = _rand_point(terrain)
		if not _usable(terrain, p, 0.86):
			continue
		_place(Callable(self, "_make_tree"), p, 1.0)
		placed += 1


func _rand_point(terrain: Terrain, margin: float = 0.88) -> Vector3:
	var x := _rng.randf_range(-Terrain.HALF * margin, Terrain.HALF * margin)
	var z := _rng.randf_range(-Terrain.HALF * margin, Terrain.HALF * margin)
	return Vector3(x, terrain.get_height(x, z), z)


func _usable(terrain: Terrain, p: Vector3, min_ny: float) -> bool:
	if p.y < Terrain.WATER_LEVEL + 0.8:
		return false
	# 树线：边缘高山（>18m 灰岩雪线）不长植被
	if p.y > 18.0:
		return false
	return terrain.get_normal(p.x, p.z).y > min_ny


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
	if _rng.randf() < 0.55:
		return _make_broadleaf()
	return _make_pine()


func _make_broadleaf() -> Node3D:
	var t := Node3D.new()
	t.name = "TreeBroadleaf"
	# 微弯的双段树干
	var trunk_mat := Toon.make_material(TRUNK_COLOR.lightened(0.10), true, 0.02)
	var lean := Vector3(_rng.randf_range(-0.3, 0.3), 0, _rng.randf_range(-0.3, 0.3))
	var t1 := MeshInstance3D.new()
	var c1 := CylinderMesh.new()
	c1.top_radius = 0.15
	c1.bottom_radius = 0.24
	c1.height = 1.5
	c1.radial_segments = 6
	t1.mesh = c1
	t1.material_override = trunk_mat
	t1.position.y = 0.75
	t.add_child(t1)
	var t2 := MeshInstance3D.new()
	var c2 := CylinderMesh.new()
	c2.top_radius = 0.08
	c2.bottom_radius = 0.15
	c2.height = 1.4
	c2.radial_segments = 6
	t2.mesh = c2
	t2.material_override = trunk_mat
	t2.position = Vector3(lean.x * 0.5, 2.0, lean.z * 0.5)
	t2.rotation = Vector3(lean.z * 0.3, 0, -lean.x * 0.3)
	t.add_child(t2)

	# 蓬松树冠：叶簇卡片球（不再是实心球）
	_queue_leaf_cards(t, Vector3(lean.x, 3.0, lean.z), 1.55)
	_queue_leaf_cards(t, Vector3(lean.x + 0.9, 2.4, lean.z + 0.3), 0.95)
	_queue_leaf_cards(t, Vector3(lean.x - 0.8, 2.5, lean.z - 0.4), 0.85)
	_add_trunk_collision(t, 0.35, 2.0)
	return t


func _make_pine() -> Node3D:
	var t := Node3D.new()
	t.name = "TreePine"
	var trunk := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.10
	cm.bottom_radius = 0.20
	cm.height = 1.9
	cm.radial_segments = 6
	trunk.mesh = cm
	trunk.material_override = Toon.make_material(TRUNK_COLOR, true, 0.02)
	trunk.position.y = 0.95
	t.add_child(trunk)

	# 针叶卡片塔：三层递减 + 塔尖
	_queue_leaf_cards(t, Vector3(0, 2.1, 0), 1.05, true)
	_queue_leaf_cards(t, Vector3(0, 3.0, 0), 0.80, true)
	_queue_leaf_cards(t, Vector3(0, 3.8, 0), 0.55, true)
	_queue_leaf_cards(t, Vector3(0, 4.4, 0), 0.32, true)
	_add_trunk_collision(t, 0.35, 1.6)
	return t


func _make_bush() -> Node3D:
	var b := Node3D.new()
	b.name = "Bush"
	_queue_leaf_cards(b, Vector3(0, 0.6, 0), 0.85)
	if _rng.randf() < 0.6:
		_queue_leaf_cards(b, Vector3(_rng.randf_range(-0.4, 0.4), 0.45, _rng.randf_range(-0.4, 0.4)), 0.55)
	return b


func _add_trunk_collision(t: Node3D, radius: float, height: float) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	var col := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = radius
	cyl.height = height
	col.shape = cyl
	col.position.y = height * 0.5
	body.add_child(col)
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
	mi.material_override = Toon.make_material(col_tint, true, 0.03)
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
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = tuft
	mm.instance_count = GRASS_COUNT
	var placed := 0
	var attempts := 0
	while placed < GRASS_COUNT and attempts < GRASS_COUNT * 8:
		attempts += 1
		var p := _rand_point(terrain, 0.90)
		if not _usable(terrain, p, 0.78):
			continue
		# 草丛成草甸分布：噪声低的区域留白，高的区域浓密
		if terrain.patch_noise.get_noise_2d(p.x, p.z) < -0.05:
			continue
		# 3 片交叉卡片各向同性，无需 Y 旋转；只保留倾斜与缩放
		var basis := Basis(Vector3.UP, _rng.randf_range(0.0, TAU))
		basis = basis.scaled(Vector3.ONE * _rng.randf_range(0.8, 1.35))
		mm.set_instance_transform(placed, Transform3D(basis, p))
		var tint := Color(1, 1, 1).lerp(Color(0.95, 1.0, 0.6), _rng.randf() * 0.6)
		mm.set_instance_color(placed, tint)
		placed += 1
	mm.instance_count = placed
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Grass"
	mmi.multimesh = mm
	mmi.material_override = _grass_shader_mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)


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
