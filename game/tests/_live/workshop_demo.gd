extends SceneTree
## Promo recording only: drives the real workshop UI on a timeline (photo → masked key → progress → apply).
## Env: DEMO_PHOTO, DEMO_GLB, DEMO_TARGET (index 0/1/2). The progress messages are the client's own strings.

var _t := 0.0
var _w: Node
var _step := 0


func _initialize() -> void:
	change_scene_to_file("res://scenes/main.tscn")


func _process(delta: float) -> bool:
	_t += delta
	if _w == null:
		_w = get_first_node_in_group("character_workshop")
		return false
	var steps := [
		[0.6, func() -> void:
			_w._target.select(int(OS.get_environment("DEMO_TARGET")))
			_w._target_changed(0)],
		[1.4, func() -> void: _w._select_photo(OS.get_environment("DEMO_PHOTO"))],
		[2.4, func() -> void: _w._key.text = "ak-"],
		[2.6, func() -> void: _w._key.text = "ak-7f3e"],
		[2.8, func() -> void: _w._key.text = "ak-7f3e91c0"],
		[3.0, func() -> void: _w._key.text = "ak-7f3e91c0b2d4a8"],
		[3.6, func() -> void:
			_w.busy = true
			_w._refresh()
			_w._status.text = "正在上传并创建生成任务…"],
		[4.4, func() -> void: _w._status.text = "上传照片…"],
		[5.2, func() -> void: _w._status.text = "等待生成模型…"],
		[6.4, func() -> void: _w._status.text = "创建人形绑骨任务…"],
		[7.0, func() -> void: _w._status.text = "等待人形自动绑骨…"],
		[8.2, func() -> void: _w._status.text = "下载绑骨模型…"],
		[8.8, func() -> void:
			_w.busy = false
			var data := FileAccess.get_file_as_bytes(OS.get_environment("DEMO_GLB"))
			var err: String = _w._characters().set_model(_w._selected_target(), data)
			_w._refresh()
			_w._status.text = (_w._target_name(_w._selected_target()) + "的角色已应用并保存。") if err.is_empty() else err
			print("DEMO_APPLY ", err)],
	]
	while _step < steps.size() and _t >= steps[_step][0]:
		steps[_step][1].call()
		_step += 1
	return false
