extends Node
## Persistent validated visuals, independent of player physics and API credentials.
## Empty session bytes mean a peer explicitly selected the built-in appearance.

signal changed(target: String)

const RIG := preload("res://scripts/humanoid_rig.gd")
const TARGETS := ["player1", "player2", "corpse"]
const MAX_BYTES := 32 * 1024 * 1024
const CACHE_DIR := "user://characters"
const HEIGHT := 1.75

var _data := {}
var _scenes := {}
var _session_data := {}
var _session_scenes := {}


func _ready() -> void:
	for target in TARGETS:
		var path := _path(target)
		if not FileAccess.file_exists(path):
			continue
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null or file.get_length() > MAX_BYTES:
			continue
		var bytes := file.get_buffer(file.get_length())
		file.close()
		var result := _prepare(bytes)
		if result.error == "":
			_data[target] = bytes
			_scenes[target] = result.scene


func set_model(target: String, data: PackedByteArray) -> String:
	if target not in TARGETS:
		return "未知角色位置。"
	var result := _prepare(data)
	if result.error != "":
		return result.error
	var error := DirAccess.make_dir_recursive_absolute(CACHE_DIR)
	if error != OK:
		return "无法创建角色缓存目录。"
	var temporary := _path(target) + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return "无法写入角色缓存。"
	file.store_buffer(data)
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK or DirAccess.rename_absolute(temporary, _path(target)) != OK:
		DirAccess.remove_absolute(temporary)
		return "无法保存角色缓存；保留原有角色。"
	_data[target] = data
	_scenes[target] = result.scene
	changed.emit(target)
	return ""


func get_local_model(target: String) -> PackedByteArray:
	return _data.get(target, PackedByteArray())


func get_model(target: String) -> PackedByteArray:
	return _session_data.get(target, get_local_model(target))


func clear_model(target: String) -> void:
	if target not in TARGETS:
		return
	if FileAccess.file_exists(_path(target)) and DirAccess.remove_absolute(_path(target)) != OK:
		return
	_data.erase(target)
	_scenes.erase(target)
	changed.emit(target)


func set_session_model(target: String, data: PackedByteArray) -> String:
	if target not in TARGETS:
		return "未知角色位置。"
	var scene: PackedScene = null
	if not data.is_empty():
		var result := _prepare(data)
		if result.error != "":
			return result.error
		scene = result.scene
	_session_data[target] = data
	_session_scenes[target] = scene
	changed.emit(target)
	return ""


func clear_session_models() -> void:
	var targets := _session_data.keys()
	_session_data.clear()
	_session_scenes.clear()
	for target in targets:
		changed.emit(target)


func make_model(target: String) -> Node3D:
	var scene: PackedScene = _session_scenes.get(target, _scenes.get(target))
	return scene.instantiate() as Node3D if scene != null else null


func _path(target: String) -> String:
	return CACHE_DIR.path_join(target + ".glb")


func _prepare(data: PackedByteArray) -> Dictionary:
	var problem := _check_glb(data)
	if problem != "":
		return {"error": problem}
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	# No filesystem base path: external resources are rejected before this call.
	if document.append_from_buffer(data, "", state) != OK:
		return {"error": "无法读取 GLB 模型。"}
	var imported := document.generate_scene(state)
	if imported == null:
		return {"error": "GLB 没有可显示的场景。"}
	_sanitize(imported)
	var skeleton := RIG.skeleton_in(imported)
	if skeleton == null:
		imported.free()
		return {"error": "模型缺少兼容的人形骨架，请先自动绑骨。"}
	var skinned := false
	var meshes := imported.find_children("*", "MeshInstance3D", true, false)
	var bounds := AABB()
	var first := true
	for mesh: MeshInstance3D in meshes:
		if mesh.mesh == null or not mesh.visible:
			continue
		if mesh.skin != null and mesh.get_node_or_null(mesh.skeleton) == skeleton:
			skinned = true
		var box: AABB = _relative_transform(mesh, imported) * mesh.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
	if not skinned or first or not bounds.position.is_finite() or not bounds.size.is_finite() or bounds.size.y < 0.001:
		imported.free()
		return {"error": "模型没有有效的人形蒙皮网格。"}
	var root := Node3D.new()
	root.name = "CustomCharacter"
	root.set_meta("custom_character", true)
	var normalization := Node3D.new()
	normalization.name = "NormalizedHuman"
	root.add_child(normalization)
	normalization.scale = Vector3.ONE * (HEIGHT / bounds.size.y)
	normalization.position = -bounds.get_center() * (HEIGHT / bounds.size.y)
	normalization.add_child(imported)
	_set_owners(root, root)
	var scene := PackedScene.new()
	var packed := scene.pack(root)
	root.free()
	if packed != OK:
		return {"error": "无法创建角色场景。"}
	return {"error": "", "scene": scene}


func _check_glb(data: PackedByteArray) -> String:
	if data.size() > MAX_BYTES:
		return "角色模型不能超过 32 MiB。"
	if data.size() < 20 or data.decode_u32(0) != 0x46546c67 or data.decode_u32(4) != 2 or data.decode_u32(8) != data.size():
		return "请选择有效的 GLB 2.0 文件。"
	var json_length := data.decode_u32(12)
	if data.decode_u32(16) != 0x4e4f534a or json_length > data.size() - 20 or json_length % 4 != 0:
		return "GLB 数据块损坏。"
	var parser := JSON.new()
	if parser.parse(data.slice(20, 20 + json_length).get_string_from_utf8()) != OK or not parser.data is Dictionary:
		return "GLB 场景描述无效。"
	var json: Dictionary = parser.data
	# A self-contained GLB must not cause network or arbitrary local-file access.
	for kind in ["buffers", "images"]:
		if not json.get(kind, []) is Array:
			return "GLB 资源列表无效。"
		for resource in json.get(kind, []):
			if not resource is Dictionary:
				return "GLB 资源无效。"
			if resource.has("uri") and not String(resource.uri).begins_with("data:"):
				return "GLB 必须内嵌全部资源，不能引用外部文件。"
	if not json.get("nodes", []) is Array or json.get("nodes", []).size() > 512:
		return "GLB 节点数量超出限制。"
	var offset := 20 + json_length
	while offset < data.size():
		if offset + 8 > data.size():
			return "GLB 数据块损坏。"
		var length := data.decode_u32(offset)
		if length % 4 or length > data.size() - offset - 8:
			return "GLB 数据块损坏。"
		offset += 8 + length
	return ""


func _sanitize(root: Node) -> void:
	for child in root.get_children():
		if child is CollisionObject3D or child is CollisionShape3D or child is Camera3D or child is Light3D or child is AnimationPlayer:
			root.remove_child(child)
			child.free()
			continue
		if child is MeshInstance3D and String(child.name).begins_with("Icosphere"):
			child.visible = false
		_sanitize(child)


func _relative_transform(node: Node3D, root: Node3D) -> Transform3D:
	var result := node.transform
	var parent := node.get_parent()
	while parent != null and parent != root:
		if parent is Node3D:
			result = parent.transform * result
		parent = parent.get_parent()
	return root.transform * result


func _set_owners(node: Node, root: Node) -> void:
	for child in node.get_children():
		child.owner = root
		_set_owners(child, root)
