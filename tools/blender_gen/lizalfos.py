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


# 前伏长身、背鳍、长尾、后掠双角（面向 -Y）
parts = []
parts.append(sphere("body", (0, 0.10, 0.72), (0.43, 0.72, 0.36), SKIN))
parts.append(sphere("belly", (0, -0.35, 0.62), (0.27, 0.37, 0.22), BELLY))
parts.append(sphere("head", (0, -0.72, 0.92), (0.27, 0.35, 0.24), SKIN))
parts.append(sphere("snout", (0, -1.02, 0.86), (0.12, 0.09, 0.06), DARK))
for sx in [-1, 1]:
	parts.append(sphere("eye", (sx * 0.14, -0.90, 0.98), (0.045, 0.032, 0.045), DARK))
	parts.append(cone("horn", (sx * 0.12, -0.58, 1.12), 0.05, 0.012, 0.42, BELLY, rot=(math.radians(-118), sx * math.radians(-14), 0)))
for i in range(4):
	parts.append(box("fin", (0, -0.25 + i * 0.28, 1.06 - i * 0.06), (0.06, 0.14, 0.30 - i * 0.04), DARK, rot=(math.radians(-18), 0, 0)))
parts.append(cone("tail", (0, 1.05, 0.60), 0.12, 0.06, 1.30, SKIN, rot=(math.radians(-70), 0, 0)))
for sx in [-1, 1]:
	parts.append(cone("arm", (sx * 0.40, -0.18, 0.60), 0.065, 0.05, 0.52, SKIN, rot=(math.radians(24), 0, sx * math.radians(10))))
	parts.append(box("claw", (sx * 0.43, -0.26, 0.36), (0.10, 0.14, 0.06), DARK))
	parts.append(cone("leg", (sx * 0.28, 0.15, 0.28), 0.10, 0.07, 0.56, SKIN))

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
