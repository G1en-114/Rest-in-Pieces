class_name Menu
extends Control
## 开局菜单和结算面板：选模式 → 选关 → 选房间；联机加入时输入 IP；送达后的结算。
## 按钮可以用鼠标点、方向键 + Enter 选，也能直接按按钮前面标的键。
## 菜单自己管翻页，选好以后发 start / join 信号，由 main.gd 去重载场景。

signal start(mode: String, role: String, level_id: String, room: int, resume: bool)
signal join(ip: String)
signal result_key(key: String)  # 结算面板上按了 "R" / "N" / "M"

var _panel: PanelContainer
var _box: VBoxContainer
var _keys := {}  # 当前页面的快捷键 → Callable
var _back := Callable()  # 当前页面按 Esc 做什么
var _mode := ""
var _role := ""


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
	visible = false


func _unhandled_key_input(event: InputEvent) -> void:
	if not visible or not (event is InputEventKey and event.pressed and not event.echo):
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

func show_modes(note := "") -> void:
	_page("抬　棺", "")
	_button("1", "单人（电脑队友帮你抬）", KEY_1, func(): _pick_mode("solo", ""))
	_button("2", "双人（两人共用键盘）", KEY_2, func(): _pick_mode("duo", ""))
	_button("3", "联机：建房间（你当房主）", KEY_3, func(): _pick_mode("online", "host"))
	_button("4", "联机：加入房间", KEY_4, show_ip.bind(""))
	if note:
		_text(note, 20, Color(1, 0.7, 0.5))
	_back = Callable()
	_focus_first()


func show_ip(ip: String) -> void:
	_page("加入房间", "输入房主的 IP，按 Enter 加入（Esc 返回）")
	var edit := LineEdit.new()
	edit.text = ip if ip else Save.last_ip(Main.join_ip)
	edit.placeholder_text = "房主的 IP"
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


func _page(title: String, subtitle: String) -> void:
	visible = true
	_keys.clear()
	for c in _box.get_children():
		_box.remove_child(c)
		c.queue_free()
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
