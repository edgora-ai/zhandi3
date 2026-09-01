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
var _contest_t := 0.0 # // FIX: OPT-G2 争夺冻结计时，超 10s 进度倒退破站桩
var _fill_ring: MeshInstance3D # // FIX: OPT-H2/FX17 占领进度世界内可视化
var _fill_mat: StandardMaterial3D
var _last_tick_step := -1 # // FIX: OPT-H2 占领逐段 tick 音
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

	# // FIX: OPT-H2/FX17 占领进度环：随 progress 从圈缘向中心收缩（0→100% 扫描填充）
	_fill_ring = MeshInstance3D.new()
	var fc := TorusMesh.new()
	fc.inner_radius = RADIUS * 0.96
	fc.outer_radius = RADIUS
	fc.rings = 40
	fc.ring_segments = 6
	_fill_ring.mesh = fc
	_fill_mat = StandardMaterial3D.new()
	_fill_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_fill_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_fill_mat.albedo_color = Color(1.0, 0.85, 0.3, 0.55)
	_fill_mat.emission_enabled = true
	_fill_mat.emission = Color(1.0, 0.85, 0.3)
	_fill_mat.emission_energy_multiplier = 1.5
	_fill_ring.material_override = _fill_mat
	_fill_ring.position.y = 0.16
	_fill_ring.scale = Vector3.ONE * 0.001
	_fill_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_fill_ring)


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

	# // FIX: OPT-G2/PG4 owner 死亡即转中立：据点不再"属于死人"（原实现保留死人旗色与归属）
	if owner_body != null and (not is_instance_valid(owner_body) or not owner_body.alive):
		_clear_owner()

	var occupants: Array = []
	for c in get_tree().get_nodes_in_group("combatant"):
		if c.alive and global_position.distance_to(c.global_position) < RADIUS:
			occupants.append(c)

	if occupants.size() == 1:
		_contest_t = 0.0
		var c: CharacterBody3D = occupants[0]
		if c != owner_body:
			if _progress_by != c:
				_progress_by = c
				progress = 0.0
				_last_tick_step = -1
			progress += delta / CAPTURE_TIME
			_update_fill_ring(c)
			if progress >= 1.0:
				_set_owner(c)
	elif occupants.is_empty():
		_contest_t = 0.0
		progress = maxf(0.0, progress - delta * 0.15)
		if _fill_ring:
			_fill_ring.scale = _fill_ring.scale.lerp(Vector3.ONE * 0.001, delta * 6.0)
	else:
		# // FIX: OPT-G2 多人争夺冻结超过 10s 触发进度倒退 0.2/s，进攻方有破局手段
		_contest_t += delta
		if _contest_t > 10.0:
			progress = maxf(0.0, progress - delta * 0.2)


# // FIX: OPT-H2/FX17 进度环收缩 + 逐 20% tick 音加速
func _update_fill_ring(c: CharacterBody3D) -> void:
	if _fill_ring == null:
		return
	_fill_ring.visible = true
	var col := COLOR_PLAYER if c is Player else COLOR_BOT
	_fill_mat.albedo_color = Color(col.r, col.g, col.b, 0.55)
	_fill_mat.emission = col
	_fill_ring.scale = Vector3.ONE * maxf(0.05, 1.0 - progress)
	var step := int(progress * 5.0)
	if step > _last_tick_step:
		_last_tick_step = step
		var sfx := get_tree().get_first_node_in_group("sfx_bank")
		if sfx:
			sfx.play_at("pickup", global_position, -6.0, 0.9 + 0.25 * step)


func _set_owner(c: CharacterBody3D) -> void:
	owner_body = c
	trigger_radar(5.0)  # // FIX: AUD-3.9
	progress = 0.0
	_progress_by = null
	_contest_t = 0.0
	_apply_owner_color(Color(0.70, 0.70, 0.72) if c == null else (COLOR_PLAYER if c is Player else COLOR_BOT))
	owner_changed.emit(self, c)


# // FIX: OPT-G2 归属清除：旗/圈/光柱回中立色并广播
func _clear_owner() -> void:
	owner_body = null
	progress = 0.0
	_progress_by = null
	_apply_owner_color(COLOR_NEUTRAL)
	owner_changed.emit(self, null)


func _apply_owner_color(col: Color) -> void:
	_flag_mat.albedo_color = col
	_ring_mat.albedo_color = Color(col.r, col.g, col.b, 0.30)
	_beam_mat.albedo_color = Color(col.r, col.g, col.b, 0.24)
	_beam_mat.emission = col


var _radar_until := 0.0  # // FIX: AUD-3.9 占点雷达脉冲
var _radar_active := false

func trigger_radar(duration: float = 5.0) -> void:  # // FIX: AUD-3.9
	_radar_active = true
	# 雷达脉冲：占点后 40m 内敌可在小地图高亮 5s（由 hud 查询 is_radar_active 驱动，可视化在 Phase 3 收口）
	_radar_until = Time.get_ticks_msec() / 1000.0 + duration

func is_radar_active() -> bool:
	if _radar_active and Time.get_ticks_msec() / 1000.0 > _radar_until:
		_radar_active = false
	return _radar_active

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
