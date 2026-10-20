class_name Art
## 共用的美术小工具：哑光纯色材质、快速建网格。整体走 How to Fish 那种平涂低多边形风格。

const SKIN := Color(0.93, 0.68, 0.53)
const SUIT := Color(0.07, 0.07, 0.08)
const SHIRT := Color(0.95, 0.95, 0.93)


static func mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 1.0
	m.metallic_specular = 0.1
	return m


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
