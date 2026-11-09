"""Boki sounds (docs/AUDIO.md): small, cute and alive, with an element flavour. Run from tools/.

Voices are two layers: a bright chirp (a sine with a pitch scoop, vibrato and a quiet 2nd/3rd harmonic,
the "squeak") and a soft wordless vowel (S.voice, formants scaled up for a small body). Several takes
of each so a Boki that talks a lot never repeats itself. Moves are by element:
  venom   bubbling gloop and a spit      spore   fluffy puffs and falling sparkle
  gravity a deep soft thud and a pull    prism   a glassy chime fan
  lunar   moonlit wind and a pale bell   echo    one ping bouncing away through a dark room
Every rigged species also has its own voice set, bk_<species>_<mood> (happy, alert, unsure, sleepy,
hurt; 2 takes each): base pitch from its weight, timbre from its type (SPECIES_VOICE below), and a
3-note signature motif that every mood bends (happy as is, alert clipped and high, unsure ending on
a question, sleepy a sigh, hurt a yelp). KinVoice.cue picks the set; kin_happy/alert/unsure stay the fallback.
Existing names are regenerated (kin_happy/unsure/alert, kinhit, recall, throw, catch, bond, skill,
k_<element>); new ones (boki_*) are lazy-loaded, so each needs its call site listed in the report.
"""
import json, os
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


# ---------------------------------------------------------------- elements (k_<element>)
def venom(i):
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


def gravity(i):
    """A deep soft thud that sucks in first: a reverse swell, a sub drop, a stone rumble."""
    f = j(i, 0.06)
    d = 0.7
    suck = lpf(noise(0.18), 500) * (np.arange(N(0.18)) / N(0.18)) ** 2 * 0.7
    hit_t = 0.16
    drop = at(S.sweep(120 * f, 42, 0.55) * env(N(0.55), 0.006, 0.17) * 1.3, hit_t)
    rumble = at(bpf(noise(0.5), 60, 380) * env(N(0.5), 0.02, 0.14) * 0.9, hit_t)
    tick = at(S.crack(0.06, 300, 1800, 0.012) * 0.3, hit_t)
    return lpf(room(mix(suck, drop, rumble, tick), 0.3), 1400 if i == 0 else 1400 + 100 * i)


def prism(i):
    """A glassy chime fan climbing a pentatonic scale, with a shimmer."""
    f = j(i, 0.02)
    notes = [(784, 0.0), (988, 0.05), (1175, 0.1), (1568, 0.15)]
    bells = [at(S.chime(fr * f, 0.9, 0.35, ((1.0, 1.0), (2.76, 0.4), (5.4, 0.2))) * (0.9 - 0.12 * k), dl)
             for k, (fr, dl) in enumerate(notes)]
    shimmer = at(S.grains(0.6, 70, 5000, 9500, 0.001, 0.003, fall=0.2) * 0.3, 0.1)
    air = bpf(noise(0.4), 1200, 4000) * env(N(0.4), 0.1, 0.1) * 0.12
    return soft(room(mix(*bells, shimmer, air), 0.8), 7500)


def lunar(i):
    """Moonlit wind: a breathy swirl that rises and a pale, slow bell inside it."""
    f = j(i, 0.04)
    d = 0.75; n = N(d); u = np.arange(n) / n
    wind = bpf(noise(d), 500, 2400) * np.sin(np.pi * u) ** 2 * (0.6 + 0.4 * np.sin(2 * np.pi * 2.2 * u))
    pad_t = S.sweep(440 * f, 587 * f, d) * np.sin(np.pi * u) ** 2 * 0.25
    bell = at(S.chime(880 * f, 0.9, 0.5, ((1.0, 0.8), (2.0, 0.25), (3.0, 0.1))) * 0.35, 0.22)
    return soft(room(mix(wind * 0.9, pad_t, bell), 0.7), 3400)


def echo(i):
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


# ---------------------------------------------------------------- per-species voices
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..')
MOODS = ['happy', 'alert', 'unsure', 'sleepy', 'hurt']
# Species theme -> the texture laid under its voice. crackle: Fire and sparks, burble: Water and venom,
# rustle: Grass, spores and swarms, chime: Crystal, moon and sound; anything else stays a plain voice.
TIMBRE = {'ember': 'crackle', 'storm': 'crackle', 'venom': 'burble', 'tempest': 'burble',
          'spore': 'rustle', 'bloom': 'rustle', 'swarm': 'rustle',
          'prism': 'chime', 'lunar': 'chime', 'echo': 'chime', 'frost': 'chime', 'stone': 'chime'}
# Per species: (vowel, signature motif as 3 pitch ratios). The motif is what makes a Pebbit and a
# Cairnback tell apart even at the same size.
SPECIES_VOICE = {
    'burrlet': ('eh', (1, 1.26, 1.12)), 'cairnback': ('oh', (1, 0.84, 0.84)), 'cindle': ('eh', (1, 1.5, 1.19)),
    'glintmole': ('ee', (1, 1.12, 1.5)), 'gloamshell': ('uh', (1, 0.9, 1.07)), 'glomwort': ('uh', (1, 1.19, 1.41)),
    'hivara': ('eh', (1, 1, 1.26)), 'kestrike': ('ee', (1, 1.78, 1.34)), 'kindlewren': ('ee', (1, 1.33, 1.67)),
    'lodestick': ('ah', (1, 0.94, 1.12)), 'marchleaf': ('eh', (1, 1.12, 1.26)), 'mossgrade': ('mm', (1, 0.89, 1)),
    'nettlynx': ('ah', (1, 1.41, 1.12)), 'pebbit': ('oh', (1, 1, 0.89)), 'puddlet': ('uh', (1, 1.26, 1.5)),
    'rimeshrew': ('ee', (1, 1.68, 1.5)), 'selenfin': ('oh', (1, 1.12, 1.33)), 'thrumbird': ('eh', (1, 1.19, 1.19)),
    'wisplet': ('ee', (1, 1.5, 1.78)), 'zapple': ('ah', (1, 1.33, 1)), 'zephyrak': ('ee', (1, 1.5, 2.0)),
}


def species_data(sp):
    """(weight kg, theme, curiosity, temper) of a species from its content files."""
    home = json.load(open(os.path.join(ROOT, 'content', 'kin', sp + '.json')))
    v2 = json.load(open(os.path.join(ROOT, 'content', 'kin_v2', sp + '.json')))
    pers = v2['personality']
    return home['size']['kg'], v2['theme'], pers['curiosity'], pers['temper']


def texture(kind, d, f, amt):
    """The type's colour under a voice of d seconds around pitch f."""
    n = N(d)
    if kind == 'crackle':
        return amt * 0.5 * S.grains(d, 150, 2500, 9000, 0.001, 0.004, fall=d * 0.7)
    if kind == 'burble':
        out = np.zeros(n)
        for _ in range(int(14 * d) + 1):
            out = mix(out, at(bubble(f * S.rng.uniform(0.4, 0.8), 0.05, 1.8) * 0.5, S.rng.uniform(0, d * 0.8)))
        return amt * out
    if kind == 'rustle':
        gate = np.abs(lpf(S.rng.standard_normal(n), 40)) * 14
        return amt * 0.4 * bpf(noise(d), 3500, 9000) * np.clip(gate, 0, 1) * env(n, 0.01, d * 0.8)
    if kind == 'chime':
        return amt * 0.35 * S.chime(f * 2, d, 0.25, ((1.0, 1.0), (2.76, 0.3)))
    return amt * 0.4 * S.sweep(f * 0.5, f * 0.5, d) * env(n, 0.01, d * 0.6)


def note(f, f_end, d, vow, tail_d=None):
    """One syllable: a squeak with a soft vowel under it, gliding f -> f_end."""
    sq = squeak(f, d, 0.1, 0.02, tail_d=tail_d)
    return mix(sq, 0.45 * vowel(f * 0.5, f_end * 0.5, d, vow, 1.4))


def species_voice(sp, mood, i):
    kg, theme, curious, temper = species_data(sp)
    vow, motif = SPECIES_VOICE[sp]
    kind = TIMBRE.get(theme, 'plain')
    base = float(np.clip(1000.0 * (2.5 / kg) ** 0.2, 520, 1450)) * j(i, 0.04)
    dd = 0.11 / (0.8 + 0.5 * curious)                 # curious ones chatter faster
    f = [base * m for m in motif]
    if mood == 'happy':
        out, t0 = np.zeros(0), 0.0
        for fr, d in zip(f, (dd, dd, dd * 1.5)):
            out = mix(out, at(note(fr, fr * 1.04, d, vow), t0))
            t0 += d * 0.85
        d_all = t0 + 0.1
    elif mood == 'alert':
        hi = 1.0 + 0.3 * temper                       # the temperamental ones go higher
        parts = [at(note(f[k % 2] * hi, f[k % 2] * hi * 1.05, 0.07, vow, 0.04), 0.085 * k) for k in range(3)]
        out, d_all = mix(*parts), 0.4
    elif mood == 'unsure':
        a = note(f[2] * 0.8, f[1] * 0.75, dd * 1.2, vow)
        b = note(f[0] * 0.7, f[0] * 1.15, dd * 2.2, vow)          # ends on a question
        out, d_all = mix(a, at(b, dd * 1.1)), dd * 3.6
    elif mood == 'sleepy':
        d_all = 0.7
        sigh = note(f[0] * 0.75, f[0] * 0.45, d_all * 0.85, 'mm', tail_d=0.4)
        out = lpf(mix(sigh, 0.3 * hpf(noise(d_all), 1500) * env(N(d_all), 0.2, 0.3)), 2200)
    else:   # hurt
        d_all = 0.26
        yelp = mix(squeak(f[0] * 1.3, 0.2, -0.25, 0.0, a=0.003, tail_d=0.1),
                   0.6 * S.voice(0.2, f[0] * 0.65, f[0] * 0.4, vow, rasp=0.5, scale=1.35, a=0.004))
        out = mix(yelp, at(S.kick(180, 80, 0.1, 0.01, 0.03, 1.2) * 0.4, 0.0))
    amt = 0.45 if mood in ('sleepy', 'hurt') else 1.0
    out = mix(out, texture(kind, d_all, base, amt))
    return soft(room(out, 0.3), 5200 if mood != 'sleepy' else 3000)


def species_names():
    return sorted(SPECIES_VOICE)


def voice_sets():
    """Writes bk_<species>_<mood> (2 takes) for every rigged species."""
    S.reseed(7001)
    for sp in species_names():
        for mood in MOODS:
            S.takes_cat('bk_%s_%s' % (sp, mood), lambda i, sp=sp, mood=mood: species_voice(sp, mood, i), 1, 'boki')


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
    S.takes_cat('k_venom', venom, 3, 'boki')
    S.takes_cat('k_spore', spore, 3, 'boki')
    S.takes_cat('k_gravity', gravity, 3, 'boki')
    S.takes_cat('k_prism', prism, 3, 'boki')
    S.takes_cat('k_lunar', lunar, 3, 'boki')
    S.takes_cat('k_echo', echo, 3, 'boki')
    S.takes_cat('boki_downed', downed, 2, 'boki')
    S.takes_cat('boki_revive', revive, 0, 'boki')
    S.takes_cat('boki_eat', eat, 2, 'boki')
    S.takes_cat('boki_sleep', sleep, 1, 'boki')
    S.takes_cat('boki_work', work, 3, 'boki')
    S.takes_cat('boki_fuse', fuse, 0, 'boki')
    S.takes_cat('boki_unfuse', unfuse, 0, 'boki')
    voice_sets()


if __name__ == '__main__':
    main()
