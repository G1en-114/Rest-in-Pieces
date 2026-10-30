class_name Props
## 中式殡仪馆的道具，全部用代码拼成低多边形。每个函数返回一个 Node3D：
## 原点在物体底部中心，正面朝本地 +Z（摆到墙边时让 +Z 朝屋里）。只有外观，没有碰撞。

const WHITE := Color(0.96, 0.95, 0.92)
const PAPER := Color(0.97, 0.96, 0.9)
const BLACK := Color(0.08, 0.08, 0.09)
const RED := Color(0.72, 0.1, 0.1)
const GOLD := Color(0.95, 0.74, 0.25)
const BRONZE := Color(0.5, 0.36, 0.18)
const LEAF := Color(0.2, 0.42, 0.2)
const MUM_WHITE := Color(0.98, 0.97, 0.9)
const MUM_YELLOW := Color(0.98, 0.8, 0.22)
const STONE := Color(0.72, 0.71, 0.68)
const WOOD := Color(0.3, 0.18, 0.1)

const LION_GLB := "res://assets/props/lion.glb"
const PAPER_KID_GLB := "res://assets/props/paper_kid.glb"
const PAPER_CAR_GLB := "res://assets/props/paper_car.glb"


static func _add(parent: Node3D, m: Mesh, color: Color, pos: Vector3, scale := Vector3.ONE, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := Art.mesh(m, color, pos)
	mi.scale = scale
	mi.rotation = rot
	parent.add_child(mi)
	return mi


## 人字形屋顶（三棱柱）。屋脊沿本地 Z，摆放时转 90° 就沿 X
static func _prism(size: Vector3) -> PrismMesh:
	var p := PrismMesh.new()
	p.size = Vector3(size.z, size.y, size.x)
	return p


## 一朵菊花：压扁的球
static func _mum(parent: Node3D, pos: Vector3, r: float, color: Color) -> void:
	_add(parent, Art.sphere(r), color, pos, Vector3(1, 0.7, 1))


## 一盆菊花（高约 0.6 米）
static func chrysanthemum_pot(yellow := false) -> Node3D:
	var n := Node3D.new()
	_add(n, Art.cylinder(0.17, 0.12, 0.26), Color(0.45, 0.16, 0.12), Vector3(0, 0.13, 0))
	_add(n, Art.cylinder(0.15, 0.15, 0.02), Color(0.2, 0.13, 0.08), Vector3(0, 0.26, 0))
	for i in 5:
		var a := TAU * i / 5.0
		_add(n, Art.sphere(0.11), LEAF, Vector3(cos(a) * 0.1, 0.34, sin(a) * 0.1), Vector3(1, 0.6, 1))
	var color := MUM_YELLOW if yellow else MUM_WHITE
	_mum(n, Vector3(0, 0.52, 0), 0.08, color)
	for i in 6:
		var a := TAU * i / 6.0 + 0.4
		_mum(n, Vector3(cos(a) * 0.12, 0.45 + (i % 2) * 0.04, sin(a) * 0.12), 0.065, color)
	return n


## 立式花圈：三脚架上一个菊花圈，中间写“奠”，两边垂着白色挽带（高约 1.7 米）
static func wreath_stand(ribbon_l := "沉痛悼念", ribbon_r := "一路走好") -> Node3D:
	var n := Node3D.new()
	for x in [-0.32, 0.32]:
		var leg := _add(n, Art.box(Vector3(0.04, 1.25, 0.04)), WOOD, Vector3(x, 0.6, 0))
		leg.rotation.z = -x * 0.25
	var back := _add(n, Art.box(Vector3(0.04, 1.2, 0.04)), WOOD, Vector3(0, 0.6, -0.25))
	back.rotation.x = 0.35
	var center := Vector3(0, 1.15, 0.03)
	var disk := _add(n, Art.cylinder(0.33, 0.33, 0.05, 16), LEAF, center)
	disk.rotation.x = PI / 2
	_add(n, Art.cylinder(0.17, 0.17, 0.06, 16), WHITE, center + Vector3(0, 0, 0.01), Vector3.ONE, Vector3(PI / 2, 0, 0))
	n.add_child(Art.text("奠", 96, BLACK, center + Vector3(0, -0.01, 0.05)))
	for i in 16:
		var a := TAU * i / 16.0
		_mum(n, center + Vector3(cos(a) * 0.36, sin(a) * 0.36, 0.04), 0.08, MUM_WHITE if i % 3 else MUM_YELLOW)
	for s in [-1.0, 1.0]:
		var rib := Vector3(s * 0.43, 0.55, 0.06)
		_add(n, Art.box(Vector3(0.11, 0.85, 0.01)), WHITE, rib + Vector3(0, 0.15, 0))
		var txt := ribbon_r if s > 0 else ribbon_l
		n.add_child(Art.text("\n".join(txt.split("")), 40, BLACK, rib + Vector3(0, 0.15, 0.01), 0.0035))
	return n


## 挽联：两条白布竖写黑字，上面一条横批。上联挂在看的人右手边（本地 -X），下联在左手边。
## width 是两条之间的距离（顶端高约 2.3 米，挂在墙上）
static func couplet(first: String, second: String, top := "", width := 2.0) -> Node3D:
	var n := Node3D.new()
	var h := 0.26 * maxi(first.length(), second.length()) + 0.2
	for s in [-1.0, 1.0]:
		var p := Vector3(s * width / 2, 1.9 - h / 2, 0)
		_add(n, Art.box(Vector3(0.3, h, 0.02)), WHITE, p)
		var txt := first if s < 0 else second
		n.add_child(Art.text("\n".join(txt.split("")), 64, BLACK, p + Vector3(0, 0, 0.012)))
	if top != "":
		var p := Vector3(0, 2.15, 0)
		_add(n, Art.box(Vector3(top.length() * 0.28 + 0.3, 0.32, 0.02)), WHITE, p)
		n.add_child(Art.text(top, 64, BLACK, p + Vector3(0, 0, 0.012)))
	return n


## 香炉：三足铜鼎，插着三炷香，冒着烟
static func incense_burner() -> Node3D:
	var n := Node3D.new()
	for i in 3:
		var a := TAU * i / 3.0
		_add(n, Art.cylinder(0.025, 0.035, 0.12), BRONZE, Vector3(cos(a) * 0.14, 0.06, sin(a) * 0.14))
	_add(n, Art.cylinder(0.2, 0.16, 0.22, 14), BRONZE, Vector3(0, 0.22, 0))
	_add(n, Art.cylinder(0.22, 0.22, 0.03, 14), BRONZE.lightened(0.15), Vector3(0, 0.34, 0))
	_add(n, Art.cylinder(0.18, 0.18, 0.01, 14), Color(0.55, 0.52, 0.48), Vector3(0, 0.33, 0))
	for x in [-0.06, 0.0, 0.06]:
		_add(n, Art.cylinder(0.008, 0.008, 0.35), RED, Vector3(x, 0.5, 0))
		var tip := MeshInstance3D.new()
		tip.mesh = Art.sphere(0.012)
		tip.material_override = Art.glow(Color(1.0, 0.45, 0.15), 4.0)
		tip.position = Vector3(x, 0.68, 0)
		n.add_child(tip)
	n.add_child(_smoke(Vector3(0, 0.7, 0)))
	return n


static func _smoke(pos: Vector3) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.position = pos
	p.amount = 24
	p.lifetime = 3.0
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3.UP
	pm.spread = 8.0
	pm.initial_velocity_min = 0.15
	pm.initial_velocity_max = 0.25
	pm.gravity = Vector3(0.02, 0.05, 0)
	pm.scale_min = 0.6
	pm.scale_max = 1.4
	var curve := CurveTexture.new()
	curve.curve = Curve.new()
	curve.curve.add_point(Vector2(0, 0.3))
	curve.curve.add_point(Vector2(1, 1.6))
	pm.scale_curve = curve
	var ramp := GradientTexture1D.new()
	ramp.gradient = Gradient.new()
	ramp.gradient.set_color(0, Color(0.85, 0.85, 0.85, 0.45))
	ramp.gradient.set_color(1, Color(0.9, 0.9, 0.9, 0.0))
	pm.color_ramp = ramp
	p.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(0.09, 0.09)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	quad.material = m
	p.draw_pass_1 = quad
	return p


## 仪仗牌：长杆上一块红牌，金字竖写（“肃静”“回避”）
static func sign_board(text: String) -> Node3D:
	var n := Node3D.new()
	_add(n, Art.cylinder(0.025, 0.025, 1.9), WOOD, Vector3(0, 0.95, 0))
	_add(n, Art.box(Vector3(0.36, 0.62, 0.03)), RED, Vector3(0, 1.75, 0.03))
	_add(n, Art.box(Vector3(0.4, 0.66, 0.02)), GOLD, Vector3(0, 1.75, 0.01))
	n.add_child(Art.text("\n".join(text.split("")), 88, GOLD, Vector3(0, 1.75, 0.05)))
	return n


## 黄色“小心地滑”立牌
static func wet_floor_sign() -> Node3D:
	var n := Node3D.new()
	for s in [-1.0, 1.0]:
		var board := _add(n, Art.box(Vector3(0.32, 0.55, 0.015)), Color(1.0, 0.82, 0.1), Vector3(0, 0.26, s * 0.09))
		board.rotation.x = s * 0.3
	var t := Art.text("小心\n地滑", 56, BLACK, Vector3(0, 0.3, 0.18))
	t.rotation.x = -0.3
	n.add_child(t)
	_add(n, Art.box(Vector3(0.12, 0.1, 0.01)), BLACK, Vector3(0, 0.12, 0.155), Vector3.ONE, Vector3(-0.3, 0, 0))
	return n


## 值班桌：桌子、保温杯、登记簿、红色塑料凳
static func duty_desk() -> Node3D:
	var n := Node3D.new()
	_add(n, Art.box(Vector3(1.1, 0.05, 0.55)), Color(0.55, 0.38, 0.22), Vector3(0, 0.74, 0))
	for x in [-0.5, 0.5]:
		for z in [-0.22, 0.22]:
			_add(n, Art.box(Vector3(0.05, 0.72, 0.05)), Color(0.4, 0.27, 0.15), Vector3(x, 0.36, z))
	_add(n, Art.cylinder(0.04, 0.04, 0.2), Color(0.75, 0.1, 0.12), Vector3(0.35, 0.87, 0))
	_add(n, Art.cylinder(0.035, 0.04, 0.03), Color(0.85, 0.85, 0.88), Vector3(0.35, 0.985, 0))
	_add(n, Art.box(Vector3(0.3, 0.02, 0.22)), Color(0.15, 0.3, 0.5), Vector3(-0.15, 0.775, 0), Vector3.ONE, Vector3(0, 0.2, 0))
	var label := Art.text("登记", 32, WHITE, Vector3(-0.15, 0.787, 0))
	label.rotation = Vector3(-PI / 2, 0.2, 0)
	n.add_child(label)
	var stool := Node3D.new()
	stool.position = Vector3(-0.1, 0, 0.6)
	_add(stool, Art.cylinder(0.17, 0.2, 0.04), Color(0.85, 0.12, 0.1), Vector3(0, 0.44, 0))
	_add(stool, Art.cylinder(0.14, 0.2, 0.42, 4), Color(0.8, 0.1, 0.08), Vector3(0, 0.21, 0), Vector3.ONE, Vector3(0, PI / 4, 0))
	n.add_child(stool)
	return n


## 白灯笼，写着“奠”，自带一点暖光
static func lantern(with_light := true) -> Node3D:
	var n := Node3D.new()
	_add(n, Art.cylinder(0.006, 0.006, 0.4), BLACK, Vector3(0, 0.2, 0))
	_add(n, Art.cylinder(0.1, 0.1, 0.05), BLACK, Vector3(0, -0.02, 0))
	var body := MeshInstance3D.new()
	body.mesh = Art.sphere(0.25)
	body.material_override = Art.glow(Color(1.0, 0.97, 0.88), 0.6)
	body.scale = Vector3(1, 1.25, 1)
	body.position = Vector3(0, -0.33, 0)
	n.add_child(body)
	_add(n, Art.cylinder(0.1, 0.1, 0.05), BLACK, Vector3(0, -0.64, 0))
	_add(n, Art.cylinder(0.01, 0.03, 0.18), RED, Vector3(0, -0.76, 0))
	n.add_child(Art.text("奠", 72, BLACK, Vector3(0, -0.33, 0.255)))
	if with_light:
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.8, 0.55)
		l.light_energy = 0.8
		l.omni_range = 3.0
		l.position = Vector3(0, -0.33, 0)
		n.add_child(l)
	return n


## 纸扎别墅：花花绿绿的纸房子
static func paper_house() -> Node3D:
	var n := Node3D.new()
	_add(n, Art.box(Vector3(0.8, 0.55, 0.6)), Color(0.98, 0.9, 0.6), Vector3(0, 0.3, 0))
	_add(n, _prism(Vector3(0.95, 0.36, 0.75)), RED, Vector3(0, 0.75, 0), Vector3.ONE, Vector3(0, PI / 2, 0))
	for x in [-0.22, 0.22]:
		_add(n, Art.box(Vector3(0.16, 0.16, 0.01)), Color(0.3, 0.6, 0.9), Vector3(x, 0.38, 0.305))
	_add(n, Art.box(Vector3(0.16, 0.26, 0.01)), Color(0.15, 0.6, 0.3), Vector3(0, 0.15, 0.305))
	var label := Art.text("豪宅", 40, RED, Vector3(0, 0.95, 0.15))
	label.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	n.add_child(label)
	return n


## 纸扎手机
static func paper_phone() -> Node3D:
	var n := Node3D.new()
	var body := _add(n, Art.box(Vector3(0.36, 0.72, 0.06)), BLACK, Vector3(0, 0.38, 0))
	body.rotation.x = -0.15
	var screen := MeshInstance3D.new()
	screen.mesh = Art.box(Vector3(0.31, 0.62, 0.01))
	screen.material_override = Art.glow(Color(0.35, 0.6, 0.95), 0.8)
	screen.position = Vector3(0, 0, 0.032)
	body.add_child(screen)
	body.add_child(Art.text("12:00\n\n冥界\n5G", 40, WHITE, Vector3(0, 0.05, 0.04)))
	_add(n, Art.box(Vector3(0.2, 0.04, 0.2)), PAPER, Vector3(0, 0.02, -0.05))
	return n


## 一堆金元宝
static func gold_ingots() -> Node3D:
	var n := Node3D.new()
	var spots := [Vector3(-0.12, 0.06, 0), Vector3(0.12, 0.06, 0.02), Vector3(0, 0.06, -0.14), Vector3(0, 0.17, -0.04)]
	for p in spots:
		_add(n, Art.sphere(0.11), GOLD, p, Vector3(1.3, 0.55, 0.8))
		_add(n, Art.sphere(0.05), GOLD.lightened(0.2), p + Vector3(0, 0.05, 0))
	return n


## 黑白遗像：黑框、白底、灰色剪影，顶上一朵黑纱花
static func portrait() -> Node3D:
	var n := Node3D.new()
	_add(n, Art.box(Vector3(0.95, 1.2, 0.06)), BLACK, Vector3(0, 0, 0))
	_add(n, Art.box(Vector3(0.78, 1.02, 0.01)), Color(0.9, 0.9, 0.88), Vector3(0, 0, 0.032))
	_add(n, Art.sphere(0.2), Color(0.4, 0.4, 0.42), Vector3(0, 0.12, 0.04), Vector3(0.85, 1.15, 0.2))
	_add(n, Art.sphere(0.3), Color(0.4, 0.4, 0.42), Vector3(0, -0.4, 0.04), Vector3(1.0, 0.55, 0.15))
	for s in [-1.0, 1.0]:
		_add(n, Art.sphere(0.09), BLACK, Vector3(s * 0.1, 0.62, 0.05), Vector3(1.2, 0.8, 0.6))
	_add(n, Art.sphere(0.06), BLACK, Vector3(0, 0.62, 0.07))
	return n


## 花山：灵台后面一层层的菊花台阶
static func flower_wall(width: float, rows := 4) -> Node3D:
	var n := Node3D.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for r in rows:
		var y := 0.25 + r * 0.32
		var z := -r * 0.28
		_add(n, Art.box(Vector3(width, 0.3, 0.3)), Color(0.18, 0.32, 0.18), Vector3(0, y - 0.1, z))
		var count := int(width / 0.17)
		for i in count:
			var x := -width / 2 + 0.085 + i * 0.17
			var yellow := rng.randf() < (0.35 if r == rows - 1 else 0.12)
			_mum(n, Vector3(x, y + 0.08, z + 0.05), 0.085, MUM_YELLOW if yellow else MUM_WHITE)
	return n


## 松树：一根树干上叠三层圆锥
static func pine(height := 2.2) -> Node3D:
	var n := Node3D.new()
	_add(n, Art.cylinder(0.06, 0.09, height * 0.35), Color(0.35, 0.22, 0.14), Vector3(0, height * 0.17, 0))
	for i in 3:
		var r := 0.55 - i * 0.14
		var h := height * 0.38
		_add(n, Art.cylinder(0.0, r, h, 7), Color(0.16, 0.36, 0.25).lightened(i * 0.04), Vector3(0, height * (0.38 + i * 0.2), 0))
	return n


## 殡仪推车：不锈钢架子、白床单，上面还盖着一位（长沿本地 X）
static func gurney() -> Node3D:
	var n := Node3D.new()
	var steel := Color(0.72, 0.74, 0.78)
	_add(n, Art.box(Vector3(0.9, 0.05, 0.95)), steel, Vector3(0, 0.62, 0))
	for x in [-0.4, 0.4]:
		for z in [-0.42, 0.42]:
			_add(n, Art.cylinder(0.02, 0.02, 0.56), steel, Vector3(x, 0.33, z))
			_add(n, Art.cylinder(0.06, 0.06, 0.04), BLACK, Vector3(x, 0.06, z), Vector3.ONE, Vector3(PI / 2, 0, 0))
	_add(n, Art.box(Vector3(0.86, 0.08, 0.92)), WHITE, Vector3(0, 0.69, 0))
	_add(n, Art.sphere(0.3), WHITE, Vector3(0, 0.82, -0.05), Vector3(1.0, 0.35, 1.4))
	_add(n, Art.sphere(0.13), WHITE, Vector3(0, 0.82, 0.42), Vector3(1, 0.7, 1))
	for z in [-0.48, 0.48]:  # 推手
		_add(n, Art.box(Vector3(0.7, 0.03, 0.03)), steel, Vector3(0, 0.95, z))
		for x in [-0.33, 0.33]:
			_add(n, Art.cylinder(0.015, 0.015, 0.3), steel, Vector3(x, 0.8, z))
	return n


## 拖把桶和拖把
static func mop_bucket() -> Node3D:
	var n := Node3D.new()
	_add(n, Art.cylinder(0.17, 0.14, 0.3, 12), Color(0.2, 0.45, 0.85), Vector3(0, 0.15, 0))
	_add(n, Art.cylinder(0.15, 0.15, 0.01, 12), Color(0.5, 0.6, 0.62), Vector3(0, 0.28, 0))
	_add(n, Art.cylinder(0.015, 0.015, 1.3), Color(0.85, 0.75, 0.55), Vector3(0.08, 0.7, 0), Vector3.ONE, Vector3(0, 0, -0.2))
	_add(n, Art.sphere(0.1), Color(0.92, 0.92, 0.88), Vector3(0.1, 0.22, 0), Vector3(1, 0.8, 1))
	return n


## 跪垫
static func kneel_cushion() -> Node3D:
	var n := Node3D.new()
	_add(n, Art.cylinder(0.24, 0.26, 0.12, 16), Color(0.85, 0.6, 0.15), Vector3(0, 0.06, 0))
	return n


## 低矮的石栏杆：每米一根望柱，中间一条扶手。沿本地 X 方向，从 0 到 length
static func railing(length: float) -> Node3D:
	var n := Node3D.new()
	var posts := maxi(int(length / 1.0), 1)
	for i in posts + 1:
		var x := length * i / posts
		_add(n, Art.box(Vector3(0.14, 0.62, 0.14)), STONE, Vector3(x, 0.31, 0))
		_add(n, Art.sphere(0.08), STONE.lightened(0.1), Vector3(x, 0.66, 0))
	_add(n, Art.box(Vector3(length, 0.07, 0.09)), STONE.lightened(0.05), Vector3(length / 2, 0.5, 0))
	_add(n, Art.box(Vector3(length, 0.18, 0.05)), STONE.darkened(0.08), Vector3(length / 2, 0.15, 0))
	return n


## 牌坊：两根红柱、一道横梁、一块匾
static func paifang(text: String, width := 3.6, height := 2.8) -> Node3D:
	var n := Node3D.new()
	for s in [-1.0, 1.0]:
		_add(n, Art.box(Vector3(0.26, 0.3, 0.26)), STONE, Vector3(s * width / 2, 0.15, 0))
		_add(n, Art.cylinder(0.1, 0.1, height), RED, Vector3(s * width / 2, height / 2, 0))
	_add(n, Art.box(Vector3(width + 0.6, 0.16, 0.3)), BLACK, Vector3(0, height + 0.08, 0))
	_add(n, _prism(Vector3(width + 1.0, 0.4, 0.6)), Color(0.2, 0.22, 0.25), Vector3(0, height + 0.36, 0), Vector3.ONE, Vector3(0, PI / 2, 0))
	_add(n, Art.box(Vector3(1.3, 0.42, 0.05)), BLACK, Vector3(0, height - 0.3, 0.12))
	n.add_child(Art.text(text, 72, GOLD, Vector3(0, height - 0.3, 0.15)))
	return n


# ---------- Lux3D 生成的道具（没有就用代码拼的顶上）----------

static func stone_lion() -> Node3D:
	var n := _glb(LION_GLB, 1.0)
	if n:
		return _on_plinth(n, 0.25)
	n = Node3D.new()
	_add(n, Art.sphere(0.3), STONE, Vector3(0, 0.3, 0), Vector3(1, 1.1, 0.9))
	_add(n, Art.sphere(0.24), STONE.lightened(0.05), Vector3(0, 0.72, 0.08))
	for s in [-1.0, 1.0]:
		_add(n, Art.sphere(0.05), BLACK, Vector3(s * 0.09, 0.78, 0.29))
	return _on_plinth(n, 0.25)


static func paper_kid() -> Node3D:
	var n := _glb(PAPER_KID_GLB, 1.0)
	if n:
		return n
	n = Node3D.new()
	_add(n, Art.cylinder(0.12, 0.2, 0.55), Color(0.2, 0.65, 0.35), Vector3(0, 0.28, 0))
	_add(n, Art.sphere(0.16), WHITE, Vector3(0, 0.72, 0))
	for s in [-1.0, 1.0]:
		_add(n, Art.sphere(0.04), Color(0.95, 0.4, 0.45), Vector3(s * 0.08, 0.68, 0.13))
	return n


static func paper_car() -> Node3D:
	var n := _glb(PAPER_CAR_GLB, 0.7)
	if n:
		return n
	n = Node3D.new()
	_add(n, Art.box(Vector3(1.2, 0.3, 0.55)), BLACK, Vector3(0, 0.28, 0))
	_add(n, Art.box(Vector3(0.6, 0.22, 0.5)), BLACK, Vector3(-0.05, 0.54, 0))
	for x in [-0.4, 0.4]:
		for z in [-0.28, 0.28]:
			_add(n, Art.cylinder(0.12, 0.12, 0.06), PAPER, Vector3(x, 0.12, z), Vector3.ONE, Vector3(PI / 2, 0, 0))
	n.add_child(Art.text("福", 64, RED, Vector3(0, 0.3, 0.28)))
	return n


static func _on_plinth(n: Node3D, h: float) -> Node3D:
	var root := Node3D.new()
	_add(root, Art.box(Vector3(0.7, h, 0.7)), STONE.darkened(0.1), Vector3(0, h / 2, 0))
	n.position.y = h
	root.add_child(n)
	return root


## 读入 Lux3D 生成的 GLB，缩放到给定高度、底部落地、居中，材质压成哑光
static func _glb(path: String, height: float) -> Node3D:
	if not ResourceLoader.exists(path):
		return null
	var scene: Node3D = (load(path) as PackedScene).instantiate()
	var aabb := AABB()
	var first := true
	for mi in scene.find_children("*", "MeshInstance3D", true, false):
		var box: AABB = mi.get_aabb()
		var xf: Transform3D = _xf_to(scene, mi)
		for i in 8:
			var p: Vector3 = xf * box.get_endpoint(i)
			if first:
				aabb = AABB(p, Vector3.ZERO)
				first = false
			else:
				aabb = aabb.expand(p)
		for i in mi.mesh.get_surface_count():
			var src: Material = mi.mesh.surface_get_material(i)
			if src is BaseMaterial3D:
				var m: BaseMaterial3D = src.duplicate()
				m.roughness = 1.0
				m.metallic = 0.0
				m.metallic_specular = 0.2
				mi.set_surface_override_material(i, m)
	if first or aabb.size.y <= 0.0:
		return scene
	var k := height / aabb.size.y
	var root := Node3D.new()
	scene.scale = Vector3.ONE * k
	var c := aabb.get_center()
	scene.position = Vector3(-c.x * k, -aabb.position.y * k, -c.z * k)
	root.add_child(scene)
	return root


static func _xf_to(root: Node3D, node: Node3D) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var n: Node = node
	while n != root and n is Node3D:
		xf = (n as Node3D).transform * xf
		n = n.get_parent()
	return xf
