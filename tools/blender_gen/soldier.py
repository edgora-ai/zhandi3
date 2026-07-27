# 战场士兵：无头 Blender 生成蒙皮士兵与动画（idle/walk/run/fight/death），导出 glb。
# 运行：/Applications/Blender.app/Contents/MacOS/Blender --background --python tools/blender_gen/soldier.py
import bpy
import math
import os

OUT = "assets/models/soldier.glb"

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


SKIN = mat("soldier_skin", (0.87, 0.70, 0.55))
JACKET = mat("soldier_jacket", (0.40, 0.45, 0.30))
PANTS = mat("soldier_pants", (0.28, 0.31, 0.20))
GEAR = mat("soldier_gear", (0.22, 0.24, 0.16))
VEST = mat("soldier_vest", (0.55, 0.46, 0.30))
PACK = mat("soldier_pack", (0.36, 0.34, 0.26))
HELMET = mat("soldier_helmet", (0.30, 0.33, 0.26))
DARK = mat("soldier_dark", (0.14, 0.15, 0.17))
BOOTS = mat("soldier_boots", (0.16, 0.14, 0.12))
WHITE = mat("soldier_white", (0.96, 0.96, 0.94))


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


# 战术装备：背心弹匣袋、背包、头盔（面向 -Y）
parts = []
parts.append(box("pelvis", (0, 0, 0.76), (0.34, 0.27, 0.24), PANTS))
parts.append(sphere("torso", (0, 0, 1.10), (0.29, 0.26, 0.36), JACKET))
parts.append(box("vest", (0, -0.02, 1.16), (0.42, 0.33, 0.42), VEST))
for i in range(3):
	parts.append(box("mag", (-0.11 + i * 0.11, -0.19, 1.13), (0.09, 0.06, 0.13), DARK))
parts.append(box("backpack", (0, 0.28, 1.18), (0.36, 0.18, 0.44), PACK))
parts.append(box("pack_flap", (0, 0.28, 1.43), (0.30, 0.16, 0.10), DARK))
parts.append(box("belt", (0, 0, 0.86), (0.40, 0.32, 0.09), DARK))
parts.append(sphere("head", (0, 0, 1.58), (0.21, 0.20, 0.23), SKIN))
for sx in [-1, 1]:
	parts.append(sphere("eye_w", (sx * 0.078, -0.155, 1.60), (0.045, 0.026, 0.058), WHITE))
	parts.append(sphere("eye", (sx * 0.078, -0.175, 1.595), (0.024, 0.013, 0.032), DARK))
	parts.append(box("brow", (sx * 0.078, -0.165, 1.685), (0.075, 0.02, 0.018), DARK))
parts.append(sphere("nose", (0, -0.20, 1.55), (0.04, 0.03, 0.05), SKIN))
parts.append(sphere("helmet", (0, 0, 1.68), (0.25, 0.24, 0.19), HELMET))
parts.append(box("helm_band", (0, 0, 1.635), (0.27, 0.26, 0.032), DARK))
parts.append(cone("brim", (0, 0, 1.615), 0.265, 0.265, 0.035, HELMET))
for sx in [-1, 1]:
	parts.append(sphere("shoulder", (sx * 0.43, 0, 1.36), (0.09, 0.09, 0.08), GEAR))
	parts.append(cone("upperarm", (sx * 0.43, 0, 1.18), 0.080, 0.065, 0.34, JACKET))
	parts.append(cone("forearm", (sx * 0.43, 0, 0.90), 0.068, 0.055, 0.32, JACKET))
	parts.append(sphere("hand", (sx * 0.43, 0, 0.74), (0.062, 0.055, 0.062), SKIN))
	parts.append(cone("thigh", (sx * 0.15, 0, 0.55), 0.105, 0.085, 0.38, PANTS))
	parts.append(box("kneepad", (sx * 0.15, -0.07, 0.38), (0.14, 0.08, 0.12), GEAR))
	parts.append(cone("shin", (sx * 0.15, 0, 0.20), 0.082, 0.065, 0.34, PANTS))
	parts.append(box("boot", (sx * 0.15, -0.04, 0.045), (0.15, 0.28, 0.10), BOOTS))
# 步枪：机匣 + 枪管 + 弹匣 + 枪托（挂右手）
parts.append(box("receiver", (0.43, -0.14, 0.82), (0.07, 0.44, 0.11), DARK))
parts.append(cone("barrel", (0.43, -0.46, 0.84), 0.018, 0.018, 0.24, DARK, rot=(math.radians(90), 0, 0)))
parts.append(box("mag_rifle", (0.43, -0.04, 0.72), (0.05, 0.06, 0.13), GEAR))
parts.append(box("stock", (0.43, 0.13, 0.80), (0.06, 0.14, 0.09), PACK))

for p in parts:
	p.select_set(True)
bpy.context.view_layer.objects.active = parts[0]
bpy.ops.object.join()
body = parts[0]
body.name = "SoldierBody"

# 骨骼：髋/脊柱/头 + 双臂双节 + 双腿双节
bpy.ops.object.armature_add(enter_editmode=True, location=(0, 0, 0))
arm = bpy.context.active_object
arm.name = "SoldierRig"
eb = arm.data.edit_bones
base = eb[0]
base.name = "hips"
base.head = (0, 0, 0.75)
base.tail = (0, 0, 1.05)


def bone(name, head, tail, parent):
	b = eb.new(name)
	b.head = head
	b.tail = tail
	b.parent = eb[parent]
	return b


bone("spine", (0, 0, 1.05), (0, 0, 1.45), "hips")
bone("head", (0, 0, 1.45), (0, 0, 1.80), "spine")
for sx, stag in [(-1, "l"), (1, "r")]:
	bone("upperarm_" + stag, (sx * 0.30, 0, 1.38), (sx * 0.43, 0, 1.10), "spine")
	bone("forearm_" + stag, (sx * 0.43, 0, 1.10), (sx * 0.43, 0, 0.85), "upperarm_" + stag)
	bone("thigh_" + stag, (sx * 0.15, 0, 0.74), (sx * 0.15, 0, 0.38), "hips")
	bone("shin_" + stag, (sx * 0.15, 0, 0.38), (sx * 0.15, 0, 0.05), "thigh_" + stag)
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

# idle：持枪低准备位呼吸（49 帧循环）
make_clip("idle", {
	"spine": [(1, 0, 0, 0), (25, 1.8, 0, 0), (49, 0, 0, 0)],
	"head": [(1, 0, 0, 0), (13, 0, 8, 0), (25, 0, 0, 0), (37, 0, -8, 0), (49, 0, 0, 0)],
	"upperarm_r": [(1, 10, 0, -6), (25, 12, 0, -6), (49, 10, 0, -6)],
	"forearm_r": [(1, -35, 0, 0), (25, -38, 0, 0), (49, -35, 0, 0)],
	"upperarm_l": [(1, 8, 0, 6), (25, 10, 0, 6), (49, 8, 0, 6)],
}, loc_keys={"hips": [(1, 0, 0, 0), (25, 0, 0, -0.015), (49, 0, 0, 0)]})

# walk：巡逻走步（25 帧循环）
make_clip("walk", {
	"thigh_l": [(1, -26, 0, 0), (13, 26, 0, 0), (25, -26, 0, 0)],
	"thigh_r": [(1, 26, 0, 0), (13, -26, 0, 0), (25, 26, 0, 0)],
	"shin_l": [(1, 6, 0, 0), (7, 36, 0, 0), (13, 6, 0, 0), (19, 20, 0, 0), (25, 6, 0, 0)],
	"shin_r": [(1, 36, 0, 0), (7, 6, 0, 0), (13, 20, 0, 0), (19, 6, 0, 0), (25, 36, 0, 0)],
	"upperarm_l": [(1, 18, 0, 5), (13, -18, 0, 5), (25, 18, 0, 5)],
	"upperarm_r": [(1, -14, 0, -6), (13, 18, 0, -6), (25, -14, 0, -6)],
	"forearm_r": [(1, -35, 0, 0), (25, -35, 0, 0)],
}, loc_keys={"hips": [(1, 0, 0, -0.02), (7, 0, 0, 0.015), (13, 0, 0, -0.02), (19, 0, 0, 0.015), (25, 0, 0, -0.02)]})

# run：大步奔跑、身体前倾、枪贴身（17 帧循环）
make_clip("run", {
	"thigh_l": [(1, -38, 0, 0), (9, 38, 0, 0), (17, -38, 0, 0)],
	"thigh_r": [(1, 38, 0, 0), (9, -38, 0, 0), (17, 38, 0, 0)],
	"shin_l": [(1, 12, 0, 0), (5, 60, 0, 0), (9, 12, 0, 0), (13, 45, 0, 0), (17, 12, 0, 0)],
	"shin_r": [(1, 60, 0, 0), (5, 12, 0, 0), (9, 45, 0, 0), (13, 12, 0, 0), (17, 60, 0, 0)],
	"spine": [(1, 12, 0, 0), (9, 14, 0, 0), (17, 12, 0, 0)],
	"upperarm_l": [(1, 30, 0, 5), (9, -30, 0, 5), (17, 30, 0, 5)],
	"upperarm_r": [(1, -24, 0, -8), (9, 28, 0, -8), (17, -24, 0, -8)],
	"forearm_r": [(1, -45, 0, 0), (17, -45, 0, 0)],
	"head": [(1, -6, 0, 0), (17, -6, 0, 0)],
}, loc_keys={"hips": [(1, 0, 0, -0.03), (5, 0, 0, 0.03), (9, 0, 0, -0.03), (13, 0, 0, 0.03), (17, 0, 0, -0.03)]})

# fight：端枪瞄准站姿（9 帧循环微动）
make_clip("fight", {
	"upperarm_r": [(1, -68, 0, -12), (5, -70, 0, -12), (9, -68, 0, -12)],
	"forearm_r": [(1, -22, 0, 0), (5, -24, 0, 0), (9, -22, 0, 0)],
	"upperarm_l": [(1, -52, 0, 32), (5, -54, 0, 32), (9, -52, 0, 32)],
	"forearm_l": [(1, -48, 0, 0), (5, -50, 0, 0), (9, -48, 0, 0)],
	"spine": [(1, 5, 0, 0), (5, 6, 0, 0), (9, 5, 0, 0)],
	"thigh_l": [(1, -8, 0, 0), (9, -8, 0, 0)],
	"thigh_r": [(1, 10, 0, 0), (9, 10, 0, 0)],
})

# death：中弹后仰倒地（25 帧，停在倒姿）
make_clip("death", {
	"hips": [(1, 0, 0, 0), (7, -55, 0, 0), (16, -82, 0, 0), (25, -84, 0, 0)],
	"spine": [(1, 0, 0, 0), (7, -18, 0, 0), (16, -8, 0, 0), (25, -8, 0, 0)],
	"head": [(1, 0, 0, 0), (7, -25, 0, 0), (16, -12, 0, 0), (25, -12, 0, 0)],
	"upperarm_l": [(1, 0, 0, 6), (7, -50, 0, 40), (16, -20, 0, 60), (25, -20, 0, 60)],
	"upperarm_r": [(1, 10, 0, -6), (7, -50, 0, -40), (16, -20, 0, -60), (25, -20, 0, -60)],
	"thigh_l": [(1, 0, 0, 0), (7, 20, 0, 0), (16, 8, 0, 0), (25, 8, 0, 0)],
	"thigh_r": [(1, 0, 0, 0), (7, 26, 0, 0), (16, 12, 0, 0), (25, 12, 0, 0)],
}, loc_keys={"hips": [(1, 0, 0, 0), (7, 0, 0, -0.30), (16, 0, 0, -0.68), (25, 0, 0, -0.68)]})

reset_pose()
scene = bpy.context.scene
scene.render.fps = 24
root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
out = os.path.join(root, OUT)
os.makedirs(os.path.dirname(out), exist_ok=True)
bpy.ops.export_scene.gltf(filepath=out, export_format='GLB', export_animations=True, export_animation_mode='NLA_TRACKS')
print("[soldier] exported:", out)
