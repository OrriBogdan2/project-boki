"""Garden minigame sounds (GARDEN.md 5, GARDEN_MODERN.md 4.2, docs/AUDIO.md): the Dash, Stump Shove, Seek, Spark
Volley, Tumble, Echo Steps, the Show Ring and the Relay Cup. Run from tools/.

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
  tumble_clash_rush / _brace / _dodge   the exchange landing, by the move that decided it: a body bump, a padded
                   block, a whoosh past and a skid      tumble_push   paws scuffing back across the ring
  tumble_ringout   a roll over the ring's edge, a bounce and the crowd's "ooh"
  echo_hit         a tiny glass sparkle over the stone's note   echo_miss   a muffled off-key stone and a low buzz
  echo_streak      a quick rising sparkle run on every few hits in a row (the stone notes stay generated in game)
  show_reveal      a wood-block roll, three judge cards flipped and a chime   show_crowd   paw-pat applause and cheers
  relay_handoff    a paw slap and a baton tick, a happy chirp   relay_fumble   the baton dropped: clatter and an "eep"
  relay_finish     the tape swish and three rising bells, one for each leg
  garden_chime_stat / _level / _evolve   a Boki's own chime at home: a stat rose, it levelled up, a change is
                   coming; two, three and four notes over its chirp, pitched by size at play time (home_chimes.gd)
  garden_hop      the Waystone lighting for a hop: a rising shimmer swelling for 0.5 s, then a soft close
  garden_wake     a zone waking: three slow rising bells and a held shimmer (once, when a zone opens)
  garden_depart   the hop itself: a short airy whoosh as the screen goes
  garden_arrive_<zone>  the chime on landing in a zone, tuned to its bed: bramblebank birds, glasswater drops,
                  cinderstep embers, hushwood a muted minor bell, ridge wind and a high fifth
  garden_locked   a locked zone picked on the Waystone: a soft wooden thud and a lock click
Boki voices reuse gen_sfx_boki's chirp. Call sites: scripts/home/garden_sfx.gd, home_chimes.gd and hub_waystone.gd.
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


# ---------------------------------------------------------------- tumble
def scuff(d=0.16, lo=300, hi=1600):
    """A paw dragged on packed dirt: low grainy noise that fades out."""
    return bpf(noise(d), lo, hi) * S.shape(d, 0.01, 0.0, d * 0.8)


def clash_rush(i):
    """Rush decided it: two small bodies bump, a soft low thump, fur and a grunt."""
    body = S.sweep(150 * j(i, 0.06), 60, 0.3) * env(N(0.3), 0.002, 0.09)
    fur = lpf(noise(0.12), 2200) * env(N(0.12), 0.002, 0.03) * 0.5
    grunt = 0.35 * B.vowel(240 * j(i, 0.05), 200, 0.18, 'uh', 1.25)
    return B.soft(mix(body, fur, at(grunt, 0.02)), 2600)


def clash_brace(i):
    """Brace decided it: a charge stopped on a guard, a padded thock and a held breath."""
    thock = mix(wood_tick(230 * j(i, 0.05), 0.14), 0.6 * S.sweep(110, 80, 0.2) * env(N(0.2), 0.002, 0.06))
    breath = bpf(noise(0.25), 500, 1800) * S.shape(0.25, 0.03, 0.05, 0.15) * 0.3
    return B.soft(mix(thock, at(breath, 0.03)), 2400)


def clash_dodge(i):
    """Dodge decided it: a quick whoosh past, a light skid and a pleased squeak."""
    d = 0.3
    whoosh = bpf(noise(d), 700, 3200) * S.shape(d, 0.12, 0.0, 0.16) * 0.8
    squeak = 0.35 * B.squeak(1150 * j(i, 0.05), 0.09, 0.2)
    return B.soft(mix(whoosh, at(scuff(0.14, 900, 2800), 0.16), at(squeak, 0.2)), 4200)


def push(i):
    """The loser pushed back along the ring: two or three scuffs, each softer than the last."""
    parts = [at(scuff(0.15, 280 * j(i + k, 0.08), 1500), 0.13 * k) * (0.9 - 0.25 * k) for k in range(3)]
    return B.soft(B.room(mix(*parts), 0.25), 2200)


def ringout(i):
    """Out of the ring: a short tumble of thumps, one bounce, and the crowd's rising "ooh"."""
    rolls = [at(S.sweep(130 - 15 * k, 70, 0.16) * env(N(0.16), 0.002, 0.05), 0.09 * k) * (1.0 - 0.18 * k)
             for k in range(4)]
    bounce = at(0.6 * S.sweep(160, 90, 0.2) * env(N(0.2), 0.002, 0.06), 0.5)
    ooh = [at(mix(B.squeak(f * j(i + k, 0.05), 0.35, 0.05, 0.03, 0.1), 0.3 * S.sweep(f, f * 1.25, 0.35)), 0.3 + 0.05 * k)
           * 0.35 for k, f in enumerate([620, 700, 780])]
    return B.soft(B.room(mix(*rolls, bounce, *ooh), 0.4), 3200)


# ---------------------------------------------------------------- echo steps
def glint(f, d=0.14):
    """A tiny glassy ping: two inharmonic partials, very short."""
    t = S.T(d); n = N(d)
    return (np.sin(2 * np.pi * f * t) + 0.5 * np.sin(2 * np.pi * f * 2.76 * t)) * env(n, 0.001, d * 0.25)


def echo_hit(i):
    """A step on the beat: a sparkle above the stone's note (the notes are G-B-D-G, so this sits at G7 and D8)."""
    return B.soft(mix(glint(3136 * j(i, 0.01)), at(0.4 * glint(4699 * j(i, 0.01), 0.1), 0.02)), 9000)


def echo_miss(i):
    """A wrong or missed step: a muffled, detuned stone and a short low buzz under it."""
    d = 0.35; t = S.T(d); n = N(d)
    stone = (np.sin(2 * np.pi * 208 * j(i, 0.03) * t) + 0.6 * np.sin(2 * np.pi * 221 * t)) * env(n, 0.003, 0.08)
    buzz = lpf(np.sign(np.sin(2 * np.pi * 98 * t)), 700) * env(n, 0.005, 0.06) * 0.25
    return B.soft(mix(stone, buzz, 0.3 * wood_tick(170, 0.1)), 1800)


def echo_streak(i):
    """A streak: a quick rising run of four glints in G major and a soft bell under the last."""
    fs = [1568, 1976, 2349, 3136]
    parts = [at(glint(f * j(i, 0.01), 0.18), 0.06 * k) * (0.6 + 0.1 * k) for k, f in enumerate(fs)]
    return B.soft(B.room(mix(*parts, at(0.4 * S.chime(1568, 0.5, 0.25), 0.18)), 0.4), 9000)


# ---------------------------------------------------------------- show ring
def card_flip(d=0.07):
    """A judge's card turned over: a dry paper snap."""
    return hpf(noise(d), 2400) * env(N(d), 0.001, 0.012)


def reveal(i):
    """The judges show their cards: a wood-block roll that swells, three card flips and a chime."""
    roll = mix(*[at(wood_tick(480 + 40 * (k % 2), 0.05) * (0.25 + 0.05 * k), 0.045 * k) for k in range(14)])
    flips = mix(*[at(0.8 * card_flip(), 0.7 + 0.12 * k) for k in range(3)])
    return B.soft(B.room(mix(roll, flips, at(0.7 * S.chime(1319, 0.8, 0.3), 1.08)), 0.4), 7000)


def crowd_cheer(i):
    """The garden crowd answers the cards: a patter of little paw pats and a spray of chirps, about 1.6 s."""
    d = 1.6; n = N(d); pats = np.zeros(n)
    for _ in range(70):
        t0 = S.rng.uniform(0, d - 0.05)
        g = 0.4 + 0.6 * np.sin(np.pi * t0 / d)
        pat = bpf(noise(0.03), 900, 3600) * env(N(0.03), 0.001, 0.006) * g * S.rng.uniform(0.4, 1.0)
        k = N(t0); pats[k:k + len(pat)] += pat[:n - k]
    chirps = [at(chirp(f * j(i + k, 0.06), 0.1, i + k), S.rng.uniform(0.05, 1.2)) * S.rng.uniform(0.3, 0.6)
              for k, f in enumerate([900, 1060, 980, 1180, 1240, 1020, 1120])]
    return B.soft(B.room(mix(pats, *chirps), 0.5), 6000)


# ---------------------------------------------------------------- relay
def handoff(i):
    """A clean hand-off: a paw slap on paw, a light baton tick and a happy chirp."""
    slap = bpf(noise(0.06), 1200, 4500) * env(N(0.06), 0.001, 0.01)
    return B.soft(mix(slap, at(0.6 * wood_tick(700 * j(i, 0.04), 0.06), 0.015),
                      at(0.45 * chirp(1200 * j(i, 0.04), 0.1, i), 0.05)), 5500)


def fumble(i):
    """A fumbled hand-off: the baton hits the ground and bounces, quicker each time, and an "eep" slides down."""
    bounces = [at(wood_tick(620 * j(i + k, 0.08), 0.07) * 0.9 ** k, sum(0.16 * 0.7 ** m for m in range(k)))
               for k in range(5)]
    eep = 0.4 * mix(B.squeak(1100 * j(i, 0.05), 0.22, -0.35, 0.02, 0.1), 0.3 * S.sweep(1100, 760, 0.22))
    return B.soft(B.room(mix(*bounces, eep), 0.3), 4800)


def relay_finish(i):
    """A team home: the tape swish and three rising bells, one for each leg."""
    swish = hpf(noise(0.25), 2500) * S.shape(0.25, 0.1, 0.0, 0.15) * 0.5
    bells = [at(S.chime(f, 0.6, 0.25) * 0.6, 0.1 + 0.11 * k) for k, f in enumerate([988, 1319, 1568])]
    return B.soft(B.room(mix(swish, *bells), 0.4), 6500)
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


# ---------------------------------------------------------------- zones
def hop(i):
    """0.5 s, the length of the Waystone's light-up (hop_fade_s): a shimmer rising and swelling, ending as the screen goes."""
    d = 0.5; n = N(d)
    rise = S.sweep(330, 990, d) * S.shape(d, 0.35, 0.0, 0.15)
    shimmer = hpf(noise(d), 3000) * S.shape(d, 0.4, 0.0, 0.1) * 0.25
    bell = at(S.chime(1320 * j(i, 0.02), 0.25, 0.1), 0.3) * 0.5
    return B.soft(B.room(mix(0.6 * rise, shimmer, bell), 0.4), 5200)


def depart(i):
    """0.35 s as the screen goes: an airy whoosh, the low band swelling first and the high one trailing off."""
    d = 0.35
    low = bpf(noise(d), 350 * j(i), 1400) * S.shape(d, 0.12, 0.0, 0.2)
    high = bpf(noise(d), 1800 * j(i), 5200) * S.shape(d, 0.2, 0.0, 0.15) * 0.5
    return B.soft(B.room(mix(low, high, 0.15 * S.sweep(600, 300, d) * S.shape(d, 0.1, 0.0, 0.25)), 0.3), 4800)


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
    thud = mix(S.sweep(160, 90, 0.16) * env(N(0.16), 0.004, 0.07),
               0.4 * lpf(noise(0.08), 900) * env(N(0.08), 0.002, 0.03))
    tick = 0.3 * hpf(noise(0.02), 3500) * env(N(0.02), 0.0005, 0.01)
    click = at(mix(S.chime(2400 * j(i, 0.03), 0.06, 0.02), tick), 0.14)
    return B.soft(mix(thud, click), 4200)


def wake(i):
    notes = [(392, 0.0), (523, 0.28), (784, 0.56)]
    bells = [at(S.chime(f, 1.2 if k == 2 else 0.7, 0.4), t0) for k, (f, t0) in enumerate(notes)]
    glow = at(0.3 * S.sweep(784, 1175, 1.0) * S.shape(1.0, 0.5, 0.1, 0.4), 0.56)
    return B.soft(B.room(mix(*bells, glow), 0.6), 5500)


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
    for move, fn in [('rush', clash_rush), ('brace', clash_brace), ('dodge', clash_dodge)]:
        S.takes_cat('tumble_clash_' + move, fn, 2, 'impact' if move != 'dodge' else 'boki')
    S.takes_cat('tumble_push', push, 2, 'step')
    S.takes_cat('tumble_ringout', ringout, 1, 'impact')
    S.takes_cat('echo_hit', echo_hit, 2, 'ui')
    S.takes_cat('echo_miss', echo_miss, 2, 'ui')
    S.takes_cat('echo_streak', echo_streak, 1, 'ui')
    S.takes_cat('show_reveal', reveal, 0, 'ui')
    S.takes_cat('show_crowd', crowd_cheer, 1, 'boki')
    S.takes_cat('relay_handoff', handoff, 2, 'boki')
    S.takes_cat('relay_fumble', fumble, 2, 'boki')
    S.takes_cat('relay_finish', relay_finish, 1, 'boki')
    S.takes_cat('garden_chime_stat', chime_stat, 2, 'boki')
    S.takes_cat('garden_chime_level', chime_level, 2, 'boki')
    S.takes_cat('garden_chime_evolve', chime_evolve, 1, 'boki')
    S.takes_cat('garden_hop', hop, 1, 'boki')
    S.takes_cat('garden_wake', wake, 0, 'boki')
    S.takes_cat('garden_depart', depart, 1, 'boki')
    for zone, fn in (('bramblebank', arrive_bramblebank), ('glasswater', arrive_glasswater),
                     ('cinderstep', arrive_cinderstep), ('hushwood', arrive_hushwood), ('ridge', arrive_ridge)):
        S.takes_cat('garden_arrive_' + zone, fn, 1, 'boki')
    S.takes_cat('garden_locked', locked, 1, 'step')


if __name__ == '__main__':
    main()
