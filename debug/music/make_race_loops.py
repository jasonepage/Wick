#!/usr/bin/env python3
# SPDX-License-Identifier: MPL-2.0
"""
Builds the race music files from GarageBand exports (3.5).

    python3 debug/music/make_race_loops.py chill.m4a kiai.m4a riser.m4a

The two loops must be 120 BPM and exactly 16 bars (32 s) of music. GarageBand
adds a ringing tail after that; this script folds the tail back onto the start
so the loop point is smooth. Then for each loop it:

  1. sets the loudness to -16 LUFS so chill and kiai match,
  2. limits peaks to about -1 dB, on three copies in a row so the limiter is
     settled when it reaches the loop point,
  3. writes a padded file: the loop's last second, the 32 s loop, its first
     second. The players loop the window from 1 s to 33 s, so a decoder's start
     delay can't put a gap in the loop (see RaceMusic.swift and music.ts),
  4. encodes it as Hunch/Sounds/race_<name>.m4a (iOS) and
     wick-web/public/sounds/race_<name>.mp3 (web).

It prints the jump at the loop point next to the song's typical sample step.
When the jump is more than twice the typical step, it fades the last and first
1.5 ms of the loop so the join can't click (too short to hear).

The riser is a one-shot that plays into the switch from chill to kiai. It must
be exactly 2 bars (4 s) at 120 BPM, ending on the downbeat where kiai starts.
It is trimmed to 4 s, set to the same loudness, and encoded the same way.

Needs ffmpeg, numpy and soundfile (pip install numpy soundfile).
"""

import os
import subprocess
import sys
import tempfile

import numpy as np
import soundfile as sf

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
LOOP_SECONDS = 32
TARGET_LUFS = -16.0


def run(*args):
    subprocess.run(["ffmpeg", "-v", "error", "-y", *args], check=True)


def loudness(path):
    out = subprocess.run(["ffmpeg", "-hide_banner", "-i", path, "-af", "ebur128", "-f", "null", "-"],
                         capture_output=True, text=True).stderr
    lines = [l for l in out.splitlines() if l.strip().startswith("I:")]
    return float(lines[-1].split()[1])


def build(src, name, tmp):
    wav = os.path.join(tmp, f"{name}.wav")
    run("-i", src, wav)
    y, sr = sf.read(wav)
    n = LOOP_SECONDS * sr
    if len(y) < n:
        sys.exit(f"{src}: only {len(y) / sr:.2f} s long, needs {LOOP_SECONDS} s")
    loop = y[:n].copy()
    tail = y[n:n + sr * 4]
    loop[:len(tail)] += tail

    sf.write(wav, loop, sr)
    loop *= 10 ** ((TARGET_LUFS - loudness(wav)) / 20)

    triple = os.path.join(tmp, f"{name}_x3.wav")
    limited = os.path.join(tmp, f"{name}_x3_lim.wav")
    sf.write(triple, np.concatenate([loop, loop, loop]), sr)
    run("-i", triple, "-af", "alimiter=limit=0.891:attack=5:release=50:level=disabled:latency=1", limited)
    x3, _ = sf.read(limited)
    loop = x3[n:2 * n]

    seam = float(np.abs(loop[0] - loop[-1]).mean())
    step = float(np.abs(np.diff(loop, axis=0)).mean())
    if seam > 2 * step:
        k = int(0.0015 * sr)
        ramp = np.linspace(0, 1, k)[:, None]
        loop[:k] *= ramp
        loop[-k:] *= ramp[::-1]
        print(f"{name}: loop jump {seam:.4f} vs typical step {step:.4f}, faded the join "
              f"(now {float(np.abs(loop[0] - loop[-1]).mean()):.4f})")
    else:
        print(f"{name}: loop jump {seam:.4f} vs typical step {step:.4f} (clean)")

    padded = os.path.join(tmp, f"{name}_padded.wav")
    sf.write(padded, np.concatenate([loop[-sr:], loop, loop[:sr]]), sr)
    encode(padded, name)


def encode(wav, name):
    run("-i", wav, "-c:a", "aac", "-b:a", "128k", os.path.join(ROOT, "Hunch", "Sounds", f"race_{name}.m4a"))
    run("-i", wav, "-c:a", "libmp3lame", "-b:a", "128k",
        os.path.join(ROOT, "wick-web", "public", "sounds", f"race_{name}.mp3"))


RISER_SECONDS = 4


def build_riser(src, tmp):
    wav = os.path.join(tmp, "riser.wav")
    run("-i", src, wav)
    y, sr = sf.read(wav)
    n = RISER_SECONDS * sr
    if len(y) < n:
        sys.exit(f"{src}: only {len(y) / sr:.2f} s long, the riser needs {RISER_SECONDS} s")
    loud = np.abs(y).max(axis=1) if y.ndim > 1 else np.abs(y)
    after = np.where(loud[n + int(0.05 * sr):] > 0.01)[0]
    if len(after):
        print(f"riser: warning, there is sound {after[0] / sr + 0.05:.2f} s after the 2 bars; it is cut")
    riser = y[:n].copy()
    k = int(0.005 * sr)
    riser[-k:] *= np.linspace(1, 0, k)[:, None]   # no click where it is cut
    sf.write(wav, riser, sr)
    riser *= 10 ** ((TARGET_LUFS - loudness(wav)) / 20)
    peak = float(np.abs(riser).max())
    if peak > 0.891:
        riser *= 0.891 / peak
    out = os.path.join(tmp, "riser_out.wav")
    sf.write(out, riser, sr)
    print(f"riser: {RISER_SECONDS} s, peak {20 * np.log10(float(np.abs(riser).max())):.1f} dB")
    encode(out, "riser")


def main():
    if len(sys.argv) != 4:
        sys.exit(__doc__)
    with tempfile.TemporaryDirectory() as tmp:
        build(sys.argv[1], "chill", tmp)
        build(sys.argv[2], "kiai", tmp)
        build_riser(sys.argv[3], tmp)


if __name__ == "__main__":
    main()
