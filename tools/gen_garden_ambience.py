"""Garden ambience beds, layered by the home clock (scripts/home/home_ambience.gd drives them):

    amb_garden_morning   birdsong over a soft breeze
    amb_garden_midday    a quiet, warm hush with the odd far-off call
    amb_garden_evening   crickets and other insects as the light goes
    amb_garden_night     a slow, low wind
    amb_pond             water lapping at a bank, a faint trickle

    python3 tools/gen_garden_ambience.py   (then: godot --headless --import)

Seamless stereo Ogg loops written with gen_ambience's helpers; needs numpy, scipy and ffmpeg.
"""
import numpy as np
from gen_ambience import SR, lpf, hpf, bpf, slow, loop, write_ogg

rng = np.random.default_rng(311)
SECONDS = 20.0


def _place(out, clip, at, pan):
    end = min(len(out), at + len(clip))
    out[at:end, 0] += clip[:end - at] * (1.0 - pan)
    out[at:end, 1] += clip[:end - at] * pan


def _chirp(f0, f1, length, wobble=0.0):
    t = np.arange(int(SR * length)) / SR
    f = np.linspace(f0, f1, len(t)) * (1.0 + wobble * np.sin(2 * np.pi * 28 * t))
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * np.abs(np.sin(np.pi * t / t[-1])) ** 1.5


def _bed(n, cutoff, level, rate):
    """Soft wind: low-passed noise whose strength drifts slowly, one channel."""
    return lpf(rng.standard_normal(n), cutoff) * slow(n, rate, 0.3, 1.0) * level


def morning():
    n = int(SR * (SECONDS + 2.0))
    out = np.stack([_bed(n, 500, 0.5, 0.2), _bed(n, 500, 0.5, 0.2)], 1)
    for _ in range(11):                      # phrases: a few chirps in a row from one bird
        at = int(rng.integers(0, n - SR * 2)); pan = rng.uniform(0.15, 0.85)
        base = rng.uniform(2200, 4200)
        for k in range(int(rng.integers(2, 6))):
            c = _chirp(base * rng.uniform(0.9, 1.15), base * rng.uniform(1.1, 1.5), rng.uniform(0.06, 0.14), 0.04)
            _place(out, c * rng.uniform(0.3, 0.6), at + int(k * SR * rng.uniform(0.12, 0.2)), pan)
    return loop(out)


def midday():
    n = int(SR * (SECONDS + 2.0))
    out = np.stack([_bed(n, 700, 0.35, 0.12), _bed(n, 700, 0.35, 0.12)], 1)
    for _ in range(2):                       # a far-off call, soft and low in the mix
        at = int(rng.integers(0, n - SR)); pan = rng.uniform(0.2, 0.8)
        _place(out, _chirp(1800, 2500, 0.22, 0.03) * 0.12, at, pan)
    return loop(out)


def evening():
    n = int(SR * (SECONDS + 2.0)); t = np.arange(n) / SR
    out = np.zeros((n, 2))
    for c in range(2):                       # crickets: a high tone chopped into fast pulses, swelling and fading
        for f in rng.uniform(3900, 5200, 3):
            pulse = np.clip(np.sin(2 * np.pi * rng.uniform(26, 34) * t), 0, 1) ** 2
            swell = np.clip(slow(n, 0.15, -0.4, 1.0), 0, 1)
            out[:, c] += np.sin(2 * np.pi * f * t) * pulse * swell * 0.12
    out += np.stack([_bed(n, 400, 0.15, 0.15)] * 2, 1)
    return loop(out)


def night():
    n = int(SR * (SECONDS + 2.0))
    chans = []
    for _ in range(2):
        gust = slow(n, 0.1, 0.1, 1.0) ** 1.5
        chans.append(lpf(rng.standard_normal(n), 260) * gust * 1.2 + bpf(rng.standard_normal(n), 300, 700) * gust * 0.08)
    return loop(np.stack(chans, 1))


def pond():
    n = int(SR * (SECONDS + 2.0))
    out = np.zeros((n, 2))
    for c in range(2):                       # lapping: band-passed noise in slow waves, a hiss of ripples on top
        wave = (0.5 + 0.5 * np.sin(2 * np.pi * rng.uniform(0.11, 0.16) * np.arange(n) / SR + rng.uniform(0, 6))) ** 2
        out[:, c] = bpf(rng.standard_normal(n), 250, 900) * wave * 0.6 + hpf(lpf(rng.standard_normal(n), 3500), 1500) * slow(n, 0.5, 0.0, 0.25)
    for _ in range(14):                      # drips: a short falling blip
        _place(out, _chirp(1600, 700, 0.05) * rng.uniform(0.1, 0.25), int(rng.integers(0, n - SR)), rng.uniform(0.1, 0.9))
    return loop(out)


if __name__ == '__main__':
    write_ogg('amb_garden_morning', morning(), 0.5)
    write_ogg('amb_garden_midday', midday(), 0.4)
    write_ogg('amb_garden_evening', evening(), 0.5)
    write_ogg('amb_garden_night', night(), 0.5)
    write_ogg('amb_pond', pond(), 0.5)
