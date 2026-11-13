"""Claire the Frost Siren (rimewright): her sound set (docs/AUDIO.md, content/sfx/rimewright.json).

    python3 tools/gen_sfx_claire.py      (then: godot --headless --import)

Her palette: glass-clear ice (inharmonic crystal partials), the dispersive "pew" of a cracking ice sheet,
a steel blade scraping and biting ice, frosty air, and a wordless woman's voice, airy and siren-like,
with a cold edge on down and death. Bright layers stay mostly under 6 kHz so a dart storm never hisses.
Writes the rime_* sounds her kit plays (listed under "replaces").
Original synthesis, no samples.
"""
import os, sys
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import sfx_lib as S
from sfx_lib import N, T, noise, lpf, hpf, bpf, env, mix, at, sat, click, tail, reflections, grains

S.reseed(7319)
SR = S.SR


def R(lo, hi):
    return S.rng.uniform(lo, hi)


def g(x, k):
    return np.asarray(x) * k


def fade(x, ms=6.0):
    """A short cosine fade at the end, so a layer that stops early never clicks."""
    x = np.asarray(x, dtype=float).copy()
    n = min(len(x), N(ms / 1000.0))
    if n > 1:
        x[-n:] *= 0.5 + 0.5 * np.cos(np.pi * np.arange(n) / n)
    return x


def kick(*a, **kw):
    return fade(S.kick(*a, **kw))


def sub(*a, **kw):
    return fade(S.sub(*a, **kw))


# ------------------------------------------------------------------ her materials
CRYSTAL_TOP = 7500.0     # Hz: the highest crystal partial kept
GLASS = ((1.0, 1.0), (2.32, 0.5), (4.25, 0.22), (6.63, 0.08))     # ice crystal partials (inharmonic)


def crystal(f, d=0.6, decay=0.25, partials=GLASS):
    """One clear ice crystal: inharmonic glass partials, the high ones fading first, a soft shimmer beat.
    Partials above CRYSTAL_TOP are left out (no aliasing, no fizz above the ice)."""
    t = T(d); out = np.zeros(N(d))
    for k, gk in partials:
        for det, w in ((1.0, 1.0), (1.004, 0.45)):
            fk = f * k * det
            if fk > CRYSTAL_TOP:
                continue
            out += w * gk * np.sin(2 * np.pi * fk * t + S.rng.uniform(0, 6.28)) * np.exp(-t / (decay / k ** 0.5))
    return fade(out * env(N(d), 0.0008, d))


def pew(f0, f1, d, decay=None):
    """The dispersive chirp of cracking ice (a frozen lake's 'pew'): a fast falling tone, almost a click."""
    x = S.sweep(f0, f1, d, curve=0.35)
    return fade(x * env(N(d), 0.0004, decay or d * 0.3), 3.0)


def ice_crack(d=0.18, f=3600, low=420):
    """A sharp crack in ice: a bright transient, the dispersion chirp and a short body knock."""
    return mix(g(click(0.004, 1800, 6500, 0.0012), 0.9), g(pew(f, low, d, d * 0.25), 0.7),
               g(kick(R(520, 640), 240, d, 0.012, 0.03, 1.6), 0.45))


def shatter(d, per_s, fall, lo=1800, hi=6200):
    """Ice breaking into many pieces: glassy grains thinning out, a few with a tiny ring."""
    x = grains(d, per_s, lo, hi, 0.002, 0.009, fall)
    tinks = np.zeros(N(d))
    for _ in range(int(per_s * d * 0.08) + 2):
        tt = min(S.rng.exponential(fall), d * 0.7)
        y = crystal(R(1700, 3600), 0.18, R(0.025, 0.05))
        s0 = N(tt); n = min(len(y), len(tinks) - s0)
        tinks[s0:s0 + n] += y[:n] * R(0.2, 0.5)
    return mix(x, g(tinks, 0.6))


def _narrow(x, lo, hi):
    """A band twice over: a steeper, more singing resonance than one bpf."""
    return bpf(bpf(x, lo, hi), lo, hi)


def blade(d, f=2600, rough=0.5, swell=0.35, glide=1.0):
    """A skate blade on ice: noise through two narrow steel resonances (the second gliding by `glide`, the
    edge carving), a stick-slip flutter, under a soft hiss of shaved ice."""
    n = N(d); t = np.arange(n) / SR
    src = noise(d)
    flutter = 1 + rough * lpf(S.rng.standard_normal(n), 60) * 4
    u = t / d
    a = _narrow(src * flutter, f * 0.97, f * 1.03)
    b = _narrow(src * flutter, f * 1.55, f * 1.6)
    c = _narrow(src * flutter, f * glide * 0.97, f * glide * 1.03)
    body = (1 - u) * (a + 0.35 * b) + u * (c + 0.3 * b)
    shave = lpf(bpf(src, 1500, 5000), 5500) * 0.12
    e = np.sin(np.pi * np.clip(u, 0, 1)) ** swell * env(n, 0.012, d * 0.7)
    return (body * 3.0 + shave) * e


def frost(d, lo=1200, hi=5200, a=0.02, decay=0.25):
    """Cold air: a soft band of breathy noise."""
    return fade(S.hiss(d, lo, hi, a, decay))



# ------------------------------------------------------------------ LMB: Ice Dart
def dart(i):
    """A homing shard flicked from her hand: a glass flick, a light whoosh, a pinch of weight."""
    d = 0.24
    p = [1.0, 1.07, 0.94, 1.12][i]
    whoosh = bpf(noise(d), 1400, 4200) * env(N(d), 0.01, 0.05)
    return mix(g(click(0.003, 2500, 6000, 0.0008), 0.5),
               g(crystal(2350 * p, d, 0.06), 0.55),
               g(pew(4200 * p, 1500, 0.05), 0.35),
               g(whoosh, 0.6),
               g(kick(760 * p, 380, 0.08, 0.01, 0.025, 1.5), 0.35))


def beam(i):
    """The skating beam: a straighter, thicker ice bolt; a falling glass tone over a jet of frost."""
    d = 0.32
    p = [1.0, 1.05, 0.95, 1.09][i]
    tone = S.fm(1900 * p, 1.41, 1.6, d, 0.09) * 0.7
    fall = S.sweep(2400 * p, 1200 * p, d, curve=0.6) * env(N(d), 0.004, 0.08)
    jet = bpf(noise(d), 900, 4500) * env(N(d), 0.006, 0.09)
    return mix(g(click(0.003, 2000, 6000, 0.001), 0.6), g(tone, 0.5), g(fall, 0.35), g(jet, 0.7),
               g(kick(520 * p, 220, 0.12, 0.015, 0.04, 1.8), 0.5), g(crystal(2900 * p, 0.3, 0.07), 0.3))


def dart_hit(i):
    """A dart landing: it pierces with a crack, a glass ting and a small cold thud, then a puff of frost."""
    d = 0.4
    p = [1.0, 1.08, 0.93, 1.15][i]
    return mix(g(ice_crack(0.16, 3800 * p, 500), 0.9),
               g(crystal(1850 * p, 0.35, 0.09), 0.45),
               g(kick(240 * p, 110, 0.18, 0.02, 0.05, 2.0), 0.7),
               g(at(frost(0.3, 1500, 5000, 0.01, 0.08), 0.01), 0.4),
               g(shatter(0.2, 70, 0.03), 0.35))


# ------------------------------------------------------------------ RMB: Ice Spear
def spear_aim():
    """The spear crystallising between her palms: crackle gathering, a glass tone rising, frost swelling."""
    d = 0.6
    t = T(d)
    rise = S.sweep(620, 1450, d, curve=1.4) * (0.5 - 0.5 * np.cos(np.pi * np.clip(t / 0.45, 0, 1))) \
        * np.exp(-np.maximum(0, t - 0.45) / 0.08)
    over = S.sweep(1240, 2900, d, curve=1.4) * 0.25 * (t / d)
    crackle = grains(d, 90, 1500, 5000, 0.002, 0.006) * (t / d) ** 1.5
    swell = frost(d, 900, 4200, 0.35, 0.2)
    return mix(g(rise + over, 0.45), g(crackle, 0.6), g(swell, 0.5), g(at(crystal(1450, 0.25, 0.08), 0.42), 0.4))


def lance():
    """The spear driven out of her palms: a heavy shove, a low glassy shaft humming away, a frost wake."""
    d = 0.7
    t = T(d)
    shove = kick(170, 70, 0.3, 0.04, 0.09, 2.4)
    rush = bpf(noise(d), 500, 2600) * env(N(d), 0.03, 0.18)
    shaft = (S.sweep(880, 700, d) + 0.5 * S.sweep(1320, 1050, d) + 0.25 * S.sweep(2210, 1760, d)) \
        * env(N(d), 0.01, 0.22) * (1 + 0.25 * np.sin(2 * np.pi * 21 * t))
    return mix(g(click(0.004, 1500, 5000, 0.0015), 0.5), g(shove, 0.8), g(rush, 0.6), g(shaft, 0.32),
               g(frost(d, 1500, 5000, 0.05, 0.25), 0.3), g(at(crystal(1760, 0.4, 0.12), 0.02), 0.3))


def zone(i):
    """The spear lands: spikes of ice burst up with a crack and a thud, the slow zone spreads in a cold puff."""
    d = 1.0
    p = [1.0, 1.04, 0.96, 1.07][i]
    return mix(g(ice_crack(0.22, 3200 * p, 300), 1.0),
               g(kick(180 * p, 65, 0.4, 0.03, 0.1, 2.2), 0.9),
               g(sub(90, 45, 0.4, 0.12), 0.4),
               g(shatter(0.5, 110, 0.06), 0.6),
               g(at(frost(0.8, 900, 4000, 0.06, 0.3), 0.04), 0.45),
               g(at(crystal(1320 * p, 0.8, 0.3), 0.03), 0.3))


def burst():
    """The spear zone detonates: a deep glassy blast, the dome bursting into shards, cold air rushing out."""
    d = 1.5
    body = mix(g(kick(150, 42, 0.8, 0.05, 0.2, 2.6), 1.0), g(sub(70, 34, 1.0, 0.3), 0.7))
    cracks = mix(*[at(g(pew(R(3000, 4200), R(250, 450), 0.12), R(0.35, 0.6)), R(0.0, 0.12)) for _ in range(4)])
    glass = mix(g(crystal(1180, 1.2, 0.4), 0.45), g(at(crystal(1570, 1.1, 0.35), 0.02), 0.35),
                g(at(crystal(2350, 0.9, 0.25), 0.035), 0.25))
    return reflections(mix(g(click(0.005, 1200, 5500, 0.002), 0.8), body, cracks, glass,
                           g(shatter(1.0, 160, 0.12), 0.8),
                           g(tail(1.4, 2200, 0.35, 0.02, 0.03), 0.45)))


def splinter(i):
    """Shatter: the icy shell round a foe bursts, a bright glass explosion with a mid thump."""
    d = 1.0
    p = [1.0, 1.06, 0.95, 1.1][i]
    chord = mix(g(crystal(1660 * p, 0.8, 0.22), 0.4), g(at(crystal(2090 * p, 0.7, 0.2), 0.015), 0.3),
                g(at(crystal(2490 * p, 0.6, 0.16), 0.03), 0.22))
    return mix(g(ice_crack(0.2, 4200 * p, 700), 1.0),
               g(kick(300 * p, 120, 0.3, 0.02, 0.07, 2.0), 0.7),
               g(shatter(0.8, 220, 0.08, 2000, 6200), 0.8),
               chord,
               g(at(frost(0.6, 1500, 5200, 0.02, 0.18), 0.02), 0.35))


# ------------------------------------------------------------------ E: Rink Wall
def wall_tell():
    """The 0.2 s tell: ice gathering at her feet, a quick rising crackle over a low groan."""
    d = 0.42
    t = T(d)
    crackle = grains(d, 140, 1400, 5000, 0.002, 0.006) * np.clip(t / 0.22, 0, 1) * np.exp(-np.maximum(0, t - 0.22) / 0.05)
    groan = lpf(S.creak(d, 70, 110, 0.5, 1400), 2000) * 0.6
    glint = S.sweep(900, 1800, d, curve=1.2) * env(N(d), 0.18, 0.06) * 0.3
    return mix(g(crackle, 0.7), g(groan, 0.7), glint, g(frost(d, 800, 3500, 0.15, 0.1), 0.35))


def wall():
    """The wall erupts: a slab of ice grinding up out of the ground, a heavy thud and a glassy ring."""
    d = 1.0
    t = T(d)
    grind = lpf(noise(d), 900) * (1 + 0.8 * np.abs(lpf(S.rng.standard_normal(N(d)), 35)) * 6) \
        * env(N(d), 0.01, 0.22)
    return reflections(mix(g(ice_crack(0.2, 2600, 260), 0.9),
                           g(kick(130, 50, 0.6, 0.04, 0.16, 2.6), 1.0),
                           g(sub(65, 38, 0.6, 0.2), 0.6),
                           g(grind, 0.5),
                           g(lpf(S.creak(0.6, 85, 55, 0.7, 1800), 2200), 0.4),
                           g(shatter(0.5, 80, 0.07), 0.45),
                           g(at(crystal(990, 0.8, 0.3), 0.04), 0.35)))


def freeze():
    """E again: the sliding wall locks fast, a sweep of freezing crackle and a hard glassy 'chk'."""
    d = 0.8
    t = T(d)
    sweep_in = grains(0.25, 300, 2000, 6000, 0.002, 0.005) * np.linspace(0.2, 1.0, N(0.25))
    lock = at(mix(g(ice_crack(0.14, 4000, 600), 1.0), g(kick(420, 180, 0.12, 0.01, 0.03, 2.0), 0.6)), 0.22)
    shimmer = at(mix(g(crystal(1980, 0.55, 0.2), 0.45), g(at(crystal(2640, 0.5, 0.16), 0.02), 0.3)), 0.22)
    return mix(g(sweep_in, 0.6), lock, shimmer, g(at(frost(0.5, 1500, 5000, 0.02, 0.15), 0.22), 0.35))


# ------------------------------------------------------------------ X: Rimelock
def lock():
    """Sealed in ice: frost races over her, the shell closes with a muffled thud, a breath of her voice inside."""
    d = 1.3
    t = T(d)
    race = grains(0.7, 260, 1500, 5500, 0.002, 0.006) * np.clip(t[:N(0.7)] / 0.5, 0, 1) ** 0.7
    rise = S.sweep(700, 1900, 0.7, curve=1.3) * env(N(0.7), 0.3, 0.2)
    close = at(mix(g(kick(150, 55, 0.6, 0.04, 0.14, 2.4), 1.0), g(sub(60, 36, 0.6, 0.2), 0.6),
                   g(ice_crack(0.16, 2800, 300), 0.6)), 0.5)
    hum = S.voice(1.1, 470, 410, 'mm', breath=0.6, vib=0.012, scale=1.2, a=0.2, decay=0.4)
    glass = at(mix(g(crystal(1245, 0.8, 0.35), 0.4), g(at(crystal(1865, 0.7, 0.3), 0.03), 0.28)), 0.5)
    return mix(g(race, 0.55), g(rise, 0.3), close, g(hum, 0.25), glass, g(frost(d, 900, 4200, 0.3, 0.3), 0.3))


def creak(i):
    """The shell and the rink under strain: a stick-slip groan in the ice and a tiny crack."""
    d = 0.5
    p = [1.0, 1.1, 0.9, 1.2][i]
    groan = lpf(S.creak(d, 140 * p, 95 * p, 0.6, 2200), 2600)
    return mix(g(groan, 1.0), g(at(pew(R(2400, 3400), 400, 0.06), R(0.05, 0.25)), 0.3),
               g(lpf(noise(d), 600) * env(N(d), 0.05, 0.15), 0.25))


def crash():
    """Rimelock cracks open: the biggest blast in her kit, the shell exploding into shards, a long cold tail."""
    d = 2.0
    body = mix(g(kick(140, 36, 1.0, 0.06, 0.26, 2.8), 1.0), g(sub(62, 30, 1.3, 0.4), 0.8))
    cracks = mix(*[at(g(pew(R(2600, 4200), R(200, 380), 0.14), R(0.35, 0.65)), R(0.0, 0.18)) for _ in range(6)])
    chord = mix(*[at(g(crystal(f, 1.6, 0.5), k), dl) for f, k, dl in
                  ((990, 0.45, 0.0), (1245, 0.38, 0.02), (1480, 0.32, 0.04), (1975, 0.22, 0.06))])
    return reflections(mix(g(click(0.006, 1200, 5000, 0.002), 0.9), body, cracks, chord,
                           g(shatter(1.4, 200, 0.16), 0.9),
                           g(tail(1.9, 1800, 0.5, 0.02, 0.04), 0.5),
                           g(at(frost(1.6, 800, 3800, 0.1, 0.6), 0.1), 0.35)))


def crack():
    """Rimelock broken early: the shell just splits and falls apart, no blast."""
    d = 0.6
    return mix(g(ice_crack(0.2, 3000, 350), 1.0), g(kick(220, 100, 0.25, 0.02, 0.06, 2.0), 0.6),
               g(shatter(0.5, 120, 0.07), 0.6), g(at(crystal(1480, 0.45, 0.12), 0.02), 0.25))


# ------------------------------------------------------------------ Shift: the skate
def dash():
    """The push-off: the blade bites with a crisp tick, then a long scraping glide and a frosty rush of air."""
    d = 0.55
    bite = mix(g(click(0.004, 2000, 6000, 0.0012), 0.7), g(crystal(2900, 0.12, 0.03), 0.3),
               g(kick(380, 200, 0.06, 0.01, 0.02, 1.6), 0.4))
    glide = blade(0.5, 2700, 0.4, 0.3, 1.12)
    air = bpf(noise(d), 600, 2800) * env(N(d), 0.06, 0.16)
    return mix(bite, g(at(glide, 0.01), 0.9), g(air, 0.5))


def skate_scrape(i):
    """Her signature skate scrape: one stride's blade carving the ice, the resonance gliding with the edge."""
    d = 0.5
    f = [2600, 2850, 2450, 3000][i]
    gl = [1.15, 0.9, 1.2, 0.88][i]
    return mix(g(blade(d, f, 0.55, 0.45, gl), 1.0), g(click(0.003, 2500, 6000, 0.001), 0.25),
               g(lpf(noise(d), 500) * env(N(d), 0.03, 0.15), 0.15))


def stop():
    """The hockey stop: both blades braced sideways, a hard spray of shaved ice."""
    d = 0.45
    t = T(d)
    hard = blade(0.38, 2300, 0.9, 0.15, 0.8)
    spray = bpf(noise(d), 1500, 5500) * env(N(d), 0.008, 0.1)
    chips = grains(0.35, 90, 2000, 5500, 0.002, 0.006, 0.08)
    return mix(g(hard, 0.9), g(spray, 0.7), g(chips, 0.5), g(kick(300, 140, 0.1, 0.01, 0.03, 1.6), 0.4))


def chime(i):
    """Her signature ice crystal chime: a few glass crystals in a cold, open chord, softly arpeggiated."""
    chords = ([1319, 1976, 2489], [1175, 1760, 2349], [1397, 2093, 2637], [1245, 1865, 2489])
    d = 1.4
    out = []
    for k, f in enumerate(chords[i]):
        out.append(at(g(crystal(f, d - 0.1, 0.55 - 0.08 * k), [0.5, 0.38, 0.28][k]), 0.035 * k + R(0, 0.01)))
    air = frost(d, 2000, 5000, 0.02, 0.4) * 0.08
    return mix(*out, air)


# ------------------------------------------------------------------ voice: a woman, airy and siren-like
def _siren(d, f0, f1, vowel, breath=0.45, vib=0.015, rasp=0.0, a=0.012, decay=None):
    """Her voice: a light, breathy female voice, doubled a few cents apart so it floats."""
    v1 = S.voice(d, f0, f1, vowel, breath, rasp, vib, 1.2, a, decay)
    v2 = S.voice(d, f0 * 1.006, f1 * 1.006, vowel, breath * 0.6, 0.0, vib, 1.22, a, decay)
    return v1 + 0.45 * v2


def hurt(i):
    """A short pained gasp, more breath than voice."""
    sets = ((0.24, 560, 430, 'ah'), (0.28, 520, 400, 'eh'), (0.22, 600, 470, 'ah'), (0.3, 500, 380, 'uh'))
    d, f0, f1, vw = sets[i]
    v = _siren(d, f0, f1, vw, 0.55, 0.0, 0.08, 0.008, d * 0.4)
    gasp = hpf(noise(0.08), 1500) * env(N(0.08), 0.004, 0.025)
    return mix(g(gasp, 0.12), g(v, 1.0))


def down():
    """Knocked down: a falling siren's cry that thins to a cold breath, a crust of frost over it."""
    d = 1.1
    v = _siren(0.9, 540, 260, 'oh', 0.5, 0.025, 0.12, 0.02, 0.4)
    breath = at(frost(0.6, 1200, 4500, 0.08, 0.25), 0.45)
    cold = at(mix(g(crystal(1480, 0.5, 0.18), 0.12), g(shatter(0.3, 40, 0.06), 0.15)), 0.5)
    return mix(v, g(breath, 0.25), cold)


def death():
    """Her last cry: a siren's wail rising then falling away, a faint demon's growl beneath it, then the ice
    takes her: a crack, shards and a cold wind."""
    d = 2.2
    t = T(1.4)
    rise = S.voice(0.35, 520, 640, 'ah', 0.45, 0.0, 0.02, 1.2, 0.03, 0.6)
    fall = S.voice(1.05, 640, 210, 'ah', 0.5, 0.15, 0.035, 1.18, 0.01, 0.45)
    dbl = S.voice(1.05, 644, 211, 'oh', 0.3, 0.0, 0.03, 1.22, 0.01, 0.45)
    wail = mix(rise, at(fall + 0.4 * dbl, 0.3))
    growl = at(S.voice(0.9, 130, 85, 'uh', 0.3, 0.9, 0.0, 0.85, 0.08, 0.35), 0.35)
    ice = at(mix(g(ice_crack(0.2, 3000, 300), 0.35), g(shatter(0.6, 90, 0.1), 0.3),
                 g(crystal(1245, 0.7, 0.25), 0.12)), 1.15)
    wind = at(frost(1.0, 700, 3200, 0.2, 0.4), 1.0)
    return mix(g(wail, 1.0), g(growl, 0.22), ice, g(wind, 0.2))


# ------------------------------------------------------------------ footsteps: a light heel and a blade's tick
def _tick(f, k):
    """The faint tick of her blade touching down."""
    return g(crystal(f, 0.09, 0.018, ((1.0, 1.0), (2.32, 0.4))), k)


def step_grass(i):
    d = 0.18
    crush = bpf(noise(d), 300, 2200) * env(N(d), 0.006, 0.035)
    blades = grains(0.1, 120, 1500, 4500, 0.001, 0.004, 0.02)
    return mix(g(crush, 1.0), g(blades, 0.35), g(kick(R(170, 200), 90, 0.06, 0.01, 0.02, 1.3), 0.35),
               _tick(R(2900, 3300), 0.08))


def step_stone(i):
    d = 0.2
    heel = mix(g(click(0.003, 2000, 6000, 0.0008), 0.8), g(kick(R(900, 1050), 520, 0.05, 0.004, 0.012, 1.5), 0.55))
    scrape = at(blade(0.06, R(2400, 2900), 0.4, 0.5, 1.0), 0.004)
    return mix(heel, g(scrape, 0.25), _tick(R(2500, 2900), 0.35), g(lpf(noise(d), 1200) * env(N(d), 0.002, 0.02), 0.25))


def step_wood(i):
    d = 0.22
    tok = bpf(noise(0.05), 350, 1800) * env(N(0.05), 0.001, 0.012)
    knock = mix(g(tok, 0.9), g(kick(R(260, 300), 170, 0.2, 0.008, 0.04, 1.4), 0.8),
                g(S.ring([R(420, 470), R(860, 940)], 0.2, [0.03, 0.02], [0.4, 0.2]), 0.6))
    return mix(g(click(0.003, 1500, 5000, 0.001), 0.5), knock, _tick(R(2600, 3000), 0.25))


def step_snow(i):
    d = 0.24
    crunch = grains(0.12, 420, 500, 3500, 0.002, 0.007, 0.04)
    pack = lpf(noise(d), 900) * env(N(d), 0.01, 0.04)
    glide = at(bpf(noise(0.14), 2000, 5000) * env(N(0.14), 0.03, 0.04), 0.03)
    return mix(g(crunch, 0.9), g(pack, 0.6), g(glide, 0.15))


TOP = 9000.0      # Hz: a gentle roll-off over every sound, so the ice stays clear, never fizzy


def polish(x):
    return lpf(lpf(x, TOP), TOP)


class S2:
    """save_cat / takes_cat through polish()."""
    @staticmethod
    def save_cat(name, x, cat):
        S.save_cat(name, polish(x), cat)

    @staticmethod
    def takes_cat(name, fn, n, cat):
        S.takes_cat(name, lambda i: polish(fn(i)), n, cat)


def build():
    A = 'rimewright_'
    S2.takes_cat('rime_shard', dart, 3, 'fire')
    S2.takes_cat('rime_beam', beam, 3, 'fire')
    S2.takes_cat(A + 'hit', dart_hit, 3, 'impact')
    S2.save_cat('rime_spear_aim', spear_aim(), 'cast')
    S2.save_cat('rime_lance', lance(), 'cast')
    S2.takes_cat('rime_zone', zone, 3, 'impact')
    S2.save_cat('rime_burst', burst(), 'impact')
    S2.takes_cat('rime_splinter', splinter, 3, 'impact')
    S2.save_cat('rime_wall_tell', wall_tell(), 'cast')
    S2.save_cat('rime_wall', wall(), 'impact')
    S2.save_cat('rime_freeze', freeze(), 'impact')
    S2.save_cat('rime_lock', lock(), 'cast')
    S2.takes_cat('rime_creak', creak, 3, 'cast')
    S2.save_cat('rime_crash', crash(), 'impact')
    S2.save_cat('rime_crack', crack(), 'impact')
    S2.save_cat(A + 'dash', dash(), 'dash')
    S2.save_cat('rime_stop', stop(), 'dash')
    S2.takes_cat(A + 'skate_scrape', skate_scrape, 3, 'signature')
    S2.takes_cat(A + 'chime', chime, 3, 'signature')
    S2.takes_cat(A + 'hurt', hurt, 3, 'grunt')
    S2.save_cat(A + 'down', down(), 'grunt')
    S2.save_cat(A + 'death', death(), 'grunt')
    for surf, fn in (('grass', step_grass), ('stone', step_stone), ('wood', step_wood), ('snow', step_snow)):
        S2.takes_cat(A + 'step_' + surf, fn, 3, 'step')


if __name__ == '__main__':
    build()
    print('claire sfx written')
