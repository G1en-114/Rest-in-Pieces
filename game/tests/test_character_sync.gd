extends SceneTree
## Two independent ENet sessions in one engine; caches exist only in memory.

const FIXTURE := preload("res://tests/fixtures/humanoid_glb.gd")
const SYNC := preload("res://scripts/character_sync.gd")

class MemoryModels extends "res://scripts/character_models.gd":
	func _ready() -> void:
		pass # Never read or write the user's character cache.

var _port := 19777
var _host_api: SceneMultiplayer
var _client_api: SceneMultiplayer
var _host_peer: ENetMultiplayerPeer
var _client_peer: ENetMultiplayerPeer
var _checks := 0
var _failed := false


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--port="):
			_port = int(arg.get_slice("=", 1))
	multiplayer_poll = false
	_run.call_deferred()


func _branch(branch_name: String, api: SceneMultiplayer, local_data: Dictionary) -> Dictionary:
	var branch := Node.new()
	branch.name = branch_name
	root.add_child(branch)
	api.root_path = branch.get_path()
	set_multiplayer(api, branch.get_path())
	var models := MemoryModels.new()
	models.name = "Characters"
	models.set("_data", local_data)
	branch.add_child(models)
	var sync := SYNC.new()
	sync.name = "CharacterSync"
	sync.models = models
	branch.add_child(sync)
	return {"models": models, "sync": sync}


func _run() -> void:
	var host_data := _padded(FIXTURE.make("mixamorig:"), 150000)
	var client_data := _padded(FIXTURE.make("mixamorig_"), 180000)
	var saved_data := FIXTURE.make("mixamorig:", 100.0)
	_host_api = SceneMultiplayer.new()
	_client_api = SceneMultiplayer.new()
	var host := _branch("Host", _host_api, {"player1": host_data, "player2": saved_data, "corpse": host_data})
	var client := _branch("Client", _client_api, {"player1": client_data, "player2": saved_data, "corpse": PackedByteArray()})
	_host_peer = ENetMultiplayerPeer.new()
	_client_peer = ENetMultiplayerPeer.new()
	if not _check(_host_peer.create_server(_port, 1) == OK, "host ENet starts"):
		_finish()
		return
	_host_api.multiplayer_peer = _host_peer
	_host_api.peer_connected.connect(func(id: int) -> void: host.sync.accept_peer(id))
	if not _check(_client_peer.create_client("127.0.0.1", _port) == OK, "client ENet starts"):
		_finish()
		return
	_client_api.multiplayer_peer = _client_peer
	if not await _wait_until(func() -> bool:
		return host.models.get_model("player2") == client_data and client.models.get_model("player1") == host_data and client.models.get_model("player2") == client_data and client.models.get_model("corpse") == host_data,
		"host player one/corpse and client player one exchange in chunks with player two echo"):
		_finish()
		return
	_check(host.models.get_local_model("player2") == saved_data, "remote model never overwrites host local choice")
	_check(client.models.get_local_model("player1") == client_data, "host player one override never overwrites client's own choice")
	_check(client.models.get_local_model("corpse").is_empty(), "host corpse is a session override only")
	# Malformed probes must be rejected before finish, preventing unbounded arrays.
	client.sync.rpc_id(1, "_begin", "corpse", 900, 1, "a".repeat(64))
	await _settle()
	_check(not host.sync.get("_receiving").has("corpse"), "client cannot open a corpse transfer")
	client.sync.rpc_id(1, "_begin", "player2", 901, 1, "a".repeat(64))
	if not await _wait_until(func() -> bool: return host.sync.get("_receiving").has("player2"), "valid player two transfer begins"):
		_finish()
		return
	client.sync.rpc_id(1, "_chunk", "player2", 901, PackedByteArray())
	await _settle()
	_check(not host.sync.get("_receiving").has("player2"), "empty chunk drops transfer immediately")
	client.sync.rpc_id(1, "_begin", "player2", 902, 100000, "a".repeat(64))
	client.sync.rpc_id(1, "_chunk", "player2", 902, PackedByteArray([1]))
	await _settle()
	_check(not host.sync.get("_receiving").has("player2"), "short nonfinal chunk drops transfer immediately")
	_check(host.models.get_model("player2") == client_data, "rejected transfers preserve current appearance")
	_check(host.models.get_model("corpse") == host_data, "unauthorized transfer preserves host corpse")
	# Legitimate empty model means default appearance and must round-trip too.
	client.models.set("_data", {"player1": PackedByteArray(), "player2": saved_data})
	client.models.changed.emit("player1")
	if not await _wait_until(func() -> bool: return host.models.get_model("player2").is_empty() and client.models.get_model("player2").is_empty(), "default appearance exchanges and echoes"):
		_finish()
		return
	_check(host.models.get_local_model("player2") == saved_data, "default override preserves local saved bytes")
	host.sync.reset()
	client.sync.reset()
	_check(host.models.get_model("player2") == saved_data, "host reset restores local appearance")
	_check(client.models.get_model("player1").is_empty(), "client reset restores latest own player one")
	_check(client.models.get_model("player2") == saved_data, "client reset restores local player two")
	_check(client.models.get_model("corpse").is_empty(), "client reset restores local corpse")
	_finish()


func _check(value: bool, message: String) -> bool:
	_checks += 1
	if not value:
		_failed = true
		push_error("SYNC_FAIL: " + message)
	return value


func _wait_until(predicate: Callable, message: String) -> bool:
	var deadline := Time.get_ticks_msec() + 8000
	while Time.get_ticks_msec() < deadline:
		_host_api.poll()
		_client_api.poll()
		if predicate.call():
			return _check(true, message)
		await process_frame
	return _check(false, message)


func _settle() -> void:
	var deadline := Time.get_ticks_msec() + 150
	while Time.get_ticks_msec() < deadline:
		_host_api.poll()
		_client_api.poll()
		await process_frame


func _finish() -> void:
	if _host_peer != null:
		_host_peer.close()
	if _client_peer != null:
		_client_peer.close()
	print("SYNC_FIXTURE_%s checks=%d" % ["FAIL" if _failed else "PASS", _checks])
	quit(1 if _failed else 0)


func _padded(source: PackedByteArray, padding: int) -> PackedByteArray:
	var json_length := source.decode_u32(12)
	var document: Dictionary = JSON.parse_string(source.slice(20, 20 + json_length).get_string_from_utf8())
	var binary := source.slice(28 + json_length)
	binary.resize(binary.size() + padding)
	document.buffers[0].byteLength = binary.size()
	var json := JSON.stringify(document).to_utf8_buffer()
	while json.size() % 4:
		json.append(32)
	var data := PackedByteArray()
	data.resize(20)
	data.encode_u32(0, 0x46546c67)
	data.encode_u32(4, 2)
	data.encode_u32(8, 28 + json.size() + binary.size())
	data.encode_u32(12, json.size())
	data.encode_u32(16, 0x4e4f534a)
	data.append_array(json)
	var header := PackedByteArray()
	header.resize(8)
	header.encode_u32(0, binary.size())
	header.encode_u32(4, 0x004e4942)
	data.append_array(header)
	data.append_array(binary)
	return data
