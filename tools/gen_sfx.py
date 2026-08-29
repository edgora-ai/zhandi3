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


def normalize(samples, peak=0.89):
    """// FIX: OPT-E1/REG5 每轨归一化到 ≤0.89 true peak（原多轨直接叠加峰值 1.6~2.28 硬剪失真）"""
    m = max(1e-6, max(abs(x) for x in samples))
    k = min(1.0, peak / m)
    return [x * k for x in samples]


def write_wav(name, samples):
    samples = normalize(samples)
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


def loopify(samples, fade_sec):
    """把开头淡入叠到结尾：循环回卷时接缝连续（噪声床专用）。"""
    f = int(SR * fade_sec)
    for i in range(f):
        w = i / f
        samples[len(samples) - f + i] = samples[len(samples) - f + i] * (1.0 - w) + samples[i] * w
    return samples


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
# // FIX: R4-7 远距枪声低通变体（>120m 切换"闷响"，原只变小不变闷）
shot("shot_rifle_far.wav", 0.22, 0.060, 70.0, 0.06)
shot("shot_dmr_far.wav", 0.40, 0.10, 55.0, 0.045)
shot("shot_smg_far.wav", 0.16, 0.045, 85.0, 0.08)

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
# // FIX: OPT-E5/FX16 循环扩写：4 和弦 ×3 遍（~72s+交叠≈96s），降低长局听觉疲劳
music = chord(SEG, CHORDS[0])
for rep in range(6):  # 6 遍 ≈102s 满足 ≥90s 验收
    for ci in range(1, 4):
        music = crossfade(music, chord(SEG, CHORDS[ci]), 2.0)
    music = crossfade(music, chord(SEG, CHORDS[0]), 2.0)   # 每遍回到起始和弦，首尾无缝
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

# 制冰：结晶风铃 + 寒气白噪
chime = mix(tone(0.5, 880, 0.30, 0.35), tone(0.6, 1320, 0.36, 0.28))
frost = noise_burst(0.5, 0.22, 0.25, 0.35)
write_wav("freeze.wav", mix(chime, frost))

# 时停：时间凝结下行滑音 + 金铃
stasis_s = sweep(0.55, 1200, 180, 0.34, 0.42)
stasis_b = mix(tone(0.4, 660, 0.28, 0.30), tone(0.5, 990, 0.34, 0.22))
write_wav("stasis.wav", mix(stasis_s, stasis_b))

# 烹饪完成：三音上扬琶音 + 嘶声尾（旷野之息式的开锅完成感）。
cook = [0.0] * int(SR * 0.9)
for ni, f in enumerate([660.0, 880.0, 1320.0]):
    off = int(SR * 0.09 * ni)
    for j, x in enumerate(tone(0.35, f, 0.28, 0.30)):
        if off + j < len(cook):
            cook[off + j] += x
for j, x in enumerate(noise_burst(0.7, 0.5, 0.20)):
    off = int(SR * 0.18) + j
    if off < len(cook):
        cook[off] += x
write_wav("cook.wav", cook)

# Boss 战：驱动鼓点循环（12 秒 100BPM 整网格，所有素材尾音都在 12 秒内衰减完，天然无缝）
# + 暗黑号角动机。底鼓/低音脉冲/反拍军鼓/八分镲/末拍通鼓。
boss = [0.0] * int(SR * 12.0)
for beat in range(20):
    off = int(SR * 0.6 * beat)
    for j, x in enumerate(sweep(0.26, 130, 40, 0.16, 0.9)):
        if off + j < len(boss):
            boss[off + j] += x
    for j, x in enumerate(tone(0.3, 55.0, 0.22, 0.30)):
        if off + j < len(boss):
            boss[off + j] += x
    if beat % 2 == 1:
        for j, x in enumerate(noise_burst(0.14, 0.05, 0.38, 0.30)):
            if off + j < len(boss):
                boss[off + j] += x
    for half in range(2):
        hoff = off + int(SR * 0.3 * half)
        for j, x in enumerate(noise_burst(0.06, 0.02, 0.16)):
            if hoff + j < len(boss):
                boss[hoff + j] += x
    if beat % 4 == 3:
        for j, x in enumerate(sweep(0.3, 200, 85, 0.22, 0.40)):
            if off + j < len(boss):
                boss[off + j] += x
for toff, f in [(0.15, 220.0), (0.75, 261.63), (6.15, 220.0), (6.75, 293.66)]:
    off = int(SR * toff)
    for j, x in enumerate(tone(1.5, f, 1.1, 0.15, "square")):
        if off + j < len(boss):
            boss[off + j] += x
write_wav("boss.wav", boss)

# 夜曲：Am–F–C–G 慢起音 pad，比白日更轻、交叠更慢，稀疏高音铃点缀。
NCHORDS = [
    [220.00, 261.63, 329.63],   # Am
    [174.61, 220.00, 261.63],   # F
    [261.63, 329.63, 392.00],   # C
    [196.00, 246.94, 329.63],   # G
]
night = chord(SEG, NCHORDS[0], 0.09)
for ci in range(1, 4):
    night = crossfade(night, chord(SEG, NCHORDS[ci], 0.09), 3.0)
night = crossfade(night, chord(SEG, NCHORDS[0], 0.09), 3.0)
NBELLS = [523.25, 659.25, 783.99, 1046.50]
for ni in range(4):
    off = int(SR * random.uniform(2.0, len(night) / SR - 3.0))
    bell = tone(1.6, random.choice(NBELLS), 1.2, 0.045)
    for j, x in enumerate(bell):
        if off + j < len(night):
            night[off + j] += x
write_wav("music_night.wav", night)

# 火山低鸣：整周期低频双音（频率×12 为整数周期天然无缝）+ 低通隆隆噪声床（loopify 接缝）
# + 岩浆翻涌的低频小爆点。
volc = [0.0] * int(SR * 12.0)
volc_bed = loopify(noise_burst(12.0, 20.0, 0.32, 0.06), 2.0)
for j, x in enumerate(volc_bed):
    volc[j] += x
for f in [38.0, 55.0]:
    for j, x in enumerate(tone(12.0, f, 60.0, 0.09)):
        volc[j] += x
for bi in range(14):
    off = int(SR * random.uniform(0.5, 11.0))
    for j, x in enumerate(sweep(0.18, random.uniform(60, 120), 35, 0.10, 0.16)):
        if off + j < len(volc):
            volc[off + j] += x
write_wav("volcano.wav", volc)

# 雪原风吼：中频风噪床 + 三阵涌风。
wind = [0.0] * int(SR * 12.0)
wind_bed = loopify(noise_burst(12.0, 20.0, 0.26, 0.45), 2.0)
for j, x in enumerate(wind_bed):
    wind[j] += x
for goff in [1.0, 5.0, 9.0]:
    off = int(SR * goff)
    for j, x in enumerate(noise_burst(2.6, 1.3, 0.30, 0.30)):
        if off + j < len(wind):
            wind[off + j] += x
write_wav("snowwind.wav", wind)

# 雷声：近距爆裂 + 低频滚滚长尾。
thun = mix(noise_burst(0.5, 0.10, 0.75), sweep(2.4, 90, 30, 1.4, 0.5))
write_wav("thunder.wav", thun)

# 新音效放在既有随机生成流程之后，避免改变旧音乐/环境音的固定种子序列。
# 近战挥空：高频风切向下扫，三连击通过运行时 pitch_scale 区分。
sword_whoosh = mix(sweep(0.19, 1750.0, 230.0, 0.11, 0.38), noise_burst(0.16, 0.055, 0.16, 0.18))
write_wav("sword_whoosh.wav", sword_whoosh)

# 近战命中：低频木石冲击叠一层短促金属亮音。
heavy_impact = mix(noise_burst(0.22, 0.045, 0.52, 0.10), tone(0.18, 105.0, 0.07, 0.72))
heavy_impact = mix(heavy_impact, sweep(0.10, 920.0, 310.0, 0.045, 0.24))
write_wav("heavy_impact.wav", heavy_impact)

# 敌人攻击前摇：短促上扬双音，提醒玩家准备闪避或举盾。
enemy_charge = mix(sweep(0.30, 170.0, 520.0, 0.20, 0.34), [0.0] * int(SR * 0.11) + tone(0.18, 720.0, 0.12, 0.20))
write_wav("enemy_charge.wav", enemy_charge)

# ---------- OPT-E1 音频回归修复新增采样（追加在既有种子序列之后，不改旧产物） ----------

# REG1：雨声循环——宽带噪声雨幕 + 随机雨滴颗粒，无鸟鸣（原复用含鸟鸣的海滩环境音）。
RAIN_DUR = 12.0
n = int(SR * RAIN_DUR)
rain = []
rain_prev = 0.0
for i in range(n):
    x = random.uniform(-1, 1)
    rain_prev += 0.18 * (x - rain_prev)
    rain.append(rain_prev * 0.9)
# 雨滴颗粒：高频短噼啪
for _ in range(160):
    off = int(SR * random.uniform(0.0, RAIN_DUR - 0.05))
    drop = noise_burst(0.012, 0.004, random.uniform(0.10, 0.28))
    for j, x in enumerate(drop):
        if off + j < n:
            rain[off + j] += x
rain = loopify(rain, 1.5)
write_wav("rain_loop.wav", rain)

# REG2：四类脚步——草地（软沙沙）/沙石（颗粒擦）/木板（木质叩击）/水面（蹚水花）。
foot_grass = noise_burst(0.09, 0.035, 0.30, 0.22)
write_wav("footstep_grass.wav", foot_grass)
foot_sand = mix(noise_burst(0.10, 0.045, 0.26, 0.35), tone(0.06, 95.0, 0.03, 0.16))
write_wav("footstep_sand.wav", foot_sand)
foot_wood = mix(tone(0.07, 185.0, 0.025, 0.42), noise_burst(0.05, 0.02, 0.18, 0.30))
write_wav("footstep_wood.wav", foot_wood)
foot_water = mix(noise_burst(0.16, 0.06, 0.30, 0.55), sweep(0.12, 900.0, 350.0, 0.05, 0.10))
write_wav("footstep_water.wav", foot_water)

# REG3：弓——蓄力吱呀（低频弦张力上滑）+ 释放弦震 twang（低频衰减 + 高频瞬态）。
bow_draw_s = sweep(0.55, 90.0, 210.0, 0.80, 0.20)
write_wav("bow_draw.wav", bow_draw_s)
bow_rel = mix(tone(0.22, 118.0, 0.045, 0.62), noise_burst(0.05, 0.012, 0.35, 0.5))
bow_rel = mix(bow_rel, tone(0.10, 340.0, 0.02, 0.22))
write_wav("bow_release.wav", bow_rel)

# FX1：换弹——拔匣双击（金属咔哒×2）+ 完成上膛单击。
rl = mix(tone(0.03, 1500.0, 0.008, 0.40, "square"), noise_burst(0.025, 0.008, 0.30, 0.4))
rl = mix(rl, [0.0] * int(SR * 0.11) + mix(tone(0.04, 1150.0, 0.010, 0.45, "square"), noise_burst(0.03, 0.010, 0.32, 0.4)))
write_wav("reload_start.wav", rl)
rl_end = mix(tone(0.045, 1750.0, 0.010, 0.42, "square"), noise_burst(0.03, 0.008, 0.28, 0.5))
write_wav("reload_end.wav", rl_end)

# OPT-D3：心跳循环——lub-dub 双低频搏动，约 1.05s 一循环（运行时 LOOP_FORWARD）。
hb = [0.0] * int(SR * 1.05)
for j, x in enumerate(tone(0.11, 58.0, 0.045, 0.85)):
    hb[j] += x
for j, x in enumerate(tone(0.09, 52.0, 0.040, 0.62)):
    off = int(SR * 0.30)
    if off + j < len(hb):
        hb[off + j] += x
write_wav("heartbeat.wav", hb)

# ---------- OPT-E3 音效覆盖缺口（12 类交互） ----------

# UI 点击（地图/背包开合）
write_wav("ui_click.wav", tone(0.035, 1250.0, 0.010, 0.32, "square"))
# 切枪：金属拉栓 + 布料摩擦
ws = mix(tone(0.05, 900.0, 0.014, 0.34), noise_burst(0.07, 0.025, 0.20, 0.5))
write_wav("weapon_switch.wav", ws)
# 闪避呼啸：快速下扫气声
write_wav("dodge_whoosh.wav", mix(sweep(0.22, 1400.0, 260.0, 0.12, 0.30), noise_burst(0.18, 0.05, 0.16, 0.35)))
# 入水水花：宽频爆裂 + 低频扑通
splash = mix(noise_burst(0.30, 0.09, 0.55, 0.30), sweep(0.16, 220.0, 70.0, 0.10, 0.40))
write_wav("water_splash.wav", splash)
# 烟雾弹起烟：气压嘶声 + 咚
smk = mix(noise_burst(0.7, 0.35, 0.30, 0.55), sweep(0.10, 140.0, 60.0, 0.07, 0.42))
write_wav("smoke_pop.wav", smk)
# 引擎循环：两缸点火脉冲（运行时 LOOP_FORWARD，音调随车速）
eng = [0.0] * int(SR * 0.5)
for k in range(4):
    off = int(SR * 0.125 * k)
    for j, x in enumerate(tone(0.06, 82.0, 0.030, 0.55)):
        if off + j < len(eng):
            eng[off + j] += x
    for j, x in enumerate(noise_burst(0.03, 0.012, 0.16, 0.30)):
        if off + j < len(eng):
            eng[off + j] += x
write_wav("engine_loop.wav", eng)
# 探索精灵奖励：三连上行铃 + 咻
kk = mix(sweep(0.12, 900.0, 1800.0, 0.08, 0.22), [0.0] * int(SR * 0.10) + tone(0.14, 1046.5, 0.10, 0.30))
kk = mix(kk, [0.0] * int(SR * 0.22) + tone(0.18, 1318.5, 0.12, 0.30))
kk = mix(kk, [0.0] * int(SR * 0.34) + tone(0.30, 1568.0, 0.20, 0.32))
write_wav("korok_reward.wav", kk)
# 动物叫声：猪哼 / 狼嚎 / 熊吼 / 鸟鸣
pig = mix(sweep(0.18, 210.0, 90.0, 0.09, 0.50), noise_burst(0.10, 0.04, 0.20, 0.20))
write_wav("animal_pig.wav", pig)
howl = sweep(0.9, 330.0, 470.0, 0.8, 0.34)
howl = mix(howl, sweep(0.4, 470.0, 300.0, 0.6, 0.20))
write_wav("animal_wolf.wav", [0.0] * int(SR * 0.15) + howl)
bear = mix(sweep(0.4, 120.0, 65.0, 0.22, 0.62), noise_burst(0.3, 0.10, 0.28, 0.12))
write_wav("animal_bear.wav", bear)
# 马嘶：颤音上扬
nh = sweep(0.5, 500.0, 720.0, 0.45, 0.30)
vib = []
for i, x in enumerate(nh):
    vib.append(x * (1.0 + 0.35 * math.sin(2 * math.pi * 13.0 * i / SR)))
write_wav("mount_neigh.wav", vib)
# 宝箱开启：木盖吱呀 + 金属扣
ch = mix(sweep(0.35, 180.0, 420.0, 0.30, 0.24), [0.0] * int(SR * 0.25) + tone(0.08, 1500.0, 0.02, 0.30, "square"))
write_wav("chest_open.wav", ch)

# // FIX: OPT-E5/FX16 血月 stinger：小二度低音撞击 + 下滑 drone
bs = mix(tone(0.9, 65.4, 0.5, 0.55), tone(0.9, 69.3, 0.5, 0.45))
bs = mix(bs, sweep(1.4, 180.0, 48.0, 1.0, 0.35))
write_wav("blood_stinger.wav", bs)

# // FIX: R2-8 圈外掉血 tick：低频嗡鸣+呼吸感（主频 <600Hz，与 hit.wav 2.4kHz 确认音区分）
zt = [0.0] * int(SR * 0.28)
for j, x in enumerate(tone(0.26, 210.0, 0.16, 0.55)):
    zt[j] += x * (1.0 + 0.3 * math.sin(2 * math.pi * 9.0 * j / SR))
for j, x in enumerate(noise_burst(0.08, 0.03, 0.10, 0.25)):
    zt[j] += x
write_wav("zone_tick.wav", zt)

# // FIX: R4-8 血月持续氛围层：小二度低音 drone 12s 无缝循环（loopify 接缝）
bd = [0.0] * int(SR * 12.0)
for f in [55.0, 58.27]:
    for j, x in enumerate(tone(12.0, f, 30.0, 0.12)):
        bd[j] += x
bed = loopify(noise_burst(12.0, 18.0, 0.10, 0.05), 2.0)
for j, x in enumerate(bed):
    bd[j] += x
write_wav("blood_drone.wav", bd)

print("done")
