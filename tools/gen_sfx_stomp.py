"""Stomp sounds (docs/AUDIO.md, docs/decisions/0061-stomp-lock.md), set content/sfx/stomp.json. Run from tools/.

  stomp_crack   hard CC breaks a stomp: a bright crack and a short rising ring as the wisp is let go
  stomp_relief  the same break for the saved wisp's squad: a soft rising two-note chime and an
                exhale of air under it, "you're free" (plays with the crack, no position)
"""
import sfx_lib as S
from sfx_lib import N, env, mix, at, lpf, hpf, noise

S.reseed(6161)


def crack_free():
    snap = S.crack(0.05, 2500, 11000, 0.008) * 1.4
    glass = at(S.chime(1650, 0.5, 0.12), 0.01) * 0.5
    lift = at(S.sweep(900, 1900, 0.3) * env(N(0.3), 0.02, 0.1), 0.05) * 0.3
    return hpf(mix(snap, glass, lift), 200)


def relief():
    lo = S.chime(523, 0.55, 0.22, partials=((1.0, 1.0), (2.0, 0.25)))
    hi = at(S.chime(784, 0.6, 0.28, partials=((1.0, 1.0), (2.0, 0.25))), 0.11)
    breath = at(lpf(noise(0.4), 1800) * env(N(0.4), 0.06, 0.2), 0.02) * 0.3
    return mix(lo * 0.7, hi * 0.8, breath)


S.save_cat('stomp_crack', crack_free(), 'impact')
S.save_cat('stomp_relief', relief(), 'cast')
