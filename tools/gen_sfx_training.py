"""Training Grounds sounds (docs/AUDIO.md, content/sfx/training.json; played by scripts/match/training_sfx.gd).

  training_count       one beat of the duel ring's 3-2-1: a struck bell plate (played at a higher pitch each beat)
  training_horn        the round starting: a short brass-like horn blast over a low thump
  training_dummy_hit   a hit on a practice dummy: a padded leather thump and a bright tick, so it reads as landed
  training_reset       a station reset: a rising two-note chime over a soft whoosh, everything back to its marks
  training_bot_spawn   a sparring bot appearing: a rising shimmer and a small landing thump
  amb_training_wind    the open expanse: wide, steady wind with gusts
  amb_training_island  a sky island: a sheltered low breeze, leaves stirring and the odd far wind chime

    cd tools && python3 gen_sfx_training.py   (then: godot --headless --import)

Original synthesis, no samples; the cues are 44.1 kHz mono wavs levelled by sfx_lib, the beds stereo Ogg
loops written with gen_ambience's helpers. Needs numpy, scipy and ffmpeg.
"""
import numpy as np
import sfx_lib as S
from sfx_lib import N, env, mix, at, lpf, hpf, bpf, noise
import gen_ambience as A

S.reseed(7311)
BED_SECONDS = 24.0


def plate(f, d=0.6, decay=0.22):
    """A struck metal plate: inharmonic partials over a quick tick."""
    body = S.chime(f, d, decay, ((1.0, 1.0), (2.32, 0.5), (4.25, 0.25), (6.8, 0.1)))
    return mix(body, 0.35 * S.click(0.006, 2500, 8000, 0.002))


def count(i):
    return S.reflections(plate(880.0, 0.55, 0.2))


def horn(i):
    d = 0.9
    t = S.T(d); n = N(d)
    f = 233.0 * (1.0 + 0.02 * np.minimum(t / 0.06, 1.0))
    ph = 2 * np.pi * np.cumsum(f) / S.SR
    tone = sum(a * np.sin(k * ph) for k, a in ((1, 1.0), (2, 0.6), (3, 0.42), (4, 0.25), (5, 0.14)))
    tone = S.sat(tone * S.shape(d, 0.03, 0.55, 0.3), 1.8)
    thump = S.kick(120, 55, 0.4, 0.04, 0.1)
    return S.reflections(lpf(mix(tone, 0.6 * thump), 4200))


def dummy_hit(i):
    d = 0.16
    pad = bpf(noise(d), 180, 900) * env(N(d), 0.001, 0.035)
    body = S.kick(200 + 20 * i, 90, d, 0.015, 0.04)
    tick = S.click(0.005, 3000, 9000, 0.0015)
    return mix(pad, 0.8 * body, 0.5 * at(tick, 0.004))


def reset(i):
    whoosh = bpf(noise(0.45), 600, 3200) * S.shape(0.45, 0.2, 0.05, 0.2)
    notes = mix(S.chime(660.0, 0.6, 0.25), at(S.chime(990.0, 0.6, 0.3), 0.12))
    return S.reflections(mix(0.35 * whoosh, notes))


def bot_spawn(i):
    d = 0.55
    shimmer = S.sweep(400, 1600, d, 'sin', 2.0) * S.shape(d, 0.35, 0.05, 0.15)
    sparkle = bpf(noise(d), 4000, 9000) * S.shape(d, 0.3, 0.05, 0.2) * 0.25
    land = at(S.kick(160, 60, 0.25, 0.03, 0.07), 0.42)
    return S.reflections(mix(0.6 * shimmer, sparkle, 0.9 * land))


def wind_bed():
    n = int(A.SR * (BED_SECONDS + 2.0))
    chans = []
    for _ in range(2):
        base = A.lpf(A.rng.standard_normal(n), 650) * A.slow(n, 0.07, 0.45, 1.0)
        gust = A.svf(A.rng.standard_normal(n), A.slow(n, 0.11, 300, 900), 5.0) * A.slow(n, 0.13, 0.0, 1.0) ** 2 * 0.3
        hiss = A.bpf(A.rng.standard_normal(n), 1800, 5200) * A.slow(n, 0.09, 0.1, 0.6) * 0.08
        chans.append(base + gust + hiss)
    return A.loop(np.stack(chans, 1))


def island_bed():
    n = int(A.SR * (BED_SECONDS + 2.0))
    out = np.stack([A.lpf(A.rng.standard_normal(n), 300) * A.slow(n, 0.05, 0.5, 1.0) for _ in range(2)], 1)
    for _ in range(14):                      # leaves stirring: short bursts of soft high noise
        s0 = int(A.rng.integers(0, n - A.SR)); m = int(A.SR * A.rng.uniform(0.4, 1.0))
        g = A.bpf(A.rng.standard_normal(m), 2500, 7000) * np.sin(np.pi * np.arange(m) / m) ** 2 * 0.12
        pan = A.rng.uniform(0.15, 0.85)
        out[s0:s0 + m, 0] += g * (1 - pan); out[s0:s0 + m, 1] += g * pan
    for _ in range(4):                       # a far wind chime, once in a while
        s0 = int(A.rng.integers(0, n - A.SR * 3)); m = int(A.SR * 2.5); tt = np.arange(m) / A.SR
        f0 = A.rng.choice([1047.0, 1175.0, 1319.0, 1568.0])
        c = sum(a * np.sin(2 * np.pi * f0 * r * tt) * np.exp(-tt / dc) for r, a, dc in ((1.0, 0.5, 0.8), (2.76, 0.2, 0.4)))
        pan = A.rng.uniform(0.2, 0.8)
        out[s0:s0 + m, 0] += c * 0.05 * (1 - pan); out[s0:s0 + m, 1] += c * 0.05 * pan
    return A.loop(out)


def main():
    S.takes_cat('training_count', count, 0, 'ui')
    S.takes_cat('training_horn', horn, 0, 'signature')
    S.takes_cat('training_dummy_hit', dummy_hit, 3, 'ui')
    S.takes_cat('training_reset', reset, 0, 'ui')
    S.takes_cat('training_bot_spawn', bot_spawn, 0, 'cast')
    A.write_ogg('amb_training_wind', wind_bed(), 0.6)
    A.write_ogg('amb_training_island', island_bed(), 0.5)


if __name__ == '__main__':
    main()
