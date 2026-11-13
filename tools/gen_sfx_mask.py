"""The Relic put-on beat's sounds (MaskBeat, scripts/ui/mask_beat.gd). Run from tools/.

Porcelain and breath, our own synthesis; MaskBeat times them from the beat (a flicker, the fade, the end), so
none of them has a length of its own to keep in step:
  mask_flicker  ui    one cool porcelain chime with a tiny glaze tick; played once per flicker of the ghost
                      face, each a major third up (pitch_scale)
  mask_swell    loop  a warm hum on a low fifth with a breath of air; MaskBeat lifts its pitch and volume over
                      the fade, the Hunter settling in from the feet up
  mask_settle   ui    the end: a soft low note that dies away, the weight arriving
"""
import numpy as np
import sfx_lib as S
from sfx_lib import N, T, env, mix, at, lpf, bpf

S.reseed(1183)


def flicker():
    bell = S.chime(1175.0, 1.3, 0.5, ((1.0, 1.0), (2.32, 0.5), (4.1, 0.25), (6.7, 0.1)))
    tick = bpf(S.rng.standard_normal(N(0.03)), 3000, 9000) * env(N(0.03), 0.0005, 0.006)
    return mix(bell, tick * 0.2)


def swell():
    d = 2.0; t = T(d)                      # whole cycles in 2 s, so the loop is seamless
    hum = sum(g * np.sin(2 * np.pi * f * t) for f, g in [(110.0, 1.0), (165.0, 0.6), (220.0, 0.4), (330.0, 0.15)])
    sway = 0.8 + 0.2 * np.sin(2 * np.pi * 1.5 * t)
    air = bpf(S.rng.standard_normal(N(d)), 700, 3500) * 0.25
    return hum * sway + air


def settle():
    d = 1.4
    low = S.kick(160.0, 82.0, d, drop=0.08, decay=0.28, drive=1.0)
    note = S.chime(330.0, d, 0.6, ((1.0, 1.0), (2.0, 0.3)))
    breath = lpf(S.rng.standard_normal(N(d)), 900) * env(N(d), 0.02, 0.3) * 0.2
    return mix(low * 0.7, note * 0.5, breath)


if __name__ == '__main__':
    S.save_cat('mask_flicker', flicker(), 'ui')
    S.save_loop('mask_swell', swell(), 'loop')
    S.save_cat('mask_settle', settle(), 'ui')
    print('mask sounds written')
