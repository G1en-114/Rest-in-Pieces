class_name Corpse
extends Node3D
## 躺在棺材里的逝者：几段胶囊用关节连成的布娃娃，头朝棺材 +X 那头，脸朝上。
## 节点本身放在棺材的位置，各部件按棺材局部坐标摆好。

var torso: RigidBody3D
var parts: Array[RigidBody3D] = []


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
