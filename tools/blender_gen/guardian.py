# 古代守卫：无头 Blender 生成蒙皮守卫与动画（idle/walk/aim/hit/die），导出 glb。
# 运行：/Applications/Blender.app/Contents/MacOS/Blender --background --python tools/blender_gen/guardian.py
import bpy
import math
import os

OUT = "assets/models/guardian.glb"

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


SHELL = mat("guardian_shell", (0.62, 0.65, 0.68))
DARK = mat("guardian_dark", (0.10, 0.11, 0.13))
EYE = mat("guardian_eye", (0.10, 0.90, 0.85), emit=(0.05, 0.95, 0.85))


def sphere(name, loc, scale, material):
	bpy.ops.mesh.primitive_uv_sphere_add(segments=14, ring_count=9, radius=1.0, location=loc)
	o = bpy.context.active_object
	o.name = name
	o.scale = scale
	bpy.ops.object.transform_apply(scale=True)
	o.data.materials.append(material)
	return o


def cone(name, loc, r1, r2, depth, material, rot=(0, 0, 0)):
	bpy.ops.mesh.primitive_cone_add(vertices=8, radius1=r1, radius2=r2, depth=depth, location=loc, rotation=rot)
	o = bpy.context.active_object
	o.name = name
	o.data.materials.append(material)
	return o


# 穹顶外壳、独眼、顶帽、六条两段式细腿（面向 -Y）
parts = []
parts.append(sphere("dome", (0, 0, 1.05), (1.15, 1.15, 0.75), SHELL))
parts.append(sphere("under", (0, -0.62, 0.85), (0.55, 0.50, 0.44), DARK))
parts.append(sphere("eye", (0, -0.85, 0.95), (0.26, 0.20, 0.26), EYE))
parts.append(cone("cap", (0, 0, 1.84), 0.20, 0.10, 0.14, DARK))
for i in range(6):
	a = i * math.tau / 6.0
	cx, cy = math.cos(a), math.sin(a)
	ux, uy = cx * 1.05, cy * 1.05
	lx, ly = cx * 1.55, cy * 1.55
	# 上段：从壳缘外下；下段：近垂直落地收尖
	mid = (ux, uy, 0.72)
	parts.append(cone("leg_up", mid, 0.09, 0.065, 0.80, DARK, rot=(uy * math.radians(38), -ux * math.radians(38), 0)))
	parts.append(cone("leg_lo", (lx, ly, 0.32), 0.06, 0.015, 0.70, SHELL, rot=(uy * math.radians(-14), -ux * math.radians(-14), 0)))

for p in parts:
	p.select_set(True)
bpy.context.view_layer.objects.active = parts[0]
bpy.ops.object.join()
body = parts[0]
body.name = "GuardianBody"

# 骨骼：核心 + 六腿各两节
bpy.ops.object.armature_add(enter_editmode=True, location=(0, 0, 0))
arm = bpy.context.active_object
arm.name = "GuardianRig"
eb = arm.data.edit_bones
base = eb[0]
base.name = "core"
base.head = (0, 0, 0.85)
base.tail = (0, -0.40, 1.10)


def bone(name, head, tail, parent):
	b = eb.new(name)
	b.head = head
	b.tail = tail
	b.parent = eb[parent]
	return b


for i in range(6):
	a = i * math.tau / 6.0
	cx, cy = math.cos(a), math.sin(a)
	bone("leg_up_%d" % i, (cx * 0.80, cy * 0.80, 0.90), (cx * 1.15, cy * 1.15, 0.55), "core")
	bone("leg_lo_%d" % i, (cx * 1.15, cy * 1.15, 0.55), (cx * 1.55, cy * 1.55, 0.05), "leg_up_%d" % i)
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

# idle：壳体轻微起伏呼吸（49 帧循环）
make_clip("idle", {
	"core": [(1, 0, 0, 0), (25, 1.5, 0, 0), (49, 0, 0, 0)],
}, loc_keys={"core": [(1, 0, 0, 0), (25, 0, 0, -0.02), (49, 0, 0, 0)]})

# walk：三组三脚架交替（0,3 / 1,4 / 2,5 三相位，25 帧循环）
_wk = {"core": [(1, 0, 0, 0), (13, 0, 0, 0), (25, 0, 0, 0)]}
for i in range(6):
	ph = (i % 3) * 8
	kl = []
	for f in [1, 9, 17, 25]:
		ang = 14.0 * math.sin(2 * math.pi * (f - 1 + ph * 2) / 24.0)
		kl.append((f, ang, 0, 0))
	_wk["leg_up_%d" % i] = kl
	kl2 = []
	for f in [1, 9, 17, 25]:
		ang = 20.0 * max(0.0, math.sin(2 * math.pi * (f - 1 + ph * 2) / 24.0 + math.pi * 0.5))
		kl2.append((f, -ang, 0, 0))
	_wk["leg_lo_%d" % i] = kl2
make_clip("walk", _wk, loc_keys={"core": [(1, 0, 0, 0), (7, 0, 0, -0.04), (13, 0, 0, 0), (19, 0, 0, -0.04), (25, 0, 0, 0)]})

# aim：六腿外张钉地、穹顶下压前倾（9 帧循环保持）
_ak = {"core": [(1, 0, 0, 0), (4, 8, 0, 0), (9, 8, 0, 0)]}
for i in range(6):
	a = i * math.tau / 6.0
	_ak["leg_up_%d" % i] = [(1, 0, 0, 0), (4, -6, 0, 0), (9, -6, 0, 0)]
	_ak["leg_lo_%d" % i] = [(1, 0, 0, 0), (4, 8, 0, 0), (9, 8, 0, 0)]
make_clip("aim", _ak, loc_keys={"core": [(1, 0, 0, 0), (4, 0, 0, -0.08), (9, 0, 0, -0.08)]})

# hit：受击震颤（7 帧）
make_clip("hit", {
	"core": [(1, 0, 0, 0), (2, -5, 4, 0), (4, 3, -4, 0), (7, 0, 0, 0)],
})

# die：六腿收拢瘫折、穹顶落地（21 帧，停在倒姿）
_dk = {"core": [(1, 0, 0, 0), (8, 10, 0, 0), (21, 12, 0, 0)]}
for i in range(6):
	_dk["leg_up_%d" % i] = [(1, 0, 0, 0), (8, 30 if i % 2 else -30, 0, 0), (21, 32 if i % 2 else -32, 0, 0)]
	_dk["leg_lo_%d" % i] = [(1, 0, 0, 0), (8, -45 if i % 2 else 45, 0, 0), (21, -48 if i % 2 else 48, 0, 0)]
make_clip("die", _dk, loc_keys={"core": [(1, 0, 0, 0), (8, 0, 0, -0.45), (21, 0, 0, -0.48)]})

reset_pose()
scene = bpy.context.scene
scene.render.fps = 24
root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
out = os.path.join(root, OUT)
os.makedirs(os.path.dirname(out), exist_ok=True)
bpy.ops.export_scene.gltf(filepath=out, export_format='GLB', export_animations=True, export_animation_mode='NLA_TRACKS')
print("[guardian] exported:", out)
