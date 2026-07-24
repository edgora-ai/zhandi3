class_name Terrain
extends Node3D
## 程序化地形：噪声位移网格 + 顶点色（按高度/坡度）+ 解析高度采样

const SIZE := 500.0
const HALF := SIZE * 0.5
const GRID := 160               ## 每边四边形数（顶点 (GRID+1)^2）
const HEIGHT_AMP := 13.0
const HEIGHT_BASE := 6.0
const RIM_HEIGHT := 50.0        ## 地图边缘抬升，形成天然边界
const WATER_LEVEL := 2.0

const GRASS_DEEP := Color(0.30, 0.52, 0.17)
const GRASS_LIGHT := Color(0.55, 0.74, 0.26)
const GRASS_DRY := Color(0.76, 0.72, 0.33)
const ROCK := Color(0.48, 0.51, 0.55)
const HIGH := Color(0.62, 0.62, 0.58)
const SAND := Color(0.82, 0.76, 0.55)

var noise := FastNoiseLite.new()
var patch_noise := FastNoiseLite.new()
var detail_noise := FastNoiseLite.new()
var profile := "battlefield"
var grid_resolution := GRID
var mesh_instance: MeshInstance3D
var _ground_material: ShaderMaterial
var _water_material: ShaderMaterial


func _init() -> void:
	noise.seed = 1337
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = 0.006
	noise.fractal_octaves = 4
	noise.fractal_gain = 0.5
	patch_noise.seed = 991
	patch_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	patch_noise.frequency = 0.025
	detail_noise.seed = 4242
	detail_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	detail_noise.frequency = 0.018
	detail_noise.fractal_octaves = 3


func configure(p_profile: String) -> void:
	profile = p_profile
	if profile == "wild":
		grid_resolution = 192
		noise.seed = 11037
		patch_noise.seed = 8841
		detail_noise.seed = 7319


func _ready() -> void:
	_build()


func get_height(x: float, z: float) -> float:
	if profile == "wild":
		return _wild_height(x, z)
	var h: float = HEIGHT_BASE + noise.get_noise_2d(x, z) * HEIGHT_AMP
	var d := maxf(absf(x), absf(z)) / HALF
	h += smoothstep(0.72, 1.0, d) * RIM_HEIGHT
	return h


# 阔野地图的手工地貌骨架：中央草原、初始台地、双子山、雪山、火山与曲流水系。
# 噪声只负责表面起伏，主轮廓由命名地标的解析函数控制，保证每次布局可辨认。
func _wild_height(x: float, z: float) -> float:
	var h := 7.0 + noise.get_noise_2d(x, z) * 4.8 + detail_noise.get_noise_2d(x, z) * 1.8
	# 初始高原：西南侧平顶台地与陡峭边缘。
	var plateau_d := maxf(absf(x + 112.0) / 72.0, absf(z - 92.0) / 58.0)
	var plateau := 1.0 - smoothstep(0.72, 1.0, plateau_d)
	h = lerpf(h, 22.0 + detail_noise.get_noise_2d(x * 0.5, z * 0.5) * 0.8, plateau)
	# 双子山：东南两座相邻高峰，中间留出河谷通道。
	h += _hill(x, z, 63.0, 72.0, 42.0, 28.0)
	h += _hill(x, z, 100.0, 62.0, 38.0, 25.0)
	var twin_gap := exp(-pow((x - 81.0) / 12.0, 2.0) - pow((z - 67.0) / 34.0, 2.0))
	h -= twin_gap * 17.0
	# 西北雪山与东北火山构成远景天际线。
	h += _hill(x, z, -166.0, -142.0, 92.0, 47.0)
	h += _hill(x, z, -205.0, -96.0, 62.0, 29.0)
	var volcano := _hill(x, z, 164.0, -145.0, 82.0, 62.0)
	var crater := exp(-pow((x - 164.0) / 19.0, 2.0) - pow((z + 145.0) / 19.0, 2.0)) * 24.0
	h += volcano - crater
	# 北部城堡丘陵与东部台阶山脊。
	h += _hill(x, z, 4.0, -112.0, 70.0, 18.0)
	h += _hill(x, z, 202.0, 16.0, 54.0, 24.0)
	# 中央海利亚河：宽阔 S 形主河，东南分叉穿过双子山。
	var river_x := sin(z * 0.021) * 24.0 - 8.0 + sin(z * 0.049) * 7.0
	var river_dist := absf(x - river_x)
	var river_mask := 1.0 - smoothstep(7.0, 13.0, river_dist)
	var river_bed := 0.15 + detail_noise.get_noise_2d(x * 2.0, z * 2.0) * 0.18
	h = lerpf(h, river_bed, river_mask)
	var branch_z := 58.0 + sin((x - 25.0) * 0.025) * 13.0
	var branch_dist := absf(z - branch_z)
	var branch_mask := (1.0 - smoothstep(5.0, 10.0, branch_dist)) * smoothstep(-15.0, 28.0, x) * smoothstep(145.0, 105.0, x)
	h = lerpf(h, 0.35, branch_mask)
	# 地标基座必须平整，但边缘保留自然过渡。
	h = _flatten_disc(h, x, z, Vector2(-112.0, 92.0), 16.0, 22.0)
	h = _flatten_disc(h, x, z, Vector2(-72.0, 21.0), 22.0, 8.2)
	h = _flatten_disc(h, x, z, Vector2(18.0, -94.0), 24.0, 20.0)
	# 地图边缘抬成连续远山，避免矩形边界感。
	var edge := maxf(absf(x), absf(z)) / HALF
	h += smoothstep(0.78, 1.0, edge) * 52.0
	return h


func _hill(x: float, z: float, cx: float, cz: float, radius: float, height: float) -> float:
	var d2 := pow((x - cx) / radius, 2.0) + pow((z - cz) / radius, 2.0)
	return exp(-d2 * 1.65) * height


func _flatten_disc(h: float, x: float, z: float, center: Vector2, radius: float, target: float) -> float:
	var d := Vector2(x, z).distance_to(center)
	return lerpf(target, h, smoothstep(radius * 0.68, radius, d))


func get_normal(x: float, z: float, e: float = 1.5) -> Vector3:
	var hx := get_height(x + e, z) - get_height(x - e, z)
	var hz := get_height(x, z + e) - get_height(x, z - e)
	return Vector3(-hx, 2.0 * e, -hz).normalized()


func is_in_water(x: float, z: float) -> bool:
	return get_height(x, z) < WATER_LEVEL


func get_water_level(_x: float = 0.0, _z: float = 0.0) -> float:
	return WATER_LEVEL


func _build() -> void:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	var step := SIZE / grid_resolution
	verts.resize((grid_resolution + 1) * (grid_resolution + 1))
	normals.resize((grid_resolution + 1) * (grid_resolution + 1))
	colors.resize((grid_resolution + 1) * (grid_resolution + 1))
	for gz in range(grid_resolution + 1):
		for gx in range(grid_resolution + 1):
			var i := gz * (grid_resolution + 1) + gx
			var x := -HALF + gx * step
			var z := -HALF + gz * step
			var y := get_height(x, z)
			verts[i] = Vector3(x, y, z)
			var n := get_normal(x, z, step * 0.5)
			normals[i] = n
			colors[i] = _vertex_color(x, y, z, n)
	for gz in range(grid_resolution):
		for gx in range(grid_resolution):
			var i0 := gz * (grid_resolution + 1) + gx
			var i1 := i0 + 1
			var i2 := i0 + (grid_resolution + 1)
			var i3 := i2 + 1
			indices.append_array([i0, i1, i2, i1, i3, i2])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	mesh_instance = MeshInstance3D.new()
	mesh_instance.mesh = mesh
	_ground_material = ShaderMaterial.new()
	_ground_material.shader = load("res://assets/shaders/ground.gdshader")
	mesh_instance.material_override = _ground_material
	add_child(mesh_instance)

	var body := StaticBody3D.new()
	body.collision_layer = 1
	var col := CollisionShape3D.new()
	col.shape = mesh.create_trimesh_shape()
	col.shape.backface_collision = true
	body.add_child(col)
	add_child(body)

	if not OS.get_cmdline_user_args().has("--noworld"):
		_build_water()


func _vertex_color(x: float, y: float, z: float, n: Vector3) -> Color:
	var p := patch_noise.get_noise_2d(x, z)
	var deep := Color(0.17, 0.37, 0.075) if profile == "wild" else GRASS_DEEP
	var light := Color(0.46, 0.66, 0.14) if profile == "wild" else GRASS_LIGHT
	var c := deep.lerp(light, clampf(p * 0.5 + 0.5, 0.0, 1.0))
	if p > 0.30:
		c = c.lerp(GRASS_DRY, smoothstep(0.30, 0.70, p) * 0.7)
	# 水线附近沙滩
	if y < WATER_LEVEL + 1.2:
		c = c.lerp(SAND, smoothstep(WATER_LEVEL + 1.2, WATER_LEVEL - 0.5, y))
	# 陡坡露岩
	c = c.lerp(ROCK, smoothstep(0.80, 0.62, n.y))
	# 高处灰岩
	if y > 18.0:
		var high_color := Color(0.39, 0.43, 0.36) if profile == "wild" else HIGH
		c = c.lerp(high_color, smoothstep(18.0, 34.0, y))
	if profile == "wild":
		# 火山暖岩与雪山冷岩形成强烈地区辨识。
		var volcanic := 1.0 - smoothstep(45.0, 115.0, Vector2(x, z).distance_to(Vector2(164, -145)))
		c = c.lerp(Color(0.30, 0.20, 0.16), volcanic * smoothstep(15.0, 35.0, y))
		var snowland := 1.0 - smoothstep(55.0, 125.0, Vector2(x, z).distance_to(Vector2(-166, -142)))
		c = c.lerp(Color(0.78, 0.86, 0.90), snowland * smoothstep(24.0, 48.0, y))
	return c


func _build_water() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(SIZE, SIZE) if profile == "wild" else Vector2(SIZE * 1.1, SIZE * 1.1)
	plane.subdivide_width = 64
	plane.subdivide_depth = 64
	var water := MeshInstance3D.new()
	water.name = "Water"
	water.mesh = plane
	water.position.y = WATER_LEVEL
	_water_material = ShaderMaterial.new()
	_water_material.shader = load("res://assets/shaders/water.gdshader")
	_water_material.set_shader_parameter("u_height_map", _bake_heightmap())
	_water_material.set_shader_parameter("u_water_level", WATER_LEVEL)
	_water_material.set_shader_parameter("u_ground_half", HALF)
	water.material_override = _water_material
	add_child(water)


func set_season_palette(ground_tint: Color, snow_amount: float, wetness: float, water_shallow: Color, water_deep: Color, rain_amount: float, ice_amount: float) -> void:
	if _ground_material:
		if profile == "wild":
			ground_tint *= Color(0.84, 0.90, 0.79, 1.0)
		_ground_material.set_shader_parameter("season_tint", ground_tint)
		_ground_material.set_shader_parameter("snow_amount", snow_amount)
		_ground_material.set_shader_parameter("wetness", wetness)
	if _water_material:
		_water_material.set_shader_parameter("color_shallow", water_shallow)
		_water_material.set_shader_parameter("color_deep", water_deep)
		_water_material.set_shader_parameter("rain_amount", rain_amount)
		_water_material.set_shader_parameter("ice_amount", ice_amount)


# 水面 shader 用：把解析高度烘成单通道纹理（R = 高度，米）
func _bake_heightmap() -> ImageTexture:
	var img := Image.create(grid_resolution + 1, grid_resolution + 1, false, Image.FORMAT_RF)
	var step := SIZE / grid_resolution
	for gz in range(grid_resolution + 1):
		for gx in range(grid_resolution + 1):
			var x := -HALF + gx * step
			var z := -HALF + gz * step
			img.set_pixel(gx, gz, Color(get_height(x, z), 0, 0))
	return ImageTexture.create_from_image(img)
