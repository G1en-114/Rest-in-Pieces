class_name NetSync
extends RefCounted
## 联机同步（客户端这一侧）：缓存房主发来的快照，显示时比房主慢一点点，
## 在前后两个快照之间插值，这样网络有抖动也看不出瞬移。
##
## 快照格式：每个刚体 7 个数（位置 xyz + 四元数 xyzw），顺序和 main.gd 的 _team_bodies() 一致。

const PORT := 7777
const SEND_EVERY := 4  # 物理 120 帧/秒，每 4 帧发一次快照 = 30 次/秒
const INPUT_EVERY := 2  # 客户端每 2 帧发一次按键 = 60 次/秒
const INTERP_DELAY := 0.1  # 显示比房主慢 0.1 秒，手里总有前后两个快照可插
const SNAP_DIST := 2.0  # 两个快照之间跳得比这还远（过断桥）就直接瞬移，不插值

var _snaps: Array = []  # [[房主时间, PackedFloat32Array], ...]，按时间排好
var _offset := 0.0  # 房主时间 - 本地时间
var _has_offset := false


static func pack(bodies: Array[RigidBody3D]) -> PackedFloat32Array:
	var data := PackedFloat32Array()
	data.resize(bodies.size() * 7)
	var i := 0
	for b in bodies:
		var p := b.global_position
		var q := b.global_basis.get_rotation_quaternion()
		for v in [p.x, p.y, p.z, q.x, q.y, q.z, q.w]:
			data[i] = v
			i += 1
	return data


static func now() -> float:
	return Time.get_ticks_usec() / 1e6


## 现在该显示房主哪一刻的画面（还没收到快照时返回 -1）
func render_time() -> float:
	return now() + _offset - INTERP_DELAY if _has_offset else -1.0


func clear() -> void:
	_snaps.clear()


func push(host_time: float, data: PackedFloat32Array) -> void:
	var target := host_time - now()
	# 时钟偏差慢慢跟：网络抖动只会让它小幅摆动，不会让画面忽快忽慢
	_offset = target if not _has_offset else lerpf(_offset, target, 0.05)
	_has_offset = true
	if not _snaps.is_empty() and host_time <= _snaps.back()[0]:
		return  # 乱序到达的旧包
	_snaps.append([host_time, data])
	while _snaps.size() > 2 and _snaps[1][0] < host_time - 1.0:
		_snaps.pop_front()


## 把插值后的位置写到各个刚体上
func apply(bodies: Array[RigidBody3D]) -> void:
	if _snaps.is_empty():
		return
	var t := now() + _offset - INTERP_DELAY
	var a: PackedFloat32Array = _snaps.back()[1]
	var b := a
	var w := 0.0
	for k in range(_snaps.size() - 1, 0, -1):
		if _snaps[k - 1][0] <= t:
			a = _snaps[k - 1][1]
			b = _snaps[k][1]
			w = clampf(inverse_lerp(_snaps[k - 1][0], _snaps[k][0], t), 0.0, 1.0)
			break
	if a.size() != bodies.size() * 7 or b.size() != a.size():
		return
	for i in bodies.size():
		var o := i * 7
		var pa := Vector3(a[o], a[o + 1], a[o + 2])
		var pb := Vector3(b[o], b[o + 1], b[o + 2])
		var qa := Quaternion(a[o + 3], a[o + 4], a[o + 5], a[o + 6]).normalized()
		var qb := Quaternion(b[o + 3], b[o + 4], b[o + 5], b[o + 6]).normalized()
		if pa.distance_to(pb) > SNAP_DIST:
			pa = pb
			qa = qb
		bodies[i].global_transform = Transform3D(Basis(qa.slerp(qb, w)), pa.lerp(pb, w))
