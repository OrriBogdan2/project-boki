"""The three lair bosses' sounds (Data.BOSSES): a wake roar, a phase sting and a defeat sting each, and one
wind-up and one strike cue per attack, a stagger groan and a fall.

    cd tools && python3 gen_sfx_boss.py      (then: godot --headless --import)

boss_<kind>_wake    the roar when it leaves dormant; carries to the lair band (content/sfx/boss.json "reach")
boss_<kind>_phase   a short sting at each phase change and at the enrage
boss_<kind>_defeat  the squad that cleared the lair hears it: a fall, then a low tail
boss_<kind>_<attack>_wind  a swell that peaks as it ends: BossSfx pitches it so the end is the clip's wind-up key
boss_<kind>_<attack>_hit   the blow, on the strike frame (boulders and lob also have _land: where the shot comes down)
boss_<kind>_stagger        the groan when a stagger opens
boss_<kind>_fall           the body hitting the ground, heard by everyone nearby (the defeat sting is the squad's)
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


# ------------------------------------------------------------------ attacks
def save_hit(name, x):
    S.save_cat(name, S.reflections(x, ((0.05, 0.3, 1400), (0.11, 0.2, 1000), (0.2, 0.12, 700))), 'heavy_impact')


def swell(x, a=0.88, rel=0.1):
    """Shapes x to build to its end (the wind-up key) and let go: wind-ups are heard coming."""
    d = len(x) / S.SR
    return x * S.shape(d, d * a, 0.0, d * rel)


def wind(d, *layers):
    return swell(mix(*[S.pad(x, d)[:N(d)] for x in layers]))


def breath(d, f0, f1, vowel, rasp=0.8, scale=0.8):
    return S.voice(d, f0, f1, vowel, breath=0.15, rasp=rasp, scale=scale, a=d * 0.5, decay=d)


def burst(d, lo, hi, decay):
    return bpf(noise(d), lo, hi) * env(N(d), 0.004, decay)


def whoosh(d, lo, hi):
    return bpf(noise(d), lo, hi) * shape(d, d * 0.3, 0.0, d * 0.6)


def wet(d, rate=11):
    return bpf(noise(d), 200, 1300) * (0.5 + 0.5 * np.sin(2 * np.pi * rate * T(d)))


def colossus_moves():
    save('boss_colossus_slam_wind', wind(1.1, rumble(1.1, 260, 9, 0.9), breath(1.0, 50, 78, 'oh'), bpf(noise(1.1), 90, 700) * 0.6,
                                       S.creak(1.1, 70, 110, 0.7, 900) * 0.5))
    save_hit('boss_colossus_slam_hit', mix(kick(75, 26, 1.0, 0.1, 0.35, 3.0), crack(0.3, 300, 4000, 0.05) * 0.9,
                                           at(grains(1.2, 90, 80, 700, 0.004, 0.02, fall=0.35), 0.04) * 0.7,
                                           at(low_tail(1.3, 32, 0.5), 0.05) * 0.7))
    save('boss_colossus_boulders_wind', wind(0.85, rumble(0.85, 400, 6, 0.8), grains(0.85, 70, 200, 1800, 0.004, 0.015) * 0.7,
                                           breath(0.8, 60, 90, 'uh')))
    save_hit('boss_colossus_boulders_hit', mix(whoosh(0.5, 120, 1500) * 0.8, kick(90, 40, 0.4, 0.05, 0.15, 2.5) * 0.9,
                                               breath(0.4, 90, 55, 'oh') * 0.6))
    save_hit('boss_colossus_boulders_land', mix(kick(80, 30, 0.9, 0.08, 0.3, 3.0), at(grains(0.9, 80, 100, 1800, 0.004, 0.02, fall=0.25), 0.02) * 0.8,
                                                crack(0.15, 400, 3000, 0.03) * 0.8))
    save('boss_colossus_fissure_wind', wind(1.0, S.creak(1.0, 55, 120, 0.8, 1200), rumble(1.0, 200, 6, 0.9),
                                          S.sweep(32, 70, 1.0, 'sin', 1.5) * 0.6))
    save_hit('boss_colossus_fissure_hit', mix(crack(0.9, 200, 5000, 0.4, 0.002), rumble(1.1, 220, 0.5, 0.02) * 1.1,
                                              kick(70, 28, 0.8, 0.08, 0.3, 3.0), grains(1.0, 120, 100, 2500, 0.003, 0.015, fall=0.4) * 0.6))
    save_hit('boss_colossus_stagger', mix(breath(1.2, 80, 34, 'oh', 1.0, 0.85) * 1.1, grains(1.1, 60, 150, 2200, 0.004, 0.02, fall=0.4) * 0.6,
                                          rumble(1.2, 220, 0.5, 0.05) * 0.8, kick(70, 34, 0.5, 0.06, 0.2) * 0.8))
    save_hit('boss_colossus_fall', mix(kick(70, 24, 1.6, 0.12, 0.5, 3.0), at(low_tail(2.0, 30, 0.9), 0.05),
                                       at(grains(1.5, 100, 60, 1800, 0.004, 0.025, fall=0.5), 0.05) * 0.8, crack(0.25, 300, 3500, 0.06) * 0.7))


def serpent_moves():
    save('boss_serpent_dash_wind', wind(0.95, S.sweep(180, 1100, 0.95, 'saw', 1.6) * 0.3, S.fm(220, 1.5, 5.0, 0.95, 0.9, 0.3) * 0.4,
                                      hiss_n(0.95, 2500, 8000) * 0.8, S.rattle(0.95, 60, 3000, 8000, decay=0.8) * 0.4))
    save_hit('boss_serpent_dash_hit', mix(whoosh(0.5, 800, 9000) * 1.2, crack(0.12, 2500, 9000, 0.03), kick(110, 45, 0.4, 0.04, 0.14, 2.5) * 0.8,
                                          S.fm(700, 2.3, 5.0, 0.3, 0.1, 0.002) * 0.5))
    save('boss_serpent_storm_wind', wind(1.1, S.sweep(120, 1600, 1.1, 'saw', 2.0) * 0.3, S.fm(300, 1.4, 6.0, 1.1, 1.0, 0.4) * 0.35,
                                       grains(1.1, 90, 3000, 9000, 0.001, 0.004) * 0.7, rumble(1.1, 240, 9, 0.9) * 0.5))
    save_hit('boss_serpent_storm_hit', mix(crack(0.5, 1500, 10000, 0.12), S.fm(500, 2.7, 7.0, 0.35, 0.12, 0.001) * 0.7,
                                           kick(100, 38, 0.6, 0.05, 0.2, 3.0), at(rumble(0.8, 300, 0.3, 0.01), 0.04) * 0.7))
    save('boss_serpent_static_wind', wind(1.5, S.sweep(90, 2200, 1.5, 'sin', 2.2) * 0.5, S.fm(160, 1.5, 7.0, 1.5, 1.4, 0.5) * 0.4,
                                        hiss_n(1.5, 3000, 9500) * 0.7, grains(1.5, 120, 3500, 9000, 0.001, 0.004) * 0.6))
    save_hit('boss_serpent_static_hit', mix(crack(0.9, 1200, 10000, 0.25), kick(85, 30, 1.0, 0.08, 0.35, 3.0),
                                            S.fm(400, 2.3, 8.0, 0.8, 0.2, 0.001) * 0.7, at(S.rattle(0.8, 50, 2500, 8000, decay=0.4), 0.05) * 0.5))
    save_hit('boss_serpent_stagger', mix(S.sweep(1200, 140, 1.1, 'saw', 1.2) * env(N(1.1), 0.01, 0.5) * 0.4, S.fm(380, 2.3, 6.0, 1.0, 0.4) * 0.6,
                                         S.rattle(1.0, 55, 2000, 7000, decay=0.5) * 0.5, hiss_n(1.0, 2000, 7000) * 0.6))
    save_hit('boss_serpent_fall', mix(kick(95, 34, 1.2, 0.09, 0.4, 3.0), S.sweep(900, 80, 1.2, 'saw', 1.5) * env(N(1.2), 0.01, 0.4) * 0.35,
                                      at(S.rattle(1.0, 40, 1800, 6000, decay=0.5), 0.1) * 0.5, at(low_tail(1.8, 40, 0.7), 0.05)))


def hiss_n(d, lo, hi):
    return S.hiss(d, lo, hi, d * 0.6, d)


def brood_moves():
    save('boss_brood_spit_wind', wind(0.85, wet(0.85, 9), breath(0.85, 110, 220, 'eh', 0.9, 0.9), grains(0.85, 80, 1500, 6000, 0.003, 0.01) * 0.5))
    save_hit('boss_brood_spit_hit', mix(burst(0.4, 400, 3500, 0.07), kick(120, 55, 0.3, 0.04, 0.1, 2.0) * 0.6,
                                        at(burst(0.3, 1000, 6000, 0.05), 0.02) * 0.6, S.voice(0.25, 260, 150, 'eh', rasp=0.9, a=0.01, decay=0.12) * 0.7))
    save('boss_brood_lob_wind', wind(0.7, wet(0.7, 7), S.sweep(120, 380, 0.7, 'sin', 1.5) * 0.5, breath(0.7, 90, 160, 'uh', 0.8, 0.9)))
    save_hit('boss_brood_lob_hit', mix(S.sweep(160, 520, 0.2, 'sin') * env(N(0.2), 0.002, 0.08), whoosh(0.4, 300, 3000) * 0.9,
                                       kick(110, 50, 0.3, 0.04, 0.1) * 0.7))
    save_hit('boss_brood_lob_land', mix(burst(0.5, 200, 2500, 0.1), kick(90, 38, 0.5, 0.05, 0.16) * 0.9, at(hiss_n(0.5, 2500, 7000), 0.03) * 0.5,
                                        at(grains(0.4, 60, 300, 2500, 0.003, 0.01, fall=0.12), 0.03) * 0.6))
    save('boss_brood_brood_wind', wind(0.6, grains(0.6, 110, 1500, 6500, 0.003, 0.01), S.voice(0.6, 380, 800, 'ee', 0.3, 0.8, a=0.3, decay=0.6) * 0.8,
                                     wet(0.6, 14) * 0.5))
    save_hit('boss_brood_brood_hit', mix(burst(0.35, 300, 3000, 0.06), kick(100, 45, 0.4, 0.05, 0.14) * 0.8,
                                         at(grains(0.7, 140, 1200, 6500, 0.003, 0.01, fall=0.25), 0.03), S.voice(0.4, 500, 900, 'ee', 0.3, 0.8, a=0.01, decay=0.2) * 0.6))
    save('boss_brood_burrow_wind', wind(2.0, rumble(2.0, 300, 20, 0.9), grains(2.0, 70, 150, 1800, 0.006, 0.03, fall=1.8) * 0.8,
                                      S.rattle(2.0, 30, 600, 3000, decay=1.5) * 0.4, breath(1.6, 70, 45, 'uh')))
    save_hit('boss_brood_burrow_hit', mix(kick(85, 30, 0.9, 0.08, 0.3, 3.0), at(grains(0.9, 140, 100, 2200, 0.004, 0.02, fall=0.3), 0.02) * 0.9,
                                          crack(0.2, 400, 3500, 0.05) * 0.8, S.voice(0.6, 320, 640, 'ee', 0.3, 0.9, a=0.05, decay=0.3) * 0.7))
    save_hit('boss_brood_stagger', mix(S.voice(1.0, 700, 260, 'ee', 0.3, 0.9, a=0.03, decay=0.5), wet(1.0, 8) * env(N(1.0), 0.05, 0.4) * 0.6,
                                       grains(0.9, 70, 1200, 5500, 0.003, 0.01, fall=0.3) * 0.5, kick(90, 42, 0.4, 0.05, 0.14) * 0.6))
    save_hit('boss_brood_fall', mix(kick(80, 30, 1.2, 0.09, 0.4, 3.0), burst(0.7, 200, 2000, 0.2) * 0.8,
                                    at(grains(1.4, 90, 1000, 6000, 0.003, 0.012, fall=0.6), 0.05) * 0.6, at(low_tail(1.8, 36, 0.8), 0.05) * 0.8))


if __name__ == '__main__':
    for kind in ('colossus', 'serpent', 'brood'):
        for event in ('wake', 'phase', 'defeat'):
            save('boss_%s_%s' % (kind, event), globals()['%s_%s' % (kind, event)]())
    colossus_moves()
    serpent_moves()
    brood_moves()
