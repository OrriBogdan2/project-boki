"""The sky train's halt and ride sounds (docs/AUDIO.md, content/sfx/train.json), played by TrainSfx.

    cd tools && python3 gen_sfx_train.py      (then: godot --headless --import)

  train_brake       easing into a halt: iron shoes on the wheels, a falling squeal over a soft grind
  train_bell        pulled in: two strokes of a brass station bell
  train_door_open   the car doors sliding open: a latch clunk and a rolling slide
  train_door_close  the doors sliding shut: the slide the other way and a firm latch
  train_whistle     about to leave: a bright two-note steam whistle that carries, so you can run for it
  train_ride        loop: riding a car, wheels over the rail joints and a low body hum (quiet)
  train_rumble      loop: the train going by, heard from the ground: a deep rumble with soft clacks
The horn and the hit stay in tools/gen_train_sfx.py. Original synthesis, no samples.
"""
import os, sys
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import sfx_lib as S
from sfx_lib import N, T, noise, lpf, hpf, bpf, env, mix, at, shape, soft_in, sweep, chime

S.reseed(5307)


def brake():
    d = 1.9
    squeal = sum(sweep(f, f * 0.82, d, curve=0.7) * g for f, g in ((1760, 1.0), (2310, 0.45), (3120, 0.2)))
    squeal *= 1 + 0.25 * np.sin(2 * np.pi * 7.0 * T(d))
    grind = bpf(noise(d), 180, 1400) * 1.6
    hiss_ = hpf(noise(d), 3500) * 0.25 * env(N(d), 0.01, 0.25)
    return soft_in(mix(squeal * 0.35 + grind, hiss_) * shape(d, 0.2, 1.1, 0.6), 2.0)


def bell():
    d = 2.2
    stroke = lambda: chime(988, 1.6, 0.6, ((1.0, 1.0), (2.0, 0.35), (2.76, 0.4), (5.4, 0.15)))
    knock = bpf(noise(0.03), 600, 3000) * env(N(0.03), 0.0005, 0.006) * 0.4
    return mix(stroke(), knock, at(stroke() * 0.85, 0.55), at(knock, 0.55))[:N(d)]


def slide(d, up):
    roll = bpf(noise(d), 250, 1600) * (1 + 0.4 * np.sin(2 * np.pi * 23 * T(d)))
    tone = sweep(220 if up else 300, 300 if up else 220, d) * 0.15
    return (roll + tone) * shape(d, 0.05, d * 0.5, d * 0.4)


def clunk():
    d = 0.25
    body = sweep(140, 70, d) * env(N(d), 0.001, 0.05)
    tick = bpf(noise(d), 1200, 5000) * env(N(d), 0.0005, 0.01) * 0.6
    return body + tick


def door_open():
    return soft_in(mix(clunk() * 0.8, at(slide(0.6, True), 0.08)), 1.0)


def door_close():
    return soft_in(mix(slide(0.55, False), at(clunk(), 0.5)), 1.0)


def whistle():
    d = 1.6
    tone = np.zeros(N(d))
    for f0, t0, dur in ((740, 0.0, 0.55), (988, 0.6, 1.0)):
        voice = sum(np.sin(2 * np.pi * f0 * k * T(dur)) * g for k, g in ((1, 1.0), (2, 0.3), (3, 0.12)))
        steam = bpf(noise(dur), f0 * 0.9, f0 * 1.3) * 0.25
        part = (voice * (1 + 0.006 * np.sin(2 * np.pi * 5.5 * T(dur))) + steam) * shape(dur, 0.06, dur - 0.3, 0.24)
        tone[N(t0):N(t0) + len(part)] += part
    return tone + hpf(noise(d), 4000) * 0.04 * shape(d, 0.05, 1.2, 0.3)


def joints(d, beat, f_lo, f_hi, gain):
    """Wheels over rail joints: soft knock pairs every `beat` seconds, a whole number per loop."""
    out = np.zeros(N(d))
    for i in range(int(round(d / beat))):
        for off in (0.0, 0.11):
            s0 = N(i * beat + off); seg = min(N(0.08), len(out) - s0)
            out[s0:s0 + seg] += bpf(noise(0.08), f_lo, f_hi)[:seg] * env(seg, 0.003, 0.02) * gain
    return out


def periodic(d, hz):
    """A hum that repeats exactly: every partial a whole number of cycles in d seconds."""
    t = T(d)
    return sum(np.sin(2 * np.pi * round(f * d) / d * t) * g for f, g in ((hz, 1.0), (hz * 1.5, 0.4), (hz * 2, 0.25)))


def ride():
    d = 2.0
    return periodic(d, 55) * 0.25 + lpf(noise(d), 300) * 0.6 + joints(d, 0.5, 250, 1200, 1.0)


def rumble():
    d = 2.0
    return periodic(d, 38) * 0.4 + lpf(noise(d), 160) * 1.2 + joints(d, 0.5, 120, 700, 0.6)


def build():
    S.save_cat('train_brake', brake(), 'cast')
    S.save_cat('train_bell', bell(), 'cast')
    S.save_cat('train_door_open', door_open(), 'dash')
    S.save_cat('train_door_close', door_close(), 'dash')
    S.save_cat('train_whistle', whistle(), 'signature')
    S.save_loop('train_ride', ride(), 'loop')
    S.save_loop('train_rumble', rumble(), 'loop')


if __name__ == '__main__':
    build()
    print('gen_sfx_train: done')
