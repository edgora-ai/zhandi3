# 维佐法师：无头 Blender 生成蒙皮法师与动画（hover/cast/hit/die），导出 glb。
# 运行：/Applications/Blender.app/Contents/MacOS/Blender --background --python tools/blender_gen/wizzrobe.py
import bpy
import math
import os

OUT = "assets/models/wizzrobe.glb"

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
			bsdf.inputs["Emission Strength"].default_value = 2.4
	return m


ROBE = mat("wizz_robe", (0.42, 0.16, 0.45))
ROBE_D = mat("wizz_robe_dark", (0.24, 0.08, 0.28))
SKIN = mat("wizz_skin", (0.75, 0.62, 0.50))
ORB = mat("wizz_orb", (1.0, 0.45, 0.10), emit=(1.0, 0.30, 0.05))
EYE = mat("wizz_eye", (1.0, 0.85, 0.20), emit=(1.0, 0.70, 0.08))
DARK = mat("wizz_dark", (0.10, 0.06, 0.12))


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
	bpy.ops.mesh.primitive_cone_add(vertices=9, radius1=r1, radius2=r2, depth=depth, location=loc, rotation=rot)
	o = bpy.context.active_object
	o.name = name
	o.data.materials.append(material)
	return o


# 悬浮锥形袍（无腿）、尖顶帽、悬浮双手、火球法杖（面向 -Y）
parts = []
parts.append(cone("robe", (0, 0, 0.75), 0.52, 0.22, 1.30, ROBE))
parts.append(sphere("chest", (0, 0, 1.32), (0.30, 0.26, 0.34), ROBE))
parts.append(box("trim", (0, 0, 0.45), (0.56, 0.56, 0.08), ROBE_D))
parts.append(sphere("head", (0, -0.02, 1.62), (0.20, 0.19, 0.22), SKIN))
for sx in [-1, 1]:
	parts.append(sphere("eye", (sx * 0.07, -0.185, 1.64), (0.035, 0.024, 0.040), EYE))
parts.append(cone("hat", (0, 0.03, 1.92), 0.26, 0.015, 0.52, ROBE_D, rot=(math.radians(-10), 0, 0)))
parts.append(cone("brim", (0, 0.01, 1.76), 0.30, 0.30, 0.05, ROBE))
for sx in [-1, 1]:
	parts.append(sphere("hand", (sx * 0.38, -0.05, 1.10), (0.075, 0.065, 0.075), SKIN))
parts.append(cone("sleeve", (sx * 0.30, 0, 1.22), 0.10, 0.06, 0.34, ROBE, rot=(0, sx * math.radians(-30), 0)))
# 法杖：长杆 + 顶端火球
parts.append(cone("staff", (0.42, -0.10, 1.05), 0.025, 0.025, 1.30, DARK, rot=(math.radians(12), 0, 0)))
parts.append(sphere("orb", (0.55, -0.24, 1.62), (0.11, 0.11, 0.11), ORB))

for p in parts:
	p.select_set(True)
bpy.context.view_layer.objects.active = parts[0]
bpy.ops.object.join()
body = parts[0]
body.name = "WizzBody"

# 骨骼：袍根/胸/头 + 双臂 + 杖臂
bpy.ops.object.armature_add(enter_editmode=True, location=(0, 0, 0))
arm = bpy.context.active_object
arm.name = "WizzRig"
eb = arm.data.edit_bones
base = eb[0]
base.name = "robe"
base.head = (0, 0, 0.30)
base.tail = (0, 0, 1.05)


def bone(name, head, tail, parent):
	b = eb.new(name)
	b.head = head
	b.tail = tail
	b.parent = eb[parent]
	return b


bone("chest", (0, 0, 1.05), (0, 0, 1.45), "robe")
bone("head", (0, 0, 1.45), (0, 0, 1.78), "chest")
bone("arm_l", (-0.20, 0, 1.35), (-0.38, -0.05, 1.12), "chest")
bone("arm_r", (0.20, 0, 1.35), (0.40, -0.08, 1.14), "chest")
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

# hover：悬浮起伏 + 袍摆轻摆 + 双手微浮（49 帧循环）
make_clip("hover", {
	"chest": [(1, 2, 0, 0), (25, -2, 0, 0), (49, 2, 0, 0)],
	"head": [(1, 0, 0, 0), (25, 0, 5, 0), (49, 0, 0, 0)],
	"arm_l": [(1, 0, 0, 10), (25, 0, 0, 16), (49, 0, 0, 10)],
	"arm_r": [(1, 0, 0, -8), (25, 0, 0, -14), (49, 0, 0, -8)],
}, loc_keys={"robe": [(1, 0, 0, 0), (25, 0, 0, 0.10), (49, 0, 0, 0)]})

# cast：杖臂高举施法，身体后仰（14 帧）
make_clip("cast", {
	"arm_r": [(1, 0, 0, -8), (5, -125, 0, -20), (10, -120, 0, -18), (14, 0, 0, -8)],
	"arm_l": [(1, 0, 0, 10), (5, -45, 0, 25), (10, -40, 0, 22), (14, 0, 0, 10)],
	"chest": [(1, 0, 0, 0), (5, -12, 0, 0), (10, -10, 0, 0), (14, 0, 0, 0)],
	"head": [(1, 0, 0, 0), (5, -8, 0, 0), (14, 0, 0, 0)],
}, loc_keys={"robe": [(1, 0, 0, 0), (5, 0, 0, 0.14), (14, 0, 0, 0)]})

# hit：受击后仰（8 帧）
make_clip("hit", {
	"chest": [(1, 0, 0, 0), (3, -16, 0, 0), (8, 0, 0, 0)],
	"head": [(1, 0, 0, 0), (3, -18, 0, 0), (8, 0, 0, 0)],
})

# die：法力溃散坠地（18 帧，停在倒姿）
make_clip("die", {
	"chest": [(1, 0, 0, 0), (7, 50, 0, 0), (18, 55, 0, 0)],
	"head": [(1, 0, 0, 0), (7, 25, 0, 0), (18, 28, 0, 0)],
	"arm_l": [(1, 0, 0, 10), (7, -30, 0, 50), (18, -32, 0, 55)],
	"arm_r": [(1, 0, 0, -8), (7, -30, 0, -50), (18, -32, 0, -55)],
}, loc_keys={"robe": [(1, 0, 0, 0), (7, 0, 0, -0.55), (18, 0, 0, -0.58)]})

reset_pose()
scene = bpy.context.scene
scene.render.fps = 24
root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
out = os.path.join(root, OUT)
os.makedirs(os.path.dirname(out), exist_ok=True)
bpy.ops.export_scene.gltf(filepath=out, export_format='GLB', export_animations=True, export_animation_mode='NLA_TRACKS')
print("[wizzrobe] exported:", out)
