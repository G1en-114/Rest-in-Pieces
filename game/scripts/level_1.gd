class_name Level1
extends Node3D
## 第一关「殡仪馆的一天」：停棺间 → L 形走廊（花圈）→ 视错觉断桥 → 灵堂。
##
## 断桥的原理（纪念碑谷式）：上层桥头和下层桥尾在空间里是错开的（差 BRIDGE_OFFSET），
## 但偏移方向正好沿着 ALIGN_YAW 视角的视线，所以固定视角转到这个角度时，画面上两段桥连成一条。
## 对齐时两边各有一段隐形的“幽灵地面”打开，队伍走过接缝，main.gd 会把整队一起平移过去。

signal bonus(amount: float, text: String)

const COFFIN_START := Vector3(0, 1.32, 0)
const GOAL := Vector3(-29, -4.63, -8.69)
const ALIGN_YAW := 135.0  # 固定视角转到这个角度，断桥才接得上
const SEAM_X := -16.0  # 上层桥头的接缝
const BRIDGE_Z := -12.4
const BRIDGE_WIDTH := 3.2
const GHOST_LEN := 1.6
const KILL_Y := -10.0
## 下层 = 上层 + 偏移；偏移方向就是 ALIGN_YAW 视角的视线方向（远离镜头）
const BRIDGE_OFFSET := Vector3(-3.71, -4.63, 3.71)
const CHECKPOINT_UPPER := Vector3(-10.5, 0, BRIDGE_Z)
const CHECKPOINT_LOWER := Vector3(-22.0, -4.63, BRIDGE_Z + 3.71)

## 自动测试用的路线（棺材中心的水平位置）；"align" 表示停下转视角，"cross" 表示走到被传送为止
const BOT_PATH := [
	Vector3(0, 0, -6), Vector3(0, 0, -12.4), Vector3(-14.4, 0, -12.4), "align", "cross",
	Vector3(-23, 0, -8.69), Vector3(-29, 0, -8.69),
]

const WALL_H := 1.6
const WALL_T := 0.3
const C_WALL := Color(0.95, 0.92, 0.86)
const C_ROOM := Color(0.86, 0.78, 0.72)
const C_CORRIDOR := Color(0.55, 0.74, 0.76)
const C_BRIDGE := Color(0.93, 0.62, 0.55)
const C_HALL := Color(0.8, 0.76, 0.88)

var _ghosts: Array[CollisionShape3D] = []
var _font: SystemFont


func _ready() -> void:
	_font = SystemFont.new()
	_font.font_names = PackedStringArray(["Microsoft YaHei", "SimHei", "Noto Sans CJK SC"])
	_build_room_1()
	_build_corridor()
	_build_bridge()
	_build_hall()


func set_bridge(aligned: bool) -> void:
	for g in _ghosts:
		g.disabled = not aligned


# ---------- 1 停棺间 ----------

func _build_room_1() -> void:
	_floor(Vector3(-4, 0, -4), Vector3(4, 0, 4), C_ROOM)
	_wall_x(4.0, -4.0, 4.0)
	_wall_z(4.0, -4.0, 4.0)
	_wall_z(-4.0, -4.0, 4.0)
	_wall_x(-4.0, -4.0, -1.6)
	_wall_x(-4.0, 1.6, 4.0)
	for x in [-0.7, 0.7]:  # 停棺架
		_box(Vector3(0.3, 1.09, 0.7), Vector3(x, 0.545, 0), Color(0.25, 0.25, 0.27), false)
	_sign("抓住把手，把棺材抬出去", Vector3(0, 2.6, -3.6))


# ---------- 2 L 形走廊 ----------

func _build_corridor() -> void:
	_floor(Vector3(-1.6, 0, -14), Vector3(1.6, 0, -4), C_CORRIDOR)
	_floor(Vector3(-12, 0, -14), Vector3(-1.6, 0, -10.8), C_CORRIDOR)
	_wall_z(1.6, -14.0, -4.0)
	_wall_z(-1.6, -10.8, -4.0)
	_wall_x(-14.0, -12.0, 1.6)
	_wall_x(-10.8, -12.0, -1.6)
	_wreath(Vector3(0, 0, -12.4))


func _wreath(pos: Vector3) -> void:
	var area := Area3D.new()
	area.position = pos + Vector3.UP * 0.9
	var cs := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 0.9
	cs.shape = sph
	area.add_child(cs)
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.28
	torus.outer_radius = 0.45
	ring.mesh = torus
	ring.material_override = Art.mat(Color(0.16, 0.45, 0.22))
	ring.rotation.x = PI / 2
	area.add_child(ring)
	for i in 8:
		var a := TAU * i / 8.0
		var c := Color(0.97, 0.97, 0.95) if i % 2 == 0 else Color(0.98, 0.82, 0.3)
		area.add_child(Art.mesh(Art.sphere(0.08), c, Vector3(cos(a) * 0.37, sin(a) * 0.37, 0.05)))
	area.add_child(_label3d("花圈 +15", Vector3(0, 0.75, 0), 48))
	add_child(area)
	var tween := create_tween().set_loops()
	tween.tween_property(ring, "rotation:z", TAU, 4.0).from(0.0)
	area.body_entered.connect(func(body: Node) -> void:
		if body is Bearer:
			bonus.emit(15.0, "捡到花圈！体面 +15")
			area.queue_free())


# ---------- 3 视错觉断桥 ----------

func _build_bridge() -> void:
	var z0 := BRIDGE_Z - BRIDGE_WIDTH / 2
	var z1 := BRIDGE_Z + BRIDGE_WIDTH / 2
	# 上层桥头：走廊出来直走到接缝
	_floor(Vector3(SEAM_X, 0, z0), Vector3(-12, 0, z1), C_BRIDGE)
	# 下层桥尾：从接缝的“另一头”通往灵堂
	var lower_start := SEAM_X + BRIDGE_OFFSET.x
	_floor(Vector3(-24, BRIDGE_OFFSET.y, z0 + BRIDGE_OFFSET.z), Vector3(lower_start, BRIDGE_OFFSET.y, z1 + BRIDGE_OFFSET.z), C_BRIDGE)
	# 两段幽灵地面：只在对齐时打开，让接缝两边都站得住人
	_ghost(Vector3(SEAM_X - GHOST_LEN, 0, z0), Vector3(SEAM_X, 0, z1))
	_ghost(Vector3(lower_start, BRIDGE_OFFSET.y, z0 + BRIDGE_OFFSET.z),
		Vector3(lower_start + GHOST_LEN, BRIDGE_OFFSET.y, z1 + BRIDGE_OFFSET.z))
	set_bridge(false)
	_sign("桥断了？\n按 Q / E 转动视角试试", Vector3(-13.5, 2.4, BRIDGE_Z))


func _ghost(a: Vector3, b: Vector3) -> void:
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(absf(b.x - a.x), 0.5, absf(b.z - a.z))
	cs.shape = shape
	body.position = Vector3((a.x + b.x) / 2, a.y - 0.25, (a.z + b.z) / 2)
	body.add_child(cs)
	add_child(body)
	_ghosts.append(cs)


# ---------- 4 灵堂 ----------

func _build_hall() -> void:
	var y := BRIDGE_OFFSET.y
	var zc := BRIDGE_Z + BRIDGE_OFFSET.z
	_floor(Vector3(-32, y, zc - 4), Vector3(-24, y, zc + 4), C_HALL)
	_wall_z(-32.0, zc - 4, zc + 4, y)
	_wall_x(zc - 4, -32.0, -24.0, y)
	_wall_x(zc + 4, -32.0, -24.0, y)
	_wall_z(-24.0, zc - 4, zc - BRIDGE_WIDTH / 2, y)
	_wall_z(-24.0, zc + BRIDGE_WIDTH / 2, zc + 4, y)
	_box(Vector3(2.6, 0.4, 1.4), GOAL + Vector3(0, 0.2, 0), Color(0.97, 0.96, 0.92), false)
	# 遗像和蜡烛
	_box(Vector3(0.9, 1.1, 0.08), Vector3(GOAL.x - 2.6, y + 1.2, GOAL.z), Color(0.1, 0.1, 0.1), false)
	for s in [-1.0, 1.0]:
		add_child(Art.mesh(Art.capsule(0.05, 0.4), Color(0.97, 0.95, 0.85), GOAL + Vector3(-0.9, 0.6, s * 0.9)))
		var flame := OmniLight3D.new()
		flame.light_color = Color(1.0, 0.75, 0.4)
		flame.omni_range = 3.0
		flame.position = GOAL + Vector3(-0.9, 0.9, s * 0.9)
		add_child(flame)
	_sign("灵台：把棺材放稳", GOAL + Vector3(0, 2.2, 0))


# ---------- 搭建小工具 ----------

## 一块地板：a、b 是对角（只看 x、z），y 是地面高度
func _floor(a: Vector3, b: Vector3, color: Color) -> void:
	var size := Vector3(absf(b.x - a.x), 0.5, absf(b.z - a.z))
	_box(size, Vector3((a.x + b.x) / 2, a.y - 0.25, (a.z + b.z) / 2), color, true)


## 沿 X 方向的墙（固定 z）
func _wall_x(z: float, x0: float, x1: float, y := 0.0) -> void:
	_box(Vector3(x1 - x0, WALL_H, WALL_T), Vector3((x0 + x1) / 2, y + WALL_H / 2, z), C_WALL, true)


## 沿 Z 方向的墙（固定 x）
func _wall_z(x: float, z0: float, z1: float, y := 0.0) -> void:
	_box(Vector3(WALL_T, WALL_H, z1 - z0), Vector3(x, y + WALL_H / 2, (z0 + z1) / 2), C_WALL, true)


func _box(size: Vector3, pos: Vector3, color: Color, hard: bool) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	if hard:
		body.add_to_group("hard")
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = size
	cs.shape = b
	body.add_child(cs)
	body.add_child(Art.mesh(Art.box(size), color))
	add_child(body)


func _sign(text: String, pos: Vector3) -> void:
	add_child(_label3d(text, pos, 64))


func _label3d(text: String, pos: Vector3, size: int) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font = _font
	l.font_size = size
	l.outline_size = 12
	l.pixel_size = 0.006
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.position = pos
	return l
