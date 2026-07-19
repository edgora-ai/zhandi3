#!/usr/bin/env python3
"""生成游戏音效（仅标准库）：枪声/命中/毒圈警报/占点/结算。输出到 assets/sfx/"""
import math
import os
import random
import struct
import wave

SR = 44100
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "sfx")
random.seed(7)


def write_wav(name, samples):
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, name)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        frames = b"".join(struct.pack("<h", max(-32767, min(32767, int(s * 32767)))) for s in samples)
        w.writeframes(frames)
    print("wrote", path, len(samples))


def mix(a, b):
    n = max(len(a), len(b))
    a = a + [0.0] * (n - len(a))
    b = b + [0.0] * (n - len(b))
    return [x + y for x, y in zip(a, b)]


def noise_burst(dur, decay, amp=1.0, lowpass=0.0):
    n = int(SR * dur)
    out = []
    prev = 0.0
    for i in range(n):
        x = random.uniform(-1, 1)
        if lowpass > 0:
            prev = prev + lowpass * (x - prev)
            x = prev
        out.append(amp * x * math.exp(-i / (SR * decay)))
    return out


def tone(dur, freq, decay, amp=0.6, shape="sine"):
    n = int(SR * dur)
    out = []
    for i in range(n):
        t = i / SR
        if shape == "sine":
            x = math.sin(2 * math.pi * freq * t)
        else:
            x = 1.0 if math.sin(2 * math.pi * freq * t) > 0 else -1.0
        out.append(amp * x * math.exp(-i / (SR * decay)))
    return out


def sweep(dur, f0, f1, decay, amp=0.6):
    n = int(SR * dur)
    out = []
    phase = 0.0
    for i in range(n):
        t = i / n
        f = f0 + (f1 - f0) * t
        phase += 2 * math.pi * f / SR
        out.append(amp * math.sin(phase) * math.exp(-i / (SR * decay)))
    return out


def shot(name, dur, decay, thump_freq, lp):
    s = noise_burst(dur, decay, 0.9, lp)
    s = mix(s, tone(dur, thump_freq, decay * 0.8, 0.7))
    write_wav(name, s)


# 三种枪声
shot("shot_rifle.wav", 0.16, 0.030, 150.0, 0.35)
shot("shot_dmr.wav", 0.30, 0.055, 110.0, 0.25)
shot("shot_smg.wav", 0.10, 0.020, 180.0, 0.45)

# 命中确认：短促咔哒
write_wav("hit.wav", tone(0.05, 2400.0, 0.012, 0.35, "square"))

# 毒圈警报：两声低鸣
alarm = mix(tone(0.28, 330.0, 0.4, 0.5), [0.0] * int(SR * 0.36) + tone(0.28, 262.0, 0.4, 0.5))
write_wav("zone_alarm.wav", alarm)

# 占点成功：上行三音
cap = tone(0.12, 523.0, 0.3, 0.45)
cap = mix(cap, [0.0] * int(SR * 0.12) + tone(0.12, 659.0, 0.3, 0.45))
cap = mix(cap, [0.0] * int(SR * 0.24) + tone(0.35, 784.0, 0.5, 0.45))
write_wav("capture.wav", cap)

# 胜利：明亮琶音
vic = tone(0.15, 523.0, 0.3, 0.45)
vic = mix(vic, [0.0] * int(SR * 0.15) + tone(0.15, 659.0, 0.3, 0.45))
vic = mix(vic, [0.0] * int(SR * 0.30) + tone(0.15, 784.0, 0.3, 0.45))
vic = mix(vic, [0.0] * int(SR * 0.45) + tone(0.6, 1047.0, 0.7, 0.5))
write_wav("victory.wav", vic)

# 失败：下行低鸣
dft = sweep(0.7, 330.0, 130.0, 0.8, 0.5)
write_wav("defeat.wav", dft)

# 拾取：轻弹
write_wav("pickup.wav", sweep(0.09, 500.0, 900.0, 0.06, 0.35))

print("done")
