# 焚天者巨龙：无头 Blender 生成蒙皮龙与动画（fly/dive/fire/hit），导出 glb。
# 运行：/Applications/Blender.app/Contents/MacOS/Blender --background --python tools/blender_gen/dragon.py
import bpy
import math
import os

OUT = "assets/models/dragon.glb"

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
			bsdf.inputs["Emission Strength"].default_value = 2.2
	return m


SCALE = mat("dragon_scale", (0.54, 0.08, 0.045))
BELLY = mat("dragon_belly", (0.92, 0.42, 0.12))
HORN = mat("dragon_horn", (0.30, 0.19, 0.12))
MEMB = mat("dragon_membrane", (0.76, 0.16, 0.075))
EYE = mat("dragon_eye", (1.0, 0.80, 0.15), emit=(1.0, 0.65, 0.08))


def sphere(name, loc, scale, material):
	bpy.ops.mesh.primitive_uv_sphere_add(segments=14, ring_count=9, radius=1.0, location=loc)
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


# 长躯、颈链、楔形头、双角、背刺（面向 -Y）
parts = []
parts.append(sphere("body", (0, 0, 0), (1.15, 3.10, 1.27), SCALE))
for i in range(6):
	parts.append(sphere("neck", (0, -2.65 - i * 0.62, 0.28 + i * 0.28), (0.78 - i * 0.055, 0.94 - i * 0.07, 0.78 - i * 0.055), SCALE))
parts.append(sphere("head", (0, -6.25, 1.75), (1.22, 1.28, 0.92), SCALE))
parts.append(sphere("jaw", (0, -7.12, 1.52), (0.62, 0.90, 0.42), BELLY))
for sx in [-1, 1]:
	parts.append(sphere("eye", (sx * 0.44, -7.02, 1.98), (0.13, 0.10, 0.13), EYE))
	parts.append(cone("horn", (sx * 0.52, -6.35, 2.48), 0.12, 0.03, 1.30, HORN, rot=(math.radians(-116), sx * math.radians(-22), 0)))
	parts.append(sphere("cheek", (sx * 0.48, -7.18, 1.96), (0.11, 0.09, 0.11), HORN))
for i in range(11):
	parts.append(box("spike", (0, -4.5 + i * 0.72, 1.20), (0.18, 0.42, 0.72 - i * 0.025), HORN, rot=(math.radians(-18), 0, 0)))
# 双翼：主骨 + 四根指骨 + 膜
for sx in [-1, 1]:
	parts.append(box("wingbone", (sx * 3.40, -0.60, 0.65), (5.60, 0.22, 0.20), HORN, rot=(0, sx * math.radians(-8), 0)))
	for i in range(4):
		parts.append(box("finger", (sx * (2.65 - i * 0.08), -0.60 + 0.72 + i * 0.72, 0.60), (4.70 - i * 0.50, 0.13, 0.11), HORN, rot=(0, sx * math.radians(20 + i * 8), 0)))
		parts.append(box("membrane", (sx * (2.55 - i * 0.06), -0.60 + 0.48 + i * 0.72, 0.56), (4.55 - i * 0.46, 1.38, 0.05), MEMB, rot=(0, sx * math.radians(10 + i * 7), 0)))
# 尾：八节渐细
for i in range(8):
		parts.append(cone("tailseg", (0, 2.10 + i * 0.62, 0.55 - i * 0.052), 0.55 - i * 0.052, 0.50 - i * 0.052, 0.90, SCALE, rot=(math.radians(90), 0, 0)))

for p in parts:
	p.select_set(True)
bpy.context.view_layer.objects.active = parts[0]
bpy.ops.object.join()
body = parts[0]
body.name = "DragonBody"

# 骨骼：脊柱/颈两节/头/颌 + 双翼各两节 + 尾三节
bpy.ops.object.armature_add(enter_editmode=True, location=(0, 0, 0))
arm = bpy.context.active_object
arm.name = "DragonRig"
eb = arm.data.edit_bones
base = eb[0]
base.name = "spine"
base.head = (0, 0.50, 1.00)
base.tail = (0, -2.50, 1.20)


def bone(name, head, tail, parent):
	b = eb.new(name)
	b.head = head
	b.tail = tail
	b.parent = eb[parent]
	return b


bone("neck1", (0, -2.50, 1.20), (0, -4.20, 1.40), "spine")
bone("neck2", (0, -4.20, 1.40), (0, -5.50, 1.60), "neck1")
bone("head", (0, -5.50, 1.60), (0, -6.80, 1.70), "neck2")
bone("jaw", (0, -6.80, 1.50), (0, -7.60, 1.30), "head")
for sx, stag in [(-1, "l"), (1, "r")]:
	bone("wing1_" + stag, (sx * 0.9, -0.60, 0.65), (sx * 3.5, -0.60, 0.75), "spine")
	bone("wing2_" + stag, (sx * 3.5, -0.60, 0.75), (sx * 6.0, -0.40, 0.70), "wing1_" + stag)
bone("tail1", (0, 1.50, 1.00), (0, 3.20, 0.90), "spine")
bone("tail2", (0, 3.20, 0.90), (0, 4.80, 0.80), "tail1")
bone("tail3", (0, 4.80, 0.80), (0, 6.40, 0.70), "tail2")
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

# fly：双翼大扇 + 脊柱起伏 + 尾波（25 帧循环）
make_clip("fly", {
	"wing1_l": [(1, 0, 0, -30), (7, 0, 0, 25), (13, 0, 0, -30), (19, 0, 0, 20), (25, 0, 0, -30)],
	"wing1_r": [(1, 0, 0, 30), (7, 0, 0, -25), (13, 0, 0, 30), (19, 0, 0, -20), (25, 0, 0, 30)],
	"wing2_l": [(1, 0, 0, -45), (9, 0, 0, 35), (17, 0, 0, -45), (25, 0, 0, -45)],
	"wing2_r": [(1, 0, 0, 45), (9, 0, 0, -35), (17, 0, 0, 45), (25, 0, 0, 45)],
	"spine": [(1, 3, 0, 0), (13, -3, 0, 0), (25, 3, 0, 0)],
	"neck1": [(1, 2, 0, 0), (13, -2, 0, 0), (25, 2, 0, 0)],
	"tail1": [(1, 0, 8, 0), (13, 0, -8, 0), (25, 0, 8, 0)],
	"tail2": [(1, 0, 14, 0), (13, 0, -14, 0), (25, 0, 14, 0)],
	"tail3": [(1, 0, 20, 0), (13, 0, -20, 0), (25, 0, 20, 0)],
}, loc_keys={"spine": [(1, 0, 0, 0), (7, 0, 0, 0.25), (13, 0, 0, -0.15), (19, 0, 0, 0.20), (25, 0, 0, 0)]})

# dive：收翼俯冲——翼后掠、身体流线、尾绷直（13 帧循环保持）
make_clip("dive", {
	"wing1_l": [(1, 0, 0, 10), (5, 0, 35, 55), (13, 0, 35, 55)],
	"wing1_r": [(1, 0, 0, -10), (5, 0, -35, -55), (13, 0, -35, -55)],
	"wing2_l": [(1, 0, 0, 10), (5, 0, 40, 60), (13, 0, 40, 60)],
	"wing2_r": [(1, 0, 0, -10), (5, 0, -40, -60), (13, 0, -40, -60)],
	"spine": [(1, 0, 0, 0), (5, 10, 0, 0), (13, 10, 0, 0)],
	"tail1": [(1, 0, 0, 0), (5, -12, 0, 0), (13, -12, 0, 0)],
})

# fire：喷火——颈前探、颌张开、头后坐（17 帧循环保持）
make_clip("fire", {
	"neck1": [(1, 0, 0, 0), (5, 12, 0, 0), (17, 12, 0, 0)],
	"neck2": [(1, 0, 0, 0), (5, 10, 0, 0), (17, 10, 0, 0)],
	"head": [(1, 0, 0, 0), (5, -8, 0, 0), (17, -8, 0, 0)],
	"jaw": [(1, 0, 0, 0), (5, 38, 0, 0), (17, 38, 0, 0)],
	"spine": [(1, 0, 0, 0), (5, -4, 0, 0), (17, -4, 0, 0)],
	"wing1_l": [(1, 0, 0, -30), (5, 0, 0, 15), (17, 0, 0, 15)],
	"wing1_r": [(1, 0, 0, 30), (5, 0, 0, -15), (17, 0, 0, -15)],
})

# hit：受击痉挛（8 帧）
make_clip("hit", {
	"spine": [(1, 0, 0, 0), (3, -8, 6, 0), (8, 0, 0, 0)],
	"neck1": [(1, 0, 0, 0), (3, -10, 0, 0), (8, 0, 0, 0)],
})

reset_pose()
scene = bpy.context.scene
scene.render.fps = 24
root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
out = os.path.join(root, OUT)
os.makedirs(os.path.dirname(out), exist_ok=True)
bpy.ops.export_scene.gltf(filepath=out, export_format='GLB', export_animations=True, export_animation_mode='NLA_TRACKS')
print("[dragon] exported:", out)
