class_name Zone
extends Node3D
## 毒圈：分阶段等待→收缩，圈外持续掉血，可视化圈墙

signal shrinking_changed(shrinking: bool)

const PHASES := [
	{"wait": 20.0, "shrink": 30.0, "radius": 170.0, "dps": 2.0},
	{"wait": 18.0, "shrink": 25.0, "radius": 110.0, "dps": 4.0},
	{"wait": 15.0, "shrink": 20.0, "radius": 62.0, "dps": 8.0},
	{"wait": 13.0, "shrink": 16.0, "radius": 28.0, "dps": 14.0},
	{"wait": 11.0, "shrink": 14.0, "radius": 9.0, "dps": 20.0},
]

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
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(0.25, 0.75, 1.0, 0.16)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
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


func status_text() -> String:
	if not active:
		return ""
	if phase >= PHASES.size():
		return "决赛圈！"
	if shrinking:
		return "毒圈收缩中 %ds" % int(ceil(timer))
	return "安全区 %ds 后收缩" % int(ceil(timer))


func _process(delta: float) -> void:
	if not active or phase >= PHASES.size():
		return
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
	var ang := randf() * TAU
	_target_center = center + Vector2.from_angle(ang) * randf() * max_off
	_from_center = center
	_from_radius = radius
	_shrink_total = ph.shrink
	timer = ph.shrink
	shrinking = true
	shrinking_changed.emit(true)


func _update_wall() -> void:
	_wall.position = Vector3(center.x, 30.0, center.y)
	_wall.scale = Vector3(radius, 160.0, radius)


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
