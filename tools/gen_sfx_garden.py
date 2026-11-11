"""Garden minigame sounds (GARDEN.md 5, docs/AUDIO.md): the Dash, Stump Shove, Seek and Spark Volley. Run from tools/.

Soft and outdoorsy, quiet enough for a garden: wood, breath, small bells and Boki chirps, no hard hits.
  garden_count     a countdown tick (twice)             garden_go           the third beat, bright
  garden_cheer_perfect / _good / _miss   the crowd of Boki answering your timing press: a spray of chirps and
                   plucks, a few cheers, a small "aww" and a dull thunk
  garden_lap       a light pat and tick                 garden_finish       a tape-snap swish and a bell
  garden_crowd     six Boki chirps for the first home   garden_strain       a loop: two Boki pushing
  garden_creak     the stump leaning                    garden_thud         the stump going over
  garden_win_small / _medium / _large    the winner's fanfare, higher and quicker for a small Boki, fuller for a large
  garden_sulk_small / _medium / _large   the loser's huff, a squeaky puff down to a deep sigh
  garden_sniff     a loop: quick little sniffs for Seek garden_bat   the seed hit over the Volley log
  garden_chime_stat / _level / _evolve   a Boki's own chime at home: a stat rose, it levelled up, a change is
                   coming; two, three and four notes over its chirp, pitched by size at play time (home_chimes.gd)
Boki voices reuse gen_sfx_boki's chirp. Call sites: scripts/home/garden_sfx.gd and home_chimes.gd.
"""
import numpy as np
import sfx_lib as S
from sfx_lib import N, env, mix, at, lpf, hpf, bpf, noise
import gen_sfx_boki as B

S.reseed(6021)


def j(i, s=0.04):
    return B.j(i, s)


def pluck(f, d=0.3, decay=0.09):
    """A felt-mallet tine (as the UI palette): the note and a quiet 4th partial."""
    t = S.T(d); n = N(d)
    return (np.sin(2 * np.pi * f * t) + 0.2 * np.sin(2 * np.pi * f * 4 * t + 0.7) * env(n, 0.002, decay * 0.3)) \
        * env(n, 0.003, decay)


def wood_tick(f=420, d=0.07):
    """Two sticks or a pat on a trunk: a short damped knock."""
    n = N(d)
    return mix(np.sin(2 * np.pi * f * S.T(d)) * env(n, 0.001, d * 0.25), 0.4 * bpf(noise(d), 900, 2600) * env(n, 0.001, d * 0.15))


def chirp(f, d=0.1, i=0):
    return mix(B.squeak(f * j(i), d, 0.14), 0.4 * B.vowel(f * 0.5, f * 0.55, d, 'ee', 1.4))


# ---------------------------------------------------------------- race
def count(i):
    """One beat of the countdown: a soft stick tick and a low pluck."""
    return B.soft(B.room(mix(wood_tick(520, 0.06), 0.8 * pluck(392, 0.2, 0.08)), 0.3), 4500)


def go(i):
    """The third beat: a rising pluck pair and a chirp."""
    return B.soft(B.room(mix(pluck(784, 0.4, 0.2), at(pluck(1175, 0.4, 0.2), 0.05), 0.3 * pluck(1568, 0.4, 0.1),
                             at(0.5 * chirp(1000, 0.14, i), 0.04)), 0.4), 5200)


def cheer_perfect(i):
    """Every Boki in the crowd cheers: a rising run of chirps over two bright plucks."""
    fs = [880, 990, 1100, 1240, 1320, 1480]
    parts = [at(chirp(f * j(i + k, 0.05), 0.11, i + k), 0.045 * k + S.rng.uniform(0, 0.02)) * S.rng.uniform(0.6, 0.9)
             for k, f in enumerate(fs)]
    bells = mix(pluck(1319 * j(i, 0.02), 0.35, 0.14), at(pluck(1760, 0.35, 0.16), 0.08))
    return B.soft(B.room(mix(*parts, 0.7 * bells), 0.5), 5600)


def cheer_good(i):
    """A few Boki cheer: four chirps and a single pluck."""
    fs = [900, 1020, 960, 1100]
    parts = [at(chirp(f * j(i + k, 0.05), 0.1, i + k), 0.06 * k + S.rng.uniform(0, 0.02)) * S.rng.uniform(0.5, 0.8)
             for k, f in enumerate(fs)]
    return B.soft(B.room(mix(*parts, 0.6 * pluck(988 * j(i, 0.03), 0.3, 0.12)), 0.4), 5200)


def cheer_miss(i):
    """A small crowd "aww": three chirps sliding down and a dull wooden thunk."""
    parts = [at(mix(B.squeak(f * j(i + k, 0.05), 0.2, -0.3, 0.02, 0.1), 0.3 * S.sweep(f, f * 0.7, 0.2)), 0.07 * k) * 0.6
             for k, f in enumerate([760, 680, 620])]
    return B.soft(B.room(mix(*parts, 0.7 * wood_tick(190 * j(i, 0.06), 0.12)), 0.4), 3600)


def lap(i):
    pat = mix(wood_tick(330 * j(i, 0.05), 0.06), 0.7 * lpf(noise(0.12), 1800) * env(N(0.12), 0.03, 0.04))
    return B.soft(mix(pat, at(pluck(880 * j(i, 0.03), 0.16, 0.06), 0.03) * 0.6), 4500)


def finish(i):
    swish = hpf(noise(0.25), 2500) * S.shape(0.25, 0.1, 0.0, 0.15) * 0.6
    return B.soft(B.room(mix(swish, at(S.chime(1175, 0.7, 0.3), 0.12)), 0.4), 6000)


def crowd(i):
    notes = [(0.00, 900), (0.07, 1100), (0.13, 820), (0.2, 1020), (0.27, 960), (0.36, 1180)]
    parts = [at(chirp(f * j(i + k, 0.08), 0.1 + 0.03 * (k % 3), i + k), t0 + S.rng.uniform(0, 0.03)) * S.rng.uniform(0.5, 0.9)
             for k, (t0, f) in enumerate(notes)]
    return B.soft(B.room(mix(*parts), 0.6), 5500)


# ---------------------------------------------------------------- shove
def strain():
    """Two small bodies pushing: breath through the nose, a wood groan under it. About 1.6 s, looped."""
    d = 1.6; n = N(d); u = np.arange(n) / n
    breath = bpf(noise(d), 400, 1800) * (0.5 + 0.5 * np.sin(2 * np.pi * 2 * u - 1.2)) * 0.5
    groan = S.creak(d, 70, 62, 0.5, 700) * 0.7
    grunt = mix(at(B.vowel(260, 300, 0.4, 'uh', 1.25), 0.2), at(B.vowel(300, 270, 0.4, 'uh', 1.3), 0.95))
    return lpf(mix(breath, groan, 0.3 * S.pad(grunt, d)[:n]), 2400)


def creak(i):
    d = 0.7
    return B.soft(mix(S.creak(d, 110 * j(i, 0.08), 70, 0.7, 1200), 0.3 * wood_tick(150, 0.1)), 2400)


def thud(i):
    body = S.sweep(120, 50, 0.4) * env(N(0.4), 0.003, 0.15)
    leaves = lpf(noise(0.3), 1400) * env(N(0.3), 0.02, 0.1) * 0.35
    return lpf(mix(body, at(wood_tick(160, 0.1), 0.0) * 0.5, leaves), 1500)


# ---------------------------------------------------------------- results
SIZES = {'small': 1.45, 'medium': 1.0, 'large': 0.7}     # pitch factor: a small Boki squeaks, a large one booms softly


def win(f):
    """The winner's fanfare: four rising notes and a chirp, higher and quicker for small, slower and rounder for large."""
    def make(i):
        notes = [(523, 0.0), (659, 0.1), (784, 0.2), (1047, 0.32)]
        parts = [at(pluck(n * f, 0.45 if k == 3 else 0.25, 0.28 if k == 3 else 0.12), t0 / f ** 0.5)
                 for k, (n, t0) in enumerate(notes)]
        return B.soft(B.room(mix(*parts, at(0.4 * chirp(1250 * f, 0.14 / f ** 0.5, i), 0.34 / f ** 0.5)), 0.4), 5200)
    return make


def sulk(f):
    """The loser's huff: breath, then a sigh; a small Boki puffs and squeaks, a large one sighs low and long."""
    def make(i):
        d = 0.28 / f ** 0.5
        huff = bpf(noise(d), 500 * f, 2200 * f) * S.shape(d, 0.04, 0.0, d * 0.8)
        sigh = B.vowel(380 * f * j(i, 0.05), 250 * f, d * 1.1, 'uh', 1.3, breath=0.3)
        return B.soft(mix(huff, 0.6 * sigh), 3600)
    return make


# ---------------------------------------------------------------- seek and volley
def sniff():
    """Seek: three quick little sniffs and a pause, about 1.2 s, looped."""
    d = 1.2; n = N(d); out = np.zeros(n)
    for t0, g in [(0.0, 1.0), (0.14, 0.8), (0.28, 0.9)]:
        sn = bpf(noise(0.1), 1800, 5200) * S.shape(0.1, 0.02, 0.0, 0.07)
        out += g * np.concatenate([np.zeros(N(t0)), sn, np.zeros(n)])[:n]
    return lpf(out, 4200)


def bat(i):
    """Volley: a soft seed knock off a Boki's paw, a dry pok and a faint spark ping."""
    return B.soft(mix(wood_tick(520 * j(i, 0.06), 0.08), 0.5 * pluck(1568 * j(i, 0.03), 0.18, 0.05)), 5000)


# ---------------------------------------------------------------- home chimes
def chime_notes(notes, gap, tail, voice_f):
    """Soft plucks rising by gap seconds, the last one rung out, and the Boki's chirp on the top note."""
    parts = [at(pluck(f, 0.3 if k < len(notes) - 1 else tail, 0.1 if k < len(notes) - 1 else tail * 0.5), k * gap)
             for k, f in enumerate(notes)]
    return mix(*parts, at(0.45 * chirp(voice_f, 0.12), (len(notes) - 1) * gap + 0.02))


def chime_stat(i):
    """A stat rose: two quick notes up a fifth and a small chirp."""
    return B.soft(B.room(chime_notes([784 * j(i, 0.02), 1175], 0.07, 0.35, 1150 * j(i)), 0.35), 5400)


def chime_level(i):
    """A garden level: three notes up a major chord, a brighter chirp, a little longer ring."""
    return B.soft(B.room(chime_notes([659, 831, 988 * j(i, 0.01)], 0.08, 0.5, 1250 * j(i)), 0.45), 5600)


def chime_evolve(i):
    """A change is coming: four notes and a bell on top, with a rising 'oh' under them."""
    ooh = B.vowel(420 * j(i, 0.03), 620, 0.45, 'oh', 1.3, breath=0.15) * 0.35
    bell = at(0.5 * S.chime(1568, 0.8, 0.3), 0.3)
    return B.soft(B.room(mix(chime_notes([523, 659, 784, 1047], 0.09, 0.6, 1300 * j(i)), ooh, bell), 0.55), 6000)


def main():
    S.takes_cat('garden_count', count, 1, 'boki')
    S.takes_cat('garden_go', go, 1, 'boki')
    S.takes_cat('garden_cheer_perfect', cheer_perfect, 2, 'boki')
    S.takes_cat('garden_cheer_good', cheer_good, 2, 'boki')
    S.takes_cat('garden_cheer_miss', cheer_miss, 2, 'boki')
    S.takes_cat('garden_lap', lap, 2, 'ui')
    S.takes_cat('garden_finish', finish, 1, 'boki')
    S.takes_cat('garden_crowd', crowd, 2, 'boki')
    S.save_loop('garden_strain', strain(), 'loop')
    S.takes_cat('garden_creak', creak, 2, 'step')
    S.takes_cat('garden_thud', thud, 1, 'impact')
    for size, f in SIZES.items():
        S.takes_cat('garden_win_' + size, win(f), 0, 'boki')
        S.takes_cat('garden_sulk_' + size, sulk(f), 2, 'boki')
    S.save_loop('garden_sniff', sniff(), 'loop')
    S.takes_cat('garden_bat', bat, 2, 'ui')
    S.takes_cat('garden_chime_stat', chime_stat, 2, 'boki')
    S.takes_cat('garden_chime_level', chime_level, 2, 'boki')
    S.takes_cat('garden_chime_evolve', chime_evolve, 1, 'boki')


if __name__ == '__main__':
    main()
