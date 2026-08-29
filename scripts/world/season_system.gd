class_name SeasonSystem
extends Node3D
## 四季总控：统一驱动地表、植被、水片、天空、雾、灯光与程序化天气。

signal season_changed(season_name: String, display_name: String)

const SEASONS := ["spring", "summer", "autumn", "winter"]
const DISPLAY_NAMES := {
	"spring": "春",
	"summer": "夏",
	"autumn": "秋",
	"winter": "冬",
}

const PALETTES := {
	"spring": {
		"ground_tint": Color(0.90, 0.96, 0.88), "snow": 0.0, "wet": 0.05, # // FIX: R4-H6b 春季 G 通道顶满是薄荷色斑来源之一
		"water_shallow": Color(0.36, 0.80, 0.75), "water_deep": Color(0.05, 0.34, 0.53), "rain": 0.12, "ice": 0.0,
		"grass_shadow": Color(0.10, 0.26, 0.07), "grass_dark": Color(0.20, 0.47, 0.11), "grass_light": Color(0.52, 0.75, 0.26),
		"leaf_shadow": Color(0.10, 0.25, 0.08), "leaf_mid": Color(0.28, 0.54, 0.17), "leaf_high": Color(0.61, 0.79, 0.34),
		"pine_shadow": Color(0.05, 0.16, 0.13), "pine_mid": Color(0.12, 0.32, 0.24), "pine_high": Color(0.24, 0.48, 0.30), "flowers": true,
		"sky_top": Color(0.24, 0.56, 0.95), "sky_horizon": Color(0.78, 0.89, 0.96), "ground_sky": Color(0.72, 0.84, 0.80),
		"fog": Color(0.68, 0.80, 0.92), "fog_density": 0.0009, "exposure": 0.88,
		"sun": Color(1.0, 0.957, 0.902), "sun_energy": 1.15, "fill": Color(0.53, 0.81, 0.92), "fill_energy": 0.42, "rim": Color(1.0, 0.84, 0.64),
		"weather": "petals", "weather_color": Color(1.0, 0.64, 0.76, 0.82),
	},
	"summer": {
		"ground_tint": Color(1.0, 0.96, 0.76), "snow": 0.0, "wet": 0.0,
		"water_shallow": Color(0.25, 0.82, 0.82), "water_deep": Color(0.025, 0.28, 0.58), "rain": 0.0, "ice": 0.0,
		"grass_shadow": Color(0.10, 0.24, 0.05), "grass_dark": Color(0.25, 0.47, 0.08), "grass_light": Color(0.65, 0.74, 0.20),
		"leaf_shadow": Color(0.08, 0.22, 0.06), "leaf_mid": Color(0.24, 0.48, 0.11), "leaf_high": Color(0.57, 0.70, 0.21),
		"pine_shadow": Color(0.04, 0.14, 0.12), "pine_mid": Color(0.10, 0.29, 0.21), "pine_high": Color(0.22, 0.43, 0.27), "flowers": true,
		"sky_top": Color(0.16, 0.48, 0.94), "sky_horizon": Color(0.72, 0.88, 0.98), "ground_sky": Color(0.68, 0.79, 0.68),
		"fog": Color(0.63, 0.78, 0.90), "fog_density": 0.00065, "exposure": 0.86,
		"sun": Color(1.0, 0.91, 0.68), "sun_energy": 1.34, "fill": Color(0.43, 0.74, 0.92), "fill_energy": 0.36, "rim": Color(1.0, 0.72, 0.38),
		"weather": "none", "weather_color": Color.WHITE,
	},
	"autumn": {
		"ground_tint": Color(1.05, 0.78, 0.50), "snow": 0.0, "wet": 0.08,
		"water_shallow": Color(0.38, 0.72, 0.70), "water_deep": Color(0.07, 0.30, 0.48), "rain": 0.08, "ice": 0.0,
		"grass_shadow": Color(0.20, 0.11, 0.03), "grass_dark": Color(0.44, 0.26, 0.05), "grass_light": Color(0.80, 0.54, 0.12),
		"leaf_shadow": Color(0.25, 0.055, 0.012), "leaf_mid": Color(0.62, 0.18, 0.028), "leaf_high": Color(0.88, 0.52, 0.06),
		"pine_shadow": Color(0.08, 0.15, 0.10), "pine_mid": Color(0.18, 0.31, 0.17), "pine_high": Color(0.38, 0.48, 0.21), "flowers": true,
		"sky_top": Color(0.31, 0.56, 0.78), "sky_horizon": Color(0.96, 0.78, 0.58), "ground_sky": Color(0.68, 0.57, 0.43),
		"fog": Color(0.78, 0.66, 0.54), "fog_density": 0.0011, "exposure": 0.86,
		"sun": Color(1.0, 0.78, 0.49), "sun_energy": 1.24, "fill": Color(0.83, 0.48, 0.31), "fill_energy": 0.34, "rim": Color(1.0, 0.48, 0.18),
		"weather": "leaves", "weather_color": Color(0.93, 0.28, 0.035, 0.94),
	},
	"winter": {
		"ground_tint": Color(0.72, 0.82, 0.90), "snow": 0.94, "wet": 0.0,
		"water_shallow": Color(0.64, 0.82, 0.94), "water_deep": Color(0.08, 0.25, 0.48), "rain": 0.0, "ice": 0.92,
		"grass_shadow": Color(0.12, 0.20, 0.28), "grass_dark": Color(0.43, 0.57, 0.66), "grass_light": Color(0.72, 0.82, 0.88),
		"leaf_shadow": Color(0.12, 0.24, 0.32), "leaf_mid": Color(0.44, 0.62, 0.69), "leaf_high": Color(0.78, 0.88, 0.92),
		"pine_shadow": Color(0.05, 0.17, 0.22), "pine_mid": Color(0.18, 0.39, 0.42), "pine_high": Color(0.72, 0.88, 0.90), "flowers": false,
		"sky_top": Color(0.50, 0.67, 0.86), "sky_horizon": Color(0.86, 0.92, 0.98), "ground_sky": Color(0.78, 0.85, 0.91),
		"fog": Color(0.72, 0.81, 0.90), "fog_density": 0.00145, "exposure": 0.82,
		"sun": Color(0.88, 0.95, 1.0), "sun_energy": 0.88, "fill": Color(0.65, 0.80, 1.0), "fill_energy": 0.36, "rim": Color(0.78, 0.88, 1.0),
		"weather": "snow", "weather_color": Color(0.95, 0.98, 1.0, 0.88),
	},
}

var current_season := "spring"
var _terrain: Terrain
var _props: Props
var _buildings: Buildings
var _player: Player
var _environment: Environment
var _sky_material: ProceduralSkyMaterial
var _sun: DirectionalLight3D
var _fill: DirectionalLight3D
var _rim: DirectionalLight3D
var _weather: MultiMeshInstance3D
var _weather_multimesh: MultiMesh
var _weather_kind := "none"
var _weather_positions: Array[Vector3] = []
var _weather_velocities: Array[Vector3] = []
var _weather_rotations: Array[float] = []
var _weather_spins: Array[float] = []
var _weather_scales: Array[float] = []
var _weather_time := 0.0


func setup(p_terrain: Terrain, p_props: Props, p_buildings: Buildings, p_player: Player, initial_season: String = "spring") -> void:
	_terrain = p_terrain
	_props = p_props
	_buildings = p_buildings
	_player = p_player
	var root := get_parent()
	var world_environment := root.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if world_environment:
		_environment = world_environment.environment
		if _environment and _environment.sky:
			_sky_material = _environment.sky.sky_material as ProceduralSkyMaterial
	_sun = root.get_node_or_null("Sun") as DirectionalLight3D
	_fill = root.get_node_or_null("FillLight") as DirectionalLight3D
	_rim = root.get_node_or_null("RimLight") as DirectionalLight3D
	_build_weather()
	set_season(initial_season if PALETTES.has(initial_season) else "spring")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_V:
		cycle_season()
		get_viewport().set_input_as_handled()


func cycle_season() -> void:
	var index := SEASONS.find(current_season)
	set_season(SEASONS[(index + 1) % SEASONS.size()])


# M4: 季/天气 Environment 互覆盖问题 — Weather 的湿润通过独立权重上报，
#   DayNight/World 应统一合成 fog/ambient/wetness。此处 Season 侧仍直写 _terrain/_env，
#   已暴露 get_season_wetness 思想由 terrain 承载；TODO(M4) 待 EnvironmentDirector 统一接管。
func set_season(season_name: String) -> void:
	if not PALETTES.has(season_name):
		return
	current_season = season_name
	var palette: Dictionary = PALETTES[season_name]
	_terrain.set_season_palette(
		palette["ground_tint"], palette["snow"], palette["wet"],
		palette["water_shallow"], palette["water_deep"], palette["rain"], palette["ice"])
	_props.set_season_palette(
		palette["grass_shadow"], palette["grass_dark"], palette["grass_light"],
		palette["leaf_shadow"], palette["leaf_mid"], palette["leaf_high"],
		palette["pine_shadow"], palette["pine_mid"], palette["pine_high"], palette["flowers"])
	if _buildings:
		_buildings.set_season(season_name)
	_apply_environment(palette)
	_configure_weather(palette["weather"], palette["weather_color"])
	var display_name: String = DISPLAY_NAMES[season_name]
	season_changed.emit(season_name, display_name)
	print("[season] %s (%s)" % [season_name, display_name])


var current_palette := {}
var wx_mat: StandardMaterial3D = null # // FIX: R3-TA5b
var wx_base := Color.WHITE # // FIX: OPT-F3-light/R19/TA4 季节只发布调色板，天空/雾/太阳由 DayNight 单点合成（原两处互覆盖，冬季仍春天蓝天）

func _apply_environment(palette: Dictionary) -> void:
	current_palette = palette


func _build_weather() -> void:
	# MultiMesh 天气避免 GPUParticles 在快速截图退出时遗留内部 ParticlesShader RID。
	if DisplayServer.get_name() == "headless":
		return
	_weather = MultiMeshInstance3D.new()
	_weather.name = "SeasonWeather"
	_weather.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_weather.custom_aabb = AABB(Vector3(-42, -4, -42), Vector3(84, 34, 84))
	add_child(_weather)


func _configure_weather(kind: String, color: Color) -> void:
	if _weather == null:
		return
	_weather_kind = kind
	_weather.visible = kind != "none"
	if kind == "none":
		return
	var quad := QuadMesh.new()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = color
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.no_depth_test = false
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	# // FIX: OPT-H6/VIS6 花瓣/雪用径向渐变贴图（原纯色方块像素读作"坏点"）
	var pgrad := Gradient.new()
	pgrad.set_color(0, Color(1, 1, 1, 1))
	pgrad.set_color(1, Color(1, 1, 1, 0.25))
	var ptex := GradientTexture2D.new()
	ptex.gradient = pgrad
	ptex.fill = GradientTexture2D.FILL_RADIAL
	ptex.fill_from = Vector2(0.5, 0.5)
	ptex.fill_to = Vector2(0.5, 0.05)
	ptex.width = 16
	ptex.height = 16
	material.albedo_texture = ptex
	quad.material = material
	wx_mat = material # // FIX: R3-TA5b 夜间粒子压暗引用
	wx_base = color
	var count := 120
	if kind == "snow":
		count = 620
		quad.size = Vector2(0.12, 0.12)
	elif kind == "leaves":
		count = 180
		quad.size = Vector2(0.18, 0.09)
	else: # 春季花瓣
		quad.size = Vector2(0.12, 0.07)
	_weather_multimesh = MultiMesh.new()
	_weather_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	_weather_multimesh.mesh = quad
	_weather_multimesh.instance_count = count
	_weather.multimesh = _weather_multimesh
	_weather_positions.clear()
	_weather_velocities.clear()
	_weather_rotations.clear()
	_weather_spins.clear()
	_weather_scales.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7719 + SEASONS.find(current_season) * 101
	for i in range(count):
		_weather_positions.append(Vector3(rng.randf_range(-34.0, 34.0), rng.randf_range(0.0, 26.0), rng.randf_range(-34.0, 34.0)))
		var velocity := Vector3(rng.randf_range(-0.18, 0.32), -rng.randf_range(0.7, 1.5), rng.randf_range(-0.12, 0.22))
		if kind != "snow":
			velocity = Vector3(rng.randf_range(0.18, 0.55), -rng.randf_range(0.35, 0.85), rng.randf_range(-0.10, 0.28))
		_weather_velocities.append(velocity)
		_weather_rotations.append(rng.randf_range(0.0, TAU))
		_weather_spins.append(rng.randf_range(-2.4, 2.4))
		_weather_scales.append(rng.randf_range(0.55, 1.45))
	_update_weather_instances(0.0)


func _process(delta: float) -> void:
	if _player and _weather:
		global_position = _player.global_position
	if _weather_kind != "none" and _weather_multimesh:
		_update_weather_instances(minf(delta, 0.08))


func _update_weather_instances(delta: float) -> void:
	_weather_time += delta
	for i in range(_weather_positions.size()):
		var p: Vector3 = _weather_positions[i]
		var v: Vector3 = _weather_velocities[i]
		p += v * delta
		p.x += sin(_weather_time * 0.8 + float(i) * 1.71) * delta * (0.28 if _weather_kind == "snow" else 0.55)
		p.z += cos(_weather_time * 0.6 + float(i) * 0.93) * delta * 0.22
		if p.y < -1.5:
			p.y = 25.0
			p.x = fposmod(p.x + 34.0, 68.0) - 34.0
		_weather_positions[i] = p
		_weather_rotations[i] += _weather_spins[i] * delta
		var scale_value: float = _weather_scales[i]
		if _weather_kind != "snow":
			scale_value *= 0.72 + absf(sin(_weather_rotations[i])) * 0.45
		var basis := Basis(Vector3.FORWARD, _weather_rotations[i]).scaled(Vector3.ONE * scale_value)
		_weather_multimesh.set_instance_transform(i, Transform3D(basis, p))
