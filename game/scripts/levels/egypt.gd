extends Level
## 埃及关「法老的最后一程」：从金色黄昏的沙漠进入地下陵墓，一路往下，最后把法老送进黄金墓室。
## 整关沿 -Z 方向推进，房间之间用短甬道（或斜坡）连着，每进一间就是一个检查点。
##
## 机关都按时间或状态算：
##   - 飞镖：按 tick(t) 的时间算位置，房主和加入方各算各的，不用同步
##   - 塌陷地板、石门：房主算状态，放进 net_state() 发给加入方
##   - 大石块：真刚体，放进 net_bodies() 跟整队一起同步位置

const SAND_SPEED := 0.6  # 沙地里走路速度打几折
const SAND_TRACTION := 0.55

# 1 沙漠入口
const DESERT_X := 7.0
const GATE_Z := -22.0
# 2 飞镖甬道
const CORRIDOR_HALF := 1.9
const DART_ROWS := [-26.0, -31.0, -36.0]
const DART_PERIOD := 4.0
const DART_ROW_OFFSET := 1.3  # 每排比前一排晚这么久发射
const DART_VOLLEYS := 3
const DART_VOLLEY_GAP := 0.25
const DART_SPEED := 7.0
const DART_HEIGHT := 1.0
const DART_SPREAD := 0.4  # 一排里三支飞镖前后的间距
const DART_HIT_RADIUS := 0.32
const DART_PENALTY := 5.0
const RAMP_Z := [-37.5, -43.5]  # 甬道尽头往下的斜坡
# 3 塌陷地板厅
const HALL_Y := -1.5
const TILE := 1.4
const TILE_COLS := 6
const TILE_ROWS := 10
const TILE_Z0 := -46.0  # 第一排砖的北边
const TILE_FALL_AFTER := 1.0  # 被踩这么久就塌
const TILE_DOWN_TIME := 8.0  # 塌下去这么久后复原
const TILE_HOLES := [[2, 0], [2, 1], [2, 2], [5, 3], [5, 4], [5, 5], [8, 0], [8, 5]]  # [排, 列]：一开始就没有的砖
# 4 封印石门
const DOOR_ROOM_Z := [-61.5, -74.0]
const DOOR_HALF := 1.8
const DOOR_H := 2.4
const DOOR_OPEN := 2.6  # 门完全升起时比平时高多少
const PLATE := Vector3(3.0, HALL_Y, -70.0)
const PLATE_SIZE := 1.6
const BLOCK_START := Vector3(3.0, HALL_Y + 0.5, -65.0)
# 临时墓室（第 2 步先放在石门后面，之后挪到最后一间）
const TOMB_Z := [-74.0, -86.0]

var _time := 0.0
var _darts: Array[Node3D] = []
var _dart_hit_at := {}  # 抬棺人 → 上次被射中的时间（冷却用）
var _dart_hits := 0
var _tiles: Array = []  # 每块砖：{body, cs, mesh, base_y, state}；state ≥ 0 是被踩了多久，< 0 是还要多久复原
var _block: RigidBody3D
var _door: AnimatableBody3D
var _door_lift := 0.0
var _plate_mesh: Node3D
var _plate_down := false
var _sand_said := false
var _door_said := false


func _init() -> void:
	id = "egypt"
	title = "法老的最后一程"
	par_time = 20.0 * 60.0
	kill_y = -9.0
	goal_pos = Vector3(-1.6, HALL_Y, -81.5)  # 石棺靠西边放：棺材要顺着长边推上去，抬棺人走在两侧
	goal_size = Vector3(2.0, 0.85, 1.0)
	rooms = [
		{name = "沙漠入口", spawn = Vector3(0, 0, 3), lift = 1.32, yaw = 0.0,
			path = [Vector3(0, 0, -5), Vector3(0, 0, -13), Vector3(0, 0, -20), Vector3(0, 0, -23.5)]},
		{name = "飞镖甬道", spawn = Vector3(0, 0, -23.5), yaw = 0.0,
			path = ["wait:dart0", Vector3(0, 0, DART_ROWS[0] - 2.5), "wait:dart1", Vector3(0, 0, DART_ROWS[1] - 2.5),
				"wait:dart2", Vector3(0, 0, DART_ROWS[2] - 2.5), Vector3(0, 0, -41.0), Vector3(0, 0, -45.2)]},
		{name = "塌陷地板厅", spawn = Vector3(0, HALL_Y, -44.8), yaw = 0.0,
			path = [Vector3(1.6, 0, -47.5), Vector3(1.6, 0, -50.6), Vector3(-1.6, 0, -53.0), Vector3(-1.6, 0, -55.0),
				Vector3(0, 0, -57.5), Vector3(0, 0, -62.0)]},
		{name = "封印石门", spawn = Vector3(0, HALL_Y, -63.0), yaw = 0.0,
			path = [Vector3(BLOCK_START.x, 0, -63.4), Vector3(BLOCK_START.x, 0, PLATE.z + 1.6), "wait:door",
				Vector3(BLOCK_START.x, 0, -66.5), Vector3(0, 0, -67.5), Vector3(0, 0, -76.0)]},
		{name = "法老墓室", spawn = Vector3(0, HALL_Y, -76.5), yaw = 0.0, path = [Vector3(2.4, 0, -79.5), Vector3(2.4, 0, -81.5), goal_pos]},
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
	_m.gold_floor = Art.floor_mat({base_color = Color(0.5, 0.36, 0.2), speck_a = Color(0.95, 0.74, 0.3),
		speck_b = Color(1.0, 0.9, 0.6), speck_density = 0.5, grout_color = Color(0.85, 0.65, 0.25),
		side_color = Color(0.55, 0.42, 0.3), tile = 1.0, roughness = 0.35})
	_m.wall = Art.sandstone_mat()
	_m.low_wall = Art.sandstone_mat({frieze_h = 0.0})
	_m.tomb_wall = Art.sandstone_mat({stone = Color(0.7, 0.56, 0.4), mortar = Color(0.5, 0.38, 0.26)})
	_build_desert()
	_build_dart_corridor()
	_build_tile_hall()
	_build_door_room()
	_build_tomb()
	_build_backdrop()


func room_at(p: Vector3) -> int:
	if p.z > GATE_Z - 0.5:
		return 0
	if p.z > RAMP_Z[1] - 1.0:
		return 1
	if p.z > DOOR_ROOM_Z[0] - 0.5:
		return 2
	if p.z > DOOR_ROOM_Z[1] - 1.0:
		return 3
	return 4


# ---------- 每帧的机关 ----------

func tick(t: float) -> void:
	_time = t
	_place_darts(t)


func physics_update(g: Node) -> void:
	_update_sand(g)
	_update_darts(g)
	_update_tiles(g, get_physics_process_delta_time())
	_update_door(g, get_physics_process_delta_time())


func bot_can_go(tag: String) -> bool:
	if tag.begins_with("dart"):
		# 这一排刚射完：接下来有将近 3 秒是安全的
		var ph := _dart_phase(int(tag.substr(4)), _time)
		var end := (DART_VOLLEYS - 1) * DART_VOLLEY_GAP + 2.0 * CORRIDOR_HALF / DART_SPEED
		return ph > end and ph < end + 0.5
	if tag == "door":
		return _door_lift > DOOR_OPEN - 0.3
	return true


func debug_text() -> String:
	var shaking := _tiles.filter(func(t): return t.state > 0.0).size()
	var down := _tiles.filter(func(t): return t.state < 0.0).size()
	return "block=%s door=%.2f plate=%s tiles shaking=%d down=%d dart_hits=%d" % [
		_block.global_position.snapped(Vector3.ONE * 0.01), _door_lift, _plate_down, shaking, down, _dart_hits]


func net_bodies() -> Array[RigidBody3D]:
	return [_block]


func net_state() -> PackedFloat32Array:
	var a := PackedFloat32Array([_door_lift, 1.0 if _plate_down else 0.0])
	for t in _tiles:
		a.append(t.state)
	return a


func apply_net_state(a: PackedFloat32Array) -> void:
	if a.size() < 2 + _tiles.size():
		return
	_door_lift = a[0]
	_door.position.y = HALL_Y + DOOR_H / 2 + _door_lift
	_set_plate(a[1] > 0.5)
	for i in _tiles.size():
		_tiles[i].state = a[2 + i]
		_show_tile(_tiles[i])


# ---------- 1 沙漠入口 ----------

## 沙地：抬棺人在沙漠里（不在石板路上）走得慢、刹不住
func _update_sand(g: Node) -> void:
	for b in g.bearers:
		var p: Vector3 = b.global_position
		var sand := p.z > GATE_Z and p.z < 6.0 and not (p.z > -3.0 and absf(p.x) < 1.6)
		b.speed_scale = SAND_SPEED if sand else 1.0
		b.traction = SAND_TRACTION if sand else 1.0
		if sand and not _sand_said and g.started:
			_sand_said = true
			notice.emit("沙子好软……走不快，也刹不住")


func _build_desert() -> void:
	var t := 4.0
	# 起点一段石板路，然后是一道沙丘：上坡、坡顶、下坡，最后是陵墓大门前的平地
	_floor(Vector3(-DESERT_X, 0, 6), Vector3(DESERT_X, 0, -4), _m.sand, t)
	_ramp(Vector3(0, 0, -4), Vector3(0, 0.9, -8), DESERT_X * 2, _m.sand, t)
	_floor(Vector3(-DESERT_X, 0.9, -8), Vector3(DESERT_X, 0.9, -11), _m.sand, t + 0.9)
	_ramp(Vector3(0, 0.9, -11), Vector3(0, 0, -15), DESERT_X * 2, _m.sand, t)
	_floor(Vector3(-DESERT_X, 0, -15), Vector3(DESERT_X, 0, GATE_Z), _m.sand, t)
	add_child(Art.block(Vector3(3.2, 0.04, 9.0), Vector3(0, 0.02, 1.5), _m.paving))  # 石板路（只是看的）
	# 两边是半埋在沙里的矮墙，挡着别掉下去
	for s in [-1.0, 1.0]:
		_wall_z(s * (DESERT_X - 0.15), GATE_Z, -15.0, 0.0, _m.low_wall, 0.7)
		_wall_z(s * (DESERT_X - 0.15), -4.0, 6.0, 0.0, _m.low_wall, 0.7)
		_wall_z(s * (DESERT_X - 0.15), -15.0, -4.0, 0.9, _m.low_wall, 0.7)  # 沙丘那段墙脚埋得高一点
	_wall_x(6.0 - 0.15, -DESERT_X, DESERT_X, 0.0, _m.low_wall, 0.7)

	# 起点：石头停棺台，两边各一座方尖碑
	for x in [-0.7, 0.7]:
		_box(Vector3(0.3, 1.09, 0.7), Vector3(x, 0.545, 3), PropsEgypt.DARK_STONE, false)
		add_child(Art.mesh(Art.box(Vector3(0.34, 0.04, 0.74)), PropsEgypt.GOLD, Vector3(x, 1.07, 3)))
	for x in [-2.6, 2.6]:
		_put(PropsEgypt.obelisk(4.2), Vector3(x, 0, 2.5))
		_solid(Vector3(0.75, 2.0, 0.75), Vector3(x, 1.0, 2.5))
	# 斯芬克斯趴在沙丘边上看着你
	_put(PropsEgypt.sphinx(5.5), Vector3(-4.6, 0, -17.5), 0.0)
	_solid(Vector3(4.6, 2.0, 2.2), Vector3(-4.6, 1.0, -17.5))
	for p in [Vector3(4.8, 0, 1.0), Vector3(5.6, 0, -2.6), Vector3(5.0, 0, -18.5), Vector3(-5.6, 0, 4.2)]:
		_put(PropsEgypt.palm(3.0 + absf(p.z) * 0.02), p, p.x)
		_solid(Vector3(0.3, 2.0, 0.3), p + Vector3(0, 1.0, 0))
	for p in [Vector3(-3.4, 0.9, -9.6), Vector3(4.2, 0.9, -9.0), Vector3(3.8, 0, -14.8)]:  # 沙丘上的碎石柱
		_put(PropsEgypt.column(1.0 + absf(p.x) * 0.15, 0.3), p)
		_solid(Vector3(0.7, 1.4, 0.7), p + Vector3(0, 0.7, 0))
	# 沙丘侧面堆起来的沙包（只是看的）
	for p in [Vector3(-5.5, 0.4, -9.5), Vector3(5.6, 0.4, -12.0), Vector3(-6.0, 0.2, -1.0), Vector3(2.0, 0.0, -19.8)]:
		var dune := Art.mesh(Art.sphere(1.0), PropsEgypt.SAND.darkened(0.04), p)
		dune.scale = Vector3(2.0, 0.45, 1.6)
		add_child(dune)
	_wreath(Vector3(5.0, 0.9, -9.5), 10.0, 0.5, Color(0.25, 0.55, 0.45), "莲花环")  # 沙丘边上：绕过去拿

	# 陵墓大门：两座梯形塔门，中间留一个门洞
	for s in [-1.0, 1.0]:
		var cx: float = s * (CORRIDOR_HALF + 2.3)
		_collider(Vector3(4.3, 4.0, 1.4), Vector3(cx, 2.0, GATE_Z), true)
		var tower := Art.mesh(Art.cylinder(1.6, 2.4, 4.0, 4), PropsEgypt.SANDSTONE, Vector3(cx, 2.0, GATE_Z))
		tower.rotation.y = PI / 4
		tower.scale = Vector3(1.25, 1.0, 0.45)
		add_child(tower)
		_put(PropsEgypt.torch(), Vector3(s * (CORRIDOR_HALF + 0.35), 1.3, GATE_Z + 0.72))
	add_child(Art.block(Vector3(CORRIDOR_HALF * 2 + 1.4, 0.7, 1.4), Vector3(0, 3.35, GATE_Z), _m.wall))
	add_child(Art.mesh(Art.box(Vector3(1.4, 0.4, 0.05)), PropsEgypt.LAPIS, Vector3(0, 3.35, GATE_Z + 0.73)))
	_put(Art.text("陵 墓", 64, PropsEgypt.GOLD, Vector3(0, 3.35, GATE_Z + 0.76)), Vector3.ZERO)
	_sign("沙地会拖慢脚步", Vector3(0, 2.8, -3.0))


# ---------- 2 飞镖甬道 ----------

## 第 row 排飞镖现在在一个周期里的第几秒
func _dart_phase(row: int, t: float) -> float:
	return fposmod(t - row * DART_ROW_OFFSET, DART_PERIOD)


## 第 row 排、第 volley 轮、第 k 支飞镖现在在哪（不在飞就返回 null）。偶数排从西墙射向东墙，奇数排反过来
func _dart_pos(row: int, volley: int, k: int, t: float) -> Variant:
	var age := _dart_phase(row, t) - volley * DART_VOLLEY_GAP
	var span := 2.0 * CORRIDOR_HALF
	if age < 0.0 or age * DART_SPEED > span:
		return null
	var dir := 1.0 if row % 2 == 0 else -1.0
	var x := -dir * CORRIDOR_HALF + dir * age * DART_SPEED
	var z: float = DART_ROWS[row] + (k - 1) * DART_SPREAD
	return Vector3(x, DART_HEIGHT, z)


func _place_darts(t: float) -> void:
	var i := 0
	for row in DART_ROWS.size():
		for v in DART_VOLLEYS:
			for k in 3:
				var d := _darts[i]
				var p: Variant = _dart_pos(row, v, k, t)
				d.visible = p != null
				if p != null:
					d.position = p
					d.rotation.y = 0.0 if row % 2 == 0 else PI
				i += 1


## 飞镖射中谁就把谁推开、扣分（每人 1 秒内只算一次）
func _update_darts(g: Node) -> void:
	for row in DART_ROWS.size():
		for v in DART_VOLLEYS:
			for k in 3:
				var p: Variant = _dart_pos(row, v, k, _time)
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
					var dir := 1.0 if row % 2 == 0 else -1.0
					b.apply_central_impulse(Vector3(dir * 110.0, 25.0, 0))
					penalty.emit(DART_PENALTY, "嗖——中了一镖！体面 -%d" % DART_PENALTY)


func _build_dart_corridor() -> void:
	var z0 := GATE_Z
	var z1: float = RAMP_Z[0]
	_floor(Vector3(-CORRIDOR_HALF, 0, z0), Vector3(CORRIDOR_HALF, 0, z1), _m.paving, 3.0)
	_ramp(Vector3(0, 0, z1), Vector3(0, HALL_Y, RAMP_Z[1]), CORRIDOR_HALF * 2, _m.paving, 1.5)
	var wx := CORRIDOR_HALF + WALL_T / 2
	for s in [-1.0, 1.0]:
		_wall_z(s * wx, z1, z0, 0.0, _m.wall)
		_wall_z(s * wx, RAMP_Z[1], z1, HALL_Y, _m.wall, WALL_H - HALL_Y)
	# 每排墙上一组蛇头射孔（对面墙上画一排箭靶一样的凹痕），中间点火把
	for row in DART_ROWS.size():
		var dir := 1.0 if row % 2 == 0 else -1.0
		for k in 3:
			var z: float = DART_ROWS[row] + (k - 1) * DART_SPREAD
			_put(PropsEgypt.dart_launcher(), Vector3(-dir * CORRIDOR_HALF, DART_HEIGHT, z), dir * PI / 2)
			add_child(Art.mesh(Art.box(Vector3(0.02, 0.1, 0.1)), PropsEgypt.BLACK, Vector3(dir * CORRIDOR_HALF, DART_HEIGHT, z)))
		# 地上画一道红线：飞镖会扫过这里
		add_child(Art.mesh(Art.box(Vector3(CORRIDOR_HALF * 2, 0.01, 0.06)), PropsEgypt.OCHRE,
			Vector3(0, 0.006, DART_ROWS[row] + DART_SPREAD + 0.35)))
		add_child(Art.mesh(Art.box(Vector3(CORRIDOR_HALF * 2, 0.01, 0.06)), PropsEgypt.OCHRE,
			Vector3(0, 0.006, DART_ROWS[row] - DART_SPREAD - 0.35)))
	for z in [-28.5, -33.5]:
		for s in [-1.0, 1.0]:
			_put(PropsEgypt.torch(s > 0), Vector3(s * CORRIDOR_HALF, 1.15, z), -s * PI / 2)
	for row in DART_ROWS.size():
		for v in DART_VOLLEYS:
			for k in 3:
				var d := PropsEgypt.dart()
				d.visible = false
				add_child(d)
				_darts.append(d)
	# 地上散着几根骨头（前人没躲过去）
	for p in [Vector3(-1.2, 0.04, -27.4), Vector3(1.0, 0.04, -32.6), Vector3(-0.6, 0.04, -37.0)]:
		var bone := Art.mesh(Art.capsule(0.04, 0.4), Props.WHITE, p)
		bone.rotation = Vector3(PI / 2, p.x, 0)
		add_child(bone)
		add_child(Art.mesh(Art.sphere(0.09), Props.WHITE, p + Vector3(0.25, 0.04, 0.05)))
	_sign("看准节奏再过去", Vector3(0, 4.4, GATE_Z + 1.0))


# ---------- 3 塌陷地板厅 ----------

func _tile_center(row: int, col: int) -> Vector3:
	return Vector3(-TILE * TILE_COLS / 2.0 + TILE * (col + 0.5), HALL_Y, TILE_Z0 - TILE * (row + 0.5))


func _build_tile_hall() -> void:
	var half := TILE * TILE_COLS / 2.0
	var z_end := TILE_Z0 - TILE * TILE_ROWS
	# 入口和出口各一块实心平台；中间是一块块悬在深渊上的石砖
	_floor(Vector3(-half, HALL_Y, RAMP_Z[1]), Vector3(half, HALL_Y, TILE_Z0), _m.paving, 1.5)
	_floor(Vector3(-half, HALL_Y, z_end), Vector3(half, HALL_Y, DOOR_ROOM_Z[0]), _m.paving, 1.5)
	for row in TILE_ROWS:
		for col in TILE_COLS:
			if [row, col] in TILE_HOLES:
				continue
			var c := _tile_center(row, col)
			var body := StaticBody3D.new()
			body.position = c - Vector3(0, 0.25, 0)
			var cs := CollisionShape3D.new()
			var shape := BoxShape3D.new()
			shape.size = Vector3(TILE - 0.04, 0.5, TILE - 0.04)
			cs.shape = shape
			body.add_child(cs)
			add_child(body)
			var mesh := Art.block(Vector3(TILE - 0.06, 0.6, TILE - 0.06), c - Vector3(0, 0.3, 0), _m.tomb)
			add_child(mesh)
			_tiles.append({body = body, cs = cs, mesh = mesh, base_y = c.y - 0.3, state = 0.0, center = c})
	var wx := half + WALL_T / 2
	for s in [-1.0, 1.0]:
		_wall_z(s * wx, DOOR_ROOM_Z[0], RAMP_Z[1], HALL_Y - 3.0, _m.wall, WALL_H + 3.0)
		_put(PropsEgypt.torch(), Vector3(s * half, HALL_Y + 1.15, -52.0), -s * PI / 2)
		_put(PropsEgypt.anubis(2.2), Vector3(s * (half - 0.6), HALL_Y, DOOR_ROOM_Z[0] + 0.8), PI)
		_solid(Vector3(0.7, 2.0, 0.7), Vector3(s * (half - 0.6), HALL_Y + 1.0, DOOR_ROOM_Z[0] + 0.8))
	# 深渊底下的尖刺（只是看的）
	for i in 14:
		var spike := Art.mesh(Art.cylinder(0.0, 0.25, 1.2, 4), PropsEgypt.DARK_STONE,
			Vector3(-half + 0.6 + (i % 7) * 1.2, HALL_Y - 6.0, TILE_Z0 - 2.0 - (i / 7) * 7.0 - (i % 3)))
		add_child(spike)
	_wreath(_tile_center(6, 5) + Vector3(0, 0, 0), 10.0, 0.45, Color(0.25, 0.55, 0.45), "莲花环")
	_sign("别在一块砖上停太久", Vector3(0, HALL_Y + 2.8, TILE_Z0 - 3.0))


## 谁（抬棺人、或者放在地上的棺材）踩在砖上，砖就开始抖，踩满 1 秒塌下去，8 秒后复原
func _update_tiles(g: Node, delta: float) -> void:
	var feet: Array[Vector3] = []
	for b in g.bearers:
		feet.append(b.global_position - Vector3(0, 0.9, 0))
	feet.append(g.coffin.global_position - Vector3(0, 0.25, 0))
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
			t.state = t.state + delta if on else maxf(t.state - delta * 0.5, 0.0)
			if t.state >= TILE_FALL_AFTER:
				t.state = -TILE_DOWN_TIME
		_show_tile(t)


func _show_tile(t: Dictionary) -> void:
	var s: float = t.state
	t.cs.disabled = s < 0.0
	var mesh: Node3D = t.mesh
	if s > -0.6 and s < 0.0:  # 最后 0.6 秒从下面升回来
		mesh.visible = true
		mesh.position = Vector3(t.center.x, t.base_y + s / 0.6 * 1.5, t.center.z)
	elif s < 0.0:  # 刚塌：加速往下掉，掉出视野就藏起来
		var since := TILE_DOWN_TIME + s
		mesh.visible = since < 1.2
		mesh.position = Vector3(t.center.x, t.base_y - since * since * 4.0, t.center.z)
	else:
		mesh.visible = true
		var shake := 0.0 if s < 0.25 else 0.03 * s * sin(_time * 70.0 + t.center.x * 3.0)
		mesh.position = Vector3(t.center.x + shake, t.base_y - s * 0.04, t.center.z - shake)


# ---------- 4 封印石门 ----------

func _build_door_room() -> void:
	var z0: float = DOOR_ROOM_Z[0]
	var z1: float = DOOR_ROOM_Z[1]
	var half := 4.5
	_floor(Vector3(-half, HALL_Y, z0), Vector3(half, HALL_Y, z1), _m.paving, 2.0)
	var wx := half + WALL_T / 2
	for s in [-1.0, 1.0]:
		_wall_z(s * wx, z1, z0, HALL_Y, _m.wall)
		# 前墙（和塌陷地板厅之间）中间留门洞
		_wall_x(z0, s * 2.2, s * (TILE * TILE_COLS / 2.0 + WALL_T), HALL_Y, _m.wall)
		_wall_x(z0, s * (TILE * TILE_COLS / 2.0 + WALL_T), s * wx, HALL_Y, _m.wall)
		# 后墙中间是石门
		_wall_x(z1, s * DOOR_HALF, s * wx, HALL_Y, _m.wall)
		_put(PropsEgypt.anubis(2.4), Vector3(s * (DOOR_HALF + 0.75), HALL_Y, z1 + 0.6))
		_solid(Vector3(0.7, 2.0, 0.7), Vector3(s * (DOOR_HALF + 0.75), HALL_Y + 1.0, z1 + 0.6))
		_put(PropsEgypt.torch(), Vector3(s * half, HALL_Y + 1.15, -67.0), -s * PI / 2)
		for z in [z0 - 1.0, z1 + 1.0]:
			_put(PropsEgypt.column(2.6), Vector3(s * (half - 0.6), HALL_Y, z))
			_solid(Vector3(0.7, 2.6, 0.7), Vector3(s * (half - 0.6), HALL_Y + 1.3, z))
	# 石门：一整块升降的石板，门楣上一只荷鲁斯之眼
	_door = AnimatableBody3D.new()
	_door.add_to_group("hard")
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(DOOR_HALF * 2, DOOR_H, 0.4)
	cs.shape = shape
	_door.add_child(cs)
	_door.add_child(Art.block(Vector3(DOOR_HALF * 2, DOOR_H, 0.4), Vector3.ZERO, _m.wall))
	var eye := PropsEgypt._eye_decal(1.2)
	eye.rotation.x = PI / 2
	eye.position = Vector3(0, 0.4, 0.22)
	_door.add_child(eye)
	_door.position = Vector3(0, HALL_Y + DOOR_H / 2, z1)
	add_child(_door)
	add_child(Art.block(Vector3(DOOR_HALF * 2 + 0.6, 0.5, 0.6), Vector3(0, HALL_Y + DOOR_H + DOOR_OPEN + 0.25, z1), _m.wall))
	# 压力板和大石块
	_plate_mesh = PropsEgypt.plate_top(PLATE_SIZE)
	_plate_mesh.position = PLATE + Vector3(0, 0.0, 0)
	add_child(_plate_mesh)
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
	# 地上画一道拖痕，从石块指到压力板
	add_child(Art.mesh(Art.box(Vector3(0.9, 0.01, PLATE.z - BLOCK_START.z)), PropsEgypt.SAND.darkened(0.2),
		Vector3(PLATE.x, HALL_Y + 0.005, (PLATE.z + BLOCK_START.z) / 2)))
	_wreath(Vector3(-3.6, HALL_Y, -72.6), 10.0, 0.45, Color(0.25, 0.55, 0.45), "莲花环")
	_sign("门打不开？\n地上那块板子好像能踩下去", Vector3(0, HALL_Y + 2.8, -67.0))


## 压力板上有够重的东西（石块或者人）就升门，没有就慢慢落下；门下有人时不落，免得压到人
func _update_door(g: Node, delta: float) -> void:
	var weights: Array[RigidBody3D] = [_block]
	weights.append_array(g.bearers)
	var pressed := false
	for w in weights:
		var d := w.global_position - PLATE
		if absf(d.x) < PLATE_SIZE / 2 + 0.3 and absf(d.z) < PLATE_SIZE / 2 + 0.3 and d.y < 1.2:
			pressed = true
	_set_plate(pressed)
	var z1: float = DOOR_ROOM_Z[1]
	var blocked: bool = g.team_bodies().any(func(b): return b.is_inside_tree() \
		and absf(b.global_position.z - z1) < 0.8 and absf(b.global_position.x) < DOOR_HALF)
	if pressed:
		_door_lift = minf(_door_lift + 1.2 * delta, DOOR_OPEN)
		if not _door_said and _door_lift > 0.5:
			_door_said = true
			notice.emit("轰隆隆……石门升起来了")
	elif not blocked:
		_door_lift = maxf(_door_lift - 0.6 * delta, 0.0)
	_door.position.y = HALL_Y + DOOR_H / 2 + _door_lift


func _set_plate(down: bool) -> void:
	_plate_down = down
	_plate_mesh.position.y = PLATE.y - (0.03 if down else 0.0)


# ---------- 法老墓室（临时放在这里）----------

func _build_tomb() -> void:
	var z0: float = TOMB_Z[0]
	var z1: float = TOMB_Z[1]
	var half := 4.0
	_floor(Vector3(-half, HALL_Y, z0), Vector3(half, HALL_Y, z1), _m.gold_floor, 2.0)
	var wx := half + WALL_T / 2
	for s in [-1.0, 1.0]:
		_wall_z(s * wx, z1, z0, HALL_Y, _m.tomb_wall)
		_put(PropsEgypt.torch(), Vector3(s * half, HALL_Y + 1.15, -79.0), -s * PI / 2)
		_put(PropsEgypt.column(2.8), Vector3(s * (half - 0.6), HALL_Y, z1 + 0.8))
		_solid(Vector3(0.7, 2.8, 0.7), Vector3(s * (half - 0.6), HALL_Y + 1.4, z1 + 0.8))
		for k in 3:
			_put(PropsEgypt.canopic_jar([Color(0.85, 0.75, 0.55), PropsEgypt.BLACK, PropsEgypt.TURQUOISE][k]),
				Vector3(s * 3.4, HALL_Y, -82.4 + k * 0.4))
		_put(PropsEgypt.gold_pile(), Vector3(s * 3.0, HALL_Y, -77.0))
	_wall_x(z1, -wx, wx, HALL_Y, _m.tomb_wall)
	# 灵台就是法老的石棺
	_collider(goal_size, goal_pos + Vector3(0, goal_size.y / 2, 0), false)
	_put(PropsEgypt.sarcophagus(goal_size.x), goal_pos, PI / 2)
	_put(PropsEgypt.scarab(1.4), Vector3(0, HALL_Y, z1 + 0.9), 0.0)
	_lamp(Vector3(0, HALL_Y + 3.0, -81.0), 1.2, 8.0, Color(1.0, 0.8, 0.45))
	_sign("把法老放进他的石棺", goal_pos + Vector3(0, 2.6, 0))


# ---------- 远景 ----------

func _build_backdrop() -> void:
	_put(PropsEgypt.pyramid(22.0, 12), Vector3(-26, -6, -40))
	_put(PropsEgypt.pyramid(14.0, 9), Vector3(22, -5, -62))
	_put(PropsEgypt.pyramid(10.0, 7), Vector3(-20, -4, 10))
	# 远处飘着几座沙岛
	for p in [Vector3(16, -7, -10), Vector3(-15, -10, -70), Vector3(12, -12, -95)]:
		var isl := Art.block(Vector3(6, 3, 5), p, _m.sand)
		add_child(isl)
		_put(PropsEgypt.palm(2.6), p + Vector3(1.0, 1.5, 0.5))
