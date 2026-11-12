"""Kael, the Unbroken (juggernaut): his sound set (docs/AUDIO.md, content/sfx/juggernaut.json).

    python3 tools/gen_sfx_kael.py      (then: godot --headless --import)

Heavy, grim and cold: a huge greatsword that hisses white-hot through the air (never a fire roar: that is
Cinder's), the iron Warchain he tore out of the arena wall rattling, biting and snapping taut, slams that
shake the ground, a demon that is fed on a knock. A big man's low wordless grunts; heavy boots with the
shackle's chain clinking at every step. Original synthesis, no samples.
"""
import os, sys
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import sfx_lib as S
from sfx_lib import (N, T, noise, lpf, hpf, bpf, env, mix, at, kick, click, crack, sub, tail, reflections, ring,
                     grains, pad)

S.reseed(4402)


# ------------------------------------------------------------------ helpers
def swish(d, f0, f1, q=3.0):
    """Air torn by something fast: noise through a band-pass whose centre sweeps f0 -> f1."""
    n = N(d); u = np.arange(n) / n
    f = f0 * (f1 / f0) ** u
    x = noise(d); out = np.empty(n); low = band = 0.0; damp = 1.0 / q
    g = 2.0 * np.sin(np.pi * np.minimum(f, S.SR / 6.5) / S.SR)
    for k in range(n):
        low += g[k] * band
        band += g[k] * (x[k] - low - damp * band)
        out[k] = band
    return out * np.sin(np.pi * np.clip(u * 1.1, 0, 1)) ** 1.5


def bell(f, d=0.6, decay=0.25):
    """A bell or a ringing blade: S.chime without the partials that would fold over the top of the band."""
    parts = tuple(pg for pg in ((1.0, 1.0), (2.76, 0.45), (5.4, 0.22), (8.93, 0.1)) if f * pg[0] < 9000)
    x = S.chime(f, d, decay, parts); k = N(0.04)
    x[-k:] *= np.linspace(1.0, 0.0, k)
    return x


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
def links(d, times, lo=700, hi=2600, g=0.5, dec=(0.012, 0.035)):
    """Iron chain links knocking: each a short inharmonic clank with a tick of noise."""
    out = np.zeros(N(d) + N(0.1))
    for tt in times:
        f = S.rng.uniform(lo, hi); dc = S.rng.uniform(*dec)
        c = mix(ring((f, f * 2.32, f * 3.91), 0.1, (dc, dc * 0.6, dc * 0.4), (g, g * 0.5, g * 0.25)),
                crack(0.02, 900, 4500, 0.002) * g * 0.8)
        s0 = N(tt); out[s0:s0 + len(c)] += c
    return fade_out(out[:N(d)], 0.02)


def chain_rattle(d, rate, lo=700, hi=2600, g=0.5, swell=None):
    """A heavy chain shaken or paid out: a dense run of links (rate per second) over a low drag."""
    times = np.sort(S.rng.uniform(0, d * 0.92, int(rate * d)))
    drag = bpf(noise(d), 250, 1200) * 0.25
    x = mix(links(d, times, lo, hi, g), drag)
    return fade_out(x * (swell if swell is not None else env(N(d), 0.01, d * 0.6)), 0.05)


def sizzle(d, a=0.02, decay=0.25, lo=2000, hi=4600):
    """White-hot metal in the air: a fine hiss with crackling pops and a thin whining tone (no flame roar)."""
    t = T(d)
    flutter = 1.0 + 0.35 * np.sin(2 * np.pi * 9.3 * t) * np.sin(2 * np.pi * 2.1 * t)
    hs = bpf(noise(d), lo, hi) * flutter
    pops = grains(d, 110, 1500, 4500, gmin=0.001, gmax=0.004) * 2.0
    whine = np.sin(2 * np.pi * (1850 + 25 * np.sin(2 * np.pi * 6 * t)) * t) * 0.12
    return fade_out(mix(hs, pops, whine) * env(N(d), a, decay), min(0.08, d * 0.3))


def stomp(g=1.0, f0=130):
    return mix(kick(f0, 48, 0.4, 0.016, 0.05, 2.6) * 0.7 * g, crack(0.3, 180, 1400, 0.03) * 1.6 * g,
               sub(55, 34, 0.45, 0.09) * 0.35 * g)


# ------------------------------------------------------------------ LMB: the greatsword
def slash(i):
    """A wide greatsword cut: heavy air moved, the hot edge hissing through it, the shackle's chain swinging."""
    d = 0.42
    whum = S.sweep(95 + 6 * i, 60, d) * np.sin(np.pi * np.arange(N(d)) / N(d)) ** 2 * 0.35
    return mix(lpf(swish(d, 170 + 15 * i, 1300 + 120 * i, 3.5), 5000) * 1.3, whum,
               at(sizzle(0.3, 0.03, 0.08) * 0.2, 0.05),
               at(links(0.2, (0.0, 0.03, 0.07), g=0.15), 0.12), at(lpf(noise(0.2), 300) * env(N(0.2), 0.03, 0.06), 0.06))


def blade_hiss(i):
    """His signature: the white-hot blade hissing as it cuts the air (on every greatsword strike)."""
    d = 0.6
    return mix(sizzle(d, 0.008, 0.16 + 0.02 * i) * 1.0, S.sweep(2400, 1700, d) * env(N(d), 0.01, 0.12) * 0.06,
               swish(0.25, 600, 2600, 3.0) * 0.4)


def wave(i):
    """The Searing Wave: a crescent of heat thrown off the blade, a pressure thump and a long searing hiss."""
    d = 0.9
    push = mix(kick(140, 55, 0.5, 0.02, 0.07, 2.4) * 0.6, lpf(noise(0.6), 600) * env(N(0.6), 0.01, 0.12) * 1.2)
    return mix(swish(0.5, 220, 2200, 1.8) * 1.0, push, at(sizzle(0.8, 0.03, 0.3) * 0.7, 0.04),
               at(S.sweep(900, 300, 0.6) * env(N(0.6), 0.01, 0.15) * 0.08, 0.02))


# ------------------------------------------------------------------ dash: Rampage
def dash(i):
    """The shoulder charge: heavy air, two driving stomps, the chain jangling."""
    d = 0.5
    return mix(swish(0.35, 150, 1200, 1.8) * 1.0, at(stomp(0.5, 120 + 6 * i), 0.0), at(stomp(0.4, 110), 0.18),
               at(chain_rattle(0.3, 45, g=0.22), 0.04), pad(np.zeros(1), d))


# ------------------------------------------------------------------ RMB: Smash, Lunge, Meteor
def charge(i):
    """Winding up: the blade heats (a rising hum), leather and plate creak, the hiss swelling."""
    d = 0.85; n = N(d)
    rise = np.linspace(0.15, 1.0, n) ** 1.5
    hum = mix(S.sweep(70, 160, d) * 0.35, S.sweep(140, 320, d) * 0.15, S.sweep(560, 1250, d) * 0.04)
    return fade_out(mix(hum * rise, sizzle(d, 0.3, 2.0) * rise * 0.4, S.creak(0.5, 80, 55, 0.6, 1600) * 0.25), 0.15)


def full(i):
    """Full charge (and the perfect-release flash): the hilt rings out bright over a flare of hiss."""
    return mix(bell(1046, 0.6, 0.25) * 0.4, bell(1568, 0.5, 0.18) * 0.25, sizzle(0.4, 0.004, 0.08) * 0.5,
               kick(400, 200, 0.12, 0.004, 0.02, 1.6) * 0.2)


def slam_wind(i):
    d = 0.55
    return mix(swish(d, 140, 900, 2.0) * 0.9, sizzle(d, 0.2, 0.6) * 0.5 * np.linspace(0.3, 1.0, N(d)),
               links(d, (0.05, 0.11, 0.2), g=0.2))


def slam_hit(i):
    """The Finishing Slam: the blade buried in the ground, stone cracking, a hiss as the hot steel bites."""
    d = 1.0
    return mix(click(0.004, 1500, 6000) * 1.4, stomp(1.4, 140), crack(d, 400, 3500, 0.025) * 1.8,
               grains(0.6, 160, 900, 4500, fall=0.12) * 0.9, at(sizzle(0.6, 0.02, 0.15) * 0.35, 0.03),
               reflections(tail(0.7, 900, 0.14) * 1.1))


def lunge_hit(i):
    """The Lunge connecting (and, pitched up, the release): a heavy chop with a bright ring of steel."""
    d = 0.6
    return mix(click(0.003, 2000, 6500) * 1.2, kick(210, 70, d, 0.01, 0.05, 2.8) * 0.65,
               crack(d, 300, 2800, 0.03) * 2.0, ring((1320, 1980, 3090), d, (0.15, 0.09, 0.05), (0.18, 0.1, 0.05)),
               at(sizzle(0.4, 0.01, 0.1) * 0.3, 0.02))


def drop(i):
    """The leap into the Meteor Drop: a heave of air upward and the blade hissing as it rises."""
    d = 0.5
    return mix(swish(d, 200, 1800, 1.8) * 1.0, kick(160, 70, 0.3, 0.02, 0.05, 2.0) * 0.5,
               at(sizzle(0.4, 0.06, 0.2) * 0.5, 0.08))


def meteor(i):
    """The Meteor landing: the biggest slam, a boom rolling off the islands and debris raining down."""
    d = 1.4
    return mix(click(0.005, 1500, 6000) * 1.6, stomp(1.8, 120), crack(d, 300, 3000, 0.04) * 2.2,
               sub(48, 28, d, 0.25) * 0.6, grains(1.0, 120, 800, 4000, fall=0.3) * 0.9,
               lpf(noise(d), 700) * env(N(d), 0.01, 0.35) * 1.5, at(sizzle(0.8, 0.05, 0.25) * 0.3, 0.05),
               reflections(tail(1.0, 800, 0.25) * 1.2, ((0.07, 0.4, 900), (0.16, 0.3, 700), (0.28, 0.2, 500))))


# ------------------------------------------------------------------ E: the Warchain
def chain_rattle_sig(i):
    """His signature: the Warchain flying out link by link (on the throw, the hook-lunge and the haul's end)."""
    d = 0.6; n = N(d)
    sw = env(n, 0.01, 0.3)
    return mix(chain_rattle(d, 75, 650, 2400, 0.5, sw), swish(0.3, 300, 1600, 2.0) * 0.4)


def chain_throw(i):
    """The throw: a heavy overhand heave, the hook whistling out, the chain paying out behind it."""
    d = 0.55
    return mix(swish(0.3, 200, 1400, 2.0) * 0.9, at(S.sweep(900, 1500, 0.25) * env(N(0.25), 0.03, 0.08) * 0.08, 0.08),
               at(chain_rattle(0.45, 60, g=0.4), 0.06))


def chain_bite(i):
    """The hook biting into a foe or a wall: an iron clank and a thud, the chain dropping slack."""
    d = 0.5
    return mix(click(0.003, 1500, 5000) * 1.2, kick(260, 90, 0.35, 0.008, 0.04, 2.4) * 0.6,
               ring((620, 1450, 2380), d, (0.12, 0.07, 0.04), (0.3, 0.18, 0.08)), crack(0.3, 300, 2500, 0.02) * 1.4,
               at(links(0.3, (0.0, 0.04, 0.07, 0.12, 0.17), g=0.25), 0.05))


def taut(i):
    """The chain snapping taut: a hard jerk of iron, a ringing strain and a creak of the links."""
    d = 0.45
    return mix(crack(0.2, 600, 3500, 0.01) * 1.6, kick(300, 120, 0.2, 0.005, 0.02, 2.2) * 0.45,
               ring((780, 1830, 2950), d, (0.1, 0.06, 0.04), (0.3, 0.16, 0.08)),
               at(S.creak(0.3, 140, 110, 0.5, 2000) * 0.35, 0.03), links(0.15, (0.0, 0.015, 0.03), g=0.3))


def reel(i):
    """The haul: the chain ratcheting in, link over link, while the air rushes past."""
    d = 0.6; t = np.arange(N(d)) / S.SR
    times = np.cumsum(np.full(18, 0.032))[:17]
    return mix(links(d, times, 600, 2000, 0.4), swish(d, 250, 1300, 1.6) * 0.7,
               S.creak(d, 120, 160, 0.5, 1800) * 0.2) * (1 - 0.6 * t / d)


# ------------------------------------------------------------------ X: Gilded Riposte, and the passives
def guard(i):
    """The guard raised: plate and blade braced with a clank, a held hum of white heat."""
    d = 0.75; n = N(d)
    hum = mix(np.sin(2 * np.pi * 110 * T(d)) * 0.25, np.sin(2 * np.pi * 220.7 * T(d)) * 0.12,
              sizzle(d, 0.05, 0.3) * 0.12) * np.minimum(1.0, np.arange(n) / N(0.06))
    return mix(click(0.003, 1500, 5000) * 1.0, kick(300, 120, 0.25, 0.006, 0.03, 2.0) * 0.5,
               ring((520, 1210, 2080), 0.5, (0.12, 0.08, 0.05), (0.3, 0.15, 0.08)), fade_out(hum, 0.12))


def ting(i):
    """A blow caught on the guard: a hard clang with a short bright ring."""
    d = 0.4
    f = (960, 1040, 900)[i]
    return mix(click(0.003, 2000, 6000) * 1.2, ring((f, f * 2.32, f * 3.63), d, (0.1, 0.06, 0.03), (0.4, 0.22, 0.1)),
               crack(0.15, 500, 3000, 0.01) * 1.2, kick(400, 200, 0.12, 0.004, 0.015, 1.8) * 0.3)


RIPOSTE_HIT = 0.1   # s: the cut lands with the cleave (content/archetypes/juggernaut.json x.strike_t)


def riposte(i):
    """The lunging upward cleave: a short rising heave, then the cut on the strike: a hard bright edge (a
    near-instant click and a steel shing) over the chop, the hot edge hissing after it."""
    edge = mix(click(0.002, 3000, 9000, 0.0008) * 2.2, crack(0.12, 2500, 8000, 0.008, 0.0002) * 1.6,
               ring((2350, 3530), 0.3, (0.06, 0.035), (0.14, 0.08), 0.0002))
    cut = mix(edge, kick(190, 65, 0.5, 0.006, 0.05, 2.8) * 0.7, crack(0.5, 300, 2600, 0.03, 0.0003) * 1.5)
    return mix(swish(RIPOSTE_HIT + 0.02, 150, 2000, 2.0) * 0.6, at(cut, RIPOSTE_HIT),
               at(sizzle(0.55, 0.01, 0.18) * 0.45, RIPOSTE_HIT + 0.01), at(bell(784, 0.5, 0.2) * 0.15, RIPOSTE_HIT))


def heal(i):
    """A knock feeds the demon: a deep heartbeat under a dark indrawn breath, the blade flaring."""
    d = 0.9; n = N(d)
    beat = mix(kick(80, 45, 0.3, 0.02, 0.06, 2.0) * 0.6, at(kick(75, 42, 0.3, 0.02, 0.06, 2.0) * 0.45, 0.22))
    breath = lpf(bpf(noise(d), 200, 1400), 1500) * np.sin(np.pi * np.arange(n) / n) ** 2 * 0.5
    return mix(breath, at(beat, 0.1), at(sizzle(0.5, 0.05, 0.15) * 0.3, 0.3))


def enrage(i):
    """Enraged: a low growl from deep in the chest, the blade flaring white-hot, the chain shaken."""
    growl = vo(0.9, 92, 78, 'uh', breath=0.25, rasp=0.9, vib=0.03, scale=0.82, a=0.06, decay=0.45)
    return mix(growl * 1.0, at(sizzle(0.8, 0.08, 0.3) * 0.4, 0.1), at(chain_rattle(0.5, 50, g=0.3), 0.15),
               stomp(0.4, 100))


# ------------------------------------------------------------------ voice (a big man, wordless, grim)
VOWEL = ('uh', 'ah', 'oh', 'uh')


def hurt(i):
    d = (0.22, 0.28, 0.2, 0.25)[i]
    v = vo(d, 135 + 10 * i, 98 - 4 * i, VOWEL[i], breath=0.15, rasp=0.45, scale=0.84, a=0.012, decay=d * 0.45)
    chest = lpf(noise(0.12), 400) * env(N(0.12), 0.005, 0.03) * 0.15        # the blow knocking the air out
    return mix(chest, at(v, 0.01), at(links(0.1, (0.0, 0.025), g=0.06), 0.02))


def down(i):
    v = vo(0.85, 125, 82, 'ah', breath=0.25, rasp=0.6, vib=0.015, scale=0.84, a=0.03, decay=0.35)
    fall = mix(stomp(0.8, 110), at(chain_rattle(0.4, 50, g=0.35), 0.01))
    return mix(v, at(fall, 0.7))


def death(i):
    v = vo(1.2, 118, 70, 'oh', breath=0.3, rasp=0.7, vib=0.02, scale=0.84, a=0.03, decay=0.5)
    exhale = lpf(hpf(noise(0.7), 300), 2500) * env(N(0.7), 0.08, 0.25) * 0.1
    fall = mix(stomp(1.0, 100), at(chain_rattle(0.6, 45, g=0.4), 0.02),
               at(ring((830, 1940, 3020), 0.6, (0.15, 0.08, 0.05), (0.2, 0.1, 0.05)), 0.08))   # the sword falling
    return mix(v, at(exhale, 1.0), at(fall, 0.95))


# ------------------------------------------------------------------ footsteps (heavy boots, the shackle chain)
def step(surface, i):
    w = 1.5
    def hit(g):
        th = kick(105 + 8 * i, 45, 0.3, 0.014, 0.022 * w, 2.0) * 0.6 * g
        if surface == 'grass':
            tex = lpf(mix(grains(0.14, 220, 800, 4000, fall=0.03) * 0.5,
                          bpf(noise(0.12), 500, 3000) * env(N(0.12), 0.004, 0.03) * 0.45), 5500)
        elif surface == 'stone':
            tex = mix(click(0.003, 1200, 4500) * 0.6, crack(0.15, 400, 3000, 0.014) * 1.1,
                      at(grains(0.08, 200, 1000, 4000, fall=0.02) * 0.25, 0.01))
        elif surface == 'wood':
            tex = mix(ring((115 + 6 * i, 290, 690), 0.35, (0.07, 0.04, 0.025), (0.55, 0.3, 0.12)),
                      crack(0.12, 250, 1800, 0.012) * 0.9, at(S.creak(0.18, 160, 120, 0.5, 1600) * 0.15, 0.03))
        else:
            tex = mix(lpf(grains(0.2, 1000, 400, 2600, fall=0.05), 3000) * 1.0,
                      lpf(noise(0.15), 700) * env(N(0.15), 0.008, 0.04) * 0.7)
        return mix(th, tex) * g
    shackle = links(0.2, (0.03 + 0.005 * i, 0.06 + 0.004 * i), 900, 2200, 0.05)
    return mix(hit(1.0), at(hit(0.4), 0.05 + 0.006 * i), shackle)


def build():
    takes('jug_slash', slash, 3, 'fire')
    takes('juggernaut_blade_hiss', blade_hiss, 2, 'signature')
    save('jug_wave', wave(0), 'cast')
    takes('juggernaut_dash', dash, 2, 'dash')
    save('jug_charge', charge(0), 'cast')
    save('jug_full', full(0), 'cast')
    save('jug_slam_wind', slam_wind(0), 'cast')
    save('jug_slam_hit', slam_hit(0), 'impact')
    save('jug_lunge_hit', lunge_hit(0), 'impact')
    save('jug_drop', drop(0), 'cast')
    save('jug_meteor', meteor(0), 'impact')
    takes('juggernaut_chain_rattle', chain_rattle_sig, 2, 'signature')
    save('jug_chain', chain_throw(0), 'cast')
    save('juggernaut_chain_bite', chain_bite(0), 'impact')
    save('jug_taut', taut(0), 'impact')
    save('jug_reel', reel(0), 'cast')
    save('jug_guard', guard(0), 'cast')
    takes('jug_ting', ting, 2, 'impact')
    save('jug_riposte', riposte(0), 'impact')
    save('juggernaut_heal', heal(0), 'cast')
    save('juggernaut_enrage', enrage(0), 'signature')
    takes('juggernaut_hurt', hurt, 3, 'grunt')
    save('juggernaut_down', down(0), 'grunt')
    save('juggernaut_death', death(0), 'grunt')
    for s in ('grass', 'stone', 'wood', 'snow'):
        takes('juggernaut_step_' + s, lambda i, s=s: step(s, i), 3, 'step')


if __name__ == '__main__':
    build()
