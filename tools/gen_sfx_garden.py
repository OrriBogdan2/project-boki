"""Garden minigame sounds (GARDEN.md 5, docs/AUDIO.md): the Dash race and the Stump Shove. Run from tools/.

Soft and outdoorsy, quiet enough for a garden: wood, breath, small bells and Boki chirps, no hard hits.
  garden_start    a wooden clap-clap and a rising two-note call (Ready... go)   garden_lap     a light pat and tick
  garden_cheer    a good cheer press: a bright pluck and a chirp                garden_miss    a dull wooden thunk
  garden_finish   a tape-snap swish and a bell                                  garden_crowd   six Boki chirps cheering
  garden_strain   a loop: two Boki pushing, breath and a wood groan             garden_creak   the stump leaning
  garden_thud     the stump going over                                          garden_win     a short happy sting
  garden_sulk     a small huff
  garden_hop      the Waystone lighting for a hop: a rising shimmer swelling for 0.5 s, then a soft close
  garden_wake     a zone waking: three slow rising bells and a held shimmer (once, when a zone opens)
  garden_arrive_<zone>  the chime on landing in a zone, tuned to its bed: bramblebank birds, glasswater drops,
                  cinderstep embers, hushwood a muted minor bell, ridge wind and a high fifth
  garden_locked   a locked zone picked on the Waystone: a soft wooden thud and a lock click
Boki voices reuse gen_sfx_boki's chirp. The new names are lazy-loaded; call sites are in
scripts/home/base_race.gd and base_shove.gd.
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
def start(i):
    clap = mix(wood_tick(400), at(wood_tick(400), 0.16))
    call = at(mix(pluck(523, 0.22, 0.12), 0.4 * S.sweep(523, 560, 0.22) * env(N(0.22), 0.02, 0.1)), 0.42)
    go = at(mix(pluck(784, 0.4, 0.2), 0.3 * pluck(1568, 0.4, 0.1), 0.35 * chirp(1000, 0.14, i)), 0.62)
    return B.soft(B.room(mix(clap, call, go), 0.4), 5000)


def lap(i):
    pat = mix(wood_tick(330 * j(i, 0.05), 0.06), 0.7 * lpf(noise(0.12), 1800) * env(N(0.12), 0.03, 0.04))
    return B.soft(mix(pat, at(pluck(880 * j(i, 0.03), 0.16, 0.06), 0.03) * 0.6), 4500)


def cheer(i):
    return B.soft(B.room(mix(pluck(988 * j(i, 0.03), 0.3, 0.12), at(pluck(1319 * j(i, 0.03), 0.3, 0.14), 0.07),
                             at(0.5 * chirp(1100, 0.1, i), 0.04)), 0.3), 5500)


def miss(i):
    return B.soft(mix(wood_tick(190 * j(i, 0.06), 0.12), 0.5 * S.sweep(300, 190, 0.14) * env(N(0.14), 0.005, 0.06)), 2600)


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
def win(i):
    notes = [(523, 0.0), (659, 0.1), (784, 0.2), (1047, 0.32)]
    parts = [at(pluck(f, 0.45 if k == 3 else 0.25, 0.28 if k == 3 else 0.12), t0) for k, (f, t0) in enumerate(notes)]
    return B.soft(B.room(mix(*parts, at(0.4 * chirp(1250, 0.14, i), 0.34)), 0.4), 5200)


def sulk(i):
    huff = bpf(noise(0.28), 500, 2200) * S.shape(0.28, 0.04, 0.0, 0.22)
    sigh = B.vowel(380 * j(i, 0.05), 250, 0.3, 'uh', 1.3, breath=0.3)
    return B.soft(mix(huff, 0.6 * sigh), 3600)


# ---------------------------------------------------------------- zones
def hop(i):
    """0.5 s, the length of the Waystone's light-up (hop_fade_s): a shimmer rising and swelling, ending as the screen goes."""
    d = 0.5; n = N(d)
    rise = S.sweep(330, 990, d) * S.shape(d, 0.35, 0.0, 0.15)
    shimmer = hpf(noise(d), 3000) * S.shape(d, 0.4, 0.0, 0.1) * 0.25
    bell = at(S.chime(1320 * j(i, 0.02), 0.25, 0.1), 0.3) * 0.5
    return B.soft(B.room(mix(0.6 * rise, shimmer, bell), 0.4), 5200)


def arrive_bramblebank(i):
    """Meadow birds: two bright plucks (a major third) and a chirp."""
    return B.soft(B.room(mix(pluck(784 * j(i, 0.02), 0.35, 0.14), at(pluck(988 * j(i, 0.02), 0.4, 0.16), 0.12),
                             at(0.5 * chirp(1250, 0.1, i), 0.26)), 0.35), 5500)


def arrive_glasswater(i):
    """Drops on water: three glassy bells falling in pitch, long in the room."""
    bells = [at(S.chime(f * j(i, 0.015), 0.6, 0.25), t0) * g
             for f, t0, g in ((1568, 0.0, 0.8), (1319, 0.14, 0.7), (988, 0.3, 0.8))]
    return B.soft(B.room(mix(*bells), 0.8), 6500)


def arrive_cinderstep(i):
    """Warm embers: a low wooden tone (a fifth) with a few crackles."""
    tone = mix(pluck(196 * j(i, 0.02), 0.5, 0.25), at(pluck(294 * j(i, 0.02), 0.5, 0.25), 0.1))
    pops = [at(wood_tick(f, 0.03), t0) * 0.35 for f, t0 in ((1400, 0.18), (1100, 0.27), (1700, 0.38))]
    return B.soft(B.room(mix(tone, *pops), 0.3), 3800)


def arrive_hushwood(i):
    """Dusk: a muted minor-third bell under a breath."""
    breath = bpf(noise(0.7), 400, 1400) * S.shape(0.7, 0.3, 0.0, 0.4) * 0.25
    bells = mix(S.chime(440 * j(i, 0.01), 0.9, 0.5) * 0.8, at(S.chime(523 * j(i, 0.01), 0.9, 0.5), 0.2) * 0.7)
    return B.soft(B.room(mix(bells, breath), 0.6), 3000)


def arrive_ridge(i):
    """Open wind: an airy rising whistle and a bright fifth on top."""
    d = 0.6
    wind = bpf(noise(d), 1500, 4500) * S.shape(d, 0.35, 0.0, 0.25) * 0.3
    whistle = S.sweep(880, 1320, d) * S.shape(d, 0.3, 0.0, 0.3) * 0.5
    top = at(mix(S.chime(1760 * j(i, 0.015), 0.5, 0.3), at(S.chime(2637, 0.5, 0.3), 0.1)), 0.25)
    return B.soft(B.room(mix(wind, whistle, top), 0.5), 6500)


def locked(i):
    """A knock on a shut door: a soft wooden thud, then a small metal click."""
    thud = mix(S.sweep(160, 90, 0.16) * env(N(0.16), 0.004, 0.07), 0.4 * lpf(noise(0.08), 900) * env(N(0.08), 0.002, 0.03))
    click = at(mix(S.chime(2400 * j(i, 0.03), 0.06, 0.02), 0.3 * hpf(noise(0.02), 3500) * env(N(0.02), 0.0005, 0.01)), 0.14)
    return B.soft(mix(thud, click), 4200)


def wake(i):
    notes = [(392, 0.0), (523, 0.28), (784, 0.56)]
    bells = [at(S.chime(f, 1.2 if k == 2 else 0.7, 0.4), t0) for k, (f, t0) in enumerate(notes)]
    glow = at(0.3 * S.sweep(784, 1175, 1.0) * S.shape(1.0, 0.5, 0.1, 0.4), 0.56)
    return B.soft(B.room(mix(*bells, glow), 0.6), 5500)


def main():
    S.takes_cat('garden_start', start, 0, 'boki')
    S.takes_cat('garden_lap', lap, 2, 'ui')
    S.takes_cat('garden_cheer', cheer, 2, 'ui')
    S.takes_cat('garden_miss', miss, 2, 'ui')
    S.takes_cat('garden_finish', finish, 1, 'boki')
    S.takes_cat('garden_crowd', crowd, 2, 'boki')
    S.save_loop('garden_strain', strain(), 'loop')
    S.takes_cat('garden_creak', creak, 2, 'step')
    S.takes_cat('garden_thud', thud, 1, 'impact')
    S.takes_cat('garden_win', win, 0, 'boki')
    S.takes_cat('garden_sulk', sulk, 2, 'boki')
    S.takes_cat('garden_hop', hop, 1, 'boki')
    S.takes_cat('garden_wake', wake, 0, 'boki')
    for zone, fn in (('bramblebank', arrive_bramblebank), ('glasswater', arrive_glasswater),
                     ('cinderstep', arrive_cinderstep), ('hushwood', arrive_hushwood), ('ridge', arrive_ridge)):
        S.takes_cat('garden_arrive_' + zone, fn, 1, 'boki')
    S.takes_cat('garden_locked', locked, 1, 'step')


if __name__ == '__main__':
    main()
