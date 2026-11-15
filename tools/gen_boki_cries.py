"""Synthesizes one cry per Boki into audio/cries/<file_id>.wav (mono, 22.05 kHz, 16-bit) plus the manifest
audio/cries/cries.json (id -> file, line, stage, recipe).

    python3 tools/gen_boki_cries.py [file_id ...]      (then: godot --headless --import)

Every evolution line has one voice, drawn from a random stream seeded by the LINE id (tools/boki_cries_roster.tsv
says who is in which line and at which stage): a source (a vowel-shaped throat, a whistle, a glassy or a buzzy
tone), a modulation (trill, purr, vibrato or none), a 2-4 note motif with its signature interval, and a tint
from the Boki's own type (fire crackle, water bubbles, electric buzz...). The stage then shapes it: the first
stage is higher, shorter, squeakier and sings the motif quickly with no extra layers. The middle is fuller. The final is
lower, longer and richer (a growl in the throat, a low octave, a held last note). Branch forms keep the voice
but bend the last note and carry their own type's tint. The one-line cry briefs add a small flavour layer.

Same house style as tools/gen_sfx.py: soft and warm, band-limited noise, raised-cosine fades so nothing clicks,
levelled to the "boki" category of content/rules/sfx_levels.json. Needs numpy and scipy. Fully synthesized.
"""
import csv, json, os, sys, zlib
import numpy as np
from scipy.signal import butter, sosfilt, lfilter

SR = 22050
HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, '..', 'audio', 'cries')
ROSTER = os.path.join(HERE, 'boki_cries_roster.tsv')     # tab-separated so Godot does not import it as a translation
LEVELS = json.load(open(os.path.join(HERE, '..', 'content', 'rules', 'sfx_levels.json')))
RMS_DB = LEVELS['cats']['boki']
PEAK_DB = LEVELS['peak_db']
rng = np.random.default_rng(0)      # re-seeded per Boki, so a file never changes unless its recipe does


# ------------------------------------------------------------------ primitives (gen_sfx.py house style)
def N(d): return int(SR * d)
def noise(n): return rng.standard_normal(n) * 0.35


def _sos(kind, hz):
    if kind == 'band':
        lo, hi = hz
        return butter(2, [max(lo, 20) / (SR / 2), min(hi, SR * 0.45) / (SR / 2)], 'band', output='sos')
    return butter(2, min(max(hz, 20), SR * 0.45) / (SR / 2), kind, output='sos')


def lpf(x, hz): return sosfilt(_sos('low', hz), x)
def hpf(x, hz): return sosfilt(_sos('high', hz), x)
def bpf(x, lo, hi): return sosfilt(_sos('band', (lo, hi)), x)


def fade(n, a=0.01, r=0.05):
    """Raised-cosine fade in over a seconds and out over the last r seconds."""
    t = np.arange(n) / SR
    dur = n / SR
    up = 0.5 - 0.5 * np.cos(np.pi * np.clip(t / max(a, 1e-4), 0, 1))
    dn = 0.5 - 0.5 * np.cos(np.pi * np.clip((dur - t) / max(r, 1e-4), 0, 1))
    return up * dn


def env(n, a=0.006, d=0.12):
    """Raised-cosine fade-in over a seconds, then an exponential fall (time constant d)."""
    t = np.arange(n) / SR
    att = np.where(t < a, 0.5 - 0.5 * np.cos(np.pi * np.clip(t / max(a, 1e-4), 0, 1)), 1.0)
    return att * np.exp(-np.maximum(0.0, t - a) / max(d, 1e-4))


def mix(*xs):
    n = max(len(x) for x in xs)
    o = np.zeros(n)
    for x in xs:
        o[:len(x)] += x
    return o


def level(x):
    """HPF (no DC), click-free fades, RMS to the boki category, a soft knee under the peak ceiling."""
    x = hpf(np.asarray(x, dtype=float), 35)
    x *= fade(len(x), 0.003, 0.025)
    pk = np.max(np.abs(x)) or 1.0
    act = np.abs(x) > pk * 0.02
    x = x * (10 ** (RMS_DB / 20) / (np.sqrt(np.mean(x[act] ** 2)) or 1.0))
    c = 10 ** (PEAK_DB / 20)
    k = c * 0.6
    a = np.abs(x)
    return np.where(a > k, np.sign(x) * (k + (c - k) * np.tanh((a - k) / (c - k))), x)


# ------------------------------------------------------------------ the voice: pitch path and sources
def pitch_path(f_base, notes, durs, porta, scoop):
    """Per-sample Hz singing the motif: each note (semitones from f_base) held for its duration, a glide of
    porta seconds between notes, and a scoop up into every note (a small throat starts a little low)."""
    segs = []
    for semi, d in zip(notes, durs):
        t = np.arange(N(d)) / SR
        segs.append(np.log(f_base * 2 ** (semi / 12.0)) - scoop * np.exp(-t / 0.05))
    lf = np.concatenate(segs)
    k = np.exp(-1.0 / (porta * SR))
    return np.exp(lfilter([1 - k], [1, -k], lf - lf[0]) + lf[0])


def note_env(durs, a=0.014, dip=0.5):
    """Articulation: each note fades in, inner notes dip (not stop) into the next, the last one rounds off."""
    segs = []
    for i, d in enumerate(durs):
        n = N(d)
        last = i == len(durs) - 1
        e = fade(n, a, d * 0.4 if last else 0.03)
        if not last:
            e = dip + (1 - dip) * e
        segs.append(e)
    return np.concatenate(segs)


VOWELS = {   # formant centre (Hz), bandwidth (share), gain
    'ah': ((780, 0.28, 1.0), (1250, 0.22, 0.5), (2500, 0.2, 0.2)),
    'eh': ((560, 0.28, 1.0), (1800, 0.2, 0.45), (2600, 0.2, 0.2)),
    'oh': ((480, 0.3, 1.0), (850, 0.25, 0.5), (2400, 0.2, 0.12)),
    'uh': ((600, 0.3, 1.0), (1000, 0.22, 0.45), (2400, 0.2, 0.15)),
    'ee': ((330, 0.3, 1.0), (2200, 0.18, 0.4), (3000, 0.18, 0.2)),
    'ow': ((520, 0.3, 1.0), (1100, 0.22, 0.3), (1900, 0.2, 0.25)),
}


def _phase(f, jitter):
    n = len(f)
    f = f * (1.0 + jitter * lpf(rng.standard_normal(n), 30) * 8)
    return np.cumsum(f) / SR


def vocal(f, vowel, scale, growl=0.0, bright=0.2, jitter=0.012, growl_hz=27.0, shift=(1.0, 1.0)):
    """A throat: a rounded saw through vowel formants (scale < 1 is a bigger body), with a clean fundamental
    for sweetness and, for big stages, a slow rough amplitude flutter (the growl)."""
    n = len(f)
    ph = _phase(f, jitter)
    src = lpf((ph % 1.0) * 2 - 1, 2400)
    if growl:
        t = np.arange(n) / SR
        src *= 1 - growl + growl * (0.5 + 0.5 * np.sin(2 * np.pi * growl_hz * t + 3 * lpf(rng.standard_normal(n), 40)))
    out = np.zeros(n)
    for i, (fc, bw, g) in enumerate(VOWELS[vowel]):
        fc *= scale * (shift[i] if i < 2 else 1.0)
        out += g * bpf(src, fc / (1 + bw), fc * (1 + bw))
    return out * 2.2 + bright * np.sin(2 * np.pi * ph)


def whistle(f, breath=0.1):
    """An airy pipe: a sine with a quiet octave and a little breath noise around it."""
    ph = 2 * np.pi * _phase(f, 0.004)
    air = bpf(noise(len(f)), 1500, 5000) * breath
    return np.sin(ph) + 0.12 * np.sin(2 * ph) + air


def glassy(f):
    """A crystal tone: the fundamental with two inharmonic partials that ring a little."""
    ph = 2 * np.pi * _phase(f, 0.002)
    return np.sin(ph) + 0.3 * np.sin(ph * 2.76) + 0.12 * np.sin(ph * 5.4)


def buzzy(f, rate):
    """An insect or electric throat: a thin tone chopped at rate Hz (a wingbeat or a hum)."""
    n = len(f)
    t = np.arange(n) / SR
    ph = 2 * np.pi * _phase(f, 0.01)
    chop = 0.45 + 0.55 * (0.5 + 0.5 * np.sin(2 * np.pi * rate * t))
    return (np.sin(ph) + 0.35 * np.sin(2 * ph) + 0.15 * np.sin(3 * ph)) * chop


def squeaky(f):
    """A tiny clean voice: sine plus a bright 2nd and 3rd harmonic (the first stage's extra layer)."""
    ph = 2 * np.pi * _phase(f, 0.008)
    return np.sin(ph) + 0.35 * np.sin(2 * ph) + 0.12 * np.sin(3 * ph)


SOURCES = {'vocal': 1.0, 'whistle': 0.9, 'glassy': 0.8, 'buzzy': 0.9}     # gain of each source


# ------------------------------------------------------------------ tints (the Boki's own type) and flavours
def crackle(d, per_s=60):
    n = N(d)
    out = np.zeros(n)
    for _ in range(int(per_s * d)):
        g = N(rng.uniform(0.004, 0.012))
        s0 = rng.integers(0, max(1, n - g))
        out[s0:s0 + g] += bpf(rng.standard_normal(g), 600, 3000) * np.hanning(g) * rng.uniform(0.3, 1.0)
    return out * 0.8


def bubbles(d, lo=300, hi=900, per_s=14):
    n = N(d)
    out = np.zeros(n)
    for _ in range(max(2, int(per_s * d))):
        bd = rng.uniform(0.04, 0.09)
        g = N(bd)
        t = np.arange(g) / SR
        f0 = rng.uniform(lo, hi)
        ph = 2 * np.pi * np.cumsum(f0 * (1 + 1.4 * t / bd)) / SR
        s0 = rng.integers(0, max(1, n - g))
        out[s0:s0 + g] += np.sin(ph) * env(g, 0.004, bd * 0.3) * rng.uniform(0.4, 1.0)
    return out


def buzz_noise(d, rate=110):
    n = N(d)
    t = np.arange(n) / SR
    chop = 0.5 + 0.5 * np.sign(np.sin(2 * np.pi * rate * t))
    return bpf(noise(n), 900, 4200) * lpf(chop, 1500) * fade(n, 0.03, d * 0.4) * 0.9


def bell(f, d):
    n = N(d)
    t = np.arange(n) / SR
    x = np.zeros(n)
    for k, g in ((1.0, 1.0), (2.76, 0.4), (5.4, 0.18)):
        x += g * np.sin(2 * np.pi * f * k * t) * np.exp(-t / (0.35 / k ** 0.5))
    return x * fade(n, 0.004, d * 0.3)


def clicks(d, count=5, lo=1200, hi=4500):
    n = N(d)
    out = np.zeros(n)
    for _ in range(count):
        g = N(rng.uniform(0.006, 0.014))
        s0 = rng.integers(0, max(1, n - g))
        out[s0:s0 + g] += bpf(rng.standard_normal(g), lo, hi) * env(g, 0.001, 0.003) * rng.uniform(0.5, 1.0)
    return out * 1.6


def air(d, f0=900, f1=2600):
    n = N(d)
    u = np.arange(n) / max(1, n - 1)
    f = f0 * (f1 / f0) ** u
    x = noise(n)
    out = np.zeros(n)
    for c in (0.15, 0.5, 0.85):      # three band passes along the sweep approximate a moving centre
        fc = f0 * (f1 / f0) ** c
        out += bpf(x, fc * 0.8, fc * 1.25) * np.exp(-((u - c) / 0.25) ** 2)
    return out * fade(n, 0.03, d * 0.4) * 1.2


def puff(d):
    n = N(d)
    return lpf(noise(n), 900) * fade(n, d * 0.25, d * 0.5) * 1.3


def growl_layer(f, d):
    return vocal(f * 0.5, 'oh', 0.8, growl=0.6, bright=0.0) * fade(len(f), 0.04, d * 0.35) * 0.5


def rumble(f, d):
    ph = 2 * np.pi * np.cumsum(f * 0.5) / SR
    return (np.sin(ph) + 0.3 * np.sin(2 * ph)) * fade(len(f), 0.03, d * 0.4)


def shimmer(f_base, d):
    n = N(d)
    t = np.arange(n) / SR
    out = np.zeros(n)
    for k, g in ((2.0, 1.0), (3.0, 0.5), (4.5, 0.3)):
        out += g * np.sin(2 * np.pi * f_base * k * t * (1 + 0.012 * np.sin(2 * np.pi * 4.5 * t + k)))
    return out * fade(n, d * 0.3, d * 0.4) * 0.35


def rustle(d):
    n = N(d)
    return bpf(noise(n), 2000, 7000) * lpf(np.abs(rng.standard_normal(n)), 25) * fade(n, 0.02, d * 0.4) * 1.6


def chatter(f, d, rate=18):
    """A short tremolo tail on the pitch path: a chitter or a rattle of the throat."""
    n = len(f)
    t = np.arange(n) / SR
    ph = 2 * np.pi * np.cumsum(f) / SR
    return np.sin(ph) * (0.5 + 0.5 * np.sin(2 * np.pi * rate * t)) * fade(n, 0.02, d * 0.4)


# what each type adds, as a share of the voice (tint is quieter than the throat so the line still leads)
TINTS = {
    'Fire': ('crackle', 0.35), 'Water': ('bubbles', 0.4), 'Electric': ('buzz', 0.3), 'Crystal': ('bell', 0.4),
    'Fairy': ('shimmer', 0.5), 'Bug': ('buzz', 0.25), 'Sound': ('echo', 0.5), 'Rock': ('clicks', 0.35),
    'Steel': ('clicks_hi', 0.3), 'Dark': ('growl', 0.6), 'Ice': ('bell_hi', 0.3), 'Spore': ('puff', 0.6),
    'Flying': ('air', 0.3), 'Dragon': ('rumble', 0.5), 'Psychic': ('shimmer', 0.4), 'Poison': ('bubbles_lo', 0.4),
    'Grass': ('rustle', 0.3), 'Normal': ('chatter', 0.3),
}
# words in the one-line cry briefs that ask for a texture (a small extra layer on top of the line's voice)
FLAVOURS = [
    (('growl', 'snarl', 'roar', 'bellow'), 'growl'), (('purr', 'rumble', 'thrum', 'boom', 'thud'), 'rumble'),
    (('click', 'tick', 'clack', 'snap', 'clink', 'rattle', 'knock', 'clatter'), 'clicks'),
    (('bell', 'chime', 'ring', 'ting', 'glass', 'crystal', 'tinkle'), 'bell'),
    (('bubble', 'gurgle', 'glug', 'burble', 'splash', 'drip', 'gloop', 'plop'), 'bubbles'),
    (('whistle', 'pipe', 'flute', 'toot', 'wind', 'breath', 'wheeze', 'hiss', 'puff', 'sigh'), 'air'),
    (('buzz', 'hum', 'drone', 'zap', 'crackle', 'sizzle', 'fizz', 'spark'), 'buzz'),
    (('rustle', 'leaf', 'leaves', 'flutter', 'rasp'), 'rustle'), (('chitter', 'chatter', 'trill', 'rattle'), 'chatter'),
]


def tint(kind, f, f_base, d):
    """One texture layer by name (TINTS / FLAVOURS)."""
    if kind == 'crackle': return crackle(d)
    if kind == 'bubbles': return bubbles(d, 300, 900)
    if kind == 'bubbles_lo': return bubbles(d, 140, 420, 10)
    if kind == 'buzz': return buzz_noise(d, rng.uniform(70, 150))
    if kind == 'bell': return bell(f_base * 2, d)
    if kind == 'bell_hi': return bell(f_base * 4, d)
    if kind == 'shimmer': return shimmer(f_base, d)
    if kind == 'clicks': return clicks(d, 4 + int(d * 4), 900, 3500)
    if kind == 'clicks_hi': return clicks(d, 4 + int(d * 4), 2500, 7000)
    if kind == 'growl': return growl_layer(f, d)
    if kind == 'rumble': return rumble(f, d)
    if kind == 'puff': return puff(d)
    if kind == 'air': return air(d, f_base * 2, f_base * 5)
    if kind == 'rustle': return rustle(d)
    if kind == 'chatter': return chatter(f, d)
    return np.zeros(N(d))      # 'echo' is applied after the mix (see render)


def echo(x, delay=0.11, gain=0.35):
    out = np.concatenate([x, np.zeros(N(delay) * 2)])
    out[N(delay):N(delay) + len(x)] += x * gain
    out[2 * N(delay):2 * N(delay) + len(x)] += x * gain * 0.45
    return out


# ------------------------------------------------------------------ line recipes and stage shaping
STEPS = [2, 3, 4, 5, 7, 9, 12]       # semitones a motif may move per note, up or down
RHYTHMS = [[0.35, 0.3, 0.35], [0.25, 0.25, 0.5], [0.45, 0.2, 0.35], [0.3, 0.4, 0.3], [0.2, 0.3, 0.5]]
# how a type leans the line's throat and modulation (weights; the line's rng still picks)
TYPE_SOURCE = {'Crystal': 'glassy', 'Ice': 'glassy', 'Fairy': 'glassy', 'Flying': 'whistle', 'Sound': 'whistle',
               'Bug': 'buzzy', 'Electric': 'buzzy'}
TYPE_PITCH = {'Bug': 1.25, 'Fairy': 1.2, 'Electric': 1.1, 'Flying': 1.1, 'Ice': 1.05, 'Rock': 0.8, 'Steel': 0.85,
              'Dragon': 0.72, 'Dark': 0.78, 'Water': 0.95, 'Spore': 0.9, 'Psychic': 0.9, 'Poison': 0.9}
# the stage transforms: pitch x line base, cry length (s), formant scale (smaller is a bigger body),
# motif notes (9: all), scoop into notes, the bright squeak layer, the growl, the low octave
STAGES = {
    'first': dict(pitch=1.45, dur=(0.4, 0.6), scale=1.4, notes=9, scoop=0.1, bright=0.35, growl=0.0, low=0.0),
    'mid': dict(pitch=1.0, dur=(0.65, 0.9), scale=1.05, notes=9, scoop=0.05, bright=0.3, growl=0.15, low=0.1),
    'final': dict(pitch=0.72, dur=(0.9, 1.2), scale=0.78, notes=9, scoop=0.02, bright=0.1, growl=0.3, low=0.2),
}
LINE_TEXTURES = ['clicks', 'bell', 'air', 'chatter', 'rustle', 'bubbles', 'buzz', 'shimmer', 'crackle', 'clicks_hi',
                 'puff']
FLUTTER = {'none': 0.2, 'trill': 0.45, 'purr': 0.35, 'vib': 0.2}      # depth of the line's amplitude flutter
# a branch form bends the motif's last note by this many semitones
BRANCH_BEND = {'a': 0, 'b': -3, 'c': 4, 'd': -5, 'e': 7, 'f': 2, 'g': -7, 'h': 5, 'i': -2}


def line_recipe(line, types, taken):
    """The family voice, drawn from a stream seeded by the line id only, leaned by the root's type. No two
    lines share a motif (taken): a clash draws again from the same stream."""
    r = np.random.default_rng(zlib.crc32(line.encode()))
    while True:
        rec = _draw(r, types)
        key = tuple(rec['motif'])
        if key not in taken:
            taken.add(key)
            return rec


def _draw(r, types):
    first = types[0] if types else 'Normal'
    f_base = r.uniform(340, 620) * TYPE_PITCH.get(first, 1.0)
    source = TYPE_SOURCE.get(first, 'vocal')
    if r.random() >= 0.7:
        source = r.choice(['vocal', 'vocal', 'whistle', 'glassy', 'buzzy'])
    mod = r.choice(['none', 'trill', 'trill', 'purr', 'vib', 'vib'])
    motif = [0]
    for _ in range(int(r.choice([2, 2, 3]))):
        motif.append(int(np.clip(motif[-1] + r.choice(STEPS) * r.choice([-1, 1]), -12, 12)))
    rhythm = list(RHYTHMS[r.integers(len(RHYTHMS))])
    if len(motif) == 4:
        rhythm = [0.25, 0.2, 0.2, 0.35]
    flutter = {'none': r.uniform(14, 34), 'trill': r.uniform(11, 24), 'purr': r.uniform(24, 40),
               'vib': r.uniform(14, 34)}[mod]
    return dict(f_base=round(float(f_base), 1), source=source, vowel=str(r.choice(list(VOWELS))), mod=mod, motif=motif,
                rhythm=rhythm, porta=round(float(r.uniform(0.02, 0.07)), 3), flutter_hz=round(float(flutter), 1),
                buzz_hz=round(float(r.uniform(60, 140)), 1), vib_hz=round(float(r.uniform(4.2, 7.0)), 2),
                shift=(round(float(r.uniform(0.86, 1.16)), 3), round(float(r.uniform(0.86, 1.16)), 3)),
                texture=str(r.choice(LINE_TEXTURES)))


def stage_key(row):
    s, n = int(row['stage']), int(row['stages'])
    if n == 1:
        return 'final' if row['band'].startswith('Legendary') else 'mid'
    if s == 1:
        return 'first'
    return 'final' if s == n else 'mid'


def flavour_of(cry):
    words = cry.lower()
    return [kind for keys, kind in FLAVOURS if any(k in words for k in keys)][:2]


def _throat(f, rec, S, bright):
    """The line's vowel throat at this stage's body size and growl."""
    return vocal(f, rec['vowel'], S['scale'], S['growl'], bright, growl_hz=rec['flutter_hz'], shift=rec['shift'])


def types_of(row):
    return [x.strip() for x in row['types'].replace('/', ',').split(',') if x.strip()]


def render(row, rec):
    """One cry: the line's voice shaped by the stage, tinted by the Boki's type and its brief."""
    global rng
    rng = np.random.default_rng(zlib.crc32(row['file_id'].encode()))
    key = stage_key(row)
    S = STAGES[key]
    notes = rec['motif'][:S['notes']]
    bend = BRANCH_BEND.get(row['branch'], 0)
    if bend:
        notes = notes[:-1] + [notes[-1] + bend]
    durs = np.array(rec['rhythm'][:len(notes)], dtype=float)
    if key == 'final':
        durs[-1] *= 1.25                                   # the held last note
    types = types_of(row)
    room = 0.8 if 'Sound' in types else 1.0                 # Sound types get an echo tail, so a shorter call
    durs = durs / durs.sum() * rng.uniform(*S['dur']) * room
    f_base = rec['f_base'] * S['pitch'] * rng.uniform(0.96, 1.04)
    f = pitch_path(f_base, notes, durs, rec['porta'], S['scoop'])
    n = len(f)
    t = np.arange(n) / SR
    if rec['mod'] == 'vib':
        f = f * (1 + 0.035 * np.sin(2 * np.pi * rec['vib_hz'] * t))
    d = n / SR
    if rec['source'] == 'vocal':
        core = _throat(f, rec, S, 0.3)
    elif rec['source'] == 'whistle':
        core = whistle(f) + _throat(f, rec, S, 0.0) * S['growl'] * 0.8
    elif rec['source'] == 'glassy':
        core = glassy(f) + _throat(f, rec, S, 0.0) * (0.2 + S['growl'] * 0.6)
    else:
        core = buzzy(f, rec['buzz_hz']) + _throat(f, rec, S, 0.0) * (0.15 + S['growl'] * 0.6)
    core = core * SOURCES[rec['source']]
    depth = FLUTTER[rec['mod']] + S['growl'] * 0.4                  # the family flutter, rougher on big stages
    core *= 1 - depth + depth * (0.5 + 0.5 * np.sin(2 * np.pi * rec['flutter_hz'] * t))
    core += S['bright'] * squeaky(f * 2) * 0.5
    core *= note_env(durs)
    layers = [core, tint(rec['texture'], f, f_base, d) * 0.25]
    if rec['mod'] == 'purr' or S['low'] > 0.2:
        layers.append(rumble(f, d) * note_env(durs) * max(S['low'], 0.3 if rec['mod'] == 'purr' else 0.0))
    used = [rec['texture']]
    for i, ty in enumerate(types[:2]):
        kind, amt = TINTS.get(ty, ('chatter', 0.2))
        layers.append(tint(kind, f, f_base, d) * amt * (1.0 if i == 0 else 0.5))
        used.append(kind)
    for kind in flavour_of(row['cry']):
        if kind not in used:
            layers.append(tint(kind, f, f_base, d) * 0.18)
            used.append(kind)
    x = mix(*layers)
    if 'echo' in used:
        x = echo(x)
    return x, dict(stage=key, notes=notes, tint=used)


def save(name, x):
    import wave
    x = level(x)
    with wave.open(os.path.join(OUT, name + '.wav'), 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((np.clip(x, -1, 1) * 32767).astype(np.int16).tobytes())


def main(only):
    os.makedirs(OUT, exist_ok=True)
    rows = list(csv.DictReader(open(ROSTER), delimiter='\t'))
    recipes = {}
    taken = set()
    for r in rows:
        if r['line'] not in recipes:
            recipes[r['line']] = line_recipe(r['line'], types_of(r), taken)
    manifest = {'cries': {}, 'lines': {}}
    for r in rows:
        rec = recipes[r['line']]
        fid = r['file_id']
        manifest['lines'].setdefault(r['line'], []).append(fid)
        if only and fid not in only:
            continue
        x, info = render(r, rec)
        save(fid.lower(), x)
        entry = dict(file='audio/cries/%s.wav' % fid.lower(), display_name=r['display_name'], line=r['line'],
                     stage=int(r['stage']), stages=int(r['stages']), branch=r['branch'], types=r['types'])
        voice = '%s %s %s %s' % (rec['source'], rec['vowel'], rec['mod'], rec['texture'])
        entry.update(voice=voice, motif=rec['motif'],
                     notes=info['notes'], shape=info['stage'], tint=info['tint'], seconds=round(len(x) / SR, 2))
        manifest['cries'][fid] = entry
    if not only:
        json.dump(manifest, open(os.path.join(OUT, 'cries.json'), 'w'), indent=1)
    print('wrote %d cries, %d lines' % (len(manifest['cries']), len(manifest['lines'])))


if __name__ == '__main__':
    main(set(sys.argv[1:]))
