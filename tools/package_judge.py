"""给评委的试玩包：用 Godot 正式导出成一个 exe（脚本编译成二进制 token、资源全打进 exe 里，不带源码），
再配上游玩说明打成 zip，直接传网盘。

用法:
  python tools/package_judge.py      # 生成 build/棺不住_评委试玩_<版本>.zip

需要 Godot 4.7.2 的 Windows 导出模板（%APPDATA%/Godot/export_templates/4.7.2.stable/）。
和 package.py 的区别：那个是给队友联机测试的，直接带着 game/ 文件夹（看得到源码）；这个不带。
"""
import re
import shutil
import subprocess
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
GODOT = "E:/Godot/Godot_v4.7.2-stable_win64_console.exe"
EXE = ROOT / "build" / "judge" / "棺不住.exe"

GUIDE = """棺不住 Rest in Pieces · 游玩说明（版本 {version}）

一群站不稳的抬棺人，要把棺材抬过中国、埃及、墨西哥三座不讲物理的灵堂。

怎么开始
  解压后双击「棺不住.exe」。Windows 提示“已保护你的电脑”时，点“更多信息”→“仍要运行”。
  只需要 Windows 10/11，不用安装任何东西。

模式
  1  一个人抬：你 + 电脑队友
  2  两个人抬：两人共用一个键盘，左右分屏第一人称（最推荐两位评委一起玩！）
  3  建房间 / 4  加入房间：两台电脑联网，房主把屏幕上的 4 位房间号告诉队友

操作
  一个人抬 / 联机 / 双人的 P1：
    WASD 走 · 鼠标 看路，也控制手的高度（往下看就弯腰去够）
    左键 / 右键 左右手抓（按住不放）· 空格 跳
    V 第一人称 ⇄ 俯视 · Q / E 转俯视视角 · 滚轮 缩放
  双人的 P2：↑↓ 走 · ←→ 转身 · ' / ; 抬头低头 · , / . 抓 · / 跳
  通用：R 回检查点 · F5 本关重来 · Esc 释放鼠标 / 回菜单

小提示
  - 两个人都抓稳了再走，一个人松手棺材就歪
  - 被机关撞飞不扣分，但棺材可能就掉了；逝者掉出来才是真的不体面
  - 中国关的断桥：切到俯视（V），按 Q / E 转到桥看起来接上了，再走过去
  - 墨西哥关的断路：站进相机标记的圈里按 C 举相机，取景框变金色时左键拍照
  - 每关都藏着近路和秘密
"""


def main() -> None:
    main_gd = (ROOT / "game/scripts/main.gd").read_text(encoding="utf-8")
    version = re.search(r'NET_VERSION := "([^"]+)"', main_gd).group(1)
    if EXE.parent.exists():
        shutil.rmtree(EXE.parent)
    EXE.parent.mkdir(parents=True)
    r = subprocess.run([GODOT, "--headless", "--path", str(ROOT / "game"), "--export-release", "Windows Desktop",
                        str(EXE)], capture_output=True, text=True, encoding="utf-8", errors="replace")
    if not EXE.exists():
        raise SystemExit("导出失败：\n" + r.stdout[-3000:] + r.stderr[-3000:])
    # 确认导出的 exe 里没有明文脚本（变量名、注释这种只在源码里出现的东西）
    blob = EXE.read_bytes()
    for marker in ("房主权威：房主的电脑算全部物理", "func _drive_bot()", "extends RefCounted\n##"):
        if marker.encode("utf-8") in blob:
            raise SystemExit(f"exe 里还能看到源码：{marker!r}")
    out = ROOT / "build" / f"棺不住_评委试玩_{version}.zip"
    with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as z:
        z.write(EXE, "棺不住/棺不住.exe")
        z.writestr("棺不住/游玩说明.txt", GUIDE.format(version=version).replace("\n", "\r\n").encode("utf-8-sig"))
        z.write(ROOT / "game/assets/fonts/OFL.txt", "棺不住/字体许可（站酷快乐体）.txt")
    print(f"{out}  {out.stat().st_size / 1e6:.0f} MB")


if __name__ == "__main__":
    main()
