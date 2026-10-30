class_name Menu
extends Control
## 开局菜单和结算面板：选模式 → 选关 → 选房间；联机加入时输入 IP；送达后的结算。
## 按钮可以用鼠标点、方向键 + Enter 选，也能直接按按钮前面标的键。
## 菜单自己管翻页，选好以后发 start / join 信号，由 main.gd 去重载场景。

signal start(mode: String, role: String, level_id: String, room: int, resume: bool)
signal join(ip: String)
signal customize
signal result_key(key: String)  # 结算面板上按了 "R" / "N" / "M"

var _panel: PanelContainer
var _box: VBoxContainer
var _keys := {}  # 当前页面的快捷键 → Callable
var _back := Callable()  # 当前页面按 Esc 做什么
var _mode := ""
var _role := ""
var _title: Control  # 开始界面：左边手写的游戏名和一列白字按钮，右边是近景的抬棺队伍
var _title_chars: Array[Label] = []  # 游戏名一个字一个 Label，各歪各的、各晃各的
var _title_buttons: VBoxContainer
var _title_note: Label
var _title_t := 0.0
const HAND_FONT := preload("res://assets/fonts/ZCOOLKuaiLe-Regular.ttf")  # 站酷快乐体（OFL）


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_panel = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.05, 0.07, 0.86)
	sb.border_color = Color(0.95, 0.74, 0.25, 0.8)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(14)
	sb.set_content_margin_all(28)
	_panel.add_theme_stylebox_override("panel", sb)
	center.add_child(_panel)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 10)
	_box.custom_minimum_size = Vector2(620, 0)
	_panel.add_child(_box)
	_build_title()
	visible = false


func _process(delta: float) -> void:
	if not showing_title():
		return
	# 字各自慢慢晃，像没摆正的招牌
	_title_t += delta
	for i in _title_chars.size():
		var l := _title_chars[i]
		l.pivot_offset = l.size / 2
		l.rotation = l.get_meta("tilt") + sin(_title_t * 1.3 + i * 1.9) * 0.03
		l.position.y = sin(_title_t * 1.7 + i * 2.3) * 4.0
	for b: Button in _title_buttons.get_children():
		var on := b.has_focus() or b.is_hovered()
		var s := lerpf(b.scale.x, 1.1 if on else 1.0, 1.0 - exp(-delta * 14.0))
		b.pivot_offset = Vector2(0, b.size.y / 2)
		b.scale = Vector2(s, s)
		b.rotation = lerpf(b.rotation, -0.03 if on else 0.0, 1.0 - exp(-delta * 14.0))



func _unhandled_key_input(event: InputEvent) -> void:
	if not visible or not (event is InputEventKey and event.pressed and not event.echo):
		return
	var workshop := get_tree().get_first_node_in_group("character_workshop") as Control
	if workshop != null and workshop.visible:
		return
	var key: Key = event.physical_keycode
	# 小键盘数字当成主键盘数字
	if key >= KEY_KP_0 and key <= KEY_KP_9:
		key = KEY_0 + (key - KEY_KP_0) as Key
	if _keys.has(key):
		get_viewport().set_input_as_handled()
		_keys[key].call()
	elif key == KEY_ESCAPE and _back.is_valid():
		get_viewport().set_input_as_handled()
		_back.call()


# ---------- 各个页面 ----------

# ---------- 各个页面 ----------

func showing_title() -> bool:
	return visible and _title.visible


## 开始界面兼选模式
func show_modes(note := "") -> void:
	_page("", "")
	_panel.visible = false
	_title.visible = true
	for c in _title_buttons.get_children():
		_title_buttons.remove_child(c)
		c.queue_free()
	_title_button("1", "一个人抬", "电脑队友帮你", KEY_1, func(): _pick_mode("solo", ""))
	_title_button("2", "两个人抬", "共用一个键盘", KEY_2, func(): _pick_mode("duo", ""))
	_title_button("3", "建房间", "联机，你当房主", KEY_3, func(): _pick_mode("online", "host"))
	_title_button("4", "加入房间", "输入房间号", KEY_4, show_ip.bind(""))
	_title_button("C", "自定义角色", "照片变角色", KEY_C, customize.emit)
	_title_button("Q", "退出", "", KEY_Q, get_tree().quit)
	_title_note.text = note
	_title_note.visible = note != ""
	_back = Callable()
	_title_buttons.get_child(0).grab_focus.call_deferred()



func show_ip(ip: String) -> void:
	_page("加入房间", "输入房主屏幕上的 4 位房间号，按 Enter 加入\n同一局域网 / Radmin 也可以直接输入房主的 IP（Esc 返回）")
	var edit := LineEdit.new()
	edit.text = ip if ip else Save.last_ip("")
	edit.placeholder_text = "房间号 或 房主的 IP"
	edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	edit.add_theme_font_size_override("font_size", 30)
	_box.add_child(edit)
	edit.grab_focus()
	edit.select_all()
	edit.text_submitted.connect(func(text: String) -> void: join.emit(text.strip_edges()))
	_back = show_modes.bind("")


## 选关：每关一张卡片，写着国家、关名和最好评级
func show_levels(mode := "", role := "") -> void:
	if mode:
		_mode = mode
		_role = role
	_page("选　关", _mode_name())
	for i in Level.LEVELS.size():
		var l: Dictionary = Level.LEVELS[i]
		var ready := ResourceLoader.exists(l.script)
		var best := Save.best(l.id)
		var text := "%s · %s" % [l.country, l.title]
		text += ("　　最好评级 " + best) if best else ("" if ready else "　　（制作中）")
		var b := _button(str(i + 1), text, (KEY_1 + i) as Key, show_rooms.bind(l.id))
		b.disabled = not ready
	_back = show_modes.bind("")
	_focus_first()


## 选房间：默认“继续”上次的存档房间，也可以从头开始，或者直接挑任意一间
func show_rooms(level_id: String) -> void:
	var level := Level.create(level_id)
	if level == null:
		return
	var info := Level.info(level_id)
	_page("%s · %s" % [info.country, info.title], _mode_name())
	var cp := Save.checkpoint(level_id)
	if not cp.is_empty() and cp.room > 0 and cp.room < level.rooms.size():
		var sc: Dictionary = cp.score
		_button("Enter", "继续：第 %d 间「%s」　体面值 %d · 用时 %s" % [cp.room + 1, level.rooms[cp.room].name,
			roundi(sc.get("dignity", 100.0)), Score.clock(sc.get("elapsed", 0.0))], KEY_ENTER,
			func(): start.emit(_mode, _role, level_id, cp.room, true))
	_button("0", "从头开始", KEY_0, func(): start.emit(_mode, _role, level_id, 0, false))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 6)
	_box.add_child(grid)
	_text("从中间房间开始算「非完整通关」，不计最好评级", 18, Color(0.75, 0.72, 0.7))
	for i in level.rooms.size():
		var key: Key = (KEY_1 + i) as Key if i < 9 else KEY_NONE
		var b := _button(str(i + 1) if i < 9 else "", "第 %d 间 · %s" % [i + 1, level.rooms[i].name], key,
			func(): start.emit(_mode, _role, level_id, i, false), grid, 22)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	level.free()
	_back = show_levels
	_focus_first()


## 结算面板。improved：刷新了最好评级
func show_result(res: Dictionary, level_title: String, has_next: bool, improved: bool) -> void:
	_page("送达！", level_title)
	var grade := _text(res.grade, 96, _grade_color(res.grade))
	grade.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var t := _text("「%s」" % res.title, 34, Color(1.0, 0.9, 0.6))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 40)
	_box.add_child(grid)
	for l in res.lines:
		_text(l[0], 24, Color.WHITE, grid)
		var v := _text(("%+d" % l[1]) if l != res.lines[0] else str(int(l[1])), 24, Color.WHITE, grid)
		v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_text("合计", 28, Props.GOLD, grid)
	var tot := _text(str(int(res.total)), 28, Props.GOLD, grid)
	tot.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_text("用时 %s · %s" % [Score.clock(res.elapsed), res.get("stats", "")], 20, Color(0.8, 0.78, 0.75))
	_text(res.get("finds", ""), 20, Color(0.8, 0.78, 0.75))
	if not res.get("badges", []).is_empty():
		_text("奖章：" + "  ".join(res.badges.map(func(b: String) -> String: return "【%s】" % b)), 24, Color(1.0, 0.8, 0.4))
	if not res.full_run:
		_text("非完整通关（从中间房间开始），不计最好评级", 20, Color(1, 0.7, 0.5))
	elif improved:
		_text("新的最好评级！", 22, Color(1.0, 0.85, 0.3))
	_button("R", "再来一局", KEY_R, result_key.emit.bind("R"))
	if has_next:
		_button("N", "下一关", KEY_N, result_key.emit.bind("N"))
	_button("M", "回选关", KEY_M, result_key.emit.bind("M"))
	_back = Callable()
	_focus_first()


## 只显示一段话（比如加入方在等房主选关）
func show_text(title: String, text: String) -> void:
	_page(title, text)
	_back = Callable()


func close() -> void:
	visible = false
	_keys.clear()


# ---------- 小工具 ----------

func _pick_mode(mode: String, role: String) -> void:
	show_levels(mode, role)


func _mode_name() -> String:
	if _mode == "online":
		return "联机房主：你选的关，队友会自动跟进来"
	return {solo = "单人", duo = "双人"}.get(_mode, "")


func _build_title() -> void:
	_title = Control.new()
	_title.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title.visible = false
	add_child(_title)
	# 只在左边垫一层很淡的影子，白字压在亮背景上也看得清
	var grad := Gradient.new()
	grad.set_color(0, Color(0.05, 0.04, 0.08, 0.6))
	grad.set_color(1, Color(0.05, 0.04, 0.08, 0.0))
	grad.add_point(0.55, Color(0.05, 0.04, 0.08, 0.45))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill_to = Vector2(0.72, 0.0)
	var shade := TextureRect.new()
	shade.texture = tex
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title.add_child(shade)

	var col := VBoxContainer.new()
	col.position = Vector2(110, 70)
	col.add_theme_constant_override("separation", 0)
	_title.add_child(col)
	# 游戏名：每个字单独一个 Label，套在普通 Control 里，晃的时候不会被容器摆回去
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", -6)
	col.add_child(row)
	var tilts := [-0.07, 0.05, -0.03]
	var sizes := [176, 150, 164]
	for i in 3:
		var holder := Control.new()
		holder.custom_minimum_size = Vector2(sizes[i] * 0.98, 200)
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(holder)
		var l := _title_label("棺不住"[i], sizes[i], holder)
		l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		l.set_meta("tilt", tilts[i])
		_title_chars.append(l)
	var en := _title_label("Rest in Pieces", 56, col)
	en.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	en.rotation = -0.03
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 46)
	col.add_child(gap)
	_title_buttons = VBoxContainer.new()
	_title_buttons.add_theme_constant_override("separation", 4)
	col.add_child(_title_buttons)
	_title_note = _title_label("", 24, col, Color(1.0, 0.8, 0.6))
	_title_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_title_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title_note.custom_minimum_size = Vector2(620, 0)
	var foot := _title_label("2–4 人物理派对游戏 · 中国 · 埃及 · 墨西哥", 22, _title, Color(1, 1, 1, 0.75))
	foot.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	foot.position = Vector2(112, foot.position.y - 56)


func _title_label(s: String, size: int, parent: Control, color := Color.WHITE) -> Label:
	var l := Label.new()
	l.text = s
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", HAND_FONT)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", Color(0.08, 0.05, 0.1, 0.55))
	l.add_theme_constant_override("shadow_offset_x", maxi(2, size / 30))
	l.add_theme_constant_override("shadow_offset_y", maxi(3, size / 22))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


## 开始界面上的白字按钮：没有底板，选中时变黄、放大一点、歪一下
func _title_button(hint: String, text: String, sub: String, key: Key, action: Callable) -> void:
	var b := Button.new()
	b.flat = true
	b.text = "%s  %s" % [hint, text]
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_override("font", HAND_FONT)
	b.add_theme_font_size_override("font_size", 44)
	for state in ["font_color", "font_pressed_color"]:
		b.add_theme_color_override(state, Color.WHITE)
	for state in ["font_hover_color", "font_focus_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(state, Color(1.0, 0.86, 0.35))
	b.add_theme_color_override("font_outline_color", Color(0.08, 0.05, 0.1, 0.5))
	b.add_theme_constant_override("outline_size", 6)
	for style in ["normal", "hover", "pressed", "focus", "hover_pressed"]:
		b.add_theme_stylebox_override(style, StyleBoxEmpty.new())
	b.pressed.connect(action)
	b.mouse_entered.connect(b.grab_focus)
	_title_buttons.add_child(b)
	if sub:
		var s := _title_label(sub, 22, b, Color(1, 1, 1, 0.7))
		s.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		s.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
		s.position.x = b.get_theme_font("font").get_string_size(b.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 44).x + 22
	_keys[key] = action


func _page(title: String, subtitle: String) -> void:
	visible = true
	_panel.visible = true
	_title.visible = false
	_keys.clear()
	for c in _box.get_children():
		_box.remove_child(c)
		c.queue_free()
	if not title:
		return
	var t := _text(title, 52, Props.GOLD)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if subtitle:
		var s := _text(subtitle, 22, Color(0.85, 0.82, 0.78))
		s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		s.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func _text(s: String, size: int, color: Color, parent: Control = null) -> Label:
	var l := Label.new()
	l.text = s
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	(parent if parent else _box).add_child(l)
	return l


func _button(hint: String, text: String, key: Key, action: Callable, parent: Control = null, size := 26) -> Button:
	var b := Button.new()
	b.text = ("%s　%s" % [hint, text]) if hint else text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_size_override("font_size", size)
	b.pressed.connect(action)
	(parent if parent else _box).add_child(b)
	if key != KEY_NONE:
		_keys[key] = func() -> void:
			if not b.disabled:
				action.call()
	return b


func _focus_first() -> void:
	for b in _box.find_children("*", "Button", true, false):
		if not b.disabled and not b.is_queued_for_deletion():
			b.grab_focus.call_deferred()
			return


func _grade_color(g: String) -> Color:
	return {S = Color(1.0, 0.82, 0.25), A = Color(0.6, 0.9, 0.5), B = Color(0.5, 0.75, 1.0),
		C = Color(0.85, 0.75, 0.65)}.get(g, Color(0.75, 0.5, 0.5))
