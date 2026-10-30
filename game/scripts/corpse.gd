class_name Corpse
extends Node3D
## 躺在棺材里的逝者：几段胶囊用关节连成的布娃娃，头朝棺材 +X 那头，脸朝上。
## 节点本身放在棺材的位置，各部件按棺材局部坐标摆好。

var torso: RigidBody3D
var parts: Array[RigidBody3D] = []
const HUMANOID := preload("res://scripts/humanoid_rig.gd")
var _model: Node3D
var _skeleton: Skeleton3D
var _default_visuals: Array[GeometryInstance3D] = []
var _bone_parts: Array[int] = []
var _rest_bones: Array[Transform3D] = []
var _rest_parts: Array[Transform3D] = []
var _skeleton_in_torso := Transform3D.IDENTITY
var _torso_rest_inverse := Transform3D.IDENTITY


func _ready() -> void:
	var grey := Color(0.32, 0.33, 0.36)
	torso = _part(0.14, 0.62, Vector3(0.1, -0.02, 0), 10.0, grey)
	var head := _part(0.12, 0.34, Vector3(0.58, -0.04, 0), 3.0, Art.SKIN)
	# 部件绕 Z 转了 90°：局部 +X 是世界“上”（脸），局部 -Y 是头顶方向
	Art.googly_eyes(head, Vector3(0.09, -0.04, 0), Vector3.RIGHT, Vector3.DOWN, 0.8)
	_joint(torso, head, Vector3(0.42, -0.03, 0))
	for s in [-1.0, 1.0]:
		var leg := _part(0.08, 0.8, Vector3(-0.5, -0.07, s * 0.09), 4.0, grey)
		_joint(torso, leg, Vector3(-0.14, -0.05, s * 0.09))
		var arm := _part(0.06, 0.6, Vector3(0.12, -0.08, s * 0.22), 1.5, grey)
		var hand := Art.mesh(Art.sphere(0.065), Art.SKIN, Vector3(0, 0.32, 0))
		arm.add_child(hand)
		_joint(torso, arm, Vector3(0.36, -0.06, s * 0.2))
	_torso_rest_inverse = torso.transform.affine_inverse()
	for part in parts:
		_rest_parts.append((_torso_rest_inverse * part.transform).affine_inverse())
		for visual in part.find_children("*", "GeometryInstance3D", true, false):
			_default_visuals.append(visual)
	var characters := get_node_or_null("/root/Characters")
	if characters != null:
		characters.changed.connect(_character_changed)
	_apply_character_model()


func _character_changed(target: String) -> void:
	if target == "corpse":
		_apply_character_model()


func _apply_character_model() -> void:
	if _model != null:
		torso.remove_child(_model)
		_model.queue_free()
		_model = null
	_skeleton = null
	_bone_parts.clear()
	_rest_bones.clear()
	for visual in _default_visuals:
		visual.visible = true
	var characters := get_node_or_null("/root/Characters")
	if characters == null:
		return
	_model = characters.make_model("corpse")
	if _model == null:
		return
	_skeleton = HUMANOID.skeleton_in(_model)
	if _skeleton == null:
		_model.free()
		_model = null
		return
	# Standard humanoid +Y points toward the coffin's +X head end; +Z faces up.
	# These are visuals only. The six capsules, joints and parts array stay intact.
	var orientation := Basis(Vector3.BACK, Vector3.RIGHT, Vector3.UP)
	var normalized := Transform3D(orientation.scaled(Vector3.ONE * (1.65 / 1.75)), Vector3(-0.075, -0.04, 0))
	_model.transform = _torso_rest_inverse * normalized
	torso.add_child(_model)
	_skeleton_in_torso = torso.global_transform.affine_inverse() * _skeleton.global_transform
	var branches := {
		HUMANOID.bone_index(_skeleton, "Head"): 1,
		HUMANOID.bone_index(_skeleton, "LeftUpLeg"): 2,
		HUMANOID.bone_index(_skeleton, "LeftArm"): 3,
		HUMANOID.bone_index(_skeleton, "RightUpLeg"): 4,
		HUMANOID.bone_index(_skeleton, "RightArm"): 5
	}
	var fits := {
		2: _limb_fit("LeftUpLeg", "LeftFoot", 2, -0.36, 0.4),
		3: _limb_fit("LeftArm", "LeftHand", 3, -0.24, 0.3),
		4: _limb_fit("RightUpLeg", "RightFoot", 4, -0.36, 0.4),
		5: _limb_fit("RightArm", "RightHand", 5, -0.24, 0.3)
	}
	for bone in _skeleton.get_bone_count():
		var ancestor := bone
		var part := 0
		while ancestor >= 0:
			if branches.has(ancestor):
				part = branches[ancestor]
				break
			ancestor = _skeleton.get_bone_parent(ancestor)
		_bone_parts.append(part)
		var fit: Transform3D = fits.get(part, Transform3D.IDENTITY)
		_rest_bones.append(fit * _skeleton.get_bone_global_rest(bone))
	for visual in _default_visuals:
		visual.visible = false
	_process(0.0)


func _limb_fit(root_name: String, end_name: String, part: int, proximal: float, distal: float) -> Transform3D:
	# Fit the rest limb along its capsule before ragdoll deltas are applied. This
	# folds a generated T-pose's arms beside the torso and fits different heights.
	var start := _skeleton.get_bone_global_rest(HUMANOID.bone_index(_skeleton, root_name)).origin
	var end := _skeleton.get_bone_global_rest(HUMANOID.bone_index(_skeleton, end_name)).origin
	var body_to_skeleton := _skeleton_in_torso.affine_inverse() * _rest_parts[part].affine_inverse()
	var target_start := body_to_skeleton * Vector3(0, proximal, 0)
	var target_end := body_to_skeleton * Vector3(0, distal, 0)
	var direction := end - start
	var target_direction := target_end - target_start
	if direction.length() < 0.0001 or target_direction.length() < 0.0001:
		return Transform3D.IDENTITY
	var axis := direction.normalized()
	var stretch := target_direction.length() / direction.length() - 1.0
	# Scale only along the limb, retaining its authored width and hand/foot size.
	var along_limb := Basis(Vector3.RIGHT + axis * axis.x * stretch, Vector3.UP + axis * axis.y * stretch, Vector3.BACK + axis * axis.z * stretch)
	var basis := Basis(Quaternion(axis, target_direction.normalized())) * along_limb
	return Transform3D(basis, target_start - basis * start)


func _process(_delta: float) -> void:
	if _skeleton == null:
		return
	var to_skeleton := _skeleton.global_transform.affine_inverse()
	var deltas: Array[Transform3D] = []
	for i in parts.size():
		deltas.append(to_skeleton * parts[i].global_transform * _rest_parts[i] * _skeleton_in_torso)
	for bone in _bone_parts.size():
		# Each rigid-body delta moves the entire corresponding limb, including its
		# forearm/hand or knee/foot descendants; torso motion is inherited naturally.
		_skeleton.set_bone_global_pose_override(bone, deltas[_bone_parts[bone]] * _rest_bones[bone], 1.0, true)


func _part(r: float, h: float, pos: Vector3, m: float, color: Color) -> RigidBody3D:
	var body := RigidBody3D.new()
	body.mass = m
	body.position = pos
	body.rotation.z = PI / 2  # 胶囊沿 X 躺平
	body.angular_damp = 2.0
	body.add_to_group("grabbable")
	body.add_to_group("corpse")
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = r
	cap.height = h
	cs.shape = cap
	body.add_child(cs)
	body.add_child(Art.mesh(Art.capsule(r, h), color))
	add_child(body)
	parts.append(body)
	return body


func _joint(a: RigidBody3D, b: RigidBody3D, pos: Vector3) -> void:
	var j := ConeTwistJoint3D.new()
	j.position = pos
	j.set_param(ConeTwistJoint3D.PARAM_SWING_SPAN, deg_to_rad(70))
	j.set_param(ConeTwistJoint3D.PARAM_TWIST_SPAN, deg_to_rad(40))
	add_child(j)
	j.node_a = j.get_path_to(a)
	j.node_b = j.get_path_to(b)
