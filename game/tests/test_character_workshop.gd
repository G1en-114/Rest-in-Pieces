extends SceneTree


class FakeModels extends Node:
	var applied_to := ""
	var cleared := ""

	func set_model(target: String, _data: PackedByteArray) -> String:
		applied_to = target
		return ""

	func clear_model(target: String) -> void:
		cleared = target


class FakeClient extends Node:
	signal progress(message: String)
	signal task_created(task_id: String, stage: String)
	signal finished
	var calls := 0
	var cancelled := false
	var last_id := ""
	var last_stage := ""
	var response: Dictionary = {"ok": true, "data": PackedByteArray([1])}

	func generate(_path: String, _key: String, _region: String, _id: String, _stage: String) -> Dictionary:
		calls += 1
		last_id = _id
		last_stage = _stage
		await finished
		return response

	func cancel() -> void:
		cancelled = true
		response = {"ok": false, "error": "已停止本地等待；远端任务仍在运行。"}
		finished.emit()


class TestWorkshop extends "res://scripts/character_workshop.gd":
	var models := FakeModels.new()

	func _characters() -> Node:
		return models

	func _task_file() -> String:
		return "user://test-character-tasks-%d.cfg" % OS.get_process_id()

	func _exit_tree() -> void:
		models.free()
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_task_file()))


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if not FileAccess.file_exists("res://scripts/character_workshop.gd"):
		push_error("Character workshop is missing")
		quit(1)
		return
	var workshop := TestWorkshop.new()
	root.add_child(workshop)
	workshop.open()
	await process_frame
	assert(workshop.visible, "Open must show the persistent workshop")
	assert(workshop._key.secret, "API key must be masked")
	# Load the menu after autoload initialization (its Level/Main dependencies use autoloads).
	var menu_script = load("res://scripts/menu.gd")
	var menu = menu_script.new()
	root.add_child(menu)
	menu.show_modes()
	await process_frame
	var customize_calls := [0]
	menu.customize.connect(func(): customize_calls[0] += 1)
	var shortcut := InputEventKey.new()
	shortcut.pressed = true
	shortcut.physical_keycode = KEY_C
	menu._unhandled_key_input(shortcut)
	assert(customize_calls[0] == 0, "Menu shortcuts must not fire behind the workshop")
	menu.close()
	workshop.open()
	await process_frame
	shortcut.keycode = KEY_C
	shortcut.unicode = 99
	Input.parse_input_event(shortcut)
	await process_frame
	assert(workshop._key.text == "c", "Typing C in the masked key field must edit text")
	assert(customize_calls[0] == 0, "Typing a key must not trigger menu navigation")
	var released := shortcut.duplicate() as InputEventKey
	released.pressed = false
	Input.parse_input_event(released)
	workshop._key.clear()
	if "--screenshot" in OS.get_cmdline_user_args():
		await process_frame
		await RenderingServer.frame_post_draw
		var screenshot := OS.get_environment("TEMP").path_join("codex-character-workshop.png")
		root.get_texture().get_image().save_png(screenshot)
		print("SCREENSHOT: ", screenshot)
	workshop._tasks = {"player1": {"id": "test-resume", "stage": "rig", "region": "cn"}}
	workshop._target.select(1)
	workshop._target_changed(1)
	assert(workshop._tasks.has("player1"), "Changing target must preserve saved task")
	workshop._close()
	assert(not workshop.visible and not workshop.is_queued_for_deletion(), "Close hides, never frees")
	menu.show_modes()
	await process_frame
	menu._unhandled_key_input(shortcut)
	assert(customize_calls[0] == 1, "Title menu C must emit customize")
	menu.queue_free()
	workshop.open()
	await process_frame
	assert(workshop._tasks.player1.stage == "rig", "Reopening preserves task stage")
	workshop._tasks.clear()
	workshop._client.queue_free()
	var client := FakeClient.new()
	workshop.add_child(client)
	workshop._client = client
	client.progress.connect(workshop._on_progress)
	client.task_created.connect(workshop._on_task_created)
	workshop._target.select(0)
	workshop._key.text = "test-memory-only"
	workshop._photo_path = "fixture.png"
	workshop._start_generation(false)
	assert(workshop.busy)
	workshop._start_generation(false)
	assert(client.calls == 1, "Duplicate submission must not start another paid task")
	workshop._target.select(1)
	workshop._target_changed(1)
	client.task_created.emit("saved-task", "rig")
	assert(workshop._tasks.player1.id == "saved-task", "Task references belong to the frozen target")
	workshop._close()
	assert(workshop.busy, "Returning to menu must keep generation active")
	client.finished.emit()
	await process_frame
	assert(workshop.models.applied_to == "player1", "Completion must use the frozen target")
	assert(not workshop.busy)
	workshop.open()
	workshop._start_generation(false)
	client.task_created.emit("cancelled-task", "generate")
	workshop._cancel_wait()
	await process_frame
	assert(client.cancelled and not workshop.busy)
	assert(workshop._tasks.player2.id == "cancelled-task", "Local cancellation must preserve the remote resume task")
	workshop._reset_model()
	assert(workshop.models.cleared == "player2")
	assert(workshop._tasks.has("player2"), "Reset appearance must not erase an active remote task")
	workshop._confirm_forget_task()
	assert(workshop._tasks.has("player2"), "Opening confirmation must preserve the task")
	workshop._forget_dialog.hide()
	workshop._forget_task()
	assert(not workshop._tasks.has("player2") and not workshop._generate.disabled, "Confirmed forget allows a new task")
	client.response = {"ok": false, "error": "创建响应丢失"}
	workshop._start_generation(false)
	client.task_created.emit("", "generate_pending")
	client.finished.emit()
	await process_frame
	assert(workshop._tasks.get("player2", {}).get("stage") == "generate_pending", "Unknown create response must retain pending state even with no task ID")
	workshop._tasks.clear()
	workshop._load_tasks()
	workshop._refresh()
	assert(workshop._tasks.player2.stage == "generate_pending", "Pending state must survive saved-task reload")
	assert(workshop._resume.disabled and workshop._generate.disabled, "Pending creation cannot be automatically resubmitted")
	var calls_before_recovery := client.calls
	workshop._start_generation(true)
	assert(client.calls == calls_before_recovery, "Resume must not create another paid task after a lost response")
	workshop._manual_task_id.text = "123456"
	workshop._recover_task_id()
	assert(workshop._tasks.player2.stage == "generate" and not workshop._resume.disabled)
	workshop._start_generation(true)
	assert(client.last_id == "123456" and client.last_stage == "generate", "Manual generation ID recovery resumes polling")
	client.task_created.emit("123456", "rig_pending")
	client.finished.emit()
	await process_frame
	workshop._tasks.clear()
	workshop._load_tasks()
	workshop._refresh()
	assert(workshop._tasks.player2.stage == "rig_pending" and workshop._resume.disabled, "Lost rig response must persist and block another rig create")
	workshop._manual_task_id.text = "invalid"
	workshop._recover_task_id()
	assert(workshop._tasks.player2.stage == "rig_pending", "Recovery requires an actual numeric platform task ID")
	workshop._manual_task_id.text = "654321"
	workshop._recover_task_id()
	assert(workshop._tasks.player2.stage == "rig")
	workshop._start_generation(true)
	assert(client.last_id == "654321" and client.last_stage == "rig", "Manual rig ID recovery resumes rig polling without creating another task")
	client.response = {"ok": true, "data": PackedByteArray([1])}
	client.finished.emit()
	await process_frame
	# A task the platform marked failed is final: drop it so a new photo can be submitted.
	workshop._start_generation(false)
	client.task_created.emit("rejected-rig", "rig")
	client.response = {"ok": false, "error": "平台任务失败。（MODEL_NOT_RIGGABLE）双臂弯曲", "final": true}
	client.finished.emit()
	await process_frame
	assert(not workshop._tasks.has("player2") and not workshop._generate.disabled, "Final platform failure clears the task record")
	assert("MODEL_NOT_RIGGABLE" in workshop._status.text, "Platform reason is shown to the player")
	workshop.queue_free()
	await process_frame
	print("PASS: menu modal shortcut, workshop masking, resume, persistence, duplicate guard, frozen target, cancel, reset, confirmed forget and final failure")
	quit(0)
