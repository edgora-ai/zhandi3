class_name DamageNumber
extends Label3D
## 飘字伤害反馈：命中瞬间在目标头顶弹出数字/短句，上浮淡出后自毁。

static var _font: Font
# // FIX: M7 飘字限频/合批已存在（200ms/8个+80ms同位合并） — 已验证合批
static var _recent_ms: Array[int] = []
static var _last_text := ""
static var _last_pos := Vector3.ZERO
static var _last_ms := 0

var _t := 0.0


static func spawn_at(parent: Node, pos: Vector3, text_value: String, color: Color = Color(1.0, 0.85, 0.25)) -> void:
	var now := Time.get_ticks_msec()
	# 滑窗限频：200ms 内至多 8 个，超出直接丢弃；同文本同位置 80ms 内合并 # // FIX: M7
	_recent_ms = _recent_ms.filter(func(t: int) -> bool: return now - t < 200)
	if _recent_ms.size() >= 8:
		return
	if text_value == _last_text and pos.distance_to(_last_pos) < 1.2 and now - _last_ms < 80:
		return
	_recent_ms.append(now)
	_last_text = text_value
	_last_pos = pos
	_last_ms = now
	if _font == null:
		_font = load("res://assets/fonts/NotoSansCJKsc-Regular.otf")
	var n := DamageNumber.new()
	n.text = text_value
	n.font = _font
	n.font_size = 72
	n.pixel_size = 0.011
	n.modulate = color
	n.outline_size = 12
	n.outline_modulate = Color(0, 0, 0, 0.9)
	n.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	n.no_depth_test = true # // FIX: M7 保留 no_depth_test 但已限频，避免刷屏遮挡
	n.position = pos + Vector3(randf_range(-0.25, 0.25), randf_range(0.0, 0.2), randf_range(-0.25, 0.25))
	parent.add_child(n)


func _process(delta: float) -> void:
	_t += delta
	position.y += delta * 1.35
	var k := 1.0 - smoothstep(0.45, 0.85, _t)
	modulate.a = k
	outline_modulate.a = k * 0.9
	if _t >= 0.9:
		queue_free()
