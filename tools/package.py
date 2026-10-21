"""把游戏打成一个给朋友的压缩包：解压后双击「开始游戏.bat」就能玩，不用装 Godot。

用法:
  python tools/package.py            # 生成 build/抬棺_<版本>.zip

压缩包里是 Godot 本体 + 已经导入好资源的 game/ 文件夹（含 .godot/ 缓存，第一次打开不用等导入）。
版本号取 main.gd 里的 NET_VERSION：联机时两边必须是同一个版本。
"""
import re
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
GODOT = Path("E:/Godot/Godot_v4.7.2-stable_win64.exe")
SKIP_DIRS = {".godot/editor", ".godot/shader_cache"}  # 编辑器缓存，运行用不到

START_BAT = """@echo off
cd /d "%~dp0"
start "" "godot\\Godot.exe" --path "game"
"""

GUIDE = """抬棺 · 联机测试说明（版本 {version}）

1. 两个人都装 Radmin VPN（https://www.radmin-vpn.com/cn/），进同一个网络：
   房主点“创建网络”，起个名字和密码；队友点“加入网络”，填同样的名字和密码。
2. 两个人都解压这个压缩包（同一个版本！），双击「开始游戏.bat」。
   第一次打开时 Windows 防火墙会弹窗，两个勾都勾上，点“允许访问”。
3. 房主：按 3「联机：建房间」→ 选关 → 选房间。屏幕上会显示房主的 IP，
   Radmin 的那个是 26. 开头的。
4. 队友：按 4「联机：加入房间」，输入房主的 26. 开头的 IP，按 Enter。
   连上以后会自动进入房主选的那一关。
5. 左上角会显示延迟和丢包。延迟 < 100 ms 就很顺；超过 200 ms 会有点飘。

操作
  WASD 走 · 鼠标看 / 控制手的高度 · 左键 / 右键 左右手抓（按住）· 空格 跳
  V 第一人称 ⇄ 俯视 · Q / E 转俯视视角 · R 回检查点 · F5 本关重来 · F1 退出联机
  C 举起相机（第一人称），左键拍照：在相机标记的圈里对准断口拍，断掉的路就会变成实的

连不上？
  - 先确认 Radmin 里能看到对方是绿色在线；在 Radmin 里右键对方 → Ping 试试
  - 两边防火墙都放行 Godot（控制面板 → Windows Defender 防火墙 → 允许应用通过防火墙）
  - 房主要先建好房间，队友再加入；端口是 UDP 7777
  - 提示“版本对不上”：两个人用的不是同一个压缩包
"""


def main() -> None:
    main_gd = (ROOT / "game/scripts/main.gd").read_text(encoding="utf-8")
    version = re.search(r'NET_VERSION := "([^"]+)"', main_gd).group(1)
    out = ROOT / "build" / f"抬棺_{version}.zip"
    out.parent.mkdir(exist_ok=True)
    game = ROOT / "game"
    with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED, compresslevel=6) as z:
        z.write(GODOT, "抬棺/godot/Godot.exe")
        for f in sorted(game.rglob("*")):
            rel = f.relative_to(game).as_posix()
            if f.is_dir() or any(rel.startswith(d) for d in SKIP_DIRS):
                continue
            z.write(f, f"抬棺/game/{rel}")
        z.writestr("抬棺/开始游戏.bat", START_BAT.replace("\n", "\r\n").encode("gbk"))
        z.writestr("抬棺/联机说明.txt", GUIDE.format(version=version).replace("\n", "\r\n").encode("utf-8-sig"))
    print(f"{out}  {out.stat().st_size / 1e6:.0f} MB")


if __name__ == "__main__":
    main()
