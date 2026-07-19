class_name Toon
## 卡通材质工厂：Godot 内置 toon 光照 + 可选描边（grow 反壳法）

static func make_material(color: Color, outline: bool = false, outline_width: float = 0.03, roughness: float = 0.9) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	m.specular_mode = BaseMaterial3D.SPECULAR_TOON
	m.roughness = roughness
	m.metallic = 0.0
	if outline:
		m.next_pass = make_outline(outline_width)
	return m


static func make_outline(width: float, color: Color = Color(0.06, 0.07, 0.10)) -> StandardMaterial3D:
	var o := StandardMaterial3D.new()
	o.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	o.albedo_color = color
	o.cull_mode = BaseMaterial3D.CULL_FRONT
	o.grow = true
	o.grow_amount = width
	return o
