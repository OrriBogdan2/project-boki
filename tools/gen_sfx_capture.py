"""Capture sounds (docs/AUDIO.md): what a scan ends with, besides the common scan_pop in gen_sfx.py. Run from tools/.

  scan_pop_fine  an uncommon catch (a mutated Boki): the pop plus a third bright note
  scan_pop_rare  a rare catch (shimmer or a rare species): a rising four-note bell run with a sparkle tail
  scan_fail      the scan breaking off: a dry snap and a short falling tone
  scan_call      the Boki's own short call as it is taken: a chirp that scoops up and a soft vowel under it
  rarity_rare / rarity_very_rare   the stings for a rare Boki coming into sight, being claimed or hatching
                 (RaritySting): two soft bell notes rising a fifth; three rising and a glassy sparkle
"""
import numpy as np
import sfx_lib as S
from sfx_lib import N, T, env, mix, at, lpf, bpf, noise

S.reseed(7117)


def bell(f, d, decay):
    return S.chime(f, d, decay, partials=((1.0, 1.0), (2.0, 0.35), (3.0, 0.12)))


def rise():
    return S.sweep(500, 1500, 0.3) * env(N(0.3), 0.25, 0.1) * 0.35


def pop_fine():
    return mix(rise(), at(bell(988, 0.5, 0.14), 0.28), at(bell(1318, 0.6, 0.2), 0.34) * 0.8, at(bell(1760, 0.7, 0.25), 0.42) * 0.7)


def pop_rare():
    notes = [(784, 0.0), (988, 0.09), (1318, 0.18), (1760, 0.27)]
    run = [at(bell(f, 0.9, 0.3), t + 0.25) for f, t in notes]
    sparkle = at(bpf(noise(0.5), 4000, 9000) * env(N(0.5), 0.01, 0.18), 0.5) * 0.25
    return mix(rise(), *run, sparkle)


def snap():
    click = bpf(noise(0.04), 1200, 6000) * env(N(0.04), 0.0005, 0.008)
    drop = S.sweep(420, 150, 0.22) * env(N(0.22), 0.002, 0.07)
    return mix(click * 1.2, drop * 0.7)


def call(i):
    d = 0.32
    n = N(d); u = np.arange(n) / n
    f = (1050 + 90 * i) * (1 + 0.16 * (1 - np.exp(-u * 9))) * (1 + 0.02 * np.sin(2 * np.pi * 9 * T(d)))
    ph = 2 * np.pi * np.cumsum(f) / S.SR
    chirp = (np.sin(ph) + 0.18 * np.sin(2 * ph)) * env(n, 0.006, d * 0.4)
    vowel = S.voice(d, 520, 640, 'eh', breath=0.1, vib=0.02, scale=1.35, a=0.01, decay=d * 0.5)
    return mix(chirp, 0.5 * vowel[:n])


def sting_rare():
    return mix(bell(659, 0.7, 0.3), at(bell(988, 0.9, 0.4), 0.16) * 0.9)


def sting_very_rare():
    notes = [(659, 0.0), (988, 0.12), (1318, 0.24)]
    glass = at(bpf(noise(0.6), 5000, 10000) * env(N(0.6), 0.02, 0.22), 0.3) * 0.18
    return mix(*[at(bell(f, 1.0, 0.45), t) for f, t in notes], glass)


S.save_cat('scan_pop_fine', lpf(pop_fine(), 5000), 'boki')
S.save_cat('scan_pop_rare', lpf(pop_rare(), 7000), 'boki')
S.save_cat('scan_fail', snap(), 'cast')
S.takes_cat('scan_call', call, 3, 'boki')
S.save_cat('rarity_rare', lpf(sting_rare(), 5000), 'boki')
S.save_cat('rarity_very_rare', lpf(sting_very_rare(), 7000), 'boki')
print('capture sounds written')
