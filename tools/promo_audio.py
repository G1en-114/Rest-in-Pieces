"""宣传片的配乐和音效，全部用 numpy 现合成（不用任何外部素材，没有版权问题）。

  python tools/promo_audio.py   # 生成 promo/audio/bgm.wav 和 promo/audio/sfx_*.wav

配乐结构：先是 INTRO 秒庄重的葬礼管风琴，然后唱片一刮，128 BPM 的欢快鼓点和木琴旋律进来，
最后一小节收在一个大和弦上。
"""
import wave
from pathlib import Path

import numpy as np

SR = 44100
BPM = 128
BEAT = 60 / BPM
BAR = BEAT * 4
INTRO = 4 * BEAT * 2  # 两小节管风琴（3.75 秒）
BARS = 34  # 鼓点部分几个小节
OUT = Path(__file__).resolve().parent.parent / "promo" / "audio"
rng = np.random.default_rng(7)


def note(n: float) -> float:
    """MIDI 音高 → 频率"""
    return 440.0 * 2 ** ((n - 69) / 12)


def env(n: int, a: float, d: float) -> np.ndarray:
    t = np.arange(n) / SR
    return np.minimum(1, t / max(a, 1e-4)) * np.exp(-t / d)


def tone(f: float, dur: float, kind="sine") -> np.ndarray:
    t = np.arange(int(dur * SR)) / SR
    if kind == "organ":
        return sum(np.sin(2 * np.pi * f * h * t) / h ** 1.3 for h in (1, 2, 3, 4, 6, 8))
    if kind == "square":
        return np.sign(np.sin(2 * np.pi * f * t)) * 0.5 + np.sin(2 * np.pi * f * t) * 0.5
    if kind == "marimba":  # 木琴：基音 + 4 倍泛音快速衰减
        return np.sin(2 * np.pi * f * t) + 0.35 * np.sin(2 * np.pi * f * 4 * t) * np.exp(-t / 0.05)
    return np.sin(2 * np.pi * f * t)


def add(buf: np.ndarray, x: np.ndarray, at: float, gain=1.0) -> None:
    i = int(at * SR)
    if i >= len(buf):
        return
    x = x[: len(buf) - i]
    buf[i: i + len(x)] += x * gain


def kick() -> np.ndarray:
    n = int(0.35 * SR)
    t = np.arange(n) / SR
    f = 50 + 110 * np.exp(-t / 0.04)
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / 0.12)


def clap() -> np.ndarray:
    n = int(0.25 * SR)
    t = np.arange(n) / SR
    noise = rng.uniform(-1, 1, n)
    bursts = sum(np.exp(-np.maximum(0, t - d) / 0.006) * (t >= d) for d in (0, 0.01, 0.02))
    return noise * (bursts * 0.5 + np.exp(-t / 0.08)) * 0.6


def hat(open_=False) -> np.ndarray:
    n = int((0.18 if open_ else 0.05) * SR)
    x = rng.uniform(-1, 1, n)
    x = np.diff(x, prepend=0)  # 粗糙高通
    return x * env(n, 0.001, 0.06 if open_ else 0.015) * 0.35


def bgm() -> np.ndarray:
    total = INTRO + BARS * BAR + 3.0
    buf = np.zeros(int(total * SR))
    # 管风琴：Dm - A - Dm（庄重、慢）
    for i, chord in enumerate([[50, 53, 57, 62], [49, 52, 57, 61], [50, 53, 57, 62]]):
        d = INTRO / 3 + 0.3
        for n in chord:
            x = tone(note(n), d, "organ") * env(int(d * SR), 0.25, 3.0)
            add(buf, x * np.minimum(1, (d - np.arange(len(x)) / SR) / 0.3), i * INTRO / 3, 0.05)
    t0 = INTRO
    prog = [[60, 64, 67], [55, 59, 62], [57, 60, 64], [53, 57, 60]]  # C G Am F
    bass_root = [36, 43, 45, 41]
    # 旋律：每两小节一句，C 大调五声，蹦蹦跳跳
    hook = [(0, 76), (0.5, 79), (1, 81), (1.5, 79), (2, 76), (3, 74), (3.5, 76),
            (4, 72), (4.5, 74), (5, 76), (6, 79), (6.5, 81), (7, 84)]
    hook2 = [(0, 81), (0.5, 79), (1, 76), (1.5, 79), (2, 81), (3, 84), (3.5, 81),
             (4, 79), (4.5, 76), (5, 74), (5.5, 76), (6, 72), (7, 72)]
    for bar in range(BARS):
        b0 = t0 + bar * BAR
        chord = prog[bar % 4]
        last = bar == BARS - 1
        for beat in range(4):
            bt = b0 + beat * BEAT
            if last and beat > 0:
                break
            add(buf, kick(), bt, 0.9)
            if beat in (1, 3):
                add(buf, clap(), bt, 0.55)
            add(buf, hat(), bt + BEAT / 2, 0.8)
            add(buf, hat(beat == 3), bt + BEAT * 0.75, 0.4)
            # 贝斯：根音 + 八度弹跳
            for k, n in enumerate((bass_root[bar % 4], bass_root[bar % 4] + 12)):
                x = tone(note(n), BEAT / 2, "square") * env(int(BEAT / 2 * SR), 0.005, 0.12)
                add(buf, x, bt + k * BEAT / 2, 0.16)
            # 反拍和弦（拨弦感）
            for n in chord:
                x = tone(note(n), 0.2, "square") * env(int(0.2 * SR), 0.003, 0.05)
                add(buf, x, bt + BEAT / 2, 0.035)
        if bar >= 2 and not last:  # 前两小节只有鼓和贝斯，然后旋律进来
            phrase = hook if (bar // 2) % 2 == 0 else hook2
            half = bar % 2
            for pos, n in phrase:
                if half * 4 <= pos < half * 4 + 4:
                    x = tone(note(n), 0.5, "marimba") * env(int(0.5 * SR), 0.002, 0.18)
                    add(buf, x, b0 + (pos - half * 4) * BEAT, 0.22)
        if bar % 8 == 7 and not last:  # 每 8 小节加一个军鼓滚奏过门
            for k in range(8):
                add(buf, clap(), b0 + 2 * BEAT + k * BEAT / 4, 0.25 + k * 0.04)
    # 收尾大和弦
    end = t0 + (BARS - 1) * BAR
    for n in (48, 60, 64, 67, 72, 76):
        x = tone(note(n), 2.8, "marimba") * env(int(2.8 * SR), 0.003, 1.0)
        add(buf, x, end, 0.12)
        x = tone(note(n), 2.8, "organ") * env(int(2.8 * SR), 0.05, 1.2)
        add(buf, x, end, 0.025)
    add(buf, kick(), end, 1.0)
    return buf


def sfx() -> dict[str, np.ndarray]:
    out = {}
    t = np.arange(int(0.5 * SR)) / SR
    # 弹簧 boing：音高上下抖着往上走
    f = 180 + 260 * t / 0.5 + 60 * np.sin(2 * np.pi * 14 * t)
    out["boing"] = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / 0.25) * 0.7
    # 撞到：低沉的 bonk + 一点噪声
    t = np.arange(int(0.3 * SR)) / SR
    f = 120 + 300 * np.exp(-t / 0.02)
    out["bonk"] = (np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / 0.08)
                   + rng.uniform(-1, 1, len(t)) * np.exp(-t / 0.02) * 0.4) * 0.9
    # 掉下去：口哨下滑
    t = np.arange(int(1.2 * SR)) / SR
    f = 1400 * (0.25 ** (t / 1.2))
    out["fall"] = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.minimum(1, (1.2 - t) / 0.2) * 0.35
    # 字幕弹出：短促的 pop
    t = np.arange(int(0.09 * SR)) / SR
    f = 900 * (2 ** (t / 0.09))
    out["pop"] = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / 0.03) * 0.5
    # 唱片刮停
    t = np.arange(int(0.45 * SR)) / SR
    f = 300 + 900 * np.abs(np.sin(2 * np.pi * 3.2 * t))
    out["scratch"] = (np.sin(2 * np.pi * np.cumsum(f) / SR) * 0.4
                      + rng.uniform(-1, 1, len(t)) * 0.5) * np.exp(-t / 0.3) * 0.6
    # 嗖：带通噪声扫过去
    n = int(0.4 * SR)
    t = np.arange(n) / SR
    x = rng.uniform(-1, 1, n)
    y = np.zeros(n)
    for i in range(2, n):  # 二阶共振，频率从低扫到高
        fc = 300 + 2500 * t[i] / 0.4
        r = 0.97
        y[i] = x[i] + 2 * r * np.cos(2 * np.pi * fc / SR) * y[i - 1] - r * r * y[i - 2]
    out["whoosh"] = y / np.abs(y).max() * np.sin(np.pi * t / 0.4) * 0.5
    # 叮：拿到花圈、奖章
    t = np.arange(int(0.6 * SR)) / SR
    out["ding"] = (np.sin(2 * np.pi * 1318 * t) + 0.5 * np.sin(2 * np.pi * 1976 * t)) * np.exp(-t / 0.2) * 0.35
    return out


def save(path: Path, x: np.ndarray) -> None:
    x = x / max(1.0, np.abs(x).max() / 0.95)
    data = (np.stack([x, x], axis=1) * 32767).astype(np.int16)
    with wave.open(str(path), "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    save(OUT / "bgm.wav", bgm())
    for name, x in sfx().items():
        save(OUT / f"sfx_{name}.wav", x)
    print("intro=%.3f beat=%.4f bar=%.4f total=%.1f" % (INTRO, BEAT, BAR, INTRO + BARS * BAR + 3))


if __name__ == "__main__":
    main()
