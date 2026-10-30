"""宣传片剪辑表（promo_edit.py 读这个）。

每段：clip = promo/raw 里的镜头名，start = 从素材第几秒开始，dur = 在成片里占几秒，speed < 1 慢放，
freeze = 最后几秒定格；caps = 弹出字幕（t 是段内时间）；fx = 画面效果；sfx = 额外音效 (段内时间, 名字, 音量)。
节奏对着 bgm：开头 INTRO 秒庄重管风琴，之后每小节 B 秒（128 BPM），镜头尽量切在小节线上。
"""
B = 1.875  # 一小节
INTRO = 3.75


def cap(t, text, style="flower", color="yellow", x=0.5, y=0.2, size=96, rot=0.0, dur=1.6, anim="pop", sfx="pop",
        vol=0.6):
    return dict(t=t, text=text, style=style, color=color, x=x, y=y, size=size, rot=rot, dur=dur, anim=anim, sfx=sfx,
                vol=vol)


CUT = [
    # 1. 庄重开场：慢放、发灰，字幕慢慢浮现
    dict(clip="c_lift_front", start=0.2, speed=0.55, dur=INTRO, fx=[("grey", 0), ("fadein", 0, 0.8)],
         caps=[cap(0.3, "今天，我们要体面地", "plain", y=0.72, size=80, dur=3.3, anim="float", sfx=""),
               cap(1.6, "送他最后一程……", "plain", y=0.84, size=80, dur=2.0, anim="float", sfx="")],
         sfx=[(3.35, "scratch", 0.9)]),
    # 2. 唱片一刮：才怪！第一人称被纸扎推墙撞飞
    dict(clip="c_push_fp", start=3.95, speed=0.6, dur=2 * B, fx=[("flash", 0), ("shake", 0.33, 0.6)],
         caps=[cap(0, "才怪！", "big", "red", y=0.42, size=230, dur=1.0, anim="slam", sfx=""),
               cap(0.5, "被纸扎推墙撞飞", "tag", "pink", x=0.27, y=0.18, size=70, rot=-5, sfx="bonk", vol=0.8),
               cap(2.0, "逝者：我先走一步", "flower", "yellow", x=0.66, y=0.8, size=84, rot=4, dur=1.7)]),
    # 3. 游戏名
    dict(clip="title", start=1.0, dur=2 * B, fx=[("punch", 0, 0.12)],
         caps=[cap(0.5, "一群站不稳的抬棺人", "tag", "yellow", x=0.74, y=0.62, size=64, rot=-4, dur=3.2),
               cap(1.6, "一座不讲物理的灵堂", "tag", "cyan", x=0.76, y=0.76, size=64, rot=3, dur=2.1)]),
    # 4. 第一人称抬起来
    dict(clip="c_lift_fp", start=1.0, dur=B,
         caps=[cap(0.15, "抬稳了！", size=130, y=0.18, rot=-3)]),
    dict(clip="c_hall_fp", start=5.0, dur=2 * B,
         caps=[cap(0.2, "左边！左边！", color="green", x=0.3, y=0.18, size=100, rot=-4),
               cap(1.7, "你的左还是我的左？？", "tag", "purple", x=0.66, y=0.8, size=66, rot=5, dur=2.0)]),
    dict(clip="e_darts_fp", start=1.0, dur=B,
         caps=[cap(0.3, "逝者：颠死我了！", "tag", "orange", x=0.66, y=0.18, size=70, rot=4)]),
    # 5. 机关轮番上
    dict(clip="c_fake_fp", start=6.8, dur=2 * B,
         caps=[cap(0.2, "地板：骗你的~", "tag", "cyan", x=0.3, y=0.16, size=70, rot=-4, dur=1.8),
               cap(1.8, "队友呢？？", color="pink", x=0.62, y=0.24, size=110, rot=5, dur=1.9, sfx="boing")]),
    dict(clip="e_boulder_front", start=2.6, dur=2 * B, fx=[("shake", 1.0, 0.8)],
         caps=[cap(0.1, "埃及 · 滚石长廊", "tag", "yellow", x=0.2, y=0.12, size=54, rot=-3, dur=1.2),
               cap(0.9, "快跑！！！", "big", "orange", y=0.3, size=200, dur=1.8, anim="shake", sfx="whoosh", vol=0.8)]),
    dict(clip="m_rockets_fp", start=3.6, speed=0.7, dur=B, fx=[("punch", 0.8, 0.2)],
         caps=[cap(0.85, "队友被火箭炸飞 ×1", "tag", "pink", x=0.3, y=0.2, size=66, rot=-5, dur=1.0, sfx="bonk")]),
    dict(clip="m_rockets_chase", start=4.0, speed=0.5, dur=B, fx=[("zoom", 0, 1.35, 1.0, 0.3, 0.45)],
         caps=[cap(0.4, "空中飞人！", color="cyan", x=0.62, y=0.2, size=110, rot=4, dur=1.4, sfx="boing")]),
    # 6. 掉进深渊：定格变灰（How to Fish 的 You are dead 那种）
    dict(clip="e_blades_side", start=3.0, dur=2 * B, freeze=1.6, fx=[("grey", 2.15)],
         sfx=[(1.2, "fall", 0.8)],
         caps=[cap(2.2, "体面值 -20", "big", "red", y=0.42, size=170, dur=1.5, anim="slam", sfx="bonk"),
               cap(2.5, "棺材：我先下去了", "plain", y=0.62, size=58, dur=1.2, anim="float", sfx="")]),
    # 7. 特色：视错觉断桥
    dict(clip="c_bridge_iso", start=0.6, dur=2 * B,
         caps=[cap(0.2, "俯视：转个视角——", "tag", "cyan", x=0.28, y=0.16, size=66, rot=-4, dur=2.9),
               cap(3.0, "断桥接上了！", x=0.6, y=0.8, size=110, dur=0.75, sfx="ding")]),
    dict(clip="c_bridge_fall_fp", start=2.2, speed=0.8, dur=2 * B, sfx=[(2.4, "fall", 0.8)],
         caps=[cap(0.2, "第一人称：桥明明是断的", "tag", "green", x=0.32, y=0.15, size=58, rot=-3, dur=2.4),
               cap(1.1, "相信队友，闭眼走！", color="yellow", x=0.6, y=0.78, size=90, dur=1.6),
               cap(2.8, "队友没转好……", "big", "red", y=0.42, size=150, dur=0.95, anim="slam", sfx="bonk")]),
    # 8. 三座灵堂
    dict(clip="m_market_orbit", start=2.0, dur=2 * B,
         caps=[cap(0.3, "中国 · 埃及 · 墨西哥", color="purple", y=0.16, size=100, dur=3.3)]),
    dict(clip="m_cemetery_fp", start=4.0, dur=2 * B,
         caps=[cap(0.3, "三座不讲道理的灵堂", "tag", "orange", x=0.34, y=0.16, size=66, rot=-3, dur=3.2),
               cap(1.6, "每关都藏着近路和秘密", "tag", "green", x=0.66, y=0.82, size=60, rot=3, dur=2.0)]),
    # 9. 慢动作回放
    dict(clip="c_push_high", start=3.9, speed=0.4, dur=2 * B, fx=[("zoom", 0, 1.4, 1.2, 0.45, 0.42)],
         caps=[cap(0.0, "慢动作回放", "tag", "red", x=0.15, y=0.1, size=50, rot=-3, dur=3.7),
               cap(1.3, "空中转体 720°！", color="yellow", x=0.62, y=0.2, size=110, rot=4, dur=2.3, sfx="boing")]),
    # 10. 联机
    dict(clip="online_host", start=1.0, dur=2 * B, fx=[("blurbox", 0, 0.25, 0.137, 0.75, 0.62), ("zoom", 0, 1.9, 0.6, 0.5, 0.16)],
         caps=[cap(0.8, "输入 4 位房间号", "tag", "green", y=0.62, size=72, rot=-2, dur=2.9),
               cap(2.0, "拉上朋友一起抬！", y=0.8, size=110, dur=1.7)]),
    # 11. 快切：一个字一个镜头
    dict(clip="c_push_fp", start=4.2, dur=B / 2,
         caps=[cap(0, "飞！", "big", "pink", y=0.4, size=240, dur=B / 2, anim="slam", sfx="bonk")]),
    dict(clip="m_rockets_fp", start=4.15, dur=B / 2,
         caps=[cap(0, "炸！", "big", "orange", y=0.4, size=240, dur=B / 2, anim="slam", sfx="bonk")]),
    dict(clip="e_blades_side", start=4.25, dur=B / 2,
         caps=[cap(0, "掉！", "big", "cyan", y=0.4, size=240, dur=B / 2, anim="slam", sfx="fall", vol=0.5)]),
    dict(clip="c_fake_fp", start=8.6, dur=B / 2,
         caps=[cap(0, "抬！", "big", "yellow", y=0.4, size=240, dur=B / 2, anim="slam", sfx="pop")]),
    # 12. 送达 + 结算
    dict(clip="c_altar_result", start=7.6, speed=1.1, dur=3 * B, fx=[("zoom", 3.9, 1.55, 0.5, 0.5, 0.5)],
         caps=[cap(0.7, "送达！", size=150, y=0.2, dur=2.2, sfx="ding"),
               cap(4.4, "评级 A", "tag", "yellow", x=0.72, y=0.3, size=72, rot=4, dur=1.2, sfx="ding"),
               cap(4.9, "奖章拿到手软", "tag", "pink", x=0.72, y=0.46, size=64, rot=-3, dur=0.7)]),
    # 13. 片尾：大和弦落在这里
    dict(clip="title", start=4.0, dur=4.875, fx=[("blur", 0), ("fadeout", 4.0, 0.8)],
         caps=[cap(0, "棺不住", "big", "yellow", y=0.36, size=260, dur=4.8, anim="slam", sfx="bonk"),
               cap(0.5, "Rest in Pieces", "flower", "cyan", y=0.55, size=96, dur=4.3),
               cap(1.2, "2–4 人联机物理派对游戏", "tag", "pink", y=0.71, size=60, dur=3.6),
               cap(2.0, "一起来抬吧！", "plain", y=0.85, size=56, dur=2.8, anim="float", sfx="")]),
]
