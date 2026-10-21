class_name Score
extends RefCounted
## 一局的计分：体面值、用时、各种失误的次数，以及送达后的结算（明细、评级、称号）。
## 只在房主（或单机）这边算；加入方只显示房主发来的数字。

const GRADES := [["S", 130.0], ["A", 100.0], ["B", 70.0], ["C", 40.0]]
const OUT_DELAY := 1.0  # 逝者在棺材外面待满这么久才算掉出来，塞回去也要待满这么久才算回来
const TILT_FREE := 20.0  # 倾角超过这么多度才开始扣分
const TILT_RATE := 3.0  # 每秒扣 TILT_RATE × 倾角 / TILT_FREE

var dignity := 100.0
var elapsed := 0.0
var drops := 0  # 逝者掉出来几次
var falls := 0  # 整队坠落几次
var full_run := true  # 从第 1 个房间开始的完整一局
var corpse_out := false
var _flip_timer := 0.0


## 存档 / 换场景时带走的数字
func snapshot() -> Dictionary:
	return {dignity = dignity, elapsed = elapsed, drops = drops, falls = falls, full_run = full_run}


func restore(d: Dictionary) -> void:
	dignity = d.get("dignity", dignity)
	elapsed = d.get("elapsed", elapsed)
	drops = d.get("drops", drops)
	falls = d.get("falls", falls)
	full_run = d.get("full_run", full_run)


## 每个物理帧调一次（开局抓起棺材之后）。inside：逝者躯干在不在棺材里。返回要提示的话（没有就是 ""）
func update(delta: float, tilt: float, inside: bool) -> String:
	elapsed += delta
	# 逝者躺在棺材里时，棺材歪得越厉害掉分越快（人都掉出来了，棺材怎么歪都无所谓）
	if inside and not corpse_out and tilt > TILT_FREE:
		dignity -= delta * TILT_RATE * tilt / TILT_FREE
	if inside == corpse_out:
		_flip_timer += delta
		if _flip_timer >= OUT_DELAY:
			_flip_timer = 0.0
			corpse_out = not inside
			if corpse_out:
				drops += 1
				dignity -= 10.0
				return "逝者掉出来了！体面 -10\n往下看、弯腰把他捡回去"
			return "塞回去了，继续"
	else:
		_flip_timer = 0.0
	return ""


func fall() -> void:
	falls += 1
	dignity -= 30.0


## 送达后的结算。corpse_in：送达那一刻逝者在不在棺材里；par：这关的标准用时
func result(par: float, corpse_in: bool) -> Dictionary:
	var lines: Array = [["基础体面值（含花圈）", roundf(dignity)]]
	if corpse_in:
		lines.append(["逝者在棺材里", 20.0])
	if drops == 0:
		lines.append(["全程没掉出来过", 10.0])
	if elapsed < par:
		lines.append(["用时低于标准 %s" % clock(par), 10.0])
	var total := 0.0
	for l in lines:
		total += l[1]
	var grade := "D"
	for g in GRADES:
		if total >= g[1]:
			grade = g[0]
			break
	var title := "平平安安"
	if dignity < 0.0:
		title = "社死现场"
	elif drops >= 3:
		title = "逝者表示很无语"
	elif not corpse_in:
		title = "人去了，棺材还在"
	elif grade == "S":
		title = "年度最佳抬棺人"
	elif elapsed < par * 0.6:
		title = "赶着投胎"
	elif falls >= 3:
		title = "深渊常客"
	return {lines = lines, total = total, grade = grade, title = title, elapsed = elapsed,
		drops = drops, falls = falls, full_run = full_run}


## 评级好坏比较：S 最好；空字符串（没通关过）最差
static func better(a: String, b: String) -> bool:
	return _rank(a) > _rank(b)


static func _rank(g: String) -> int:
	return ["", "D", "C", "B", "A", "S"].find(g)


static func clock(seconds: float) -> String:
	var s := int(seconds)
	return "%d:%02d" % [s / 60, s % 60]
