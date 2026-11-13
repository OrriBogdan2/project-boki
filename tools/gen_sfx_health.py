"""The low-health heartbeat (docs/AUDIO.md, scripts/ui/low_hp_cue.gd). Run from tools/: python3 gen_sfx_health.py

One soft "lub-dub": two muffled thumps 0.17 s apart, the second a little higher and quieter. Each thump is a
low sine that falls in pitch, a quiet second harmonic so small speakers still carry it, and a dull noise
pat of the chest wall. It is felt more than heard. Three takes, each a hair different in pitch and timing.
"""
import numpy as np
import sfx_lib as S
from sfx_lib import N, env, mix, at, lpf, noise

S.reseed(2026)


def thump(f0, f1, d=0.2):
    """One beat: a pitch that falls from f0 to f1, its 2nd harmonic, and a dull pat."""
    body = S.sub(f0, f1, d, 0.055)
    over = 0.35 * S.sub(f0 * 2.0, f1 * 2.0, d * 0.6, 0.03)
    pat = 0.3 * lpf(noise(0.04), 380) * env(N(0.04), 0.002, 0.012)
    return mix(body, over, pat)


def heartbeat(i):
    k = 1.0 + (0 if i == 0 else S.rng.uniform(-0.05, 0.05))
    gap = 0.17 * (1.0 + (0 if i == 0 else S.rng.uniform(-0.06, 0.06)))
    lub = thump(78 * k, 46 * k)
    dub = 0.7 * thump(92 * k, 54 * k, 0.17)
    return lpf(mix(lub, at(dub, gap)), 520)


if __name__ == '__main__':
    S.takes_cat('heartbeat', heartbeat, 3, 'ui')
