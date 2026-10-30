class_name CharacterWorkshop
extends Control
## Persistent native overlay. Keys/photos stay in memory; only remote task references are saved.

signal closed

const TARGETS := ["player1", "player2", "corpse"]
const TASK_FILE := "user://character_tasks.cfg"
const GOLD := Color(0.95, 0.74, 0.25)
const MUTED := Color(0.77, 0.75, 0.72)
const HAND_FONT := preload("res://assets/fonts/ZCOOLKuaiLe-Regular.ttf")
const MAX_MODEL_BYTES := 32 * 1024 * 1024

var busy := false
var _client: Node
var _tasks: Dictionary = {}
var _active_target := ""
var _active_region := "cn"
var _photo_path := ""
var _target: OptionButton
var _region: OptionButton
var _key: LineEdit
var _preview: TextureRect
var _photo_label: Label
var _status: Label
var _saved: Label
var _recovery: HBoxContainer
var _manual_task_id: LineEdit
var _generate: Button
var _resume: Button
var _cancel: Button
var _reset: Button
var _import: Button
var _choose: Button
var _forget: Button
var _forget_dialog: ConfirmationDialog
var _forget_target := ""
var _progress: ProgressBar
var _photo_picker: FileDialog
var _model_picker: FileDialog


func _ready() -> void:
	add_to_group("character_workshop")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_client = load("res://scripts/lux3d_client.gd").new()
	add_child(_client)
	_client.progress.connect(_on_progress)
	_client.task_created.connect(_on_task_created)
	_load_tasks()
	_build()
	_target_changed(0)
	hide()


func open() -> void:
	show()
	_refresh()
	_key.grab_focus.call_deferred()


func _close() -> void:
	hide()
	closed.emit()


func _input(event: InputEvent) -> void:
	if not visible or not event is InputEventKey or not event.pressed:
		return
	if _photo_picker.visible or _model_picker.visible or _forget_dialog.visible:
		return
	# Consume menu letter shortcuts before unhandled input; LineEdit owns typed text.
	var focus := get_viewport().gui_get_focus_owner()
	if focus is LineEdit:
		return
	if event.physical_keycode == KEY_ESCAPE:
		_close()
		get_viewport().set_input_as_handled()
	elif event.physical_keycode >= KEY_A and event.physical_keycode <= KEY_Z:
		get_viewport().set_input_as_handled()


func _unhandled_key_input(event: InputEvent) -> void:
	if not visible or not event is InputEventKey:
		return
	if event.pressed and event.physical_keycode == KEY_ESCAPE:
		_close()
	get_viewport().set_input_as_handled()


func _build() -> void:
	var shade := ColorRect.new()
	shade.color = Color(0.025, 0.02, 0.035, 0.94)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 32)
	add_child(margin)
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.065, 0.055, 0.075)
	style.border_color = GOLD
	style.set_border_width_all(2)
	style.set_corner_radius_all(14)
	style.set_content_margin_all(24)
	panel.add_theme_stylebox_override("panel", style)
	margin.add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 12)
	scroll.add_child(box)
	var heading := HBoxContainer.new()
	box.add_child(heading)
	var title := _label("自定义角色", heading, 38, GOLD)
	title.add_theme_font_override("font", HAND_FONT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_button("返回菜单  Esc", heading, _close)
	_label("把自己的照片变成抬棺人，或送别的主角。生成中可返回菜单，任务会继续。", box, 22)
	_label("联机时，两台电脑各自的“玩家一”代表自己；逝者外观使用房主的选择。", box, 18, MUTED)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	box.add_child(row)
	_label("应用到", row)
	_target = OptionButton.new()
	for text in ["玩家一", "玩家二", "逝者"]:
		_target.add_item(text)
	_target.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_target.item_selected.connect(_target_changed)
	row.add_child(_target)
	_region = OptionButton.new()
	_region.add_item("国内官方 API · cn")
	_region.add_item("国际官方 API · com")
	row.add_child(_region)
	var photo_row := HBoxContainer.new()
	photo_row.add_theme_constant_override("separation", 20)
	box.add_child(photo_row)
	_preview = TextureRect.new()
	_preview.custom_minimum_size = Vector2(180, 180)
	_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	photo_row.add_child(_preview)
	var photo_box := VBoxContainer.new()
	photo_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	photo_box.add_theme_constant_override("separation", 10)
	photo_row.add_child(photo_box)
	_choose = _button("选择照片 · PNG / JPEG", photo_box, func(): _photo_picker.popup_centered_ratio(0.8))
	_photo_label = _label("尚未选择照片", photo_box)
	_label("单人、正面、全身照最佳，双臂展开为 T / A 字姿势。", photo_box, 20, MUTED)
	_label("照片会上传到所选平台用于生成；游戏不保存照片。", photo_box, 20, MUTED)
	_label("你的 AHOLO API Key", box)
	_key = LineEdit.new()
	_key.secret = true
	_key.placeholder_text = "输入平台提供的完整密钥（仅本次运行保留）"
	_key.add_theme_font_size_override("font_size", 22)
	box.add_child(_key)
	_label("密钥只保留在本机内存中，不写入存档、不发给队友。", box, 18, MUTED)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 12)
	box.add_child(actions)
	_generate = _button("生成并自动绑骨（使用你的平台额度）", actions, _start_generation.bind(false))
	_generate.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_resume = _button("继续查询已有任务", actions, _start_generation.bind(true))
	_cancel = _button("停止本地等待", actions, _cancel_wait)
	_saved = _label("", box, 18, MUTED)
	_recovery = HBoxContainer.new()
	_recovery.add_theme_constant_override("separation", 12)
	box.add_child(_recovery)
	_manual_task_id = LineEdit.new()
	_manual_task_id.placeholder_text = "从平台任务记录复制实际任务号"
	_manual_task_id.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_manual_task_id.add_theme_font_size_override("font_size", 22)
	_recovery.add_child(_manual_task_id)
	_button("使用平台任务号", _recovery, _recover_task_id)
	_progress = ProgressBar.new()
	_progress.indeterminate = true
	_progress.show_percentage = false
	_progress.custom_minimum_size.y = 8
	box.add_child(_progress)
	_status = _label("选择照片和目标，输入密钥后开始。生成通常需要数分钟。", box, 21)
	_label("停止等待不会取消远端任务，平台仍可能扣除额度；请用“继续查询”避免重复创建。", box, 18, MUTED)
	var local_row := HBoxContainer.new()
	local_row.add_theme_constant_override("separation", 12)
	box.add_child(local_row)
	_import = _button("导入已有 GLB", local_row, func(): _model_picker.popup_centered_ratio(0.8))
	_reset = _button("恢复此目标的默认外观", local_row, _reset_model)
	_forget = _button("放弃此任务，重新生成…", local_row, _confirm_forget_task)
	_label("GLB 需具备可适配的人形骨架；验证失败会保留原外观。", box, 18, MUTED)
	_photo_picker = _picker(["*.png ; PNG 图片", "*.jpg, *.jpeg ; JPEG 图片"])
	_photo_picker.file_selected.connect(_select_photo)
	_model_picker = _picker(["*.glb ; GLB 人形模型"])
	_model_picker.file_selected.connect(_import_model)
	_forget_dialog = ConfirmationDialog.new()
	_forget_dialog.title = "放弃本地任务记录？"
	_forget_dialog.dialog_text = "这只会移除本地的任务号，不会取消远端任务或退还额度。\n原任务仍可能运行和计费；再次生成是新的付费任务。\n确认后你可以选择新照片，再点击生成按钮。"
	_forget_dialog.ok_button_text = "移除记录，允许重新生成"
	_forget_dialog.cancel_button_text = "保留任务"
	_forget_dialog.confirmed.connect(_forget_task)
	add_child(_forget_dialog)


func _label(text: String, parent: Control, size := 22, color := Color.WHITE) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label


func _button(text: String, parent: Control, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.add_theme_font_size_override("font_size", 22)
	button.custom_minimum_size.y = 44
	button.pressed.connect(action)
	parent.add_child(button)
	return button


func _picker(filters: Array[String]) -> FileDialog:
	var picker := FileDialog.new()
	picker.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	picker.access = FileDialog.ACCESS_FILESYSTEM
	picker.use_native_dialog = true
	picker.filters = PackedStringArray(filters)
	add_child(picker)
	return picker


func _selected_target() -> String:
	return TARGETS[_target.selected]


func _target_changed(_index: int) -> void:
	_manual_task_id.clear()
	_refresh()
	if not busy:
		_status.text = "已选择%s。生成通常需要数分钟，可随时返回菜单。" % _target.get_item_text(_target.selected)


func _refresh() -> void:
	var record: Dictionary = _tasks.get(_selected_target(), {})
	var pending := str(record.get("stage", "")).ends_with("_pending")
	_generate.disabled = busy or not record.is_empty()
	_resume.disabled = busy or record.is_empty() or pending
	_forget.disabled = busy or record.is_empty()
	_cancel.disabled = not busy
	for control in [_target, _region, _choose, _import, _reset]:
		control.disabled = busy
	_key.editable = not busy
	_progress.visible = busy
	_recovery.visible = pending and not busy
	if pending:
		_saved.text = "%s请求的提交结果待核对。请先在平台任务记录中找到实际任务号，再填入下方。" % ("绑骨" if record.get("stage") == "rig_pending" else "生成")
	else:
		_saved.text = "已有%s任务 · %s · %s，可继续查询。" % ["绑骨" if record.get("stage") == "rig" else "生成", record.get("region", "cn"), record.get("id", "")] if not record.is_empty() else ""
	if not busy and not record.is_empty():
		_region.select(1 if record.get("region", "cn") == "com" else 0)


func _select_photo(path: String) -> void:
	if busy:
		return
	if not path.get_extension().to_lower() in ["png", "jpg", "jpeg"]:
		_status.text = "请选择 PNG 或 JPEG 图片。"
		return
	# Share the client's bounded PNG/JPEG decoder: inspect dimensions before allocating pixels.
	var photo: Dictionary = _client._load_photo(path)
	if not photo.get("ok", false):
		_status.text = str(photo.get("error", "无法读取照片。"))
		return
	var image: Image = photo.image
	# The upload uses the original; only the in-memory preview is reduced.
	if maxi(image.get_width(), image.get_height()) > 512:
		var scale_factor := 512.0 / maxi(image.get_width(), image.get_height())
		image.resize(maxi(1, roundi(image.get_width() * scale_factor)), maxi(1, roundi(image.get_height() * scale_factor)))
	_photo_path = path
	_preview.texture = ImageTexture.create_from_image(image)
	_photo_label.text = path.get_file()
	_status.text = "照片已选择，输入密钥后生成。"


func _start_generation(resume: bool) -> void:
	if busy:
		return
	var api_key := _key.text.strip_edges()
	if api_key.is_empty():
		_status.text = "请先输入你的 AHOLO API Key。"
		_key.grab_focus()
		return
	var target := _selected_target()
	var record: Dictionary = _tasks.get(target, {})
	if resume and record.is_empty():
		_status.text = "此目标没有可继续查询的任务。"
		return
	if resume and str(record.get("stage", "")).ends_with("_pending"):
		_status.text = "创建结果尚未确认，请先核对平台任务记录并填写实际任务号。"
		return
	if not resume and not record.is_empty():
		_status.text = "此目标已有远端任务，请继续查询，避免重复扣费。"
		return
	if not resume and _photo_path.is_empty():
		_status.text = "请先选择一张 PNG / JPEG 全身照。"
		return
	# Capture all task inputs before awaiting. A changed selection can never redirect a result.
	_active_target = target
	_active_region = str(record.get("region", "cn")) if resume else ("cn" if _region.selected == 0 else "com")
	busy = true
	_refresh()
	_status.text = "正在继续查询已有任务…" if resume else "正在上传并创建生成任务…"
	var result: Dictionary = await _client.generate(_photo_path, api_key, _active_region, str(record.get("id", "")) if resume else "", str(record.get("stage", "generate")))
	api_key = ""
	busy = false
	if result.get("ok", false):
		var error: String = _characters().set_model(target, result.get("data", PackedByteArray()))
		if error.is_empty():
			_tasks.erase(target)
			_save_tasks()
			_status.text = "%s的角色已应用并保存。" % _target_name(target)
		else:
			_status.text = "模型验证失败，保留原外观：" + error
	else:
		_status.text = str(result.get("error", "生成失败，请稍后继续查询。"))
		if result.get("final", false):
			_tasks.erase(target)
			_save_tasks()
	_active_target = ""
	_refresh()


func _on_progress(message: String) -> void:
	_status.text = message


func _on_task_created(task_id: String, stage: String) -> void:
	if _active_target.is_empty() or stage not in ["generate", "rig", "generate_pending", "rig_pending"]:
		return
	if task_id.is_empty() and stage != "generate_pending":
		return
	_tasks[_active_target] = {"id": task_id, "stage": stage, "region": _active_region}
	_save_tasks()
	_refresh()


func _recover_task_id() -> void:
	if busy:
		return
	var target := _selected_target()
	var record: Dictionary = _tasks.get(target, {})
	var stage := str(record.get("stage", ""))
	if stage not in ["generate_pending", "rig_pending"]:
		return
	var task_id := _manual_task_id.text.strip_edges()
	if not task_id.is_valid_int() or task_id.begins_with("-") or task_id.length() > 32:
		_status.text = "请输入平台任务记录中的数字任务号。"
		return
	record.id = task_id
	record.stage = stage.trim_suffix("_pending")
	_tasks[target] = record
	_save_tasks()
	_manual_task_id.clear()
	_status.text = "任务号已更新，可继续查询已有任务。"
	_refresh()


func _cancel_wait() -> void:
	if busy:
		_client.cancel()
		_status.text = "已停止本地等待；远端任务仍可能运行和计费，可稍后继续查询。"


func _reset_model() -> void:
	if busy:
		return
	_characters().clear_model(_selected_target())
	_status.text = "已恢复%s的默认外观；已有远端任务仍可继续查询。" % _target_name(_selected_target())


func _confirm_forget_task() -> void:
	if busy or not _tasks.has(_selected_target()):
		return
	_forget_target = _selected_target()
	_forget_dialog.popup_centered()


func _forget_task() -> void:
	if busy or _forget_target.is_empty():
		return
	_tasks.erase(_forget_target)
	_save_tasks()
	_forget_target = ""
	_status.text = "已移除本地任务记录。远端任务不受影响；再次生成将使用新的平台额度。"
	_refresh()


func _import_model(path: String) -> void:
	if busy:
		return
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > MAX_MODEL_BYTES or path.get_extension().to_lower() != "glb":
		_status.text = "无法读取 GLB，或文件超过 32 MiB。"
		return
	var error: String = _characters().set_model(_selected_target(), file.get_buffer(file.get_length()))
	_status.text = "模型已应用并保存。" if error.is_empty() else "导入失败，保留原外观：" + error


func _characters() -> Node:
	return get_node("/root/Characters")


func _target_name(target: String) -> String:
	return {"player1": "玩家一", "player2": "玩家二", "corpse": "逝者"}.get(target, target)


func _load_tasks() -> void:
	var config := ConfigFile.new()
	if config.load(_task_file()) != OK:
		return
	for target in TARGETS:
		var task_id: String = config.get_value(target, "id", "")
		var stage: String = config.get_value(target, "stage", "generate")
		var region: String = config.get_value(target, "region", "cn")
		if (not task_id.is_empty() or stage == "generate_pending") and stage in ["generate", "rig", "generate_pending", "rig_pending"] and region in ["cn", "com"]:
			_tasks[target] = {"id": task_id, "stage": stage, "region": region}


func _save_tasks() -> void:
	var config := ConfigFile.new()
	for target in _tasks:
		var record: Dictionary = _tasks[target]
		for field in ["id", "stage", "region"]:
			config.set_value(target, field, record[field])
	if config.save(_task_file()) != OK:
		_client.cancel()
		_status.text = "无法保存任务恢复记录，已停止本地请求。请检查存储空间和权限。"


func _task_file() -> String:
	return TASK_FILE
