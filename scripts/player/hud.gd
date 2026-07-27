class_name HUD
extends CanvasLayer
## 玩家 HUD：准星、血条/护甲、弹药、毒圈状态、击杀播报、占点提示、结算画面

const MAX_FEED_ITEMS := 5

var _ui: Control
var _crosshair_lines := []
var _crosshair_dot: ColorRect
var _hp_bar: ColorRect
var _armor_bar: ColorRect
var _hp_label: Label
var _ammo_label: Label
var _weapon_label: Label
var _zone_label: Label
var _alive_label: Label
var _kills_label: Label
var _rupees_label: Label
var _world_state_label: Label
var _feed_box: VBoxContainer
var _interact_label: Label
var _capture_bar: ColorRect
var _capture_wrap: Control
var _capture_label: Label
var _stamina_segs: Array[ColorRect] = []
var _stamina_wrap: Control
var _minimap_wrap: Control
var _minimap_player: ColorRect
var _vignette: TextureRect
var _end_panel: Control
var _pause_panel: Control
var _backpack_panel: Control
var _shop_panel: Control
var _flurry_overlay: ColorRect
var _boss_bar: Control
var _boss_fill: ColorRect
var _death_panel: Control
var _map_panel: Control
var _spread_px := 8.0


func _ready() -> void:
	layer = 10
	_ui = Control.new()
	_ui.name = "UI"
	_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 默认字体不含中文字形，且字形回退链对部分字符失效 —— 直接整体换成内置 Noto Sans SC
	var font_path := "res://assets/fonts/NotoSansCJKsc-Regular.otf"
	if FileAccess.file_exists(font_path):
		var font := FontFile.new()
		font.data = FileAccess.get_file_as_bytes(font_path)
		var theme := Theme.new()
		theme.default_font = font
		_ui.theme = theme
	add_child(_ui)
	_build_crosshair()
	_build_stamina_wheel()
	_build_minimap()
	_build_bars()
	_build_top()
	_build_feed()
	_build_vignette()
	_ignore_mouse(_ui)


# HUD 全部控件不接收鼠标事件：捕获模式下光标钉在屏幕中心，
# 任何 mouse_filter=STOP 的可见控件（如准星）都会吞掉转向/开火输入
func _ignore_mouse(node: Node) -> void:
	if node is Control:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_ignore_mouse(child)


func _mk_label(parent: Control, text: String, size: int, color: Color = Color.WHITE) -> Label:
	var l := Label.new()
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	l.add_theme_constant_override("shadow_size", 3)
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 2)
	parent.add_child(l)
	return l


func _mk_rect(parent: Control, pos: Vector2, size: Vector2, color: Color) -> ColorRect:
	var r := ColorRect.new()
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.color = color
	r.position = pos
	r.size = size
	parent.add_child(r)
	return r


# ---------- 精力轮（16 段环形，只在消耗后显示） ----------

func _build_stamina_wheel() -> void:
	_stamina_wrap = Control.new()
	_stamina_wrap.name = "StaminaWheel"
	_stamina_wrap.set_anchors_preset(Control.PRESET_CENTER)
	_stamina_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stamina_wrap.visible = false
	_ui.add_child(_stamina_wrap)
	for i in range(16):
		var angle := -PI * 0.5 + float(i) * TAU / 16.0
		var seg := ColorRect.new()
		seg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		seg.size = Vector2(5, 12)
		seg.pivot_offset = Vector2(2.5, 6)
		seg.position = Vector2(58 + cos(angle) * 24.0, sin(angle) * 24.0)
		seg.rotation = angle + PI * 0.5
		_stamina_wrap.add_child(seg)
		_stamina_segs.append(seg)


func set_stamina(frac: float) -> void:
	_stamina_wrap.visible = frac < 0.999
	var lit := int(ceil(frac * 16.0))
	var color := Color(0.35, 0.90, 0.45) if frac > 0.5 else Color(0.95, 0.80, 0.25) if frac > 0.22 else Color(0.95, 0.30, 0.20)
	for i in range(_stamina_segs.size()):
		_stamina_segs[i].color = color if i < lit else Color(1, 1, 1, 0.15)


# ---------- 小地图 ----------

func _world_to_map(p: Vector3) -> Vector2:
	return Vector2((p.x + 250.0) / 500.0 * 164.0, (p.z + 250.0) / 500.0 * 164.0)


func _build_minimap() -> void:
	_minimap_wrap = Control.new()
	_minimap_wrap.name = "Minimap"
	_minimap_wrap.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_minimap_wrap.position = Vector2(-176, -176)
	_minimap_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_minimap_wrap)
	_mk_rect(_minimap_wrap, Vector2.ZERO, Vector2(164, 164), Color(0.04, 0.07, 0.06, 0.60))
	_mk_rect(_minimap_wrap, Vector2.ZERO, Vector2(164, 2), Color(0.4, 0.5, 0.4, 0.8))
	# 静态地标：驿站/神庙/塔/城堡/大桥/家/遗迹。
	var landmarks := [
		[Vector3(-72, 0, 21), Color(0.95, 0.75, 0.30)],
		[Vector3(-112, 0, 92), Color(0.20, 0.90, 0.80)],
		[Vector3(105, 0, 25), Color(0.20, 0.90, 0.80)],
		[Vector3(-140, 0, -110), Color(0.20, 0.90, 0.80)],
		[Vector3(-132, 0, 109), Color(0.95, 0.55, 0.20)],
		[Vector3(72, 0, 116), Color(0.95, 0.55, 0.20)],
		[Vector3(-132, 0, -78), Color(0.95, 0.55, 0.20)],
		[Vector3(4, 0, -124), Color(0.40, 0.60, 1.00)],
		[Vector3(6, 0, 18), Color(0.70, 0.55, 0.35)],
		[Vector3(-122, 0, 98), Color(0.45, 0.85, 0.45)],
		[Vector3(18, 0, -94), Color(0.75, 0.70, 0.65)],
		[Vector3(164, 0, -145), Color(1.00, 0.30, 0.10)],
	]
	for entry in landmarks:
		var dot := ColorRect.new()
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dot.size = Vector2(6, 6)
		dot.color = entry[1]
		dot.position = _world_to_map(entry[0]) - Vector2(3, 3)
		_minimap_wrap.add_child(dot)
	_minimap_player = ColorRect.new()
	_minimap_player.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_minimap_player.size = Vector2(8, 8)
	_minimap_player.color = Color(1.0, 1.0, 1.0)
	_minimap_wrap.add_child(_minimap_player)


func update_minimap(player: Player) -> void:
	if _minimap_wrap == null:
		return
	_minimap_wrap.visible = player != null and player.alive
	if player == null:
		return
	_minimap_player.position = _world_to_map(player.global_position) - Vector2(4, 4)


# ---------- 准星 ----------

func _build_crosshair() -> void:
	var c := Control.new()
	c.name = "Crosshair"
	c.set_anchors_preset(Control.PRESET_CENTER)
	_ui.add_child(c)
	for i in range(4):
		var line := ColorRect.new()
		line.color = Color(1, 1, 1, 0.9)
		line.size = Vector2(2, 10) if i < 2 else Vector2(10, 2)
		c.add_child(line)
		_crosshair_lines.append(line)
	_crosshair_dot = ColorRect.new()
	_crosshair_dot.color = Color(1, 1, 1, 0.9)
	_crosshair_dot.size = Vector2(3, 3)
	c.add_child(_crosshair_dot)
	_layout_crosshair()


func _layout_crosshair() -> void:
	var gap := _spread_px
	# 0上 1下 2左 3右
	_crosshair_lines[0].position = Vector2(-1, -gap - 10)
	_crosshair_lines[1].position = Vector2(-1, gap)
	_crosshair_lines[2].position = Vector2(-gap - 10, -1)
	_crosshair_lines[3].position = Vector2(gap, -1)
	_crosshair_dot.position = Vector2(-1.5, -1.5)


func set_spread(px: float) -> void:
	_spread_px = lerpf(_spread_px, px, 0.25)
	_layout_crosshair()


func set_crosshair_visible(v: bool) -> void:
	for l in _crosshair_lines:
		l.visible = v
	_crosshair_dot.visible = v


# ---------- 血条 / 弹药 ----------

func _build_bars() -> void:
	var wrap := Control.new()
	wrap.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	wrap.position = Vector2(24, -70)
	_ui.add_child(wrap)
	_mk_rect(wrap, Vector2.ZERO, Vector2(260, 14), Color(0, 0, 0, 0.45))
	_hp_bar = _mk_rect(wrap, Vector2(2, 2), Vector2(256, 10), Color(0.35, 0.85, 0.35))
	_mk_rect(wrap, Vector2(0, -10), Vector2(260, 7), Color(0, 0, 0, 0.45))
	_armor_bar = _mk_rect(wrap, Vector2(2, -8), Vector2(0, 3), Color(0.35, 0.6, 1.0))
	_hp_label = _mk_label(wrap, "100", 20)
	_hp_label.position = Vector2(268, -8)

	var aw := Control.new()
	aw.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	aw.position = Vector2(-280, -80)
	_ui.add_child(aw)
	_weapon_label = _mk_label(aw, "徒手", 18, Color(0.9, 0.9, 0.8))
	_weapon_label.position = Vector2(0, 0)
	_ammo_label = _mk_label(aw, "--", 34)
	_ammo_label.position = Vector2(60, 16)


func set_health(hp: float, armor: float) -> void:
	_hp_bar.size.x = 256.0 * clampf(hp / 100.0, 0.0, 1.0)
	_armor_bar.size.x = 256.0 * clampf(armor / 100.0, 0.0, 1.0)
	_hp_bar.color = Color(0.35, 0.85, 0.35) if hp > 35 else Color(0.9, 0.3, 0.2)
	_hp_label.text = str(int(ceil(hp)))


func set_ammo(mag: int, reserve: int) -> void:
	_ammo_label.text = "%d / %d" % [mag, reserve]


func set_weapon_name(n: String) -> void:
	_weapon_label.text = n


func set_ammo_text(t: String) -> void:
	_ammo_label.text = t


# ---------- 顶部信息 ----------

func _build_top() -> void:
	var wrap := Control.new()
	wrap.set_anchors_preset(Control.PRESET_CENTER_TOP)
	wrap.position = Vector2(-200, 14)
	_ui.add_child(wrap)
	_zone_label = _mk_label(wrap, "", 20, Color(0.75, 0.95, 1.0))
	_zone_label.position = Vector2(0, 0)
	_zone_label.size.x = 400
	_zone_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var rw := Control.new()
	rw.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	rw.position = Vector2(-220, 14)
	_ui.add_child(rw)
	_alive_label = _mk_label(rw, "存活 24", 20)
	_kills_label = _mk_label(rw, "击杀 0", 20, Color(1.0, 0.85, 0.4))
	_kills_label.position = Vector2(0, 26)
	_rupees_label = _mk_label(rw, "卢比 0", 20, Color(0.45, 0.95, 0.55))
	_rupees_label.position = Vector2(0, 52)

	_world_state_label = _mk_label(_ui, "", 17, Color(0.86, 0.95, 0.76))
	_world_state_label.position = Vector2(22, 18)
	_world_state_label.size = Vector2(420, 54)

	_capture_wrap = Control.new()
	_capture_wrap.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_capture_wrap.position = Vector2(-130, 52)
	_ui.add_child(_capture_wrap)
	_capture_label = _mk_label(_capture_wrap, "占领中...", 16, Color(1.0, 0.95, 0.6))
	_capture_label.position = Vector2(0, 0)
	_capture_label.size.x = 260
	_capture_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mk_rect(_capture_wrap, Vector2(0, 24), Vector2(260, 8), Color(0, 0, 0, 0.45))
	_capture_bar = _mk_rect(_capture_wrap, Vector2(2, 26), Vector2(0, 4), Color(1.0, 0.85, 0.3))
	_capture_wrap.visible = false


func set_zone_text(t: String) -> void:
	_zone_label.text = t


func set_alive(n: int) -> void:
	_alive_label.text = "存活 %d" % n


func set_alive_text(text: String) -> void:
	_alive_label.text = text


func set_kills(n: int) -> void:
	_kills_label.text = "击杀 %d" % n


func set_rupees(n: int) -> void:
	_rupees_label.text = "卢比 %d" % n


func set_world_state(text: String) -> void:
	_world_state_label.text = text


func set_capture(text: String, frac: float) -> void:
	if frac < 0.0:
		_capture_wrap.visible = false
		return
	_capture_wrap.visible = true
	_capture_label.text = text
	_capture_bar.size.x = 256.0 * clampf(frac, 0.0, 1.0)


# ---------- 击杀播报 ----------

func _build_feed() -> void:
	_feed_box = VBoxContainer.new()
	_feed_box.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_feed_box.position = Vector2(-420, 70)
	_feed_box.custom_minimum_size.x = 400
	_feed_box.alignment = BoxContainer.ALIGNMENT_END
	_ui.add_child(_feed_box)


func add_feed(text: String) -> void:
	var l := _mk_label(_feed_box, text, 15, Color(0.95, 0.95, 0.9))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	l.size_flags_horizontal = Control.SIZE_SHRINK_END
	var tw := l.create_tween()
	tw.tween_interval(4.5)
	tw.tween_property(l, "modulate:a", 0.0, 0.8)
	tw.tween_callback(l.queue_free)
	while _feed_box.get_child_count() > MAX_FEED_ITEMS:
		var oldest := _feed_box.get_child(0)
		# queue_free() 到帧末才移除节点；先脱离容器才能让当前循环收敛。
		_feed_box.remove_child(oldest)
		oldest.queue_free()


func feed_item_count() -> int:
	return _feed_box.get_child_count()


# ---------- 交互提示 / 受击 ----------

func set_interact(text: String) -> void:
	if _interact_label == null:
		_interact_label = Label.new()
		_interact_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_interact_label.add_theme_font_size_override("font_size", 18)
		_interact_label.add_theme_color_override("font_color", Color(1.0, 1.0, 0.8))
		_interact_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
		_interact_label.add_theme_constant_override("shadow_size", 3)
		_interact_label.set_anchors_preset(Control.PRESET_CENTER)
		_interact_label.position = Vector2(-120, 90)
		_interact_label.size.x = 240
		_interact_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_ui.add_child(_interact_label)
	_interact_label.text = text
	_interact_label.visible = text != ""


func _build_vignette() -> void:
	var grad := Gradient.new()
	grad.set_color(0, Color(0.7, 0.05, 0.05, 0.55))
	grad.set_color(1, Color(0.7, 0.05, 0.05, 0.0))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	tex.width = 512
	tex.height = 288
	_vignette = TextureRect.new()
	_vignette.texture = tex
	_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vignette.modulate.a = 0.0
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_vignette)


func flash_damage() -> void:
	_vignette.modulate.a = 1.0
	var tw := _vignette.create_tween()
	tw.tween_property(_vignette, "modulate:a", 0.0, 0.6)


func set_danger(on: bool) -> void:
	if on and _vignette.modulate.a < 0.25:
		_vignette.modulate.a = 0.25


# ---------- 结算 ----------

func show_end(victory: bool, rank: int, kills: int, total: int) -> void:
	if _end_panel:
		return
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_end_panel = Control.new()
	_end_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui.add_child(_end_panel)
	_mk_rect(_end_panel, Vector2.ZERO, Vector2(4000, 4000), Color(0, 0, 0, 0.62))
	# 结算卡片：主题顶条 + 大字排名 + 分隔线 + 数据行，胜金败红。
	var accent := Color(1.0, 0.85, 0.3) if victory else Color(0.95, 0.42, 0.32)
	var card := Control.new()
	card.set_anchors_preset(Control.PRESET_CENTER)
	card.position = Vector2(-260, -190)
	card.size = Vector2(520, 380)
	_end_panel.add_child(card)
	_mk_rect(card, Vector2.ZERO, Vector2(520, 380), Color(0.05, 0.06, 0.08, 0.92))
	_mk_rect(card, Vector2(6, 6), Vector2(508, 368), Color(0.10, 0.13, 0.16, 0.85))
	_mk_rect(card, Vector2(6, 6), Vector2(508, 6), accent)
	var title := _mk_label(card, "大吉大利，今晚吃鸡！" if victory else "阵  亡", 38, accent)
	title.position = Vector2(0, 28)
	title.size.x = 520
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var rank_label := _mk_label(card, "#%d" % rank, 62, Color(1.0, 0.95, 0.75) if victory else Color(0.90, 0.88, 0.82))
	rank_label.position = Vector2(0, 88)
	rank_label.size.x = 520
	rank_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var total_label := _mk_label(card, "共 %d 名战士" % total, 18, Color(0.72, 0.78, 0.84))
	total_label.position = Vector2(0, 166)
	total_label.size.x = 520
	total_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mk_rect(card, Vector2(60, 206), Vector2(400, 2), Color(0.35, 0.38, 0.42, 0.8))
	var stats := [
		["击  杀", "%d" % kills, Color(0.95, 0.55, 0.45)],
		["评  价", _rank_comment(victory, rank, total), Color(0.55, 0.85, 0.95)],
	]
	for i in range(stats.size()):
		var row: Array = stats[i]
		_mk_rect(card, Vector2(122, 236 + i * 42), Vector2(14, 14), row[2])
		var name_l := _mk_label(card, str(row[0]), 22, Color(0.82, 0.85, 0.88))
		name_l.position = Vector2(148, 228 + i * 42)
		var val_l := _mk_label(card, str(row[1]), 22, Color(0.97, 0.93, 0.80))
		val_l.position = Vector2(252, 228 + i * 42)
	var hint := _mk_label(card, "按 R 重新开始", 19, Color(0.75, 0.88, 1.0))
	hint.position = Vector2(0, 330)
	hint.size.x = 520
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ignore_mouse(_end_panel)


# 结算评语：按名次给一句 tiers 评价。
func _rank_comment(victory: bool, rank: int, total: int) -> String:
	if victory:
		return "传说再续"
	if rank <= 3:
		return "虽败犹荣"
	if rank <= int(ceil(total / 2.0)):
		return "可圈可点"
	return "再接再厉"


func show_quest_end(title_text: String, lines: Array[String]) -> void:
	if _end_panel:
		return
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_end_panel = Control.new()
	_end_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui.add_child(_end_panel)
	_mk_rect(_end_panel, Vector2.ZERO, Vector2(4000, 4000), Color(0, 0, 0, 0.62))
	# 与战场结算同款的卡片：金色顶条 + 居中标题与逐行结语。
	var card := Control.new()
	card.set_anchors_preset(Control.PRESET_CENTER)
	card.position = Vector2(-300, -175)
	card.size = Vector2(600, 350)
	_end_panel.add_child(card)
	_mk_rect(card, Vector2.ZERO, Vector2(600, 350), Color(0.05, 0.06, 0.08, 0.92))
	_mk_rect(card, Vector2(6, 6), Vector2(588, 338), Color(0.10, 0.13, 0.16, 0.85))
	_mk_rect(card, Vector2(6, 6), Vector2(588, 6), Color(1.0, 0.85, 0.3))
	var title := _mk_label(card, title_text, 38, Color(1.0, 0.85, 0.3))
	title.position = Vector2(0, 26)
	title.size.x = 600
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	for i in range(lines.size()):
		var sub := _mk_label(card, lines[i], 22, Color(0.88, 0.90, 0.92))
		sub.position = Vector2(0, 100 + i * 36)
		sub.size.x = 600
		sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var hint := _mk_label(card, "按 R 重新开始", 19, Color(0.75, 0.88, 1.0))
	hint.position = Vector2(0, 300)
	hint.size.x = 600
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ignore_mouse(_end_panel)


# ---------- 暂停（窗口失焦） ----------

func show_pause() -> void:
	if _pause_panel:
		return
	_pause_panel = Control.new()
	_pause_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui.add_child(_pause_panel)
	_mk_rect(_pause_panel, Vector2.ZERO, Vector2(4000, 4000), Color(0, 0, 0, 0.5))
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.position = Vector2(-250, -60)
	box.custom_minimum_size.x = 500
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	_pause_panel.add_child(box)
	var title := _mk_label(box, "已 暂 停", 44, Color(1.0, 0.95, 0.7))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var sub := _mk_label(box, "窗口失去焦点，点击游戏窗口继续", 20, Color(0.8, 0.9, 1.0))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ignore_mouse(_pause_panel)


func hide_pause() -> void:
	if _pause_panel:
		_pause_panel.queue_free()
		_pause_panel = null


# ---------- 背包 ----------

func show_backpack(lines: Array[String], selected: int) -> void:
	if _backpack_panel:
		_backpack_panel.queue_free()
	_backpack_panel = Control.new()
	_backpack_panel.set_anchors_preset(Control.PRESET_CENTER)
	_backpack_panel.position = Vector2(-330, -245)
	_backpack_panel.size = Vector2(660, 490)
	_ui.add_child(_backpack_panel)
	_mk_rect(_backpack_panel, Vector2.ZERO, Vector2(660, 490), Color(0.035, 0.075, 0.075, 0.94))
	_mk_rect(_backpack_panel, Vector2(8, 8), Vector2(644, 474), Color(0.09, 0.17, 0.16, 0.88))
	var title := _mk_label(_backpack_panel, "旅 行 背 包", 31, Color(0.97, 0.83, 0.42))
	title.position = Vector2(30, 24)
	var subtitle := _mk_label(_backpack_panel, "↑↓ / W S 选择    E / Enter 取出或使用    X 存入当前武器    B 关闭", 15, Color(0.68, 0.88, 0.83))
	subtitle.position = Vector2(30, 70)
	for i in range(lines.size()):
		var active := i == selected
		if active:
			_mk_rect(_backpack_panel, Vector2(25, 111 + i * 48), Vector2(610, 41), Color(0.18, 0.50, 0.45, 0.65))
		var label := _mk_label(_backpack_panel, ("▶  " if active else "    ") + lines[i], 19, Color(1.0, 0.94, 0.68) if active else Color(0.86, 0.90, 0.82))
		label.position = Vector2(38, 118 + i * 48)
	_ignore_mouse(_backpack_panel)


func hide_backpack() -> void:
	if _backpack_panel:
		_backpack_panel.queue_free()
		_backpack_panel = null


# ---------- 商店 ----------

func show_shop(lines: Array, rupees: int) -> void:
	if _shop_panel:
		_shop_panel.queue_free()
	_shop_panel = Control.new()
	_shop_panel.set_anchors_preset(Control.PRESET_CENTER)
	_shop_panel.position = Vector2(-280, -215)
	_shop_panel.size = Vector2(560, 430)
	_ui.add_child(_shop_panel)
	_mk_rect(_shop_panel, Vector2.ZERO, Vector2(560, 430), Color(0.075, 0.045, 0.02, 0.94))
	_mk_rect(_shop_panel, Vector2(8, 8), Vector2(544, 414), Color(0.17, 0.11, 0.05, 0.88))
	var title := _mk_label(_shop_panel, "多戈商店", 30, Color(0.97, 0.80, 0.40))
	title.position = Vector2(30, 24)
	var sub := _mk_label(_shop_panel, "持有卢比：%d    按 1/2/3 购买、4/5 出售    E / Esc 离开" % rupees, 16, Color(0.85, 0.92, 0.70))
	sub.position = Vector2(30, 72)
	# 结构化条目：图标色块 + 名称 + 价格栏；买不起的整行压暗。
	var row := 104
	for i in range(lines.size()):
		if i == 0 or i == 3:
			var head := _mk_label(_shop_panel, "— 购 买 —" if i == 0 else "— 出 售 —", 15, Color(0.72, 0.62, 0.42))
			head.position = Vector2(34, row - 4)
			row += 24
		var it: Dictionary = lines[i]
		var cost := int(it.get("cost", -1))
		var afford := cost < 0 or rupees >= cost
		var icon_col: Color = it.get("color", Color(0.9, 0.88, 0.7))
		_mk_rect(_shop_panel, Vector2(38, row + 4), Vector2(20, 20), icon_col if afford else icon_col.darkened(0.55))
		var label := _mk_label(_shop_panel, str(it.get("text", "")), 20, Color(0.92, 0.90, 0.76) if afford else Color(0.52, 0.50, 0.44))
		label.position = Vector2(70, row)
		var price_label := _mk_label(_shop_panel, str(it.get("price", "")), 18, Color(0.97, 0.83, 0.42) if afford else Color(0.52, 0.48, 0.38))
		price_label.position = Vector2(400, row + 2)
		row += 52
	_ignore_mouse(_shop_panel)


func hide_shop() -> void:
	if _shop_panel:
		_shop_panel.queue_free()
		_shop_panel = null


# ---------- 林克时间 ----------

# ---------- Boss 血条 ----------

# ---------- 死亡画面 ----------

# 旷野之息式死亡：红闪 + “你死了”，随后在最近神庙重生（由 main 调度）。
func show_death_screen() -> void:
	if _death_panel:
		return
	_death_panel = Control.new()
	_death_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui.add_child(_death_panel)
	_mk_rect(_death_panel, Vector2.ZERO, Vector2(4000, 4000), Color(0.20, 0.0, 0.0, 0.45))
	var t := _mk_label(_death_panel, "你 死 了", 64, Color(0.92, 0.16, 0.10))
	t.set_anchors_preset(Control.PRESET_CENTER)
	t.position = Vector2(-150, -44)
	var s := _mk_label(_death_panel, "正在返回最近的神庙……", 22, Color(0.86, 0.80, 0.74))
	s.set_anchors_preset(Control.PRESET_CENTER)
	s.position = Vector2(-130, 42)
	_ignore_mouse(_death_panel)


func hide_death_screen() -> void:
	if _death_panel:
		_death_panel.queue_free()
		_death_panel = null



# Boss 战血条：屏幕顶部居中的大型名条（进入战区自动显示，离开或讨伐即撤）。
func show_boss_bar(boss_name: String, ratio: float) -> void:
	if _boss_bar == null:
		_boss_bar = Control.new()
		_boss_bar.set_anchors_preset(Control.PRESET_CENTER)
		_boss_bar.position = Vector2(-240, -350)
		_boss_bar.size = Vector2(480, 60)
		_ui.add_child(_boss_bar)
		_mk_rect(_boss_bar, Vector2.ZERO, Vector2(480, 60), Color(0.02, 0.02, 0.03, 0.72))
		_mk_rect(_boss_bar, Vector2(4, 4), Vector2(472, 52), Color(0.10, 0.05, 0.06, 0.85))
		var name_l := _mk_label(_boss_bar, boss_name, 22, Color(1.0, 0.80, 0.35))
		name_l.position = Vector2(18, 8)
		_mk_rect(_boss_bar, Vector2(18, 38), Vector2(444, 12), Color(0.28, 0.10, 0.10, 0.9))
		_boss_fill = _mk_rect(_boss_bar, Vector2(18, 38), Vector2(444, 12), Color(0.90, 0.22, 0.12, 0.95))
		var sfx := get_tree().get_first_node_in_group("sfx_bank")
		if sfx:
			sfx.set_boss_music(true)
	_boss_fill.size.x = 444.0 * clampf(ratio, 0.0, 1.0)


func hide_boss_bar() -> void:
	if _boss_bar:
		_boss_bar.queue_free()
		_boss_bar = null
		_boss_fill = null
		var sfx := get_tree().get_first_node_in_group("sfx_bank")
		if sfx:
			sfx.set_boss_music(false)



# 完美闪避触发的慢动作：全屏蓝色渐晕，结束即撤。
func set_flurry_overlay(on: bool) -> void:
	if on:
		if _flurry_overlay == null:
			_flurry_overlay = ColorRect.new()
			_flurry_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
			var sm := ShaderMaterial.new()
			sm.shader = load("res://assets/shaders/flurry.gdshader")
			_flurry_overlay.material = sm
			_flurry_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_ui.add_child(_flurry_overlay)
		_flurry_overlay.visible = true
	elif _flurry_overlay:
		_flurry_overlay.visible = false


# ---------- 地图选择 ----------

func show_map_selector(current_map: String) -> void:
	if _map_panel:
		return
	_map_panel = Control.new()
	_map_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui.add_child(_map_panel)
	_mk_rect(_map_panel, Vector2.ZERO, Vector2(4000, 4000), Color(0.015, 0.035, 0.05, 0.96))
	var title := _mk_label(_map_panel, "选 择 地 图", 42, Color(1.0, 0.88, 0.46))
	title.position = Vector2(490, 70)
	title.size.x = 300
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_build_map_card(_map_panel, Vector2(145, 175), "1", "群岛战场", "500m 海岛 · 24 人战术吃鸡\n村庄、据点、载具、四季毒圈", current_map == "battlefield", Color(0.24, 0.49, 0.65))
	_build_map_card(_map_panel, Vector2(685, 175), "2", "海拉鲁阔野", "旷野之息风格 · 高原河谷\n神庙、驿站、骑乘、生态与巨龙", current_map == "wild", Color(0.28, 0.58, 0.32))
	var hint := _mk_label(_map_panel, "按 1 / 2 进入地图    M 返回当前地图", 19, Color(0.76, 0.91, 0.88))
	hint.position = Vector2(420, 640)
	hint.size.x = 440
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ignore_mouse(_map_panel)


func _build_map_card(parent: Control, pos: Vector2, number: String, map_name: String, description: String, active: bool, color: Color) -> void:
	var card := Control.new()
	card.position = pos
	card.size = Vector2(450, 330)
	parent.add_child(card)
	_mk_rect(card, Vector2.ZERO, card.size, Color(color.r * 0.22, color.g * 0.22, color.b * 0.22, 0.96))
	_mk_rect(card, Vector2(8, 8), Vector2(434, 314), Color(color.r, color.g, color.b, 0.48 if active else 0.28))
	# 程序化缩略景观：天空、山、河和地标剪影。
	_mk_rect(card, Vector2(20, 20), Vector2(410, 142), Color(0.32, 0.65, 0.87))
	_mk_rect(card, Vector2(20, 125), Vector2(410, 37), Color(0.17, 0.50, 0.65) if map_name == "群岛战场" else Color(0.16, 0.66, 0.67))
	for i in range(5):
		var mountain := Polygon2D.new()
		var base_x := 22.0 + i * 82.0
		var peak_y := 48.0 + (i % 3) * 15.0
		mountain.polygon = PackedVector2Array([Vector2(base_x, 142), Vector2(base_x + 55, peak_y), Vector2(base_x + 105, 142)])
		mountain.color = Color(0.24 + i * 0.025, 0.43 + i * 0.025, 0.18)
		card.add_child(mountain)
	# 远景塔/神庙剪影让两张卡片不只是抽象色块。
	_mk_rect(card, Vector2(318, 78), Vector2(18, 64), Color(0.18, 0.27, 0.23))
	_mk_rect(card, Vector2(303, 76), Vector2(48, 9), Color(0.18, 0.27, 0.23))
	var badge := _mk_label(card, number, 34, Color(1.0, 0.88, 0.35))
	badge.position = Vector2(30, 174)
	var name_label := _mk_label(card, map_name + ("  · 当前" if active else ""), 28, Color.WHITE)
	name_label.position = Vector2(88, 178)
	var desc := _mk_label(card, description, 18, Color(0.90, 0.94, 0.87))
	desc.position = Vector2(30, 232)
	desc.size = Vector2(390, 80)


func hide_map_selector() -> void:
	if _map_panel:
		_map_panel.queue_free()
		_map_panel = null
