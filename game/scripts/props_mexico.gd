class_name PropsMexico
extends RefCounted
## 墨西哥亡灵节关的道具：只有外观，碰撞由关卡自己加。都是代码拼的低多边形；
## 卡特里娜、阿雷布里赫、糖骷髅、骷髅乐手优先用 Lux3D 生成的模型，没有就用拼的顶上。

const MARIGOLD := Color(1.0, 0.55, 0.08)
const MARIGOLD_Y := Color(1.0, 0.78, 0.15)
const MAGENTA := Color(0.88, 0.16, 0.52)
const TURQUOISE := Color(0.1, 0.72, 0.7)
const PURPLE := Color(0.46, 0.2, 0.62)
const LIME := Color(0.55, 0.8, 0.22)
const CREAM := Color(0.96, 0.9, 0.78)
const ADOBE := Color(0.82, 0.6, 0.45)
const WOOD := Props.WOOD
const BLACK := Props.BLACK
const HOUSE_COLORS := [Color(0.95, 0.42, 0.55), Color(0.2, 0.62, 0.78), Color(0.98, 0.78, 0.25), Color(0.55, 0.78, 0.4),
	Color(0.62, 0.42, 0.78), Color(0.98, 0.55, 0.3), Color(0.3, 0.75, 0.68), Color(0.92, 0.3, 0.3)]
const FLAG_COLORS := [MAGENTA, TURQUOISE, MARIGOLD, PURPLE, LIME, Color(0.95, 0.3, 0.3)]

const CATRINA_GLB := "res://assets/props/catrina.glb"
const ALEBRIJE_GLB := "res://assets/props/alebrije.glb"
const SUGARSKULL_GLB := "res://assets/props/sugarskull.glb"
const MARIACHI_GLB := "res://assets/props/mariachi.glb"


static func _add(parent: Node3D, m: Mesh, color: Color, pos: Vector3, scale := Vector3.ONE, rot := Vector3.ZERO) -> MeshInstance3D:
	return Props._add(parent, m, color, pos, scale, rot)


static func _glow(parent: Node3D, m: Mesh, color: Color, pos: Vector3, energy := 3.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = Art.glow(color, energy)
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


## 一簇万寿菊（橙黄小球）
static func marigolds(n := 5, spread := 0.3, seed := 0) -> Node3D:
	var root := Node3D.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	for i in n:
		var p := Vector3(rng.randf_range(-spread, spread), 0.1 + rng.randf() * 0.12, rng.randf_range(-spread, spread))
		_add(root, Art.sphere(0.09 + rng.randf() * 0.05), MARIGOLD if i % 3 else MARIGOLD_Y, p)
	return root


## 一排蜡烛：白蜡烛 + 发光火苗
static func candles(n := 3, spacing := 0.12) -> Node3D:
	var root := Node3D.new()
	for i in n:
		var h := 0.12 + (i % 3) * 0.06
		var x := (i - (n - 1) / 2.0) * spacing
		_add(root, Art.cylinder(0.025, 0.025, h), CREAM, Vector3(x, h / 2, 0))
		var f := _glow(root, Art.sphere(0.02), Color(1.0, 0.7, 0.3), Vector3(x, h + 0.03, 0), 6.0)
		f.scale = Vector3(1, 1.7, 1)
	return root


## 坟：土堆 + 墓碑（或十字架）+ 花和蜡烛；沿 Z 长 2 米
static func grave(kind := 0, color := CREAM) -> Node3D:
	var n := Node3D.new()
	_add(n, Art.box(Vector3(1.0, 0.25, 1.8)), Color(0.42, 0.3, 0.24), Vector3(0, 0.125, 0))
	var top := marigolds(9, 0.4, kind * 7 + 1)
	top.position = Vector3(0, 0.22, 0.1)
	top.scale = Vector3(1, 1, 2.0)
	n.add_child(top)
	if kind % 2 == 0:
		_add(n, Art.box(Vector3(0.8, 0.9, 0.16)), color, Vector3(0, 0.45, -0.85))
		_add(n, Art.cylinder(0.4, 0.4, 0.16, 16), color, Vector3(0, 0.9, -0.85), Vector3.ONE, Vector3(PI / 2, 0, 0))
	else:
		_add(n, Art.box(Vector3(0.12, 1.2, 0.12)), color, Vector3(0, 0.6, -0.85))
		_add(n, Art.box(Vector3(0.6, 0.12, 0.12)), color, Vector3(0, 0.9, -0.85))
	var c := candles(3)
	c.position = Vector3(0.3, 0.25, 0.75)
	n.add_child(c)
	return n


static func cypress(height := 4.0) -> Node3D:
	var n := Node3D.new()
	_add(n, Art.cylinder(0.08, 0.1, 0.5), WOOD, Vector3(0, 0.25, 0))
	_add(n, Art.cylinder(0.0, 0.55, height - 0.4, 8), Color(0.16, 0.36, 0.22), Vector3(0, 0.4 + (height - 0.4) / 2, 0))
	return n


## 一串剪纸彩旗：从 a 拉到 b，中间微微下垂
static func papel_picado(a: Vector3, b: Vector3, flags := 12) -> Node3D:
	var n := Node3D.new()
	var mat := StandardMaterial3D.new()
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	for i in flags + 1:
		var t := float(i) / flags
		var p := a.lerp(b, t) + Vector3(0, -0.5 * sin(t * PI), 0)
		if i < flags:
			var q := a.lerp(b, t + 0.5 / flags) + Vector3(0, -0.5 * sin((t + 0.5 / flags) * PI) - 0.2, 0)
			var flag := _add(n, Art.box(Vector3(0.32, 0.36, 0.005)), FLAG_COLORS[i % FLAG_COLORS.size()], q)
			flag.basis = Basis.looking_at((b - a).cross(Vector3.UP).normalized(), Vector3.UP)
			flag.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if i > 0:
			var prev := a.lerp(b, float(i - 1) / flags) + Vector3(0, -0.5 * sin(float(i - 1) / flags * PI), 0)
			var seg := _add(n, Art.box(Vector3(0.01, 0.01, prev.distance_to(p))), BLACK, (prev + p) / 2)
			seg.basis = Basis.looking_at((p - prev).normalized(), Vector3.UP)
	return n


## 一栋彩色小房子（外观）：墙、檐口、门、两扇窗、窗台花箱。正面朝 +Z，底面中心在原点
static func house(w: float, h: float, d: float, color: Color, seed := 0) -> Node3D:
	var n := Node3D.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	_add(n, Art.box(Vector3(w, h, d)), color, Vector3(0, h / 2, 0))
	_add(n, Art.box(Vector3(w + 0.16, 0.18, d + 0.16)), color.darkened(0.3), Vector3(0, h + 0.09, 0))
	_add(n, Art.box(Vector3(w, 0.3, 0.02)), color.lightened(0.25), Vector3(0, 0.15, d / 2 + 0.01))
	var trim: Color = HOUSE_COLORS[(seed + 3) % HOUSE_COLORS.size()]
	var door_x := rng.randf_range(-w * 0.25, w * 0.25)
	_add(n, Art.box(Vector3(0.9, 1.9, 0.06)), WOOD.lightened(0.15), Vector3(door_x, 0.95, d / 2 + 0.03))
	_add(n, Art.box(Vector3(1.1, 0.12, 0.08)), trim, Vector3(door_x, 1.96, d / 2 + 0.04))
	for k in int(w / 1.6):
		var x := -w / 2 + 0.8 + k * 1.6
		if absf(x - door_x) < 0.9:
			continue
		var y := 1.5 if h < 4.0 else 1.5 + (k % 2) * 1.5
		_add(n, Art.box(Vector3(0.7, 0.8, 0.05)), Color(0.15, 0.2, 0.3), Vector3(x, y, d / 2 + 0.03))
		_add(n, Art.box(Vector3(0.84, 0.94, 0.03)), trim, Vector3(x, y, d / 2 + 0.015))
		var box := _add(n, Art.box(Vector3(0.8, 0.14, 0.18)), WOOD, Vector3(x, y - 0.5, d / 2 + 0.1))
		var flowers := marigolds(4, 0.3, seed + k)
		flowers.position = box.position + Vector3(0, 0.02, 0)
		flowers.scale = Vector3(1.0, 0.6, 0.4)
		n.add_child(flowers)
	return n


## 亡灵节祭坛：三层台阶，铺紫和橙的布，摆蜡烛、遗像、糖骷髅、万寿菊；正面朝 +Z
static func ofrenda(width := 3.0) -> Node3D:
	var n := Node3D.new()
	for k in 3:
		var w := width - k * 0.6
		var y := 0.35 + k * 0.4
		_add(n, Art.box(Vector3(w, 0.4, 0.8 - k * 0.15)), PURPLE if k % 2 == 0 else MARIGOLD, Vector3(0, y - 0.2, -k * 0.2))
		var c := candles(int(w / 0.25))
		c.position = Vector3(0, y, 0.25 - k * 0.2)
		n.add_child(c)
	for x in [-0.4, 0.4]:  # 遗像
		_add(n, Art.box(Vector3(0.36, 0.46, 0.04)), Props.GOLD, Vector3(x, 1.55, -0.45))
		_add(n, Art.box(Vector3(0.28, 0.38, 0.05)), Color(0.35, 0.32, 0.3), Vector3(x, 1.55, -0.44))
	for x in [-width / 2 + 0.3, width / 2 - 0.3]:
		var skull := sugar_skull(0.3)
		skull.position = Vector3(x, 0.55, 0.1)
		n.add_child(skull)
	var arch := marigold_arch(width + 0.4, 2.4)
	arch.position.z = -0.4
	n.add_child(arch)
	return n


## 万寿菊拱门（外观），正面朝 +Z
static func marigold_arch(width: float, height: float) -> Node3D:
	var n := Node3D.new()
	var steps := 18
	for i in steps + 1:
		var a := PI * i / steps
		var p := Vector3(-cos(a) * width / 2, height - width / 2 + sin(a) * width / 2, 0)
		if p.y < 0.0:
			continue
		_add(n, Art.sphere(0.14), MARIGOLD if i % 2 else MARIGOLD_Y, p)
	for s in [-1.0, 1.0]:
		for k in 6:
			var y := (height - width / 2) * k / 6.0
			_add(n, Art.sphere(0.13), MARIGOLD if k % 2 else MARIGOLD_Y, Vector3(s * width / 2, y, 0))
	return n


## 集市摊位：桌子 + 条纹布篷 + 一些货
static func stall(color: Color, seed := 0) -> Node3D:
	var n := Node3D.new()
	_add(n, Art.box(Vector3(2.4, 0.9, 1.4)), WOOD.lightened(0.2), Vector3(0, 0.45, 0))
	for x in [-1.1, 1.1]:
		for z in [-0.6, 0.6]:
			_add(n, Art.cylinder(0.04, 0.04, 2.2), WOOD, Vector3(x, 1.1, z))
	for k in 5:
		_add(n, Art.box(Vector3(2.6 / 5.0, 0.06, 1.7)), color if k % 2 == 0 else CREAM,
			Vector3(-1.3 + 2.6 / 10.0 + k * 2.6 / 5.0, 2.22, 0), Vector3.ONE, Vector3(0.12, 0, 0))
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	for k in 6:
		var c: Color = FLAG_COLORS[rng.randi() % FLAG_COLORS.size()]
		var p := Vector3(rng.randf_range(-1.0, 1.0), 1.0, rng.randf_range(-0.5, 0.5))
		if k % 2:
			_add(n, Art.sphere(0.14), c, p + Vector3(0, 0.08, 0))
		else:
			var s := sugar_skull(0.18)
			s.position = p
			n.add_child(s)
	return n


## 彩罐：星形，七个尖角，挂一根绳
static func pinata(color := MAGENTA) -> Node3D:
	var n := Node3D.new()
	_add(n, Art.sphere(0.4), color, Vector3.ZERO)
	var dirs := [Vector3.UP, Vector3.DOWN, Vector3.LEFT, Vector3.RIGHT, Vector3.FORWARD, Vector3.BACK,
		Vector3(1, 1, 0).normalized()]
	for i in dirs.size():
		var d: Vector3 = dirs[i]
		var cone := _add(n, Art.cylinder(0.0, 0.17, 0.5, 8), FLAG_COLORS[i % FLAG_COLORS.size()], d * 0.5)
		cone.basis = Basis(Quaternion(Vector3.UP, d)) if d != Vector3.DOWN else Basis(Vector3.RIGHT, PI)
	for k in 4:  # 下面的彩带
		_add(n, Art.box(Vector3(0.04, 0.5, 0.01)), FLAG_COLORS[k], Vector3((k - 1.5) * 0.08, -0.8, 0))
	return n


## 花船（trajinera）的外观：彩色船身 + 拱门招牌 + 花；甲板顶面在原点，长边沿 Z
static func trajinera(w: float, l: float, name := "LUPITA") -> Node3D:
	var n := Node3D.new()
	_add(n, Art.box(Vector3(w, 0.6, l)), Color(0.85, 0.3, 0.25), Vector3(0, -0.3, 0))
	_add(n, Art.box(Vector3(w + 0.1, 0.12, l + 0.1)), TURQUOISE, Vector3(0, -0.05, 0))
	_add(n, Art.box(Vector3(w - 0.3, 0.02, l - 0.3)), WOOD.lightened(0.35), Vector3(0, 0.01, 0))
	for s in [-1.0, 1.0]:
		_add(n, Art.box(Vector3(0.12, 0.3, l)), MARIGOLD_Y, Vector3(s * (w / 2 - 0.06), 0.15, 0))
	for z in [-l / 2 + 0.2, l / 2 - 0.2]:
		for s in [-1.0, 1.0]:
			_add(n, Art.cylinder(0.05, 0.05, 2.4), PURPLE, Vector3(s * (w / 2 - 0.1), 1.2, z))
		_add(n, Art.box(Vector3(w, 0.5, 0.08)), MAGENTA, Vector3(0, 2.4, z))
		n.add_child(Art.text(name, 64, MARIGOLD_Y, Vector3(0, 2.4, z + (0.05 if z > 0 else -0.05))))
		var arch := marigold_arch(w - 0.2, 2.2)
		arch.position = Vector3(0, 0, z)
		arch.scale = Vector3(1, 1, 0.5)
		n.add_child(arch)
	return n


## 广场上的音乐亭：八角形台子 + 柱子 + 顶；台面高 h，半径 r
static func bandstand(r: float, h: float) -> Node3D:
	var n := Node3D.new()
	_add(n, Art.cylinder(r, r + 0.2, h, 8), CREAM, Vector3(0, h / 2, 0))
	_add(n, Art.cylinder(r + 0.1, r + 0.1, 0.12, 8), TURQUOISE, Vector3(0, h - 0.06, 0))
	for k in 8:
		var a := TAU * (k + 0.5) / 8.0
		_add(n, Art.cylinder(0.08, 0.08, 2.6), Color(0.2, 0.5, 0.4), Vector3(cos(a) * (r - 0.2), h + 1.3, sin(a) * (r - 0.2)))
	_add(n, Art.cylinder(0.3, r + 0.4, 1.0, 8), MAGENTA, Vector3(0, h + 3.1, 0))
	_add(n, Art.sphere(0.25), Props.GOLD, Vector3(0, h + 3.7, 0))
	return n


## 白墙小教堂（外观）：正面朝 +Z，带钟楼
static func chapel() -> Node3D:
	var n := Node3D.new()
	_add(n, Art.box(Vector3(4.0, 3.6, 5.0)), CREAM, Vector3(0, 1.8, 0))
	_add(n, Art.box(Vector3(4.2, 0.2, 5.2)), ADOBE, Vector3(0, 3.7, 0))
	_add(n, Art.box(Vector3(1.6, 2.4, 1.6)), CREAM, Vector3(0, 4.9, 1.7))
	_add(n, Art.cylinder(0.0, 1.1, 1.0, 4), ADOBE, Vector3(0, 6.6, 1.7), Vector3.ONE, Vector3(0, PI / 4, 0))
	_add(n, Art.box(Vector3(0.6, 0.8, 0.06)), Color(0.12, 0.12, 0.15), Vector3(0, 5.0, 2.52))
	_add(n, Art.box(Vector3(1.4, 2.2, 0.08)), WOOD, Vector3(0, 1.1, 2.52))
	_add(n, Art.box(Vector3(0.1, 0.7, 0.06)), Props.GOLD, Vector3(0, 7.4, 1.7))
	_add(n, Art.box(Vector3(0.4, 0.1, 0.06)), Props.GOLD, Vector3(0, 7.55, 1.7))
	return n


## 游行花车：一辆彩色木车，上面站一只阿雷布里赫神兽；沿 X 开
static func parade_float() -> Node3D:
	var n := Node3D.new()
	_add(n, Art.box(Vector3(2.6, 0.7, 1.8)), MAGENTA, Vector3(0, 0.6, 0))
	_add(n, Art.box(Vector3(2.7, 0.12, 1.9)), MARIGOLD_Y, Vector3(0, 0.98, 0))
	for x in [-0.9, 0.9]:
		for z in [-0.95, 0.95]:
			_add(n, Art.cylinder(0.3, 0.3, 0.12, 12), WOOD, Vector3(x, 0.3, z), Vector3.ONE, Vector3(PI / 2, 0, 0))
	var beast := alebrije(1.4)
	beast.position.y = 1.04
	beast.rotation.y = PI / 2
	n.add_child(beast)
	var arch := marigold_arch(2.4, 2.6)
	arch.rotation.y = PI / 2
	n.add_child(arch)
	return n


# ---------- Lux3D 生成的大件（没有就用拼的顶上）----------

static func catrina(height := 2.0) -> Node3D:
	var n := Props._glb(CATRINA_GLB, height)
	if n:
		return n
	n = Node3D.new()
	var s := height / 2.0
	_add(n, Art.cylinder(0.2, 0.5, 1.2), MAGENTA, Vector3(0, 0.6, 0) * s, Vector3.ONE * s)
	_add(n, Art.sphere(0.2), CREAM, Vector3(0, 1.45, 0) * s, Vector3.ONE * s)
	_add(n, Art.cylinder(0.55, 0.55, 0.05, 16), BLACK, Vector3(0, 1.62, 0) * s, Vector3.ONE * s)
	var f := marigolds(5, 0.2, 3)
	f.position = Vector3(0, 1.62, 0) * s
	n.add_child(f)
	return n


static func alebrije(height := 1.6) -> Node3D:
	var n := Props._glb(ALEBRIJE_GLB, height)
	if n:
		return n
	n = Node3D.new()
	var s := height / 1.6
	_add(n, Art.sphere(0.5), TURQUOISE, Vector3(0, 0.8, 0) * s, Vector3(1.6, 0.8, 0.8) * s)
	_add(n, Art.sphere(0.3), TURQUOISE, Vector3(0.8, 1.1, 0) * s, Vector3.ONE * s)
	for z in [-0.4, 0.4]:
		_add(n, Art.box(Vector3(0.6, 0.05, 0.8)), MAGENTA, Vector3(0, 1.2, z * 1.5) * s, Vector3.ONE * s)
	return n


static func sugar_skull(height := 1.0) -> Node3D:
	var n := Props._glb(SUGARSKULL_GLB, height)
	if n:
		return n
	n = Node3D.new()
	_add(n, Art.sphere(height * 0.45), CREAM, Vector3(0, height * 0.5, 0))
	for x in [-0.15, 0.15]:
		_add(n, Art.sphere(height * 0.12), MARIGOLD, Vector3(x * height, height * 0.55, height * 0.36))
	return n


static func mariachi(height := 1.9) -> Node3D:
	var n := Props._glb(MARIACHI_GLB, height)
	if n:
		return n
	n = Node3D.new()
	var s := height / 1.9
	_add(n, Art.cylinder(0.2, 0.22, 1.3), BLACK, Vector3(0, 0.65, 0) * s, Vector3.ONE * s)
	_add(n, Art.sphere(0.18), CREAM, Vector3(0, 1.5, 0) * s, Vector3.ONE * s)
	_add(n, Art.cylinder(0.45, 0.45, 0.05, 16), BLACK, Vector3(0, 1.68, 0) * s, Vector3.ONE * s)
	return n
