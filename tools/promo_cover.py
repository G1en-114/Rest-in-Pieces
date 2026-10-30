"""作品封面：滚石镜头当底图，左上角游戏名，右下角贴一张“队友起飞”的拍立得，字和宣传片同一套花字。

  python tools/promo_cover.py   # 生成 promo/out/棺不住_封面.png（1920x1080）和 _封面_方.png（1080x1080）

底图从 promo/raw 里录好的镜头截帧（先跑 promo_shots.py）。
"""
import subprocess
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

sys.path.insert(0, str(Path(__file__).resolve().parent))
from promo_edit import FONT, sticker  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
RAW = ROOT / "promo" / "raw"
OUT = ROOT / "promo" / "out"


def grab(clip: str, t: float) -> Image.Image:
    png = OUT / f"_grab_{clip}.png"
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-ss", str(t), "-i", str(RAW / f"{clip}.avi"), "-frames:v", "1",
                    str(png)], check=True)
    return Image.open(png).convert("RGBA")


def paste(base: Image.Image, im: Image.Image, cx: float, cy: float, rot=0.0) -> None:
    if rot:
        im = im.rotate(rot, Image.BICUBIC, expand=True)
    base.alpha_composite(im, (int(cx * base.width - im.width / 2), int(cy * base.height - im.height / 2)))


def polaroid(photo: Image.Image, w: int, caption: str) -> Image.Image:
    """白边拍立得：照片 + 底下一行手写字"""
    ph = photo.resize((w, int(w * photo.height / photo.width)), Image.LANCZOS)
    pad = w // 22
    card = Image.new("RGBA", (w + pad * 2, ph.height + pad * 2 + w // 7), (250, 247, 240, 255))
    card.paste(ph, (pad, pad))
    font = ImageFont.truetype(FONT, w // 13)
    d = ImageDraw.Draw(card)
    tw = d.textlength(caption, font=font)
    d.text(((card.width - tw) / 2, ph.height + pad * 1.4), caption, font=font, fill=(40, 30, 40))
    # 投影
    shadow = Image.new("RGBA", (card.width + 60, card.height + 60), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rectangle([30, 36, card.width + 30, card.height + 36], fill=(0, 0, 0, 110))
    shadow = shadow.filter(ImageFilter.GaussianBlur(14))
    shadow.alpha_composite(card, (30, 30))
    return shadow


def vignette(base: Image.Image, strength=0.55) -> None:
    w, h = base.size
    y, x = np.ogrid[:h, :w]
    # 左上角压暗一点，给标题让位；四角稍暗
    d = np.sqrt(((x - w * 0.62) / w) ** 2 + ((y - h * 0.6) / h) ** 2)
    a = np.clip((d - 0.25) * strength * 1.6, 0, strength)
    layer = Image.fromarray((np.dstack([np.zeros((h, w, 3)), a * 255])).astype(np.uint8), "RGBA")
    base.alpha_composite(layer)


def wide() -> Image.Image:
    base = grab("e_boulder_front", 3.8).resize((1920, 1080), Image.LANCZOS)
    vignette(base)
    paste(base, sticker("棺不住", 250, "yellow", "big"), 0.24, 0.2, rot=4)
    paste(base, sticker("Rest in Pieces", 96, "cyan", "flower"), 0.25, 0.38, rot=2)
    paste(base, sticker("一群站不稳的抬棺人", 58, "pink", "tag"), 0.22, 0.53, rot=-3)
    paste(base, sticker("一座不讲物理的灵堂", 58, "green", "tag"), 0.26, 0.63, rot=2)
    paste(base, sticker("快跑！！", 110, "orange", "flower"), 0.86, 0.36, rot=-8)
    paste(base, polaroid(grab("m_rockets_fp", 4.4).convert("RGB"), 470, "队友，起飞中"), 0.16, 0.88, rot=-7)
    paste(base, sticker("物理抬棺 · 第一人称 · 视错觉解谜 · 联机", 40, "white", "plain"), 0.68, 0.94)
    return base


def square() -> Image.Image:
    src = grab("e_boulder_front", 3.8)
    side = src.height
    x0 = int(src.width * 0.58 - side / 2)
    base = src.crop((x0, 0, x0 + side, side)).resize((1080, 1080), Image.LANCZOS)
    vignette(base, 0.5)
    paste(base, sticker("棺不住", 220, "yellow", "big"), 0.5, 0.15, rot=3)
    paste(base, sticker("Rest in Pieces", 84, "cyan", "flower"), 0.5, 0.31, rot=1)
    paste(base, sticker("快跑！！", 96, "orange", "flower"), 0.78, 0.5, rot=-8)
    paste(base, sticker("一群站不稳的抬棺人", 52, "pink", "tag"), 0.3, 0.86, rot=-3)
    return base


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    wide().convert("RGB").save(OUT / "棺不住_封面.png")
    square().convert("RGB").save(OUT / "棺不住_封面_方.png")
    for p in OUT.glob("_grab_*.png"):
        p.unlink()
    print(OUT / "棺不住_封面.png")


if __name__ == "__main__":
    main()
