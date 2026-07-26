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


# ---------- 音乐与环境音（无缝循环） ----------

def crossfade(a, b, fade):
    """a 尾部淡出与 b 头部淡入交叠拼接"""
    f = int(SR * fade)
    out = a[:-f]
    for i in range(f):
        w = i / f
        out.append(a[len(a) - f + i] * (1.0 - w) + b[i] * w)
    out += b[f:]
    return out


def pad_note(dur, freq, amp):
    """柔和 pad 音色：基频 + 八度 + 微失谐，慢起音"""
    n = int(SR * dur)
    attack = SR * 1.2
    out = []
    for i in range(n):
        t = i / SR
        env = min(1.0, i / attack) * math.exp(-i / (SR * dur * 0.6))
        x = (math.sin(2 * math.pi * freq * t) * 0.6
             + math.sin(2 * math.pi * freq * 2.0 * t) * 0.22
             + math.sin(2 * math.pi * freq * 1.005 * t) * 0.18)
        out.append(amp * x * env)
    return out


def chord(dur, freqs, amp=0.13):
    s = []
    for f in freqs:
        s = mix(s, pad_note(dur, f, amp))
    return s


# 音乐：I–V–vi–IV 和弦进行的氛围 pad，交叠拼接成无缝循环
CHORDS = [
    [261.63, 329.63, 392.00],   # C
    [196.00, 246.94, 293.66],   # G
    [220.00, 261.63, 329.63],   # Am
    [174.61, 220.00, 261.63],   # F
]
SEG = 6.0
music = chord(SEG, CHORDS[0])
for ci in range(1, 4):
    music = crossfade(music, chord(SEG, CHORDS[ci]), 2.0)
music = crossfade(music, chord(SEG, CHORDS[0]), 2.0)   # 回到起始和弦，首尾无缝
# 稀疏五声音阶铃音点缀
PENTA = [523.25, 587.33, 659.25, 783.99, 880.00]
for ni in range(7):
    off = int(SR * random.uniform(1.0, len(music) / SR - 2.0))
    bell = tone(1.2, random.choice(PENTA), 0.9, 0.07)
    for j, x in enumerate(bell):
        if off + j < len(music):
            music[off + j] += x
write_wav("music.wav", music)


def bird_chirp():
    """一声短促鸟鸣：两到三个快速滑音"""
    f0 = random.uniform(2200, 3000)
    s = sweep(0.09, f0, f0 * random.uniform(1.15, 1.35), 0.03, 0.10)
    if random.random() < 0.7:
        s2 = sweep(0.07, f0 * 1.1, f0 * 0.9, 0.03, 0.08)
        s = mix(s, [0.0] * int(SR * 0.10) + s2)
    return s


# 环境音：海风 + 浪涌 + 随机鸟鸣，30s 无缝循环
AMB_DUR = 30.0
n = int(SR * AMB_DUR)
amb = []
brown = 0.0
surf_prev = 0.0
for i in range(n):
    t = i / SR
    # 风：棕噪声（漏积分白噪声）+ 慢速 LFO 起伏
    brown += (random.uniform(-1, 1) - brown) * 0.02
    wind = brown * 2.0 * (0.72 + 0.28 * math.sin(2 * math.pi * 0.07 * t))
    # 海浪：低通白噪声 × 缓慢涌动包络
    surf_prev += 0.06 * (random.uniform(-1, 1) - surf_prev)
    surf_env = 0.5 + 0.5 * math.sin(2 * math.pi * 0.09 * t + 1.3)
    surf = surf_prev * (0.5 + 3.0 * surf_env * surf_env) * 0.35
    amb.append(wind * 0.30 + surf * 0.22)
for _ in range(9):
    off = int(SR * random.uniform(0.5, AMB_DUR - 1.0))
    c = bird_chirp()
    for j, x in enumerate(c):
        if off + j < n:
            amb[off + j] += x
# 首尾 1s 交叠，循环无接缝
f = SR
for i in range(f):
    w = i / f
    amb[i] = amb[i] * w + amb[n - f + i] * (1.0 - w)
amb = amb[:-f]
write_wav("ambience.wav", amb)

# 爆炸：低频轰击 + 爆破噪声 + 碎裂尾音
boom = sweep(0.55, 95, 34, 0.30, 0.9)
blast = noise_burst(0.65, 0.16, 1.0, 0.22)
crackle = [0.0] * int(SR * 0.06) + noise_burst(0.4, 0.045, 0.38)
expl = mix(mix(boom, blast), crackle)
write_wav("explosion.wav", expl)

print("done")
