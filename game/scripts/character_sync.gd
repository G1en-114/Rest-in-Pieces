extends Node
## 只同步 GLB 外观；密钥和照片始终留在本机。Autoload 在换关时继续接收。

const MAX_MODEL_BYTES := 32 * 1024 * 1024
const CHUNK_BYTES := 24 * 1024
const TARGETS := ["player1", "player2", "corpse"]

var _peer := 0
var _server := false
var _receiving := {}
var _sending := {}
var _serial := 0
var _applying := false
var models: Node  # 可注入独立缓存，供双 ENet 实例的离线集成测试使用。


func _ready() -> void:
	if models == null:
		models = get_node("/root/Characters")
	models.changed.connect(_on_changed)
	multiplayer.peer_disconnected.connect(func(id: int) -> void:
		if id == _peer:
			reset())
	multiplayer.server_disconnected.connect(reset)
	set_process(false)


func accept_peer(id: int) -> void:
	if not multiplayer.is_server() or id not in multiplayer.get_peers():
		return
	reset()
	_server = true
	_peer = id
	_welcome.rpc_id(id)
	_send_model(id, "player1", models.get_local_model("player1"))
	_send_model(id, "corpse", models.get_local_model("corpse"))


func reset() -> void:
	_peer = 0
	_receiving.clear()
	_sending.clear()
	_applying = true
	models.clear_session_models()
	_applying = false
	set_process(false)


@rpc("authority", "call_remote", "reliable", 1)
func _welcome() -> void:
	if multiplayer.get_remote_sender_id() != 1:
		return
	reset()
	_server = false
	_peer = 1
	# 每台电脑的“玩家一”作为自己的联机角色；加入方在队伍中是玩家二。
	_send_model(1, "player2", models.get_local_model("player1"))


func _on_changed(target: String) -> void:
	if _applying or _peer == 0:
		return
	if _server and target in ["player1", "corpse"]:
		_send_model(_peer, target, models.get_local_model(target))
	elif not _server and target == "player1":
		_send_model(1, "player2", models.get_local_model("player1"))


func _send_model(id: int, target: String, data: PackedByteArray) -> void:
	if data.size() > MAX_MODEL_BYTES:
		return
	_serial += 1
	var ticket := _serial
	_sending[target] = ticket
	_begin.rpc_id(id, target, ticket, data.size(), _digest(data))
	for offset in range(0, data.size(), CHUNK_BYTES):
		if _peer != id or _sending.get(target, -1) != ticket or id not in multiplayer.get_peers():
			return
		_chunk.rpc_id(id, target, ticket, data.slice(offset, offset + CHUNK_BYTES))
		await get_tree().create_timer(0.015).timeout
	if _peer == id and _sending.get(target, -1) == ticket and id in multiplayer.get_peers():
		_finish.rpc_id(id, target, ticket)


func _allowed(sender: int, target: String) -> bool:
	return sender == _peer and sender != 0 and target in TARGETS and (not _server or target == "player2")


@rpc("any_peer", "call_remote", "reliable", 1)
func _begin(target: String, ticket: int, size: int, digest: String) -> void:
	if not _allowed(multiplayer.get_remote_sender_id(), target):
		return
	if size < 0 or size > MAX_MODEL_BYTES or digest.length() != 64:
		return
	_receiving[target] = {ticket = ticket, size = size, digest = digest,
		chunks = [], received = 0, until = Time.get_ticks_msec() + 60000,
		deadline = Time.get_ticks_msec() + 120000}
	set_process(true)


@rpc("any_peer", "call_remote", "reliable", 1)
func _chunk(target: String, ticket: int, data: PackedByteArray) -> void:
	if not _allowed(multiplayer.get_remote_sender_id(), target) or not _receiving.has(target):
		return
	var entry: Dictionary = _receiving[target]
	if entry.ticket != ticket:
		return
	var expected: int = mini(CHUNK_BYTES, entry.size - entry.received)
	if expected <= 0 or data.size() != expected or Time.get_ticks_msec() > entry.deadline:
		_receiving.erase(target)
		return
	entry.chunks.append(data)
	entry.received += data.size()
	entry.until = Time.get_ticks_msec() + 60000


@rpc("any_peer", "call_remote", "reliable", 1)
func _finish(target: String, ticket: int) -> void:
	if not _allowed(multiplayer.get_remote_sender_id(), target) or not _receiving.has(target):
		return
	var entry: Dictionary = _receiving[target]
	if entry.ticket != ticket:
		return
	_receiving.erase(target)
	if entry.received != entry.size:
		return
	var data := PackedByteArray()
	for chunk: PackedByteArray in entry.chunks:
		data.append_array(chunk)
	if _digest(data) != entry.digest:
		return
	_applying = true
	var error: String = models.set_session_model(target, data)
	_applying = false
	if not error.is_empty():
		push_warning("队友的自定义外观不兼容，保留当前角色。")
		return
	if _server:
		_send_model(_peer, target, data)
	print("CHARACTER_SYNC target=%s bytes=%d" % [target, data.size()])


func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec()
	for target in _receiving.keys():
		if now > _receiving[target].until or now > _receiving[target].deadline:
			_receiving.erase(target)
	if _receiving.is_empty():
		set_process(false)


static func _digest(data: PackedByteArray) -> String:
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	if not data.is_empty():
		hash.update(data)
	return hash.finish().hex_encode()
