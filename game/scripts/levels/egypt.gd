extends Level
## 埃及关「法老的最后一程」：从金色黄昏的沙漠进入地下陵墓，一路往下，最后把法老送进黄金墓室。
##
## 每个房间分三段，同一种机关一段比一段狠（先学会 → 换个花样 → 逼你快）：
##   1 沙漠入口：沙丘（全是软沙）→ 沙堆迷宫（S 形绕路）→ 风沙广场（阵风往东边的悬崖推，躲断墙后面）
##   2 飞镖甬道：按节奏射的三排 → 往西拐，机关砖（踩了 0.6 秒后放箭，不能停）→ 往南拐，更密的三排
##   3 塌陷地板：大厅（站 1 秒就塌）→ 之字形窄桥（塌得更快）→ 身后一排排追着塌，跑！
##   4 封印石门：推石块压住压力板开第一道门 → 第二道门踩一下就开，但松开 7 秒就关，门在 11 米外
##   5 滚石长廊：中线上一个接一个滚下来的石球，横倒的巨石逼你来回穿过它
##   6 刀摆深渊：摆刀窄桥（快）或者坐木筏（慢）
##   7 法老墓室：石棺前面的地板是假的
## 另外：沙堆迷宫边上有弹簧板能直接弹过去（近路），沙丘东头的花环头顶悬着落石，飞镖甬道西墙有一段是假的
##
## 机关都按时间或状态算：
##   - 飞镖、风：按 tick(t) 的时间算，房主和加入方各算各的；机关砖什么时候被踩的放进 net_state()
##   - 石砖、石门、压力板：房主算状态，放进 net_state() 发给加入方
##   - 大石块：真刚体，放进 net_bodies() 跟整队一起同步位置

const SAND_SPEED := 0.6  # 沙地里走路速度打几折
const SAND_TRACTION := 0.55

# ---- 1 沙漠入口 ----
const DESERT_X := 9.0
const DUNE := [-6.0, -11.0, -13.0, -18.0]  # 上坡起点、坡顶起点、坡顶终点、下坡终点
const DUNE_H := 1.4
const MOUNDS := [[-DESERT_X, 3.0, -20.5, -22.0], [-3.0, DESERT_X, -25.5, -27.0]]  # 沙堆：[x0, x1, z0, z1]
const WIND_Z := [-30.0, -44.0]
const WIND_PERIOD := 7.0
const WIND_CALM := 4.0  # 每个周期前 4 秒没风，后 3 秒刮
const WIND_ACCEL := 5.5  # 阵风给每个刚体的加速度（往 +X）
const SHELTERS := [[-2.2, -32.0, -35.0], [-2.2, -37.5, -40.5]]  # 断墙：[x, z0, z1]，墙东边 3 米内吹不到
const GATE_Z := -44.0
const GATE_HALF := 1.4
# ---- 2 飞镖甬道 ----
const CORRIDOR_HALF := 1.9
const TURN_Z := -64.0  # 往西拐的那段甬道中线
const WEST_X := -16.0  # 往南拐以后（以及后面所有房间）的中线
const DART_SPEED := 7.0
const DART_HEIGHT := 1.0
const DART_SPREAD := 0.4  # 一排里三支飞镖的间距
const DART_VOLLEY_GAP := 0.25
const DART_HIT_RADIUS := 0.32
const TRAP_DELAY := 0.6  # 机关砖被踩后多久放箭
const TRAP_XS := [-4.0, -7.0, -10.0, -13.0]
const RAMP_Z := [-84.0, -90.0]  # 甬道尽头往下的斜坡
const SECRET2_Z := [-50.6, -52.4]  # A 段西墙上那段假墙
# ---- 3 塌陷地板 ----
const HALL_Y := -1.5
const TILE := 1.4
const HALL_Z := [-92.0, -103.2]  # 大厅 6 × 8 块砖
const HALL_HOLES := [[2, 0], [2, 1], [2, 2], [5, 3], [5, 4], [5, 5]]  # [排, 列]：一开始就没有的砖
const BRIDGE_Z := [-106.2, -117.4]  # 窄桥 2 × 8 块
const BRIDGE_SHIFT := [0.0, 0.0, 1.4, 1.4, 0.0, 0.0, -1.4, -1.4]  # 每排往东偏多少
const CHASE_Z := [-120.6, -134.6]  # 追着塌的 3 × 10 块
const CHASE_SPEED := 2.0  # 塌陷往前追的速度（米/秒）
const TILE_DOWN_TIME := 8.0
# ---- 4 封印石门 ----
const DOOR_ROOM_Z := [-136.6, -162.6]
const ROOM_HALF := 4.5
const DOOR_HALF := 1.8
const DOOR_H := 2.4
const DOOR_OPEN := 2.6
const DOOR1_Z := -149.1
const PLATE1 := Vector3(-13.0, HALL_Y, -145.1)
const BLOCK_START := Vector3(-13.0, HALL_Y + 0.5, -140.1)
const PLATE2 := Vector3(-19.0, HALL_Y, -151.1)
const DOOR2_CLOSE_TIME := 7.0
const PLATE_SIZE := 1.6
# ---- 5 滚石长廊 ----
const BOULDER_Z := [-162.6, -192.0]
const BOULDER_HALF := 4.0
const BOULDER_R := 0.95
const BOULDER_END := -167.0  # 石球滚到这里掉进铁栅栏
const BLOCKS := [[-4.0, -1.1, -170.0, -172.0], [1.1, 4.0, -178.0, -180.0], [-4.0, -1.1, -186.0, -188.0]]  # 横倒的巨石：[x0, x1, z0, z1]（x 相对中线）
const EXIT5 := [1.4, 4.0]  # 北墙出口（x 相对中线）
# ---- 6 刀摆深渊 ----
const ABYSS_Z := [-192.0, -215.0]
const PIT_Z := [-195.0, -211.0]
const BLADE_X := -2.7  # 摆刀桥中线（相对 WEST_X）
const RAFT_X := 2.4
const BLADES := [-199.0, -203.0, -207.0]
# ---- 7 墓室 ----
const TOMB_Z := [-215.0, -227.0]
const TOMB_FAKE := [-1.2, 1.0, -218.0, -220.2]  # 石棺前面那块假地板：[x0, x1, z0, z1]（x 相对中线）

var _time := 0.0
var _lanes: Array = []  # 每条飞镖道：{origin, dir, spread, span, volleys, period, offset, trap, fire_at, tile}
var _periodic: Array = []  # 按节奏射的那几条（电脑队伍 "wait:dart<n>" 用的序号）
var _darts: Array[Node3D] = []
var _dart_hit_at := {}  # 抬棺人 → 上次被射中的时间（冷却用）
var _dart_hits := 0
var _tiles: Array = []  # 每块砖：{cs, mesh, base_y, center, state, fall_after, group, row, waved}
var _chase_t0 := -1.0
var _block: RigidBody3D
var _doors: Array = []  # {body, z, lift, plate, plate_mesh, pressed, timed}
var _wind_fx: GPUParticles3D
var _said := {}


func _init() -> void:
	id = "egypt"
	title = "法老的最后一程"
	par_time = 25.0 * 60.0
	kill_y = -9.0
	goal_pos = Vector3(WEST_X - 1.6, HALL_Y, -222.5)  # 石棺靠西边放：棺材要顺着长边推上去，抬棺人走在两侧
	goal_size = Vector3(2.0, 0.85, 1.0)
	rooms = [
		{name = "沙漠入口", spawn = Vector3(0, 0, 3), lift = 1.32, yaw = 0.0,
			path = [Vector3(0, 0, -5), Vector3(0, 0, -12), Vector3(0, 0, -18.5), Vector3(6, 0, -19.5), Vector3(6, 0, -23.75),
				Vector3(-6, 0, -23.75), Vector3(-6, 0, -28.5), Vector3(0, 0, -29.5),
				"wait:calm", Vector3(-0.5, 0, -33.5), "wait:calm", Vector3(-0.5, 0, -39.0), "wait:calm", Vector3(0, 0, -46.0)]},
		{name = "飞镖甬道", spawn = Vector3(0, 0, -45.5), yaw = 0.0,
			path = ["wait:dart0", Vector3(0, 0, -50.5), "wait:dart1", Vector3(0, 0, -55.5), "wait:dart2", Vector3(0, 0, -60.5),
				Vector3(0, 0, TURN_Z), Vector3(-7.0, 0, TURN_Z), Vector3(WEST_X, 0, TURN_Z), Vector3(WEST_X, 0, -67.5),
				"wait:dart3", Vector3(WEST_X, 0, -72.5), "wait:dart4", Vector3(WEST_X, 0, -77.5), "wait:dart5",
				Vector3(WEST_X, 0, -82.5), Vector3(WEST_X, 0, -88.0), Vector3(WEST_X, 0, -91.3)]},
		{name = "塌陷地板", spawn = Vector3(WEST_X, HALL_Y, -90.8), yaw = 0.0,
			path = [Vector3(WEST_X + 1.6, 0, -93.5), Vector3(WEST_X + 1.6, 0, -96.6), Vector3(WEST_X - 1.6, 0, -99.0),
				Vector3(WEST_X - 1.6, 0, -101.0), Vector3(WEST_X, 0, -104.7),
				Vector3(WEST_X, 0, -107.6), Vector3(WEST_X + 1.4, 0, -110.4), Vector3(WEST_X, 0, -113.2),
				Vector3(WEST_X - 1.4, 0, -116.0), Vector3(WEST_X, 0, -119.0), Vector3(WEST_X, 0, -127.0),
				Vector3(WEST_X, 0, -138.6)]},
		{name = "封印石门", spawn = Vector3(WEST_X, HALL_Y, -138.1), yaw = 0.0,
			path = [Vector3(BLOCK_START.x, 0, -138.5), Vector3(BLOCK_START.x, 0, PLATE1.z + 1.6), "wait:door0",
				Vector3(BLOCK_START.x, 0, -141.6), Vector3(WEST_X, 0, -142.6), Vector3(WEST_X, 0, DOOR1_Z - 1.0),
				Vector3(PLATE2.x, 0, PLATE2.z), "wait:door1", Vector3(WEST_X, 0, -155.6), Vector3(WEST_X, 0, -163.3)]},
		{name = "滚石长廊", spawn = Vector3(WEST_X, HALL_Y, -163.6), yaw = 0.0,
			path = ["wait:trap:boulder:1.8:22_26", Vector3(WEST_X + 2.4, 0, -166.5), Vector3(WEST_X + 2.4, 0, -172.6),
				"wait:trap:boulder:2.2:17.5_21.5", Vector3(WEST_X - 2.4, 0, -173.4), Vector3(WEST_X - 2.4, 0, -180.6),
				"wait:trap:boulder:2.2:9.5_13.5", Vector3(WEST_X + 2.4, 0, -181.5), Vector3(WEST_X + 2.6, 0, -193.6)]},
		{name = "刀摆深渊", spawn = Vector3(WEST_X + RAFT_X, HALL_Y, -193.6), yaw = 0.0,
			path = [Vector3(WEST_X + RAFT_X, 0, -193.9), "wait:trap:raft:3.0:a", Vector3(WEST_X + RAFT_X, 0, -197.0),
				"wait:trap:raft:2.2:b", Vector3(WEST_X + RAFT_X, 0, -211.8), Vector3(WEST_X, 0, -212.6), Vector3(WEST_X, 0, -213.8)]},
		{name = "法老墓室", spawn = Vector3(WEST_X, HALL_Y, -216.4), yaw = 0.0,
			path = [Vector3(WEST_X, 0, -216.4), Vector3(WEST_X + 2.4, 0, -216.4), Vector3(WEST_X + 2.4, 0, goal_pos.z), goal_pos]},
	]


func env() -> Dictionary:
	return {
		sky_top = Color(0.3, 0.4, 0.68), sky_horizon = Color(1.0, 0.74, 0.42), sky_curve = 0.1,
		ground_horizon = Color(0.96, 0.7, 0.42), ground_bottom = Color(0.22, 0.13, 0.1), ground_curve = 0.08,
		ambient = 0.7, exposure = 1.08, saturation = 1.12,
		fog_color = Color(0.92, 0.66, 0.42), fog_density = 0.005, fog_height = -4.0, fog_height_density = 0.1,
		sun_rot = Vector3(-32, -60, 0), sun_color = Color(1.0, 0.8, 0.55), sun_energy = 1.35,
	}


func _ready() -> void:
	_m.sand = Art.floor_mat({base_color = PropsEgypt.SAND, speck_a = Color(0.78, 0.6, 0.38), speck_b = Color(1.0, 0.9, 0.7),
		speck_density = 0.5, grout_color = PropsEgypt.SAND, side_color = Color(0.82, 0.62, 0.4), tile = 50.0, roughness = 0.95})
	_m.paving = Art.floor_mat({base_color = Color(0.84, 0.7, 0.5), speck_a = Color(0.6, 0.46, 0.3),
		grout_color = Color(0.62, 0.48, 0.32), side_color = Color(0.8, 0.64, 0.44), tile = 1.2, roughness = 0.8})
	_m.tomb = Art.floor_mat({base_color = Color(0.62, 0.5, 0.38), speck_a = Color(0.4, 0.3, 0.22), speck_b = Color(0.9, 0.75, 0.5),
		grout_color = Color(0.42, 0.32, 0.22), side_color = Color(0.55, 0.42, 0.3), tile = TILE, roughness = 0.75})
	_m.tomb_fast = Art.floor_mat({base_color = Color(0.55, 0.38, 0.3), speck_a = Color(0.35, 0.22, 0.18),
		speck_b = Color(0.9, 0.6, 0.45), grout_color = Color(0.4, 0.25, 0.2), side_color = Color(0.5, 0.36, 0.28), tile = TILE})
	_m.gold_floor = Art.floor_mat({base_color = Color(0.5, 0.36, 0.2), speck_a = Color(0.95, 0.74, 0.3),
		speck_b = Color(1.0, 0.9, 0.6), speck_density = 0.5, grout_color = Color(0.85, 0.65, 0.25),
		side_color = Color(0.55, 0.42, 0.3), tile = 1.0, roughness = 0.35})
	_m.wall = Art.sandstone_mat()
	_m.low_wall = Art.sandstone_mat({frieze_h = 0.0})
	_m.tomb_wall = Art.sandstone_mat({stone = Color(0.7, 0.56, 0.4), mortar = Color(0.5, 0.38, 0.26)})
	_build_desert()
	_build_dart_corridor()
	_build_tile_rooms()
	_build_door_room()
	_build_boulder_hall()
	_build_abyss()
	_build_tomb()
	_build_backdrop()


func room_at(p: Vector3) -> int:
	if p.z > GATE_Z - 0.3:
		return 0
	if p.z > RAMP_Z[1] - 1.0:
		return 1
	if p.z > DOOR_ROOM_Z[0] - 0.5:
		return 2
	if p.z > DOOR_ROOM_Z[1] - 0.5:
		return 3
	if p.z > BOULDER_Z[1] - 0.5:
		return 4
	if p.z > ABYSS_Z[1] + 2.0:
		return 5
	return 6


# ---------- 每帧的机关 ----------

func tick(t: float) -> void:
	_time = t
	_place_darts(t)
	_wind_fx.emitting = fposmod(t, WIND_PERIOD) > WIND_CALM - 0.8  # 起风前 0.8 秒先看到沙子飘起来


func physics_update(g: Node) -> void:
	var delta := get_physics_process_delta_time()
	_update_sand(g)
	_update_wind(g)
	_update_darts(g)
	_update_tiles(g, delta)
	_update_doors(g, delta)


func bot_can_go(tag: String) -> bool:
	if tag.begins_with("dart"):
		# 这一排刚射完：接下来一段时间是安全的
		var l: Dictionary = _periodic[int(tag.substr(4))]
		var end: float = (l.volleys - 1) * DART_VOLLEY_GAP + l.span / DART_SPEED
		var ph := _lane_age(l, _time)
		return ph > end and ph < end + 0.4
	if tag == "calm":
		return fposmod(_time, WIND_PERIOD) < 0.4
	if tag.begins_with("door"):
		return _doors[int(tag.substr(4))].lift > DOOR_OPEN - 0.3
	return true


func debug_text() -> String:
	var shaking := _tiles.filter(func(t): return t.state > 0.0).size()
	var down := _tiles.filter(func(t): return t.state < 0.0).size()
	return "block=%s doors=%s tiles shaking=%d down=%d chase=%.1f dart_hits=%d gust=%s" % [
		_block.global_position.snapped(Vector3.ONE * 0.01), _doors.map(func(d): return snappedf(d.lift, 0.01)),
		shaking, down, _chase_t0, _dart_hits, fposmod(_time, WIND_PERIOD) >= WIND_CALM]


func net_bodies() -> Array[RigidBody3D]:
	return [_block]


func net_state() -> PackedFloat32Array:
	var a := PackedFloat32Array()
	for d in _doors:
		a.append(d.lift)
		a.append(1.0 if d.pressed else 0.0)
	for l in _lanes:
		if l.trap:
			a.append(l.fire_at)
	for t in _tiles:
		a.append(t.state)
	return a


func apply_net_state(a: PackedFloat32Array) -> void:
	var traps := _lanes.filter(func(l): return l.trap)
	if a.size() != _doors.size() * 2 + traps.size() + _tiles.size():
		return
	var i := 0
	for d in _doors:
		d.lift = a[i]
		_set_plate(d, a[i + 1] > 0.5)
		_place_door(d)
		i += 2
	for l in traps:
		l.fire_at = a[i]
		i += 1
	for t in _tiles:
		t.state = a[i]
		_show_tile(t)
		i += 1


func _say_once(key: String, text: String) -> void:
	if not _said.has(key):
		_said[key] = true
		notice.emit(text)


# ---------- 1 沙漠入口 ----------

## 沙地：抬棺人在沙丘和沙堆迷宫里走得慢、刹不住（起点石板路和风沙广场是石头地）
func _update_sand(g: Node) -> void:
	for b in g.bearers:
		var p: Vector3 = b.global_position
		var sand := p.z < DUNE[0] + 1.0 and p.z > WIND_Z[0] and p.y > -1.0
		b.speed_scale = SAND_SPEED if sand else 1.0
		b.traction = SAND_TRACTION if sand else 1.0
		if sand and g.started:
			_say_once("sand", "沙子好软……走不快，也刹不住")


func _sheltered(p: Vector3) -> bool:
	for s in SHELTERS:
		if p.x > s[0] and p.x < s[0] + 3.4 and p.z < s[1] + 0.3 and p.z > s[2] - 0.3:
			return true
	return false


## 阵风：往 +X（东边悬崖）推广场上所有没躲在断墙后面的刚体
func _update_wind(g: Node) -> void:
	if fposmod(_time, WIND_PERIOD) < WIND_CALM:
		return
	for body in g.team_bodies():
		if not body.is_inside_tree():
			continue
		var p: Vector3 = body.global_position
		if p.z < WIND_Z[0] and p.z > WIND_Z[1] and p.y > -1.0 and not _sheltered(p):
			body.apply_central_force(Vector3(WIND_ACCEL * body.mass, 0, 0))
			if body == g.coffin:
				_say_once("wind", "起风了！躲到断墙后面")


func _build_desert() -> void:
	var t := 4.0
	_floor(Vector3(-DESERT_X, 0, 6), Vector3(DESERT_X, 0, DUNE[0]), _m.sand, t)
	_ramp(Vector3(0, 0, DUNE[0]), Vector3(0, DUNE_H, DUNE[1]), DESERT_X * 2, _m.sand, t)
	_floor(Vector3(-DESERT_X, DUNE_H, DUNE[1]), Vector3(DESERT_X, DUNE_H, DUNE[2]), _m.sand, t + DUNE_H)
	_ramp(Vector3(0, DUNE_H, DUNE[2]), Vector3(0, 0, DUNE[3]), DESERT_X * 2, _m.sand, t)
	_floor(Vector3(-DESERT_X, 0, DUNE[3]), Vector3(DESERT_X, 0, WIND_Z[0]), _m.sand, t)
	_floor(Vector3(-DESERT_X, 0, WIND_Z[0]), Vector3(DESERT_X, 0, GATE_Z), _m.paving, t)
	add_child(Art.block(Vector3(3.2, 0.04, 11.0), Vector3(0, 0.02, 0.5), _m.paving))  # 起点的石板路（只是看的）
	# 两边半埋在沙里的矮墙；风沙广场东边没有墙，是悬崖
	for s in [-1.0, 1.0]:
		var x: float = s * (DESERT_X - 0.15)
		_wall_z(x, 6.0, DUNE[0], 0.0, _m.low_wall, 0.7)
		_wall_z(x, DUNE[0], DUNE[3], 0.0, _m.low_wall, DUNE_H + 0.7)
		_wall_z(x, DUNE[3], WIND_Z[0], 0.0, _m.low_wall, 0.7)
	_wall_z(-(DESERT_X - 0.15), WIND_Z[0], GATE_Z, 0.0, _m.low_wall, 0.7)
	_wall_x(6.0 - 0.15, -DESERT_X, DESERT_X, 0.0, _m.low_wall, 0.7)

	# 起点：石头停棺台，两边各一座方尖碑
	for x in [-0.7, 0.7]:
		_box(Vector3(0.3, 1.09, 0.7), Vector3(x, 0.545, 3), PropsEgypt.DARK_STONE, false)
		add_child(Art.mesh(Art.box(Vector3(0.34, 0.04, 0.74)), PropsEgypt.GOLD, Vector3(x, 1.07, 3)))
	for x in [-2.6, 2.6]:
		_put(PropsEgypt.obelisk(4.2), Vector3(x, 0, 2.5))
		_solid(Vector3(0.75, 2.0, 0.75), Vector3(x, 1.0, 2.5))
	for p in [Vector3(4.8, 0, 1.0), Vector3(6.6, 0, -3.6), Vector3(-6.4, 0, 4.2), Vector3(-7.0, 0, -2.0)]:
		_put(PropsEgypt.palm(3.0 + absf(p.z) * 0.05), p, p.x)
		_solid(Vector3(0.3, 2.0, 0.3), p + Vector3(0, 1.0, 0))
	# 沙丘顶上的碎石柱和斯芬克斯
	for p in [Vector3(-4.4, DUNE_H, -12.0), Vector3(3.6, DUNE_H, -11.6)]:
		_put(PropsEgypt.column(1.2, 0.3), p)
		_solid(Vector3(0.7, 1.4, 0.7), p + Vector3(0, 0.7, 0))
	_put(PropsEgypt.sphinx(5.5), Vector3(-6.0, DUNE_H - 0.6, -15.2), 0.0)
	_solid(Vector3(3.0, 2.4, 3.8), Vector3(-6.0, DUNE_H + 0.6, -15.2))
	_wreath(Vector3(7.6, DUNE_H, -12.0), 10.0, 0.5, Color(0.25, 0.55, 0.45), "莲花环")  # 沙丘东头：绕过去拿
	var rock := Art.mesh(Art.sphere(0.8), PropsEgypt.SANDSTONE.darkened(0.2), Vector3(0, 0.8, 0))
	var holder := Node3D.new()
	holder.add_child(rock)
	var drop := Traps.Dropper.new(holder, Vector3(7.6, DUNE_H + 5.0, -12.0), DUNE_H, 0.9)
	drop.text = "落石！"
	_trap(drop)
	_sign("沙地会拖慢脚步", Vector3(0, 3.2, -4.0))

	# 沙堆迷宫：两道沙堆墙，只能 S 形绕过去
	for m in MOUNDS:
		var size := Vector3(m[1] - m[0], 1.5, absf(m[3] - m[2]))
		var c := Vector3((m[0] + m[1]) / 2, 0.75, (m[2] + m[3]) / 2)
		_collider(size, c, false)
		for k in int(size.x / 1.6) + 1:
			var mound := Art.mesh(Art.sphere(1.0), PropsEgypt.SAND.darkened(0.03 * (k % 3)),
				Vector3(m[0] + 0.8 + k * 1.6, 0.3, c.z + (k % 2) * 0.2))
			mound.scale = Vector3(1.2, 1.25, size.z * 0.75)
			add_child(mound)
	_put(PropsEgypt.pot(), Vector3(-8.0, 0, -18.8))
	_put(PropsEgypt.pot(PropsEgypt.SANDSTONE), Vector3(8.0, 0, -28.4))
	_wreath(Vector3(-8.0, 0, -24.0), 10.0, 0.5, Color(0.25, 0.55, 0.45), "莲花环")  # 迷宫西头的死角
	var spring := Traps.Spring.new(Vector3(-3.0, 0, -19.2), Vector2(1.4, 1.2), Vector3(0, 7.6, -7.2), PropsEgypt.LAPIS)
	spring.text = "嘣——直接飞过沙堆！"
	_trap(spring)
	_sign("圣甲虫弹簧", Vector3(-3.0, 2.0, -18.6))
	_discover("shortcut", "飞过沙堆", Vector3(-1.0, 3.4, -26.2), Vector3(9.0, 2.6, 3.0))

	# 风沙广场：断墙挡风，东边是悬崖
	for s in SHELTERS:
		_wall_z(s[0], s[1], s[2], 0.0, _m.low_wall, 1.4)
		for z in [s[1] - 0.4, s[2] + 0.4]:
			_put(PropsEgypt.column(1.9, 0.26), Vector3(s[0] - 0.35, 0, z))
	for z in [-31.0, -36.2, -42.0]:  # 悬崖边上的破柱子（只是看的，提醒这边会掉下去）
		_put(PropsEgypt.column(0.8, 0.28), Vector3(DESERT_X - 0.6, 0, z))
	_wind_fx = _sand_wind()
	_sign("起风时躲到断墙后面", Vector3(0, 3.4, WIND_Z[0] - 1.0))

	# 陵墓大门：两座梯形塔门，中间留一个门洞
	for s in [-1.0, 1.0]:
		var cx: float = s * (GATE_HALF + (DESERT_X - GATE_HALF) / 2)
		_collider(Vector3(DESERT_X - GATE_HALF, 4.0, 1.4), Vector3(cx, 2.0, GATE_Z), true)
		var tower := Art.mesh(Art.cylinder(2.6, 3.8, 4.0, 4), PropsEgypt.SANDSTONE, Vector3(cx, 2.0, GATE_Z))
		tower.rotation.y = PI / 4
		tower.scale = Vector3(1.2, 1.0, 0.3)
		add_child(tower)
		_put(PropsEgypt.torch(), Vector3(s * (GATE_HALF + 0.3), 1.3, GATE_Z + 0.72))
	add_child(Art.block(Vector3(GATE_HALF * 2 + 1.4, 0.7, 1.4), Vector3(0, 3.35, GATE_Z), _m.wall))
	add_child(Art.mesh(Art.box(Vector3(1.4, 0.4, 0.05)), PropsEgypt.LAPIS, Vector3(0, 3.35, GATE_Z + 0.73)))
	_put(Art.text("陵 墓", 64, PropsEgypt.GOLD, Vector3(0, 3.35, GATE_Z + 0.76)), Vector3.ZERO)


## 风沙：刮风时从西往东飞的一道道沙线
func _sand_wind() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.position = Vector3(-DESERT_X - 2, 0.8, (WIND_Z[0] + WIND_Z[1]) / 2)
	p.amount = 220
	p.lifetime = 1.6
	p.emitting = false
	p.visibility_aabb = AABB(Vector3(-2, -2, -9), Vector3(26, 6, 18))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(0.5, 0.8, 7.5)
	pm.direction = Vector3(1, 0.05, 0)
	pm.spread = 4.0
	pm.initial_velocity_min = 11.0
	pm.initial_velocity_max = 15.0
	pm.gravity = Vector3.ZERO
	p.process_material = pm
	var streak := BoxMesh.new()
	streak.size = Vector3(0.6, 0.02, 0.02)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(1.0, 0.88, 0.62, 0.7)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	streak.material = m
	p.draw_pass_1 = streak
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(p)
	return p


# ---------- 2 飞镖甬道 ----------

## 一排按节奏射的飞镖：沿 X 横穿甬道（中线 cx），dir_sign 是从西往东（1）还是从东往西（-1）
func _periodic_row(cx: float, z: float, dir_sign: float, period: float, offset: float, volleys: int) -> void:
	var l := {origin = Vector3(cx - dir_sign * CORRIDOR_HALF, DART_HEIGHT, z), dir = Vector3(dir_sign, 0, 0),
		spread = Vector3(0, 0, 1), span = CORRIDOR_HALF * 2, volleys = volleys, period = period, offset = offset,
		trap = false, fire_at = -100.0, tile = Rect2()}
	_lanes.append(l)
	_periodic.append(l)
	for k in 3:
		var p: Vector3 = l.origin + l.spread * (k - 1) * DART_SPREAD
		_put(PropsEgypt.dart_launcher(), p, dir_sign * PI / 2)
	# 地上画两道红线：飞镖会扫过这中间
	for s in [-1.0, 1.0]:
		add_child(Art.mesh(Art.box(Vector3(CORRIDOR_HALF * 2, 0.01, 0.06)), PropsEgypt.OCHRE,
			Vector3(cx, 0.006, z + s * (DART_SPREAD + 0.35))))


## 机关砖：踩上去 0.6 秒后，北墙射孔沿 -Z 横扫这块砖
func _trap_lane(x: float, tile_z: float) -> void:
	var l := {origin = Vector3(x, DART_HEIGHT, TURN_Z + CORRIDOR_HALF), dir = Vector3(0, 0, -1), spread = Vector3(1, 0, 0),
		span = CORRIDOR_HALF * 2, volleys = 2, period = 0.0, offset = 0.0, trap = true, fire_at = -100.0,
		tile = Rect2(x - TILE / 2, tile_z - TILE / 2, TILE, TILE)}
	_lanes.append(l)
	for k in 3:
		_put(PropsEgypt.dart_launcher(), l.origin + l.spread * (k - 1) * DART_SPREAD, PI)
	var plate := PropsEgypt.plate_top(TILE - 0.1)
	plate.position = Vector3(x, 0.0, tile_z)
	add_child(plate)


## 这条飞镖道的“发射后过了多久”
func _lane_age(l: Dictionary, t: float) -> float:
	if l.trap:
		return t - l.fire_at
	return fposmod(t - l.offset, l.period)


## 第 volley 轮、第 k 支飞镖现在在哪（不在飞就返回 null）
func _dart_pos(l: Dictionary, volley: int, k: int, t: float) -> Variant:
	var age: float = _lane_age(l, t) - volley * DART_VOLLEY_GAP
	if age < 0.0 or age * DART_SPEED > l.span:
		return null
	return l.origin + l.dir * age * DART_SPEED + l.spread * (k - 1) * DART_SPREAD


func _place_darts(t: float) -> void:
	var i := 0
	for l in _lanes:
		for v in l.volleys:
			for k in 3:
				var d := _darts[i]
				var p: Variant = _dart_pos(l, v, k, t)
				d.visible = p != null
				if p != null:
					d.position = p
					d.rotation.y = atan2(-l.dir.z, l.dir.x)
				i += 1


## 踩机关砖、飞镖射中谁就把谁推开、扣分（每人 1 秒内只算一次）
func _update_darts(g: Node) -> void:
	for l in _lanes:
		if l.trap and _time - l.fire_at > 1.6:
			for b in g.bearers:
				var f: Vector3 = b.global_position
				if l.tile.has_point(Vector2(f.x, f.z)) and f.y < 1.5:
					l.fire_at = _time + TRAP_DELAY
					_say_once("trap", "咔哒……脚下的砖陷下去了，快走！")
					break
		for v in l.volleys:
			for k in 3:
				var p: Variant = _dart_pos(l, v, k, _time)
				if p == null:
					continue
				for b in g.bearers:
					var d: Vector3 = b.global_position - p
					if Vector2(d.x, d.z).length() > DART_HIT_RADIUS or absf(d.y) > 0.9:
						continue
					if _time - _dart_hit_at.get(b, -10.0) < 1.0:
						continue
					_dart_hit_at[b] = _time
					_dart_hits += 1
					b.knock(l.dir * 6.0 + Vector3.UP * 4.0, 1.0)
					notice.emit("嗖——被飞镖撞飞了！")


func _build_dart_corridor() -> void:
	var h := CORRIDOR_HALF
	var wt := WALL_T / 2
	var n_wall := TURN_Z + h  # 西拐那段的北墙
	var s_wall := TURN_Z - h
	# A 段：南北向，三排节奏飞镖
	_floor(Vector3(-h, 0, GATE_Z), Vector3(h, 0, n_wall), _m.paving, 3.0)
	_wall_z(-h - wt, GATE_Z, SECRET2_Z[0], 0.0, _m.wall)
	_wall_z(-h - wt, SECRET2_Z[1], n_wall, 0.0, _m.wall)
	_fake_wall(Vector3(WALL_T, WALL_H, SECRET2_Z[0] - SECRET2_Z[1]), Vector3(-h - wt, WALL_H / 2, (SECRET2_Z[0] + SECRET2_Z[1]) / 2))
	_floor(Vector3(-h - 2.6, 0, SECRET2_Z[0] + 0.4), Vector3(-h - WALL_T, 0, SECRET2_Z[1] - 0.4), _m.paving, 3.0)
	_wall_z(-h - 2.6, SECRET2_Z[1] - 0.4, SECRET2_Z[0] + 0.4, 0.0, _m.wall)
	_wall_x(SECRET2_Z[0] + 0.4, -h - 2.6, -h - WALL_T, 0.0, _m.wall)
	_wall_x(SECRET2_Z[1] - 0.4, -h - 2.6, -h - WALL_T, 0.0, _m.wall)
	_wreath(Vector3(-h - 1.4, 0, (SECRET2_Z[0] + SECRET2_Z[1]) / 2), 15.0, 0.45, Color(0.25, 0.55, 0.45), "莲花环")
	_discover("secret", "墙里的暗室", Vector3(-h - 1.4, 1.0, (SECRET2_Z[0] + SECRET2_Z[1]) / 2), Vector3(1.8, 2.0, 1.8))
	_wall_z(h + wt, GATE_Z, s_wall, 0.0, _m.wall)
	for i in 3:
		_periodic_row(0.0, [-48.0, -53.0, -58.0][i], 1.0 if i % 2 == 0 else -1.0, 4.0, i * 1.3, 3)
	# 拐角 + B 段：往西，地上一路机关砖
	_floor(Vector3(WEST_X - h, 0, n_wall), Vector3(h, 0, s_wall), _m.paving, 3.0)
	_wall_x(n_wall + wt, WEST_X - h - WALL_T, -h - WALL_T)
	_wall_x(s_wall - wt, WEST_X + h, h + WALL_T)
	_wall_z(WEST_X - h - wt, n_wall + WALL_T, s_wall, 0.0, _m.wall)
	for i in TRAP_XS.size():
		_trap_lane(TRAP_XS[i], TURN_Z + (0.9 if i % 2 == 0 else -0.9))
	_sign("机关砖：踩了就别停", Vector3(-2.5, 2.6, TURN_Z))
	# C 段：往南，三排更密的飞镖，然后下坡
	_floor(Vector3(WEST_X - h, 0, s_wall), Vector3(WEST_X + h, 0, RAMP_Z[0]), _m.paving, 3.0)
	_ramp(Vector3(WEST_X, 0, RAMP_Z[0]), Vector3(WEST_X, HALL_Y, RAMP_Z[1]), h * 2, _m.paving, 1.5)
	for s in [-1.0, 1.0]:
		_wall_z(WEST_X + s * (h + wt), s_wall, RAMP_Z[0], 0.0, _m.wall)
		_wall_z(WEST_X + s * (h + wt), RAMP_Z[0], RAMP_Z[1], HALL_Y, _m.wall, WALL_H - HALL_Y)
	for i in 3:
		_periodic_row(WEST_X, [-70.0, -75.0, -80.0][i], -1.0 if i % 2 == 0 else 1.0, 3.6, 0.4 + i * 0.9, 4)
	_sign("这几排射得更密", Vector3(WEST_X, 2.6, -67.0))
	# 火把、骨头和飞镖
	for p in [Vector3(-h, 1.15, -50.5), Vector3(h, 1.15, -55.5), Vector3(-h, 1.15, -60.5)]:
		_put(PropsEgypt.torch(p.x < 0), p, -signf(p.x) * PI / 2)
	for p in [Vector3(WEST_X - h, 1.15, -72.5), Vector3(WEST_X + h, 1.15, -77.5)]:
		_put(PropsEgypt.torch(), p, -signf(p.x - WEST_X) * PI / 2)
	_put(PropsEgypt.torch(), Vector3(-8.5, 1.15, s_wall), 0.0)
	for p in [Vector3(-1.2, 0.04, -49.4), Vector3(1.0, 0.04, -54.6), Vector3(-5.5, 0.04, -63.2),
			Vector3(WEST_X + 0.8, 0.04, -71.0)]:
		var bone := Art.mesh(Art.capsule(0.04, 0.4), Props.WHITE, p)
		bone.rotation = Vector3(PI / 2, p.x, 0)
		add_child(bone)
		add_child(Art.mesh(Art.sphere(0.09), Props.WHITE, p + Vector3(0.25, 0.04, 0.05)))
	_wreath(Vector3(WEST_X - 1.2, 0, TURN_Z + 1.1), 10.0, 0.45, Color(0.25, 0.55, 0.45), "莲花环")  # 拐角里
	for l in _lanes:
		for v in l.volleys:
			for k in 3:
				var d := PropsEgypt.dart()
				d.visible = false
				add_child(d)
				_darts.append(d)
	_sign("看准节奏再过去", Vector3(0, 4.4, GATE_Z + 1.0))


# ---------- 3 塌陷地板 ----------

func _add_tile(c: Vector3, group: String, row: int, fall_after: float, material: Material) -> void:
	var body := StaticBody3D.new()
	body.position = c - Vector3(0, 0.25, 0)
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(TILE - 0.04, 0.5, TILE - 0.04)
	cs.shape = shape
	body.add_child(cs)
	add_child(body)
	var mesh := Art.block(Vector3(TILE - 0.06, 0.6, TILE - 0.06), c - Vector3(0, 0.3, 0), material)
	add_child(mesh)
	_tiles.append({cs = cs, mesh = mesh, base_y = c.y - 0.3, center = c, state = 0.0, fall_after = fall_after,
		group = group, row = row, waved = false})


func _build_tile_rooms() -> void:
	var half := TILE * 3.0  # 大厅 6 块砖宽
	var x0 := WEST_X - half
	var x1 := WEST_X + half
	# 入口平台、两段之间的歇脚平台、出口平台
	_floor(Vector3(x0, HALL_Y, RAMP_Z[1]), Vector3(x1, HALL_Y, HALL_Z[0]), _m.paving, 1.5)
	_floor(Vector3(x0, HALL_Y, HALL_Z[1]), Vector3(x1, HALL_Y, BRIDGE_Z[0]), _m.paving, 1.5)
	_floor(Vector3(x0, HALL_Y, BRIDGE_Z[1]), Vector3(x1, HALL_Y, CHASE_Z[0]), _m.paving, 1.5)
	_floor(Vector3(x0, HALL_Y, CHASE_Z[1]), Vector3(x1, HALL_Y, DOOR_ROOM_Z[0]), _m.paving, 1.5)
	# A：大厅，6 × 8，站 1 秒就塌
	for row in 8:
		for col in 6:
			if not [row, col] in HALL_HOLES:
				_add_tile(Vector3(x0 + TILE * (col + 0.5), HALL_Y, HALL_Z[0] - TILE * (row + 0.5)), "hall", row, 1.0, _m.tomb)
	# B：之字形窄桥，2 块宽，0.75 秒就塌
	for row in 8:
		for col in 2:
			var cx: float = WEST_X + BRIDGE_SHIFT[row] + TILE * (col - 0.5)
			_add_tile(Vector3(cx, HALL_Y, BRIDGE_Z[0] - TILE * (row + 0.5)), "bridge", row, 0.75, _m.tomb_fast)
	# C：3 块宽的长跑道，一踩上去，身后就一排排追着塌
	for row in 10:
		for col in 3:
			_add_tile(Vector3(WEST_X + TILE * (col - 1), HALL_Y, CHASE_Z[0] - TILE * (row + 0.5)), "chase", row, 99.0, _m.tomb)
	var wx := half + WALL_T / 2
	for s in [-1.0, 1.0]:
		_wall_z(WEST_X + s * wx, DOOR_ROOM_Z[0], RAMP_Z[1], HALL_Y - 3.0, _m.wall, WALL_H + 3.0)
		for z in [-97.0, -111.0, -127.0]:
			_put(PropsEgypt.torch(), Vector3(WEST_X + s * half, HALL_Y + 1.15, z), -s * PI / 2)
		_put(PropsEgypt.anubis(2.2), Vector3(WEST_X + s * (half - 0.6), HALL_Y, BRIDGE_Z[1] - 0.9), PI)
		_solid(Vector3(0.7, 2.0, 0.7), Vector3(WEST_X + s * (half - 0.6), HALL_Y + 1.0, BRIDGE_Z[1] - 0.9))
	# 深渊底下的尖刺（只是看的）
	for i in 24:
		add_child(Art.mesh(Art.cylinder(0.0, 0.25, 1.2, 4), PropsEgypt.DARK_STONE,
			Vector3(x0 + 0.6 + (i % 7) * 1.2, HALL_Y - 6.0, HALL_Z[0] - 2.0 - (i / 7) * 9.0 - (i % 3) * 1.3)))
	_wreath(Vector3(x1 - 0.7, HALL_Y, HALL_Z[0] - TILE * 6.5), 10.0, 0.45, Color(0.25, 0.55, 0.45), "莲花环")
	_sign("别在一块砖上停太久", Vector3(WEST_X, HALL_Y + 2.8, HALL_Z[0] - 3.0))
	_sign("桥更窄，砖塌得更快", Vector3(WEST_X, HALL_Y + 2.8, BRIDGE_Z[0] - 1.5))
	_sign("跑起来！", Vector3(WEST_X, HALL_Y + 2.8, CHASE_Z[0] - 1.5))


## 谁（抬棺人、或者放在地上的棺材）一直踩在砖上，砖就开始抖，踩满 fall_after 秒塌下去，8 秒后复原。
## 跑道那一段不看踩多久：一踩上去就从第一排开始往前追着塌
func _update_tiles(g: Node, delta: float) -> void:
	var feet: Array[Vector3] = []
	for b in g.bearers:
		feet.append(b.global_position - Vector3(0, 0.9, 0))
	feet.append(g.coffin.global_position - Vector3(0, 0.25, 0))
	var chase_front := int(floor((_time - _chase_t0) * CHASE_SPEED / TILE)) if _chase_t0 >= 0.0 else -1
	var chase_busy := false
	for t in _tiles:
		if t.state < 0.0:
			t.state = minf(t.state + delta, 0.0)
		else:
			var on := false
			for f in feet:
				var d: Vector3 = f - t.center
				if absf(d.x) < TILE / 2 and absf(d.z) < TILE / 2 and absf(d.y) < 0.25:
					on = true
					break
			if t.group == "chase":
				if on and _chase_t0 < 0.0:
					_chase_t0 = _time + 1.2  # 等后面那个人也离开第一排
					notice.emit("身后的地板开始塌了——跑！")
				if not t.waved and t.row <= chase_front:
					t.waved = true
					t.state = -TILE_DOWN_TIME
			else:
				t.state = t.state + delta if on else 0.0
				if t.state >= t.fall_after:
					t.state = -TILE_DOWN_TIME
		if t.group == "chase" and (t.state != 0.0 or (t.waved and t.row > chase_front)):
			chase_busy = true
		_show_tile(t)
	# 整条跑道塌完又全部复原了：重新待命
	if _chase_t0 >= 0.0 and chase_front > 10 and not chase_busy:
		_chase_t0 = -1.0
		for t in _tiles:
			t.waved = false


func _show_tile(t: Dictionary) -> void:
	var s: float = t.state
	t.cs.disabled = s < 0.0
	var mesh: Node3D = t.mesh
	if s > -0.6 and s < 0.0:  # 最后 0.6 秒从下面升回来
		mesh.visible = true
		mesh.position = Vector3(t.center.x, t.base_y + s / 0.6 * 1.5, t.center.z)
	elif s < 0.0:  # 刚塌：加速往下掉，掉出视野就藏起来
		var since: float = TILE_DOWN_TIME + s
		mesh.visible = since < 1.2
		mesh.position = Vector3(t.center.x, t.base_y - since * since * 4.0, t.center.z)
	else:
		mesh.visible = true
		var shake: float = 0.0 if s < t.fall_after * 0.3 else 0.03 * s / t.fall_after * sin(_time * 70.0 + t.center.x * 3.0)
		mesh.position = Vector3(t.center.x + shake, t.base_y - s / t.fall_after * 0.04, t.center.z - shake)


# ---------- 4 封印石门 ----------

func _add_door(z: float, plate: Vector3, timed: bool) -> void:
	var body := AnimatableBody3D.new()
	body.add_to_group("hard")
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(DOOR_HALF * 2, DOOR_H, 0.4)
	cs.shape = shape
	body.add_child(cs)
	body.add_child(Art.block(Vector3(DOOR_HALF * 2, DOOR_H, 0.4), Vector3.ZERO, _m.wall))
	var eye := PropsEgypt._eye_decal(1.2)
	eye.rotation.x = PI / 2
	eye.position = Vector3(0, 0.4, 0.22)
	body.add_child(eye)
	body.position = Vector3(WEST_X, HALL_Y + DOOR_H / 2, z)
	add_child(body)
	add_child(Art.block(Vector3(DOOR_HALF * 2 + 0.6, 0.5, 0.6), Vector3(WEST_X, HALL_Y + DOOR_H + DOOR_OPEN + 0.25, z), _m.wall))
	var pm := PropsEgypt.plate_top(PLATE_SIZE)
	pm.position = plate
	add_child(pm)
	var wx := ROOM_HALF + WALL_T / 2
	for s in [-1.0, 1.0]:
		_wall_x(z, WEST_X + s * DOOR_HALF, WEST_X + s * wx, HALL_Y, _m.wall)
		_put(PropsEgypt.anubis(2.4), Vector3(WEST_X + s * (DOOR_HALF + 0.75), HALL_Y, z + 0.6))
		_solid(Vector3(0.7, 2.0, 0.7), Vector3(WEST_X + s * (DOOR_HALF + 0.75), HALL_Y + 1.0, z + 0.6))
	_doors.append({body = body, z = z, lift = 0.0, plate = plate, plate_mesh = pm, pressed = false, timed = timed})


func _build_door_room() -> void:
	var z0: float = DOOR_ROOM_Z[0]
	var z1: float = DOOR_ROOM_Z[1]
	var wx := ROOM_HALF + WALL_T / 2
	_floor(Vector3(WEST_X - ROOM_HALF, HALL_Y, z0), Vector3(WEST_X + ROOM_HALF, HALL_Y, z1), _m.paving, 2.0)
	for s in [-1.0, 1.0]:
		_wall_z(WEST_X + s * wx, z1, z0, HALL_Y, _m.wall)
		_wall_x(z0, WEST_X + s * 2.2, WEST_X + s * wx, HALL_Y, _m.wall)  # 和跑道之间的门洞
		for z in [-142.6, -154.6, -159.6]:
			_put(PropsEgypt.torch(), Vector3(WEST_X + s * ROOM_HALF, HALL_Y + 1.15, z), -s * PI / 2)
		for z in [z0 - 1.0, DOOR1_Z + 1.0]:
			_put(PropsEgypt.column(2.6), Vector3(WEST_X + s * (ROOM_HALF - 0.6), HALL_Y, z))
			_solid(Vector3(0.7, 2.6, 0.7), Vector3(WEST_X + s * (ROOM_HALF - 0.6), HALL_Y + 1.3, z))
	_add_door(DOOR1_Z, PLATE1, false)
	_add_door(z1, PLATE2, true)
	_block = RigidBody3D.new()
	_block.mass = 60.0
	_block.lock_rotation = true  # 推的时候只滑不转，不容易被推歪
	_block.add_to_group("grabbable")
	_block.physics_material_override = PhysicsMaterial.new()
	_block.physics_material_override.friction = 0.5
	var bcs := CollisionShape3D.new()
	var bshape := BoxShape3D.new()
	bshape.size = Vector3(1.6, 1.0, 1.0)
	bcs.shape = bshape
	_block.add_child(bcs)
	_block.add_child(Art.block(Vector3(1.6, 1.0, 1.0), Vector3.ZERO, _m.low_wall))
	_block.add_child(Art.mesh(Art.box(Vector3(0.6, 0.6, 0.02)), PropsEgypt.LAPIS, Vector3(0, 0, 0.51)))
	_block.position = BLOCK_START
	add_child(_block)
	add_child(Art.mesh(Art.box(Vector3(0.9, 0.01, PLATE1.z - BLOCK_START.z)), PropsEgypt.SAND.darkened(0.2),
		Vector3(PLATE1.x, HALL_Y + 0.005, (PLATE1.z + BLOCK_START.z) / 2)))  # 拖痕：从石块指到压力板
	_wreath(Vector3(WEST_X + 3.6, HALL_Y, z1 + 1.2), 10.0, 0.45, Color(0.25, 0.55, 0.45), "莲花环")
	_sign("门打不开？\n地上那块板子好像能踩下去", Vector3(WEST_X, HALL_Y + 2.8, -141.6))
	_sign("这扇门松开 7 秒就关", Vector3(WEST_X, HALL_Y + 2.8, -155.6))


## 压力板上有够重的东西（石块或者人）就升门。第一道门没东西压着就慢慢落下；
## 第二道门一松开就开始往下关，7 秒关死。门下有人时不落，免得压到人
func _update_doors(g: Node, delta: float) -> void:
	var weights: Array[RigidBody3D] = [_block]
	weights.append_array(g.bearers)
	for door in _doors:
		var pressed := false
		for w in weights:
			var d: Vector3 = w.global_position - door.plate
			if absf(d.x) < PLATE_SIZE / 2 + 0.3 and absf(d.z) < PLATE_SIZE / 2 + 0.3 and d.y < 1.2:
				pressed = true
		_set_plate(door, pressed)
		var blocked: bool = g.team_bodies().any(func(b): return b.is_inside_tree() \
			and absf(b.global_position.z - door.z) < 0.8 and absf(b.global_position.x - WEST_X) < DOOR_HALF)
		if pressed:
			door.lift = minf(door.lift + (2.6 if door.timed else 1.2) * delta, DOOR_OPEN)
			if door.lift > 0.5:
				_say_once("door%d" % _doors.find(door), "轰隆隆……石门升起来了")
		elif not blocked:
			door.lift = maxf(door.lift - (DOOR_OPEN / DOOR2_CLOSE_TIME if door.timed else 0.6) * delta, 0.0)
		_place_door(door)


func _place_door(door: Dictionary) -> void:
	door.body.position.y = HALL_Y + DOOR_H / 2 + door.lift


func _set_plate(door: Dictionary, down: bool) -> void:
	door.pressed = down
	door.plate_mesh.position.y = door.plate.y - (0.03 if down else 0.0)


# ---------- 5 滚石长廊 ----------

## 中线上每隔几秒从北墙的洞里滚出一个大石球，一直滚到南头的铁栅栏掉下去。
## 长廊里横倒着三块巨石，一会儿挡东边一会儿挡西边，逼着你来回穿过石球滚的那条线
func _build_boulder_hall() -> void:
	var z0: float = BOULDER_Z[0]
	var z1: float = BOULDER_Z[1]
	var h := BOULDER_HALF
	_floor(Vector3(WEST_X - h, HALL_Y, z0), Vector3(WEST_X + h, HALL_Y, z1), _m.paving, 2.0)
	for s in [-1.0, 1.0]:
		_wall_z(WEST_X + s * (h + WALL_T / 2), z1, z0, HALL_Y, _m.wall, WALL_H + 0.6)
		for z in [-168.0, -176.0, -184.0]:
			_put(PropsEgypt.torch(), Vector3(WEST_X + s * h, HALL_Y + 1.15, z), -s * PI / 2)
	_wall_x(z1, WEST_X - h, WEST_X + EXIT5[0], HALL_Y, _m.wall, WALL_H + 0.6)
	add_child(Art.block(Vector3(2.4, 2.4, 0.05), Vector3(WEST_X, HALL_Y + 1.2, z1 + 0.17), Art.mat(Color(0.05, 0.03, 0.02))))  # 石球出来的黑洞
	add_child(Art.block(Vector3(3.0, 0.05, 1.6), Vector3(WEST_X, HALL_Y + 0.03, BOULDER_END), Art.mat(Color(0.12, 0.1, 0.08))))  # 南头的铁栅栏
	for k in 5:
		add_child(Art.mesh(Art.box(Vector3(0.08, 0.06, 1.6)), PropsEgypt.DARK_STONE, Vector3(WEST_X - 1.2 + k * 0.6, HALL_Y + 0.06, BOULDER_END)))
	for b in BLOCKS:
		var size := Vector3(b[1] - b[0], 1.6, absf(b[3] - b[2]))
		var c := Vector3(WEST_X + (b[0] + b[1]) / 2, HALL_Y + 0.8, (b[2] + b[3]) / 2)
		_collider(size, c, true)
		add_child(Art.block(size, c, _m.low_wall))
		_put(PropsEgypt.column(1.0, 0.3), c + Vector3(0, 0.8, 0))
	var ball := func() -> Node3D:
		var n := Node3D.new()
		n.add_child(Art.mesh(Art.sphere(BOULDER_R), PropsEgypt.SANDSTONE.darkened(0.15)))
		n.add_child(Art.mesh(Art.box(Vector3(BOULDER_R * 2.02, 0.12, 0.3)), PropsEgypt.DARK_STONE))  # 一道刻痕，看得出在滚
		return n
	var tr := Traps.Shooter.new(Vector3(WEST_X, HALL_Y + BOULDER_R, z1 - 0.5), Vector3(WEST_X, HALL_Y + BOULDER_R, BOULDER_END),
		6.0, 4.5, 0.0, BOULDER_R, ball)
	tr.roll = true
	tr.text = "被滚石撞飞了！"
	_trap(tr, "boulder")
	_wreath(Vector3(WEST_X - 3.2, HALL_Y, -175.0), 10.0, 0.45, Color(0.25, 0.55, 0.45), "莲花环")
	_sign("石球滚过来了！躲到巨石后面", Vector3(WEST_X, HALL_Y + 3.0, z0 - 1.0))


# ---------- 6 刀摆深渊 ----------

## 一个大坑，两条路：东边是窄石桥，桥上三把摆刀来回荡（快）；西边坐来回开的木筏（慢但稳）
func _build_abyss() -> void:
	var z0: float = ABYSS_Z[0]
	var z1: float = ABYSS_Z[1]
	var h := BOULDER_HALF
	_floor(Vector3(WEST_X - h, HALL_Y, z0), Vector3(WEST_X + h, HALL_Y, PIT_Z[0]), _m.paving, 2.0)
	_floor(Vector3(WEST_X - h, HALL_Y, PIT_Z[1]), Vector3(WEST_X + h, HALL_Y, z1), _m.paving, 2.0)
	for s in [-1.0, 1.0]:
		_wall_z(WEST_X + s * (h + WALL_T / 2), PIT_Z[0], z0, HALL_Y, _m.wall, WALL_H + 0.6)  # 坑上面不要墙，免得挡住视线
		_wall_z(WEST_X + s * (h + WALL_T / 2), z1, PIT_Z[1], HALL_Y, _m.wall, WALL_H + 0.6)
	# 东：摆刀石桥
	var bx: float = WEST_X + BLADE_X
	_floor(Vector3(bx - 1.2, HALL_Y, PIT_Z[0]), Vector3(bx + 1.2, HALL_Y, PIT_Z[1]), _m.tomb, 1.0)
	add_child(Art.block(Vector3(2.8, 0.4, PIT_Z[0] - PIT_Z[1]), Vector3(bx, HALL_Y + 5.2, (PIT_Z[0] + PIT_Z[1]) / 2), _m.wall))
	for k in BLADES.size():
		var head := Node3D.new()
		var blade := Art.mesh(Art.box(Vector3(1.5, 0.5, 0.08)), PropsEgypt.GOLD)
		head.add_child(blade)
		head.add_child(Art.mesh(Art.box(Vector3(1.55, 0.1, 0.1)), PropsEgypt.DARK_STONE, Vector3(0, 0.25, 0)))
		var tr := Traps.Pendulum.new(Vector3(bx, HALL_Y + 5.0, BLADES[k]), 4.3, Vector3.RIGHT, 0.75, 3.0, k * 0.33, head, 0.55,
			PropsEgypt.DARK_STONE)
		tr.text = "被摆刀扫飞了！"
		_trap(tr, "blade%d" % k)
	_sign("近路：躲开摆刀", Vector3(bx, HALL_Y + 2.6, PIT_Z[0] + 0.8))
	# 西：木筏
	var rx: float = WEST_X + RAFT_X
	var raft := Traps.Mover.new(Vector3(rx, HALL_Y, PIT_Z[0] - 1.8), Vector3(rx, HALL_Y, PIT_Z[1] + 1.8),
		Vector3(3.2, 0.5, 3.2), 5.0, 4.0, _m.tomb)
	_trap(raft, "raft")
	_sign("等木筏靠岸再上", Vector3(rx, HALL_Y + 2.6, PIT_Z[0] + 0.8))
	# 坑底的尖刺（只是看的）
	for i in 18:
		add_child(Art.mesh(Art.cylinder(0.0, 0.25, 1.2, 4), PropsEgypt.DARK_STONE,
			Vector3(WEST_X - 3.4 + (i % 6) * 1.35, HALL_Y - 6.0, PIT_Z[0] - 1.5 - (i / 6) * 5.0 - (i % 2) * 1.2)))
	_wreath(Vector3(bx, HALL_Y, (PIT_Z[0] + PIT_Z[1]) / 2), 15.0, 0.45, Color(0.25, 0.55, 0.45), "莲花环")  # 摆刀桥正中间
	_discover("shortcut", "摆刀桥", Vector3(bx, HALL_Y + 1.0, PIT_Z[1] + 2.0), Vector3(2.4, 2.0, 1.5))
	for s in [-1.0, 1.0]:
		_put(PropsEgypt.torch(), Vector3(WEST_X + s * h, HALL_Y + 1.15, z0 - 1.5), -s * PI / 2)
		_put(PropsEgypt.torch(), Vector3(WEST_X + s * h, HALL_Y + 1.15, z1 + 1.5), -s * PI / 2)
	_wall_x(z1, WEST_X - h, WEST_X - 1.8, HALL_Y, _m.tomb_wall)
	_wall_x(z1, WEST_X + 1.8, WEST_X + h, HALL_Y, _m.tomb_wall)


# ---------- 7 法老墓室 ----------

func _build_tomb() -> void:
	var z0: float = TOMB_Z[0]
	var z1: float = TOMB_Z[1]
	var half := 4.0
	# 地面：石棺正前方那块是假的（踩上去就塌）
	var f: Array = TOMB_FAKE
	_floor(Vector3(WEST_X - half, HALL_Y, z0), Vector3(WEST_X + half, HALL_Y, f[2]), _m.gold_floor, 2.0)
	_floor(Vector3(WEST_X - half, HALL_Y, f[3]), Vector3(WEST_X + half, HALL_Y, z1), _m.gold_floor, 2.0)
	_floor(Vector3(WEST_X - half, HALL_Y, f[2]), Vector3(WEST_X + f[0], HALL_Y, f[3]), _m.gold_floor, 2.0)
	_floor(Vector3(WEST_X + f[1], HALL_Y, f[2]), Vector3(WEST_X + half, HALL_Y, f[3]), _m.gold_floor, 2.0)
	var fake := Traps.FakeFloor.new(Vector3(WEST_X + f[0], HALL_Y, f[2]), Vector3(WEST_X + f[1], HALL_Y, f[3]), _m.gold_floor, 2.0)
	fake.down = 6.0
	_trap(fake)
	_sign("终于到了！\n直接走过去就好", Vector3(WEST_X, HALL_Y + 2.6, z0 - 1.2))
	var wx := half + WALL_T / 2
	for s in [-1.0, 1.0]:
		_wall_z(WEST_X + s * wx, z1, z0, HALL_Y, _m.tomb_wall)
		_put(PropsEgypt.torch(), Vector3(WEST_X + s * half, HALL_Y + 1.15, z0 - 5.0), -s * PI / 2)
		_put(PropsEgypt.column(2.8), Vector3(WEST_X + s * (half - 0.6), HALL_Y, z1 + 0.8))
		_solid(Vector3(0.7, 2.8, 0.7), Vector3(WEST_X + s * (half - 0.6), HALL_Y + 1.4, z1 + 0.8))
		for k in 3:
			_put(PropsEgypt.canopic_jar([Color(0.85, 0.75, 0.55), PropsEgypt.BLACK, PropsEgypt.TURQUOISE][k]),
				Vector3(WEST_X + s * 3.4, HALL_Y, goal_pos.z - 0.9 + k * 0.4))
		_put(PropsEgypt.gold_pile(), Vector3(WEST_X + s * 3.0, HALL_Y, z0 - 2.0))
	_wall_x(z1, WEST_X - wx, WEST_X + wx, HALL_Y, _m.tomb_wall)
	# 灵台就是法老的石棺
	_collider(goal_size, goal_pos + Vector3(0, goal_size.y / 2, 0), false)
	_put(PropsEgypt.sarcophagus(goal_size.x), goal_pos, PI / 2)
	_put(PropsEgypt.scarab(1.4), Vector3(WEST_X, HALL_Y, z1 + 0.9), 0.0)
	_lamp(Vector3(WEST_X, HALL_Y + 3.0, goal_pos.z), 1.2, 8.0, Color(1.0, 0.8, 0.45))
	_sign("把法老放进他的石棺", goal_pos + Vector3(0, 2.6, 0))


# ---------- 远景 ----------

func _build_backdrop() -> void:
	_put(PropsEgypt.pyramid(22.0, 12), Vector3(-34, -6, -40))
	_put(PropsEgypt.pyramid(14.0, 9), Vector3(14, -5, -110))
	_put(PropsEgypt.pyramid(18.0, 10), Vector3(-42, -6, -150))
	_put(PropsEgypt.pyramid(10.0, 7), Vector3(-22, -4, 10))
	for p in [Vector3(20, -7, -10), Vector3(6, -10, -80), Vector3(-36, -12, -100), Vector3(4, -12, -170)]:
		add_child(Art.block(Vector3(6, 3, 5), p, _m.sand))
		_put(PropsEgypt.palm(2.6), p + Vector3(1.0, 1.5, 0.5))
