#!/usr/bin/env python3
"""Prints the levels of the horns, ambience and radio music made by make_sounds.py.

Checks each file for clipping, a peak above -1 dBFS and a jump at the loop point
written in the file. Radio tracks play once, so instead their first and last
10 ms must be near silent, or the song would click as it starts and ends. Shows
how loud each one is as a phone speaker plays it, so horns match horns and tracks
match tracks. Exits non-zero if a file fails. Needs numpy.

    python3 tools/check_sounds.py
"""
import struct
import sys
import wave
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
from sound_kit import dsp  # noqa: E402

AUDIO = Path(__file__).resolve().parent.parent / "assets" / "audio"
PEAK_LIMIT_DB = -1.0
## How sharp the turn at a loop point may be, compared with the sharpest turns
## the sound makes anywhere else (the 99.9th percentile of its second difference).
## Below 1 the join is smoother than the sound's own attacks.
SEAM_LIMIT = 1.0
## Horns and tracks may differ by this much in loudness within their group.
MATCH_DB = 1.5
## A song's first and last 10 ms stay below this, so it starts and ends in silence.
QUIET_ENDS = 0.01
ENDS_SECONDS = 0.01

GROUPS = {
    "Horns": (sorted(AUDIO.glob("horn_*.wav")), -35.0),
    "Ambience": (sorted((AUDIO / "ambience").glob("*.wav")), -45.0),
    "Radio": (sorted((AUDIO / "radio").glob("*.wav")), None),
}


def read(path):
    with wave.open(str(path), "rb") as f:
        frames = f.readframes(f.getnframes())
        rate, channels = f.getframerate(), f.getnchannels()
    return np.frombuffer(frames, dtype="<i2").astype(float) / 32768.0, rate, channels


def loop_points(path):
    """The loop from the file's smpl chunk, or None."""
    raw = path.read_bytes()
    at = raw.find(b"smpl", 12)
    if at < 0:
        return None
    _cue, _kind, start, end = struct.unpack("<4I", raw[at + 8 + 36:at + 8 + 52])
    return start, end


def seam(x, loop):
    """How sharply the sound turns where the loop jumps back, against its own
    sharpest turns elsewhere."""
    start, end = loop
    turn = abs(x[start] - 2 * x[end - 1] + x[end - 2])
    usual = np.percentile(np.abs(np.diff(x, 2)), 99.9)
    return turn / (usual + 1e-9)


def loud_ends(x):
    """The loudest sample in the first and in the last 10 ms."""
    n = int(ENDS_SECONDS * dsp.RATE)
    return max(np.max(np.abs(x[:n])), np.max(np.abs(x[-n:])))


def main():
    failed = []
    for group, (files, gate) in GROUPS.items():
        print("\n%s\n%-26s %6s %6s %8s %8s %6s %6s %5s" % (group, "file", "secs", "peak", "rms", "heard", "seam", "ends", "clip"))
        loudness = []
        for path in files:
            x, rate, channels = read(path)
            peak = dsp.peak_db(x)
            rms = dsp.rms_db(x, gate)
            heard = dsp.heard_db(x, gate)
            loop = loop_points(path)
            join = seam(x, loop) if loop else 0.0
            ends = loud_ends(x) if group == "Radio" else 0.0
            clipped = int(np.sum(np.abs(x) >= 0.999))
            loudness.append(heard)
            print("%-26s %6.1f %6.1f %8.1f %8.1f %6s %6s %5d" % (path.name, len(x) / rate, peak, rms, heard,
                                                              "%.2f" % join if loop else "-",
                                                              "%.4f" % ends if group == "Radio" else "-", clipped))
            if peak > PEAK_LIMIT_DB or clipped:
                failed.append("%s peaks at %.1f dBFS" % (path.name, peak))
            if group == "Radio" and loop:
                failed.append("%s is a song and must not loop" % path.name)
            if ends >= QUIET_ENDS:
                failed.append("%s does not start and end in silence (%.3f)" % (path.name, ends))
            if join > SEAM_LIMIT:
                failed.append("%s jumps at its loop point (%.2f)" % (path.name, join))
            if rate != dsp.RATE or channels != 1:
                failed.append("%s is not mono at %d Hz" % (path.name, dsp.RATE))
        if group != "Ambience" and loudness:
            spread = max(loudness) - min(loudness)
            print("loudness spread: %.1f dB" % spread)
            if spread > MATCH_DB:
                failed.append("%s differ by %.1f dB" % (group, spread))
    for problem in failed:
        print("FAIL:", problem)
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
