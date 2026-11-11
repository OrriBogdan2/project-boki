"""The three lair bosses' sounds (Data.BOSSES): a wake roar, a phase sting and a defeat sting each.

    cd tools && python3 gen_sfx_boss.py      (then: godot --headless --import)

boss_<kind>_wake    the roar when it leaves dormant; carries to the lair band (content/sfx/boss.json "reach")
boss_<kind>_phase   a short sting at each phase change and at the enrage
boss_<kind>_defeat  the squad that cleared the lair hears it: a fall, then a low tail
colossus is stone (a deep voice, grinding rock, rubble), serpent is charge (hiss, rattle, discharge),
brood is wet and many (chitter, shriek, gurgle). Levelled to the cast category so they sit under the
ultimates and the lair callouts. Original synthesis, no samples.
"""
import os, sys
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import sfx_lib as S
from sfx_lib import N, T, noise, lpf, hpf, bpf, env, mix, at, kick, crack, sub, grains, shape, sat

S.reseed(6150)


def save(name, x):
    S.save_cat(name, S.reflections(x, ((0.06, 0.25, 1400), (0.13, 0.17, 1000), (0.24, 0.1, 700))), 'cast')


def rumble(d, lp, decay, a=0.05):
    """Low noise that swells and dies: rock moving."""
    return lpf(noise(d), lp) * env(N(d), a, decay)


def low_tail(d, f, decay):
    """The defeat's tail: a sub tone and a dark hush that outlast the sting."""
    return sub(f * 1.1, f, d, decay, 0.04) * 0.8 + rumble(d, 160, decay, 0.1) * 0.9


# ------------------------------------------------------------------ colossus: stone
def colossus_wake():
    d = 2.2
    roar = S.voice(1.6, 52, 34, 'oh', breath=0.1, rasp=0.9, scale=0.8, a=0.25, decay=1.0)
    grind = bpf(noise(d), 90, 600) * (0.6 + 0.4 * np.sin(2 * np.pi * 7 * T(d))) * env(N(d), 0.3, 0.9)
    thud = kick(80, 36, 1.0, 0.08, 0.3, 2.5)
    return mix(roar * 1.2, grind * 0.8, at(thud, 0.0) * 0.9, at(grains(1.2, 60, 600, 2800, fall=0.4), 0.3) * 0.5)


def colossus_phase():
    return mix(kick(110, 40, 0.8, 0.05, 0.22, 2.5), crack(0.25, 500, 3500, 0.06), at(grains(0.9, 70, 500, 3000, fall=0.25), 0.05) * 0.6,
               S.voice(0.7, 60, 40, 'oh', breath=0.1, rasp=0.8, scale=0.8, a=0.05, decay=0.3) * 0.7)


def colossus_defeat():
    fall = mix(kick(90, 30, 1.2, 0.1, 0.4, 2.0), at(grains(1.6, 50, 400, 2600, fall=0.6), 0.15) * 0.6, at(crack(0.2, 600, 3000, 0.05), 0.5) * 0.5,
               S.voice(1.4, 46, 28, 'oh', breath=0.1, rasp=0.7, scale=0.8, a=0.1, decay=0.6) * 0.7)
    return mix(fall, at(low_tail(2.6, 34, 1.1), 0.6))


# ------------------------------------------------------------------ serpent: charge
def serpent_wake():
    d = 2.0
    hiss = bpf(noise(d), 2200, 7500) * shape(d, 0.5, 0.5, 0.9)
    shriek = S.voice(1.2, 300, 620, 'ee', breath=0.3, rasp=0.6, scale=1.0, a=0.2, decay=0.7)
    buzz = S.fm(180, 1.5, 4.0, d, 0.9, 0.1) * 0.35
    return mix(hiss * 0.9, at(shriek, 0.3) * 0.8, buzz, S.rattle(1.2, 45, 3000, 8000, decay=0.5) * 0.4, kick(90, 45, 0.6, 0.05, 0.18) * 0.6)


def serpent_phase():
    zap = S.fm(900, 2.3, 6.0, 0.4, 0.12, 0.002)
    return mix(zap, crack(0.3, 2000, 9000, 0.05), at(S.rattle(0.5, 60, 2500, 7000, decay=0.2), 0.05) * 0.5, kick(100, 50, 0.5, 0.04, 0.12) * 0.5)


def serpent_defeat():
    d = 1.6
    fall = mix(S.sweep(1400, 90, d, 'saw', 1.6) * env(N(d), 0.01, 0.5) * 0.4, bpf(noise(d), 1500, 6000) * env(N(d), 0.01, 0.4),
               S.fm(500, 2.3, 5.0, 0.5, 0.15) * 0.6, at(S.rattle(0.9, 30, 2000, 6000, decay=0.4), 0.2) * 0.4)
    return mix(fall, at(low_tail(2.4, 42, 1.0), 0.5))


# ------------------------------------------------------------------ brood: wet and many
def brood_wake():
    d = 2.1
    chitter = grains(d, 140, 1500, 6500, 0.003, 0.012) * shape(d, 0.4, 0.8, 0.8)
    growl = S.voice(1.5, 120, 70, 'eh', breath=0.2, rasp=1.0, scale=0.9, a=0.2, decay=0.8)
    squelch = bpf(noise(d), 200, 1200) * (0.5 + 0.5 * np.sin(2 * np.pi * 11 * T(d))) * env(N(d), 0.2, 0.7)
    return mix(chitter * 0.9, growl * 1.1, squelch * 0.5, kick(90, 42, 0.8, 0.06, 0.25) * 0.7)


def brood_phase():
    shriek = S.voice(0.6, 420, 780, 'ee', breath=0.3, rasp=0.8, scale=1.0, a=0.02, decay=0.25)
    return mix(shriek * 0.8, grains(0.6, 160, 1800, 7000, 0.003, 0.01, fall=0.2), kick(100, 45, 0.5, 0.04, 0.12) * 0.6,
               bpf(noise(0.4), 300, 1500) * env(N(0.4), 0.01, 0.12) * 0.5)


def brood_defeat():
    d = 1.6
    fall = mix(S.voice(d, 160, 60, 'eh', breath=0.2, rasp=0.9, scale=0.9, a=0.05, decay=0.6) * 0.9,
               grains(1.3, 90, 1500, 6000, 0.003, 0.012, fall=0.5) * 0.7,
               bpf(noise(d), 200, 1000) * (0.5 + 0.5 * np.sin(2 * np.pi * 9 * T(d))) * env(N(d), 0.1, 0.5) * 0.5,
               kick(80, 36, 0.9, 0.08, 0.3) * 0.7)
    return mix(fall, at(low_tail(2.4, 38, 1.0), 0.5))


if __name__ == '__main__':
    for kind in ('colossus', 'serpent', 'brood'):
        for event in ('wake', 'phase', 'defeat'):
            save('boss_%s_%s' % (kind, event), globals()['%s_%s' % (kind, event)]())
