"""Boki sounds (docs/AUDIO.md): small, cute and alive, with an element flavour. Run from tools/.

Voices are two layers: a bright chirp (a sine with a pitch scoop, vibrato and a quiet 2nd/3rd harmonic,
the "squeak") and a soft wordless vowel (S.voice, formants scaled up for a small body). Several takes
of each so a Boki that talks a lot never repeats itself. Ability casts are one cue per Boki type,
k_<type> for the 18 types of KinParts.THEMES (the kin's theme field), each a small sound picture:
  poison gloop and a spit    spore puffs and sparkle    psychic a soft thud and a pull
  crystal a glassy chime fan  fairy moonlit wind and bell  sound a ping bouncing away
  normal a plain pop         water bloops and a splash  dragon a growl over a rising ember rush
  fire a crackling whoosh    ice a crack and cold tinkle  electric a zap and fizz
  rock a grind and clack     grass a leafy swish and pluck  dark a falling hush with a whisper
  steel a clang and ring     bug a chitter and wing buzz  flying a feathery swoop
Existing names are regenerated (kin_happy/unsure/alert, kinhit, recall, throw, catch, bond, skill);
new ones (boki_*) are lazy-loaded, so each needs its call site listed in the report.
"""
import numpy as np
import sfx_lib as S
from sfx_lib import N, T, env, mix, at, lpf, hpf, bpf, noise

S.reseed(5309)


def squeak(f, d, scoop=0.12, vib=0.02, bright=0.25, a=0.006, tail_d=None):
    """A bright little chirp: the pitch scoops up into f, wobbles, and rounds off."""
    n = N(d); u = np.arange(n) / n; t = u * d
    ff = f * (1 + scoop * np.exp(-u * 9)) * (1 + vib * np.sin(2 * np.pi * 8 * t))
    ph = 2 * np.pi * np.cumsum(ff) / S.SR
    x = np.sin(ph) + 0.18 * np.sin(2 * ph) + bright * 0.2 * np.sin(3 * ph)
    return x * env(n, a, tail_d or d * 0.45)


def vowel(f0, f1, d, v='eh', scale=1.35, breath=0.12, a=0.01):
    return S.voice(d, f0, f1, v, breath=breath, vib=0.02, scale=scale, a=a, decay=d * 0.5)


def j(i, s=0.05):
    return 1.0 + (0 if i == 0 else S.rng.uniform(-s, s))


def soft(x, cut=5200):
    return lpf(lpf(x, cut), cut * 1.3)


def room(x, amt=0.5):
    return S.reflections(x, ((0.02, 0.18 * amt, 2400), (0.047, 0.12 * amt, 1700), (0.09, 0.07 * amt, 1200)))


def bubble(f, d=0.07, rise=1.6):
    """A bubble: a sine rising quickly, popped by a fast fall."""
    return S.sweep(f, f * rise, d) * env(N(d), 0.004, d * 0.35)


# ---------------------------------------------------------------- voices
HAPPY = [((760, 980, 1200), (0.11, 0.09, 0.16)), ((880, 1100, 990), (0.09, 0.09, 0.14)),
         ((700, 880, 1180), (0.1, 0.1, 0.17)), ((820, 1040, 1320), (0.08, 0.08, 0.15))]


def happy(i):
    notes, ds = HAPPY[i % len(HAPPY)]
    f = j(i, 0.04)
    out = np.zeros(0)
    t0 = 0.0
    for k, (fr, dd) in enumerate(zip(notes, ds)):
        piece = mix(squeak(fr * f, dd, 0.14), 0.45 * vowel(fr * f * 0.5, fr * f * 0.55, dd, 'ee', 1.4))
        out = mix(out, at(piece, t0))
        t0 += dd * 0.85
    return soft(room(out, 0.3))


def unsure(i):
    f = j(i, 0.04)
    a = mix(squeak(640 * f, 0.14, -0.10, 0.03), 0.5 * vowel(330 * f, 300 * f, 0.14, 'uh', 1.3))
    b = mix(S.sweep(470 * f, 600 * f, 0.22) * env(N(0.22), 0.01, 0.1) * 0.8,
            0.3 * mix(squeak(500 * f, 0.22, 0.0, 0.05, tail_d=0.12), 0.5 * vowel(250 * f, 360 * f, 0.22, 'eh', 1.3)))
    return soft(room(mix(a, at(b, 0.17)), 0.3), 4200)


def alert(i):
    f = j(i, 0.03)
    parts = [at(mix(squeak(1000 * f * (1 + 0.03 * k), 0.07, 0.2, 0.0, a=0.003), 0.35 * vowel(560 * f, 600 * f, 0.07, 'ee', 1.4)),
                0.095 * k) for k in range(2 + (i % 2))]
    return soft(room(mix(*parts), 0.3), 6000)


def hit(i):
    """The Boki getting hit or landing a blow: a soft thump, a squishy pop and a tiny yip."""
    f = j(i, 0.06)
    thump = S.kick(190 * f, 90, 0.14, 0.012, 0.03, 1.5)
    pop = bubble(380 * f, 0.07, 2.2) * 0.8
    yip = squeak(900 * f, 0.09, -0.2, 0.0, a=0.003) * 0.5
    return soft(mix(thump * 0.8, pop, at(yip, 0.02), at(S.crack(0.08, 600, 2600, 0.02) * 0.35, 0.0)), 3800)


def downed(i):
    """A small sad mew that sags and trails off."""
    f = j(i, 0.04)
    n = 0.5
    mew = squeak(620 * f, n, 0.0, 0.04, tail_d=0.3)
    sag = S.sweep(620 * f, 360 * f, n) * env(N(n), 0.02, 0.28)
    return soft(room(mix(0.5 * mew, 0.6 * sag, 0.4 * vowel(330 * f, 200 * f, n, 'uh', 1.3, 0.2)), 0.4), 3200)


def revive(i):
    f = j(i, 0.02)
    up = mix(squeak(520 * f, 0.18, 0.1), at(squeak(700 * f, 0.18, 0.1), 0.12), at(squeak(930 * f, 0.3, 0.15), 0.24))
    sparkle = at(S.chime(1568 * f, 0.8, 0.3, ((1.0, 0.6), (2.76, 0.2))) * 0.25, 0.3)
    return soft(room(mix(up, sparkle), 0.7))


# ---------------------------------------------------------------- calls and bonds
def recall(i):
    """Called home: a spiral of air rushes in, ends in a small happy pop."""
    d = 0.45; n = N(d); u = np.arange(n) / n
    sw = S.sweep(350, 1300, d, curve=1.5) * np.sin(np.pi * u ** 0.7) * 0.6
    air = bpf(noise(d), 500, 2600) * u ** 1.6 * (1 - u) * 3
    pop = at(mix(bubble(520, 0.08, 2.0), squeak(1100, 0.1, 0.1) * 0.5), d - 0.08)
    return soft(room(mix(sw * 0.7, air * 0.35, pop), 0.4), 4200)


def throw(i):
    """Sent out: a breezy whoosh with a rising twinkle."""
    d = 0.32; n = N(d); u = np.arange(n) / n
    air = bpf(noise(d), 500, 3000) * np.sin(np.pi * u ** 0.6) ** 1.5
    tw = S.sweep(500 * j(i), 1250, d) * np.sin(np.pi * u) * 0.22
    return soft(room(mix(air * 0.9, tw), 0.3), 3800)


def catch(i):
    notes = [392, 494, 587, 784, 988]
    arp = [at(mix(squeak(f, 0.26, 0.04, 0.01, tail_d=0.12), 0.5 * squeak(f * 2, 0.2, 0, 0, tail_d=0.07)), 0.095 * k)
           for k, f in enumerate(notes)]
    return soft(room(mix(*arp, at(S.chime(1568, 1.0, 0.4, ((1.0, 0.5), (2.76, 0.15))) * 0.2, 0.4)), 0.8), 5400)


def bond(i):
    heart = [at(mix(S.chime(f, 0.9, 0.4, ((1.0, 1.0), (2.0, 0.3), (4.1, 0.1))), 0.3 * squeak(f * 0.5, 0.3, 0, 0.01, tail_d=0.15)),
                0.1 * k) for k, f in enumerate([523, 659, 784, 1047])]
    return soft(room(mix(*heart), 0.9), 4800)


def skill(i):
    d = 0.4; n = N(d); u = np.arange(n) / n
    rise = S.sweep(420, 1100, d) * np.sin(np.pi * u ** 0.8) * 0.4
    sparkle = S.grains(d, 60, 3000, 8000, 0.002, 0.005, fall=0.15) * 0.5
    return soft(room(mix(rise, sparkle, at(squeak(1100, 0.2, 0.1) * 0.4, 0.18)), 0.4), 5000)


# ---------------------------------------------------------------- types (k_<type>)
def poison(i):
    """Toxic gloop: a run of fat bubbles that climb, a wet spit, a sizzling hiss."""
    f = j(i, 0.08)
    bubs = [at(bubble(180 * f * (1 + 0.35 * k + S.rng.uniform(-0.05, 0.1)), 0.09, 1.9), 0.06 * k) for k in range(5)]
    spit = at(bpf(noise(0.16), 1500, 5000) * env(N(0.16), 0.004, 0.04) * 0.8, 0.28)
    hiss = bpf(noise(0.5), 3000, 7000) * env(N(0.5), 0.1, 0.18) * 0.18
    sub = S.sweep(110, 70, 0.4) * env(N(0.4), 0.02, 0.12) * 0.4
    return soft(room(mix(*bubs, spit, hiss, sub), 0.4), 4200)


def spore(i):
    """Fluffy puffs of dust that fall as soft sparkle."""
    f = j(i, 0.1)
    puffs = [at(bpf(noise(0.2), 250 * f, 1600) * env(N(0.2), 0.02, 0.06) * g, dl)
             for dl, g in ((0.0, 1.0), (0.11, 0.65), (0.2, 0.4))]
    dust = S.grains(0.5, 55, 2500, 7500, 0.002, 0.006, fall=0.18) * 0.35
    fall = [at(S.chime(1318 * f * r, 0.5, 0.18, ((1.0, 0.5),)) * 0.17, 0.12 + 0.1 * k) for k, r in enumerate((1.0, 0.89, 0.75))]
    return soft(room(mix(*puffs, at(dust, 0.05), *fall), 0.5), 4600)


def psychic(i):
    """A deep soft thud that sucks in first: a reverse swell, a sub drop, a stone rumble."""
    f = j(i, 0.06)
    d = 0.7
    suck = lpf(noise(0.18), 500) * (np.arange(N(0.18)) / N(0.18)) ** 2 * 0.7
    hit_t = 0.16
    drop = at(S.sweep(120 * f, 42, 0.55) * env(N(0.55), 0.006, 0.17) * 1.3, hit_t)
    rumble = at(bpf(noise(0.5), 60, 380) * env(N(0.5), 0.02, 0.14) * 0.9, hit_t)
    tick = at(S.crack(0.06, 300, 1800, 0.012) * 0.3, hit_t)
    return lpf(room(mix(suck, drop, rumble, tick), 0.3), 1400 if i == 0 else 1400 + 100 * i)


def crystal(i):
    """A glassy chime fan climbing a pentatonic scale, with a shimmer."""
    f = j(i, 0.02)
    notes = [(784, 0.0), (988, 0.05), (1175, 0.1), (1568, 0.15)]
    bells = [at(S.chime(fr * f, 0.9, 0.35, ((1.0, 1.0), (2.76, 0.4), (5.4, 0.2))) * (0.9 - 0.12 * k), dl)
             for k, (fr, dl) in enumerate(notes)]
    shimmer = at(S.grains(0.6, 70, 5000, 9500, 0.001, 0.003, fall=0.2) * 0.3, 0.1)
    air = bpf(noise(0.4), 1200, 4000) * env(N(0.4), 0.1, 0.1) * 0.12
    return soft(room(mix(*bells, shimmer, air), 0.8), 7500)


def fairy(i):
    """Moonlit wind: a breathy swirl that rises and a pale, slow bell inside it."""
    f = j(i, 0.04)
    d = 0.75; n = N(d); u = np.arange(n) / n
    wind = bpf(noise(d), 500, 2400) * np.sin(np.pi * u) ** 2 * (0.6 + 0.4 * np.sin(2 * np.pi * 2.2 * u))
    pad_t = S.sweep(440 * f, 587 * f, d) * np.sin(np.pi * u) ** 2 * 0.25
    bell = at(S.chime(880 * f, 0.9, 0.5, ((1.0, 0.8), (2.0, 0.25), (3.0, 0.1))) * 0.35, 0.22)
    return soft(room(mix(wind * 0.9, pad_t, bell), 0.7), 3400)


def sound(i):
    """One round ping that bounces away through a dark room, each repeat darker and quieter."""
    f = j(i, 0.03)
    base = mix(S.chime(660 * f, 0.3, 0.12, ((1.0, 1.0), (2.0, 0.3))), S.kick(140, 70, 0.2, 0.01, 0.05, 1.5) * 0.5)
    out = np.zeros(0)
    cut = 3600
    for k in range(5):
        out = mix(out, at(lpf(base, cut) * 0.62 ** k, 0.13 * k))
        cut *= 0.72
    rumble = bpf(noise(0.5), 60, 300) * env(N(0.5), 0.03, 0.15) * 0.5
    return soft(mix(out, rumble), 4200)


def normal(i):
    """No flavour at all: a round, friendly pop with a short soft puff behind it."""
    f = j(i, 0.05)
    pop = S.kick(420 * f, 160, 0.22, 0.04, 0.06, 1.4) * 0.9
    puff = at(bpf(noise(0.18), 600, 2600) * env(N(0.18), 0.01, 0.05) * 0.4, 0.03)
    return soft(room(mix(pop, puff, at(squeak(660 * f, 0.12, 0.08) * 0.3, 0.06)), 0.3), 4200)


def water(i):
    """Round drops that climb and a small splash: three bloops, then a wet slap and a trickle."""
    f = j(i, 0.06)
    drops = [at(bubble(320 * f * (1 + 0.28 * k), 0.08, 1.5), 0.07 * k) for k in range(3)]
    slap = at(bpf(noise(0.14), 900, 4200) * env(N(0.14), 0.003, 0.04) * 0.7, 0.24)
    trickle = at(S.grains(0.4, 70, 1200, 4200, 0.002, 0.005, fall=0.12) * 0.35, 0.26)
    return soft(room(mix(*drops, slap, trickle), 0.4), 3800)


def dragon(i):
    """A low growl rising into a short hot rush: a chest rumble with a throat rasp, then breath."""
    f = j(i, 0.05)
    growl = S.voice(0.55, 70 * f, 110 * f, 'uh', breath=0.2, rasp=0.5, scale=0.8, a=0.05, decay=0.3) * 0.9
    rush = at(bpf(noise(0.4), 700, 3800) * env(N(0.4), 0.12, 0.12) * 0.55, 0.22)
    sub_t = S.sweep(90 * f, 45, 0.5) * env(N(0.5), 0.02, 0.15) * 0.6
    return lpf(room(mix(growl, rush, sub_t), 0.3), 3600)


def fire(i):
    """A crackling whoosh: a hot air rush that swells and fades, over a burst of sparks."""
    f = j(i, 0.07)
    d = 0.6; n = N(d); u = np.arange(n) / n
    rush = bpf(noise(d), 400 * f, 3000 * f) * np.sin(np.pi * u ** 0.6) ** 1.5 * 0.9
    sparks = S.grains(d, 90, 1800, 7500, 0.001, 0.004, fall=0.2) * 0.5
    thump = at(S.kick(150, 60, 0.25, 0.04, 0.07, 1.6) * 0.6, 0.02)
    return soft(room(mix(rush, sparks, thump), 0.25), 5200)


def ice(i):
    """A cold crack and a falling tinkle: a hard glassy snap, thin shards, a cold hiss."""
    f = j(i, 0.04)
    snap = S.crack(0.1, 2500, 9000, 0.012) * 0.9
    shards = [at(S.chime((2200 + 380 * k) * f, 0.4, 0.1, ((1.0, 1.0), (2.4, 0.3))) * 0.25, 0.04 + 0.05 * k) for k in range(4)]
    cold = at(S.hiss(0.4, 4000, 10000, 0.05, 0.12) * 0.3, 0.05)
    return soft(room(mix(snap, *shards, cold), 0.5), 8500)


def electric(i):
    """A bright zap: a fast downward fizzing sweep, a crackle of arcs, a faint mains hum."""
    f = j(i, 0.06)
    zap = S.fm(1800 * f, 1.41, 5.0, 0.28, decay=0.08) * 0.5
    zip_t = S.sweep(3200 * f, 400, 0.22) * env(N(0.22), 0.001, 0.06) * 0.4
    arcs = S.grains(0.4, 120, 2500, 9000, 0.0005, 0.002, fall=0.12) * 0.55
    hum = at(S.sweep(120, 118, 0.3) * env(N(0.3), 0.03, 0.1) * 0.3, 0.05)
    return soft(room(mix(zap, zip_t, arcs, hum), 0.2), 7500)


def rock(i):
    """Stone on stone: a grinding scrape, a hard clack and a few falling pebbles (not psychic's soft thud)."""
    f = j(i, 0.06)
    grind = S.creak(0.3, 110 * f, 70, 0.9, 1800) * 0.7
    clack = at(mix(S.crack(0.05, 700, 3500, 0.012), S.kick(240, 110, 0.15, 0.02, 0.04, 2.0) * 0.6), 0.2)
    pebbles = [at(S.crack(0.03, 1200, 5000, 0.006) * (0.4 - 0.08 * k), 0.3 + 0.07 * k + S.rng.uniform(0, 0.02)) for k in range(4)]
    return lpf(room(mix(grind, clack, *pebbles), 0.3), 4200)


def grass(i):
    """A leafy swish and a springy pluck: rustling leaves sweep by, then a green stem twangs."""
    f = j(i, 0.05)
    d = 0.5; n = N(d); u = np.arange(n) / n
    leaves = bpf(noise(d), 2500, 8000) * np.sin(np.pi * u) ** 2 * (0.6 + 0.4 * np.sin(2 * np.pi * 14 * u)) * 0.7
    pluck = at(S.sweep(520 * f, 300 * f, 0.22) * env(N(0.22), 0.002, 0.07) * 0.6, 0.16)
    twang = at(S.chime(780 * f, 0.4, 0.12, ((1.0, 1.0), (2.0, 0.3))) * 0.25, 0.17)
    return soft(room(mix(leaves, pluck, twang), 0.4), 5000)


def dark(i):
    """A hush that drops away: a low descending drone with a hollow whisper that fades into dark."""
    f = j(i, 0.04)
    d = 0.8; n = N(d); u = np.arange(n) / n
    drone = S.sweep(220 * f, 70, d, curve=1.3) * np.sin(np.pi * u ** 0.5) * 0.7
    whisper = bpf(noise(d), 900, 3200) * np.sin(np.pi * u) ** 2 * 0.35
    thud = at(S.kick(100, 40, 0.3, 0.05, 0.09, 1.5) * 0.5, 0.18)
    return lpf(room(mix(drone, whisper, thud), 0.6), 2400)


def steel(i):
    """A metal clang and its ring: a hard strike, an inharmonic bell tone, a thin scrape-off."""
    f = j(i, 0.03)
    strike = S.click(0.006, 2000, 9000) * 0.8
    clang = S.chime(520 * f, 0.9, 0.3, ((1.0, 1.0), (2.32, 0.6), (4.1, 0.4), (6.7, 0.2))) * 0.7
    slide = at(bpf(noise(0.2), 3000, 9000) * env(N(0.2), 0.01, 0.05) * 0.25, 0.04)
    return soft(room(mix(strike, clang, slide), 0.35), 8000)


def bug(i):
    """A chitter and a wing buzz: quick clicking legs under a fast, wobbling buzz."""
    f = j(i, 0.05)
    clicks = [at(S.click(0.004, 3000, 8000) * (0.6 - 0.04 * k), 0.045 * k + S.rng.uniform(0, 0.012)) for k in range(7)]
    d = 0.4; n = N(d); t = np.arange(n) / S.SR
    buzz = bpf(S.sweep(210 * f, 260 * f, d, 'saw'), 300, 3000) * (0.6 + 0.4 * np.sin(2 * np.pi * 38 * t)) * env(n, 0.02, 0.15) * 0.8
    return soft(room(mix(*clicks, at(buzz, 0.05)), 0.2), 6000)


def flying(i):
    """A feathery swoop: a breath of wind that rises then falls, with a light flutter of wing beats."""
    f = j(i, 0.05)
    d = 0.6; n = N(d); u = np.arange(n) / n; t = u * d
    wind = bpf(noise(d), 600 * f, 3600 * f) * np.sin(np.pi * u) ** 1.5 * 0.9
    flap = bpf(noise(d), 200, 1100) * np.clip(np.sin(2 * np.pi * 9 * t), 0, 1) ** 2 * np.sin(np.pi * u) * 0.5
    whistle = S.sweep(900 * f, 1500 * f, d) * np.sin(np.pi * u) ** 3 * 0.12
    return soft(room(mix(wind, flap, whistle), 0.5), 4600)


# ---------------------------------------------------------------- everyday life (boki_*, new names)
def eat(i):
    """Munching: three or four soft crunch-and-smack bites with a happy hum."""
    out = np.zeros(0)
    for k in range(3 + (i % 2)):
        bite = mix(bpf(noise(0.06), 600, 3200) * env(N(0.06), 0.003, 0.018) * (0.8 + 0.2 * S.rng.random()),
                   bubble(260 + 40 * S.rng.random(), 0.05, 1.5) * 0.5)
        out = mix(out, at(bite, 0.14 * k))
    hum = at(vowel(330, 380, 0.4, 'mm', 1.3) * 0.25, 0.1)
    return soft(room(mix(out, hum), 0.3), 3800)


def sleep(i):
    """A tiny sleeper's breath: a slow soft in-and-out with a tiny snore at the end."""
    d = 1.5; n = N(d); u = np.arange(n) / n
    breath = bpf(noise(d), 300, 1500) * (np.sin(np.pi * np.clip(u * 2, 0, 1)) ** 2 * (u < 0.5) +
                                          0.7 * np.sin(np.pi * np.clip(u * 2 - 1, 0, 1)) ** 2 * (u >= 0.5))
    snore = at(vowel(210, 190, 0.3, 'mm', 1.3, 0.1) * 0.4, 1.0)
    return soft(room(mix(breath * 0.8, snore), 0.3), 2200)


def work(i):
    """Busy little Boki: a quick determined 'hup-hup' with a scuff."""
    f = j(i, 0.05)
    h = lambda fr, dl: at(mix(squeak(fr * f, 0.07, 0.15, 0.0, a=0.003), 0.4 * vowel(fr * f * 0.5, fr * f * 0.5, 0.07, 'oh', 1.4)), dl)
    scuff = at(bpf(noise(0.12), 500, 3000) * env(N(0.12), 0.01, 0.04) * 0.3, 0.0)
    return soft(room(mix(h(620, 0.0), h(700, 0.13), scuff), 0.3), 4000)


def fuse(i):
    """Fusion: the Boki leaps in. A rising sparkle spiral, a warm swell and a bright pop with a bell."""
    d = 0.9; n = N(d); u = np.arange(n) / n
    spiral = S.sweep(300, 1800, d, curve=1.6) * np.sin(np.pi * u ** 0.6) * 0.5
    swell_t = S.sweep(180, 360, d) * np.sin(np.pi * u ** 1.2) * 0.45
    grain = S.grains(d, 90, 3000, 8500, 0.002, 0.005, fall=0.4) * 0.3 * u
    bell = at(mix(S.chime(1047, 1.2, 0.5, ((1.0, 1.0), (2.76, 0.3))), S.chime(1568, 1.2, 0.5, ((1.0, 0.7),))) * 0.4, 0.78)
    pop = at(mix(bubble(400, 0.1, 2.5), S.kick(150, 60, 0.3, 0.02, 0.1, 2.0) * 0.5), 0.76)
    return soft(room(mix(spiral, swell_t, grain, bell, pop), 0.9), 5400)


def unfuse(i):
    d = 0.5; n = N(d); u = np.arange(n) / n
    fall = S.sweep(1400, 380, d) * np.sin(np.pi * u ** 0.4) * (1 - u) * 0.6
    return soft(room(mix(fall, at(bubble(360, 0.1, 2.0), 0.02), at(squeak(880, 0.12, 0.1) * 0.4, 0.3)), 0.5), 4200)


def main():
    S.takes_cat('kin_happy', happy, 3, 'boki')
    S.takes_cat('kin_unsure', unsure, 3, 'boki')
    S.takes_cat('kin_alert', alert, 3, 'boki')
    S.takes_cat('kinhit', hit, 3, 'boki')
    S.takes_cat('recall', recall, 2, 'boki')
    S.takes_cat('throw', throw, 2, 'boki')
    S.takes_cat('catch', catch, 0, 'boki')
    S.takes_cat('bond', bond, 0, 'boki')
    S.takes_cat('skill', skill, 2, 'boki')
    S.takes_cat('k_poison', poison, 3, 'boki')
    S.takes_cat('k_spore', spore, 3, 'boki')
    S.takes_cat('k_psychic', psychic, 3, 'boki')
    S.takes_cat('k_crystal', crystal, 3, 'boki')
    S.takes_cat('k_fairy', fairy, 3, 'boki')
    S.takes_cat('k_sound', sound, 3, 'boki')
    S.takes_cat('boki_downed', downed, 2, 'boki')
    S.takes_cat('boki_revive', revive, 0, 'boki')
    S.takes_cat('boki_eat', eat, 2, 'boki')
    S.takes_cat('boki_sleep', sleep, 1, 'boki')
    S.takes_cat('boki_work', work, 3, 'boki')
    S.takes_cat('boki_fuse', fuse, 0, 'boki')
    S.takes_cat('boki_unfuse', unfuse, 0, 'boki')
    S.takes_cat('k_normal', normal, 3, 'boki')
    S.takes_cat('k_water', water, 3, 'boki')
    S.takes_cat('k_dragon', dragon, 3, 'boki')
    S.takes_cat('k_fire', fire, 3, 'boki')
    S.takes_cat('k_ice', ice, 3, 'boki')
    S.takes_cat('k_electric', electric, 3, 'boki')
    S.takes_cat('k_rock', rock, 3, 'boki')
    S.takes_cat('k_grass', grass, 3, 'boki')
    S.takes_cat('k_dark', dark, 3, 'boki')
    S.takes_cat('k_steel', steel, 3, 'boki')
    S.takes_cat('k_bug', bug, 3, 'boki')
    S.takes_cat('k_flying', flying, 3, 'boki')


if __name__ == '__main__':
    main()
