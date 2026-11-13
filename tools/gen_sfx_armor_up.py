"""The armour tier-up cues (Juice.armor_up) into audio/armor_up.wav and audio/armor_up_own.wav.

    python3 tools/gen_sfx_armor_up.py      (then: godot --headless --import)

Our own sounds, numpy only, own random stream. Both are a metallic rise: a sine glide up a fifth with a
ring of inharmonic plate partials, and a bright ting where it lands. Juice sets the pitch per tier.
  armor_up     : ~0.4 s, what everyone nearby hears (positional).
  armor_up_own : ~0.55 s, your own Hunter's: the same rise with an octave-up shimmer and a low plate thump.
"""
import numpy as np
import sfx_lib as S
from sfx_lib import N, T, env, mix, at, lpf

S.reseed(5307)
F0, F1 = 520.0, 780.0        # Hz: the glide's start and end (a fifth up); the tier then shifts it by pitch_scale


def glide(d, f0, f1):
    n = N(d)
    f = np.geomspace(f0, f1, n)
    return np.sin(2 * np.pi * np.cumsum(f) / S.SR) * env(n, 0.012, d * 0.55)


def rise(d, own):
    n = N(d)
    body = glide(d, F0, F1) * 0.5
    plate = glide(d, F0 * 1.58, F1 * 1.58) * 0.22 + glide(d, F0 * 2.31, F1 * 2.31) * 0.12
    base = 2 * F1
    ting = at(S.ring((base, base * 2.01, base * 2.76), 0.2, (0.07, 0.04, 0.025), (0.5, 0.2, 0.12)), d * 0.5)
    scrape = S.bpf(S.noise(d), 2500, 8000) * env(n, 0.05, d * 0.3) * 0.12
    x = mix(body, plate, ting, scrape, S.click(0.003, 3000, 9000) * 0.6)
    if own:
        x = mix(x, glide(d, F0 * 2, F1 * 2) * 0.22, at(S.kick(200, 90, 0.2, 0.02, 0.07, 2.0) * 0.5, d * 0.5))
    return lpf(x, 9000)


if __name__ == '__main__':
    S.save_cat('armor_up', rise(0.4, False), 'cast')
    S.save_cat('armor_up_own', rise(0.55, True), 'impact')
