class_name Art
## 共用的美术小工具：哑光纯色材质、快速建网格。整体走 How to Fish 那种平涂低多边形风格。

const SKIN := Color(0.93, 0.68, 0.53)
const SUIT := Color(0.07, 0.07, 0.08)
const SHIRT := Color(0.95, 0.95, 0.93)
const FLOOR_SHADER := preload("res://shaders/floor.gdshader")
const WALL_SHADER := preload("res://shaders/wall.gdshader")
const SANDSTONE_SHADER := preload("res://shaders/sandstone.gdshader")

static var _mats := {}
static var _unit_box: BoxMesh
static var _font: SystemFont


## 同一种颜色共用一个材质（道具成百上千，各建一个太浪费）。拿到的材质不要改。
static func mat(color: Color) -> StandardMaterial3D:
	if _mats.has(color):
		return _mats[color]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 1.0
	m.metallic_specular = 0.1
	_mats[color] = m
	return m


## 会发光的纯色（蜡烛火苗、香头、灯笼）
static func glow(color: Color, energy := 2.0) -> StandardMaterial3D:
	var key := [color, energy]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	_mats[key] = m
	return m


static func font() -> SystemFont:
	if _font == null:
		_font = SystemFont.new()
		_font.font_names = PackedStringArray(["Microsoft YaHei", "SimHei", "Noto Sans CJK SC"])
	return _font


## 磨石地面材质，params 里写要改的 uniform（base_color、tile……）
static func floor_mat(params: Dictionary) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = FLOOR_SHADER
	for k in params:
		m.set_shader_parameter(k, params[k])
	return m


static func wall_mat(params := {}) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = WALL_SHADER
	for k in params:
		m.set_shader_parameter(k, params[k])
	return m


## 用单位立方体缩放出来的方块：地面、墙的着色器靠缩放算出真实尺寸
static func block(size: Vector3, pos: Vector3, material: Material) -> MeshInstance3D:
	if _unit_box == null:
		_unit_box = BoxMesh.new()
	var mi := MeshInstance3D.new()
	mi.mesh = _unit_box
	mi.material_override = material
	mi.position = pos
	mi.scale = size
	return mi


static func mesh(m: Mesh, color: Color, pos := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mat(color)
	mi.position = pos
	return mi


static func sphere(r: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 12
	s.rings = 6
	return s


static func capsule(r: float, h: float) -> CapsuleMesh:
	var c := CapsuleMesh.new()
	c.radius = r
	c.height = h
	c.radial_segments = 12
	c.rings = 4
	return c


static func cylinder(r_top: float, r_bottom: float, h: float, segments := 12) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = r_top
	c.bottom_radius = r_bottom
	c.height = h
	c.radial_segments = segments
	c.rings = 1
	return c


## 贴在物体上的文字（挽联、牌匾）。不朝向镜头，正面朝本地 +Z
static func text(s: String, size: int, color: Color, pos := Vector3.ZERO, pixel := 0.004) -> Label3D:
	var l := Label3D.new()
	l.text = s
	l.font = font()
	l.font_size = size
	l.pixel_size = pixel
	l.modulate = color
	l.outline_size = 0
	l.position = pos
	l.double_sided = false
	return l


static func box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b


## 一对外凸的大眼珠（凸眼是这套角色的灵魂）。forward 是脸朝的方向，up 是头顶方向。
static func googly_eyes(parent: Node3D, center: Vector3, forward: Vector3, up: Vector3, size := 1.0) -> void:
	var side := forward.cross(up).normalized()
	for s in [-1.0, 1.0]:
		var base: Vector3 = center + side * s * 0.11 * size + up * 0.06 * size
		parent.add_child(mesh(sphere(0.075 * size), Color.WHITE, base))
		parent.add_child(mesh(sphere(0.034 * size), Color.BLACK, base + forward * 0.062 * size + up * 0.01 * size))


## 埃及砂岩墙材质（带象形文字饰带），params 里写要改的 uniform
static func sandstone_mat(params := {}) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SANDSTONE_SHADER
	for k in params:
		m.set_shader_parameter(k, params[k])
	return m
