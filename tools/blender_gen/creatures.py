# 阔野动物：Blender 生成野猪/狼/熊蒙皮模型与动画（idle/walk/run/attack/hit/die），各导一个 glb。
# 运行：/Applications/Blender.app/Contents/MacOS/Blender --background --python tools/blender_gen/creatures.py
# 约定：Blender +Y 为 Godot -Z（面向 -Z），Blender Z+ 为 Godot Y（向上）。前向件位于 +Y，后向件位于 -Y。
import bpy
import math
import mathutils
import os
import bmesh


def mat(name, rgb, emit=None, emit_strength=0.6):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = None
    for n in m.node_tree.nodes:
        if n.type == "BSDF_PRINCIPLED":
            bsdf = n
            break
    if bsdf is None:
        bsdf = m.node_tree.nodes.new("ShaderNodeBsdfPrincipled")
        out = None
        for n in m.node_tree.nodes:
            if n.type == "OUTPUT_MATERIAL":
                out = n
                break
        if out is None:
            raise RuntimeError(f"material {name}: Material Output missing")
        linked = False
        for link in m.node_tree.links:
            if link.to_node == out and link.to_socket.name == "Surface":
                linked = True
                break
        if not linked:
            m.node_tree.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    if "Base Color" not in bsdf.inputs:
        raise RuntimeError(f"material {name}: Principled missing Base Color")
    bsdf.inputs["Base Color"].default_value = (*rgb, 1.0)
    if "Roughness" not in bsdf.inputs:
        raise RuntimeError(f"material {name}: Principled missing Roughness")
    bsdf.inputs["Roughness"].default_value = 1.0
    if "Metallic" in bsdf.inputs:
        bsdf.inputs["Metallic"].default_value = 0.0
    if emit is not None:
        emit_key = None
        for k in ("Emission Color", "Emission"):
            if k in bsdf.inputs:
                emit_key = k
                break
        if emit_key is None:
            raise RuntimeError(f"material {name}: Principled missing Emission Color/Emission")
        bsdf.inputs[emit_key].default_value = (*emit, 1.0)
        if "Emission Strength" not in bsdf.inputs:
            raise RuntimeError(f"material {name}: Principled missing Emission Strength")
        bsdf.inputs["Emission Strength"].default_value = float(emit_strength)
    return m


def rigid_assign(obj, bone):
    if not bone:
        raise RuntimeError(f"rigid_assign: bone name empty for {obj.name}")
    vg = obj.vertex_groups.new(name=bone)
    indices = [v.index for v in obj.data.vertices]
    if indices:
        vg.add(indices, 1.0, "REPLACE")
    if obj.data.validate(verbose=True):
        raise RuntimeError(f"mesh {obj.name} for bone {bone} required repair after rigid_assign")
    return obj


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
    bpy.ops.mesh.primitive_cone_add(vertices=10, radius1=r1, radius2=r2, depth=depth, location=loc, rotation=rot)
    o = bpy.context.active_object
    o.name = name
    o.data.materials.append(material)
    return o


def create_tube_mesh(name, points, radii, segments, material):
    if len(points) != len(radii):
        raise ValueError(f"tube {name}: points/radii length mismatch {len(points)} vs {len(radii)}")
    if len(points) < 2:
        raise ValueError(f"tube {name}: need at least 2 points, got {len(points)}")
    if segments < 3:
        raise ValueError(f"tube {name}: segments must be >=3, got {segments}")
    for i, r in enumerate(radii):
        if not math.isfinite(r) or r <= 0:
            raise ValueError(f"tube {name}: radius[{i}] invalid {r}")
    for i, p in enumerate(points):
        if len(p) != 3:
            raise ValueError(f"tube {name}: point[{i}] must be 3-tuple")
        for c in p:
            if not math.isfinite(c):
                raise ValueError(f"tube {name}: point[{i}] non-finite {p}")
    n_rings = len(points)
    pts = [mathutils.Vector(p) for p in points]
    tangents = []
    for i in range(n_rings):
        if i == 0:
            t = (pts[1] - pts[0]).normalized()
        elif i == n_rings - 1:
            t = (pts[-1] - pts[-2]).normalized()
        else:
            t = (pts[i + 1] - pts[i - 1]).normalized()
        if t.length < 1e-6:
            raise RuntimeError(f"tube {name}: degenerate tangent at ring {i}")
        tangents.append(t)
    verts = []
    faces = []
    for p, r, t in zip(pts, radii, tangents):
        up = mathutils.Vector((0, 0, 1))
        if abs(t.dot(up)) > 0.99:
            up = mathutils.Vector((0, 1, 0))
        u = t.cross(up)
        if u.length < 1e-6:
            u = mathutils.Vector((1, 0, 0))
        u.normalize()
        v = t.cross(u)
        v.normalize()
        for j in range(segments):
            ang = 2 * math.pi * j / segments
            offset = (math.cos(ang) * u + math.sin(ang) * v) * r
            verts.append(p + offset)
    for i in range(n_rings - 1):
        for j in range(segments):
            jn = (j + 1) % segments
            a = i * segments + j
            b = i * segments + jn
            c = (i + 1) * segments + jn
            d = (i + 1) * segments + j
            faces.append((a, b, c))
            faces.append((a, c, d))
    cap_base = len(verts)
    verts.append(pts[0])
    cap_tip = len(verts)
    verts.append(pts[-1])
    for j in range(segments):
        jn = (j + 1) % segments
        a = j
        b = jn
        faces.append((cap_base, b, a))
    off = (n_rings - 1) * segments
    for j in range(segments):
        jn = (j + 1) % segments
        a = off + j
        b = off + jn
        faces.append((cap_tip, a, b))
    mesh = bpy.data.meshes.new(name + "_mesh")
    mesh.from_pydata([tuple(v) for v in verts], [], faces)
    mesh.update()
    if mesh.validate(verbose=True):
        raise RuntimeError(f"tube {name}: mesh required repair, invalid geometry")
    bm = bmesh.new()
    try:
        bm.from_mesh(mesh)
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        bm.to_mesh(mesh)
    finally:
        bm.free()
    mesh.update()
    if mesh.validate(verbose=True):
        raise RuntimeError(f"tube {name}: mesh invalid after normal recalc")
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(material)
    return obj


def boar_parts():
    fur = mat("boar_fur", (0.30, 0.20, 0.14))
    mane_mat = mat("boar_mane", (0.13, 0.10, 0.075))
    tusk_mat = mat("boar_tusk", (0.92, 0.83, 0.60))
    eye_mat = mat("boar_eye", (0.08, 0.05, 0.04), emit=(0.35, 0.16, 0.05), emit_strength=0.6)
    nose_mat = mat("boar_nose", (0.07, 0.05, 0.04))
    nostril_mat = mat("boar_nostril", (0.04, 0.03, 0.02))
    ear_inner_mat = mat("boar_ear_inner", (0.42, 0.28, 0.20))
    p = []
    o = sphere("body", (0, 0.02, 0.72), (0.56, 0.88, 0.46), fur)
    rigid_assign(o, "spine"); p.append(o)
    o = sphere("hump", (0, 0.30, 1.00), (0.32, 0.42, 0.30), mane_mat)
    rigid_assign(o, "spine"); p.append(o)
    o = sphere("head", (0, 0.72, 0.78), (0.38, 0.42, 0.32), fur)
    rigid_assign(o, "head"); p.append(o)
    o = box("snout", (0, 1.06, 0.70), (0.30, 0.42, 0.22), fur)
    rigid_assign(o, "head"); p.append(o)
    o = sphere("nose_disk", (0, 1.32, 0.70), (0.14, 0.07, 0.11), nose_mat)
    rigid_assign(o, "head"); p.append(o)
    for sx in [-1, 1]:
        o = sphere("nostril", (sx * 0.045, 1.36, 0.71), (0.025, 0.015, 0.025), nostril_mat)
        rigid_assign(o, "head"); p.append(o)
        o = box("ear_outer", (sx * 0.31, 0.72, 1.04), (0.16, 0.07, 0.24), fur, rot=(0, sx * math.radians(-20), 0))
        rigid_assign(o, "head"); p.append(o)
        o = box("ear_inner", (sx * 0.31, 0.76, 1.05), (0.10, 0.02, 0.15), ear_inner_mat, rot=(0, sx * math.radians(-20), 0))
        rigid_assign(o, "head"); p.append(o)
        o = sphere("eye", (sx * 0.18, 1.00, 0.88), (0.060, 0.045, 0.060), eye_mat)
        rigid_assign(o, "head"); p.append(o)
        pts = [
            (sx * 0.23, 1.14, 0.64),
            (sx * 0.28, 1.22, 0.62),
            (sx * 0.33, 1.30, 0.64),
            (sx * 0.35, 1.36, 0.70),
            (sx * 0.32, 1.38, 0.78),
            (sx * 0.26, 1.36, 0.83),
        ]
        radii = [0.048, 0.040, 0.033, 0.026, 0.018, 0.010]
        o = create_tube_mesh("tusk", pts, radii, 8, tusk_mat)
        rigid_assign(o, "head"); p.append(o)
    for i in range(7):
        y = 0.38 - i * 0.15
        h = 0.16 if i < 2 else 0.13 if i < 4 else 0.10
        bpy.ops.mesh.primitive_cone_add(vertices=4, radius1=0.06, radius2=0.015, depth=h, location=(0, y, 1.20 + h * 0.35))
        o = bpy.context.active_object
        o.name = "bristle"
        o.rotation_euler = (0, 0, math.radians(45))
        o.data.materials.append(mane_mat)
        rigid_assign(o, "spine"); p.append(o)
    o = cone("tail", (0, -0.82, 0.88), 0.05, 0.02, 0.28, fur, rot=(math.radians(42), 0, 0))
    rigid_assign(o, "tail"); p.append(o)
    hip_h = 0.58
    knee = hip_h * 0.45
    for sx in [-0.36, 0.36]:
        for sz, tag in [(0.52, "f"), (-0.52, "h")]:
            side = "l" if sx < 0 else "r"
            bone_up = f"up_{tag}{side}"
            bone_lo = f"lo_{tag}{side}"
            up_bottom = knee - 0.03
            up_center = (hip_h + up_bottom) * 0.5
            up_depth = hip_h - up_bottom
            o = cone(f"leg_up_{tag}{side}", (sx, sz, up_center), 0.105, 0.088, up_depth, fur)
            rigid_assign(o, bone_up); p.append(o)
            lo_top = knee + 0.03
            lo_bottom = 0.10
            lo_center = (lo_top + lo_bottom) * 0.5
            lo_depth = lo_top - lo_bottom
            o = cone(f"leg_lo_{tag}{side}", (sx, sz, lo_center), 0.088, 0.070, lo_depth, fur)
            rigid_assign(o, bone_lo); p.append(o)
            o = box("hoof", (sx, sz, 0.05), (0.15, 0.17, 0.10), mane_mat)
            rigid_assign(o, bone_lo); p.append(o)
    return p


def wolf_parts():
    fur = mat("wolf_fur", (0.15, 0.16, 0.19))
    light = mat("wolf_light", (0.30, 0.31, 0.29))
    dark = mat("wolf_dark", (0.07, 0.07, 0.08))
    eye_mat = mat("wolf_eye", (0.14, 0.10, 0.04), emit=(0.52, 0.34, 0.08), emit_strength=0.85)
    ear_inner_mat = mat("wolf_ear_inner", (0.58, 0.40, 0.32))
    nose_mat = mat("wolf_nose", (0.06, 0.06, 0.07))
    p = []
    o = sphere("body", (0, 0.02, 0.82), (0.36, 0.68, 0.34), fur)
    rigid_assign(o, "spine"); p.append(o)
    o = sphere("chest", (0, 0.42, 0.86), (0.34, 0.30, 0.32), fur)
    rigid_assign(o, "spine"); p.append(o)
    o = sphere("waist", (0, -0.32, 0.82), (0.28, 0.22, 0.30), fur)
    rigid_assign(o, "spine"); p.append(o)
    o = cone("neck", (0, 0.56, 1.02), 0.26, 0.20, 0.60, fur, rot=(math.radians(-55), 0, 0))
    rigid_assign(o, "neck"); p.append(o)
    o = sphere("head", (0, 0.82, 1.24), (0.31, 0.34, 0.29), fur)
    rigid_assign(o, "head"); p.append(o)
    o = sphere("muzzle", (0, 1.10, 1.14), (0.15, 0.22, 0.11), light)
    rigid_assign(o, "head"); p.append(o)
    o = sphere("nose", (0, 1.32, 1.16), (0.060, 0.050, 0.055), nose_mat)
    rigid_assign(o, "head"); p.append(o)
    for sx in [-1, 1]:
        bpy.ops.mesh.primitive_cone_add(vertices=3, radius1=0.13, radius2=0.006, depth=0.20, location=(sx * 0.18, 0.83, 1.54))
        o = bpy.context.active_object
        o.name = "ear_outer"
        o.rotation_euler = (0, sx * math.radians(-12), 0)
        o.data.materials.append(fur)
        rigid_assign(o, "head"); p.append(o)
        bpy.ops.mesh.primitive_cone_add(vertices=3, radius1=0.055, radius2=0.003, depth=0.12, location=(sx * 0.18, 0.86, 1.51))
        oi = bpy.context.active_object
        oi.name = "ear_inner"
        oi.rotation_euler = (0, sx * math.radians(-12), 0)
        oi.data.materials.append(ear_inner_mat)
        rigid_assign(oi, "head"); p.append(oi)
        o = sphere("eye", (sx * 0.15, 1.13, 1.30), (0.058, 0.040, 0.058), eye_mat)
        rigid_assign(o, "head"); p.append(o)
    tail_pts = [
        (0, -0.58, 0.92),
        (0, -0.80, 0.88),
        (0, -1.02, 0.78),
        (0, -1.20, 0.62),
        (0, -1.34, 0.34),
    ]
    tail_radii = [0.16, 0.15, 0.13, 0.10, 0.06]
    o = create_tube_mesh("tail", tail_pts, tail_radii, 10, fur)
    rigid_assign(o, "tail"); p.append(o)
    hip_h = 0.64
    knee = hip_h * 0.45
    for sx in [-0.28, 0.28]:
        for sz, tag in [(0.52, "f"), (-0.52, "h")]:
            side = "l" if sx < 0 else "r"
            bone_up = f"up_{tag}{side}"
            bone_lo = f"lo_{tag}{side}"
            up_bottom = knee - 0.03
            up_center = (hip_h + up_bottom) * 0.5
            up_depth = hip_h - up_bottom
            o = cone(f"leg_up_{tag}{side}", (sx, sz, up_center), 0.090, 0.072, up_depth, fur)
            rigid_assign(o, bone_up); p.append(o)
            lo_top = knee + 0.03
            lo_bottom = 0.10
            lo_center = (lo_top + lo_bottom) * 0.5
            lo_depth = lo_top - lo_bottom
            o = cone(f"leg_lo_{tag}{side}", (sx, sz, lo_center), 0.072, 0.055, lo_depth, fur)
            rigid_assign(o, bone_lo); p.append(o)
            o = box("paw", (sx, sz, 0.05), (0.14, 0.18, 0.09), dark)
            rigid_assign(o, bone_lo); p.append(o)
    return p


def bear_parts():
    fur = mat("bear_fur", (0.29, 0.18, 0.105))
    muzzle_mat = mat("bear_muzzle", (0.58, 0.42, 0.26))
    dark = mat("bear_dark", (0.07, 0.055, 0.045))
    eye_mat = mat("bear_eye", (0.08, 0.05, 0.03), emit=(0.30, 0.16, 0.06), emit_strength=0.90)
    ear_inner_mat = mat("bear_ear_inner", (0.62, 0.46, 0.36))
    nose_mat = mat("bear_nose", (0.07, 0.055, 0.045))
    p = []
    o = sphere("body", (0, -0.02, 1.18), (0.84, 1.05, 0.91), fur)
    rigid_assign(o, "spine"); p.append(o)
    o = sphere("chest", (0, 0.45, 1.22), (0.78, 0.48, 0.80), fur)
    rigid_assign(o, "spine"); p.append(o)
    o = sphere("rump", (0, -0.62, 1.18), (0.76, 0.52, 0.82), fur)
    rigid_assign(o, "spine"); p.append(o)
    o = sphere("head", (0, 0.72, 1.62), (0.57, 0.60, 0.57), fur)
    rigid_assign(o, "head"); p.append(o)
    o = sphere("muzzle", (0, 1.18, 1.46), (0.37, 0.36, 0.22), muzzle_mat)
    rigid_assign(o, "head"); p.append(o)
    o = sphere("nose", (0, 1.45, 1.58), (0.11, 0.08, 0.07), nose_mat)
    rigid_assign(o, "head"); p.append(o)
    for sx in [-1, 1]:
        o = sphere("ear_outer", (sx * 0.42, 0.67, 2.02), (0.18, 0.14, 0.18), fur)
        rigid_assign(o, "head"); p.append(o)
        o = sphere("ear_inner", (sx * 0.42, 0.76, 2.00), (0.10, 0.08, 0.10), ear_inner_mat)
        rigid_assign(o, "head"); p.append(o)
        o = sphere("eye", (sx * 0.26, 1.25, 1.80), (0.075, 0.028, 0.075), eye_mat)
        rigid_assign(o, "head"); p.append(o)
    o = sphere("tail", (0, -1.22, 1.28), (0.16, 0.14, 0.16), fur)
    rigid_assign(o, "tail"); p.append(o)
    hip_h = 0.78
    knee = hip_h * 0.45
    for sx in [-0.44, 0.44]:
        for sz, tag in [(0.68, "f"), (-0.68, "h")]:
            side = "l" if sx < 0 else "r"
            bone_up = f"up_{tag}{side}"
            bone_lo = f"lo_{tag}{side}"
            up_bottom = knee - 0.03
            up_center = (hip_h + up_bottom) * 0.5
            up_depth = hip_h - up_bottom
            o = cone(f"leg_up_{tag}{side}", (sx, sz, up_center), 0.17, 0.14, up_depth, fur)
            rigid_assign(o, bone_up); p.append(o)
            lo_top = knee + 0.03
            lo_bottom = 0.12
            lo_center = (lo_top + lo_bottom) * 0.5
            lo_depth = lo_top - lo_bottom
            o = cone(f"leg_lo_{tag}{side}", (sx, sz, lo_center), 0.14, 0.11, lo_depth, fur)
            rigid_assign(o, bone_lo); p.append(o)
            o = box("paw", (sx, sz, 0.07), (0.28, 0.32, 0.14), dark)
            rigid_assign(o, bone_lo); p.append(o)
    return p


def reset_pose(pb):
    for b in pb:
        b.rotation_mode = "XYZ"
        b.rotation_euler = (0.0, 0.0, 0.0)
        b.location = (0.0, 0.0, 0.0)
        b.scale = (1.0, 1.0, 1.0)


def make_clip(arm, pb, name, keys, loc_keys=None):
    reset_pose(pb)
    act = bpy.data.actions.new(name)
    if arm.animation_data is None:
        arm.animation_data_create()
    arm.animation_data.action = act
    for bname, klist in keys.items():
        if bname not in pb:
            raise RuntimeError(f"clip {name}: bone {bname} missing")
        b = pb[bname]
        b.rotation_mode = "XYZ"
        for (f, rx, ry, rz) in klist:
            b.rotation_euler = (math.radians(rx), math.radians(ry), math.radians(rz))
            b.keyframe_insert("rotation_euler", frame=f)
    if loc_keys:
        for bname, klist in loc_keys.items():
            if bname not in pb:
                raise RuntimeError(f"clip {name} loc: bone {bname} missing")
            b = pb[bname]
            for (f, x, y, z) in klist:
                b.location = (x, y, z)
                b.keyframe_insert("location", frame=f)
    track = arm.animation_data.nla_tracks.new()
    track.name = name
    track.strips.new(name, 1, act)
    track.mute = True
    arm.animation_data.action = None


def validate_weights(body, arm, out_name):
    bone_names = set(b.name for b in arm.data.bones)
    for vg in body.vertex_groups:
        if vg.name not in bone_names:
            raise RuntimeError(f"validate {out_name}: vertex group {vg.name} has no matching bone")
    for v in body.data.vertices:
        groups = [g for g in v.groups if abs(g.weight) > 1e-6]
        if len(groups) != 1:
            raise RuntimeError(f"validate {out_name}: vertex {v.index} has {len(groups)} influences, expected exactly 1")
        w = groups[0].weight
        if not math.isfinite(w):
            raise RuntimeError(f"validate {out_name}: vertex {v.index} weight non-finite {w}")
        if abs(w - 1.0) > 1e-4:
            raise RuntimeError(f"validate {out_name}: vertex {v.index} weight {w} != 1.0")
        if w < -1e-6 or w > 1.0 + 1e-4:
            raise RuntimeError(f"validate {out_name}: vertex {v.index} weight out of range {w}")
        gi = groups[0].group
        vg_name = body.vertex_groups[gi].name
        if vg_name not in bone_names:
            raise RuntimeError(f"validate {out_name}: vertex {v.index} group {vg_name} not a bone")


def build(out_name, parts, leg_x, leg_zf, leg_zb, hip_h, spine_z, head_z, tail_z):
    for p in parts:
        p.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.join()
    body = parts[0]
    body.name = "Body"
    body.data.name = out_name.replace(".glb", "") + "_Body"
    if body.data.validate(verbose=True):
        raise RuntimeError(f"mesh {out_name}: joined mesh required repair")
    bpy.ops.object.armature_add(enter_editmode=True, location=(0, 0, 0))
    arm = bpy.context.active_object
    arm.name = "Rig"
    eb = arm.data.edit_bones
    base = eb[0]
    base.name = "spine"
    base.head = (0, leg_zb * 0.55, spine_z)
    base.tail = (0, leg_zf * 0.62, spine_z + 0.06)

    def bone(bname, head, tail, parent):
        b = arm.data.edit_bones.new(bname)
        b.head = head
        b.tail = tail
        b.parent = eb[parent]
        return b

    bone("neck", (0, leg_zf * 0.62, spine_z + 0.06), (0, leg_zf * 1.05, head_z), "spine")
    bone("head", (0, leg_zf * 1.05, head_z), (0, leg_zf * 1.45, head_z - 0.06), "neck")
    bone("tail", (0, leg_zb * 0.9, spine_z + 0.04), (0, leg_zb * 1.25, tail_z), "spine")
    for sx, stag in [(-1, "l"), (1, "r")]:
        for zv, ztag in [(leg_zf, "f"), (leg_zb, "h")]:
            bone("up_" + ztag + stag, (sx * leg_x, zv, hip_h), (sx * leg_x, zv, hip_h * 0.45), "spine")
            bone("lo_" + ztag + stag, (sx * leg_x, zv, hip_h * 0.45), (sx * leg_x, zv, 0.05), "up_" + ztag + stag)
    bpy.ops.object.mode_set(mode="OBJECT")
    mod = body.modifiers.new(name="Armature", type="ARMATURE")
    mod.object = arm
    mod.use_vertex_groups = True
    mod.use_bone_envelopes = False
    body.parent = arm
    validate_weights(body, arm, out_name)
    if body.data.validate(verbose=True):
        raise RuntimeError(f"mesh {out_name}: post-rig mesh required repair")
    pb = arm.pose.bones
    species = out_name.replace(".glb", "")
    if species == "boar":
        walk_keys = {
            "up_fl": [(1, 18, 0, 0), (13, -18, 0, 0), (25, 18, 0, 0)],
            "up_hr": [(1, 18, 0, 0), (13, -18, 0, 0), (25, 18, 0, 0)],
            "up_fr": [(1, -18, 0, 0), (13, 18, 0, 0), (25, -18, 0, 0)],
            "up_hl": [(1, -18, 0, 0), (13, 18, 0, 0), (25, -18, 0, 0)],
            "lo_fl": [(1, 6, 0, 0), (7, 24, 0, 0), (13, 6, 0, 0), (19, 18, 0, 0), (25, 6, 0, 0)],
            "lo_hr": [(1, 6, 0, 0), (7, 24, 0, 0), (13, 6, 0, 0), (19, 18, 0, 0), (25, 6, 0, 0)],
            "lo_fr": [(1, 24, 0, 0), (7, 6, 0, 0), (13, 18, 0, 0), (19, 6, 0, 0), (25, 24, 0, 0)],
            "lo_hl": [(1, 24, 0, 0), (7, 6, 0, 0), (13, 18, 0, 0), (19, 6, 0, 0), (25, 24, 0, 0)],
            "neck": [(1, 2, 0, 0), (13, -2, 0, 0), (25, 2, 0, 0)],
        }
        walk_loc = {"spine": [(1, 0, 0, 0), (7, 0, 0, -0.02), (13, 0, 0, 0), (19, 0, 0, -0.02), (25, 0, 0, 0)]}
        run_keys = {
            "up_fl": [(1, 24, 0, 0), (9, -24, 0, 0), (17, 24, 0, 0)],
            "up_hr": [(1, 24, 0, 0), (9, -24, 0, 0), (17, 24, 0, 0)],
            "up_fr": [(1, -24, 0, 0), (9, 24, 0, 0), (17, -24, 0, 0)],
            "up_hl": [(1, -24, 0, 0), (9, 24, 0, 0), (17, -24, 0, 0)],
            "lo_fl": [(1, 8, 0, 0), (5, 32, 0, 0), (9, 8, 0, 0), (13, 26, 0, 0), (17, 8, 0, 0)],
            "lo_hr": [(1, 8, 0, 0), (5, 32, 0, 0), (9, 8, 0, 0), (13, 26, 0, 0), (17, 8, 0, 0)],
            "lo_fr": [(1, 32, 0, 0), (5, 8, 0, 0), (9, 26, 0, 0), (13, 8, 0, 0), (17, 32, 0, 0)],
            "lo_hl": [(1, 32, 0, 0), (5, 8, 0, 0), (9, 26, 0, 0), (13, 8, 0, 0), (17, 32, 0, 0)],
            "neck": [(1, 3, 0, 0), (9, -3, 0, 0), (17, 3, 0, 0)],
        }
        run_loc = {"spine": [(1, 0, 0, 0), (5, 0, 0, -0.03), (9, 0, 0, 0), (13, 0, 0, -0.03), (17, 0, 0, 0)]}
    elif species == "wolf":
        walk_keys = {
            "up_fl": [(1, 26, 0, 0), (13, -26, 0, 0), (25, 26, 0, 0)],
            "up_hr": [(1, 26, 0, 0), (13, -26, 0, 0), (25, 26, 0, 0)],
            "up_fr": [(1, -26, 0, 0), (13, 26, 0, 0), (25, -26, 0, 0)],
            "up_hl": [(1, -26, 0, 0), (13, 26, 0, 0), (25, -26, 0, 0)],
            "lo_fl": [(1, 8, 0, 0), (7, 34, 0, 0), (13, 8, 0, 0), (19, 28, 0, 0), (25, 8, 0, 0)],
            "lo_hr": [(1, 8, 0, 0), (7, 34, 0, 0), (13, 8, 0, 0), (19, 28, 0, 0), (25, 8, 0, 0)],
            "lo_fr": [(1, 34, 0, 0), (7, 8, 0, 0), (13, 28, 0, 0), (19, 8, 0, 0), (25, 34, 0, 0)],
            "lo_hl": [(1, 34, 0, 0), (7, 8, 0, 0), (13, 28, 0, 0), (19, 8, 0, 0), (25, 34, 0, 0)],
            "neck": [(1, 3, 0, 0), (13, -3, 0, 0), (25, 3, 0, 0)],
        }
        walk_loc = {"spine": [(1, 0, 0, 0), (7, 0, 0, -0.03), (13, 0, 0, 0), (19, 0, 0, -0.03), (25, 0, 0, 0)]}
        run_keys = {
            "up_fl": [(1, 34, 0, 0), (9, -34, 0, 0), (17, 34, 0, 0)],
            "up_hr": [(1, 34, 0, 0), (9, -34, 0, 0), (17, 34, 0, 0)],
            "up_fr": [(1, -34, 0, 0), (9, 34, 0, 0), (17, -34, 0, 0)],
            "up_hl": [(1, -34, 0, 0), (9, 34, 0, 0), (17, -34, 0, 0)],
            "lo_fl": [(1, 10, 0, 0), (5, 42, 0, 0), (9, 10, 0, 0), (13, 36, 0, 0), (17, 10, 0, 0)],
            "lo_hr": [(1, 10, 0, 0), (5, 42, 0, 0), (9, 10, 0, 0), (13, 36, 0, 0), (17, 10, 0, 0)],
            "lo_fr": [(1, 42, 0, 0), (5, 10, 0, 0), (9, 36, 0, 0), (13, 10, 0, 0), (17, 42, 0, 0)],
            "lo_hl": [(1, 42, 0, 0), (5, 10, 0, 0), (9, 36, 0, 0), (13, 10, 0, 0), (17, 42, 0, 0)],
            "neck": [(1, 5, 0, 0), (9, -5, 0, 0), (17, 5, 0, 0)],
            "tail": [(1, 0, 6, 0), (9, 0, -6, 0), (17, 0, 6, 0)],
        }
        run_loc = {"spine": [(1, 0, 0, 0), (5, 0, 0, -0.05), (9, 0, 0, 0), (13, 0, 0, -0.05), (17, 0, 0, 0)]}
    else:
        walk_keys = {
            "up_fl": [(1, 20, 0, 0), (13, -20, 0, 0), (25, 20, 0, 0)],
            "up_hr": [(1, 20, 0, 0), (13, -20, 0, 0), (25, 20, 0, 0)],
            "up_fr": [(1, -20, 0, 0), (13, 20, 0, 0), (25, -20, 0, 0)],
            "up_hl": [(1, -20, 0, 0), (13, 20, 0, 0), (25, -20, 0, 0)],
            "lo_fl": [(1, 4, 0, 0), (7, 22, 0, 0), (13, 4, 0, 0), (19, 18, 0, 0), (25, 4, 0, 0)],
            "lo_hr": [(1, 4, 0, 0), (7, 22, 0, 0), (13, 4, 0, 0), (19, 18, 0, 0), (25, 4, 0, 0)],
            "lo_fr": [(1, 22, 0, 0), (7, 4, 0, 0), (13, 18, 0, 0), (19, 4, 0, 0), (25, 22, 0, 0)],
            "lo_hl": [(1, 22, 0, 0), (7, 4, 0, 0), (13, 18, 0, 0), (19, 4, 0, 0), (25, 22, 0, 0)],
            "neck": [(1, 1, 0, 0), (13, -1, 0, 0), (25, 1, 0, 0)],
        }
        walk_loc = {"spine": [(1, 0, 0, 0), (7, 0, 0, -0.04), (13, 0, 0, 0), (19, 0, 0, -0.04), (25, 0, 0, 0)]}
        run_keys = {
            "up_fl": [(1, 26, 0, 0), (9, -26, 0, 0), (17, 26, 0, 0)],
            "up_hr": [(1, 26, 0, 0), (9, -26, 0, 0), (17, 26, 0, 0)],
            "up_fr": [(1, -26, 0, 0), (9, 26, 0, 0), (17, -26, 0, 0)],
            "up_hl": [(1, -26, 0, 0), (9, 26, 0, 0), (17, -26, 0, 0)],
            "lo_fl": [(1, 6, 0, 0), (5, 30, 0, 0), (9, 6, 0, 0), (13, 24, 0, 0), (17, 6, 0, 0)],
            "lo_hr": [(1, 6, 0, 0), (5, 30, 0, 0), (9, 6, 0, 0), (13, 24, 0, 0), (17, 6, 0, 0)],
            "lo_fr": [(1, 30, 0, 0), (5, 6, 0, 0), (9, 24, 0, 0), (13, 6, 0, 0), (17, 30, 0, 0)],
            "lo_hl": [(1, 30, 0, 0), (5, 6, 0, 0), (9, 24, 0, 0), (13, 6, 0, 0), (17, 30, 0, 0)],
            "neck": [(1, 2, 0, 0), (9, -2, 0, 0), (17, 2, 0, 0)],
        }
        run_loc = {"spine": [(1, 0, 0, 0), (5, 0, 0, -0.06), (9, 0, 0, 0), (13, 0, 0, -0.06), (17, 0, 0, 0)]}
    make_clip(arm, pb, "walk", walk_keys, loc_keys=walk_loc)
    make_clip(arm, pb, "run", run_keys, loc_keys=run_loc)
    make_clip(arm, pb, "idle", {
        "neck": [(1, 0, 0, 0), (25, 2.5, 0, 0), (49, 0, 0, 0)],
        "head": [(1, 0, 0, 0), (13, 0, 7, 0), (25, 0, 0, 0), (37, 0, -7, 0), (49, 0, 0, 0)],
        "tail": [(1, 0, 8, 0), (25, 0, -8, 0), (49, 0, 8, 0)],
    }, loc_keys={"spine": [(1, 0, 0, 0), (25, 0, 0, -0.015), (49, 0, 0, 0)]})
    if species == "boar":
        make_clip(arm, pb, "attack", {
            "neck": [(1, 0, 0, 0), (4, -14, 0, 0), (8, -18, 0, 0), (12, 0, 0, 0)],
            "head": [(1, 0, 0, 0), (4, -10, 0, 0), (8, -12, 0, 0), (12, 0, 0, 0)],
            "spine": [(1, 0, 0, 0), (4, -5, 0, 0), (8, -6, 0, 0), (12, 0, 0, 0)],
            "up_fl": [(1, 0, 0, 0), (4, -10, 0, 0), (8, -12, 0, 0), (12, 0, 0, 0)],
            "up_fr": [(1, 0, 0, 0), (4, -10, 0, 0), (8, -12, 0, 0), (12, 0, 0, 0)],
        }, loc_keys={"spine": [(1, 0, 0, 0), (4, 0, 0.28, -0.04), (8, 0, 0.32, -0.04), (12, 0, 0, 0)]})
    elif species == "wolf":
        make_clip(arm, pb, "attack", {
            "neck": [(1, 0, 0, 0), (4, -14, 0, 0), (8, -18, 0, 0), (12, 0, 0, 0)],
            "head": [(1, 0, 0, 0), (4, -8, 0, 0), (8, -10, 0, 0), (12, 0, 0, 0)],
            "spine": [(1, 0, 0, 0), (4, -6, 0, 0), (8, -8, 0, 0), (12, 0, 0, 0)],
            "up_fl": [(1, 0, 0, 0), (4, 16, 0, 0), (8, 20, 0, 0), (12, 0, 0, 0)],
            "up_fr": [(1, 0, 0, 0), (4, 16, 0, 0), (8, 20, 0, 0), (12, 0, 0, 0)],
        }, loc_keys={"spine": [(1, 0, 0, 0), (4, 0, 0.32, 0.02), (8, 0, 0.36, 0.02), (12, 0, 0, 0)]})
    else:
        make_clip(arm, pb, "attack", {
            "spine": [(1, 0, 0, 0), (4, 16, 0, 0), (8, 20, 0, 0), (12, 0, 0, 0)],
            "neck": [(1, 0, 0, 0), (4, 8, 0, -14), (8, 10, 0, -18), (12, 0, 0, 0)],
            "head": [(1, 0, 0, 0), (4, 6, 0, 0), (8, 8, 0, 0), (12, 0, 0, 0)],
            "up_fl": [(1, 0, 0, 0), (4, 48, 0, 22), (8, 55, 0, 26), (12, 0, 0, 0)],
            "up_fr": [(1, 0, 0, 0), (4, 48, 0, -22), (8, 55, 0, -26), (12, 0, 0, 0)],
            "lo_fl": [(1, 0, 0, 0), (4, 20, 0, 0), (8, 24, 0, 0), (12, 0, 0, 0)],
            "lo_fr": [(1, 0, 0, 0), (4, 20, 0, 0), (8, 24, 0, 0), (12, 0, 0, 0)],
        }, loc_keys={"spine": [(1, 0, 0, 0), (4, 0, 0, 0.14), (8, 0, 0, 0.16), (12, 0, 0, 0)]})
    make_clip(arm, pb, "hit", {
        "spine": [(1, 0, 0, 0), (3, -12, 0, 0), (8, 0, 0, 0)],
        "neck": [(1, 0, 0, 0), (3, -16, 0, 0), (8, 0, 0, 0)],
    }, loc_keys={"spine": [(1, 0, 0, 0), (3, 0, -0.08, 0), (8, 0, 0, 0)]})
    make_clip(arm, pb, "die", {
        "spine": [(1, 0, 0, 0), (8, 0, 0, 78), (24, 0, 0, 80)],  # // FIX: DIE 绕Z侧倒（原绕Y=水平打转）
        "neck": [(1, 0, 0, 0), (8, 0, 0, 14), (24, 0, 0, 16)],
        "up_fl": [(1, 0, 0, 0), (10, -52, 0, 0), (24, -55, 0, 0)],
        "up_fr": [(1, 0, 0, 0), (10, -48, 0, 0), (24, -50, 0, 0)],
        "up_hl": [(1, 0, 0, 0), (10, 44, 0, 0), (24, 46, 0, 0)],
        "up_hr": [(1, 0, 0, 0), (10, 48, 0, 0), (24, 50, 0, 0)],
        "lo_fl": [(1, 0, 0, 0), (10, 62, 0, 0), (24, 64, 0, 0)],
        "lo_fr": [(1, 0, 0, 0), (10, 58, 0, 0), (24, 60, 0, 0)],
        "lo_hl": [(1, 0, 0, 0), (10, 55, 0, 0), (24, 57, 0, 0)],
        "lo_hr": [(1, 0, 0, 0), (10, 58, 0, 0), (24, 60, 0, 0)],
    }, loc_keys={"spine": [(1, 0, 0, 0), (8, 0, 0, -0.30), (24, 0, 0, -0.32)]})
    reset_pose(pb)
    bpy.context.scene.render.fps = 24
    root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    out = os.path.join(root, "assets/models", out_name)
    os.makedirs(os.path.dirname(out), exist_ok=True)
    result = bpy.ops.export_scene.gltf(filepath=out, export_format="GLB", export_animations=True, export_animation_mode="NLA_TRACKS")
    if "FINISHED" not in result:
        raise RuntimeError(f"export {out_name} failed: {result}")
    print("[creatures] exported:", out)


SPECIES = [
    ("boar.glb", boar_parts, 0.36, 0.52, -0.52, 0.58, 0.78, 0.80, 0.72),
    ("wolf.glb", wolf_parts, 0.28, 0.52, -0.58, 0.64, 0.84, 1.20, 0.85),
    ("bear.glb", bear_parts, 0.44, 0.68, -0.72, 0.78, 1.18, 1.58, 1.25),
]

for out_name, parts_fn, lx, lzf, lzb, hh, sz, hz, tz in SPECIES:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for block in list(bpy.data.meshes):
        if block.users == 0:
            bpy.data.meshes.remove(block)
    for block in list(bpy.data.materials):
        if block.users == 0:
            bpy.data.materials.remove(block)
    for block in list(bpy.data.actions):
        if block.users == 0:
            bpy.data.actions.remove(block)
    build(out_name, parts_fn(), lx, lzf, lzb, hh, sz, hz, tz)
