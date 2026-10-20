class_name Coffin
extends RigidBody3D
## 一口没盖子的棺材：底板 + 四面墙，两侧各一根铜把手横杆。开口朝上，里面的人会被颠出来。

const LENGTH := 2.0
const WIDTH := 0.66
const HEIGHT := 0.45
const WALL := 0.06
const RAIL_OFFSET := 0.045


func _ready() -> void:
	mass = 35.0
	can_sleep = false
	contact_monitor = true
	max_contacts_reported = 8
	add_to_group("grabbable")
	var wood := Color(0.33, 0.19, 0.11)
	var brass := Color(0.86, 0.66, 0.26)
	_part(Vector3(LENGTH, WALL, WIDTH), Vector3(0, -HEIGHT / 2 + WALL / 2, 0), wood)
	for s in [-1.0, 1.0]:
		_part(Vector3(LENGTH, HEIGHT, WALL), Vector3(0, 0, s * (WIDTH / 2 - WALL / 2)), wood)
		_part(Vector3(WALL, HEIGHT, WIDTH - 2 * WALL), Vector3(s * (LENGTH / 2 - WALL / 2), 0, 0), wood)
		_part(Vector3(LENGTH * 0.8, 0.05, 0.05), Vector3(0, 0, s * (WIDTH / 2 + RAIL_OFFSET)), brass)
		for x in [-0.6, 0.0, 0.6]:  # 把手和棺身之间的连接块
			add_child(Art.mesh(Art.box(Vector3(0.05, 0.05, RAIL_OFFSET)), brass,
				Vector3(x, 0, s * (WIDTH / 2 + RAIL_OFFSET / 2))))
	# 红色内衬（只是好看）
	add_child(Art.mesh(Art.box(Vector3(LENGTH - 2 * WALL, 0.01, WIDTH - 2 * WALL)), Color(0.7, 0.1, 0.13),
		Vector3(0, -HEIGHT / 2 + WALL + 0.005, 0)))


func _part(size: Vector3, pos: Vector3, color: Color) -> void:
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = size
	cs.shape = b
	cs.position = pos
	add_child(cs)
	add_child(Art.mesh(Art.box(size), color, pos))


## 某个世界坐标点是否在棺材里面（用来判断逝者有没有掉出去）
func contains(world_pos: Vector3) -> bool:
	var p := to_local(world_pos)
	return absf(p.x) < LENGTH / 2 + 0.05 and absf(p.z) < WIDTH / 2 + 0.03 and p.y > -HEIGHT and p.y < HEIGHT
