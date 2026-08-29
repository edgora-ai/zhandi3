class_name Buildings
extends Node3D
## 程序化建筑与场景：村庄（小屋/两层楼/仓库/瞭望塔/废墟）、据点工事、码头小船
## 碰撞全部用盒体，不用 trimesh（避免单向碰撞坑）

const VILLAGE_COUNT := 3

const WALL_WHITE := Color(0.84, 0.79, 0.68)
const WALL_WOOD := Color(0.62, 0.48, 0.33)
const WALL_BRICK := Color(0.72, 0.52, 0.42)
const ROOF_RED := Color(0.72, 0.33, 0.24)
const ROOF_BLUE := Color(0.38, 0.46, 0.58)
const ROOF_DARK := Color(0.35, 0.33, 0.30)
const WOOD := Color(0.55, 0.42, 0.28)
const WOOD_DARK := Color(0.42, 0.32, 0.22)
const GLASS := Color(0.35, 0.45, 0.52)
const SAND := Color(0.79, 0.73, 0.55)
const METAL := Color(0.45, 0.47, 0.50)

var village_centers: Array[Vector3] = []
var _rng := RandomNumberGenerator.new()

var _m_wall: StandardMaterial3D
var _m_wood_wall: StandardMaterial3D
var _m_brick: StandardMaterial3D
var _m_roof_r: StandardMaterial3D
var _m_roof_b: StandardMaterial3D
var _m_roof_d: StandardMaterial3D
var _m_wood: StandardMaterial3D
var _m_wood_d: StandardMaterial3D
var _m_glass: StandardMaterial3D
var _m_sand: StandardMaterial3D
var _m_metal: StandardMaterial3D
var _m_snow: StandardMaterial3D
var _snow_caps: Array[MeshInstance3D] = []

var _terrain: Terrain


func generate(terrain: Terrain) -> void:
	_terrain = terrain
	_rng.seed = 20260719
	_m_wall = Toon.make_material(WALL_WHITE, true, 0.02)
	_m_wood_wall = Toon.make_material(WALL_WOOD, true, 0.02)
	_m_brick = Toon.make_material(WALL_BRICK, true, 0.02)
	# // FIX: OPT-F8/TA11 墙面接程序化纹理（三面映射，近看不再是纯色平板）
	_m_wall.albedo_texture = TexGen.wall_plaster()
	_m_wall.uv1_triplanar = true
	_m_wall.uv1_world_triplanar = true # // FIX: R3-TA5 砖缝跨部件连续
	_m_wall.uv1_scale = Vector3(0.35, 0.35, 0.35)
	_m_wood_wall.albedo_texture = TexGen.wall_plank()
	_m_wood_wall.uv1_triplanar = true
	_m_wood_wall.uv1_world_triplanar = true
	_m_wood_wall.uv1_scale = Vector3(0.4, 0.4, 0.4)
	_m_brick.albedo_texture = TexGen.wall_brick()
	_m_brick.uv1_triplanar = true
	_m_brick.uv1_world_triplanar = true
	_m_brick.uv1_scale = Vector3(0.4, 0.4, 0.4)
	_m_roof_r = Toon.make_material(ROOF_RED, true, 0.02)
	_m_roof_b = Toon.make_material(ROOF_BLUE, true, 0.02)
	_m_roof_d = Toon.make_material(ROOF_DARK, true, 0.02)
	_m_wood = Toon.make_material(WOOD, true, 0.015)
	# // FIX: R4-15 木箱/木质件接木板纹理（三面映射）
	_m_wood.albedo_texture = TexGen.wall_plank()
	_m_wood.uv1_triplanar = true
	_m_wood.uv1_world_triplanar = true
	_m_wood.uv1_scale = Vector3(0.5, 0.5, 0.5)
	_m_wood_d = Toon.make_material(WOOD_DARK, true, 0.015)
	_m_glass = Toon.make_material(GLASS, false)
	_m_sand = Toon.make_material(SAND, true, 0.01)
	_m_metal = Toon.make_material(METAL, true, 0.01)
	_m_snow = Toon.make_material(Color(0.88, 0.94, 0.98), true, 0.008)

	for i in range(VILLAGE_COUNT):
		var c := _find_village_spot()
		village_centers.append(c)
		_make_village(c)
	_make_dock()
	print("[buildings] villages: ", village_centers)


func _find_village_spot() -> Vector3:
	for i in range(300):
		var x := _rng.randf_range(-Terrain.HALF * 0.72, Terrain.HALF * 0.72)
		var z := _rng.randf_range(-Terrain.HALF * 0.72, Terrain.HALF * 0.72)
		var y := _terrain.get_height(x, z)
		if y < Terrain.WATER_LEVEL + 1.5 or _terrain.get_normal(x, z).y < 0.90:
			continue
		var p := Vector3(x, y, z)
		var ok := true
		for c in village_centers:
			if c.distance_to(p) < 120.0:
				ok = false
				break
		if ok:
			return p
	return Vector3(0, _terrain.get_height(0, 0), 0)


# ---------- 村庄 ----------

func _make_village(center: Vector3) -> void:
	var houses := _rng.randi_range(5, 7)
	var made_tower := false
	var made_warehouse := false
	var made_ruin := false
	for i in range(houses):
		var ang := TAU * float(i) / houses + _rng.randf_range(-0.35, 0.35)
		var r := _rng.randf_range(9.0, 19.0)
		var p := center + Vector3(cos(ang) * r, 0, sin(ang) * r)
		p.y = _terrain.get_height(p.x, p.z)
		if p.y < Terrain.WATER_LEVEL + 1.2 or _terrain.get_normal(p.x, p.z).y < 0.86:
			continue
		# 面向村庄中心（略带随机）
		var face := atan2(center.x - p.x, center.z - p.z) + PI + _rng.randf_range(-0.3, 0.3)
		var roll := _rng.randf()
		if not made_warehouse and roll < 0.18:
			_make_warehouse(p, face)
			made_warehouse = true
		elif not made_ruin and roll < 0.32:
			_make_ruin(p, face)
			made_ruin = true
		elif roll < 0.62:
			_make_house(p, face, _rng.randf() < 0.35)
		else:
			_make_house(p, face, false)
	# 一座瞭望塔
	if not made_tower:
		var tp := center + Vector3(_rng.randf_range(-6, 6), 0, _rng.randf_range(-6, 6))
		tp.y = _terrain.get_height(tp.x, tp.z)
		if tp.y > Terrain.WATER_LEVEL + 1.2:
			_make_tower(tp, _rng.randf_range(0.0, TAU))
	# 散落的箱子与油桶
	for i in range(_rng.randi_range(4, 7)):
		var cp := center + Vector3(_rng.randf_range(-16, 16), 0, _rng.randf_range(-16, 16))
		cp.y = _terrain.get_height(cp.x, cp.z)
		if cp.y > Terrain.WATER_LEVEL + 1.0:
			if _rng.randf() < 0.6:
				_make_crate(cp, _rng.randf_range(0.0, TAU))
			else:
				_make_barrel(cp)
	# 一半村庄有吉普车
	if _rng.randf() < 0.5:
		var vp := center + Vector3(_rng.randf_range(-8, 8), 0, _rng.randf_range(-8, 8))
		vp.y = _terrain.get_height(vp.x, vp.z) + 0.5
		if _terrain.get_normal(vp.x, vp.z).y > 0.88:
			var veh := Vehicle.new()
			veh.terrain = _terrain
			add_child(veh)
			veh.global_position = vp
			veh.rotation.y = _rng.randf_range(0.0, TAU)
			print("[buildings] vehicle at ", vp)


# ---------- 基础件 ----------

func _part(size: Vector3, mat: Material, pos: Vector3, parent: Node3D, rot_y: float = 0.0, rot_x: float = 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	mi.rotation.y = rot_y
	mi.rotation.x = rot_x
	parent.add_child(mi)
	return mi


func _col(body: StaticBody3D, size: Vector3, pos: Vector3, rot_y: float = 0.0) -> void:
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	cs.position = pos
	cs.rotation.y = rot_y
	body.add_child(cs)


func _body(parent: Node3D) -> StaticBody3D:
	var b := StaticBody3D.new()
	b.collision_layer = 1
	parent.add_child(b)
	return b


# 四坡屋顶：金字塔锥体（前向面顺时针绕序）// FIX: R4-F8b 屋顶形制差异化
func _hip_roof(parent: Node3D, w: float, h: float, d: float, y: float, mat: Material) -> void:
	var hw := w * 0.5
	var hd := d * 0.5
	var apex := Vector3(0, h, -hd * 0.2)
	var a := Vector3(-hw, 0, -hd)
	var b := Vector3(hw, 0, -hd)
	var c := Vector3(hw, 0, hd)
	var dd := Vector3(-hw, 0, hd)
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	for tri in [[b, apex, a], [c, apex, b], [dd, apex, c], [a, apex, dd]]:
		var n: Vector3 = (tri[1] - tri[0]).cross(tri[2] - tri[0]).normalized()
		verts.append(tri[0])
		verts.append(tri[2])
		verts.append(tri[1])
		for k in range(3):
			normals.append(n)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position.y = y
	parent.add_child(mi)


# 人字屋顶：三棱柱网格（前向面顺时针绕序）
func _gable_roof(parent: Node3D, w: float, h: float, d: float, y: float, mat: Material) -> void:
	var hw := w * 0.5
	var hd := d * 0.5
	var a := Vector3(-hw, 0, -hd)
	var b := Vector3(hw, 0, -hd)
	var c := Vector3(0, h, -hd)
	var dd := Vector3(-hw, 0, hd)
	var e := Vector3(hw, 0, hd)
	var f := Vector3(0, h, hd)
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	for tri in [[a, c, b], [dd, e, f], [a, e, dd], [a, b, e], [a, dd, f], [a, f, c], [b, c, f], [b, f, e]]:
		var n: Vector3 = (tri[1] - tri[0]).cross(tri[2] - tri[0]).normalized()
		# Godot 前向面为顺时针绕序：交换后两顶点，法线方向保持不变
		verts.append(tri[0])
		verts.append(tri[2])
		verts.append(tri[1])
		for k in range(3):
			normals.append(n)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position.y = y
	parent.add_child(mi)
	# 同一轮廓的薄雪盖，冬季直接显隐，避免运行时重建建筑网格。
	var snow := MeshInstance3D.new()
	snow.mesh = mesh
	snow.material_override = _m_snow
	snow.position.y = y + 0.045
	snow.scale = Vector3(1.012, 1.012, 1.012)
	snow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	snow.visible = false
	parent.add_child(snow)
	_snow_caps.append(snow)


# 带门洞的前墙：两段侧墙 + 门楣 + 木门框
func _front_wall(parent: Node3D, body: StaticBody3D, w: float, h: float, z: float, mat: Material, door_w: float = 1.3, door_h: float = 2.2) -> void:
	var side := (w - door_w) * 0.5
	_part(Vector3(side, h, 0.18), mat, Vector3(-(door_w + side) * 0.5, h * 0.5, z), parent)
	_part(Vector3(side, h, 0.18), mat, Vector3((door_w + side) * 0.5, h * 0.5, z), parent)
	_part(Vector3(door_w, h - door_h, 0.18), mat, Vector3(0, (h + door_h) * 0.5, z), parent)
	_col(body, Vector3(side, h, 0.18), Vector3(-(door_w + side) * 0.5, h * 0.5, z))
	_col(body, Vector3(side, h, 0.18), Vector3((door_w + side) * 0.5, h * 0.5, z))
	_col(body, Vector3(door_w, h - door_h, 0.18), Vector3(0, (h + door_h) * 0.5, z))
	# 门框
	_part(Vector3(0.1, door_h, 0.24), _m_wood_d, Vector3(-door_w * 0.5, door_h * 0.5, z), parent)
	_part(Vector3(0.1, door_h, 0.24), _m_wood_d, Vector3(door_w * 0.5, door_h * 0.5, z), parent)
	# 门口踏阶
	_part(Vector3(door_w + 0.5, 0.14, 0.9), _m_wood_d, Vector3(0, 0.05, z - 0.55), parent)


func _window(parent: Node3D, pos: Vector3, rot_y: float = 0.0) -> void:
	_part(Vector3(0.7, 0.7, 0.06), _m_glass, pos, parent, rot_y)
	_part(Vector3(0.82, 0.08, 0.1), _m_wood_d, pos + Vector3(0, 0.4, 0), parent, rot_y)
	_part(Vector3(0.82, 0.08, 0.1), _m_wood_d, pos - Vector3(0, 0.4, 0), parent, rot_y)
	var side := Vector3(cos(rot_y), 0, -sin(rot_y)) * 0.4
	_part(Vector3(0.08, 0.82, 0.1), _m_wood_d, pos - side, parent, rot_y)
	_part(Vector3(0.08, 0.82, 0.1), _m_wood_d, pos + side, parent, rot_y)
	# 十字窗棂让远处窗口也有清晰轮廓。
	_part(Vector3(0.06, 0.72, 0.11), _m_wood_d, pos, parent, rot_y)
	_part(Vector3(0.72, 0.06, 0.11), _m_wood_d, pos, parent, rot_y)


func _house_timber_frame(parent: Node3D, w: float, d: float, h: float) -> void:
	# 墙面之外再叠一层木构骨架，形成墙、梁、柱三层体块。
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_part(Vector3(0.16, h + 0.14, 0.16), _m_wood_d, Vector3(sx * w * 0.5, h * 0.5, sz * d * 0.5), parent)
	for y in [0.18, h - 0.12]:
		_part(Vector3(w + 0.18, 0.15, 0.16), _m_wood_d, Vector3(0, y, d * 0.5), parent)
		_part(Vector3(w + 0.18, 0.15, 0.16), _m_wood_d, Vector3(0, y, -d * 0.5), parent)
		_part(Vector3(0.16, 0.15, d + 0.18), _m_wood_d, Vector3(-w * 0.5, y, 0), parent)
		_part(Vector3(0.16, 0.15, d + 0.18), _m_wood_d, Vector3(w * 0.5, y, 0), parent)


# ---------- 房型 ----------

func _make_house(p: Vector3, rot: float, two_story: bool) -> void:
	var g := Node3D.new()
	g.position = p - Vector3(0, 0.25, 0)
	g.rotation.y = rot
	add_child(g)
	var body := _body(g)

	var w := _rng.randf_range(4.2, 5.2)
	var d := _rng.randf_range(5.0, 6.2)
	var h := 5.4 if two_story else 2.7
	var wall_mat: StandardMaterial3D = [_m_wall, _m_wood_wall, _m_brick][_rng.randi_range(0, 2)]
	var roof_mat: StandardMaterial3D = _m_roof_r if _rng.randf() < 0.6 else _m_roof_b

	# 石质基座 + 地板 + 四面墙（前面带门洞）
	_part(Vector3(w + 0.35, 0.38, d + 0.35), _m_brick, Vector3(0, -0.05, 0), g)
	_part(Vector3(w, 0.2, d), _m_wood_d, Vector3(0, 0.1, 0), g)
	_part(Vector3(w, h, 0.18), wall_mat, Vector3(0, h * 0.5, d * 0.5), g)
	_col(body, Vector3(w, h, 0.18), Vector3(0, h * 0.5, d * 0.5))
	_part(Vector3(0.18, h, d), wall_mat, Vector3(-w * 0.5, h * 0.5, 0), g)
	_col(body, Vector3(0.18, h, d), Vector3(-w * 0.5, h * 0.5, 0))
	_part(Vector3(0.18, h, d), wall_mat, Vector3(w * 0.5, h * 0.5, 0), g)
	_col(body, Vector3(0.18, h, d), Vector3(w * 0.5, h * 0.5, 0))
	_front_wall(g, body, w, h, -d * 0.5, wall_mat)
	_house_timber_frame(g, w, d, h)

	if two_story:
		# 中层楼板 + 二层窗户
		_part(Vector3(w - 0.3, 0.14, d - 0.3), _m_wood_d, Vector3(0, 2.7, 0), g)
		_window(g, Vector3(-w * 0.5 - 0.06, 4.1, 0), PI * 0.5)
		_window(g, Vector3(w * 0.5 + 0.06, 4.1, 0), PI * 0.5)
		_window(g, Vector3(0, 4.1, d * 0.5 + 0.06))
	else:
		_window(g, Vector3(-w * 0.5 - 0.06, 1.5, 0.6), PI * 0.5)
		_window(g, Vector3(w * 0.5 + 0.06, 1.5, -0.6), PI * 0.5)

	var roof_h := 1.5 if two_story else 1.3
	_gable_roof(g, w + 0.7, roof_h, d + 0.9, h, roof_mat)
	# 深色屋脊与檐口，把单块屋顶拆成可读的层次。
	_part(Vector3(0.18, 0.18, d + 1.05), _m_wood_d, Vector3(0, h + roof_h + 0.04, 0), g)
	_part(Vector3(w + 0.85, 0.14, 0.18), _m_wood_d, Vector3(0, h + 0.02, d * 0.5 + 0.46), g)
	_part(Vector3(w + 0.85, 0.14, 0.18), _m_wood_d, Vector3(0, h + 0.02, -d * 0.5 - 0.46), g)
	# 烟囱
	if _rng.randf() < 0.5:
		_part(Vector3(0.4, 1.2, 0.4), _m_brick, Vector3(w * 0.25, h + 0.9, d * 0.15), g)
	# 屋内家具箱
	if _rng.randf() < 0.5:
		_make_crate(Vector3(w * 0.22, 0.65, d * 0.15), _rng.randf_range(0.0, TAU), g, 0.7)


func _make_warehouse(p: Vector3, rot: float) -> void:
	var g := Node3D.new()
	g.position = p - Vector3(0, 0.25, 0)
	g.rotation.y = rot
	add_child(g)
	var body := _body(g)

	var w := 8.5
	var d := 7.0
	var h := 3.6
	_part(Vector3(w, 0.2, d), _m_wood_d, Vector3(0, 0.1, 0), g)
	_part(Vector3(w, h, 0.18), _m_metal, Vector3(0, h * 0.5, d * 0.5), g)
	_col(body, Vector3(w, h, 0.18), Vector3(0, h * 0.5, d * 0.5))
	_part(Vector3(0.18, h, d), _m_metal, Vector3(-w * 0.5, h * 0.5, 0), g)
	_col(body, Vector3(0.18, h, d), Vector3(-w * 0.5, h * 0.5, 0))
	_part(Vector3(0.18, h, d), _m_metal, Vector3(w * 0.5, h * 0.5, 0), g)
	_col(body, Vector3(0.18, h, d), Vector3(w * 0.5, h * 0.5, 0))
	# 宽大库门洞
	_front_wall(g, body, w, h, -d * 0.5, _m_metal, 3.0, 2.9)
	_hip_roof(g, w + 0.7, 1.6, d + 0.9, h, _m_roof_d) # // FIX: R4-F8b 仓库四坡顶
	# 仓库立向压条，弱化大块平墙的塑料盒感。
	for x in range(-3, 4):
		_part(Vector3(0.055, h - 0.2, 0.08), _m_wood_d, Vector3(float(x) * 1.15, h * 0.5, d * 0.5 + 0.08), g)
	for z in range(-2, 3):
		_part(Vector3(0.08, h - 0.2, 0.055), _m_wood_d, Vector3(-w * 0.5 - 0.08, h * 0.5, float(z) * 1.25), g)
		_part(Vector3(0.08, h - 0.2, 0.055), _m_wood_d, Vector3(w * 0.5 + 0.08, h * 0.5, float(z) * 1.25), g)
	# 库内物资箱
	_make_crate(Vector3(-w * 0.28, 0.45, d * 0.15), 0.3, g)
	_make_crate(Vector3(-w * 0.28, 1.3, d * 0.15), 0.8, g, 0.8)
	_make_crate(Vector3(w * 0.24, 0.45, -d * 0.1), -0.2, g)


func _make_tower(p: Vector3, rot: float) -> void:
	var g := Node3D.new()
	g.position = p - Vector3(0, 0.15, 0)
	g.rotation.y = rot
	add_child(g)
	var body := _body(g)

	var h := 6.0
	var spread := 1.0
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_part(Vector3(0.24, h, 0.24), _m_wood, Vector3(sx * spread, h * 0.5, sz * spread), g)
			_col(body, Vector3(0.24, h, 0.24), Vector3(sx * spread, h * 0.5, sz * spread))
	# 梯子（前腿）：横档 + 可攀爬区域
	_part(Vector3(0.06, h, 0.06), _m_wood_d, Vector3(-0.25, h * 0.5, spread + 0.15), g)
	_part(Vector3(0.06, h, 0.06), _m_wood_d, Vector3(0.25, h * 0.5, spread + 0.15), g)
	for i in range(8):
		_part(Vector3(0.5, 0.05, 0.05), _m_wood_d, Vector3(0, 0.5 + i * 0.65, spread + 0.15), g)
	var lad := Area3D.new()
	lad.add_to_group("ladder")
	var lc := CollisionShape3D.new()
	var lb := BoxShape3D.new()
	lb.size = Vector3(1.2, h + 1.5, 1.2)
	lc.shape = lb
	lc.position = Vector3(0, h * 0.5, spread + 0.15)
	lad.add_child(lc)
	g.add_child(lad)
	# 平台 + 围栏
	_part(Vector3(3.0, 0.16, 3.0), _m_wood_d, Vector3(0, h, 0), g)
	_col(body, Vector3(3.0, 0.16, 3.0), Vector3(0, h, 0))
	for side in range(4):
		var rp := Vector3(0, h + 0.55, 1.42).rotated(Vector3.UP, side * PI * 0.5)
		_part(Vector3(3.0, 0.08, 0.08) if side % 2 == 0 else Vector3(0.08, 0.08, 3.0), _m_wood, rp, g)
	_gable_roof(g, 3.4, 1.0, 3.4, h + 1.5, _m_roof_b)
	for sx in [-1.2, 1.2]:
		_part(Vector3(0.12, 1.5, 0.12), _m_wood, Vector3(sx, h + 0.75, sx), g)


func _make_ruin(p: Vector3, rot: float) -> void:
	var g := Node3D.new()
	g.position = p - Vector3(0, 0.2, 0)
	g.rotation.y = rot
	add_child(g)
	var body := _body(g)

	var w := 5.0
	var d := 6.0
	# 残墙：随机高度、缺口的砖墙
	_part(Vector3(w, 1.8, 0.22), _m_brick, Vector3(0, 0.9, d * 0.5), g)
	_col(body, Vector3(w, 1.8, 0.22), Vector3(0, 0.9, d * 0.5))
	_part(Vector3(0.22, 1.1, d * 0.6), _m_brick, Vector3(-w * 0.5, 0.55, d * 0.1), g)
	_col(body, Vector3(0.22, 1.1, d * 0.6), Vector3(-w * 0.5, 0.55, d * 0.1))
	_part(Vector3(0.22, 2.2, d * 0.4), _m_brick, Vector3(w * 0.5, 1.1, -d * 0.15), g)
	_col(body, Vector3(0.22, 2.2, d * 0.4), Vector3(w * 0.5, 1.1, -d * 0.15))
	_part(Vector3(w * 0.45, 0.8, 0.22), _m_brick, Vector3(-w * 0.2, 0.4, -d * 0.5), g)
	_col(body, Vector3(w * 0.45, 0.8, 0.22), Vector3(-w * 0.2, 0.4, -d * 0.5))
	# 塌落的屋梁与碎块
	_part(Vector3(0.18, 3.2, 0.18), _m_wood_d, Vector3(0.8, 0.6, 0.4), g, 0.4, 1.15)
	_part(Vector3(0.7, 0.5, 0.6), _m_brick, Vector3(-1.2, 0.25, -1.0), g, 0.7)


func _make_crate(p: Vector3, rot: float, parent: Node3D = null, s: float = 1.0) -> void:
	var g := Node3D.new()
	g.position = p
	g.rotation.y = rot
	g.scale = Vector3.ONE * s
	(parent if parent else self).add_child(g)
	_part(Vector3(0.95, 0.9, 0.95), _m_wood, Vector3(0, 0, 0), g)
	_part(Vector3(1.0, 0.12, 1.0), _m_wood_d, Vector3(0, 0.42, 0), g)
	_part(Vector3(1.0, 0.12, 1.0), _m_wood_d, Vector3(0, -0.42, 0), g)
	var body := _body(g)
	_col(body, Vector3(0.95, 0.9, 0.95), Vector3.ZERO)


func _make_barrel(p: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.36
	cm.bottom_radius = 0.36
	cm.height = 0.95
	cm.radial_segments = 10
	mi.mesh = cm
	mi.material_override = _m_metal
	mi.position = p + Vector3(0, 0.48, 0)
	add_child(mi)
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.position = p + Vector3(0, 0.48, 0)
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.36
	cyl.height = 0.95
	cs.shape = cyl
	body.add_child(cs)
	add_child(body)


# ---------- 据点工事 ----------

func fortify(center: Vector3) -> void:
	var g := Node3D.new()
	g.position = center
	add_child(g)
	var body := _body(g)
	var r := 7.6
	var stacks := 9
	for i in range(stacks):
		var ang := TAU * float(i) / stacks
		# 留两个出入口
		if i == 2 or i == 6:
			continue
		var bp := Vector3(cos(ang) * r, 0, sin(ang) * r)
		bp.y = _terrain.get_height(center.x + bp.x, center.z + bp.z) - center.y
		var rot := -ang + PI * 0.5
		for lvl in range(3):
			var n := 2 if lvl < 2 else 1
			for k in range(n):
				var off := (float(k) - float(n - 1) * 0.5) * 0.95 + _rng.randf_range(-0.06, 0.06)
				var pp := bp + Vector3(cos(rot), 0, -sin(rot)) * off
				pp.y += 0.20 + lvl * 0.38 + _rng.randf_range(-0.02, 0.02)
				var bag := Vector3(0.9, 0.38, 0.55) * _rng.randf_range(0.9, 1.08)
				_part(bag, _m_sand, pp, g, rot + _rng.randf_range(-0.16, 0.16))
		_col(body, Vector3(2.0, 1.1, 0.6), bp + Vector3(0, 0.6, 0), rot)
	# 弹药箱与油桶
	_make_crate(center + Vector3(2.6, 0.45, 2.2), 0.5)
	_make_barrel(center + Vector3(-2.8, 0, 2.6))
	_make_barrel(center + Vector3(-2.2, 0, 3.3))


# ---------- 码头与小船 ----------

func _make_dock() -> void:
	# 从第一个村庄朝地图边缘找水线
	var c: Vector3 = village_centers[0] if not village_centers.is_empty() else Vector3.ZERO
	var dir := Vector3(c.x, 0, c.z).normalized()
	if dir.length_squared() < 0.01:
		dir = Vector3(1, 0, 0)
	var shore := Vector3.ZERO
	var found := false
	for t in range(0, 300):
		var p := c + dir * (float(t) * 2.0 + 20.0)
		if _terrain.get_height(p.x, p.z) < Terrain.WATER_LEVEL + 0.4:
			shore = p
			found = true
			break
	if not found:
		return
	var yaw := atan2(dir.x, dir.z)

	var g := Node3D.new()
	g.position = Vector3(shore.x, Terrain.WATER_LEVEL + 0.55, shore.z)
	g.rotation.y = yaw
	add_child(g)
	# 栈桥：木板伸向水面
	for i in range(8):
		_part(Vector3(2.2, 0.12, 1.9), _m_wood, Vector3(0, 0, i * 1.85 + 0.9), g)
		if i % 2 == 0:
			for sx in [-0.95, 0.95]:
				_part(Vector3(0.16, 2.4, 0.16), _m_wood_d, Vector3(sx, -1.1, i * 1.85 + 0.9), g)
				_part(Vector3(0.18, 1.75, 0.18), _m_wood_d, Vector3(sx, 0.82, i * 1.85 + 0.9), g)
	_part(Vector3(2.3, 0.1, 0.4), _m_wood_d, Vector3(0, 0.02, 15.6), g)
	# 两侧下垂绳索：分段盒体模拟绳桥轮廓，保持纯程序化且开销固定。
	for sx in [-0.98, 0.98]:
		_rope_line(g, sx, 0.9, 14.8, 1.58, 0.34)
	# 小船泊在桥尾
	_make_boat(g.position + Vector3(cos(yaw) * 3.2, -0.35, sin(yaw) * 3.2 + 12.0), yaw + 0.25)


func _rope_line(parent: Node3D, x: float, z0: float, z1: float, height: float, sag: float) -> void:
	var segments := 18
	for i in range(segments):
		var t0 := float(i) / segments
		var t1 := float(i + 1) / segments
		var a := Vector3(x, height - sin(t0 * PI) * sag, lerpf(z0, z1, t0))
		var b := Vector3(x, height - sin(t1 * PI) * sag, lerpf(z0, z1, t1))
		var delta := b - a
		var part := _part(Vector3(0.055, 0.055, delta.length() + 0.025), _m_wood_d, (a + b) * 0.5, parent)
		part.rotation.x = -atan2(delta.y, delta.z)


func set_season(season_name: String) -> void:
	var winter := season_name == "winter"
	for cap in _snow_caps:
		if is_instance_valid(cap):
			cap.visible = winter


func _make_boat(p: Vector3, rot: float) -> void:
	var g := Node3D.new()
	g.position = p
	g.rotation.y = rot
	add_child(g)
	# 船体：收口盒 + 船头斜块 + 座舱
	_part(Vector3(1.7, 0.55, 3.6), _m_wood_d, Vector3(0, 0.1, 0), g)
	_part(Vector3(1.4, 0.4, 2.6), _m_wood, Vector3(0, 0.42, 0), g)
	_part(Vector3(1.1, 0.5, 0.7), _m_wood_d, Vector3(0, 0.25, 1.95), g, 0.0, -0.5)
	_part(Vector3(1.3, 0.1, 0.3), _m_wood_d, Vector3(0, 0.6, -0.6), g)
	_part(Vector3(1.3, 0.1, 0.3), _m_wood_d, Vector3(0, 0.6, 0.5), g)
