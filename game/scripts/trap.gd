class_name Trap
extends Node3D
## 机关基类（具体的机关在 traps.gd）。
##
## 一个机关的外观和碰撞只由“现在几点”和“什么时候被触发的”（t0）决定：sim(t) 两边都跑，
## 联机时只要把 t0 同步过去，加入方看到的就和房主一样。host(g, t) 只在房主跑：判断有没有人踩到、
## 把被打中的人撞飞。周期性的机关不用 t0，纯按时间走。
## 机关都放在原点，参数里的坐标都是世界坐标。

var trap_name := ""
var level: Level
var t0 := -1.0  # 被触发的时间（-1 = 没触发）
var rearm := 0.0  # 触发后过多久复位、可以再次触发（0 = 一次性）
var _hit_at := {}  # 抬棺人 → 上次被这个机关打中的时间


func sim(_t: float) -> void:
	pass


func host(_g: Node, _t: float) -> void:
	pass


## 电脑队伍用：接下来 dur 秒这个机关都伤不到人（arg 是关卡路线里写的附加参数）
func safe(_t: float, _dur: float, _arg: String) -> bool:
	return true


## 触发以后过了多久（没触发返回 -1）
func since(t: float) -> float:
	return t - t0 if t0 >= 0.0 else -1.0


func fire(t: float) -> void:
	if t0 < 0.0:
		t0 = t


func _rearm(t: float) -> void:
	if rearm > 0.0 and t0 >= 0.0 and t - t0 > rearm:
		t0 = -1.0


## 把一个抬棺人撞飞（同一个机关 1 秒内不重复打同一个人）
func _hit(b: Bearer, velocity: Vector3, t: float, text := "", stun := 1.3) -> void:
	if t - _hit_at.get(b, -10.0) < 1.0:
		return
	_hit_at[b] = t
	b.knock(velocity, stun)
	if text != "":
		level.notice.emit(text)


## 抬棺人站在一块水平区域上：脚在 top 附近，水平位置在 center ± half 里
static func _standing_on(b: Node3D, center: Vector3, half: Vector2, top: float) -> bool:
	var p := b.global_position
	var feet := p.y - 0.87
	return absf(p.x - center.x) < half.x and absf(p.z - center.z) < half.y and feet > top - 0.3 and feet < top + 0.35


## 抬棺人的身体（一根竖着的胶囊）和一个盒子挨上了
static func _touches_box(b: Node3D, center: Vector3, half: Vector3, margin := 0.3) -> bool:
	var d := b.global_position - center
	return absf(d.x) < half.x + margin and absf(d.z) < half.z + margin and absf(d.y) < half.y + 0.85


## 在 [t, t + dur] 里每隔 0.1 秒问一次 ok(t)，全都为真才算安全
static func _always(t: float, dur: float, ok: Callable) -> bool:
	var k := 0.0
	while k <= dur:
		if not ok.call(t + k):
			return false
		k += 0.1
	return true
