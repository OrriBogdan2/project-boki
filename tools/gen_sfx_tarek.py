"""Tarek, the Cliff Runner (dolm): his sound set (docs/AUDIO.md, content/sfx/dolm.json).

    python3 tools/gen_sfx_tarek.py      (then: godot --headless --import)

Stone through and through: boulders heaved and smashed, rocks torn up out of the ground with a crunch (his
signature), gravel spraying, quakes rolling under a slam, a glow of molten rock in the cracks. His Tremor
Sense is a deep pulse with his seeing-stones knocking softly. A wiry man's wordless grunts with a little
grit in them; sure, light feet with grit under them. Original synthesis, no samples.
"""
import os, sys
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import sfx_lib as S
from sfx_lib import (N, T, noise, lpf, hpf, bpf, env, mix, at, kick, click, crack, sub, tail, reflections, ring,
                     grains, pad)

S.reseed(4403)


# ------------------------------------------------------------------ helpers
def swish(d, f0, f1, q=3.0):
    """Air moved by something fast: noise through a band-pass whose centre sweeps f0 -> f1."""
    n = N(d); u = np.arange(n) / n
    f = f0 * (f1 / f0) ** u
    x = noise(d); out = np.empty(n); low = band = 0.0; damp = 1.0 / q
    g = 2.0 * np.sin(np.pi * np.minimum(f, S.SR / 6.5) / S.SR)
    for k in range(n):
        low += g[k] * band
        band += g[k] * (x[k] - low - damp * band)
        out[k] = band
    return out * np.sin(np.pi * np.clip(u * 1.1, 0, 1)) ** 1.5


def fade_out(x, d=0.03):
    k = min(len(x), N(d)); x = x.copy(); x[-k:] *= np.linspace(1.0, 0.0, k)
    return x


def polish(x):
    """Every sound's last pass: nothing harsh above 10 kHz and a 2.5 ms fade-in, so no take starts on a click."""
    x = lpf(x, 10000)
    k = N(0.0025); x[:k] *= 0.5 - 0.5 * np.cos(np.pi * np.arange(k) / k)
    return x


def save(name, x, cat):
    S.save_cat(name, polish(x), cat)


def takes(name, fn, n, cat):
    S.takes_cat(name, lambda i: polish(fn(i)), n, cat)


def vo(*a, **k):
    """S.voice with its tail faded, so a cut-short grunt never ends on a click."""
    return fade_out(S.voice(*a, **k), 0.025)


# ------------------------------------------------------------------ his materials
def crunch(d, per_s, lo=300, hi=3200, fall=None, big=6):
    """Stone breaking: a dense run of small fractures with a few bigger cracks through it."""
    n = N(d)
    fine = grains(d, per_s, lo, hi, 0.002, 0.009, fall)
    bigs = np.zeros(n)
    for _ in range(big):
        tt = S.rng.exponential(fall) if fall else S.rng.uniform(0, d)
        if tt >= d - 0.06:
            continue
        c = mix(crack(0.06, lo, hi * 0.8, 0.008) * 1.2, kick(S.rng.uniform(250, 500), 120, 0.06, 0.004, 0.01, 1.6) * 0.3)
        s0 = N(tt); bigs[s0:s0 + len(c)] += c[:n - s0] * S.rng.uniform(0.5, 1.0)
    return fade_out(mix(fine, bigs), 0.04)


def rumble(d, lp=220, a=0.02, decay=0.3):
    """The ground shaking: deep noise with a slow wobble."""
    t = T(d)
    return lpf(noise(d), lp) * (1 + 0.4 * np.sin(2 * np.pi * 7 * t)) * env(N(d), a, decay)


def gravel(d, per_s=160, fall=0.12):
    """Loose stones and grit pattering down."""
    return lpf(grains(d, per_s, 700, 4000, 0.001, 0.005, fall), 5000)


def molten(d, a=0.02, decay=0.2):
    """The molten glow in the cracks: a low bubbling fizz with crackles (not a flame)."""
    t = T(d)
    fz = bpf(noise(d), 900, 3200) * (0.6 + 0.4 * np.sin(2 * np.pi * 13 * t) ** 2)
    pops = grains(d, 50, 700, 2600, 0.002, 0.006) * 1.5
    return fade_out(mix(fz * 0.5, pops) * env(N(d), a, decay), 0.05)


def thud(f0=150, g=1.0, d=0.5):
    return mix(kick(f0, 50, d, 0.016, 0.06, 2.6) * 0.7 * g, sub(58, 36, d, 0.1) * 0.35 * g)


def stone_tok(f, d=0.5, g=1.0):
    """A seeing-stone knocking: a dry stony ring, the overtones gone at once."""
    return ring((f, f * 2.63, f * 4.87), d, (0.09, 0.03, 0.015), (0.5 * g, 0.2 * g, 0.08 * g))


# ------------------------------------------------------------------ LMB: Rubble Fists
def throw(i):
    """The boulder heaved from the shoulder: a low grinding heave, the stone whooshing off, grit shed behind it."""
    d = 0.45
    return mix(swish(0.32, 140 + 15 * i, 1100 + 80 * i, 2.2) * 1.0, kick(170 + 10 * i, 70, 0.3, 0.02, 0.05, 2.0) * 0.4,
               crunch(0.12, 300, fall=0.04, big=1) * 0.35, at(gravel(0.3, 90, 0.08) * 0.5, 0.05), pad(np.zeros(1), d))


def boulder_hit(i):
    """The boulder smashing: a heavy thud, the rock splitting, gravel spraying and a hiss of hot stone."""
    d = 0.8
    return mix(click(0.004, 1200, 5000) * 1.0, thud(160 + 10 * i, 1.0), crack(d, 350, 3000, 0.02) * 1.6,
               crunch(0.4, 500, fall=0.08, big=5) * 0.9, at(gravel(0.6, 140, 0.18) * 0.6, 0.04),
               at(molten(0.35, 0.02, 0.1) * 0.3, 0.03))


def wind(i):
    """The held punch winding up: the fist gathering stone, grinding and rumbling, the molten core humming."""
    d = 0.9; n = N(d)
    rise = np.linspace(0.25, 1.0, n)
    hum = mix(S.sweep(55, 85, d) * 0.4, S.sweep(110, 170, d) * 0.15) * rise
    grind = bpf(noise(d), 250, 1600) * (0.5 + 0.5 * np.abs(np.sin(2 * np.pi * 11 * T(d)))) * 0.5 * rise
    return fade_out(mix(hum, grind, crunch(d, 120, big=3) * 0.35, molten(d, 0.2, 1.0) * 0.4 * rise), 0.12)


def punch(i):
    """The punch: a stone fist driven through the lane, a whump of air, cracking and a spray of grit."""
    d = 0.8
    return mix(swish(0.18, 180, 1400, 2.0) * 0.8, at(click(0.004, 1200, 5000) * 1.1, 0.06),
               at(thud(140 - 8 * i, 1.3), 0.06), at(crack(0.4, 300, 2600, 0.03) * 1.5, 0.06),
               at(crunch(0.35, 400, fall=0.07, big=4) * 0.7, 0.07), at(gravel(0.5, 130, 0.15) * 0.5, 0.1))


# ------------------------------------------------------------------ rocks: torn up, launched, bursting
def rock_crunch(i):
    """His signature: a rock torn out of the ground and crushed, a deep grinding crunch."""
    d = 0.55
    return mix(crunch(d, 700, 250, 2800, fall=0.12, big=8) * 1.2, thud(120 + 15 * i, 0.6, 0.4),
               bpf(noise(0.3), 150, 700) * env(N(0.3), 0.01, 0.08) * 0.8, at(gravel(0.4, 100, 0.12) * 0.4, 0.08))


def launch(i):
    """A rock sent flying: a heavy whoosh and the crumbs it sheds."""
    d = 0.4
    return mix(swish(0.3, 160, 1000, 2.2) * 1.0, kick(140, 60, 0.25, 0.015, 0.04, 2.0) * 0.4,
               at(gravel(0.3, 80, 0.1) * 0.35, 0.03), pad(np.zeros(1), d))


def burst(i):
    """A launched rock bursting on something: a blast of stone, fragments flying, a glow of molten fizz."""
    d = 0.9
    return mix(click(0.005, 1200, 5500) * 1.2, thud(130, 1.3), crack(d, 300, 3000, 0.03) * 1.8,
               crunch(0.5, 600, fall=0.1, big=6) * 0.9, at(gravel(0.7, 160, 0.22) * 0.6, 0.05),
               at(molten(0.5, 0.02, 0.15) * 0.35, 0.03), reflections(tail(0.5, 900, 0.1) * 0.6))


# ------------------------------------------------------------------ Tremor Sense
def sense(i):
    """Tremor Sense: a deep pulse through the ground and the seeing-stones knocking as they 'see'."""
    d = 0.8
    pulse = mix(np.sin(2 * np.pi * 52 * T(0.6)) * env(N(0.6), 0.03, 0.18) * 0.6, rumble(0.6, 180, 0.03, 0.15) * 0.8)
    toks = mix(*[at(stone_tok(f, 0.4, 0.6 - 0.12 * k), 0.12 + 0.07 * k) for k, f in enumerate((620, 740, 560))])
    return mix(pulse, toks, pad(np.zeros(1), d))


# ------------------------------------------------------------------ dash: Rubble Leap; the air dash
def dash(i):
    """The air dash: a stone-skinned body whipping through the air, grit trailing."""
    d = 0.45
    return mix(swish(0.3, 220 + 20 * i, 1600, 2.2) * 1.0, at(gravel(0.3, 120, 0.1) * 0.35, 0.04),
               kick(180, 80, 0.2, 0.01, 0.03, 1.8) * 0.25, pad(np.zeros(1), d))


def rise(i):
    """The leap's rock heaving up under him: a grinding upthrust and a crunch."""
    d = 0.55
    up = bpf(noise(0.3), 120, 900) * np.linspace(0.3, 1.0, N(0.3)) * 0.9
    return mix(up, at(crunch(0.35, 500, fall=0.08, big=4) * 0.8, 0.22), at(thud(170, 0.8, 0.35), 0.22),
               at(gravel(0.3, 80, 0.1) * 0.35, 0.26))


def leap(i):
    """The push-off: a scuff of stone and a rising rush of air."""
    d = 0.5
    return mix(crunch(0.1, 300, fall=0.03, big=1) * 0.6, kick(200, 90, 0.2, 0.01, 0.03, 1.8) * 0.35,
               swish(0.42, 250, 1500, 2.0) * 0.9, pad(np.zeros(1), d))


def slam(i):
    """Quakefall / the leap's landing: a quake rolling out, stone cracking open, gravel raining."""
    d = 1.3
    return mix(click(0.005, 1200, 5000) * 1.2, thud(110, 1.6, 0.9), crack(d, 250, 2600, 0.04) * 1.8,
               rumble(1.1, 200, 0.01, 0.35) * 1.5, crunch(0.6, 500, fall=0.15, big=6) * 0.8,
               at(gravel(1.0, 140, 0.3) * 0.6, 0.06), reflections(tail(0.9, 700, 0.2) * 0.8))


def shove(i):
    """The lunge out of a slam: a heavy stone-shoulder shove and scattered grit."""
    d = 0.45
    return mix(swish(0.25, 180, 1200, 2.2) * 0.8, at(thud(180, 0.7, 0.3), 0.05), at(crunch(0.2, 300, big=2) * 0.5, 0.05),
               pad(np.zeros(1), d))


def roll(i):
    """The leap's rock rolling on: a tumbling, knocking grind that fades off."""
    d = 0.9; t = T(d)
    bumps = mix(*[at(thud(150 + 20 * (k % 2), 0.35, 0.2), 0.1 * k + 0.02 * (k % 3)) for k in range(8)])
    grind = bpf(noise(d), 200, 1500) * (0.5 + 0.5 * np.abs(np.sin(2 * np.pi * 5 * t))) * 0.6
    return fade_out(mix(bumps[:N(d)], grind, crunch(d, 150, big=4) * 0.5) * env(N(d), 0.02, 0.45), 0.1)


# ------------------------------------------------------------------ E: Stone Row; X: Basalt Spine
def crack_cast(i):
    """Stone Row's tell: the ground splitting open in a line, molten light in the cracks."""
    d = 0.6
    splits = mix(*[at(crack(0.08, 300, 2500, 0.012) * (1.0 - 0.1 * k), 0.06 * k) for k in range(5)])
    return mix(splits, rumble(0.6, 250, 0.05, 0.2) * 0.9, at(molten(0.5, 0.05, 0.2) * 0.35, 0.05))


def raise_rocks(i):
    """Stone Row: the rocks bursting up out of the ground in a row, crunching into place."""
    d = 0.9
    pushes = mix(*[at(mix(thud(160 - 10 * k, 0.6, 0.35), crunch(0.25, 500, big=3) * 0.5), 0.07 * k) for k in range(3)])
    return mix(pushes, rumble(0.7, 220, 0.02, 0.25) * 1.0, at(gravel(0.6, 130, 0.2) * 0.5, 0.1))


def spine(i):
    """Basalt Spine: the ground heaving, a ring of basalt columns ripping up, a long settling of stone."""
    d = 1.6
    heave = rumble(1.4, 160, 0.15, 0.5) * 1.6
    cols = mix(*[at(mix(crack(0.12, 250, 2400, 0.02) * 1.2, thud(140 + 15 * (k % 3), 0.6, 0.3)), 0.15 + 0.09 * k)
                 for k in range(7)])
    return mix(heave, cols, at(crunch(1.0, 400, fall=0.3, big=8) * 0.7, 0.15), at(gravel(1.2, 120, 0.4) * 0.5, 0.3),
               sub(48, 30, d, 0.4) * 0.5)


# ------------------------------------------------------------------ voice (a wiry man, wordless, with grit)
VOWEL = ('uh', 'eh', 'ah', 'uh')


def hurt(i):
    d = (0.2, 0.25, 0.18, 0.23)[i]
    v = vo(d, 175 + 12 * i, 132 - 5 * i, VOWEL[i], breath=0.2, rasp=0.3, scale=0.93, a=0.01, decay=d * 0.45)
    return mix(v, at(gravel(0.15, 60, 0.05) * 0.06, 0.02))


def down(i):
    v = vo(0.8, 165, 105, 'ah', breath=0.3, rasp=0.4, vib=0.015, scale=0.93, a=0.025, decay=0.32)
    fall = mix(thud(150, 0.6, 0.3), crunch(0.3, 300, big=3) * 0.4, gravel(0.4, 100, 0.12) * 0.4)
    return mix(v, at(fall, 0.66))


def death(i):
    v = vo(1.1, 158, 90, 'oh', breath=0.35, rasp=0.5, vib=0.02, scale=0.93, a=0.025, decay=0.45)
    exhale = lpf(hpf(noise(0.6), 400), 3000) * env(N(0.6), 0.08, 0.2) * 0.08
    stones = mix(*[at(stone_tok(f, 0.4, 0.5), 0.12 * k) for k, f in enumerate((640, 560, 700))])  # his stones drop
    return mix(v, at(exhale, 0.95), at(mix(thud(140, 0.7, 0.4), stones), 0.9))


# ------------------------------------------------------------------ footsteps (sure, light feet, grit underfoot)
def step(surface, i):
    w = 1.0
    def hit(g):
        th = kick(130 + 10 * i, 58, 0.25, 0.01, 0.018 * w, 1.6) * 0.45 * g
        if surface == 'grass':
            tex = lpf(mix(grains(0.12, 240, 900, 4500, fall=0.025) * 0.5,
                          bpf(noise(0.1), 600, 3500) * env(N(0.1), 0.004, 0.025) * 0.35), 5500)
        elif surface == 'stone':
            tex = mix(crack(0.12, 500, 3200, 0.01) * 0.8, crunch(0.08, 300, 600, 4000, big=1) * 0.5)
        elif surface == 'wood':
            tex = mix(ring((150 + 7 * i, 360, 820), 0.3, (0.06, 0.035, 0.02), (0.5, 0.28, 0.1)),
                      crack(0.1, 300, 2200, 0.01) * 0.8)
        else:
            tex = mix(lpf(grains(0.18, 950, 450, 3000, fall=0.045), 3200) * 0.95,
                      lpf(noise(0.13), 800) * env(N(0.13), 0.006, 0.035) * 0.6)
        return mix(th, tex) * g
    grit = gravel(0.12, 70, 0.04) * 0.12
    return mix(hit(1.0), at(hit(0.45), 0.04 + 0.006 * i), at(grit, 0.01))


def build():
    takes('br_throw', throw, 3, 'fire')
    takes('br_boulder_hit', boulder_hit, 3, 'impact')
    save('br_wind', wind(0), 'cast')
    takes('br_punch', punch, 2, 'fire')
    takes('dolm_rock_crunch', rock_crunch, 2, 'signature')
    takes('br_launch', launch, 2, 'cast')
    takes('br_burst', burst, 2, 'impact')
    save('br_sense', sense(0), 'cast')
    takes('dolm_dash', dash, 2, 'dash')
    save('br_rise', rise(0), 'cast')
    save('br_leap', leap(0), 'cast')
    save('br_slam', slam(0), 'impact')
    save('br_shove', shove(0), 'cast')
    save('br_roll', roll(0), 'cast')
    save('br_crack', crack_cast(0), 'cast')
    save('br_raise', raise_rocks(0), 'impact')
    save('br_spine', spine(0), 'impact')
    takes('dolm_hurt', hurt, 3, 'grunt')
    save('dolm_down', down(0), 'grunt')
    save('dolm_death', death(0), 'grunt')
    for s in ('grass', 'stone', 'wood', 'snow'):
        takes('dolm_step_' + s, lambda i, s=s: step(s, i), 3, 'step')


if __name__ == '__main__':
    build()
