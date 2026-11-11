"""Carry sounds (docs/AUDIO.md, "carry 2 in, 1 extra out"): played through scripts/match/carry_sfx.gd. Run from tools/.

  carry_swap_out  the lead swap's first note: the outgoing Boki's chirp, dipping as it hops into the satchel
  carry_swap_in   the second note, a fifth up: the incoming Boki's chirp, rising as it comes out
  carry_claim     a Boki claimed into the carry-out slot: a warm low chord that settles in under a soft latch
  carry_stolen    your carried Boki was taken: a falling minor sting with a snatch of cloth (the owner hears it)
  carry_take      the thief's sly take: a grace-note pluck up and a quick swish (positional, nearby squads hear it)
"""
import numpy as np
import sfx_lib as S
from sfx_lib import N, T, env, mix, at, lpf, bpf, noise

S.reseed(9093)

NOTE_OUT = 784.0          # Hz, G5: the outgoing Boki's chirp (CarrySfx pitches it by the Boki's size)
NOTE_IN = 1175.0          # Hz, D6: a fifth up, the incoming one


def chirp(f, bend, vowel, d=0.2):
    """A short Boki chirp around f that bends by `bend` (0.88 dips, 1.14 rises), with a soft vowel under it."""
    n = N(d); u = np.arange(n) / n
    fr = f * bend ** (1 - np.exp(-u * 7)) * (1 + 0.015 * np.sin(2 * np.pi * 8 * T(d)))
    ph = 2 * np.pi * np.cumsum(fr) / S.SR
    tone = (np.sin(ph) + 0.15 * np.sin(2 * ph)) * S.shape(d, 0.012, d * 0.25, d * 0.6)
    body = S.voice(d, f * 0.5, f * 0.5 * bend, vowel, breath=0.08, scale=1.3, a=0.012, decay=d * 0.5)
    return lpf(mix(tone, 0.4 * body[:n]), 6000)


def claim():
    """Warm lock-in: a soft latch, then a low A major chord (A3, E4, A4, C#5) settling in."""
    latch = bpf(noise(0.03), 900, 3500) * env(N(0.03), 0.0005, 0.006)
    thunk = S.sweep(180, 120, 0.09) * env(N(0.09), 0.002, 0.03)
    d = 0.6
    chord = mix(*[g * np.sin(2 * np.pi * f * T(d)) for f, g in ((220, 1.0), (330, 0.7), (440, 0.45), (554, 0.2))])
    chord = chord * S.shape(d, 0.04, 0.12, 0.44) * (1 + 0.04 * np.sin(2 * np.pi * 4 * T(d)))
    return lpf(mix(latch * 0.8, thunk * 0.6, at(chord, 0.02)), 3000)


def stolen():
    """The owner's sting: three falling notes (E5, C5, A4), the last one bending flat, over a snatch of cloth."""
    notes = [(659, 0.0, 1.0), (523, 0.11, 1.0), (440, 0.22, 0.96)]
    run = []
    for f, t, bend in notes:
        d = 0.42 if t > 0.2 else 0.16
        tone = S.sweep(f, f * bend, d) + 0.25 * S.sweep(2 * f, 2 * f * bend, d)
        run.append(at(tone * S.shape(d, 0.006, d * 0.2, d * 0.75), t))
    snatch = S.hiss(0.14, 1500, 6000, a=0.01, decay=0.05)
    return lpf(mix(snatch * 0.5, *run), 5000)


def take():
    """The thief's take: a low grace note flicking up a sixth, a pizzicato pluck, a quick swish into the bag."""
    def pluck(f, d):
        return (np.sin(2 * np.pi * f * T(d)) + 0.3 * np.sin(4 * np.pi * f * T(d))) * env(N(d), 0.002, d * 0.3)
    swish = bpf(noise(0.16), 1200, 5000) * S.shape(0.16, 0.06, 0.0, 0.1)
    return lpf(mix(pluck(330, 0.12) * 0.7, at(pluck(554, 0.3), 0.07), at(swish * 0.45, 0.12)), 5500)


S.save_cat('carry_swap_out', chirp(NOTE_OUT, 0.88, 'oh'), 'boki')
S.save_cat('carry_swap_in', chirp(NOTE_IN, 1.14, 'ah'), 'boki')
S.save_cat('carry_claim', S.soft_in(claim(), 4), 'ui')
S.save_cat('carry_stolen', stolen(), 'cast')
S.save_cat('carry_take', S.soft_in(take(), 4), 'cast')
print('carry sounds written')
