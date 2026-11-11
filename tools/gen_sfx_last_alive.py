"""The last-one-up sounds (scripts/match/last_alive.gd, content/sfx/last_alive.json). Run from tools/.

Heard by the last one up only, never by anyone else (it is your state). Our own synthesis:
  last_alive_start  sting  the moment you are the last one up: a low swell rising a fifth under two bells
  last_alive_bed    loop   while it lasts: a slow, soft low heartbeat over a dark drone, played on the Music
                           bus so the score's combat ducking (the SFX-keyed sidechain) pulls it under a fight
  last_alive_end    sting  a teammate is back up: a warm falling exhale that settles on a major third
"""
import numpy as np
import sfx_lib as S
from sfx_lib import T, mix, at, lpf, bpf

S.reseed(1111)

BED_S = 2.0      # s, one loop: two beats (60 bpm, slower than the Heart carrier's heart_beat)


def thump(f0, d=0.32, decay=0.09):
    return S.kick(f0 * 1.7, f0, d, drop=0.04, decay=decay, drive=1.4)


def start():
    d = 0.9
    swell = sum(S.sweep(f, f * 1.5, d, curve=0.7) * S.shape(d, 0.55, 0.05, 0.3) for f in (110.0, 165.0)) * 0.45
    air = bpf(S.noise(d), 600, 3000) * S.shape(d, 0.6, 0.0, 0.3) * 0.2
    bells = mix(at(S.chime(659.0, 0.8, 0.3), 0.42), at(S.chime(988.0, 0.9, 0.4), 0.58))
    return mix(swell, air, bells * 0.6)


def bed():
    t = T(BED_S)                          # whole cycles of 55 Hz and 0.5 Hz in 2 s, so the drone loops cleanly
    drone = (np.sin(2 * np.pi * 55.0 * t) + 0.4 * np.sin(2 * np.pi * 82.5 * t)) * (0.8 + 0.2 * np.cos(np.pi * t))
    beat = mix(thump(46.0), at(thump(56.0) * 0.6, 0.2))
    beats = mix(beat, at(beat, BED_S / 2))
    wash = lpf(S.noise(BED_S), 120) * 0.3
    return S.pad(beats, BED_S)[:len(t)] + drone * 0.35 + wash


def end():
    d = 1.3
    exhale = bpf(S.noise(d), 300, 2200) * S.shape(d, 0.15, 0.1, 1.0) * 0.35
    fall = S.sweep(330.0, 262.0, d, curve=0.6) * S.shape(d, 0.05, 0.2, 1.0) * 0.4
    bells = mix(at(S.chime(523.0, 1.0, 0.45), 0.08), at(S.chime(659.0, 1.1, 0.5), 0.26))
    return mix(exhale, fall, bells * 0.7)


def main():
    S.save_cat('last_alive_start', start(), 'cast')
    S.save_loop('last_alive_bed', bed(), 'loop')
    S.save_cat('last_alive_end', end(), 'cast')


if __name__ == '__main__':
    main()
