"""Writes audio/amb_match.ogg: the soft wind and engine-room bed heard from the moment a match starts (the ship).

A seamless 48 s mono loop. Every layer is made in the frequency domain, so the end meets the start exactly (no
crossfade seam) and nothing in it is a regular swell: the slow level drift is smoothed noise (no sine pulse that
repeats every few seconds), so the ear finds no beat to count. Peak -12 dBFS, 6 dB under the old 13 s bed.
Run: python3 tools/gen_amb_match.py
"""

import numpy as np

from gen_music import SR, write_ogg

SECONDS = 48.0
PEAK = 0.25  # linear peak (-12 dBFS); the old bed peaked at 0.6, so this is 7.6 dB lower
rng = np.random.default_rng(1117)


def shaped(n, lo_hz, hi_hz):
    """Circular band-limited noise: a smooth, exactly looping signal."""
    spec = np.fft.rfft(rng.normal(0, 1, n))
    f = np.fft.rfftfreq(n, 1 / SR)
    spec *= 1 / (1 + (f / hi_hz) ** 4) / (1 + (lo_hz / np.maximum(f, 1e-3)) ** 4)
    return np.fft.irfft(spec, n)


def drift(n, depth):
    """A level that wanders (about +-depth) on a 6 to 20 s scale, never on a beat."""
    slow = shaped(n, 0.02, 0.12)
    return 1.0 + depth * slow / np.max(np.abs(slow))


def bed():
    n = int(SR * SECONDS)
    wind = shaped(n, 90, 650) * drift(n, 0.25)  # the airy part
    air = shaped(n, 700, 1800) * drift(n, 0.4)  # a little hiss on top, drifting on its own
    hull = shaped(n, 40, 140) * drift(n, 0.2) * 1.4  # the engine room: a low rumble, no pitch to count
    x = wind / np.std(wind) + air / np.std(air) * 0.12 + hull / np.std(hull) * 0.9
    return x


if __name__ == "__main__":
    write_ogg("amb_match", bed(), PEAK)
