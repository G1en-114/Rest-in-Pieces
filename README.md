# 抬棺（黑客松项目）

2–4 人物理派对游戏：一群站不稳的抬棺人，把棺材抬过一座不讲物理定律的灵堂。角色由 AHOLO Lux3D 生成。

- 设计文档：`docs/设计文档.md`（在线版见文档顶部链接）
- 角色风格与提示词：`docs/角色风格.md`

## 运行

双击 `play.bat`（需要 Godot 4.7.2，装在 `E:\Godot`）。开局按 1 单人、按 2 双人同键盘。

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
E:/Godot/Godot_v4.7.2-stable_win64_console.exe --headless -- --bot --quit=10        # 双人：抬到灵台
E:/Godot/Godot_v4.7.2-stable_win64_console.exe --headless -- --solotest --quit=17   # 单人：抬、扔、捡、转弯
```

## Git 分支

- `main`：始终是能玩的版本
- `feature/*`：每个功能一个分支（如 `feature/level-1`、`feature/netcode`），验证通过后合回 `main`
