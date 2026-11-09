"""The abyss sounds (docs/AUDIO.md): falling off an island, the glider catching you, and the end. Run from tools/: python3 gen_sfx_abyss.py

  abyss_whoosh  : 1.1 s. Wind rushing up past you as you drop under the island's lip: band-passed air whose
                  centre climbs from 250 Hz to 2.6 kHz while it swells.
  abyss_catch   : 0.55 s. The canopy biting: a cloth snap, a low thump and a short upward gust.
  abyss_strain  : 1.4 s loop. An overheated glider lifting at half strength: a tight stick-slip creak over a
                  hot, thin hiss, never settling.
  abyss_fallout : 2.4 s. The point of no return: a long falling wail through thinning wind, then one far,
                  soft thud at the bottom. Heard by teammates too (reach in content/sfx/abyss.json).
"""
import numpy as np
import sfx_lib as S
from sfx_lib import N, T, env, mix, at, lpf, hpf, bpf, noise

S.reseed(4417)


def gust(d, f0, f1, peak, bands=7):
    """Noise through a band whose centre glides f0 -> f1 (a bank of fixed bands weighted over time)."""
    centres = f0 * (f1 / f0) ** (np.arange(bands) / (bands - 1))
    t = np.arange(N(d)) / S.SR / d
    out = np.zeros(N(d))
    for i, c in enumerate(centres):
        w = np.exp(-((t - i / (bands - 1)) ** 2) / (2 * (0.75 / bands) ** 2))
        out += w * bpf(noise(d), c * 0.7, c * 1.4)
    return out * peak


def whoosh(i):
    d = 1.1
    rise = S.shape(d, 0.75, 0.0, 0.35)
    wind = gust(d, 250, 2600, 1.0) * rise
    sub = lpf(noise(d), 160) * rise * 0.6
    return S.soft_in(mix(wind, sub), 6)


def catch(i):
    snap = S.crack(0.09, 900, 4200, 0.03) * 1.2
    thump = S.kick(150, 62, 0.3, drop=0.05, decay=0.1) * 0.9
    up = gust(0.4, 400, 2200, 0.5) * S.shape(0.4, 0.05, 0.0, 0.3)
    return S.soft_in(mix(snap, thump, up), 1)


def strain():
    d = 1.4
    n = N(d); t = np.arange(n) / S.SR
    f = 62 * (1 + 0.18 * np.sin(2 * np.pi * 2.5 * t) + 0.07 * np.sin(2 * np.pi * 7.1 * t))
    ph = np.cumsum(f) / S.SR
    pulses = (np.diff(np.floor(ph), prepend=0) > 0).astype(float) * (1 + 0.6 * S.rng.standard_normal(n))
    creak = bpf(pulses, 220, 1500) + 0.35 * bpf(pulses, 700, 1100)
    hot = hpf(noise(d), 3500) * (0.12 + 0.05 * np.sin(2 * np.pi * 5.0 * t))
    return creak / (np.max(np.abs(creak)) or 1.0) + hot / (np.max(np.abs(hot)) or 1.0) * 0.25


def fallout(i):
    d = 2.4
    fade = S.shape(d, 0.15, 0.5, 1.7)
    wail = lpf(S.sweep(620, 70, d, 'saw', 1.4), 1100) * fade * 0.5
    wail += 0.25 * S.sweep(930, 105, d) * fade
    wind = gust(d, 2200, 180, 0.8) * fade
    thud = at(S.kick(70, 28, 0.7, drop=0.12, decay=0.22), 1.55) * 1.4
    far = at(lpf(noise(0.8), 260) * env(N(0.8), 0.01, 0.2), 1.55) * 0.5
    return S.reflections(mix(wail, wind, thud, far), ((0.11, 0.3, 900), (0.23, 0.2, 700)))


if __name__ == '__main__':
    S.takes_cat('abyss_whoosh', whoosh, 1, 'dash')
    S.takes_cat('abyss_catch', catch, 1, 'cast')
    S.save_loop('abyss_strain', strain(), 'loop')
    S.save_cat('abyss_fallout', fallout(0), 'heavy_impact')
