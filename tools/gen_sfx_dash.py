"""Every Hunter's air dash, and the shared soft "no charge" tick (docs/AUDIO.md, content/sfx/dash.json).

    python3 tools/gen_sfx_dash.py      (then: godot --headless --import)

Each <arch>_dash_air is that Hunter's own ground dash (audio/<arch>_dash*.wav, made by its group script)
re-voiced for a dash with no floor under it: the foot scrape and ground thump filtered out, wind rushing
past, and the one thing that Hunter's motion trails: Kael's flame, Grimble's tumbling junk, Neve's ice
flecks off the blade, Sparkle's crackle. Gil has no ground dash to re-voice (he swims under the floor), so
gil_dash_air is made whole here in his water: a wet flick of the tail, bubbles shed off the scales, drops falling
behind. dash_empty is the tick of a Shift press with no charge to spend.
Run it after the group scripts (it reads their dash files). Original synthesis, no samples.
"""
import os, sys, wave
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import sfx_lib as S
from sfx_lib import SR, N, noise, hpf, lpf, env, mix, click, shape

S.reseed(4417)
AUDIO = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'audio')

# arch -> (high-pass Hz that drops the floor contact, pitch ratio, wind band Hz, wind level, trail)
AIR = {
    'gunslinger': (400, 1.06, (3000, 9000), 0.5, None),
    'archer': (300, 1.05, (2500, 8000), 0.5, None),
    'juggernaut': (120, 0.97, (500, 3500), 0.6, 'flame'),
    'bulwark': (150, 0.95, (400, 2500), 0.6, None),
    'ostra': (300, 1.08, (2500, 8000), 0.4, None),
    'ashwick': (250, 1.0, (800, 5000), 0.6, None),
    'dredge': (200, 0.98, (600, 3500), 0.4, 'junk'),
    'rimewright': (900, 1.1, (4000, 11000), 0.4, 'ice'),
    'tender': (300, 1.08, (2500, 8000), 0.4, None),
    'thief': (350, 1.06, (3000, 9000), 0.5, None),
    'mage': (500, 1.04, (3000, 10000), 0.4, 'zap'),
    'dolm': (200, 0.97, (500, 3000), 0.6, None),
}


def ground_takes(arch):
    """The ground dash's takes, in order (name.wav, name_1.wav, ...)."""
    out = []
    for suffix in [''] + ['_%d' % i for i in range(1, 5)]:
        path = os.path.join(AUDIO, '%s_dash%s.wav' % (arch, suffix))
        if os.path.exists(path):
            with wave.open(path) as w:
                out.append(np.frombuffer(w.readframes(w.getnframes()), dtype=np.int16) / 32768.0)
    return out


def trail(kind, n):
    """What the Hunter's own motion adds in the air, n samples long."""
    d = n / SR
    if kind == 'flame':      # a hot roar with crackle
        return lpf(noise(d), 1800) * shape(d, 0.03, d * 0.4, d * 0.5) * 1.4 + S.rattle(d, 60, 800, 2500, 0.5, 0.2) * 0.25
    if kind == 'junk':       # scrap tumbling loose
        return S.rattle(d, 70, 900, 4500, 0.6, 0.25) * 0.5
    if kind == 'ice':        # flecks off the blade
        return S.rattle(d, 30, 5000, 9000, 0.5, 0.15) * 0.35
    if kind == 'zap':        # lightning snaps
        return mix(*[S.at(click(0.003, 2500, 9000) * 1.2, float(S.rng.uniform(0.0, d * 0.8))) for _ in range(7)])[:n]
    return np.zeros(n)


def air(arch, ground, i):
    hp, pitch, band, wind, kind = AIR[arch]
    x = ground[i % len(ground)]
    x = np.interp(np.arange(int(len(x) / pitch)) * pitch, np.arange(len(x)), x)
    x = hpf(x, hp)
    d = len(x) / SR
    rush = S.hiss(d, band[0], band[1], 0.06, 0.2) * shape(d, 0.06, d * 0.3, d * 0.6) * wind
    t = trail(kind, len(x))
    return mix(x, rush, np.pad(t, (0, max(0, len(x) - len(t))))[:len(x)])


def gil_air(i):
    """Gil's air dash: a wet rush, a burst of bubbles off the scales and a spray of drops behind (take i)."""
    d = 0.3 + 0.03 * i
    rush = S.hiss(d, 500, 2600, 0.04, 0.2) * shape(d, 0.04, d * 0.25, d * 0.6)
    body = lpf(noise(d), 700) * shape(d, 0.02, d * 0.2, d * 0.5) * 0.6
    shed = S.bubbles(d * 0.5, 50, 500, 1400, 0.03) * 0.4
    drops = S.bubbles(d * 0.6, 20, 1600, 3200, 0.02) * 0.25
    return mix(rush, body, shed, S.at(drops, d * 0.35))[:N(d)]


def empty():
    """A soft tick: the slot has nothing to give."""
    return mix(click(0.004, 1500, 4500) * 0.8, lpf(noise(0.04), 600) * env(N(0.04), 0.001, 0.012) * 0.5)


def build():
    for arch in AIR:
        ground = ground_takes(arch)
        S.takes_cat('%s_dash_air' % arch, lambda i, a=arch, g=ground: air(a, g, i), 2, 'dash')
    S.save_cat('dash_empty', empty(), 'ui')
    S.takes_cat('gil_dash_air', gil_air, 2, 'dash')


if __name__ == '__main__':
    build()
    print('gen_sfx_dash: done')
