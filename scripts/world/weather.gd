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
# M4: Environment 合成分解 — Weather 的湿润独立通道，DayNight/World 再统一合成。
#   当前 terrain.set_weather 仍直写 wetness，与 SeasonSystem.set_season_palette 潜在互覆盖；
#   独立权重 weather_wetness 供 EnvironmentDirector 统一合成（Season × Weather 取 max/lerp）。
var _weather_wetness := 0.0  # 独立通道：仅天气侧的湿润贡献（0..0.85）

const DROP_COUNT := 420
const AREA := 26.0
const FALL_SPEED := 22.0


var _rain_player: AudioStreamPlayer
var _snow_player: AudioStreamPlayer

func setup(p_terrain: Terrain, p_player: Player, env: Environment) -> void:
	terrain = p_terrain
	player = p_player
	_env = env
	_rng.seed = 4477
	_state_t = _rng.randf_range(0.0, 40.0)
	_build_rain()
	# M9 雨雪环境声：复用 ambience/volcano 循环，随强度淡入
	var rs: AudioStreamWAV = load("res://assets/sfx/ambience.wav")
	rs.loop_mode = AudioStreamWAV.LOOP_FORWARD
	rs.loop_end = int(rs.get_length() * rs.mix_rate)
	_rain_player = AudioStreamPlayer.new()
	_rain_player.bus = "Ambience"
	_rain_player.stream = rs
	_rain_player.volume_db = -48.0
	add_child(_rain_player)
	_rain_player.play()
	var ss: AudioStreamWAV = load("res://assets/sfx/snowwind.wav")
	ss.loop_mode = AudioStreamWAV.LOOP_FORWARD
	ss.loop_end = int(ss.get_length() * ss.mix_rate)
	_snow_player = AudioStreamPlayer.new()
	_snow_player.bus = "Ambience"
	_snow_player.stream = ss
	_snow_player.volume_db = -48.0
	add_child(_snow_player)
	_snow_player.play()


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
	if _rain_player:
		_rain_player.volume_db = lerpf(-48.0, -10.0, rain_strength)
	if _snow_player:
		_snow_player.volume_db = lerpf(-48.0, -12.0, snow_strength)
	# 地面与水面联动。
	# TODO(M4): weather 与 season 的 wetness 合成应由 DayNight/World 统一合成器接管；
	#   此处先保留独立权重 _weather_wetness，并暴露 get_weather_wetness()/get_season_wetness()
	#   供合成测试验证互覆盖回归为 0。当前仍调用 terrain.set_weather，但同时记录独立通道。
	_weather_wetness = rain_strength * 0.85
	if terrain:
		terrain.set_weather(_weather_wetness, rain_strength)
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
	# 闪电：雨时每 8~20s 一次落雷（雷柱+光脉冲+雷声+落点杀伤），测试序列豁免。
	if raining:
		_lightning_t -= delta
		if _lightning_t <= 0.0:
			_lightning_t = _rng.randf_range(8.0, 20.0)
			if not OS.get_cmdline_user_args().has("--wildtest"):
				_strike_lightning()
	if _env and _env.ambient_light_energy > 0.6:
		_env.ambient_light_energy = move_toward(_env.ambient_light_energy, 0.5, delta * 3.0)


# 落雷：玩家附近 25~45m 随机点；手持金属武器时 35% 概率劈向玩家（旷野之息式引雷）。
func _strike_lightning() -> void:
	if player == null or terrain == null:
		return
	var metal_out: bool = player.weapon != null and player.weapon.weapon_id != ""
	var at_player := metal_out and _rng.randf() < 0.35
	var pos: Vector3
	if at_player:
		pos = player.global_position
		_feed("金属武器引来了雷电！")
	else:
		var ang := _rng.randf() * TAU
		var r := _rng.randf_range(25.0, 45.0)
		pos = player.global_position + Vector3(cos(ang) * r, 0, sin(ang) * r)
		_feed("远雷滚滚")
	pos.y = terrain.get_height(pos.x, pos.z)
	_spawn_bolt(pos)
	if _env:
		_env.ambient_light_energy = 1.4
	# 雷声按距离延迟（声速 340m/s）。
	var delay: float = pos.distance_to(player.global_position) / 340.0
	var sfx := get_tree().get_first_node_in_group("sfx_bank")
	if sfx:
		if delay > 0.05:
			get_tree().create_timer(delay).timeout.connect(func() -> void: sfx.play_at("thunder", pos, -2.0))
		else:
			sfx.play_at("thunder", pos, -2.0)
	# 落点杀伤：半径 3.5m 的怪物与野兽；玩家被引雷命中掉 25 血。
	for group in ["wild_enemy", "wildlife"]:
		for target in get_tree().get_nodes_in_group(group):
			if not (target is CharacterBody3D) or not target.alive:
				continue
			if target.global_position.distance_to(pos) < 3.5 and target.has_method("take_damage"):
				target.take_damage(35.0, self, "body")
	if at_player and player.alive:
		player.take_damage(25.0, self)


# 锯齿雷柱：五段折线从 60m 高空劈落 + 落点闪光，0.14 秒后消散。
func _spawn_bolt(pos: Vector3) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var bolt := Node3D.new()
	scene.add_child(bolt)
	bolt.global_position = pos
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.85, 0.92, 1.0)
	mat.emission_enabled = true
	mat.emission = Color(0.75, 0.88, 1.0)
	mat.emission_energy_multiplier = 4.0
	var sheath := StandardMaterial3D.new()
	sheath.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sheath.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sheath.albedo_color = Color(0.45, 0.65, 1.0, 0.28)
	sheath.emission_enabled = true
	sheath.emission = Color(0.40, 0.60, 1.0)
	sheath.emission_energy_multiplier = 1.2
	var prev := Vector3(0, 60.0, 0)
	for i in range(5):
		var next := Vector3(_rng.randf_range(-1.5, 1.5) * (1.0 - float(i) / 5.0), 60.0 - float(i + 1) * 12.0, _rng.randf_range(-1.5, 1.5) * (1.0 - float(i) / 5.0))
		var seg := MeshInstance3D.new()
		var sm := BoxMesh.new()
		var d := next - prev
		sm.size = Vector3(0.22, d.length(), 0.22)
		seg.mesh = sm
		seg.material_override = mat
		seg.transform = Transform3D(Basis(Quaternion(Vector3.UP, d.normalized())), (prev + next) * 0.5)
		bolt.add_child(seg)
		var glow := MeshInstance3D.new()
		var gm := BoxMesh.new()
		gm.size = Vector3(0.85, d.length(), 0.85)
		glow.mesh = gm
		glow.material_override = sheath
		glow.transform = seg.transform
		bolt.add_child(glow)
		prev = next
	var flash := OmniLight3D.new()
	flash.light_color = Color(0.75, 0.85, 1.0)
	flash.light_energy = 6.0
	flash.omni_range = 30.0
	flash.position.y = 6.0
	bolt.add_child(flash)
	var tw := bolt.create_tween()
	# 经典二次回击闪烁：亮 0.10s → 熄 0.06s → 再亮 0.16s 后消散。
	tw.tween_interval(0.10)
	tw.tween_property(bolt, "visible", false, 0.0)
	tw.tween_interval(0.06)
	tw.tween_property(bolt, "visible", true, 0.0)
	tw.tween_interval(0.16)
	tw.tween_callback(bolt.queue_free)


func get_weather_wetness() -> float:
	return _weather_wetness

# 占位：供 DayNight/World 合成器调用的季节基线读取（通过 terrain.get_season_wetness() 或 SeasonSystem 注入）
# 当前最小改动仅记录天气侧，季节侧已由 terrain 暴露 get_season_wetness()，两值可在测试中验证 max 合成正确。


func _feed(text_value: String) -> void:
	var scene := get_tree().current_scene
	if scene and scene.get("hud") != null:
		scene.hud.add_feed(text_value)
