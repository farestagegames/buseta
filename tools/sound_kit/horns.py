"""Bus horns. Each file loops for as long as the horn is held.

A steady horn's loop lasts exactly one second and every partial is a whole number
of hertz, so each one completes whole cycles and the join is seamless. Before the
loop comes a short fade in, played once, so pressing the horn never clicks. The
loop points are written into the file. Horns made of separate notes start and end
in silence and loop whole.
"""
import numpy as np

from . import dsp

RATE = dsp.RATE
## Every horn is set to the same loudness while it sounds, gaps left out.
LOUDNESS_DB = -9.0
GATE_DB = -35.0


def _saturate(x, drive):
    return np.tanh(x * drive)


def two_tone():
    """The buseta's bright car-style horn: two tones a major third apart."""
    n = RATE
    tone = np.zeros(n)
    for freq, level in [(440, 1.0), (554, 0.85)]:
        tone += level * dsp.harmonics(freq, n, [(1, 1.0, 0), (2, 0.45, 0), (3, 0.3, 0), (4, 0.12, 0), (5, 0.08, 0)])
    return _saturate(tone * 0.6, 1.8)


def air_horn():
    """The articulated bus's deep air horn: three low reeds in a wide chord, with air."""
    n = RATE
    chord = np.zeros(n)
    for freq, level in [(156, 1.0), (196, 0.8), (233, 0.7)]:
        partials = [(k, 1.0 / k ** 0.8, 0) for k in range(1, 18)]
        chord += level * dsp.harmonics(freq, n, partials)
    air = dsp.shape(dsp.noise(n, 41), low=500, high=3000) * 0.6
    return _saturate(chord * 0.25, 1.4) + air * 0.08


def _note(freq, length, partials, drive=1.6):
    n = int(length * RATE)
    tone = dsp.harmonics(freq, n, partials)
    return _saturate(tone * 0.5, drive) * dsp.envelope(n, 0.008, 0.02)


def double_tap():
    """A short friendly 'beep beep', the way a driver thanks someone who let them in."""
    partials = [(1, 1.0, 0), (2, 0.4, 0), (3, 0.22, 0), (4, 0.08, 0)]
    beep = _note(587, 0.13, partials) + 0.8 * _note(740, 0.13, partials)
    gap = np.zeros(int(0.07 * RATE))
    rest = np.zeros(int(0.5 * RATE))
    return np.concatenate([beep, gap, beep, rest])


## The chiva's musical horn, composed for this game. MIDI note and seconds, 0 is a rest.
CHIVA_TUNE = [(81, 0.11), (81, 0.11), (78, 0.15), (83, 0.15), (81, 0.22), (0, 0.08),
              (76, 0.12), (78, 0.12), (74, 0.36), (0, 0.35)]


def chiva_tune():
    """A playful electric trumpet horn with a short tune, as chivas carry."""
    partials = [(1, 1.0, 0), (2, 0.5, 0), (3, 0.55, 0), (4, 0.2, 0), (5, 0.25, 0), (6, 0.08, 0), (7, 0.1, 0)]
    parts = []
    for note, length in CHIVA_TUNE:
        if note == 0:
            parts.append(np.zeros(int(length * RATE)))
        else:
            parts.append(_note(dsp.midi(note), length, partials, 2.0))
    return np.concatenate(parts)


## The fade in before a steady horn's loop, in seconds.
ATTACK = 0.025


def with_attack(sustain):
    """Puts a fade in before a seamless loop. The loop is the same sound turned
    round to start where the fade in ends, so it stays seamless.
    Returns the sound and its loop points."""
    a = int(ATTACK * RATE)
    ramp = np.sin(0.5 * np.pi * np.arange(a) / a) ** 2
    out = np.concatenate([sustain[:a] * ramp, sustain[a:], sustain[:a]])
    return out, (a, len(out))


def make_all(out, standard):
    """Writes every horn. The standard horn is the original city bus horn, passed in
    from make_sounds.py. All are brought to the same loudness as a phone speaker
    plays them, so the deep air horn is not quieter than the rest."""
    steady = {
        "horn_loop.wav": np.array(standard, dtype=float),
        "horn_two_tone.wav": two_tone(),
        "horn_air.wav": air_horn(),
    }
    tunes = {
        "horn_double_tap.wav": double_tap(),
        "horn_chiva.wav": chiva_tune(),
    }
    for name, sound in steady.items():
        sound, loop = with_attack(dsp.master(sound, LOUDNESS_DB, GATE_DB, heard=True))
        dsp.write(out / name, sound, loop)
    for name, sound in tunes.items():
        dsp.write(out / name, dsp.master(sound, LOUDNESS_DB, GATE_DB, heard=True), True)
