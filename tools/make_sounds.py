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


def lowpass_loop(samples, cutoff, passes=2):
    """Filters a looping sound, running round it so the join stays seamless."""
    a = min(1.0, 2 * math.pi * cutoff / RATE)
    out = list(samples)
    for _ in range(passes):
        value = sum(out) / len(out)
        for _lap in range(2):
            for i, sample in enumerate(out):
                value += a * (sample - value)
                out[i] = value
    return out


def engine_loop():
    """A six cylinder diesel idling: uneven low thuds under a soft rumble.

    Each firing is a short decaying pulse with its own strength and timing, so
    it sounds mechanical rather than like a steady musical note.
    """
    random.seed(21)
    fires_per_second = 48
    fires = 72  # 1.5 seconds, long enough not to sound like a short repeat.
    period = RATE // fires_per_second
    total = period * fires
    pulses = [0.0] * total
    for fire in range(fires):
        strength = random.uniform(0.75, 1.0)
        start = fire * period + random.randint(-12, 12)
        for i in range(period * 2):
            t = i / RATE
            at = (start + i) % total
            pulses[at] += strength * math.exp(-t * 95) * math.sin(2 * math.pi * 95 * t)
    body = lowpass_loop(pulses, 320)
    rumble = lowpass_loop([random.uniform(-1, 1) for _ in range(total)], 170)
    clatter = lowpass_loop([random.uniform(-1, 1) for _ in range(total)], 1500, 1)
    return [b + 1.6 * r + 0.05 * c for b, r, c in zip(body, rumble, clatter)]


def horn_loop():
    """A city bus air horn: two close tones, softly saturated, not a buzzer."""
    total = RATE  # Whole cycles of every partial, so the loop is seamless.
    tones = [(415, 1.0), (494, 0.8), (830, 0.22), (988, 0.16), (1245, 0.06)]
    out = []
    for i in range(total):
        t = i / RATE
        wave_sum = sum(a * math.sin(2 * math.pi * f * t) for f, a in tones)
        out.append(math.tanh(wave_sum * 1.1))
    return out


def hiss(seconds, seed, fall=True):
    noise = noise_filtered(seconds, 2200, seed)
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
    return hiss(1.1, 4)


def door_close():
    return hiss(0.9, 5)


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
