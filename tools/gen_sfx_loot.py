"""Opening a chest or a deathbox (docs/AUDIO.md): two short held loops while the channel runs and three
stings when it completes. Run from tools/: python3 gen_sfx_loot.py

  loot_creak  chest: wood under a slow strain, a lid stick-slipping, seamless
  loot_latch  deathbox: a soft metal latch tick every half second over a low hum, seamless
  loot_rare / loot_epic / loot_legend: a rising bell run for the rarest thing inside, longer and
              brighter with each step (rare 2 notes, epic 3, legendary 4 with a shimmer)
Original synthesis, no samples; same soft palette as gen_sfx_ui.py.
"""
import numpy as np
import sfx_lib as S
from sfx_lib import N, T, env, mix, at, lpf, bpf, noise

S.reseed(5120)
LOOP_S = 1.2     # s: both loops; every hum partial is a whole number of cycles in it so the seam is clean


def creak_loop():
    d = LOOP_S
    x = S.creak(d, 95, 70, 0.5, 2200)
    x = mix(x, 0.25 * S.creak(d, 140, 110, 0.7, 1600))
    return lpf(x, 3200) * S.shape(d, 0.02, d, 0.02)


def latch_loop():
    d = LOOP_S
    t = T(d)
    hum = sum(g * np.sin(2 * np.pi * f * t) for f, g in ((100, 1.0), (200, 0.35), (300, 0.12)))
    hum = hum * (0.65 + 0.35 * np.sin(np.pi * 2 * t / d) ** 2)        # two slow swells per loop
    tick = 6.0 * lpf(S.click(0.006, 1500, 5000, 0.002), 2600)
    out = mix(hum, at(tick, 0.0), at(tick, d / 2))[:N(d)]
    return lpf(out, 1800)


def sting(freqs, step, decay, shimmer):
    """Bells starting `step` s apart, each ringing `decay`; the last one doubled an octave up for a shimmer."""
    d = step * len(freqs) + decay * 2.2
    parts = [at(S.chime(f, decay * 2.2, decay), step * i) for i, f in enumerate(freqs)]
    if shimmer:
        parts.append(shimmer * at(S.chime(freqs[-1] * 2, 0.9, 0.5), step * (len(freqs) - 1)))
    return lpf(S.pad(mix(*parts), d), 7000)


def main():
    S.save_loop('loot_creak', creak_loop(), 'loop')
    S.save_loop('loot_latch', latch_loop(), 'loop')
    S.save_cat('loot_rare', sting((660, 880), 0.11, 0.35, 0), 'cast')
    S.save_cat('loot_epic', sting((523, 659, 880), 0.1, 0.4, 0), 'cast')
    S.save_cat('loot_legend', sting((523, 659, 784, 1047), 0.09, 0.5, 0.35), 'cast')


if __name__ == '__main__':
    main()
