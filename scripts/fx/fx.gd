class_name FX
## 轻量战斗特效：弹道曳光、命中烟尘、血液喷溅（全部为临时节点，自动回收）

# // FIX: D2/FX11 共享静态资源：枪口焰/曳光网格与材质全局复用，运行时零 new Mesh/Material
static var _flash_mesh: QuadMesh
static var _flash_mat: StandardMaterial3D
static var _tracer_mesh: BoxMesh # // FIX: H4b tracer 单位网格（scale.z=dist，运行时零 new Mesh）
static var _tracer_mats: Dictionary = {} # // FIX: H4b tracer 材质缓存（Color 键，≤8）

static func _scene() -> Node:
	return (Engine.get_main_loop() as SceneTree).current_scene


static func _unshaded(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color
	return m


# 枪口焰：十字火舌面片（billboard）+ 随机滚转，0.05s 消失；玩家与 bot 共用。
static func muzzle_flash(pos: Vector3, size: float = 0.22) -> void:
	if _flash_mesh == null:
		_flash_mesh = QuadMesh.new()
		_flash_mesh.size = Vector2(1.0, 1.0)
		_flash_mat = StandardMaterial3D.new()
		_flash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_flash_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_flash_mat.albedo_color = Color(1.0, 0.82, 0.45, 0.95)
		_flash_mat.emission_enabled = true
		_flash_mat.emission = Color(1.0, 0.72, 0.30)
		_flash_mat.emission_energy_multiplier = 2.0
		_flash_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	var mi := MeshInstance3D.new()
	mi.mesh = _flash_mesh
	mi.material_override = _flash_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_scene().add_child(mi)
	mi.global_position = pos
	mi.scale = Vector3.ONE * size * randf_range(0.85, 1.2)
	var tw := mi.create_tween()
	tw.tween_property(mi, "scale", mi.scale * 0.3, 0.05)
	tw.tween_callback(mi.queue_free)


static func tracer(from: Vector3, to: Vector3, color: Color = Color(1.0, 0.88, 0.45), width: float = 0.025) -> void:
	var dist := from.distance_to(to)
	if dist < 1.0:
		return
	if _tracer_mesh == null:
		_tracer_mesh = BoxMesh.new()
		_tracer_mesh.size = Vector3(1, 1, 1)
	var mat: Variant = _tracer_mats.get(color)
	if mat == null:
		mat = _unshaded(color)
		if _tracer_mats.size() >= 8:
			_tracer_mats.clear()
		_tracer_mats[color] = mat
	var mi := MeshInstance3D.new()
	mi.mesh = _tracer_mesh
	mi.material_override = mat as Material
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.scale = Vector3(width, width, dist)
	_scene().add_child(mi)
	mi.global_position = (from + to) * 0.5
	mi.look_at(to, Vector3.UP)
	var tw := mi.create_tween()
	tw.tween_interval(0.05)
	tw.tween_property(mi, "scale", Vector3(width * 0.15, width * 0.15, dist), 0.09)
	tw.tween_callback(mi.queue_free)


static func impact(pos: Vector3, color: Color = Color(0.85, 0.80, 0.65)) -> void:
	_puff(pos, color, 0.06, 3.0, 0.18)


# ---------- 弹孔 decal ----------
# // FIX: D5/FX8 弹孔池：64 个共享贴图四边形 LRU 复用，存续 20s；扫射弹着点可读

const DECAL_MAX := 64
static var _decals: Array[MeshInstance3D] = []
static var _decal_idx := 0
static var _decal_mat: StandardMaterial3D
static var _decal_mesh: QuadMesh

static func _ensure_decal_res() -> void:
	if _decal_mesh != null:
		return
	_decal_mesh = QuadMesh.new()
	_decal_mesh.size = Vector2(0.09, 0.09)
	var grad := Gradient.new()
	grad.set_color(0, Color(0.05, 0.05, 0.06, 0.85))
	grad.set_color(1, Color(0.05, 0.05, 0.06, 0.0))
	grad.add_point(0.35, Color(0.08, 0.08, 0.09, 0.6))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	tex.width = 32
	tex.height = 32
	_decal_mat = StandardMaterial3D.new()
	_decal_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_decal_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_decal_mat.albedo_texture = tex
	_decal_mat.albedo_color = Color(1, 1, 1, 0.9)

static func decal(pos: Vector3, normal: Vector3) -> void:
	_ensure_decal_res()
	# // FIX: R2-1 静态池跨场景重载悬垂：入口校验，任何 freed 引用即整池清空重建
	if _decals.size() > 0 and not is_instance_valid(_decals[0]):
		_decals.clear()
		_decal_idx = 0
	var mi: MeshInstance3D
	if _decals.size() < DECAL_MAX:
		mi = MeshInstance3D.new()
		mi.mesh = _decal_mesh
		mi.material_override = _decal_mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_scene().add_child(mi)
		_decals.append(mi)
	else:
		mi = _decals[_decal_idx]
	_decal_idx = (_decal_idx + 1) % DECAL_MAX
	var n := normal.normalized() if normal.length_squared() > 0.01 else Vector3.UP
	mi.visible = true
	mi.global_position = pos + n * 0.012
	# 四边形贴着表面：look_at 沿法线
	if absf(n.dot(Vector3.UP)) < 0.98:
		mi.look_at(mi.global_position + n, Vector3.UP)
	else:
		mi.look_at(mi.global_position + n, Vector3.FORWARD)
	mi.rotation.z = randf() * TAU
	mi.scale = Vector3.ONE * randf_range(0.8, 1.3)


static func blood(pos: Vector3) -> void:
	_puff(pos, Color(0.75, 0.12, 0.10), 0.09, 2.6, 0.22)


# 盾反闪光：蓝白外闪 + 亮核双球，配合顿帧表达完美格挡。
static func parry_flash(pos: Vector3) -> void:
	_puff(pos, Color(0.65, 0.90, 1.0), 0.30, 4.5, 0.22)
	_puff(pos, Color(1.0, 1.0, 0.9), 0.12, 3.0, 0.14)


# 剑刃命中：中心闪光加放射状短芒，比通用枪击烟尘更清楚地表达斩击方向。
static func melee_hit(pos: Vector3, attack_dir: Vector3, heavy: bool = false) -> void:
	var tint := Color(1.0, 0.66, 0.22) if heavy else Color(0.62, 0.88, 1.0)
	_puff(pos, tint, 0.11 if heavy else 0.08, 3.8, 0.16)
	var forward := attack_dir.normalized()
	var right := forward.cross(Vector3.UP).normalized()
	if right.length_squared() < 0.01:
		right = Vector3.RIGHT
	for i in range(7 if heavy else 5):
		var angle := TAU * float(i) / float(7 if heavy else 5)
		var outward := (right * cos(angle) + Vector3.UP * sin(angle)).normalized()
		var streak := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.025, 0.025, 0.34 if heavy else 0.24)
		streak.mesh = mesh
		streak.material_override = _unshaded(tint)
		streak.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_scene().add_child(streak)
		streak.global_position = pos + outward * 0.10
		streak.look_at(pos + outward, Vector3.UP if absf(outward.dot(Vector3.UP)) < 0.95 else Vector3.FORWARD)
		var tw := streak.create_tween()
		tw.set_parallel(true)
		tw.tween_property(streak, "global_position", pos + outward * (0.75 if heavy else 0.52), 0.15)
		tw.tween_property(streak, "scale", Vector3(0.18, 0.18, 0.45), 0.15)
		tw.chain().tween_callback(streak.queue_free)


# 敌人脚下的攻击预警环。调用者保留节点并在前摇阶段控制 visible/scale。
static func attack_ring(parent: Node3D, radius: float, color: Color) -> MeshInstance3D:
	var ring := MeshInstance3D.new()
	var mesh := TorusMesh.new()
	mesh.inner_radius = radius * 0.88
	mesh.outer_radius = radius
	mesh.rings = 24
	mesh.ring_segments = 5
	ring.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = Color(color.r, color.g, color.b)
	mat.emission_energy_multiplier = 2.0
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	ring.material_override = mat
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.position.y = 0.08
	ring.visible = false
	parent.add_child(ring)
	return ring


static var _puff_meshes: Dictionary = {} # // FIX: R4-14 puff 网格按半径共享（拖尾 100 次/s 不再每次 new SphereMesh）
static var _puff_mats: Dictionary = {} # // FIX: H4b puff 材质色板缓存（Color 键，≤8，实例 transparency 淡出故可共享）

static func _puff(pos: Vector3, color: Color, radius: float, grow: float, life: float) -> void:
	var s: SphereMesh = _puff_meshes.get(radius)
	if s == null:
		s = SphereMesh.new()
		s.radius = radius
		s.height = radius * 2.0
		s.radial_segments = 6
		s.rings = 3
		_puff_meshes[radius] = s
	# // FIX: H4b 材质按 Color 缓存（满 8 清池），淡出走实例 transparency 而非材质独占
	var key := Color(color.r, color.g, color.b, 1.0)
	var mat: Variant = _puff_mats.get(key)
	if mat == null:
		mat = _unshaded(Color(key.r, key.g, key.b, 0.85)) # // FIX: M6 0.85 alpha，已验证
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA # // FIX: M6 透明混合
		if _puff_mats.size() >= 8:
			_puff_mats.clear()
		_puff_mats[key] = mat
	var mi := MeshInstance3D.new()
	mi.mesh = s
	mi.material_override = mat as Material
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.transparency = 0.0
	_scene().add_child(mi)
	mi.global_position = pos
	var tw := mi.create_tween()
	tw.set_parallel(true)
	tw.tween_property(mi, "scale", Vector3.ONE * grow, life) # // FIX: M6 scale 淡出
	tw.tween_property(mi, "position:y", pos.y + 0.25, life)
	tw.tween_property(mi, "transparency", 1.0, life) # // FIX: H4b 实例级淡出（共享材质不独占）
	tw.chain().tween_callback(mi.queue_free)
