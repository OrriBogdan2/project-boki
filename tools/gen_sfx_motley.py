"""Motley the Void Jester (ostra): every sound his kit plays, synthesised and levelled (docs/AUDIO.md).

    cd tools && python3 gen_sfx_motley.py      (then: godot --headless --import)

Motley is Malgrave's court jester sealed in his own grinning mask: a floating jack-in-the-box of a man
from the Void. His palette is a worn music box (steel comb tines, slightly out of true), a coiled spring,
the bells on his cap (which ring only when he swaps) and the Void under it all (dark swells, a hollow
low drone). His voice is a man's behind a mask: hollow, eerie, playful, a giggle where a groan should be.

  os_orb (fire, 3 takes)       a violet orb flicked out: a soft void puff and a music-box tine
  os_orb_hot (fire, 3 takes)   the full orb: a deeper puff and a two-tine flourish
  os_prime                     the orb at full: a quiet tine trill
  ostra_music_box              SIGNATURE: the crank's eerie tune, when Brimseed is nearly ripe (its column)
  ostra_spring_boing           SIGNATURE: the jack springing out as Brimseed pops
  os_snap_wind / os_snap / os_snap_hit   Snap: the crank ratcheting / the spring-loaded spear / the crown stun
  os_swap_lob / os_swap        Trade: the toss (a rising slide whistle) / the arrival, cap bells ringing
  os_seed / os_pop             Brimseed planted / popped
  os_empower                   Swollen: the Void inflating round him, a giggle
  os_well / os_well_hum        Nightwell: the gathering implosion / the well opening
  ostra_dash                   a floating lurch, a small spring and the cap bells
  ostra_step_<surface>         he floats: soft hover pulses, the surface faintly under him, a bell now and then
  ostra_hurt/down/death        wordless voice

The os_* files were first written by tools/gen_pair_sfx.py; this script replaces them (content/sfx/
ostra.json lists them under "replaces"). Original synthesis and an original tune, no samples.
"""
import os, sys
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import sfx_lib as S
from sfx_lib import (N, T, noise, lpf, hpf, bpf, env, mix, at, kick, click, crack, sub, tail,
                     reflections, ring, grains, pad)

S.reseed(6623)


# ------------------------------------------------------------------ shared helpers
def swoosh(d, f0, f1, q=2.0, curve=1.0, shape=1.5):
    """Air pushed aside: noise through a resonant band-pass sweeping f0 -> f1, a smooth swell and fade."""
    n = N(d); u = np.arange(n) / max(1, n - 1)
    f = f0 * (f1 / f0) ** (u ** curve)
    x = noise(d); out = np.empty(n); low = band = 0.0; damp = 1.0 / q
    for k in range(n):
        g = 2.0 * np.sin(np.pi * min(f[k], S.SR / 6.5) / S.SR)
        low += g * band
        band += g * (x[k] - low - damp * band)
        out[k] = band
    return out * np.sin(np.pi * u) ** shape


def soft(x, ms=4.0):
    """A short raised-cosine fade-in, so a layer never starts on a hard edge."""
    k = min(len(x), N(ms / 1000.0))
    x = x.copy(); x[:k] *= 0.5 - 0.5 * np.cos(np.pi * np.arange(k) / max(1, k))
    return x


def tick(f=1800, g=1.0):
    """A small mechanical tick (a ratchet tooth, a gear): a short damped ring, no broadband edge."""
    return mix(ring((f, f * 1.7), 0.03, (0.004, 0.0025), (0.6, 0.25), 0.0004),
               kick(500, 300, 0.02, 0.003, 0.004, 1.2) * 0.3) * g


def fo(x, frac=0.35):
    """A raised-cosine fade over the last `frac` of a layer, so no layer stops on an edge mid-sound."""
    k = max(1, int(len(x) * frac))
    x = x.copy(); x[-k:] *= 0.5 + 0.5 * np.cos(np.pi * np.arange(k) / k)
    return x


def hz(midi):
    return 440.0 * 2 ** ((midi - 69) / 12.0)


def tine(f, d=0.9, decay=0.45, wow=0.004):
    """One music-box tine: a pure fundamental, the comb's high bending mode, a tiny pluck, a worn wobble."""
    t = T(d)
    ff = f * (1 + wow * np.sin(2 * np.pi * 0.9 * t + S.rng.uniform(0, 6.28)))
    ph = 2 * np.pi * np.cumsum(ff) / S.SR
    body = np.sin(ph) * np.exp(-t / decay) + 0.12 * np.sin(2 * ph) * np.exp(-t / (decay * 0.4))
    bend = 0.04 * np.sin(ph * 5.93) * np.exp(-t / 0.02)
    pluck = bpf(noise(0.01), 2000, 5000) * env(N(0.01), 0.0005, 0.0015) * 0.1
    return fo(lpf(mix(body + bend, pluck) * env(N(d), 0.0008, d), 7000), 0.2)


def bells(d, hits=10, lo=1900, hi=2700, g=1.0, spread=None):
    """The cap's jingle bells shaken: small bright bells struck in a quick, uneven cluster."""
    out = np.zeros(N(d)); spread = spread or d * 0.5
    for _ in range(hits):
        f = S.rng.uniform(lo, hi)
        b = ring((f, f * 1.51, f * 2.32), 0.35, (0.09, 0.05, 0.025), (0.5, 0.25, 0.08))
        out = mix(out, at(fo(b, 0.3) * S.rng.uniform(0.35, 1.0), S.rng.uniform(0, spread)))
    return fo(lpf(pad(out, d)[:N(d)], 7000), 0.25) * g


def spring(d=0.5, f0=150, wob=0.45, rate=16.0, decay=0.18):
    """A coiled spring let go: a low tone wobbling round its pitch as it rings down, a metal twang on top."""
    t = T(d)
    f = f0 * (1 + wob * np.exp(-t / (decay * 0.8)) * np.sin(2 * np.pi * rate * t))
    tone = np.sin(2 * np.pi * np.cumsum(f) / S.SR) * np.exp(-t / decay)
    # the coil's dispersion: little falling chirps repeating as the wave runs up and down it
    chirp = np.zeros(N(d))
    for k in range(int(d / 0.045)):
        c = S.sweep(3200, 500, 0.03) * env(N(0.03), 0.001, 0.01) * np.exp(-k * 0.045 / (decay * 0.7))
        chirp = mix(chirp, at(c, k * 0.045))
    twang = ring((f0 * 6.1, f0 * 9.7), d, (0.06, 0.03), (0.15, 0.06))
    return fo(mix(S.sat(tone, 1.3), pad(chirp, d)[:N(d)] * 0.12, twang), 0.25)


def void(d, lp=500, rise=0.7):
    """The Void swelling: dark low noise rising in, a pair of beating low sines under it."""
    t = T(d)
    shape = np.minimum(1, t / (d * rise)) ** 2
    drone = (np.sin(2 * np.pi * 55 * t) + np.sin(2 * np.pi * 58.3 * t + 1.0)) * 0.3
    return (lpf(noise(d), lp) * 1.2 + drone) * shape


def hollow(x, ms=1.6, g=0.55):
    """Through the mask: a short comb (the voice's hollow, boxed-in ring)."""
    k = N(ms / 1000.0)
    return mix(x, at(x * g, ms / 1000.0))[:len(x) + k]


def giggle(n=4, f0=190, gap=0.085, vowel='eh', g=1.0):
    """A wordless, breathy 'heh-heh' run, each pulse a little higher (eerie, playful)."""
    out = np.zeros(1)
    for k in range(n):
        p = S.voice(0.075, f0 * (1 + 0.06 * k), f0 * (1 + 0.06 * k) * 0.92, vowel, breath=0.6, rasp=0.15,
                    scale=1.0, a=0.006, decay=0.03)
        out = mix(out, at(fo(p, 0.3) * (1 - 0.12 * k), k * gap))
    return hollow(lpf(out, 4500)) * g


# ------------------------------------------------------------------ LMB: the orbs
SCALE = (81, 84, 85, 88, 89, 92)    # an eerie set of notes for the tines (A5 C6 C#6 E6 F6 G#6)


def orb(i):
    """A violet orb flicked out: a soft void puff, a quick airy whoosh and one tine from the box."""
    d = 0.5
    puff = mix(kick(220, 90, 0.18, 0.01, 0.03, 1.6) * 0.5, lpf(noise(0.15), 900) * env(N(0.15), 0.002, 0.03) * 0.8)
    air = lpf(swoosh(0.26, 700, 1900, 2.4, 0.8, 1.4), 4000) * 0.22
    note = tine(hz(SCALE[(i * 2 + 1) % len(SCALE)]), 0.45, 0.16) * 0.6
    under = at(void(0.22, 400, 0.2) * 0.4, 0.0)
    return pad(lpf(mix(soft(puff, 1.0), fo(air), note, fo(under)), 8000), d)


def orb_hot(i):
    """The full orb: a deeper whoomp from the Void and a two-tine flourish."""
    d = 0.75
    whoomp = mix(kick(160, 55, 0.35, 0.02, 0.06, 2.2) * 0.75, lpf(noise(0.3), 700) * env(N(0.3), 0.003, 0.06) * 1.0,
                 sub(70, 45, 0.3, 0.06) * 0.35)
    air = lpf(swoosh(0.36, 450, 1800, 2.0, 0.8, 1.3), 4000) * 0.3
    a, b = SCALE[(i + 2) % len(SCALE)], SCALE[(i + 4) % len(SCALE)]
    notes = mix(tine(hz(a), 0.6, 0.2) * 0.4, at(tine(hz(b), 0.6, 0.22) * 0.45, 0.06))
    return pad(lpf(mix(soft(whoomp, 1.0), fo(air), notes), 8000), d)


def prime():
    """The orb at full: a quiet three-tine trill falling, like the box catching its breath."""
    d = 0.8
    out = mix(*[at(tine(hz(m), 0.6, 0.2) * (0.6 - 0.1 * k), k * 0.05) for k, m in enumerate((92, 88, 85))])
    return pad(out, d)


# ------------------------------------------------------------------ signatures
TUNE = ((88, 0.0), (85, 0.2), (81, 0.4), (84, 0.6), (85, 0.8), (89, 1.0), (88, 1.3), (82, 1.62), (81, 2.0))
BASS = ((57, 0.0), (52, 0.4), (58, 0.8), (57, 1.3), (45, 2.0))


def music_box():
    """The crank's tune: an original falling phrase that slows as the spring runs down, a low tine under it,
    the gear's faint tick. Worn: the notes waver a little out of true."""
    d = 3.0
    out = np.zeros(N(d))
    for m, t0 in TUNE:
        out = mix(out, at(tine(hz(m) * S.rng.uniform(0.996, 1.004), 0.95, 0.42, 0.006) * 0.55, t0))
    for m, t0 in BASS:
        out = mix(out, at(tine(hz(m + 12), 1.0, 0.5, 0.004) * 0.3, t0 + 0.01))
    ticks = np.zeros(N(d))
    for k in range(18):
        ticks = mix(ticks, at(tick(1400, 0.06), 0.12 * k * (1 + 0.012 * k)))
    return fo(pad(mix(out, ticks), d)[:N(d)], 0.2)


def spring_boing():
    """The jack springing out of the box: a lid knock, the big boing ringing down, a rattle of the coil."""
    d = 0.9
    lid = mix(click(0.003, 1500, 5000) * 0.8, kick(260, 120, 0.12, 0.006, 0.02, 1.8) * 0.5,
              ring((620, 1040), 0.12, (0.03, 0.02), (0.25, 0.1)))
    boing = at(spring(0.85, 165, 0.5, 15.0, 0.22), 0.01)
    up = at(S.sweep(300, 900, 0.12) * env(N(0.12), 0.003, 0.05) * 0.25, 0.005)
    return pad(lpf(mix(soft(lid, 0.8), boing, up), 7500), d)


# ------------------------------------------------------------------ RMB: Snap
def snap_wind():
    """Snap wound up: the crank ratcheting faster and faster, the spring's tension climbing."""
    d = 0.55; t = T(d)
    rate = 14 * (40 / 14) ** (t / d)
    ph = np.cumsum(rate) / S.SR
    teeth = np.flatnonzero(np.diff(np.floor(ph), prepend=0) > 0) / S.SR
    ratchet = pad(mix(*[at(tick(1500 + 300 * (k % 2), 0.5 + 0.5 * k / len(teeth)), t0) for k, t0 in enumerate(teeth)]), d)[:N(d)]
    tension = S.sweep(220, 520, d, curve=0.8) * 0.12 * np.minimum(1, t / 0.1)
    hum = void(d, 350, 1.0) * 0.4
    return fo(mix(ratchet, tension, hum), 0.12)


def snap():
    """The spear let go: a spring's sharp release, a dark rushing streak."""
    d = 0.6
    rel = mix(click(0.003, 1800, 6000) * 1.0, kick(300, 110, 0.15, 0.008, 0.025, 2.0) * 0.6)
    boing = at(spring(0.4, 240, 0.3, 22.0, 0.09) * 0.55, 0.004)
    streak = lpf(swoosh(0.4, 1800, 400, 2.4, 1.0, 1.4), 4500) * 0.45
    dark = at(lpf(noise(0.4), 600) * env(N(0.4), 0.01, 0.1) * 0.6, 0.02)
    return pad(lpf(mix(soft(rel, 0.8), boing, fo(streak), dark), 8000), d)


def snap_hit():
    """The spear landing and the crown stun: a void crunch, the bells shaken, a dizzy fall of tines."""
    d = 1.0
    hit = mix(click(0.004, 1500, 6000) * 1.2, kick(200, 70, 0.4, 0.012, 0.05, 2.6) * 0.75,
              crack(0.25, 300, 2600, 0.025) * 1.8, sub(65, 42, 0.35, 0.07) * 0.35)
    shake = at(bells(0.5, 8, 1700, 2500, 0.35, 0.18), 0.02)
    dizzy = mix(*[at(tine(hz(m), 0.4, 0.14) * 0.3, 0.12 + 0.08 * k) for k, m in enumerate((89, 85, 82, 78))])
    return pad(lpf(mix(soft(hit, 1.0), shake, dizzy), 8000), d)


# ------------------------------------------------------------------ Shift: Trade
def swap_lob():
    """The toss: a quick whoosh up and a slide whistle rising (the joke before the trick)."""
    d = 0.55; t = T(d)
    air = lpf(swoosh(0.4, 400, 1600, 1.8, 0.8, 1.4), 4000) * 0.35
    f = 520 * (1500 / 520) ** ((t / d) ** 0.8) * (1 + 0.01 * np.sin(2 * np.pi * 6 * t))
    whistle = (np.sin(2 * np.pi * np.cumsum(f) / S.SR) + 0.1 * bpf(noise(d), 800, 3000)) * np.sin(np.pi * t / d) ** 1.2
    return mix(fo(air), whistle * 0.35)


def swap():
    """The arrival: the Void folding him in with a reversed rush, a pop, and his cap bells ringing out."""
    d = 1.0
    t0 = 0.22
    rush = void(t0, 1200, 1.0) * 0.9
    pop = at(mix(kick(240, 80, 0.25, 0.008, 0.03, 2.2) * 0.7, lpf(noise(0.12), 2000) * env(N(0.12), 0.001, 0.02) * 0.7), t0)
    jingle = at(bells(0.75, 14, 1900, 2800, 0.6, 0.3), t0 + 0.005)
    tail_ = at(soft(void(0.6, 400, 0.05)[::-1], 40) * 0.25, t0)
    return pad(lpf(mix(soft(rush, 30), pop, jingle, fo(tail_)), 8000), d)


# ------------------------------------------------------------------ E: Brimseed
def seed():
    """The seed dropped: a soft void plop, a little wind-up of the crank, a single low tine."""
    d = 0.7
    plop = mix(kick(180, 70, 0.25, 0.012, 0.04, 1.8) * 0.6, lpf(noise(0.15), 800) * env(N(0.15), 0.002, 0.03) * 0.6)
    crank = mix(*[at(tick(1600, 0.35), 0.08 + 0.07 * k) for k in range(4)])
    note = at(tine(hz(69), 0.6, 0.28) * 0.4, 0.06)
    drone = fo(void(0.6, 300, 0.4) * 0.25)
    return pad(lpf(mix(soft(plop, 1.0), crank, note, drone), 7500), d)


def pop():
    """Brimseed popped: a deep void blast, the air sucked back in, confetti of bells."""
    d = 1.3
    blast = mix(click(0.005, 1500, 6500) * 1.4, kick(140, 38, d, 0.03, 0.12, 3.2) * 0.85,
                crack(0.5, 200, 3000, 0.04) * 2.2, sub(55, 30, 0.9, 0.2) * 0.55)
    roar = lpf(noise(0.8), 900) * env(N(0.8), 0.004, 0.18) * 1.4
    suck = at(fo(soft(void(0.35, 900, 1.0)[::-1], 30) * 0.4), 0.25)
    confetti = at(bells(0.8, 10, 1800, 2900, 0.3, 0.35), 0.05)
    return lpf(mix(soft(blast, 1.0), roar, suck, confetti), 8000)


# ------------------------------------------------------------------ passive: Swollen
def empower():
    """Swollen: the Void inflating round him with a rising swell, a hollow giggle, a bell shimmer."""
    d = 1.4; t = T(d)
    swell = (lpf(noise(d), 700) + 0.5 * S.sweep(80, 160, d)) * np.minimum(1, t / 0.6) ** 2 * np.exp(-np.maximum(0, t - 0.7) / 0.2)
    inflate = S.sweep(200, 600, 0.8, curve=0.7) * env(N(0.8), 0.2, 0.4) * 0.12
    laugh = at(giggle(4, 200, 0.08, 'eh', 0.55), 0.55)
    shimmer = at(bells(0.6, 8, 2200, 3000, 0.2, 0.4), 0.6)
    return pad(mix(soft(swell, 20), inflate, laugh, shimmer), d)


# ------------------------------------------------------------------ R: Nightwell
def well():
    """Nightwell called: the Void gathering in an implosion, a hollow drone deepening, the box's tune bent low."""
    d = 1.6; t = T(d)
    gather = mix(void(1.0, 800, 1.0) * 1.0, swoosh(1.0, 2500, 300, 1.4, 1.0, 0.6) * 0.5)
    drone = S.sweep(110, 55, d) * 0.3 * np.minimum(1, t / 0.4) * np.exp(-np.maximum(0, t - 1.1) / 0.2)
    bent = mix(*[at(tine(hz(m) * 0.5, 0.8, 0.35, 0.02) * 0.25, 0.25 + 0.22 * k) for k, m in enumerate((81, 80, 77))])
    thump = at(mix(kick(120, 40, 0.5, 0.03, 0.08, 2.4) * 0.6, sub(50, 30, 0.5, 0.12) * 0.5), 1.0)
    gather = gather * np.concatenate([np.ones(N(0.94)), np.cos(np.linspace(0, np.pi / 2, len(gather) - N(0.94))) ** 2])
    return pad(lpf(mix(soft(gather, 40), drone, bent, thump), 7500), d)


def well_hum():
    """The well opening: a heavy low snap, then a hollow humming pull that wavers and fades."""
    d = 1.8; t = T(d)
    snap_ = mix(click(0.004, 1200, 5000) * 0.9, kick(130, 40, 0.5, 0.025, 0.08, 2.6) * 0.75, sub(55, 32, 0.6, 0.14) * 0.5)
    hum = (np.sin(2 * np.pi * 73 * t) + 0.6 * np.sin(2 * np.pi * 110.5 * t) + 0.3 * np.sin(2 * np.pi * 147 * t))
    hum = S.sat(hum * (0.7 + 0.3 * np.sin(2 * np.pi * 3.2 * t)), 1.4) * 0.35 * env(N(d), 0.08, 0.7)
    pull = lpf(noise(d), 500) * (0.5 + 0.5 * np.sin(2 * np.pi * 1.6 * t)) * env(N(d), 0.1, 0.6) * 0.6
    return lpf(mix(soft(snap_, 1.0), hum, pull), 7000)


# ------------------------------------------------------------------ dash, steps
def dash():
    """A floating lurch: a soft whoosh, a small spring and a flick of the cap bells."""
    d = 0.5
    air = lpf(swoosh(0.4, 450, 1700, 1.8, 0.8, 1.3), 4500)
    boing = at(spring(0.35, 280, 0.25, 20.0, 0.07) * 0.25, 0.02)
    jingle = at(bells(0.35, 4, 2000, 2700, 0.18, 0.08), 0.05)
    return pad(mix(fo(air), boing, jingle), d)


def footstep(surface, i):
    """He floats: a soft hover pulse (a breath of the Void pushing down), the surface faintly answering
    beneath, and on some takes one cap bell."""
    d = 0.3
    puff = lpf(noise(0.18), 500) * np.sin(np.pi * np.linspace(0, 1, N(0.18))) ** 2 * 0.9
    thrum = S.sweep(95 + 4 * i, 80, 0.2) * np.sin(np.pi * np.linspace(0, 1, N(0.2))) ** 2 * 0.35
    if surface == 'grass':
        under = bpf(noise(0.2), 1200, 4000) * np.sin(np.pi * np.linspace(0, 1, N(0.2))) ** 3 * 0.2
    elif surface == 'stone':
        under = at(fo(ring((1150 + 30 * i, 1720), 0.12, (0.02, 0.012), (0.12, 0.05)), 0.4), 0.06)
    elif surface == 'wood':
        under = at(fo(ring((190 + 6 * i, 330), 0.18, (0.05, 0.03), (0.35, 0.15)), 0.4), 0.05)
    else:
        under = lpf(grains(0.2, 260, 600, 2600, 0.001, 0.003, fall=0.08), 3200) * 0.3
    out = mix(puff, thrum, under)
    if i in (1, 3):
        f = (2050, 2350)[i // 2]
        out = mix(out, at(fo(ring((f, f * 1.51), 0.18, (0.05, 0.03), (0.07, 0.03)), 0.4), 0.07))
    return fo(pad(lpf(out, 6500), d), 0.25)


# ------------------------------------------------------------------ voice: a hollow, eerie, playful man
def hurt(i):
    vowel = ('eh', 'ah', 'oh', 'eh')[i]
    d = 0.2 + 0.03 * (i % 2)
    v = S.voice(d, 210 + 15 * i, 150, vowel, breath=0.4, rasp=0.2, scale=1.0, a=0.008, decay=0.08)
    v = hollow(fo(lpf(v, 4500)))
    tag = at(giggle(2, 230, 0.07, 'ee', 0.35), d + 0.02) if i % 2 else np.zeros(1)
    jingle = at(bells(0.25, 3, 2000, 2600, 0.08, 0.05), 0.01)
    return pad(mix(v, tag, jingle), 0.5)


def down():
    v = S.voice(0.8, 220, 120, 'ah', breath=0.4, rasp=0.25, vib=0.04, scale=1.0, a=0.02, decay=0.35)
    laugh = at(giggle(3, 160, 0.11, 'uh', 0.4), 0.75)
    box = mix(*[at(tine(hz(m), 0.6, 0.25, 0.015) * 0.12, 0.3 + 0.18 * k) for k, m in enumerate((81, 77, 74))])
    return pad(mix(hollow(fo(lpf(v, 4500), 0.4)), laugh, box), 1.5)


def death():
    """A long falling cry that turns into a last giggle; the music box winds down to nothing."""
    v = S.voice(1.0, 240, 95, 'oh', breath=0.4, rasp=0.25, vib=0.05, scale=1.0, a=0.02, decay=0.45)
    laugh = at(giggle(3, 140, 0.13, 'eh', 0.35), 0.95)
    notes = ((84, 0.5, 1.0), (81, 0.8, 0.985), (80, 1.2, 0.97), (76, 1.75, 0.95))
    box = mix(*[at(tine(hz(m) * bend, 0.9, 0.4, 0.02) * 0.14, t0) for m, t0, bend in notes])
    sink = at(fo(soft(void(0.9, 300, 0.3)[::-1], 60) * 0.3), 1.2)
    return pad(mix(hollow(fo(lpf(v, 4500), 0.4)), laugh, box, sink), 2.8)


def build():
    S.takes_cat('os_orb', orb, 3, 'fire')
    S.takes_cat('os_orb_hot', orb_hot, 3, 'fire')
    S.save_cat('os_prime', prime(), 'cast')
    S.save_cat('ostra_music_box', music_box(), 'signature')
    S.save_cat('ostra_spring_boing', spring_boing(), 'signature')
    S.save_cat('os_snap_wind', snap_wind(), 'cast')
    S.save_cat('os_snap', snap(), 'cast')
    S.save_cat('os_snap_hit', snap_hit(), 'impact')
    S.save_cat('os_swap_lob', swap_lob(), 'cast')
    S.save_cat('os_swap', swap(), 'impact')
    S.save_cat('os_seed', seed(), 'cast')
    S.save_cat('os_pop', pop(), 'impact')
    S.save_cat('os_empower', empower(), 'cast')
    S.save_cat('os_well', well(), 'cast')
    S.save_cat('os_well_hum', well_hum(), 'impact')
    S.save_cat('ostra_dash', dash(), 'dash')
    for surf in ('grass', 'stone', 'wood', 'snow'):
        S.takes_cat('ostra_step_' + surf, lambda i, s=surf: footstep(s, i), 3, 'step')
    S.takes_cat('ostra_hurt', hurt, 3, 'grunt')
    S.save_cat('ostra_down', down(), 'grunt')
    S.save_cat('ostra_death', death(), 'grunt')


if __name__ == '__main__':
    build()
    print('gen_sfx_motley: done')
