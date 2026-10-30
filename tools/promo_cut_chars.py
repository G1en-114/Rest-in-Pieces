"""自定义角色短片的剪辑表：python tools/promo_edit.py --cut=promo_cut_chars

素材：promo_shots.py 里 x_ 开头的镜头（工作台已把三个 Lux3D 真实生成的角色应用到玩家一 / 玩家二 / 逝者），
x_ws_* 是工作台界面演示（照片、密钥打码、进度文字都是游戏里真实的界面和文案，等待时间压缩了），
x_photos / x_models 是输入照片和生成结果的静帧。格式同 promo_cut.py。
"""
from promo_cut import B, INTRO, cap

NAME = "棺不住_自定义角色"

CUT = [
    # 1. 开场：标题页的抬棺人已经是那只猫了
    dict(clip="x_title", start=0.5, dur=INTRO, fx=[("fadein", 0, 0.6)],
         caps=[cap(0.4, "这次，抬棺的换人了", "plain", y=0.84, size=80, dur=3.2, anim="float", sfx="")],
         sfx=[(3.35, "scratch", 0.9)]),
    # 2. 第一人称：对面是卡特里娜，撞一下，保镖逝者飞出去
    dict(clip="x_push_fp", start=0.0, dur=2 * B, fx=[("flash", 0.82), ("shake", 0.85, 0.6)],
         caps=[cap(0.05, "对面那位是……？", "tag", "pink", x=0.3, y=0.15, size=66, rot=-4, dur=0.8),
               cap(0.9, "撞！", "big", "red", y=0.42, size=200, dur=0.8, anim="slam", sfx="bonk"),
               cap(1.8, "逝者：我先走一步", "flower", "yellow", x=0.64, y=0.82, size=84, rot=4, dur=1.9)]),
    # 3. 照片
    dict(clip="x_photos.mp4", start=0.0, dur=2 * B, fx=[("zoom", 0, 1.08, 3.7)],
         caps=[cap(0.2, "一张正面全身照", y=0.1, size=100, dur=3.4),
               cap(1.4, "双臂张开 · T 字站好", "tag", "cyan", y=0.92, size=60, rot=-2, dur=2.2)]),
    # 4. 工作台：选照片 → 密钥打码 → 上传 → 生成 → 绑骨 → 应用
    dict(clip="x_ws_cat.avi", start=1.0, speed=1.5, dur=3 * B, fx=[("zoom", 0, 1.6, 0.6, 0.3, 0.35)],
         caps=[cap(0.8, "填你自己的 AHOLO Key", "tag", "yellow", x=0.74, y=0.2, size=60, rot=3, dur=1.6),
               cap(2.3, "Lux3D 图生 3D", color="cyan", x=0.72, y=0.45, size=96, rot=-3, dur=1.5),
               cap(3.7, "自动绑骨！", color="pink", x=0.72, y=0.62, size=96, rot=3, dur=1.8, sfx="ding"),
               cap(3.9, "（实际约 7–9 分钟，已加速）", "plain", y=0.93, size=44, dur=1.7, anim="float", sfx="")]),
    # 5. 生成结果
    dict(clip="x_models.mp4", start=0.0, dur=2 * B, fx=[("punch", 0, 0.1)],
         caps=[cap(0.1, "生成好了，自带骨架", y=0.11, size=96, dur=3.6),
               cap(0.9, "玩家一", "tag", "yellow", x=0.17, y=0.92, size=58, rot=-3, dur=2.8),
               cap(1.3, "玩家二", "tag", "pink", x=0.5, y=0.92, size=58, rot=2, dur=2.4),
               cap(1.7, "逝者", "tag", "purple", x=0.83, y=0.92, size=58, rot=-2, dur=2.0, sfx="bonk")]),
    # 6. 进游戏：还是原来的物理身体
    dict(clip="x_orbit", start=2.2, dur=2 * B,
         caps=[cap(0.2, "身体还是那副物理身体", "tag", "green", x=0.3, y=0.15, size=60, rot=-3, dur=1.8),
               cap(1.9, "站不稳也是原装的", x=0.62, y=0.82, size=90, rot=3, dur=1.8)]),
    dict(clip="x_boulder_front", start=2.6, dur=2 * B, fx=[("shake", 1.0, 0.8)],
         caps=[cap(0.1, "埃及 · 滚石长廊", "tag", "yellow", x=0.2, y=0.12, size=54, rot=-3, dur=1.2),
               cap(1.3, "猫：喵？？", "flower", "orange", x=0.68, y=0.22, size=110, rot=5, dur=2.2, sfx="boing")]),
    dict(clip="x_rockets_chase", start=0.1, dur=2 * B, fx=[("punch", 1.0, 0.14)],
         caps=[cap(0.1, "墨西哥 · 烟花城堡", "tag", "pink", x=0.22, y=0.12, size=54, rot=-3, dur=1.2),
               cap(1.0, "保镖起飞", "big", "orange", x=0.6, y=0.3, size=150, rot=-4, dur=1.6, anim="slam",
                   sfx="bonk")]),
    dict(clip="x_push_fp", start=6.4, dur=B,
         caps=[cap(0.2, "棺材呢？？", "big", "pink", y=0.3, size=150, dur=1.6, anim="slam", sfx="fall", vol=0.5)]),
    # 7. 片尾
    dict(clip="x_title", start=2.0, dur=4.875, fx=[("blur", 0), ("fadeout", 4.0, 0.8)],
         caps=[cap(0, "棺不住", "big", "yellow", y=0.32, size=240, dur=4.8, anim="slam", sfx="bonk"),
               cap(0.5, "新功能 · 自定义角色", "flower", "cyan", y=0.52, size=90, dur=4.3),
               cap(1.2, "主菜单按 C · 用你自己的 AHOLO Key", "tag", "pink", y=0.68, size=56, dur=3.6),
               cap(2.0, "把朋友（和猫）送进灵堂", "plain", y=0.84, size=56, dur=2.8, anim="float", sfx="")]),
]
