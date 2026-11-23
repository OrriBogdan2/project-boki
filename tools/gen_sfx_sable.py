"""Sable, the Silver Thief (thief): her sound set (docs/AUDIO.md, content/sfx/thief.json).

    python3 tools/gen_sfx_sable.py      (then: godot --headless --import)

Her voice is quick, light and silver: flintlock cracks (a flint snap, the pan's flash, then the shot and its
smoke), whirled chain bolas, a thrown dagger, a shadow blink, a storm of blades for her Encore. A light woman's
wordless voice; soft leather boots with a faint jingle of stolen silver.
Original synthesis, no samples.
"""
import os, sys
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import sfx_lib as S
from sfx_lib import (N, T, noise, lpf, hpf, bpf, env, mix, at, kick, click, crack, sub, tail, reflections, ring,
                     grains, pad)

S.reseed(4401)


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
    """A small silver bell: S.chime without the partials that would fold over the top of the band."""
    parts = tuple(pg for pg in ((1.0, 1.0), (2.76, 0.45), (5.4, 0.22), (8.93, 0.1)) if f * pg[0] < 9000)
    x = S.chime(f, d, decay, parts); k = N(0.04)
    x[-k:] *= np.linspace(1.0, 0.0, k)               # ring out instead of stopping at d
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


def am_whirl(d, r0, r1, lo, hi, sharp=3.0):
    """A thing whirled round: band noise pulsing once a turn, the turn rate gliding r0 -> r1 (Hz)."""
    n = N(d); t = np.arange(n) / S.SR
    rate = r0 + (r1 - r0) * t / d
    ph = 2 * np.pi * np.cumsum(rate) / S.SR
    pulse = (0.5 + 0.5 * np.sin(ph)) ** sharp
    return bpf(noise(d), lo, hi) * pulse, ph


# ------------------------------------------------------------------ LMB: the flintlock (Arc Bolts)
def flint(i):
    """The lock: the flint scraping the frizzen (a click and a shower of sparks), then the pan's 'pff'."""
    return mix(click(0.003, 2500, 7000) * 1.1, at(grains(0.025, 700, 2500, 6500, fall=0.007) * 0.5, 0.002),
               at(bpf(noise(0.03), 700, 3500) * env(N(0.03), 0.002, 0.009) * 0.7, 0.008 + 0.002 * i))


def shot(i, big=1.0):
    """The charge going off: a cracking report, a punchy body and the smoke hanging in the air."""
    d = 0.5
    rep = mix(crack(d, 900, 6000, 0.010) * 2.6, crack(d, 180, 900, 0.03) * 2.0,
              kick(330 + 18 * i, 105, d, 0.008, 0.035 * big, 2.6) * 0.55 * big)
    return mix(rep, reflections(tail(0.4 * big, 1500, 0.075 * big) * 0.9))


def bolt(i):
    lock = 0.020 + 0.004 * (i % 3)          # the lock time: the flint, then the shot a beat later
    zing = S.sweep(2300 + 60 * i, 1500, 0.09) * env(N(0.09), 0.003, 0.03) * 0.10   # the bolt spinning off
    return mix(flint(i) * 0.7, at(shot(i), lock), at(zing, lock + 0.01))


def flintlock_crack(i):
    """The empowered shot, both pistols at once: two cracks a hair apart, a sub, and the blue chakram's ring."""
    ring_up = S.sweep(1400, 2600, 0.35) * env(N(0.35), 0.01, 0.12) * 0.13
    shimmer = mix(bell(1975, 0.5, 0.22) * 0.12, ring_up)
    return mix(flint(0) * 0.8, at(flint(1) * 0.6, 0.012),
               at(shot(0, 1.4), 0.024), at(shot(2, 1.2) * 0.75, 0.047),
               at(sub(72, 40, 0.6, 0.11) * 0.45, 0.024), at(shimmer, 0.03))


def cock(i):
    """The empowered bolt forming in her hand: a flintlock hammer drawn back to full cock (click, clack)."""
    first = mix(click(0.003, 1800, 5500) * 0.8, ring((2650, 3900), 0.06, (0.012, 0.008), (0.25, 0.12)))
    second = mix(click(0.004, 1500, 5000) * 1.1, kick(950, 480, 0.08, 0.004, 0.012, 1.6) * 0.35,
                 ring((2300, 3450, 5100), 0.18, (0.035, 0.02, 0.012), (0.3, 0.15, 0.06)))
    return mix(first, at(second, 0.07))


def fizzle(i):
    """A bolt running out at the cursor: the spark dying in a little violet puff."""
    d = 0.32
    return mix(S.hiss(d, 1000, 3800, 0.004, 0.06) * 0.5, grains(0.25, 140, 1200, 4000, fall=0.07) * 0.7,
               lpf(noise(d), 700) * env(N(d), 0.006, 0.05) * 1.2,
               S.sweep(900, 380, 0.2) * env(N(0.2), 0.004, 0.06) * 0.15)


# ------------------------------------------------------------------ dash: the cartwheel
def dash(i):
    tap = mix(kick(620, 240, 0.08, 0.004, 0.012, 1.5) * 0.3, crack(0.08, 300, 2200, 0.008) * 0.8)
    land = mix(kick(200, 75, 0.2, 0.012, 0.03, 1.8) * 0.45, crack(0.2, 300, 2500, 0.02) * 0.7,
               grains(0.12, 220, 1200, 4500, fall=0.03) * 0.4)
    flutter, _ = am_whirl(0.36, 22, 16, 300, 1600, 2.0)
    return mix(swish(0.22, 320, 2300) * 0.9, at(swish(0.2, 420, 2700) * 0.8, 0.13), at(tap, 0.1),
               flutter * env(N(0.36), 0.03, 0.12) * 0.35, at(land, 0.3))


# ------------------------------------------------------------------ RMB: the Bola
def chain_clinks(d, times, lo=2300, hi=4800, g=0.35):
    out = np.zeros(N(d))
    for tt in times:
        c = ring((S.rng.uniform(lo, hi), S.rng.uniform(lo, hi) * 1.47), 0.05, (0.01, 0.006), (g, g * 0.5))
        s0 = N(tt); out[s0:s0 + len(c)] += c[:len(out) - s0]
    return out


def bola_whirl(i):
    d = 0.5
    whirl, ph = am_whirl(d, 7.0, 11.0, 350, 2600, 2.0)
    peaks = np.where(np.diff(np.floor(ph / (2 * np.pi))) > 0)[0] / S.SR
    hum = mix(S.sweep(110, 150, d) * (0.6 + 0.4 * np.sin(ph)) * 0.12, lpf(noise(d), 500) * 0.25)
    return (mix(whirl * 1.1, hum, chain_clinks(d, peaks, g=0.25)) * env(N(d), 0.05, 1.0))


def bola_throw(i):
    snap = mix(crack(0.12, 900, 4500, 0.008) * 1.6, kick(520, 210, 0.12, 0.005, 0.015, 2.0) * 0.35)
    away, _ = am_whirl(0.35, 15, 12, 500, 3000, 2.5)
    return mix(swish(0.24, 380, 3200) * 1.0, at(snap, 0.09),
               at(S.rattle(0.2, 70, 2000, 5200, decay=0.06) * 0.3, 0.1),
               at(away * env(N(0.35), 0.01, 0.1) * 0.6, 0.11))


def bola_wrap(i):
    whips = mix(*[at(swish(0.07, 600 + 300 * k, 2600 + 400 * k, 4.0) * (0.7 + 0.1 * k), 0.045 * k)
                  for k in range(3)])
    thud = mix(kick(180, 68, 0.3, 0.012, 0.04, 2.4) * 0.6, crack(0.3, 250, 1800, 0.025) * 1.5)
    return mix(whips, at(thud, 0.13), at(S.rattle(0.22, 90, 2000, 5000, decay=0.06) * 0.35, 0.13),
               at(chain_clinks(0.3, (0.0, 0.03, 0.07), g=0.3), 0.15))


def bola_stun(i):
    """Two foes tangled together: the chain snapping taut, two bodies slammed, a dizzy ring."""
    taut = mix(crack(0.2, 800, 4200, 0.012) * 1.8,
               ring((1810, 2740, 3920), 0.4, (0.09, 0.06, 0.03), (0.35, 0.2, 0.08)))
    thuds = mix(kick(160, 55, 0.4, 0.014, 0.05, 2.6) * 0.6, at(kick(145, 52, 0.4, 0.014, 0.05, 2.6) * 0.5, 0.055),
                crack(0.3, 250, 1600, 0.03) * 1.6, sub(65, 40, 0.5, 0.09) * 0.35)
    daze = mix(*[at(bell(f, 0.45, 0.16) * 0.10, 0.12 + 0.09 * k) for k, f in enumerate((1568, 2093, 1760))])
    return mix(taut, at(thuds, 0.02), at(S.rattle(0.25, 80, 2200, 5000, decay=0.07) * 0.3, 0.02), daze)


# ------------------------------------------------------------------ E: the Shadow Knife
def knife_throw(i):
    shing = mix(S.sweep(3100, 3600, 0.12) * env(N(0.12), 0.004, 0.035) * 0.22,
                ring((3350, 4720), 0.12, (0.04, 0.025), (0.12, 0.06)))
    return lpf(mix(at(swish(0.17, 800, 3600, 5.0) * 1.0, 0.01), shing, crack(0.05, 400, 2500, 0.006) * 0.5), 6500)


def knife_stick(i):
    """The dagger biting into a foe or the ground: a thunk and the blade quivering."""
    d = 0.4; t = T(d)
    quiver = np.sin(2 * np.pi * 255 * t) * (0.6 + 0.4 * np.sin(2 * np.pi * 28 * t)) * env(N(d), 0.002, 0.11) * 0.25
    return mix(click(0.003, 2000, 6000) * 0.9, kick(420, 170, d, 0.006, 0.025, 2.4) * 0.6,
               crack(d, 250, 1600, 0.02) * 1.6, quiver,
               ring((2880, 4150), d, (0.08, 0.05), (0.12, 0.05)))


def blink(i):
    """The shadow blink: a sucked-in breath of air, a soft pop where she lands, a trail of afterimage pings."""
    d = 0.16; n = N(d)
    inhale = bpf(noise(d), 500, 4500) * (np.arange(n) / n) ** 3 * 1.2
    pop = mix(kick(320, 120, 0.2, 0.006, 0.025, 1.8) * 0.45, lpf(noise(0.25), 1600) * env(N(0.25), 0.003, 0.05))
    ghosts = mix(*[at(bell(2600 - 170 * k, 0.3, 0.09) * (0.14 - 0.022 * k), 0.17 + 0.035 * k) for k in range(5)])
    return mix(inhale, at(pop, d), ghosts)


def heal(i):
    """A knock taken: a little silver flourish rising over a soft breath."""
    notes = (1318, 1568, 1976, 2637)
    arp = mix(*[at(bell(f, 0.6, 0.25) * 0.2, 0.055 * k) for k, f in enumerate(notes)])
    rise = bpf(noise(0.5), 600, 3000) * env(N(0.5), 0.15, 0.12) * 0.25
    pad_ = S.sweep(330, 392, 0.7) * env(N(0.7), 0.05, 0.25) * 0.12
    return mix(arp, rise, pad_)


# ------------------------------------------------------------------ X: Encore
def shing(f, g=1.0):
    d = 0.35
    blade = S.sweep(f, f * 1.25, d) * env(N(d), 0.004, 0.09)
    return mix(blade * 0.18 * g, bpf(noise(d), 2000, 6000) * env(N(d), 0.004, 0.03) * 0.5 * g,
               ring((f * 1.5, f * 2.3), d, (0.07, 0.04), (0.08 * g, 0.04 * g)))


def encore(i):
    swell_d = 0.7; n = N(swell_d)
    swirl = swish(swell_d, 300, 1900, 2.0) * np.linspace(0.3, 1.0, n) * 1.1
    drum = mix(kick(150, 50, 0.6, 0.02, 0.08, 2.8) * 0.7, crack(0.5, 200, 2000, 0.04) * 1.6, sub(60, 38, 0.6, 0.12) * 0.4)
    chord = mix(*[bell(f, 0.6, 0.3) * 0.12 for f in (1175, 1480, 1760)])
    blades = mix(*[at(shing(2500 + 230 * k, 1.0 - 0.12 * k), 0.06 * k) for k in range(4)])
    return mix(blades, at(swirl, 0.08), at(drum, 0.45), at(chord, 0.46))


def encore_whirr(i):
    d = 2.0; n = N(d)
    a, _ = am_whirl(d, 13, 15, 900, 4200, 3.0)
    b, _ = am_whirl(d, 17.3, 19, 500, 2600, 3.0)
    glint = mix(*[at(bell(S.rng.uniform(2400, 3600), 0.2, 0.05) * 0.06, S.rng.uniform(0, 1.7)) for _ in range(14)])
    e = np.minimum(1.0, np.arange(n) / N(0.12)) * np.minimum(1.0, (n - np.arange(n)) / N(0.35))
    return mix(a * 0.8 + b * 0.7, pad(glint, d)[:n]) * e


def blade(i):
    zing = S.sweep(2700 + 90 * i, 3300 + 90 * i, 0.13) * env(N(0.13), 0.02, 0.04) * 0.3
    return lpf(mix(swish(0.13, 1100 + 80 * i, 3600, 6.0) * 0.8, zing,
                   at(ring((3000 + 90 * i, 4300), 0.1, (0.025, 0.015), (0.1, 0.05)), 0.03)), 7000)


def encore_hit(i):
    d = 0.22
    return mix(click(0.003, 2500, 7000) * 1.2, kick(270 + 15 * i, 110, d, 0.006, 0.022, 2.4) * 0.5,
               crack(d, 300, 2500, 0.022) * 2.0, ring((2400 + 70 * i, 3550), d, (0.05, 0.03), (0.12, 0.05)))


# ------------------------------------------------------------------ voice (a light woman's voice, wordless)
VOWEL = ('ah', 'eh', 'uh', 'ah')


def vo(*a, **k):
    """S.voice with its last 25 ms faded, so a cut-short cry never ends on a click."""
    x = S.voice(*a, **k); f = min(len(x), N(0.025))
    x[-f:] *= np.linspace(1.0, 0.0, f)
    return x


def hurt(i):
    d = (0.2, 0.26, 0.17, 0.23)[i]
    catch = vo(0.08, 300 + 15 * i, 360 + 25 * i, VOWEL[i], breath=0.3, rasp=0.3, scale=1.13, a=0.004, decay=0.03)
    v = vo(d, 370 + 22 * i, 250 - 10 * i, VOWEL[i], breath=0.18, rasp=0.12, scale=1.13, a=0.01, decay=d * 0.4)
    v = mix(catch * 0.6, at(v, 0.03))
    exhale = hpf(noise(0.25), 1400) * env(N(0.25), 0.02, 0.06) * 0.05
    return mix(v, at(lpf(exhale, 5000), 0.12))


def down(i):
    gasp = hpf(noise(0.12), 1200) * env(N(0.12), 0.06, 0.03) * 0.08
    cry = vo(0.75, 370, 215, 'ah', breath=0.4, rasp=0.2, vib=0.02, scale=1.12, a=0.02, decay=0.28)
    fall = mix(kick(150, 60, 0.3, 0.015, 0.04, 2.0) * 0.4, crack(0.3, 200, 1500, 0.03) * 0.8)
    return mix(gasp, at(cry, 0.08), at(fall, 0.62))


def death(i):
    cry = vo(1.05, 345, 165, 'oh', breath=0.5, rasp=0.25, vib=0.015, scale=1.12, a=0.02, decay=0.42)
    exhale = lpf(hpf(noise(0.6), 900), 4500) * env(N(0.6), 0.08, 0.2) * 0.06
    clatter = mix(ring((2210, 3330, 4870), 0.4, (0.08, 0.05, 0.03), (0.2, 0.1, 0.05)),
                  at(ring((1980, 2960), 0.35, (0.07, 0.04), (0.16, 0.08)), 0.09),
                  kick(300, 160, 0.15, 0.005, 0.015, 1.5) * 0.25)
    return mix(cry, at(exhale, 0.9), at(clatter, 0.78))


# ------------------------------------------------------------------ footsteps (light leather boots)
def step(surface, i):
    w = 0.7                                        # light on her feet
    def hit(g):
        th = kick(150 + 12 * i, 70, 0.2, 0.008, 0.016 * w, 1.4) * 0.35 * g
        if surface == 'grass':
            tex = lpf(mix(grains(0.12, 260, 1300, 4500, fall=0.025) * 0.55, bpf(noise(0.1), 900, 4000) *
                      env(N(0.1), 0.004, 0.02) * 0.3), 6000)
        elif surface == 'stone':
            tex = mix(click(0.003, 1800, 5500) * 0.6, crack(0.12, 700, 3800, 0.01) * 0.9,
                      at(bpf(noise(0.06), 1500, 4500) * env(N(0.06), 0.01, 0.015) * 0.2, 0.02))
        elif surface == 'wood':
            tex = mix(ring((175 + 8 * i, 420, 960), 0.25, (0.05, 0.03, 0.018), (0.45, 0.25, 0.1)),
                      crack(0.1, 400, 2500, 0.008) * 0.8)
        else:
            tex = mix(lpf(grains(0.16, 900, 500, 3200, fall=0.04), 3500) * 0.9,
                      lpf(noise(0.12), 900) * env(N(0.12), 0.006, 0.03) * 0.5)
        return mix(th, tex) * g
    jingle = bell(3100 + 140 * i, 0.15, 0.04) * 0.03          # a little stolen silver on her belt
    return mix(hit(1.0), at(hit(0.45), 0.035 + 0.006 * i), at(jingle, 0.02))


def build():
    takes('dj_bolt', bolt, 3, 'fire')
    save('thief_flintlock_crack', flintlock_crack(0), 'signature')
    save('thief_cock', cock(0), 'cast')
    save('dj_fizzle', fizzle(0), 'impact')
    takes('thief_dash', dash, 2, 'dash')
    save('dj_bola_whirl', bola_whirl(0), 'cast')
    save('dj_bola_throw', bola_throw(0), 'cast')
    save('dj_bola_wrap', bola_wrap(0), 'impact')
    save('thief_bola_stun', bola_stun(0), 'impact')
    save('dj_knife_throw', knife_throw(0), 'cast')
    save('thief_knife_stick', knife_stick(0), 'impact')
    save('dj_blink', blink(0), 'cast')
    save('dj_heal', heal(0), 'cast')
    save('dj_encore', encore(0), 'cast')
    save('dj_encore_whirr', encore_whirr(0), 'loop')
    takes('dj_blade', blade, 3, 'fire')
    takes('dj_encore_hit', encore_hit, 3, 'impact')
    takes('thief_hurt', hurt, 3, 'grunt')
    save('thief_down', down(0), 'grunt')
    save('thief_death', death(0), 'grunt')
    for s in ('grass', 'stone', 'wood', 'snow'):
        takes('thief_step_' + s, lambda i, s=s: step(s, i), 3, 'step')


if __name__ == '__main__':
    build()
