"""Pip's sounds (id tender, the Dawnfox): a small pastel fairy-fox field medic, brave but afraid of the
dark. Her lantern holds a star she caught as a kid; it is her relic and her courage. She heals with its light.

    cd tools && python3 gen_sfx_pip.py      (then: godot --headless --import)

Light, warm and cute, never fiery: soft air, small brass-and-glass lantern rings, warm sine chords and
starry sparkles kept under 6 kHz; seeds and roots are leafy and woody. Signature: the lantern chime
(tender_lantern_chime: the Hearthlight and Hearth Call), and she cheers when a Hearth Call mends someone
(tender_cheer). Her voice is small and wordless. The kit's older tend_* files are rebuilt under their own
names (content/sfx/tender.json "replaces"). Original synthesis, no samples.
"""
import os, sys
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import sfx_lib as S
from sfx_lib import N, T, noise, lpf, hpf, bpf, env, mix, at, kick, click, crack, grains, shape, soft_in

S.reseed(9203)

STAR = (784.0, 988.0, 1175.0, 1568.0)     # G5 B5 D6 G6: the lantern's star (a bright, happy G major)


# ------------------------------------------------------------------ building blocks
def slow(d, rate, depth):
    """A smooth random wobble around 1: `rate` new values a second."""
    pts = max(4, int(d * rate) + 3)
    v = S.rng.standard_normal(pts)
    x = np.interp(np.arange(N(d)) / S.SR * rate, np.arange(pts), v)
    return np.clip(1.0 + depth * lpf(x, 40) / (np.std(x) + 1e-9), 0.05, None)


def sweep_noise(d, f0, f1, width=0.35):
    """Noise whose band glides f0 -> f1 (a soft rush of air)."""
    n = N(d); u = np.arange(n) / max(1, n - 1)
    lf = np.log(f0) + (np.log(f1) - np.log(f0)) * u
    out = np.zeros(n); src = noise(d)
    for fc in np.geomspace(120, 7000, 16):
        g = np.exp(-((np.log(fc) - lf) / width) ** 2)
        if g.max() < 0.02:
            continue
        out += bpf(src, fc * 0.8, fc * 1.25) * g
    return out


def bell(f, d, decay, partials=((1.0, 1.0), (2.0, 0.35), (3.01, 0.12))):
    """A small glass-and-brass ring with a 2 ms attack and a tail faded to silence (no tick, no cut-off)."""
    t = T(d); out = np.zeros(N(d))
    for k, g in partials:
        out += g * np.sin(2 * np.pi * f * k * t + S.rng.uniform(0, 6.28)) * np.exp(-t / (decay / k ** 0.5))
    return out * shape(d, 0.002, d * 0.5, d * 0.5 - 0.002)


def sparkle(d, count, lo=1800, hi=3600, fall=None, gain=0.3):
    """Starry twinkles: tiny high bells scattered (or bunched at the start with `fall`)."""
    out = np.zeros(N(d))
    for _ in range(count):
        t0 = S.rng.exponential(fall) if fall else S.rng.uniform(0, d * 0.8)
        t0 = min(t0, d - 0.16)
        out = mix(out, at(bell(S.rng.uniform(lo, hi), 0.16, 0.04, ((1.0, 1.0), (2.0, 0.2))) * S.rng.uniform(0.4, 1.0), t0))
    return out * gain


def warm(freqs, d, a, rel, detune=0.003):
    """A warm soft chord: each note two slightly detuned sines with a little second harmonic."""
    t = T(d); out = np.zeros(N(d))
    for f in freqs:
        for s in (-1, 1):
            ff = f * (1 + s * detune)
            out += np.sin(2 * np.pi * ff * t + S.rng.uniform(0, 6.28)) + 0.18 * np.sin(4 * np.pi * ff * t)
    return out / (2 * len(freqs)) * shape(d, a, max(0.0, d - a - rel), rel)


def puff(d, f0, f1, a=0.01):
    """A soft breath of air (no hiss): band noise gliding, dark."""
    return lpf(sweep_noise(d, f0, f1, 0.4), 4000) * shape(d, a, d * 0.2, d * 0.8 - a)


def lantern_ring(i=0, base=1.0):
    """The lantern itself: a soft glass ring over a small brass one, with a star twinkle on top."""
    f = STAR[i % 4] * base
    return mix(bell(f, 1.0, 0.32) * 0.8, bell(f * 1.5, 0.8, 0.22) * 0.35, at(bell(f * 2.0, 0.6, 0.15) * 0.25, 0.06),
               sparkle(0.6, 3, fall=0.08, gain=0.25))


def pvoice(d, f0, f1, vowel='ee', breath=0.3, vib=0.02, a=0.01):
    """Pip's voice: a small, bright, breathy little throat (its tail eased to silence, never cut off)."""
    return S.voice(d, f0, f1, vowel, breath=breath, rasp=0.0, vib=vib, scale=1.38, a=a) * shape(d, 0.0, d * 0.55, d * 0.45)


# ------------------------------------------------------------------ LMB: Ember Cast (soft light, not fire)
def ember(i):
    """A puff of warm light pushed from her hand: a soft fwip and a small twinkle."""
    d = 0.4
    fwip = puff(0.2, 700 + 60 * i, 2400, 0.008) * 0.9
    glow = bell((1175, 1319, 1480, 1175)[i], 0.35, 0.08, ((1.0, 1.0), (2.0, 0.25))) * 0.35
    return mix(fwip, at(glow, 0.012), at(sparkle(0.3, 2, fall=0.04, gain=0.25), 0.02),
               kick(260, 160, 0.08, 0.008, 0.012, 1.2) * 0.12)


def ember_emp():
    """The long-range ember: a fuller push, a bright rising twinkle."""
    d = 0.6
    push = puff(0.32, 500, 2800, 0.01) * 1.0
    rise = mix(*[at(bell(f, 0.4, 0.1) * 0.35, 0.03 + 0.04 * k) for k, f in enumerate(STAR)])
    return mix(push, rise, at(sparkle(0.5, 6, fall=0.12, gain=0.3), 0.04), kick(220, 130, 0.12, 0.01, 0.02, 1.3) * 0.2)


def kindled(i=0):
    """A foe is Kindled: a little magical bloom, a soft thump and twinkles settling."""
    d = 0.75
    bloom = warm((587, 880, 1175), d, 0.01, 0.6) * 0.8
    thump = kick(190, 100, 0.25, 0.015, 0.05, 1.5) * 0.4
    return mix(bloom, thump, sparkle(d, 8, fall=0.15, gain=0.35), puff(0.3, 2000, 600, 0.005) * 0.4)


# ------------------------------------------------------------------ RMB: Burrseed
def seed_aim():
    """Coiling for the throw: a rustle in her seed pouch and a faint rising shimmer."""
    d = 0.6
    rustle = bpf(noise(d), 1200, 4000) * slow(d, 40, 1.0) * shape(d, 0.05, 0.25, 0.25) * 0.35
    shimmer = warm((880, 1319), d, 0.35, 0.2) * 0.35
    return mix(rustle, shimmer)


def seed():
    """The burrseed flicked out: a light sling snap and the seed whistling away."""
    d = 0.45
    snap = mix(click(0.002, 1500, 5000) * 0.5, kick(330, 180, 0.08, 0.006, 0.015, 1.3) * 0.25)
    whip = puff(0.22, 900, 3000, 0.006) * 0.9
    whistle = S.sweep(1800, 1350, 0.35) * shape(0.35, 0.02, 0.05, 0.28) * 0.08
    return mix(snap, whip, at(whistle, 0.02))


def stick():
    """The burr sticks to a foe: a soft thup and a leafy crunch."""
    d = 0.4
    thup = kick(240, 120, 0.2, 0.01, 0.03, 1.6) * 0.6
    leaf = grains(0.15, 250, 900, 3500, 0.002, 0.006, fall=0.05) * 0.7
    stretch = S.creak(0.25, 180, 140, 0.4, 2000) * 0.25
    return mix(thup, leaf, at(stretch, 0.03))


def root():
    """Roots burst up: an earthy thump, wood cracking and twisting, leaves, a shimmer of her magic."""
    d = 0.9
    thump = mix(kick(140, 55, 0.5, 0.03, 0.09, 2.2) * 0.75, S.sub(70, 45, 0.5, 0.08) * 0.3)
    crackle = grains(0.4, 160, 500, 2500, 0.003, 0.012, fall=0.1) * 1.0
    twist = S.creak(0.6, 110, 70, 0.6, 1500) * 0.45
    leaf = bpf(noise(0.5), 1500, 4500) * slow(0.5, 30, 0.8) * shape(0.5, 0.02, 0.1, 0.38) * 0.25
    magic = warm((523, 784), 0.7, 0.03, 0.6) * 0.25
    return mix(thump, crackle, at(twist, 0.04), at(leaf, 0.05), magic)


# ------------------------------------------------------------------ E: Hearthlight
def hearth():
    """The lantern held up: warm light swelling round her."""
    d = 1.0
    swell = warm((392, 587, 784, 988), d, 0.12, 0.6) * 0.9
    air = puff(0.5, 400, 1600, 0.12) * 0.3
    return mix(swell, air, at(sparkle(0.7, 5, gain=0.25), 0.1))


def lantern_chime(i):
    """Her lantern's star ringing (the signature): soft glass, warm brass and a twinkle."""
    return lantern_ring(i)


def toss():
    """The lantern tossed to a friend: a light whoosh and the handle jingling."""
    d = 0.5
    whoosh = puff(0.35, 600, 2000, 0.03) * 0.9
    jingle = mix(bell(1568, 0.3, 0.06) * 0.25, at(bell(1760, 0.3, 0.05) * 0.2, 0.05))
    return mix(whoosh, at(jingle, 0.02), at(sparkle(0.4, 3, gain=0.2), 0.08))


def land():
    """The lantern lands or latches on: a soft glass clink and a little warm bloom."""
    d = 0.7
    clink = mix(bell(1319, 0.5, 0.09) * 0.6, at(bell(1976, 0.4, 0.06) * 0.3, 0.004), kick(300, 180, 0.08, 0.006, 0.015, 1.2) * 0.2)
    bloom = warm((659, 988), d, 0.04, 0.5) * 0.45
    return mix(clink, bloom)


def flare():
    """The Hearthlight's closing bloom: a warm chord opening and twinkles drifting up."""
    d = 1.1
    chord = warm((392, 494, 587, 784), d, 0.03, 0.85) * 0.9
    lift = puff(0.5, 500, 1800, 0.02) * 0.3
    return mix(chord, lift, sparkle(d, 9, gain=0.3), at(bell(1568, 0.8, 0.25) * 0.25, 0.02))


# ------------------------------------------------------------------ Shift: Relay Step, Carrier
def hop():
    """A light skip (or the start of her glide): a soft pad off the ground and a breath of air."""
    d = 0.35
    pad = kick(240, 140, 0.12, 0.01, 0.02, 1.3) * 0.35
    air = puff(0.28, 700, 2200, 0.015) * 0.9
    return mix(pad, air, at(sparkle(0.25, 2, fall=0.05, gain=0.2), 0.03))


def dash(i):
    """The shared dash, Pip's way: a quick airy whisk and a tiny twinkle."""
    d = 0.36
    air = puff(0.3, 650 + 50 * i, 2100, 0.015) * 0.95
    return mix(air, at(sparkle(0.25, 2, fall=0.06, gain=0.2), 0.04))


def pickup():
    """She heaves a downed friend onto her back: a small effort, cloth rustling, a shield shimmering up."""
    d = 0.7
    effort = pvoice(0.2, 520, 470, 'uh', 0.45, 0.0, 0.01) * 0.7
    cloth = bpf(noise(0.3), 600, 3000) * slow(0.3, 35, 0.9) * shape(0.3, 0.02, 0.1, 0.18) * 0.4
    shield = warm((523, 784, 1047), 0.6, 0.08, 0.4) * 0.4
    return mix(effort, cloth, at(shield, 0.1))


# ------------------------------------------------------------------ X: Hearth Call
def call():
    """Hearth Call: a soft wordless choir swelling up, and her lantern ringing out."""
    d = 1.3
    choir = np.zeros(N(d))
    for f in (392, 494, 587, 784):
        choir = mix(choir, S.voice(d, f, f * 1.01, 'oh', breath=0.25, rasp=0.0, vib=0.012, scale=1.25, a=0.2, decay=0.9) * 0.3)
    choir *= shape(d, 0.25, 0.5, 0.55)
    return mix(choir, at(lantern_ring(0) * 0.6, 0.05), puff(0.6, 300, 1200, 0.2) * 0.25)


def call_hum(i):
    """The tether's warm hum (one every 0.22 s while it holds, each blending into the next)."""
    d = 0.7
    hum = warm((392 * (1 + 0.004 * i), 587, 784), d, 0.18, 0.4, 0.004) * 0.9
    return mix(hum, sparkle(d, 2, gain=0.12))


def arrive():
    """Mended: a gentle whoosh and two lantern bells."""
    d = 1.0
    swoosh = puff(0.4, 500, 2200, 0.05) * 0.6
    return mix(swoosh, at(bell(988, 0.8, 0.25) * 0.6, 0.08), at(bell(1319, 0.8, 0.25) * 0.55, 0.2),
               at(sparkle(0.6, 5, gain=0.25), 0.2))


def cheer():
    """She cheers when the light mends someone: a bright wordless little 'yay'."""
    a = pvoice(0.12, 560, 640, 'ee', 0.25, 0.0, 0.008)
    b = pvoice(0.26, 700, 820, 'ah', 0.2, 0.03, 0.01)
    return mix(a, at(b, 0.1), at(sparkle(0.4, 3, gain=0.15), 0.12))


# ------------------------------------------------------------------ footsteps
def step(surface, i):
    """Light little pads (a small fox), the lantern's handle ticking now and then."""
    d = 0.2
    pad = kick(220 + 15 * i, 140, d, 0.006, 0.014, 1.2) * 0.4
    if surface == 'grass':
        tex = bpf(noise(0.08), 700, 3000) * env(N(0.08), 0.004, 0.022) * 0.55
    elif surface == 'stone':
        tex = mix(crack(d, 900, 3000, 0.006) * 0.4, click(0.002, 1500, 4000) * 0.2)
    elif surface == 'wood':
        tex = S.ring((330 + 12 * i, 720), d, (0.03, 0.02), (0.35, 0.15))
    else:
        tex = grains(0.08, 450, 600, 2200, 0.002, 0.005, fall=0.035) * 0.6
        pad *= 0.6
    tick = at(bell(2093 + 60 * i, 0.12, 0.03, ((1.0, 1.0), (2.0, 0.15))) * 0.12, 0.02) if i in (1, 3) else np.zeros(1)
    return soft_in(mix(pad, tex, tick))


# ------------------------------------------------------------------ voice: small and cute
def hurt(i):
    v = ('ee', 'eh', 'ah', 'ee')[i]
    f0 = (620, 580, 660, 600)[i]
    return mix(pvoice(0.16 + 0.02 * (i % 2), f0, f0 * 1.12 if i % 2 else f0 * 0.85, v, 0.35, 0.0, 0.006),
               at(pvoice(0.1, 420, 460, 'uh', 0.85, 0.0, 0.01) * 0.25, 0.19))


def down():
    """Knocked down: a little falling whimper, and her lantern flickering."""
    whimper = pvoice(0.75, 600, 380, 'uh', 0.35, 0.05, 0.02)
    flicker = np.zeros(1)
    for k in range(3):
        flicker = mix(flicker, at(bell(STAR[0] * (1 - 0.01 * k), 0.35, 0.08) * (0.25 - 0.06 * k), 0.75 + 0.14 * k))
    return mix(whimper, flicker)


def death():
    """A small cry fading out, and the lantern's star dimming to nothing."""
    cry = pvoice(1.0, 680, 330, 'ah', 0.35, 0.04, 0.015)
    t = T(1.6)
    dim = np.sin(2 * np.pi * 784 * t * (1 - 0.03 * t)) * np.exp(-t / 0.45) * shape(1.6, 0.05, 0.6, 0.95) * 0.25
    return mix(cry, at(dim, 0.5))


# ------------------------------------------------------------------ dropped, snuffed and snapped
def carrier_drop():
    """A carried thing let fall: a dull wooden thump and a couple of loose rattles."""
    return mix(kick(170, 60, 0.3, 0.04, 0.1) * 1.0, crack(0.04, 400, 2500, 0.012) * 0.6,
               at(S.rattle(0.18, 50, 600, 2200, 0.5, 0.06) * 0.4, 0.04))


def hearth_snuff():
    """The hearth light going out: a soft hiss that falls away, with a low puff."""
    return mix(S.hiss(0.55, 500, 3500, 0.01, 0.16) * 0.8, S.sweep(300, 110, 0.4) * shape(0.4, 0.01, 0.02, 0.35) * 0.5)


def tether_snap():
    """The tether breaking: a taut twang that drops in pitch, with a click at the break."""
    tw = S.fm(900, 1.0, 3.0, 0.3, 0.1) * shape(0.3, 0.002, 0.02, 0.2)
    return mix(click(0.004, 2500, 8000) * 0.8, tw * 0.7, S.sweep(700, 260, 0.2) * shape(0.2, 0.002, 0.0, 0.15) * 0.4)


def build():
    S.takes_cat('tend_ember', ember, 3, 'fire')
    S.save_cat('tend_ember_emp', ember_emp(), 'fire')
    S.save_cat('tend_kindled', kindled(), 'impact')
    S.save_cat('tend_seed_aim', seed_aim(), 'cast')
    S.save_cat('tend_seed', seed(), 'cast')
    S.save_cat('tend_stick', stick(), 'impact')
    S.save_cat('tend_root', root(), 'impact')
    S.save_cat('tend_hearth', hearth(), 'cast')
    S.takes_cat('tender_lantern_chime', lantern_chime, 3, 'signature')
    S.save_cat('tend_toss', toss(), 'cast')
    S.save_cat('tend_land', land(), 'impact')
    S.save_cat('tend_flare', flare(), 'impact')
    S.save_cat('tend_hop', hop(), 'dash')
    S.takes_cat('tender_dash', dash, 3, 'dash')
    S.save_cat('tend_pickup', pickup(), 'cast')
    S.save_cat('tend_call', call(), 'cast')
    S.takes_cat('tend_call_hum', call_hum, 3, 'loop')
    S.save_cat('tend_arrive', arrive(), 'impact')
    S.save_cat('tender_cheer', cheer(), 'signature')
    for s in ('grass', 'stone', 'wood', 'snow'):
        S.takes_cat('tender_step_' + s, lambda i, s=s: step(s, i), 3, 'step')
    S.takes_cat('tender_hurt', hurt, 3, 'grunt')
    S.save_cat('tender_down', down(), 'grunt')
    S.save_cat('tender_death', death(), 'grunt')
    S.save_cat('tender_drop', carrier_drop(), 'impact')
    S.save_cat('tender_hearth_snuff', hearth_snuff(), 'cast')
    S.save_cat('tender_tether_snap', tether_snap(), 'impact')


if __name__ == '__main__':
    build()
    print('gen_sfx_pip: done')
