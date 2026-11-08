"""Small building blocks shared by the horns, ambience and music.

Loops are filtered in the frequency domain, which wraps round by nature, so a
loop's join stays seamless. Notes are added round the end of a loop for the
same reason: a tail that runs past the end carries on at the start. A sound that
plays once, such as a radio song, adds with wrap off instead.
"""
import struct
import wave
from pathlib import Path

import numpy as np

RATE = 22050
## Highest peak any new file may reach: about -1.4 dBFS.
CEILING = 0.85


def seconds(n):
    return np.arange(int(n)) / RATE


def noise(length, seed):
    return np.random.default_rng(seed).uniform(-1.0, 1.0, int(length))


def shape(x, low=None, high=None, tilt=0.0, wrap=True):
    """Band-limits a sound. With wrap off, the sound is padded so its tail does
    not fold back onto its start."""
    n = len(x)
    padded = x if wrap else np.concatenate([x, np.zeros(min(n, RATE // 2))])
    spectrum = np.fft.rfft(padded)
    f = np.maximum(np.fft.rfftfreq(len(padded), 1.0 / RATE), 1e-3)
    gain = np.ones_like(f)
    if low:
        gain /= np.sqrt(1.0 + (low / f) ** 4)
    if high:
        gain /= np.sqrt(1.0 + (f / high) ** 4)
    if tilt:
        gain *= (np.maximum(f, 30.0) / 1000.0) ** tilt
    out = np.fft.irfft(spectrum * gain, len(padded))
    return out[:n]


def envelope(n, attack, release, decay=0.0):
    """Linear attack and release in seconds, with an optional exponential decay."""
    t = seconds(n)
    env = np.ones(int(n))
    if attack > 0:
        env = np.minimum(env, t / attack)
    if release > 0:
        env = np.minimum(env, (n / RATE - t) / release)
    if decay:
        env *= np.exp(-t * decay)
    return np.clip(env, 0.0, 1.0)


def add(mix, sound, at, gain=1.0, wrap=True):
    """Adds a sound into a loop, carrying anything past the end round to the start.
    With wrap off, anything past the end is dropped."""
    total = len(mix)
    sound = sound * gain
    if not wrap:
        at = max(0, at)
        room = max(0, min(total - at, len(sound)))
        mix[at:at + room] += sound[:room]
        return
    at %= total
    while len(sound) > 0:
        room = min(total - at, len(sound))
        mix[at:at + room] += sound[:room]
        sound = sound[room:]
        at = 0


def rms_db(x, gate_db=None):
    """Loudness as RMS in dBFS. With a gate, quiet gaps such as the rest between
    two horn taps do not count."""
    x = np.asarray(x, dtype=float)
    if gate_db is not None:
        block = RATE // 20
        blocks = [x[i:i + block] for i in range(0, len(x) - block + 1, block)]
        loud = [b for b in blocks if 20 * np.log10(np.sqrt(np.mean(b * b)) + 1e-12) > gate_db]
        x = np.concatenate(loud) if loud else x
    return 20 * np.log10(np.sqrt(np.mean(x * x)) + 1e-12)


def heard_db(x, gate_db=None):
    """Loudness as a phone speaker plays it: RMS with the deep bass left out,
    since a small speaker barely reproduces it."""
    return rms_db(shape(np.asarray(x, dtype=float), low=200.0), gate_db)


def peak_db(x):
    return 20 * np.log10(np.max(np.abs(x)) + 1e-12)


def soft_limit(x, knee=0.6, ceiling=CEILING):
    """Leaves quiet parts alone and rounds off peaks, so nothing ever clips."""
    out = np.array(x, dtype=float)
    over = np.abs(out) > knee
    room = ceiling - knee
    out[over] = np.sign(out[over]) * (knee + room * np.tanh((np.abs(out[over]) - knee) / room))
    return out


def master(x, target_db, gate_db=None, heard=False):
    """Sets a sound's loudness, then limits its peaks below the ceiling. With heard
    on, loudness is measured as a phone speaker plays it (see heard_db)."""
    x = np.asarray(x, dtype=float)
    x = x - np.mean(x)
    measure = heard_db if heard else rms_db
    for _ in range(4):
        x = x * 10 ** ((target_db - measure(x, gate_db)) / 20)
        x = soft_limit(x)
    return x * min(1.0, CEILING / (np.max(np.abs(x)) + 1e-12))


def fade(x, fade_in, fade_out):
    """A sound that plays once: a short linear fade in and a smooth fade out, both
    in seconds, so it starts and ends in silence and never clicks."""
    out = np.array(x, dtype=float)
    a = max(1, int(fade_in * RATE))
    out[:a] *= np.arange(a) / a
    b = max(1, int(fade_out * RATE))
    out[-b:] *= 0.5 + 0.5 * np.cos(np.pi * np.arange(1, b + 1) / b)
    return out


def write(path, x, loop=None):
    """Saves mono 16-bit WAV without normalising, so set levels stay as set.

    loop is (start, end) in samples, or True for the whole file. It is written as
    a WAV "smpl" chunk, which Godot's importer reads, so the sound loops there with
    no code. The end is the sample the loop jumps back from."""
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    data = (np.clip(x, -1.0, 1.0) * 32767).astype("<i2").tobytes()
    with wave.open(str(path), "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(RATE)
        f.writeframes(data)
    if loop:
        start, end = (0, len(x)) if loop is True else loop
        _add_loop_chunk(path, int(start), int(end))


def _add_loop_chunk(path, start, end):
    # Manufacturer, product, sample period, MIDI note, pitch fraction, SMPTE format
    # and offset, one loop, no extra data; then the loop: id, forward, start, end,
    # fraction and play count (0 is forever).
    period = int(round(1e9 / RATE))
    body = struct.pack("<9I", 0, 0, period, 60, 0, 0, 0, 1, 0) + struct.pack("<6I", 0, 0, start, end, 0, 0)
    raw = bytearray(path.read_bytes())
    raw += b"smpl" + struct.pack("<I", len(body)) + body
    raw[4:8] = struct.pack("<I", len(raw) - 8)
    path.write_bytes(bytes(raw))


def midi(note):
    return 440.0 * 2 ** ((note - 69) / 12.0)


def harmonics(freq, n, partials, vibrato=0.0, vibrato_rate=5.0, vibrato_delay=0.15, detune=0.0):
    """Additive tone: partials is a list of (multiple, level, decay per second).
    Partials above the top of the band are left out, so nothing aliases."""
    t = seconds(n)
    wobble = np.ones(int(n))
    if vibrato:
        wobble = 1.0 + vibrato * np.sin(2 * np.pi * vibrato_rate * t) * np.clip((t - vibrato_delay) / 0.2, 0.0, 1.0)
    base = freq * (2 ** (detune / 1200.0)) * wobble
    phase = 2 * np.pi * np.cumsum(base) / RATE
    out = np.zeros(int(n))
    for multiple, level, decay in partials:
        if freq * multiple >= RATE * 0.45:
            continue
        part = level * np.sin(multiple * phase)
        if decay:
            part *= np.exp(-t * decay)
        out += part
    return out
