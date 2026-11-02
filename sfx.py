"""用程式合成音效，依動畫時間點混成一個 wav。
用法：python3 sfx.py events.json 輸出.wav 秒數
events.json 是 [{"t": 0.05, "type": "pop", ...}, ...]，由 index.html 的 SFX 清單產生。
全部自己合成，沒有用到外部音效素材，不會有版權問題。
"""
import json
import sys
import wave

import numpy as np

SR = 48000
rng = np.random.default_rng(3)


def env(n, attack=0.005, decay=0.2):
    t = np.arange(n) / SR
    a = np.clip(t / max(attack, 1e-4), 0, 1)
    return a * np.exp(-t / decay)


def svf_bandpass(x, f0, f1, q=0.7):
    """頻率從 f0 掃到 f1 的帶通濾波（state variable filter）。"""
    n = len(x)
    fc = np.geomspace(f0, f1, n)
    g = 2 * np.sin(np.pi * np.clip(fc, 20, SR / 6) / SR)
    lp = bp = 0.0
    out = np.empty(n)
    for i in range(n):
        hp = x[i] - lp - bp / q
        bp += g[i] * hp
        lp += g[i] * bp
        out[i] = bp
    return out


def sweep(f0, f1, dur, shape="exp"):
    n = int(dur * SR)
    f = np.geomspace(f0, f1, n) if shape == "exp" else np.linspace(f0, f1, n)
    return np.sin(2 * np.pi * np.cumsum(f) / SR)


def pop(gain=1.0, pitch=1.0, **_):
    d = 0.12
    s = sweep(700 * pitch, 180 * pitch, d) * env(int(d * SR), 0.001, 0.04)
    s += 0.3 * rng.standard_normal(len(s)) * env(len(s), 0.0005, 0.006)
    return s * gain


def blip(gain=1.0, freq=880, **_):
    d = 0.16
    n = int(d * SR)
    t = np.arange(n) / SR
    s = (np.sin(2 * np.pi * freq * t) + 0.25 * np.sin(2 * np.pi * freq * 2 * t)) * env(n, 0.002, 0.05)
    return s * gain * 0.7


def knock(gain=1.0, pitch=1.0, **_):
    """木頭筷子「咔」的一聲。"""
    d = 0.12
    n = int(d * SR)
    t = np.arange(n) / SR
    s = (np.sin(2 * np.pi * 1150 * pitch * t) * env(n, 0.0005, 0.018)
         + 0.6 * np.sin(2 * np.pi * 2650 * pitch * t) * env(n, 0.0005, 0.01))
    s += 0.5 * svf_bandpass(rng.standard_normal(n), 3000, 3000, 2) * env(n, 0.0002, 0.004)
    return s * gain


def whoosh(gain=1.0, dur=0.5, f0=300, f1=3500, **_):
    n = int(dur * SR)
    x = svf_bandpass(rng.standard_normal(n), f0, f1, 1.2)
    t = np.linspace(0, 1, n)
    shape = np.sin(np.pi * t) ** 1.5
    return x * shape * gain * 0.6


def impact(gain=1.0, **_):
    d = 0.9
    n = int(d * SR)
    s = sweep(95, 40, d) * env(n, 0.002, 0.22)
    s += 0.35 * svf_bandpass(rng.standard_normal(n), 900, 200, 0.8) * env(n, 0.001, 0.08)
    return s * gain


def sparkle(gain=1.0, dur=0.6, **_):
    n = int((dur + 0.3) * SR)
    out = np.zeros(n)
    notes = [1568, 1760, 2093, 2349, 2637, 3136, 3520]
    for _ in range(9):
        st = int(rng.uniform(0, dur) * SR)
        f = rng.choice(notes)
        m = int(0.25 * SR)
        t = np.arange(m) / SR
        p = np.sin(2 * np.pi * f * t) * env(m, 0.001, 0.06) * rng.uniform(0.25, 0.6)
        out[st:st + m] += p[: n - st]
    return out * gain


def chime(gain=1.0, root=523.25, **_):
    """收尾的明亮和弦（大三加九）。"""
    d = 2.2
    n = int(d * SR)
    t = np.arange(n) / SR
    s = np.zeros(n)
    for k, ratio in enumerate([1, 1.25, 1.5, 2.25, 2]):
        f = root * ratio
        dl = int(k * 0.035 * SR)
        part = (np.sin(2 * np.pi * f * t) + 0.3 * np.sin(2 * np.pi * f * 2.76 * t) * np.exp(-t / 0.15))
        part = part * env(n, 0.003, 0.7)
        s[dl:] += part[: n - dl] * 0.22
    return s * gain


def riser(gain=1.0, dur=0.6, **_):
    n = int(dur * SR)
    x = svf_bandpass(rng.standard_normal(n), 400, 6000, 1.5)
    t = np.linspace(0, 1, n)
    return x * t ** 2 * gain * 0.5


SOUNDS = dict(pop=pop, blip=blip, knock=knock, whoosh=whoosh, impact=impact,
              sparkle=sparkle, chime=chime, riser=riser)


# ---------- 柔和音色：低一點、圓一點、起音慢一點 ----------
def lowpass(x, fc):
    a = 1 - np.exp(-2 * np.pi * fc / SR)
    y = np.empty_like(x)
    acc = 0.0
    for i in range(len(x)):
        acc += a * (x[i] - acc)
        y[i] = acc
    return y


def softpop(gain=1.0, pitch=1.0, **_):
    d = 0.2
    n = int(d * SR)
    s = sweep(320 * pitch, 110 * pitch, d) * env(n, 0.004, 0.06)
    return lowpass(s, 1500) * gain


def thock(gain=1.0, pitch=1.0, **_):
    """比 knock 低、比較悶的木頭聲。"""
    d = 0.18
    n = int(d * SR)
    t = np.arange(n) / SR
    s = (np.sin(2 * np.pi * 420 * pitch * t) * env(n, 0.0015, 0.035)
         + 0.35 * np.sin(2 * np.pi * 1080 * pitch * t) * env(n, 0.0015, 0.012))
    return lowpass(s, 2000) * gain


def air(gain=1.0, dur=0.6, f0=180, f1=1100, **_):
    n = int(dur * SR)
    x = svf_bandpass(rng.standard_normal(n), f0, f1, 0.6)
    t = np.linspace(0, 1, n)
    return lowpass(x * np.sin(np.pi * t) ** 2, 2500) * gain * 0.7


def thump(gain=1.0, **_):
    d = 0.5
    n = int(d * SR)
    return sweep(75, 45, d) * env(n, 0.006, 0.12) * gain


def mallet(gain=1.0, freq=392, **_):
    """木琴／馬林巴那種圓圓的敲擊聲。"""
    d = 0.9
    n = int(d * SR)
    t = np.arange(n) / SR
    s = (np.sin(2 * np.pi * freq * t) * env(n, 0.002, 0.3)
         + 0.15 * np.sin(2 * np.pi * freq * 4 * t) * env(n, 0.002, 0.025))
    return lowpass(s, 3000) * gain * 0.6


def pad(gain=1.0, root=261.63, dur=2.4, attack=0.06, lp=1800, **_):
    """溫暖的和弦，起音柔、尾巴長。"""
    n = int(dur * SR)
    t = np.arange(n) / SR
    s = np.zeros(n)
    for ratio, amp in [(1, 1), (1.25, .8), (1.5, .8), (2, .5), (2.25, .3)]:
        for det in (-0.6, 0.6):
            s += amp * np.sin(2 * np.pi * (root * ratio + det) * t)
    a = np.clip(t / attack, 0, 1)
    rel = np.clip((dur - t) / 0.9, 0, 1)
    s = s * a * rel * np.exp(-t / 2.5) * 0.09
    return lowpass(s, lp) * gain


# ---------- 輕盈音色：中高音域、短、乾淨，但一樣濾掉刺耳的高頻 ----------
def kalimba(gain=1.0, freq=784, **_):
    """拇指琴般輕輕撥一下。"""
    d = 0.7
    n = int(d * SR)
    t = np.arange(n) / SR
    s = (np.sin(2 * np.pi * freq * t) * env(n, 0.003, 0.18)
         + 0.12 * np.sin(2 * np.pi * freq * 3.01 * t) * env(n, 0.003, 0.04))
    return lowpass(s, 3500) * gain * 0.5


def breeze(gain=1.0, dur=0.6, f0=500, f1=1800, **_):
    """比 air 更薄、更亮一點的風聲，沒有低頻。"""
    n = int(dur * SR)
    x = svf_bandpass(rng.standard_normal(n), f0, f1, 0.9)
    t = np.linspace(0, 1, n)
    return lowpass(x * np.sin(np.pi * t) ** 3, 3500) * gain * 0.5


SOUNDS.update(softpop=softpop, thock=thock, air=air, thump=thump, mallet=mallet, pad=pad,
              kalimba=kalimba, breeze=breeze)



# ---------- 紙張音色：一樣低通柔化，不做尖銳的脆響 ----------
def paper_slide(gain=1.0, dur=0.6, **_):
    """紙在桌面上滑動。"""
    n = int(dur * SR)
    x = svf_bandpass(rng.standard_normal(n), 350, 900, 0.7)
    t = np.linspace(0, 1, n)
    return lowpass(x * np.sin(np.pi * t) ** 1.5, 2500) * gain * 0.6


def crinkle(gain=1.0, dur=0.5, density=160, f0=1000, f1=2600, **_):
    """紙張窸窣：很多 2–8ms 的細小噪音顆粒。"""
    n = int((dur + 0.05) * SR)
    out = np.zeros(n)
    count = int(density * dur)
    for _ in range(count):
        m = int(rng.uniform(0.002, 0.008) * SR)
        st = int(rng.uniform(0, dur) * SR)
        f = rng.uniform(f0, f1)
        g = svf_bandpass(rng.standard_normal(m), f, f, 1.2) * np.hanning(m)
        # 中段比較密、比較大聲，頭尾收掉
        pos = st / (dur * SR)
        out[st:st + m] += g[: n - st] * rng.exponential(0.5) * np.sin(np.pi * pos) ** 0.7
    body = svf_bandpass(rng.standard_normal(n), 500, 1200, 0.6) * 0.15
    body *= np.sin(np.pi * np.linspace(0, 1, n))
    return lowpass(out + body, 4000) * gain * 0.9


def flap(gain=1.0, **_):
    """紙面攤平落下：短風聲加一下很輕的「啪」。"""
    d = 0.22
    n = int(d * SR)
    w = svf_bandpass(rng.standard_normal(n), 400, 1400, 0.7) * np.sin(np.pi * np.linspace(0, 1, n)) ** 2 * 0.35
    body = sweep(120, 70, d) * env(n, 0.002, 0.035)
    tick = lowpass(rng.standard_normal(n) * env(n, 0.0005, 0.006), 1500) * 0.6
    st = int(0.12 * SR)
    hit = np.zeros(n)
    hit[st:] = (body + tick)[: n - st]
    return lowpass(w + hit, 3000) * gain


def marker(gain=1.0, dur=0.45, **_):
    """螢光筆刷過紙面。"""
    n = int(dur * SR)
    t = np.arange(n) / SR
    x = svf_bandpass(rng.standard_normal(n), 900, 1800, 0.8)
    wob = 0.75 + 0.25 * np.sin(2 * np.pi * 17 * t)
    shape = np.clip(t / 0.04, 0, 1) * np.clip((dur - t) / 0.08, 0, 1)
    return lowpass(x * wob * shape, 3000) * gain * 0.5


SOUNDS.update(paper_slide=paper_slide, crinkle=crinkle, flap=flap, marker=marker)

def reverb(mix, amount):
    """用一段漸弱的噪音當殘響，讓聲音比較軟。"""
    m = int(1.4 * SR)
    t = np.arange(m) / SR
    ir = lowpass(rng.standard_normal(m) * np.exp(-t / 0.35), 3000)
    ir /= np.sqrt(np.sum(ir ** 2))
    out = np.empty_like(mix)
    size = 1 << int(np.ceil(np.log2(len(mix) + m)))
    for c in range(2):
        wet = np.fft.irfft(np.fft.rfft(mix[:, c], size) * np.fft.rfft(ir, size), size)[: len(mix)]
        out[:, c] = mix[:, c] + wet * amount
    return out


def main():
    data = json.load(open(sys.argv[1]))
    # 可以是純清單，或 {"master": {"lp": 5000, "verb": 0.2}, "events": [...]}
    master = data.get("master", {}) if isinstance(data, dict) else {}
    events = data["events"] if isinstance(data, dict) else data
    out_path = sys.argv[2]
    total = float(sys.argv[3]) + 1.5
    mix = np.zeros((int(total * SR), 2))
    for e in events:
        s = SOUNDS[e["type"]](**{k: v for k, v in e.items() if k not in ("t", "type", "pan")})
        pan = e.get("pan", 0.0)
        st = int(e["t"] * SR)
        end = min(len(mix), st + len(s))
        mix[st:end, 0] += s[: end - st] * np.sqrt((1 - pan) / 2)
        mix[st:end, 1] += s[: end - st] * np.sqrt((1 + pan) / 2)
    if master.get("lp"):
        for c in range(2):
            mix[:, c] = lowpass(mix[:, c], master["lp"])
    if master.get("verb"):
        mix = reverb(mix, master["verb"])
    # 輕微壓縮，避免爆音
    mix = np.tanh(mix * 1.1) * 0.85
    # 尾巴淡出
    fade = int(0.4 * SR)
    mix[-fade:] *= np.linspace(1, 0, fade)[:, None]
    pcm = (mix * 32767).astype(np.int16)
    with wave.open(out_path, "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())


if __name__ == "__main__":
    main()
