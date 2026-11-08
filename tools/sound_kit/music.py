"""Original music for the fictional radio stations of Puerto Marisol.

Three styles inspired by the Caribbean coast: a cumbia-like 2/4 groove with a
tambora-style drum, a guacharaca-like scraper, bass and a gaita-like lead; a
vallenato-inspired paseo with an accordion-like voice and a caja; and a
champeta-inspired groove with bright plucked guitar runs. Rhythms and styles are
not anyone's property. Every melody is composed here by a seeded process that
walks the chords of each section, so each track is new.

A radio track is a song: it starts from silence, its last bar lands on a held
closing chord, and that chord rings out and fades away. The shop-doorway music
in the street is a loop instead: its notes are placed round a circular buffer, so
the tail of the last bar rings into the first.
"""
import numpy as np

from . import dsp

RATE = dsp.RATE
## Every track is mastered to this level as a phone speaker plays it, so stations
## match in loudness.
TRACK_DB = -19.0
## A song starts after this much silence, so its first beat never clicks.
LEAD_IN = 0.03
## Seconds after the last bar for the closing chord to ring out.
ENDING = 2.6
FADE_IN = 0.005
## The closing chord fades away over the last this many seconds.
FADE_OUT = 1.8

SCALES = {"major": [0, 2, 4, 5, 7, 9, 11], "minor": [0, 2, 3, 5, 7, 8, 10]}


# --- Instruments ---------------------------------------------------------

def membrane(freq, length, decay, drop=0.6, click=0.25, seed=0):
    """A hand-played drum: a pitched skin that sags as it rings, and a slap."""
    n = int(length * RATE)
    t = dsp.seconds(n)
    f = freq * (1.0 + drop * np.exp(-t * 35.0))
    body = np.sin(2 * np.pi * np.cumsum(f) / RATE) * np.exp(-t * decay)
    slap = dsp.shape(dsp.noise(n, seed), low=800, high=6000, wrap=False) * np.exp(-t * 90.0)
    return (body + click * slap) * dsp.envelope(n, 0.001, 0.01)


def wood(seed=0, pitch=1700.0):
    """A stick on the drum's wooden rim."""
    n = int(0.06 * RATE)
    t = dsp.seconds(n)
    tone = np.sin(2 * np.pi * pitch * t) * np.exp(-t * 110.0)
    tick = dsp.shape(dsp.noise(n, seed), low=1500, high=7000, wrap=False) * np.exp(-t * 200.0)
    return 0.7 * tone + 0.6 * tick


def scrape(length, seed=0, ridges=65.0):
    """A guacharaca-like scraper: noise chopped by the ridges of a cane."""
    n = int(length * RATE)
    t = dsp.seconds(n)
    hiss = dsp.shape(dsp.noise(n, seed), low=2500, high=9000, wrap=False)
    teeth = 0.35 + 0.65 * (np.sin(2 * np.pi * ridges * t) > 0.2)
    return hiss * teeth * dsp.envelope(n, 0.008, length * 0.6)


def shaker(seed=0, length=0.07):
    n = int(length * RATE)
    return dsp.shape(dsp.noise(n, seed), low=5000, high=10000, wrap=False) * dsp.envelope(n, 0.004, length * 0.8)


def kick():
    n = int(0.3 * RATE)
    t = dsp.seconds(n)
    f = 48.0 * (1.0 + 2.2 * np.exp(-t * 28.0))
    return np.sin(2 * np.pi * np.cumsum(f) / RATE) * np.exp(-t * 11.0)


def snare(seed=0):
    n = int(0.22 * RATE)
    t = dsp.seconds(n)
    tone = np.sin(2 * np.pi * 190.0 * t) * np.exp(-t * 30.0)
    rattle = dsp.shape(dsp.noise(n, seed), low=1500, high=8000, wrap=False) * np.exp(-t * 22.0)
    return 0.6 * tone + rattle


def bass(freq, length):
    """A round plucked bass."""
    n = int(length * RATE)
    tone = dsp.harmonics(freq, n, [(1, 1.0, 2.0), (2, 0.35, 4.0), (3, 0.12, 6.0)])
    return tone * dsp.envelope(n, 0.006, 0.05, decay=1.5)


def gaita(freq, length):
    """A breathy cane-flute voice, the way a gaita sits on top of cumbia."""
    n = int(length * RATE)
    tone = dsp.harmonics(freq, n, [(1, 1.0, 0), (2, 0.18, 0), (3, 0.12, 0), (4, 0.03, 0)], vibrato=0.006, vibrato_rate=5.3)
    breath = dsp.shape(dsp.noise(n, int(freq)), low=1200, high=5000, wrap=False) * 0.07
    return (tone + breath) * dsp.envelope(n, 0.035, 0.06)


def clarinet(freq, length):
    """A warm reed lead with mostly odd harmonics."""
    n = int(length * RATE)
    tone = dsp.harmonics(freq, n, [(1, 1.0, 0), (3, 0.45, 0), (5, 0.25, 0), (7, 0.1, 0), (2, 0.06, 0)],
                         vibrato=0.004, vibrato_rate=5.0)
    return tone * dsp.envelope(n, 0.03, 0.05)


def accordion(freq, length):
    """Two slightly detuned reeds per note, as a button accordion's tremolo voice."""
    n = int(length * RATE)
    partials = [(k, (1.0 / k ** 0.85) * (1.0 if k % 2 else 0.7), 0) for k in range(1, 14)]
    tone = dsp.harmonics(freq, n, partials, detune=-6.0) + dsp.harmonics(freq, n, partials, detune=6.0)
    return 0.5 * tone * dsp.envelope(n, 0.018, 0.04)


def keys(freqs, length):
    """A short organ-like chord stab on the off-beat."""
    n = int(length * RATE)
    out = np.zeros(n)
    for freq in freqs:
        out += dsp.harmonics(freq, n, [(1, 1.0, 0), (2, 0.5, 0), (4, 0.15, 0)])
    return out * dsp.envelope(n, 0.004, 0.03, decay=6.0) / max(1, len(freqs))


def guitar(freq, length):
    """A bright plucked electric guitar, upper partials fading first."""
    n = int(length * RATE)
    partials = [(k, 1.0 / k, 3.0 + 2.2 * k) for k in range(1, 12)]
    return dsp.harmonics(freq, n, partials) * dsp.envelope(n, 0.002, 0.03)


def synth_lead(freq, length):
    n = int(length * RATE)
    partials = [(k, 1.0 / k, 0) for k in range(1, 10)]
    tone = dsp.harmonics(freq, n, partials, vibrato=0.005, vibrato_rate=6.0, vibrato_delay=0.1)
    return dsp.shape(tone, high=2600, wrap=False) * dsp.envelope(n, 0.01, 0.05)


# --- Harmony and composition ----------------------------------------------

class Key:
    def __init__(self, tonic, mode):
        self.tonic = tonic
        self.mode = mode
        self.scale = SCALES[mode]

    def degree_pitch(self, degree):
        """MIDI pitch of a scale degree counted from 0, any octave."""
        octave, step = divmod(degree, 7)
        return self.tonic + 12 * octave + self.scale[step]

    def chord(self, root):
        """The triad on a scale degree, as scale degrees. In minor, V takes a major third."""
        return [root, root + 2, root + 4]

    def chord_pitch_classes(self, root):
        classes = {self.degree_pitch(d) % 12 for d in self.chord(root)}
        if self.mode == "minor" and root % 7 == 4:
            classes.add((self.degree_pitch(root + 2) + 1) % 12)
            classes.discard(self.degree_pitch(root + 2) % 12)
        return classes

    def pitch(self, degree, root):
        """A scale degree as MIDI, raising the leading note over a minor key's V chord."""
        p = self.degree_pitch(degree)
        if self.mode == "minor" and root % 7 == 4 and degree % 7 == 6:
            p += 1
        return p


def compose_phrase(rng, key, chords, steps_per_bar, rhythm, low, high, start):
    """One phrase of melody over the given chords (one per bar).

    rhythm lists (step, length) in steps across two bars and repeats. Strong
    steps land on a chord tone near the last note, others move by a step or two
    along the scale, and the phrase ends held on the chord's root.
    Returns notes as (absolute step, length in steps, scale degree, chord root)."""
    notes = []
    degree = start
    bars = len(chords)
    for bar in range(0, bars, 2):
        for step, length in rhythm:
            at_bar = bar + step // steps_per_bar
            if at_bar >= bars:
                continue
            root = chords[at_bar]
            strong = step % (steps_per_bar // 2) == 0
            if strong:
                tones = [d for d in range(low, high + 1) if key.degree_pitch(d) % 12 in
                         {key.degree_pitch(c) % 12 for c in key.chord(root)}]
                tones.sort(key=lambda d: abs(d - degree) + rng.uniform(0, 1.6))
                degree = tones[0]
            else:
                move = rng.choice([-2, -1, -1, 1, 1, 2, 0])
                if degree + move < low or degree + move > high:
                    move = -move
                degree += move
            notes.append((bar * steps_per_bar + step % (2 * steps_per_bar), length, degree, root))
    # Land on the root of the last chord, held.
    if notes:
        last_bar = bars - 1
        root = chords[last_bar]
        options = [d for d in range(low, high + 1) if (d - root) % 7 == 0]
        landing = min(options, key=lambda d: abs(d - degree))
        step, _length, _degree, _root = notes[-1]
        notes[-1] = (step, max(2, last_bar * steps_per_bar + steps_per_bar - step - 1), landing, root)
    return notes


def vary(rng, notes, key, low, high):
    """A second time through: the same shape, with a few notes nudged."""
    out = []
    for i, (step, length, degree, root) in enumerate(notes):
        if i < len(notes) - 1 and rng.uniform() < 0.25:
            degree = min(high, max(low, degree + rng.choice([-1, 1])))
        out.append((step, length, degree, root))
    return out


class Track:
    """Whole bars of music and a mix to place sounds into. A song has silence
    before it and room after it for the closing chord. A loop (song off) is a
    circular mix, so a tail past the end carries on at the start."""

    def __init__(self, bpm, beats_per_bar, bars, seed, song=True):
        self.step = 60.0 / bpm / 4.0
        self.steps_per_bar = beats_per_bar * 4
        self.bars = bars
        self.song = song
        self.rng = np.random.default_rng(seed)
        self.lead = int(LEAD_IN * RATE) if song else 0
        music = int(round(bars * self.steps_per_bar * self.step * RATE))
        self.mix = np.zeros(self.lead + music + (int(ENDING * RATE) if song else 0))

    def at(self, bar, step, humanise=0.0):
        seconds = (bar * self.steps_per_bar + step) * self.step
        if humanise:
            seconds += self.rng.uniform(-humanise, humanise)
        return self.lead + int(round(seconds * RATE))

    def put(self, sound, bar, step, gain=1.0, humanise=0.004):
        dsp.add(self.mix, sound, self.at(bar, step, humanise), gain * self.rng.uniform(0.88, 1.0), wrap=not self.song)

    def steps(self, count):
        return count * self.step

    def finale(self, sounds):
        """The closing hit of a song: (sound, gain) pairs all on the downbeat after
        the last bar. A loop has none."""
        if self.song:
            for sound, gain in sounds:
                dsp.add(self.mix, sound, self.at(self.bars, 0), gain, wrap=False)

    def render(self):
        out = dsp.master(self.mix, TRACK_DB, heard=True)
        return dsp.fade(out, FADE_IN, FADE_OUT) if self.song else out


def song_chords(sections, progressions):
    """The chord for every bar, from a list of section names."""
    out = []
    for name in sections:
        out.extend(progressions[name])
    return out


def melody_for(track, key, sections, progressions, rhythms, low, high, voice, gain, seed, harmony=None):
    """Composes a phrase for each named section and plays it each time that section
    comes round, varied on repeats. Sections without a rhythm are left to the band."""
    rng = np.random.default_rng(seed)
    phrases = {}
    bar = 0
    for name in sections:
        chords = progressions[name]
        if name in rhythms:
            if name not in phrases:
                phrases[name] = compose_phrase(rng, key, chords, track.steps_per_bar, rhythms[name], low, high, (low + high) // 2)
                notes = phrases[name]
            else:
                notes = vary(rng, phrases[name], key, low, high)
            for step, length, degree, root in notes:
                pitch = key.pitch(degree, root)
                sound = voice(dsp.midi(pitch), track.steps(length) * 0.95)
                track.put(sound, bar, step, gain)
                if harmony is not None:
                    below = key.pitch(degree - 2, root)
                    track.put(voice(dsp.midi(below), track.steps(length) * 0.95), bar, step, gain * harmony)
        bar += len(chords)


def chord_freqs(key, root, octave_shift=0):
    return [dsp.midi(key.pitch(d, root) + 12 * octave_shift) for d in key.chord(root)]


def home_chord(key, voice, length, octave_shift=1):
    """The key's own chord, held, for the end of a song."""
    return sum(voice(f, length) for f in chord_freqs(key, 0, octave_shift)) / 3.0


def home_bass(key, length):
    return bass(dsp.midi(key.pitch(0, 0) - 12), length)


# --- Styles --------------------------------------------------------------

def cumbia(bpm, key, sections, progressions, rhythms, lead, seed, song=True):
    """2/4 cumbia-like groove: tambora-style low drum and rim, scraper, hand drum,
    bass on one and the fifth, off-beat keys and a lead."""
    track = Track(bpm, 2, sum(len(progressions[s]) for s in sections), seed, song)
    chords = song_chords(sections, progressions)
    for bar, root in enumerate(chords):
        last = bar == track.bars - 1
        track.put(membrane(70, 0.4, 9, seed=bar), bar, 0, 0.3)
        track.put(membrane(78, 0.5, 7, seed=bar + 1), bar, 4, 0.6)
        for step in (2, 3, 6, 7):
            track.put(wood(bar * 8 + step), bar, step, 0.25 if step % 2 else 0.35)
        for step, length in ((0, 2), (2, 1), (3, 1), (4, 2), (6, 1), (7, 1)):
            track.put(scrape(track.steps(length) * 0.9, bar * 8 + step), bar, step, 0.42 if length == 2 else 0.3)
        for step in (1, 3, 5, 7):
            track.put(membrane(210, 0.18, 25, drop=0.2, click=0.6, seed=step + bar), bar, step, 0.22)
        if last:
            for step in (5, 6, 7):
                track.put(membrane(95, 0.25, 12, seed=step), bar, step, 0.6)
        root_pitch = key.pitch(root, root) - 12
        fifth_pitch = key.pitch(root + 4, root) - 24
        track.put(bass(dsp.midi(root_pitch), track.steps(3)), bar, 0, 0.45)
        track.put(bass(dsp.midi(fifth_pitch), track.steps(2)), bar, 4, 0.4)
        if bar % 2 == 1:
            track.put(bass(dsp.midi(root_pitch), track.steps(1)), bar, 7, 0.3)
        stab = chord_freqs(key, root, 0)
        for step in (2, 6):
            track.put(keys(stab, track.steps(1)), bar, step, 0.22)
    melody_for(track, key, sections, progressions, rhythms, 4, 13, lead, 0.5, seed + 1)
    track.finale([(membrane(70, 1.6, 3.5, seed=7), 0.8), (home_bass(key, ENDING), 0.5),
                  (scrape(0.3, 9), 0.4), (home_chord(key, lead, ENDING), 0.55),
                  (keys(chord_freqs(key, 0), 0.5), 0.25)])
    return track.render()


def vallenato(bpm, key, sections, progressions, rhythms, seed):
    """2/4 paseo inspired by vallenato: caja, scraper, syncopated bass, and an
    accordion playing the melody in thirds with off-beat chords between."""
    track = Track(bpm, 2, sum(len(progressions[s]) for s in sections), seed)
    chords = song_chords(sections, progressions)
    for bar, root in enumerate(chords):
        for step, kind in ((0, "tone"), (2, "slap"), (3, "ghost"), (4, "tone"), (6, "slap"), (7, "ghost")):
            if kind == "tone":
                track.put(membrane(160, 0.25, 16, drop=0.3, click=0.4, seed=bar + step), bar, step, 0.55)
            elif kind == "slap":
                track.put(membrane(240, 0.12, 30, drop=0.1, click=1.2, seed=bar + step), bar, step, 0.45)
            else:
                track.put(membrane(240, 0.08, 40, drop=0.1, click=0.8, seed=bar + step), bar, step, 0.18)
        for step, length in ((0, 2), (2, 1), (3, 1), (4, 2), (6, 1), (7, 1)):
            track.put(scrape(track.steps(length) * 0.85, bar * 8 + step, ridges=80.0), bar, step, 0.4 if length == 2 else 0.28)
        root_pitch = key.pitch(root, root) - 12
        fifth_pitch = key.pitch(root + 4, root) - 24
        for step, pitch, length in ((0, root_pitch, 2), (3, root_pitch, 1), (4, fifth_pitch, 2), (6, root_pitch + 12 if bar % 2 else fifth_pitch, 1)):
            track.put(bass(dsp.midi(pitch), track.steps(length)), bar, step, 0.42)
        stab = chord_freqs(key, root, 0)
        for step in (2, 6):
            track.put(accordion(stab[0], track.steps(1) * 0.8) + accordion(stab[1], track.steps(1) * 0.8), bar, step, 0.12)
    melody_for(track, key, sections, progressions, rhythms, 4, 13, accordion, 0.3, seed + 1, harmony=0.7)
    track.finale([(membrane(160, 0.6, 8, drop=0.3, click=0.5, seed=5), 0.7), (home_bass(key, ENDING), 0.45),
                  (scrape(0.3, 11, ridges=80.0), 0.4), (home_chord(key, accordion, ENDING), 0.5)])
    return track.render()


def champeta(bpm, key, sections, progressions, rhythms, riff_seed, seed):
    """4/4 champeta-inspired groove: syncopated kick, snare and rim, a bouncing bass,
    and bright guitar runs ringing over the chords, with a synth answering in places."""
    track = Track(bpm, 4, sum(len(progressions[s]) for s in sections), seed)
    chords = song_chords(sections, progressions)
    riff_rng = np.random.default_rng(riff_seed)
    # A sixteen-step guitar pattern over the chord tones, made once and kept, so the
    # guitar has a recognisable figure. Each entry is a chord tone index and octave.
    pattern = [(int(riff_rng.integers(0, 3)), int(riff_rng.integers(0, 2))) for _ in range(16)]
    rests = set(int(s) for s in riff_rng.choice(16, size=4, replace=False))
    for bar, root in enumerate(chords):
        for step in (0, 3, 8, 11):
            track.put(kick(), bar, step, 0.6, humanise=0.0)
        for step in (4, 12):
            track.put(snare(bar * 16 + step), bar, step, 0.45, humanise=0.0)
        for step in (6, 14):
            track.put(wood(bar + step, 2200.0), bar, step, 0.3)
        for step in range(0, 16, 2):
            track.put(shaker(bar * 16 + step), bar, step, 0.35 if step % 4 == 2 else 0.2)
        root_pitch = key.pitch(root, root) - 12
        for step, pitch, length in ((0, root_pitch, 2), (3, root_pitch, 1), (6, root_pitch + 12, 1), (8, root_pitch, 2), (11, root_pitch + 7, 1), (14, root_pitch + 12, 2)):
            track.put(bass(dsp.midi(pitch), track.steps(length)), bar, step, 0.5)
        tones = [key.pitch(d, root) + 12 for d in key.chord(root)]
        for step, (index, octave) in enumerate(pattern):
            if step in rests:
                continue
            track.put(guitar(dsp.midi(tones[index] + 12 * octave), track.steps(2)), bar, step, 0.2)
    melody_for(track, key, sections, progressions, rhythms, 5, 12, synth_lead, 0.22, seed + 1)
    strum = sum(guitar(f, ENDING) for f in chord_freqs(key, 0, 1)) / 3.0
    track.finale([(kick(), 0.7), (snare(99), 0.4), (home_bass(key, ENDING), 0.5),
                  (strum, 0.45), (home_chord(key, synth_lead, ENDING, 0), 0.2)])
    return track.render()


# --- The six tracks ----------------------------------------------------------

## Melody rhythms: (step, length) across two bars.
EIGHT = [(0, 2), (2, 1), (3, 1), (4, 3), (8, 2), (10, 2), (12, 1), (13, 3)]
LILT = [(0, 3), (3, 1), (4, 2), (6, 2), (8, 1), (9, 1), (10, 2), (12, 4)]
ANSWER = [(2, 2), (4, 1), (5, 1), (6, 2), (10, 1), (11, 1), (12, 4)]
## Chords per bar for each section, as scale degrees from 0.
CUMBIA_B = {"intro": [0, 0, 3, 4], "a": [0, 0, 3, 3, 4, 4, 0, 0], "b": [5, 5, 3, 3, 4, 4, 0, 4], "break": [3, 4, 0, 0]}


def track_list():
    """Name, how to make it. Titles are fictional and only appear in CREDITS.md."""
    eight, lilt, answer, cumbia_b = EIGHT, LILT, ANSWER, CUMBIA_B
    cumbia_a = {"intro": [0, 0, 4, 4], "a": [0, 0, 4, 4, 4, 4, 0, 0], "b": [3, 3, 0, 0, 4, 4, 0, 0], "break": [0, 4, 0, 4]}
    paseo = {"intro": [0, 0, 3, 3, 4, 4, 0, 0], "a": [0, 0, 3, 3, 4, 4, 0, 0], "b": [5, 5, 3, 3, 4, 4, 0, 0]}
    paseo_fast = {"intro": [0, 0, 4, 4], "a": [0, 0, 0, 0, 4, 4, 4, 4], "b": [3, 3, 0, 0, 4, 4, 0, 0], "break": [0, 4, 0, 4]}
    champ_a = {"intro": [0, 3], "a": [0, 3, 4, 3], "b": [5, 3, 0, 4], "break": [0, 3]}
    champ_b = {"intro": [0, 5], "a": [0, 5, 3, 4], "b": [3, 4, 0, 0], "break": [5, 4]}
    sixteen = [(0, 2), (3, 1), (4, 2), (6, 2), (8, 4), (16, 2), (18, 2), (20, 1), (21, 3), (24, 6)]
    return {
        "onda_marisol_1.wav": ("Brisa de las cinco", lambda: cumbia(
            94, Key(55, "major"), ["intro", "a", "b", "break", "a", "b"], cumbia_a,
            {"a": eight, "b": lilt}, gaita, 1101)),
        "onda_marisol_2.wav": ("Ventana al mar", lambda: cumbia(
            98, Key(57, "minor"), ["intro", "a", "b", "a", "break", "b"], cumbia_b,
            {"a": lilt, "b": answer}, clarinet, 1202)),
        "acordeon_puerto_1.wav": ("Paseo de la ciénaga", lambda: vallenato(
            108, Key(52, "minor"), ["intro", "a", "a", "b", "a", "b"], paseo,
            {"a": eight, "b": lilt}, 2101)),
        "acordeon_puerto_2.wav": ("Camino a Los Almendros", lambda: vallenato(
            122, Key(50, "major"), ["intro", "a", "b", "a", "break", "b", "a", "break"], paseo_fast,
            {"a": lilt, "b": eight}, 2202)),
        "pico_marisol_1.wav": ("Terraza Caliente", lambda: champeta(
            104, Key(60, "major"), ["intro", "a", "b", "a", "break", "b", "a"], champ_a,
            {"b": sixteen}, 3150, 3101)),
        "pico_marisol_2.wav": ("Baile en el Barrio", lambda: champeta(
            108, Key(57, "minor"), ["intro", "a", "b", "a", "break", "b", "a"], champ_b,
            {"b": sixteen, "a": sixteen}, 3250, 3202)),
    }


def shop_music():
    """The music from a shop doorway in the street: sixteen bars of "Ventana al mar"
    as a seamless loop, so it is the song people know from the radio."""
    return cumbia(98, Key(57, "minor"), ["a", "b"], CUMBIA_B, {"a": LILT, "b": ANSWER}, clarinet, 1202, song=False)


def make_all(out, ambience_out):
    """Writes the radio songs without loop points, so the radio moves on to the
    next track when one ends, and the shop music as a loop with its loop points."""
    for name, (_title, make) in track_list().items():
        dsp.write(out / name, make())
    dsp.write(ambience_out / "shop_music.wav", shop_music(), True)
