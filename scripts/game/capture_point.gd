class_name CapturePoint
extends Node3D
## 占领点：站入圈内 5 秒夺旗，归属方获得回血 + 伤害加成（由 main 统一结算）

signal owner_changed(point, new_owner)

const RADIUS := 6.0
const CAPTURE_TIME := 5.0

const COLOR_NEUTRAL := Color(0.70, 0.70, 0.72)
const COLOR_PLAYER := Color(0.25, 0.85, 0.35)
const COLOR_BOT := Color(0.90, 0.30, 0.22)

var point_name := "A"
var owner_body: CharacterBody3D = null
var progress := 0.0

var _progress_by: CharacterBody3D = null
var _flag: MeshInstance3D
var _ring: MeshInstance3D
var _beam: MeshInstance3D
var _flag_mat: StandardMaterial3D
var _ring_mat: StandardMaterial3D
var _beam_mat: StandardMaterial3D
var _t := 0.0


func _ready() -> void:
	add_to_group("capture_point")
	_build()


func _build() -> void:
	# 占领圈
	_ring = MeshInstance3D.new()
	var rc := CylinderMesh.new()
	rc.top_radius = RADIUS
	rc.bottom_radius = RADIUS
	rc.height = 0.12
	rc.radial_segments = 40
	_ring.mesh = rc
	_ring_mat = _flat_material(COLOR_NEUTRAL, 0.30)
	_ring.material_override = _ring_mat
	_ring.position.y = 0.1
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ring)

	# 远处可见的光柱
	_beam = MeshInstance3D.new()
	var bc := CylinderMesh.new()
	bc.top_radius = 0.4
	bc.bottom_radius = 0.4
	bc.height = 60.0
	bc.radial_segments = 10
	bc.cap_top = false
	bc.cap_bottom = false
	_beam.mesh = bc
	_beam_mat = _flat_material(COLOR_NEUTRAL, 0.24)
	_beam_mat.emission_enabled = true
	_beam_mat.emission = Color(COLOR_NEUTRAL)
	_beam_mat.emission_energy_multiplier = 1.5
	_beam.material_override = _beam_mat
	_beam.position.y = 30.0
	_beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_beam)

	# 旗杆
	var pole := MeshInstance3D.new()
	var pc := CylinderMesh.new()
	pc.top_radius = 0.06
	pc.bottom_radius = 0.08
	pc.height = 4.6
	pc.radial_segments = 6
	pole.mesh = pc
	pole.material_override = Toon.make_material(Color(0.4, 0.32, 0.22), false)
	pole.position.y = 2.3
	add_child(pole)

	# 旗帜
	_flag = MeshInstance3D.new()
	var fb := BoxMesh.new()
	fb.size = Vector3(1.25, 0.75, 0.05)
	_flag.mesh = fb
	_flag_mat = Toon.make_material(COLOR_NEUTRAL, true, 0.01)
	_flag.material_override = _flag_mat
	_flag.position = Vector3(0.68, 4.1, 0)
	add_child(_flag)


func _flat_material(c: Color, alpha: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(c.r, c.g, c.b, alpha)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


func _process(delta: float) -> void:
	_t += delta
	_flag.rotation.y = sin(_t * 2.0) * 0.25

	var occupants: Array = []
	for c in get_tree().get_nodes_in_group("combatant"):
		if c.alive and global_position.distance_to(c.global_position) < RADIUS:
			occupants.append(c)

	if occupants.size() == 1:
		var c: CharacterBody3D = occupants[0]
		if c != owner_body:
			if _progress_by != c:
				_progress_by = c
				progress = 0.0
			progress += delta / CAPTURE_TIME
			if progress >= 1.0:
				_set_owner(c)
	elif occupants.is_empty():
		progress = maxf(0.0, progress - delta * 0.15)
	# 多人争夺 → 进度冻结


func _set_owner(c: CharacterBody3D) -> void:
	owner_body = c
	progress = 0.0
	_progress_by = null
	var col := COLOR_PLAYER if c is Player else COLOR_BOT
	_flag_mat.albedo_color = col
	_ring_mat.albedo_color = Color(col.r, col.g, col.b, 0.30)
	_beam_mat.albedo_color = Color(col.r, col.g, col.b, 0.24)
	_beam_mat.emission = col
	owner_changed.emit(self, c)


func contains(c: CharacterBody3D) -> bool:
	return global_position.distance_to(c.global_position) < RADIUS


## 返回 [文本, 进度(-1 隐藏)]，供 HUD 显示
func hud_status(c: CharacterBody3D) -> Array:
	if not contains(c):
		return ["", -1.0]
	if owner_body == c:
		return ["已占领据点 %s（回血+伤害提升）" % point_name, 1.0]
	var others := 0
	for o in get_tree().get_nodes_in_group("combatant"):
		if o != c and o.alive and contains(o):
			others += 1
	if others > 0:
		return ["据点 %s 争夺中！" % point_name, progress]
	if _progress_by == c:
		return ["正在占领据点 %s..." % point_name, progress]
	return ["留在圈内占领据点 %s" % point_name, 0.0]
