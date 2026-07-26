# 夜行蝙蝠：无头 Blender 生成蒙皮蝙蝠与动画（flap/dive/hit），导出 glb。
# 运行：/Applications/Blender.app/Contents/MacOS/Blender --background --python tools/blender_gen/keese.py
import bpy
import math
import os

OUT = "assets/models/keese.glb"

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


FUR = mat("keese_fur", (0.22, 0.14, 0.20))
MEMB = mat("keese_membrane", (0.30, 0.16, 0.28))
EYE = mat("keese_eye", (1.0, 0.20, 0.12), emit=(1.0, 0.10, 0.05))
FANG = mat("keese_fang", (0.92, 0.88, 0.78))


def sphere(name, loc, scale, material):
	bpy.ops.mesh.primitive_uv_sphere_add(segments=10, ring_count=6, radius=1.0, location=loc)
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
	bpy.ops.mesh.primitive_cone_add(vertices=7, radius1=r1, radius2=r2, depth=depth, location=loc, rotation=rot)
	o = bpy.context.active_object
	o.name = name
	o.data.materials.append(material)
	return o


# 小球身、尖耳、红眼、獠牙、两片膜翼（面向 -Y）
parts = []
parts.append(sphere("body", (0, 0, 0), (0.20, 0.26, 0.18), FUR))
parts.append(sphere("head", (0, -0.22, 0.10), (0.14, 0.13, 0.12), FUR))
for sx in [-1, 1]:
	parts.append(cone("ear", (sx * 0.09, -0.20, 0.24), 0.05, 0.008, 0.16, FUR, rot=(0, sx * math.radians(-18), 0)))
	parts.append(sphere("eye", (sx * 0.055, -0.33, 0.12), (0.028, 0.02, 0.028), EYE))
	parts.append(cone("fang", (sx * 0.03, -0.32, 0.02), 0.012, 0.003, 0.06, FANG, rot=(math.radians(180), 0, 0)))
	parts.append(box("wing", (sx * 0.42, 0.06, 0.04), (0.70, 0.42, 0.025), MEMB, rot=(0, sx * math.radians(14), 0)))

for p in parts:
	p.select_set(True)
bpy.context.view_layer.objects.active = parts[0]
bpy.ops.object.join()
body = parts[0]
body.name = "KeeseBody"

bpy.ops.object.armature_add(enter_editmode=True, location=(0, 0, 0))
arm = bpy.context.active_object
arm.name = "KeeseRig"
eb = arm.data.edit_bones
base = eb[0]
base.name = "root"
base.head = (0, 0, 0)
base.tail = (0, -0.20, 0.06)


def bone(name, head, tail, parent):
	b = eb.new(name)
	b.head = head
	b.tail = tail
	b.parent = eb[parent]
	return b


bone("wing_l", (-0.10, 0.02, 0.04), (-0.55, 0.08, 0.05), "root")
bone("wing_r", (0.10, 0.02, 0.04), (0.55, 0.08, 0.05), "root")
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


def make_clip(name, keys):
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
	track = arm.animation_data.nla_tracks.new()
	track.name = name
	track.strips.new(name, 1, act)
	track.mute = True
	arm.animation_data.action = None

# flap：双翼快速扇动（13 帧循环）
make_clip("flap", {
	"wing_l": [(1, 0, 0, -45), (7, 0, 0, 40), (13, 0, 0, -45)],
	"wing_r": [(1, 0, 0, 45), (7, 0, 0, -40), (13, 0, 0, 45)],
	"root": [(1, 3, 0, 0), (7, -3, 0, 0), (13, 3, 0, 0)],
})

# dive：收翼俯冲（9 帧保持）
make_clip("dive", {
	"wing_l": [(1, 0, 0, -10), (4, 0, 25, 60), (9, 0, 25, 60)],
	"wing_r": [(1, 0, 0, 10), (4, 0, -25, -60), (9, 0, -25, -60)],
	"root": [(1, 0, 0, 0), (4, 25, 0, 0), (9, 25, 0, 0)],
})

# hit：受击痉挛（7 帧）
make_clip("hit", {
	"root": [(1, 0, 0, 0), (2, -14, 8, 0), (5, 6, -6, 0), (7, 0, 0, 0)],
})

reset_pose()
scene = bpy.context.scene
scene.render.fps = 24
root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
out = os.path.join(root, OUT)
os.makedirs(os.path.dirname(out), exist_ok=True)
bpy.ops.export_scene.gltf(filepath=out, export_format='GLB', export_animations=True, export_animation_mode='NLA_TRACKS')
print("[keese] exported:", out)
