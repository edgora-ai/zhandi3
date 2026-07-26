# 骷髅兵：无头 Blender 生成蒙皮骷髅与动画（rise/walk/attack/crumble），导出 glb。
# 运行：/Applications/Blender.app/Contents/MacOS/Blender --background --python tools/blender_gen/skeleton.py
import bpy
import math
import os

OUT = "assets/models/skeleton.glb"

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


BONE = mat("stal_bone", (0.82, 0.80, 0.72))
BONE_D = mat("stal_bone_dark", (0.55, 0.52, 0.45))
DARK = mat("stal_dark", (0.08, 0.07, 0.06))


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


def cyl(name, loc, radius, depth, material):
	bpy.ops.mesh.primitive_cylinder_add(vertices=7, radius=radius, depth=depth, location=loc)
	o = bpy.context.active_object
	o.name = name
	o.data.materials.append(material)
	return o


# 颅骨 + 眼窝 + 下颌 + 三节肋排 + 脊柱 + 细四肢（面向 -Y）
parts = []
parts.append(sphere("skull", (0, -0.02, 1.62), (0.16, 0.15, 0.17), BONE))
for sx in [-1, 1]:
	parts.append(sphere("socket", (sx * 0.06, -0.145, 1.64), (0.035, 0.022, 0.042), DARK))
parts.append(box("jaw", (0, -0.10, 1.50), (0.16, 0.06, 0.07), BONE_D))
for i in range(3):
	parts.append(box("rib", (0, 0, 1.24 + i * 0.075), (0.34 - i * 0.03, 0.05, 0.045), BONE))
parts.append(cyl("spine", (0, 0, 1.10), 0.05, 0.36, BONE_D))
parts.append(box("pelvis", (0, 0, 0.95), (0.26, 0.18, 0.14), BONE))
for sx in [-1, 1]:
	parts.append(cyl("upperarm", (sx * 0.22, 0, 1.28), 0.040, 0.30, BONE))
	parts.append(cyl("forearm", (sx * 0.22, 0, 1.02), 0.034, 0.28, BONE))
	parts.append(sphere("claw", (sx * 0.22, -0.01, 0.86), (0.05, 0.04, 0.05), BONE_D))
	parts.append(cyl("thigh", (sx * 0.10, 0, 0.62), 0.045, 0.40, BONE))
	parts.append(cyl("shin", (sx * 0.10, 0, 0.24), 0.038, 0.38, BONE))
	parts.append(box("foot", (sx * 0.10, -0.04, 0.035), (0.09, 0.18, 0.06), BONE_D))

for p in parts:
	p.select_set(True)
bpy.context.view_layer.objects.active = parts[0]
bpy.ops.object.join()
body = parts[0]
body.name = "StalBody"

# 骨骼（rig）：髋/脊柱/头 + 双臂双节 + 双腿双节
bpy.ops.object.armature_add(enter_editmode=True, location=(0, 0, 0))
arm = bpy.context.active_object
arm.name = "StalRig"
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
	bone("upperarm_" + stag, (sx * 0.18, 0, 1.40), (sx * 0.22, 0, 1.14), "spine")
	bone("forearm_" + stag, (sx * 0.22, 0, 1.14), (sx * 0.22, 0, 0.88), "upperarm_" + stag)
	bone("thigh_" + stag, (sx * 0.10, 0, 0.82), (sx * 0.10, 0, 0.44), "hips")
	bone("shin_" + stag, (sx * 0.10, 0, 0.44), (sx * 0.10, 0, 0.05), "thigh_" + stag)
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

# rise：破土而出——从地平下平躺到站立，双臂撑地爬起（30 帧）
make_clip("rise", {
	"hips": [(1, -80, 0, 0), (12, -55, 0, 0), (22, -15, 0, 0), (30, 0, 0, 0)],
	"spine": [(1, -20, 0, 0), (12, -10, 0, 0), (22, 5, 0, 0), (30, 0, 0, 0)],
	"head": [(1, -30, 0, 0), (22, 8, 0, 0), (30, 0, 0, 0)],
	"upperarm_l": [(1, -140, 0, 20), (12, -80, 0, 15), (30, 0, 0, 4)],
	"upperarm_r": [(1, -140, 0, -20), (12, -80, 0, -15), (30, 0, 0, -4)],
	"thigh_l": [(1, -40, 0, 0), (22, 15, 0, 0), (30, 0, 0, 0)],
	"thigh_r": [(1, -40, 0, 0), (22, 15, 0, 0), (30, 0, 0, 0)],
}, loc_keys={"hips": [(1, 0, 0, -1.35), (12, 0, 0, -0.75), (22, 0, 0, -0.15), (30, 0, 0, 0)]})

# walk：僵硬提膝拖步，双臂悬荡（25 帧循环）
make_clip("walk", {
	"thigh_l": [(1, -30, 0, 0), (13, 26, 0, 0), (25, -30, 0, 0)],
	"thigh_r": [(1, 26, 0, 0), (13, -30, 0, 0), (25, 26, 0, 0)],
	"shin_l": [(1, 4, 0, 0), (7, 22, 0, 0), (13, 4, 0, 0), (19, 12, 0, 0), (25, 4, 0, 0)],
	"shin_r": [(1, 22, 0, 0), (7, 4, 0, 0), (13, 12, 0, 0), (19, 4, 0, 0), (25, 22, 0, 0)],
	"upperarm_l": [(1, 8, 0, 6), (13, -8, 0, 6), (25, 8, 0, 6)],
	"upperarm_r": [(1, -8, 0, -6), (13, 8, 0, -6), (25, -8, 0, -6)],
	"spine": [(1, 4, 0, 2), (13, 4, 0, -2), (25, 4, 0, 2)],
}, loc_keys={"hips": [(1, 0, 0, -0.03), (7, 0, 0, 0.01), (13, 0, 0, -0.03), (19, 0, 0, 0.01), (25, 0, 0, -0.03)]})

# attack：双爪前扑撕抓（12 帧）
make_clip("attack", {
	"upperarm_l": [(1, 0, 0, 6), (4, -85, 0, 25), (8, -80, 0, 22), (12, 0, 0, 6)],
	"upperarm_r": [(1, 0, 0, -6), (4, -85, 0, -25), (8, -80, 0, -22), (12, 0, 0, -6)],
	"forearm_l": [(1, 0, 0, 0), (4, -30, 0, 0), (8, -25, 0, 0), (12, 0, 0, 0)],
	"forearm_r": [(1, 0, 0, 0), (4, -30, 0, 0), (8, -25, 0, 0), (12, 0, 0, 0)],
	"spine": [(1, 0, 0, 0), (4, 16, 0, 0), (8, 14, 0, 0), (12, 0, 0, 0)],
	"head": [(1, 0, 0, 0), (4, 10, 0, 0), (8, 8, 0, 0), (12, 0, 0, 0)],
})

# crumble：散架塌落（20 帧，停在骨堆）
make_clip("crumble", {
	"hips": [(1, 0, 0, 0), (8, 55, 0, 0), (20, 62, 0, 0)],
	"spine": [(1, 0, 0, 0), (8, 25, 0, 8), (20, 28, 0, 10)],
	"head": [(1, 0, 0, 0), (8, 30, 12, 0), (20, 34, 14, 0)],
	"upperarm_l": [(1, 0, 0, 4), (8, -40, 0, 55), (20, -45, 0, 60)],
	"upperarm_r": [(1, 0, 0, -4), (8, -40, 0, -55), (20, -45, 0, -60)],
	"thigh_l": [(1, 0, 0, 0), (8, 35, 0, 12), (20, 38, 0, 14)],
	"thigh_r": [(1, 0, 0, 0), (8, 30, 0, -12), (20, 33, 0, -14)],
}, loc_keys={"hips": [(1, 0, 0, 0), (8, 0, 0, -0.55), (20, 0, 0, -0.60)]})

reset_pose()
scene = bpy.context.scene
scene.render.fps = 24
root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
out = os.path.join(root, OUT)
os.makedirs(os.path.dirname(out), exist_ok=True)
bpy.ops.export_scene.gltf(filepath=out, export_format='GLB', export_animations=True, export_animation_mode='NLA_TRACKS')
print("[skeleton] exported:", out)
