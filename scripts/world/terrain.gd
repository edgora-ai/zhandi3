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


func _ready() -> void:
	_build()


func get_height(x: float, z: float) -> float:
	var h: float = HEIGHT_BASE + noise.get_noise_2d(x, z) * HEIGHT_AMP
	var d := maxf(absf(x), absf(z)) / HALF
	h += smoothstep(0.72, 1.0, d) * RIM_HEIGHT
	return h


func get_normal(x: float, z: float, e: float = 1.5) -> Vector3:
	var hx := get_height(x + e, z) - get_height(x - e, z)
	var hz := get_height(x, z + e) - get_height(x, z - e)
	return Vector3(-hx, 2.0 * e, -hz).normalized()


func is_in_water(x: float, z: float) -> bool:
	return get_height(x, z) < WATER_LEVEL


func _build() -> void:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	var step := SIZE / GRID
	verts.resize((GRID + 1) * (GRID + 1))
	normals.resize((GRID + 1) * (GRID + 1))
	colors.resize((GRID + 1) * (GRID + 1))
	for gz in range(GRID + 1):
		for gx in range(GRID + 1):
			var i := gz * (GRID + 1) + gx
			var x := -HALF + gx * step
			var z := -HALF + gz * step
			var y := get_height(x, z)
			verts[i] = Vector3(x, y, z)
			var n := get_normal(x, z, step * 0.5)
			normals[i] = n
			colors[i] = _vertex_color(x, y, z, n)
	for gz in range(GRID):
		for gx in range(GRID):
			var i0 := gz * (GRID + 1) + gx
			var i1 := i0 + 1
			var i2 := i0 + (GRID + 1)
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
	var c := GRASS_DEEP.lerp(GRASS_LIGHT, clampf(p * 0.5 + 0.5, 0.0, 1.0))
	if p > 0.30:
		c = c.lerp(GRASS_DRY, smoothstep(0.30, 0.70, p) * 0.7)
	# 水线附近沙滩
	if y < WATER_LEVEL + 1.2:
		c = c.lerp(SAND, smoothstep(WATER_LEVEL + 1.2, WATER_LEVEL - 0.5, y))
	# 陡坡露岩
	c = c.lerp(ROCK, smoothstep(0.80, 0.62, n.y))
	# 高处灰岩
	if y > 18.0:
		c = c.lerp(HIGH, smoothstep(18.0, 30.0, y))
	return c


func _build_water() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(SIZE * 1.1, SIZE * 1.1)
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
	var img := Image.create(GRID + 1, GRID + 1, false, Image.FORMAT_RF)
	var step := SIZE / GRID
	for gz in range(GRID + 1):
		for gx in range(GRID + 1):
			var x := -HALF + gx * step
			var z := -HALF + gz * step
			img.set_pixel(gx, gz, Color(get_height(x, z), 0, 0))
	return ImageTexture.create_from_image(img)
