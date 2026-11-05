"""Synthesizes Lisette's sounds (id archer) into audio/pin_*.wav and audio/lis_*.wav: plucked red thread, silver needles,
scissor snips and cloth, on the DSP and the CC0 foley of tools/gen_kael_sfx.py, set to the same category loudness.

    python3 tools/gen_lisette_sfx.py [names...]      (then: godot --headless --import)
"""
import math, sys
import gen_kael_sfx as K
from gen_kael_sfx import N, R, at, biquad, blade_ring, bp, decay, foley, gain, grunt, hp, lp, mix, modal, noise, resample, rise, room, \
    sat, sub, swell, tail_off, tone, vocal_env, whoosh, write


def pluck(f, s, damp=0.996, bright=0.5):
    """A plucked string (Karplus-Strong): her thread bowstring, red silk under tension rather than gut."""
    n = N(s)
    p = max(2, int(K.SR / f))
    buf = [R.uniform(-1, 1) for _ in range(p)]
    lo = 0.0
    for i in range(p):
        lo += (buf[i] - lo) * bright
        buf[i] = lo
    out = K.zeros(n)
    i = 0
    prev = 0.0
    for t in range(n):
        v = buf[i]
        nxt = (v + prev) * 0.5 * damp
        prev = v
        buf[i] = nxt
        out[t] = v
        i = (i + 1) % p
    return out


def needle(f=4200, s=0.14, level=1.0):
    """A thin steel needle: a very high, very short ring."""
    return gain(modal([(f, 1.0, 0.03), (f * 1.62, 0.6, 0.02), (f * 2.41, 0.3, 0.012)], s), level)


def whistle(s, f0, f1, level=1.0):
    """A needle through the air: a narrow rising then falling hiss."""
    def f(u):
        return f0 + (f1 - f0) * u
    return gain(swell(biquad(noise(s), 'bp', f, 6.0), 0.3, 1.3), level)


def snip():
    """Tailor's scissors closing: two blades, one click."""
    blades = gain(hp(resample(foley('knifeSlice'), 1.5)[:N(0.1)], 1200), 0.7)
    return mix(blades, at(gain(resample(foley('metalClick'), 1.4), 1.0), 0.045))


def thread_creak(s, f0, f1):
    """Thread drawn tight: a rising strained tone with a fibrous grain."""
    n = N(s)
    body = biquad(tone(f0, f1, s, 'saw'), 'lp', lambda u: 500 + 2000 * u, 2.0)
    grain = bp(noise(s), 2600, 1.2)
    flut = [0.5 + 0.5 * math.sin(i * 0.011 + 3 * math.sin(i * 0.0017)) for i in range(n)]
    return mix(gain(body, 0.5), [grain[i] * flut[i] * 0.4 for i in range(n)])


def draw():
    """LMB drawn: leather, the thread pulling tight."""
    return tail_off(mix(rise(thread_creak(0.5, 130, 240), 0.9), gain(resample(foley('cloth1'), 1.1), 0.45)))


def stage():
    """Empowered ready: one needle tick."""
    return room(mix(needle(3600, 0.16), at(gain(needle(5400, 0.12), 0.5), 0.03)), 0.14)


def stage_super():
    """Supercharged ready: a bright silver ring with the thread humming under it."""
    return room(mix(gain(blade_ring(1760, 0.6, 1.0, 0.2), 0.8), gain(blade_ring(2637, 0.5, 1.0, 0.14), 0.45), gain(pluck(110, 0.5), 0.3)), 0.2)


def perfect():
    """Perfect release: the scissors' snip, then a clean ring, the cue she times to."""
    return room(mix(gain(snip(), 1.0), at(gain(blade_ring(2093, 0.5, 1.0, 0.16), 0.7), 0.05)), 0.16)


def overdraw():
    """Held too long: the thread fraying."""
    x = thread_creak(0.42, 240, 150)
    return tail_off(mix(decay(x, 0.2, 0.02), K.rattle(0.3, 14, 3000, 6000, 0.25)))


def loose(take=0):
    """A shot leaving: the thread plucked and the needle's whistle."""
    f = (196, 208, 185)[take]
    return room(mix(gain(decay(pluck(f, 0.32), 0.09), 1.0), gain(whistle(0.24, 3200, 5200), 0.7), gain(decay(hp(noise(0.02), 2000), 0.004), 0.4)), 0.1)


def loose_super():
    """Supercharged: a deeper pluck and a long needle tear."""
    return room(mix(gain(decay(pluck(131, 0.5), 0.15), 1.0), gain(whistle(0.46, 2200, 6000), 0.9), gain(whoosh(0.4, 700, 3400, 0.2, 1.3), 0.4)), 0.12)


def needle_hit(take):
    """A needle arrow landing in a body: a sharp tick, a dull stop."""
    return mix(needle(4300 + 400 * take, 0.1, 0.5), gain(resample(foley('chop'), 1.3 + 0.1 * take), 0.8), gain(sub(200, 120, 0.08, 0.03), 0.4))


def stick():
    """A missed needle biting the ground: a tick, the thread settling."""
    return mix(needle(3800, 0.12, 0.7), gain(resample(foley('footstep06'), 1.5), 0.5), at(gain(decay(hp(noise(0.1), 3000), 0.03), 0.1), 0.03))


def super_hit():
    """A Supercharged needle through: a hard silver crack."""
    return room(mix(gain(blade_ring(1319, 0.5, 1.0, 0.14), 0.7), gain(decay(hp(noise(0.08), 1800), 0.012), 0.9), gain(resample(foley('chop'), 0.9), 0.8), gain(sub(240, 90, 0.2, 0.06), 0.6)), 0.14)


def heavy_draw():
    """Heavy Shot held: the whole bow bending, a thick thread complaining."""
    return tail_off(mix(rise(thread_creak(0.85, 70, 150), 0.8), gain(rise(lp(resample(foley('creak1'), 0.8), 2200)[:N(0.85)], 0.6), 0.5)))


def heavy():
    """Heavy Shot loosed: a deep pluck and a big needle leaving."""
    return room(mix(gain(decay(pluck(82, 0.6), 0.2), 1.0), gain(whoosh(0.5, 300, 2600, 0.2, 0.9), 0.8), gain(whistle(0.36, 1500, 3200), 0.5)), 0.12)


def heavy_thump():
    """The weight under the Heavy Shot's release."""
    return mix(gain(sub(120, 55, 0.3, 0.1), 1.0), gain(lp(resample(foley('dropLeather'), 0.7), 1500), 0.6))


def heavy_hit():
    """The Heavy Shot landing: steel driven in, the body shoved."""
    return room(sat(mix(gain(sub(150, 50, 0.5, 0.15), 1.0), gain(resample(foley('chop'), 0.6), 0.9), gain(resample(foley('metalPot2'), 0.8), 0.35), gain(needle(2600, 0.2), 0.4)), 1.4), 0.16, 0.05)


def pin():
    """Pinned to a wall: a big needle into stone, ringing in place."""
    return room(mix(gain(blade_ring(740, 0.8, 1.0, 0.28), 0.7), gain(resample(foley('metalLatch'), 0.6), 0.9), gain(sub(170, 80, 0.2, 0.06), 0.7)), 0.2)


def hail():
    """Hail Wall thrown up: a volley of plucks and a rush of needles."""
    out = K.zeros(N(0.5))
    for i in range(5):
        p = at(decay(pluck(R.uniform(170, 260), 0.2), 0.05), 0.03 * i)
        out = mix(out, gain(p, 0.5))
    return room(mix(out, gain(whoosh(0.5, 900, 4800, 0.4, 1.0), 0.8)), 0.1)


def rain():
    """The rain arriving: many needles falling, a long shiver."""
    s = 0.95
    wash = swell(hp(bp(noise(s), 4000, 0.6), 1500), 0.3, 1.0)
    return mix(gain(wash, 0.6), K.rattle(s * 0.9, 90, 3200, 7000, 0.5))


def patter(take):
    """One needle landing in the rain (very short: it plays many times a second)."""
    return mix(needle(3400 + 900 * take, 0.06, 0.8), gain(decay(lp(noise(0.03), 2400), 0.006), 0.4))


def spirit():
    """Spirit Walk: cloth snapped, then thread unspooling at speed."""
    n = 0.62
    spool = K.rattle(n * 0.8, 50, 700, 1600, 0.35)
    return room(mix(gain(resample(foley('cloth3'), 1.2), 0.9), gain(whoosh(n, 500, 3000, 0.25, 0.9), 0.9), spool, gain(pluck(330, 0.3), 0.2)), 0.2)


def spirit_end():
    """Back in the world: a thread pulled through, two soft notes."""
    return room(mix(gain(blade_ring(1319, 0.5, 1.0, 0.14), 0.5), at(gain(blade_ring(988, 0.5, 1.0, 0.14), 0.4), 0.08), gain(whistle(0.2, 2600, 1600), 0.5)), 0.2)


def focus():
    """A full Focus spent: the string's sharp snap."""
    return mix(gain(decay(pluck(392, 0.2), 0.05), 1.0), gain(needle(5200, 0.1), 0.5))


def ult_cast():
    """Starpiercer armed: a spool spinning up, a low sung thread."""
    s = 0.85
    hum = rise(biquad(mix(tone(98, 147, s, 'saw'), gain(tone(147, 220, s, 'saw'), 0.5)), 'lp', lambda u: 300 + 2400 * u, 1.6), 0.7)
    return room(mix(gain(sat(hum, 1.6), 0.8), K.rattle(s * 0.8, 60, 900, 2600, 0.3), at(gain(snip(), 0.8), 0.72), gain(blade_ring(1175, 0.7, 1.0, 0.3), 0.3)), 0.2)


def ult_nock():
    """A beam nocked: the thread winding tight in one breath."""
    return tail_off(rise(thread_creak(0.3, 220, 620), 0.8))


def ult_beam(final):
    """A beam: a huge pluck and the air stitched open; the last one is deeper and longer."""
    f, s = (65, 0.9) if final else (82, 0.65)
    crack = decay(hp(noise(0.1), 1400), 0.016)
    tear = whoosh(s * 0.7, 900, 5600, 0.12, 1.4, 1.0)
    return room(sat(mix(gain(decay(pluck(f, s), s * 0.3), 1.0), gain(crack, 1.0), gain(tear, 0.8), gain(sub(110, 40, s, s * 0.3), 1.0), gain(blade_ring(1480, 0.5, 1.0, 0.16), 0.3 if final else 0.2)), 1.4), 0.18, 0.06)


HURT = ([(760, 7.0, 1.0), (1500, 7.0, 0.6), (2900, 8.0, 0.2)], [(850, 7.0, 1.0), (1400, 7.0, 0.55), (2800, 8.0, 0.2)],
        [(680, 7.0, 1.0), (1700, 7.0, 0.5), (3000, 8.0, 0.18)], [(900, 6.0, 1.0), (1300, 7.0, 0.5), (2900, 8.0, 0.16)])


def hurt(take):
    """A short breath-held gasp through the teeth, four takes, no words."""
    s = (0.17, 0.2, 0.15, 0.23)[take]
    f = (262, 240, 285, 225)[take]
    return vocal_env(grunt(s, f, f * 0.8, HURT[take], 0.28, 0.2), 0.1, 0.25, 0.75)


def downed():
    """Going down: a falling cry, the breath going out, no words."""
    cry = grunt(0.8, 275, 150, [(800, 6.0, 1.0), (1300, 6.0, 0.55), (2800, 8.0, 0.16)], 0.3, 0.3)
    breath = at(decay(bp(noise(0.4), 1200, 0.7), 0.12, 0.05), 0.62)
    return room(mix(vocal_env(cry, 0.06, 0.3, 0.7), gain(breath, 0.2), at(gain(resample(foley('dropLeather'), 0.95), 0.4), 0.42)), 0.12)


def step(surface, take):
    """A light laced boot: the foley's foot, no weight under it."""
    foot = resample(foley('footstep0%d' % (take * 2)), {'grass': 1.05, 'stone': 1.1, 'snow': 0.95, 'wood': 1.0}[surface])
    if surface == 'grass':
        return mix(gain(lp(foot, 4200), 0.8), gain(hp(decay(noise(0.1), 0.04), 1800), 0.2))
    if surface == 'snow':
        return mix(gain(lp(foot, 2600), 0.5), K.rattle(0.09, 30, 2400, 5600, 0.4))
    if surface == 'wood':
        return mix(gain(foot, 0.8), gain(modal([(310, 1.0, 0.03), (520, 0.5, 0.02)], 0.1), 0.45))
    return mix(gain(hp(foot, 250), 1.0), gain(decay(hp(noise(0.02), 3000), 0.006), 0.2))


def build():
    jobs = [('pin_draw', draw, 'wind'), ('pin_stage', stage, 'tick'), ('pin_super', stage_super, 'tick'), ('pin_perfect', perfect, 'tick'),
            ('pin_overdraw', overdraw, 'wind'), ('pin_loose_super', loose_super, 'cast'), ('pin_super_hit', super_hit, 'hit'),
            ('lis_stick', stick, 'tick'), ('pin_heavy_draw', heavy_draw, 'wind'), ('pin_heavy', heavy, 'cast'), ('lis_heavy_thump', heavy_thump, 'hit'),
            ('pin_heavy_hit', heavy_hit, 'impact'), ('lis_pin', pin, 'hit'), ('pin_hail', hail, 'cast'), ('pin_rain', rain, 'wind'),
            ('pin_spirit', spirit, 'cast'), ('pin_spirit_end', spirit_end, 'tick'), ('lis_focus', focus, 'tick'), ('pin_ult_cast', ult_cast, 'cast'),
            ('pin_ult_nock', ult_nock, 'tick'), ('pin_ult_beam', lambda: ult_beam(False), 'impact'), ('pin_ult_final', lambda: ult_beam(True), 'impact'),
            ('lis_downed', downed, 'voice')]
    jobs += [('pin_loose', lambda: loose(0), 'swing')]
    jobs += [('lis_needle_hit_%d' % (i + 1), lambda i=i: needle_hit(i), 'hit') for i in range(3)]
    jobs += [('pin_patter_%d' % (i + 1), lambda i=i: patter(i), 'step') for i in range(3)]
    jobs += [('lis_hurt_%d' % (i + 1), lambda i=i: hurt(i), 'voice') for i in range(4)]
    for surface in ('grass', 'stone', 'snow', 'wood'):
        jobs += [('lis_step_%s_%d' % (surface, i + 1), lambda s=surface, i=i: step(s, i), 'step') for i in range(3)]
    return jobs


def main():
    only = sys.argv[1:]
    K.CEILING_DB = -3.5          # needle ticks are all transient: a little more room for their true peaks
    for name, fn, category in build():
        if only and not any(name.startswith(o) for o in only):
            continue
        write(name, fn(), category)


if __name__ == '__main__':
    main()
