"""合辑版宣传片：原宣传片（到送达 + 结算）→ 新功能「自定义角色」→ 共同片尾。

  python tools/promo_audio.py --bars=50 --out=bgm_long.wav   # 先生成加长配乐（大和弦落在片尾第一帧）
  python tools/promo_edit.py --cut=promo_cut_full
"""
import promo_cut
import promo_cut_chars
from promo_cut import cap

NAME = "棺不住_宣传片_完整版"
BGM = "bgm_long.wav"

main = promo_cut.CUT[:-1]  # 去掉原片尾
chars = [dict(s) for s in promo_cut_chars.CUT[1:-1]]  # 去掉短片自己的开场和片尾
# 新功能段的第一个镜头：先亮出“新功能”，再接原来的字幕
chars[0]["caps"] = [cap(0.0, "新功能！", "big", "yellow", y=0.4, size=200, dur=0.75, anim="slam", sfx="ding")] + [
    dict(c, t=c["t"] + 0.6) if c["t"] < 0.6 else c for c in chars[0]["caps"]]

CUT = main + chars + [
    dict(clip="title", start=4.0, dur=4.875, fx=[("blur", 0), ("fadeout", 4.0, 0.8)],
         caps=[cap(0, "棺不住", "big", "yellow", y=0.32, size=260, dur=4.8, anim="slam", sfx="bonk"),
               cap(0.5, "Rest in Pieces", "flower", "cyan", y=0.51, size=96, dur=4.3),
               cap(1.1, "双人同屏 · 房间号联机 · 自定义角色", "tag", "pink", y=0.67, size=58, dur=3.7),
               cap(2.0, "把朋友（和猫）送进灵堂", "plain", y=0.84, size=56, dur=2.8, anim="float", sfx="")]),
]
assert abs(sum(s["dur"] for s in CUT) - (100.5)) < 0.01, sum(s["dur"] for s in CUT)
