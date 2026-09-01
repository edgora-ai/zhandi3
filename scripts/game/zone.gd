class_name Zone
extends Node3D
## 毒圈：分阶段等待→收缩，圈外持续掉血，可视化圈墙

signal shrinking_changed(shrinking: bool)

# // FIX: OPT-G1/G5/R24 毒圈节奏重调：总时长 wait 143s + shrink 67s ≈ 210s（+grace 10 ≈ 220s）；
# 第 3 阶段（index 2）起收缩速度 ≥8.6 m/s（105→55/5.5s=9.1、55→28/3.0s=9.0、28→14/1.6s=8.75），
# 逼位移逼交火；决赛圈 9→14m 缓冲；圈外 DPS 每阶段翻倍 2→4→8→16→32，不理圈必死于前中期。
const PHASES := [
	{"wait": 45.0, "shrink": 35.0, "radius": 170.0, "dps": 2.0},
	{"wait": 36.0, "shrink": 22.0, "radius": 105.0, "dps": 4.0},
	{"wait": 26.0, "shrink": 5.5, "radius": 55.0, "dps": 8.0},
	{"wait": 20.0, "shrink": 3.0, "radius": 28.0, "dps": 16.0},
	{"wait": 16.0, "shrink": 1.6, "radius": 14.0, "dps": 32.0},
]

var rng := RandomNumberGenerator.new() # // FIX: OPT-G7/REG4 毒圈漂移可播种（原全局 randf 不受 --seed 控制）

var center := Vector2.ZERO
var radius := 265.0
var phase := -1
var shrinking := false
var timer := 0.0
var active := false

var _from_center := Vector2.ZERO
var _from_radius := 265.0
var _target_center := Vector2.ZERO
var _target_radius := 265.0
var _shrink_total := 1.0
var _dmg_acc := 0.0
var _wall: MeshInstance3D


func _ready() -> void:
	var cm := CylinderMesh.new()
	cm.top_radius = 1.0
	cm.bottom_radius = 1.0
	cm.height = 1.0
	cm.radial_segments = 96
	cm.cap_top = false
	cm.cap_bottom = false
	_wall = MeshInstance3D.new()
	_wall.mesh = cm
	var m := ShaderMaterial.new()
	m.shader = load("res://assets/shaders/zone.gdshader")
	_wall.material_override = m
	_wall.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if OS.get_cmdline_user_args().has("--nozonewall"):
		_wall.visible = false
	add_child(_wall)
	_update_wall()


func start(grace: float) -> void:
	active = true
	phase = 0
	shrinking = false
	timer = grace + PHASES[phase].wait


func current_dps() -> float:
	if phase < 0:
		return 0.0
	return PHASES[mini(phase, PHASES.size() - 1)].dps


func is_outside(pos: Vector3) -> bool:
	return Vector2(pos.x, pos.z).distance_to(center) > radius


# // FIX: OPT-H1/FX10 下一目标圈数据 (center_x, radius, center_z)：小地图虚线预览与 HUD 同源
func next_target() -> Vector3:
	return Vector3(_target_center.x, _target_radius, _target_center.y)


func status_text() -> String:
	if not active:
		return ""
	if phase >= PHASES.size():
		return "决赛圈！"
	if shrinking:
		return "毒圈收缩中 %ds" % int(ceil(timer))
	return "安全区 %ds 后收缩" % int(ceil(timer))


func _process(delta: float) -> void:
	if not active:
		return
	# 即使已到决赛圈后（phase==size）仍保持最后阶段 DPS，不提前 return
	if phase < PHASES.size():
		timer -= delta
		if shrinking:
			var t := clampf(1.0 - timer / _shrink_total, 0.0, 1.0)
			center = _from_center.lerp(_target_center, t)
			radius = lerpf(_from_radius, _target_radius, t)
			if timer <= 0.0:
				shrinking = false
				phase += 1
				if phase < PHASES.size():
					timer = PHASES[phase].wait
					shrinking_changed.emit(false)
		elif timer <= 0.0:
			_begin_shrink()
		_update_wall()
	_damage_tick(delta)


func _begin_shrink() -> void:
	var ph: Dictionary = PHASES[phase]
	_target_radius = ph.radius
	var max_off := maxf(0.0, (radius - _target_radius) * 0.6)
	var ang := rng.randf() * TAU
	_target_center = center + Vector2.from_angle(ang) * rng.randf() * max_off
	_from_center = center
	_from_radius = radius
	_shrink_total = ph.shrink
	timer = ph.shrink
	shrinking = true
	# // FIX: OPT-G7 缩圈中心序列日志（headless 断言 --seed 复现）
	if OS.get_cmdline_user_args().has("--sim"):
		print("[zone][seed] phase=%d center=(%.2f,%.2f) r=%.1f" % [phase, _target_center.x, _target_center.y, _target_radius])
	shrinking_changed.emit(true)


func _update_wall() -> void:
	_wall.position = Vector3(center.x, 25.0, center.y)
	_wall.scale = Vector3(radius, 70.0, radius)


func _damage_tick(delta: float) -> void:
	_dmg_acc += delta
	if _dmg_acc < 0.5:
		return
	_dmg_acc = 0.0
	var dps := current_dps()
	if dps <= 0.0:
		return
	for c in get_tree().get_nodes_in_group("combatant"):
		if not c.alive:
			continue
		if is_outside(c.global_position):
			c.take_damage(dps * 0.5, null)
			# // FIX: OPT-H1/FX10 圈外掉血 tick 音（≥2 次/s 低鸣），不再静默掉血
			if c is Player:
				var sfx := get_tree().get_first_node_in_group("sfx_bank")
				if sfx:
					sfx.play("zone_tick", -10.0, 1.0) # // FIX: R2-8 专用低鸣（原复用 hit.wav 确认音）
