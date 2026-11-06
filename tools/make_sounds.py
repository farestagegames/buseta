#!/usr/bin/env python3
"""Generates the game's sound effects as WAV files in assets/audio.

All sounds are synthesised here, so there are no third-party licences.
"""
import math
import random
import struct
import wave
from pathlib import Path

RATE = 22050
OUT = Path(__file__).resolve().parent.parent / "assets" / "audio"


def save(name, samples):
    peak = max(abs(s) for s in samples) or 1.0
    scaled = [int(s / peak * 0.9 * 32767) for s in samples]
    with wave.open(str(OUT / name), "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(RATE)
        f.writeframes(struct.pack("<%dh" % len(scaled), *scaled))


def envelope(i, total, attack=0.01, release=0.05):
    t = i / RATE
    end = (total - i) / RATE
    return min(1.0, t / attack, end / release)


def saw(phase):
    return 2.0 * (phase - math.floor(phase + 0.5))


def noise_filtered(seconds, cutoff, seed):
    random.seed(seed)
    a = min(1.0, 2 * math.pi * cutoff / RATE)
    out, value = [], 0.0
    for _ in range(int(seconds * RATE)):
        value += a * (random.uniform(-1, 1) - value)
        out.append(value)
    return out


def engine_loop():
    # A whole number of cycles of each harmonic, so the loop has no click.
    total = RATE
    base = 55
    harmonics = [(1, 1.0), (2, 0.7), (3, 0.45), (4, 0.3), (6, 0.15), (9, 0.08)]
    out = []
    for i in range(total):
        t = i / RATE
        beat = 0.8 + 0.2 * math.sin(2 * math.pi * 11 * t)
        out.append(beat * sum(a * saw(base * n * t) for n, a in harmonics))
    return out


def horn_loop():
    total = RATE // 2
    tones = [(350, 1.0), (440, 0.9), (700, 0.3), (880, 0.25)]
    return [sum(a * saw(f * i / RATE) for f, a in tones) for i in range(total)]


def hiss(seconds, seed, fall=True):
    noise = noise_filtered(seconds, 3500, seed)
    total = len(noise)
    return [n * (1.0 - i / total if fall else 1.0) * envelope(i, total, 0.02, 0.1) for i, n in enumerate(noise)]


def thump(seconds, frequency, drop, seed):
    total = int(seconds * RATE)
    noise = noise_filtered(seconds, 900, seed)
    out = []
    phase = 0.0
    for i in range(total):
        t = i / RATE
        phase += (frequency * math.exp(-t * drop)) / RATE
        decay = math.exp(-t * 9.0 / seconds * 0.5)
        out.append(decay * (math.sin(2 * math.pi * phase) + 0.6 * noise[i]))
    return out


def door_open():
    return thump(0.12, 90, 8, 3) + hiss(1.0, 4)


def door_close():
    return hiss(0.9, 5) + thump(0.18, 80, 8, 6)


def knock():
    total = int(0.22 * RATE)
    noise = noise_filtered(0.22, 2400, 7)
    return [noise[i] * math.exp(-i / RATE * 24) + 0.5 * math.sin(2 * math.pi * 210 * i / RATE) * math.exp(-i / RATE * 30) for i in range(total)]


def bell():
    total = int(0.7 * RATE)
    return [math.exp(-i / RATE * 5) * (math.sin(2 * math.pi * 1320 * i / RATE) + 0.5 * math.sin(2 * math.pi * 1980 * i / RATE)) for i in range(total)]


def pay():
    total = int(0.09 * RATE)
    first = [math.sin(2 * math.pi * 1500 * i / RATE) * envelope(i, total) for i in range(total)]
    second = [math.sin(2 * math.pi * 2000 * i / RATE) * envelope(i, total) for i in range(total)]
    return first + second


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    save("engine_loop.wav", engine_loop())
    save("horn_loop.wav", horn_loop())
    save("door_open.wav", door_open())
    save("door_close.wav", door_close())
    save("crash.wav", thump(0.45, 120, 7, 8))
    save("thud.wav", thump(0.2, 70, 6, 9))
    save("knock.wav", knock())
    save("pay.wav", pay())
    save("bell.wav", bell())
    save("air_brake.wav", hiss(0.7, 10))


if __name__ == "__main__":
    main()
