class_name Props
extends Node3D
## 风格化植被与岩石：程序化树木（阔叶/针叶）、噪声岩石、MultiMesh 草

const TREE_COUNT := 330
const ROCK_COUNT := 70
const GRASS_COUNT := 22000
const FLOWER_COUNT := 600

const TRUNK_COLOR := Color(0.42, 0.30, 0.19)
const LEAF_A := Color(0.38, 0.62, 0.20)
const LEAF_B := Color(0.58, 0.78, 0.26)
const LEAF_TEAL := Color(0.22, 0.55, 0.42)
const PINE_A := Color(0.15, 0.44, 0.38)
const PINE_B := Color(0.28, 0.58, 0.36)
const ROCK_COLOR := Color(0.52, 0.55, 0.58)

var _rng := RandomNumberGenerator.new()


func generate(terrain: Terrain, rng_seed: int = 20260718) -> void:
	_rng.seed = rng_seed
	_scatter_forest(terrain)
	_scatter(terrain, ROCK_COUNT, Callable(self, "_make_rock"), 0.70, 1.4)
	_scatter_grass(terrain)
	_scatter_flowers(terrain)


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
	add_child(node)


# ---------- 树木 ----------

func _make_tree() -> Node3D:
	if _rng.randf() < 0.55:
		return _make_broadleaf()
	return _make_pine()


func _make_broadleaf() -> Node3D:
	var t := Node3D.new()
	t.name = "TreeBroadleaf"
	var trunk := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.12
	cm.bottom_radius = 0.24
	cm.height = 2.0
	cm.radial_segments = 6
	trunk.mesh = cm
	trunk.material_override = Toon.make_material(TRUNK_COLOR.lightened(0.12), true, 0.02)
	trunk.position.y = 1.0
	t.add_child(trunk)

	# 旷野之息式的扁平层叠树冠垫
	var leaf_col := LEAF_A.lerp(LEAF_B, _rng.randf())
	if _rng.randf() < 0.25:
		leaf_col = leaf_col.lerp(LEAF_TEAL, 0.5)
	var leaf_mat := Toon.make_material(leaf_col, true, 0.04)
	var blob1 := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 1.7
	sm.height = 2.4
	sm.radial_segments = 8
	sm.rings = 5
	blob1.mesh = sm
	blob1.material_override = leaf_mat
	blob1.position = Vector3(0, 2.7, 0)
	blob1.scale = Vector3(1.25, 0.55, 1.25)
	t.add_child(blob1)
	var blob2 := MeshInstance3D.new()
	var sm2 := SphereMesh.new()
	sm2.radius = 1.15
	sm2.height = 1.7
	sm2.radial_segments = 8
	sm2.rings = 5
	blob2.mesh = sm2
	blob2.material_override = leaf_mat
	blob2.position = Vector3(_rng.randf_range(-0.5, 0.5), 3.6, _rng.randf_range(-0.5, 0.5))
	blob2.scale = Vector3(1.1, 0.5, 1.1)
	t.add_child(blob2)
	_add_trunk_collision(t, 0.35, 2.0)
	return t


func _make_pine() -> Node3D:
	var t := Node3D.new()
	t.name = "TreePine"
	var trunk := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.10
	cm.bottom_radius = 0.20
	cm.height = 1.6
	cm.radial_segments = 6
	trunk.mesh = cm
	trunk.material_override = Toon.make_material(TRUNK_COLOR, true, 0.02)
	trunk.position.y = 0.8
	t.add_child(trunk)

	var leaf_col := PINE_A.lerp(PINE_B, _rng.randf())
	var leaf_mat := Toon.make_material(leaf_col, true, 0.04)
	for i in range(3):
		var cone := MeshInstance3D.new()
		var cc := CylinderMesh.new()
		cc.top_radius = 0.0
		cc.bottom_radius = 1.5 - i * 0.38
		cc.height = 1.3
		cc.radial_segments = 7
		cone.mesh = cc
		cone.material_override = leaf_mat
		cone.position.y = 1.7 + i * 0.95
		t.add_child(cone)
	_add_trunk_collision(t, 0.35, 1.6)
	return t


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
	var blade := _make_blade_mesh()
	var shader_mat := ShaderMaterial.new()
	shader_mat.shader = load("res://assets/shaders/grass.gdshader")
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = blade
	mm.instance_count = GRASS_COUNT
	var placed := 0
	var attempts := 0
	while placed < GRASS_COUNT and attempts < GRASS_COUNT * 8:
		attempts += 1
		var p := _rand_point(terrain, 0.90)
		if not _usable(terrain, p, 0.78):
			continue
		var basis := Basis(Vector3.UP, _rng.randf_range(0.0, TAU))
		basis = basis.scaled(Vector3.ONE * _rng.randf_range(0.8, 1.6))
		mm.set_instance_transform(placed, Transform3D(basis, p))
		var tint := Color(1, 1, 1).lerp(Color(0.9, 1.0, 0.5), _rng.randf() * 0.7)
		mm.set_instance_color(placed, tint)
		placed += 1
	mm.instance_count = placed
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Grass"
	mmi.multimesh = mm
	mmi.material_override = shader_mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)


func _scatter_flowers(terrain: Terrain) -> void:
	# 点缀花丛：小十字面片，白/黄/粉
	var blade := _make_blade_mesh()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = blade
	mm.instance_count = FLOWER_COUNT
	var petals := [Color(1.0, 1.0, 0.95), Color(1.0, 0.9, 0.3), Color(1.0, 0.6, 0.7), Color(0.8, 0.6, 1.0)]
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
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
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Flowers"
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)


func _make_blade_mesh() -> ArrayMesh:
	# 两片交叉三角叶，底部为原点，UV.y 顶部为 1（风摆权重）
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var w := 0.08
	var h := 0.72
	for q in range(2):
		var ang := q * PI * 0.5
		var dir := Vector3(cos(ang), 0, sin(ang)) * w
		var base_i := verts.size()
		verts.append(-dir)
		verts.append(dir)
		verts.append(Vector3(0, h, 0))
		uvs.append(Vector2(0, 0))
		uvs.append(Vector2(1, 0))
		uvs.append(Vector2(0.5, 1))
		indices.append_array([base_i, base_i + 1, base_i + 2])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
