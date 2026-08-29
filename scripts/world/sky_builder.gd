class_name SkyBuilder
extends RefCounted
## // FIX: R14 切片二：天空/环境/云构建外迁（原 ~130 行在 main 上帝类）。
## 一次性构建（无逐帧状态），成员经 m. 回写 main。

static func build_environment(m: Node) -> void:
	var env := Environment.new()
	m._env = env
	if OS.get_cmdline_user_args().has("--flatsky"):
		env.background_mode = Environment.BG_CLEAR_COLOR
		var we0 := WorldEnvironment.new()
		we0.environment = env
		m.add_child(we0)
		return
	var sky := Sky.new()
	var psm := ProceduralSkyMaterial.new()
	m._sky_mat = psm
	psm.sky_top_color = Color(0.24, 0.56, 0.95)
	psm.sky_horizon_color = Color(0.78, 0.89, 0.96)
	psm.ground_bottom_color = Color(0.32, 0.42, 0.30)
	psm.ground_horizon_color = Color(0.72, 0.84, 0.80)
	psm.sun_curve = 0.09
	sky.sky_material = psm
	env.sky = sky
	env.background_mode = Environment.BG_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.5
	# 卡通渲染用 Linear 保持颜色饱和（ACES 会把亮色洗白）
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.tonemap_exposure = 1.0
	# 远景蓝色大气雾（原创旷野卡通的空气感）
	env.fog_enabled = true
	env.fog_light_color = Color(0.68, 0.80, 0.92)
	env.fog_light_energy = 0.8
	env.fog_density = 0.0009
	env.fog_sky_affect = 0.2
	# 轻微泛光，让天空和水面更通透
	env.glow_enabled = true
	env.glow_intensity = 0.2
	env.glow_strength = 0.6
	env.glow_bloom = 0.05
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = env
	m.add_child(we)

	# 三灯架设（参考 Elemental-Serenity）：暖色主光 + 天蓝补光 + 暖橙轮廓光
	var sun := DirectionalLight3D.new()
	m._sun = sun
	sun.name = "Sun"
	sun.light_color = Color(1.0, 0.957, 0.902)
	sun.light_energy = 1.15
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 320.0 # // FIX: OPT-F9/TA16 覆盖远山地标
	sun.shadow_bias = 0.02 # // FIX: OPT-F9/TA16 降 bias 减接触影漂移
	sun.rotation_degrees = Vector3(-48.0, -35.0, 0.0)
	m.add_child(sun)

	var fill := DirectionalLight3D.new()
	m._fill = fill
	fill.name = "FillLight"
	fill.light_color = Color(0.53, 0.81, 0.92)
	fill.light_energy = 0.42
	fill.shadow_enabled = false
	fill.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY   # 不在天上画太阳盘
	fill.rotation_degrees = Vector3(-22.0, 145.0, 0.0)
	m.add_child(fill)

	var rim := DirectionalLight3D.new()
	m._rim = rim
	rim.name = "RimLight"
	rim.light_color = Color(1.0, 0.84, 0.64)
	rim.light_energy = 0.35
	rim.shadow_enabled = false
	rim.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	rim.rotation_degrees = Vector3(-62.0, 190.0, 0.0)
	m.add_child(rim)

	spawn_clouds(m)


static func spawn_clouds(m: Node) -> void:
	if OS.get_cmdline_user_args().has("--noclouds"):
		return
	# 扁平大朵白云，缓慢漂移（原创卡通天空）
	var rng := RandomNumberGenerator.new()
	rng.seed = 88
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 1.0, 1.0, 0.88)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.disable_fog = true
	m._cloud_mat = mat
	for i in range(22):
		var cloud := Node3D.new()
		# // FIX: OPT-H6/VIS5 高度带抬升（不再贴山腰）+ 三种云形（团块/长条/双层）
		cloud.position = Vector3(rng.randf_range(-460, 460), rng.randf_range(135, 190), rng.randf_range(-460, 460))
		var shape := i % 3 # 0=团块 1=长条 2=双层
		var puff_n := 3 if shape == 1 else (4 if shape == 2 else 5)
		for j in range(puff_n):
			var puff := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = rng.randf_range(10.0, 22.0)
			sm.height = sm.radius * 2.0
			sm.radial_segments = 8
			sm.rings = 4
			puff.mesh = sm
			puff.material_override = mat
			puff.position = Vector3(rng.randf_range(-22, 22), rng.randf_range(-2.5, 2.5), rng.randf_range(-9, 9))
			puff.scale = Vector3(1.6, 0.38, 1.0) if shape == 0 else (Vector3(4.2, 0.30, 1.0) if shape == 1 else Vector3(1.4, 0.34, 1.0))
			puff.position.y += (0.0 if shape != 2 else (0.0 if j % 2 == 0 else 6.0))
			puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			cloud.add_child(puff)
		m.add_child(cloud)
		m._clouds.append(cloud)


# ---------- 截图模式（供自动化验证画面） ----------

