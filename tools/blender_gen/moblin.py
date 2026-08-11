# 莫布林：无头 Blender 生成蒙皮模型与战斗动画（idle/walk/windup/smash/hit），导出 glb。
# 运行：/Applications/Blender.app/Contents/MacOS/Blender --background --python tools/blender_gen/moblin.py
import bpy
import math
import os

OUT = "assets/models/moblin.glb"

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


SKIN = mat("moblin_skin", (0.62, 0.22, 0.14))
BELLY = mat("moblin_belly", (0.85, 0.62, 0.35))
DARK = mat("moblin_dark", (0.10, 0.08, 0.07))
BONE = mat("moblin_bone", (0.90, 0.82, 0.60))
EYE = mat("moblin_eye", (1.0, 0.85, 0.20), emit=(1.0, 0.72, 0.10))
MANE = mat("moblin_mane", (0.25, 0.055, 0.035))
CLOTH = mat("moblin_cloth", (0.12, 0.30, 0.34))
LEATHER = mat("moblin_leather", (0.32, 0.16, 0.07))
METAL = mat("moblin_metal", (0.42, 0.48, 0.52))


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


def cyl(name, loc, r1, r2, depth, material, rot=(0, 0, 0)):
	return cone(name, loc, r1, r2, depth, material, rot)


# 身体部件（Blender z-up，面向 -Y；对应 Godot 模型比例）
parts = []
parts.append(sphere("body", (0, 0, 1.25), (0.95, 0.86, 1.05), SKIN))
parts.append(sphere("belly", (0, 0.55, 1.15), (0.56, 0.34, 0.62), BELLY))
parts.append(sphere("head", (0, 0.10, 2.25), (0.44, 0.40, 0.38), SKIN))
# 加厚眉弓、长口鼻与上下颌，把头部从圆球拆成可读的兽人脸。
parts.append(sphere("muzzle", (0, 0.44, 2.18), (0.30, 0.25, 0.19), BELLY))
parts.append(sphere("nose", (0, 0.655, 2.25), (0.15, 0.075, 0.10), DARK))
for sx in [-1, 1]:
	parts.append(sphere("nostril", (sx * 0.055, 0.716, 2.27), (0.022, 0.012, 0.018), MANE))
	parts.append(box("brow", (sx * 0.16, 0.445, 2.40), (0.17, 0.045, 0.045), MANE, rot=(0, sx * math.radians(8), sx * math.radians(-12))))
parts.append(cone("horn", (0, 0.10, 2.72), 0.10, 0.02, 0.55, BONE))
for sx in [-1, 1]:
	parts.append(cone("ear", (sx * 0.44, 0.08, 2.30), 0.085, 0.015, 0.48, SKIN, rot=(0, sx * math.radians(78), 0)))
parts.append(box("mouth", (0, 0.50, 2.12), (0.30, 0.05, 0.09), DARK))
for i in range(3):
	parts.append(box("tooth", (-0.08 + i * 0.08, 0.515, 2.145), (0.05, 0.03, 0.07), BONE))
# 两颗上挑獠牙和后脑鬃冠强化远距离剪影。
for sx in [-1, 1]:
	parts.append(cone("tusk", (sx * 0.19, 0.57, 2.12), 0.052, 0.008, 0.25, BONE, rot=(math.radians(-10), sx * math.radians(8), 0)))
for i in range(5):
	z = 2.58 - i * 0.15
	parts.append(cone("mane", (0, -0.27, z), 0.11 - i * 0.008, 0.018, 0.34, MANE, rot=(math.radians(74), 0, 0)))
for sx in [-1, 1]:
	parts.append(sphere("eye", (sx * 0.16, 0.44, 2.30), (0.07, 0.05, 0.07), EYE))
	parts.append(sphere("pupil", (sx * 0.16, 0.485, 2.30), (0.026, 0.015, 0.038), DARK))
# 腰带、分片裙甲与肩甲让大块身体拥有装备层次。
parts.append(box("belt", (0, 0.02, 0.91), (0.86, 0.48, 0.12), LEATHER))
parts.append(sphere("buckle", (0, 0.50, 0.91), (0.13, 0.055, 0.13), METAL))
for sx in [-1, 0, 1]:
	parts.append(box("loincloth", (sx * 0.25, 0.48, 0.66), (0.23, 0.055, 0.42 - abs(sx) * 0.07), CLOTH, rot=(math.radians(-7), 0, sx * math.radians(4))))
for sx in [-1, 1]:
	parts.append(sphere("shoulder_guard", (sx * 0.70, 0.01, 1.69), (0.34, 0.30, 0.20), METAL))
	parts.append(cyl("bracer", (sx * 0.85, 0.01, 0.98), 0.245, 0.225, 0.32, LEATHER))
parts.append(cyl("arm_r", (0.85, 0, 1.30), 0.22, 0.18, 1.10, SKIN))
parts.append(cyl("club", (0.85, 0.15, 0.62), 0.16, 0.10, 1.60, DARK, rot=(math.radians(8), 0, 0)))
# 木棒的金属箍与不对称尖刺形成武器轮廓。
for z in [0.20, 0.48, 0.76]:
	parts.append(cyl("club_band", (0.85, 0.15, z), 0.175, 0.175, 0.075, METAL, rot=(math.radians(8), 0, 0)))
for i, z in enumerate([0.26, 0.52, 0.78]):
	side = -1 if i % 2 == 0 else 1
	parts.append(cone("club_spike", (0.85 + side * 0.19, 0.15, z), 0.075, 0.008, 0.30, BONE, rot=(0, side * math.radians(90), 0)))
parts.append(cyl("arm_l", (-0.85, 0, 1.30), 0.22, 0.18, 1.10, SKIN))
for sx in [-1, 1]:
	parts.append(cyl("leg", (sx * 0.38, 0, 0.45), 0.20, 0.16, 0.90, SKIN))
	parts.append(sphere("foot", (sx * 0.38, 0.18, 0.08), (0.25, 0.34, 0.13), DARK))

for p in parts:
	p.select_set(True)
bpy.context.view_layer.objects.active = parts[0]
bpy.ops.object.join()
body = parts[0]
body.name = "MoblinBody"

# 骨骼：脊柱/头/双臂双节/双腿双节
bpy.ops.object.armature_add(enter_editmode=True, location=(0, 0, 0))
arm = bpy.context.active_object
arm.name = "MoblinRig"
eb = arm.data.edit_bones
base = eb[0]
base.name = "spine"
base.head = (0, 0, 0.50)
base.tail = (0, 0, 1.90)


def bone(name, head, tail, parent):
	b = eb.new(name)
	b.head = head
	b.tail = tail
	b.parent = eb[parent]
	return b


bone("head", (0, 0, 1.90), (0, 0, 2.50), "spine")
bone("armr", (0.55, 0, 1.75), (0.85, 0, 1.30), "spine")
bone("forearmr", (0.85, 0, 1.30), (0.85, 0, 0.60), "armr")
bone("arml", (-0.55, 0, 1.75), (-0.85, 0, 1.30), "spine")
bone("forearml", (-0.85, 0, 1.30), (-0.85, 0, 0.60), "arml")
for sx, tag in [(-1, "l"), (1, "r")]:
	bone("leg" + tag, (sx * 0.38, 0, 0.85), (sx * 0.38, 0, 0.40), "spine")
	bone("shin" + tag, (sx * 0.38, 0, 0.40), (sx * 0.38, 0, 0.02), "leg" + tag)
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
	"""keys: {bone: [(frame, rx, ry, rz), ...]}；loc_keys: {bone: [(frame, x, y, z), ...]}。"""
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

# idle：大肚腩呼吸起伏（48 帧循环）
make_clip("idle", {
	"spine": [(1, 0, 0, 0), (25, 2.5, 0, 0), (49, 0, 0, 0)],
	"head": [(1, 0, 0, 0), (25, -2.0, 0, 0), (49, 0, 0, 0)],
	"arml": [(1, 0, 0, 0), (25, 3.0, 0, 0), (49, 0, 0, 0)],
	"armr": [(1, 0, 0, 0), (25, 3.0, 0, 0), (49, 0, 0, 0)],
}, loc_keys={"spine": [(1, 0, 0, 0), (25, 0, 0, -0.04), (49, 0, 0, 0)]})

# walk：短腿快倒腾，身体左右晃（24 帧循环）
make_clip("walk", {
	"legl": [(1, -26, 0, 0), (13, 26, 0, 0), (25, -26, 0, 0)],
	"legr": [(1, 26, 0, 0), (13, -26, 0, 0), (25, 26, 0, 0)],
	"shinl": [(1, 8, 0, 0), (7, 30, 0, 0), (13, 8, 0, 0), (19, 22, 0, 0), (25, 8, 0, 0)],
	"shinr": [(1, 30, 0, 0), (7, 8, 0, 0), (13, 22, 0, 0), (19, 8, 0, 0), (25, 30, 0, 0)],
	"spine": [(1, 0, 0, 4), (13, 0, 0, -4), (25, 0, 0, 4)],
	"arml": [(1, 14, 0, 0), (13, -14, 0, 0), (25, 14, 0, 0)],
	"armr": [(1, -14, 0, 0), (13, 14, 0, 0), (25, -14, 0, 0)],
})

# windup：0.9 秒举棒蓄力——身体后仰、棒子过顶，是给玩家喂招的关键前摇（22 帧）
make_clip("windup", {
	"armr": [(1, 10, 0, 0), (10, -95, 0, -20), (17, -150, 0, -30), (22, -165, 0, -32)],
	"forearmr": [(1, 0, 0, 0), (10, -35, 0, 0), (17, -55, 0, 0), (22, -60, 0, 0)],
	"arml": [(1, 0, 0, 0), (17, -45, 0, 25), (22, -50, 0, 28)],
	"spine": [(1, 0, 0, 0), (10, -8, 0, 0), (22, -14, 0, 0)],
	"head": [(1, 0, 0, 0), (22, -16, 0, 0)],
	"legl": [(1, 0, 0, 0), (22, -8, 0, 0)],
	"legr": [(1, 0, 0, 0), (22, 8, 0, 0)],
})

# smash：猛砸落地 + 身体前扑（8 帧）
make_clip("smash", {
	"armr": [(1, -165, 0, -32), (4, 48, 0, 10), (8, 42, 0, 8)],
	"forearmr": [(1, -60, 0, 0), (4, 12, 0, 0), (8, 10, 0, 0)],
	"arml": [(1, -50, 0, 28), (4, 18, 0, -15), (8, 15, 0, -12)],
	"spine": [(1, -14, 0, 0), (4, 22, 0, 0), (8, 18, 0, 0)],
	"head": [(1, -16, 0, 0), (4, 14, 0, 0), (8, 12, 0, 0)],
	"legl": [(1, -8, 0, 0), (4, 10, 0, 0), (8, 8, 0, 0)],
	"legr": [(1, 8, 0, 0), (4, -6, 0, 0), (8, -5, 0, 0)],
})

# hit：受击后仰顿挫（10 帧）
make_clip("hit", {
	"spine": [(1, 0, 0, 0), (3, -14, 0, 0), (10, 0, 0, 0)],
	"head": [(1, 0, 0, 0), (3, -18, 0, 0), (10, 0, 0, 0)],
	"arml": [(1, 0, 0, 0), (3, -25, 0, 15), (10, 0, 0, 0)],
	"armr": [(1, 0, 0, 0), (3, -25, 0, -15), (10, 0, 0, 0)],
})

# die：膝盖先软、躯干侧倒，最后停在倒地姿态，避免生命清空时瞬间消失。
make_clip("die", {
	"spine": [(1, 0, 0, 0), (7, -10, 0, 8), (15, -28, 0, 58), (25, -34, 0, 82)],
	"head": [(1, 0, 0, 0), (7, -12, 0, -8), (15, -20, 0, -28), (25, -22, 0, -35)],
	"armr": [(1, 0, 0, 0), (7, -38, 0, -22), (15, -18, 0, -58), (25, -12, 0, -72)],
	"forearmr": [(1, 0, 0, 0), (15, 35, 0, 0), (25, 46, 0, 0)],
	"arml": [(1, 0, 0, 0), (7, -30, 0, 28), (15, 18, 0, 64), (25, 24, 0, 78)],
	"legl": [(1, 0, 0, 0), (7, 30, 0, 0), (15, 54, 0, 0), (25, 62, 0, 0)],
	"legr": [(1, 0, 0, 0), (7, 18, 0, 0), (15, -20, 0, 0), (25, -30, 0, 0)],
}, loc_keys={"spine": [(1, 0, 0, 0), (7, 0, 0, -0.16), (15, 0, 0, -0.52), (25, 0, 0, -0.72)]})

reset_pose()
scene = bpy.context.scene
scene.render.fps = 24
root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
out = os.path.join(root, OUT)
os.makedirs(os.path.dirname(out), exist_ok=True)
bpy.ops.export_scene.gltf(filepath=out, export_format='GLB', export_animations=True, export_animation_mode='NLA_TRACKS')
print("[moblin] exported:", out)
