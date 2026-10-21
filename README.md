# 抬棺（黑客松项目）

2–4 人物理派对游戏：一群站不稳的抬棺人，把棺材抬过一座不讲物理定律的灵堂。角色由 AHOLO Lux3D 生成。

- 设计文档：`docs/设计文档.md`（在线版见文档顶部链接）
- 角色风格与提示词：`docs/角色风格.md`

## 运行

双击 `play.bat`（需要 Godot 4.7.2，装在 `E:\Godot`）。开局按 1 单人（电脑队友）、按 2 双人（P1 键鼠 + P2 方向键，左右分屏第一人称，V / Enter 切共享俯视），然后选关、选房间（默认继续上次存档的房间）。棺材进入新房间会自动记检查点并存档；掉下去或按 R 回到检查点，F5 本关从头来。送达后出结算面板：R 再来一局 · N 下一关 · M 回选关。存档在 `user://save.cfg`（`%APPDATA%\Godot\app_userdata\抬棺\`）。

**联机**（每人一台电脑）：房主按 3 建房间，屏幕上会显示本机 IP；队友按 4，输入房主的 IP 后按 Enter。两台电脑要在同一个局域网，或者都开着 Radmin VPN（用 26. 开头的那个 IP）。过断桥要有人在俯视里转对角度；第一人称的人看到的永远是断桥，桥接上时脚下会出现只有他看得见的金色虚线，踩着走过去就行（“信任之桥”）。端口是 UDP 7777，第一次建房时 Windows 防火墙弹窗要点“允许”。

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

按关卡 / 房间测（自动测试不会写存档）：

```
E:/Godot/Godot_v4.7.2-stable_win64_console.exe --headless -- --levelbot --level=china --quit=40      # 从第 1 间走完整关，打印 GRADE 结算
E:/Godot/Godot_v4.7.2-stable_win64_console.exe --headless -- --bot --level=china --room=1 --quit=40  # 只测第 2 间（从 0 数）：走进下一间打印 ROOM_PASS
E:/Godot/Godot_v4.7.2-stable_win64_console.exe -- --menu=rooms:china --quit=1.5 --shot=rooms.png    # 截菜单页（levels / rooms:<关卡>）
```

两边都会打印 `NET` 行：加入方的棺材坐标应和房主一致（慢约 0.1 秒），`max_step` 是加入方画面里棺材每帧最大位移，远小于 0.2 就说明没有瞬移。

脚本有语法错误时游戏不会自动退出，跑测试记得加超时（如 `timeout 90 ...`）。新增 `class_name` 后要先跑一次 `--headless --import` 让 Godot 登记新类。

## Git 分支

- `main`：始终是能玩的版本
- `feature/*`：每个功能一个分支（如 `feature/level-1`、`feature/netcode`），验证通过后合回 `main`
