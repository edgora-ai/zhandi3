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


static func _puff(pos: Vector3, color: Color, radius: float, grow: float, life: float) -> void:
	var s := SphereMesh.new()
	s.radius = radius
	s.height = radius * 2.0
	s.radial_segments = 6
	s.rings = 3
	var mi := MeshInstance3D.new()
	mi.mesh = s
	mi.material_override = _unshaded(color)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_scene().add_child(mi)
	mi.global_position = pos
	var tw := mi.create_tween()
	tw.set_parallel(true)
	tw.tween_property(mi, "scale", Vector3.ONE * grow, life)
	tw.tween_property(mi, "position:y", pos.y + 0.25, life)
	tw.chain().tween_callback(mi.queue_free)
