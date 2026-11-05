"""Claire the Frost Siren (rimewright): every sound her kit plays, synthesised and levelled (docs/AUDIO.md).

    cd tools && python3 gen_sfx_claire.py      (then: godot --headless --import)

Claire was the star skater of the winter canal festival; the frost took her the night the ice broke.
She fights on skates over her own ice path with a fan of ice darts. Her palette is steel blades on ice
(the long singing scrape, the bite of a push-off, a hockey stop's spray), glassy crystal (chimes,
shards, a shattering shell) and deep lake ice under strain (creaks, groans, cracks). Her voice is a
woman's, sweet and breathy, with something cold and inhuman under it (a frosted whisper, a low shadow
under the death cry).

  rime_shard (fire, 3 takes)    a fan dart flicked out: a crisp icy flick and a glassy tick
  rime_beam (fire, 3 takes)     the straight thick dart she throws while skating
  rimewright_skate_scrape (3)   SIGNATURE: one skating stride, the blade carving and singing on the ice
  rimewright_ice_chime          SIGNATURE: crystals ringing as ice closes (the 8-dart shell, the wall frozen)
  rime_run / rime_stop          the skate's push-off / the hard stop and its spray
  rime_spear_aim / rime_lance   the spear forming in her hands / pushed off on its way
  rime_wall_tell                frost gathering (the wall's tell, under the spear's push)
  rime_zone / rime_burst        the spear landing in spikes / its detonation
  rime_splinter                 a Shatter: glass bursting outward
  rime_wall / rime_freeze       the ice wall grinding up / frozen solid
  rime_lock / rime_creak (3)    Rimelock: encased in ice / the ice straining while it holds
  rime_crash / rime_crack       Rimelock broken out at full / cancelled early
  rimewright_dash               a skater's glide: blade bite and a swish
  rimewright_step_<surface>     a light step and the faint click of a skate blade (3 takes each)
  rimewright_hurt/down/death    wordless voice

The rime_* files were first written by tools/gen_care_sfx.py; this script replaces them (content/sfx/
rimewright.json lists them under "replaces"). Original synthesis, no samples.
"""
import os, sys
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import sfx_lib as S
from sfx_lib import (N, T, noise, lpf, hpf, bpf, env, mix, at, kick, click, crack, sub, tail,
                     reflections, ring, grains, pad)

S.reseed(3917)


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


def crystal(f, d=0.6, g=1.0, decay=0.25):
    """A glassy crystal struck: bright inharmonic partials, the upper ones dying fast."""
    parts = (1.0, 2.32, 3.81, 5.3)
    tone = ring(tuple(f * p for p in parts), d, tuple(decay / p ** 0.8 for p in parts), (0.6, 0.3, 0.14, 0.06))
    return fo(lpf(tone, 7000), 0.3) * g


def shards(d, per_s=300, fall=0.12, g=1.0, lo=1800, hi=5500):
    """Ice splinters skittering: many tiny glassy grains thinning out."""
    return lpf(grains(d, per_s, lo, hi, 0.001, 0.004, fall=fall), 6500) * g


def blade(d, f=2100, g=1.0, shape=None):
    """A steel blade on ice: a narrow singing band over a grainy scrape, swelling and fading."""
    t = T(d)
    sing = bpf(noise(d), f * 0.94, f * 1.06) * 2.2
    scrape = bpf(noise(d), 500, 3500) * (0.7 + 0.3 * np.abs(S.rng.standard_normal(N(d))))
    grit = lpf(grains(d, 140, 1500, 4500, 0.001, 0.003), 5000) * 0.4
    sh = shape if shape is not None else np.sin(np.pi * t / d) ** 1.4
    return lpf(sing + scrape + grit, 6500) * sh * g


def ice_creak(d, f0=70, f1=45, bright=1800, g=1.0):
    """Lake ice under strain: a deep stick-slip creak with a cold, hollow ring."""
    c = S.creak(d, f0, f1, 0.6, bright) * 1.5
    hollow = bpf(noise(d), 350, 800) * env(N(d), 0.05, d * 0.4) * 0.3
    return fo(mix(c, hollow), 0.3) * g


def frost(d, a=0.05, decay=0.2, g=1.0):
    """Frost forming: a soft high hiss with fine crackle."""
    return (lpf(S.hiss(d, 2500, 6000, a, decay), 6500) * 0.5
            + lpf(grains(d, 120, 2500, 5500, 0.0008, 0.002), 6000) * 0.3 * env(N(d), a, decay)) * g


# ------------------------------------------------------------------ LMB: the fan's darts
def shard(i):
    """A fan dart: a quick flick of the wrist, a crisp ice tick and a breath of frost."""
    d = 0.35
    flick = lpf(swoosh(0.18, 1200, 3800, 2.4, 0.8, 1.2), 5500) * 0.5
    tick = at(crystal((2350, 2620, 2480, 2790)[i], 0.25, 0.45, 0.06), 0.008)
    snap = mix(click(0.002, 2500, 6000) * 0.6, kick(420, 220, 0.06, 0.004, 0.01, 1.4) * 0.3)
    return pad(mix(soft(snap, 0.5), fo(flick), tick, at(frost(0.2, 0.01, 0.06, 0.35), 0.02)), d)


def beam(i):
    """The skating dart: straighter and heavier, a whistling zing over a little low thump."""
    d = 0.45
    zing = (S.sweep(1900 + 80 * i, 1450, 0.3) * env(N(0.3), 0.004, 0.09) * 0.25)
    air = lpf(swoosh(0.28, 900, 3200, 2.2, 0.8, 1.2), 5500) * 0.6
    thump = kick(260, 120, 0.12, 0.008, 0.025, 1.8) * 0.45
    tick = at(crystal(1980 + 70 * i, 0.3, 0.45, 0.08), 0.005)
    return pad(mix(soft(thump, 1.0), zing, fo(air), tick), d)


# ------------------------------------------------------------------ signatures
def skate_scrape(i):
    """One stride: the blade bites, carves a long singing scrape across the ice and lifts away."""
    d = 0.55; t = T(d)
    shape = np.minimum(1, t / 0.03) * np.exp(-np.maximum(0, t - 0.12) / 0.16)
    carve = blade(d, (2050, 2250, 1900, 2400)[i], 1.0, shape)
    bite = mix(click(0.002, 1500, 5000) * 0.4, kick(300, 160, 0.05, 0.004, 0.01, 1.4) * 0.25)
    chips = at(shards(0.25, 120, 0.08, 0.35), 0.03)
    return fo(mix(soft(bite, 0.6), carve, chips), 0.2)


def ice_chime():
    """Crystals ringing as ice closes: a cluster of glassy bells, rising and shimmering."""
    d = 1.6
    notes = ((1568, 0.0, 0.5), (1976, 0.06, 0.45), (2349, 0.12, 0.4), (2637, 0.2, 0.35), (3136, 0.3, 0.25))
    out = mix(*[at(crystal(f, 1.2, g, 0.45), t0) for f, t0, g in notes])
    glow = S.chime(784, d, 0.7, ((1.0, 0.5), (2.0, 0.2), (3.0, 0.08))) * 0.25
    return pad(mix(out, glow, at(frost(0.6, 0.05, 0.25, 0.2), 0.0)), d)


# ------------------------------------------------------------------ Shift: the skate
def run():
    """The push-off: a hard blade bite, the first long carve, and the rush of speed."""
    d = 0.75; t = T(d)
    bite = mix(click(0.003, 1500, 5000) * 0.8, kick(220, 100, 0.12, 0.008, 0.02, 1.8) * 0.5,
               crack(0.08, 800, 3500, 0.01) * 0.8)
    carve = blade(0.65, 2150, 0.9, np.minimum(1, t[:N(0.65)] / 0.02) * np.exp(-t[:N(0.65)] / 0.25))
    rush = lpf(swoosh(0.6, 300, 1600, 1.4, 0.7, 1.3), 4500) * 0.6
    chips = shards(0.3, 200, 0.06, 0.5)
    return pad(mix(soft(bite, 0.6), carve, fo(rush), chips), d)


def stop():
    """The hard stop: blades turned across the ice, a harsh scrape and a spray of snow thrown ahead."""
    d = 0.8; t = T(d)
    shape = np.minimum(1, t / 0.02) * np.exp(-t / 0.18)
    scrape = lpf(bpf(noise(d), 600, 4500) * (0.7 + 0.3 * np.abs(S.rng.standard_normal(N(d)))), 6000) * shape * 1.4
    sing = bpf(noise(d), 1650, 1800) * shape * 2.0
    spray = at(lpf(grains(0.6, 500, 1200, 4500, 0.001, 0.004, fall=0.15), 5500) * 0.8, 0.03)
    body = kick(160, 80, 0.15, 0.01, 0.03, 1.6) * 0.3
    return fo(mix(scrape, sing, spray, soft(body, 1.0)), 0.25)


def dash():
    """A skater's glide: a blade bite and a smooth, quick swish."""
    d = 0.45; t = T(d)
    glide = blade(0.4, 2200, 0.6, np.minimum(1, t[:N(0.4)] / 0.02) * np.exp(-t[:N(0.4)] / 0.12))
    air = lpf(swoosh(0.4, 500, 1900, 1.8, 0.8, 1.3), 4500) * 0.7
    bite = mix(click(0.002, 1500, 4500) * 0.3, kick(280, 140, 0.06, 0.005, 0.012, 1.4) * 0.25)
    return pad(mix(soft(bite, 0.6), glide, fo(air)), d)


# ------------------------------------------------------------------ RMB: the ice spear
def spear_aim():
    """The spear forming in her hands: crystal growing with a rising shimmer and a faint ice creak."""
    d = 0.8; t = T(d)
    grow = mix(*[at(crystal(f, 0.6, 0.3, 0.2), t0) for f, t0 in ((1175, 0.0), (1480, 0.09), (1760, 0.18), (2217, 0.27))])
    rise = S.sweep(500, 1300, d, curve=0.8) * 0.07 * np.sin(np.pi * t / d)
    hush = frost(d, 0.2, 0.3, 0.6)
    creak = at(ice_creak(0.35, 110, 85, 2400, 0.3), 0.3)
    return mix(grow, rise, hush, creak)


def lance():
    """The spear pushed off: a heavy ice shaft sliding out of her grip and away, a glassy ring."""
    d = 0.7
    push = mix(kick(200, 80, 0.25, 0.015, 0.05, 2.0) * 0.6, crack(0.12, 500, 2500, 0.015) * 0.8)
    air = lpf(swoosh(0.55, 350, 2400, 1.8, 0.8, 1.2), 5000) * 0.9
    ring_ = at(crystal(1320, 0.5, 0.35, 0.18), 0.02)
    return pad(mix(soft(push, 1.0), fo(air), ring_), d)


def wall_tell():
    """Frost gathering: a cold hiss and a deep, hollow tone swelling in."""
    d = 0.9; t = T(d)
    swell = np.minimum(1, t / 0.6) ** 2 * np.exp(-np.maximum(0, t - 0.7) / 0.08)
    tone = (np.sin(2 * np.pi * 220 * t) * 0.3 + np.sin(2 * np.pi * 330.5 * t) * 0.15) * swell
    hush = lpf(S.hiss(d, 2000, 5500, 0.3, 2.0), 6000) * swell * 0.5
    crk = lpf(grains(d, 80, 2000, 5000, 0.0008, 0.002), 6000) * swell * 0.4
    return mix(tone, hush, crk)


def zone():
    """The spear landing: ice spikes bursting up out of the ground with a crunch."""
    d = 0.9
    crunch = mix(click(0.004, 1500, 5500) * 1.0, kick(170, 60, 0.4, 0.015, 0.06, 2.4) * 0.7,
                 crack(0.3, 400, 3500, 0.03) * 1.8)
    spikes = mix(*[at(crystal(f, 0.5, 0.3, 0.12), t0) for f, t0 in ((880, 0.0), (1245, 0.02), (1661, 0.045))])
    splinters = shards(0.6, 280, 0.15, 0.8)
    return pad(mix(soft(crunch, 0.8), spikes, splinters, at(frost(0.5, 0.05, 0.2, 0.3), 0.05)), d)


def burst():
    """The spear's detonation: a deep frozen boom, a dome of ice blown apart, glass raining down."""
    d = 1.5
    boom = mix(click(0.006, 1200, 6000) * 1.5, kick(140, 36, d, 0.035, 0.13, 3.2) * 0.85,
               crack(0.6, 250, 3500, 0.05) * 2.4, sub(55, 30, 1.0, 0.22) * 0.55)
    glass = mix(*[at(crystal(f, 1.0, 0.35, 0.3), t0) for f, t0 in ((1047, 0.0), (1397, 0.03), (1865, 0.06), (2489, 0.1))])
    rain = shards(1.3, 260, 0.4, 1.0)
    room = reflections(tail(1.0, 1500, 0.25, 0.01) * 0.6)
    return lpf(mix(soft(boom, 1.0), glass, rain, room), 7500)


def splinter():
    """A Shatter: a hard crack and a burst of glass flying outward."""
    d = 1.0
    crk = mix(click(0.004, 2000, 6000) * 1.2, kick(240, 90, 0.3, 0.01, 0.035, 2.4) * 0.55,
              crack(0.2, 900, 5000, 0.015) * 2.2)
    glass = mix(*[at(crystal(f, 0.7, 0.4, 0.15), t0) for f, t0 in ((1760, 0.0), (2349, 0.015), (2960, 0.03), (3520, 0.05))])
    flying = shards(0.8, 520, 0.18, 1.1)
    return pad(lpf(mix(soft(crk, 0.6), glass, flying), 7500), d)


# ------------------------------------------------------------------ E: the ice wall
def wall():
    """The wall grinding up out of the ground: ice crunching, a low rumble, creaking as it settles."""
    d = 1.3; t = T(d)
    grind = lpf(bpf(noise(d), 200, 2500) * (0.6 + 0.4 * np.abs(np.sin(2 * np.pi * 23 * t))), 4500) * env(N(d), 0.03, 0.35) * 1.4
    thud = mix(kick(140, 45, 0.6, 0.02, 0.09, 2.6) * 0.75, sub(55, 32, 0.6, 0.14) * 0.45)
    crunch = lpf(grains(0.8, 220, 900, 4500, 0.001, 0.005, fall=0.25), 5000) * 0.9
    creak = at(ice_creak(0.6, 60, 40, 1600, 0.6), 0.45)
    return lpf(mix(soft(thud, 1.0), soft(grind, 8), crunch, creak), 7000)


def freeze():
    """The wall frozen solid: a crackle racing across it and a cold glassy settle."""
    d = 1.0
    crackle = lpf(grains(0.5, 400, 1500, 5000, 0.0008, 0.003, fall=0.15), 6000) * 1.1
    snap = mix(click(0.003, 2000, 5000) * 0.6, crack(0.1, 800, 3500, 0.012) * 1.0)
    tone = at(crystal(1397, 0.8, 0.4, 0.3), 0.04)
    groan = at(ice_creak(0.5, 80, 55, 1800, 0.4), 0.15)
    return pad(mix(soft(snap, 0.6), crackle, tone, groan), d)


# ------------------------------------------------------------------ R: Rimelock
def lock():
    """Encased: ice slamming shut round her, a deep crack, a cold chord, a held breath."""
    d = 1.5
    shut = mix(click(0.005, 1500, 5500) * 1.2, kick(150, 45, 0.7, 0.025, 0.1, 2.8) * 0.8,
               crack(0.4, 300, 3500, 0.04) * 2.0, sub(55, 34, 0.7, 0.16) * 0.5)
    chord = mix(*[at(crystal(f, 1.3, 0.3, 0.5), t0) for f, t0 in ((659, 0.02), (831, 0.05), (988, 0.08), (1319, 0.12))])
    creak = at(ice_creak(0.8, 55, 35, 1500, 0.7), 0.2)
    gasp = at(lpf(S.voice(0.25, 330, 380, 'ah', breath=0.85, rasp=0.0, scale=1.15, a=0.03, decay=0.1), 5000) * 0.18, 0.0)
    return lpf(mix(soft(shut, 0.8), chord, creak, gasp, shards(0.8, 200, 0.2, 0.5)), 7500)


def creak(i):
    """The ice holding: a short deep strain, a few cold ticks."""
    d = 0.55
    c = ice_creak(0.5, 65 + 8 * i, 45 + 5 * i, 1700 + 150 * i, 1.0)
    ticks = lpf(grains(0.4, 25, 1800, 4500, 0.001, 0.003), 5500) * 0.5
    return pad(mix(c, ticks), d)


def crash():
    """Rimelock broken at full: the shell blasting apart, a deep boom, glass flying everywhere."""
    d = 1.8
    boom = mix(click(0.006, 1200, 6000) * 1.6, kick(130, 32, d, 0.04, 0.15, 3.4) * 0.9,
               crack(0.8, 200, 3500, 0.06) * 2.6, sub(52, 28, 1.2, 0.28) * 0.6)
    glass = mix(*[at(crystal(f, 1.2, 0.35, 0.35), t0) for f, t0 in ((784, 0.0), (1175, 0.02), (1568, 0.05), (2093, 0.08), (2794, 0.11))])
    flying = shards(1.5, 340, 0.4, 1.2)
    room = reflections(tail(1.2, 1300, 0.3, 0.01) * 0.6)
    return lpf(mix(soft(boom, 1.0), glass, flying, room), 7500)


def crack_():
    """Rimelock cancelled: the shell cracking open and falling away in pieces."""
    d = 0.9
    crk = mix(click(0.003, 1800, 5500) * 0.8, crack(0.25, 600, 4000, 0.025) * 1.6, kick(210, 90, 0.25, 0.01, 0.03, 2.0) * 0.4)
    split = at(ice_creak(0.25, 140, 70, 2600, 0.6), 0.01)
    falls = mix(at(crystal(1245, 0.4, 0.3, 0.1), 0.18), at(crystal(1568, 0.4, 0.25, 0.1), 0.3))
    return pad(mix(soft(crk, 0.6), split, falls, shards(0.6, 160, 0.2, 0.6)), d)


# ------------------------------------------------------------------ footsteps
def footstep(surface, i):
    """A light step: the soft footfall, the surface's texture and the faint click of a skate blade."""
    d = 0.24
    if surface == 'grass':
        body = kick(170, 95, 0.1, 0.008, 0.016, 1.4) * 0.35
        tex = lpf(grains(0.12, 380, 700, 3500, 0.001, 0.004, fall=0.03), 4500) * 0.5
        tex = mix(tex, fo(bpf(noise(0.1), 400, 2000) * env(N(0.1), 0.003, 0.02)) * 0.5)
        clk = 0.25
    elif surface == 'stone':
        body = kick(220, 120, 0.08, 0.005, 0.01, 1.5) * 0.3
        tex = mix(crack(0.05, 900, 3800, 0.006) * 0.6, lpf(grains(0.05, 200, 2500, 6000, 0.001, 0.003, fall=0.01), 6000) * 0.2)
        clk = 0.9
    elif surface == 'wood':
        body = kick(190, 110, 0.1, 0.006, 0.014, 1.4) * 0.35
        tex = fo(ring((230 + 8 * i, 470, 930), 0.14, (0.025, 0.018, 0.01), (0.5, 0.35, 0.15)), 0.4)
        clk = 0.7
    else:
        body = lpf(kick(150, 85, 0.1, 0.008, 0.016, 1.2), 900) * 0.3
        tex = lpf(grains(0.16, 750, 900, 3600, 0.001, 0.003, fall=0.045), 4500) * 0.6
        tex = mix(tex, fo(lpf(noise(0.14), 1600) * env(N(0.14), 0.005, 0.035)) * 0.4)
        clk = 0.35
    # the blade's tick as the heel comes down, and on some takes a short glide off the toe
    blade_tick = at(crystal(2600 + 90 * i, 0.12, 0.16 * clk, 0.025), 0.004)
    out = mix(soft(body, 1.0), tex, blade_tick)
    if i in (1, 3):
        out = mix(out, at(blade(0.12, 2300, 0.08 * (0.4 + clk)), 0.05))
    return fo(lpf(pad(out, d), 6500), 0.25)


# ------------------------------------------------------------------ voice: a sweet, breathy woman with frost under it
def hurt(i):
    vowel = ('ah', 'eh', 'uh', 'ah')[i]
    d = 0.2 + 0.025 * (i % 2)
    v = S.voice(d, 330 + 18 * i, 255, vowel, breath=0.45, rasp=0.08, scale=1.18, a=0.008, decay=0.08)
    rime = at(fo(frost(0.25, 0.02, 0.08, 0.25)), d * 0.5)
    return pad(mix(fo(lpf(v, 5500)), rime), 0.45)


def down():
    v = S.voice(0.8, 320, 200, 'ah', breath=0.5, rasp=0.12, vib=0.025, scale=1.18, a=0.02, decay=0.35)
    shadow = S.voice(0.8, 160, 100, 'oh', breath=0.2, rasp=0.4, scale=0.95, a=0.05, decay=0.3) * 0.18
    gasp = at(fo(bpf(noise(0.3), 1200, 6000) * env(N(0.3), 0.05, 0.1), 0.6) * 0.07, 0.75)
    creak_ = at(ice_creak(0.45, 75, 50, 1500, 0.2), 0.45)
    return pad(mix(fo(lpf(v, 5500), 0.4), fo(lpf(shadow, 2000), 0.4), gasp, creak_), 1.3)


def death():
    """A long falling cry with a demonic shadow an octave under it, then ice closing and a last chime."""
    v = S.voice(1.1, 340, 160, 'ah', breath=0.5, rasp=0.12, vib=0.03, scale=1.18, a=0.02, decay=0.45)
    shadow = S.voice(1.1, 170, 80, 'oh', breath=0.2, rasp=0.5, scale=0.9, a=0.08, decay=0.45) * 0.25
    exhale = at(fo(frost(0.8, 0.1, 0.3, 0.35)), 0.9)
    freeze_ = at(ice_creak(0.7, 60, 38, 1500, 0.35), 1.0)
    last = at(crystal(1568, 1.0, 0.12, 0.4), 1.5)
    return pad(mix(fo(lpf(v, 5500), 0.4), fo(lpf(shadow, 2000), 0.4), exhale, freeze_, last), 2.6)


def build():
    S.takes_cat('rime_shard', shard, 3, 'fire')
    S.takes_cat('rime_beam', beam, 3, 'fire')
    S.takes_cat('rimewright_skate_scrape', skate_scrape, 3, 'signature')
    S.save_cat('rimewright_ice_chime', ice_chime(), 'signature')
    S.save_cat('rime_run', run(), 'cast')
    S.save_cat('rime_stop', stop(), 'cast')
    S.save_cat('rimewright_dash', dash(), 'dash')
    S.save_cat('rime_spear_aim', spear_aim(), 'cast')
    S.save_cat('rime_lance', lance(), 'cast')
    S.save_cat('rime_wall_tell', wall_tell(), 'cast')
    S.save_cat('rime_zone', zone(), 'impact')
    S.save_cat('rime_burst', burst(), 'impact')
    S.save_cat('rime_splinter', splinter(), 'impact')
    S.save_cat('rime_wall', wall(), 'impact')
    S.save_cat('rime_freeze', freeze(), 'cast')
    S.save_cat('rime_lock', lock(), 'cast')
    S.takes_cat('rime_creak', creak, 3, 'cast')
    S.save_cat('rime_crash', crash(), 'impact')
    S.save_cat('rime_crack', crack_(), 'cast')
    for surf in ('grass', 'stone', 'wood', 'snow'):
        S.takes_cat('rimewright_step_' + surf, lambda i, s=surf: footstep(s, i), 3, 'step')
    S.takes_cat('rimewright_hurt', hurt, 3, 'grunt')
    S.save_cat('rimewright_down', down(), 'grunt')
    S.save_cat('rimewright_death', death(), 'grunt')


if __name__ == '__main__':
    build()
    print('gen_sfx_claire: done')
