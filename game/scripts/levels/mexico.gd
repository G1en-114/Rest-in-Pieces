extends Level
## 墨西哥关「万寿菊之路」：亡灵节的晚上，从花海墓园出发，穿过彩色小镇、河边集市、坐花船过运河，
## 把逝者送上山谷里的大祭坛。主打第一人称：地方大、能走的路多，有好几条路线和藏起来的花环。
##
## 两种视错觉：
##   拍照（见 level_base.gd 的 _photo_gap）：路断了，站在相机标记的圈里看，断口正好被远处一块大一号的路接上；
##     举起相机（C）在这个角度拍一张，那块就沿着视线缩回断口里，变成一段平的灰色照片路面。
##   俯视断桥（见 _view_bridge，和中国关一样）：要有人按 V 俯视、Q / E 把视角转对，两段桥才接得上。
##   1 万寿菊墓园：坟堆里绕过陵墓 → 墓地中间一道沟，踩东边的铃铛石板，墓碑像多米诺一样倒过去，最后一块大石碑搭成桥
##     → 墓园北边伸出去的石栈道断了，第一处拍照
##   2 彩色小镇：两条横街上有来回开的游行花车；爬上广场音乐亭往北拍 → 第二处拍照（运河上的断桥）
##   3 河边集市：三条摊位巷子，头顶的彩罐来回荡，被砸到的人直接飞出去
##   4 花船运河：花船载着去河中间的小岛；小岛北边的桥断了，下面是山谷 → 俯视转视角过桥
##   5 大祭坛（山谷里）：一根转着的骷髅长臂扫过整个广场，跳过去或者跟在它后面走
##     → 爬上小金字塔往北拍，第三处拍照接上天坑上的断桥 → 把逝者放上祭坛
##
## 联机：花车、彩罐、花船、长臂、倒下的墓碑都按 tick(t) 的时间算，两边各算各的；
## 拍没拍成由 main.gd 放在快照头里同步；断桥接没接上、墓碑什么时候开始倒放在 net_state 里。

const TY := 0.0  # 小镇地面
const MY := 0.0  # 集市、运河、小岛
const BAND_H := 3.0  # 音乐亭台面比小镇地面高多少
const AY := -4.63  # 祭坛山谷：比小岛低，从小岛过俯视断桥下去
const DEEP := AY - 4.0  # 小镇以后掉到这里算坠落
const WATER_Y := -1.2
const PHOTO_W := 3.2  # 拍照断口的路宽
# 1 墓园
const YARD := [16.0, 8.0, -32.0]  # 半宽、南边、北边
const GRAVE_ROWS := [-3.0, -8.0, -16.0, -21.0, -27.0]
const GRAVE_XS := [5.5, 8.0, 10.5, 13.0]
const TRENCH := [-22.4, -25.0]  # 墓地中间那道沟的南北两边
const PLATE := Vector3(14.0, 0, -18.5)  # 铃铛石板：踩上去墓碑就开始倒
const PLATE_R := 0.9
const DOMINO_SIZE := Vector3(0.55, 1.3, 0.16)  # 宽、高、厚
const DOMINO_STEP := 0.2  # 后一块比前一块晚多少秒倒
const DOMINO_FALL := 0.45  # 一块倒下去要多久
const SLAB := Vector3(3.2, 3.4, 0.4)  # 最后那块大石碑：倒下来就是过沟的桥
const SLAB_FALL := 1.2
const PIER_Z := -38.0
const ARM0_Z := [-39.6, -42.0]  # 第一处照片路面尽头往西拐的栈道
const WALK0 := [-8.8, -5.6]  # 墓园到小镇的栈道（x 范围）
# 2 小镇
const TOWN_X := 20.0
const STREET1 := [-58.5, -62.0]  # 南横街
const STREET2 := [-76.0, -79.5]  # 北横街
const PLAZA := [11.0, -62.0, -76.0]  # 广场半宽、南、北
const BAND_C := Vector3(0, TY, -69.0)
const BAND_R := 3.0
const BANK_Z := -84.0  # 小镇北岸
const ARM1_Z := [-90.1, -92.5]  # 第二处照片路面尽头往东拐的栈道
const WALK1 := [7.2, 10.4]  # 往北到集市的木桥（x 范围）
const FLOAT_RANGE := 17.0
const FLOAT_PERIOD := 14.0
# 3 集市
const MARKET_Z := [-98.1, -134.0]
const PINATAS := [[0.0, -104.0, 0.0], [0.0, -109.0, 1.3], [0.0, -118.0, 0.6], [0.0, -123.0, 2.0],
	[8.0, -106.0, 0.4], [8.0, -120.0, 1.7], [-8.0, -108.0, 1.1], [-8.0, -121.0, 0.2]]  # [x, z, 相位]
const PIN_LANE := {4: 8.8}  # 电脑队伍从哪条线走过这个彩罐底下（默认就是彩罐那条巷子的正中）
const PINATA_AMP := 3.0
const PINATA_PERIOD := 4.0
# 4 运河、小岛
const CANAL := [-134.0, -150.0]
const BOAT_W := 5.0
const BOAT_Z := [-136.5, -147.5]  # 靠南岸 / 小岛时船的中心
const BOAT_DOCK := 5.0
const BOAT_MOVE := 6.0
const ISLAND := [6.0, -150.0, -157.0]  # 半宽、南、北
const SEAM := Vector3(0, MY, -159.0)  # 小岛北边断桥的接缝
const ALIGN_YAW := 315.0
const BRIDGE_THICK := 0.8
# 5 山谷
const VALLEY := [9.5, -168.0, -222.0]  # 半宽、南、北
const HUB := Vector3(0, AY, -177.0)  # 转臂的轴
const SWEEP_LEN := 9.2
const SWEEP_PERIOD := 16.0
const SWEEP_TOP := 0.55  # 长臂的上沿离地多高：脚比这高就算跳过去了
const PYRAMID_H := 2.5
const PYRAMID_Z := [-190.4, -193.8]  # 金字塔顶的南北边
const CENOTE := [-197.0, -209.5]  # 天坑的南北边
const ARM2_Z := [-200.6, -203.0]
const WALK2 := [-8.8, -5.6]

var _time := 0.0
var _floats: Array[AnimatableBody3D] = []
var _pinatas: Array[Node3D] = []
var _pinata_hit_at := {}
var _boat: AnimatableBody3D
var _dominoes: Array[Node3D] = []
var _domino_dirs: Array[Vector3] = []
var _domino_t := -1.0  # 墓碑开始倒的时间（-1 = 还没人踩石板）
var _slab: AnimatableBody3D
var _slab_down := false
var _sweeper: Node3D
var _sweep_hit_at := {}
var _said := {}


func _init() -> void:
	id = "mexico"
	title = "万寿菊之路"
	par_time = 25.0 * 60.0
	kill_y = -12.0
	prefer_first_person = true
	goal_pos = Vector3(2.5, AY, -215.0)
	goal_size = Vector3(2.2, 0.8, 1.1)
	var lo := SEAM + _bridge_offset()
	rooms = [
		{name = "万寿菊墓园", spawn = Vector3(0, 0, 4), lift = 1.32, yaw = 0.0, kill_y = -12.0,
			path = [Vector3(0, 0, -6), Vector3(-5.6, 0, -12), Vector3(0, 0, -18.5), "wait:domino", Vector3(0, 0, -26.5),
				Vector3(0, 0, -36.6), "wait:photo0", Vector3(0, 0, -40.8), Vector3(-7.2, 0, -40.8), Vector3(-7.2, 0, -46.5)]},
		{name = "彩色小镇", spawn = Vector3(-7.2, TY, -46.5), yaw = 0.0, kill_y = DEEP,
			path = [Vector3(-7.2, 0, -56.5), "wait:float0", Vector3(-6.5, 0, -63.5), Vector3(-6.5, 0, -74.5), "wait:float1",
				Vector3(0, 0, -81.5), Vector3(0, 0, -86.2), "wait:photo1", Vector3(0, 0, -91.3), Vector3(8.8, 0, -91.3),
				Vector3(8.8, 0, -99.5)]},
		{name = "河边集市", spawn = Vector3(8.8, MY, -100.2), yaw = 0.0, kill_y = DEEP,
			path = [Vector3(8.8, 0, -104.0), "wait:pin4", Vector3(8.8, 0, -110.0), Vector3(8.8, 0, -113.0), Vector3(0, 0, -113.0),
				Vector3(0, 0, -115.8), "wait:pin2", Vector3(0, 0, -120.6), "wait:pin3", Vector3(0, 0, -127.0), Vector3(0, 0, -131.6)]},
		{name = "花船运河", spawn = Vector3(0, MY, -132.0), yaw = 0.0, kill_y = DEEP,
			path = ["wait:boat_s", Vector3(0, 0, -137.0), "wait:boat_n", Vector3(0, 0, -153.5), Vector3(0, 0, -157.6),
				"wait:align0", {dir = Vector3.FORWARD, until = "crossed0"}]},
		{name = "大祭坛", spawn = Vector3(lo.x, AY, -165.5), yaw = 0.0, kill_y = DEEP,
			path = [Vector3(lo.x, 0, -166.4), "wait:sweep", Vector3(lo.x, 0, -186.9), Vector3(6.2, 0, -188.5),
				Vector3(6.2, 0, -195.6), Vector3(0, 0, -195.6), Vector3(0, 0, -197.1), "wait:photo2", Vector3(0, 0, -201.8),
				Vector3(-7.2, 0, -201.8), Vector3(-7.2, 0, -211.0), Vector3(-7.2, 0, goal_pos.z), goal_pos]},
	]


## 俯视断桥的偏移：从接缝到下层那段起点（和 _view_bridge 里算的一样，_init 里要提前知道）
static func _bridge_offset() -> Vector3:
	var a := deg_to_rad(ALIGN_YAW)
	var cam := Vector3(sin(a) * Main.CAM_DIST, Main.CAM_HEIGHT, cos(a) * Main.CAM_DIST).normalized()
	return -cam * ((MY - AY) / cam.y)


func env() -> Dictionary:
	return {
		sky_top = Color(0.16, 0.14, 0.4), sky_horizon = Color(1.0, 0.52, 0.42), sky_curve = 0.14,
		ground_horizon = Color(0.9, 0.45, 0.45), ground_bottom = Color(0.12, 0.07, 0.18), ground_curve = 0.06,
		ambient = 0.8, exposure = 1.1, saturation = 1.2,
		fog_color = Color(0.7, 0.42, 0.55), fog_density = 0.006, fog_height = -7.0, fog_height_density = 0.12,
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
	_m.bridge = Art.floor_mat({base_color = Color(0.9, 0.55, 0.6), speck_a = Color(0.7, 0.36, 0.42),
		grout_color = Color(0.75, 0.42, 0.48), side_color = Color(0.82, 0.48, 0.55), tile = 0.8, roughness = 0.85})
	_m.wall = Art.wall_mat({upper = Color(0.95, 0.88, 0.78), lower = Color(0.85, 0.3, 0.45), trim = Color(0.98, 0.7, 0.2),
		cap = Color(0.6, 0.4, 0.32)})
	_build_cemetery()
	_build_town()
	_build_market()
	_build_canal()
	_build_valley()
	_build_backdrop()
	tick(0.0)


func room_at(p: Vector3) -> int:
	if p.z > ARM0_Z[1] - 0.5:
		return 0
	if p.z > MARKET_Z[0] - 0.5:
		return 1
	if p.z > -131.0:
		return 2
	if p.z > -160.0:
		return 3
	return 4


func _say_once(key: String, text: String) -> void:
	if not _said.has(key):
		_said[key] = true
		notice.emit(text)


## 一道矮栏（有碰撞，不算硬物）：a、b 是两端的地面点
func _rail(a: Vector3, b: Vector3, h := 1.0) -> void:
	var size := Vector3(maxf(absf(b.x - a.x), 0.16), h, maxf(absf(b.z - a.z), 0.16))
	var c := (a + b) / 2 + Vector3(0, h / 2, 0)
	_solid(size, c)
	add_child(Art.mesh(Art.box(Vector3(size.x, 0.1, size.z) + Vector3(0.04, 0, 0.04)), Props.WOOD, c + Vector3(0, h / 2 - 0.05, 0)))
	var n := int(maxf(size.x, size.z) / 0.8) + 1
	for k in n + 1:
		var p := a.lerp(b, float(k) / n)
		add_child(Art.mesh(Art.box(Vector3(0.1, h, 0.1)), Props.WOOD, p + Vector3(0, h / 2, 0)))


# ---------- 会动的东西 ----------

func tick(t: float) -> void:
	_time = t
	for i in _floats.size():
		_floats[i].position.x = _float_x(i, t)
	for i in _pinatas.size():
		_pinatas[i].position.x = _pinata_x(i, t)
	_boat.position.z = _boat_z(t)
	_sweeper.rotation.y = _sweep_angle(t)
	# 墓碑一块接一块往前倒（越倒越快），最后那块大石碑倒下来搭在沟上
	for i in _dominoes.size():
		var u := _domino_u(i, t)
		_dominoes[i].basis = Basis(Vector3.UP.cross(_domino_dirs[i]).normalized(), deg_to_rad(84.0) * u * u)
	var su := _slab_u(t)
	_slab.rotation.x = -PI / 2 * su * su


## 第 i 块墓碑倒到哪了：0 = 还立着，1 = 倒平了
func _domino_u(i: int, t: float) -> float:
	if _domino_t < 0.0:
		return 0.0
	return clampf((t - _domino_t - i * DOMINO_STEP) / DOMINO_FALL, 0.0, 1.0)


func _slab_u(t: float) -> float:
	if _domino_t < 0.0:
		return 0.0
	var start := _domino_t + _dominoes.size() * DOMINO_STEP + DOMINO_FALL * 0.6
	return clampf((t - start) / SLAB_FALL, 0.0, 1.0)


## 第 i 辆花车在横街上的位置：两头之间来回开，第二辆晚半个周期
func _float_x(i: int, t: float) -> float:
	var ph := fposmod(t / FLOAT_PERIOD + i * 0.5, 1.0)
	var tri := 1.0 - absf(ph * 2.0 - 1.0)
	return -FLOAT_RANGE + 2.0 * FLOAT_RANGE * smoothstep(0.0, 1.0, tri)


func _pinata_x(i: int, t: float) -> float:
	return PINATAS[i][0] + PINATA_AMP * sin(TAU * t / PINATA_PERIOD + PINATAS[i][2] * TAU / PINATA_PERIOD)


func _boat_phase(t: float) -> float:
	return fposmod(t, 2.0 * (BOAT_DOCK + BOAT_MOVE))


## 花船：靠南岸停 5 秒 → 6 秒开到小岛 → 停 5 秒 → 开回来
func _boat_z(t: float) -> float:
	var ph := _boat_phase(t)
	if ph < BOAT_DOCK:
		return BOAT_Z[0]
	if ph < BOAT_DOCK + BOAT_MOVE:
		return lerpf(BOAT_Z[0], BOAT_Z[1], smoothstep(0.0, 1.0, (ph - BOAT_DOCK) / BOAT_MOVE))
	if ph < 2.0 * BOAT_DOCK + BOAT_MOVE:
		return BOAT_Z[1]
	return lerpf(BOAT_Z[1], BOAT_Z[0], smoothstep(0.0, 1.0, (ph - 2.0 * BOAT_DOCK - BOAT_MOVE) / BOAT_MOVE))


## 骷髅长臂的朝向（弧度）：0 指向南（+Z），慢慢往东、往北转
func _sweep_angle(t: float) -> float:
	return TAU * fposmod(t / SWEEP_PERIOD + 0.3, 1.0)


func physics_update(g: Node) -> void:
	var dt := get_physics_process_delta_time()
	_update_view_bridges(g)
	# 站在船上的人：走路速度按船算（不然船一开，人就留在原地掉进水里）
	var bz := _boat_z(_time)
	var bv := (_boat_z(_time + dt) - bz) / dt
	for b in g.bearers:
		var p: Vector3 = b.global_position
		var on_boat := absf(p.x) < BOAT_W / 2 and absf(p.z - bz) < BOAT_W / 2 and absf(p.y - MY - 0.87) < 0.5
		if on_boat:
			b.ground_velocity += Vector3(0, 0, bv)
			_say_once("boat", "上船了！站稳，等船靠岸再下")
	# 铃铛石板：有人踩上去，墓碑就开始倒
	if _domino_t < 0.0:
		for b in g.bearers:
			var d: Vector3 = b.global_position - PLATE
			if Vector2(d.x, d.z).length() < PLATE_R and absf(d.y - 0.87) < 0.6:
				_start_dominoes()
				break
	if not _slab_down and _slab_u(_time) >= 1.0:
		_slab_down = true
		notice.emit("轰——大石碑倒下来，正好搭在沟上！")
	# 彩罐：荡到谁就把谁撞飞
	for i in _pinatas.size():
		var pp := Vector3(_pinata_x(i, _time), MY + 1.3, PINATAS[i][1])
		var vx := (_pinata_x(i, _time + dt) - pp.x) / dt
		for b in g.bearers:
			var d: Vector3 = b.global_position - pp
			if Vector2(d.x, d.z).length() < 0.7 and _time - _pinata_hit_at.get(b, -10.0) > 1.2:
				_pinata_hit_at[b] = _time
				b.knock(Vector3(signf(vx) * 7.0, 5.5, randf_range(-1.5, 1.5)))
				notice.emit("咚！被彩罐抡飞了！")
	# 骷髅长臂：扫到脚就把人铲飞；跳起来（脚比臂高）就没事
	var ang := _sweep_angle(_time)
	var arm := Vector2(sin(ang), cos(ang))
	var tangent := Vector2(cos(ang), -sin(ang))
	for b in g.bearers:
		var d: Vector3 = b.global_position - HUB
		var along := Vector2(d.x, d.z).dot(arm)
		var off := absf(Vector2(d.x, d.z).dot(tangent))
		var feet: float = d.y - 0.87
		if along > 0.8 and along < SWEEP_LEN + 0.2 and off < 0.4 and feet < SWEEP_TOP - 0.1 and feet > -0.5 \
				and _time - _sweep_hit_at.get(b, -10.0) > 1.0:
			_sweep_hit_at[b] = _time
			var speed := maxf(TAU / SWEEP_PERIOD * along * 1.6, 4.0)
			b.knock(Vector3(tangent.x, 0, tangent.y) * speed + Vector3(arm.x, 0, arm.y) * 2.0 + Vector3.UP * 6.0)
			notice.emit("被骷髅长臂铲飞了！下次跳起来，或者跟在它后面走")
	for i in _floats.size():
		var fx := _floats[i].position.x
		for b in g.bearers:
			if absf(b.global_position.x - fx) < 3.0 and absf(b.global_position.z - _floats[i].position.z) < 2.0:
				_say_once("float", "游行花车来了！让一让！")
	for b in g.bearers:
		if b.global_position.y < AY + 2.0 and b.global_position.z < -167.0:
			_say_once("sweep", "小心那根转着的骷髅长臂！")
			break


func _start_dominoes() -> void:
	_domino_t = _time
	notice.emit("当——铃铛响了！墓碑一块接一块倒下去……")


func net_state() -> PackedFloat32Array:
	return PackedFloat32Array([view_bridge_mask(), _domino_t])


func apply_net_state(a: PackedFloat32Array) -> void:
	if a.size() < 2:
		return
	apply_view_bridge_mask(int(a[0]))
	if a[1] >= 0.0 and _domino_t < 0.0:
		_domino_t = a[1]


func bot_can_go(tag: String) -> bool:
	if tag.begins_with("photo"):
		var i := int(tag.substr(5))
		fix_illusion(i)  # 电脑队伍不用真的举相机：直接当作拍对了
		return _illusions[i].solid
	if tag == "domino":  # 电脑队伍不用真的去踩石板
		if _domino_t < 0.0:
			_start_dominoes()
		return _slab_u(_time) >= 1.0
	if tag.begins_with("align"):
		var vb: Dictionary = _view_bridges[int(tag.substr(5))]
		if game.bot_noalign:
			return true
		vb.bot = true  # 电脑队伍当作有人在俯视
		game.cam_yaw_target = vb.yaw
		return vb.aligned
	if tag.begins_with("crossed"):
		return game.coffin.global_position.y < AY + 2.0
	if tag.begins_with("float"):
		# 接下来 3 秒花车都不会开到要穿过的那段横街附近
		var i := int(tag.substr(5))
		var cross_x := -7.0 if i == 0 else -3.5
		for k in 31:
			if absf(_float_x(i, _time + k * 0.1) - cross_x) < 5.0:
				return false
		return true
	if tag.begins_with("pin"):
		# 接下来 1.5 秒彩罐都不会荡到要走的那条线上
		var i := int(tag.substr(3))
		var lane: float = PIN_LANE.get(i, PINATAS[i][0])
		for k in 16:
			if absf(_pinata_x(i, _time + k * 0.1) - lane) < 1.0:
				return false
		return true
	if tag == "boat_s":
		return _boat_phase(_time) < 1.0
	if tag == "boat_n":
		var ph := _boat_phase(_time)
		return ph > BOAT_DOCK + BOAT_MOVE + 0.3 and ph < 2.0 * BOAT_DOCK + BOAT_MOVE - 1.0
	if tag == "sweep":  # 长臂已经扫过这条路的大半段：跟在它后面走（走得比它快，太早出发会追上它）
		var deg := rad_to_deg(_sweep_angle(_time))
		return deg > 100.0 and deg < 130.0
	return true


func debug_text() -> String:
	return "photos=%d bridge=%d domino=%.1f boat=%.1f sweep=%d" % [illusion_mask(), view_bridge_mask(), _domino_t,
		_boat_z(_time), roundi(rad_to_deg(_sweep_angle(_time)))]


# ---------- 1 万寿菊墓园 ----------

func _build_cemetery() -> void:
	var hw: float = YARD[0]
	var z0: float = YARD[1]
	var z1: float = YARD[2]
	# 地面被中间那道沟分成南北两块
	_floor(Vector3(-hw, 0, z0), Vector3(hw, 0, TRENCH[0]), _m.grass, 5.0)
	_floor(Vector3(-hw, 0, TRENCH[1]), Vector3(hw, 0, z1), _m.grass, 5.0)
	for zz in [[z0, TRENCH[0]], [TRENCH[1], z1]]:  # 中间的石板路
		add_child(Art.block(Vector3(3.6, 0.03, zz[0] - zz[1]), Vector3(0, 0.015, (zz[0] + zz[1]) / 2), _m.path))
	for k in 40:  # 路上撒的万寿菊花瓣
		var p := Vector3(randf_range(-1.6, 1.6), 0.035, randf_range(z1, z0))
		if p.z < TRENCH[0] and p.z > TRENCH[1]:
			continue
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
				if z < -25.0 and s < 0 and x > 9.0:
					continue  # 小教堂那块地方
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
	# 西边的小教堂、四周的柏树和雕像
	_put(PropsMexico.chapel(), Vector3(-12.0, 0, -29.0), 0.0)
	_solid(Vector3(4.0, 3.6, 5.0), Vector3(-12.0, 1.8, -29.0))
	_put(PropsMexico.catrina(2.2), Vector3(-3.0, 0, 1.8), 0.3)
	_solid(Vector3(0.8, 2.0, 0.8), Vector3(-3.0, 1.0, 1.8))
	_put(PropsMexico.sugar_skull(1.6), Vector3(7.5, 0, -30.5), -0.4)
	_solid(Vector3(1.4, 1.6, 1.4), Vector3(7.5, 0.8, -30.5))
	for p in [Vector3(-15, 0, 7), Vector3(15, 0, 7), Vector3(-15, 0, -12), Vector3(15, 0, -18), Vector3(15, 0, -31),
			Vector3(-6.5, 0, -31), Vector3(3.5, 0, -31)]:
		_put(PropsMexico.cypress(3.5 + absf(p.z) * 0.02), p)
	for z in [-1.0, -19.0, -28.5]:
		_put(PropsMexico.papel_picado(Vector3(-3.2, 3.4, z), Vector3(3.2, 3.4, z)), Vector3.ZERO)
		for s in [-1.0, 1.0]:
			add_child(Art.mesh(Art.cylinder(0.05, 0.05, 3.5), Props.WOOD, Vector3(s * 3.2, 1.75, z)))
	_lamp(Vector3(0, 3.5, -4.0), 0.9, 12.0, Color(1.0, 0.7, 0.4))
	_lamp(Vector3(0, 3.5, -22.0), 0.9, 12.0, Color(1.0, 0.7, 0.4))
	_wreath(Vector3(-14.0, 0, -19.0), 10.0, 0.5, PropsMexico.MARIGOLD.darkened(0.2), "万寿菊花环")
	_wreath(Vector3(14.0, 0, -2.5), 10.0, 0.5, PropsMexico.MARIGOLD.darkened(0.2), "万寿菊花环")
	_sign("抓住把手，把棺材抬到山谷里的大祭坛", Vector3(0, 3.0, 0.5))
	_build_dominoes()

	# 石栈道：伸出墓园，悬在山谷上，到 PIER_Z 就断了 → 第一处拍照。照片路面尽头往西拐，再往北接到小镇
	_floor(Vector3(-1.6, 0, z1), Vector3(1.6, 0, PIER_Z), _m.path, 5.0)
	var pier := _last_block
	for s in [-1.0, 1.0]:
		var cc := PropsMexico.candles(3)
		cc.position = Vector3(s * 1.4, 0, -34.0)
		add_child(cc)
	var end := _photo_gap(Vector3(0, 0, z1), Vector3(0, 0, PIER_Z), 1.8, PHOTO_W, PIER_Z - ARM0_Z[1], _m.path, [pier])
	_floor(Vector3(WALK0[0], 0, ARM0_Z[0]), Vector3(-PHOTO_W / 2, 0, end.z), _m.path, 0.8)
	_floor(Vector3(WALK0[0], 0, end.z), Vector3(WALK0[1], 0, -50.0), _m.path, 0.8)
	_rail(Vector3(WALK0[0], 0, ARM0_Z[0] + 0.08), Vector3(-PHOTO_W / 2, 0, ARM0_Z[0] + 0.08))  # 不让人从栈道尽头斜着跳过去
	_rail(Vector3(WALK0[0] + 0.08, 0, ARM0_Z[0]), Vector3(WALK0[0] + 0.08, 0, -50.0))
	_rail(Vector3(WALK0[1] - 0.08, 0, end.z), Vector3(WALK0[1] - 0.08, 0, -50.0))
	for p in [Vector3(-4.5, -12.0, -40.8), Vector3(-7.2, -12.0, -46.0)]:  # 栈道底下的柱子，一直伸进雾里
		add_child(Art.block(Vector3(0.8, 23.0, 0.8), p, _m.path))
	_sign("路断了？\n站到相机的圈里，按 C 举起相机看看", Vector3(0, 2.8, z1 + 2.5))


## 墓地中间那道沟：东边一块铃铛石板，一排墓碑从石板一直排到沟边的大石碑
func _build_dominoes() -> void:
	for zz in TRENCH:  # 沟两边的土壁
		add_child(Art.block(Vector3(YARD[0] * 2, 0.04, 0.3), Vector3(0, 0.02, zz), Art.mat(Color(0.3, 0.22, 0.18))))
	add_child(Art.mesh(Art.cylinder(PLATE_R, PLATE_R, 0.08, 20), Props.GOLD.darkened(0.3), PLATE + Vector3(0, 0.04, 0)))
	add_child(Art.mesh(Art.cylinder(0.25, 0.4, 0.6, 12), Props.GOLD, PLATE + Vector3(0, 0.38, 0)))  # 铃铛
	_sign("踩一下铃铛石板", PLATE + Vector3(0, 1.8, 0))
	_sign("沟太宽了，过不去……\n东边那块铃铛石板好像能踩", Vector3(0, 2.4, TRENCH[0] + 1.6))
	var pts: Array[Vector3] = []
	var x := 12.6
	while x > 2.0:
		pts.append(Vector3(x, 0, -17.6))
		x -= 1.0
	pts.append_array([Vector3(1.5, 0, -18.6), Vector3(0.9, 0, -19.7), Vector3(0.5, 0, -20.8)])
	var targets := pts.duplicate()
	targets.append(Vector3(0, 0, TRENCH[0] + 0.2))
	for i in pts.size():
		var pivot := Node3D.new()
		pivot.position = pts[i]
		var dir: Vector3 = (targets[i + 1] - pts[i]).normalized()
		var stone := Art.mesh(Art.box(DOMINO_SIZE), PropsMexico.CREAM.darkened(0.1 + 0.1 * (i % 2)),
			Vector3(0, DOMINO_SIZE.y / 2, 0))
		stone.rotation.y = atan2(dir.x, dir.z)  # 薄的那面朝倒下的方向
		pivot.add_child(stone)
		add_child(pivot)
		_dominoes.append(pivot)
		_domino_dirs.append(dir)
	# 大石碑：立在沟的南边，倒下来正好横跨整道沟（顶面和地面一样高）
	_slab = AnimatableBody3D.new()
	_slab.position = Vector3(0, -SLAB.z + 0.03, TRENCH[0])
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = SLAB
	cs.shape = box
	cs.position = Vector3(0, SLAB.y / 2, SLAB.z / 2)
	_slab.add_child(cs)
	_slab.add_child(Art.block(SLAB, cs.position, _m.path))
	var epitaph := _label3d("R.I.P.", Vector3(0, SLAB.y * 0.6, SLAB.z + 0.01), 64)
	epitaph.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	_slab.add_child(epitaph)
	add_child(_slab)


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
	_floor(Vector3(-hx, TY, -50.0), Vector3(hx, TY, BANK_Z), _m.street, 3.0)
	add_child(Art.block(Vector3(PLAZA[0] * 2, 0.02, PLAZA[1] - PLAZA[2]), Vector3(0, TY + 0.01, (PLAZA[1] + PLAZA[2]) / 2), _m.plaza))
	for s in [-1.0, 1.0]:
		_wall_z(s * (hx + WALL_T / 2), BANK_Z, -50.0, TY, _m.wall, 1.0)
		_wall_x(BANK_Z - WALL_T / 2, s * 3.2, s * hx, TY, _m.wall, 0.8)
	# 一片片房子：南边从栈道进来的是一条小巷
	_town_block(-hx, WALK0[0], -50.0, STREET1[0], PI, 1)
	_town_block(WALK0[1], hx, -50.0, STREET1[0], PI, 2)
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
	var wx := (WALK0[0] + WALK0[1]) / 2
	for z in [-52.0, -55.5]:
		_put(PropsMexico.papel_picado(Vector3(WALK0[0], TY + 4.6, z), Vector3(WALK0[1], TY + 4.6, z), 6), Vector3.ZERO)
	for z in [-81.0, -83.0]:
		_put(PropsMexico.papel_picado(Vector3(-3.2, TY + 4.6, z), Vector3(3.2, TY + 4.6, z), 10), Vector3.ZERO)
	for z in [STREET1[0] - 1.7, STREET2[0] - 1.7]:
		_put(PropsMexico.papel_picado(Vector3(-hx, TY + 5.2, z), Vector3(hx, TY + 5.2, z), 40), Vector3.ZERO)
	for x in [-8.0, 8.0]:
		_put(PropsMexico.papel_picado(Vector3(x, TY + 5.0, PLAZA[1]), Vector3(x, TY + 5.0, PLAZA[2]), 18), Vector3.ZERO)
	_lamp(Vector3(-6, TY + 4.0, -69.0), 1.0, 12.0, Color(1.0, 0.72, 0.45))
	_lamp(Vector3(6, TY + 4.0, -69.0), 1.0, 12.0, Color(1.0, 0.72, 0.45))
	_lamp(Vector3(wx, TY + 4.0, -54.0), 0.8, 10.0, Color(1.0, 0.72, 0.45))
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
	# 北岸：伸到运河上的半截木桥 → 第二处拍照。照片路面尽头往东拐，再往北接到集市
	_floor(Vector3(-1.6, TY, BANK_Z), Vector3(1.6, TY, -87.5), _m.wood, 0.6)
	var near := _last_block
	var eye_floor := Vector3(0, TY + BAND_H, BAND_C.z - BAND_R + 0.5)
	var end := _photo_gap(eye_floor, Vector3(0, TY, -87.5), 1.2, PHOTO_W, -87.5 - ARM1_Z[1], _m.wood, [near])
	_floor(Vector3(PHOTO_W / 2, TY, ARM1_Z[0]), Vector3(WALK1[1], TY, end.z), _m.wood, 0.6)
	_floor(Vector3(WALK1[0], TY, end.z), Vector3(WALK1[1], TY, MARKET_Z[0]), _m.wood, 0.6)
	_rail(Vector3(PHOTO_W / 2, TY, ARM1_Z[0] + 0.08), Vector3(WALK1[1], TY, ARM1_Z[0] + 0.08))
	_rail(Vector3(WALK1[1] - 0.08, TY, ARM1_Z[0]), Vector3(WALK1[1] - 0.08, TY, MARKET_Z[0]))
	_rail(Vector3(WALK1[0] + 0.08, TY, end.z), Vector3(WALK1[0] + 0.08, TY, MARKET_Z[0]))
	for p in [Vector3(5.0, WATER_Y - 3.0, -91.3), Vector3(8.8, WATER_Y - 3.0, -96.0)]:
		add_child(Art.block(Vector3(0.5, 6.0, 0.5), p, _m.wood))


# ---------- 3 河边集市 ----------

func _build_market() -> void:
	var z0: float = MARKET_Z[0]
	var z1: float = MARKET_Z[1]
	_floor(Vector3(-18, MY, z0), Vector3(18, MY, z1), _m.plaza, 2.0)
	for s in [-1.0, 1.0]:
		_wall_z(s * (18 + WALL_T / 2), z1, z0, MY, _m.wall, 1.0)
	_wall_x(z0 - WALL_T / 2, -18, WALK1[0], MY, _m.wall, 0.8)
	_wall_x(z0 - WALL_T / 2, WALK1[1], 18, MY, _m.wall, 0.8)
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
	_sign("小心头顶的彩罐", Vector3(WALK1[0] + 1.6, MY + 3.0, -101.5))


# ---------- 4 花船运河、小岛 ----------

func _build_canal() -> void:
	var water := StandardMaterial3D.new()
	water.albedo_color = Color(0.15, 0.4, 0.5, 0.75)
	water.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water.roughness = 0.08
	water.metallic = 0.2
	# 小镇和集市之间的运河、集市北边的运河，一整片水面
	add_child(Art.block(Vector3(60, 0.05, BANK_Z - MARKET_Z[0] + 2), Vector3(0, WATER_Y, (BANK_Z + MARKET_Z[0]) / 2), water))
	add_child(Art.block(Vector3(60, 0.05, CANAL[0] - CANAL[1] + 2), Vector3(0, WATER_Y, (CANAL[0] + CANAL[1]) / 2), water))
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

	# 河中间的小岛：北边是悬崖，下面就是祭坛所在的山谷。小岛伸出去的石桥断了 → 俯视转视角
	var hw: float = ISLAND[0]
	_floor(Vector3(-hw, MY, ISLAND[1]), Vector3(hw, MY, ISLAND[2]), _m.plaza, 5.0)
	_floor(Vector3(-1.6, MY, ISLAND[2]), Vector3(1.6, MY, SEAM.z), _m.bridge, BRIDGE_THICK)
	var offset := _view_bridge(SEAM, Vector3.FORWARD, 3.2, ALIGN_YAW, MY - AY)
	var lo := SEAM + offset
	_floor(Vector3(lo.x - 1.6, AY, lo.z), Vector3(lo.x + 1.6, AY, VALLEY[1]), _m.bridge, BRIDGE_THICK)
	for p in [Vector3(0, MY - BRIDGE_THICK - 6.0, -158.0), Vector3(lo.x, AY - BRIDGE_THICK - 6.0, -166.5)]:  # 桥墩伸进雾里
		add_child(Art.block(Vector3(1.6, 12.0, 0.9), p, _m.bridge))
	for s in [-1.0, 1.0]:
		_put(PropsMexico.cypress(3.0), Vector3(s * 4.5, MY, -155.5))
		_put(PropsMexico.marigolds(8, 0.6, 3), Vector3(s * 2.6, MY, -156.2))
	_put(PropsMexico.catrina(2.0), Vector3(-4.0, MY, -151.5), 0.4)
	_solid(Vector3(0.8, 2.0, 0.8), Vector3(-4.0, MY + 1.0, -151.5))
	_wreath(Vector3(4.6, MY, -151.2), 10.0, 0.45, PropsMexico.MARIGOLD.darkened(0.2), "万寿菊花环")
	_sign("桥断了？\n按 V 换成俯视，再按 Q / E 转视角试试", Vector3(0, 2.6, ISLAND[2] + 1.0))
	_lamp(Vector3(0, MY + 3.0, -155.0), 0.8, 10.0, Color(1.0, 0.65, 0.4))


# ---------- 5 山谷里的大祭坛 ----------

func _build_valley() -> void:
	var hw: float = VALLEY[0]
	var z0: float = VALLEY[1]
	var z1: float = VALLEY[2]
	var lo := SEAM + _bridge_offset()
	_floor(Vector3(-hw, AY, z0), Vector3(hw, AY, CENOTE[0]), _m.plaza, 2.0)
	for s in [-1.0, 1.0]:
		_wall_z(s * (hw + WALL_T / 2), z1, z0, AY, _m.wall, 1.2)
	_wall_x(z0 + WALL_T / 2, -hw, lo.x - 1.6, AY, _m.wall, 1.2)
	_wall_x(z0 + WALL_T / 2, lo.x + 1.6, hw, AY, _m.wall, 1.2)
	_wall_x(z1 - WALL_T / 2, -hw, hw, AY, _m.wall, 1.2)
	_put(PropsMexico.marigold_arch(4.0, 3.2), Vector3(lo.x, AY, z0 - 0.6))

	# 骷髅长臂：中间一根柱子，一条长臂贴着地面慢慢转，扫过整个广场
	_box(Vector3(1.6, 2.2, 1.6), HUB + Vector3(0, 1.1, 0), PropsMexico.TURQUOISE.darkened(0.2), true)
	_sweeper = Node3D.new()
	_sweeper.position = HUB
	_sweeper.add_child(Art.mesh(Art.box(Vector3(0.2, SWEEP_TOP - 0.2, SWEEP_LEN - 0.8)), PropsMexico.MAGENTA,
		Vector3(0, (SWEEP_TOP + 0.2) / 2, (SWEEP_LEN + 0.8) / 2)))
	for k in 8:
		var z := 1.4 + k * (SWEEP_LEN - 1.6) / 7.0
		_sweeper.add_child(Art.mesh(Art.sphere(0.16), PropsMexico.MARIGOLD if k % 2 else PropsMexico.CREAM, Vector3(0, SWEEP_TOP, z)))
	_sweeper.add_child(Art.mesh(Art.cylinder(0.25, 0.25, 0.12, 12), Props.BLACK, Vector3(0, 0.25, SWEEP_LEN)))
	var skull := PropsMexico.sugar_skull(1.2)
	skull.position = Vector3(0, 2.2, 0)
	_sweeper.add_child(skull)
	add_child(_sweeper)
	_wreath(Vector3(-8.0, AY, -180.0), 15.0, 0.45, PropsMexico.MARIGOLD.darkened(0.2), "万寿菊花环")

	# 小金字塔：南边一道台阶上去，顶上是第三处拍照点
	var tiers := [[2.6, -189.6, PYRAMID_Z[1], 0.9], [2.1, -190.0, PYRAMID_Z[1], 1.7], [1.7, PYRAMID_Z[0], PYRAMID_Z[1], PYRAMID_H]]
	for k in tiers.size():
		var t: Array = tiers[k]
		var size := Vector3(t[0] * 2, t[3], t[1] - t[2])
		_box(size, Vector3(0, AY + t[3] / 2, (t[1] + t[2]) / 2), PropsMexico.ADOBE.darkened(0.12 * (k % 2)), false)
	var steps := 8
	var front: float = PYRAMID_Z[0] + 3.8
	for k in steps:
		var h := PYRAMID_H * (k + 1) / steps
		var zs := front - k * 3.8 / steps
		_box(Vector3(1.6, h, zs - PYRAMID_Z[0]), Vector3(0, AY + h / 2, (zs + PYRAMID_Z[0]) / 2),
			PropsMexico.CREAM.darkened(0.06 * (k % 2)), false)
	for s in [-1.0, 1.0]:
		_put(PropsMexico.candles(5, 0.15), Vector3(s * 1.4, AY + PYRAMID_H, PYRAMID_Z[1] + 0.3))
	_sign("爬上金字塔，往北边的天坑看", Vector3(0, AY + PYRAMID_H + 2.4, front))

	# 天坑：南边伸出去半截石栈道 → 第三处拍照。照片路面尽头往西拐，再往北接到祭坛平台
	var a := Vector3(0, AY, CENOTE[0] - 2.0)
	_floor(Vector3(-1.6, AY, CENOTE[0]), Vector3(1.6, AY, a.z), _m.path, 2.0)
	var pier := _last_block
	var end := _photo_gap(Vector3(0, AY + PYRAMID_H, PYRAMID_Z[0] - 0.6), a, 1.5, PHOTO_W, a.z - ARM2_Z[1], _m.path, [pier])
	_floor(Vector3(WALK2[0], AY, ARM2_Z[0]), Vector3(-PHOTO_W / 2, AY, end.z), _m.path, 0.8)
	_floor(Vector3(WALK2[0], AY, end.z), Vector3(WALK2[1], AY, CENOTE[1]), _m.path, 0.8)
	_rail(Vector3(WALK2[0], AY, ARM2_Z[0] + 0.08), Vector3(-PHOTO_W / 2, AY, ARM2_Z[0] + 0.08))
	_rail(Vector3(WALK2[1] - 0.08, AY, end.z), Vector3(WALK2[1] - 0.08, AY, CENOTE[1]))
	var cenote_water := StandardMaterial3D.new()
	cenote_water.albedo_color = Color(0.1, 0.35, 0.45)
	cenote_water.roughness = 0.1
	add_child(Art.block(Vector3(hw * 2, 0.05, CENOTE[0] - CENOTE[1]), Vector3(0, DEEP - 0.5, (CENOTE[0] + CENOTE[1]) / 2), cenote_water))

	# 祭坛平台：灵台是一张铺着紫布的长桌；后面一座大祭坛
	_floor(Vector3(-hw, AY, CENOTE[1]), Vector3(hw, AY, z1), _m.plaza, 2.0)
	_box(goal_size, goal_pos + Vector3(0, goal_size.y / 2, 0), PropsMexico.PURPLE, false)
	add_child(Art.mesh(Art.box(Vector3(goal_size.x + 0.1, 0.04, goal_size.z + 0.1)), PropsMexico.MARIGOLD,
		goal_pos + Vector3(0, goal_size.y, 0)))
	var fl := PropsMexico.marigolds(12, 0.5, 9)
	fl.position = goal_pos + Vector3(0, 0, -goal_size.z / 2 - 0.15)
	fl.scale = Vector3(2.5, 1, 0.5)
	add_child(fl)
	_put(PropsMexico.ofrenda(6.0), Vector3(0, AY, z1 + 1.2))
	_solid(Vector3(6.0, 1.6, 1.0), Vector3(0, AY + 0.8, z1 + 1.0))
	for s in [-1.0, 1.0]:
		_put(PropsMexico.catrina(2.4), Vector3(s * 6.5, AY, z1 + 2.5), 0.0)
		_put(PropsMexico.cypress(4.0), Vector3(s * 8.3, AY, -213.0))
		var cc := PropsMexico.candles(9, 0.2)
		cc.position = Vector3(s * 4.0, AY, -218.5)
		add_child(cc)
	for z in [-172.0, -182.0, -213.0]:
		_put(PropsMexico.papel_picado(Vector3(-hw, AY + 5.5, z), Vector3(hw, AY + 5.5, z), 30), Vector3.ZERO)
	_lamp(Vector3(0, AY + 3.0, -216.0), 1.4, 12.0, Color(1.0, 0.65, 0.35))
	_lamp(Vector3(0, AY + 4.0, -177.0), 1.0, 14.0, Color(1.0, 0.65, 0.35))
	_lamp(Vector3(0, AY + 4.0, -194.0), 0.9, 10.0, Color(1.0, 0.65, 0.35))
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
