"""把 promo/raw 里录好的镜头剪成宣传片：切镜头、慢放、推镜头、震屏、定格变灰，
再叠上综艺花字式的弹出字幕和音效，配上 promo/audio/bgm.wav，输出 promo/out/棺不住_宣传片.mp4。

  python tools/promo_edit.py            # 完整输出
  python tools/promo_edit.py --preview  # 960x540、只出每段的缩略图，检查节奏和字幕位置

剪辑表在 promo_cut.py 里（CUT），这里只管怎么画。
"""
import subprocess
import sys
import wave
from functools import lru_cache
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

sys.path.insert(0, str(Path(__file__).resolve().parent))
from promo_cut import CUT  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
RAW = ROOT / "promo" / "raw"
AUDIO = ROOT / "promo" / "audio"
OUT = ROOT / "promo" / "out"
FONT = str(ROOT / "game" / "assets" / "fonts" / "ZCOOLKuaiLe-Regular.ttf")
FPS = 60
W, H = 1920, 1080
SR = 44100

COLORS = {
    "yellow": (255, 213, 74), "pink": (255, 111, 168), "cyan": (90, 220, 255), "green": (140, 230, 110),
    "red": (255, 80, 70), "white": (255, 255, 255), "orange": (255, 150, 60), "purple": (180, 130, 255),
}
DARK = (35, 20, 40)


# ---------- 字幕贴纸 ----------

@lru_cache(maxsize=256)
def sticker(text: str, size: int, color: str, style: str) -> Image.Image:
    """渲染一张字幕贴纸（RGBA）。style: flower = 白字彩边黑描边；tag = 彩色圆角底板白字；
    big = 超大彩字；plain = 白字黑影（How to Fish 那种安静的字）"""
    font = ImageFont.truetype(FONT, size)
    lines = text.split("\n")
    pad = size // 2
    boxes = [font.getbbox(l) for l in lines]
    tw = max(b[2] - b[0] for b in boxes)
    lh = int(size * 1.15)
    th = lh * len(lines)
    img = Image.new("RGBA", (tw + pad * 4, th + pad * 4), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    c = COLORS[color]
    ox, oy = pad * 2, pad * 2
    if style == "tag":
        d.rounded_rectangle([ox - pad * 0.8, oy - pad * 0.5, ox + tw + pad * 0.8, oy + th + pad * 0.3],
                            radius=size // 3, fill=c + (255,), outline=DARK + (255,), width=max(4, size // 14))
    shadow = Image.new("RGBA", img.size, (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow)
    for i, l in enumerate(lines):
        x = ox + (tw - (boxes[i][2] - boxes[i][0])) / 2 - boxes[i][0]
        y = oy + i * lh - boxes[i][1] + (lh - size) / 2
        if style == "tag":
            d.text((x, y), l, font=font, fill=(255, 255, 255), stroke_width=max(3, size // 16), stroke_fill=DARK)
            continue
        sd.text((x + size * 0.05, y + size * 0.08), l, font=font, fill=(0, 0, 0, 120),
                stroke_width=size // 7 if style != "plain" else 0, stroke_fill=(0, 0, 0, 120))
        if style == "plain":
            d.text((x, y), l, font=font, fill=(255, 255, 255))
        elif style == "big":
            d.text((x, y), l, font=font, fill=c, stroke_width=size // 8, stroke_fill=DARK)
            d.text((x, y), l, font=font, fill=c, stroke_width=size // 22, stroke_fill=(255, 255, 255))
        else:  # flower：外圈黑、中圈彩色、里面白字
            d.text((x, y), l, font=font, fill=DARK, stroke_width=size // 6, stroke_fill=DARK)
            d.text((x, y), l, font=font, fill=c, stroke_width=size // 10, stroke_fill=c)
            d.text((x, y), l, font=font, fill=(255, 255, 255))
    shadow = shadow.filter(ImageFilter.GaussianBlur(size / 18))
    return Image.alpha_composite(shadow, img)


def ease_pop(u: float) -> float:
    """0→1 的弹出缩放：先冲过头再回弹"""
    if u >= 1:
        return 1.0
    return 1 + 2.7 * (u - 1) ** 3 + 1.7 * (u - 1) ** 2


def draw_caption(frame: Image.Image, cap: dict, t: float) -> None:
    """cap: {t, dur, text, size, color, style, x, y, rot, anim}；t 是这段里的时间"""
    u = t - cap["t"]
    dur = cap.get("dur", 1.6)
    if u < 0 or u > dur:
        return
    img = sticker(cap["text"], cap.get("size", 90), cap.get("color", "yellow"), cap.get("style", "flower"))
    anim = cap.get("anim", "pop")
    a_in = min(1, u / 0.22)
    out = max(0.0, (u - (dur - 0.18)) / 0.18)
    scale = 1.0
    rot = cap.get("rot", 0.0)
    dx = dy = 0.0
    alpha = 1.0
    if anim == "pop":
        scale = ease_pop(a_in) * (1 - out)
        rot += np.sin(u * 7) * 2.0 * (1 - a_in * 0.5)
    elif anim == "slam":  # 从大砸下来
        scale = (1 + 2.0 * (1 - a_in) ** 2) * (1 - out * 0.3)
        alpha = a_in * (1 - out)
    elif anim == "slide":  # 从左边滑进来
        dx = -W * 0.6 * (1 - a_in) ** 3 + W * 0.6 * out ** 2
    elif anim == "float":  # 慢慢浮现、往上飘（安静的字）
        alpha = min(1, u / 0.4) * (1 - out)
        dy = -u * 12
    elif anim == "shake":
        scale = ease_pop(a_in) * (1 - out)
        dx = np.sin(u * 60) * 8 * max(0, 1 - u / 0.6)
    if scale <= 0.01 or alpha <= 0.01:
        return
    im = img
    if scale != 1.0 or rot:
        im = img.resize((max(1, int(img.width * scale)), max(1, int(img.height * scale))), Image.BILINEAR)
        im = im.rotate(rot, Image.BILINEAR, expand=True)
    if alpha < 1:
        im = im.copy()
        im.putalpha(im.getchannel("A").point(lambda v: int(v * alpha)))
    x = int(cap.get("x", 0.5) * W + dx - im.width / 2)
    y = int(cap.get("y", 0.2) * H + dy - im.height / 2)
    frame.alpha_composite(im, (max(0, x), max(0, y)), (max(0, -x), max(0, -y)))


# ---------- 画面 ----------

def read_clip(name: str, start: float, dur: float, speed: float, w: int, h: int):
    """从录好的 avi 里按速度读出 dur 秒（输出时长）的帧"""
    src_dur = dur * speed
    vf = f"setpts=PTS/{speed},fps={FPS},scale={w}:{h}"
    cmd = ["ffmpeg", "-v", "error", "-ss", f"{start:.3f}", "-t", f"{src_dur:.3f}", "-i", str(RAW / f"{name}.avi"),
           "-vf", vf, "-f", "rawvideo", "-pix_fmt", "rgb24", "-"]
    p = subprocess.Popen(cmd, stdout=subprocess.PIPE)
    n = int(round(dur * FPS))
    last = None
    for _ in range(n):
        buf = p.stdout.read(w * h * 3)
        if len(buf) < w * h * 3:
            buf = last  # 素材不够长就停在最后一帧
        last = buf
        yield np.frombuffer(buf, np.uint8).reshape(h, w, 3) if buf else np.zeros((h, w, 3), np.uint8)
    p.stdout.close()
    p.wait()


def zoom(arr: np.ndarray, z: float, cx=0.5, cy=0.5) -> np.ndarray:
    if z <= 1.001:
        return arr
    h, w = arr.shape[:2]
    cw, ch = int(w / z), int(h / z)
    x0 = int(np.clip(cx * w - cw / 2, 0, w - cw))
    y0 = int(np.clip(cy * h - ch / 2, 0, h - ch))
    return np.asarray(Image.fromarray(arr[y0:y0 + ch, x0:x0 + cw]).resize((w, h), Image.BILINEAR))


def apply_fx(arr: np.ndarray, seg: dict, t: float) -> np.ndarray:
    for fx in seg.get("fx", []):
        kind, ft = fx[0], fx[1]
        u = t - ft
        if kind == "punch" and 0 <= u < 0.5:  # 猛地推近再退回
            z = 1 + fx[2] * np.exp(-u / 0.12) if len(fx) > 2 else 1 + 0.18 * np.exp(-u / 0.12)
            arr = zoom(arr, z, *(fx[3:5] if len(fx) > 4 else (0.5, 0.5)))
        elif kind == "zoom" and u >= 0:  # 慢慢推近：("zoom", 开始, 结束倍数, 用时, cx, cy)
            k = min(1, u / fx[3])
            arr = zoom(arr, 1 + (fx[2] - 1) * (k * k * (3 - 2 * k)), *(fx[4:6] if len(fx) > 5 else (0.5, 0.5)))
        elif kind == "shake" and 0 <= u < fx[2]:
            amp = 18 * (1 - u / fx[2])
            dx, dy = int(np.sin(u * 77) * amp), int(np.cos(u * 61) * amp)
            arr = np.roll(np.roll(arr, dx, axis=1), dy, axis=0)
        elif kind == "grey" and u >= 0:  # 定格那种褪色
            k = min(1, u / 0.25)
            g = arr.mean(axis=2, keepdims=True, dtype=np.float32)
            arr = (arr * (1 - k * 0.85) + g * k * 0.85).astype(np.uint8)
            arr = (arr * (1 - 0.25 * k)).astype(np.uint8)
        elif kind == "flash" and 0 <= u < 0.25:
            k = 1 - u / 0.25
            arr = np.clip(arr + 255 * k * 0.7, 0, 255).astype(np.uint8)
        elif kind == "fadein" and u < fx[2]:
            arr = (arr * max(0, u / fx[2])).astype(np.uint8)
        elif kind == "fadeout":
            k = min(1, max(0, (t - ft) / fx[2]))
            arr = (arr * (1 - k)).astype(np.uint8)
        elif kind == "blurbox":  # 打码：("blurbox", 开始, x0, y0, x1, y1)，坐标是画面比例
            h, w = arr.shape[:2]
            x0, y0, x1, y1 = int(fx[2] * w), int(fx[3] * h), int(fx[4] * w), int(fx[5] * h)
            arr = arr.copy()
            box = Image.fromarray(arr[y0:y1, x0:x1]).filter(ImageFilter.GaussianBlur(w / 60))
            arr[y0:y1, x0:x1] = np.asarray(box)
        elif kind == "blur" and u >= 0:
            arr = np.asarray(Image.fromarray(arr).filter(ImageFilter.GaussianBlur(min(1, u / 0.4) * 14)))
    return arr


def frames(seg: dict, w: int, h: int):
    dur = seg["dur"]
    if seg.get("freeze"):  # 前面一段正常放，最后 freeze 秒停在同一帧
        live = dur - seg["freeze"]
        last = None
        for arr in read_clip(seg["clip"], seg["start"], live, seg.get("speed", 1.0), w, h):
            last = arr
            yield arr
        for _ in range(int(round(seg["freeze"] * FPS))):
            yield last
        return
    if "clip" not in seg:  # 纯色底（片尾）
        for _ in range(int(round(dur * FPS))):
            yield np.full((h, w, 3), seg.get("bg", (20, 14, 26)), np.uint8)
        return
    yield from read_clip(seg["clip"], seg["start"], dur, seg.get("speed", 1.0), w, h)


# ---------- 声音 ----------

def load_wav(path: Path) -> np.ndarray:
    with wave.open(str(path)) as w:
        x = np.frombuffer(w.readframes(w.getnframes()), np.int16).astype(np.float32) / 32767
    return x.reshape(-1, 2)


def mix_audio(total: float, path: Path) -> None:
    out = np.zeros((int(total * SR) + SR, 2), np.float32)
    bgm = load_wav(AUDIO / "bgm.wav") * 0.8
    n = min(len(bgm), len(out))
    out[:n] += bgm[:n]
    t0 = 0.0
    for seg in CUT:
        for cap in seg.get("caps", []):
            if cap.get("sfx", "pop"):
                s = load_wav(AUDIO / f"sfx_{cap.get('sfx', 'pop')}.wav")
                i = int((t0 + cap["t"]) * SR)
                out[i:i + len(s)] += s[: len(out) - i] * cap.get("vol", 0.7)
        for at, name, vol in seg.get("sfx", []):
            s = load_wav(AUDIO / f"sfx_{name}.wav")
            i = int((t0 + at) * SR)
            out[i:i + len(s)] += s[: len(out) - i] * vol
        t0 += seg["dur"]
    fade = int(1.5 * SR)
    end = int(total * SR)
    out[end - fade:end] *= np.linspace(1, 0, fade)[:, None]
    out = out[:end]
    out /= max(1.0, np.abs(out).max() / 0.97)
    with wave.open(str(path), "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((out * 32767).astype(np.int16).tobytes())


# ---------- 主流程 ----------

def render(preview: bool) -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    w, h = (960, 540) if preview else (W, H)
    total = sum(s["dur"] for s in CUT)
    wav = OUT / "mix.wav"
    mix_audio(total, wav)
    dst = OUT / ("preview.mp4" if preview else "棺不住_宣传片.mp4")
    enc = subprocess.Popen(
        ["ffmpeg", "-v", "error", "-y", "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", f"{w}x{h}", "-r", str(FPS),
         "-i", "-", "-i", str(wav), "-c:v", "libx264", "-preset", "veryfast" if preview else "medium", "-threads", "2",
         "-crf", "24" if preview else "17", "-pix_fmt", "yuv420p", "-c:a", "aac", "-b:a", "192k",
         "-shortest", "-movflags", "+faststart", str(dst)], stdin=subprocess.PIPE)
    s = w / W
    for k, seg in enumerate(CUT):
        for i, arr in enumerate(frames(seg, w, h)):
            t = i / FPS
            arr = apply_fx(arr, seg, t)
            img = Image.fromarray(arr).convert("RGBA")
            if seg.get("caps"):
                layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
                for cap in seg["caps"]:
                    draw_caption(layer, cap, t)
                if s != 1:
                    layer = layer.resize((w, h), Image.BILINEAR)
                img.alpha_composite(layer)
            enc.stdin.write(img.convert("RGB").tobytes())
        print(f"段 {k + 1}/{len(CUT)} {seg.get('clip', '片尾')} {seg['dur']}s", flush=True)
    enc.stdin.close()
    enc.wait()
    print(dst, f"{total:.1f}s")


if __name__ == "__main__":
    render("--preview" in sys.argv)
