"""
喝水提醒 App 音效生成器 - 纯 Python 标准库
==========================================
合成 4 个治愈系 WAV 音效(44.1kHz / 16-bit / mono):
  flow.wav  - 流水声(粉红噪声 + 低通滤波 + 振幅调制)
  wind.wav  - 风铃声(多频正弦波 + 指数衰减)
  rain.wav  - 雨滴声(背景雨幕 + 随机水滴)
  piano.wav - 轻钢琴(C-E-G 和弦 + ADSR 包络)

运行:
  python gen_sounds.py

输出:
  当前目录生成 4 个 .wav 文件,复制到 assets/sounds/ 即可。
"""

import math
import random
import struct
import wave
from pathlib import Path

# ============ 全局参数 ============
SAMPLE_RATE = 44100       # 采样率
DURATION = 3.0            # 单个音效时长(秒)
AMP_MAX = 0.85            # 最大振幅(避免削波)
random.seed(42)           # 固定随机种子,保证可复现


def write_wav(path: Path, samples: list[float]) -> None:
    """把归一化振幅列表(-1.0~1.0)写成 16-bit PCM WAV"""
    n = len(samples)
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)  # 16-bit
        w.setframerate(SAMPLE_RATE)
        frames = bytearray()
        for s in samples:
            v = max(-1.0, min(1.0, s))
            frames += struct.pack("<h", int(v * 32767))
        w.writeframes(bytes(frames))
    print(f"  [OK] {path.name}  ({n} samples, {n / SAMPLE_RATE:.1f}s)")


def fade(samples: list[float], fade_time: float = 0.15) -> list[float]:
    """首尾淡入淡出,避免爆音"""
    n_fade = int(SAMPLE_RATE * fade_time)
    n = len(samples)
    for i in range(min(n_fade, n)):
        ratio = i / n_fade
        samples[i] *= ratio
        samples[n - 1 - i] *= ratio
    return samples


def gen_flow() -> list[float]:
    """流水声:粉红噪声 + 低通滤波 + 缓慢振幅调制"""
    n = int(SAMPLE_RATE * DURATION)
    # 1. 白噪声
    white = [random.uniform(-1, 1) for _ in range(n)]
    # 2. 粉红噪声(Voss-McCartney 简化:多阶积分)
    pink = [0.0] * n
    b0 = b1 = b2 = 0.0
    for i in range(n):
        w = white[i]
        b0 = 0.99765 * b0 + w * 0.0990460
        b1 = 0.96300 * b1 + w * 0.2965164
        b2 = 0.57000 * b2 + w * 1.0526913
        pink[i] = (b0 + b1 + b2 + w * 0.1848) * 0.18
    # 3. 低通滤波(简单移动平均,窗口 15)
    window = 15
    out = [0.0] * n
    for i in range(n):
        s = 0.0
        for j in range(window):
            if i - j >= 0:
                s += pink[i - j]
        out[i] = s / window
    # 4. 振幅调制(模拟水流起伏)
    for i in range(n):
        t = i / SAMPLE_RATE
        mod = 0.7 + 0.3 * math.sin(2 * math.pi * 0.5 * t)
        out[i] *= mod * AMP_MAX
    return fade(out, 0.2)


def gen_wind() -> list[float]:
    """风铃声:多个金属谐波 + 指数衰减 + 轻微随机颤动"""
    n = int(SAMPLE_RATE * DURATION)
    # 风铃和弦基频(C5/E5/G5/C6)
    freqs = [523.25, 659.25, 783.99, 1046.50]
    # 每个基频的非整数倍谐波(金属铃特性)
    harmonics = [1.0, 2.01, 3.97, 5.43]
    harmonic_amps = [1.0, 0.5, 0.25, 0.12]
    out = [0.0] * n
    for i in range(n):
        t = i / SAMPLE_RATE
        # 整体指数衰减(模拟铃声音量随时间衰减)
        env = math.exp(-1.2 * t)
        # 每个铃错开触发(0s / 0.4s / 0.8s / 1.2s)
        sample = 0.0
        for k, f in enumerate(freqs):
            delay = k * 0.4
            if t < delay:
                continue
            local_t = t - delay
            local_env = math.exp(-1.5 * local_t)
            for h, ha in zip(harmonics, harmonic_amps):
                # 轻微随机颤动(模拟风吹)
                vibrato = 1.0 + 0.005 * math.sin(2 * math.pi * 5.5 * t + k)
                sample += math.sin(2 * math.pi * f * h * vibrato * local_t) * ha * local_env
        out[i] = sample * env * 0.18 * AMP_MAX
    return fade(out, 0.05)


def gen_rain() -> list[float]:
    """雨滴声:背景雨幕(低通白噪声) + 随机水滴(高频短促衰减)"""
    n = int(SAMPLE_RATE * DURATION)
    out = [0.0] * n
    # 1. 背景雨幕:白噪声 + 低通
    white = [random.uniform(-1, 1) for _ in range(n)]
    bg = [0.0] * n
    window = 8
    for i in range(n):
        s = 0.0
        for j in range(window):
            if i - j >= 0:
                s += white[i - j]
        bg[i] = s / window
    for i in range(n):
        out[i] = bg[i] * 0.15
    # 2. 随机水滴(平均每秒 4-6 个)
    n_drops = int(DURATION * 5)
    for _ in range(n_drops):
        pos = random.randint(int(SAMPLE_RATE * 0.1), n - int(SAMPLE_RATE * 0.3))
        # 水滴频率:1.5kHz ~ 3kHz
        f = random.uniform(1500, 3000)
        drop_len = int(SAMPLE_RATE * 0.08)  # 80ms
        for j in range(drop_len):
            if pos + j >= n:
                break
            t = j / SAMPLE_RATE
            env = math.exp(-30 * t)  # 快速衰减
            out[pos + j] += math.sin(2 * math.pi * f * t) * env * 0.5
    # 归一化
    peak = max(abs(s) for s in out) or 1.0
    out = [s / peak * AMP_MAX for s in out]
    return fade(out, 0.2)


def gen_piano() -> list[float]:
    """轻钢琴:C-E-G 大三和弦 + 谐波 + ADSR 包络"""
    n = int(SAMPLE_RATE * DURATION)
    # C4/E4/G4(中音区,温柔)
    freqs = [261.63, 329.63, 392.00]
    # 每个音的谐波(基频 + 2/3/4 倍频,振幅递减模拟钢琴音色)
    harmonics = [1.0, 2.0, 3.0, 4.0]
    harmonic_amps = [1.0, 0.45, 0.22, 0.10]
    out = [0.0] * n
    for i in range(n):
        t = i / SAMPLE_RATE
        # ADSR:5ms 攻击 + 200ms 衰减 + 1.5s 平台(0.5) + 1.3s 释放
        if t < 0.005:
            env = t / 0.005
        elif t < 0.205:
            env = 1.0 - 0.5 * (t - 0.005) / 0.2
        elif t < 1.705:
            env = 0.5
        else:
            env = 0.5 * max(0.0, 1.0 - (t - 1.705) / 1.295)
        sample = 0.0
        for f in freqs:
            for h, ha in zip(harmonics, harmonic_amps):
                sample += math.sin(2 * math.pi * f * h * t) * ha
        out[i] = sample * env
    # 归一化
    peak = max(abs(s) for s in out) or 1.0
    out = [s / peak * AMP_MAX for s in out]
    return fade(out, 0.01)


def main():
    out_dir = Path(__file__).parent
    print("开始生成治愈音效...")
    print(f"  采样率: {SAMPLE_RATE} Hz / 时长: {DURATION}s / 格式: 16-bit PCM WAV")
    print()
    print("[1/4] 生成流水声 flow.wav ...")
    write_wav(out_dir / "flow.wav", gen_flow())
    print("[2/4] 生成风铃声 wind.wav ...")
    write_wav(out_dir / "wind.wav", gen_wind())
    print("[3/4] 生成雨滴声 rain.wav ...")
    write_wav(out_dir / "rain.wav", gen_rain())
    print("[4/4] 生成轻钢琴 piano.wav ...")
    write_wav(out_dir / "piano.wav", gen_piano())
    print()
    print("完成! 4 个音效已生成在当前目录。")
    print("请将这 4 个 .wav 文件复制到 assets/sounds/ 目录。")


if __name__ == "__main__":
    main()
