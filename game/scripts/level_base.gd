class_name Level
extends Node3D
## 关卡基类：房间列表、灵台、机关接口，以及搭场景用的小工具。
##
## 每关一个子类（scripts/levels/*.gd）。房间列表在 _init() 里填好，这样选关界面 new() 一下就能读到
## 房间名，不用真的搭场景；场景在 _ready() 里搭。
##
## 房间字段：
##   name    房间名
##   spawn   检查点：棺材正下方的地面点
##   yaw     整队朝向（0 = 棺材沿 X 放，两个抬棺人站在 ±Z 两侧）
##   lift    棺材离地多高（默认 0.24，平放在地上；停棺架上更高）
##   path    电脑队伍路线，见下
##   kill_y  可选：这间屋子里掉到多低算坠落（默认用关卡的 kill_y）
##
## 路线里的每一项：
##   Vector3         棺材中心要走到的水平位置（y 不管）
##   "wait:<标签>"   原地等，直到 bot_can_go(标签) 为真
##   {dir, until}    朝 dir 一直走，直到 bot_can_go(until) 为真

signal bonus(amount: float, text: String)
signal notice(text: String)
signal penalty(amount: float, text: String)

## 只有第一人称镜头渲染这一层（给第一人称的提示，比如断桥接上时的虚线）
const HINT_LAYER := 6
const WALL_H := 1.6
const WALL_T := 0.3
const EYE_HEIGHT := 1.67  # 第一人称眼睛离脚下地面多高（抬棺人身体中心 0.87 + 镜头 0.8）
const PHOTO_POS_TOL := 0.7  # 拍照时眼睛离拍照点多近才算
const PHOTO_ANGLE_TOL := 7.0  # 镜头朝向和该看的方向差几度以内才算

## 所有关卡，按选关界面的顺序
const LEVELS := [
	{id = "china", country = "中国", title = "殡仪馆的一天", script = "res://scripts/levels/china.gd"},
	{id = "egypt", country = "埃及", title = "法老的最后一程", script = "res://scripts/levels/egypt.gd"},
	{id = "mexico", country = "墨西哥", title = "万寿菊之路", script = "res://scripts/levels/mexico.gd"},
]

var id := ""
var title := ""
var par_time := 300.0  # 标准用时（秒）：快于它结算时 +10
var rooms: Array = []
var goal_pos := Vector3.ZERO  # 灵台底面中心
var goal_size := Vector3(2.6, 0.4, 1.4)  # 灵台的长、高、宽（世界坐标轴向）
var kill_y := -10.0
var game: Node  # main.gd，搭场景前由它填上

var _m := {}  # 各区域的材质
var prefer_first_person := false  # 主打第一人称的关卡：一进来就是第一人称
var _illusions: Array = []  # 拍照固定的视错觉：{eye, dir, fill_mesh, fill_cs, grey, fixed}
var _photo_mat: Material
var _last_block: MeshInstance3D  # 刚搭的那块地面的外观（给视错觉拿去变灰）


static func create(level_id: String) -> Level:
	for l in LEVELS:
		if l.id == level_id and ResourceLoader.exists(l.script):
			return load(l.script).new()
	return null


static func info(level_id: String) -> Dictionary:
	for l in LEVELS:
		if l.id == level_id:
			return l
	return {}


## 下一关的 id；已经是最后一关（或下一关还没做）就返回 ""
static func next_id(level_id: String) -> String:
	for i in LEVELS.size() - 1:
		if LEVELS[i].id == level_id and ResourceLoader.exists(LEVELS[i + 1].script):
			return LEVELS[i + 1].id
	return ""


# ---------- 接口（子类按需覆盖） ----------

## 这个点（通常是棺材）在第几个房间
func room_at(_pos: Vector3) -> int:
	return 0


func room_kill_y(room: int) -> float:
	return rooms[room].get("kill_y", kill_y)


## 天空、雾、太阳的参数，main.gd 拿去覆盖默认值（键名见 main.gd 的 ENV_DEFAULT）
func env() -> Dictionary:
	return {}


## 按时间运动的机关。房主每个物理帧用 sim_time 调；加入方用插值后的房主时间调，两边一致
func tick(_t: float) -> void:
	pass


## 房主每个物理帧调一次：有状态的关卡逻辑（断桥平移、塌陷地板、压力板）
func physics_update(_game: Node) -> void:
	pass


## 需要联机同步位置的刚体（石块、滚石），接在整队刚体后面一起进快照；数量和顺序不能变
func net_bodies() -> Array[RigidBody3D]:
	return []


## 有状态机关的联机状态（加入方拿去 apply_net_state）
func net_state() -> PackedFloat32Array:
	return PackedFloat32Array()


func apply_net_state(_a: PackedFloat32Array) -> void:
	pass


## 自动测试日志里附带的关卡状态（机关位置之类）
func debug_text() -> String:
	return ""


# ---------- 拍照固定视错觉 ----------

## 一处拍照固定的视错觉断口（路都沿 -Z 方向走）。
## 站在 vantage（地面点）用第一人称往 a 看：a 是近处这段路的尽头。远处那段路的起点 b 就在同一条视线上、远 s 倍，
## 宽和长也放大 s 倍，所以从这里看，两段路严丝合缝地接在一起；换个地方一看就露馅：中间是空的，远处那段更低（或更高）。
## 在这个角度拍照，a 和 b 之间长出一段灰色的“照片”路面。它正好沿着视线，从拍照点看画面一点没变，但现在是实的了。
## near_grey：近处那段路要一起变灰的外观。返回远处那段路（far_len 是放大前的长度）的终点
func _photo_gap(vantage: Vector3, a: Vector3, s: float, width: float, far_len: float, far_mat: Material,
		near_grey: Array = []) -> Vector3:
	if _photo_mat == null:
		# 不受光照影响的平涂灰：在黄昏的暖光里也一眼看得出“这一块是照片”
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = Color(0.62, 0.62, 0.64)
		_photo_mat = m
	var eye := vantage + Vector3(0, EYE_HEIGHT, 0)
	var b := eye + (a - eye) * s
	var far_w := width * s
	var end := b + Vector3(0, 0, -far_len * s)
	_floor(Vector3(b.x - far_w / 2, b.y, b.z), Vector3(b.x + far_w / 2, b.y, end.z), far_mat, 2.0 * s)
	var grey: Array = near_grey.duplicate()
	grey.append(_last_block)
	var fill: Array = _ramp(a, b, width, _photo_mat, 0.3)
	fill[0].disabled = true
	fill[1].visible = false
	var marker := _camera_marker()
	marker.position = vantage
	add_child(marker)
	_illusions.append({eye = eye, dir = (a - eye).normalized(), fill_cs = fill[0], fill_mesh = fill[1], grey = grey,
		fixed = false, marker = marker})
	return end


## 拍照点的标记：一台架在三脚架上的老式相机，地上画个圈
func _camera_marker() -> Node3D:
	var n := Node3D.new()
	var ring := Art.mesh(Art.cylinder(0.55, 0.55, 0.01, 24), Props.GOLD, Vector3(0, 0.006, 0))
	n.add_child(ring)
	n.add_child(Art.mesh(Art.cylinder(0.48, 0.48, 0.012, 24), Color(0.25, 0.2, 0.22), Vector3(0, 0.008, 0)))
	for k in 3:
		var a := TAU * k / 3.0
		var leg := Art.mesh(Art.cylinder(0.015, 0.015, 1.3), Props.WOOD, Vector3(cos(a) * 0.25, 0.62, sin(a) * 0.25 + 0.6))
		leg.rotation = Vector3(-sin(a) * 0.35, 0, cos(a) * 0.35)
		n.add_child(leg)
	n.add_child(Art.mesh(Art.box(Vector3(0.28, 0.2, 0.2)), Props.BLACK, Vector3(0, 1.3, 0.6)))
	n.add_child(Art.mesh(Art.cylinder(0.06, 0.07, 0.12), Color(0.3, 0.3, 0.32), Vector3(0, 1.3, 0.47)))
	var tip := _label3d("拍照点：站在圈里往前看", Vector3(0, 2.0, 0.3), 40)
	tip.modulate = Color(1.0, 0.9, 0.55)
	n.add_child(tip)
	return n


## 用这个镜头位置拍照：对上了哪处视错觉就把它固定下来，返回它的序号（没对上返回 -1）
func try_photo(xf: Transform3D) -> int:
	for i in _illusions.size():
		var il: Dictionary = _illusions[i]
		if il.fixed:
			continue
		if xf.origin.distance_to(il.eye) < PHOTO_POS_TOL \
				and rad_to_deg((-xf.basis.z).angle_to(il.dir)) < PHOTO_ANGLE_TOL:
			fix_illusion(i)
			return i
	return -1


## 取景框上的提示：离最近一处没拍的视错觉还差多少
func photo_hint(xf: Transform3D) -> Dictionary:
	var best := -1
	var best_d := 12.0
	for i in _illusions.size():
		var d: float = xf.origin.distance_to(_illusions[i].eye)
		if not _illusions[i].fixed and d < best_d:
			best = i
			best_d = d
	if best < 0:
		return {aligned = false, text = ""}
	if best_d > PHOTO_POS_TOL:
		return {aligned = false, text = "走到地上那个相机标记的圈里"}
	var ang := rad_to_deg((-xf.basis.z).angle_to(_illusions[best].dir))
	if ang > PHOTO_ANGLE_TOL:
		return {aligned = false, text = "往前面那段路的尽头看（还差 %d°）" % int(ang)}
	return {aligned = true, text = "就是这个角度！两段路接上了"}


func fix_illusion(i: int) -> void:
	var il: Dictionary = _illusions[i]
	if il.fixed:
		return
	il.fixed = true
	il.fill_cs.disabled = false
	il.fill_mesh.visible = true
	for m in il.grey:
		m.material_override = _photo_mat
	il.marker.visible = false


func illusion_mask() -> int:
	var m := 0
	for i in _illusions.size():
		if _illusions[i].fixed:
			m |= 1 << i
	return m


func apply_illusion_mask(m: int) -> void:
	for i in _illusions.size():
		if m & (1 << i):
			fix_illusion(i)


## 电脑队伍在 "wait:<标签>" 处能不能出发
func bot_can_go(_tag: String) -> bool:
	return true


## 这个点是不是在灵台上方：xz 落在台面里（可以放宽 margin），高度在台面以上 max_h 以内
func on_altar(p: Vector3, margin := 0.0, max_h := 1.0) -> bool:
	var top := goal_pos.y + goal_size.y
	return absf(p.x - goal_pos.x) < goal_size.x / 2 + margin and absf(p.z - goal_pos.z) < goal_size.z / 2 + margin \
		and p.y > top - 0.15 and p.y < top + max_h


# ---------- 搭建小工具 ----------

## 一块地面：a、b 是对角（只看 x、z），a.y 是地面高度。
## 碰撞固定 0.5 米厚，外观可以更厚，像悬在空中的石块
func _floor(a: Vector3, b: Vector3, material: Material, thick := 0.5, hard := true) -> StaticBody3D:
	var size := Vector3(absf(b.x - a.x), 0.5, absf(b.z - a.z))
	var center := Vector3((a.x + b.x) / 2, a.y - 0.25, (a.z + b.z) / 2)
	var body := _collider(size, center, hard)
	_last_block = Art.block(Vector3(size.x, thick, size.z), Vector3(center.x, a.y - thick / 2, center.z), material)
	add_child(_last_block)
	return body


## 沿 X 方向的墙（固定 z）
func _wall_x(z: float, x0: float, x1: float, y := 0.0, material: Material = null, h := WALL_H) -> void:
	_wall(Vector3(absf(x1 - x0), h, WALL_T), Vector3((x0 + x1) / 2, y + h / 2, z), material)


## 沿 Z 方向的墙（固定 x）
func _wall_z(x: float, z0: float, z1: float, y := 0.0, material: Material = null, h := WALL_H) -> void:
	_wall(Vector3(WALL_T, h, absf(z1 - z0)), Vector3(x, y + h / 2, (z0 + z1) / 2), material)


func _wall(size: Vector3, pos: Vector3, material: Material) -> void:
	_collider(size, pos, true)
	add_child(Art.block(size, pos, material if material else _m.wall))


func _collider(size: Vector3, pos: Vector3, hard: bool) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = pos
	if hard:
		body.add_to_group("hard")
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = size
	cs.shape = b
	body.add_child(cs)
	add_child(body)
	return body


## 看不见的碰撞盒，给会挡路的道具用（撞上不扣分）
func _solid(size: Vector3, pos: Vector3) -> StaticBody3D:
	return _collider(size, pos, false)


## 带外观的纯色方块（停棺架、供桌、灵台）
func _box(size: Vector3, pos: Vector3, color: Color, hard: bool) -> void:
	_collider(size, pos, hard)
	add_child(Art.mesh(Art.box(size), color, pos))


func _put(node: Node3D, pos: Vector3, yaw := 0.0) -> Node3D:
	node.position += pos
	node.rotation.y = yaw
	add_child(node)
	return node


func _lamp(pos: Vector3, energy: float, reach: float, color := Color(1.0, 0.84, 0.62)) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.light_color = color
	l.light_energy = energy
	l.omni_range = reach
	l.position = pos
	add_child(l)
	return l


func _sign(text: String, pos: Vector3) -> Label3D:
	var l := _label3d(text, pos, 64)
	add_child(l)
	return l


func _label3d(text: String, pos: Vector3, size: int) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font = Art.font()
	l.font_size = size
	l.outline_size = 12
	l.pixel_size = 0.006
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.position = pos
	return l


## 一段斜坡：a、b 是坡面中线低端和高端的点（也可以反过来），width 是坡宽。碰撞 0.5 米厚，外观 thick 厚
func _ramp(a: Vector3, b: Vector3, width: float, material: Material, thick := 0.5, hard := false) -> Array:
	var d := b - a
	var basis := Basis.looking_at(d.normalized(), Vector3.UP)  # 局部 -Z 沿坡面，局部 Y 是坡面法线
	var center := (a + b) / 2
	var body := StaticBody3D.new()
	if hard:
		body.add_to_group("hard")
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(width, 0.5, d.length())
	cs.shape = shape
	body.add_child(cs)
	body.transform = Transform3D(basis, center - basis.y * 0.25)
	add_child(body)
	var mi := Art.block(Vector3.ONE, Vector3.ZERO, material)
	mi.transform = Transform3D(basis * Basis.from_scale(Vector3(width, thick, d.length())), center - basis.y * thick / 2)
	add_child(mi)
	return [cs, mi]


## 一个会转的花圈：抬棺人碰到就加分
func _wreath(pos: Vector3, amount := 15.0, radius := 0.9, color := Color(0.16, 0.45, 0.22), label := "花圈") -> void:
	var area := Area3D.new()
	area.position = pos + Vector3.UP * 0.9
	var cs := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = radius
	cs.shape = sph
	area.add_child(cs)
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.28
	torus.outer_radius = 0.45
	ring.mesh = torus
	ring.material_override = Art.mat(color)
	ring.rotation.x = PI / 2
	area.add_child(ring)
	for i in 8:
		var a := TAU * i / 8.0
		var c := Color(0.97, 0.97, 0.95) if i % 2 == 0 else Color(0.98, 0.82, 0.3)
		ring.add_child(Art.mesh(Art.sphere(0.09), c, Vector3(cos(a) * 0.37, 0.05, sin(a) * 0.37)))
	area.add_child(_label3d("%s +%d" % [label, amount], Vector3(0, 0.75, 0), 48))
	add_child(area)
	var tween := ring.create_tween().set_loops()  # 绑在花圈上：花圈被捡走后补间跟着停
	tween.tween_property(ring, "rotation:y", TAU, 4.0).from(0.0)
	area.body_entered.connect(func(body: Node) -> void:
		if body is Bearer:
			bonus.emit(amount, "捡到%s！体面 +%d" % [label, amount])
			area.queue_free())
