# 多房间长关卡：实现计划

对应设计：`docs/superpowers/specs/2026-10-20-multi-room-levels-design.md`。分支 `feature/levels`。

每一步结束时都要：原有测试全部通过（中式关），新增测试通过，提交一次。

## 第 1 步：框架 + 移植中式关

1. `scripts/level_base.gd`（`class_name Level`）
   - 关卡注册表 `LEVELS`（id、国家、关名、脚本路径），`Level.create(id)`、`Level.next_id(id)`
   - 房间列表在 `_init()` 里填好，这样选关界面 `new()` 一下就能读到房间名，不用搭场景
   - 房间字段：`name`、`spawn`（检查点地面点）、`yaw`（整队朝向）、`lift`（棺材离地高度，默认 0.24）、`path`（电脑队伍路线）、可选 `kill_y`
   - 路线里的点：`Vector3`（棺材要走到的水平位置）、`"wait:<标签>"`（原地等 `bot_can_go` 为真）、`{dir, until}`（朝某方向走，直到 `bot_can_go(until)` 为真）
   - 灵台 `goal_pos`（台底中心）+ `goal_size`（x、高、z），`on_altar(p, margin)`
   - 接口：`room_at`、`env`、`tick`、`physics_update(game)`、`net_bodies`、`net_state`、`apply_net_state`、`bot_can_go`；信号 `bonus`、`notice`、`penalty`
   - 通用搭建工具：从 `level_1.gd` 挪过来的 `_floor`、`_wall_x/_z`、`_collider`、`_solid`、`_box`、`_put`、`_lamp`、`_sign`、`_label3d`、`_wreath`
2. `scripts/levels/china.gd`：`level_1.gd` 改名搬家；断桥对齐、锁桥、平移整组刚体从 `main.gd` 挪进 `physics_update`；4 个房间：停棺间、走廊、断桥、灵堂
3. `scripts/score.gd`（`class_name Score`）：体面值、用时、掉出 / 坠落次数、逝者掉出 1 秒判定、倾斜扣分、结算明细 / 评级 / 称号、存档用的快照与恢复
4. `scripts/save.gd`（`class_name Save`）：`user://save.cfg`；自动测试时关掉写入
5. `scripts/menu.gd`（`class_name Menu`）：选模式 → 选关 → 选房间，输入 IP，结算面板；按钮可点，也能按数字键
6. `main.gd` 改造：
   - 静态变量 `level_id`、`start_room`、`carry`（跨重载带着的分数）、`menu_page`
   - `R` 回检查点；`F5` 从本局起点重来；结算面板 R / N / M
   - 联机：所有“换关 / 重来”走 `_goto(level, room, carry)`，房主先发可靠 RPC 再自己重载；队友加入时房主把整局带到当前房间重开
   - 快照 = 整队刚体 + `level.net_bodies()`；另带 `level.net_state()`
7. 测试参数：`--level=<id>`、`--room=N`（配 `--bot`：只走这一间，到下一间打印 `ROOM_PASS`）、`--levelbot`（从第 1 间走完整关，打印结算）；`--atbridge` 等同中式关 `--room=2`

## 第 2 步：埃及关 1–4 间

`scripts/levels/egypt.gd` + `scripts/props_egypt.gd`；沙地减速、飞镖、塌陷地板、压力板石门（石块进 `net_bodies`，门和地板进 `net_state`）。Lux3D 生成斯芬克斯、阿努比斯、石棺（失败用代码拼的版本）。每间 `--bot --room=N` 通过，截俯视图和第一人称图。

## 第 3 步：埃及关 5–8 间

滚石（刚体，进 `net_bodies`）、深渊窄梁、升降石台（`tick` 驱动）、天平桥（铰链刚体）。

## 第 4 步：埃及关 9–12 间

流沙、星象视错觉（复用断桥平移，抽成基类工具）、最终考验、法老墓室结算。`--levelbot --level=egypt` 走完整关。

## 第 5 步：收尾

README 更新测试命令；全部测试回归；合回 `main` 前请用户试玩，按试玩结果调各房间时长。
