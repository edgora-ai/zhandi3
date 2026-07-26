# 村民：无头 Blender 生成蒙皮村民与动画（idle/walk/talk/cower/sleep），三顶帽子挂头骨，导出 glb。
# 运行：/Applications/Blender.app/Contents/MacOS/Blender --background --python tools/blender_gen/villager.py
import bpy
import math
import os

OUT = "assets/models/villager.glb"

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


SKIN = mat("villager_skin", (0.92, 0.72, 0.55))
TUNIC = mat("villager_tunic", (0.45, 0.32, 0.55))
PANTS = mat("villager_pants", (0.42, 0.33, 0.24))
BOOTS = mat("villager_boots", (0.24, 0.17, 0.11))
HAIR = mat("villager_hair", (0.35, 0.22, 0.12))
STRAW = mat("villager_straw", (0.85, 0.70, 0.35))
DARK = mat("villager_dark", (0.16, 0.12, 0.10))
MOUTH = mat("villager_mouth", (0.50, 0.22, 0.18))
BLUSH = mat("villager_blush", (0.95, 0.55, 0.50))
WHITE = mat("villager_white", (0.96, 0.96, 0.94))


def sphere(name, loc, scale, material):
	bpy.ops.mesh.primitive_uv_sphere_add(segments=12, ring_count=8, radius=1.0, location=loc)
	o = bpy.context.active_object
	o.name = name
	o.scale = scale
	bpy.ops.object.transform_apply(scale=True)
	o.data.materials.append(material)
	return o


def box(name, loc, size, material):
	bpy.ops.mesh.primitive_cube_add(size=1.0, location=loc)
	o = bpy.context.active_object
	o.name = name
	o.scale = size
	bpy.ops.object.transform_apply(scale=True)
	o.data.materials.append(material)
	return o


def cone(name, loc, r1, r2, depth, material):
	bpy.ops.mesh.primitive_cone_add(vertices=10, radius1=r1, radius2=r2, depth=depth, location=loc)
	o = bpy.context.active_object
	o.name = name
	o.data.materials.append(material)
	return o


def cyl(name, loc, radius, depth, material):
	bpy.ops.mesh.primitive_cylinder_add(vertices=9, radius=radius, depth=depth, location=loc)
	o = bpy.context.active_object
	o.name = name
	o.data.materials.append(material)
	return o


# 身体（面向 -Y）
parts = []
parts.append(sphere("torso", (0, 0, 1.18), (0.30, 0.26, 0.42), TUNIC))
parts.append(cone("skirt", (0, 0, 0.72), 0.44, 0.28, 0.55, TUNIC))
parts.append(cyl("belt", (0, 0, 0.98), 0.32, 0.09, DARK))
parts.append(sphere("head", (0, -0.02, 1.72), (0.21, 0.20, 0.23), SKIN))
parts.append(sphere("hair", (0, 0.07, 1.78), (0.20, 0.17, 0.19), HAIR))
for sx in [-1, 1]:
	parts.append(sphere("eye_w", (sx * 0.085, -0.185, 1.76), (0.048, 0.028, 0.062), WHITE))
	parts.append(sphere("eye", (sx * 0.085, -0.207, 1.755), (0.026, 0.014, 0.034), DARK))
	parts.append(box("brow", (sx * 0.085, -0.19, 1.85), (0.075, 0.02, 0.018), DARK))
	parts.append(sphere("blush", (sx * 0.14, -0.165, 1.67), (0.036, 0.014, 0.024), BLUSH))
	parts.append(sphere("ear", (sx * 0.21, -0.01, 1.72), (0.03, 0.045, 0.05), SKIN))
parts.append(sphere("nose", (0, -0.215, 1.70), (0.035, 0.028, 0.04), SKIN))
parts.append(box("mouth", (0, -0.20, 1.62), (0.07, 0.02, 0.014), MOUTH))
for sx in [-1, 1]:
	parts.append(cyl("upperarm", (sx * 0.26, 0, 1.25), 0.07, 0.30, TUNIC))
	parts.append(cyl("forearm", (sx * 0.26, 0, 0.95), 0.06, 0.26, TUNIC))
	parts.append(sphere("hand", (sx * 0.26, 0, 0.80), (0.07, 0.06, 0.07), SKIN))
	parts.append(cyl("leg", (sx * 0.11, 0, 0.45), 0.085, 0.50, PANTS))
	parts.append(box("boot", (sx * 0.11, -0.03, 0.06), (0.14, 0.24, 0.12), BOOTS))

for p in parts:
	p.select_set(True)
bpy.context.view_layer.objects.active = parts[0]
bpy.ops.object.join()
body = parts[0]
body.name = "VillagerBody"

# 骨骼：髋/脊柱/头 + 双臂双节 + 双腿双节
bpy.ops.object.armature_add(enter_editmode=True, location=(0, 0, 0))
arm = bpy.context.active_object
arm.name = "VillagerRig"
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
for sx, tag in [(-1.0, "l"), (1.0, "r")]:
	bone("upperarm_" + tag, (sx * 0.22, 0, 1.40), (sx * 0.26, 0, 1.10), "spine")
	bone("forearm_" + tag, (sx * 0.26, 0, 1.10), (sx * 0.26, 0, 0.82), "upperarm_" + tag)
	bone("thigh_" + tag, (sx * 0.11, 0, 0.78), (sx * 0.11, 0, 0.44), "hips")
	bone("shin_" + tag, (sx * 0.11, 0, 0.44), (sx * 0.11, 0, 0.06), "thigh_" + tag)
bpy.ops.object.mode_set(mode='OBJECT')

# 三顶帽子作为独立物体挂到 head 骨（Godot 侧按 hat_style 显隐）
hats = []
bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=0.38, depth=0.05, location=(0, 0, 1.90))
hats.append(bpy.context.active_object)
hats[-1].name = "hat_straw"
hats[-1].data.materials.append(STRAW)
bpy.ops.mesh.primitive_cylinder_add(vertices=10, radius=0.16, depth=0.12, location=(0, 0, 1.96))
straw_top = bpy.context.active_object
straw_top.data.materials.append(STRAW)
straw_top.parent = hats[-1]
hats.append(cone("hat_point", (0, 0, 2.10), 0.24, 0.02, 0.42, TUNIC))
bpy.ops.mesh.primitive_uv_sphere_add(segments=10, ring_count=6, radius=1.0, location=(0, 0, 1.82), scale=(0.24, 0.23, 0.16))
hats.append(bpy.context.active_object)
hats[-1].name = "hat_bandana"
hats[-1].data.materials.append(TUNIC)
for h in hats:
	h.select_set(False)
	h.parent = arm
	h.parent_type = 'BONE'
	h.parent_bone = "head"

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

# idle：呼吸起伏 + 头部偶尔轻转（48 帧循环）
make_clip("idle", {
	"spine": [(1, 0, 0, 0), (25, 1.8, 0, 0), (49, 0, 0, 0)],
	"head": [(1, 0, 0, 0), (13, 0, 8, 0), (25, -1.5, 0, 0), (37, 0, -8, 0), (49, 0, 0, 0)],
	"upperarm_l": [(1, 0, 0, 4), (25, 2.0, 0, 5), (49, 0, 0, 4)],
	"upperarm_r": [(1, 0, 0, -4), (25, 2.0, 0, -5), (49, 0, 0, -4)],
}, loc_keys={"hips": [(1, 0, 0, 0), (25, 0, 0, -0.02), (49, 0, 0, 0)]})

# walk：髋膝两级步态 + 手臂反摆 + 重心起伏（24 帧循环）
make_clip("walk", {
	"thigh_l": [(1, -28, 0, 0), (13, 28, 0, 0), (25, -28, 0, 0)],
	"thigh_r": [(1, 28, 0, 0), (13, -28, 0, 0), (25, 28, 0, 0)],
	"shin_l": [(1, 6, 0, 0), (7, 38, 0, 0), (13, 6, 0, 0), (19, 20, 0, 0), (25, 6, 0, 0)],
	"shin_r": [(1, 38, 0, 0), (7, 6, 0, 0), (13, 20, 0, 0), (19, 6, 0, 0), (25, 38, 0, 0)],
	"upperarm_l": [(1, 22, 0, 4), (13, -22, 0, 4), (25, 22, 0, 4)],
	"upperarm_r": [(1, -22, 0, -4), (13, 22, 0, -4), (25, -22, 0, -4)],
	"forearm_l": [(1, -10, 0, 0), (13, -22, 0, 0), (25, -10, 0, 0)],
	"forearm_r": [(1, -22, 0, 0), (13, -10, 0, 0), (25, -22, 0, 0)],
	"spine": [(1, 2, 0, 2.5), (13, 2, 0, -2.5), (25, 2, 0, 2.5)],
}, loc_keys={"hips": [(1, 0, 0, -0.02), (7, 0, 0, 0.02), (13, 0, 0, -0.02), (19, 0, 0, 0.02), (25, 0, 0, -0.02)]})

# talk：右手抬起比划 + 头部随语气点头（36 帧循环）
make_clip("talk", {
	"upperarm_r": [(1, -10, 0, -20), (9, -55, 0, -30), (18, -48, 0, -26), (27, -58, 0, -32), (36, -10, 0, -20)],
	"forearm_r": [(1, -20, 0, 0), (9, -55, 0, 0), (18, -40, 0, 0), (27, -60, 0, 0), (36, -20, 0, 0)],
	"head": [(1, 0, 0, 0), (9, 5, 0, 0), (18, -3, 4, 0), (27, 5, 0, 0), (36, 0, 0, 0)],
	"spine": [(1, 0, 0, 0), (18, 3, 0, 0), (36, 0, 0, 0)],
})

# cower：受惊抱头蹲下（20 帧循环，前后缓冲）
make_clip("cower", {
	"hips": [(1, 20, 0, 0), (10, 28, 0, 0), (20, 20, 0, 0)],
	"spine": [(1, 18, 0, 0), (10, 24, 0, 0), (20, 18, 0, 0)],
	"head": [(1, 25, 0, 0), (10, 32, 0, 0), (20, 25, 0, 0)],
	"upperarm_l": [(1, -120, 0, 30), (10, -135, 0, 35), (20, -120, 0, 30)],
	"upperarm_r": [(1, -120, 0, -30), (10, -135, 0, -35), (20, -120, 0, -30)],
	"forearm_l": [(1, -110, 0, 0), (10, -120, 0, 0), (20, -110, 0, 0)],
	"forearm_r": [(1, -110, 0, 0), (10, -120, 0, 0), (20, -110, 0, 0)],
	"thigh_l": [(1, -55, 0, 0), (10, -65, 0, 0), (20, -55, 0, 0)],
	"thigh_r": [(1, -55, 0, 0), (10, -65, 0, 0), (20, -55, 0, 0)],
	"shin_l": [(1, 70, 0, 0), (10, 80, 0, 0), (20, 70, 0, 0)],
	"shin_r": [(1, 70, 0, 0), (10, 80, 0, 0), (20, 70, 0, 0)],
}, loc_keys={"hips": [(1, 0, 0, -0.28), (10, 0, 0, -0.34), (20, 0, 0, -0.28)]})

# sleep：站立打盹，头一点点下垂又抬起（48 帧循环）
make_clip("sleep", {
	"spine": [(1, 8, 0, 0), (24, 14, 0, 0), (48, 8, 0, 0)],
	"head": [(1, 12, 0, 0), (24, 24, 0, 0), (48, 12, 0, 0)],
	"upperarm_l": [(1, 5, 0, 6), (24, 8, 0, 6), (48, 5, 0, 6)],
	"upperarm_r": [(1, 5, 0, -6), (24, 8, 0, -6), (48, 5, 0, -6)],
})

reset_pose()
scene = bpy.context.scene
scene.render.fps = 24
root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
out = os.path.join(root, OUT)
os.makedirs(os.path.dirname(out), exist_ok=True)
bpy.ops.export_scene.gltf(filepath=out, export_format='GLB', export_animations=True, export_animation_mode='NLA_TRACKS')
print("[villager] exported:", out)
