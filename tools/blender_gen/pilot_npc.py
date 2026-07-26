# 管线试点：无头 Blender 生成带骨骼与走路循环的卡通小人，导出 glb 供 Godot 使用。
# 运行：/Applications/Blender.app/Contents/MacOS/Blender --background --python tools/blender_gen/pilot_npc.py
import bpy
import math
from mathutils import Vector

OUT = "assets/models/pilot_npc.glb"

# 清空场景
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)


def mat(name, rgb):
	"""纯色粗糙材质（到 Godot 即平色卡通底）。"""
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


SKIN = mat("skin", (0.90, 0.70, 0.54))
TUNIC = mat("tunic", (0.16, 0.42, 0.22))
PANTS = mat("pants", (0.32, 0.26, 0.20))
HAIR = mat("hair", (0.55, 0.38, 0.16))
DARK = mat("dark", (0.12, 0.10, 0.10))


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
	bpy.ops.mesh.primitive_cone_add(vertices=8, radius1=r1, radius2=r2, depth=depth, location=loc)
	o = bpy.context.active_object
	o.name = name
	o.data.materials.append(material)
	return o


# 身体部件（面向 Blender -Y，导出后对应 Godot -Z 前方）
parts = []
parts.append(box("torso", (0, 0, 1.05), (0.42, 0.26, 0.55), TUNIC))
parts.append(sphere("head", (0, -0.02, 1.55), (0.16, 0.15, 0.17), SKIN))
parts.append(sphere("eye_l", (-0.06, -0.145, 1.58), (0.022, 0.016, 0.030), DARK))
parts.append(sphere("eye_r", (0.06, -0.145, 1.58), (0.022, 0.016, 0.030), DARK))
parts.append(sphere("hair", (0, 0.02, 1.63), (0.155, 0.14, 0.13), HAIR))
parts.append(cone("cap", (0, 0.06, 1.80), 0.15, 0.015, 0.34, TUNIC))
for sx, tag in [(-1, "l"), (1, "r")]:
	parts.append(box("upperarm_" + tag, (sx * 0.26, 0, 1.22), (0.09, 0.10, 0.26), TUNIC))
	parts.append(box("forearm_" + tag, (sx * 0.26, 0, 0.94), (0.08, 0.09, 0.24), SKIN))
	parts.append(box("thigh_" + tag, (sx * 0.11, 0, 0.62), (0.11, 0.12, 0.30), PANTS))
	parts.append(box("shin_" + tag, (sx * 0.11, 0, 0.24), (0.10, 0.11, 0.28), PANTS))

# 合并为单一网格
for p in parts:
	p.select_set(True)
bpy.context.view_layer.objects.active = parts[0]
bpy.ops.object.join()
body = parts[0]
body.name = "PilotBody"

# 骨骼：脊柱/头 + 双臂双节 + 双腿双节
bpy.ops.object.armature_add(enter_editmode=True, location=(0, 0, 0))
arm = bpy.context.active_object
arm.name = "PilotRig"
eb = arm.data.edit_bones
base = eb[0]
base.name = "spine"
base.head = (0, 0, 0.85)
base.tail = (0, 0, 1.30)


def bone(name, head, tail, parent):
	b = eb.new(name)
	b.head = head
	b.tail = tail
	b.parent = eb[parent]
	return b


bone("head", (0, 0, 1.38), (0, 0, 1.62), "spine")
for sx, tag in [(-1.0, "l"), (1.0, "r")]:
	bone("upperarm_" + tag, (sx * 0.24, 0, 1.32), (sx * 0.26, 0, 1.06), "spine")
	bone("forearm_" + tag, (sx * 0.26, 0, 1.06), (sx * 0.26, 0, 0.82), "upperarm_" + tag)
	bone("thigh_" + tag, (sx * 0.11, 0, 0.80), (sx * 0.11, 0, 0.46), "spine")
	bone("shin_" + tag, (sx * 0.11, 0, 0.46), (sx * 0.11, 0, 0.08), "thigh_" + tag)
bpy.ops.object.mode_set(mode='OBJECT')

# 自动权重蒙皮
body.select_set(True)
arm.select_set(True)
bpy.context.view_layer.objects.active = arm
bpy.ops.object.parent_set(type='ARMATURE_AUTO')

# 走路循环：24 帧一圈，腿对摆 + 膝弯 + 手臂反摆 + 脊柱起伏
scene = bpy.context.scene
scene.frame_start = 1
scene.frame_end = 25
scene.render.fps = 24
arm.animation_data_create()
pb = arm.pose.bones


def key(bname, frame, rx, rz=0.0):
	b = pb[bname]
	b.rotation_mode = 'XYZ'
	b.rotation_euler = (math.radians(rx), 0.0, math.radians(rz))
	b.keyframe_insert("rotation_euler", frame=frame)


for f, ph in [(1, 0.0), (7, 0.5), (13, 1.0), (19, 1.5), (25, 2.0)]:
	s = math.sin(ph * math.pi)
	key("thigh_l", f, -32.0 * s)
	key("thigh_r", f, 32.0 * s)
	key("shin_l", f, 12.0 + 40.0 * max(0.0, math.sin(ph * math.pi + 0.8)))
	key("shin_r", f, 12.0 + 40.0 * max(0.0, math.sin(ph * math.pi + math.pi + 0.8)))
	key("upperarm_l", f, 26.0 * s)
	key("upperarm_r", f, -26.0 * s)
	key("forearm_l", f, -14.0)
	key("forearm_r", f, -14.0)
	sp = pb["spine"]
	sp.location = (0, 0, -0.035 * abs(math.cos(ph * math.pi)))
	sp.keyframe_insert("location", frame=f)
	key("head", f, 4.0 * s)

# Blender 5 动作已分层化，不再逐个改插值；默认贝塞尔对走路循环足够平滑。

# 导出 glb（含动画）
import os
root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
out = os.path.join(root, OUT)
os.makedirs(os.path.dirname(out), exist_ok=True)
bpy.ops.export_scene.gltf(filepath=out, export_format='GLB', export_animations=True)
print("[pilot] exported:", out)
