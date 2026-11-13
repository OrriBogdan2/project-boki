"""Breaker the Barnacle Knight (bulwark): every sound his kit plays, synthesised and levelled (docs/AUDIO.md).

    cd tools && python3 gen_sfx_breaker.py      (then: godot --headless --import)

Breaker is a drowned ferryman remade by the frozen sea into a sea-ogre half again a Hunter's size: a
ship's iron-banded prow for a shield, a barnacled iron hammer, heavy sea boots. His palette is old wet
timber under strain, barnacled iron, a ship's bell and the sea itself (swell, bubbles). His voice is a
huge man's, deep and warm, with a wet gurgle under the bad moments (he went down with his ship).

  bjorn_throw (fire, 3 takes)   the hammer hurled overhand: effort, a heavy tumbling whoosh
  bulwark_hammer_clang (3)      SIGNATURE: the barnacled hammer striking a foe on its way out or back
  bulwark_hull_creak            SIGNATURE: the prow's old timbers groaning as the shield comes up
  bjorn_recall / bjorn_catch    the hammer called back (a hauling whirr) / slapping into his palm
  bjorn_plant                   the hammer biting into the ground where it lands
  bjorn_spin (3) / bjorn_glint  the Crushing Blow's wind-up turns / the full charge's ship's-bell ding
  bjorn_slam (3)                the Crushing Blow landing
  bjorn_shield_up / bjorn_block (3) / bjorn_break   the prow raised / a shot thudding into it / it splitting
  bjorn_bash                    the prow rammed into foes (push hint, Shield Slam)
  bulwark_charge                Shield Charge: the prow driven forward like a ram, the hull groaning
  bulwark_dash / bjorn_whirl    the 360 Smash's lunge / its spin landing all round him
  bjorn_purify / _burst         Mending Ground: a bell toll and a rising sea glow / the healing wave breaking
  bjorn_ult_wind/_slam/_rumble/_crackle   Faultline: the hull-groaning wind-up, the slam, the lane erupting,
                                the scar's crackle
  bulwark_step_<surface>        heavy sea boots, iron bands and a rattle of shells (3 takes each)
  bulwark_hurt/down/death       wordless voice

It also writes the kit's bjorn_* files (content/sfx/bulwark.json lists them under "replaces"). Original synthesis, no samples.
"""
import os, sys
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import sfx_lib as S
from sfx_lib import (N, T, noise, lpf, hpf, bpf, env, mix, at, kick, click, crack, sub, tail,
                     reflections, ring, grains, pad)

S.reseed(7411)


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


def fo(x, frac=0.35):
    """A raised-cosine fade over the last `frac` of a layer, so no layer stops on an edge mid-sound."""
    k = max(1, int(len(x) * frac))
    x = x.copy(); x[-k:] *= 0.5 + 0.5 * np.cos(np.pi * np.arange(k) / k)
    return x


def iron(f, d, g=1.0, decay=0.25):
    """Barnacled iron struck: inharmonic partials (a thick bar), the high ones dying first, a little grit."""
    parts = (1.0, 2.41, 3.93, 5.6, 7.7)
    gains = (0.55, 0.4, 0.25, 0.14, 0.06)
    tone = ring(tuple(f * p for p in parts), d, tuple(decay / p ** 0.7 for p in parts), gains)
    return fo(tone, 0.3) * g


def timber(f, d, g=1.0, decay=0.06):
    """A thick plank knocked: a few low hollow modes and a dull band of noise."""
    body = ring((f, f * 1.73, f * 2.6), d, (decay, decay * 0.7, decay * 0.45), (0.6, 0.35, 0.18))
    knock = bpf(noise(d), f * 0.8, f * 5) * env(N(d), 0.0008, decay * 0.5) * 1.4
    return fo(body + knock, 0.3) * g


def groan(d, f0, f1, wob=0.08, bright=900):
    """A hull's slow low groan: a filtered saw under a stick-slip creak, wobbling as the wood flexes."""
    t = T(d)
    f = f0 * (f1 / f0) ** (t / d) * (1 + wob * np.sin(2 * np.pi * 2.3 * t) + 0.5 * wob * np.sin(2 * np.pi * 5.1 * t))
    saw = 2.0 * ((np.cumsum(f) / S.SR) % 1.0) - 1.0
    body = bpf(saw, 70, bright) * 0.5
    return S.sat(body, 1.6)


def bubbles(d, per_s, f_lo=250, f_hi=900, size=0.04):
    """Rising air bubbles: short sines that chirp upward as they pop (water around a drowned thing)."""
    n = N(d); out = np.zeros(n)
    for _ in range(max(1, int(per_s * d))):
        s0 = int(S.rng.uniform(0, max(1, n - N(size * 1.5))))
        bd = size * S.rng.uniform(0.6, 1.4); bn = N(bd); tt = np.arange(bn) / S.SR
        f = S.rng.uniform(f_lo, f_hi) * (1 + 2.5 * tt / bd)
        b = np.sin(2 * np.pi * np.cumsum(f) / S.SR) * np.exp(-tt / (bd * 0.35)) * (1 - tt / bd)
        b *= np.sin(np.pi * np.minimum(1, tt / 0.003) / 2)
        out[s0:s0 + bn] += b * S.rng.uniform(0.4, 1.0)
    return out


def swell(d, lp=700, rate=0.8):
    """Sea water heaving: low noise with a slow rise and fall."""
    t = T(d)
    return lpf(noise(d), lp) * (0.55 + 0.45 * np.sin(2 * np.pi * rate * t - 1.2)) * 1.4


def grit(d, g=1.0, fall=0.03):
    """Barnacles and shells rattling off a struck surface."""
    return lpf(grains(d, 220, 1800, 6000, 0.001, 0.004, fall=fall), 6500) * g


# ------------------------------------------------------------------ signatures
def hull_creak():
    """The prow's old timbers taking the strain: a slow wooden groan, stick-slip creaks, water draining off."""
    d = 1.1; t = T(d)
    shape = np.minimum(1, t / 0.12) ** 1.5 * np.exp(-np.maximum(0, t - 0.45) / 0.28)
    g1 = groan(d, 62, 48, 0.09, 800) * shape * 0.9
    c1 = S.creak(0.8, 38, 22, 0.7, 1800) * 1.6
    c2 = at(S.creak(0.5, 70, 50, 0.5, 2600) * 0.9, 0.42)
    band = at(iron(410, 0.4, 0.12, 0.12), 0.05)
    drip = at(fo(lpf(grains(0.6, 25, 600, 2200, 0.004, 0.012, fall=0.25), 3000) * 0.5), 0.3)
    return pad(mix(soft(g1, 20), fo(c1, 0.3), fo(c2, 0.4), band, drip, swell(d, 400, 0.6) * 0.18 * shape), d)


def hammer_clang(i):
    """The barnacled hammer striking: a hard iron clang over a heavy thud, shells scattering."""
    d = 0.7
    f = (282, 301, 268, 315)[i]
    hit = mix(click(0.003, 1800, 6500) * 1.4, kick(180 + 10 * i, 62, 0.35, 0.012, 0.045, 2.6) * 0.8,
              crack(0.2, 250, 2200, 0.02) * 1.6)
    clang = at(iron(f, d, 1.0, 0.32), 0.001)
    return lpf(mix(soft(hit, 0.8), clang, grit(0.25, 0.5), sub(70, 46, 0.4, 0.08) * 0.4), 8000)


# ------------------------------------------------------------------ LMB: the hammer thrown and called back
def throw(i):
    """The overhand hurl: a grunt of effort, the heavy head tumbling through the air, the haft creaking."""
    d = 0.5
    effort = lpf(S.voice(0.16, 105 + 4 * i, 82, 'uh', breath=0.5, rasp=0.35, scale=0.8, a=0.01, decay=0.06), 3000) * 0.3
    air = at(swoosh(0.42, 180 + 15 * i, 1300, 1.6, 0.7, 1.2), 0.03)
    # the tumble: the whoosh pulsing as the head comes round about 9 times a second
    tum = at(swoosh(0.4, 300, 900, 3.0) * (0.5 + 0.5 * np.sin(2 * np.pi * (8.5 + i) * T(0.4))) * 0.7, 0.06)
    haft = at(S.creak(0.12, 80, 60, 0.4, 1600) * 0.5, 0.0)
    push = kick(110, 60, 0.2, 0.02, 0.05, 1.8) * 0.4
    return lpf(mix(soft(effort, 6), fo(air), fo(tum), haft, soft(push, 2)), 7500)


def recall():
    """The hammer called home: a hauling whirr climbing as it comes, a chain's rattle and a low pull."""
    d = 0.55; t = T(d)
    whirr = swoosh(d, 250, 1500, 2.6, 1.0, 0.9) * (0.6 + 0.4 * np.sin(2 * np.pi * 14 * t)) * 0.9
    pull = groan(d, 50, 85, 0.05, 500) * np.minimum(1, t / 0.15) * 0.4
    rattle = lpf(S.rattle(d, 30, 1500, 3800, decay=0.25), 5000) * 0.25
    return mix(fo(whirr, 0.25), fo(soft(pull, 15)), rattle)


def catch():
    """The haft slapping into his palm: a meaty leather smack and the head's short iron ring."""
    d = 0.4
    smack = mix(kick(160, 80, 0.15, 0.008, 0.025, 2.0) * 0.7, bpf(noise(0.12), 300, 2200) * env(N(0.12), 0.0006, 0.02) * 1.5)
    head = at(iron(340, 0.35, 0.35, 0.14), 0.01)
    return pad(lpf(mix(soft(smack, 0.8), head, grit(0.12, 0.2, 0.015)), 7000), d)


def plant():
    """The hammer biting into the ground: a deep thud, earth thrown up, the head ringing and settling."""
    d = 0.95
    thud = mix(click(0.004, 1500, 6000) * 1.2, kick(120, 40, d, 0.02, 0.09, 3.0) * 0.85,
               crack(0.4, 150, 1600, 0.05) * 1.8, sub(60, 36, 0.6, 0.12) * 0.5)
    dirt = lpf(grains(0.5, 120, 600, 3500, 0.002, 0.008, fall=0.12), 4000) * 0.6
    head = at(iron(262, 0.9, 0.45, 0.4), 0.004)
    settle = at(timber(140, 0.3, 0.3, 0.05), 0.12)
    return lpf(mix(soft(thud, 1.0), dirt, head, settle), 8000)


# ------------------------------------------------------------------ LMB hold: the Crushing Blow
def spin(i):
    """One turn of the wind-up: a heavy, low whoosh as the head comes round."""
    d = 0.42
    air = swoosh(d, 140 + 10 * i, 900 + 60 * i, 1.8, 1.0, 1.3)
    hum = swoosh(d, 90, 260, 4.0, 1.0, 2.0) * 0.6
    return fo(lpf(mix(air, hum), 5000), 0.3)


def glint():
    """Full charge: a ship's bell rung once, bright over a soft swell."""
    d = 1.1
    bell = S.chime(1046, d, 0.45, ((1.0, 1.0), (2.0, 0.35), (2.4, 0.3), (3.0, 0.12), (4.2, 0.08)))
    hum = S.chime(523, d, 0.6, ((1.0, 0.5), (2.0, 0.15))) * 0.4
    tick = click(0.002, 3000, 8000) * 0.4
    return mix(soft(tick, 0.3), bell, hum)


def slam(i):
    """The Crushing Blow landing: a huge iron-and-earth impact, splinters and shells flying, the head ringing."""
    d = 1.3
    hit = mix(click(0.006, 1400, 7000) * 1.8, kick(130 + 8 * i, 34, d, 0.035, 0.13, 3.4) * 0.9,
              crack(0.6, 160, 2600, 0.06) * 2.6, sub(55, 30, d, 0.28) * 0.6)
    clang = at(iron(230 + 12 * i, 1.0, 0.55, 0.45), 0.003)
    rubble = lpf(grains(1.0, 110, 700, 4500, 0.002, 0.01, fall=0.25), 5000) * 0.9
    splinter = at(lpf(grains(0.35, 300, 1500, 5000, 0.001, 0.004, fall=0.06), 6000) * 0.5, 0.01)
    room = reflections(tail(0.9, 800, 0.25, 0.01) * 0.9, ((0.07, 0.35, 700), (0.15, 0.25, 550), (0.26, 0.14, 450)))
    return lpf(mix(soft(hit, 1.0), clang, rubble, splinter, room), 8000)


# ------------------------------------------------------------------ RMB: the prow shield
def shield_up():
    """The prow swung round in front of him: a heavy wooden thump and its iron bands clanking."""
    d = 0.6
    swing = swoosh(0.25, 150, 700, 1.4) * 0.6
    thump = at(mix(kick(110, 55, 0.4, 0.02, 0.07, 2.4) * 0.8, timber(120, 0.35, 0.8, 0.07)), 0.16)
    bands = at(mix(iron(520, 0.4, 0.35, 0.12), at(iron(610, 0.3, 0.22, 0.09), 0.05)), 0.17)
    return pad(lpf(mix(fo(swing), soft(thump, 1.0), bands), 7500), d)


def block(i):
    """A shot thudding into the prow: thick wet timber, an iron band's ping, water shaken off."""
    d = 0.45
    wood = mix(click(0.003, 1500, 5500) * 0.9, timber(150 + 12 * i, d, 1.0, 0.07), kick(170, 70, 0.25, 0.01, 0.03, 2.2) * 0.5)
    band = iron(700 + 40 * i, 0.4, 0.3 if i % 2 else 0.18, 0.1)
    spray = fo(lpf(grains(0.2, 90, 900, 3500, 0.002, 0.006, fall=0.05), 4000) * 0.35)
    return lpf(mix(soft(wood, 0.8), band, at(spray, 0.01)), 7500)


def shield_break():
    """The prow splitting: a hard crack, planks tearing, iron bands snapping, the pieces thudding down."""
    d = 1.3
    crk = mix(click(0.005, 1500, 7000) * 1.6, crack(0.5, 300, 4000, 0.04) * 2.6, kick(140, 45, 0.8, 0.02, 0.1, 3.0) * 0.8)
    tear = at(S.creak(0.35, 140, 60, 0.9, 3200) * 2.0, 0.02)
    splinters = lpf(grains(0.9, 260, 1200, 5500, 0.001, 0.006, fall=0.18), 6500) * 0.8
    snap = mix(at(iron(480, 0.6, 0.4, 0.15), 0.03), at(iron(655, 0.5, 0.3, 0.12), 0.09))
    falls = mix(at(timber(110, 0.35, 0.6, 0.06), 0.42), at(timber(135, 0.35, 0.45, 0.05), 0.6))
    return lpf(mix(soft(crk, 1.0), fo(tear), splinters, snap, falls, sub(58, 34, 0.7, 0.14) * 0.5), 8000)


def bash():
    """The prow rammed into foes: a booming wooden slam, the iron bands rattling, the push of air."""
    d = 0.7
    hit = mix(click(0.004, 1500, 6000) * 1.2, kick(120, 45, d, 0.02, 0.08, 3.0) * 0.85,
              timber(105, 0.5, 1.2, 0.08), crack(0.3, 200, 1800, 0.035) * 1.6)
    bands = at(iron(560, 0.5, 0.3, 0.12), 0.005)
    air = swoosh(0.35, 1400, 300, 1.4) * 0.35
    return lpf(mix(soft(hit, 1.0), bands, fo(air), sub(62, 38, 0.5, 0.1) * 0.45), 7500)


def shield_charge():
    """Shield Charge: the hull groans as he drives in behind it, the boots pound, a roar of effort."""
    d = 0.9; t = T(d)
    hull = groan(d, 55, 75, 0.12, 700) * np.minimum(1, t / 0.08) * np.exp(-np.maximum(0, t - 0.4) / 0.2) * 0.9
    creak = S.creak(0.6, 45, 30, 0.6, 2000) * 1.2
    rush = swoosh(0.7, 200, 1100, 1.2, 0.8, 1.0) * 0.8
    roar = at(lpf(S.voice(0.45, 95, 80, 'ah', breath=0.4, rasp=0.5, scale=0.78, a=0.03, decay=0.2), 3000) * 0.35, 0.02)
    boots = mix(*[at(kick(95, 50, 0.15, 0.015, 0.03, 2.0) * 0.5, k * 0.17) for k in range(4)])
    rattle = lpf(S.rattle(0.6, 35, 1500, 3800, decay=0.3), 5000) * 0.25
    return lpf(mix(soft(hull, 15), fo(creak), fo(rush), roar, boots, rattle), 7000)


# ------------------------------------------------------------------ Shift: 360 Smash
def dash():
    """The lunge: a big body heaving forward, a heavy boot push-off and the gear swinging."""
    d = 0.5
    push = kick(90, 45, 0.25, 0.02, 0.05, 2.2) * 0.7
    air = swoosh(0.45, 220, 1100, 1.4, 0.7, 1.2)
    gear = at(mix(iron(480, 0.25, 0.15, 0.08), lpf(S.rattle(0.2, 50, 1600, 4000, decay=0.07), 5000) * 0.3), 0.04)
    huff = at(lpf(S.voice(0.14, 100, 85, 'uh', breath=0.7, rasp=0.2, scale=0.8, a=0.01, decay=0.05), 2500) * 0.2, 0.02)
    return lpf(mix(soft(push, 2), fo(air), gear, huff), 7000)


def whirl():
    """The 360 Smash landing: the hammer swept all the way round, a booming hit and the head's ring."""
    d = 1.0
    sweep_air = swoosh(0.32, 180, 1500, 1.6, 1.0, 1.0) * 0.9
    hit = at(mix(click(0.005, 1500, 6500) * 1.3, kick(130, 42, 0.7, 0.025, 0.09, 3.0) * 0.85,
                 crack(0.4, 200, 2200, 0.04) * 2.0, sub(60, 36, 0.6, 0.12) * 0.5), 0.24)
    clang = at(iron(300, 0.7, 0.4, 0.3), 0.245)
    dirt = at(lpf(grains(0.5, 100, 700, 3500, 0.002, 0.008, fall=0.12), 4000) * 0.6, 0.25)
    return pad(lpf(mix(fo(sweep_air, 0.2), hit, clang, dirt), 8000), d)


# ------------------------------------------------------------------ E: Mending Ground
def purify():
    """Mending Ground called down: a deep bell toll, the sea glowing up in a slow rising chord."""
    d = 1.5; t = T(d)
    toll = S.chime(196, d, 0.9, ((1.0, 1.0), (2.0, 0.5), (2.4, 0.35), (3.0, 0.2), (4.1, 0.1)))
    chord = sum(S.sweep(f * 0.98, f, d) * g for f, g in ((392, 0.25), (494, 0.2), (587, 0.18), (784, 0.1)))
    chord = chord * np.minimum(1, t / 0.6) ** 2 * np.exp(-np.maximum(0, t - 0.9) / 0.3)
    shimmer = bpf(noise(d), 2500, 6000) * np.minimum(1, t / 0.8) * np.exp(-np.maximum(0, t - 0.9) / 0.25) * 0.06
    sea = swell(d, 500, 0.7) * 0.25 * np.exp(-t / 0.9)
    rise = bubbles(d, 14, 400, 1100, 0.05) * 0.18
    return mix(toll * 0.8, chord, shimmer, sea, rise)


def purify_burst():
    """The zone's last burst: a wave breaking outward, a bright bell chord blooming over it."""
    d = 1.6; t = T(d)
    wave = mix(kick(100, 45, 0.6, 0.03, 0.08, 2.0) * 0.5,
               swoosh(1.1, 300, 2600, 0.9, 0.6, 2.2) * 1.4,
               lpf(noise(d), 1200) * env(N(d), 0.04, 0.35) * 1.0)
    spray = lpf(grains(1.0, 160, 1200, 4500, 0.002, 0.006, fall=0.3), 5000) * 0.6
    bells = mix(at(S.chime(784, 1.2, 0.4) * 0.45, 0.04), at(S.chime(988, 1.2, 0.4) * 0.4, 0.09),
                at(S.chime(1175, 1.3, 0.45) * 0.4, 0.14))
    return lpf(mix(soft(wave, 3), spray, bells, bubbles(1.0, 20, 300, 900, 0.05) * 0.2), 8500)


# ------------------------------------------------------------------ R: Faultline
def ult_wind():
    """He lifts the hammer high: the whole hull groaning, water pouring off, a rising surge."""
    d = 0.9; t = T(d)
    hull = groan(d, 45, 70, 0.1, 700) * np.minimum(1, t / 0.2) * 0.9
    creak = S.creak(0.85, 30, 55, 0.7, 2200) * 1.4
    surge = swoosh(d, 120, 900, 1.2, 1.4, 0.8) * 0.8
    pour = lpf(grains(d, 60, 500, 2500, 0.004, 0.015), 3000) * np.minimum(1, t / 0.3) * 0.5
    voice = at(lpf(S.voice(0.6, 82, 100, 'oh', breath=0.35, rasp=0.45, scale=0.78, a=0.06, decay=0.4), 2800) * 0.3, 0.2)
    out = mix(soft(hull, 20), fo(creak), surge, pour, voice)
    return fo(out, 0.12)


def ult_slam():
    """Faultline's slam: the biggest hit he has, iron, rock and a sub drop that shakes the ground."""
    d = 1.8
    hit = mix(click(0.006, 1200, 6500) * 2.0, kick(110, 28, d, 0.05, 0.18, 3.6) * 0.95,
              crack(0.9, 120, 2400, 0.09) * 3.0, sub(50, 26, d, 0.4) * 0.75)
    clang = at(iron(196, 1.4, 0.55, 0.55), 0.004)
    rock = lpf(grains(1.4, 120, 500, 3500, 0.003, 0.012, fall=0.35), 4000) * 1.0
    room = reflections(tail(1.4, 700, 0.35, 0.02) * 1.0, ((0.1, 0.4, 600), (0.22, 0.3, 500), (0.38, 0.18, 400)))
    return lpf(mix(soft(hit, 1.0), clang, rock, room), 7500)


def ult_rumble():
    """The lane erupting: a rolling rumble moving away, rocks popping up along it."""
    d = 1.8; t = T(d)
    roll = lpf(noise(d), 350) * np.minimum(1, t / 0.1) * np.exp(-t / 0.7) * 2.2
    grind = bpf(noise(d), 200, 1100) * (0.6 + 0.4 * np.sin(2 * np.pi * 9 * t)) * np.exp(-t / 0.5) * 0.7
    pops = mix(*[at(mix(kick(140, 55, 0.25, 0.012, 0.04, 2.4) * 0.5, crack(0.15, 300, 2400, 0.02) * 0.9) * (0.9 - 0.12 * k),
                    0.05 + 0.16 * k) for k in range(6)])
    debris = lpf(grains(d, 50, 800, 4000, 0.002, 0.01, fall=0.6), 4500) * 0.6
    return lpf(mix(soft(roll, 15), grind, pops, debris, sub(45, 30, d, 0.5) * 0.4), 7000)


def ult_crackle():
    """The scar still settling: a few stones cracking and a low grind."""
    d = 0.8; t = T(d)
    crk = lpf(grains(0.6, 40, 700, 3500, 0.002, 0.008), 4000) * 1.1
    bed = lpf(noise(d), 300) * np.sin(np.pi * t / d) ** 1.5 * 0.5
    return mix(crk, bed)


# ------------------------------------------------------------------ footsteps
def footstep(surface, i):
    """A huge sea boot: a deep heel thud, the surface's texture, the prow's iron bands and shells rattling."""
    if surface == 'grass':
        body = kick(85 + 4 * i, 42, 0.25, 0.015, 0.05, 2.2) * 0.8
        tex = mix(lpf(grains(0.18, 420, 600, 3200, 0.001, 0.005, fall=0.05), 4000) * 0.7,
                  fo(bpf(noise(0.18), 250, 1500) * env(N(0.18), 0.003, 0.04)) * 0.8)
    elif surface == 'stone':
        body = kick(100 + 4 * i, 48, 0.22, 0.012, 0.04, 2.4) * 0.8
        tex = mix(click(0.003, 1200, 4500) * 0.8, crack(0.08, 500, 3000, 0.012) * 1.1,
                  lpf(grains(0.08, 240, 1500, 5000, 0.001, 0.003, fall=0.02), 6000) * 0.35)
    elif surface == 'wood':
        body = kick(95 + 4 * i, 48, 0.25, 0.012, 0.045, 2.2) * 0.7
        tex = mix(click(0.002, 1200, 4000) * 0.5, fo(timber(118 + 6 * i, 0.25, 0.9, 0.06), 0.4),
                  at(S.creak(0.14, 90, 70, 0.4, 1400) * 0.35, 0.05))
    else:
        body = lpf(kick(80 + 4 * i, 40, 0.25, 0.015, 0.05, 1.8), 700) * 0.75
        tex = mix(lpf(grains(0.24, 700, 700, 3000, 0.001, 0.004, fall=0.07), 4000) * 0.75,
                  fo(lpf(noise(0.22), 1000) * env(N(0.22), 0.008, 0.06)) * 0.7)
    out = mix(soft(body, 1.5), tex, sub(55, 40, 0.18, 0.04) * 0.35)
    # the gear on his back: an iron band knocking on every step, shells rattling on some
    out = mix(out, at(iron(560 + 25 * i, 0.22, 0.07, 0.07), 0.035 + 0.006 * i))
    if i in (1, 3):
        out = mix(out, at(lpf(S.rattle(0.12, 45, 1600, 3800, decay=0.04), 4500) * 0.12, 0.03))
    return fo(lpf(pad(out, 0.34), 6500), 0.25)


# ------------------------------------------------------------------ voice: a huge, warm, drowned man
def hurt(i):
    vowel = ('uh', 'ah', 'oh', 'uh')[i]
    d = 0.26 + 0.03 * (i % 2)
    v = S.voice(d, 112 + 6 * i, 84, vowel, breath=0.3, rasp=0.4, scale=0.8, a=0.01, decay=0.12)
    chest = kick(80, 50, 0.15, 0.02, 0.04, 1.6) * 0.15
    gurgle = at(bubbles(0.18, 30, 200, 600, 0.03) * 0.08, d * 0.6) if i % 2 == 0 else np.zeros(1)
    return pad(mix(fo(lpf(v, 4000)), soft(chest, 3), gurgle), 0.5)


def down():
    v = S.voice(1.0, 105, 62, 'oh', breath=0.35, rasp=0.55, vib=0.02, scale=0.8, a=0.03, decay=0.45)
    gurgle = at(bubbles(0.6, 35, 180, 520, 0.04) * 0.12, 0.55)
    creak = at(S.creak(0.7, 35, 25, 0.6, 1500) * 0.45, 0.3)
    thud = at(mix(kick(90, 38, 0.4, 0.02, 0.08, 2.4) * 0.4, iron(470, 0.4, 0.08, 0.12)), 0.7)
    return pad(mix(fo(lpf(v, 4000), 0.4), gurgle, fo(creak), thud), 1.5)


def death():
    v = S.voice(1.4, 100, 52, 'ah', breath=0.4, rasp=0.5, vib=0.025, scale=0.78, a=0.03, decay=0.6)
    sink = at(fo(groan(1.2, 50, 34, 0.08, 500) * env(N(1.2), 0.2, 0.5) * 0.4, 0.4), 0.5)
    gurgle = at(bubbles(1.2, 28, 160, 500, 0.05) * 0.16, 0.9)
    bell = at(S.chime(392, 1.4, 0.7, ((1.0, 1.0), (2.4, 0.3), (3.0, 0.15))) * 0.07, 1.1)
    return pad(mix(fo(lpf(v, 4000), 0.4), sink, gurgle, bell), 2.6)


# ------------------------------------------------------------------ added 11-09 (kept last: the older takes stay identical)
def boop():
    """The aegis thrust landing: a short hollow wooden knock, a quick iron tick and a puff of air. Small and punchy."""
    d = 0.32
    knock = mix(click(0.003, 1800, 6500) * 1.0, kick(170, 70, d, 0.01, 0.045, 2.6) * 0.8, timber(150, 0.25, 1.4, 0.05))
    tick = at(iron(720, 0.2, 0.25, 0.06), 0.003)
    puff = swoosh(0.16, 1800, 500, 1.6) * 0.3
    return pad(lpf(mix(soft(knock, 0.9), tick, fo(puff)), 7500), d)


def reel():
    """The rope hauling the hammer home on its own: the line snapping taut, then a fast ratcheting whirr."""
    d = 0.6; t = T(d)
    snap = mix(click(0.003, 1200, 5000) * 0.9, crack(0.08, 600, 3200, 0.012) * 1.2)
    ratchet = mix(*[at(click(0.002, 2000, 6000) * (0.5 - 0.02 * k), 0.06 + 0.035 * k) for k in range(14)])
    whirr = swoosh(d, 300, 1600, 2.4, 1.0, 0.9) * (0.6 + 0.4 * np.sin(2 * np.pi * 18 * t)) * 0.7
    return lpf(mix(snap, ratchet, fo(whirr, 0.2)), 7000)


def ult_quake():
    """Faultline's landing under the slam: a sub-heavy boom that drops the floor out, then the ground settling."""
    d = 1.6
    boom = mix(kick(80, 22, d, 0.06, 0.25, 4.0) * 1.0, sub(42, 22, d, 0.6) * 0.9)
    thump = crack(0.5, 80, 900, 0.07) * 1.6
    settle = at(lpf(grains(1.1, 60, 300, 1800, 0.004, 0.016, fall=0.5), 2200) * 0.7, 0.08)
    return lpf(mix(soft(boom, 1.2), thump, settle), 3200)


def build():
    S.takes_cat('bjorn_throw', throw, 3, 'fire')
    S.takes_cat('bulwark_hammer_clang', hammer_clang, 3, 'signature')
    S.save_cat('bulwark_hull_creak', hull_creak(), 'signature')
    S.save_cat('bjorn_recall', recall(), 'cast')
    S.save_cat('bjorn_catch', catch(), 'cast')
    S.save_cat('bjorn_plant', plant(), 'impact')
    S.takes_cat('bjorn_spin', spin, 3, 'cast')
    S.save_cat('bjorn_glint', glint(), 'cast')
    S.takes_cat('bjorn_slam', slam, 3, 'impact')
    S.save_cat('bjorn_shield_up', shield_up(), 'cast')
    S.takes_cat('bjorn_block', block, 3, 'impact')
    S.save_cat('bjorn_break', shield_break(), 'impact')
    S.save_cat('bjorn_bash', bash(), 'impact')
    S.save_cat('bulwark_charge', shield_charge(), 'cast')
    S.save_cat('bulwark_dash', dash(), 'dash')
    S.save_cat('bjorn_whirl', whirl(), 'impact')
    S.save_cat('bjorn_purify', purify(), 'cast')
    S.save_cat('bjorn_purify_burst', purify_burst(), 'impact')
    S.save_cat('bjorn_ult_wind', ult_wind(), 'cast')
    S.save_cat('bjorn_ult_slam', ult_slam(), 'impact')
    S.save_cat('bjorn_ult_rumble', ult_rumble(), 'impact')
    S.save_cat('bjorn_ult_crackle', ult_crackle(), 'loop')
    for surf in ('grass', 'stone', 'wood', 'snow'):
        S.takes_cat('bulwark_step_' + surf, lambda i, s=surf: footstep(s, i), 3, 'step')
    S.takes_cat('bulwark_hurt', hurt, 3, 'grunt')
    S.save_cat('bulwark_down', down(), 'grunt')
    S.save_cat('bulwark_death', death(), 'grunt')
    S.save_cat('bjorn_boop', boop(), 'impact')
    S.save_cat('bjorn_reel', reel(), 'cast')
    S.save_cat('bjorn_ult_quake', ult_quake(), 'impact')


if __name__ == '__main__':
    build()
    print('gen_sfx_breaker: done')
