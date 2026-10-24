"""把《棺不住》打成一个给朋友的压缩包：解压后双击「开始游戏.bat」就能玩，不用装 Godot。

用法:
  python tools/package.py            # 生成 build/棺不住_<版本>.zip

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

GUIDE = """棺不住 Rest in Pieces · 联机说明（版本 {version}）

1. 两个人都解压这个压缩包（同一个版本！），双击「开始游戏.bat」。
   第一次打开时 Windows 防火墙会弹窗，两个勾都勾上，点“允许访问”。
2. 房主：按 3「建房间」→ 选关 → 选房间。屏幕上会显示 4 位房间号。
3. 队友：按 4「加入房间」，输入房间号，按 Enter。
   连上以后会自动进入房主选的那一关。
4. 左上角会显示延迟和丢包。延迟 < 100 ms 就很顺；超过 200 ms 会有点飘。

操作
  WASD 走 · 鼠标看 / 控制手的高度 · 左键 / 右键 左右手抓（按住）· 空格 跳
  V 第一人称 ⇄ 俯视 · Q / E 转俯视视角 · R 回检查点 · F5 本关重来 · F1 退出联机
  C 举起相机（第一人称），左键拍照：在相机标记的圈里对准断口拍，断掉的路就会变成实的

连不上？
  - 提示“房间不存在”：核对房间号；房主退出游戏后房间号就作废了
  - 提示“联机服务器连不上”：可以改用局域网 / Radmin VPN（https://www.radmin-vpn.com/cn/）：
    两人进同一个 Radmin 网络，队友在「加入房间」里直接输入房主屏幕上 26. 开头的 IP
  - 提示“版本对不上”：两个人用的不是同一个压缩包
"""


def main() -> None:
    main_gd = (ROOT / "game/scripts/main.gd").read_text(encoding="utf-8")
    version = re.search(r'NET_VERSION := "([^"]+)"', main_gd).group(1)
    out = ROOT / "build" / f"棺不住_{version}.zip"
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
