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
			# // FIX: R9 模型重染透传修复：
			# 1) 带 albedo_texture 的表面保留原贴图+原色（原只透传颜色，Blender 贴图细节全丢）
			# 2) emission 表面透传发光（守护者核心/龙脊/眼睛）
			# 3) 仅纯色表面换卡通材质+描边
			var sm := mat as StandardMaterial3D
			if sm == null:
				count += 1
				continue
			if sm.albedo_texture != null:
				# 有贴图的表面：贴卡通光照模式但不换色（描边照加）
				var tex_mat := make_material(sm.albedo_color, true, outline_width)
				tex_mat.albedo_texture = sm.albedo_texture
				mesh_inst.set_surface_override_material(si, tex_mat)
				if sm.emission_enabled:
					tex_mat.emission_enabled = true
					tex_mat.emission = sm.emission
					tex_mat.emission_energy_multiplier = sm.emission_energy_multiplier
			elif sm.emission_enabled:
				# 纯自发光表面（眼/核心）：保留原材质，仅补描边 next_pass
				if sm.next_pass == null:
					var emis_outline := sm.duplicate() as StandardMaterial3D
					emis_outline.next_pass = make_outline(outline_width)
					mesh_inst.set_surface_override_material(si, emis_outline)
			else:
				var new_mat := make_material(sm.albedo_color, true, outline_width)
				mesh_inst.set_surface_override_material(si, new_mat)
			count += 1
	return count
