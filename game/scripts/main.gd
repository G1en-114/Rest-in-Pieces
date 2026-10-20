extends Node3D
## 抬棺原型（第 1 阶段）：把棺材从起点的架子上抬起来，送到远处的灵台。
##
## 两种玩法（开局按 1 / 2 选择，F5 重来时保留）：
##   单人：键鼠控制一个抬棺人，另一个是电脑队友，跟着你抓、跟着你走
##   双人：两人共用一个键盘
## 两种镜头：固定视角（Q/E 旋转 45°，滚轮缩放，为视错觉关卡准备）和第一人称，单人模式按 V 切换。
##
## 命令行参数（放在 `--` 之后）：
##   --bot          两个抬棺人自动抓住棺材往灵台走（测试物理用）
##   --solotest     单人模式自动测试：抓起 → 走 → 扔到地上 → 弯腰捡起 → 再抬起来
##   --solo / --fp  直接进入单人模式 / 并切到第一人称
##   --quit=秒      到时间自动退出
##   --shot=路径    退出前截一张图

const P1_KEYS := {
	"up": [KEY_W], "down": [KEY_S], "left": [KEY_A], "right": [KEY_D],
	"grab_l": [KEY_Q], "grab_r": [KEY_E], "jump": [KEY_SPACE],
	"reach_up": [KEY_R], "reach_down": [KEY_F],
}
const P2_KEYS := {
	"up": [KEY_UP], "down": [KEY_DOWN], "left": [KEY_LEFT], "right": [KEY_RIGHT],
	"grab_l": [KEY_COMMA, KEY_KP_1], "grab_r": [KEY_PERIOD, KEY_KP_3], "jump": [KEY_SLASH, KEY_KP_0],
	"reach_up": [KEY_APOSTROPHE, KEY_KP_8], "reach_down": [KEY_SEMICOLON, KEY_KP_2],
}
const CAM_DIST := 8.5
const CAM_HEIGHT := 7.5
const MOUSE_SENS := 0.0025
const HAND_PITCH_OFFSET := 0.35  # 平视时手的仰角：大约举在胸口
const FP_FREE_LOOK := 95.0  # 第一人称抓着东西时，转头这么多度以内身体不跟着转
const FP_EYE_HEIGHT := 0.8
const GOAL := Level1.GOAL
const COFFIN_START := Level1.COFFIN_START
const ORTHO_SIZE := 15.0

static var mode := ""  # "solo" | "duo"，重来时保留

var level: Level1
var bearers: Array[Bearer] = []
var coffin: Coffin
var corpse: Corpse
var cam_fixed: Camera3D
var cam_fp: Camera3D
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
var duo_pitch: Array[float] = [HAND_PITCH_OFFSET, HAND_PITCH_OFFSET]

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
var bot_noalign := false  # 测试用：不转视角直接走上断桥（应该掉下去）
var quit_at := -1.0
var shot_path := ""
var _log_timer := 0.0


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg == "--bot":
			bot = true
		elif arg == "--noalign":
			bot_noalign = true
		elif arg == "--solotest":
			solotest = true
			mode = "solo"
		elif arg == "--solo":
			mode = "solo"
		elif arg == "--fp":
			mode = "solo"
			first_person = true
		elif arg.begins_with("--camyaw="):
			cam_yaw_target = float(arg.get_slice("=", 1))
		elif arg.begins_with("--quit="):
			quit_at = float(arg.get_slice("=", 1))
		elif arg.begins_with("--shot="):
			shot_path = arg.get_slice("=", 1)

	_build_environment()
	level = Level1.new()
	add_child(level)
	level.bonus.connect(func(amount: float, text: String) -> void:
		dignity += amount
		_say(text))
	_spawn_team(COFFIN_START, 0.0)

	cam_fixed = Camera3D.new()
	cam_fixed.projection = Camera3D.PROJECTION_ORTHOGONAL  # 正交投影：纪念碑谷式的视错觉只在正交下严格成立
	cam_fixed.size = ORTHO_SIZE
	cam_fixed.far = 200.0
	cam_fixed.cull_mask &= ~(1 << (Bearer.FP_ONLY_LAYER - 1))
	add_child(cam_fixed)
	cam_fixed.global_position = COFFIN_START + _cam_offset()
	cam_fixed.look_at(COFFIN_START)
	cam_fp = Camera3D.new()
	cam_fp.fov = 75
	cam_fp.near = 0.05
	cam_fp.cull_mask &= ~(1 << (Bearer.FP_HIDDEN_LAYER - 1))
	add_child(cam_fp)
	_build_hud()

	if mode == "solo":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_apply_camera()
	if mode == "" and not bot:
		_say("按 1：单人模式（电脑队友帮你抬）\n按 2：双人模式（两人共用键盘）", 9999.0)


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
		bearers[0].set_first_person_owner()


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


func _team_bodies() -> Array[RigidBody3D]:
	var list: Array[RigidBody3D] = [coffin]
	list.append_array(corpse.parts)
	for b in bearers:
		list.append(b)
		list.append_array(b.hands)
	return list


## 断桥：视角对齐时打开幽灵地面；棺材走过接缝时，整队连人带棺一起平移到另一段桥上。
## 平移方向正好沿着视线，所以画面上看不出任何跳动。
func _update_level() -> void:
	var aligned := not first_person and absf(wrapf(cam_yaw - Level1.ALIGN_YAW, -180.0, 180.0)) < 6.0
	if aligned != _bridge_aligned:
		_bridge_aligned = aligned
		level.set_bridge(aligned)
		if aligned and coffin.global_position.y > -2.0:
			_say("咔哒——桥接上了！")
	var c := coffin.global_position
	var upper := c.y > -2.0
	if aligned and upper and c.x < Level1.SEAM_X:
		_shift_team(Level1.BRIDGE_OFFSET)
		_checkpoint = Level1.CHECKPOINT_LOWER
	elif aligned and not upper and c.x > Level1.SEAM_X + Level1.BRIDGE_OFFSET.x:
		_shift_team(-Level1.BRIDGE_OFFSET)
		_checkpoint = Level1.CHECKPOINT_UPPER

	if c.y < Level1.KILL_Y or bearers.any(func(b): return b.global_position.y < Level1.KILL_Y):
		dignity -= 30.0
		_say("整队掉进了深渊！体面 -30
从检查点重来")
		_respawn_team(_checkpoint)
	elif corpse.torso.global_position.y < Level1.KILL_Y:
		dignity -= 10.0
		_say("逝者掉进了深渊……又被送回来了。体面 -10")
		corpse.queue_free()
		corpse = Corpse.new()
		corpse.transform = coffin.global_transform
		add_child(corpse)


func _shift_team(d: Vector3) -> void:
	for body in _team_bodies():
		body.global_position += d


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
		if mode == "solo" and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
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
		elif key in [KEY_F5, KEY_BACKSPACE]:
			get_tree().reload_current_scene()
		elif key == KEY_F1:
			mode = ""
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			get_tree().reload_current_scene()
		elif key == KEY_ESCAPE:
			if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			else:
				get_tree().quit()
		elif key == KEY_V and mode == "solo":
			first_person = not first_person
			_apply_camera()
		elif not first_person and _is_rotate_key(key, -1):
			cam_yaw_target -= 45.0
		elif not first_person and _is_rotate_key(key, 1):
			cam_yaw_target += 45.0


## 旋转固定视角的键：单人用 Q / E（手由鼠标管），双人用 Z / X（Q / E 是 P1 的手）
func _is_rotate_key(key: Key, dir: int) -> bool:
	if dir < 0:
		return key == KEY_Z or (mode == "solo" and key == KEY_Q)
	return key == KEY_X or (mode == "solo" and key == KEY_E)


func _physics_process(delta: float) -> void:
	if bot:
		_drive_bot()
	elif mode == "solo":
		_control_solo()
		_control_partner(bearers[1], bearers[0], delta)
	elif mode == "duo":
		_control_keyboard(0, P1_KEYS, delta)
		_control_keyboard(1, P2_KEYS, delta)
	_update_level()
	_update_rules(delta)


func _control_solo() -> void:
	var p := bearers[0]
	var input := Vector2(_key(KEY_D) - _key(KEY_A), _key(KEY_S) - _key(KEY_W))
	var basis := Basis(Vector3.UP, look_yaw) if first_person else cam_fixed.global_basis
	p.move_dir = _to_world(input, basis)
	p.face_yaw = look_yaw
	p.face_deadzone = deg_to_rad(FP_FREE_LOOK) if first_person and p.is_holding() else 0.0
	p.reach_pitch = look_pitch + HAND_PITCH_OFFSET
	p.want_grab = [Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT), Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)]
	p.want_jump = Input.is_physical_key_pressed(KEY_SPACE)
	if solotest:
		_solotest_script(p)


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


func _control_keyboard(i: int, keys: Dictionary, delta: float) -> void:
	var b := bearers[i]
	var input := Vector2(_held(keys.right) - _held(keys.left), _held(keys.down) - _held(keys.up))
	b.move_dir = _to_world(input, cam_fixed.global_basis)
	b.face_yaw = null
	duo_pitch[i] = clampf(duo_pitch[i] + (_held(keys.reach_up) - _held(keys.reach_down)) * 1.5 * delta, -1.35, 1.1)
	b.reach_pitch = duo_pitch[i]
	b.want_grab = [_held(keys.grab_l) > 0.0, _held(keys.grab_r) > 0.0]
	b.want_jump = _held(keys.jump) > 0.0


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
	if bot or solotest:
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
	cam_fp.current = first_person
	cam_fixed.current = not first_person
	_crosshair.visible = first_person
	if mode == "solo":
		help.text = "WASD 移动 · 鼠标 看 / 控制手的高度（往下看就弯腰去够）· 左键 / 右键 左右手抓（按住）· 空格 跳\n" \
			+ "V 切换第一人称 / 固定视角 · Q / E 旋转固定视角 · 滚轮 缩放 · F5 重来 · F1 换模式 · Esc 释放鼠标 / 退出"
	elif mode == "duo":
		help.text = "P1：WASD 移动 · Q / E 左右手抓（按住）· R / F 手抬高 / 放低 · 空格 跳\n" \
			+ "P2：方向键 移动 · , / . 左右手抓 · ' / ; 手抬高 / 放低 · / 跳　　Z / X 旋转视角 · F5 重来 · F1 换模式"
	else:
		help.text = ""


func _process(delta: float) -> void:
	cam_yaw = lerpf(cam_yaw, cam_yaw_target, 1.0 - exp(-delta * 6.0))
	var focus := coffin.global_position
	for b in bearers:
		focus += b.global_position
	focus /= bearers.size() + 1
	cam_fixed.global_position = cam_fixed.global_position.lerp(focus + _cam_offset(), 1.0 - exp(-delta * 4.0))
	cam_fixed.look_at(cam_fixed.global_position - _cam_offset())
	cam_fixed.size = ORTHO_SIZE * zoom

	if first_person:
		var me := bearers[0]
		var view := Basis.from_euler(Vector3(look_pitch, look_yaw, 0))
		cam_fp.global_transform = Transform3D(view, me.to_global(Vector3(0, FP_EYE_HEIGHT, 0)) + Basis(Vector3.UP, look_yaw) * Vector3(0, 0, -0.12))

	hud.text = "体面值 %d    用时 %.1f 秒" % [roundi(dignity), elapsed]
	hud.add_theme_color_override("font_color", Color(1, 0.35, 0.3) if dignity < 0.0 else Color.WHITE)
	status_timer -= delta
	status.modulate.a = clampf(status_timer, 0.0, 1.0)

	if quit_at >= 0.0 and Time.get_ticks_msec() / 1000.0 > quit_at:
		quit_at = -1.0
		_finish_run()


# ---------- 自动测试 ----------

## 自动测试：两个抬棺人一起抓住棺材，沿关卡路线走；到断桥前转视角，过桥，送上灵台
func _drive_bot() -> void:
	var t := Time.get_ticks_msec() / 1000.0
	for b in bearers:
		b.want_grab = [t > 0.5, t > 0.5]
		b.move_dir = Vector3.ZERO
		b.face_yaw = null
		b.reach_pitch = HAND_PITCH_OFFSET
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


func _solotest_script(p: Bearer) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	var grab := (t > 0.5 and t < 6.0) or t > 8.0
	p.want_grab = [grab, grab]
	p.move_dir = Vector3.ZERO
	look_pitch = 0.0
	if t > 2.5 and t < 5.0:
		if first_person:
			look_yaw = lerp_angle(look_yaw, atan2(1.0, 0.8), 0.05)  # 转头看向行走方向
		p.move_dir = Vector3(0, 0, -1)  # 往灵台方向横着走
	elif t > 6.5 and t < 9.5:
		look_pitch = -1.45  # 低头弯腰去够地上的棺材
	elif t > 11.0 and t < 13.0:
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
	print("BOT wp=%d aligned=%s t=%.1f coffin=%s tilt=%.0f dignity=%d corpse_out=%s holding=%s" % [
		_bot_wp, _bridge_aligned, t, coffin.global_position.snapped(Vector3.ONE * 0.01),
		rad_to_deg(coffin.global_basis.y.angle_to(Vector3.UP)), int(dignity), corpse_out,
		bearers.map(func(b): return b.grabs.map(func(g): return g != null))])


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
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.45, 0.62, 0.86)
	sky_mat.sky_horizon_color = Color(0.82, 0.86, 0.9)
	sky_mat.ground_horizon_color = Color(0.82, 0.86, 0.9)
	sky_mat.ground_bottom_color = Color(0.93, 0.86, 0.84)  # 深渊下面是一片浅色虚空，而不是棕色地面
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -35, 0)
	sun.light_energy = 1.3
	sun.shadow_enabled = true
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
	if mode != "":
		_say("抓住棺材把手，把棺材抬到远处有蜡烛的灵台上", 5.0)



func _label(parent: Control, size: int, pos: Vector2) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color.WHITE)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 8)
	l.position = pos
	parent.add_child(l)
	return l
