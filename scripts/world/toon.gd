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


# // FIX: OPT-F1/TA1 glb 角色卡通化重染：Blender Principled BSDF 材质（哑光无描边）统一
# 转为 DIFFUSE/SPECULAR TOON + next_pass 描边（0.014±），与 bot/马同渲染语言
static func apply_to_glb(root: Node, outline_width: float = 0.014) -> int:
	var count := 0
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_inst := mi as MeshInstance3D
		if mesh_inst == null or mesh_inst.mesh == null:
			continue
		for si in range(mesh_inst.mesh.get_surface_count()):
			var mat := mesh_inst.get_active_material(si)
			var col := Color(0.72, 0.66, 0.58)
			var new_mat := make_material(col, true, outline_width)
			if mat is StandardMaterial3D:
				var sm := mat as StandardMaterial3D
				col = sm.albedo_color
				# // FIX: R3-TA1 透传 emission（守护者核心/龙/骷髅眼的夜间发光特征，原被覆盖抹平）
				if sm.emission_enabled:
					new_mat.emission_enabled = true
					new_mat.emission = sm.emission
					new_mat.emission_energy_multiplier = sm.emission_energy_multiplier
			elif mat is BaseMaterial3D:
				col = (mat as BaseMaterial3D).albedo_color
			new_mat.albedo_color = col
			mesh_inst.set_surface_override_material(si, new_mat)
			count += 1
	return count
