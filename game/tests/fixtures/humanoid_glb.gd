extends RefCounted
## Small, self-contained skinned GLB for offline cache/network tests (no textures).


static func make(prefix := "mixamorig:", size_scale := 1.0) -> PackedByteArray:
	var names := ["Hips", "Spine", "Head", "LeftArm", "LeftForeArm", "LeftHand", "RightArm", "RightForeArm", "RightHand", "LeftUpLeg", "LeftLeg", "LeftFoot", "RightUpLeg", "RightLeg", "RightFoot"]
	var parents := [-1, 0, 1, 1, 3, 4, 1, 6, 7, 0, 9, 10, 0, 12, 13]
	var positions := [Vector3(0, 0.9, 0), Vector3(0, 0.3, 0), Vector3(0, 0.5, 0), Vector3(-0.25, 0.2, 0), Vector3(-0.3, 0, 0), Vector3(-0.25, 0, 0), Vector3(0.25, 0.2, 0), Vector3(0.3, 0, 0), Vector3(0.25, 0, 0), Vector3(-0.1, -0.1, 0), Vector3(0, -0.4, 0), Vector3(0, -0.4, 0.1), Vector3(0.1, -0.1, 0), Vector3(0, -0.4, 0), Vector3(0, -0.4, 0.1)]
	var nodes := []
	var world_positions: Array[Vector3] = []
	for i in names.size():
		var position: Vector3 = positions[i] * size_scale
		nodes.append({"name": prefix + names[i], "translation": [position.x, position.y, position.z]})
		world_positions.append(position + (world_positions[parents[i]] if parents[i] >= 0 else Vector3.ZERO))
		if parents[i] >= 0:
			if not nodes[parents[i]].has("children"):
				nodes[parents[i]]["children"] = []
			nodes[parents[i]].children.append(i)
	nodes.append({"name": "TestSkinnedMesh", "mesh": 0, "skin": 0})
	var binary := PackedByteArray()
	var vertices := PackedVector3Array([Vector3(-0.2, 0, 0), Vector3(0.2, 0, 0), Vector3(0, 1.75, 0)])
	for vertex in vertices:
		binary.append_array(PackedFloat32Array([vertex.x * size_scale, vertex.y * size_scale, vertex.z * size_scale]).to_byte_array())
	# Three VEC4 joint indices (uint16) and three VEC4 weights (float32).
	binary.append_array(PackedInt32Array([0, 0, 0, 0, 0, 0]).to_byte_array())
	for i in 3:
		binary.append_array(PackedFloat32Array([1.0, 0.0, 0.0, 0.0]).to_byte_array())
	for position in world_positions:
		binary.append_array(PackedFloat32Array([1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, -position.x, -position.y, -position.z, 1]).to_byte_array())
	var doc := {
		"asset": {"version": "2.0"}, "scene": 0, "scenes": [{"nodes": [0, 15]}], "nodes": nodes,
		"buffers": [{"byteLength": binary.size()}],
		"bufferViews": [{"buffer": 0, "byteOffset": 0, "byteLength": 36}, {"buffer": 0, "byteOffset": 36, "byteLength": 24}, {"buffer": 0, "byteOffset": 60, "byteLength": 48}, {"buffer": 0, "byteOffset": 108, "byteLength": 960}],
		"accessors": [
			{"bufferView": 0, "componentType": 5126, "count": 3, "type": "VEC3", "min": [-0.2 * size_scale, 0, 0], "max": [0.2 * size_scale, 1.75 * size_scale, 0]},
			{"bufferView": 1, "componentType": 5123, "count": 3, "type": "VEC4"},
			{"bufferView": 2, "componentType": 5126, "count": 3, "type": "VEC4"},
			{"bufferView": 3, "componentType": 5126, "count": 15, "type": "MAT4"}
		],
		"skins": [{"inverseBindMatrices": 3, "skeleton": 0, "joints": [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14]}],
		"meshes": [{"primitives": [{"attributes": {"POSITION": 0, "JOINTS_0": 1, "WEIGHTS_0": 2}}]}]
	}
	var json := JSON.stringify(doc).to_utf8_buffer()
	while json.size() % 4:
		json.append(32)
	var glb := PackedByteArray()
	glb.resize(20)
	glb.encode_u32(0, 0x46546c67)
	glb.encode_u32(4, 2)
	glb.encode_u32(8, 28 + json.size() + binary.size())
	glb.encode_u32(12, json.size())
	glb.encode_u32(16, 0x4e4f534a)
	glb.append_array(json)
	var chunk := PackedByteArray()
	chunk.resize(8)
	chunk.encode_u32(0, binary.size())
	chunk.encode_u32(4, 0x004e4942)
	glb.append_array(chunk)
	glb.append_array(binary)
	return glb
