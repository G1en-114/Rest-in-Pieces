class_name Bearer
extends RigidBody3D
## 一个站不太稳的抬棺人。
## 身体是一根会晃的胶囊，两只手是被弹簧拉着的物理球；想抓时，手会粘住碰到的东西。
## 手拉东西的力会等量反作用到身体上，所以棺材越重、越歪，人就越站不稳。
## 本身不读键盘：由 main.gd 里的玩家、电脑队友或测试脚本每帧填写下面这几个“意图”。

const MODEL := preload("res://assets/bearer.glb")
const FP_HIDDEN_LAYER := 2  # 第一人称时自己的身体放在这层，第一人称镜头不渲染
const FP_ONLY_LAYER := 4  # 第一人称时才看得到的自己的手

const SPEED := 3.2
const MOVE_ACCEL := 10.0
const MOVE_MAX_FORCE := 900.0
const UPRIGHT_K := 1500.0
const UPRIGHT_D := 140.0
const YAW_K := 220.0
const YAW_D := 45.0
const JUMP_SPEED := 4.2
const HAND_K := 1600.0
const HAND_D := 70.0
const HAND_MAX_FORCE := 650.0
const GRAB_RADIUS := 0.2
const SHOULDER := Vector3(0.17, 0.27, 0.0)
const HAND_SPREAD := 0.3
const LIFT_HEIGHT := 0.22  # 抓住东西后手往上抬多少
const MAX_BEND := 0.6  # 往下够时身体最多前倾多少（弧度）

# ---- 意图（每个物理帧由控制者填写）----
var move_dir := Vector3.ZERO  # 世界坐标，长度 0~1
var face_yaw: Variant = null  # 想朝向的偏航角；null = 空手时转向移动方向，抓着东西时保持不动
var face_deadzone := 0.0  # 朝向偏差在这个角度内就不转身（第一人称抓着棺材时可以自由转头看路）
var want_grab: Array[bool] = [false, false]
var want_jump := false
var reach_pitch := 0.35  # 手伸出的仰角：正数往上，负数往下够，-1.2 左右能碰到地面

var hands: Array[RigidBody3D] = []
var grabs: Array = [null, null]  # 每只手的关节
var held: Array = [null, null]  # 每只手抓着的物体
var bend := 0.0  # 当前前倾程度 0~1（往下够的时候）
var _jump_was_down := false
var _model: Node3D
var _skeleton: Skeleton3D
var _arm_bones: Array[int] = []


func _ready() -> void:
	mass = 60.0
	angular_damp = 1.0
	can_sleep = false
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0, -0.35, 0)
	physics_material_override = PhysicsMaterial.new()
	physics_material_override.friction = 0.0
	add_to_group("grabbable")

	var shape := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.26
	cap.height = 1.75
	shape.shape = cap
	add_child(shape)
	_build_model()

	for side in [-1.0, 1.0]:
		var hand := RigidBody3D.new()
		hand.mass = 2.0
		hand.can_sleep = false
		hand.linear_damp = 0.5
		var hs := CollisionShape3D.new()
		var sph := SphereShape3D.new()
		sph.radius = 0.08
		hs.shape = sph
		hand.add_child(hs)
		hand.position = to_global(_hand_target_local(side))
		hand.add_collision_exception_with(self)
		for other in hands:
			hand.add_collision_exception_with(other)
		get_parent().add_child.call_deferred(hand)
		hands.append(hand)


## 第一人称时：自己的身体对第一人称镜头隐身，只露出两只手
func set_first_person_owner() -> void:
	for mi in _model.find_children("*", "MeshInstance3D", true, false):
		mi.layers = 1 << (FP_HIDDEN_LAYER - 1)
	for hand in hands:
		var m := Art.mesh(Art.sphere(0.07), Art.SKIN)
		m.layers = 1 << (FP_ONLY_LAYER - 1)
		hand.add_child(m)


func _build_model() -> void:
	_model = MODEL.instantiate()
	_model.rotation.y = PI  # 模型面朝 +Z，我们的“前方”是 -Z
	add_child(_model)
	for mi in _model.find_children("*", "MeshInstance3D", true, false):
		if mi.name.begins_with("Icosphere"):
			mi.visible = false  # 绑骨结果里附带的辅助球，不要
			continue
		# 生成的模型偏光滑塑料感，统一压成哑光
		for i in mi.mesh.get_surface_count():
			var src: Material = mi.mesh.surface_get_material(i)
			if src is BaseMaterial3D:
				var m: BaseMaterial3D = src.duplicate()
				m.roughness = 1.0
				m.metallic = 0.0
				m.metallic_specular = 0.15
				mi.set_surface_override_material(i, m)
	_skeleton = _model.find_children("*", "Skeleton3D", true, false).front()
	for bone_name in ["LeftArm", "RightArm"]:
		var idx := _skeleton.find_bone("mixamorig:" + bone_name)
		if idx < 0:
			idx = _skeleton.find_bone("mixamorig_" + bone_name)
		_arm_bones.append(idx)


func _physics_process(_delta: float) -> void:
	var dir := move_dir.limit_length(1.0)
	var grounded := _is_grounded()

	# 移动：力作用在腰部以下，起步和刹车时身体会自己晃
	var vel_h := Vector3(linear_velocity.x, 0, linear_velocity.z)
	var force := (dir * SPEED - vel_h) * mass * MOVE_ACCEL
	force = force.limit_length(MOVE_MAX_FORCE * (1.0 if grounded else 0.25))
	apply_force(force, global_basis.y * -0.45)

	# 保持站立：力度有限，负重太大就会被压歪
	var av := angular_velocity
	apply_torque(global_basis.y.cross(Vector3.UP) * UPRIGHT_K - Vector3(av.x, 0, av.z) * UPRIGHT_D)

	var yaw_torque := -av.y * YAW_D
	var fwd := -global_basis.z
	if face_yaw != null:
		var err := wrapf(float(face_yaw) - atan2(-fwd.x, -fwd.z), -PI, PI)
		if absf(err) > face_deadzone:
			yaw_torque += (err - signf(err) * face_deadzone) * YAW_K
	elif dir.length() > 0.1 and not is_holding():
		fwd.y = 0
		yaw_torque += fwd.signed_angle_to(dir, Vector3.UP) * YAW_K
	apply_torque(Vector3.UP * yaw_torque)

	if grounded and dir.length() > 0.1 and _step_ahead(dir):
		linear_velocity.y = maxf(linear_velocity.y, 2.2)
	if want_jump and not _jump_was_down and grounded:
		apply_central_impulse(Vector3.UP * JUMP_SPEED * mass)
	_jump_was_down = want_jump

	bend = clampf((-reach_pitch - 0.3) / 0.9, 0.0, 1.0)
	for i in 2:
		_drive_hand(i)


func _process(_delta: float) -> void:
	if _skeleton == null or hands.is_empty() or not hands[0].is_inside_tree():
		return
	# 往下够的时候整个人以胯部为轴往前倾
	var pivot := Vector3(0, -0.13, 0)
	var lean := Basis(Vector3.RIGHT, -bend * MAX_BEND)
	_model.transform = Transform3D(lean * Basis(Vector3.UP, PI), pivot - lean * pivot)
	# 让模型的上臂骨骼指向物理手，整条手臂就跟着手走
	var to_skel := _skeleton.global_transform.affine_inverse()
	for i in 2:
		var bone := _arm_bones[i]
		if bone < 0:
			continue
		var parent := _skeleton.get_bone_parent(bone)
		var parent_pose := _skeleton.get_bone_global_pose(parent)
		var rest := parent_pose * _skeleton.get_bone_rest(bone)
		var dir := (to_skel * hands[i].global_position) - rest.origin
		if dir.length() < 0.01:
			continue
		var aimed := Basis(Quaternion(rest.basis.y.normalized(), dir.normalized())) * rest.basis
		_skeleton.set_bone_pose_rotation(bone, (parent_pose.basis.inverse() * aimed).get_rotation_quaternion())


func is_holding() -> bool:
	return grabs[0] != null or grabs[1] != null


func holds(body: Node) -> bool:
	return held[0] == body or held[1] == body


## 手的目标位置（身体局部坐标）：从肩膀沿 reach_pitch 方向伸出去。
## 往下够时弯腰，手主要往下伸（能碰到地面），往前只伸一点，落在脚前方不远处。
func _hand_target_local(side: float) -> Vector3:
	var p := clampf(reach_pitch, -1.35, 1.1)
	var lift := LIFT_HEIGHT if is_holding() else 0.0
	var down_reach := lerpf(0.5, 1.25, bend)
	return Vector3(HAND_SPREAD * side, SHOULDER.y + lift, 0) + Vector3(0, sin(p) * down_reach, -cos(p) * 0.5)


func _drive_hand(i: int) -> void:
	var hand := hands[i]
	if not hand.is_inside_tree():
		return
	var side := -1.0 if i == 0 else 1.0
	var target := to_global(_hand_target_local(side))
	var shoulder := to_global(Vector3(SHOULDER.x * side, SHOULDER.y, 0))
	if hand.global_position.distance_to(shoulder) > 2.2:
		# 手被扯得太远：松手，弹回来
		_release(i)
		hand.global_position = target
		hand.linear_velocity = linear_velocity
		return
	var f := (target - hand.global_position) * HAND_K + (linear_velocity - hand.linear_velocity) * HAND_D
	f = f.limit_length(HAND_MAX_FORCE)
	hand.apply_central_force(f)
	apply_force(-f, shoulder - global_position)

	if want_grab[i]:
		if grabs[i] == null:
			_try_grab(i)
	else:
		_release(i)


func _try_grab(i: int) -> void:
	var hand := hands[i]
	var q := PhysicsShapeQueryParameters3D.new()
	var s := SphereShape3D.new()
	s.radius = GRAB_RADIUS
	q.shape = s
	q.transform = Transform3D(Basis.IDENTITY, hand.global_position)
	q.exclude = [get_rid(), hands[0].get_rid(), hands[1].get_rid()]
	for hit in get_world_3d().direct_space_state.intersect_shape(q, 8):
		var body: Object = hit.collider
		if body is RigidBody3D and body.is_in_group("grabbable"):
			var j := Generic6DOFJoint3D.new()
			get_parent().add_child(j)
			j.global_position = hand.global_position
			j.node_a = j.get_path_to(hand)
			j.node_b = j.get_path_to(body)
			grabs[i] = j
			held[i] = body
			return


func release_all() -> void:
	for i in 2:
		_release(i)


func _release(i: int) -> void:
	if grabs[i] != null:
		grabs[i].queue_free()
		grabs[i] = null
		held[i] = null


func _is_grounded() -> bool:
	var q := PhysicsRayQueryParameters3D.create(global_position, global_position + Vector3.DOWN * 1.05)
	q.exclude = [get_rid(), hands[0].get_rid(), hands[1].get_rid()]
	return not get_world_3d().direct_space_state.intersect_ray(q).is_empty()


## 前方脚边有矮障碍（台阶），膝盖高度却是空的 → 可以迈上去
func _step_ahead(dir: Vector3) -> bool:
	var feet := global_position + Vector3.DOWN * 0.8
	var space := get_world_3d().direct_space_state
	var excl: Array[RID] = [get_rid(), hands[0].get_rid(), hands[1].get_rid()]
	var low := PhysicsRayQueryParameters3D.create(feet, feet + dir.normalized() * 0.5)
	low.exclude = excl
	var high := PhysicsRayQueryParameters3D.create(feet + Vector3.UP * 0.35, feet + Vector3.UP * 0.35 + dir.normalized() * 0.5)
	high.exclude = excl
	return not space.intersect_ray(low).is_empty() and space.intersect_ray(high).is_empty()
