class_name Weather
extends Node
## 天气系统：晴/雨交替，雨时地面湿滑、水面起涟漪、雨幕与偶发闪电。

var terrain: Terrain
var player: Player
var raining := false
var rain_strength := 0.0   # 0..1，过渡平滑
var snowing := false
var snow_strength := 0.0
var _snow_mm: MultiMeshInstance3D
var _flakes: Array[Vector3] = []
var _sway_t := 0.0

const SNOW_COUNT := 700
const SNOW_FALL := 2.2

var _state_t := 0.0
var _state_len := 100.0
var _rain_mm: MultiMeshInstance3D
var _drops: Array[Vector3] = []
var _env: Environment
var _fog_base := 0.0009
var _lightning_t := 0.0
var _rng := RandomNumberGenerator.new()

const DROP_COUNT := 420
const AREA := 26.0
const FALL_SPEED := 22.0


func setup(p_terrain: Terrain, p_player: Player, env: Environment) -> void:
	terrain = p_terrain
	player = p_player
	_env = env
	_rng.seed = 4477
	_state_t = _rng.randf_range(0.0, 40.0)
	_build_rain()


func _build_rain() -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.012, 0.55, 0.012)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = DROP_COUNT
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.75, 0.85, 0.95, 0.4)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for i in range(DROP_COUNT):
		_drops.append(Vector3(_rng.randf_range(-AREA, AREA), _rng.randf_range(0, 22.0), _rng.randf_range(-AREA, AREA)))
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, _drops[i]))
	_rain_mm = MultiMeshInstance3D.new()
	_rain_mm.multimesh = mm
	_rain_mm.material_override = mat
	_rain_mm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_rain_mm.visible = false
	add_child(_rain_mm)
	_build_snow()


func _build_snow() -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.055, 0.055, 0.055)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = SNOW_COUNT
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.96, 0.97, 1.0, 0.8)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for i in range(SNOW_COUNT):
		_flakes.append(Vector3(_rng.randf_range(-AREA, AREA), _rng.randf_range(0, 22.0), _rng.randf_range(-AREA, AREA)))
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, _flakes[i]))
	_snow_mm = MultiMeshInstance3D.new()
	_snow_mm.multimesh = mm
	_snow_mm.material_override = mat
	_snow_mm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_snow_mm.visible = false
	add_child(_snow_mm)


# 西北雪山地区：雪线以北以西降水为雪。
func in_snow_region(pos: Vector3) -> bool:
	return pos.x < -105.0 and pos.z < -75.0


func force_rain(on: bool) -> void:
	raining = on
	_state_t = 0.0


func _process(delta: float) -> void:
	_state_t += delta
	# 晴 90~150s，降水 40~70s；雪山地区降水为雪，其余为雨。
	if not raining and not snowing and _state_t > _state_len:
		_state_t = 0.0
		_state_len = _rng.randf_range(40.0, 70.0)
		if player and in_snow_region(player.global_position):
			snowing = true
			_feed("下雪了")
		else:
			raining = true
			_feed("下雨了")
	elif (raining or snowing) and _state_t > _state_len:
		_feed("雪停了" if snowing else "雨停了")
		raining = false
		snowing = false
		_state_t = 0.0
		_state_len = _rng.randf_range(90.0, 150.0)
	rain_strength = move_toward(rain_strength, 1.0 if raining else 0.0, delta * 0.25)
	snow_strength = move_toward(snow_strength, 1.0 if snowing else 0.0, delta * 0.25)
	# 地面与水面联动。
	if terrain:
		terrain.set_weather(rain_strength * 0.85, rain_strength)
	# 雨幕跟随玩家。
	if _rain_mm:
		_rain_mm.visible = rain_strength > 0.05
		if _rain_mm.visible and player:
			var center := player.global_position
			var mm := _rain_mm.multimesh
			for i in range(DROP_COUNT):
				var d: Vector3 = _drops[i]
				d.y -= FALL_SPEED * delta
				if d.y < 0.0:
					d.y = 22.0
					d.x = _rng.randf_range(-AREA, AREA)
					d.z = _rng.randf_range(-AREA, AREA)
				_drops[i] = d
				mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, center + Vector3(d.x, d.y, d.z)))
	# 雪幕跟随玩家：慢速飘落 + 左右摇曳。
	_sway_t += delta
	if _snow_mm:
		_snow_mm.visible = snow_strength > 0.05
		if _snow_mm.visible and player:
			var center2 := player.global_position
			var mm2 := _snow_mm.multimesh
			for i in range(SNOW_COUNT):
				var d2: Vector3 = _flakes[i]
				d2.y -= SNOW_FALL * delta
				d2.x += sin(_sway_t * 1.3 + float(i)) * 0.4 * delta
				if d2.y < 0.0:
					d2.y = 22.0
					d2.x = _rng.randf_range(-AREA, AREA)
					d2.z = _rng.randf_range(-AREA, AREA)
				_flakes[i] = d2
				mm2.set_instance_transform(i, Transform3D(Basis.IDENTITY, center2 + Vector3(d2.x, d2.y, d2.z)))
	# 闪电：雨时每 8~20s 一次环境光脉冲。
	if raining:
		_lightning_t -= delta
		if _lightning_t <= 0.0:
			_lightning_t = _rng.randf_range(8.0, 20.0)
			if _env:
				_env.ambient_light_energy = 1.4
			_feed("远雷滚滚")
	if _env and _env.ambient_light_energy > 0.6:
		_env.ambient_light_energy = move_toward(_env.ambient_light_energy, 0.5, delta * 3.0)


func _feed(text_value: String) -> void:
	var scene := get_tree().current_scene
	if scene and scene.get("hud") != null:
		scene.hud.add_feed(text_value)
