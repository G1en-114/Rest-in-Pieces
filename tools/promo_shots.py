"""录宣传片素材：每个镜头开一次 Godot（Movie Maker 定帧 60fps），电脑队伍按参数走，镜头按 --cam= 跟拍。

用法:
  python tools/promo_shots.py              # 录全部镜头到 promo/raw/<名字>.avi，并各出一张缩略图 <名字>.jpg
  python tools/promo_shots.py c_push e_bo  # 只录名字以这些开头的镜头
  python tools/promo_shots.py --res 960x540 ...  # 先低分辨率试拍

同样的参数录出来的画面每次都一样（物理是定帧算的），挑好了直接拿来剪。
"""
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
GODOT = "E:/Godot/Godot_v4.7.2-stable_win64_console.exe"
OUT = ROOT / "promo" / "raw"

# 名字: (秒数, 参数)。秒数是模拟时间，到点自动退出
SHOTS = {
    "title": (8, []),
    "c_lift_front": (7, ["--bot", "--level=china", "--room=0", "--cam=front"]),
    "c_lift_fp": (7, ["--bot", "--level=china", "--room=0", "--cam=fp0"]),
    "c_fake_chase": (10, ["--bot", "--level=china", "--room=1", "--botpath=-7,32.4;-7,20", "--cam=chase"]),
    "c_fake_fp": (10, ["--bot", "--level=china", "--room=1", "--botpath=-7,32.4;-7,20", "--cam=fp0"]),
    "c_push_fp": (9, ["--bot", "--nowait", "--level=china", "--room=2", "--cam=fp0", "--botdelay=0.8"]),
    "c_push_side": (9, ["--bot", "--nowait", "--level=china", "--room=2", "--cam=side", "--botdelay=0.8"]),
    "c_drawer_side": (10, ["--bot", "--nowait", "--level=china", "--room=3", "--cam=side"]),
    "c_bridge_fall_fp": (9, ["--bot", "--noalign", "--level=china", "--room=5", "--cam=fp0"]),
    "c_bridge_iso": (14, ["--bot", "--level=china", "--room=5"]),
    "c_altar_result": (26, ["--bot", "--level=china", "--room=6", "--cam=chase"]),
    "e_spring_chase": (12, ["--bot", "--level=egypt", "--room=0", "--botpath=0,-12;0,-17.4;-3,-17.5;-3,-31",
                            "--cam=chase"]),
    "e_darts_fp": (12, ["--bot", "--nowait", "--level=egypt", "--room=1", "--cam=fp0"]),
    "e_collapse_chase": (14, ["--bot", "--nowait", "--level=egypt", "--room=2", "--cam=chase"]),
    "e_boulder_fp": (12, ["--bot", "--nowait", "--level=egypt", "--room=4", "--cam=fp0"]),
    "e_boulder_front": (12, ["--bot", "--nowait", "--level=egypt", "--room=4", "--cam=front"]),
    "e_blades_side": (14, ["--bot", "--nowait", "--level=egypt", "--room=5", "--cam=side"]),
    "m_cemetery_fp": (12, ["--bot", "--nowait", "--level=mexico", "--room=0", "--cam=fp0"]),
    "m_cemetery_orbit": (10, ["--bot", "--level=mexico", "--room=0", "--cam=orbit", "--camdist=5"]),
    "m_rockets_chase": (12, ["--bot", "--nowait", "--level=mexico", "--room=5", "--cam=chase"]),
    "m_rockets_fp": (12, ["--bot", "--nowait", "--level=mexico", "--room=5", "--cam=fp0"]),
    # 第二轮：镜头抬高以后补拍
    "c_push_high": (9, ["--bot", "--nowait", "--level=china", "--room=2", "--cam=side", "--botdelay=0.8",
                        "--camh=4", "--camdist=5"]),
    "e_boulder_side": (12, ["--bot", "--nowait", "--level=egypt", "--room=4", "--cam=side", "--camh=3"]),
    "e_darts_side": (12, ["--bot", "--nowait", "--level=egypt", "--room=1", "--cam=side", "--camh=3"]),
    "m_market_orbit": (10, ["--bot", "--level=mexico", "--room=2", "--cam=orbit", "--camdist=6", "--camh=3"]),
    "c_hall_fp": (10, ["--bot", "--level=china", "--room=1", "--cam=fp0"]),
    "online_host": (6, ["--host", "--level=china", "--room=1", "--keepui"]),  # 联机：屏幕上显示房间号
    # 自定义角色短片：先在工作台把生成的模型应用到玩家一 / 玩家二 / 逝者，再录这些
    "x_title": (6, []),
    "x_lift_front": (7, ["--bot", "--level=china", "--room=0", "--cam=front"]),
    "x_orbit": (9, ["--bot", "--level=mexico", "--room=0", "--cam=orbit", "--camdist=4"]),
    "x_push_fp": (9, ["--bot", "--nowait", "--level=china", "--room=2", "--cam=fp0", "--botdelay=0.8"]),
    "x_push_side": (9, ["--bot", "--nowait", "--level=china", "--room=2", "--cam=side", "--botdelay=0.8",
                        "--camh=4", "--camdist=5"]),
    "x_boulder_front": (12, ["--bot", "--nowait", "--level=egypt", "--room=4", "--cam=front"]),
    "x_rockets_chase": (12, ["--bot", "--nowait", "--level=mexico", "--room=5", "--cam=chase"]),
    "x_bridge_fall_fp": (9, ["--bot", "--noalign", "--level=china", "--room=5", "--cam=fp0"]),
}


def main() -> None:
    args = sys.argv[1:]
    res = "1920x1080"
    if args[:1] == ["--res"]:
        res, args = args[1], args[2:]
    OUT.mkdir(parents=True, exist_ok=True)
    for name, (secs, extra) in SHOTS.items():
        if args and not any(name.startswith(a) for a in args):
            continue
        avi = OUT / f"{name}.avi"
        cmd = [GODOT, "--write-movie", str(avi), "--fixed-fps", "60", "--resolution", res, "--path",
               str(ROOT / "game"), "--", *[a for a in extra if a != "--keepui"],
               *([] if "--keepui" in extra else ["--clean"]), f"--quit={secs}"]
        for attempt in range(3):  # 内存紧的时候 Godot 偶尔一开录就崩，重试几次
            r = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=900)
            probe = subprocess.run(["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0",
                                    str(avi)], capture_output=True, text=True)
            if probe.stdout.strip() not in ("", "N/A"):
                break
            print(name, "录坏了，重试", attempt + 1, flush=True)
        log = [l for l in r.stdout.splitlines() if l.startswith(("RESULT", "GRADE", "SCRIPT ERROR"))]
        subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", str(avi), "-vf", "fps=2,scale=320:-1,tile=6x5",
                        "-frames:v", "1", str(OUT / f"{name}.jpg")])
        print(name, *log, flush=True)


if __name__ == "__main__":
    main()
