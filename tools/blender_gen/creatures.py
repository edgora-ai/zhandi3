# 阔野动物：无头 Blender 生成野猪/狼/熊蒙皮模型与动画（walk/idle/attack/hit/die），各导一个 glb。
# 运行：/Applications/Blender.app/Contents/MacOS/Blender --background --python tools/blender_gen/creatures.py
import bpy
import math
import os


def mat(name, rgb):
	m = bpy.data.materials.new(name)
	m.use_nodes = True
	bsdf = None
	for n in m.node_tree.nodes:
		if n.type == "BSDF_PRINCIPLED":
			bsdf = n
	if bsdf is None:
		bsdf = m.node_tree.nodes.new("ShaderNodeBsdfPrincipled")
	bsdf.inputs["Base Color"].default_value = (*rgb, 1.0)
	bsdf.inputs["Roughness"].default_value = 1.0
	return m


def sphere(name, loc, scale, material):
	bpy.ops.mesh.primitive_uv_sphere_add(segments=12, ring_count=8, radius=1.0, location=loc)
	o = bpy.context.active_object
	o.name = name
	o.scale = scale
	bpy.ops.object.transform_apply(scale=True)
	o.data.materials.append(material)
	return o


def box(name, loc, size, material, rot=(0, 0, 0)):
	bpy.ops.mesh.primitive_cube_add(size=1.0, location=loc, rotation=rot)
	o = bpy.context.active_object
	o.name = name
	o.scale = size
	bpy.ops.object.transform_apply(scale=True)
	o.data.materials.append(material)
	return o


def cone(name, loc, r1, r2, depth, material, rot=(0, 0, 0)):
	bpy.ops.mesh.primitive_cone_add(vertices=8, radius1=r1, radius2=r2, depth=depth, location=loc, rotation=rot)
	o = bpy.context.active_object
	o.name = name
	o.data.materials.append(material)
	return o


def boar_parts():
	fur = mat("boar_fur", (0.30, 0.20, 0.14))
	mane = mat("boar_mane", (0.13, 0.10, 0.075))
	tusk = mat("boar_tusk", (0.92, 0.83, 0.60))
	p = []
	p.append(sphere("body", (0, 0, 0.78), (0.51, 0.80, 0.45), fur))
	p.append(sphere("head", (0, -0.72, 0.78), (0.38, 0.42, 0.32), fur))
	p.append(sphere("snout", (0, -1.02, 0.70), (0.28, 0.24, 0.17), mane))
	for sx in [-1, 1]:
		p.append(cone("tusk", (sx * 0.23, -1.14, 0.64), 0.045, 0.012, 0.30, tusk, rot=(math.radians(52), 0, sx * math.radians(24))))
		p.append(box("ear", (sx * 0.31, -0.72, 1.04), (0.16, 0.07, 0.24), fur, rot=(0, sx * math.radians(-20), 0)))
		p.append(sphere("eye", (sx * 0.19, -1.00, 0.88), (0.05, 0.035, 0.05), mane))
	for i in range(7):
		p.append(box("bristle", (0, -0.35 + i * 0.15, 1.22), (0.06, 0.13, 0.22), mane, rot=(math.radians(90), 0, 0)))
	p.append(cone("tail", (0, 0.82, 0.88), 0.05, 0.02, 0.28, fur, rot=(math.radians(-42), 0, 0)))
	for sx in [-0.36, 0.36]:
		for sz in [-0.52, 0.52]:
			p.append(cone("leg", (sx, sz, 0.30), 0.105, 0.075, 0.60, fur))
			p.append(box("hoof", (sx, sz - 0.02, 0.05), (0.15, 0.17, 0.10), mane))
	return p


def wolf_parts():
	fur = mat("wolf_fur", (0.42, 0.46, 0.44))
	light = mat("wolf_light", (0.70, 0.72, 0.65))
	dark = mat("wolf_dark", (0.12, 0.14, 0.14))
	p = []
	p.append(sphere("body", (0, 0, 0.82), (0.36, 0.65, 0.34), fur))
	p.append(cone("neck", (0, -0.56, 1.02), 0.26, 0.20, 0.60, fur, rot=(math.radians(55), 0, 0)))
	p.append(sphere("head", (0, -0.82, 1.24), (0.31, 0.34, 0.29), fur))
	p.append(sphere("muzzle", (0, -1.10, 1.14), (0.18, 0.26, 0.13), light))
	p.append(sphere("nose", (0, -1.32, 1.16), (0.075, 0.06, 0.07), dark))
	for sx in [-1, 1]:
		p.append(box("ear", (sx * 0.22, -0.83, 1.55), (0.14, 0.09, 0.36), fur, rot=(0, sx * math.radians(-10), 0)))
		p.append(sphere("eye", (sx * 0.12, -1.04, 1.33), (0.035, 0.026, 0.035), dark))
	p.append(cone("tail", (0, 0.88, 0.92), 0.13, 0.06, 0.90, fur, rot=(math.radians(-58), 0, 0)))
	for sx in [-0.28, 0.28]:
		for sz in [-0.58, 0.58]:
			p.append(cone("leg", (sx, sz, 0.33), 0.09, 0.065, 0.66, fur))
			p.append(box("paw", (sx, sz - 0.02, 0.05), (0.14, 0.18, 0.09), dark))
	return p


def bear_parts():
	fur = mat("bear_fur", (0.29, 0.18, 0.105))
	muzzle = mat("bear_muzzle", (0.58, 0.42, 0.26))
	dark = mat("bear_dark", (0.07, 0.055, 0.045))
	p = []
	p.append(sphere("body", (0, 0.15, 1.18), (0.84, 1.05, 0.91), fur))
	p.append(sphere("head", (0, -0.72, 1.62), (0.57, 0.60, 0.57), fur))
	p.append(sphere("muzzle", (0, -1.18, 1.46), (0.37, 0.36, 0.22), muzzle))
	p.append(sphere("nose", (0, -1.45, 1.58), (0.11, 0.08, 0.07), dark))
	for sx in [-1, 1]:
		p.append(sphere("ear", (sx * 0.45, -0.67, 2.04), (0.20, 0.14, 0.20), fur))
		p.append(sphere("eye", (sx * 0.20, -1.12, 1.73), (0.045, 0.032, 0.045), dark))
	p.append(sphere("tail", (0, 1.22, 1.28), (0.16, 0.14, 0.16), fur))
	for sx in [-0.44, 0.44]:
		for sz in [-0.72, 0.72]:
			p.append(cone("leg", (sx, sz, 0.41), 0.17, 0.12, 0.82, fur))
			p.append(box("paw", (sx, sz - 0.03, 0.07), (0.24, 0.28, 0.13), dark))
	return p


def reset_pose(pb):
	for b in pb:
		b.rotation_euler = (0.0, 0.0, 0.0)
		b.location = (0.0, 0.0, 0.0)


def make_clip(arm, pb, name, keys, loc_keys=None):
	reset_pose(pb)
	act = bpy.data.actions.new(name)
	if arm.animation_data is None:
		arm.animation_data_create()
	arm.animation_data.action = act
	for bname, klist in keys.items():
		b = pb[bname]
		b.rotation_mode = 'XYZ'
		for (f, rx, ry, rz) in klist:
			b.rotation_euler = (math.radians(rx), math.radians(ry), math.radians(rz))
			b.keyframe_insert("rotation_euler", frame=f)
	if loc_keys:
		for bname, klist in loc_keys.items():
			b = pb[bname]
			for (f, x, y, z) in klist:
				b.location = (x, y, z)
				b.keyframe_insert("location", frame=f)
	track = arm.animation_data.nla_tracks.new()
	track.name = name
	track.strips.new(name, 1, act)
	track.mute = True
	arm.animation_data.action = None


def build(out_name, parts, leg_x, leg_zf, leg_zb, hip_h, spine_z, head_z, tail_z):
	for p in parts:
		p.select_set(True)
	bpy.context.view_layer.objects.active = parts[0]
	bpy.ops.object.join()
	body = parts[0]
	body.name = "Body"
	bpy.ops.object.armature_add(enter_editmode=True, location=(0, 0, 0))
	arm = bpy.context.active_object
	arm.name = "Rig"
	eb = arm.data.edit_bones
	base = eb[0]
	base.name = "spine"
	base.head = (0, leg_zb * 0.55, spine_z)
	base.tail = (0, leg_zf * 0.62, spine_z + 0.06)
	
	def bone(bname, head, tail, parent):
		b = eb.new(bname)
		b.head = head
		b.tail = tail
		b.parent = eb[parent]
		return b
	
	bone("neck", (0, leg_zf * 0.62, spine_z + 0.06), (0, leg_zf * 1.05, head_z), "spine")
	bone("head", (0, leg_zf * 1.05, head_z), (0, leg_zf * 1.45, head_z - 0.06), "neck")
	bone("tail", (0, leg_zb * 0.9, spine_z + 0.04), (0, leg_zb * 1.25, tail_z), "spine")
	for sx, stag in [(-1, "l"), (1, "r")]:
		for zv, ztag in [(leg_zf, "f"), (leg_zb, "h")]:
			bone("up_" + ztag + stag, (sx * leg_x, zv, hip_h), (sx * leg_x, zv, hip_h * 0.45), "spine")
			bone("lo_" + ztag + stag, (sx * leg_x, zv, hip_h * 0.45), (sx * leg_x, zv - 0.02, 0.05), "up_" + ztag + stag)
	bpy.ops.object.mode_set(mode='OBJECT')
	body.select_set(True)
	arm.select_set(True)
	bpy.context.view_layer.objects.active = arm
	bpy.ops.object.parent_set(type='ARMATURE_AUTO')
	pb = arm.pose.bones
	# walk：对角两拍（25 帧循环）
	make_clip(arm, pb, "walk", {
		"up_fl": [(1, 22, 0, 0), (13, -22, 0, 0), (25, 22, 0, 0)],
		"up_hr": [(1, 22, 0, 0), (13, -22, 0, 0), (25, 22, 0, 0)],
		"up_fr": [(1, -22, 0, 0), (13, 22, 0, 0), (25, -22, 0, 0)],
		"up_hl": [(1, -22, 0, 0), (13, 22, 0, 0), (25, -22, 0, 0)],
		"lo_fl": [(1, 6, 0, 0), (7, 28, 0, 0), (13, 6, 0, 0), (19, 20, 0, 0), (25, 6, 0, 0)],
		"lo_hr": [(1, 6, 0, 0), (7, 28, 0, 0), (13, 6, 0, 0), (19, 20, 0, 0), (25, 6, 0, 0)],
		"lo_fr": [(1, 28, 0, 0), (7, 6, 0, 0), (13, 20, 0, 0), (19, 6, 0, 0), (25, 28, 0, 0)],
		"lo_hl": [(1, 28, 0, 0), (7, 6, 0, 0), (13, 20, 0, 0), (19, 6, 0, 0), (25, 28, 0, 0)],
		"neck": [(1, 2, 0, 0), (13, -2, 0, 0), (25, 2, 0, 0)],
	}, loc_keys={"spine": [(1, 0, 0, 0), (7, 0, 0, -0.03), (13, 0, 0, 0), (19, 0, 0, -0.03), (25, 0, 0, 0)]})
	# idle：呼吸、尾摆、头探望（49 帧循环）
	make_clip(arm, pb, "idle", {
		"neck": [(1, 0, 0, 0), (25, 2.5, 0, 0), (49, 0, 0, 0)],
		"head": [(1, 0, 0, 0), (13, 0, 7, 0), (25, 0, 0, 0), (37, 0, -7, 0), (49, 0, 0, 0)],
		"tail": [(1, 0, 8, 0), (25, 0, -8, 0), (49, 0, 8, 0)],
	}, loc_keys={"spine": [(1, 0, 0, 0), (25, 0, 0, -0.015), (49, 0, 0, 0)]})
	# attack：扑咬——颈前探猛咬（12 帧）
	make_clip(arm, pb, "attack", {
		"neck": [(1, 0, 0, 0), (4, 28, 0, 0), (8, 32, 0, 0), (12, 0, 0, 0)],
		"head": [(1, 0, 0, 0), (4, 20, 0, 0), (8, 24, 0, 0), (12, 0, 0, 0)],
		"spine": [(1, 0, 0, 0), (4, 10, 0, 0), (8, 12, 0, 0), (12, 0, 0, 0)],
		"up_fl": [(1, 0, 0, 0), (4, -14, 0, 0), (8, -16, 0, 0), (12, 0, 0, 0)],
		"up_fr": [(1, 0, 0, 0), (4, -14, 0, 0), (8, -16, 0, 0), (12, 0, 0, 0)],
	}, loc_keys={"spine": [(1, 0, 0, 0), (4, 0, -0.28, 0.04), (8, 0, -0.32, 0.04), (12, 0, 0, 0)]})
	# hit：受击后缩（8 帧）
	make_clip(arm, pb, "hit", {
		"spine": [(1, 0, 0, 0), (3, -12, 0, 0), (8, 0, 0, 0)],
		"neck": [(1, 0, 0, 0), (3, -16, 0, 0), (8, 0, 0, 0)],
	})
	# die：侧倒四腿收拢（24 帧，停在倒姿）
	make_clip(arm, pb, "die", {
		"spine": [(1, 0, 0, 0), (8, 0, 78, 0), (24, 0, 80, 0)],
		"neck": [(1, 0, 0, 0), (8, 0, 14, 0), (24, 0, 16, 0)],
		"up_fl": [(1, 0, 0, 0), (10, -52, 0, 0), (24, -55, 0, 0)],
		"up_fr": [(1, 0, 0, 0), (10, -48, 0, 0), (24, -50, 0, 0)],
		"up_hl": [(1, 0, 0, 0), (10, 44, 0, 0), (24, 46, 0, 0)],
		"up_hr": [(1, 0, 0, 0), (10, 48, 0, 0), (24, 50, 0, 0)],
		"lo_fl": [(1, 0, 0, 0), (10, 62, 0, 0), (24, 64, 0, 0)],
		"lo_fr": [(1, 0, 0, 0), (10, 58, 0, 0), (24, 60, 0, 0)],
		"lo_hl": [(1, 0, 0, 0), (10, 55, 0, 0), (24, 57, 0, 0)],
		"lo_hr": [(1, 0, 0, 0), (10, 58, 0, 0), (24, 60, 0, 0)],
	}, loc_keys={"spine": [(1, 0, 0, 0), (8, 0, 0, -0.30), (24, 0, 0, -0.32)]})
	reset_pose(pb)
	bpy.context.scene.render.fps = 24
	root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
	out = os.path.join(root, "assets/models", out_name)
	os.makedirs(os.path.dirname(out), exist_ok=True)
	bpy.ops.export_scene.gltf(filepath=out, export_format='GLB', export_animations=True, export_animation_mode='NLA_TRACKS')
	print("[creatures] exported:", out)


SPECIES = [
	("boar.glb", boar_parts, 0.36, -0.52, 0.52, 0.58, 0.78, 0.80, 0.72),
	("wolf.glb", wolf_parts, 0.28, -0.58, 0.58, 0.64, 0.84, 1.20, 0.85),
	("bear.glb", bear_parts, 0.44, -0.72, 0.72, 0.78, 1.18, 1.58, 1.25),
]

for out_name, parts_fn, lx, lzf, lzb, hh, sz, hz, tz in SPECIES:
	bpy.ops.object.select_all(action='SELECT')
	bpy.ops.object.delete(use_global=False)
	build(out_name, parts_fn(), lx, lzf, lzb, hh, sz, hz, tz)
