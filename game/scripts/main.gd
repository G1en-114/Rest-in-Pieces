extends Node3D
## 抬棺原型（第 1 阶段）：把棺材从起点的架子上抬起来，送到远处的灵台。
##
## 三种玩法（开局按 1 / 2 / 3 / 4 选择，F5 重来时保留）：
##   单人：键鼠控制一个抬棺人，另一个是电脑队友，跟着你抓、跟着你走
##   双人：P1 用键鼠，P2 用键盘右侧；默认左右分屏各自第一人称（像《双人成行》）
##   联机：每人一台电脑。房主（3）计算全部物理；加入的人（4）只发按键，收到位置后插值显示
## 两种镜头：第一人称和固定俯视视角（Q/E 旋转 45°，滚轮缩放，过视错觉断桥要用它）。
## 单人按 V 切换；双人按 V 或 Enter，两人一起在“分屏第一人称”和“共享俯视”之间切换。
##
## 命令行参数（放在 `--` 之后）：
##   --bot          两个抬棺人自动抓住棺材往灵台走（测试物理用）
##   --lonetest     同上，但 2 号空着手自己过断桥（测试单人过桥不掉下去）
##   --solotest     单人模式自动测试：抓起 → 走 → 扔到地上 → 弯腰捡起 → 再抬起来
##   --solo / --fp  直接进入单人模式 / 并切到第一人称（放在 --join 后面则是联机加入方用第一人称）
##   --atbridge     整队直接出生在断桥前
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
const DUO_FREE_LOOK := 180.0  # 双人分屏：抓着东西时随便转头，棺材靠两人走位来转  # 第一人称抓着东西时，转头这么多度以内身体不跟着转
const FP_EYE_HEIGHT := 0.8
const GOAL := Level1.GOAL
const COFFIN_START := Level1.COFFIN_START
const ORTHO_SIZE := 15.0

static var mode := ""  # "solo" | "duo" | "online"，重来时保留
static var net_role := ""  # 联机时："host" | "client"
static var join_ip := "127.0.0.1"
static var menu_note := ""  # 回到选择界面时顺便提示一句（比如断线了）

var level: Level1
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

var first_person := false
var cam_yaw := 45.0
var cam_yaw_target := 45.0
var zoom := 1.0
var look_yaw := 0.0
var look_pitch := 0.0
var p2_yaw := PI
var p2_pitch := 0.0

var dignity := 100.0
var elapsed := 0.0
var started := false
var finished := false
var corpse_out := false
var goal_timer := 0.0
var status_timer := 0.0

var _partner_formed := false
var _partner_offset := Vector3.ZERO
var _coffin_prev_vel := Vector3.ZERO
var _coffin_falling := false
var _bridge_aligned := false
var _checkpoint := Level1.CHECKPOINT_UPPER
var _bot_wp := 0
var _bot_lower_timer := 0.0
var _altar_hint_shown := false

var bot := false
var solotest := false
var _force_topdown := false
var duotest := false
var atbridge := false  # 测试用：整队直接出生在断桥前（上层检查点），面朝桥
var lonetest := false  # 测试用：2 号抬棺人不抓棺材，空着手自己走过断桥（不该掉下去）
var bot_noalign := false  # 测试用：不转视角直接走上断桥（应该掉下去）
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
var _ip_edit: LineEdit
var _wait_note := ""
var _max_step := 0.0  # --nettest：加入方画面里棺材每帧最大位移，用来看有没有瞬移
var _last_coffin_pos := Vector3.ZERO
var _flash_rects: Array[ColorRect] = []  # 过桥闪白：全屏一块；双人分屏时左右各一块

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg == "--bot":
			bot = true
		elif arg == "--noalign":
			bot_noalign = true
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
		elif arg == "--nettest":
			nettest = true
		elif arg.begins_with("--camyaw="):
			cam_yaw_target = float(arg.get_slice("=", 1))
		elif arg.begins_with("--quit="):
			quit_at = float(arg.get_slice("=", 1))
		elif arg.begins_with("--shot="):
			shot_path = arg.get_slice("=", 1)

	_build_environment()
	level = Level1.new()
	add_child(level)
	if net_role != "client":  # 加入方的分数和提示都由房主发过来
		level.bonus.connect(func(amount: float, text: String) -> void:
			dignity += amount
			_say(text))
		level.notice.connect(_say)
	if atbridge:
		_spawn_team(Level1.CHECKPOINT_UPPER + Vector3(0, 0.24, 0), 0.0)
	else:
		_spawn_team(COFFIN_START, 0.0)

	cam_fixed = Camera3D.new()
	cam_fixed.projection = Camera3D.PROJECTION_ORTHOGONAL  # 正交投影：纪念碑谷式的视错觉只在正交下严格成立
	cam_fixed.size = ORTHO_SIZE
	cam_fixed.far = 200.0
	for layer in Bearer.HAND_LAYERS:
		cam_fixed.cull_mask &= ~(1 << (layer - 1))
	cam_fixed.cull_mask &= ~(1 << (Level1.HINT_LAYER - 1))
	_fixed_mask = cam_fixed.cull_mask
	add_child(cam_fixed)
	cam_fixed.global_position = COFFIN_START + _cam_offset()
	cam_fixed.look_at(COFFIN_START)
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
	if mode == "" and not bot:
		_say("按 1：单人模式（电脑队友帮你抬）\n按 2：双人模式（两人共用键盘）\n"
			+ "按 3：联机建房间（你当房主）\n按 4：联机加入房间" + ("\n\n" + menu_note if menu_note else ""), 9999.0)
		menu_note = ""


## 生成整队：棺材 + 逝者 + 两个抬棺人（站在棺材两侧）。floor_y 是脚下地面的高度
func _spawn_team(coffin_pos: Vector3, floor_y: float) -> void:
	coffin = Coffin.new()
	coffin.position = coffin_pos
	add_child(coffin)
	coffin.body_entered.connect(_on_coffin_hit)
	corpse = Corpse.new()
	corpse.position = coffin_pos
	add_child(corpse)
	_spawn_bearer(Vector3(coffin_pos.x, floor_y + 0.9, coffin_pos.z + 0.85), 0.0)
	_spawn_bearer(Vector3(coffin_pos.x, floor_y + 0.9, coffin_pos.z - 0.85), PI)
	if mode == "solo":
		bearers[0].set_first_person_owner(0)
	elif mode == "duo":
		bearers[0].set_first_person_owner(0)
		bearers[1].set_first_person_owner(1)
	elif mode == "online":
		bearers[_me()].set_first_person_owner(_me())
		if net_role == "client":
			_make_puppets()


## 掉进深渊后在检查点重来：棺材放在地上，要自己弯腰捡起来
func _respawn_team(cp: Vector3) -> void:
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
	corpse_out = false
	_spawn_team(cp + Vector3(0, 0.24, 0), cp.y)
	_bump_gen()
	if _is_host():
		_net_respawn_team.rpc(cp)


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


func _team_bodies() -> Array[RigidBody3D]:
	var list: Array[RigidBody3D] = [coffin]
	list.append_array(corpse.parts)
	for b in bearers:
		list.append(b)
		list.append_array(b.hands)
	return list


## 断桥（“信任之桥”）：有人俯视、并且视角转对了，幽灵地面就打开；之后只要还有人站在接缝上，
## 桥就锁住不断，免得俯视的人一转视角把队友摔下去。
## 谁走过接缝，就把谁连同他抓着的东西一起平移到另一段桥上。平移方向正好沿着俯视的视线，
## 所以俯视画面上看不出任何跳动；第一人称看到的永远是断桥，过桥时闪一下白光遮住瞬移。
func _update_level() -> void:
	# 联机时只要有一个人在俯视、并且视角转对了，桥就接上
	var someone_topdown: bool = not first_person or (_peer_present() and not _remote_input.get("fp", true))
	var view_ok := someone_topdown and absf(wrapf(cam_yaw - Level1.ALIGN_YAW, -180.0, 180.0)) < 6.0
	var locked := _bridge_aligned and _team_bodies().any(func(b): return Level1.on_ghost(b.global_position))
	var aligned := view_ok or locked
	if aligned != _bridge_aligned:
		_bridge_aligned = aligned
		level.set_bridge(aligned)
		if aligned and coffin.global_position.y > -2.0:
			_say("咔哒——桥接上了！" + ("" if mode == "solo" else "
第一人称的人：踩着金色虚线往虚空里走"))
	if aligned:
		for group in _move_groups():
			var ref: RigidBody3D = group[0]
			var p := ref.global_position
			var d := Vector3.ZERO
			if p.y > -2.0 and p.x < Level1.SEAM_X:
				d = Level1.BRIDGE_OFFSET
			elif p.y <= -2.0 and p.x > Level1.SEAM_X + Level1.BRIDGE_OFFSET.x:
				d = -Level1.BRIDGE_OFFSET
			if d == Vector3.ZERO:
				continue
			for body in group:
				body.global_position += d
			if ref == coffin:
				_checkpoint = Level1.CHECKPOINT_LOWER if d.y < 0.0 else Level1.CHECKPOINT_UPPER
			for i in bearers.size():
				if bearers[i] in group:
					_flash(i)

	var c := coffin.global_position

	if c.y < Level1.KILL_Y or bearers.any(func(b): return b.global_position.y < Level1.KILL_Y):
		dignity -= 30.0
		_say("整队掉进了深渊！体面 -30
从检查点重来")
		_respawn_team(_checkpoint)
	elif corpse.torso.global_position.y < Level1.KILL_Y:
		dignity -= 10.0
		_say("逝者掉进了深渊……又被送回来了。体面 -10")
		_respawn_corpse()


## 过桥时要一起平移的几组刚体：抓在一起的必须一起走，不然关节会把人扯飞。
## 起步是棺材、逝者、每个抬棺人（连同两只手）各一组；谁抓着谁就并成一组，躺在棺材里的逝者跟棺材一组。
## 每组第一个刚体是判断过没过接缝的参照（有棺材时就是棺材）。
func _move_groups() -> Array:
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


## 第 player 号玩家过桥瞬移了：第一人称就闪一下白光
func _flash(player: int) -> void:
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


# ---------- 输入 ----------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		look_yaw = wrapf(look_yaw - event.relative.x * MOUSE_SENS, -PI, PI)
		look_pitch = clampf(look_pitch - event.relative.y * MOUSE_SENS, -1.5, 1.2)
	elif event is InputEventMouseButton and event.pressed:
		if mode != "" and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom = clampf(zoom - 0.1, 0.5, 1.8)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom = clampf(zoom + 0.1, 0.5, 1.8)
	elif event is InputEventKey and event.pressed and not event.echo:
		var key: Key = event.physical_keycode
		if mode == "" and key in [KEY_1, KEY_KP_1, KEY_2, KEY_KP_2]:
			mode = "solo" if key in [KEY_1, KEY_KP_1] else "duo"
			get_tree().reload_current_scene()
		elif mode == "" and key in [KEY_3, KEY_KP_3]:
			mode = "online"
			net_role = "host"
			get_tree().reload_current_scene()
		elif _ip_edit != null and key == KEY_ESCAPE:
			get_tree().reload_current_scene()
		elif mode == "" and key in [KEY_4, KEY_KP_4] and _ip_edit == null:
			get_viewport().set_input_as_handled()
			_show_ip_edit()
		elif key in [KEY_F5, KEY_BACKSPACE]:
			if net_role == "client":
				_net_request_restart.rpc_id(1)
			else:
				_restart()
		elif key == KEY_F1:
			_leave_online("")
		elif key == KEY_ESCAPE:
			if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			else:
				get_tree().quit()
		elif mode != "" and (key == KEY_V or (mode == "duo" and key in [KEY_ENTER, KEY_KP_ENTER])):
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
		_say("抓住了！抬到灵台去")
	if not started:
		return
	elapsed += delta

	# 棺材歪得越厉害，掉分越快
	var tilt := rad_to_deg(coffin.global_basis.y.angle_to(Vector3.UP))
	if tilt > 20.0:
		dignity -= delta * 6.0 * tilt / 20.0

	var inside := coffin.contains(corpse.torso.global_position)
	if not inside and not corpse_out:
		corpse_out = true
		dignity -= 20.0
		_say("逝者掉出来了！体面 -20
往下看、弯腰把他捡回去")
	elif inside and corpse_out:
		corpse_out = false
		_say("塞回去了，继续")
	# 没人抓着、棺材在往下掉 → 等它落停就扣分
	var held := bearers.any(func(b): return b.holds(coffin))
	if not held and coffin.linear_velocity.y < -3.0:
		_coffin_falling = true
	elif _coffin_falling and (held or absf(coffin.linear_velocity.y) < 0.3):
		_coffin_falling = false
		if not held:
			dignity -= 15.0
			_say("棺材摔地上了！体面 -15")
	_coffin_prev_vel = coffin.linear_velocity

	if on_altar_xz() and held and not _altar_hint_shown:
		_altar_hint_shown = true
		_say("到灵台了！往下看把棺材放低，再轻轻松手", 4.0)

	# 棺材稳稳停在灵台上 1.5 秒算送达
	var on_altar := on_altar_xz()
	if on_altar and inside and coffin.linear_velocity.length() < 0.3 and tilt < 15.0:
		goal_timer += delta
		if goal_timer > 1.5:
			finished = true
			_say("送达！体面值 %d，用时 %.1f 秒\n按 F5 再来一局" % [int(dignity), elapsed], 9999.0)
	else:
		goal_timer = 0.0


func on_altar_xz() -> bool:
	return Vector2(coffin.global_position.x - GOAL.x, coffin.global_position.z - GOAL.z).length() < 1.4


func _on_coffin_hit(body: Node) -> void:
	if started and not finished and body is StaticBody3D and body.is_in_group("hard") \
			and coffin.linear_velocity.length() > 1.2:
		dignity -= 5.0
		_say("砰！")


func _say(text: String, seconds := 2.5) -> void:
	if _peer_present():
		_net_say.rpc(text, seconds)
	if bot or solotest or nettest:
		print("SAY ", text.replace("
", " "))
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
	if mode == "solo":
		help.text = "WASD 移动 · 鼠标 看 / 控制手的高度（往下看就弯腰去够）· 左键 / 右键 左右手抓（按住）· 空格 跳\n" \
			+ "V 切换第一人称 / 固定视角 · Q / E 旋转固定视角 · 滚轮 缩放 · F5 重来 · F1 换模式 · Esc 释放鼠标 / 退出"
	elif mode == "duo":
		help.text = "P1：WASD + 鼠标 · 左键 / 右键 抓 · 空格 跳 · Q / E 转俯视视角　　" \
			+ "P2：↑↓ 走 · ←→ 转身（俯视时为平移）· ' / ; 抬头 / 低头 · , / . 抓 · / 跳\n" \
			+ "V 或 Enter：分屏第一人称 ⇄ 共享俯视（过断桥要俯视）· 滚轮 缩放 · F5 重来 · F1 换模式 · Esc 释放鼠标 / 退出"
	elif mode == "online":
		help.text = "WASD 移动 · 鼠标 看 / 控制手的高度 · 左键 / 右键 左右手抓（按住）· 空格 跳\n" \
			+ "V 切换第一人称 / 俯视（俯视视角大家共用，有人俯视并转对角度桥才接上）· Q / E 旋转 · F5 重来 · F1 退出联机"
	else:
		help.text = ""


func _place_fp_camera(cam: Camera3D, b: Bearer, yaw: float, pitch: float) -> void:
	var view := Basis.from_euler(Vector3(pitch, yaw, 0))
	cam.global_transform = Transform3D(view, b.to_global(Vector3(0, FP_EYE_HEIGHT, 0)) + Basis(Vector3.UP, yaw) * Vector3(0, 0, -0.12))


func _process(delta: float) -> void:
	if net_role == "client":
		_sync.apply(_team_bodies())
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

	hud.text = "体面值 %d    用时 %.1f 秒" % [roundi(dignity), elapsed]
	hud.add_theme_color_override("font_color", Color(1, 0.35, 0.3) if dignity < 0.0 else Color.WHITE)
	status_timer -= delta
	status.modulate.a = clampf(status_timer, 0.0, 1.0)

	if quit_at >= 0.0 and sim_time > quit_at:
		quit_at = -1.0
		_finish_run()


# ---------- 联机 ----------
# 房主权威：房主的电脑算全部物理和规则，30 次/秒把整队刚体的位置发给加入方；
# 加入方的身体都是冻住的“傀儡”，只负责显示，自己的键鼠意图 60 次/秒发给房主。
# 房主固定控制 0 号抬棺人，加入方控制 1 号。

## 本机玩家控制第几个抬棺人
func _me() -> int:
	return 1 if mode == "online" and net_role == "client" else 0


func _is_host() -> bool:
	return mode == "online" and net_role == "host"


func _connected() -> bool:
	var peer := multiplayer.multiplayer_peer
	return peer is ENetMultiplayerPeer and peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED


## 房主这边：队友在不在
func _peer_present() -> bool:
	return _is_host() and _connected() and not multiplayer.get_peers().is_empty()


func _bump_gen() -> void:
	_gen += 1
	_sync.clear()


## 加入方：整队都不算物理，只等快照来摆位置
func _make_puppets() -> void:
	for body in _team_bodies():
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
			_say(_wait_note, 9999.0)
		else:
			_peer_joined_at = 0.0  # F5 重来，队友还在
	elif _connected():
		_peer_joined_at = 0.0
	else:
		_say("正在连接 %s ……" % join_ip, 9999.0)


func _local_ips() -> String:
	var ips: Array[String] = []
	for a in IP.get_local_addresses():
		if a.contains(".") and not a.begins_with("127.") and not a.begins_with("169.254."):
			ips.append(a)
	return " 或 ".join(ips) if ips else "（没找到网卡地址）"


func _on_peer_connected(_id: int) -> void:
	if _is_host():
		_peer_joined_at = sim_time
		_say("队友加入了！一起抬吧")


func _on_peer_disconnected(_id: int) -> void:
	if _is_host():
		_remote_input.clear()
		_peer_joined_at = -1.0
		_say("队友断开了。\n" + _wait_note, 9999.0)


func _on_connected() -> void:
	_peer_joined_at = sim_time
	_say("连上了！抓住棺材把手，一起抬到灵台")


## 退出联机，回到选择界面（note 会显示在选择界面上）
func _leave_online(note: String) -> void:
	if multiplayer.multiplayer_peer is ENetMultiplayerPeer:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null
	mode = ""
	net_role = ""
	menu_note = note
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if nettest:
		print("NET left: ", note)
		get_tree().quit.call_deferred()
		return
	get_tree().reload_current_scene.call_deferred()


func _restart() -> void:
	if _peer_present():
		_net_restart.rpc()
	get_tree().reload_current_scene()


func _show_ip_edit() -> void:
	_ip_edit = LineEdit.new()
	_ip_edit.text = join_ip
	_ip_edit.placeholder_text = "房主的 IP"
	_ip_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ip_edit.custom_minimum_size = Vector2(380, 0)
	_ip_edit.add_theme_font_size_override("font_size", 30)
	status.get_parent().add_child(_ip_edit)
	_ip_edit.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_ip_edit.position.y += 120
	_ip_edit.grab_focus()
	_ip_edit.select_all()
	_ip_edit.text_submitted.connect(func(text: String) -> void:
		join_ip = text.strip_edges()
		mode = "online"
		net_role = "client"
		get_tree().reload_current_scene())
	_say("输入房主的 IP，按 Enter 加入（Esc 返回）", 9999.0)


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
	var header := PackedFloat32Array([_gen, dignity, elapsed, cam_yaw_target, bearers[0].bend, bearers[1].bend,
		1.0 if _bridge_aligned else 0.0])
	_net_state.rpc(sim_time, header, NetSync.pack(_team_bodies()))


@rpc("any_peer", "call_remote", "unreliable_ordered")
func _net_input(move: Vector3, yaw: float, pitch: float, grab_l: bool, grab_r: bool, jump: bool, fp: bool) -> void:
	if not _is_host():
		return
	_remote_input = {move = move.limit_length(1.0), yaw = yaw, pitch = clampf(pitch, -1.5, 1.6),
		grab_l = grab_l, grab_r = grab_r, jump = jump, fp = fp}
	_remote_input_at = sim_time


@rpc("authority", "call_remote", "unreliable_ordered")
func _net_state(host_time: float, header: PackedFloat32Array, bodies: PackedFloat32Array) -> void:
	if net_role != "client" or header.size() < 7 or int(header[0]) != _gen:
		return
	_sync.push(host_time, bodies)
	dignity = header[1]
	elapsed = header[2]
	cam_yaw_target = header[3]
	bearers[0].bend = header[4]
	bearers[1].bend = header[5]
	if (header[6] > 0.5) != _bridge_aligned:
		_bridge_aligned = header[6] > 0.5
		level.set_bridge(_bridge_aligned)  # 加入方要看得见第一人称的虚线提示


@rpc("authority", "call_remote", "reliable")
func _net_respawn_team(cp: Vector3) -> void:
	_respawn_team(cp)


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
	_say(text, seconds)


@rpc("any_peer", "call_remote", "reliable")
func _net_rotate(dir: int) -> void:
	if _is_host():
		cam_yaw_target += 45.0 * signi(dir)


@rpc("any_peer", "call_remote", "reliable")
func _net_request_restart() -> void:
	if _is_host():
		_restart()


@rpc("authority", "call_remote", "reliable")
func _net_restart() -> void:
	get_tree().reload_current_scene()


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

## 自动测试：两个抬棺人一起抓住棺材，沿关卡路线走；到断桥前转视角，过桥，送上灵台
func _drive_bot() -> void:
	var t := sim_time
	for b in bearers:
		b.want_grab = [t > 0.5, t > 0.5]
		b.move_dir = Vector3.ZERO
		b.face_yaw = null
		b.reach_pitch = HAND_PITCH_OFFSET
	if lonetest:
		bearers[1].want_grab = [false, false]
	if t < 2.0:
		return
	_log_timer -= get_physics_process_delta_time()
	if _log_timer <= 0.0:
		_log_timer = 1.0
		_bot_log(t)
	if _bot_wp >= Level1.BOT_PATH.size():
		_bot_lower_timer += get_physics_process_delta_time()
		for b in bearers:
			b.reach_pitch = -0.4  # 先把棺材放低，再松手
			b.want_grab = [_bot_lower_timer < 1.5, _bot_lower_timer < 1.5]
		return
	var wp: Variant = Level1.BOT_PATH[_bot_wp]
	var dir := Vector3.ZERO
	if wp is String and wp == "align":
		if not bot_noalign:
			cam_yaw_target = Level1.ALIGN_YAW
		if _bridge_aligned or bot_noalign:
			_bot_wp += 1
	elif wp is String and wp == "trolley":
		if level.trolley_safe():
			_bot_wp += 1
	elif wp is String and wp == "cross":
		if coffin.global_position.y < -2.0:
			_bot_wp += 1
		else:
			dir = Vector3.LEFT
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
	print("BOT wp=%d aligned=%s t=%.1f coffin=%s tilt=%.0f dignity=%d corpse_out=%s holding=%s b1=%s" % [
		_bot_wp, _bridge_aligned, t, coffin.global_position.snapped(Vector3.ONE * 0.01),
		rad_to_deg(coffin.global_basis.y.angle_to(Vector3.UP)), int(dignity), corpse_out,
		bearers.map(func(b): return b.grabs.map(func(g): return g != null)), bearers[1].global_position.snapped(Vector3.ONE * 0.01)])


func _finish_run() -> void:
	print("RESULT coffin=%s dignity=%d corpse_out=%s started=%s finished=%s" % [
		coffin.global_position.snapped(Vector3.ONE * 0.01), int(dignity), corpse_out, started, finished])
	if shot_path != "":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(shot_path)
		print("SHOT ", shot_path)
	get_tree().quit()


# ---------- 场景搭建 ----------

func _build_environment() -> void:
	# 黄昏：头顶蓝紫、地平线暖橘，往下是一片暗紫的雾海，建筑像悬在晚霞里
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.3, 0.33, 0.55)
	sky_mat.sky_horizon_color = Color(0.98, 0.72, 0.56)
	sky_mat.sky_curve = 0.12
	sky_mat.ground_horizon_color = Color(0.92, 0.66, 0.56)
	sky_mat.ground_bottom_color = Color(0.36, 0.3, 0.42)
	sky_mat.ground_curve = 0.06
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.75
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.05
	env.ssao_enabled = true
	env.ssao_radius = 0.8
	env.ssao_intensity = 1.6
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.glow_hdr_threshold = 1.2
	# 雾：整体一层很淡的暖色薄雾，越往下越浓，深渊里的桥墩和小岛渐渐隐掉
	env.fog_enabled = true
	env.fog_light_color = Color(0.86, 0.66, 0.62)
	env.fog_density = 0.004
	env.fog_sky_affect = 0.0
	env.fog_height = -3.0
	env.fog_height_density = 0.12
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.08
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, -35, 0)
	sun.light_color = Color(1.0, 0.86, 0.7)
	sun.light_energy = 1.25
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
	if mode != "":
		_say("抓住棺材把手，把棺材抬到远处有蜡烛的灵台上", 5.0)



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
