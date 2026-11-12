"""Each Hunter's quiet foley layer for steps and dashes (docs/AUDIO.md, "Hunter foley").
Run from tools/: python3 gen_sfx_foley.py. Writes audio/<arch>_foley(.wav, _1..3.wav) for a footstep and
audio/<arch>_foley_dash(.wav, _1..2.wav) for a dash, one pair per Hunter, from its final design.

Synthesised in code (no outside sound), short and dry like the footsteps so a run never clutters a fight:
what the Hunter wears or carries, not what it stands on.
"""
import numpy as np
import sfx_lib as S
from sfx_lib import N, T, env, mix, at, lpf, hpf, bpf, noise, rattle, hiss, chime, pad
from sfx_combat import click, crack, ring, grains, kick

S.reseed(6140)


def flutter(d, lo, hi, rate, a=0.02, decay=0.2):
    """Band noise beaten by a fast wing-like pulse."""
    t = T(d)
    return bpf(noise(d), lo, hi) * (0.55 + 0.45 * np.sin(2 * np.pi * rate * t)) * env(N(d), a, decay)


def tick(f, d=0.05, dc=0.012):
    return ring((f, f * 2.3), d, (dc, dc * 0.6), (0.8, 0.3))


# Grimble: the hoard on his back, chests, tin, coins and a dull bell.
def dredge(dash, i):
    d = 0.45 if dash else 0.22
    return mix(rattle(d, 70 if dash else 45, 900, 4500, 0.5, d * 0.5) * 0.8,
               at(chime(520 + 40 * i, 0.3, 0.12), 0.02) * (0.5 if dash else 0.3),
               kick(95, 55, 0.12, 0.01, 0.03, 1.3) * 0.4)


# Albert: barnacle armour, plate on plate and shell crunch.
def bulwark(dash, i):
    d = 0.4 if dash else 0.26
    f = 190 + 12 * i
    return mix(ring((f, f * 2.9, f * 5.1), d, (0.1, 0.05, 0.03), (0.7, 0.4, 0.25)),
               grains(0.2, 90, 1500, 6000, 0.001, 0.004, fall=0.05) * 0.6,
               kick(110, 60, 0.15, 0.01, 0.04, 1.4) * 0.5)


# Neve: skate blades hissing on the ground.
def rimewright(dash, i):
    d = 0.5 if dash else 0.28
    t = T(d)
    slide = bpf(noise(d), 3000 + 300 * i, 9500) * env(N(d), 0.04, d * 0.45)
    edge = np.sin(2 * np.pi * np.cumsum(2400 + 1600 * t / d) / S.SR) * env(N(d), 0.03, d * 0.3)
    return mix(slide * 0.9, edge * 0.12, click(0.003, 3500, 9000) * 0.5)


# Kael: the chain at his collar and wrists.
def juggernaut(dash, i):
    d = 0.5 if dash else 0.3
    return mix(rattle(d, 55 if dash else 32, 700, 3200, 0.45, d * 0.55) * 0.9,
               ring((780 + 30 * i, 2100), 0.18, (0.05, 0.025), (0.5, 0.3)),
               kick(80, 50, 0.15, 0.012, 0.04, 1.4) * 0.35)


# Cinder: living-fire hair and obsidian seams, crackle and pops.
def ashwick(dash, i):
    d = 0.5 if dash else 0.3
    return mix(grains(d, 140 if dash else 80, 1200, 7000, 0.001, 0.005, fall=d * 0.5) * 0.9,
               bpf(noise(d), 200, 1100) * env(N(d), 0.04, d * 0.5) * (0.5 if dash else 0.25),
               crack(0.1, 1500, 6000, 0.012) * 0.5)


# Sable: moth wings (a flutter on dashes), a coat's cloth and a buckle on steps.
def thief(dash, i):
    if dash:
        return mix(flutter(0.5, 900, 4200, 26 + 2 * i, 0.03, 0.2) * 0.9, hiss(0.3, 3000, 8000, 0.03, 0.12) * 0.25)
    return mix(bpf(noise(0.18), 500, 3000) * env(N(0.18), 0.02, 0.06) * 0.7,
               at(tick(2600 + 150 * i, 0.04), 0.03) * 0.3)


# Lace: porcelain joints clicking, a wooden cross knocking on her back.
def archer(dash, i):
    d = 0.4 if dash else 0.22
    return mix(tick(1700 + 90 * i) * 0.8, at(tick(2300), 0.045) * 0.6,
               at(ring((310 + 15 * i, 760), 0.15, (0.04, 0.02), (0.6, 0.3)), 0.02) * (0.9 if dash else 0.5),
               hiss(d, 4000, 9000, 0.02, 0.1) * (0.35 if dash else 0.0))


# Tenzo: pebbles and the floating eye stones, a soft jade ring.
def dolm(dash, i):
    d = 0.45 if dash else 0.25
    return mix(grains(0.2, 60, 700, 3500, 0.002, 0.006, fall=0.06) * 0.7,
               kick(130, 70, 0.14, 0.01, 0.04, 1.3) * 0.5,
               at(chime(430 + 30 * i, d, 0.18, ((1.0, 1.0), (2.0, 0.4), (3.0, 0.2))), 0.03) * (0.5 if dash else 0.3))


# Vex: brass ammo strap and the coin chain on her hip.
def gunslinger(dash, i):
    d = 0.4 if dash else 0.24
    return mix(rattle(d, 60 if dash else 38, 2500, 7500, 0.5, d * 0.5) * 0.8,
               at(chime(1180 + 60 * i, 0.18, 0.06), 0.015) * 0.4,
               click(0.003, 1500, 6000) * 0.5)


# Sparkle: copper coils at the wrists, a spit of static and a thin ring.
def mage(dash, i):
    d = 0.45 if dash else 0.25
    return mix(grains(d, 110 if dash else 60, 2500, 9000, 0.0008, 0.003, fall=d * 0.4) * 0.8,
               ring((1450 + 80 * i, 3300), d, (0.1, 0.05), (0.35, 0.2)) * (1.0 if dash else 0.6),
               hiss(d, 5000, 10000, 0.01, 0.08) * 0.2)


# Motley: tiny jester bells and a flick of cards.
def ostra(dash, i):
    d = 0.5 if dash else 0.28
    return mix(chime(1350 + 70 * i, d, 0.1) * 0.6, at(chime(1810, 0.25, 0.08), 0.045) * 0.4,
               bpf(noise(0.12), 2500, 8000) * env(N(0.12), 0.002, 0.03) * (0.8 if dash else 0.4))


# Meeko: the glass globe with its tiny sun and raincloud, a tink and a drip.
def tender(dash, i):
    d = 0.45 if dash else 0.22
    tink = at(chime(1900 + 100 * i, 0.22, 0.07), 0.01)
    drip = at(np.sin(2 * np.pi * np.cumsum(900 + 1400 * T(0.06) / 0.06) / S.SR) * env(N(0.06), 0.002, 0.02), 0.05)
    return mix(tink * 0.5, drip * 0.35, bpf(noise(d), 1500, 6000) * env(N(d), 0.01, d * 0.3) * (0.4 if dash else 0.15))


# Gil: potion vials clinking in his bag, a wet slap of robe hem (he was a fish).
def gil(dash, i):
    d = 0.45 if dash else 0.24
    vial = at(chime(1500 + 110 * i, 0.2, 0.07, ((1.0, 1.0), (2.4, 0.3))), 0.015) * (0.6 if dash else 0.4)
    slosh = bpf(noise(d), 400, 2200) * env(N(d), 0.02, d * 0.4) * (0.7 if dash else 0.45)
    return mix(vial, slosh, at(tick(2200 + 120 * i, 0.04), 0.045) * 0.35)


HUNTERS = {'dredge': dredge, 'bulwark': bulwark, 'rimewright': rimewright, 'juggernaut': juggernaut, 'ashwick': ashwick,
           'thief': thief, 'archer': archer, 'dolm': dolm, 'gunslinger': gunslinger, 'mage': mage, 'ostra': ostra,
           'tender': tender, 'gil': gil}

if __name__ == '__main__':
    for arch, fn in HUNTERS.items():
        S.takes_cat('%s_foley' % arch, lambda i, fn=fn: fn(False, i), 3, 'step')
        S.takes_cat('%s_foley_dash' % arch, lambda i, fn=fn: fn(True, i), 2, 'dash')
    print('hunter foley sfx written')
