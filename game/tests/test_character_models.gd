extends SceneTree
## Headless integration checks. Run with --headless --path game --script res://tests/test_character_models.gd.

var failures := 0
var checks := 0


func _initialize() -> void:
	_run.call_deferred()


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("FAIL: " + message)


func _run() -> void:
	if not ResourceLoader.exists("res://scripts/character_models.gd"):
		check(false, "runtime character cache and customization are available")
		quit(1)
		return
	var cache: Node = root.get_node_or_null("Characters")
	if cache == null:
		cache = load("res://scripts/character_models.gd").new()
		cache.name = "Characters"
		root.add_child(cache)
	var saved := {}
	for target in ["player1", "player2", "corpse"]:
		saved[target] = cache.get_local_model(target)
		cache.clear_model(target)
	cache.clear_session_models()
	var data := FileAccess.get_file_as_bytes("res://assets/bearer.glb")
	check(not data.is_empty(), "packaged human GLB fixture is present")
	check(cache.set_model("../escape", data) != "", "unknown target cannot write outside cache")
	check(cache.set_model("player1", data) == "", "compatible packaged GLB is accepted")
	check(cache.get_model("player1") == data, "accepted model bytes are available")
	var normalized: Node3D = cache.make_model("player1")
	check(normalized != null, "accepted GLB creates a visual scene")
	if normalized != null:
		check(normalized.find_children("*", "Skeleton3D", true, false).size() == 1, "custom scene retains its human skeleton")
		normalized.free()
	check(cache.set_model("player1", "not a GLB".to_utf8_buffer()) != "", "corrupt GLB is rejected")
	check(cache.get_model("player1") == data, "corrupt replacement preserves accepted appearance")
	check(cache.set_model("player1", edited_glb(data, "rename_bones")) != "", "unrecognized human bones are rejected")
	check(cache.get_model("player1") == data, "incompatible skeleton preserves accepted appearance")
	check(cache.set_model("player1", edited_glb(data, "external")) != "", "external image URI is rejected before runtime import")
	var oversized := PackedByteArray()
	oversized.resize(32 * 1024 * 1024 + 1)
	check(cache.set_model("player1", oversized) != "", "models over 32 MiB are rejected")
	check(cache.set_session_model("player1", PackedByteArray()) == "", "remote default can override a local custom appearance")
	check(cache.get_model("player1").is_empty(), "remote default takes visual precedence")
	check(cache.get_local_model("player1") == data, "remote override retains user's saved model")
	cache.clear_session_models()
	check(cache.get_model("player1") == data, "ending session restores local appearance")
	var fixture := load("res://tests/fixtures/humanoid_glb.gd")
	var tiny: PackedByteArray = fixture.make("mixamorig_", 100.0)
	check(cache.set_model("player2", tiny) == "", "tiny fixture accepts alternate Mixamo prefix and centimeter units")
	var tiny_model: Node3D = cache.make_model("player2")
	world_size_check(tiny_model)
	tiny_model.free()
	var reloaded: Node = load("res://scripts/character_models.gd").new()
	root.add_child(reloaded)
	check(reloaded.get_local_model("player2") == tiny, "valid cache survives a fresh manager instance")
	reloaded.queue_free()
	var world := Node3D.new()
	root.add_child(world)
	var bearer: Node3D = load("res://scripts/bearer.gd").new()
	bearer.character_slot = "player1"
	bearer.puppet = true
	world.add_child(bearer)
	await process_frame
	bearer.set_first_person_owner(1)
	var custom: Node3D = bearer.get("_model")
	check(custom != null and custom.has_meta("custom_character"), "new bearer uses selected custom model")
	check(all_body_layers(custom, 4), "first-person body uses player two render layer")
	check(bearer.hands.size() == 2, "custom bearer preserves two physical hands")
	var hand_mesh_count: int = bearer.hands[0].find_children("*", "MeshInstance3D", true, false).size()
	cache.clear_model("player1")
	check(bearer.get("_model") != custom, "clear swaps existing bearer immediately")
	check(not bearer.get("_model").has_meta("custom_character"), "cleared bearer restores packaged model")
	check(all_body_layers(bearer.get("_model"), 4), "clearing preserves first-person body mask")
	check(cache.set_model("player1", data) == "", "existing bearer can receive a custom replacement")
	check(all_body_layers(bearer.get("_model"), 4), "replacement preserves first-person body mask")
	bearer.set_first_person_owner(1)
	check(bearer.hands[0].find_children("*", "MeshInstance3D", true, false).size() == hand_mesh_count, "reapplying camera ownership does not duplicate first-person hands")
	check((bearer.fp_cull_mask(1) & 4) == 0, "player two camera hides own body")
	var fixture_bearer: Node3D = load("res://scripts/bearer.gd").new()
	fixture_bearer.character_slot = "player2"
	fixture_bearer.puppet = true
	world.add_child(fixture_bearer)
	await process_frame
	fixture_bearer.call("_process", 0.0)
	var fixture_skeleton: Skeleton3D = fixture_bearer.get("_skeleton")
	for side in 2:
		var prefix := "Left" if side == 0 else "Right"
		var shoulder := fixture_skeleton.to_global(fixture_skeleton.get_bone_global_pose(find_bone(fixture_skeleton, prefix + "Arm")).origin)
		var elbow := fixture_skeleton.to_global(fixture_skeleton.get_bone_global_pose(find_bone(fixture_skeleton, prefix + "ForeArm")).origin)
		var physical_hand: Vector3 = fixture_bearer.hands[side].global_position
		check((elbow - shoulder).normalized().dot((physical_hand - shoulder).normalized()) > 0.99, prefix + " upper arm aims toward physical hand using authored bone axis")
	var corpse: Node3D = load("res://scripts/corpse.gd").new()
	world.add_child(corpse)
	var original_parts: Array = corpse.parts.duplicate()
	check(corpse.parts.size() == 6, "default corpse has six snapshot bodies")
	check(cache.set_model("corpse", data) == "", "corpse accepts custom human GLB")
	check(corpse.parts == original_parts, "corpse customization preserves body identity and snapshot order")
	check(corpse.find_children("*", "RigidBody3D", true, false).size() == 6, "custom appearance introduces no rigid bodies")
	check(not corpse.parts[1].get_child(1).visible, "custom corpse hides original capsule visuals")
	var corpse_model: Node3D = corpse.get("_model")
	check(corpse_model != null, "custom corpse attaches humanoid visual")
	if corpse_model != null:
		var skel: Skeleton3D = corpse_model.find_children("*", "Skeleton3D", true, false).front()
		var arm := find_bone(skel, "LeftArm")
		corpse.call("_process", 0.0)
		var shoulder_position: Vector3 = corpse.to_local(skel.to_global(skel.get_bone_global_pose(arm).origin))
		var hand_position: Vector3 = corpse.to_local(skel.to_global(skel.get_bone_global_pose(find_bone(skel, "LeftHand")).origin))
		check(shoulder_position.distance_to(Vector3(0.36, -0.08, -0.22)) < 0.08, "custom corpse shoulder aligns with physical arm root")
		check(hand_position.distance_to(Vector3(-0.18, -0.08, -0.22)) < 0.08, "custom corpse neutral arms lie along coffin instead of T pose")
		var before := skel.get_bone_global_pose(arm)
		corpse.parts[3].rotate_z(0.5)
		corpse.call("_process", 0.0)
		var after := skel.get_bone_global_pose(arm)
		check(not before.basis.is_equal_approx(after.basis), "custom corpse skeleton follows physical arm rotation")
		corpse.torso.rotate_y(0.4)
		corpse.call("_process", 0.0)
		var expected_skeleton_transform := skel.global_transform
		var expected_arm_pose := skel.get_bone_global_pose(arm)
		check(cache.set_model("corpse", data) == "", "custom corpse supports replacement while ragdoll is moving")
		skel = corpse.get("_model").find_children("*", "Skeleton3D", true, false).front()
		check(skel.global_transform.is_equal_approx(expected_skeleton_transform), "replacement retains attachment relative to moving torso")
		check(skel.get_bone_global_pose(arm).is_equal_approx(expected_arm_pose), "replacement retains deformed limb pose relative to original bind")
	cache.clear_model("corpse")
	check(corpse.get("_model") == null, "clear removes custom corpse visual")
	check(corpse.parts[1].get_child(1).visible, "clear restores original corpse visuals")
	check(corpse.parts == original_parts, "clear preserves corpse body identity and order")
	world.queue_free()
	await process_frame
	for target in saved:
		if saved[target].is_empty():
			cache.clear_model(target)
		else:
			cache.set_model(target, saved[target])
	print("Character models: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func world_size_check(model: Node3D) -> void:
	var mesh: MeshInstance3D = model.find_children("*", "MeshInstance3D", true, false).front()
	var transform := mesh.transform
	var parent := mesh.get_parent()
	while parent != model:
		if parent is Node3D:
			transform = parent.transform * transform
		parent = parent.get_parent()
	var bounds: AABB = transform * mesh.get_aabb()
	check(is_equal_approx(bounds.size.y, 1.75), "generated model units normalize to bearer height")
	check(bounds.get_center().is_equal_approx(Vector3.ZERO), "generated model centers on physical bearer")


func all_body_layers(model: Node3D, expected: int) -> bool:
	for mesh in model.find_children("*", "MeshInstance3D", true, false):
		if mesh.layers != expected:
			return false
	return true


func find_bone(skeleton: Skeleton3D, suffix: String) -> int:
	for i in skeleton.get_bone_count():
		if String(skeleton.get_bone_name(i)).ends_with(suffix):
			return i
	return -1


func edited_glb(source: PackedByteArray, change: String) -> PackedByteArray:
	var json_length := source.decode_u32(12)
	var doc: Dictionary = JSON.parse_string(source.slice(20, 20 + json_length).get_string_from_utf8())
	if change == "rename_bones":
		for node in doc.nodes:
			if String(node.get("name", "")).begins_with("mixamorig"):
				node.name = "Unknown_" + str(node.name.hash())
	elif change == "external":
		doc.images[0] = {"uri": "https://example.invalid/do-not-fetch.png"}
	var json_data := JSON.stringify(doc).to_utf8_buffer()
	while json_data.size() % 4:
		json_data.append(32)
	var result := PackedByteArray()
	result.resize(20)
	result.encode_u32(0, 0x46546c67)
	result.encode_u32(4, 2)
	result.encode_u32(8, 20 + json_data.size() + source.size() - 20 - json_length)
	result.encode_u32(12, json_data.size())
	result.encode_u32(16, 0x4e4f534a)
	result.append_array(json_data)
	result.append_array(source.slice(20 + json_length))
	return result
