class_name DamageNumber
extends Label3D
## 飘字伤害反馈：命中瞬间在目标头顶弹出数字/短句，上浮淡出后自毁。

static var _font: Font

var _t := 0.0


static func spawn_at(parent: Node, pos: Vector3, text_value: String, color: Color = Color(1.0, 0.85, 0.25)) -> void:
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
	n.no_depth_test = true
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
