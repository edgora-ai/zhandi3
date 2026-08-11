# 蜥蜴战士：无头 Blender 生成蒙皮蜥蜴与动画（idle/strafe/dash/hit/die），导出 glb。
# 运行：/Applications/Blender.app/Contents/MacOS/Blender --background --python tools/blender_gen/lizalfos.py
import bpy
import math
import os

OUT = "assets/models/lizalfos.glb"

bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)


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


SKIN = mat("liz_skin", (0.35, 0.62, 0.30))
BELLY = mat("liz_belly", (0.82, 0.78, 0.50))
DARK = mat("liz_dark", (0.10, 0.12, 0.08))
EYE = mat("liz_eye", (0.95, 0.76, 0.12))
CREST = mat("liz_crest", (0.12, 0.34, 0.22))
CLOTH = mat("liz_cloth", (0.18, 0.36, 0.48))
WOOD = mat("liz_wood", (0.30, 0.18, 0.08))
BONE = mat("liz_bone", (0.90, 0.84, 0.62))


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


def cyl(name, loc, r1, r2, depth, material, rot=(0, 0, 0)):
	return cone(name, loc, r1, r2, depth, material, rot)


# 前伏长身、背鳍、长尾、后掠双角（面向 -Y）
parts = []
parts.append(sphere("body", (0, 0.10, 0.72), (0.43, 0.72, 0.36), SKIN))
parts.append(sphere("belly", (0, -0.35, 0.62), (0.27, 0.37, 0.22), BELLY))
parts.append(sphere("head", (0, -0.72, 0.92), (0.27, 0.35, 0.24), SKIN))
# 分层长吻、下颌与鼻孔，避免头部只剩一个黑鼻球。
parts.append(sphere("snout", (0, -1.00, 0.87), (0.18, 0.17, 0.105), SKIN))
parts.append(box("jaw", (0, -1.01, 0.79), (0.17, 0.18, 0.055), BELLY, rot=(math.radians(-5), 0, 0)))
parts.append(box("mouth", (0, -1.175, 0.82), (0.15, 0.018, 0.025), DARK))
for sx in [-1, 1]:
	parts.append(sphere("eye", (sx * 0.14, -0.91, 1.00), (0.060, 0.040, 0.060), EYE))
	parts.append(sphere("pupil", (sx * 0.14, -0.948, 1.00), (0.018, 0.012, 0.039), DARK))
	parts.append(sphere("nostril", (sx * 0.062, -1.155, 0.91), (0.018, 0.010, 0.013), DARK))
	parts.append(cone("horn", (sx * 0.12, -0.58, 1.12), 0.05, 0.012, 0.42, BELLY, rot=(math.radians(-118), sx * math.radians(-14), 0)))
for i in range(4):
	parts.append(box("fin", (0, -0.25 + i * 0.28, 1.06 - i * 0.06), (0.06, 0.14, 0.30 - i * 0.04), CREST, rot=(math.radians(-18), 0, 0)))
parts.append(cone("tail", (0, 1.05, 0.60), 0.12, 0.06, 1.30, SKIN, rot=(math.radians(-70), 0, 0)))
# 腹甲片、腰巾与臂环建立装备层级。
for i in range(4):
	parts.append(box("belly_plate", (0, -0.445 + i * 0.16, 0.67 - i * 0.018), (0.25 - i * 0.018, 0.09, 0.045), BELLY, rot=(math.radians(8), 0, 0)))
parts.append(box("belt", (0, 0.18, 0.58), (0.44, 0.32, 0.075), DARK))
parts.append(box("loincloth", (0, -0.12, 0.42), (0.25, 0.055, 0.30), CLOTH, rot=(math.radians(-12), 0, 0)))
for sx in [-1, 1]:
	parts.append(cone("arm", (sx * 0.40, -0.18, 0.60), 0.065, 0.05, 0.52, SKIN, rot=(math.radians(24), 0, sx * math.radians(10))))
	parts.append(cyl("arm_band", (sx * 0.40, -0.18, 0.53), 0.082, 0.082, 0.09, CLOTH, rot=(math.radians(24), 0, sx * math.radians(10))))
	parts.append(sphere("hand", (sx * 0.43, -0.28, 0.35), (0.115, 0.15, 0.07), SKIN))
	for claw_i in [-1, 0, 1]:
		parts.append(cone("finger_claw", (sx * 0.43 + claw_i * 0.038, -0.405, 0.34), 0.018, 0.003, 0.13, BONE, rot=(math.radians(90), 0, 0)))
	parts.append(cone("leg", (sx * 0.28, 0.15, 0.28), 0.10, 0.07, 0.56, SKIN))
	parts.append(sphere("foot", (sx * 0.28, -0.02, 0.06), (0.16, 0.27, 0.08), DARK))
	for claw_i in [-1, 0, 1]:
		parts.append(cone("toe", (sx * 0.28 + claw_i * 0.050, -0.25, 0.06), 0.020, 0.003, 0.16, BONE, rot=(math.radians(90), 0, 0)))

# 轻型骨矛随右臂蒙皮，突进时让攻击方向一眼可读。
parts.append(cyl("spear_shaft", (0.46, -0.42, 0.62), 0.025, 0.025, 1.45, WOOD, rot=(math.radians(90), 0, 0)))
parts.append(cone("spear_tip", (0.46, -1.17, 0.62), 0.085, 0.008, 0.36, BONE, rot=(math.radians(90), 0, 0)))
parts.append(box("spear_wrap", (0.46, -0.92, 0.62), (0.045, 0.11, 0.045), CLOTH))

for p in parts:
	p.select_set(True)
bpy.context.view_layer.objects.active = parts[0]
bpy.ops.object.join()
body = parts[0]
body.name = "LizBody"

# 骨骼：脊柱/颈/头/尾两节 + 双腿双节 + 双臂双节
bpy.ops.object.armature_add(enter_editmode=True, location=(0, 0, 0))
arm = bpy.context.active_object
arm.name = "LizRig"
eb = arm.data.edit_bones
base = eb[0]
base.name = "spine"
base.head = (0, 0.05, 0.55)
base.tail = (0, -0.45, 0.80)


def bone(name, head, tail, parent):
	b = eb.new(name)
	b.head = head
	b.tail = tail
	b.parent = eb[parent]
	return b


bone("neck", (0, -0.45, 0.80), (0, -0.72, 0.92), "spine")
bone("head", (0, -0.72, 0.92), (0, -1.05, 0.90), "neck")
bone("tail1", (0, 0.75, 0.65), (0, 1.30, 0.45), "spine")
bone("tail2", (0, 1.30, 0.45), (0, 1.85, 0.25), "tail1")
for sx, stag in [(-1, "l"), (1, "r")]:
	bone("thigh_" + stag, (sx * 0.28, 0.15, 0.55), (sx * 0.28, 0.15, 0.28), "spine")
	bone("shin_" + stag, (sx * 0.28, 0.15, 0.28), (sx * 0.28, 0.13, 0.05), "thigh_" + stag)
	bone("arm_" + stag, (sx * 0.30, -0.10, 0.75), (sx * 0.40, -0.18, 0.50), "spine")
	bone("forearm_" + stag, (sx * 0.40, -0.18, 0.50), (sx * 0.43, -0.26, 0.30), "arm_" + stag)
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

# idle：尾波摆动、呼吸、头探望（49 帧循环）
make_clip("idle", {
	"tail1": [(1, 0, 10, 0), (25, 0, -10, 0), (49, 0, 10, 0)],
	"tail2": [(1, 0, 16, 0), (25, 0, -16, 0), (49, 0, 16, 0)],
	"neck": [(1, 0, 0, 0), (25, 3, 0, 0), (49, 0, 0, 0)],
	"head": [(1, 0, 0, 0), (13, 0, 8, 0), (25, 0, 0, 0), (37, 0, -8, 0), (49, 0, 0, 0)],
}, loc_keys={"spine": [(1, 0, 0, 0), (25, 0, 0, -0.02), (49, 0, 0, 0)]})

# strafe：快速碎步游走（17 帧循环）
make_clip("strafe", {
	"thigh_l": [(1, -30, 0, 0), (9, 30, 0, 0), (17, -30, 0, 0)],
	"thigh_r": [(1, 30, 0, 0), (9, -30, 0, 0), (17, 30, 0, 0)],
	"shin_l": [(1, 10, 0, 0), (5, 40, 0, 0), (9, 10, 0, 0), (13, 30, 0, 0), (17, 10, 0, 0)],
	"shin_r": [(1, 40, 0, 0), (5, 10, 0, 0), (9, 30, 0, 0), (13, 10, 0, 0), (17, 40, 0, 0)],
	"arm_l": [(1, 12, 0, 0), (9, -12, 0, 0), (17, 12, 0, 0)],
	"arm_r": [(1, -12, 0, 0), (9, 12, 0, 0), (17, -12, 0, 0)],
	"tail1": [(1, 0, 8, 0), (9, 0, -8, 0), (17, 0, 8, 0)],
}, loc_keys={"spine": [(1, 0, 0, 0), (5, 0, 0, -0.035), (9, 0, 0, 0), (13, 0, 0, -0.035), (17, 0, 0, 0)]})

# prepare：突进前压低重心、尾巴反向蓄力，和脚下预警环同步。
make_clip("prepare", {
	"spine": [(1, 0, 0, 0), (7, -12, 0, 0), (13, -18, 0, 0)],
	"neck": [(1, 0, 0, 0), (7, 10, 0, 0), (13, 16, 0, 0)],
	"head": [(1, 0, 0, 0), (7, 6, 0, 0), (13, 10, 0, 0)],
	"thigh_l": [(1, 0, 0, 0), (13, 36, 0, -8)],
	"thigh_r": [(1, 0, 0, 0), (13, 36, 0, 8)],
	"shin_l": [(1, 0, 0, 0), (13, 48, 0, 0)],
	"shin_r": [(1, 0, 0, 0), (13, 48, 0, 0)],
	"arm_l": [(1, 0, 0, 0), (13, -22, 0, -18)],
	"arm_r": [(1, 0, 0, 0), (13, -32, 0, 16)],
	"tail1": [(1, 0, 0, 0), (7, 0, 20, 0), (13, 0, 34, 0)],
	"tail2": [(1, 0, 0, 0), (7, 0, 28, 0), (13, 0, 46, 0)],
}, loc_keys={"spine": [(1, 0, 0, 0), (7, 0, 0.08, -0.06), (13, 0, 0.12, -0.12)]})

# dash：突进——身体绷直前扑、双腿后甩、双臂后掠、尾拉直（13 帧）
make_clip("dash", {
	"spine": [(1, 0, 0, 0), (4, 22, 0, 0), (13, 20, 0, 0)],
	"neck": [(1, 0, 0, 0), (4, 16, 0, 0), (13, 14, 0, 0)],
	"head": [(1, 0, 0, 0), (4, 12, 0, 0), (13, 10, 0, 0)],
	"thigh_l": [(1, 0, 0, 0), (4, -42, 0, 0), (13, -40, 0, 0)],
	"thigh_r": [(1, 0, 0, 0), (4, -38, 0, 0), (13, -36, 0, 0)],
	"shin_l": [(1, 0, 0, 0), (4, 30, 0, 0), (13, 28, 0, 0)],
	"shin_r": [(1, 0, 0, 0), (4, 26, 0, 0), (13, 24, 0, 0)],
	"arm_l": [(1, 0, 0, 0), (4, -48, 0, -10), (13, -45, 0, -10)],
	"arm_r": [(1, 0, 0, 0), (4, -48, 0, 10), (13, -45, 0, 10)],
	"tail1": [(1, 0, 0, 0), (4, -18, 0, 0), (13, -16, 0, 0)],
	"tail2": [(1, 0, 0, 0), (4, -12, 0, 0), (13, -10, 0, 0)],
}, loc_keys={"spine": [(1, 0, 0, 0), (4, 0, -0.20, 0.02), (13, 0, -0.20, 0.02)]})

# hit：受击后仰（8 帧）
make_clip("hit", {
	"spine": [(1, 0, 0, 0), (3, -14, 0, 0), (8, 0, 0, 0)],
	"neck": [(1, 0, 0, 0), (3, -18, 0, 0), (8, 0, 0, 0)],
})

# die：前扑瘫倒、尾蜷曲（21 帧，停在倒姿）
make_clip("die", {
	"spine": [(1, 0, 0, 0), (7, 55, 0, 0), (21, 58, 0, 0)],
	"neck": [(1, 0, 0, 0), (7, 30, 0, 0), (21, 32, 0, 0)],
	"thigh_l": [(1, 0, 0, 0), (7, 60, 0, 0), (21, 62, 0, 0)],
	"thigh_r": [(1, 0, 0, 0), (7, 55, 0, 0), (21, 57, 0, 0)],
	"shin_l": [(1, 0, 0, 0), (7, 70, 0, 0), (21, 72, 0, 0)],
	"shin_r": [(1, 0, 0, 0), (7, 66, 0, 0), (21, 68, 0, 0)],
	"tail1": [(1, 0, 0, 0), (7, 0, 35, 0), (21, 0, 38, 0)],
	"tail2": [(1, 0, 0, 0), (7, 0, 50, 0), (21, 0, 55, 0)],
}, loc_keys={"spine": [(1, 0, 0, 0), (7, 0, 0, -0.30), (21, 0, 0, -0.32)]})

reset_pose()
scene = bpy.context.scene
scene.render.fps = 24
root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
out = os.path.join(root, OUT)
os.makedirs(os.path.dirname(out), exist_ok=True)
bpy.ops.export_scene.gltf(filepath=out, export_format='GLB', export_animations=True, export_animation_mode='NLA_TRACKS')
print("[lizalfos] exported:", out)
