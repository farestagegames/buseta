"""Street ambience for Puerto Marisol: loops mixed by where the bus is, and short
sounds played now and then. No recorded speech, no recordings at all.
"""
import numpy as np

from . import dsp

RATE = dsp.RATE
## Each layer is set to about this loudness. The pack's volume_db does the mixing.
LAYER_DB = -20.0


def _cyclic_bump(n, centre, rise, fall):
    """An envelope that rises to a peak at centre and falls away, wrapping round
    the loop so a wave near the end carries on at the start."""
    t = dsp.seconds(n)
    length = n / RATE
    d = (t - centre + length / 2) % length - length / 2
    return np.where(d < 0, np.exp(-(d / rise) ** 2), np.exp(-d / fall))


def city_bed():
    """Traffic murmur from the streets around: a low rumble, a mid wash that swells
    slowly and a little tyre hiss. No single car stands out, so the 24 s loop is
    hard to hear repeat; the passing motorbikes are one-off sounds of their own."""
    n = RATE * 24
    rumble = dsp.shape(dsp.noise(n, 50), high=220, tilt=-1.0)
    wash = dsp.shape(dsp.noise(n, 51), low=250, high=2200, tilt=-0.6)
    hiss = dsp.shape(dsp.noise(n, 52), low=2000, high=6000)
    t = dsp.seconds(n)
    # Slow swells whose periods all divide the loop, so the join stays seamless.
    swell = 0.78 + 0.1 * np.sin(2 * np.pi * t / 24) + 0.07 * np.sin(2 * np.pi * 5 * t / 24 + 1.0) \
        + 0.05 * np.sin(2 * np.pi * 11 * t / 24 + 2.3)
    out = (0.45 * rumble / np.std(rumble) + swell * wash / np.std(wash)
           + 0.12 * (0.4 + 0.3 * swell) * hiss / np.std(hiss))
    return dsp.master(out, LAYER_DB)


def sea_waves():
    """Caribbean waves on the beach below the Malecón: a soft swell, a break and
    the fizz of water running back."""
    n = RATE * 12
    low = dsp.shape(dsp.noise(n, 60), low=60, high=400, tilt=-0.5)
    body = dsp.shape(dsp.noise(n, 61), low=200, high=4500, tilt=-0.4)
    fizz = dsp.shape(dsp.noise(n, 62), low=2500, high=8000)
    waves = [(1.0, 1.3, 2.4, 1.0), (5.3, 1.6, 2.8, 0.8), (9.1, 1.1, 2.2, 0.9)]
    crash = sum(s * _cyclic_bump(n, c, r, f) for c, r, f, s in waves)
    run_back = sum(s * _cyclic_bump(n, c + 0.6, 0.6, f * 1.6) for c, _r, f, s in waves)
    out = (0.5 * low / np.std(low) + crash * body / np.std(body)
           + 0.35 * run_back * fizz / np.std(fizz))
    return dsp.master(out, LAYER_DB)


def _sweep(start_hz, end_hz, length, curve=1.0):
    n = int(length * RATE)
    t = np.linspace(0.0, 1.0, n) ** curve
    freq = start_hz + (end_hz - start_hz) * t
    return np.sin(2 * np.pi * np.cumsum(freq) / RATE) * np.sin(np.pi * np.linspace(0, 1, n)) ** 0.6


def grackle_whistle():
    """The great-tailed grackle's rising whistle."""
    return _sweep(1300, 4200, 0.38, 1.8)


def grackle_clacks(seed):
    """Its dry wooden clacks, a quick run of them."""
    rng = np.random.default_rng(seed)
    out = np.zeros(int(0.5 * RATE))
    for i in range(rng.integers(3, 6)):
        click = dsp.shape(dsp.noise(int(0.02 * RATE), seed + i), low=1500, high=5000, wrap=False)
        click *= dsp.envelope(len(click), 0.001, 0.0, decay=220)
        at = int(i * 0.075 * RATE)
        out[at:at + len(click)] += click
    return out


def parrot_squawk(seed):
    """A parrot flying over: a rough, buzzing squawk."""
    rng = np.random.default_rng(seed)
    n = int(rng.uniform(0.18, 0.28) * RATE)
    t = dsp.seconds(n)
    base = rng.uniform(1700, 2400)
    freq = base + 450 * np.sin(2 * np.pi * rng.uniform(28, 40) * t)
    tone = np.sign(np.sin(2 * np.pi * np.cumsum(freq) / RATE)) * 0.4 + np.sin(2 * np.pi * np.cumsum(freq) / RATE)
    rough = 1.0 + 0.5 * dsp.shape(dsp.noise(n, seed), high=300, wrap=False)
    out = dsp.shape(tone * rough, low=900, high=5000, wrap=False)
    return out * np.sin(np.pi * np.linspace(0, 1, n)) ** 0.5


def birds():
    """Grackles and parrots in the palms, at seeded random times over a 40 s loop
    with quiet between, so there is no short pattern to hear repeat."""
    length = 40
    n = RATE * length
    out = np.zeros(n)
    rng = np.random.default_rng(70)
    events = []
    when = 0.4
    while when < length - 0.5:
        kind = str(rng.choice(["whistle", "whistle", "clacks", "parrot"]))
        events.append((when, kind))
        if kind == "parrot" and rng.uniform() < 0.6:
            events.append((when + rng.uniform(0.2, 0.35), "parrot"))
        when += rng.uniform(0.5, 3.4)
    for i, (when, kind) in enumerate(events):
        if kind == "whistle":
            sound, gain = grackle_whistle(), rng.uniform(0.5, 0.8)
        elif kind == "clacks":
            sound, gain = grackle_clacks(80 + i), rng.uniform(0.5, 0.8)
        else:
            sound, gain = parrot_squawk(90 + i), rng.uniform(0.35, 0.55)
        dsp.add(out, sound, int(when * RATE), gain)
    # A little distance: birds up in the trees, not in the bus.
    out = dsp.shape(out, high=6000)
    return dsp.master(out, LAYER_DB, gate_db=-45)


def rain():
    """A hook for the weather to come: steady rain on the street and the roof."""
    n = RATE * 6
    hiss = dsp.shape(dsp.noise(n, 100), low=400, high=9000, tilt=-0.2)
    out = hiss / np.std(hiss)
    rng = np.random.default_rng(101)
    for _ in range(240):
        length = int(0.006 * RATE)
        drop = np.sin(2 * np.pi * rng.uniform(2000, 5000) * dsp.seconds(length)) * np.exp(-dsp.seconds(length) * 700)
        dsp.add(out, drop, int(rng.integers(0, n)), rng.uniform(1.0, 3.0))
    return dsp.master(out, LAYER_DB)


def motorbike_pass():
    """A small motorbike buzzing past, its note dropping as it goes by."""
    length = 3.2
    n = int(length * RATE)
    t = dsp.seconds(n)
    speed, nearest, passing = 13.0, 5.0, 1.5
    x = speed * (t - passing)
    distance = np.sqrt(x * x + nearest * nearest)
    approach = speed * x / distance
    firing = 105.0 * (1.0 + 0.04 * np.sin(2 * np.pi * 1.3 * t)) / (1.0 + approach / 343.0)
    phase = 2 * np.pi * np.cumsum(firing) / RATE
    buzz = sum((1.0 / k ** 0.7) * np.sin(k * phase) for k in range(1, 28) if 105 * k * 1.05 < RATE * 0.45)
    exhaust = dsp.shape(dsp.noise(n, 110), low=300, high=3000, wrap=False) * (0.6 + 0.4 * np.sin(phase))
    near = buzz / np.std(buzz) + 0.5 * exhaust / np.std(exhaust)
    far = dsp.shape(near, high=900, wrap=False)
    closeness = nearest / distance
    out = (closeness * near + (1.0 - closeness) * far) * closeness ** 0.8
    out *= dsp.envelope(n, 0.3, 0.4)
    return dsp.master(out, LAYER_DB + 2, gate_db=-40)


def vendor_bell():
    """A paletero's hand bell, rung three times as the cart goes along."""
    n = int(1.6 * RATE)
    out = np.zeros(n)
    partials = [(1.0, 1.0, 5.0), (2.0, 0.35, 7.0), (2.76, 0.5, 9.0), (5.4, 0.25, 14.0), (8.9, 0.1, 20.0)]
    for i, when in enumerate([0.0, 0.27, 0.54]):
        ring = dsp.harmonics(1180.0, n - int(when * RATE), partials)
        ring *= dsp.envelope(len(ring), 0.002, 0.05)
        out[int(when * RATE):] += ring * (1.0 - 0.15 * i)
    return dsp.master(out, LAYER_DB, gate_db=-40)


def sharpener_whistle():
    """A knife sharpener's pan pipe: a quick run up and down, breathy and soft."""
    notes = [72, 74, 76, 79, 81, 84, 86, 84, 81, 79, 76, 74, 72]
    parts = []
    for i, note in enumerate(notes):
        length = 0.07 if i not in (6, len(notes) - 1) else 0.2
        n = int(length * RATE)
        tone = dsp.harmonics(dsp.midi(note), n, [(1, 1.0, 0), (2, 0.08, 0), (3, 0.05, 0)])
        breath = dsp.shape(dsp.noise(n, 120 + i), low=1500, high=7000, wrap=False) * 0.25
        parts.append((tone + breath) * dsp.envelope(n, 0.01, 0.02))
    return dsp.master(np.concatenate(parts), LAYER_DB, gate_db=-40)


## Beds that loop for as long as they are heard. The rest play once each time.
LOOPS = ["city_bed.wav", "sea_waves.wav", "birds.wav", "rain.wav"]


def make_all(out):
    for name, sound in {
        "city_bed.wav": city_bed(),
        "sea_waves.wav": sea_waves(),
        "birds.wav": birds(),
        "rain.wav": rain(),
        "motorbike_pass.wav": motorbike_pass(),
        "vendor_bell.wav": vendor_bell(),
        "sharpener_whistle.wav": sharpener_whistle(),
    }.items():
        dsp.write(out / name, sound, name in LOOPS)
