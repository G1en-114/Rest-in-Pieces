extends SceneTree
## Diagnostic: camera above the corpse torso. Env: SHOT path, AT seconds, CAMH height.

var _t := 0.0
var _cam: Camera3D


func _initialize() -> void:
	change_scene_to_file("res://scenes/main.tscn")


func _process(delta: float) -> bool:
	_t += delta
	var corpse: Node = null
	for n in root.find_children("*", "", true, false):
		if n.get_script() != null and str(n.get_script().resource_path).ends_with("corpse.gd"):
			corpse = n
			break
	if corpse == null:
		return false
	if _cam == null:
		_cam = Camera3D.new()
		_cam.fov = 50
		root.add_child(_cam)
	var torso: Node3D = corpse.torso
	var h := float(OS.get_environment("CAMH")) if OS.get_environment("CAMH") else 1.6
	_cam.global_position = torso.global_position + Vector3(0.6, h, 0.0)
	_cam.look_at(torso.global_position, Vector3.FORWARD)
	_cam.current = true
	if _t >= float(OS.get_environment("AT")):
		root.get_viewport().get_texture().get_image().save_png(OS.get_environment("SHOT"))
		quit()
	return false
