"""Boki sounds (docs/AUDIO.md): small, cute and alive, with an element flavour. Run from tools/.

Voices are two layers: a bright chirp (a sine with a pitch scoop, vibrato and a quiet 2nd/3rd harmonic,
the "squeak") and a soft wordless vowel (S.voice, formants scaled up for a small body). Several takes
of each so a Boki that talks a lot never repeats itself. The cast cue is one short sound per standard
type (k_<type>: the 18 types of DECISIONS 2026-11-08 22:29; KinLib.cue_type maps a species' theme to it):
  normal  a plain double pop             fire    a crackle and a warm whoomp
  water   droplets and a splash          grass   leaf rustle and a wooden pluck
  spore   fluffy puffs, falling sparkle  electric an FM zap with a buzz
  ice     frozen ticks and a thin chime  rock    a deep soft thud and a stone rumble
  psychic a wobbling pulse that warps    flying  two rising gusts
  dragon  a low growl and ember hiss     dark    a reversed swell on a tritone
  poison  bubbling gloop and a spit      bug     chitter and wing buzz
  steel   a short metal clang            fairy   moonlit wind and a pale bell
  crystal a glassy chime fan             sound   one ping bouncing away through a dark room
Existing names are regenerated (kin_happy/unsure/alert, kinhit, recall, throw, catch, bond, skill,
k_<type>); new ones (boki_*) are lazy-loaded, so each needs its call site listed in the report.
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


def rock(i):
    """A deep soft thud that sucks in first: a reverse swell, a sub drop, a stone rumble (mob slams use it)."""
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
    """A plain, friendly double pop with a small round thump."""
    f = j(i, 0.05)
    pops = [at(mix(bubble(fr * f, 0.06, 1.5), squeak(fr * f * 1.5, 0.08, 0.1) * 0.35), dl) for fr, dl in ((420, 0.0), (520, 0.09))]
    return soft(room(mix(*pops, S.kick(160, 80, 0.12, 0.02, 0.05, 1.5) * 0.4), 0.3), 4500)


def fire(i):
    """A warm whoomp with a crackle on top and a few flying sparks."""
    f = j(i, 0.07)
    whoomp = lpf(noise(0.4), 900 * f) * env(N(0.4), 0.05, 0.12) * 0.9
    low = S.sweep(140 * f, 70, 0.4) * env(N(0.4), 0.01, 0.13) * 0.6
    crackle = S.grains(0.5, 90, 1800, 6500, 0.001, 0.004, fall=0.2) * 0.45
    sparks = at(S.grains(0.3, 40, 4500, 9000, 0.001, 0.003, fall=0.1) * 0.25, 0.1)
    return soft(room(mix(whoomp, low, crackle, sparks), 0.4), 5000)


def water(i):
    """Three rising droplets, then a little splash of bright noise."""
    f = j(i, 0.06)
    drops = [at(bubble(500 * f * (1 + 0.3 * k), 0.08, 1.8) * 0.8, 0.07 * k) for k in range(3)]
    splash = at(bpf(noise(0.25), 900, 3800) * env(N(0.25), 0.01, 0.07) * 0.5, 0.2)
    return soft(room(mix(*drops, splash), 0.6), 5200)


def grass(i):
    """A fluttering leaf rustle and a soft wooden pluck."""
    f = j(i, 0.05)
    d = 0.4; u = np.arange(N(d)) / N(d)
    leaves = bpf(noise(d), 2200, 6500) * env(N(d), 0.03, 0.12) * (0.6 + 0.4 * np.sin(2 * np.pi * 14 * u)) * 0.55
    pluck = at(S.chime(330 * f, 0.3, 0.1, ((1.0, 1.0), (2.1, 0.4), (3.3, 0.15))) * 0.6, 0.08)
    return soft(room(mix(leaves, pluck, at(squeak(660 * f, 0.1, 0.12) * 0.25, 0.16)), 0.4), 5200)


def electric(i):
    """A quick FM zap that falls through a buzz, with a dry crack at the front."""
    f = j(i, 0.06)
    zap = S.fm(1400 * f, 1.41, 6, 0.22, 0.09) * 0.5
    zip_t = S.sweep(2600 * f, 500, 0.18) * env(N(0.18), 0.002, 0.06) * 0.4
    buzz = S.sat(S.sweep(110, 100, 0.3), 4) * env(N(0.3), 0.01, 0.1) * 0.3
    return soft(mix(zap, zip_t, buzz, S.crack(0.05, 2500, 9000, 0.008) * 0.4), 7200)


def ice(i):
    """Frozen ticks, a brittle snap and one thin cold chime."""
    f = j(i, 0.04)
    ticks = S.rattle(0.3, 55, 3500, 8500, 0.5, 0.08) * 0.35
    snap = S.crack(0.08, 3000, 9000, 0.015) * 0.5
    ping = at(S.chime(1760 * f, 0.5, 0.2, ((1.0, 1.0), (3.1, 0.25))) * 0.35, 0.05)
    return soft(room(mix(ticks, snap, ping, hpf(noise(0.3), 5000) * env(N(0.3), 0.05, 0.08) * 0.1), 0.5), 8000)


def psychic(i):
    """A wobbling pulse that bends up and back, two sines slightly apart so the air seems to warp."""
    f = j(i, 0.04)
    d = 0.6; n = N(d); u = np.arange(n) / n
    ph = 2 * np.pi * np.cumsum(330 * f * (1 + 0.5 * np.sin(np.pi * u))) / S.SR
    wob = np.sin(ph) + np.sin(ph * 1.012)
    pulse = wob * (0.65 + 0.35 * np.sin(2 * np.pi * 9 * u)) * np.sin(np.pi * u) ** 1.5 * 0.35
    ping = at(S.chime(990 * f, 0.4, 0.2, ((1.0, 0.8), (1.5, 0.3))) * 0.3, 0.3)
    return soft(room(mix(pulse, ping), 0.8), 3800)


def flying(i):
    """Two quick gusts that climb, with a fluttering feather squeak."""
    f = j(i, 0.05)

    def gust(lo, hi, d):
        return bpf(noise(d), lo, hi) * np.sin(np.pi * np.arange(N(d)) / N(d)) ** 2
    g = mix(gust(500 * f, 1800 * f, 0.3) * 0.7, at(gust(900 * f, 3200 * f, 0.28) * 0.6, 0.12))
    return soft(room(mix(g, at(squeak(1500 * f, 0.08, 0.2) * 0.2, 0.3)), 0.4), 5500)


def dragon(i):
    """A short low growl over a drop, with an ember hiss as it ends."""
    f = j(i, 0.06)
    growl = S.voice(0.45, 110 * f, 70 * f, 'ah', breath=0.2, rasp=0.9, vib=0.03, scale=0.85, a=0.03, decay=0.28) * 0.9
    drop = S.sweep(90 * f, 45, 0.4) * env(N(0.4), 0.01, 0.15) * 0.5
    ember = at(S.hiss(0.3, 2500, 7000, 0.06, 0.12) * 0.25, 0.25)
    return lpf(room(mix(growl, drop, ember), 0.4), 3200)


def dark(i):
    """A reversed swell that lands on a low tritone, a little breath of shade."""
    f = j(i, 0.04)
    d = 0.55; n = N(d); u = np.arange(n) / n
    swell = lpf(noise(d), 700) * u ** 2.2 * 0.8
    tri = (np.sin(2 * np.pi * 150 * f * T(d)) + np.sin(2 * np.pi * 212 * f * T(d))) * u ** 1.5 * (1 - u) ** 0.6 * 0.4
    thud = at(S.kick(110, 50, 0.25, 0.03, 0.08, 1.5) * 0.6, 0.4)
    return lpf(room(mix(swell, tri, thud), 0.6), 1800)


def bug(i):
    """A quick chitter of clicks over a buzzing wing."""
    f = j(i, 0.06)
    chit = S.rattle(0.28, 70, 3200 * f, 6500, 0.4, 0.1) * 0.45
    wing = S.sat(np.sin(2 * np.pi * 240 * f * T(0.32)), 2) * (0.5 + 0.5 * np.sign(np.sin(2 * np.pi * 85 * T(0.32)))) * env(N(0.32), 0.02, 0.1) * 0.3
    return soft(room(mix(chit, at(wing, 0.04)), 0.3), 6000)


def steel(i):
    """A short bright clang: struck bell-metal with a click."""
    f = j(i, 0.04)
    clang = S.chime(540 * f, 0.5, 0.25, ((1.0, 1.0), (2.76, 0.6), (5.4, 0.4), (8.93, 0.2)))
    return soft(room(mix(clang * 0.6, S.click(0.004, 3000, 9000) * 0.6, S.fm(900 * f, 1.4, 3, 0.2, 0.06) * 0.3), 0.3), 8000)


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


TYPES = [
    'normal', 'fire', 'water', 'grass', 'spore', 'electric', 'ice', 'rock', 'psychic',
    'flying', 'dragon', 'dark', 'poison', 'bug', 'steel', 'fairy', 'crystal', 'sound']


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
    for t in TYPES:
        S.takes_cat('k_' + t, globals()[t], 3, 'boki')
    S.takes_cat('boki_downed', downed, 2, 'boki')
    S.takes_cat('boki_revive', revive, 0, 'boki')
    S.takes_cat('boki_eat', eat, 2, 'boki')
    S.takes_cat('boki_sleep', sleep, 1, 'boki')
    S.takes_cat('boki_work', work, 3, 'boki')
    S.takes_cat('boki_fuse', fuse, 0, 'boki')
    S.takes_cat('boki_unfuse', unfuse, 0, 'boki')


if __name__ == '__main__':
    main()
