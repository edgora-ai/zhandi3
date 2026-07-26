# 马匹：无头 Blender 生成蒙皮马与步态动画（idle/walk/trot/gallop/graze/buck），导出 glb。
# 运行：/Applications/Blender.app/Contents/MacOS/Blender --background --python tools/blender_gen/horse.py
import bpy
import math
import os

OUT = "assets/models/horse.glb"

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


COAT = mat("horse_coat", (0.42, 0.26, 0.15))
COAT_L = mat("horse_coat_light", (0.52, 0.34, 0.20))
MANE = mat("horse_mane", (0.16, 0.10, 0.06))
MARK = mat("horse_marking", (0.90, 0.82, 0.64))
LEATHER = mat("horse_leather", (0.19, 0.095, 0.045))
CLOTH = mat("horse_cloth", (0.08, 0.39, 0.49))
BRASS = mat("horse_brass", (0.72, 0.48, 0.16))
DARK = mat("horse_dark", (0.10, 0.08, 0.07))


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


# 躯干（面向 -Y = Godot -Z；Blender y = Godot z，Blender z = Godot y）
parts = []
parts.append(sphere("body", (0, 0.02, 2.02), (0.61, 1.55, 0.63), COAT))
parts.append(sphere("chest", (0, -0.80, 2.04), (0.63, 0.67, 0.71), COAT_L))
parts.append(sphere("rump", (0, 0.82, 2.04), (0.70, 0.76, 0.70), COAT))
parts.append(sphere("blaze_chest", (0, -0.88, 2.27), (0.30, 0.30, 0.24), MARK))
for sx in [-1, 1]:
	parts.append(sphere("shoulder", (sx * 0.48, -0.82, 1.90), (0.26, 0.34, 0.40), COAT_L))
	parts.append(sphere("haunch", (sx * 0.46, 0.84, 1.88), (0.27, 0.36, 0.46), COAT))
parts.append(sphere("brisket", (0, -1.10, 1.66), (0.24, 0.28, 0.30), COAT_L))
# 颈部斜向前上方
parts.append(cone("neck", (0, -1.36, 2.62), 0.44, 0.30, 1.70, COAT_L, rot=(math.radians(58), 0, 0)))
# 头：颅箱 + 收分长脸 + 短耳 + 眼鼻
parts.append(box("cranium", (0, -2.02, 3.14), (0.40, 0.46, 0.42), COAT_L))
parts.append(box("muzzle", (0, -2.42, 2.96), (0.22, 0.42, 0.26), COAT_L, rot=(math.radians(-14), 0, 0)))
parts.append(box("blaze", (0, -2.30, 3.18), (0.08, 0.30, 0.10), MARK, rot=(math.radians(-14), 0, 0)))
for sx in [-1, 1]:
	parts.append(cone("ear", (sx * 0.13, -1.94, 3.44), 0.075, 0.015, 0.26, COAT, rot=(0, sx * math.radians(-10), 0)))
	parts.append(sphere("eye", (sx * 0.185, -2.14, 3.22), (0.05, 0.035, 0.05), DARK))
	parts.append(sphere("nostril", (sx * 0.055, -2.62, 2.90), (0.024, 0.02, 0.028), DARK))
# 立式鬃毛脊冠
for i in range(7):
	t = i / 6.0
	parts.append(box("mane", (0, -1.10 - t * 0.75, 3.20 - t * 0.55), (0.07, 0.22, 0.30), MANE, rot=(math.radians(35), 0, 0)))
# 尾巴：根部到末端渐粗再收束
parts.append(cone("tail", (0, 1.48, 1.72), 0.16, 0.09, 1.30, MANE, rot=(math.radians(-18), 0, 0)))
parts.append(sphere("tail_end", (0, 1.62, 1.12), (0.16, 0.18, 0.24), MANE))

# 四腿：上腿、膝下段、蹄
for zi, zv in enumerate([-0.86, 0.86]):
	for xi, xv in enumerate([-0.43, 0.43]):
		upper_mat = COAT_L if zi == 0 else COAT
		parts.append(cone("leg_up", (xv, zv, 1.28), 0.145, 0.105, 0.88, upper_mat))
		parts.append(cone("leg_lo", (xv, zv - 0.02, 0.56), 0.105, 0.075, 0.70, COAT))
		parts.append(box("hoof", (xv, zv - 0.04, 0.09), (0.20, 0.26, 0.16), DARK))
# 鞍毯、鞍座、前后鞍桥、腹带、脚蹬、缰绳
parts.append(box("blanket", (0, 0.16, 2.62), (1.08, 1.58, 0.10), CLOTH))
parts.append(box("saddle", (0, 0.12, 2.76), (0.82, 1.02, 0.24), LEATHER))
parts.append(box("pommel", (0, -0.38, 2.92), (0.88, 0.14, 0.28), LEATHER))
parts.append(box("cantle", (0, 0.58, 2.92), (0.88, 0.14, 0.28), LEATHER))
for sx in [-1, 1]:
	parts.append(box("girth", (sx * 0.52, 0.12, 2.02), (0.075, 0.10, 1.30), LEATHER))
	parts.append(box("stirrup", (sx * 0.58, 0.18, 1.62), (0.10, 0.20, 0.34), BRASS))
	parts.append(box("rein", (sx * 0.31, -1.10, 2.90), (0.035, 2.10, 0.035), LEATHER, rot=(math.radians(-6), 0, 0)))

for p in parts:
	p.select_set(True)
bpy.context.view_layer.objects.active = parts[0]
bpy.ops.object.join()
body = parts[0]
body.name = "HorseBody"

# 骨骼：脊柱两段/颈/头/尾两段 + 四腿各两节
bpy.ops.object.armature_add(enter_editmode=True, location=(0, 0, 0))
arm = bpy.context.active_object
arm.name = "HorseRig"
eb = arm.data.edit_bones
base = eb[0]
base.name = "spine"
base.head = (0, 0.60, 1.95)
base.tail = (0, -0.55, 2.10)


def bone(name, head, tail, parent):
	b = eb.new(name)
	b.head = head
	b.tail = tail
	b.parent = eb[parent]
	return b


bone("neck", (0, -0.55, 2.10), (0, -1.45, 2.90), "spine")
bone("head", (0, -1.45, 2.90), (0, -2.15, 3.18), "neck")
bone("tail", (0, 1.30, 2.10), (0, 1.55, 1.45), "spine")
for sx, stag in [(-1, "l"), (1, "r")]:
	for zv, ztag in [(-0.86, "f"), (0.86, "h")]:
		bone("up_" + ztag + stag, (sx * 0.43, zv, 1.72), (sx * 0.43, zv, 0.95), "spine")
		bone("lo_" + ztag + stag, (sx * 0.43, zv, 0.95), (sx * 0.43, zv - 0.02, 0.10), "up_" + ztag + stag)
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

# idle：呼吸、摆尾、偶尔晃头（49 帧循环）
make_clip("idle", {
	"neck": [(1, 0, 0, 0), (25, 2.5, 0, 0), (49, 0, 0, 0)],
	"head": [(1, 0, 0, 0), (13, -3, 4, 0), (25, 0, 0, 0), (37, -3, -4, 0), (49, 0, 0, 0)],
	"tail": [(1, 0, 8, 0), (25, 0, -8, 0), (49, 0, 8, 0)],
}, loc_keys={"spine": [(1, 0, 0, 0), (25, 0, 0, -0.015), (49, 0, 0, 0)]})

# walk：四拍走步 LF→RH→RF→LH（33 帧循环）
_offs = {"up_fl": 0, "up_hr": 8, "up_fr": 16, "up_hl": 24}
_keys = {}
for _bn, _off in _offs.items():
	_keys[_bn] = []
	for _f in [1, 9, 17, 25, 33]:
		_ang = 22.0 * math.sin(2 * math.pi * (_f - 1 + _off) / 32.0)
		_keys[_bn].append((_f, _ang, 0, 0))
	_lo = "lo_" + _bn[3:]
	_keys[_lo] = []
	for _f in [1, 9, 17, 25, 33]:
		_ang = 32.0 * max(0.0, math.sin(2 * math.pi * (_f - 1 + _off) / 32.0 + math.pi * 0.55))
		_keys[_lo].append((_f, _ang, 0, 0))
_keys["neck"] = [(1, 2, 0, 0), (9, -2, 0, 0), (17, 2, 0, 0), (25, -2, 0, 0), (33, 2, 0, 0)]
_keys["head"] = [(1, -2, 0, 0), (9, 2, 0, 0), (17, -2, 0, 0), (25, 2, 0, 0), (33, -2, 0, 0)]
_keys["tail"] = [(1, 0, 6, 0), (17, 0, -6, 0), (33, 0, 6, 0)]
make_clip("walk", _keys, loc_keys={"spine": [(1, 0, 0, 0), (9, 0, 0, -0.03), (17, 0, 0, 0), (25, 0, 0, -0.03), (33, 0, 0, 0)]})

# trot：对侧对角两拍快步（17 帧循环）
make_clip("trot", {
	"up_fl": [(1, 26, 0, 0), (9, -26, 0, 0), (17, 26, 0, 0)],
	"up_hr": [(1, 26, 0, 0), (9, -26, 0, 0), (17, 26, 0, 0)],
	"up_fr": [(1, -26, 0, 0), (9, 26, 0, 0), (17, -26, 0, 0)],
	"up_hl": [(1, -26, 0, 0), (9, 26, 0, 0), (17, -26, 0, 0)],
	"lo_fl": [(1, 10, 0, 0), (5, 36, 0, 0), (9, 10, 0, 0), (13, 30, 0, 0), (17, 10, 0, 0)],
	"lo_hr": [(1, 10, 0, 0), (5, 36, 0, 0), (9, 10, 0, 0), (13, 30, 0, 0), (17, 10, 0, 0)],
	"lo_fr": [(1, 36, 0, 0), (5, 10, 0, 0), (9, 30, 0, 0), (13, 10, 0, 0), (17, 36, 0, 0)],
	"lo_hl": [(1, 36, 0, 0), (5, 10, 0, 0), (9, 30, 0, 0), (13, 10, 0, 0), (17, 36, 0, 0)],
	"neck": [(1, 4, 0, 0), (9, -4, 0, 0), (17, 4, 0, 0)],
}, loc_keys={"spine": [(1, 0, 0, 0.03), (5, 0, 0, -0.04), (9, 0, 0, 0.03), (13, 0, 0, -0.04), (17, 0, 0, 0.03)]})

# gallop：前后两束轮流蹬伸，有悬空期（17 帧循环）
make_clip("gallop", {
	"up_fl": [(1, 34, 0, 0), (5, 10, 0, 0), (9, -30, 0, 0), (13, -12, 0, 0), (17, 34, 0, 0)],
	"up_fr": [(1, 30, 0, 0), (5, 14, 0, 0), (9, -34, 0, 0), (13, -8, 0, 0), (17, 30, 0, 0)],
	"up_hl": [(1, -18, 0, 0), (5, 32, 0, 0), (9, 12, 0, 0), (13, -28, 0, 0), (17, -18, 0, 0)],
	"up_hr": [(1, -14, 0, 0), (5, 28, 0, 0), (9, 16, 0, 0), (13, -32, 0, 0), (17, -14, 0, 0)],
	"lo_fl": [(1, 20, 0, 0), (5, 55, 0, 0), (9, 15, 0, 0), (17, 20, 0, 0)],
	"lo_fr": [(1, 24, 0, 0), (5, 50, 0, 0), (9, 18, 0, 0), (17, 24, 0, 0)],
	"lo_hl": [(1, 40, 0, 0), (5, 15, 0, 0), (9, 45, 0, 0), (17, 40, 0, 0)],
	"lo_hr": [(1, 36, 0, 0), (5, 18, 0, 0), (9, 42, 0, 0), (17, 36, 0, 0)],
	"spine": [(1, 4, 0, 0), (5, -6, 0, 0), (9, 6, 0, 0), (13, -4, 0, 0), (17, 4, 0, 0)],
	"neck": [(1, 8, 0, 0), (5, -10, 0, 0), (9, 10, 0, 0), (13, -6, 0, 0), (17, 8, 0, 0)],
}, loc_keys={"spine": [(1, 0, 0, 0.04), (5, 0, 0, -0.06), (9, 0, 0, 0.05), (13, 0, 0, -0.05), (17, 0, 0, 0.04)]})

# graze：低头吃草，尾巴轻摆（49 帧循环）
make_clip("graze", {
	"neck": [(1, 8, 0, 0), (13, 52, 0, 0), (25, 48, 0, 0), (37, 54, 0, 0), (49, 8, 0, 0)],
	"head": [(1, -4, 0, 0), (13, -34, 0, 0), (25, -30, 0, 0), (37, -36, 0, 0), (49, -4, 0, 0)],
	"tail": [(1, 0, 10, 0), (25, 0, -10, 0), (49, 0, 10, 0)],
})

# buck：尥蹶子——前躯扬起、前腿腾空踢踏、头一甩（17 帧）
make_clip("buck", {
	"spine": [(1, 0, 0, 0), (5, -32, 0, 0), (11, -36, 0, 0), (17, 0, 0, 0)],
	"neck": [(1, 0, 0, 0), (5, -18, 0, 0), (11, -22, 0, 0), (17, 0, 0, 0)],
	"head": [(1, 0, 0, 0), (5, -16, 0, 8), (11, -20, 0, -8), (17, 0, 0, 0)],
	"up_fl": [(1, 0, 0, 0), (5, -68, 0, 0), (11, -75, 0, 0), (17, 0, 0, 0)],
	"up_fr": [(1, 0, 0, 0), (5, -62, 0, 0), (11, -70, 0, 0), (17, 0, 0, 0)],
	"lo_fl": [(1, 0, 0, 0), (5, 80, 0, 0), (11, 88, 0, 0), (17, 0, 0, 0)],
	"lo_fr": [(1, 0, 0, 0), (5, 74, 0, 0), (11, 82, 0, 0), (17, 0, 0, 0)],
	"up_hl": [(1, 0, 0, 0), (5, 16, 0, 0), (11, 18, 0, 0), (17, 0, 0, 0)],
	"up_hr": [(1, 0, 0, 0), (5, 14, 0, 0), (11, 16, 0, 0), (17, 0, 0, 0)],
	"tail": [(1, 0, 0, 0), (5, -30, 0, 0), (11, -35, 0, 0), (17, 0, 0, 0)],
}, loc_keys={"spine": [(1, 0, 0, 0), (5, 0, 0, 0.22), (11, 0, 0, 0.25), (17, 0, 0, 0)]})

reset_pose()
scene = bpy.context.scene
scene.render.fps = 24
root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
out = os.path.join(root, OUT)
os.makedirs(os.path.dirname(out), exist_ok=True)
bpy.ops.export_scene.gltf(filepath=out, export_format='GLB', export_animations=True, export_animation_mode='NLA_TRACKS')
print("[horse] exported:", out)
