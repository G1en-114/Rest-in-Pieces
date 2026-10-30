class_name Lux3DClient
extends Node
## AHOLO Asset/OUS → Lux3D generation → humanoid rigging. Keys stay in memory.
## Endpoint/timeout overrides are for offline fixtures; the workshop only selects cn/com.

signal progress(message: String)
## Normal stages: generate, rig. Before each paid POST emit generate_pending (no ID)
## or rig_pending (generation ID). Persist pending metadata before returning from
## the signal handler; recovery requires the actual created task ID from the platform.
signal task_created(task_id: String, stage: String)

const MAX_MODEL_BYTES := 32 * 1024 * 1024
const MAX_PHOTO_BYTES := 16 * 1024 * 1024
const MAX_JSON_BYTES := 1024 * 1024
const BOUNDARY := "GodotAholoPhotoBoundary73c191"

var gateway_base := ""
var request_timeout_seconds := 60.0
var poll_timeout_seconds := 900.0
var poll_interval_seconds := 5.0
var _cancelled := false
var _busy := false


func cancel() -> void:
	# Never calls a remote cancellation endpoint: the paid task continues remotely.
	_cancelled = true


func generate(image_path: String, api_key: String, region := "cn", resume_id := "", resume_stage := "generate") -> Dictionary:
	if _busy:
		return _failure("已有任务正在等待，请先停止本地等待。")
	if resume_stage in ["generate_pending", "rig_pending"]:
		return _failure("创建结果尚未确认。请先检查平台任务记录，填写已创建任务的实际任务号及阶段后再查询，避免重复创建和扣费。")
	if api_key.strip_edges().is_empty() or "\n" in api_key or "\r" in api_key:
		return _failure("请输入有效的 AHOLO API Key。")
	if region not in ["cn", "com"] or resume_stage not in ["generate", "rig"]:
		return _failure("无效的区域或任务阶段。")
	_busy = true
	_cancelled = false
	var base := gateway_base.trim_suffix("/")
	if base.is_empty():
		base = "https://api.aholo.ai" if region == "com" else "https://api.aholo3d.cn"
	var prefix := "/global" if region == "com" else ""
	var headers := PackedStringArray(["Authorization: " + api_key.strip_edges()])
	var result := await _pipeline(image_path, base, prefix, headers, resume_id, resume_stage)
	# Release all key-bearing request headers when this invocation returns.
	headers.clear()
	_busy = false
	return result


func _pipeline(path: String, base: String, prefix: String, headers: PackedStringArray, resume_id: String, stage: String) -> Dictionary:
	var task_id := resume_id.strip_edges()
	if task_id.is_empty():
		progress.emit("检查照片…")
		var photo := _load_photo(path)
		if not photo.ok:
			return photo
		progress.emit("上传照片…")
		var uploaded := await _upload(photo.image, base + prefix + "/asset/v1/token", headers)
		if not uploaded.ok:
			return uploaded
		task_created.emit("", "generate_pending")
		var created := await _json(base + prefix + "/lux3d/v1/generate/img-to-3d/task/create", headers, HTTPClient.METHOD_POST,
			JSON.stringify({"img": uploaded.url, "version": "G1", "faceCount": 20000, "outputFormat": ["glb"]}).to_utf8_buffer())
		if not created.ok:
			return _uncertain_create(created)
		task_id = _task_id(created.value)
		if task_id.is_empty():
			return _failure("平台未返回有效任务号；请在平台任务记录中检查，避免重复创建。")
		stage = "generate"
	if not task_id.is_valid_int() or task_id.length() > 32:
		return _failure("任务号无效。")
	task_created.emit(task_id, stage)
	var polled := await _poll_task(base + prefix, headers, task_id, stage)
	if not polled.ok:
		return polled
	if stage == "generate":
		progress.emit("创建人形绑骨任务…")
		task_created.emit(task_id, "rig_pending")
		var rig := await _json(base + prefix + "/lux3d/v1/animations/rig/task/create", headers, HTTPClient.METHOD_POST,
			JSON.stringify({"modelUrl": polled.url}).to_utf8_buffer())
		if not rig.ok:
			return _uncertain_create(rig)
		task_id = _task_id(rig.value)
		if task_id.is_empty():
			return _failure("平台未返回绑骨任务号；请检查平台任务记录，避免重复创建。")
		task_created.emit(task_id, "rig")
		polled = await _poll_task(base + prefix, headers, task_id, "rig")
		if not polled.ok:
			return polled
	progress.emit("下载绑骨模型…")
	var downloaded := await _request(polled.url, PackedStringArray(), HTTPClient.METHOD_GET, PackedByteArray(), MAX_MODEL_BYTES)
	if not downloaded.ok:
		return downloaded
	var data: PackedByteArray = downloaded.data
	if data.size() < 12 or data.slice(0, 4).get_string_from_ascii() != "glTF" or data.decode_u32(4) != 2 or data.decode_u32(8) != data.size():
		return _failure("平台返回的文件不是有效的 GLB 2 模型。")
	return {"ok": true, "data": data}


func _load_photo(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() == 0 or file.get_length() > MAX_PHOTO_BYTES:
		return _failure("请选择不超过 16 MiB 的 PNG/JPEG 照片。")
	var data := file.get_buffer(file.get_length())
	file.close()
	var image := Image.new()
	var error := ERR_FILE_UNRECOGNIZED
	if data.size() >= 24 and data.slice(0, 8) == PackedByteArray([137, 80, 78, 71, 13, 10, 26, 10]):
		# Inspect PNG dimensions before allocating its decoded pixel buffer.
		var width := (int(data[16]) << 24) | (int(data[17]) << 16) | (int(data[18]) << 8) | int(data[19])
		var height := (int(data[20]) << 24) | (int(data[21]) << 16) | (int(data[22]) << 8) | int(data[23])
		if width <= 0 or height <= 0 or width * height > 40000000:
			return _failure("照片尺寸过大，请缩小后重试。")
		error = image.load_png_from_buffer(data)
	elif data.size() >= 3 and data[0] == 255 and data[1] == 216 and data[2] == 255:
		if not _jpeg_size_allowed(data):
			return _failure("JPEG 照片尺寸无效或过大。")
		error = image.load_jpg_from_buffer(data)
	if error != OK or image.is_empty():
		return _failure("无法读取照片，请选择有效的 PNG/JPEG 文件。")
	if maxi(image.get_width(), image.get_height()) > 2048:
		var scale := 2048.0 / maxi(image.get_width(), image.get_height())
		image.resize(maxi(1, roundi(image.get_width() * scale)), maxi(1, roundi(image.get_height() * scale)), Image.INTERPOLATE_LANCZOS)
	return {"ok": true, "image": image}


func _jpeg_size_allowed(data: PackedByteArray) -> bool:
	var offset := 2
	while offset + 8 < data.size():
		if data[offset] != 255:
			return false
		var marker := int(data[offset + 1])
		if marker == 255:
			offset += 1
			continue
		var length := (int(data[offset + 2]) << 8) | int(data[offset + 3])
		if length < 2 or offset + 2 + length > data.size():
			return false
		if marker in [192, 193, 194, 195, 197, 198, 199, 201, 202, 203, 205, 206, 207]:
			var height := (int(data[offset + 5]) << 8) | int(data[offset + 6])
			var width := (int(data[offset + 7]) << 8) | int(data[offset + 8])
			return width > 0 and height > 0 and width * height <= 40000000
		offset += length + 2
	return false


func _upload(image: Image, token_url: String, headers: PackedStringArray) -> Dictionary:
	var response := await _json(token_url, headers, HTTPClient.METHOD_GET, PackedByteArray(), true, true)
	if not response.ok:
		return response
	var token: Variant = response.value
	if not token is Dictionary or not token.get("globalDomain") is String or not token.get("ousToken") is String:
		return _failure("平台上传凭证无效。")
	var upload_token: String = token.ousToken
	if "\n" in upload_token or "\r" in upload_token or upload_token.is_empty():
		return _failure("平台上传凭证无效。")
	var block_size := _number(token.get("blockSize"))
	if block_size < 1024:
		return _failure("平台上传块大小无效。")
	# Re-encode and shrink to a single SDK-defined upload block; no block protocol guessing.
	var data := image.save_jpg_to_buffer(0.88)
	while data.size() > block_size and mini(image.get_width(), image.get_height()) > 32:
		image.resize(maxi(1, int(image.get_width() * 0.75)), maxi(1, int(image.get_height() * 0.75)), Image.INTERPOLATE_LANCZOS)
		data = image.save_jpg_to_buffer(0.8)
	if data.size() > block_size:
		return _failure("照片无法压缩至平台上传限制内。")
	var hashing := HashingContext.new()
	hashing.start(HashingContext.HASH_MD5)
	hashing.update(data)
	var digest := hashing.finish().hex_encode()
	var body := ("--" + BOUNDARY + "\r\nContent-Disposition: form-data; name=\"md5\"\r\n\r\n" + digest + "\r\n--" + BOUNDARY + "\r\nContent-Disposition: form-data; name=\"file\"; filename=\"photo.jpg\"\r\nContent-Type: application/octet-stream\r\n\r\n").to_utf8_buffer()
	body.append_array(data)
	body.append_array(("\r\n--" + BOUNDARY + "--\r\n").to_utf8_buffer())
	var domain: String = token.globalDomain.trim_suffix("/")
	var ous_headers := PackedStringArray(["ous-token-v2: " + upload_token, "Content-Type: multipart/form-data; boundary=" + BOUNDARY])
	response = await _json(domain + "/ous/api/v2/single/upload", ous_headers, HTTPClient.METHOD_POST, body, false)
	if not response.ok:
		return response
	var deadline := Time.get_ticks_msec() + int(poll_timeout_seconds * 1000)
	while Time.get_ticks_msec() < deadline:
		response = await _json(domain + "/ous/api/v2/upload/status", ous_headers)
		if not response.ok:
			return response
		var value: Variant = _envelope_data(response.value)
		if not value is Dictionary:
			return _failure("平台上传状态无效。")
		if _number(value.get("status")) == 5 and _allowed_url(str(value.get("url", ""))):
			return {"ok": true, "url": str(value.url)}
		if _number(value.get("status")) in [6, 8]:
			return _failure("照片上传失败，请稍后重试。")
		await _pause()
	return _failure("照片上传等待超时。")


func _poll_task(base: String, headers: PackedStringArray, task_id: String, stage: String) -> Dictionary:
	progress.emit("等待生成模型…" if stage == "generate" else "等待人形自动绑骨…")
	var deadline := Time.get_ticks_msec() + int(poll_timeout_seconds * 1000)
	while Time.get_ticks_msec() < deadline:
		var response := await _json(base + "/lux3d/v1/generate/task/get?taskid=" + task_id.uri_encode(), headers)
		if not response.ok:
			return response
		var value: Variant = _envelope_data(response.value)
		if not value is Dictionary or not value.has("status"):
			return _failure("平台任务状态无效；可使用任务号继续查询。")
		var status := _number(value.status)
		if status == 3:
			var outputs: Variant = value.get("outputs", [])
			if outputs is Array:
				for output in outputs:
					if output is Dictionary and output.get("content") is String:
						var url: String = output.content
						if _allowed_url(url) and url.get_slice("?", 0).to_lower().ends_with(".glb"):
							return {"ok": true, "url": url}
			return _failure("任务完成，但未返回 GLB 模型。")
		if status in [4, 6]:
			# Final on the platform side: querying again cannot change it, so the caller may drop the task.
			var final := _failure("平台任务失败。" + _task_error(value.get("outputs", [])) if status == 4 else "平台任务已取消。")
			final.final = true
			return final
		if status not in [0, 1]:
			return _failure("平台返回未知任务状态；可稍后继续查询。")
		await _pause()
	return _failure("等待超时，可使用已保存的任务号继续查询。")


func _pause() -> void:
	var deadline := Time.get_ticks_msec() + int(maxf(0.01, poll_interval_seconds) * 1000)
	while not _cancelled and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame


func _json(url: String, headers: PackedStringArray, method := HTTPClient.METHOD_GET, body := PackedByteArray(), json_body := true, token_response := false) -> Dictionary:
	var request_headers := headers.duplicate()
	if method == HTTPClient.METHOD_POST and json_body:
		request_headers.append("Content-Type: application/json")
	var response := await _request(url, request_headers, method, body, MAX_JSON_BYTES)
	if not response.ok:
		return response
	var raw: String = response.data.get_string_from_utf8()
	var value: Variant = JSON.parse_string(raw)
	if not value is Dictionary:
		return _failure("平台返回的数据格式无效。")
	if not token_response and not value.has("c"):
		return _failure("平台返回的数据缺少状态码。")
	if value.has("c") and str(value.c) != "0":
		return _failure("平台拒绝请求，请检查额度、密钥和输入。")
	# Godot JSON uses doubles; preserve 64-bit numeric task IDs directly from wire text.
	if value.get("d") is float:
		var pattern := RegEx.new()
		pattern.compile('"d"\\s*:\\s*([0-9]+)\\s*[,}]')
		var matched := pattern.search(raw)
		if matched != null:
			value.d = matched.get_string(1)
	return {"ok": true, "value": value}


func _envelope_data(value: Dictionary) -> Variant:
	return value.get("d") if str(value.get("c", "")) == "0" else null


func _task_id(value: Dictionary) -> String:
	var id := str(_envelope_data(value))
	return id if id.is_valid_int() and id.length() <= 32 else ""


## A failed task puts its reason in outputs[].content as {"error": {code, message}},
## e.g. MODEL_NOT_RIGGABLE when the arms are not in T / A pose. Returned text is bounded.
func _task_error(outputs: Variant) -> String:
	if not outputs is Array:
		return ""
	for output in outputs:
		if not output is Dictionary or not output.get("content") is String:
			continue
		var parsed: Variant = JSON.parse_string(output.content)
		if parsed is Dictionary and parsed.get("error") is Dictionary:
			var code := str(parsed.error.get("code", "")).left(40)
			var message := str(parsed.error.get("message", "")).left(160)
			if code == "MODEL_NOT_RIGGABLE":
				message += "请换一张双臂张开、自然站立的单人全身照（T / A 字姿势）。"
			return "（%s）%s" % [code, message] if code else message
	return ""


func _number(value: Variant) -> int:
	if value is int or value is float:
		return int(value) if float(value) == float(int(value)) else -1
	if value is String and value.is_valid_int():
		return value.to_int()
	return -1


func _uncertain_create(response: Dictionary) -> Dictionary:
	return _failure(str(response.error) + " 创建请求可能已被受理；请先检查平台任务记录，避免重复创建和扣费。")


func _allowed_url(url: String) -> bool:
	if "\r" in url or "\n" in url or "@" in url or url.length() > 8192:
		return false
	if url.begins_with("https://"):
		return true
	# Cleartext is permitted only for explicitly injected loopback fixture gateways.
	return gateway_base.begins_with("http://127.0.0.1:") and url.begins_with(gateway_base.trim_suffix("/") + "/")


func _request(url: String, headers: PackedStringArray, method: int, body: PackedByteArray, limit: int) -> Dictionary:
	if _cancelled:
		return _failure("已停止本地等待；远端任务仍可能运行并计费，可凭任务号恢复。")
	if not _allowed_url(url):
		return _failure("平台返回的下载或上传地址无效。")
	var request := HTTPRequest.new()
	request.timeout = maxf(0.05, request_timeout_seconds)
	request.body_size_limit = limit
	# Never forward Authorization to a redirect target or follow an unbounded redirect chain.
	request.max_redirects = 0
	add_child(request)
	var completed := {"done": false}
	request.request_completed.connect(func(result: int, code: int, _response_headers: PackedStringArray, data: PackedByteArray):
		completed.merge({"done": true, "result": result, "code": code, "data": data}, true))
	var error := request.request_raw(url, headers, method, body)
	if error != OK:
		request.queue_free()
		return _failure("无法发起网络请求，请检查网络连接。")
	while not completed.done and not _cancelled:
		await get_tree().process_frame
	if _cancelled:
		request.cancel_request()
		request.queue_free()
		return _failure("已停止本地等待；远端任务仍可能运行并计费，可凭任务号恢复。")
	request.queue_free()
	if int(completed.result) == HTTPRequest.RESULT_BODY_SIZE_LIMIT_EXCEEDED:
		return _failure("平台文件超出允许大小（模型最多 32 MiB）。")
	if int(completed.result) == HTTPRequest.RESULT_TIMEOUT:
		return _failure("网络请求超时，可凭已保存任务号恢复查询。")
	if int(completed.result) != HTTPRequest.RESULT_SUCCESS:
		return _failure("网络请求失败，请检查连接后继续查询。")
	if int(completed.code) < 200 or int(completed.code) >= 300:
		return _failure("平台 HTTP %d：请检查密钥、额度及网络后重试。" % int(completed.code))
	return {"ok": true, "data": completed.data}


func _failure(message: String) -> Dictionary:
	return {"ok": false, "error": message}
