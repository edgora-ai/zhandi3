class_name FX
## 轻量战斗特效：弹道曳光、命中烟尘、血液喷溅（全部为临时节点，自动回收）

static func _scene() -> Node:
	return (Engine.get_main_loop() as SceneTree).current_scene


static func _unshaded(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color
	return m


static func tracer(from: Vector3, to: Vector3, color: Color = Color(1.0, 0.88, 0.45)) -> void:
	var dist := from.distance_to(to)
	if dist < 1.0:
		return
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.025, 0.025, dist)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _unshaded(color)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_scene().add_child(mi)
	mi.global_position = (from + to) * 0.5
	mi.look_at(to, Vector3.UP)
	var tw := mi.create_tween()
	tw.tween_interval(0.05)
	tw.tween_property(mi, "scale", Vector3(0.15, 0.15, 1.0), 0.09)
	tw.tween_callback(mi.queue_free)


static func impact(pos: Vector3, color: Color = Color(0.85, 0.80, 0.65)) -> void:
	_puff(pos, color, 0.06, 3.0, 0.18)


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


static func _puff(pos: Vector3, color: Color, radius: float, grow: float, life: float) -> void:
	var s := SphereMesh.new()
	s.radius = radius
	s.height = radius * 2.0
	s.radial_segments = 6
	s.rings = 3
	var mi := MeshInstance3D.new()
	mi.mesh = s
	# M6: 已核验 fix — 半透明 puff 初始 alpha 0.85 且 scale/alpha 同步淡出（非实心球）
	var mat := _unshaded(Color(color.r, color.g, color.b, 0.85)) # FIX: M6 0.85 alpha，已验证
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA # FIX: M6 透明混合
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_scene().add_child(mi)
	mi.global_position = pos
	var tw := mi.create_tween()
	tw.set_parallel(true)
	tw.tween_property(mi, "scale", Vector3.ONE * grow, life) # FIX: M6 scale 淡出
	tw.tween_property(mi, "position:y", pos.y + 0.25, life)
	tw.tween_property(mat, "albedo_color:a", 0.0, life) # FIX: M6 alpha 淡出至 0
	tw.chain().tween_callback(mi.queue_free)
