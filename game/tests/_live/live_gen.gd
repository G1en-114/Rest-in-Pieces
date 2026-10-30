extends SceneTree
## Live (paid) run: LIVE_PHOTO, LIVE_OUT, AHOLO_API_KEY from env. Not part of the regular suite.

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var client := Lux3DClient.new()
	root.add_child(client)
	client.progress.connect(func(m: String) -> void: print("PROGRESS ", m))
	client.task_created.connect(func(id: String, st: String) -> void: print("TASK ", st, " ", id))
	var t0 := Time.get_ticks_msec()
	var r: Dictionary = await client.generate(OS.get_environment("LIVE_PHOTO"), OS.get_environment("AHOLO_API_KEY"), "cn",
		OS.get_environment("LIVE_RESUME"), OS.get_environment("LIVE_STAGE") if OS.get_environment("LIVE_STAGE") else "generate")
	print("ELAPSED ", (Time.get_ticks_msec() - t0) / 1000.0)
	if not r.get("ok", false):
		print("LIVE_FAIL ", r.get("error"))
		quit(1)
		return
	var data: PackedByteArray = r.data
	var f := FileAccess.open(OS.get_environment("LIVE_OUT"), FileAccess.WRITE)
	f.store_buffer(data)
	f.close()
	var cache: Node = root.get_node("Characters")
	var err: String = cache._prepare(data).get("error", "") if cache.has_method("_prepare") else ""
	print("LIVE_OK bytes=", data.size(), " validate_error=", err)
	quit(0)
