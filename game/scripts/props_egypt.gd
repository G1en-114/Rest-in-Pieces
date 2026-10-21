class_name PropsEgypt
extends RefCounted
## 埃及关的道具：只有外观，碰撞由关卡自己加。都是代码拼的低多边形；
## 斯芬克斯、阿努比斯、法老石棺、圣甲虫优先用 Lux3D 生成的模型，没有就用拼的顶上。

const SAND := Color(0.93, 0.78, 0.52)
const SANDSTONE := Color(0.86, 0.7, 0.48)
const DARK_STONE := Color(0.42, 0.33, 0.25)
const LAPIS := Color(0.14, 0.3, 0.64)
const TURQUOISE := Color(0.2, 0.66, 0.62)
const OCHRE := Color(0.72, 0.3, 0.16)
const GOLD := Props.GOLD
const BLACK := Props.BLACK

const SPHINX_GLB := "res://assets/props/sphinx.glb"
const ANUBIS_GLB := "res://assets/props/anubis.glb"
const SARCOPHAGUS_GLB := "res://assets/props/sarcophagus.glb"
const SCARAB_GLB := "res://assets/props/scarab.glb"


static func _add(parent: Node3D, m: Mesh, color: Color, pos: Vector3, scale := Vector3.ONE, rot := Vector3.ZERO) -> MeshInstance3D:
	return Props._add(parent, m, color, pos, scale, rot)


## 墙上的火把：铁托架 + 一团发光的火苗；with_light 时带一盏暖光
static func torch(with_light := true) -> Node3D:
	var n := Node3D.new()
	_add(n, Art.box(Vector3(0.08, 0.3, 0.08)), BLACK, Vector3(0, 0, 0.06))
	_add(n, Art.cylinder(0.07, 0.04, 0.16), DARK_STONE, Vector3(0, 0.22, 0.12))
	var flame := MeshInstance3D.new()
	flame.mesh = Art.sphere(0.08)
	flame.material_override = Art.glow(Color(1.0, 0.6, 0.2), 6.0)
	flame.scale = Vector3(1, 1.7, 1)
	flame.position = Vector3(0, 0.38, 0.12)
	flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(flame)
	var tw := flame.create_tween().set_loops()
	tw.tween_property(flame, "scale", Vector3(0.85, 1.9, 0.85), 0.23).set_trans(Tween.TRANS_SINE)
	tw.tween_property(flame, "scale", Vector3(1.05, 1.55, 1.05), 0.31).set_trans(Tween.TRANS_SINE)
	if with_light:
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.62, 0.3)
		l.light_energy = 1.4
		l.omni_range = 5.0
		l.position = Vector3(0, 0.45, 0.35)
		n.add_child(l)
	return n


## 纸莎草柱：柱身 + 喇叭口柱头 + 彩色环带
static func column(height := 3.0, r := 0.32) -> Node3D:
	var n := Node3D.new()
	_add(n, Art.cylinder(r * 1.25, r * 1.35, 0.2), DARK_STONE, Vector3(0, 0.1, 0))
	_add(n, Art.cylinder(r * 0.9, r, height - 0.75), SANDSTONE, Vector3(0, 0.2 + (height - 0.75) / 2, 0))
	for k in 3:
		_add(n, Art.cylinder(r * 0.93, r * 0.93, 0.06), [LAPIS, GOLD, OCHRE][k], Vector3(0, height - 0.6 - k * 0.09, 0))
	_add(n, Art.cylinder(r * 1.5, r * 0.9, 0.45), SANDSTONE.lightened(0.05), Vector3(0, height - 0.3, 0))
	_add(n, Art.box(Vector3(r * 3.0, 0.1, r * 3.0)), DARK_STONE, Vector3(0, height - 0.05, 0))
	return n


static func obelisk(height := 4.0) -> Node3D:
	var n := Node3D.new()
	var w := height * 0.11
	_add(n, Art.box(Vector3(w * 1.6, 0.3, w * 1.6)), DARK_STONE, Vector3(0, 0.15, 0))
	_add(n, Art.cylinder(w * 0.55, w * 0.75, height - 0.6, 4), SANDSTONE, Vector3(0, 0.3 + (height - 0.6) / 2, 0), Vector3.ONE,
		Vector3(0, PI / 4, 0))
	_add(n, Art.cylinder(0.0, w * 0.55, 0.3, 4), GOLD, Vector3(0, height - 0.15, 0), Vector3.ONE, Vector3(0, PI / 4, 0))
	return n


static func palm(height := 3.2) -> Node3D:
	var n := Node3D.new()
	var trunk := Color(0.5, 0.36, 0.22)
	for k in 6:
		var y := k * height / 6.0
		_add(n, Art.cylinder(0.1, 0.13, height / 6.0 + 0.02), trunk.darkened(0.06 * (k % 2)), Vector3(0.03 * k, y + height / 12.0, 0))
	var top := Vector3(0.18, height, 0)
	for k in 7:
		var a := TAU * k / 7.0
		var leaf := _add(n, Art.box(Vector3(1.4, 0.03, 0.32)), Color(0.32, 0.55, 0.25).darkened(0.08 * (k % 2)),
			top + Vector3(cos(a) * 0.6, -0.15, sin(a) * 0.6))
		leaf.rotation = Vector3(0, -a, -0.35)
	return n


## 远处的金字塔：一层层缩小的石块，顶上一个金色塔尖
static func pyramid(base := 16.0, layers := 10) -> Node3D:
	var n := Node3D.new()
	var h := base * 0.62 / layers
	for k in layers:
		var s := base * (1.0 - float(k) / layers)
		_add(n, Art.box(Vector3(s, h, s)), SANDSTONE.lerp(SAND, 0.3 * (k % 2)), Vector3(0, h * (k + 0.5), 0))
	var cap_s := base / layers
	_add(n, Art.cylinder(0.0, cap_s * 0.7, h * 1.6, 4), GOLD, Vector3(0, h * (layers + 0.8), 0), Vector3.ONE, Vector3(0, PI / 4, 0))
	return n


## 墙上的蛇头射孔（飞镖从嘴里射出来），面朝 +Z
static func dart_launcher() -> Node3D:
	var n := Node3D.new()
	_add(n, Art.box(Vector3(0.36, 0.3, 0.08)), GOLD.darkened(0.2), Vector3(0, 0, 0.02))
	_add(n, Art.box(Vector3(0.24, 0.18, 0.14)), TURQUOISE.darkened(0.1), Vector3(0, 0, 0.08))
	_add(n, Art.sphere(0.07), BLACK, Vector3(0, -0.01, 0.15), Vector3(1, 0.6, 0.4))
	for s in [-1.0, 1.0]:
		_add(n, Art.sphere(0.025), Color(0.9, 0.2, 0.1), Vector3(s * 0.07, 0.06, 0.15))
	return n


## 飞镖：细杆、铜箭头、红羽毛；沿 +X 飞
static func dart() -> Node3D:
	var n := Node3D.new()
	_add(n, Art.cylinder(0.012, 0.012, 0.42), Color(0.45, 0.3, 0.16), Vector3.ZERO, Vector3.ONE, Vector3(0, 0, PI / 2))
	_add(n, Art.cylinder(0.0, 0.03, 0.08), Props.BRONZE.lightened(0.3), Vector3(0.24, 0, 0), Vector3.ONE, Vector3(0, 0, -PI / 2))
	_add(n, Art.box(Vector3(0.1, 0.06, 0.005)), OCHRE, Vector3(-0.18, 0, 0))
	_add(n, Art.box(Vector3(0.1, 0.005, 0.06)), OCHRE, Vector3(-0.18, 0, 0))
	return n


## 卡诺匹斯罐：罐身 + 动物头盖子
static func canopic_jar(lid := Color(0.85, 0.75, 0.55)) -> Node3D:
	var n := Node3D.new()
	_add(n, Art.cylinder(0.12, 0.09, 0.32), Color(0.92, 0.88, 0.78), Vector3(0, 0.16, 0))
	_add(n, Art.cylinder(0.125, 0.125, 0.04), LAPIS, Vector3(0, 0.22, 0))
	_add(n, Art.sphere(0.1), lid, Vector3(0, 0.38, 0), Vector3(1, 1.1, 1))
	return n


## 陶罐
static func pot(color := OCHRE) -> Node3D:
	var n := Node3D.new()
	_add(n, Art.sphere(0.2), color, Vector3(0, 0.2, 0), Vector3(1, 1.1, 1))
	_add(n, Art.cylinder(0.09, 0.12, 0.12), color.darkened(0.1), Vector3(0, 0.44, 0))
	return n


## 一叠金块
static func gold_pile() -> Node3D:
	var n := Node3D.new()
	for k in 6:
		_add(n, Art.box(Vector3(0.22, 0.08, 0.11)), GOLD, Vector3((k % 3 - 1) * 0.24, 0.04 + (k / 3) * 0.08, (k / 3) * 0.05))
	return n


## 压力板：一块嵌进地里的金边石板，中间刻一只眼
static func plate_top(size: float) -> Node3D:
	var n := Node3D.new()
	_add(n, Art.box(Vector3(size, 0.08, size)), GOLD.darkened(0.25), Vector3.ZERO)
	_add(n, Art.box(Vector3(size - 0.16, 0.09, size - 0.16)), DARK_STONE.lightened(0.15), Vector3.ZERO)
	n.add_child(_eye_decal(size * 0.5))
	return n


static func _eye_decal(s: float) -> Node3D:
	var n := Node3D.new()
	_add(n, Art.sphere(s * 0.3), GOLD, Vector3(0, 0.04, 0), Vector3(1.6, 0.05, 0.8))
	_add(n, Art.sphere(s * 0.14), BLACK, Vector3(0, 0.05, 0), Vector3(1, 0.05, 1))
	return n


# ---------- Lux3D 生成的大件（没有就用拼的顶上）----------

static func sphinx(length := 5.0) -> Node3D:
	var n := Props._glb(SPHINX_GLB, length * 0.55)
	if n:
		return n
	n = Node3D.new()
	var s := length / 5.0
	_add(n, Art.box(Vector3(5.0, 0.5, 2.0) * s), DARK_STONE, Vector3(0, 0.25, 0) * s)
	_add(n, Art.box(Vector3(3.6, 1.1, 1.5) * s), SANDSTONE, Vector3(-0.4, 1.05, 0) * s)
	for z in [-0.45, 0.45]:  # 前爪
		_add(n, Art.box(Vector3(1.6, 0.4, 0.45) * s), SANDSTONE, Vector3(1.8, 0.7, z) * s)
	_add(n, Art.box(Vector3(1.0, 1.0, 1.0) * s), SANDSTONE, Vector3(1.3, 2.0, 0) * s)
	# 法老头巾：蓝金条纹，两边垂下来
	_add(n, Art.box(Vector3(1.1, 0.5, 1.5) * s), LAPIS, Vector3(1.2, 2.35, 0) * s)
	for k in 3:
		_add(n, Art.box(Vector3(1.12, 0.06, 1.52) * s), GOLD, Vector3(1.2, 2.2 + k * 0.15, 0) * s)
	for z in [-0.6, 0.6]:
		_add(n, Art.box(Vector3(0.5, 1.0, 0.3) * s), LAPIS, Vector3(1.45, 1.75, z) * s)
	for z in [-0.18, 0.18]:
		_add(n, Art.sphere(0.08 * s), BLACK, Vector3(1.82, 2.1 * s, z * s))
	return n


static func anubis(height := 2.4) -> Node3D:
	var n := Props._glb(ANUBIS_GLB, height)
	if n:
		return n
	n = Node3D.new()
	var s := height / 2.4
	_add(n, Art.box(Vector3(0.7, 0.3, 0.6) * s), DARK_STONE, Vector3(0, 0.15, 0) * s)
	_add(n, Art.cylinder(0.2, 0.26, 1.2) as Mesh, BLACK, Vector3(0, 0.9, 0) * s, Vector3.ONE * s)
	_add(n, Art.cylinder(0.28, 0.28, 0.1), GOLD, Vector3(0, 1.45, 0) * s, Vector3.ONE * s)
	_add(n, Art.box(Vector3(0.26, 0.3, 0.3) * s), BLACK, Vector3(0, 1.7, 0) * s)
	_add(n, Art.box(Vector3(0.14, 0.12, 0.3) * s), BLACK, Vector3(0, 1.66, 0.25) * s)  # 长嘴
	for x in [-0.08, 0.08]:  # 竖起来的耳朵
		_add(n, Art.cylinder(0.0, 0.06, 0.3, 4), BLACK, Vector3(x, 2.0, -0.04) * s, Vector3.ONE * s)
		_add(n, Art.sphere(0.03), GOLD, Vector3(x * 1.1, 1.78, 0.14) * s)
	_add(n, Art.cylinder(0.025, 0.025, 2.0), GOLD, Vector3(0.36, 1.1, 0.1) * s, Vector3.ONE * s)  # 权杖
	return n


## 法老石棺：灵台用。沿 X 放，长 length
static func sarcophagus(length := 2.6) -> Node3D:
	var n := Props._glb(SARCOPHAGUS_GLB, length * 0.427)  # 模型长边沿 Z，放的时候转 90°
	if n:
		return n
	n = Node3D.new()
	var s := length / 2.6
	_add(n, Art.box(Vector3(2.6, 0.7, 1.2) * s), SANDSTONE.darkened(0.1), Vector3(0, 0.35, 0) * s)
	for k in 5:
		_add(n, Art.box(Vector3(0.06, 0.6, 1.22) * s), [LAPIS, GOLD][k % 2], Vector3((-1.0 + k * 0.5), 0.35, 0) * s)
	_add(n, Art.box(Vector3(2.7, 0.08, 1.3) * s), GOLD, Vector3(0, 0.72, 0) * s)
	n.rotation.y = PI / 2  # 和生成的模型一样，长边沿 Z
	var root := Node3D.new()
	root.add_child(n)
	return root


static func scarab(height := 1.0) -> Node3D:
	var n := Props._glb(SCARAB_GLB, height)
	if n:
		return n
	n = Node3D.new()
	var s := height
	_add(n, Art.sphere(0.35 * s), TURQUOISE, Vector3(0, 0.3, 0) * s, Vector3(0.8, 0.6, 1.0))
	_add(n, Art.sphere(0.15 * s), TURQUOISE.darkened(0.2), Vector3(0, 0.3, 0.34) * s, Vector3(1, 0.7, 0.8))
	_add(n, Art.cylinder(0.3 * s, 0.3 * s, 0.05 * s), GOLD, Vector3(0, 0.75, 0.25) * s, Vector3.ONE, Vector3(PI / 2, 0, 0))
	return n
