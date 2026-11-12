"""Stomp sounds (docs/AUDIO.md, docs/decisions/0061-stomp-lock.md), set content/sfx/stomp.json. Run from tools/.

  stomp_commit  the 0.2 s hold commits: a heel scuff and a short low latch that says "locked in"
  stomp_strike  one foot slam on the wisp (3 takes); StompSfx pitches it and adds the shared thump
                under it per the Hunter's weight class, so one file covers light, medium and heavy
  stomp_crush   the finish on the last slam: a deep crushing slam, a crunch and the wisp's light
                squeezed out under the foot (a falling tone choked off)
  stomp_crack   CC breaks the stomp: a bright crack and a short rising ring as the wisp is let go
The wisp's strain while pinned is its own hum (wisp_hum), bent by StompSfx.strain, not a file here.
"""
import numpy as np
import sfx_lib as S
from sfx_lib import N, T, env, mix, at, lpf, hpf, bpf, noise

S.reseed(6161)


def commit():
    scuff = bpf(noise(0.12), 300, 2400) * env(N(0.12), 0.01, 0.05)
    latch = S.kick(220, 140, 0.22, drop=0.02, decay=0.06, drive=1.5)
    knock = at(S.chime(330, 0.25, 0.07, partials=((1.0, 1.0), (2.0, 0.3))), 0.05)
    return mix(scuff * 0.6, latch, knock * 0.45)


def strike(i):
    thud = S.kick(150 + 12 * i, 52, 0.38, drop=0.025, decay=0.11, drive=2.4)
    crunch = S.grains(0.09, 260, 500, 3500, fall=0.05) * 0.5
    press = at(bpf(noise(0.06), 2500, 7000) * env(N(0.06), 0.001, 0.015), 0.004) * 0.35
    return mix(thud, crunch, press, S.tail(0.25, 600, 0.07) * 0.3)


def crush():
    slam = S.kick(110, 34, 0.7, drop=0.035, decay=0.2, drive=3.2)
    body = S.sub(70, 38, 0.6, 0.22) * 0.6
    crunch = at(S.grains(0.22, 420, 300, 4200, fall=0.1), 0.008) * 0.7
    squeeze = at(S.sweep(640, 110, 0.3) * env(N(0.3), 0.005, 0.07), 0.03) * 0.35
    return mix(slam, body, crunch, squeeze, S.tail(0.6, 450, 0.18) * 0.35)


def crack_free():
    snap = S.crack(0.05, 2500, 11000, 0.008) * 1.4
    glass = at(S.chime(1650, 0.5, 0.12), 0.01) * 0.5
    lift = at(S.sweep(900, 1900, 0.3) * env(N(0.3), 0.02, 0.1), 0.05) * 0.3
    return hpf(mix(snap, glass, lift), 200)


S.save_cat('stomp_commit', commit(), 'cast')
S.takes_cat('stomp_strike', strike, 3, 'heavy_impact')
S.save_cat('stomp_crush', crush(), 'heavy_impact')
S.save_cat('stomp_crack', crack_free(), 'impact')
print('stomp sounds written')
