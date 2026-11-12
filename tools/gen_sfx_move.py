"""Movement sounds by weight class (docs/AUDIO.md): jump, land and wall kick in three weights, and a heavier
glider open for the heavy class. Run from tools/: python3 gen_sfx_move.py   (then: godot --headless --import)

The class is the `weight` of content/archetypes/<id>.json (light, medium, heavy); HeroSfx.weighted picks
<kind>_<weight>. Light = brighter, shorter, a small pat; medium = the old shared sound's character;
heavy = a low push-off, a sub thump and a rumble tail. Every file is levelled to the same category, so
the call site's volume (and, for a landing, the fall speed) carries the loudness. Original synthesis.
"""
import numpy as np
import sfx_lib as S
from sfx_lib import N, noise, lpf, bpf, env, mix, at, kick

S.reseed(5521)

# per weight: pitch of the body, band of the air/scuff noise, and how much low thump is under it
WEIGHT = {
    'light':  {'body': 1.30, 'lo': 700, 'hi': 3600, 'thump': 0.25},
    'medium': {'body': 1.00, 'lo': 380, 'hi': 2000, 'thump': 0.55},
    'heavy':  {'body': 0.70, 'lo': 160, 'hi': 900,  'thump': 1.10},
}
TAKES = 2          # name.wav plus name_1, name_2 for each, so repeats differ


def drift(i):
    """Take i drifts a little in pitch."""
    return 1.0 + (0.0 if i == 0 else S.rng.uniform(-0.05, 0.05))


def jump(w):
    p = WEIGHT[w]

    def make(i):
        d = 0.12 + 0.08 * (1.3 - p['body'] + 0.3)
        f = drift(i) * p['body']
        air = bpf(noise(d), p['lo'], p['hi']) * env(N(d), 0.012, d * 0.45) * 0.9
        push = S.sweep(150 * f, 250 * f, d) * env(N(d), 0.006, 0.04) * 0.5
        base = kick(95 * f, 48 * f, d + 0.05, 0.04, 0.07, 1.6) * p['thump'] * 0.6
        return S.lpf(mix(air, push, base), 2600 * p['body'] ** 0.5)
    return make


def land(w):
    p = WEIGHT[w]

    def make(i):
        d = 0.12 + 0.2 * p['thump'] / 1.1
        f = drift(i) * p['body']
        pat = bpf(noise(d), p['lo'] * 0.5, p['hi'] * 0.7) * env(N(d), 0.004, d * 0.28) * 1.6
        body = kick(150 * f, 55 * f, d, 0.035, d * 0.3, 1.8) * (0.4 + p['thump'])
        rumble = at(lpf(noise(d * 1.6), 260) * env(N(d * 1.6), 0.02, d * 0.5), 0.02) * p['thump'] * 0.7
        return lpf(mix(pat, body, rumble), 1700 * p['body'] ** 0.5)
    return make


def kick_push(w):
    """The wall hop's push: a scuff of the foot on stone, then the shove off it."""
    p = WEIGHT[w]

    def make(i):
        d = 0.07 + 0.07 * p['thump'] / 1.1
        f = drift(i) * p['body']
        scuff = bpf(noise(d), p['lo'], p['hi']) * env(N(d), 0.002, d * 0.35) * 1.3
        tick = kick(260 * f, 110 * f, d, 0.02, 0.03, 1.4) * 0.5
        shove = kick(110 * f, 48 * f, d + 0.06, 0.04, 0.06, 1.8) * p['thump'] * 0.7
        return lpf(mix(scuff, tick, shove), 3000)
    return make


def glide_open_heavy(i):
    """The glider cracking open under a heavy Hunter: cloth taking the air, a low thump and a short rumble."""
    d = 0.5
    f = drift(i)
    cloth = bpf(noise(d), 140, 700) * S.shape(d, 0.03, 0.08, 0.38) * 1.4
    flap = at(bpf(noise(0.12), 300, 1400) * env(N(0.12), 0.003, 0.035), 0.05) * 0.6
    thump = kick(120 * f, 45 * f, d, 0.05, 0.12, 1.8) * 0.9
    return lpf(mix(cloth, flap, thump), 1600)


def main():
    for w in WEIGHT:
        S.takes_cat('jump_' + w, jump(w), TAKES, 'step')
        S.takes_cat('land_' + w, land(w), TAKES, 'step')
        S.takes_cat('kick_' + w, kick_push(w), TAKES, 'step')
    S.takes_cat('glide_open_heavy', glide_open_heavy, TAKES, 'step')


if __name__ == '__main__':
    main()
