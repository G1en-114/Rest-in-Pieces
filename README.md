# 抬棺（黑客松项目）

2–4 人物理派对游戏：一群站不稳的抬棺人，把棺材抬过一座不讲物理定律的灵堂。角色由 AHOLO Lux3D 生成。

- 设计文档：`docs/设计文档.md`（在线版见文档顶部链接）
- 角色风格与提示词：`docs/角色风格.md`

## 运行

双击 `play.bat`（需要 Godot 4.7.2，装在 `E:\Godot`）。开局按 1 单人（电脑队友）、按 2 双人（P1 键鼠 + P2 方向键，左右分屏第一人称，V / Enter 切共享俯视），然后选关、选房间（默认继续上次存档的房间）。棺材进入新房间会自动记检查点并存档；掉下去或按 R 回到检查点，F5 本关从头来。送达后出结算面板：R 再来一局 · N 下一关 · M 回选关。存档在 `user://save.cfg`（`%APPDATA%\Godot\app_userdata\抬棺\`）。

三关：中国（教学关，7 间：告别厅三条过道、纸扎仓库的推墙和二楼近路、俯视断桥、会躲的灵台）、埃及（机关长关，7 间：沙漠、飞镖、塌陷地板、石门、滚石长廊、刀摆深渊、墓室）、墨西哥（大地图，主打第一人称，6 间，最后是烟花城堡）。墨西哥关里路会断：站进地上相机标记的圈里，按 C 举起相机，取景框变金色时左键拍照，远处那块路就沿着视线缩回断口里，变成一段平的灰色照片路面。双人时 P2 用 [ 举相机、] 拍照。

机关都在 `scripts/traps.gd`（地刺、天降、假地板、弹簧板、推墙、摆锤、压板、传送带、移动平台、滚石 / 火箭、转臂），I wanna 式的坑不少：看着能走的地板会塌、花圈底下藏地刺、头顶会掉东西。被机关打中的人会松手飞出去，晕一下再爬起来（不扣分，但棺材可能就掉了）。每关都有近路（弹簧板之类）和藏在假墙后面的秘密。

计分只按事件扣：颠一下 -2、逝者掉出 -10、坠落 -20、棺材摔地 -8、撞墙 -3（有冷却），不会再扣到几千分。结算显示颠了几下、被撞飞几次、花圈和秘密找到几个、抄了哪条近路、零失误房间数，还有奖章（空中飞人、稳如泰山、探险家……）。

**联机**（每人一台电脑）：房主按 3 建房间，屏幕上显示 4 位房间号；队友按 4 输入房间号加入。走的是杭州服务器上的房间号中转（`tools/relay.py`，只转发 UDP 包，不跑物理），两边不用在同一个网络。服务器连不上时也可以照旧输入房主的局域网 / Radmin IP 直连（UDP 7777）。发给朋友：`python tools/package.py`，把 `build/棺不住_<版本>.zip` 发过去，两边必须是同一个压缩包。左上角显示延迟和丢包。

过断桥要有人在俯视里转对角度；第一人称的人看到的永远是断桥，桥接上时脚下会出现只有他看得见的金色虚线，踩着走过去就行（“信任之桥”）。

**中转服务器**：`python tools/relay.py` 监听 UDP 7777（队友）和 7778（房主心跳），安全组要放行这两个端口。本机测试：`python tools/relay.py --port 9777`，游戏加 `--relay=127.0.0.1:9777`，`--join=<房间号>`。

## 目录

| 路径 | 内容 |
| --- | --- |
| `game/` | Godot 项目 |
| `tools/aholo.py` | 调用 Lux3D 生成 / 查询 / 下载（只用标准库） |
| `tools/rig.py` | 上传 GLB 并自动绑骨（需要 `tools/.venv` 里的官方 SDK） |
| `tools/preview_glb.py` | 用 Blender 渲染模型四视图 |
| `generated/` | API 生成的原始结果（不进 git） |

API key 放在根目录 `.env`（`AHOLO_API_KEY=...`），**不要提交**。

## 自动测试

```
cd game
E:/Godot/Godot_v4.7.2-stable_win64_console.exe --headless -- --bot --quit=24            # 走完第一关：花圈、转视角过断桥、放上灵台
E:/Godot/Godot_v4.7.2-stable_win64_console.exe --headless -- --bot --noalign --quit=20   # 不转视角上断桥：应掉进深渊并重生
E:/Godot/Godot_v4.7.2-stable_win64_console.exe --headless -- --lonetest --quit=30       # 2 号空手自己过断桥：不该掉下去
E:/Godot/Godot_v4.7.2-stable_win64_console.exe --headless -- --solotest --quit=17       # 单人：抬、扔、捡、转弯
E:/Godot/Godot_v4.7.2-stable_win64_console.exe --headless -- --duotest --quit=5         # 双人分屏：两人抬着往前走
```

联机测试要开两个进程（房主先开）：

```
E:/Godot/Godot_v4.7.2-stable_win64_console.exe --headless -- --host --nettest --quit=12
E:/Godot/Godot_v4.7.2-stable_win64_console.exe --headless -- --join=127.0.0.1 --nettest --quit=10
```

加 `--atbridge` 可让整队直接出生在断桥前，方便反复测过桥。

`--botpath=x,z;x,z` 让电脑队伍改走自己给的几个点（测弹簧板、近路）：

```
E:/Godot/Godot_v4.7.2-stable_win64_console.exe --headless -- --bot --level=egypt --room=0 "--botpath=0,-12;0,-17.4;-3,-17.5;-3,-31" --quit=20
```

按关卡 / 房间测（自动测试不会写存档）：

```
E:/Godot/Godot_v4.7.2-stable_win64_console.exe --headless -- --levelbot --level=china --quit=40      # 从第 1 间走完整关，打印 GRADE 结算
E:/Godot/Godot_v4.7.2-stable_win64_console.exe --headless -- --bot --level=china --room=1 --quit=40  # 只测第 2 间（从 0 数）：走进下一间打印 ROOM_PASS
E:/Godot/Godot_v4.7.2-stable_win64_console.exe -- --menu=rooms:china --quit=1.5 --shot=rooms.png    # 截菜单页（levels / rooms:<关卡>）
E:/Godot/Godot_v4.7.2-stable_win64_console.exe --headless -- --bot --level=mexico --room=0 --nowait --quit=30  # 不拍照硬走：应该掉下去
E:/Godot/Godot_v4.7.2-stable_win64_console.exe -- --solo --level=mexico --photocam=0 --quit=1.5 --shot=p.png  # 从拍照点看视错觉（加 --photofix 看拍完的样子）
E:/Godot/Godot_v4.7.2-stable_win64_console.exe --headless -- --join=127.0.0.1 --nettest --netversion=old --quit=6  # 版本不一致应被房主拒绝
```

两边都会打印 `NET` 行：加入方的棺材坐标应和房主一致（慢约 0.1 秒），`max_step` 是加入方画面里棺材每帧最大位移，远小于 0.2 就说明没有瞬移。

脚本有语法错误时游戏不会自动退出，跑测试记得加超时（如 `timeout 90 ...`）。新增 `class_name` 后要先跑一次 `--headless --import` 让 Godot 登记新类。

## Git 分支

- `main`：始终是能玩的版本
- `feature/*`：每个功能一个分支（如 `feature/level-1`、`feature/netcode`），验证通过后合回 `main`
