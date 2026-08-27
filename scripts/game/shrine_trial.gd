class_name ShrineTrial
extends Node3D
## 神庙试炼：靠近开启，限时射中全部符文，奖励精灵宝珠（生命上限 +10）。

const RUNE_COUNT := 4
const TIME_LIMIT := 15.0
const START_DIST := 22.0

var player: Player
var completed := false
var mode := "rune"
var _plate_t := 0.0
var _plate: MeshInstance3D
var _runes: Array[ShrineRune] = []
var _active := false
var _window := 0.0
var _hit_count := 0


func setup(p_player: Player, trial_mode: Variant = "rune") -> void:
	player = p_player
	# 兼容布尔调用：true = 火盆。
	if trial_mode is bool:
		mode = "torch" if trial_mode else "rune"
	else:
		mode = str(trial_mode)
	if mode == "plate":
		_build_plate()
		return
	if mode == "ball":
		_build_ball_trial()
		return
	# 符文环绕神庙入口悬浮，高度错落，需要稍微找角度；火盆模式改为三座待点燃火盆。
	var spots := [
		Vector3(-2.6, 2.2, -4.6), Vector3(2.8, 3.4, -4.0),
		Vector3(-3.4, 4.6, -1.0), Vector3(3.2, 2.6, 1.6),
	]
	if mode == "torch":
		spots = [Vector3(-2.6, 1.0, -4.6), Vector3(2.8, 1.0, -4.0), Vector3(0.0, 1.0, -1.0), Vector3(3.2, 1.0, 1.6)]
	for spot in spots:
		var rune := ShrineRune.new()
		rune.torch_style = mode == "torch"
		rune.trial = self
		add_child(rune)
		rune.position = spot
		_runes.append(rune)


func _build_plate() -> void:
	# 压力板：站上 4 秒完成试炼。
	var stone := Toon.make_material(Color(0.22, 0.26, 0.28), true, 0.010)
	_plate = MeshInstance3D.new()
	var pm := CylinderMesh.new()
	pm.top_radius = 1.2
	pm.bottom_radius = 1.35
	pm.height = 0.16
	pm.radial_segments = 14
	_plate.mesh = pm
	_plate.material_override = stone
	_plate.position = Vector3(0, 0.55, -4.2)
	add_child(_plate)
	var ring := MeshInstance3D.new()
	var rm := TorusMesh.new()
	rm.inner_radius = 0.05
	rm.outer_radius = 1.05
	rm.rings = 20
	rm.ring_segments = 6
	ring.mesh = rm
	var ring_mat := StandardMaterial3D.new()
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_mat.albedo_color = Color(0.1, 0.9, 0.85)
	ring_mat.emission_enabled = true
	ring_mat.emission = Color(0.05, 0.95, 0.85)
	ring_mat.emission_energy_multiplier = 1.8
	ring.material_override = ring_mat
	ring.rotation_degrees.x = 90.0
	ring.position = Vector3(0, 0.66, -4.2)
	add_child(ring)


var _ball: RigidBody3D
var _socket := Vector3.ZERO

# 推球入臼：把重球推进发光圆环即完成。
func _build_ball_trial() -> void:
	_socket = Vector3(0, 0.4, -4.2)
	var ring_mat := StandardMaterial3D.new()
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_mat.albedo_color = Color(0.1, 0.9, 0.85)
	ring_mat.emission_enabled = true
	ring_mat.emission = Color(0.05, 0.95, 0.85)
	ring_mat.emission_energy_multiplier = 2.0
	var ring := MeshInstance3D.new()
	var rm := TorusMesh.new()
	rm.inner_radius = 0.08
	rm.outer_radius = 1.3
	rm.rings = 20
	rm.ring_segments = 6
	ring.mesh = rm
	ring.material_override = ring_mat
	ring.position = _socket
	add_child(ring)
	_ball = RigidBody3D.new()
	_ball.mass = 3.0
	_ball.linear_damp = 1.2
	_ball.angular_damp = 1.5
	var ball_mesh := MeshInstance3D.new()
	var bm := SphereMesh.new()
	bm.radius = 0.55
	bm.height = 1.1
	bm.radial_segments = 12
	bm.rings = 7
	ball_mesh.mesh = bm
	ball_mesh.material_override = Toon.make_material(Color(0.35, 0.38, 0.42), true, 0.014)
	_ball.add_child(ball_mesh)
	var col := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.55
	col.shape = shape
	_ball.add_child(col)
	add_child(_ball)
	_ball.position = Vector3(0, 0.7, -10.5)


func on_rune_hit(_rune: ShrineRune) -> void:
	_hit_count += 1
	var scene := get_tree().current_scene
	if scene and scene.get("hud") != null:
		scene.hud.add_feed("符文点亮 %d/%d" % [_hit_count, RUNE_COUNT])
	if _hit_count >= RUNE_COUNT:
		_complete()


func _complete() -> void:
	if completed:
		return
	completed = true
	_active = false
	var scene := get_tree().current_scene
	if scene and scene.get("hud") != null:
		scene.hud.add_feed("神庙试炼完成！石门开启")
	# 完成时刻全符文强光脉冲。
	var light := OmniLight3D.new()
	light.light_color = Color(0.5, 1.0, 0.85)
	light.light_energy = 3.0
	light.omni_range = 16.0
	light.position = Vector3(0, 3.5, -3.5)
	add_child(light)


func hud_status(pos: Vector3) -> Array:
	if completed or global_position.distance_to(pos) > 30.0:
		return ["", -1.0]
	if mode == "ball":
		var d := _ball.global_position.distance_to(global_position + _socket) if _ball else 99.0
		return ["把石球推进光环（%dm）" % int(d), 1.0 - clampf(d / 10.0, 0.0, 1.0)]
	if mode == "plate":
		if _plate_t > 0.05:
			return ["压力板 %.1f / 4.0 秒" % _plate_t, _plate_t / 4.0]
		return ["站上发光的圆盘", 0.0]
	if _active:
		return ["神庙试炼 %d/%d（剩 %ds）" % [_hit_count, RUNE_COUNT, int(_window)], float(_hit_count) / RUNE_COUNT]
	return ["接近神庙开启试炼", 0.0]


func _process(delta: float) -> void:
	if completed or player == null:
		return
	if mode == "plate":
		var pd := player.global_position.distance_to(_plate.global_position)
		var weighted := pd < 1.7
		if not weighted:
			# 金属块压板：磁力搬箱压在上面同样触发（旷野之息式解谜）。
			for prop in get_tree().get_nodes_in_group("metal_prop"):
				if prop.global_position.distance_to(_plate.global_position) < 1.6:
					weighted = true
					break
		if weighted:
			_plate_t += delta
			if _plate_t >= 4.0:
				completed = true
				var scene := get_tree().current_scene
				if scene and scene.get("hud") != null:
					scene.hud.add_feed("机关启动！石门开启")
		else:
			_plate_t = maxf(0.0, _plate_t - delta * 2.0)
		return
	if mode == "ball":
		if _ball and _ball.global_position.distance_to(global_position + _socket) < 1.3:
			completed = true
			_ball.freeze = true
			var scene := get_tree().current_scene
			if scene and scene.get("hud") != null:
				scene.hud.add_feed("石球归位！石门开启")
		return
	var dist := global_position.distance_to(player.global_position)
	if not _active and dist < START_DIST:
		_active = true
		_window = TIME_LIMIT
		_hit_count = 0
		var scene := get_tree().current_scene
		if scene and scene.get("hud") != null:
			scene.hud.add_feed("神庙试炼开启：%d 秒内射中 %d 个符文" % [int(TIME_LIMIT), RUNE_COUNT])
	elif _active:
		_window -= delta
		if _window <= 0.0:
			# 超时重置，可反复挑战。
			_active = false
			_hit_count = 0
			for rune in _runes:
				rune.reset_rune()
			var scene2 := get_tree().current_scene
			if scene2 and scene2.get("hud") != null:
				scene2.hud.add_feed("试炼超时，符文已重置")
