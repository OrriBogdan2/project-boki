"""Resource-full tells (docs/AUDIO.md, content/sfx/res_tells.json): the short sting ArchKit._tells plays when a
Hunter's meter comes full, heard by foes within about 25 m.

    python3 tools/gen_sfx_res_tells.py      (then: godot --headless --import)

One sound per Hunter whose meter can fill (<arch>_tell), voiced to what fills it: Cinder's Char flares, Albert's
Guard rings, Vex's Fever spins up. Each is a quick rise into a bright accent and a short tail, under half a
second, so it reads as "ready" without masking the fight. Hawk Sense has no meter, so Lace has none. Original
synthesis, no samples. Its own seed: running it re-rolls nothing else.
"""
import os, sys
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import sfx_lib as S
from sfx_lib import N, noise, lpf, hpf, bpf, mix, at, kick, click, crack, tail, ring

S.reseed(7417)


def swell(f0, f1, d=0.18, curve=1.5):
    """A tone gliding into the accent, fading in as it goes."""
    return S.sweep(f0, f1, d, curve=curve) * (np.arange(N(d)) / N(d)) ** 1.5


def gust(lo, hi, d=0.18):
    """Noise through a band, swelling in: breath, fire, water."""
    return bpf(noise(d), lo, hi) * (np.arange(N(d)) / N(d)) ** 2


def tell_ashwick():     # Char: a flare catching, embers crackling
    flare = mix(gust(400, 2500) * 0.9, at(S.hiss(0.3, 1500, 7000, 0.01, 0.12) * 0.7, 0.16))
    embers = S.rattle(0.25, 45, 2500, 8000, 0.6, 0.08) * 0.5
    return mix(flare, at(embers, 0.17), at(kick(110, 60, 0.2, 0.02, 0.05) * 0.5, 0.16))

def tell_bulwark():     # Guard: the shield struck once, ringing warm
    clang = ring([520, 1310, 2070], 0.45, [0.25, 0.12, 0.07], [0.6, 0.3, 0.15])
    return mix(swell(160, 260) * 0.4, at(clang, 0.17), at(kick(150, 70, 0.25, 0.015, 0.05) * 0.6, 0.17))

def tell_dolm():        # Rocks: two stones knocked together over a low rumble
    knock = mix(click(0.004, 800, 3000) * 0.9, crack(0.06, 300, 1800, 0.02) * 0.8,
                kick(180, 90, 0.12, 0.01, 0.03) * 0.5)
    return mix(lpf(noise(0.4), 160) * np.linspace(0.8, 0.0, N(0.4)) * 0.6, at(knock, 0.1), at(knock * 1.1, 0.19))

def tell_dredge():      # Salvage: coins settling on the hoard
    coins = mix(*[at(ring([3100 + 400 * i, 4700 + 300 * i], 0.18, [0.05, 0.03], [0.4, 0.25]), 0.13 + 0.035 * i)
                  for i in range(4)])
    return mix(swell(300, 520) * 0.3, coins, at(click(0.003, 2000, 7000) * 0.6, 0.13))

def tell_gil():         # Splash Marks: a drop falling into still water
    drop = S.sweep(700, 1600, 0.08, curve=0.6) * np.exp(-np.arange(N(0.08)) / N(0.03))
    return mix(gust(300, 1200, 0.2) * 0.4, at(drop * 0.8, 0.17), at(tail(0.25, 2500, 0.08) * 0.3, 0.18))

def tell_gunslinger():  # Fever: the barrel spinning up to a brass ping
    barrel = S.rattle(0.2, 60, 1500, 5000, 0.4) * np.linspace(0.1, 0.6, N(0.2))
    return mix(swell(400, 1400, 0.2, 2.0) * 0.45, barrel, at(ring([2400, 3700], 0.3, [0.1, 0.06], [0.5, 0.3]), 0.2))

def tell_juggernaut():  # Rage: a growl swelling under a drawn blade
    growl = lpf(S.sweep(70, 110, 0.32, 'saw'), 600) * np.sin(np.linspace(0, np.pi, N(0.32))) * 0.7
    blade = S.hiss(0.25, 3000, 8000, 0.03, 0.1) * 0.5
    return mix(growl, at(blade, 0.12), at(kick(120, 55, 0.22, 0.02, 0.06) * 0.6, 0.2))

def tell_mage():        # Static: a charge crackling up to a bright zap
    zap = S.fm(1300, 1.5, 5.0, 0.18, 0.06) * 0.6
    return mix(swell(500, 1800, 0.18, 2.5) * 0.35, S.rattle(0.18, 90, 3000, 9000, 0.6) * 0.4, at(zap, 0.17))

def tell_ostra():       # Swell: a wave drawing in, a bubble at the crest
    bubble = S.sweep(500, 1100, 0.06, curve=0.7) * np.exp(-np.arange(N(0.06)) / N(0.02))
    crest = mix(bubble * 0.7, tail(0.2, 1500, 0.07) * 0.4)
    return mix(gust(150, 900, 0.24) * 0.8, swell(120, 200, 0.24) * 0.4, at(crest, 0.22))

def tell_rimewright():  # Chill: frost forming, a glass chime
    frost = S.rattle(0.18, 50, 4000, 9000, 0.5) * np.linspace(0.1, 0.5, N(0.18))
    return mix(frost, at(S.chime(1760, 0.4, 0.18) * 0.7, 0.17))

def tell_tender():      # Kindle: a soft warm bloom, two notes up
    return mix(swell(260, 330, 0.16) * 0.5, at(S.chime(660, 0.35, 0.2, ((1.0, 1.0), (2.0, 0.3))) * 0.5, 0.12),
               at(S.chime(990, 0.35, 0.2, ((1.0, 1.0), (2.0, 0.3))) * 0.5, 0.2))

def tell_thief():       # Marks: a blade drawn, a silver shimmer
    shimmer = ring([2900, 4400, 6100], 0.3, [0.12, 0.08, 0.05], [0.5, 0.3, 0.2])
    return mix(S.hiss(0.18, 4000, 10000, 0.12, 0.05) * 0.6, at(shimmer, 0.14))


def build():
    for arch, fn in sorted((k[5:], v) for k, v in globals().items() if k.startswith('tell_')):
        S.save_cat(arch + '_tell', hpf(fn(), 40), 'cast')


if __name__ == '__main__':
    build()
