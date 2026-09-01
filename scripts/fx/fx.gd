class_name FX
## Lightweight combat FX: pooled muzzle flash, tapered tracer, impact puffs and decals.

const FLASH_MAX := 16
const TRACER_MAX := 32
const PUFF_MAX := 64
const DECAL_MAX := 64
const MELEE_POOL_MAX := 24

# Shared radial flash texture and additive material
static var _flash_tex: GradientTexture2D
static var _flash_mat: StandardMaterial3D
static var _flash_tex_player: GradientTexture2D
static var _flash_mat_player: StandardMaterial3D
static var _flash_mesh: ArrayMesh

# Tracer shared tapered mesh and color materials
static var _tracer_mesh: ArrayMesh
static var _tracer_mats: Dictionary = {}

# Puff meshes/materials cached by radius / color
static var _puff_meshes: Dictionary = {}
static var _puff_mats: Dictionary = {}

# Melee streak shared meshes/materials
static var _melee_mesh_l: BoxMesh
static var _melee_mesh_h: BoxMesh
static var _melee_mats: Dictionary = {}

# Ring caches
static var _ring_meshes: Dictionary = {}
static var _ring_mats: Dictionary = {}

# Decal shared resources
static var _decal_mesh: QuadMesh
static var _decal_mat: StandardMaterial3D
static var _decals: Array[MeshInstance3D] = []
static var _decal_idx: int = 0

# Pools: host node driving TTL
static var _host: Node
static var _flash_pool: Array[MeshInstance3D] = []
static var _flash_ttl: Array[float] = []
static var _flash_life: Array[float] = []
static var _flash_base: Array[Vector3] = []
static var _flash_next: int = 0

static var _tracer_pool: Array[MeshInstance3D] = []
static var _tracer_ttl: Array[float] = []
static var _tracer_life: Array[float] = []
static var _tracer_width: Array[float] = []
static var _tracer_next: int = 0

static var _puff_pool: Array[MeshInstance3D] = []
static var _puff_ttl: Array[float] = []
static var _puff_life: Array[float] = []
static var _puff_grow: Array[float] = []
static var _puff_y0: Array[float] = []
static var _puff_next: int = 0

static var _melee_pool: Array[MeshInstance3D] = []
static var _melee_ttl: Array[float] = []
static var _melee_life: Array[float] = []
static var _melee_from: Array[Vector3] = []
static var _melee_to: Array[Vector3] = []
static var _melee_next: int = 0


class FXTicker extends Node:
	func _process(delta: float) -> void:
		FX._on_tick(delta)


static func _scene() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.current_scene


static func _color_diff(a: Color, b: Color) -> float:
	var dr := a.r - b.r
	var dg := a.g - b.g
	var db := a.b - b.b
	return sqrt(dr * dr + dg * dg + db * db)


static func _unshaded(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color
	return m


static func _ensure_flash_res() -> void:
	if _flash_mesh != null and _flash_mat != null and _flash_tex != null and _flash_mat_player != null and _flash_tex_player != null:
		return
	# world flash: W3 accepted (alpha0.35, emission0.85, size0.13 world; gradient points 0.45/0.70; random roll/aspect/life preserved)
	var grad := Gradient.new()
	grad.set_color(0, Color(1.0, 0.96, 0.80, 1.0))
	grad.set_color(1, Color(1.0, 0.62, 0.22, 0.0))
	grad.add_point(0.45, Color(1.0, 0.88, 0.55, 0.85))
	grad.add_point(0.70, Color(1.0, 0.72, 0.30, 0.35))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	tex.width = 64
	tex.height = 64
	_flash_tex = tex
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_texture = tex
	mat.albedo_color = Color(1, 1, 1, 1)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.78, 0.38)
	mat.emission_energy_multiplier = 0.85
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.billboard_keep_scale = false
	_flash_mat = mat
	# player flash: compact radial, tight texture, emission 0.15
	var grad_p := Gradient.new()
	grad_p.set_color(0, Color(1.0, 0.96, 0.80, 1.0))
	grad_p.set_color(1, Color(1.0, 0.62, 0.22, 0.0))
	grad_p.add_point(0.18, Color(1.0, 0.88, 0.55, 0.85))
	grad_p.add_point(0.26, Color(1.0, 0.72, 0.30, 0.15))
	var tex_p := GradientTexture2D.new()
	tex_p.gradient = grad_p
	tex_p.fill = GradientTexture2D.FILL_RADIAL
	tex_p.fill_from = Vector2(0.5, 0.5)
	tex_p.fill_to = Vector2(0.5, 0.0)
	tex_p.width = 64
	tex_p.height = 64
	_flash_tex_player = tex_p
	var mat_p := mat.duplicate() as StandardMaterial3D
	mat_p.albedo_texture = tex_p
	mat_p.albedo_color = Color(1, 1, 1, 0.9)
	mat_p.emission_energy_multiplier = 0.15
	_flash_mat_player = mat_p
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var quad_a: Array[Vector3] = [
		Vector3(-0.5, -0.5, 0), Vector3(0.5, -0.5, 0), Vector3(0.5, 0.5, 0), Vector3(-0.5, 0.5, 0)
	]
	var uv_a: Array[Vector2] = [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
	for i in range(4):
		st.set_uv(uv_a[i])
		st.add_vertex(quad_a[i])
	st.add_index(0); st.add_index(1); st.add_index(2)
	st.add_index(0); st.add_index(2); st.add_index(3)
	var cos45 := cos(PI * 0.25)
	var sin45 := sin(PI * 0.25)
	var base_b: Array[Vector3] = [
		Vector3(-0.5, -0.5, 0), Vector3(0.5, -0.5, 0), Vector3(0.5, 0.5, 0), Vector3(-0.5, 0.5, 0)
	]
	var uv_b: Array[Vector2] = [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
	for i in range(4):
		var p := base_b[i]
		var rx := p.x * cos45 - p.y * sin45
		var ry := p.x * sin45 + p.y * cos45
		var rp := Vector3(rx, ry, 0.0)
		st.set_uv(uv_b[i])
		st.add_vertex(rp)
	st.add_index(4); st.add_index(5); st.add_index(6)
	st.add_index(4); st.add_index(6); st.add_index(7)
	st.generate_normals()
	var mesh := st.commit()
	_flash_mesh = mesh


static func _ensure_tracer_res() -> void:
	if _tracer_mesh != null:
		return
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var w0 := 0.5
	var w1 := 0.08
	var z0 := -0.5
	var z1 := 0.5
	var v0 := Vector3(-w0, -w0, z0)
	var v1 := Vector3(w0, -w0, z0)
	var v2 := Vector3(w0, w0, z0)
	var v3 := Vector3(-w0, w0, z0)
	var v4 := Vector3(-w1, -w1, z1)
	var v5 := Vector3(w1, -w1, z1)
	var v6 := Vector3(w1, w1, z1)
	var v7 := Vector3(-w1, w1, z1)
	var verts: Array[Vector3] = [v0, v1, v2, v3, v4, v5, v6, v7]
	var uvs: Array[Vector2] = [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1), Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
	for i in range(8):
		st.set_uv(uvs[i % 4] if i < 4 else uvs[i - 4])
		st.add_vertex(verts[i])
	# sides
	st.add_index(0); st.add_index(1); st.add_index(5)
	st.add_index(0); st.add_index(5); st.add_index(4)
	st.add_index(1); st.add_index(2); st.add_index(6)
	st.add_index(1); st.add_index(6); st.add_index(5)
	st.add_index(2); st.add_index(3); st.add_index(7)
	st.add_index(2); st.add_index(7); st.add_index(6)
	st.add_index(3); st.add_index(0); st.add_index(4)
	st.add_index(3); st.add_index(4); st.add_index(7)
	# caps
	st.add_index(0); st.add_index(3); st.add_index(2)
	st.add_index(0); st.add_index(2); st.add_index(1)
	st.add_index(4); st.add_index(5); st.add_index(6)
	st.add_index(4); st.add_index(6); st.add_index(7)
	st.generate_normals()
	_tracer_mesh = st.commit()


static func _get_tracer_mat(color: Color) -> StandardMaterial3D:
	var mat: Variant = _tracer_mats.get(color)
	if mat != null:
		return mat as StandardMaterial3D
	var m := _unshaded(color)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.emission_enabled = true
	m.emission = Color(color.r, color.g, color.b)
	m.emission_energy_multiplier = 0.7
	if _tracer_mats.size() >= 8:
		_tracer_mats.clear()
	_tracer_mats[color] = m
	return m


static func _ensure_decal_res() -> void:
	if _decal_mesh != null and _decal_mat != null:
		return
	_decal_mesh = QuadMesh.new()
	_decal_mesh.size = Vector2(0.09, 0.09)
	var grad := Gradient.new()
	grad.set_color(0, Color(0.05, 0.05, 0.06, 0.85))
	grad.set_color(1, Color(0.05, 0.05, 0.06, 0.0))
	grad.add_point(0.35, Color(0.08, 0.08, 0.09, 0.6))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	tex.width = 32
	tex.height = 32
	_decal_mat = StandardMaterial3D.new()
	_decal_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_decal_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_decal_mat.albedo_texture = tex
	_decal_mat.albedo_color = Color(1, 1, 1, 0.9)


static func _reset_pools_if_scene_invalid() -> void:
	if _flash_pool.size() > 0 and not is_instance_valid(_flash_pool[0]):
		_flash_pool.clear(); _flash_ttl.clear(); _flash_life.clear(); _flash_base.clear(); _flash_next = 0
	if _tracer_pool.size() > 0 and not is_instance_valid(_tracer_pool[0]):
		_tracer_pool.clear(); _tracer_ttl.clear(); _tracer_life.clear(); _tracer_width.clear(); _tracer_next = 0
	if _puff_pool.size() > 0 and not is_instance_valid(_puff_pool[0]):
		_puff_pool.clear(); _puff_ttl.clear(); _puff_life.clear(); _puff_grow.clear(); _puff_y0.clear(); _puff_next = 0
	if _melee_pool.size() > 0 and not is_instance_valid(_melee_pool[0]):
		_melee_pool.clear(); _melee_ttl.clear(); _melee_life.clear(); _melee_from.clear(); _melee_to.clear(); _melee_next = 0
	if _decals.size() > 0 and not is_instance_valid(_decals[0]):
		_decals.clear(); _decal_idx = 0
	if _host != null and not is_instance_valid(_host):
		_host = null


static func _ensure_host() -> void:
	_reset_pools_if_scene_invalid()
	if _host != null and is_instance_valid(_host):
		return
	var sc := _scene()
	if sc == null:
		return
	var h := FXTicker.new()
	h.name = "FXHost"
	sc.add_child(h)
	_host = h
	_ensure_flash_res()
	_ensure_tracer_res()
	_ensure_decal_res()
	_prewarm_flash()
	_prewarm_tracer()
	_prewarm_puff()
	_prewarm_melee()


static func _prewarm_flash() -> void:
	if _flash_pool.size() >= FLASH_MAX:
		return
	var need := FLASH_MAX - _flash_pool.size()
	for i in range(need):
		var mi := MeshInstance3D.new()
		mi.mesh = _flash_mesh
		mi.material_override = _flash_mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visible = false
		mi.transparency = 0.0
		_host.add_child(mi)
		_flash_pool.append(mi)
		_flash_ttl.append(0.0)
		_flash_life.append(0.0)
		_flash_base.append(Vector3.ONE)


static func _prewarm_tracer() -> void:
	if _tracer_pool.size() >= TRACER_MAX:
		return
	var need := TRACER_MAX - _tracer_pool.size()
	for i in range(need):
		var mi := MeshInstance3D.new()
		mi.mesh = _tracer_mesh
		mi.material_override = _get_tracer_mat(Color(1.0, 0.88, 0.45))
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visible = false
		mi.transparency = 0.0
		_host.add_child(mi)
		_tracer_pool.append(mi)
		_tracer_ttl.append(0.0)
		_tracer_life.append(0.0)
		_tracer_width.append(0.025)


static func _prewarm_puff() -> void:
	if _puff_pool.size() >= PUFF_MAX:
		return
	var need := PUFF_MAX - _puff_pool.size()
	for i in range(need):
		var mi := MeshInstance3D.new()
		var s := SphereMesh.new()
		s.radius = 0.06
		s.height = 0.12
		s.radial_segments = 6
		s.rings = 3
		mi.mesh = s
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visible = false
		mi.transparency = 0.0
		_host.add_child(mi)
		_puff_pool.append(mi)
		_puff_ttl.append(0.0)
		_puff_life.append(0.0)
		_puff_grow.append(1.0)
		_puff_y0.append(0.0)


static func _prewarm_melee() -> void:
	if _melee_pool.size() >= MELEE_POOL_MAX:
		return
	if _melee_mesh_l == null:
		_melee_mesh_l = BoxMesh.new()
		_melee_mesh_l.size = Vector3(0.025, 0.025, 1.0)
		_melee_mesh_h = BoxMesh.new()
		_melee_mesh_h.size = Vector3(0.025, 0.025, 1.0)
	var need := MELEE_POOL_MAX - _melee_pool.size()
	for i in range(need):
		var mi := MeshInstance3D.new()
		mi.mesh = _melee_mesh_l
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visible = false
		_host.add_child(mi)
		_melee_pool.append(mi)
		_melee_ttl.append(0.0)
		_melee_life.append(0.0)
		_melee_from.append(Vector3.ZERO)
		_melee_to.append(Vector3.ZERO)


static func _on_tick(delta: float) -> void:
	for i in range(_flash_pool.size()):
		if _flash_ttl[i] <= 0.0:
			continue
		_flash_ttl[i] -= delta
		if _flash_ttl[i] <= 0.0:
			_flash_pool[i].visible = false
			_flash_pool[i].transparency = 0.0
			_flash_ttl[i] = 0.0
			continue
		var life := _flash_life[i]
		var t := 1.0 - (_flash_ttl[i] / life) if life > 0.0 else 1.0
		var base: Vector3 = _flash_base[i]
		_flash_pool[i].scale = base * lerpf(1.0, 0.32, t)
		_flash_pool[i].transparency = clampf(t, 0.0, 1.0)
	for i in range(_tracer_pool.size()):
		if _tracer_ttl[i] <= 0.0:
			continue
		_tracer_ttl[i] -= delta
		if _tracer_ttl[i] <= 0.0:
			_tracer_pool[i].visible = false
			_tracer_pool[i].transparency = 0.0
			_tracer_ttl[i] = 0.0
			continue
		var life2 := _tracer_life[i]
		var t2 := 1.0 - (_tracer_ttl[i] / life2) if life2 > 0.0 else 1.0
		var w: float = _tracer_width[i]
		var hold := 0.05
		var cur_w: float
		if t2 * life2 < hold:
			cur_w = w
		else:
			var k := (t2 * life2 - hold) / (life2 - hold) if life2 > hold else 1.0
			cur_w = lerpf(w, w * 0.15, clampf(k, 0.0, 1.0))
		var dist: float = _tracer_pool[i].scale.z
		_tracer_pool[i].scale = Vector3(cur_w, cur_w, dist)
		_tracer_pool[i].transparency = clampf(t2 * 0.95, 0.0, 1.0)
	for i in range(_puff_pool.size()):
		if _puff_ttl[i] <= 0.0:
			continue
		_puff_ttl[i] -= delta
		if _puff_ttl[i] <= 0.0:
			_puff_pool[i].visible = false
			_puff_pool[i].transparency = 0.0
			_puff_ttl[i] = 0.0
			continue
		var life3 := _puff_life[i]
		var t3 := 1.0 - (_puff_ttl[i] / life3) if life3 > 0.0 else 1.0
		var g: float = _puff_grow[i]
		_puff_pool[i].scale = Vector3.ONE * lerpf(1.0, g, t3)
		_puff_pool[i].position.y = _puff_y0[i] + t3 * 0.25
		_puff_pool[i].transparency = clampf(t3, 0.0, 1.0)
	for i in range(_melee_pool.size()):
		if _melee_ttl[i] <= 0.0:
			continue
		_melee_ttl[i] -= delta
		if _melee_ttl[i] <= 0.0:
			_melee_pool[i].visible = false
			_melee_ttl[i] = 0.0
			continue
		var life4 := _melee_life[i]
		var t4 := 1.0 - (_melee_ttl[i] / life4) if life4 > 0.0 else 1.0
		_melee_pool[i].global_position = _melee_from[i].lerp(_melee_to[i], t4)
		_melee_pool[i].scale = Vector3(1, 1, 1) * lerpf(1.0, 0.18, t4)
		_melee_pool[i].transparency = clampf(t4, 0.0, 1.0)


# Public FX API — signatures preserved for callers

static func muzzle_flash(pos: Vector3, size: float = 0.12) -> void:
	_ensure_host()
	_ensure_flash_res()
	if _flash_pool.is_empty():
		return
	var idx := -1
	for i in range(_flash_pool.size()):
		if _flash_ttl[i] <= 0.0:
			idx = i
			break
	if idx == -1:
		idx = _flash_next
		_flash_next = (_flash_next + 1) % FLASH_MAX
	var mi := _flash_pool[idx]
	if not is_instance_valid(mi):
		return
	mi.mesh = _flash_mesh
	var is_player_flash := size < 0.1
	mi.material_override = _flash_mat_player if is_player_flash else _flash_mat
	mi.global_position = pos
	if is_player_flash:
		mi.rotation.z = 0.0
		mi.scale = Vector3(size, size, 1.0)
	else:
		mi.rotation.z = randf() * TAU
		var aspect := randf_range(0.78, 1.22)
		var sx := size * aspect
		var sy := size * (1.6 - aspect * 0.6)
		mi.scale = Vector3(sx, sy, 1.0)
	mi.transparency = 0.0
	mi.visible = true
	var life := 0.040 if is_player_flash else randf_range(0.035, 0.055)
	_flash_ttl[idx] = life
	_flash_life[idx] = life
	_flash_base[idx] = mi.scale


static func tracer(from: Vector3, to: Vector3, color: Color = Color(1.0, 0.88, 0.45), width: float = 0.025) -> void:
	var dist := from.distance_to(to)
	if dist < 1.0:
		return
	_ensure_host()
	_ensure_tracer_res()
	if _tracer_pool.is_empty():
		return
	var idx := -1
	for i in range(_tracer_pool.size()):
		if _tracer_ttl[i] <= 0.0:
			idx = i
			break
	if idx == -1:
		idx = _tracer_next
		_tracer_next = (_tracer_next + 1) % TRACER_MAX
	var mi := _tracer_pool[idx]
	if not is_instance_valid(mi):
		return
	mi.mesh = _tracer_mesh
	var mat := _get_tracer_mat(color)
	mi.material_override = mat
	mi.scale = Vector3(width, width, dist)
	mi.global_position = (from + to) * 0.5
	var dir := (to - from).normalized()
	var up := Vector3.UP
	if absf(dir.dot(up)) > 0.98:
		up = Vector3.FORWARD
	mi.look_at(to, up)
	mi.transparency = 0.0
	mi.visible = true
	var life := 0.14
	_tracer_ttl[idx] = life
	_tracer_life[idx] = life
	_tracer_width[idx] = width


static func impact(pos: Vector3, color: Color = Color(0.85, 0.80, 0.65)) -> void:
	var wood := Color(0.55, 0.38, 0.18)
	var metal := Color(1.0, 0.85, 0.35)
	var dirt := Color(0.62, 0.58, 0.48)
	var dw := _color_diff(color, wood)
	var dm := _color_diff(color, metal)
	var dd := _color_diff(color, dirt)
	if dw < dm and dw < dd and dw < 0.25:
		_puff(pos, color, 0.05, 2.2, 0.20)
	elif dm < dw and dm < dd and dm < 0.25:
		_puff(pos, color, 0.042, 3.4, 0.14)
	elif dd < dw and dd < dm and dd < 0.25:
		_puff(pos, color, 0.07, 1.9, 0.24)
	else:
		_puff(pos, color, 0.06, 3.0, 0.18)


static func decal(pos: Vector3, normal: Vector3) -> void:
	_ensure_decal_res()
	_reset_pools_if_scene_invalid()
	if _decals.size() > 0 and not is_instance_valid(_decals[0]):
		_decals.clear()
		_decal_idx = 0
	var mi: MeshInstance3D
	if _decals.size() < DECAL_MAX:
		mi = MeshInstance3D.new()
		mi.mesh = _decal_mesh
		mi.material_override = _decal_mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var sc := _scene()
		if sc != null:
			sc.add_child(mi)
		_decals.append(mi)
	else:
		mi = _decals[_decal_idx]
	_decal_idx = (_decal_idx + 1) % DECAL_MAX
	if not is_instance_valid(mi):
		return
	var n := normal.normalized() if normal.length_squared() > 0.01 else Vector3.UP
	mi.visible = true
	var sc2 := _scene()
	if sc2 != null and mi.get_parent() == null:
		sc2.add_child(mi)
	mi.global_position = pos + n * 0.012
	if absf(n.dot(Vector3.UP)) < 0.98:
		mi.look_at(mi.global_position + n, Vector3.UP)
	else:
		mi.look_at(mi.global_position + n, Vector3.FORWARD)
	mi.rotation.z = randf() * TAU
	mi.scale = Vector3.ONE * randf_range(0.8, 1.3)


static func blood(pos: Vector3) -> void:
	_puff(pos, Color(0.75, 0.12, 0.10), 0.09, 2.6, 0.22)


static func parry_flash(pos: Vector3) -> void:
	_puff(pos, Color(0.65, 0.90, 1.0), 0.30, 4.5, 0.22)
	_puff(pos, Color(1.0, 1.0, 0.9), 0.12, 3.0, 0.14)


static func melee_hit(pos: Vector3, attack_dir: Vector3, heavy: bool = false) -> void:
	_ensure_host()
	if _melee_mesh_l == null:
		_melee_mesh_l = BoxMesh.new()
		_melee_mesh_l.size = Vector3(0.025, 0.025, 1.0)
		_melee_mesh_h = BoxMesh.new()
		_melee_mesh_h.size = Vector3(0.025, 0.025, 1.0)
	var tint := Color(1.0, 0.66, 0.22) if heavy else Color(0.62, 0.88, 1.0)
	var mat: Variant = _melee_mats.get(tint)
	if mat == null:
		mat = _unshaded(tint)
		(mat as StandardMaterial3D).transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		(mat as StandardMaterial3D).blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		if _melee_mats.size() >= 8:
			_melee_mats.clear()
		_melee_mats[tint] = mat
	var forward := attack_dir.normalized()
	if forward.length_squared() < 0.001:
		forward = Vector3.FORWARD
	var right := forward.cross(Vector3.UP).normalized()
	if right.length_squared() < 0.01:
		right = Vector3.RIGHT
	var count := 7 if heavy else 5
	var base_mat := mat as Material
	var base_mesh := _melee_mesh_h if heavy else _melee_mesh_l
	var streak_len := 0.34 if heavy else 0.24
	var outward_dist := 0.75 if heavy else 0.52
	for i in range(count):
		var angle := TAU * float(i) / float(count)
		var outward := (right * cos(angle) + Vector3.UP * sin(angle)).normalized()
		var start := pos + outward * 0.10
		var end := pos + outward * outward_dist
		var idx := -1
		for k in range(_melee_pool.size()):
			if _melee_ttl[k] <= 0.0:
				idx = k
				break
		if idx == -1:
			idx = _melee_next
			_melee_next = (_melee_next + 1) % MELEE_POOL_MAX
		var mi := _melee_pool[idx]
		if not is_instance_valid(mi):
			continue
		mi.mesh = base_mesh
		mi.material_override = base_mat
		mi.scale = Vector3(1, 1, streak_len)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.global_position = start
		var look_target := pos + outward
		var up2 := Vector3.UP if absf(outward.dot(Vector3.UP)) < 0.95 else Vector3.FORWARD
		mi.look_at(look_target, up2)
		mi.transparency = 0.0
		mi.visible = true
		_melee_ttl[idx] = 0.15
		_melee_life[idx] = 0.15
		_melee_from[idx] = start
		_melee_to[idx] = end
	_puff(pos, tint, 0.11 if heavy else 0.08, 3.8, 0.16)


static func attack_ring(parent: Node3D, radius: float, color: Color) -> MeshInstance3D:
	var mesh: Variant = _ring_meshes.get(radius)
	if mesh == null:
		var t := TorusMesh.new()
		t.inner_radius = radius * 0.88
		t.outer_radius = radius
		t.rings = 24
		t.ring_segments = 5
		_ring_meshes[radius] = t
		mesh = t
	var mat: Variant = _ring_mats.get(color)
	if mat == null:
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.albedo_color = color
		m.emission_enabled = true
		m.emission = Color(color.r, color.g, color.b)
		m.emission_energy_multiplier = 2.0
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		if _ring_mats.size() >= 8:
			_ring_mats.clear()
		_ring_mats[color] = m
		mat = m
	var ring := MeshInstance3D.new()
	ring.mesh = mesh as Mesh
	ring.material_override = mat as Material
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.position.y = 0.08
	ring.visible = false
	parent.add_child(ring)
	return ring


static func _puff(pos: Vector3, color: Color, radius: float, grow: float, life: float) -> void:
	_ensure_host()
	var s: SphereMesh = _puff_meshes.get(radius)
	if s == null:
		s = SphereMesh.new()
		s.radius = radius
		s.height = radius * 2.0
		s.radial_segments = 6
		s.rings = 3
		_puff_meshes[radius] = s
	var key := Color(color.r, color.g, color.b, 1.0)
	var mat: Variant = _puff_mats.get(key)
	if mat == null:
		var m := _unshaded(Color(key.r, key.g, key.b, 0.85))
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		if _puff_mats.size() >= 8:
			_puff_mats.clear()
		_puff_mats[key] = m
		mat = m
	if _puff_pool.is_empty():
		return
	var idx := -1
	for i in range(_puff_pool.size()):
		if _puff_ttl[i] <= 0.0:
			idx = i
			break
	if idx == -1:
		idx = _puff_next
		_puff_next = (_puff_next + 1) % PUFF_MAX
	var mi := _puff_pool[idx]
	if not is_instance_valid(mi):
		return
	mi.mesh = s
	mi.material_override = mat as Material
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.scale = Vector3.ONE
	mi.position.y = pos.y
	mi.global_position = pos
	mi.transparency = 0.0
	mi.visible = true
	_puff_ttl[idx] = life
	_puff_life[idx] = life
	_puff_grow[idx] = grow
	_puff_y0[idx] = pos.y
