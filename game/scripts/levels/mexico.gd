extends Level
## 墨西哥关「万寿菊之路」：亡灵节的晚上，从花海墓园出发，穿过彩色小镇、河边集市、坐花船过运河，
## 把逝者送上镇子尽头的大祭坛。主打第一人称：地方大、能走的路多，有好几条路线和藏起来的花环。
##
## 核心机关是“拍照固定视错觉”（见 level_base.gd 的 _photo_gap）：路断了，但站在相机标记的圈里看，
## 断口两边正好接上；举起相机（C）在这个角度拍一张，断口就长出一段灰色的照片路面，变成实的。
##   1 万寿菊墓园：大片墓地，中间的陵墓挡路要绕；墓园北边伸出去的石栈道断了 → 第一处拍照
##   2 彩色小镇：街道、广场、小巷；两条横街上有来回开的游行花车；站上广场音乐亭往北拍 → 第二处拍照（运河上的断桥）
##   3 河边集市：三条摊位巷子，头顶的彩罐来回荡，被砸到会被撞开
##   4 花船运河：花船在两岸之间来回开，上船、坐过去、下船
##   5 大祭坛：通往祭坛高台的坡道断了 → 第三处拍照，把逝者放上祭坛
##
## 联机：花车、彩罐、花船都按 tick(t) 的时间算，两边各算各的；拍没拍成由 main.gd 放在快照头里同步。

const TY := -EYE_HEIGHT  # 小镇地面高度：第一处拍照的远端正好落在这里（s = 2）
const BAND_H := 3.0  # 音乐亭台面比小镇地面高多少
const MY := -3.538  # 集市 / 运河 / 祭坛广场的地面：第二处拍照的远端
const SY := -1.994  # 祭坛高台：第三处拍照的远端
# 1 墓园
const YARD := [16.0, 8.0, -32.0]  # 半宽、南边、北边
const GRAVE_ROWS := [-3.0, -8.0, -16.0, -21.0, -26.0]
const GRAVE_XS := [5.5, 8.0, 10.5, 13.0]
const PIER_Z := -38.0
# 2 小镇
const TOWN_X := 20.0
const STREET1 := [-58.5, -62.0]  # 南横街
const STREET2 := [-76.0, -79.5]  # 北横街
const PLAZA := [11.0, -62.0, -76.0]  # 广场半宽、南、北
const BAND_C := Vector3(0, TY, -69.0)
const BAND_R := 3.0
const BANK_Z := -84.0  # 小镇北岸
const FLOAT_RANGE := 17.0
const FLOAT_PERIOD := 14.0
# 3 集市
const MARKET_Z := [-98.1, -134.0]
const PINATAS := [[0.0, -104.0, 0.0], [0.0, -109.0, 1.3], [0.0, -118.0, 0.6], [0.0, -123.0, 2.0],
	[8.0, -106.0, 0.4], [8.0, -120.0, 1.7], [-8.0, -108.0, 1.1], [-8.0, -121.0, 0.2]]  # [x, z, 相位]
const PINATA_AMP := 2.4
const PINATA_PERIOD := 4.0
const PINATA_PENALTY := 3.0
# 4 运河
const CANAL := [-134.0, -150.0]
const BOAT_W := 5.0
const BOAT_Z := [-136.5, -147.5]  # 靠南岸 / 北岸时船的中心
const BOAT_DOCK := 5.0
const BOAT_MOVE := 6.0
const WATER_Y := -4.5
# 5 祭坛广场
const ALTAR_PLAZA := [14.0, -150.0, -192.0]

var _time := 0.0
var _floats: Array[AnimatableBody3D] = []
var _pinatas: Array[Node3D] = []
var _pinata_hit_at := {}
var _boat: AnimatableBody3D
var _said := {}


func _init() -> void:
	id = "mexico"
	title = "万寿菊之路"
	par_time = 25.0 * 60.0
	kill_y = -12.0
	prefer_first_person = true
	goal_pos = Vector3(-3.0, SY, -185.0)
	goal_size = Vector3(2.2, 0.8, 1.1)
	rooms = [
		{name = "万寿菊墓园", spawn = Vector3(0, 0, 4), lift = 1.32, yaw = 0.0, kill_y = -12.0,
			path = [Vector3(0, 0, -6), Vector3(-5.6, 0, -12), Vector3(0, 0, -18.5), Vector3(0, 0, -30), Vector3(0, 0, -36.6),
				"wait:photo0", Vector3(0, 0, -46.5)]},
		{name = "彩色小镇", spawn = Vector3(0, TY, -46.5), yaw = 0.0, kill_y = WATER_Y - 0.7,
			path = [Vector3(0, 0, -56.5), "wait:float0", Vector3(-6.5, 0, -63.5), Vector3(-6.5, 0, -74.5), "wait:float1",
				Vector3(0, 0, -81.5), Vector3(0, 0, -86.2), "wait:photo1", Vector3(0, 0, -96.0), Vector3(0, 0, -100.5)]},
		{name = "河边集市", spawn = Vector3(0, MY, -100.2), yaw = 0.0, kill_y = WATER_Y - 0.7,
			path = [Vector3(0, 0, -101.5), "wait:pin0", Vector3(0, 0, -106.5), "wait:pin1", Vector3(0, 0, -113.0),
				"wait:pin2", Vector3(0, 0, -120.5), "wait:pin3", Vector3(0, 0, -127.0), Vector3(0, 0, -131.6)]},
		{name = "花船运河", spawn = Vector3(0, MY, -132.0), yaw = 0.0, kill_y = WATER_Y - 0.7,
			path = ["wait:boat_s", Vector3(0, 0, -137.0), "wait:boat_n", Vector3(0, 0, -153.0)]},
		{name = "大祭坛", spawn = Vector3(0, MY, -154.0), yaw = 0.0, kill_y = WATER_Y - 0.7,
			path = [Vector3(0, 0, -163.0), Vector3(0, 0, -164.6), "wait:photo2", Vector3(0, 0, -176.0), Vector3(0, 0, -181.0),
				Vector3(2.2, 0, -183.0), Vector3(2.2, 0, goal_pos.z), goal_pos]},
	]


func env() -> Dictionary:
	return {
		sky_top = Color(0.16, 0.14, 0.4), sky_horizon = Color(1.0, 0.52, 0.42), sky_curve = 0.14,
		ground_horizon = Color(0.9, 0.45, 0.45), ground_bottom = Color(0.12, 0.07, 0.18), ground_curve = 0.06,
		ambient = 0.8, exposure = 1.1, saturation = 1.2,
		fog_color = Color(0.7, 0.42, 0.55), fog_density = 0.006, fog_height = -5.0, fog_height_density = 0.12,
		sun_rot = Vector3(-24, -120, 0), sun_color = Color(1.0, 0.62, 0.42), sun_energy = 1.1,
	}


func _ready() -> void:
	_m.grass = Art.floor_mat({base_color = Color(0.36, 0.42, 0.3), speck_a = Color(0.25, 0.32, 0.2), speck_b = Color(0.5, 0.55, 0.35),
		speck_density = 0.5, grout_color = Color(0.36, 0.42, 0.3), side_color = Color(0.55, 0.42, 0.34), tile = 50.0, roughness = 1.0})
	_m.path = Art.floor_mat({base_color = Color(0.8, 0.68, 0.55), speck_a = Color(0.55, 0.44, 0.34),
		grout_color = Color(0.62, 0.5, 0.4), side_color = Color(0.6, 0.48, 0.4), tile = 0.9, roughness = 0.85})
	_m.street = Art.floor_mat({base_color = Color(0.6, 0.55, 0.52), speck_a = Color(0.42, 0.38, 0.36), speck_b = Color(0.78, 0.74, 0.7),
		grout_color = Color(0.45, 0.42, 0.4), side_color = Color(0.7, 0.55, 0.45), tile = 0.6, roughness = 0.9})
	_m.plaza = Art.floor_mat({base_color = Color(0.86, 0.66, 0.5), speck_a = Color(0.65, 0.42, 0.32),
		grout_color = Color(0.7, 0.5, 0.38), side_color = Color(0.7, 0.55, 0.45), tile = 1.2, roughness = 0.8})
	_m.wood = Art.floor_mat({base_color = Color(0.55, 0.38, 0.24), speck_a = Color(0.4, 0.26, 0.15),
		grout_color = Color(0.35, 0.22, 0.12), side_color = Color(0.45, 0.3, 0.2), tile = 0.5, roughness = 0.9})
	_m.wall = Art.wall_mat({upper = Color(0.95, 0.88, 0.78), lower = Color(0.85, 0.3, 0.45), trim = Color(0.98, 0.7, 0.2),
		cap = Color(0.6, 0.4, 0.32)})
	_build_cemetery()
	_build_town()
	_build_market()
	_build_canal()
	_build_altar()
	_build_backdrop()


func room_at(p: Vector3) -> int:
	if p.z > -40.5:
		return 0
	if p.z > MARKET_Z[0] - 0.5:
		return 1
	if p.z > -131.0:
		return 2
	if p.z > CANAL[1] - 0.5:
		return 3
	return 4


func _say_once(key: String, text: String) -> void:
	if not _said.has(key):
		_said[key] = true
		notice.emit(text)


# ---------- 会动的东西 ----------

func tick(t: float) -> void:
	_time = t
	for i in _floats.size():
		_floats[i].position.x = _float_x(i, t)
	for i in _pinatas.size():
		_pinatas[i].position.x = _pinata_x(i, t)
	_boat.position.z = _boat_z(t)


## 第 i 辆花车在横街上的位置：两头之间来回开，第二辆晚半个周期
func _float_x(i: int, t: float) -> float:
	var ph := fposmod(t / FLOAT_PERIOD + i * 0.5, 1.0)
	var tri := 1.0 - absf(ph * 2.0 - 1.0)
	return -FLOAT_RANGE + 2.0 * FLOAT_RANGE * smoothstep(0.0, 1.0, tri)


func _pinata_x(i: int, t: float) -> float:
	return PINATAS[i][0] + PINATA_AMP * sin(TAU * t / PINATA_PERIOD + PINATAS[i][2] * TAU / PINATA_PERIOD)


func _boat_phase(t: float) -> float:
	return fposmod(t, 2.0 * (BOAT_DOCK + BOAT_MOVE))


## 花船：靠南岸停 5 秒 → 6 秒开到北岸 → 停 5 秒 → 开回来
func _boat_z(t: float) -> float:
	var ph := _boat_phase(t)
	if ph < BOAT_DOCK:
		return BOAT_Z[0]
	if ph < BOAT_DOCK + BOAT_MOVE:
		return lerpf(BOAT_Z[0], BOAT_Z[1], smoothstep(0.0, 1.0, (ph - BOAT_DOCK) / BOAT_MOVE))
	if ph < 2.0 * BOAT_DOCK + BOAT_MOVE:
		return BOAT_Z[1]
	return lerpf(BOAT_Z[1], BOAT_Z[0], smoothstep(0.0, 1.0, (ph - 2.0 * BOAT_DOCK - BOAT_MOVE) / BOAT_MOVE))


func physics_update(g: Node) -> void:
	var dt := get_physics_process_delta_time()
	# 站在船上的人：走路速度按船算（不然船一开，人就留在原地掉进水里）
	var bz := _boat_z(_time)
	var bv := (_boat_z(_time + dt) - bz) / dt
	for b in g.bearers:
		var p: Vector3 = b.global_position
		var on_boat := absf(p.x) < BOAT_W / 2 and absf(p.z - bz) < BOAT_W / 2 and absf(p.y - MY - 0.87) < 0.5
		b.ground_velocity = Vector3(0, 0, bv) if on_boat else Vector3.ZERO
		if on_boat:
			_say_once("boat", "上船了！站稳，等船靠岸再下")
	# 彩罐：荡到谁就把谁撞开
	for i in _pinatas.size():
		var pp := Vector3(_pinata_x(i, _time), MY + 1.3, PINATAS[i][1])
		var vx := (_pinata_x(i, _time + dt) - pp.x) / dt
		for b in g.bearers:
			var d: Vector3 = b.global_position - pp
			if Vector2(d.x, d.z).length() < 0.7 and _time - _pinata_hit_at.get(b, -10.0) > 1.2:
				_pinata_hit_at[b] = _time
				b.apply_central_impulse(Vector3(signf(vx) * 100.0, 20.0, 0))
				penalty.emit(PINATA_PENALTY, "咚！被彩罐砸了一下，体面 -%d" % PINATA_PENALTY)
	for i in _floats.size():
		var fx := _floats[i].position.x
		for b in g.bearers:
			if absf(b.global_position.x - fx) < 3.0 and absf(b.global_position.z - _floats[i].position.z) < 2.0:
				_say_once("float", "游行花车来了！让一让！")


func bot_can_go(tag: String) -> bool:
	if tag.begins_with("photo"):
		fix_illusion(int(tag.substr(5)))  # 电脑队伍不用真的举相机：直接当作拍对了
		return true
	if tag.begins_with("float"):
		# 接下来 3 秒花车都不会开到大街（x≈0）附近
		var i := int(tag.substr(5))
		for k in 31:
			if absf(_float_x(i, _time + k * 0.1)) < 4.5:
				return false
		return true
	if tag.begins_with("pin"):
		# 接下来 1.4 秒彩罐都不会荡到巷子中间
		var i := int(tag.substr(3))
		for k in 15:
			if absf(_pinata_x(i, _time + k * 0.1) - PINATAS[i][0]) < 1.0:
				return false
		return true
	if tag == "boat_s":
		return _boat_phase(_time) < 1.0
	if tag == "boat_n":
		var ph := _boat_phase(_time)
		return ph > BOAT_DOCK + BOAT_MOVE + 0.3 and ph < 2.0 * BOAT_DOCK + BOAT_MOVE - 1.0
	return true


func debug_text() -> String:
	return "photos=%d boat=%.1f float0=%.1f" % [illusion_mask(), _boat_z(_time), _float_x(0, _time)]


# ---------- 1 万寿菊墓园 ----------

func _build_cemetery() -> void:
	var hw: float = YARD[0]
	var z0: float = YARD[1]
	var z1: float = YARD[2]
	_floor(Vector3(-hw, 0, z0), Vector3(hw, 0, z1), _m.grass, 5.0)
	add_child(Art.block(Vector3(3.6, 0.03, z0 - z1), Vector3(0, 0.015, (z0 + z1) / 2), _m.path))  # 中间的石板路
	for k in 40:  # 路上撒的万寿菊花瓣
		var p := Vector3(randf_range(-1.6, 1.6), 0.035, randf_range(z1, z0))
		add_child(Art.mesh(Art.box(Vector3(0.12, 0.005, 0.08)), PropsMexico.MARIGOLD, p))
	# 围墙：北边中间留出石栈道的口子
	_wall_z(-hw - WALL_T / 2, z1, z0, 0.0, _m.wall, 1.2)
	_wall_z(hw + WALL_T / 2, z1, z0, 0.0, _m.wall, 1.2)
	_wall_x(z0 + WALL_T / 2, -hw, hw, 0.0, _m.wall, 1.2)
	_wall_x(z1 - WALL_T / 2, -hw, -1.6, 0.0, _m.wall, 1.2)
	_wall_x(z1 - WALL_T / 2, 1.6, hw, 0.0, _m.wall, 1.2)
	# 起点：停棺台，旁边一座小祭坛
	for x in [-0.7, 0.7]:
		_box(Vector3(0.3, 1.09, 0.7), Vector3(x, 0.545, 4), Color(0.4, 0.3, 0.26), false)
		add_child(Art.mesh(Art.box(Vector3(0.34, 0.04, 0.74)), PropsMexico.MARIGOLD, Vector3(x, 1.07, 4)))
	_put(PropsMexico.ofrenda(2.6), Vector3(4.0, 0, 6.6), PI)
	_solid(Vector3(2.6, 1.2, 1.0), Vector3(4.0, 0.6, 6.8))
	# 一排排的坟，中间的石板路空着
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for z in GRAVE_ROWS:
		for x in GRAVE_XS:
			for s in [-1.0, 1.0]:
				var p := Vector3(s * x, 0, z)
				_put(PropsMexico.grave(rng.randi() % 4, PropsMexico.CREAM.darkened(rng.randf() * 0.2)), p)
				_solid(Vector3(1.1, 0.9, 2.0), p + Vector3(0, 0.45, 0))
	# 陵墓：挡在路中间，得从旁边绕
	_box(Vector3(4.8, 3.2, 4.0), Vector3(0, 1.6, -12.0), PropsMexico.CREAM.darkened(0.1), true)
	_put(Art.mesh(Art.cylinder(0.3, 2.2, 1.2, 8), PropsMexico.TURQUOISE.darkened(0.2)), Vector3(0, 3.8, -12.0))
	_put(Art.mesh(Art.box(Vector3(0.12, 0.9, 0.12)), Props.GOLD), Vector3(0, 4.8, -12.0))
	_put(Art.mesh(Art.box(Vector3(0.5, 0.12, 0.12)), Props.GOLD), Vector3(0, 4.95, -12.0))
	_put(Art.mesh(Art.box(Vector3(1.4, 2.0, 0.06)), Color(0.18, 0.14, 0.12)), Vector3(0, 1.0, -9.98))
	var c := PropsMexico.candles(7, 0.2)
	c.position = Vector3(0, 0, -9.6)
	add_child(c)
	# 西边的小教堂、东边的大祭坛、四周的柏树和雕像
	_put(PropsMexico.chapel(), Vector3(-12.0, 0, -29.0) + Vector3(0, 0, 0), 0.0)
	_solid(Vector3(4.0, 3.6, 5.0), Vector3(-12.0, 1.8, -29.0))
	_put(PropsMexico.catrina(2.2), Vector3(-3.0, 0, 1.8), 0.3)
	_solid(Vector3(0.8, 2.0, 0.8), Vector3(-3.0, 1.0, 1.8))
	_put(PropsMexico.sugar_skull(1.6), Vector3(7.5, 0, -30.0), -0.4)
	_solid(Vector3(1.4, 1.6, 1.4), Vector3(7.5, 0.8, -30.0))
	for p in [Vector3(-15, 0, 7), Vector3(15, 0, 7), Vector3(-15, 0, -12), Vector3(15, 0, -18), Vector3(15, 0, -31),
			Vector3(-6.5, 0, -31), Vector3(3.5, 0, -31)]:
		_put(PropsMexico.cypress(3.5 + absf(p.z) * 0.02), p)
	for z in [-1.0, -19.0, -28.0]:
		_put(PropsMexico.papel_picado(Vector3(-3.2, 3.4, z), Vector3(3.2, 3.4, z)), Vector3.ZERO)
		for s in [-1.0, 1.0]:
			add_child(Art.mesh(Art.cylinder(0.05, 0.05, 3.5), Props.WOOD, Vector3(s * 3.2, 1.75, z)))
	_lamp(Vector3(0, 3.5, -4.0), 0.9, 12.0, Color(1.0, 0.7, 0.4))
	_lamp(Vector3(0, 3.5, -22.0), 0.9, 12.0, Color(1.0, 0.7, 0.4))
	_wreath(Vector3(-14.0, 0, -22.0), 10.0, 0.5, PropsMexico.MARIGOLD.darkened(0.2), "万寿菊花环")
	_wreath(Vector3(14.0, 0, -2.5), 10.0, 0.5, PropsMexico.MARIGOLD.darkened(0.2), "万寿菊花环")
	_sign("抓住把手，把棺材抬到镇子尽头的大祭坛", Vector3(0, 3.0, 0.5))

	# 石栈道：伸出墓园，悬在山谷上，到 PIER_Z 就断了
	_floor(Vector3(-1.6, 0, z1), Vector3(1.6, 0, PIER_Z), _m.path, 5.0)
	var pier := _last_block
	for s in [-1.0, 1.0]:
		var cc := PropsMexico.candles(3)
		cc.position = Vector3(s * 1.4, 0, -34.0)
		add_child(cc)
	_photo_gap(Vector3(0, 0, z1), Vector3(0, 0, PIER_Z), 2.0, 3.2, 3.0, _m.street, [pier])
	_sign("路断了？\n站到相机的圈里，按 C 举起相机看看", Vector3(0, 2.8, z1 + 2.5))


# ---------- 2 彩色小镇 ----------

## 一整片房子：碰撞是一整块，外观是一排高低、颜色不一样的小房子，正面朝 yaw 方向
func _town_block(x0: float, x1: float, z0: float, z1: float, yaw: float, seed: int) -> void:
	_collider(Vector3(absf(x1 - x0), 4.0, absf(z1 - z0)), Vector3((x0 + x1) / 2, TY + 2.0, (z0 + z1) / 2), true)
	var along_x := absf(sin(yaw)) < 0.5  # 正面朝 ±Z：房子沿 X 一栋栋排开
	var length := absf(x1 - x0) if along_x else absf(z1 - z0)
	var depth := absf(z1 - z0) if along_x else absf(x1 - x0)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var pos := 0.0
	var k := 0
	while pos < length - 0.5:
		var w := minf(rng.randf_range(3.0, 4.6), length - pos)
		var h := rng.randf_range(3.2, 5.2)
		var color: Color = PropsMexico.HOUSE_COLORS[(seed + k) % PropsMexico.HOUSE_COLORS.size()]
		var c := pos + w / 2
		var center := Vector3(minf(x0, x1) + c, TY, (z0 + z1) / 2) if along_x else Vector3((x0 + x1) / 2, TY, minf(z0, z1) + c)
		_put(PropsMexico.house(w - 0.05, h, depth, color, seed * 13 + k), center, yaw)
		pos += w
		k += 1


func _build_town() -> void:
	var hx := TOWN_X
	# 入口街（第一处拍照的远端已经搭好了 z -44 ~ -50），然后是整个镇子的地面
	_floor(Vector3(-hx, TY, -50.0), Vector3(hx, TY, BANK_Z), _m.street, 3.0)
	add_child(Art.block(Vector3(PLAZA[0] * 2, 0.02, PLAZA[1] - PLAZA[2]), Vector3(0, TY + 0.01, (PLAZA[1] + PLAZA[2]) / 2), _m.plaza))
	for s in [-1.0, 1.0]:
		_wall_z(s * (hx + WALL_T / 2), BANK_Z, -50.0, TY, _m.wall, 1.0)
		_wall_x(-50.0 + WALL_T / 2, s * 3.2, s * hx, TY, _m.wall, 1.0)
		_wall_x(BANK_Z - WALL_T / 2, s * 3.2, s * hx, TY, _m.wall, 0.8)
	# 一片片房子
	_town_block(-hx, -3.2, -50.0, STREET1[0], PI, 1)
	_town_block(3.2, hx, -50.0, STREET1[0], PI, 2)
	_town_block(-hx, -PLAZA[0], PLAZA[1], PLAZA[2], PI / 2, 3)
	_town_block(PLAZA[0], hx, PLAZA[1], PLAZA[2], -PI / 2, 4)
	_town_block(-hx, -3.2, STREET2[1], BANK_Z, 0.0, 5)
	_town_block(3.2, hx, STREET2[1], BANK_Z, 0.0, 6)
	# 广场中间的音乐亭（第二处拍照点在它北边的台沿上），南边一道台阶上去
	_put(PropsMexico.bandstand(BAND_R, BAND_H), BAND_C)
	var band := StaticBody3D.new()
	var bcs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = BAND_R
	cyl.height = BAND_H
	bcs.shape = cyl
	band.add_child(bcs)
	band.position = BAND_C + Vector3(0, BAND_H / 2, 0)
	add_child(band)
	var steps := 10
	for k in steps:
		var h := BAND_H * (k + 1) / steps
		var z := BAND_C.z + BAND_R - 0.2 + (steps - k) * 0.37
		_box(Vector3(2.0, h, 0.37), Vector3(0, TY + h / 2, z - 0.185), PropsMexico.CREAM.darkened(0.05 * (k % 2)), false)
	for s in [-1.0, 1.0]:
		_put(PropsMexico.mariachi(1.9), Vector3(s * 1.6, TY + BAND_H, BAND_C.z), s * PI / 2)
	_wreath(Vector3(BAND_R - 0.8, TY + BAND_H, BAND_C.z + 1.0), 10.0, 0.45, PropsMexico.MARIGOLD.darkened(0.2), "万寿菊花环")
	_sign("爬上音乐亭，往北边的运河看", Vector3(0, TY + 3.0, STREET1[1] - 0.5))
	# 广场四角的雕像、街上的剪纸彩旗和路灯
	for p in [Vector3(-9.5, TY, -63.5), Vector3(9.5, TY, -74.5)]:
		_put(PropsMexico.catrina(2.0), p, PI if p.z < -70 else 0.0)
		_solid(Vector3(0.8, 2.0, 0.8), p + Vector3(0, 1.0, 0))
	for p in [Vector3(9.5, TY, -63.5), Vector3(-9.5, TY, -74.5)]:
		_put(PropsMexico.alebrije(1.6), p, PI / 2)
		_solid(Vector3(1.2, 1.6, 1.2), p + Vector3(0, 0.8, 0))
	for z in [-52.0, -55.5, -81.0, -83.0]:
		_put(PropsMexico.papel_picado(Vector3(-3.2, TY + 4.6, z), Vector3(3.2, TY + 4.6, z), 10), Vector3.ZERO)
	for z in [STREET1[0] - 1.7, STREET2[0] - 1.7]:
		_put(PropsMexico.papel_picado(Vector3(-hx, TY + 5.2, z), Vector3(hx, TY + 5.2, z), 40), Vector3.ZERO)
	for x in [-8.0, 8.0]:
		_put(PropsMexico.papel_picado(Vector3(x, TY + 5.0, PLAZA[1]), Vector3(x, TY + 5.0, PLAZA[2]), 18), Vector3.ZERO)
	_lamp(Vector3(-6, TY + 4.0, -69.0), 1.0, 12.0, Color(1.0, 0.72, 0.45))
	_lamp(Vector3(6, TY + 4.0, -69.0), 1.0, 12.0, Color(1.0, 0.72, 0.45))
	_lamp(Vector3(0, TY + 4.0, -54.0), 0.8, 10.0, Color(1.0, 0.72, 0.45))
	_wreath(Vector3(-18.5, TY, (STREET1[0] + STREET1[1]) / 2), 10.0, 0.45, PropsMexico.MARIGOLD.darkened(0.2), "万寿菊花环")
	_wreath(Vector3(18.5, TY, (STREET2[0] + STREET2[1]) / 2), 10.0, 0.45, PropsMexico.MARIGOLD.darkened(0.2), "万寿菊花环")
	# 两条横街上的游行花车
	for street in [STREET1, STREET2]:
		var f := AnimatableBody3D.new()
		f.add_to_group("hard")
		var fcs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(2.8, 1.6, 2.0)
		fcs.shape = box
		fcs.position.y = 0.8
		f.add_child(fcs)
		f.add_child(PropsMexico.parade_float())
		f.position = Vector3(_float_x(_floats.size(), 0.0), TY, (street[0] + street[1]) / 2)
		add_child(f)
		_floats.append(f)
	# 北岸：伸到运河上的半截木桥，第二处拍照的近端
	_floor(Vector3(-1.6, TY, BANK_Z), Vector3(1.6, TY, -87.5), _m.wood, 0.6)
	var near := _last_block
	var eye_floor := Vector3(0, TY + BAND_H, BAND_C.z - BAND_R + 0.5)
	_photo_gap(eye_floor, Vector3(0, TY, -87.5), 1.4, 3.2, 3.0, _m.wood, [near])


# ---------- 3 河边集市 ----------

func _build_market() -> void:
	var z0: float = MARKET_Z[0]
	var z1: float = MARKET_Z[1]
	_floor(Vector3(-18, MY, z0), Vector3(18, MY, z1), _m.plaza, 2.0)
	for s in [-1.0, 1.0]:
		_wall_z(s * (18 + WALL_T / 2), z1, z0, MY, _m.wall, 1.0)
		_wall_x(z0 - WALL_T / 2, s * 2.3, s * 18, MY, _m.wall, 0.8)
	# 摊位：中间一条宽巷子、两边各一条窄巷子、最外面两条绕远的路
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for x in [-12.0, -4.3, 4.3, 12.0]:
		for z in [-101.0, -104.0, -107.0, -110.0, -116.0, -119.0, -122.0, -125.0]:
			var color: Color = PropsMexico.FLAG_COLORS[rng.randi() % PropsMexico.FLAG_COLORS.size()]
			_put(PropsMexico.stall(color, rng.randi()), Vector3(x, MY, z), PI / 2 if absf(x) > 8.0 else 0.0)
			_solid(Vector3(2.4, 1.2, 1.4) if absf(x) < 8.0 else Vector3(1.4, 1.2, 2.4), Vector3(x, MY + 0.6, z))
	# 彩罐：挂在横梁上，来回荡
	for i in PINATAS.size():
		var x: float = PINATAS[i][0]
		var z: float = PINATAS[i][1]
		add_child(Art.mesh(Art.box(Vector3(PINATA_AMP * 2 + 1.6, 0.12, 0.12)), Props.WOOD, Vector3(x, MY + 3.6, z)))
		var pin := Node3D.new()
		pin.add_child(PropsMexico.pinata(PropsMexico.FLAG_COLORS[i % PropsMexico.FLAG_COLORS.size()]))
		pin.add_child(Art.mesh(Art.box(Vector3(0.02, 2.2, 0.02)), Props.BLACK, Vector3(0, 1.2, 0)))
		pin.position = Vector3(x, MY + 1.3, z)
		add_child(pin)
		_pinatas.append(pin)
	for x in [-8.0, 0.0, 8.0]:
		_put(PropsMexico.papel_picado(Vector3(x, MY + 4.4, z0 - 1.0), Vector3(x, MY + 4.4, -128.0), 30), Vector3.ZERO)
	for p in [Vector3(-15.5, MY, -113.0), Vector3(15.5, MY, -113.0)]:
		_put(PropsMexico.mariachi(1.9), p, -signf(p.x) * PI / 2)
		_solid(Vector3(0.7, 1.9, 0.7), p + Vector3(0, 0.95, 0))
	_put(PropsMexico.sugar_skull(1.8), Vector3(-15.5, MY, -128.0), 0.5)
	_solid(Vector3(1.5, 1.8, 1.5), Vector3(-15.5, MY + 0.9, -128.0))
	_put(PropsMexico.catrina(2.2), Vector3(15.5, MY, -128.0), -0.5)
	_solid(Vector3(0.8, 2.2, 0.8), Vector3(15.5, MY + 1.1, -128.0))
	_lamp(Vector3(0, MY + 4.0, -106.0), 1.0, 12.0, Color(1.0, 0.7, 0.45))
	_lamp(Vector3(0, MY + 4.0, -121.0), 1.0, 12.0, Color(1.0, 0.7, 0.45))
	_wreath(Vector3(16.0, MY, -105.0), 10.0, 0.45, PropsMexico.MARIGOLD.darkened(0.2), "万寿菊花环")
	_wreath(Vector3(-16.0, MY, -120.0), 10.0, 0.45, PropsMexico.MARIGOLD.darkened(0.2), "万寿菊花环")
	_sign("小心头顶的彩罐", Vector3(0, MY + 3.0, -101.5))


# ---------- 4 花船运河 ----------

func _build_canal() -> void:
	var water := StandardMaterial3D.new()
	water.albedo_color = Color(0.15, 0.4, 0.5, 0.75)
	water.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water.roughness = 0.08
	water.metallic = 0.2
	# 小镇和集市之间的运河、集市北边的运河，一整片水面
	add_child(Art.block(Vector3(60, 0.05, BANK_Z - MARKET_Z[0] + 2), Vector3(0, WATER_Y, (BANK_Z + MARKET_Z[0]) / 2), water))
	add_child(Art.block(Vector3(60, 0.05, CANAL[0] - CANAL[1]), Vector3(0, WATER_Y, (CANAL[0] + CANAL[1]) / 2), water))
	for k in 16:  # 水上漂的万寿菊花瓣和蜡烛
		var p := Vector3(randf_range(-20, 20), WATER_Y + 0.04, randf_range(CANAL[1] + 1, CANAL[0] - 1))
		if absf(p.x) < BOAT_W:
			continue
		var c := PropsMexico.candles(1)
		c.position = p
		add_child(c)
		add_child(Art.mesh(Art.cylinder(0.12, 0.12, 0.02, 8), PropsMexico.MARIGOLD, p))
	_boat = AnimatableBody3D.new()
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(BOAT_W, 0.6, BOAT_W)
	cs.shape = box
	cs.position.y = -0.3
	_boat.add_child(cs)
	_boat.add_child(PropsMexico.trajinera(BOAT_W, BOAT_W, "LUPITA"))
	_boat.position = Vector3(0, MY, BOAT_Z[0])
	add_child(_boat)
	# 两边系着不开的花船（只是看的）
	for p in [Vector3(-9, MY - 0.2, -142), Vector3(10, MY - 0.2, -141), Vector3(-17, MY - 0.2, -144)]:
		_put(PropsMexico.trajinera(3.0, 6.0, ["ROSITA", "CARMEN", "LOLITA"][int(p.x + 20) % 3]), p, 0.2 * p.x)
	_put(PropsMexico.papel_picado(Vector3(-4, MY + 4.0, CANAL[0]), Vector3(-4, MY + 4.0, CANAL[1]), 20), Vector3.ZERO)
	_put(PropsMexico.papel_picado(Vector3(4, MY + 4.0, CANAL[0]), Vector3(4, MY + 4.0, CANAL[1]), 20), Vector3.ZERO)
	_lamp(Vector3(0, MY + 3.5, -142.0), 1.0, 12.0, Color(1.0, 0.65, 0.4))
	_sign("等花船靠岸再上", Vector3(0, MY + 2.8, -131.0))


# ---------- 5 大祭坛 ----------

func _build_altar() -> void:
	var hw: float = ALTAR_PLAZA[0]
	var z0: float = ALTAR_PLAZA[1]
	var z1: float = ALTAR_PLAZA[2]
	_floor(Vector3(-hw, MY, z0), Vector3(hw, MY, z1), _m.plaza, 2.0)
	for s in [-1.0, 1.0]:
		_wall_z(s * (hw + WALL_T / 2), z1, z0, MY, _m.wall, 1.0)
	_wall_x(z1 - WALL_T / 2, -hw, hw, MY, _m.wall, 1.0)
	# 通往高台的坡道：爬到一半就断了 → 第三处拍照
	var a := Vector3(0, MY + 1.6, -166.0)
	var ramp: Array = _ramp(Vector3(0, MY, -160.0), a, 3.2, _m.wood, 0.4)
	var end := _photo_gap(Vector3(0, MY, -158.0), a, 1.8, 3.2, 4.0, _m.wood, [ramp[1]])
	# 高台本身（远端那段路接上来的大平台），底下用实心挡住，不能从下面钻
	_floor(Vector3(-8.0, SY, end.z), Vector3(8.0, SY, -190.5), _m.plaza, SY - MY)
	_solid(Vector3(16.0, SY - MY - 0.5, absf(-190.5 - end.z)), Vector3(0, MY + (SY - MY - 0.5) / 2, (end.z - 190.5) / 2))
	_solid(Vector3(3.2 * 1.8, SY - MY - 0.5, absf(end.z + 172.4)), Vector3(0, MY + (SY - MY - 0.5) / 2, (end.z - 172.4) / 2))
	# 灵台：高台西边一张铺着紫布的长桌；后面是一座大祭坛和万寿菊拱门
	_box(goal_size, goal_pos + Vector3(0, goal_size.y / 2, 0), PropsMexico.PURPLE, false)
	add_child(Art.mesh(Art.box(Vector3(goal_size.x + 0.1, 0.04, goal_size.z + 0.1)), PropsMexico.MARIGOLD,
		goal_pos + Vector3(0, goal_size.y, 0)))
	var fl := PropsMexico.marigolds(12, 0.5, 9)
	fl.position = goal_pos + Vector3(0, 0, goal_size.z / 2 + 0.15)
	fl.scale = Vector3(2.5, 1, 0.5)
	add_child(fl)
	_put(PropsMexico.ofrenda(6.0), Vector3(0, SY, -189.5))
	_solid(Vector3(6.0, 1.6, 1.0), Vector3(0, SY + 0.8, -189.7))
	for s in [-1.0, 1.0]:
		_put(PropsMexico.catrina(2.4), Vector3(s * 6.5, SY, -188.5), 0.0)
		_put(PropsMexico.cypress(4.0), Vector3(s * 12.0, MY, -186.0))
		var cc := PropsMexico.candles(9, 0.2)
		cc.position = Vector3(s * 4.0, SY, -183.0)
		add_child(cc)
	_put(PropsMexico.marigold_arch(4.4, 3.4), Vector3(0, MY, -159.0))
	for z in [-162.0, -170.0, -178.0]:
		_put(PropsMexico.papel_picado(Vector3(-hw, MY + 5.5, z), Vector3(hw, MY + 5.5, z), 30), Vector3.ZERO)
	_lamp(Vector3(0, SY + 3.0, -184.0), 1.4, 12.0, Color(1.0, 0.65, 0.35))
	_lamp(Vector3(0, MY + 3.0, -164.0), 0.9, 10.0, Color(1.0, 0.65, 0.35))
	_wreath(Vector3(-11.0, MY, -176.0), 10.0, 0.45, PropsMexico.MARIGOLD.darkened(0.2), "万寿菊花环")
	_sign("把逝者送上祭坛", goal_pos + Vector3(0, 2.6, 0))


func _build_backdrop() -> void:
	# 远处山坡上的小镇灯火和教堂
	for i in 14:
		var p := Vector3(-48 + i * 7.0, -6.0 + (i % 3) * 1.5, -120 - (i % 4) * 18.0)
		if absf(p.x) < 26.0:
			p.x += 52.0 * signf(p.x if p.x != 0.0 else 1.0)
		_put(PropsMexico.house(4.0, 3.0 + (i % 3), 4.0, PropsMexico.HOUSE_COLORS[i % 8], i), p, PI / 2 * (i % 4))
	_put(PropsMexico.chapel(), Vector3(-40, -5, -60), PI / 2)
	_put(PropsMexico.chapel(), Vector3(42, -6, -160), -PI / 2)
