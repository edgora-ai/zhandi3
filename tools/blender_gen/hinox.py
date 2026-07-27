# 西诺克斯独眼巨人：无头 Blender 生成蒙皮巨人（sleep/wake/walk/stomp/throw/stagger/hit/die），导出 glb。
# 运行：/Applications/Blender.app/Contents/MacOS/Blender --background --python tools/blender_gen/hinox.py
import bpy
import math
import os

OUT = "assets/models/hinox.glb"

bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)


def mat(name, rgb, emit=None):
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
	if emit is not None:
		for key in ("Emission Color", "Emission"):
			if key in bsdf.inputs:
				bsdf.inputs[key].default_value = (*emit, 1.0)
				break
		if "Emission Strength" in bsdf.inputs:
			bsdf.inputs["Emission Strength"].default_value = 1.6
	return m


SKIN = mat("hinox_skin", (0.55, 0.38, 0.22))
FUR = mat("hinox_fur", (0.28, 0.18, 0.10))
BELLY = mat("hinox_belly", (0.78, 0.62, 0.40))
EYEW = mat("hinox_eyewhite", (0.94, 0.92, 0.85))
PUPIL = mat("hinox_pupil", (0.35, 0.18, 0.08), emit=(0.55, 0.25, 0.08))
DARK = mat("hinox_dark", (0.10, 0.07, 0.05))
TEETH = mat("hinox_teeth", (0.90, 0.85, 0.70))


def sphere(name, loc, scale, material):
	bpy.ops.mesh.primitive_uv_sphere_add(segments=16, ring_count=11, radius=1.0, location=loc)
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
	bpy.ops.mesh.primitive_cone_add(vertices=10, radius1=r1, radius2=r2, depth=depth, location=loc, rotation=rot)
	o = bpy.context.active_object
	o.name = name
	o.data.materials.append(material)
	return o


# 巨躯、独眼、獠牙大嘴、粗长臂、短粗腿、毛皮裙（面向 -Y，站立约 5.2m）
parts = []
parts.append(sphere("body", (0, 0, 2.6), (1.7, 1.5, 1.9), SKIN))
parts.append(sphere("belly", (0, -0.9, 2.3), (1.2, 0.7, 1.3), BELLY))
# 独眼（白眼球 + 棕色瞳孔），眉脊毛
parts.append(sphere("eyeball", (0, -1.52, 3.35), (0.42, 0.30, 0.36), EYEW))
parts.append(sphere("pupil", (0, -1.78, 3.35), (0.17, 0.12, 0.17), PUPIL))
parts.append(box("brow", (0, -1.48, 3.72), (1.15, 0.24, 0.28), FUR, rot=(math.radians(-10), 0, 0)))
# 大嘴与下獠牙
parts.append(box("mouth", (0, -1.55, 2.55), (0.95, 0.16, 0.36), DARK))
for i in range(4):
	parts.append(box("tooth", (-0.30 + i * 0.20, -1.62, 2.72), (0.08, 0.06, 0.14), TEETH))
# 头顶毛簇
for i in range(3):
	parts.append(cone("tuft", (-0.18 + i * 0.18, 0.05, 4.48), 0.09, 0.015, 0.34, FUR, rot=(math.radians(-14 + i * 14), 0, 0)))
# 粗长臂（垂到膝）与拳
for sx in [-1, 1]:
	parts.append(cone("upperarm", (sx * 1.85, 0, 3.05), 0.52, 0.42, 1.55, SKIN))
	parts.append(cone("forearm", (sx * 2.00, -0.05, 1.65), 0.46, 0.38, 1.45, SKIN))
	parts.append(sphere("fist", (sx * 2.05, -0.05, 0.85), (0.55, 0.50, 0.55), SKIN))
# 短粗腿与脚
for sx in [-1, 1]:
	parts.append(cone("thigh", (sx * 0.70, 0, 0.95), 0.58, 0.46, 1.30, SKIN))
	parts.append(box("foot", (sx * 0.72, -0.18, 0.14), (0.62, 0.95, 0.28), FUR))
# 毛皮裙
parts.append(cone("skirt", (0, 0, 1.85), 1.95, 1.55, 0.70, FUR))

for p in parts:
	p.select_set(True)
bpy.context.view_layer.objects.active = parts[0]
bpy.ops.object.join()
body = parts[0]
body.name = "HinoxBody"

# 骨骼：脊柱/头区 + 双臂双节 + 双腿双节
bpy.ops.object.armature_add(enter_editmode=True, location=(0, 0, 0))
arm = bpy.context.active_object
arm.name = "HinoxRig"
eb = arm.data.edit_bones
base = eb[0]
base.name = "spine"
base.head = (0, 0, 1.50)
base.tail = (0, 0, 3.20)


def bone(name, head, tail, parent):
	b = eb.new(name)
	b.head = head
	b.tail = tail
	b.parent = eb[parent]
	return b


bone("head", (0, 0, 3.20), (0, -0.50, 3.80), "spine")
for sx, stag in [(-1, "l"), (1, "r")]:
	bone("arm_" + stag, (sx * 1.20, 0, 3.40), (sx * 1.95, 0, 2.30), "spine")
	bone("forearm_" + stag, (sx * 1.95, 0, 2.30), (sx * 2.05, 0, 0.80), "arm_" + stag)
	bone("thigh_" + stag, (sx * 0.70, 0, 1.60), (sx * 0.70, 0, 0.80), "spine")
	bone("shin_" + stag, (sx * 0.70, 0, 0.80), (sx * 0.72, 0, 0.10), "thigh_" + stag)
bpy.ops.object.mode_set(mode='OBJECT')

body.select_set(True)
arm.select_set(True)
bpy.context.view_layer.objects.active = arm
bpy.ops.object.parent_set(type='ARMATURE_AUTO')
pb = arm.pose.bones


def reset_pose():
	for b in pb:
		b.rotation_euler = (0.0, 0.0, 0.0)
		b.location = (0.0, 0.0, 0.0)


def make_clip(name, keys, loc_keys=None):
	reset_pose()
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

# sleep：坐姿抱膝打鼾，肚皮起伏（49 帧循环）
make_clip("sleep", {
	"spine": [(1, 30, 0, 0), (25, 34, 0, 0), (49, 30, 0, 0)],
	"head": [(1, 25, 0, 0), (25, 28, 3, 0), (37, 28, -3, 0), (49, 25, 0, 0)],
	"arm_l": [(1, 15, 0, 20), (25, 18, 0, 20), (49, 15, 0, 20)],
	"arm_r": [(1, 15, 0, -20), (25, 18, 0, -20), (49, 15, 0, -20)],
	"thigh_l": [(1, -85, 0, -10), (49, -85, 0, -10)],
	"thigh_r": [(1, -85, 0, 10), (49, -85, 0, 10)],
	"shin_l": [(1, 95, 0, 0), (49, 95, 0, 0)],
	"shin_r": [(1, 95, 0, 0), (49, 95, 0, 0)],
}, loc_keys={"spine": [(1, 0, 0, -1.05), (25, 0, 0, -0.98), (49, 0, 0, -1.05)]})

# wake：起身咆哮（24 帧）
make_clip("wake", {
	"spine": [(1, 30, 0, 0), (10, -8, 0, 0), (17, -14, 0, 0), (24, 0, 0, 0)],
	"head": [(1, 25, 0, 0), (10, -22, 0, 0), (17, -26, 0, 0), (24, 0, 0, 0)],
	"arm_l": [(1, 15, 0, 20), (10, -60, 0, 45), (17, -70, 0, 50), (24, 0, 0, 4)],
	"arm_r": [(1, 15, 0, -20), (10, -60, 0, -45), (17, -70, 0, -50), (24, 0, 0, -4)],
	"thigh_l": [(1, -85, 0, -10), (10, 0, 0, 0), (24, 0, 0, 0)],
	"thigh_r": [(1, -85, 0, 10), (10, 0, 0, 0), (24, 0, 0, 0)],
	"shin_l": [(1, 95, 0, 0), (10, 0, 0, 0), (24, 0, 0, 0)],
	"shin_r": [(1, 95, 0, 0), (10, 0, 0, 0), (24, 0, 0, 0)],
}, loc_keys={"spine": [(1, 0, 0, -1.05), (10, 0, 0, -0.2), (17, 0, 0, 0.06), (24, 0, 0, 0)]})

# walk：沉重慢步，躯体晃动（25 帧循环）
make_clip("walk", {
	"thigh_l": [(1, -20, 0, 0), (13, 20, 0, 0), (25, -20, 0, 0)],
	"thigh_r": [(1, 20, 0, 0), (13, -20, 0, 0), (25, 20, 0, 0)],
	"shin_l": [(1, 6, 0, 0), (7, 24, 0, 0), (13, 6, 0, 0), (19, 16, 0, 0), (25, 6, 0, 0)],
	"shin_r": [(1, 24, 0, 0), (7, 6, 0, 0), (13, 16, 0, 0), (19, 6, 0, 0), (25, 24, 0, 0)],
	"spine": [(1, 4, 0, 5), (13, 4, 0, -5), (25, 4, 0, 5)],
	"arm_l": [(1, 14, 0, 8), (13, -14, 0, 8), (25, 14, 0, 8)],
	"arm_r": [(1, -14, 0, -8), (13, 14, 0, -8), (25, -14, 0, -8)],
}, loc_keys={"spine": [(1, 0, 0, -0.05), (7, 0, 0, 0.03), (13, 0, 0, -0.05), (19, 0, 0, 0.03), (25, 0, 0, -0.05)]})

# stomp：双拳高举猛砸（14 帧）
make_clip("stomp", {
	"arm_l": [(1, 0, 0, 4), (5, -150, 0, 25), (9, 55, 0, 5), (14, 0, 0, 4)],
	"arm_r": [(1, 0, 0, -4), (5, -150, 0, -25), (9, 55, 0, -5), (14, 0, 0, -4)],
	"forearm_l": [(1, 0, 0, 0), (5, -45, 0, 0), (9, 15, 0, 0), (14, 0, 0, 0)],
	"forearm_r": [(1, 0, 0, 0), (5, -45, 0, 0), (9, 15, 0, 0), (14, 0, 0, 0)],
	"spine": [(1, 0, 0, 0), (5, -18, 0, 0), (9, 26, 0, 0), (14, 0, 0, 0)],
	"head": [(1, 0, 0, 0), (5, -12, 0, 0), (9, 18, 0, 0), (14, 0, 0, 0)],
}, loc_keys={"spine": [(1, 0, 0, 0), (5, 0, 0, 0.15), (9, 0, 0, -0.22), (14, 0, 0, 0)]})

# throw：单臂捞石抡出（16 帧）
make_clip("throw", {
	"arm_r": [(1, 0, 0, -4), (5, 45, 0, -30), (9, -135, 0, -15), (12, -120, 0, -12), (16, 0, 0, -4)],
	"forearm_r": [(1, 0, 0, 0), (5, -30, 0, 0), (9, -50, 0, 0), (12, -20, 0, 0), (16, 0, 0, 0)],
	"arm_l": [(1, 0, 0, 4), (9, -40, 0, 35), (16, 0, 0, 4)],
	"spine": [(1, 0, 0, 0), (5, 8, -14, 0), (9, -6, 16, 0), (12, -4, 12, 0), (16, 0, 0, 0)],
})

# stagger：护目跪地（16 帧）
make_clip("stagger", {
	"spine": [(1, 0, 0, 0), (5, 22, 0, 0), (16, 20, 0, 0)],
	"head": [(1, 0, 0, 0), (5, 28, 0, 0), (16, 26, 0, 0)],
	"arm_l": [(1, 0, 0, 4), (5, -95, 0, 45), (16, -90, 0, 42)],
	"thigh_l": [(1, 0, 0, 0), (5, -70, 0, 0), (16, -68, 0, 0)],
	"shin_l": [(1, 0, 0, 0), (5, 85, 0, 0), (16, 82, 0, 0)],
	"thigh_r": [(1, 0, 0, 0), (5, 20, 0, 0), (16, 18, 0, 0)],
}, loc_keys={"spine": [(1, 0, 0, 0), (5, 0, 0, -0.55), (16, 0, 0, -0.52)]})

# hit：上身一晃（8 帧）
make_clip("hit", {
	"spine": [(1, 0, 0, 0), (3, -10, 0, 0), (8, 0, 0, 0)],
	"head": [(1, 0, 0, 0), (3, -14, 0, 0), (8, 0, 0, 0)],
})

# die：前扑倒地（24 帧，停在倒姿）
make_clip("die", {
	"spine": [(1, 0, 0, 0), (8, 40, 0, 0), (16, 72, 0, 0), (24, 76, 0, 0)],
	"head": [(1, 0, 0, 0), (8, 20, 0, 0), (16, 30, 0, 0), (24, 32, 0, 0)],
	"arm_l": [(1, 0, 0, 4), (8, -30, 0, 40), (16, -50, 0, 55), (24, -52, 0, 58)],
	"arm_r": [(1, 0, 0, -4), (8, -30, 0, -40), (16, -50, 0, -55), (24, -52, 0, -58)],
}, loc_keys={"spine": [(1, 0, 0, 0), (8, 0, 0, -0.5), (16, 0, 0, -1.3), (24, 0, 0, -1.35)]})

reset_pose()
scene = bpy.context.scene
scene.render.fps = 24
root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
out = os.path.join(root, OUT)
os.makedirs(os.path.dirname(out), exist_ok=True)
bpy.ops.export_scene.gltf(filepath=out, export_format='GLB', export_animations=True, export_animation_mode='NLA_TRACKS')
print("[hinox] exported:", out)
