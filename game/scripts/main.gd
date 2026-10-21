class_name Main
extends Node3D
## 抬棺：一群站不稳的抬棺人，把棺材从起点一路抬到灵台。这里只负责组装：
## 玩家控制、镜头、联机、计分；关卡本身（房间、机关、灵台）在 scripts/levels/*.gd。
##
## 流程：选模式（单人 / 双人 / 建房 / 加入）→ 选关 → 选房间 → 游戏 → 送达后的结算面板（菜单在 menu.gd）。
##   单人：键鼠控制一个抬棺人，另一个是电脑队友，跟着你抓、跟着你走
##   双人：P1 用键鼠，P2 用键盘右侧；默认左右分屏各自第一人称（像《双人成行》）
##   联机：每人一台电脑。房主计算全部物理；加入的人只发按键，收到位置后插值显示
## 两种镜头：第一人称和固定俯视视角（Q/E 旋转 45°，滚轮缩放，过视错觉断桥要用它）。
## 单人按 V 切换；双人按 V 或 Enter，两人一起在“分屏第一人称”和“共享俯视”之间切换。
## 棺材进入新房间就记检查点（同时存档）；坠落或按 R 回到检查点。
##
## 命令行参数（放在 `--` 之后）：
##   --level=<id>   直接进某一关（默认 china）
##   --room=N       从第 N 个房间（从 0 数）出发；配 --bot 时只测这一间：走到下一间打印 ROOM_PASS 并退出
##   --bot          两个抬棺人自动抓住棺材沿关卡路线走（测试物理用）
##   --levelbot     同 --bot，从第 1 间走完整关，送达后打印结算并退出
##   --noalign      配 --bot：不转视角直接走上断桥（应该掉下去）
##   --nowait       配 --bot：路线里的 "wait:" 都不等（测机关会不会伤人）
##   --stopat=N     配 --bot：走到第 N 个路线点就站着不动（测塌陷地板之类）
##   --lonetest     同 --bot，但 2 号空着手自己过断桥（测试单人过桥不掉下去）
##   --solotest     单人模式自动测试：抓起 → 走 → 扔到地上 → 弯腰捡起 → 再抬起来
##   --solo / --fp  直接进入单人模式 / 并切到第一人称（放在 --join 后面则是联机加入方用第一人称）
##   --atbridge     中式关：整队直接出生在断桥前（等于 --room=2）
##   --duo / --topdown  直接进入双人模式 / 并切到俯视
##   --host / --join=IP  直接建房间 / 加入房间
##   --nettest      联机自动测试：两边各自抓住棺材往前走（房主和加入方都要加）
##   --quit=秒      到时间自动退出
##   --shot=路径    退出前截一张图

const P2_KEYS := {
	"up": [KEY_UP], "down": [KEY_DOWN], "left": [KEY_LEFT], "right": [KEY_RIGHT],
	"grab_l": [KEY_COMMA, KEY_KP_1], "grab_r": [KEY_PERIOD, KEY_KP_3], "jump": [KEY_SLASH, KEY_KP_0],
	"reach_up": [KEY_APOSTROPHE, KEY_KP_8], "reach_down": [KEY_SEMICOLON, KEY_KP_2],
}
const CAM_DIST := 8.5
const CAM_HEIGHT := 7.5
const MOUSE_SENS := 0.0025
const HAND_PITCH_OFFSET := 0.35  # 平视时手的仰角：大约举在胸口
const P2_TURN_SPEED := 2.4  # P2 用 ←→ 转身的速度（弧度/秒）
const P2_PITCH_SPEED := 1.5
const FP_FREE_LOOK := 95.0  # 单人：转头超过这个角度会拖着身体（和队友、棺材）一起转
const DUO_FREE_LOOK := 180.0  # 双人分屏：抓着东西时随便转头，棺材靠两人走位来转
const FP_EYE_HEIGHT := 0.8
const ORTHO_SIZE := 15.0
const DELIVER_TILT := 25.0  # 送达时棺材倾角要小于这个
const DELIVER_HOLD := 1.5  # 稳稳停在灵台上这么久算送达
## 天空、雾、太阳的默认值（中式关的黄昏），关卡的 env() 可以覆盖其中任意几项
const ENV_DEFAULT := {
	sky_top = Color(0.3, 0.33, 0.55), sky_horizon = Color(0.98, 0.72, 0.56), sky_curve = 0.12,
	ground_horizon = Color(0.92, 0.66, 0.56), ground_bottom = Color(0.36, 0.3, 0.42), ground_curve = 0.06,
	ambient = 0.75, exposure = 1.05, saturation = 1.08,
	fog_color = Color(0.86, 0.66, 0.62), fog_density = 0.004, fog_height = -3.0, fog_height_density = 0.12,
	sun_rot = Vector3(-40, -35, 0), sun_color = Color(1.0, 0.86, 0.7), sun_energy = 1.25,
}

static var mode := ""  # "solo" | "duo" | "online"，重来时保留
static var net_role := ""  # 联机时："host" | "client"
static var join_ip := "127.0.0.1"
static var menu_note := ""  # 回到选择界面时顺便提示一句（比如断线了）
static var level_id := ""  # 正在玩的关卡；加入方是 "" 时表示还在等房主告诉他玩哪关
static var start_room := 0
static var carry := {}  # 换场景时带过去的分数（继续存档、队友中途加入）
static var menu_page := ""  # 重载后先显示哪页菜单："levels" = 选关
static var _args_done := false  # --level / --room 只在第一次进场景时生效，之后由菜单决定

var level: Level
var score := Score.new()
var room := 0  # 当前检查点所在的房间
var bearers: Array[Bearer] = []
var coffin: Coffin
var corpse: Corpse
var cam_fixed: Camera3D
var cam_fp: Camera3D
var cam_split: Array[Camera3D] = []  # 双人分屏的两个第一人称镜头
var _split: Control
var _fixed_mask := 0
var hud: Label
var status: Label
var help: Label
var _crosshair: Label
var _menu: Menu

var first_person := false
var cam_yaw := 45.0
var cam_yaw_target := 45.0
var zoom := 1.0
var look_yaw := 0.0
var look_pitch := 0.0
var p2_yaw := PI
var p2_pitch := 0.0

var started := false
var finished := false
var goal_timer := 0.0
var status_timer := 0.0
var _in_menu := false
var _waiting := false  # 加入方：还不知道玩哪关（等房主）

var _partner_formed := false
var _partner_offset := Vector3.ZERO
var _coffin_falling := false
var _bot_path: Array = []
var _bot_wp := 0
var _bot_lower_timer := 0.0
var _altar_hint_shown := false

var bot := false
var levelbot := false
var solotest := false
var _force_topdown := false
var duotest := false
var atbridge := false  # 测试用：中式关整队直接出生在断桥前，面朝桥
var lonetest := false  # 测试用：2 号抬棺人不抓棺材，空着手自己走过断桥（不该掉下去）
var bot_noalign := false  # 测试用：不转视角直接走上断桥（应该掉下去）
var bot_nowait := false
var bot_stopat := -1
var bot_delay := 0.0  # --botdelay=秒：电脑队伍晚这么久才出发（换个时机撞机关）
var _room_test := -1  # --bot --room=N：只测第 N 间
var quit_at := -1.0  # 按模拟时间算，开头卡顿不影响测试
var sim_time := 0.0  # 物理模拟走过的时间，测试脚本都用它计时
var shot_path := ""
var _log_timer := 0.0

# 联机
var nettest := false
var _sync := NetSync.new()
var _gen := 0  # 每次重生整队 / 逝者加一；快照带着它，旧快照不会套到新身体上
var _remote_input := {}  # 房主这边：加入方最近一次发来的按键
var _remote_input_at := -10.0
var _peer_joined_at := -1.0  # 房主：队友加入时的 sim_time（--nettest 从这时开始计时）
var _net_tick := 0
var _wait_note := ""
var _max_step := 0.0  # --nettest：加入方画面里棺材每帧最大位移，用来看有没有瞬移
var _last_coffin_pos := Vector3.ZERO
var _flash_rects: Array[ColorRect] = []  # 过桥闪白：全屏一块；双人分屏时左右各一块


func _ready() -> void:
	var arg_level := ""
	var arg_room := -1
	for arg in OS.get_cmdline_user_args():
		if arg == "--bot":
			bot = true
		elif arg == "--levelbot":
			bot = true
			levelbot = true
		elif arg == "--noalign":
			bot_noalign = true
		elif arg == "--nowait":
			bot_nowait = true
		elif arg.begins_with("--botdelay="):
			bot_delay = float(arg.get_slice("=", 1))
		elif arg.begins_with("--stopat="):
			bot_stopat = int(arg.get_slice("=", 1))
		elif arg == "--lonetest":
			bot = true
			lonetest = true
		elif arg == "--solotest":
			solotest = true
			mode = "solo"
		elif arg == "--solo":
			mode = "solo"
		elif arg == "--duo":
			mode = "duo"
		elif arg == "--duotest":
			mode = "duo"
			duotest = true
		elif arg == "--topdown":
			_force_topdown = true
		elif arg == "--fp":
			if mode == "":
				mode = "solo"
			first_person = true
		elif arg == "--host":
			mode = "online"
			net_role = "host"
		elif arg.begins_with("--join="):
			mode = "online"
			net_role = "client"
			join_ip = arg.get_slice("=", 1)
		elif arg == "--atbridge":
			atbridge = true
			arg_room = 2
		elif arg.begins_with("--level="):
			arg_level = arg.get_slice("=", 1)
		elif arg.begins_with("--room="):
			arg_room = int(arg.get_slice("=", 1))
		elif arg.begins_with("--menu="):  # 截图用：直接打开 levels 或 rooms:<关卡 id> 这一页
			menu_page = arg.get_slice("=", 1)
		elif arg == "--nettest":
			nettest = true
		elif arg.begins_with("--camyaw="):
			cam_yaw_target = float(arg.get_slice("=", 1))
		elif arg.begins_with("--quit="):
			quit_at = float(arg.get_slice("=", 1))
		elif arg.begins_with("--shot="):
			shot_path = arg.get_slice("=", 1)
	if bot or solotest or duotest or nettest:
		Save.enabled = false  # 自动测试不碰玩家的存档
	if not _args_done:
		_args_done = true
		if arg_level:
			level_id = arg_level
		if arg_room >= 0:
			start_room = arg_room
		if (bot or mode != "") and level_id == "" and net_role != "client":
			level_id = "china"
	if bot and arg_room >= 0 and not levelbot:
		_room_test = start_room
	_in_menu = not bot and (menu_page != "" or mode == "")
	var menu_mode := mode
	var menu_role := net_role
	if _in_menu:
		mode = ""  # 菜单里谁也不控制；选好以后再把模式写回去
		net_role = ""
	_waiting = mode == "online" and net_role == "client" and level_id == ""

	level = Level.create(level_id) if level_id else null
	if level == null and level_id and bot:
		print("LEVEL_LOAD_FAILED ", level_id)  # 自动测试别悄悄换成中式关
		get_tree().quit(1)
	if level == null:
		level = Level.create("china")  # 菜单和等房主时拿中式关当背景
	level.game = self
	add_child(level)
	_build_environment(level.env())
	if net_role != "client":  # 加入方的分数和提示都由房主发过来
		level.bonus.connect(func(amount: float, text: String) -> void:
			score.dignity += amount
			say(text))
		level.penalty.connect(func(amount: float, text: String) -> void:
			if started and not finished:
				score.dignity -= amount
				say(text))
		level.notice.connect(say)
	room = 0 if _in_menu or _waiting else clampi(start_room, 0, level.rooms.size() - 1)
	if not carry.is_empty():
		score.restore(carry)
		carry = {}
	elif room > 0:
		score.full_run = false
	_spawn_team(room)
	if bot:
		for i in range(room, level.rooms.size() if _room_test < 0 else room + 1):
			_bot_path.append_array(level.rooms[i].path)

	var spawn := _spawn_point(room)
	cam_fixed = Camera3D.new()
	cam_fixed.projection = Camera3D.PROJECTION_ORTHOGONAL  # 正交投影：纪念碑谷式的视错觉只在正交下严格成立
	cam_fixed.size = ORTHO_SIZE
	cam_fixed.far = 200.0
	for layer in Bearer.HAND_LAYERS:
		cam_fixed.cull_mask &= ~(1 << (layer - 1))
	cam_fixed.cull_mask &= ~(1 << (Level.HINT_LAYER - 1))
	_fixed_mask = cam_fixed.cull_mask
	add_child(cam_fixed)
	cam_fixed.global_position = spawn + _cam_offset()
	cam_fixed.look_at(spawn)
	cam_fp = Camera3D.new()
	cam_fp.fov = 75
	cam_fp.near = 0.05
	cam_fp.cull_mask = Bearer.fp_cull_mask(_me())
	add_child(cam_fp)
	_build_hud()

	if mode == "duo":
		first_person = not _force_topdown  # 双人默认分屏第一人称
	if atbridge:
		look_yaw = PI / 2  # 面朝 -X，看着断桥
	elif mode == "online" and net_role == "client":
		look_yaw = PI  # 加入方站在棺材另一侧，面朝 +Z
	if mode != "" and not bot and not nettest:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_apply_camera()
	if mode == "online":
		_start_net()
	if _in_menu:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		if menu_page.begins_with("rooms:"):
			_menu.show_levels("solo", "")
			_menu.show_rooms(menu_page.get_slice(":", 1))
		elif menu_page == "levels":
			_menu.show_levels(menu_mode if menu_mode else "solo", menu_role)
		else:
			_menu.show_modes(menu_note)
		menu_page = ""
		menu_note = ""


func _spawn_point(r: int) -> Vector3:
	return level.rooms[r].spawn + Vector3(0, level.rooms[r].get("lift", 0.24), 0)


## 在第 r 个房间的检查点生成整队：棺材 + 逝者 + 两个抬棺人（站在棺材两侧）
func _spawn_team(r: int) -> void:
	var rm: Dictionary = level.rooms[r]
	var floor_pos: Vector3 = rm.spawn
	var yaw: float = rm.get("yaw", 0.0)
	var turn := Basis(Vector3.UP, yaw)
	coffin = Coffin.new()
	coffin.transform = Transform3D(turn, _spawn_point(r))
	add_child(coffin)
	coffin.body_entered.connect(_on_coffin_hit)
	corpse = Corpse.new()
	corpse.transform = coffin.transform
	add_child(corpse)
	_spawn_bearer(floor_pos + Vector3(0, 0.9, 0) + turn * Vector3(0, 0, 0.85), yaw)
	_spawn_bearer(floor_pos + Vector3(0, 0.9, 0) + turn * Vector3(0, 0, -0.85), yaw + PI)
	if mode == "solo":
		bearers[0].set_first_person_owner(0)
	elif mode == "duo":
		bearers[0].set_first_person_owner(0)
		bearers[1].set_first_person_owner(1)
	elif mode == "online":
		bearers[_me()].set_first_person_owner(_me())
		if net_role == "client":
			_make_puppets()


## 掉进深渊（或按 R）后在当前检查点重来：棺材放在地上，要自己弯腰捡起来
func _respawn_team(r: int) -> void:
	for b in bearers:
		b.release_all()
		for h in b.hands:
			h.queue_free()
		b.queue_free()
	bearers.clear()
	coffin.queue_free()
	corpse.queue_free()
	_partner_formed = false
	_coffin_falling = false
	_spawn_team(r)
	_bump_gen()
	if _is_host():
		_net_respawn_team.rpc(r)


func _respawn_corpse() -> void:
	corpse.queue_free()
	corpse = Corpse.new()
	corpse.transform = coffin.global_transform
	add_child(corpse)
	_bump_gen()
	if _is_host():
		_net_respawn_corpse.rpc()
	elif net_role == "client":
		_make_puppets()


func team_bodies() -> Array[RigidBody3D]:
	var list: Array[RigidBody3D] = [coffin]
	list.append_array(corpse.parts)
	for b in bearers:
		list.append(b)
		list.append_array(b.hands)
	return list


## 联机快照里的全部刚体：整队在前，关卡里要同步的石块、滚石接在后面
func _sync_bodies() -> Array[RigidBody3D]:
	var list := team_bodies()
	list.append_array(level.net_bodies())
	return list


## 有没有人在俯视（联机时任何一方俯视都算；关卡里的视错觉机关用）
func someone_topdown() -> bool:
	return not first_person or (_peer_present() and not _remote_input.get("fp", true))


## 房主每帧：关卡机关、推进检查点、坠落判定
func _update_level() -> void:
	level.physics_update(self)
	var r := level.room_at(coffin.global_position)
	if r > room and r < level.rooms.size() and coffin.linear_velocity.y > -2.0:  # 正在往下掉的不算进了新房间
		room = r
		_on_room_entered()
	var kill := level.room_kill_y(room)
	if coffin.global_position.y < kill or bearers.any(func(b): return b.global_position.y < kill):
		if started and not finished:
			score.fall()
		say("整队掉进了深渊！体面 -30\n从检查点重来")
		_respawn_team(room)
	elif corpse.torso.global_position.y < kill:
		score.dignity -= 10.0
		say("逝者掉进了深渊……又被送回来了。体面 -10")
		_respawn_corpse()


func _on_room_entered() -> void:
	say("第 %d 间 · %s" % [room + 1, level.rooms[room].name], 3.0)
	if started and not finished and mode != "":
		Save.store_checkpoint(level_id, room, score.snapshot())
	if _room_test >= 0 and room > _room_test:
		print("ROOM_PASS %d -> %d t=%.1f dignity=%d" % [_room_test, room, sim_time, roundi(score.dignity)])
		_finish_run()


## 关卡要整组平移刚体时（比如过断桥）用：抓在一起的必须一起走，不然关节会把人扯飞。
## 起步是棺材、逝者、每个抬棺人（连同两只手）各一组；谁抓着谁就并成一组，躺在棺材里的逝者跟棺材一组。
## 每组第一个刚体是判断位置的参照（有棺材时就是棺材）。
func move_groups() -> Array:
	var units: Array = [[coffin], corpse.parts.duplicate()]
	for b in bearers:
		units.append([b, b.hands[0], b.hands[1]])
	var unit_of := {}
	for i in units.size():
		for body in units[i]:
			unit_of[body] = i
	var label: Array = range(units.size())
	var links: Array = []
	if coffin.contains(corpse.torso.global_position):
		links.append([0, 1])
	for i in range(2, units.size()):
		for h in units[i][0].held:
			if h != null and unit_of.has(h):
				links.append([unit_of[h], i])
	for l in links:
		var from: int = label[l[1]]
		var to: int = label[l[0]]
		for k in label.size():
			if label[k] == from:
				label[k] = to
	var groups := {}
	for i in units.size():
		if not groups.has(label[i]):
			groups[label[i]] = []
		groups[label[i]].append_array(units[i])
	return groups.values()


## 第 player 号玩家被关卡瞬移了（比如过断桥）：第一人称就闪一下白光
func flash(player: int) -> void:
	if mode == "duo":
		if first_person:
			_flash_rect(_flash_rects[player])
	elif player == _me():
		if first_person:
			_flash_rect(_flash_rects[0])
	elif _peer_present():
		_net_flash.rpc()


func _flash_rect(r: ColorRect) -> void:
	var tw := create_tween()
	tw.tween_property(r, "color:a", 1.0, 0.06).from(0.0)
	tw.tween_property(r, "color:a", 0.0, 0.5)


func _spawn_bearer(pos: Vector3, yaw: float) -> void:
	var b := Bearer.new()
	b.position = pos
	b.rotation.y = yaw
	add_child(b)
	bearers.append(b)


# ---------- 菜单与换关 ----------

## 菜单里选好了：把模式和关卡写进静态变量，重载场景开始
func _on_menu_start(m: String, role: String, lid: String, r: int, resume: bool) -> void:
	mode = m
	net_role = role
	var c := {}
	if resume:
		c = Save.checkpoint(lid).get("score", {})
	elif r > 0:
		c = {full_run = false}
	_goto(lid, r, c)


func _on_menu_join(ip: String) -> void:
	join_ip = ip
	mode = "online"
	net_role = "client"
	level_id = ""
	get_tree().reload_current_scene()


## 换关 / 重来都走这里：房主先叫加入方跟着换，再自己重载
func _goto(lid: String, r: int, c: Dictionary) -> void:
	level_id = lid
	start_room = r
	carry = c
	menu_page = ""
	if net_role == "host" and _link_has_peers():
		_net_goto.rpc(lid, r, c)
	get_tree().reload_current_scene()


func _to_level_menu() -> void:
	menu_page = "levels"
	if net_role == "host" and _link_has_peers():
		_net_wait.rpc()
	get_tree().reload_current_scene()


## R / N / M / F5：房主或单机直接执行；加入方发给房主
func _command(key: String) -> void:
	if net_role == "client":
		_net_command.rpc_id(1, key)
		return
	match key:
		"F5":
			_goto(level_id, 0, {})
		"R":
			if finished:
				_goto(level_id, 0, {})
			else:
				say("回到检查点：第 %d 间" % (room + 1))
				_respawn_team(room)
		"N":
			if finished and Level.next_id(level_id) != "":
				_goto(Level.next_id(level_id), 0, {})
		"M":
			if finished:
				_to_level_menu()


func _on_delivered() -> void:
	finished = true
	var res := score.result(level.par_time, coffin.contains(corpse.torso.global_position))
	var improved := Save.finish(level_id, res.grade, res.full_run) if mode != "" else false
	_show_result(res, improved)
	if _peer_present():
		_net_result.rpc(res, improved)
	print("GRADE %s total=%d title=%s elapsed=%.1f drops=%d falls=%d full=%s" % [res.grade, res.total, res.title,
		res.elapsed, res.drops, res.falls, res.full_run])
	if _room_test >= 0:
		print("ROOM_PASS %d -> goal t=%.1f" % [_room_test, sim_time])
	if levelbot or _room_test >= 0:
		quit_at = sim_time + 0.5


func _show_result(res: Dictionary, improved: bool) -> void:
	finished = true
	status_timer = 0.0
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_menu.show_result(res, "%s · %s" % [Level.info(level_id).get("country", ""), level.title],
		Level.next_id(level_id) != "", improved)


# ---------- 输入 ----------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		look_yaw = wrapf(look_yaw - event.relative.x * MOUSE_SENS, -PI, PI)
		look_pitch = clampf(look_pitch - event.relative.y * MOUSE_SENS, -1.5, 1.2)
	elif event is InputEventMouseButton and event.pressed:
		if mode != "" and not finished and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom = clampf(zoom - 0.1, 0.5, 1.8)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom = clampf(zoom + 0.1, 0.5, 1.8)
	elif event is InputEventKey and event.pressed and not event.echo:
		var key: Key = event.physical_keycode
		if key == KEY_ESCAPE:
			if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			elif _in_menu or _waiting:
				get_tree().quit()
			else:
				_leave_online("")  # 回到选模式
			return
		if mode == "" or _waiting:
			return
		if key in [KEY_F5, KEY_BACKSPACE]:
			_command("F5")
		elif key == KEY_R and not finished:
			_command("R")
		elif key == KEY_F1:
			_leave_online("")
		elif key == KEY_V or (mode == "duo" and key in [KEY_ENTER, KEY_KP_ENTER]):
			first_person = not first_person
			if first_person and mode == "duo":
				p2_yaw = _yaw_of(bearers[1])  # 切回分屏时，P2 的视角从他现在面朝的方向开始
				p2_pitch = 0.0
			_apply_camera()
		elif not first_person and _is_rotate_key(key, -1):
			_rotate_view(-1)
		elif not first_person and _is_rotate_key(key, 1):
			_rotate_view(1)


## 俯视视角联机时是大家共用的：加入方按 Q/E 要请房主转
func _rotate_view(dir: int) -> void:
	if net_role == "client":
		_net_rotate.rpc_id(1, dir)
	else:
		cam_yaw_target += 45.0 * dir


## 旋转固定视角的键：Q / E（也可以用 Z / X）
func _is_rotate_key(key: Key, dir: int) -> bool:
	if dir < 0:
		return key in [KEY_Q, KEY_Z]
	return key in [KEY_E, KEY_X]


func _physics_process(delta: float) -> void:
	sim_time += delta
	if bot:
		_drive_bot()
	elif mode == "solo":
		_control_mouse_player()
		_control_partner(bearers[1], bearers[0], delta)
	elif mode == "duo":
		_control_mouse_player()
		_control_p2(delta)
		if duotest:
			_duotest_script()
	elif net_role == "client":
		if _waiting:
			return
		_control_mouse_player()  # 只是把意图写在本地的傀儡身上，再发给房主
		_net_tick += 1
		if _net_tick % NetSync.INPUT_EVERY == 0 and _connected():
			_send_input()
		return  # 规则和关卡都由房主算
	elif net_role == "host":
		_control_mouse_player()
		_apply_remote_input()
	level.tick(sim_time)
	_update_level()
	_update_rules(delta)
	if _is_host():
		_net_tick += 1
		if _net_tick % NetSync.SEND_EVERY == 0 and _peer_present():
			_send_state()


## 键鼠玩家（单人 / 双人的 P1 / 联机时自己）。鼠标管视角和手的高度，左右键管两只手
func _control_mouse_player() -> void:
	var p := bearers[_me()]
	var input := Vector2(_key(KEY_D) - _key(KEY_A), _key(KEY_S) - _key(KEY_W))
	var basis := Basis(Vector3.UP, look_yaw) if first_person else cam_fixed.global_basis
	p.move_dir = _to_world(input, basis)
	p.face_yaw = look_yaw
	var free_look := FP_FREE_LOOK if mode == "solo" else DUO_FREE_LOOK
	p.face_deadzone = deg_to_rad(free_look) if first_person and p.is_holding() else 0.0
	p.reach_pitch = look_pitch + HAND_PITCH_OFFSET
	p.want_grab = [Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT), Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)]
	p.want_jump = Input.is_physical_key_pressed(KEY_SPACE)
	if solotest:
		_solotest_script(p)
	elif nettest:
		_nettest_script(p)


## 电脑队友：
## - 你没抓棺材时，它走到棺材另一侧，把手放到把手高度等着；你一抓它就抓
## - 抓住以后，它记住自己相对你身体的站位：你走它跟着走，你转身它绕着你走，棺材就跟着转弯
## - 它会调自己手的高度去对齐你的手，让棺材保持水平；你松手它也松手
func _control_partner(me: Bearer, leader: Bearer, delta: float) -> void:
	var leader_has_coffin := leader.holds(coffin)
	me.want_jump = false
	if me.holds(coffin) and leader_has_coffin:
		var leader_frame := Basis(Vector3.UP, _yaw_of(leader))
		if not _partner_formed:
			_partner_offset = leader_frame.inverse() * (me.global_position - leader.global_position)
			_partner_offset.y = 0
			_partner_formed = true
		var err := leader.global_position + leader_frame * _partner_offset - me.global_position
		err.y = 0
		me.move_dir = (leader.move_dir + err * 2.5).limit_length(1.0)
		me.face_yaw = null
		_level_hands(me, _hand_height(leader), delta)
		me.want_grab = [true, true]
		return
	_partner_formed = false
	if me.holds(coffin):
		me.want_grab = [false, false]  # 你松手了，它也松手
		return
	# 走到和你相对的那一侧，面朝棺材，手对准把手高度
	var leader_local := coffin.to_local(leader.global_position)
	var side := 1.0 if leader_local.z >= 0.0 else -1.0
	var slot := coffin.to_global(Vector3(clampf(leader_local.x, -0.6, 0.6), 0, -side * 0.85))
	var to_slot := slot - me.global_position
	to_slot.y = 0
	me.move_dir = to_slot.normalized() * clampf(to_slot.length() * 2.0, 0.0, 1.0) if to_slot.length() > 0.08 else Vector3.ZERO
	var to_coffin := coffin.global_position - me.global_position
	me.face_yaw = atan2(-to_coffin.x, -to_coffin.z)
	_level_hands(me, coffin.global_position.y, delta)
	var in_place := to_slot.length() < 0.35 and leader_has_coffin
	me.want_grab = [in_place, in_place]


## 慢慢调整手伸出的角度，让两只手的平均高度靠近目标高度
func _level_hands(b: Bearer, target_y: float, delta: float) -> void:
	b.reach_pitch = clampf(b.reach_pitch + (target_y - _hand_height(b)) * 3.0 * delta, -1.35, 1.1)


func _hand_height(b: Bearer) -> float:
	if not b.hands[0].is_inside_tree():
		return b.global_position.y
	return (b.hands[0].global_position.y + b.hands[1].global_position.y) * 0.5


func _yaw_of(b: Bearer) -> float:
	var f := -b.global_basis.z
	return atan2(-f.x, -f.z)


## P2：键盘右侧。分屏第一人称时 ↑↓ 前后走、←→ 转身；俯视时方向键按画面方向走
func _control_p2(delta: float) -> void:
	var b := bearers[1]
	var k := P2_KEYS
	p2_pitch = clampf(p2_pitch + (_held(k.reach_up) - _held(k.reach_down)) * P2_PITCH_SPEED * delta, -1.5, 1.2)
	if first_person:
		p2_yaw = wrapf(p2_yaw + (_held(k.left) - _held(k.right)) * P2_TURN_SPEED * delta, -PI, PI)
		b.move_dir = Basis(Vector3.UP, p2_yaw) * Vector3(0, 0, _held(k.down) - _held(k.up))
		b.face_yaw = p2_yaw
		b.face_deadzone = deg_to_rad(DUO_FREE_LOOK) if b.is_holding() else 0.0
	else:
		var input := Vector2(_held(k.right) - _held(k.left), _held(k.down) - _held(k.up))
		b.move_dir = _to_world(input, cam_fixed.global_basis)
		b.face_yaw = null
		b.face_deadzone = 0.0
	b.reach_pitch = p2_pitch + HAND_PITCH_OFFSET
	b.want_grab = [_held(k.grab_l) > 0.0, _held(k.grab_r) > 0.0]
	b.want_jump = _held(k.jump) > 0.0


## 把输入方向（x 右、y 下）按某个朝向换算成世界里的水平方向
func _to_world(input: Vector2, basis: Basis) -> Vector3:
	var fwd := -basis.z
	fwd.y = 0
	var right := basis.x
	right.y = 0
	return (right.normalized() * input.x + fwd.normalized() * -input.y).limit_length(1.0)


func _key(k: Key) -> float:
	return 1.0 if Input.is_physical_key_pressed(k) else 0.0


func _held(keys: Array) -> float:
	for k in keys:
		if Input.is_physical_key_pressed(k):
			return 1.0
	return 0.0


# ---------- 规则 ----------

func _update_rules(delta: float) -> void:
	if finished:
		return
	if not started and bearers.any(func(b): return b.holds(coffin)):
		started = true
		say("抓住了！抬到灵台去")
	if not started:
		return

	var tilt := rad_to_deg(coffin.global_basis.y.angle_to(Vector3.UP))
	var inside := coffin.contains(corpse.torso.global_position)
	var msg := score.update(delta, tilt, inside)
	if msg:
		say(msg)
	# 没人抓着、棺材在往下掉 → 等它落停就扣分
	var held := bearers.any(func(b): return b.holds(coffin))
	if not held and coffin.linear_velocity.y < -3.0:
		_coffin_falling = true
	elif _coffin_falling and (held or absf(coffin.linear_velocity.y) < 0.3):
		_coffin_falling = false
		if not held:
			score.dignity -= 15.0
			say("棺材摔地上了！体面 -15")

	if held and level.on_altar(coffin.global_position, 0.3) and not _altar_hint_shown:
		_altar_hint_shown = true
		say("到灵台了！往下看把棺材放低，再轻轻松手", 4.0)

	# 棺材放平、落在灵台上，逝者也在灵台上（在棺材里或直接躺在台上都行），稳住 1.5 秒算送达
	var corpse_ok := inside or level.on_altar(corpse.torso.global_position, 0.4)
	if tilt < DELIVER_TILT and level.on_altar(coffin.global_position, 0.0, 0.45) and corpse_ok \
			and coffin.linear_velocity.length() < 0.3:
		goal_timer += delta
		if goal_timer > DELIVER_HOLD:
			_on_delivered()
	else:
		goal_timer = 0.0


func _on_coffin_hit(body: Node) -> void:
	if started and not finished and body is StaticBody3D and body.is_in_group("hard") \
			and coffin.linear_velocity.length() > 1.2:
		score.dignity -= 5.0
		say("砰！")


func say(text: String, seconds := 2.5) -> void:
	if _peer_present():
		_net_say.rpc(text, seconds)
	if bot or solotest or nettest:
		print("SAY ", text.replace("\n", " "))
	status.text = text
	status_timer = seconds


# ---------- 镜头与界面 ----------

## 固定镜头相对焦点的偏移：方向由 cam_yaw 决定，距离固定（正交投影，远近不影响画面大小）
func _cam_offset() -> Vector3:
	var a := deg_to_rad(cam_yaw)
	return Vector3(sin(a) * CAM_DIST, CAM_HEIGHT, cos(a) * CAM_DIST).normalized() * 40.0


func _apply_camera() -> void:
	var split := mode == "duo" and first_person
	if _split:
		_split.visible = split
	cam_fp.current = first_person and not split
	cam_fixed.current = not first_person or split
	# 分屏时主画面被两块分屏盖住，让它的镜头什么都不画，省一遍渲染
	# （不能用 disable_3d：那会让主视口里的物体退出 3D 世界，物理直接停掉）
	cam_fixed.cull_mask = 0 if split else _fixed_mask
	_crosshair.visible = first_person and not split
	var common := "R 回检查点 · F5 本关重来 · Esc 释放鼠标 / 回菜单"
	if mode == "solo":
		help.text = "WASD 移动 · 鼠标 看 / 控制手的高度（往下看就弯腰去够）· 左键 / 右键 左右手抓（按住）· 空格 跳\n" \
			+ "V 切换第一人称 / 固定视角 · Q / E 旋转固定视角 · 滚轮 缩放 · " + common
	elif mode == "duo":
		help.text = "P1：WASD + 鼠标 · 左键 / 右键 抓 · 空格 跳 · Q / E 转俯视视角　　" \
			+ "P2：↑↓ 走 · ←→ 转身（俯视时为平移）· ' / ; 抬头 / 低头 · , / . 抓 · / 跳\n" \
			+ "V 或 Enter：分屏第一人称 ⇄ 共享俯视（过断桥要俯视）· 滚轮 缩放 · " + common
	elif mode == "online":
		help.text = "WASD 移动 · 鼠标 看 / 控制手的高度 · 左键 / 右键 左右手抓（按住）· 空格 跳\n" \
			+ "V 切换第一人称 / 俯视（俯视视角大家共用）· Q / E 旋转 · " + common + " · F1 退出联机"
	else:
		help.text = ""


func _place_fp_camera(cam: Camera3D, b: Bearer, yaw: float, pitch: float) -> void:
	var view := Basis.from_euler(Vector3(pitch, yaw, 0))
	cam.global_transform = Transform3D(view, b.to_global(Vector3(0, FP_EYE_HEIGHT, 0)) + Basis(Vector3.UP, yaw) * Vector3(0, 0, -0.12))


func _process(delta: float) -> void:
	if net_role == "client" and not _waiting:
		_sync.apply(_sync_bodies())
		level.tick(_sync.render_time())
		_max_step = maxf(_max_step, coffin.global_position.distance_to(_last_coffin_pos))
		_last_coffin_pos = coffin.global_position
	cam_yaw = lerpf(cam_yaw, cam_yaw_target, 1.0 - exp(-delta * 6.0))
	var focus := coffin.global_position
	for b in bearers:
		focus += b.global_position
	focus /= bearers.size() + 1
	cam_fixed.global_position = cam_fixed.global_position.lerp(focus + _cam_offset(), 1.0 - exp(-delta * 4.0))
	cam_fixed.look_at(cam_fixed.global_position - _cam_offset())
	cam_fixed.size = ORTHO_SIZE * zoom

	if first_person and mode == "duo":
		_place_fp_camera(cam_split[0], bearers[0], look_yaw, look_pitch)
		_place_fp_camera(cam_split[1], bearers[1], p2_yaw, p2_pitch)
	elif first_person:
		_place_fp_camera(cam_fp, bearers[_me()], look_yaw, look_pitch)

	hud.visible = mode != "" and not _waiting
	hud.text = "体面值 %d    用时 %s    第 %d / %d 间 · %s" % [roundi(score.dignity), Score.clock(score.elapsed),
		room + 1, level.rooms.size(), level.rooms[room].name]
	hud.add_theme_color_override("font_color", Color(1, 0.35, 0.3) if score.dignity < 0.0 else Color.WHITE)
	status_timer -= delta
	status.modulate.a = clampf(status_timer, 0.0, 1.0)

	if quit_at >= 0.0 and sim_time > quit_at:
		quit_at = -1.0
		_finish_run()


# ---------- 联机 ----------
# 房主权威：房主的电脑算全部物理和规则，30 次/秒把整队刚体（加上关卡里要同步的刚体）的位置发给加入方；
# 加入方的身体都是冻住的“傀儡”，只负责显示，自己的键鼠意图 60 次/秒发给房主。
# 房主固定控制 0 号抬棺人，加入方控制 1 号。玩哪关、从哪间开始由房主定，换关时用可靠 RPC 通知加入方。

## 本机玩家控制第几个抬棺人
func _me() -> int:
	return 1 if mode == "online" and net_role == "client" else 0


func _is_host() -> bool:
	return mode == "online" and net_role == "host"


func _connected() -> bool:
	var peer := multiplayer.multiplayer_peer
	return peer is ENetMultiplayerPeer and peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED


## 网络连着、而且有队友（不管现在是在菜单里还是在游戏里）
func _link_has_peers() -> bool:
	return _connected() and not multiplayer.get_peers().is_empty()


## 房主这边：队友在不在
func _peer_present() -> bool:
	return _is_host() and _link_has_peers()


func _bump_gen() -> void:
	_gen += 1
	_sync.clear()


## 加入方：整队和关卡里要同步的刚体都不算物理，只等快照来摆位置
func _make_puppets() -> void:
	for body in _sync_bodies():
		body.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
		body.freeze = true
	for b in bearers:
		b.puppet = true


func _start_net() -> void:
	var peer := multiplayer.multiplayer_peer
	if not (peer is ENetMultiplayerPeer and peer.get_connection_status() != MultiplayerPeer.CONNECTION_DISCONNECTED):
		peer = ENetMultiplayerPeer.new()
		var err: Error
		if net_role == "host":
			err = peer.create_server(NetSync.PORT, 1)
		else:
			err = peer.create_client(join_ip, NetSync.PORT)
		if err != OK:
			_leave_online("端口 %d 被占用了（是不是已经开着一个房主窗口？）" % NetSync.PORT if net_role == "host"
				else "无法连接 %s（错误 %d）" % [join_ip, err])
			return
		multiplayer.multiplayer_peer = peer
	# multiplayer 跨场景重载一直存在；连的是本节点的方法，节点释放时会自动断开
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_leave_online.bind(
		"连不上 %s。确认房主已经建好房间、两台电脑在同一个局域网（或都开着 Radmin VPN），并且防火墙放行了 Godot" % join_ip))
	multiplayer.server_disconnected.connect(_leave_online.bind("和房主断开了连接"))
	if net_role == "host":
		_wait_note = "房间建好了，等队友加入……\n让队友按 4，输入你的 IP：%s" % _local_ips()
		if multiplayer.get_peers().is_empty():
			say(_wait_note, 9999.0)
		else:
			_peer_joined_at = 0.0  # 重来或换关，队友还在
	elif _waiting:
		_menu.show_text("联机", ("连上了，等房主选关……" if _connected() else "正在连接 %s ……" % join_ip))
	elif _connected():
		_peer_joined_at = 0.0


func _local_ips() -> String:
	var ips: Array[String] = []
	for a in IP.get_local_addresses():
		if a.contains(".") and not a.begins_with("127.") and not a.begins_with("169.254."):
			ips.append(a)
	return " 或 ".join(ips) if ips else "（没找到网卡地址）"


## 队友中途加入：带着现在的分数，从当前检查点一起重开（这样两边的场景和计时从同一刻开始）
func _on_peer_connected(_id: int) -> void:
	if _is_host():
		_goto(level_id, room, score.snapshot())


func _on_peer_disconnected(_id: int) -> void:
	if _is_host():
		_remote_input.clear()
		_peer_joined_at = -1.0
		say("队友断开了。\n" + _wait_note, 9999.0)


func _on_connected() -> void:
	if _waiting:
		_menu.show_text("联机", "连上了，等房主选关……")
	else:
		_peer_joined_at = sim_time


## 退出联机（单机时就是回到选模式），note 会显示在选择界面上
func _leave_online(note: String) -> void:
	if multiplayer.multiplayer_peer is ENetMultiplayerPeer:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null
	mode = ""
	net_role = ""
	level_id = ""
	menu_page = ""
	menu_note = note
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if nettest:
		print("NET left: ", note)
		get_tree().quit.call_deferred()
		return
	get_tree().reload_current_scene.call_deferred()


func _send_input() -> void:
	var p := bearers[1]
	_net_input.rpc_id(1, p.move_dir, float(p.face_yaw), p.reach_pitch, p.want_grab[0], p.want_grab[1], p.want_jump, first_person)


## 房主：把加入方的按键填到 1 号抬棺人身上；一秒没收到就当他松手站着
func _apply_remote_input() -> void:
	var b := bearers[1]
	if not _peer_present() or sim_time - _remote_input_at > 1.0:
		b.move_dir = Vector3.ZERO
		b.face_yaw = null
		b.want_grab = [false, false]
		b.want_jump = false
		return
	var r := _remote_input
	b.move_dir = r.move
	b.face_yaw = r.yaw
	b.reach_pitch = r.pitch
	b.want_grab = [r.grab_l, r.grab_r]
	b.want_jump = r.jump
	b.face_deadzone = deg_to_rad(DUO_FREE_LOOK) if r.fp and b.is_holding() else 0.0


func _send_state() -> void:
	var header := PackedFloat32Array([_gen, score.dignity, score.elapsed, cam_yaw_target, bearers[0].bend, bearers[1].bend,
		room])
	_net_state.rpc(sim_time, header, NetSync.pack(_sync_bodies()), level.net_state())


@rpc("any_peer", "call_remote", "unreliable_ordered")
func _net_input(move: Vector3, yaw: float, pitch: float, grab_l: bool, grab_r: bool, jump: bool, fp: bool) -> void:
	if not _is_host():
		return
	_remote_input = {move = move.limit_length(1.0), yaw = yaw, pitch = clampf(pitch, -1.5, 1.6),
		grab_l = grab_l, grab_r = grab_r, jump = jump, fp = fp}
	_remote_input_at = sim_time


@rpc("authority", "call_remote", "unreliable_ordered")
func _net_state(host_time: float, header: PackedFloat32Array, bodies: PackedFloat32Array, level_state: PackedFloat32Array) -> void:
	if net_role != "client" or _waiting or header.size() < 7 or int(header[0]) != _gen:
		return
	_sync.push(host_time, bodies)
	score.dignity = header[1]
	score.elapsed = header[2]
	cam_yaw_target = header[3]
	bearers[0].bend = header[4]
	bearers[1].bend = header[5]
	room = clampi(int(header[6]), 0, level.rooms.size() - 1)
	level.apply_net_state(level_state)


@rpc("authority", "call_remote", "reliable")
func _net_respawn_team(r: int) -> void:
	_respawn_team(r)


@rpc("authority", "call_remote", "reliable")
func _net_respawn_corpse() -> void:
	_respawn_corpse()


@rpc("authority", "call_remote", "reliable")
func _net_flash() -> void:
	await get_tree().create_timer(NetSync.INTERP_DELAY).timeout  # 等快照里的瞬移真的显示出来
	if first_person:
		_flash_rect(_flash_rects[0])


@rpc("authority", "call_remote", "reliable")
func _net_say(text: String, seconds: float) -> void:
	say(text, seconds)


@rpc("any_peer", "call_remote", "reliable")
func _net_rotate(dir: int) -> void:
	if _is_host():
		cam_yaw_target += 45.0 * signi(dir)


@rpc("any_peer", "call_remote", "reliable")
func _net_command(key: String) -> void:
	if _is_host() and key in ["F5", "R", "N", "M"]:
		_command(key)


## 房主换关 / 重来：加入方跟着进同一关同一间
@rpc("authority", "call_remote", "reliable")
func _net_goto(lid: String, r: int, c: Dictionary) -> void:
	level_id = lid
	start_room = r
	carry = c
	get_tree().reload_current_scene()


## 房主回选关了：加入方停下来等
@rpc("authority", "call_remote", "reliable")
func _net_wait() -> void:
	level_id = ""
	get_tree().reload_current_scene()


@rpc("authority", "call_remote", "reliable")
func _net_result(res: Dictionary, improved: bool) -> void:
	_show_result(res, improved)


# ---------- 自动测试 ----------

## 联机测试：连上后两边各自抓住棺材，转头看向 -Z，一起往前走 3 秒
func _nettest_script(p: Bearer) -> void:
	p.reach_pitch = HAND_PITCH_OFFSET
	if _peer_joined_at < 0.0:
		p.want_grab = [false, false]
		p.move_dir = Vector3.ZERO
		return
	var t := sim_time - _peer_joined_at
	p.want_grab = [t > 1.0, t > 1.0]
	if t > 1.5:
		look_yaw = lerp_angle(look_yaw, 0.0, 0.05)
		p.face_yaw = look_yaw
	p.move_dir = Vector3.FORWARD if t > 3.0 and t < 6.0 else Vector3.ZERO
	_log_timer -= get_physics_process_delta_time()
	if _log_timer <= 0.0:
		_log_timer = 0.5
		print("NET %s t=%.1f coffin=%s tilt=%.0f b0=%s b1=%s held=%s max_step=%.3f" % [net_role, t,
			coffin.global_position.snapped(Vector3.ONE * 0.01), rad_to_deg(coffin.global_basis.y.angle_to(Vector3.UP)),
			bearers[0].global_position.snapped(Vector3.ONE * 0.01), bearers[1].global_position.snapped(Vector3.ONE * 0.01),
			bearers.map(func(b): return b.holds(coffin)), _max_step])
		_max_step = 0.0


## 自动测试：两个抬棺人一起抓住棺材，沿关卡的房间路线走，走完就把棺材放低松手（应该落在灵台上）
func _drive_bot() -> void:
	var t := sim_time
	for b in bearers:
		b.want_grab = [t > 0.5, t > 0.5]
		b.move_dir = Vector3.ZERO
		b.face_yaw = null
		b.reach_pitch = HAND_PITCH_OFFSET
		# 棺材在地上（检查点重生）时：面朝棺材、凑近一点、弯腰去够，抓住了再抬到胸口
		if coffin.global_position.y < b.global_position.y - 0.4 and not b.holds(coffin) and t > 0.5:
			var to := coffin.global_position - b.global_position
			to.y = 0
			b.face_yaw = atan2(-to.x, -to.z)
			b.move_dir = to.normalized() * 0.4 if to.length() > 0.6 else Vector3.ZERO
			b.reach_pitch = -1.1
	if lonetest:
		bearers[1].want_grab = [false, false]
	if t < 2.0 + bot_delay:
		return
	_log_timer -= get_physics_process_delta_time()
	if _log_timer <= 0.0:
		_log_timer = 1.0
		_bot_log(t)
	if _bot_wp >= _bot_path.size():
		if _room_test >= 0 and _room_test < level.rooms.size() - 1:
			return  # 只测一间：停在原地，等超时判失败（最后一间则照常放上灵台）
		_bot_lower_timer += get_physics_process_delta_time()
		for b in bearers:
			b.reach_pitch = -0.4  # 先把棺材放低，再松手
			b.want_grab = [_bot_lower_timer < 1.5, _bot_lower_timer < 1.5]
		return
	if not bearers.all(func(b): return b.holds(coffin) or (lonetest and b == bearers[1])):
		return  # 等两个人都抓稳了再走
	if _bot_wp == bot_stopat:
		return
	var wp: Variant = _bot_path[_bot_wp]
	var dir := Vector3.ZERO
	if wp is String:
		if bot_nowait or level.bot_can_go(wp.trim_prefix("wait:")):
			_bot_wp += 1
	elif wp is Dictionary:
		if level.bot_can_go(wp.until):
			_bot_wp += 1
		else:
			dir = wp.dir
	else:
		var to: Vector3 = wp - coffin.global_position
		to.y = 0
		if to.length() < 0.5:
			_bot_wp += 1
		else:
			dir = to.normalized()
	for b in bearers:
		b.move_dir = dir


## 双人测试：两人一起抓住棺材，各自转头看向前进方向（-Z），往前走
func _duotest_script() -> void:
	var t := sim_time
	var walk := t > 2.0 and t < 4.5
	for i in 2:
		var b := bearers[i]
		b.want_grab = [t > 0.5, t > 0.5]
		b.move_dir = Vector3.FORWARD if walk else Vector3.ZERO
	if t > 1.0:
		look_yaw = lerp_angle(look_yaw, 0.0, 0.05)
		p2_yaw = lerp_angle(p2_yaw, 0.0, 0.05)
		bearers[0].face_yaw = look_yaw
		bearers[1].face_yaw = p2_yaw
	_log_timer -= get_physics_process_delta_time()
	if _log_timer <= 0.0:
		_log_timer = 0.5
		for b in bearers:
			print("DUO t=%.1f pos=%s vel=%s grab=%s held=%s move=%s hands=%s" % [t, b.global_position.snapped(Vector3.ONE * 0.01),
				b.linear_velocity.snapped(Vector3.ONE * 0.01), b.want_grab, b.held.map(func(x): return x != null), b.move_dir,
				b.hands.map(func(h): return h.global_position.snapped(Vector3.ONE * 0.01))])


func _solotest_script(p: Bearer) -> void:
	var t := sim_time
	var grab := (t > 0.5 and t < 6.0) or t > 8.0
	p.want_grab = [grab, grab]
	p.move_dir = Vector3.ZERO
	look_pitch = 0.0
	if t > 2.5 and t < 3.4:  # 走得短一点，扔和捡都在停棺间里（走廊里有台阶和湿地板）
		if first_person:
			look_yaw = lerp_angle(look_yaw, atan2(1.0, 0.8), 0.05)  # 转头看向行走方向
		p.move_dir = Vector3(0, 0, -1)  # 往灵台方向横着走
	elif t > 6.5 and t < 9.5:
		look_pitch = -1.45  # 低头弯腰去够地上的棺材
	elif t > 11.0 and t < 12.0:
		p.move_dir = Vector3(0, 0, -1)
	elif t > 13.5 and t < 16.0 and not first_person:
		look_yaw = wrapf(look_yaw + 1.0 * get_physics_process_delta_time(), -PI, PI)  # 原地转身，看棺材会不会跟着转
	_log_timer -= get_physics_process_delta_time()
	if _log_timer <= 0.0:
		_log_timer = 0.5
		var partner := bearers[1]
		print("    coffin_yaw=%.0f" % rad_to_deg(atan2(coffin.global_basis.x.z, coffin.global_basis.x.x)))
		print("SOLO t=%.1f coffin_y=%.2f coffin=%s pitch=%.2f bend=%.2f p_hold=%s partner_hold=%s partner_pos=%s p_hands_y=%s" % [
			t, coffin.global_position.y, coffin.global_position.snapped(Vector3.ONE * 0.01), look_pitch, p.bend,
			p.holds(coffin), partner.holds(coffin), partner.global_position.snapped(Vector3.ONE * 0.01),
			p.hands.map(func(h): return snappedf(h.global_position.y, 0.01))])
		print("    held=%s p_pos=%s hands=%s" % [p.held.map(func(x): return x.name if x else null), p.global_position.snapped(Vector3.ONE * 0.01), p.hands.map(func(h): return coffin.to_local(h.global_position).snapped(Vector3.ONE * 0.01))])


func _bot_log(t: float) -> void:
	print("BOT wp=%d/%d room=%d t=%.1f coffin=%s tilt=%.0f dignity=%d corpse_out=%s holding=%s b1=%s" % [
		_bot_wp, _bot_path.size(), room, t, coffin.global_position.snapped(Vector3.ONE * 0.01),
		rad_to_deg(coffin.global_basis.y.angle_to(Vector3.UP)), int(score.dignity), score.corpse_out,
		bearers.map(func(b): return b.grabs.map(func(g): return g != null)), bearers[1].global_position.snapped(Vector3.ONE * 0.01)])
	var extra := level.debug_text()
	if extra:
		print("    ", extra)


func _finish_run() -> void:
	print("RESULT level=%s room=%d coffin=%s dignity=%d corpse_out=%s started=%s finished=%s" % [
		level.id, room, coffin.global_position.snapped(Vector3.ONE * 0.01), int(score.dignity), score.corpse_out,
		started, finished])
	if shot_path != "":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(shot_path)
		print("SHOT ", shot_path)
	get_tree().quit()


# ---------- 场景搭建 ----------

func _build_environment(overrides: Dictionary) -> void:
	var e := ENV_DEFAULT.duplicate()
	e.merge(overrides, true)
	# 默认是黄昏：头顶蓝紫、地平线暖橘，往下是一片暗紫的雾海，建筑像悬在晚霞里
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = e.sky_top
	sky_mat.sky_horizon_color = e.sky_horizon
	sky_mat.sky_curve = e.sky_curve
	sky_mat.ground_horizon_color = e.ground_horizon
	sky_mat.ground_bottom_color = e.ground_bottom
	sky_mat.ground_curve = e.ground_curve
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = e.ambient
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = e.exposure
	env.ssao_enabled = true
	env.ssao_radius = 0.8
	env.ssao_intensity = 1.6
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.glow_hdr_threshold = 1.2
	# 雾：整体一层很淡的薄雾，越往下越浓，深渊里的东西渐渐隐掉
	env.fog_enabled = true
	env.fog_light_color = e.fog_color
	env.fog_density = e.fog_density
	env.fog_sky_affect = 0.0
	env.fog_height = e.fog_height
	env.fog_height_density = e.fog_height_density
	env.adjustment_enabled = true
	env.adjustment_saturation = e.saturation
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = e.sun_rot
	sun.light_color = e.sun_color
	sun.light_energy = e.sun_energy
	sun.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY  # 天空里不画太阳（俯视时会变成一道白光）
	sun.shadow_enabled = true
	sun.shadow_blur = 1.5
	sun.directional_shadow_max_distance = 60.0
	add_child(sun)


func _build_hud() -> void:
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei", "SimHei", "Noto Sans CJK SC"])
	var theme := Theme.new()
	theme.default_font = font
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = theme
	var layer := CanvasLayer.new()
	add_child(layer)
	layer.add_child(root)

	hud = _label(root, 30, Vector2(24, 16))
	status = _label(root, 40, Vector2.ZERO)
	status.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	status.offset_top = 90
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help = _label(root, 18, Vector2.ZERO)
	help.anchor_top = 1.0
	help.anchor_bottom = 1.0
	help.offset_left = 24
	help.offset_top = -76
	# 准星：第一人称时帮你看清自己在往哪儿够
	var dot := _label(root, 28, Vector2.ZERO)
	dot.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	dot.text = "·"
	dot.visible = false
	_crosshair = dot
	if mode == "duo":
		_build_split(root)
	else:
		_flash_rects.append(_flash_overlay(root))
	_menu = Menu.new()
	root.add_child(_menu)
	_menu.start.connect(_on_menu_start)
	_menu.join.connect(_on_menu_join)
	_menu.result_key.connect(_command)
	if mode != "" and not _waiting:
		say("第 %d 间 · %s\n抓住棺材把手，一路抬到灵台" % [room + 1, level.rooms[room].name], 5.0)


## 双人分屏：左右两块 SubViewport，共用同一个 3D 世界，各放一个第一人称镜头
func _build_split(root: Control) -> void:
	_split = HBoxContainer.new()
	_split.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_split.add_theme_constant_override("separation", 4)
	_split.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_split)
	root.move_child(_split, 0)  # 放在最底层，HUD 文字盖在上面
	for i in 2:
		var panel := Control.new()
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_split.add_child(panel)
		var svc := SubViewportContainer.new()
		svc.stretch = true
		svc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		svc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(svc)
		var sv := SubViewport.new()
		sv.msaa_3d = Viewport.MSAA_2X
		svc.add_child(sv)
		var cam := Camera3D.new()
		cam.fov = 75
		cam.near = 0.05
		cam.cull_mask = Bearer.fp_cull_mask(i)
		sv.add_child(cam)
		cam_split.append(cam)
		_flash_rects.append(_flash_overlay(panel))
		var tag := _label(panel, 22, Vector2(16, 64))
		tag.text = "P1（键鼠）" if i == 0 else "P2（方向键）"
		var dot := _label(panel, 28, Vector2.ZERO)
		dot.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		dot.text = "·"


func _flash_overlay(parent: Control) -> ColorRect:
	var r := ColorRect.new()
	r.color = Color(1, 1, 1, 0)
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(r)
	return r


func _label(parent: Control, size: int, pos: Vector2) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color.WHITE)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 8)
	l.position = pos
	parent.add_child(l)
	return l
