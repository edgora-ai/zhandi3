class_name ShrineTrial
extends Node3D
## 神庙试炼：靠近开启，限时射中全部符文，奖励精灵宝珠（生命上限 +10）。

const RUNE_COUNT := 4
const TIME_LIMIT := 15.0
const START_DIST := 22.0

var player: Player
var completed := false
var _runes: Array[ShrineRune] = []
var _active := false
var _window := 0.0
var _hit_count := 0


func setup(p_player: Player) -> void:
	player = p_player
	# 符文环绕神庙入口悬浮，高度错落，需要稍微找角度。
	var spots := [
		Vector3(-2.6, 2.2, -4.6), Vector3(2.8, 3.4, -4.0),
		Vector3(-3.4, 4.6, -1.0), Vector3(3.2, 2.6, 1.6),
	]
	for spot in spots:
		var rune := ShrineRune.new()
		rune.trial = self
		add_child(rune)
		rune.position = spot
		_runes.append(rune)


func on_rune_hit(_rune: ShrineRune) -> void:
	_hit_count += 1
	var scene := get_tree().current_scene
	if scene and scene.get("hud") != null:
		scene.hud.add_feed("符文点亮 %d/%d" % [_hit_count, RUNE_COUNT])
	if _hit_count >= RUNE_COUNT:
		_complete()


func _complete() -> void:
	completed = true
	_active = false
	var scene := get_tree().current_scene
	if scene and scene.get("hud") != null:
		scene.hud.add_feed("神庙试炼完成！获得精灵宝珠")
	Loot.spawn(scene, global_position + Vector3(0, 1.2, -5.2), "orb", "", 1, 3)
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
	if _active:
		return ["神庙试炼 %d/%d（剩 %ds）" % [_hit_count, RUNE_COUNT, int(_window)], float(_hit_count) / RUNE_COUNT]
	return ["接近神庙开启试炼", 0.0]


func _process(delta: float) -> void:
	if completed or player == null:
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
