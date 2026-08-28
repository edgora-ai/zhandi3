class_name DayNight
extends Node
## 昼夜循环：驱动太阳/天空/雾色变化。一天 6 分钟，t∈[0,1)：0.0 日出，0.3 正午，0.55 日落，0.8 午夜。

const DAY_LENGTH := 360.0

var t := 0.28
var speed_scale := 1.0
var blood_moon := false
var _night_index := 0
var _last_midnight := -1.0

signal blood_moon_started

var _env: Environment
var _sky_mat: ProceduralSkyMaterial
var _sun: DirectionalLight3D
var _fill: DirectionalLight3D
var _rim: DirectionalLight3D

const SKY_TOP_DAY := Color(0.24, 0.56, 0.95)
const SKY_TOP_DUSK := Color(0.42, 0.26, 0.48)
const SKY_TOP_NIGHT := Color(0.03, 0.06, 0.14)
const SKY_HORIZON_DAY := Color(0.78, 0.89, 0.96)
const SKY_HORIZON_DUSK := Color(0.98, 0.55, 0.32)
const SKY_HORIZON_NIGHT := Color(0.10, 0.16, 0.28)
const FOG_DAY := Color(0.68, 0.80, 0.92)
const FOG_DUSK := Color(0.85, 0.62, 0.55)
const FOG_NIGHT := Color(0.10, 0.15, 0.25)
const SUN_DAY := Color(1.0, 0.957, 0.902)
const SUN_DUSK := Color(1.0, 0.55, 0.32)
const SUN_NIGHT := Color(0.55, 0.68, 0.95)


func setup(env: Environment, sky_mat: ProceduralSkyMaterial, sun: DirectionalLight3D, fill: DirectionalLight3D, rim: DirectionalLight3D) -> void:
	_env = env
	_sky_mat = sky_mat
	_sun = sun
	_fill = fill
	_rim = rim
	_apply()


func is_night() -> bool:
	return t > 0.62 and t < 0.94


func phase_name() -> String:
	if t < 0.12:
		return "清晨"
	if t < 0.42:
		return "正午"
	if t < 0.62:
		return "黄昏"
	if t < 0.94:
		return "夜晚"
	return "黎明"


# 氛围权重：白天 1.0 → 黄昏 → 夜晚 0.0。
func _daylight() -> float:
	var elev := sin(t * TAU)
	return smoothstep(-0.12, 0.25, elev)


func _duskness() -> float:
	var elev := sin(t * TAU)
	return (1.0 - absf(elev)) * (1.0 if t < 0.65 else 0.0) * 0.9


func advance(hours: float) -> void:
	var prev := t
	t = fmod(t + hours / 24.0, 1.0)
	_check_midnight(prev, t)
	_apply()


func _process(delta: float) -> void:
	var prev := t
	t = fmod(t + delta * speed_scale / DAY_LENGTH, 1.0)
	_check_midnight(prev, t)
	_apply()


func _check_midnight(prev: float, now: float) -> void:
	# 午夜计数：跨过 0.8 记一夜，每三夜一次血月。
	if prev < 0.8 and t >= 0.8:
		_night_index += 1
		if _night_index % 3 == 0:
			blood_moon = true
			blood_moon_started.emit()
	if prev < 0.94 and t >= 0.94:
		blood_moon = false


# TODO(M4): EnvironmentDirector 统一合成 — Season/DayNight/Weather 仅上报权重，
#   由单一合成器决定 fog/ambient/wetness；当前三者各直写 Environment，Weather 已独立 _weather_wetness
#   供测试桩验证 max 合成正确（互覆盖回归为 0）。
func _apply() -> void:
	if _sky_mat == null:
		return
	var day := _daylight()
	var dusk := clampf(_duskness(), 0.0, 1.0)
	var night := 1.0 - day
	# 天空与雾。
	var top := SKY_TOP_NIGHT.lerp(SKY_TOP_DAY, day).lerp(SKY_TOP_DUSK, dusk * 0.6)
	var horizon := SKY_HORIZON_NIGHT.lerp(SKY_HORIZON_DAY, day).lerp(SKY_HORIZON_DUSK, dusk * 0.8)
	if blood_moon:
		top = top.lerp(Color(0.35, 0.05, 0.08), 0.75)
		horizon = horizon.lerp(Color(0.85, 0.18, 0.12), 0.75)
	_sky_mat.sky_top_color = top
	_sky_mat.sky_horizon_color = horizon
	_sky_mat.ground_bottom_color = horizon.darkened(0.55)
	_sky_mat.ground_horizon_color = horizon
	_env.ambient_light_energy = lerpf(0.12, 0.5, day)
	_env.fog_light_color = FOG_NIGHT.lerp(FOG_DAY, day).lerp(FOG_DUSK, dusk * 0.5)
	if blood_moon:
		_env.fog_light_color = _env.fog_light_color.lerp(Color(0.55, 0.12, 0.10), 0.7)
	_env.fog_density = lerpf(0.0016, 0.0009, day)
	# 太阳角度随时间转过天空；夜间变成冷色月光。
	var sun_angle := t * TAU - PI * 0.5
	_sun.rotation_degrees = Vector3(rad_to_deg(-asin(clampf(sin(sun_angle), -1.0, 1.0))) - 20.0, -35.0, 0.0)
	_sun.light_color = SUN_NIGHT.lerp(SUN_DAY, day).lerp(SUN_DUSK, dusk * 0.7)
	if blood_moon:
		_sun.light_color = Color(1.0, 0.22, 0.15)
		_sun.light_energy = 0.35
		return
	_sun.light_energy = lerpf(0.14, 1.15, day)
	_fill.light_energy = lerpf(0.06, 0.42, day)
	_rim.light_energy = lerpf(0.10, 0.35, day)
