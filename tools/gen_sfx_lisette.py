"""Lisette the Red Stitch (archer): every sound her kit plays, synthesised and levelled (docs/AUDIO.md).

    cd tools && python3 gen_sfx_lisette.py      (then: godot --headless --import)

Lisette was Malgrave's mask-stitcher: a needle bow strung with red thread, a spool quiver, scissors at
her belt, a loose shadow that walks on its own. Her palette is plucked thread (Karplus-Strong strings,
thin and silky, never a guitar), steel needles and shears, the spool's ratchet, cloth, and a breathy
hollow shimmer for the shadow. Her voice is an adult woman's, cool and quiet, more breath than tone.

  archer_thread_twang (3 takes)  SIGNATURE: the red thread snapping forward as she looses (the bow's shot)
  pin_loose (3 takes)            an Empowered arrow leaving: a needle's whistle and an air whip
  pin_loose_super                a Supercharged arrow: a heavy twang, a tearing whoosh, a bass punch
  pin_draw / pin_heavy_draw      drawing: the limbs creak, the spool's ratchet ticks, the thread stretches
  pin_stage / pin_super          Empowered / Supercharged ready: a needle's ping / a two-note chime
  pin_perfect                    the perfect release: a pair of shears' clean snip-shing
  pin_overdraw                   held too long: a dull falling creak
  pin_super_hit (2 takes)        the Supercharged hit
  pin_heavy / pin_heavy_hit      the Heavy Shot loosed / landing and pinning (3 takes)
  pin_hail / pin_rain / pin_patter  Hail Wall: arrows up, the rain falling, one arrow striking (3 takes)
  pin_spirit / pin_spirit_end    Spirit Walk: the roll into her shadow / stepping back out
  pin_ult_cast/_nock/_beam/_final  Starpiercer
  archer_dash                    the roll: a cloak flap and a whoosh
  archer_step_<surface>          soft boots, a cloak's brush, now and then a needle's tick (3 takes each)
  archer_hurt/down/death         wordless voice

It also writes the kit's pin_* files (content/sfx/archer.json lists them under "replaces"). Original synthesis, no samples.
"""
import os, sys
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import sfx_lib as S
from sfx_lib import (N, T, noise, lpf, hpf, bpf, env, mix, at, sat, kick, click, crack, sub, tail,
                     reflections, ring, grains, pad)

S.reseed(9184)


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
    return fo(lpf(out, 7000) * np.sin(np.pi * u) ** shape, 0.35)


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


def pluck(f, d, damp=0.996, bright=0.5, bend=0.0):
    """A plucked thread (Karplus-Strong): a noise burst in a delay line one period long, averaged each
    pass. damp sets the ring time, bright the pluck's edge; bend > 0 starts the pitch that much sharp."""
    n = N(d); out = np.zeros(n)
    L0 = S.SR / f
    buf_len = int(L0 * (1 + bend)) + 2
    burst = lpf(S.rng.standard_normal(buf_len), 2000 + 9000 * bright)
    line = list(burst)
    pos = 0
    for k in range(n):
        L = int(L0 * (1 + bend * np.exp(-k / (0.02 * S.SR))))
        L = max(2, min(L, len(line) - 1))
        a = line[(pos - L) % len(line)]; b = line[(pos - L - 1) % len(line)]
        v = damp * 0.5 * (a + b)
        line[pos % len(line)] = v
        out[k] = v
        pos += 1
    return fo(out * env(n, 0.0005, d * 0.35), 0.3)


def ratchet(d, rate0, rate1, lo=2200, hi=6000):
    """The spool's pawl ticking over its teeth, rate0 -> rate1 clicks per second."""
    n = N(d); t = T(d)
    rate = rate0 * (rate1 / rate0) ** (t / d)
    ph = np.cumsum(rate) / S.SR
    ticks = (np.diff(np.floor(ph), prepend=0) > 0).astype(float) * (0.7 + 0.3 * S.rng.random(n))
    return mix(bpf(ticks, lo, hi) * 3.0, bpf(ticks, 700, 1400) * 1.2)


def creak(d, f0, f1, bright=2200, rough=0.5):
    """The bow's limbs bending (sfx_lib's creak, softened at both ends)."""
    return fo(soft(S.creak(d, f0, f1, rough, bright), 8), 0.3)


def stretch(d, f0, f1):
    """Thread tightening: a thin rising squeak with a faint fibre noise."""
    t = T(d)
    tone = S.sweep(f0, f1, d, curve=0.8) * 0.4 + S.sweep(f0 * 2.01, f1 * 2.01, d, curve=0.8) * 0.12
    fib = bpf(noise(d), 2500, 6000) * 0.12
    return fo((tone + fib) * np.minimum(1, t / 0.06), 0.3)


# ------------------------------------------------------------------ the bow
def twang(i):
    """The thread snaps forward: a bright plucked thread, the needle bow's limb knock, a silky buzz."""
    d = 0.55
    f = (392.0, 415.3, 370.0, 440.0)[i]
    th = pluck(f, d, 0.993, 0.5, bend=0.06) * 1.0
    th2 = pluck(f * 1.5, d, 0.990, 0.4, bend=0.04) * 0.35
    knock = mix(click(0.002, 1500, 5000) * 0.6, kick(260, 140, 0.08, 0.004, 0.012, 1.6) * 0.35)
    silk = bpf(noise(0.12), 3000, 6500) * env(N(0.12), 0.001, 0.025) * 0.25
    return lpf(lpf(mix(th, th2, soft(knock, 0.5), silk), 7000), 9000)


def loose(i):
    """An Empowered arrow leaving: a thin needle whistle over a quick air whip."""
    d = 0.42
    whip = lpf(swoosh(0.3, 900 + 60 * i, 4200, 4.0, 0.6, 1.2), 7000) * 0.9
    whistle = fo(S.sweep(2600 + 100 * i, 1900, 0.3) * env(N(0.3), 0.01, 0.12), 0.4) * 0.3
    fletch = at(swoosh(0.12, 2500, 5000, 1.5) * 0.25, 0.02)
    return pad(mix(whip, whistle, fletch), d)


def loose_super():
    """A Supercharged arrow: the thread at full pull, a tearing whoosh and a bass punch."""
    d = 0.75
    th = pluck(294, 0.6, 0.994, 0.8, bend=0.08) * 0.9
    punch = mix(kick(150, 55, 0.4, 0.02, 0.07, 2.6) * 0.6, sub(70, 42, 0.4, 0.08) * 0.35)
    tear = swoosh(0.5, 400, 5200, 1.8, 0.5, 1.1) * 0.9
    ring_ = at(fo(ring((1567, 2350), 0.5, (0.12, 0.08), (0.12, 0.06)), 0.5), 0.01)
    return lpf(pad(mix(th, soft(punch, 1), tear, ring_), d), 9000)


def draw():
    """The draw: the limbs creak, the spool's ratchet ticks, the thread stretches."""
    d = 0.55
    return pad(mix(creak(0.5, 70, 110, 2000) * 0.7, ratchet(0.45, 14, 30) * 0.18, stretch(0.5, 700, 1150)), d)


def heavy_draw():
    """The Heavy Shot's draw: a deep slow creak, a heavier ratchet, the thread groaning tight."""
    d = 0.85
    return pad(mix(creak(0.8, 50, 80, 1400, 0.7) * 0.9, ratchet(0.7, 9, 22, 1600, 5000) * 0.2,
                   stretch(0.75, 420, 760) * 0.8), d)


def stage():
    """Empowered ready: a sewing needle's small bright ping and a short shimmer."""
    d = 0.45
    ping = fo(S.chime(2793, 0.42, 0.11, ((1.0, 1.0), (2.76, 0.3), (5.4, 0.1))), 0.4) * 0.8
    shim = fo(bpf(noise(0.25), 4000, 7000) * env(N(0.25), 0.01, 0.06), 0.5) * 0.1
    return pad(mix(ping, shim), d)


def super_ready():
    """Supercharged ready: a fuller two-note chime over a low swell (also the deep layer under a Heavy Shot)."""
    d = 0.75
    a = fo(S.chime(1568, 0.7, 0.2), 0.4) * 0.6
    b = at(fo(S.chime(2093, 0.65, 0.2), 0.4) * 0.6, 0.07)
    swell = fo(lpf(S.sweep(110, 150, 0.6, 'saw'), 600) * env(N(0.6), 0.08, 0.25), 0.4) * 0.35
    return pad(mix(a, b, swell, kick(160, 80, 0.2, 0.01, 0.05, 1.6) * 0.3), d)


def perfect():
    """The perfect release: a pair of shears closing, snip into a ringing shing."""
    d = 0.75
    snip = mix(click(0.002, 2500, 7500) * 1.0, crack(0.03, 2500, 7000, 0.004) * 0.8)
    scrape = fo(bpf(noise(0.07), 3500, 7500) * np.linspace(0.3, 1, N(0.07)), 0.3) * 0.35
    shing = at(fo(ring((3136, 4704, 6272), 0.65, (0.22, 0.12, 0.07), (0.45, 0.2, 0.08)), 0.4), 0.06)
    return lpf(pad(mix(soft(scrape, 3), at(snip, 0.06), shing), d), 9500)


def overdraw():
    """Held too long: the limbs droop with a dull falling creak and the thread sags."""
    d = 0.5
    return pad(mix(creak(0.45, 110, 55, 1500) * 0.9, stretch(0.4, 900, 600) * 0.4), d)


def super_hit(i):
    """The Supercharged hit: a glassy crack, a needle's ring, a thread's whip."""
    d = 0.65
    hit = mix(click(0.003, 2500, 8500) * 1.4, kick(240 + 10 * i, 90, 0.3, 0.008, 0.03, 2.4) * 0.5,
              crack(0.2, 900, 5500, 0.015) * 1.8, grains(0.25, 200, 3000, 7000, fall=0.05) * 0.4)
    glass = fo(ring((2489 + 60 * i, 3730, 5590), 0.6, (0.15, 0.1, 0.06), (0.35, 0.18, 0.08)), 0.4)
    return lpf(pad(mix(hit, glass), d), 9500)


# ------------------------------------------------------------------ RMB: Heavy Shot
def heavy():
    """The Heavy Shot loosed: a thick low thread thrum and a low whoosh."""
    d = 0.65
    th = pluck(196, 0.6, 0.995, 0.6, bend=0.05) * 0.9
    th2 = pluck(98, 0.6, 0.996, 0.4) * 0.5
    air = swoosh(0.45, 300, 2400, 1.6, 0.7) * 0.7
    knock = kick(200, 90, 0.12, 0.006, 0.02, 1.8) * 0.4
    return lpf(pad(mix(th, th2, air, soft(knock, 0.5)), d), 8500)


def heavy_hit(i):
    """The Heavy Shot landing: a meaty thunk, the shaft biting in and quivering, a puff of grit."""
    d = 0.5
    thunk = mix(click(0.003, 1800, 6500) * 1.2, kick(190 + 12 * i, 65, 0.4, 0.012, 0.05, 2.8) * 0.75,
                crack(0.2, 300, 2200, 0.025) * 2.0)
    t = T(0.35)
    quiver = np.sin(2 * np.pi * (150 + 10 * i) * t) * (0.5 + 0.5 * np.sin(2 * np.pi * 26 * t)) * np.exp(-t / 0.08)
    grit = grains(0.2, 150, 1500, 5000, fall=0.05) * 0.4
    return pad(mix(thunk, at(fo(quiver, 0.3) * 0.3, 0.01), grit, sub(70, 45, 0.3, 0.05) * 0.3), d)


# ------------------------------------------------------------------ E: Hail Wall
def hail():
    """A flight of arrows swishing up: several plucks and swooshes staggered."""
    d = 0.8
    out = np.zeros(N(d))
    for k in range(5):
        dl = 0.03 + 0.06 * k + S.rng.uniform(0, 0.02)
        s_ = swoosh(0.35, 700 + 120 * k, 3800 + 200 * k, 2.2, 0.6, 1.3) * (0.7 - 0.08 * k)
        out = mix(out, at(s_, dl))
    t1 = pluck(349, 0.45, 0.992, 0.7, bend=0.05) * 0.5
    return pad(mix(out, t1), d)


def rain():
    """The rain starting: a hush of many shafts falling, thickening then thinning."""
    d = 1.05; t = T(d)
    hush = lpf(bpf(noise(d), 1200, 4500), 5000) * np.sin(np.pi * np.clip(t / d, 0, 1)) ** 1.2 * 0.45
    many = np.zeros(N(d))
    for _ in range(16):
        dl = S.rng.uniform(0.0, 0.7)
        many = mix(many, at(swoosh(0.22, 3500, 1200, 3.0, 1.0, 1.4) * S.rng.uniform(0.25, 0.5), dl))
    ticks = grains(d, 40, 1500, 5000, 0.002, 0.005) * np.sin(np.pi * np.clip(t / d, 0, 1)) * 0.6
    return pad(mix(hush, many, ticks), d)


def patter(i):
    """One arrow of the rain striking: a small dry tick into the ground."""
    d = 0.12
    return pad(mix(click(0.002, 1500, 5500) * 0.9, kick(420 + 30 * i, 200, 0.06, 0.003, 0.008, 1.6) * 0.4,
                   crack(0.04, 800, 3500, 0.006) * 0.8), d)


# ------------------------------------------------------------------ Shift: Spirit Walk
def spirit():
    """The roll into her shadow: a quick whoosh, then a hollow airy shimmer and a thread unspooling."""
    d = 0.9; t = T(d)
    roll = swoosh(0.28, 400, 2200, 1.6, 0.8) * 0.9
    hollow = fo(mix(bpf(noise(0.75), 500, 900) * 0.6, bpf(noise(0.75), 1700, 2300) * 0.3)
                * np.sin(np.pi * np.clip(T(0.75) / 0.75, 0, 1)) ** 1.5, 0.3)
    shim = fo(S.sweep(1300, 1700, 0.7) * (0.5 + 0.5 * np.sin(2 * np.pi * 6 * T(0.7))) * env(N(0.7), 0.1, 0.4), 0.4) * 0.1
    spool = at(ratchet(0.35, 40, 12, 2500, 6000) * np.exp(-T(0.35) / 0.15) * 0.08, 0.15)
    return pad(mix(roll, at(hollow * 0.6, 0.1), at(shim, 0.12), spool), d)


def spirit_end():
    """Stepping back out of the shadow: a soft falling chime and a breath."""
    d = 0.7
    a = fo(S.chime(1760, 0.6, 0.18), 0.4) * 0.5
    b = at(fo(S.chime(1318, 0.55, 0.18), 0.4) * 0.45, 0.08)
    breath = fo(bpf(noise(0.4), 600, 3000) * env(N(0.4), 0.05, 0.12), 0.5) * 0.25
    return pad(mix(a, b, breath), d)


# ------------------------------------------------------------------ X: Starpiercer
def ult_cast():
    """Starpiercer: a bright rising shimmer over a low swell, a chord of threads blooming out."""
    d = 1.0; t = T(d)
    swell = fo(lpf(S.sweep(80, 140, d, 'saw'), 500) * np.minimum(1, t / 0.3) * np.exp(-t / 0.6), 0.3) * 0.5
    shim = fo(S.sweep(900, 2600, 0.6, curve=0.7) * env(N(0.6), 0.15, 0.3), 0.3) * 0.18
    chord = np.zeros(N(d))
    for k, f in enumerate((294, 370, 440, 587)):
        chord = mix(chord, at(pluck(f, 0.6, 0.995, 0.5) * 0.35, 0.3 + 0.035 * k))
    return pad(mix(swell, shim, chord), d)


def ult_beam(final):
    """A beam: a deep thread thrum and a cracking boom (the last one heavier, ringing longer)."""
    d = 1.3 if final else 0.75
    th = pluck(147 if final else 196, d * 0.9, 0.997, 0.7, bend=0.06) * 0.8
    crk = mix(click(0.004, 2500, 9000) * 1.6, crack(d, 900, 6500, 0.012) * 2.2)
    boom = kick(150, 45, d, 0.025, 0.12 if final else 0.08, 3.0) * 0.8
    tear = swoosh(min(0.6, d), 500, 5000, 1.6, 0.5, 1.0) * 0.6
    rings = fo(ring((1175, 1760, 2637), d, (0.4, 0.25, 0.15) if final else (0.18, 0.1, 0.06), (0.25, 0.15, 0.08)), 0.4)
    return lpf(mix(th, crk, boom, tear, rings, sub(60, 36, d, 0.2 if final else 0.12) * 0.45), 9500)


# ------------------------------------------------------------------ Shift's shared slot
def dash():
    """The roll: a cloak's flap and a quick low whoosh."""
    d = 0.4; t = T(d)
    air = swoosh(d, 350, 1800, 1.5, 0.8)
    flap = bpf(noise(d), 200, 1200) * (0.5 + 0.5 * np.sin(2 * np.pi * 18 * t)) * np.sin(np.pi * t / d) ** 2 * 0.4
    return mix(air, flap)


# ------------------------------------------------------------------ footsteps: light, soft boots
def footstep(surface, i):
    """A soft, light step (she walks quietly); the cloak's brush; now and then a needle's faint tick."""
    def hit(g):
        if surface == 'grass':
            body = kick(130, 75, 0.09, 0.008, 0.014, 1.4) * 0.3
            tex = mix(lpf(grains(0.1, 380, 700, 3400, 0.001, 0.004, fall=0.03), 4000) * 0.6,
                      fo(bpf(noise(0.09), 300, 1600) * env(N(0.09), 0.004, 0.02)) * 0.5)
        elif surface == 'stone':
            body = kick(180, 100, 0.08, 0.005, 0.01, 1.4) * 0.35
            tex = mix(click(0.002, 1500, 5500) * 0.5, crack(0.05, 700, 3500, 0.006) * 0.8,
                      fo(bpf(noise(0.05), 2000, 5000) * env(N(0.05), 0.002, 0.008)) * 0.2)
        elif surface == 'wood':
            body = kick(160, 90, 0.11, 0.006, 0.014, 1.4) * 0.35
            tex = mix(click(0.002, 1200, 4500) * 0.45,
                      fo(ring((200 + 6 * i, 455, 960), 0.13, (0.024, 0.017, 0.011), (0.5, 0.4, 0.2)), 0.5))
        else:
            body = lpf(kick(110, 65, 0.1, 0.008, 0.015, 1.2), 800) * 0.3
            tex = mix(lpf(grains(0.13, 700, 900, 3500, 0.001, 0.003, fall=0.04), 4500) * 0.6,
                      fo(lpf(noise(0.12), 1200) * env(N(0.12), 0.006, 0.03)) * 0.5)
        return mix(soft(body, 1.5), tex) * g
    out = mix(hit(1.0), at(hit(0.45), 0.03 + 0.005 * i))
    out = mix(out, at(fo(bpf(noise(0.12), 400, 2500) * env(N(0.12), 0.02, 0.04)) * 0.12, 0.0))
    if i == 2:
        out = mix(out, at(fo(ring((4186, 5900), 0.08, (0.02, 0.012), (0.04, 0.02))), 0.02))
    return lpf(lpf(pad(out, 0.2), 6500), 9000)


# ------------------------------------------------------------------ voice: an adult woman, cool and breathy
def hurt(i):
    vowel = ('uh', 'eh', 'ah', 'uh')[i]
    d = 0.17 + 0.02 * (i % 2)
    v = S.voice(d, 255 + 10 * i, 205, vowel, breath=0.45, rasp=0.08, scale=1.12, a=0.01, decay=0.075)
    hiss_ = at(fo(bpf(noise(0.22), 1500, 6000) * env(N(0.22), 0.02, 0.06), 0.6) * 0.08, d * 0.5)
    return pad(mix(fo(lpf(v, 5500)), hiss_), 0.36)


def down():
    v = S.voice(0.6, 245, 165, 'ah', breath=0.5, rasp=0.15, vib=0.02, scale=1.1, a=0.02, decay=0.28)
    breath = at(fo(bpf(noise(0.35), 800, 5500) * env(N(0.35), 0.06, 0.12), 0.6) * 0.1, 0.55)
    thread = at(lpf(pluck(220, 0.5, 0.99, 0.4), 4500) * 0.08, 0.05)
    return pad(mix(fo(lpf(v, 5500), 0.4), breath, thread), 1.0)


def death():
    v = S.voice(0.9, 250, 130, 'oh', breath=0.5, rasp=0.15, vib=0.03, scale=1.1, a=0.02, decay=0.38)
    exhale = at(fo(bpf(noise(0.6), 700, 5000) * env(N(0.6), 0.08, 0.22), 0.6) * 0.09, 0.7)
    snap = at(lpf(pluck(330, 0.7, 0.993, 0.4, bend=-0.03), 4500) * 0.12, 0.45)
    return pad(mix(fo(lpf(v, 5500), 0.4), exhale, snap), 1.6)


def build():
    S.takes_cat('archer_thread_twang', twang, 3, 'signature')
    S.takes_cat('pin_loose', loose, 3, 'fire')
    S.save_cat('pin_loose_super', loose_super(), 'fire')
    S.save_cat('pin_draw', draw(), 'cast')
    S.save_cat('pin_heavy_draw', heavy_draw(), 'cast')
    S.save_cat('pin_stage', stage(), 'cast')
    S.save_cat('pin_super', super_ready(), 'cast')
    S.save_cat('pin_perfect', perfect(), 'cast')
    S.save_cat('pin_overdraw', overdraw(), 'cast')
    S.takes_cat('pin_super_hit', super_hit, 2, 'impact')
    S.save_cat('pin_heavy', heavy(), 'fire')
    S.takes_cat('pin_heavy_hit', heavy_hit, 3, 'impact')
    S.save_cat('pin_hail', hail(), 'cast')
    S.save_cat('pin_rain', rain(), 'impact')
    S.takes_cat('pin_patter', patter, 3, 'impact')
    S.save_cat('pin_spirit', spirit(), 'cast')
    S.save_cat('pin_spirit_end', spirit_end(), 'cast')
    S.save_cat('pin_ult_cast', ult_cast(), 'cast')
    S.save_cat('pin_ult_beam', ult_beam(False), 'impact')
    S.save_cat('pin_ult_final', ult_beam(True), 'impact')
    S.save_cat('archer_dash', dash(), 'dash')
    for surf in ('grass', 'stone', 'wood', 'snow'):
        S.takes_cat('archer_step_' + surf, lambda i, s=surf: footstep(s, i), 3, 'step')
    S.takes_cat('archer_hurt', hurt, 3, 'grunt')
    S.save_cat('archer_down', down(), 'grunt')
    S.save_cat('archer_death', death(), 'grunt')


if __name__ == '__main__':
    build()
    print('gen_sfx_lisette: done')
