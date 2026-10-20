class_name Level1
extends Node3D
## 第一关「殡仪馆的一天」：停棺间 → L 形走廊（花圈）→ 视错觉断桥 → 灵堂。
##
## 断桥的原理（纪念碑谷式）：上层桥头和下层桥尾在空间里是错开的（差 BRIDGE_OFFSET），
## 但偏移方向正好沿着 ALIGN_YAW 视角的视线，所以固定视角转到这个角度时，画面上两段桥连成一条。
## 对齐时两边各有一段隐形的“幽灵地面”打开，谁走过接缝，main.gd 就把谁（连同他抓着的东西）平移过去。
## 第一人称永远看到的是断桥：只能靠俯视的队友喊话，踩着只有第一人称看得见的虚线提示往虚空里走。
##
## 美术：纪念碑谷式悬在黄昏雾里的石块建筑，套中式殡仪馆的皮。道具在 props.gd，只有外观；
## 会挡路的道具另外用 _solid() 加一个看不见的碰撞盒。

signal bonus(amount: float, text: String)
signal notice(text: String)

const COFFIN_START := Vector3(0, 1.32, 0)
const GOAL := Vector3(-29, -4.63, -8.69)
const ALIGN_YAW := 135.0  # 固定视角转到这个角度，断桥才接得上
const SEAM_X := -16.0  # 上层桥头的接缝
const BRIDGE_Z := -12.4
const BRIDGE_WIDTH := 3.2
const GHOST_LEN := 1.6
const KILL_Y := -10.0
const HINT_LAYER := 6  # 只有第一人称镜头渲染这一层：桥接上时，幽灵地面上的虚线和纸钱
## 下层 = 上层 + 偏移；偏移方向就是 ALIGN_YAW 视角的视线方向（远离镜头）
const BRIDGE_OFFSET := Vector3(-3.71, -4.63, 3.71)
const CHECKPOINT_UPPER := Vector3(-10.5, 0, BRIDGE_Z)
const CHECKPOINT_LOWER := Vector3(-22.0, -4.63, BRIDGE_Z + 3.71)

## 自动测试用的路线（棺材中心的水平位置）；"align" 表示停下转视角，"cross" 表示走到被传送为止，
## "trolley" 表示等推车停进杂物间再走
const BOT_PATH := [
	Vector3(0, 0, -6), Vector3(0, 0, -12.4), Vector3(-3.6, 0, -12.4), "trolley", Vector3(-14.4, 0, -12.4), "align", "cross",
	Vector3(-23, 0, -8.69), Vector3(-29, 0, -8.69),
]

const WALL_H := 1.6
const WALL_T := 0.3
const BUILDING_THICK := 3.0  # 房间、走廊这些“石块”露出来的厚度（只是外观，碰撞还是 0.5 米）
const BRIDGE_THICK := 0.8

## 走廊西段横穿的推车：在南北两个杂物间之间来回，停一会儿、冲过去、再停一会儿
const TROLLEY_X := -6.5
const TROLLEY_Z := [-10.25, -14.55]  # 停在北边 / 南边杂物间里时的中心
const TROLLEY_MOVE := 1.6
const TROLLEY_PARK := 2.6
const WET_Z := [-10.6, -8.6]  # 走廊南段刚拖过的一段地

var _ghosts: Array[CollisionShape3D] = []
var _hints: Array[Node3D] = []
var _m := {}  # 各区域的材质
var _trolley: AnimatableBody3D
var _wet_noticed := false
var _trolley_said := -10.0
var _time := 0.0


func _ready() -> void:
	_m.room = Art.floor_mat({base_color = Color(0.84, 0.8, 0.74), speck_a = Color(0.42, 0.38, 0.35),
		grout_color = Color(0.66, 0.62, 0.58), side_color = Color(0.9, 0.84, 0.78), tile = 0.8})
	_m.corridor = Art.floor_mat({base_color = Color(0.7, 0.76, 0.76), speck_a = Color(0.3, 0.36, 0.38),
		grout_color = Color(0.55, 0.6, 0.6), side_color = Color(0.9, 0.84, 0.78), tile = 0.6})
	_m.bridge = Art.floor_mat({base_color = Color(0.86, 0.6, 0.53), speck_a = Color(0.6, 0.38, 0.34),
		speck_b = Color(0.95, 0.8, 0.75), grout_color = Color(0.95, 0.82, 0.76), side_color = Color(0.86, 0.6, 0.55), tile = 1.0})
	_m.hall = Art.floor_mat({base_color = Color(0.26, 0.24, 0.27), speck_a = Color(0.55, 0.52, 0.56),
		speck_b = Color(0.85, 0.8, 0.7), grout_color = Color(0.4, 0.36, 0.3), side_color = Color(0.72, 0.64, 0.72),
		tile = 1.0, roughness = 0.25})
	_m.gravel = Art.floor_mat({base_color = Color(0.8, 0.76, 0.66), speck_a = Color(0.55, 0.5, 0.42),
		speck_density = 0.6, grout_color = Color(0.8, 0.76, 0.66), side_color = Color(0.82, 0.74, 0.68), tile = 50.0})
	_m.rock = Art.floor_mat({base_color = Color(0.5, 0.62, 0.45), speck_a = Color(0.36, 0.48, 0.33), speck_density = 0.5,
		grout_color = Color(0.5, 0.62, 0.45), side_color = Color(0.7, 0.62, 0.6), tile = 50.0})
	_m.wall = Art.wall_mat()
	_m.hall_wall = Art.wall_mat({lower = Color(0.24, 0.21, 0.24), trim = Color(0.78, 0.62, 0.3)})
	_build_room_1()
	_build_corridor()
	_build_garden()
	_build_bridge()
	_build_hall()
	_build_sky_decor()


## 关卡里随时间动的东西（推车）。房主每个物理帧用 sim_time 调；加入方用插值后的房主时间调，两边一致
func tick(t: float) -> void:
	_time = t
	var period := 2.0 * (TROLLEY_MOVE + TROLLEY_PARK)
	var ph := fposmod(t, period)
	var z: float
	if ph < TROLLEY_PARK:
		z = TROLLEY_Z[0]
	elif ph < TROLLEY_PARK + TROLLEY_MOVE:
		z = lerpf(TROLLEY_Z[0], TROLLEY_Z[1], smoothstep(0.0, 1.0, (ph - TROLLEY_PARK) / TROLLEY_MOVE))
	elif ph < 2.0 * TROLLEY_PARK + TROLLEY_MOVE:
		z = TROLLEY_Z[1]
	else:
		z = lerpf(TROLLEY_Z[1], TROLLEY_Z[0], smoothstep(0.0, 1.0, (ph - 2.0 * TROLLEY_PARK - TROLLEY_MOVE) / TROLLEY_MOVE))
	_trolley.position = Vector3(TROLLEY_X, 0, z)


## 推车正停在杂物间里、而且还要停至少 2 秒（自动测试用来判断能不能过）
func trolley_safe() -> bool:
	var period := 2.0 * (TROLLEY_MOVE + TROLLEY_PARK)
	var ph := fposmod(_time, period)
	var half := TROLLEY_PARK + TROLLEY_MOVE
	return fposmod(ph, half) < TROLLEY_PARK - 2.0


func set_bridge(aligned: bool) -> void:
	for g in _ghosts:
		g.disabled = not aligned
	for h in _hints:
		h.visible = aligned


## 这个点是不是站在（或刚踩上）某一段幽灵地面上：有人在上面时桥不能断
static func on_ghost(p: Vector3) -> bool:
	var z0 := BRIDGE_Z - BRIDGE_WIDTH / 2 - 0.5
	var z1 := BRIDGE_Z + BRIDGE_WIDTH / 2 + 0.5
	if p.y > -2.0:
		return p.x > SEAM_X - GHOST_LEN - 0.5 and p.x < SEAM_X + 0.5 and p.z > z0 and p.z < z1
	var lower_start := SEAM_X + BRIDGE_OFFSET.x
	return p.y > BRIDGE_OFFSET.y - 2.0 and p.x > lower_start - 0.5 and p.x < lower_start + GHOST_LEN + 0.5 \
		and p.z > z0 + BRIDGE_OFFSET.z and p.z < z1 + BRIDGE_OFFSET.z


# ---------- 1 停棺间 ----------

func _build_room_1() -> void:
	_floor(Vector3(-4, 0, -4), Vector3(4, 0, 4), _m.room, BUILDING_THICK)
	_wall_x(4.0, -4.0, 4.0)
	_wall_z(4.0, -4.0, 4.0)
	_wall_z(-4.0, -4.0, 4.0)
	_wall_x(-4.0, -4.0, -1.6)
	_wall_x(-4.0, 1.6, 4.0)
	for x in [-0.7, 0.7]:  # 停棺架
		_box(Vector3(0.3, 1.09, 0.7), Vector3(x, 0.545, 0), Color(0.18, 0.18, 0.2), false)
		add_child(Art.mesh(Art.box(Vector3(0.34, 0.04, 0.74)), Props.GOLD, Vector3(x, 1.07, 0)))

	# 西墙：加高一块白色背景板，挂挽联；前面是供桌、香炉
	add_child(Art.block(Vector3(0.12, 1.0, 3.4), Vector3(-3.9, WALL_H + 0.5, 0), Art.mat(Props.WHITE)))
	_put(Props.couplet("一路走好", "抬稳别晃", "体面要紧", 2.4), Vector3(-3.82, 0, 0), PI / 2)
	_box(Vector3(0.6, 0.75, 1.3), Vector3(-3.3, 0.375, 0), Color(0.45, 0.1, 0.08), false)
	add_child(Art.mesh(Art.box(Vector3(0.64, 0.04, 1.34)), Props.GOLD, Vector3(-3.3, 0.76, 0)))
	_put(Props.incense_burner(), Vector3(-3.3, 0.78, 0))
	for z in [-0.45, 0.45]:  # 供果：一盘橘子
		add_child(Art.mesh(Art.cylinder(0.14, 0.1, 0.03), Props.WHITE, Vector3(-3.3, 0.79, z)))
		for k in 3:
			add_child(Art.mesh(Art.sphere(0.05), Color(0.98, 0.55, 0.1), Vector3(-3.3 + (k - 1) * 0.06, 0.84, z + (k % 2) * 0.04)))

	_put(Props.wreath_stand("沉痛悼念", "早登极乐"), Vector3(-3.2, 0, 2.3), PI / 2)
	_put(Props.wreath_stand("音容宛在", "一路顺风"), Vector3(-3.2, 0, -2.3), PI / 2)
	_put(Props.wreath_stand(), Vector3(2.9, 0, -3.3), -PI / 6)
	_put(Props.duty_desk(), Vector3(3.1, 0, 2.6), -PI / 2)
	_solid(Vector3(0.6, 0.8, 1.2), Vector3(3.1, 0.4, 2.6))
	for p in [Vector3(3.4, 0, 3.4), Vector3(-3.4, 0, 3.4), Vector3(3.4, 0, -1.2), Vector3(-2.3, 0, -3.4)]:
		_put(Props.chrysanthemum_pot(p.x > 0), p)

	# 门槛：要抬脚迈过去（抬棺人会自己迈上矮台阶）
	_box(Vector3(3.2, 0.12, 0.2), Vector3(0, 0.06, -4.0), Color(0.36, 0.1, 0.08), false)
	# 门框、匾额和一对白灯笼
	for x in [-1.75, 1.75]:
		add_child(Art.block(Vector3(0.3, 2.8, 0.36), Vector3(x, 1.4, -4.0), Art.mat(Color(0.45, 0.12, 0.1))))
	add_child(Art.block(Vector3(4.6, 0.26, 0.42), Vector3(0, 2.9, -4.0), Art.mat(Props.BLACK)))
	add_child(Art.block(Vector3(1.4, 0.4, 0.06), Vector3(0, 2.6, -4.2), Art.mat(Props.BLACK)))
	_put(Art.text("停棺间", 72, Props.GOLD, Vector3(0, 2.6, -4.235)), Vector3.ZERO, PI)
	_put(Art.text("出 口", 56, Props.GOLD, Vector3(0, 2.6, -3.79)), Vector3.ZERO)
	for x in [-2.1, 2.1]:
		_put(Props.lantern(), Vector3(x, 2.77, -4.0))
	_lamp(Vector3(0, 3.2, 0), 0.9, 8.0)
	_sign("抓住把手，把棺材抬出去", Vector3(0, 3.4, -3.6))


# ---------- 2 L 形走廊 ----------

func _build_corridor() -> void:
	_floor(Vector3(-1.6, 0, -14), Vector3(1.6, 0, -4), _m.corridor, BUILDING_THICK)
	_floor(Vector3(-12, 0, -14), Vector3(-1.6, 0, -10.8), _m.corridor, BUILDING_THICK)
	_wall_z(1.6, -14.0, -4.0)
	_wall_z(-1.6, -10.8, -4.0)
	var gap := [TROLLEY_X - 0.6, TROLLEY_X + 0.6]  # 推车进出杂物间的门洞
	_wall_x(-14.0, -12.0, gap[0])
	_wall_x(-14.0, gap[1], 1.6)
	_wall_x(-10.8, -12.0, gap[0])
	_wall_x(-10.8, gap[1], -1.6)
	_wreath(Vector3(0, 0, -12.4))
	# 偏离主路的小花圈：判定范围小，得专门绕过去拿
	_wreath(Vector3(1.2, 0, -9.7), 10.0, 0.4)  # 湿地板边上
	_wreath(Vector3(TROLLEY_X, 0, -10.2), 10.0, 0.4)  # 北边杂物间里：趁推车停在南边时冲进去拿
	_build_steps()
	_build_wet_floor()
	_build_trolley()

	# 墙外一圈窄平台（纪念碑谷式的露台），摆花和灯笼柱，不占走廊
	_floor(Vector3(1.75, 0, -15.0), Vector3(2.7, 0, -4.0), _m.gravel, BUILDING_THICK, false)
	_floor(Vector3(-12.0, 0, -15.0), Vector3(1.75, 0, -14.15), _m.gravel, BUILDING_THICK, false)
	for z in [-5.0, -8.0, -11.0, -14.4]:
		_lantern_post(Vector3(2.25, 0, z))
	for z in [-6.5, -9.5, -12.6]:
		_put(Props.chrysanthemum_pot(int(z) % 2 == 0), Vector3(2.25, 0, z))
	for x in [-10.5, -8.6, -4.2, -1.5]:
		_lantern_post(Vector3(x, 0, -14.6))
	for x in [-9.6, -3.0, 0.5]:
		_put(Props.chrysanthemum_pot(int(x) % 2 == 0), Vector3(x, 0, -14.6))

	# 墙上挂的：仪仗牌、指路牌、横幅、壁灯（贴墙，不占路）
	_wall_plaque("肃静", Vector3(-1.44, 1.05, -5.6), PI / 2)
	_wall_plaque("回避", Vector3(-1.44, 1.05, -8.8), PI / 2)
	_put(_banner("沉 痛 悼 念", 2.6), Vector3(-9.9, 1.15, -13.84))
	_put(_plate("← 灵堂  请保持体面", Color(0.1, 0.5, 0.3), Props.WHITE), Vector3(-2.8, 1.25, -13.84))
	_put(_plate("← 灵堂  请保持体面", Color(0.1, 0.5, 0.3), Props.WHITE), Vector3(-1.44, 1.25, -10.0), PI / 2)
	_put(_plate("⚠ 小心台阶", Color(1.0, 0.82, 0.1), Props.BLACK), Vector3(-1.44, 1.25, -5.5), PI / 2)
	for p in [Vector3(-1.44, 1.35, -7.2), Vector3(-7.85, 1.35, -13.84), Vector3(-4.6, 1.35, -13.84)]:
		var lamp := Node3D.new()
		lamp.add_child(Art.mesh(Art.box(Vector3(0.22, 0.12, 0.08)), Props.BLACK))
		var shade := MeshInstance3D.new()
		shade.mesh = Art.box(Vector3(0.18, 0.08, 0.06))
		shade.material_override = Art.glow(Color(1.0, 0.86, 0.6), 1.5)
		shade.position = Vector3(0, -0.02, 0.03)
		lamp.add_child(shade)
		_put(lamp, p, PI / 2 if p.x > -2.0 else 0.0)
		_lamp(p + (Vector3(0.4, 0, 0) if p.x > -2.0 else Vector3(0, 0, 0.4)), 0.6, 4.5)

	# 地上零星的纸钱
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for i in 28:
		var p := Vector3(rng.randf_range(-1.3, 1.3), 0.003, rng.randf_range(-13.7, -4.3))
		if i % 2:
			p = Vector3(rng.randf_range(-11.8, -1.6), 0.003, rng.randf_range(-13.7, -11.1))
		var paper := Art.mesh(Art.box(Vector3(0.16, 0.004, 0.09)), Props.PAPER if i % 3 else Props.MUM_YELLOW, p)
		paper.rotation.y = rng.randf() * TAU
		add_child(paper)


## 走廊南段的一组台阶：上两级、走一小段、下两级（教大家怎么抬着棺材上下台阶）
func _build_steps() -> void:
	var steps := [[-6.0, -6.4, 0.15], [-6.4, -6.8, 0.3], [-6.8, -7.6, 0.3], [-7.6, -8.0, 0.15]]
	for st in steps:
		var h: float = st[2]
		var size := Vector3(2.9, h, absf(st[1] - st[0]))
		var pos := Vector3(0, h / 2, (st[0] + st[1]) / 2)
		_collider(size, pos, false)
		add_child(Art.block(size, pos, _m.corridor))
		add_child(Art.mesh(Art.box(Vector3(2.9, 0.025, 0.05)), Props.GOLD.darkened(0.3), Vector3(0, h, st[0] - 0.02)))


## 湿地板：踩上去抓地力只剩一点点，起步刹车都打滑
func _build_wet_floor() -> void:
	var z0: float = WET_Z[0]
	var z1: float = WET_Z[1]
	var puddle := StandardMaterial3D.new()
	puddle.albedo_color = Color(0.3, 0.46, 0.6, 0.6)
	puddle.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	puddle.roughness = 0.03
	puddle.metallic = 0.3
	add_child(Art.block(Vector3(2.9, 0.008, z1 - z0), Vector3(0, 0.005, (z0 + z1) / 2), puddle))
	_put(Props.wet_floor_sign(), Vector3(1.2, 0, z1 + 0.3), 0.3)
	_put(Props.mop_bucket(), Vector3(1.2, 0, z0 + 0.2))
	var area := Area3D.new()
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(3.0, 1.0, z1 - z0)
	cs.shape = box
	area.add_child(cs)
	area.position = Vector3(0, 0.5, (z0 + z1) / 2)
	add_child(area)
	area.body_entered.connect(func(body: Node) -> void:
		if body is Bearer:
			body.traction = 0.18
			if not _wet_noticed:
				_wet_noticed = true
				notice.emit("地刚拖过！小心脚下"))
	area.body_exited.connect(func(body: Node) -> void:
		if body is Bearer:
			body.traction = 1.0)


## 推车和它两边的杂物间
func _build_trolley() -> void:
	for side in [-1.0, 1.0]:
		# 北边杂物间在走廊北墙外（z 大），南边在南墙外
		var zc: float = -10.25 if side > 0 else -14.55
		var y := 0.0
		_floor(Vector3(TROLLEY_X - 0.75, y, zc - 0.7), Vector3(TROLLEY_X + 0.75, y, zc + 0.7), _m.corridor, 1.0, false)
		var back: float = zc + side * 0.75
		_wall_x(back, TROLLEY_X - 0.9, TROLLEY_X + 0.9)
		_wall_z(TROLLEY_X - 0.75, zc - 0.7, zc + 0.7)
		_wall_z(TROLLEY_X + 0.75, zc - 0.7, zc + 0.7)
		add_child(Art.block(Vector3(1.8, 0.12, 1.7), Vector3(TROLLEY_X, WALL_H + 0.06, zc + side * 0.05), Art.mat(Color(0.3, 0.28, 0.28))))
		var plaque := Node3D.new()
		plaque.add_child(Art.mesh(Art.box(Vector3(0.7, 0.24, 0.03)), Props.WHITE))
		plaque.add_child(Art.text("杂物间", 40, Props.BLACK, Vector3(0, 0, 0.02)))
		_put(plaque, Vector3(TROLLEY_X, 1.45, zc - side * 0.72), PI if side > 0 else 0.0)
	_trolley = AnimatableBody3D.new()
	_trolley.add_to_group("hard")
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.95, 1.0, 1.0)
	cs.shape = box
	cs.position.y = 0.5
	_trolley.add_child(cs)
	_trolley.add_child(Props.gurney())
	tick(0.0)  # 先摆到位再进场景，不然它会在原点待一帧、撞到刚出生的人
	add_child(_trolley)
	var area := Area3D.new()
	var acs := CollisionShape3D.new()
	var abox := BoxShape3D.new()
	abox.size = Vector3(1.1, 1.0, 1.2)
	acs.shape = abox
	acs.position.y = 0.5
	area.add_child(acs)
	_trolley.add_child(area)
	area.body_entered.connect(func(body: Node) -> void:
		if body is Bearer and _time - _trolley_said > 3.0:
			_trolley_said = _time
			notice.emit("推车来了！让一让！"))


func _lantern_post(p: Vector3) -> void:
	add_child(Art.mesh(Art.cylinder(0.05, 0.06, 2.0), Props.WOOD, p + Vector3(0, 1.0, 0)))
	add_child(Art.mesh(Art.box(Vector3(0.5, 0.05, 0.05)), Props.WOOD, p + Vector3(0, 1.98, 0)))
	_put(Props.lantern(false), p + Vector3(0.18, 1.95, 0))


## L 形走廊内侧低一层的小庭院：碎石、松树、石头（只是看的）
func _build_garden() -> void:
	_floor(Vector3(-11.0, -1.0, -10.6), Vector3(-1.75, -1.0, -4.6), _m.gravel, 2.2, false)
	for p in [Vector3(-3.4, -1, -6.4), Vector3(-7.6, -1, -5.6), Vector3(-9.6, -1, -8.9), Vector3(-5.6, -1, -9.2)]:
		_put(Props.pine(2.0 + absf(p.x) * 0.06), p)
	for p in [Vector3(-5.0, -1, -7.2), Vector3(-8.2, -1, -7.8), Vector3(-2.6, -1, -9.6)]:
		var rock := Art.mesh(Art.sphere(0.4), Props.STONE.darkened(0.15), p + Vector3(0, 0.15, 0))
		rock.scale = Vector3(1.3, 0.6, 1.0)
		add_child(rock)


# ---------- 3 视错觉断桥 ----------

func _build_bridge() -> void:
	var z0 := BRIDGE_Z - BRIDGE_WIDTH / 2
	var z1 := BRIDGE_Z + BRIDGE_WIDTH / 2
	var oz := BRIDGE_OFFSET.z
	var y1 := BRIDGE_OFFSET.y
	# 上层桥头：走廊出来直走到接缝
	_floor(Vector3(SEAM_X, 0, z0), Vector3(-12, 0, z1), _m.bridge, BRIDGE_THICK)
	# 下层桥尾：从接缝的“另一头”通往灵堂。两段厚度一样，对齐时侧面也连成一条
	var lower_start := SEAM_X + BRIDGE_OFFSET.x
	_floor(Vector3(-24, y1, z0 + oz), Vector3(lower_start, y1, z1 + oz), _m.bridge, BRIDGE_THICK)
	# 两段幽灵地面：只在对齐时打开，让接缝两边都站得住人
	_ghost(Vector3(SEAM_X - GHOST_LEN, 0, z0), Vector3(SEAM_X, 0, z1))
	_ghost(Vector3(lower_start, y1, z0 + oz), Vector3(lower_start + GHOST_LEN, y1, z1 + oz))
	set_bridge(false)

	# 桥墩：一直伸进下面的雾里（只是看的，不挡掉下去的人）
	for x in [-13.0, -15.0]:
		add_child(Art.block(Vector3(0.9, 12.0, 1.6), Vector3(x, -BRIDGE_THICK - 6.0, BRIDGE_Z), _m.bridge))
	for x in [-21.0, -23.0]:
		add_child(Art.block(Vector3(0.9, 12.0, 1.6), Vector3(x, y1 - BRIDGE_THICK - 6.0, BRIDGE_Z + oz), _m.bridge))
	# 石栏杆（有碰撞，免得从桥侧面掉下去；不算“硬物”，撞上不扣分）
	for z in [z0 + 0.12, z1 - 0.12]:
		_railing(Vector3(-15.9, 0, z), 3.9)
		_railing(Vector3(-22.9, y1, z + oz), lower_start - 0.1 + 22.9)
	# 桥头一对石狮子，站在桥两侧伸出去的小台子上
	for z in [z0 - 0.45, z1 + 0.45]:
		var s := -1.0 if z < BRIDGE_Z else 1.0
		_floor(Vector3(-13.0, 0, z - 0.45), Vector3(-12.0, 0, z + 0.45), _m.bridge, BRIDGE_THICK, false)
		_put(Props.stone_lion(), Vector3(-12.5, 0, z), PI / 2 + s * 0.3)
	_sign("桥断了？\n按 Q / E 转动视角试试", Vector3(-13.5, 2.4, BRIDGE_Z))


func _railing(start: Vector3, length: float) -> void:
	_put(Props.railing(length), start)
	_solid(Vector3(length, 0.7, 0.16), start + Vector3(length / 2, 0.35, 0))


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
	_ghost_hint(a, b)


## 第一人称专用的提示：半透明的金色地面、两侧虚线，上面飘着几张纸钱
func _ghost_hint(a: Vector3, b: Vector3) -> void:
	var root := Node3D.new()
	root.position = Vector3((a.x + b.x) / 2, a.y, (a.z + b.z) / 2)
	add_child(root)
	_hints.append(root)
	var length := absf(b.x - a.x)
	var wid := absf(b.z - a.z)
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow.albedo_color = Color(1.0, 0.78, 0.25, 0.5)
	var dash := StandardMaterial3D.new()
	dash.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dash.albedo_color = Color(1.0, 0.9, 0.55)
	var parts: Array[MeshInstance3D] = []
	var plane := MeshInstance3D.new()
	plane.mesh = Art.box(Vector3(length, 0.02, wid))
	plane.material_override = glow
	plane.position.y = 0.01
	parts.append(plane)
	for s in [-1.0, 1.0]:
		for i in int(length / 0.4):
			var d := MeshInstance3D.new()
			d.mesh = Art.box(Vector3(0.24, 0.05, 0.1))
			d.material_override = dash
			d.position = Vector3(-length / 2 + 0.2 + i * 0.4, 0.02, s * (wid / 2 - 0.1))
			parts.append(d)
	for i in 8:
		var paper := MeshInstance3D.new()
		paper.mesh = Art.box(Vector3(0.24, 0.005, 0.13))
		paper.material_override = dash
		paper.position = Vector3(randf_range(-length / 2, length / 2), randf_range(0.6, 1.6), randf_range(-wid / 2, wid / 2))
		parts.append(paper)
		var tw := create_tween().set_loops()
		tw.tween_property(paper, "position:y", paper.position.y + 0.25, 1.3 + i * 0.2).set_trans(Tween.TRANS_SINE)
		tw.tween_property(paper, "position:y", paper.position.y, 1.3 + i * 0.2).set_trans(Tween.TRANS_SINE)
		var spin := create_tween().set_loops()
		spin.tween_property(paper, "rotation:y", TAU, 3.0 + i).from(0.0)
	if a.y > -2.0:  # 上层接缝上方飘一行字
		var tip := _label3d("相信队友，往前走", Vector3(0, 1.9, 0), 48)
		tip.modulate = Color(1.0, 0.9, 0.55)
		root.add_child(tip)
		tip.layers = 1 << (HINT_LAYER - 1)
	for m in parts:
		m.layers = 1 << (HINT_LAYER - 1)
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(m)


# ---------- 4 灵堂 ----------

func _build_hall() -> void:
	var y := BRIDGE_OFFSET.y
	var zc := BRIDGE_Z + BRIDGE_OFFSET.z
	_floor(Vector3(-32, y, zc - 4), Vector3(-24, y, zc + 4), _m.hall, BUILDING_THICK)
	_wall_z(-32.0, zc - 4, zc + 4, y, _m.hall_wall)
	_wall_x(zc - 4, -32.0, -24.0, y, _m.hall_wall)
	_wall_x(zc + 4, -32.0, -24.0, y, _m.hall_wall)
	_wall_z(-24.0, zc - 4, zc - BRIDGE_WIDTH / 2, y, _m.hall_wall)
	_wall_z(-24.0, zc + BRIDGE_WIDTH / 2, zc + 4, y, _m.hall_wall)

	# 灵台：深红木台，金边
	_box(Vector3(2.6, 0.4, 1.4), GOAL + Vector3(0, 0.2, 0), Color(0.36, 0.08, 0.07), false)
	add_child(Art.mesh(Art.box(Vector3(2.64, 0.04, 1.44)), Props.GOLD, GOAL + Vector3(0, 0.4, 0)))
	add_child(Art.mesh(Art.box(Vector3(0.02, 0.3, 1.0)), Props.GOLD, GOAL + Vector3(1.31, 0.2, 0)))
	# 正面红地毯
	add_child(Art.mesh(Art.box(Vector3(3.6, 0.012, 1.5)), Color(0.62, 0.08, 0.08), Vector3(-25.9, y + 0.006, zc)))
	for s in [-1.0, 1.0]:
		add_child(Art.mesh(Art.box(Vector3(3.6, 0.014, 0.06)), Props.GOLD, Vector3(-25.9, y + 0.007, zc + s * 0.7)))

	# 后墙：黑色幕布上一个大“奠”，挽联、遗像、花山
	add_child(Art.block(Vector3(0.1, 2.9, 5.2), Vector3(-31.8, y + 1.45, zc), Art.mat(Props.BLACK)))
	_put(Art.text("奠", 220, Props.WHITE, Vector3(0, 2.3, 0)), Vector3(-31.74, y, zc), PI / 2)
	_put(Props.couplet("音容宛在", "浩气长存", "", 3.6), Vector3(-31.74, y, zc), PI / 2)
	_put(Props.portrait(), Vector3(-31.6, y + 1.5, zc), PI / 2)
	_put(Props.flower_wall(4.2), Vector3(-30.75, y, zc), PI / 2)
	_put(Props.incense_burner(), Vector3(-30.5, y, zc))
	for s in [-1.0, 1.0]:
		var c := GOAL + Vector3(-0.9, 0.4, s * 0.9)
		add_child(Art.mesh(Art.cylinder(0.05, 0.05, 0.4), Color(0.97, 0.95, 0.85), c + Vector3(0, 0.2, 0)))
		var flame := MeshInstance3D.new()
		flame.mesh = Art.sphere(0.035)
		flame.material_override = Art.glow(Color(1.0, 0.7, 0.3), 5.0)
		flame.scale = Vector3(1, 1.6, 1)
		flame.position = c + Vector3(0, 0.45, 0)
		add_child(flame)
		var light := OmniLight3D.new()
		light.light_color = Color(1.0, 0.75, 0.4)
		light.omni_range = 3.0
		light.position = c + Vector3(0, 0.5, 0)
		add_child(light)
		# 灵台两边的纸扎童子
		_put(Props.paper_kid(), Vector3(-30.3, y, zc + s * 1.85), PI / 2 - s * 0.35)
		_solid(Vector3(0.45, 1.0, 0.45), Vector3(-30.3, y + 0.5, zc + s * 1.85))

	# 北墙边：纸扎别墅、纸扎轿车、纸扎手机、金元宝
	_put(Props.paper_house(), Vector3(-26.4, y, zc - 3.3))
	_put(Props.paper_car(), Vector3(-28.6, y, zc - 3.25), PI / 2)
	_put(Props.paper_phone(), Vector3(-25.0, y, zc - 3.4))
	_put(Props.gold_ingots(), Vector3(-27.6, y, zc - 3.5))
	_put(Props.gold_ingots(), Vector3(-30.9, y, zc + 3.4))
	_solid(Vector3(6.6, 1.0, 1.0), Vector3(-27.3, y + 0.5, zc - 3.3))
	# 南墙边：一排花圈和跪垫
	for x in [-25.4, -27.4, -29.4]:
		_put(Props.wreath_stand("沉痛悼念", "千古" if x < -27.0 else "安息"), Vector3(x, y, zc + 3.4), PI)
	_solid(Vector3(5.0, 1.6, 0.6), Vector3(-27.4, y + 0.8, zc + 3.4))
	for z in [zc - 2.2, zc + 2.2]:
		_put(Props.kneel_cushion(), Vector3(-27.2, y, z))

	# 门口的牌坊和灯笼
	_put(Props.paifang("往生堂", 3.4, 2.9), Vector3(-23.4, y, zc), PI / 2)
	for s in [-1.0, 1.0]:
		_solid(Vector3(0.3, 2.9, 0.3), Vector3(-23.4, y + 1.45, zc + s * 1.7))
		_put(Props.lantern(), Vector3(-23.4, y + 2.75, zc + s * 1.2))
	_wreath(Vector3(-25.3, y, zc - 2.4), 10.0, 0.4)
	_lamp(Vector3(-28.0, y + 3.2, zc), 0.8, 10.0)
	_sign("灵台：把棺材放稳", GOAL + Vector3(0, 2.6, 0))


# ---------- 雾里的远景 ----------

## 悬在雾里的小岛，和满天慢慢飘落的纸钱
func _build_sky_decor() -> void:
	var islands := [
		[Vector3(-20, -13, -1), Vector3(3.5, 2.0, 3.0)], [Vector3(-6, -11, -21), Vector3(4.0, 2.5, 3.0)],
		[Vector3(8, -9, -9), Vector3(3.0, 1.6, 4.0)], [Vector3(-34, -12, -18), Vector3(4.5, 2.2, 3.5)],
		[Vector3(-13, -16, 6), Vector3(3.0, 1.8, 3.0)],
	]
	for isl in islands:
		var p: Vector3 = isl[0]
		var s: Vector3 = isl[1]
		add_child(Art.block(s, p - Vector3(0, s.y / 2, 0), _m.rock))
		add_child(Art.block(s * Vector3(0.6, 1.4, 0.6), p - Vector3(0, s.y + s.y * 0.7, 0), _m.rock))
		_put(Props.pine(1.8 + s.x * 0.2), p + Vector3(-s.x * 0.2, 0, 0))
		_put(Props.pine(1.4), p + Vector3(s.x * 0.25, 0, s.z * 0.2))

	var money := GPUParticles3D.new()
	money.position = Vector3(-14, 14, -8)
	money.amount = 260
	money.lifetime = 24.0
	money.preprocess = 24.0
	money.visibility_aabb = AABB(Vector3(-40, -45, -35), Vector3(80, 60, 70))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(28, 1, 24)
	pm.direction = Vector3(0.2, -1, 0.1)
	pm.spread = 25.0
	pm.initial_velocity_min = 0.8
	pm.initial_velocity_max = 1.6
	pm.gravity = Vector3(0, -0.05, 0)
	pm.angular_velocity_min = -90.0
	pm.angular_velocity_max = 90.0
	pm.angle_min = 0.0
	pm.angle_max = 360.0
	pm.particle_flag_rotate_y = true
	var ramp := GradientTexture1D.new()
	ramp.gradient = Gradient.new()
	ramp.gradient.set_color(0, Props.PAPER)
	ramp.gradient.set_color(1, Props.MUM_YELLOW)
	pm.color_initial_ramp = ramp
	money.process_material = pm
	var sheet := BoxMesh.new()
	sheet.size = Vector3(0.18, 0.004, 0.1)
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 1.0
	sheet.material = m
	money.draw_pass_1 = sheet
	money.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(money)


func _wreath(pos: Vector3, amount := 15.0, radius := 0.9) -> void:
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
	ring.material_override = Art.mat(Color(0.16, 0.45, 0.22))
	ring.rotation.x = PI / 2
	area.add_child(ring)
	for i in 8:
		var a := TAU * i / 8.0
		var c := Color(0.97, 0.97, 0.95) if i % 2 == 0 else Color(0.98, 0.82, 0.3)
		ring.add_child(Art.mesh(Art.sphere(0.09), c, Vector3(cos(a) * 0.37, 0.05, sin(a) * 0.37)))
	area.add_child(_label3d("花圈 +%d" % amount, Vector3(0, 0.75, 0), 48))
	add_child(area)
	var tween := create_tween().set_loops()
	tween.tween_property(ring, "rotation:y", TAU, 4.0).from(0.0)
	area.body_entered.connect(func(body: Node) -> void:
		if body is Bearer:
			bonus.emit(amount, "捡到花圈！体面 +%d" % amount)
			area.queue_free())


# ---------- 搭建小工具 ----------

## 一块地面：a、b 是对角（只看 x、z），a.y 是地面高度。
## 碰撞固定 0.5 米厚（和以前一样，不影响物理），外观可以更厚，像悬在空中的石块
func _floor(a: Vector3, b: Vector3, material: Material, thick := 0.5, hard := true) -> void:
	var size := Vector3(absf(b.x - a.x), 0.5, absf(b.z - a.z))
	var center := Vector3((a.x + b.x) / 2, a.y - 0.25, (a.z + b.z) / 2)
	_collider(size, center, hard)
	add_child(Art.block(Vector3(size.x, thick, size.z), Vector3(center.x, a.y - thick / 2, center.z), material))


## 沿 X 方向的墙（固定 z）
func _wall_x(z: float, x0: float, x1: float, y := 0.0, material: Material = null) -> void:
	_wall(Vector3(x1 - x0, WALL_H, WALL_T), Vector3((x0 + x1) / 2, y + WALL_H / 2, z), material)


## 沿 Z 方向的墙（固定 x）
func _wall_z(x: float, z0: float, z1: float, y := 0.0, material: Material = null) -> void:
	_wall(Vector3(WALL_T, WALL_H, z1 - z0), Vector3(x, y + WALL_H / 2, (z0 + z1) / 2), material)


func _wall(size: Vector3, pos: Vector3, material: Material) -> void:
	_collider(size, pos, true)
	add_child(Art.block(size, pos, material if material else _m.wall))


func _collider(size: Vector3, pos: Vector3, hard: bool) -> void:
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


## 看不见的碰撞盒，给会挡路的道具用（撞上不扣分）
func _solid(size: Vector3, pos: Vector3) -> void:
	_collider(size, pos, false)


## 带外观的纯色方块（停棺架、供桌、灵台）
func _box(size: Vector3, pos: Vector3, color: Color, hard: bool) -> void:
	_collider(size, pos, hard)
	add_child(Art.mesh(Art.box(size), color, pos))


func _put(node: Node3D, pos: Vector3, yaw := 0.0) -> Node3D:
	node.position += pos
	node.rotation.y = yaw
	add_child(node)
	return node


func _lamp(pos: Vector3, energy: float, reach: float) -> void:
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.84, 0.62)
	l.light_energy = energy
	l.omni_range = reach
	l.position = pos
	add_child(l)


## 挂在墙上的红底金字仪仗牌
func _wall_plaque(text: String, pos: Vector3, yaw: float) -> void:
	var n := Node3D.new()
	n.add_child(Art.mesh(Art.box(Vector3(0.44, 0.74, 0.03)), Props.GOLD))
	n.add_child(Art.mesh(Art.box(Vector3(0.38, 0.68, 0.03)), Props.RED, Vector3(0, 0, 0.01)))
	n.add_child(Art.text("\n".join(text.split("")), 96, Props.GOLD, Vector3(0, 0, 0.03)))
	_put(n, pos, yaw)


## 挂在墙上的小牌子（指路牌、警示牌）
func _plate(text: String, bg: Color, fg: Color) -> Node3D:
	var n := Node3D.new()
	n.add_child(Art.mesh(Art.box(Vector3(1.2, 0.36, 0.03)), bg))
	n.add_child(Art.text(text, 40, fg, Vector3(0, 0, 0.02)))
	return n


## 白底黑字横幅
func _banner(text: String, width: float) -> Node3D:
	var n := Node3D.new()
	n.add_child(Art.mesh(Art.box(Vector3(width, 0.38, 0.02)), Props.WHITE))
	n.add_child(Art.text(text, 64, Props.BLACK, Vector3(0, 0, 0.012)))
	return n


func _sign(text: String, pos: Vector3) -> void:
	add_child(_label3d(text, pos, 64))


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
