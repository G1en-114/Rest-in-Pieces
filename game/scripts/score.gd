class_name Score
extends RefCounted
## 一局的计分：体面值、用时、各种失误和趣事的次数，以及送达后的结算（明细、评级、称号、奖章）。
## 体面值只按事件扣（颠一下、掉出来、摔下去……），不按秒扣，所以再狼狈也不会掉到几千分。
## 只在房主（或单机）这边算；加入方只显示房主发来的数字。

const GRADES := [["S", 150.0], ["A", 115.0], ["B", 85.0], ["C", 55.0]]
const OUT_DELAY := 1.0  # 逝者在棺材外面待满这么久才算掉出来，塞回去也要待满这么久才算回来
const BUMP_TILT := 35.0  # 逝者在棺材里时，棺材歪过这个角度算“颠了一下”
const BUMP_RESET := 20.0  # 回到这个角度以内才重新计
const BUMP := 2.0
const DROP := 10.0
const FALL := 20.0
const COFFIN_DROP := 8.0
const HIT := 3.0
const HIT_COOLDOWN := 1.5
const STEADY_BADGE := 90.0

var dignity := 100.0
var elapsed := 0.0
var bumps := 0  # 颠了几下
var drops := 0  # 逝者掉出来几次
var falls := 0  # 整队坠落几次
var coffin_drops := 0  # 棺材摔地上几次
var hits := 0  # 撞上硬物几次
var knocks := 0  # 被机关撞飞几次（不扣分）
var wreaths := 0
var wreath_total := 0
var secrets := 0
var secret_total := 0
var shortcuts: Array = []  # 抄过的近路名字
var clean_rooms := 0  # 一点失误没有的房间数
var steady := 0.0  # 当前连续稳稳当当了多久
var steady_best := 0.0
var full_run := true  # 从第 1 个房间开始的完整一局
var corpse_out := false
var _flip_timer := 0.0
var _bumped := false
var _hit_at := -10.0
var _room_mistakes := 0


## 存档 / 换场景时带走的数字
func snapshot() -> Dictionary:
	return {dignity = dignity, elapsed = elapsed, bumps = bumps, drops = drops, falls = falls, coffin_drops = coffin_drops,
		hits = hits, knocks = knocks, wreaths = wreaths, secrets = secrets, shortcuts = shortcuts.duplicate(),
		clean_rooms = clean_rooms, steady_best = steady_best, full_run = full_run}


func restore(d: Dictionary) -> void:
	for k in d:
		if k in self:
			set(k, d[k])


## 每个物理帧调一次（开局抓起棺材之后）。tilt：棺材倾角；inside：逝者躯干在不在棺材里。返回要提示的话（没有就是 ""）
func update(delta: float, tilt: float, inside: bool) -> String:
	elapsed += delta
	steady += delta
	steady_best = maxf(steady_best, steady)
	var msg := ""
	if inside and not corpse_out and tilt > BUMP_TILT and not _bumped:
		_bumped = true
		bumps += 1
		_mistake(BUMP)
	elif tilt < BUMP_RESET:
		_bumped = false
	if inside == corpse_out:
		_flip_timer += delta
		if _flip_timer >= OUT_DELAY:
			_flip_timer = 0.0
			corpse_out = not inside
			if corpse_out:
				drops += 1
				_mistake(DROP)
				msg = "逝者掉出来了！体面 -%d\n往下看、弯腰把他捡回去" % DROP
			else:
				msg = "塞回去了，继续"
	else:
		_flip_timer = 0.0
	return msg


func _mistake(amount: float) -> void:
	dignity -= amount
	steady = 0.0
	_room_mistakes += 1


func fall() -> void:
	falls += 1
	_mistake(FALL)


func coffin_drop() -> void:
	coffin_drops += 1
	_mistake(COFFIN_DROP)


## 棺材撞上硬物：有冷却，蹭着墙走不会一直扣。返回这次算不算
func hit() -> bool:
	if elapsed - _hit_at < HIT_COOLDOWN:
		return false
	_hit_at = elapsed
	hits += 1
	_mistake(HIT)
	return true


func knock() -> void:
	knocks += 1
	steady = 0.0


## 进了下一个房间：上一间一点失误没有就记一个零失误房间
func end_room() -> void:
	if _room_mistakes == 0:
		clean_rooms += 1
	_room_mistakes = 0


## 送达后的结算。corpse_in：送达那一刻逝者在不在棺材里；par：这关的标准用时
func result(par: float, corpse_in: bool) -> Dictionary:
	end_room()
	var lines: Array = [["基础体面值（含花圈、秘密）", roundf(dignity)]]
	if corpse_in:
		lines.append(["逝者在棺材里", 20.0])
	if drops == 0:
		lines.append(["全程没掉出来过", 10.0])
	if elapsed < par:
		lines.append(["用时低于标准 %s" % clock(par), 10.0])
	if wreath_total > 0 and wreaths >= wreath_total:
		lines.append(["花圈全部收集", 15.0])
	if clean_rooms > 0:
		lines.append(["零失误房间 × %d" % clean_rooms, 3.0 * clean_rooms])
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
	elif knocks >= 8:
		title = "人在空中飞，棺在地上爬"
	elif elapsed < par * 0.6:
		title = "赶着投胎"
	elif falls >= 3:
		title = "深渊常客"
	var badges: Array = []
	if knocks >= 5:
		badges.append("空中飞人")
	if steady_best >= STEADY_BADGE:
		badges.append("稳如泰山")
	if secret_total > 0 and secrets >= secret_total:
		badges.append("探险家")
	if wreath_total > 0 and wreaths >= wreath_total:
		badges.append("花圈收割机")
	if not shortcuts.is_empty():
		badges.append("抄近路")
	if drops == 0 and falls == 0:
		badges.append("一镜到底")
	if falls >= 5:
		badges.append("深渊常客")
	if drops >= 5:
		badges.append("逝者想自己走")
	var stats := "颠了 %d 下 · 掉出 %d 次 · 坠落 %d 次 · 被撞飞 %d 次 · 撞墙 %d 次" % [bumps, drops, falls, knocks, hits]
	var finds := "花圈 %d / %d · 秘密 %d / %d · 最长稳了 %s" % [wreaths, wreath_total, secrets, secret_total, clock(steady_best)]
	if not shortcuts.is_empty():
		finds += " · 近路：" + "、".join(shortcuts)
	return {lines = lines, total = total, grade = grade, title = title, elapsed = elapsed, badges = badges,
		stats = stats, finds = finds, drops = drops, falls = falls, knocks = knocks, full_run = full_run}


## 评级好坏比较：S 最好；空字符串（没通关过）最差
static func better(a: String, b: String) -> bool:
	return _rank(a) > _rank(b)


static func _rank(g: String) -> int:
	return ["", "D", "C", "B", "A", "S"].find(g)


static func clock(seconds: float) -> String:
	var s := int(seconds)
	return "%d:%02d" % [s / 60, s % 60]
