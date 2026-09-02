class_name DayNight
extends Node
## 昼夜循环：驱动太阳/天空/雾色变化。一天 6 分钟，t∈[0,1)：0.0 日出，0.25 正午（仰角峰值），0.5 日落，0.8 午夜。

const DAY_LENGTH := 360.0

var t := 0.28
var speed_scale := 1.0
var blood_moon := false
var _night_index := 0
var _last_midnight := -1.0

signal blood_moon_started
signal blood_moon_ended # // FIX: R2-3 血月结束广播（Boss 音乐/氛围层解除）

var _env: Environment
var _sky_mat: ProceduralSkyMaterial
var _sun: DirectionalLight3D
var _fill: DirectionalLight3D
var _rim: DirectionalLight3D
var _daylight_gp_ready := false # // FIX: OPT-F2 全局 shader 参数只注册一次
var season_palette := {} # // FIX: OPT-F3-light 季节调色板（由 SeasonSystem 发布）

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
	# // FIX: OPT-F4 日落 0.5（仰角曲线对齐），夜晚边界相应前移
	return t > 0.53 and t < 0.97


func phase_name() -> String:
	if t < 0.08:
		return "清晨"
	if t < 0.42:
		return "正午"
	if t < 0.53:
		return "黄昏"
	if t < 0.95:
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
		blood_moon_ended.emit() # // FIX: R2-3


# TODO(M4): EnvironmentDirector 统一合成 — Season/DayNight/Weather 仅上报权重，
#   由单一合成器决定 fog/ambient/wetness；当前三者各直写 Environment，Weather 已独立 _weather_wetness
#   供测试桩验证 max 合成正确（互覆盖回归为 0）。
func _apply() -> void:
	if _sky_mat == null:
		return
	var day := _daylight()
	var dusk := clampf(_duskness(), 0.0, 1.0)
	var night := 1.0 - day
	# 天空与雾。// FIX: OPT-F3-light/TA4 季节调色板参与合成：冬季冷白蓝天空/秋橙霞真正生效
	var season_top: Color = season_palette.get("sky_top", SKY_TOP_DAY)
	var season_horizon: Color = season_palette.get("sky_horizon", SKY_HORIZON_DAY)
	var season_fog: Color = season_palette.get("fog", FOG_DAY)
	var season_sun: Color = season_palette.get("sun", SUN_DAY)
	var top := SKY_TOP_NIGHT.lerp(season_top, day).lerp(SKY_TOP_DUSK, dusk * 0.6)
	var horizon := SKY_HORIZON_NIGHT.lerp(season_horizon, day).lerp(SKY_HORIZON_DUSK, dusk * 0.8)
	if blood_moon:
		top = top.lerp(Color(0.35, 0.05, 0.08), 0.75)
		horizon = horizon.lerp(Color(0.85, 0.18, 0.12), 0.75)
	_sky_mat.sky_top_color = top
	_sky_mat.sky_horizon_color = horizon
	_sky_mat.ground_bottom_color = horizon.darkened(0.55)
	_sky_mat.ground_horizon_color = horizon
	# // FIX: R3-TA6 闪电期间 ambient 写权让位天气（原每帧覆盖使闪光存活不过 1 帧）
	var wx: Node = get_parent().get_node_or_null("Weather")
	if wx == null or wx.get("ambient_flash") == null or float(wx.get("ambient_flash")) <= 0.01:
		_env.ambient_light_energy = lerpf(0.12, 0.5, day)
	_env.fog_light_color = FOG_NIGHT.lerp(season_fog, day).lerp(FOG_DUSK, dusk * 0.5)
	if season_palette.has("exposure"):
		_env.tonemap_exposure = float(season_palette["exposure"])
	if blood_moon:
		_env.fog_light_color = _env.fog_light_color.lerp(Color(0.55, 0.12, 0.10), 0.7)
	# // FIX: R3-TA2 季节雾密度真正生效（原季节行被本行无条件覆盖=死代码）；meta_wild 恒假分支一并删除
	var season_fog_d: float = float(season_palette.get("fog_density", 0.0009)) if season_palette.has("fog_density") else 0.0009
	_env.fog_density = lerpf(0.0016, season_fog_d, day)
	# // FIX: OPT-F2/TA3 unshaded 植被/水面随昼夜明暗（全局 shader 参数，夜晚 ≤ 白天 30%）
	# // FIX: R9 删除运行时注册分支（global_shader_parameter_get_list 是编辑器专用 API，
	# 运行时调用每帧刷性能警告；project.godot [shader_globals] 已声明 day_light，直接 set 即可）
	RenderingServer.global_shader_parameter_set("day_light", lerpf(0.22, 1.0, day))
	# // FIX: OPT-F4/TA5 太阳轨迹方位角-仰角参数化：
	# 白天 yaw -110°→110°（东升西落），夜晚月光 yaw 110°→250°（连续西移，黎明 250°≡-110° 无跳变）；
	# 仰角单峰 sin 曲线（峰值 t=0.25 与 phase 正午对齐），修原 asin 镜像导致正午阴影翻转 180°
	var elev_deg: float
	var yaw_deg: float
	if t < 0.5:
		var day_u := t / 0.5
		elev_deg = sin(PI * day_u) * 62.0
		yaw_deg = lerpf(-110.0, 110.0, day_u)
	else:
		var night_u := (t - 0.5) / 0.5
		elev_deg = sin(PI * night_u) * 40.0
		yaw_deg = lerpf(110.0, 250.0, night_u)
	_sun.rotation_degrees = Vector3(-(90.0 - elev_deg), yaw_deg, 0.0)
	_sun.light_color = SUN_NIGHT.lerp(season_sun, day).lerp(SUN_DUSK, dusk * 0.7)
	if not season_palette.is_empty() and _fill:
		_fill.light_color = season_palette.get("fill", _fill.light_color)
		_rim.light_color = season_palette.get("rim", _rim.light_color)
	if blood_moon:
		_sun.light_color = Color(1.0, 0.22, 0.15)
		_sun.light_energy = 0.35
		# // FIX: BM 血月 rim/fill 转红压暗（原角色剪影仍冷白）
		if _fill:
			_fill.light_color = Color(0.5, 0.12, 0.10)
			_fill.light_energy = lerpf(0.06, 0.42, day) * 0.35
		if _rim:
			_rim.light_color = Color(1.0, 0.18, 0.10)
			_rim.light_energy = lerpf(0.10, 0.35, day) * 0.30
		return
	_sun.light_energy = lerpf(0.14, 1.15, day)
	_fill.light_energy = lerpf(0.06, 0.42, day)
	_rim.light_energy = lerpf(0.10, 0.35, day)
