"""Last-hit steal cues (docs/AUDIO.md "Steal cues", content/sfx/steals.json, played by StealSfx).

    python3 tools/gen_sfx_steals.py      (then: godot --headless --import)

steal_cry_<kind>: a prize monster's cry the first time it drops to a quarter of its health, one per voice
kind of the monster voices (v_<kind>, tools/gen_sfx.py), pitched up and strained so it reads as hurt.
steal_reel: the heavy thud of its reel (a stagger). steal_won: a bright swipe and rising run for the squad
that took the last hit; steal_lost: a low falling pair for the squad that did the damage and lost it.
Both stings sit at the same level, told apart by colour, like the ultimate team tags.
Original synthesis, no samples. Its own seed: running it re-rolls nothing else.
"""
import os, sys
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import sfx_lib as S
from sfx_lib import N, noise, lpf, hpf, bpf, env, mix, at, kick, sub, tail

S.reseed(7417)


def am(x, hz, depth):
    """A flutter: the sound pulsed `hz` times a second, `depth` of the way to silence."""
    return x * (1.0 - depth + depth * np.sin(2 * np.pi * hz * np.arange(len(x)) / S.SR))


def fade(x, d=0.06):
    """The last `d` s ramped to silence, so a layer never stops with a click."""
    k = min(len(x), N(d))
    x = x.copy()
    x[-k:] *= np.linspace(1.0, 0.0, k)
    return x


# ---------------------------------------------------------------- the cries, one per monster voice
def cry_skitter():
    clicks = [at(bpf(noise(0.025), 900, 2400) * env(N(0.025), 0.001, 0.006), 0.03 * k) for k in range(6)]
    return mix(S.voice(0.45, 340, 210, 'ee', breath=0.3, rasp=0.3, scale=1.3), *clicks)


def cry_spitter():
    d = 0.55
    gargle = lpf(noise(d), 600) * env(N(d), 0.02, 0.2) * 0.4
    return mix(am(S.voice(d, 270, 150, 'ah', rasp=0.35, scale=1.1), 18, 0.45), gargle)


def cry_brute():
    return S.voice(0.7, 160, 92, 'ah', breath=0.2, rasp=0.6, scale=0.85, a=0.03)


def cry_bomber():
    d = 0.5
    return mix(am(S.voice(d, 220, 430, 'eh', vib=0.04, scale=1.1, a=0.04), 13, 0.35), lpf(S.hiss(d, 1800, 5000), 5000) * 0.08)


def cry_sentinel():
    d = 0.75
    knock = kick(150, 80, 0.15, decay=0.04) * 0.5
    return mix(S.voice(d, 118, 72, 'oh', rasp=0.45, scale=0.8, a=0.04), S.creak(d, 85, 55) * 0.5, at(knock, 0.08))


def cry_glimmer():
    d = 0.6
    falls = [at(S.chime(f, 0.35, 0.12), 0.07 * i) * (0.8 - 0.15 * i) for i, f in enumerate((1568, 1319, 1047, 880))]
    return mix(*falls, S.voice(d, 600, 420, 'ee', breath=0.6, scale=1.4, a=0.02) * 0.4)


def cry_warden():
    return S.voice(1.0, 128, 56, 'ah', breath=0.2, rasp=0.7, scale=0.75, a=0.06)


# ---------------------------------------------------------------- the reel and the two stings
def reel():
    """Something big knocked off its feet: a low body thud, a crunch of ground, a rumble that settles."""
    body = fade(kick(72, 36, 0.5, drop=0.06, decay=0.16, drive=2.5), 0.15)
    crunch = bpf(noise(0.12), 300, 1600) * env(N(0.12), 0.001, 0.03) * 0.6
    return mix(body, fade(sub(48, 30, 0.6, 0.25), 0.2) * 0.8, crunch, tail(0.7, 500, 0.3, delay=0.04) * 0.35)


def won():
    """A quick swipe up into a bright rising run (A5, C#6, E6): got it."""
    swipe = fade(bpf(noise(0.12), 1800, 7000) * env(N(0.12), 0.06, 0.05), 0.04) * 0.5
    run = [at(S.chime(f, 0.5, 0.18 if i < 2 else 0.35), 0.11 + 0.065 * i) for i, f in enumerate((880, 1109, 1319))]
    return hpf(mix(swipe, *run), 200)


def lost():
    """A low falling pair (E4 down to C4) over a dull thump: taken from you."""
    pair = [at(S.chime(f, 0.8, 0.45, ((1.0, 1.0), (2.0, 0.25))), 0.16 * i) for i, f in enumerate((330, 262))]
    thump = mix(kick(110, 60, 0.2, decay=0.06) * 0.35, fade(sub(65, 55, 0.7, 0.3), 0.2) * 0.3)
    return lpf(mix(thump, *pair), 2400)


def build():
    for kind, fn in sorted((k[4:], v) for k, v in globals().items() if k.startswith('cry_')):
        S.save_cat('steal_cry_' + kind, hpf(fn(), 40), 'grunt')
    S.save_cat('steal_reel', reel(), 'heavy_impact')
    S.save_cat('steal_won', won(), 'cast')
    S.save_cat('steal_lost', lost(), 'cast')


if __name__ == '__main__':
    build()
