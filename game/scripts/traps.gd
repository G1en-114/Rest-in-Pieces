class_name Traps
## 各种机关（基类和约定见 trap.gd）。关卡里用 _trap(Traps.Spikes.new(...)) 放进场景。
## 会伤人的机关都是把人撞飞（Bearer.knock），不直接扣分；人飞了棺材掉了，才按掉落扣。

const STEEL := Color(0.72, 0.72, 0.76)


## 地刺：藏在地里，触发区里有人就（过 delay 秒）弹出来，把站在上面的人顶飞。
## 也可以 periodic() 成按周期自己弹，弹之前会先冒一点尖（提示）
class Spikes extends Trap:
	var center: Vector3
	var half: Vector2
	var trigger_c: Vector3
	var trigger_half: Vector3
	var delay := 0.0
	var up := 1.2
	var period := 0.0
	var phase := 0.0
	var text := "地刺！"
	var _rack := Node3D.new()

	func _init(c: Vector3, size: Vector2, color := STEEL) -> void:
		center = c
		half = size / 2
		trigger_c = c + Vector3(0, 1, 0)
		trigger_half = Vector3(half.x, 1.0, half.y)
		var nx := maxi(1, int(size.x / 0.35))
		var nz := maxi(1, int(size.y / 0.35))
		for i in nx:
			for j in nz:
				var p := Vector3(-half.x + (i + 0.5) * size.x / nx, 0.28, -half.y + (j + 0.5) * size.y / nz)
				_rack.add_child(Art.mesh(Art.cylinder(0.0, 0.09, 0.56, 6), color, p))
		_rack.position = c + Vector3(0, -0.62, 0)
		add_child(_rack)
		rearm = delay + up + 1.5

	## 触发区：c ± h（默认就是地刺本身那块）
	func triggered_by(c: Vector3, h: Vector3, wait := 0.0) -> Spikes:
		trigger_c = c
		trigger_half = h
		delay = wait
		rearm = delay + up + 1.5
		return self

	func periodic(p: float, ph: float, up_time := 1.0) -> Spikes:
		period = p
		phase = ph
		up = up_time
		return self

	## 伸出来多少：0 = 藏着，1 = 全伸出
	func _height(t: float) -> float:
		var s: float
		if period > 0.0:
			s = fposmod(t / period + phase, 1.0) * period
			if s > period - 0.5:
				return 0.25  # 提示：先冒个尖
		else:
			if t0 < 0.0:
				return 0.0
			s = since(t) - delay
			if s < 0.0:
				return 0.0
		if s < up:
			return clampf(s / 0.08, 0.0, 1.0)
		if s < up + 0.4:
			return 1.0 - (s - up) / 0.4
		return 0.0

	func sim(t: float) -> void:
		_rack.position.y = center.y - 0.62 + 0.62 * _height(t)

	func host(g: Node, t: float) -> void:
		_rearm(t)
		if period <= 0.0 and t0 < 0.0:
			for b in g.bearers:
				if _touches_box(b, trigger_c, trigger_half, 0.0):
					fire(t)
		if _height(t) > 0.6:
			for b in g.bearers:
				var p: Vector3 = b.global_position
				if absf(p.x - center.x) < half.x + 0.2 and absf(p.z - center.z) < half.y + 0.2 \
						and p.y - 0.87 < center.y + 0.6 and p.y - 0.87 > center.y - 0.4:
					_hit(b, Vector3(randf_range(-2, 2), 9.0, randf_range(-2, 2)), t, text)

	func safe(t: float, dur: float, _arg: String) -> bool:
		return _always(t, dur, func(x: float) -> bool: return _height(x) < 0.3)


## 天降：头顶挂着的东西，有人走到下面就砸下来，在地上躺一会儿再升回去
class Dropper extends Trap:
	var obj: Node3D
	var top: Vector3
	var ground := 0.0
	var radius := 0.8
	var lie := 2.5
	var trigger_c: Vector3
	var trigger_half: Vector3
	var text := "头顶！"

	## o：掉下来的东西（原点在它底下）；top_pos：挂着的位置；ground_y：落到哪
	func _init(o: Node3D, top_pos: Vector3, ground_y: float, r := 0.8) -> void:
		obj = o
		top = top_pos
		ground = ground_y
		radius = r
		add_child(o)
		o.position = top
		trigger_c = Vector3(top.x, ground + 1.0, top.z)
		trigger_half = Vector3(r + 0.4, 1.5, r + 0.4)
		rearm = _fall_time() + lie + 1.5

	## 触发区挪到别处（比如提前一步：人还没走到正下方就开始掉）
	func triggered_by(c: Vector3, h: Vector3) -> Dropper:
		trigger_c = c
		trigger_half = h
		return self

	func _fall_time() -> float:
		return sqrt(2.0 * (top.y - ground) / 16.0)

	func _y(t: float) -> float:
		var s := since(t)
		var tf := _fall_time()
		if s < 0.0:
			return top.y
		if s < tf:
			return top.y - 8.0 * s * s
		if s < tf + lie:
			return ground
		if s < tf + lie + 1.2:
			return lerpf(ground, top.y, (s - tf - lie) / 1.2)
		return top.y

	func sim(t: float) -> void:
		obj.position.y = _y(t)

	func host(g: Node, t: float) -> void:
		_rearm(t)
		if t0 < 0.0:
			for b in g.bearers:
				if _touches_box(b, trigger_c, trigger_half, 0.0):
					fire(t)
					break
			return
		var s := since(t)
		if s < _fall_time() + 0.05:
			var y := _y(t)
			for b in g.bearers:
				var d: Vector3 = b.global_position - Vector3(top.x, 0, top.z)
				d.y = 0
				if d.length() < radius + 0.3 and b.global_position.y + 0.9 > y - 0.2 and b.global_position.y < y + 0.5:
					var away := d.normalized() if d.length() > 0.05 else Vector3.RIGHT
					_hit(b, away * 5.0 + Vector3.UP * 3.0, t, text, 1.8)


## 假地板：看着是地，有人站上去一小会儿就塌，过几秒再长回来
class FakeFloor extends Trap:
	var center: Vector3
	var half: Vector2
	var delay := 0.35
	var down := 4.0
	var _cs: CollisionShape3D
	var _mesh: MeshInstance3D
	var _base_y := 0.0

	func _init(a: Vector3, b: Vector3, material: Material, thick := 0.5) -> void:
		center = Vector3((a.x + b.x) / 2, a.y, (a.z + b.z) / 2)
		half = Vector2(absf(b.x - a.x), absf(b.z - a.z)) / 2
		var body := StaticBody3D.new()
		_cs = CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(half.x * 2, 0.5, half.y * 2)
		_cs.shape = box
		body.position = center + Vector3(0, -0.25, 0)
		body.add_child(_cs)
		add_child(body)
		_base_y = a.y - thick / 2
		_mesh = Art.block(Vector3(half.x * 2, thick, half.y * 2), Vector3(center.x, _base_y, center.z), material)
		add_child(_mesh)
		rearm = delay + down + 0.3

	func sim(t: float) -> void:
		var s := since(t)
		var gone := s >= delay and s < delay + down
		if _cs.disabled != gone:
			_cs.disabled = gone
		if s < 0.0 or s >= delay + down:
			_mesh.position = Vector3(center.x, _base_y, center.z)
			_mesh.visible = true
		elif s < delay:
			_mesh.position = Vector3(center.x + 0.03 * sin(t * 70.0), _base_y, center.z)  # 抖一下
		else:
			var fall := s - delay
			_mesh.position = Vector3(center.x, _base_y - 6.0 * fall * fall, center.z)
			_mesh.visible = fall < 1.2

	func host(g: Node, t: float) -> void:
		_rearm(t)
		if t0 < 0.0:
			for b in g.bearers:
				if _standing_on(b, center, half, center.y):
					fire(t)


## 弹簧板：有人踩上去，就把他连同抓在一起的（棺材、队友）一起弹飞。用来抄近路
class Spring extends Trap:
	var center: Vector3
	var half: Vector2
	var launch: Vector3
	var text := "嘣——！"
	var _pad: MeshInstance3D

	func _init(c: Vector3, size: Vector2, velocity: Vector3, color := Color(0.95, 0.35, 0.3)) -> void:
		center = c
		half = size / 2
		launch = velocity
		add_child(Art.mesh(Art.box(Vector3(size.x, 0.06, size.y)), Color(0.25, 0.25, 0.28), c + Vector3(0, 0.03, 0)))
		for k in 4:
			var sx := (-1.0 if k % 2 == 0 else 1.0) * half.x * 0.6
			var sz := (-1.0 if k < 2 else 1.0) * half.y * 0.6
			add_child(Art.mesh(Art.cylinder(0.07, 0.07, 0.1, 8), STEEL, c + Vector3(sx, 0.08, sz)))
		_pad = Art.mesh(Art.box(Vector3(size.x - 0.1, 0.05, size.y - 0.1)), color, c + Vector3(0, 0.13, 0))
		add_child(_pad)
		rearm = 0.8

	func sim(t: float) -> void:
		var s := since(t)
		var pop := sin(clampf(s / 0.4, 0.0, 1.0) * PI) * 0.25 if s >= 0.0 else 0.0
		_pad.position.y = center.y + 0.13 + pop

	func host(g: Node, t: float) -> void:
		_rearm(t)
		if t0 >= 0.0:
			return
		for b in g.bearers:
			if b.stun <= 0.0 and b.linear_velocity.y < 1.0 and _standing_on(b, center, half, center.y):
				fire(t)
				for group in g.move_groups():
					if b in group:
						for body in group:
							body.linear_velocity = launch
				level.notice.emit(text)
				return


## 推墙：墙里周期性冲出来的石块，把挡在前面的人推飞。冲出来之前会先往回缩一下（提示）
class Piston extends Trap:
	var base: Vector3
	var size: Vector3
	var dir: Vector3
	var travel: float
	var period: float
	var phase: float
	var out := 0.18
	var hold := 0.7
	var back := 0.9
	var text := "被推飞了！"
	var _body := AnimatableBody3D.new()

	## base：缩回去时石块的中心；dir：冲出去的方向；travel：冲出去多远
	func _init(base_c: Vector3, sz: Vector3, d: Vector3, trav: float, p: float, ph: float, material: Material) -> void:
		base = base_c
		size = sz
		dir = d.normalized()
		travel = trav
		period = p
		phase = ph
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = sz
		cs.shape = box
		_body.add_child(cs)
		_body.add_child(Art.block(sz, Vector3.ZERO, material))
		_body.position = base
		add_child(_body)

	func _e(t: float) -> float:
		var ph := fposmod(t / period + phase, 1.0) * period
		if ph < out:
			return ph / out
		if ph < out + hold:
			return 1.0
		if ph < out + hold + back:
			return 1.0 - (ph - out - hold) / back
		if ph > period - 0.45:
			return -0.08  # 提示：先往回缩
		return 0.0

	func sim(t: float) -> void:
		_body.position = base + dir * travel * _e(t)

	func host(g: Node, t: float) -> void:
		var ph := fposmod(t / period + phase, 1.0) * period
		if ph > out + 0.1:
			return
		for b in g.bearers:
			if _touches_box(b, _body.position, size / 2, 0.35):
				_hit(b, dir * 9.0 + Vector3.UP * 3.5, t, text)

	func safe(t: float, dur: float, _arg: String) -> bool:
		return _always(t, dur, func(x: float) -> bool: return _e(x) < 0.05)


## 摆锤：吊在 pivot 下面、沿 swing 方向来回荡的锤子 / 香炉 / 刀
class Pendulum extends Trap:
	var pivot: Vector3
	var length: float
	var swing: Vector3
	var amp: float
	var period: float
	var phase: float
	var radius: float
	var text := "被摆锤抡飞了！"
	var _arm := Node3D.new()

	func _init(pv: Vector3, rod_len: float, sw: Vector3, a: float, p: float, ph: float, head: Node3D, r: float,
			rod_color := Color(0.3, 0.25, 0.2)) -> void:
		pivot = pv
		length = rod_len
		swing = sw.normalized()
		amp = a
		period = p
		phase = ph
		radius = r
		_arm.position = pivot
		_arm.add_child(Art.mesh(Art.box(Vector3(0.06, length, 0.06)), rod_color, Vector3(0, -length / 2, 0)))
		head.position = Vector3(0, -length, 0)
		_arm.add_child(head)
		add_child(_arm)

	func _theta(t: float) -> float:
		return amp * sin(TAU * (t / period + phase))

	func head_pos(t: float) -> Vector3:
		var th := _theta(t)
		return pivot + (Vector3.DOWN * cos(th) + swing * sin(th)) * length

	func sim(t: float) -> void:
		_arm.basis = Basis(Vector3.UP.cross(swing).normalized(), -_theta(t))

	func host(g: Node, t: float) -> void:
		var hp := head_pos(t)
		var omega := amp * TAU / period * cos(TAU * (t / period + phase))
		for b in g.bearers:
			var p: Vector3 = b.global_position
			var q := Vector3(p.x, clampf(hp.y, p.y - 0.6, p.y + 0.6), p.z)
			if q.distance_to(hp) < radius + 0.28:
				var speed := maxf(absf(omega) * length * 1.2, 6.0)
				_hit(b, swing * signf(omega if omega != 0.0 else 1.0) * speed + Vector3.UP * 4.0, t, text)

	## arg：锤子离最低点至少多少弧度才算安全（默认振幅的一半）
	func safe(t: float, dur: float, arg: String) -> bool:
		var danger := arg.to_float() if arg != "" else amp * 0.5
		return _always(t, dur, func(x: float) -> bool: return absf(_theta(x)) > danger)


## 压板：天花板上的大石块周期性砸下来，压到谁就把谁挤飞
class Crusher extends Trap:
	var center: Vector3
	var size: Vector3
	var lift: float
	var period: float
	var phase: float
	var drop := 0.22
	var stay := 0.9
	var rise := 1.6
	var text := "被压板拍飞了！"
	var _body := AnimatableBody3D.new()

	## c：正下方的地面点；sz：石块大小；raised：抬起来时底面离地多高
	func _init(c: Vector3, sz: Vector3, raised: float, p: float, ph: float, material: Material) -> void:
		center = c
		size = sz
		lift = raised
		period = p
		phase = ph
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = sz
		cs.shape = box
		_body.add_child(cs)
		_body.add_child(Art.block(sz, Vector3.ZERO, material))
		add_child(_body)

	## 底面离地多高
	func _h(t: float) -> float:
		var ph := fposmod(t / period + phase, 1.0) * period
		if ph < drop:
			var u := ph / drop
			return lerpf(lift, 0.0, u * u)
		if ph < drop + stay:
			return 0.0
		if ph < drop + stay + rise:
			return lerpf(0.0, lift, (ph - drop - stay) / rise)
		if ph > period - 0.4:
			return lift - 0.08 * absf(sin(t * 40.0))  # 提示：抖一下
		return lift

	func sim(t: float) -> void:
		_body.position = center + Vector3(0, _h(t) + size.y / 2, 0)

	func host(g: Node, t: float) -> void:
		var ph := fposmod(t / period + phase, 1.0) * period
		if ph > drop + 0.1 or _h(t) > 1.9:
			return
		for b in g.bearers:
			var d: Vector3 = b.global_position - center
			if absf(d.x) < size.x / 2 + 0.3 and absf(d.z) < size.z / 2 + 0.3:
				var out := Vector3(d.x, 0, d.z)
				out = out.normalized() if out.length() > 0.05 else Vector3.RIGHT
				_hit(b, out * 7.0 + Vector3.UP * 3.0, t, text, 1.6)

	func safe(t: float, dur: float, _arg: String) -> bool:
		return _always(t, dur, func(x: float) -> bool: return _h(x) > 2.0)


## 传送带：站上去就被带着走（velocity 是带子的速度，沿 X 或 Z）
class Conveyor extends Trap:
	var center: Vector3
	var half: Vector2
	var velocity: Vector3
	var _stripes: Array[MeshInstance3D] = []
	var _len := 0.0

	func _init(a: Vector3, b: Vector3, v: Vector3, color := Color(0.25, 0.22, 0.22), stripe := Color(0.9, 0.75, 0.3)) -> void:
		center = Vector3((a.x + b.x) / 2, a.y, (a.z + b.z) / 2)
		half = Vector2(absf(b.x - a.x), absf(b.z - a.z)) / 2
		velocity = v
		add_child(Art.mesh(Art.box(Vector3(half.x * 2, 0.04, half.y * 2)), color, center + Vector3(0, 0.02, 0)))
		var along_x := absf(v.x) > absf(v.z)
		_len = half.x * 2 if along_x else half.y * 2
		var wid := half.y * 2 if along_x else half.x * 2
		for i in int(_len / 0.8):
			var m := Art.mesh(Art.box(Vector3(0.12, 0.02, wid - 0.1) if along_x else Vector3(wid - 0.1, 0.02, 0.12)), stripe)
			add_child(m)
			_stripes.append(m)

	func sim(t: float) -> void:
		var dir := velocity.normalized()
		for i in _stripes.size():
			var s := fposmod(t * velocity.length() + i * 0.8, _len) - _len / 2
			_stripes[i].position = center + dir * s + Vector3(0, 0.045, 0)

	func host(g: Node, _t: float) -> void:
		for b in g.bearers:
			if _standing_on(b, center, half, center.y):
				b.ground_velocity += velocity


## 移动平台：在 a、b 两点之间来回开（a、b 是平台顶面中心），两头各停 pause 秒。站在上面的人跟着走
class Mover extends Trap:
	var a: Vector3
	var b: Vector3
	var size: Vector3
	var move: float
	var pause: float
	var phase := 0.0
	var _body := AnimatableBody3D.new()

	func _init(pa: Vector3, pb: Vector3, sz: Vector3, move_time: float, pause_time: float, material: Material) -> void:
		a = pa
		b = pb
		size = sz
		move = move_time
		pause = pause_time
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = sz
		cs.shape = box
		_body.add_child(cs)
		_body.add_child(Art.block(sz, Vector3.ZERO, material))
		add_child(_body)

	func _ph(t: float) -> float:
		return fposmod(t + phase * 2.0 * (move + pause), 2.0 * (move + pause))

	func top(t: float) -> Vector3:
		var ph := _ph(t)
		if ph < pause:
			return a
		if ph < pause + move:
			return a.lerp(b, smoothstep(0.0, 1.0, (ph - pause) / move))
		if ph < 2.0 * pause + move:
			return b
		return b.lerp(a, smoothstep(0.0, 1.0, (ph - 2.0 * pause - move) / move))

	func sim(t: float) -> void:
		_body.position = top(t) - Vector3(0, size.y / 2, 0)

	func host(g: Node, t: float) -> void:
		var dt := get_physics_process_delta_time()
		var p := top(t)
		var v := (top(t + dt) - p) / dt
		for bb in g.bearers:
			if _standing_on(bb, p, Vector2(size.x, size.z) / 2, p.y):
				bb.ground_velocity += Vector3(v.x, 0, v.z)

	## arg = "a" / "b"：接下来 dur 秒平台都停在这一头
	func safe(t: float, dur: float, arg: String) -> bool:
		var target := b if arg == "b" else a
		return _always(t, dur, func(x: float) -> bool: return top(x).distance_to(target) < 0.05)


## 弹射物 / 滚石：每隔 period 秒从 from 发出一个，沿直线飞（或滚）到 to 就消失。撞到人就撞飞
class Shooter extends Trap:
	var from: Vector3
	var to: Vector3
	var speed: float
	var period: float
	var phase: float
	var radius: float
	var roll := false  # 滚石：一边走一边转
	var text := "被砸飞了！"
	var _dir: Vector3
	var _len: float
	var _balls: Array[Node3D] = []

	## make：造一个弹射物外观的函数（原点在它中心）
	func _init(f: Vector3, t: Vector3, sp: float, p: float, ph: float, r: float, make: Callable) -> void:
		from = f
		to = t
		speed = sp
		period = p
		phase = ph
		radius = r
		_dir = (to - from).normalized()
		_len = from.distance_to(to)
		for i in int(ceil(_len / speed / period)) + 1:
			var ball: Node3D = make.call()
			ball.visible = false
			add_child(ball)
			_balls.append(ball)

	## 现在飞在半路上的每一个离起点多远
	func shots(t: float) -> Array[float]:
		var out: Array[float] = []
		var n := floorf(t / period + phase)
		while true:
			var s := (t - (n - phase) * period) * speed
			if s > _len:
				break
			if s >= 0.0:
				out.append(s)
			n -= 1.0
		return out

	func sim(t: float) -> void:
		var s := shots(t)
		for i in _balls.size():
			var ball := _balls[i]
			ball.visible = i < s.size()
			if ball.visible:
				ball.position = from + _dir * s[i]
				if roll:
					ball.basis = Basis(_dir.cross(Vector3.UP).normalized(), -s[i] / radius)

	func host(g: Node, t: float) -> void:
		for s in shots(t):
			var p := from + _dir * s
			for b in g.bearers:
				var q: Vector3 = b.global_position
				var c := Vector3(q.x, clampf(p.y, q.y - 0.6, q.y + 0.6), q.z)
				if c.distance_to(p) < radius + 0.3:
					_hit(b, _dir * maxf(speed * 1.4, 6.0) + Vector3.UP * 4.5, t, text)

	## arg = "s0_s1"：电脑队伍会站在离起点 s0 ~ s1 米的那一段上，这段时间里不能有弹射物经过
	func safe(t: float, dur: float, arg: String) -> bool:
		var s0 := 0.0
		var s1 := _len
		if arg.contains("_"):
			s0 = arg.get_slice("_", 0).to_float()
			s1 = arg.get_slice("_", 1).to_float()
		return _always(t, dur, func(x: float) -> bool:
			for s in shots(x):
				if s > s0 - radius - 0.8 and s < s1 + radius + 0.8:
					return false
			return true)
