"""The combat layer of the sound palette: guns, hits, crits, armor, knocks, kills, explosions, blades.

Run by tools/gen_sfx.py at the end (it overwrites the soft placeholder versions written above it),
or on its own:  python3 tools/sfx_combat.py  (then: godot --headless --import)

These are built for weight rather than politeness, in the way a top-down arena shooter sounds:
every shot and hit is layered from
  1. a transient   a 1-4 ms click of bright noise, so the ear catches the exact moment,
  2. a body        a pitch-dropping sine "kick", soft-clipped so it grows harmonics and reads on
                   small speakers, plus a band of noise for the crack or the smack,
  3. a sub         a low sine under the heavy ones (shotgun, sniper, knock, explosions),
  4. a tail        low-passed noise and a few early reflections off the islands, so a shot hangs
                   in the air for a moment instead of stopping dead.
Crits add a bright metallic ting, armor adds an inharmonic clank, an armor break shatters glass.

44.1 kHz mono 16-bit. Original synthesis, no samples. Its own random stream (so running it never
changes the other sounds generate_sfx writes).
"""
import os, wave
import numpy as np
from scipy.signal import butter, sosfilt

SR = 44100
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'audio')
rng = np.random.default_rng(2611)


def N(d): return int(SR * d)
def T(d): return np.arange(N(d)) / SR
def noise(d): return rng.standard_normal(N(d))


def _f(kind, hz, x, order=2):
    if kind == 'band':
        lo, hi = hz
        sos = butter(order, [max(lo, 20) / (SR / 2), min(hi, SR * 0.45) / (SR / 2)], 'band', output='sos')
    else:
        sos = butter(order, min(max(hz, 20), SR * 0.45) / (SR / 2), kind, output='sos')
    return sosfilt(sos, x)


def lpf(x, hz): return _f('low', hz, x)
def hpf(x, hz): return _f('high', hz, x)
def bpf(x, lo, hi): return _f('band', (lo, hi), x)


def env(n, a=0.001, d=0.05):
    """A fast fade-in (a seconds, raised cosine) then an exponential fall with time constant d."""
    t = np.arange(n) / SR
    att = np.where(t < a, 0.5 - 0.5 * np.cos(np.pi * np.clip(t / max(a, 1e-5), 0, 1)), 1.0)
    return att * np.exp(-np.maximum(0.0, t - a) / max(d, 1e-5))


def mix(*xs):
    n = max(len(x) for x in xs); o = np.zeros(n)
    for x in xs: o[:len(x)] += x
    return o


def at(x, delay): return np.concatenate([np.zeros(N(delay)), x])
def sat(x, drive=2.0): return np.tanh(x * drive) / np.tanh(drive)


def kick(f0, f1, d, drop=0.03, decay=0.06, drive=2.0, a=0.0008):
    """A pitch-dropping sine body: f0 falls to f1 over about `drop` seconds, then decays."""
    n = N(d); t = np.arange(n) / SR
    f = f1 + (f0 - f1) * np.exp(-t / max(drop, 1e-4))
    ph = 2 * np.pi * np.cumsum(f) / SR
    return sat(np.sin(ph) * env(n, a, decay), drive)


def click(d=0.004, lo=2500, hi=9000, decay=0.0012):
    return bpf(noise(d + 0.004), lo, hi) * env(N(d + 0.004), 0.0002, decay)


def crack(d, lo, hi, decay, a=0.0005):
    return bpf(noise(d), lo, hi) * env(N(d), a, decay)


def sub(f0, f1, d, decay, a=0.003):
    n = N(d); t = np.arange(n) / SR
    f = f1 + (f0 - f1) * np.exp(-t / 0.05)
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * env(n, a, decay)


def tail(d, lp, decay, a=0.004, delay=0.0):
    return at(lpf(noise(d), lp) * env(N(d), a, decay), delay)


def reflections(x, taps=((0.045, 0.32, 1800), (0.083, 0.22, 1300), (0.131, 0.14, 900), (0.19, 0.08, 700))):
    """Early reflections: quieter, darker copies a few tens of ms later (an outdoor slap)."""
    out = x.copy()
    for dl, g, lp in taps:
        out = mix(out, at(lpf(x, lp) * g, dl))
    return out


def ring(freqs, d, decays, gains, a=0.0005):
    n = N(d); t = np.arange(n) / SR
    return sum(g * np.sin(2 * np.pi * f * t + rng.uniform(0, 6.28)) * env(n, a, dc) for f, dc, g in zip(freqs, decays, gains))


def grains(d, per_s, lo, hi, gmin=0.002, gmax=0.008, fall=None):
    """Many tiny bright grains (glass, debris), thinning out over d (fall: time constant)."""
    n = N(d); out = np.zeros(n)
    for _ in range(int(per_s * d)):
        tt = rng.exponential(fall) if fall else rng.uniform(0, d)
        if tt >= d: continue
        g = N(rng.uniform(gmin, gmax)); s0 = min(N(tt), max(0, n - g - 1))
        out[s0:s0 + g] += bpf(rng.standard_normal(g + 64), lo, hi)[64:] * np.hanning(g) * rng.uniform(0.3, 1.0)
    return out


# ------------------------------------------------------------------ levelling and writing
def level(x, peak_db=-1.5, rms_db=None):
    x = np.asarray(x, dtype=float)
    x = hpf(x, 30)
    fi = N(0.0004); x[:fi] *= 0.5 - 0.5 * np.cos(np.pi * np.arange(fi) / fi)
    fo = min(len(x), N(0.03)); x[-fo:] *= 0.5 + 0.5 * np.cos(np.pi * np.arange(fo) / fo)
    if rms_db is not None:
        pk = np.max(np.abs(x)) or 1.0
        act = np.abs(x) > pk * 0.02
        r = np.sqrt(np.mean(x[act] ** 2)) or 1.0
        x = x * (10 ** (rms_db / 20) / r)
    c = 10 ** (peak_db / 20)
    m = np.max(np.abs(x)) or 1.0
    if m > c:
        # a soft knee above 60% of the ceiling instead of a hard clip
        k = c * 0.6; s = np.sign(x); a = np.abs(x)
        x = np.where(a > k, s * (k + (c - k) * np.tanh((a - k) / (c - k))), x)
    return x


def save(name, x, rms_db=-17.0, peak_db=-1.0):
    x = level(x, peak_db, rms_db)
    with wave.open(os.path.join(OUT, name + '.wav'), 'wb') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((np.clip(x, -1, 1) * 32767).astype(np.int16).tobytes())


def takes(name, fn, n=3, **kw):
    save(name, fn(0), **kw)
    for i in range(1, n + 1):
        save('%s_%d' % (name, i), fn(i), **kw)


def build():
    # ============================================================== guns
    def smg(i):
        d = 0.32
        body = kick(300 + 12 * i, 120, d, 0.008, 0.022, 2.4) * 0.5
        snap = crack(d, 900, 5000 + 300 * i, 0.012) * 2.6
        mid = crack(d, 250, 900, 0.02) * 2.0
        return mix(click(0.003, 3000, 10000) * 1.6, body, snap, mid, reflections(tail(0.25, 2200, 0.05) * 0.9))
    takes('smg', smg, rms_db=-19)

    def rifle(i):
        d = 0.6
        body = kick(240 + 10 * i, 85, d, 0.012, 0.04, 2.8) * 0.6
        snap = crack(d, 800, 5500 + 200 * i, 0.016) * 2.8
        low = crack(d, 180, 800, 0.035) * 2.2
        return mix(click(0.004, 2800, 11000) * 1.8, body, snap, low, reflections(tail(0.45, 1800, 0.09) * 1.1))
    takes('rifle', rifle, rms_db=-18)

    def shotgun(i):
        d = 0.95
        body = kick(190 + 8 * i, 60, d, 0.02, 0.07, 3.2) * 0.75
        blast = crack(d, 250, 4200, 0.05) * 3.2
        return mix(click(0.005, 2200, 10000) * 2.0, body, blast, sub(70, 40, d, 0.1) * 0.4,
                   reflections(tail(0.8, 1500, 0.16) * 1.4, ((0.06, 0.35, 1400), (0.11, 0.25, 1000), (0.18, 0.15, 800), (0.27, 0.08, 600))))
    takes('shotgun', shotgun, 2, rms_db=-16)

    def sniper(i):
        d = 1.5
        crk = mix(click(0.003, 4000, 14000) * 2.5, crack(d, 1500, 9000, 0.01) * 3.0, crack(d, 300, 1500, 0.04) * 2.0)
        body = kick(220, 55, d, 0.015, 0.09, 3.0) * 0.7
        # the long roll of the report off distant islands, and a faint rising whine of the round
        roll = reflections(tail(1.3, 1400, 0.32, 0.01) * 1.4, ((0.09, 0.4, 900), (0.21, 0.3, 700), (0.36, 0.22, 500), (0.55, 0.12, 400)))
        return mix(crk, body, sub(64, 36, d, 0.16) * 0.45, roll)
    takes('sniper', sniper, 1, rms_db=-16)

    # the shotgun stays "thump" for things that borrow it (heavy bumps, the Feel damage layer)
    save('thump', mix(kick(170, 60, 0.45, 0.02, 0.07, 2.6) * 0.8, crack(0.45, 200, 1800, 0.04) * 2.4, sub(60, 40, 0.45, 0.08) * 0.35), rms_db=-19)

    def boom(i):
        d = 1.8; n = N(d)
        crk = mix(click(0.006, 1500, 9000) * 2.0, crack(d, 400, 5000, 0.03) * 3.0)
        body = kick(130 + 6 * i, 40, d, 0.04, 0.16, 3.5) * 0.7
        rumble = lpf(noise(d), 900) * env(n, 0.01, 0.4) * 1.8
        roar = bpf(noise(d), 200, 2500) * env(n, 0.005, 0.15) * 2.2
        debris = grains(d, 90, 1500, 6000, fall=0.35) * 1.0
        return mix(crk, body, rumble, roar, debris, sub(55, 30, d, 0.3) * 0.5)
    takes('boom', boom, 2, rms_db=-15)

    # ============================================================== blades
    def swish(d, f0, f1, q=3.0):
        """Air torn by a blade: noise through a band-pass whose centre sweeps f0 -> f1 (a state-variable filter)."""
        n = N(d); u = np.arange(n) / n
        f = f0 * (f1 / f0) ** u
        x = noise(d); out = np.empty(n); low = band = 0.0; damp = 1.0 / q
        for k in range(n):
            g = 2.0 * np.sin(np.pi * min(f[k], SR / 6.5) / SR)
            low += g * band
            high = x[k] - low - damp * band
            band += g * high
            out[k] = band
        win = np.sin(np.pi * np.clip(u * 1.15, 0, 1)) ** 1.5
        return out * win

    def swipe(i):
        d = 0.22 + 0.02 * i
        return mix(swish(d, 500 + 40 * i, 3500 + 200 * i) * 1.0, at(ring((2900 + 80 * i, 4100), 0.15, (0.03, 0.02), (0.12, 0.06)), 0.03))
    takes('swipe', swipe, rms_db=-19)

    def cleave(i):
        d = 0.42
        return mix(swish(d, 250 + 20 * i, 2200 + 100 * i, 2.2) * 1.0, at(kick(130, 60, 0.3, 0.02, 0.06, 2.4) * 0.3, 0.12))
    takes('cleave', cleave, 2, rms_db=-18)

    # a blade biting into something: a wet smack, a crunch and a little metal
    def slash_hit(i):
        d = 0.3
        return mix(click(0.003, 2500, 9000) * 1.4, kick(220 + 15 * i, 90, d, 0.01, 0.03, 2.8) * 0.55,
                   crack(d, 300, 2600, 0.03) * 2.6, grains(0.12, 260, 1200, 5000, fall=0.03) * 1.2,
                   ring((1850 + 60 * i, 2730 + 40 * i), 0.25, (0.05, 0.03), (0.12, 0.07)))
    takes('slash_hit', slash_hit, rms_db=-17)

    # ============================================================== hits
    # your shot landing: a short meaty thwack with a crisp tick on top, so every hit registers
    def hit(i):
        d = 0.2
        return mix(click(0.003, 3000, 10000) * 1.8, kick(280 + 20 * i, 120, d, 0.006, 0.02, 2.6) * 0.5,
                   crack(d, 250, 900, 0.02) * 2.0, crack(d, 900, 3800 + 200 * i, 0.014) * 2.4)
    takes('hit', hit, rms_db=-18)

    # a heavy hit (a slug, a charged shot): a deeper thwack with a sub punch under it
    def hit_heavy(i):
        d = 0.4
        return mix(click(0.004, 2500, 10000) * 1.8, kick(200 + 10 * i, 70, d, 0.012, 0.045, 3.0) * 0.7,
                   crack(d, 300, 2400, 0.03) * 2.8, sub(70, 42, d, 0.07) * 0.35)
    takes('hit_heavy', hit_heavy, 2, rms_db=-16)

    # a crit: the same thwack with a bright metallic ting ringing over it (unmistakable)
    def crit(i):
        d = 0.5
        base = (2093, 2637, 3136)[i % 3]
        ting = ring((base, base * 2.01, base * 2.76, base * 4.1), d, (0.16, 0.07, 0.05, 0.02), (0.5, 0.18, 0.12, 0.05))
        return mix(hit(i) * 0.8, at(ting * 1.6, 0.004), at(click(0.002, 5000, 14000) * 1.2, 0.002))
    takes('crit', crit, rms_db=-17)

    # a hit on armor: a hollow clank of plate, inharmonic and short
    def armor_hit(i):
        d = 0.3
        f = 620 + 40 * i
        clank = ring((f, f * 1.58, f * 2.31, f * 3.47), d, (0.06, 0.045, 0.03, 0.02), (0.5, 0.35, 0.25, 0.12))
        return mix(click(0.003, 2000, 8000) * 1.2, clank, crack(d, 1500, 6000, 0.012) * 1.2, kick(260, 120, d, 0.006, 0.02, 2.0) * 0.25)
    takes('armor_hit', armor_hit, 2, rms_db=-19)

    # armor broken: a hard crack, plate and glass shattering outward, and a falling tone
    def armor_break(i):
        d = 0.9; n = N(d)
        crk = mix(click(0.005, 2000, 12000) * 1.6, kick(260, 80, d, 0.01, 0.04, 3.0) * 0.6, crack(d, 500, 6000, 0.025) * 2.6)
        shards = grains(d, 420, 2500, 9500, 0.002, 0.006, fall=0.12) * 0.7
        glass = ring((2350, 3720, 5180, 6600), d, (0.22, 0.14, 0.1, 0.07), (0.25, 0.18, 0.12, 0.08))
        fall = np.sin(2 * np.pi * np.cumsum(np.geomspace(1400, 500, n)) / SR) * env(n, 0.02, 0.15) * 0.18
        return mix(crk, shards, glass, fall)
    takes('armor_break', armor_break, 1, rms_db=-15)

    # being hit yourself: a dull body blow with grit (low, so it never sounds like your own hits)
    def hurt(i):
        d = 0.32
        return mix(kick(170 + 10 * i, 70, d, 0.015, 0.05, 2.6) * 0.6, crack(d, 180, 1400, 0.04) * 2.6,
                   click(0.003, 1500, 5000) * 0.9, sub(65, 42, d, 0.07) * 0.3)
    takes('hurt', hurt, rms_db=-16)

    def kinhit(i):
        d = 0.26
        return mix(kick(240 + 15 * i, 100, d, 0.01, 0.035, 2.4) * 0.55, crack(d, 300, 2200, 0.025) * 2.4, click(0.003, 2000, 7000) * 1.0)
    takes('kinhit', kinhit, rms_db=-17)

    # ============================================================== big moments
    # someone knocked down: a heavy body slam with a cracking tail
    save('knock', mix(click(0.005, 1500, 8000) * 1.8, kick(160, 50, 1.0, 0.025, 0.12, 3.2) * 0.75, crack(1.0, 150, 2200, 0.08) * 2.8,
                      sub(58, 32, 1.0, 0.2) * 0.45, grains(1.0, 80, 800, 4000, fall=0.2) * 1.0), rms_db=-15)

    # you knocked someone: a punchy confirm on top of the slam, a low hit and two rising notes
    def note(f, d, decay):
        return ring((f, f * 2, f * 3), d, (decay, decay * 0.6, decay * 0.3), (0.6, 0.2, 0.08), 0.002)
    save('knock_confirm', mix(kick(190, 70, 0.6, 0.015, 0.06, 2.8) * 0.45, crack(0.6, 300, 2500, 0.03) * 1.5, at(note(523, 0.5, 0.12), 0.0) * 1.4, at(note(784, 0.7, 0.2), 0.07) * 1.4), rms_db=-17)

    # a kill (taken out for good): a deep drop, a crack, and a ringing three-note chord that blooms
    save('kill', mix(click(0.006, 1500, 9000) * 1.6, kick(150, 45, 1.4, 0.04, 0.16, 3.4) * 0.65, sub(55, 30, 1.4, 0.25) * 0.4,
                     crack(1.4, 250, 3000, 0.05) * 2.0,
                     at(note(392, 1.2, 0.35), 0.03) * 1.6, at(note(587, 1.2, 0.35), 0.09) * 1.4, at(note(784, 1.3, 0.45), 0.15) * 1.4,
                     tail(1.2, 1800, 0.25, 0.02) * 1.0), rms_db=-15)

    # extracted: air rushing up and a bright major chord that rises and opens out
    d = 2.2; n = N(d); u = np.arange(n) / n
    rush = bpf(noise(d), 300, 3000) * np.sin(np.pi * np.clip(u * 1.6, 0, 1)) ** 2 * 0.9
    chord = sum(at(ring((f, f * 2.0, f * 3.0), d - k * 0.09, (0.9, 0.5, 0.3), (0.55, 0.2, 0.08), 0.03), k * 0.09) * g
                for k, (f, g) in enumerate(((392, 1.0), (494, 0.9), (587, 0.85), (784, 0.9), (988, 0.6))))
    save('extract_ok', mix(rush, chord * 1.2, sub(70, 50, d, 0.4) * 0.3), rms_db=-17)

    # monsters dying: a wet crunch and debris, small and big
    def die(i, big=False):
        if big:
            d = 0.9
            return mix(click(0.005, 1500, 8000) * 1.5, kick(150 + 8 * i, 55, d, 0.025, 0.09, 3.0) * 0.7, crack(d, 200, 2000, 0.06) * 2.6,
                       grains(d, 120, 900, 5000, fall=0.15) * 1.4, sub(60, 36, d, 0.14) * 0.35)
        d = 0.4
        return mix(click(0.004, 2000, 9000) * 1.3, kick(260 + 15 * i, 110, d, 0.01, 0.035, 2.6) * 0.5, crack(d, 400, 3000, 0.03) * 2.4,
                   grains(d, 200, 1500, 6000, fall=0.06) * 1.2)
    for i in range(1, 4):
        save('die_small_%d' % i, die(i), rms_db=-18)
        save('die_big_%d' % i, die(i, True), rms_db=-16)


    # ============================================================== weapon abilities (right click) and other casts
    # One sound per way an ability is delivered (Juice.ab_cast) and one per what it does on a hit
    # (Juice.ab_hit), so any ability (a gun's right click, an archetype kit, a Boki) can use them.
    def sweep(d, f0, f1, q=4.0):
        """Noise through a band-pass whose centre glides f0 -> f1 (state-variable filter)."""
        n = N(d); u = np.arange(n) / n
        f = f0 * (f1 / f0) ** u
        x = noise(d); out = np.empty(n); low = band = 0.0; damp = 1.0 / q
        for k in range(n):
            g = 2.0 * np.sin(np.pi * min(f[k], SR / 6.5) / SR)
            low += g * band
            high = x[k] - low - damp * band
            band += g * high
            out[k] = band
        return out

    def tone_glide(f0, f1, d, harm=(1.0, 0.3, 0.12)):
        n = N(d); f = f0 * (f1 / f0) ** (np.arange(n) / n)
        ph = 2 * np.pi * np.cumsum(f) / SR
        return sum(a * np.sin(ph * (k + 1)) for k, a in enumerate(harm))

    # thrown or fired (a disc, a knife, a bolt): a sharp tearing whoosh off a hard release
    def ab_throw(i):
        d = 0.32; n = N(d)
        return mix(click(0.003, 2500, 9000) * 1.5, kick(260 + 20 * i, 110, d, 0.008, 0.025, 2.2) * 0.45,
                   sweep(d, 900 + 100 * i, 4200, 3.0) * np.sin(np.pi * np.clip(np.arange(n) / n * 1.3, 0, 1)) ** 1.5 * 2.2)
    takes('ab_throw', ab_throw, 2, rms_db=-17)

    # a charged rail going off: a split-the-air crack, an electric sweep down and a deep sub
    def ab_rail(i):
        d = 1.3; n = N(d)
        zapl = sat(tone_glide(1800, 160, 0.5, (1.0, 0.5, 0.3, 0.2)) * env(N(0.5), 0.001, 0.14), 2.5) * 0.5
        return mix(click(0.003, 3500, 14000) * 3.0, crack(d, 1500, 10000, 0.012) * 3.2, crack(d, 300, 1500, 0.05) * 2.4,
                   zapl, kick(240, 45, d, 0.012, 0.1, 3.2) * 0.8, sub(60, 34, d, 0.18) * 0.5,
                   reflections(tail(1.1, 1500, 0.26) * 1.4, ((0.08, 0.4, 1200), (0.19, 0.28, 900), (0.33, 0.18, 700))))
    takes('ab_rail', ab_rail, 1, rms_db=-15)

    # holding a charge: a whine that climbs and a crackle that thickens (about 1s)
    d = 1.1; n = N(d); u = np.arange(n) / n
    save('ab_charge', mix(sat(tone_glide(220, 880, d, (1.0, 0.4, 0.2)) * (0.2 + 0.8 * u) * env(n, 0.05, 5.0), 1.6) * 0.5,
                          grains(d, 160, 2500, 8000, 0.001, 0.003) * u * 1.2, lpf(noise(d), 300) * u * 0.4), rms_db=-21)

    # a blast at close range (a shotgun's breach, a cone): a huge chest-hit and the air shoved away
    def ab_blast(i):
        d = 1.0; n = N(d)
        return mix(click(0.005, 2000, 10000) * 2.2, kick(170 + 10 * i, 45, d, 0.022, 0.08, 3.4) * 0.8,
                   crack(d, 250, 5000, 0.05) * 3.4, sub(62, 36, d, 0.16) * 0.55,
                   sweep(0.6, 3000, 300, 1.4) * env(N(0.6), 0.003, 0.18) * 1.6,
                   reflections(tail(0.8, 1500, 0.16) * 1.2))
    takes('ab_blast', ab_blast, 1, rms_db=-15)

    # leaping into the air: a heavy push-off and the rush of air
    def ab_leap(i):
        d = 0.6; n = N(d)
        return mix(kick(150, 60, d, 0.02, 0.06, 2.6) * 0.6, crack(d, 200, 1500, 0.03) * 1.6,
                   sweep(d, 400, 2400, 2.0) * np.sin(np.pi * np.arange(n) / n) ** 1.2 * 1.8)
    takes('ab_leap', ab_leap, 1, rms_db=-18)

    # an ability landing on an area (a slam, a mine going off): the ground cracks, rubble flies
    def ab_slam(i):
        d = 1.4; n = N(d)
        return mix(click(0.006, 1500, 9000) * 2.0, kick(130 + 8 * i, 34, d, 0.04, 0.14, 3.6) * 0.85,
                   crack(d, 150, 3000, 0.07) * 3.0, sub(55, 30, d, 0.3) * 0.6,
                   grains(d, 140, 900, 6000, fall=0.25) * 1.4, lpf(noise(d), 600) * env(n, 0.01, 0.35) * 1.4)
    takes('ab_slam', ab_slam, 1, rms_db=-14)

    # a barrier going up: a hard set-down and a rising energy shimmer
    def ab_wall(i):
        d = 0.9; n = N(d); u = np.arange(n) / n
        shimmer = sum(np.sin(2 * np.pi * f * T(d) + 3 * np.sin(2 * np.pi * 6 * T(d))) for f in (440, 660, 990)) * np.sin(np.pi * np.clip(u * 1.2, 0, 1)) * 0.12
        return mix(click(0.004, 1500, 8000) * 1.6, kick(180, 55, d, 0.015, 0.06, 2.8) * 0.7, crack(d, 300, 2500, 0.03) * 2.2,
                   shimmer, sweep(d, 300, 2000, 2.5) * env(n, 0.05, 0.3) * 0.8)
    takes('ab_wall', ab_wall, 1, rms_db=-17)

    # a shot stopped by a barrier: a bright energy ping
    def ab_shield_hit(i):
        d = 0.35
        return mix(click(0.002, 3000, 10000) * 1.2, ring((1320 + 60 * i, 1980, 2970), d, (0.07, 0.05, 0.03), (0.5, 0.3, 0.15)),
                   crack(d, 1000, 5000, 0.01) * 0.8)
    takes('ab_shield_hit', ab_shield_hit, 2, rms_db=-20)

    # a blade raised to parry: a quick metallic shing
    def ab_guard(i):
        d = 0.6
        return mix(sweep(0.25, 2000, 7000, 6.0) * env(N(0.25), 0.01, 0.08) * 1.5,
                   at(ring((2637, 3951, 5274, 6900), d - 0.03, (0.25, 0.15, 0.1, 0.05), (0.4, 0.25, 0.15, 0.06)), 0.03))
    takes('ab_guard', ab_guard, 1, rms_db=-19)

    # a parry or a reflect landing: a big ringing clang with a punch under it
    def ab_parry(i):
        d = 1.0
        return mix(click(0.003, 2500, 12000) * 2.0, kick(240, 80, d, 0.01, 0.04, 2.8) * 0.6, crack(d, 1500, 7000, 0.02) * 1.8,
                   ring((1046, 1568, 2489, 3520, 4650), d, (0.4, 0.3, 0.2, 0.12, 0.08), (0.5, 0.35, 0.25, 0.15, 0.08)))
    takes('ab_parry', ab_parry, 1, rms_db=-15)

    # a trap planted: a heavy thunk into the ground and two arming beeps
    def ab_plant(i):
        d = 0.7
        beep = lambda f: ring((f, f * 2), 0.08, (0.03, 0.02), (0.5, 0.15))
        return mix(click(0.004, 1500, 7000) * 1.4, kick(200, 70, d, 0.012, 0.05, 2.6) * 0.7, crack(d, 300, 2000, 0.025) * 2.0,
                   at(beep(1760), 0.32) * 1.2, at(beep(2349), 0.46) * 1.2)
    takes('ab_plant', ab_plant, 1, rms_db=-18)

    # a tether hooking on: an electric twang that bends down
    def ab_tether(i):
        d = 0.7; n = N(d)
        tw = sat(tone_glide(620, 300, d, (1.0, 0.6, 0.4, 0.25)) * env(n, 0.002, 0.18), 2.4)
        return mix(click(0.003, 2500, 9000) * 1.4, tw * 0.6, grains(0.4, 300, 2500, 7000, fall=0.1) * 0.8,
                   kick(220, 90, d, 0.01, 0.03, 2.2) * 0.4)
    takes('ab_tether', ab_tether, 1, rms_db=-17)

    # vanishing and reappearing: air sucked in backwards, then a sharp snap
    def ab_blink(i):
        d = 0.45; n = N(d); u = np.arange(n) / n
        suck = sweep(d, 4000, 500, 2.5) * (u ** 2) * 1.8
        return mix(suck, at(mix(click(0.003, 2500, 10000) * 2.0, crack(0.2, 600, 4000, 0.015) * 1.8, kick(260, 100, 0.2, 0.008, 0.02, 2.2) * 0.4), d - 0.08))
    takes('ab_blink', ab_blink, 1, rms_db=-17)

    # a spinning blade in flight: a fast whirring buzz that rises and falls past you
    d = 0.7; n = N(d); u = np.arange(n) / n
    am = 0.5 + 0.5 * np.sin(2 * np.pi * 34 * T(d))
    save('ab_whirr', mix(sweep(d, 1200, 2600, 5.0) * am * np.sin(np.pi * u) * 1.6, tone_glide(380, 420, d, (1.0, 0.3)) * am * np.sin(np.pi * u) * 0.15), rms_db=-21)

    # what a hit DOES, by category (Juice.ab_hit): control is a hard hit then a held, dazed ring;
    # a slow is a cold crackle
    def ab_stun(i):
        d = 0.9; n = N(d)
        daze = ring((880, 1245, 1760), d, (0.4, 0.35, 0.3), (0.3, 0.22, 0.12)) * (0.7 + 0.3 * np.sin(2 * np.pi * 7 * T(d)))
        return mix(click(0.004, 2000, 10000) * 1.8, kick(200, 60, d, 0.012, 0.05, 3.0) * 0.7, crack(d, 400, 3500, 0.03) * 2.4, at(daze, 0.03))
    takes('ab_stun', ab_stun, 1, rms_db=-16)

    def ab_slow(i):
        d = 0.5
        return mix(grains(d, 500, 2500, 9000, 0.001, 0.004, fall=0.15) * 1.6, ring((2093, 3136), d, (0.12, 0.08), (0.2, 0.1)),
                   crack(d, 600, 3000, 0.02) * 1.0)
    takes('ab_slow', ab_slow, 1, rms_db=-19)

    # ============================================================== interface
    # crisp and tactile: a woody tick for a press, a faint glassy tick for a hover
    save('click', mix(click(0.002, 2500, 9000) * 0.8, ring((1180, 2410, 3560), 0.06, (0.012, 0.008, 0.005), (0.6, 0.25, 0.1)),
                      kick(420, 260, 0.06, 0.004, 0.01, 1.4) * 0.3), rms_db=-21)
    save('hover', mix(ring((2200, 3300), 0.04, (0.006, 0.004), (0.5, 0.2)), click(0.0015, 4000, 10000) * 0.3), rms_db=-27)

    # ============================================================== footsteps by surface
    # quiet, short and dry so a run reads without ever cluttering a fight; three takes of each
    def step_grass(i):
        d = 0.14
        return mix(kick(110 + 8 * i, 70, d, 0.008, 0.02, 1.5) * 0.5, crack(d, 700, 3200, 0.025) * 0.9,
                   grains(0.07, 300, 1500, 5000, fall=0.025) * 0.5)
    def step_stone(i):
        d = 0.12
        return mix(kick(150 + 10 * i, 90, d, 0.005, 0.015, 1.6) * 0.5, click(0.003, 1800, 7000) * 1.4,
                   crack(d, 1200, 5000, 0.008) * 1.0, crack(d, 300, 900, 0.015) * 0.8)
    def step_snow(i):
        d = 0.2
        return mix(kick(100 + 6 * i, 65, d, 0.01, 0.025, 1.4) * 0.45, grains(0.16, 700, 1200, 4500, 0.002, 0.005, fall=0.05) * 1.3,
                   crack(d, 400, 1500, 0.03) * 0.5)
    def step_wood(i):
        d = 0.18
        return mix(click(0.003, 1500, 6000) * 1.0, ring((190 + 12 * i, 430 + 20 * i, 760), d, (0.05, 0.035, 0.02), (0.6, 0.4, 0.15)),
                   crack(d, 300, 1500, 0.02) * 0.7)
    for nm, fn in (('step_grass', step_grass), ('step_stone', step_stone), ('step_snow', step_snow), ('step_wood', step_wood)):
        for i in range(1, 4):
            save('%s_%d' % (nm, i), fn(i), rms_db=-22)

    # ============================================================== ability impacts (AbilityFx IMPACT, appended last so
    # nothing above changes): an ability's damage landing is heavier and brighter than a bullet: a
    # crack, a deep body, and an energy zing that bends down, so a right click that connects is unmistakable
    def ab_hit(i):
        d = 0.75; n = N(d)
        zing = sat(tone_glide(1400 + 80 * i, 420, 0.35, (1.0, 0.45, 0.2)) * env(N(0.35), 0.001, 0.09), 2.2) * 0.45
        return mix(click(0.003, 2500, 12000) * 2.4, crack(d, 900, 6000, 0.02) * 2.6, kick(190 + 12 * i, 50, d, 0.012, 0.07, 3.2) * 0.85,
                   sub(70, 40, d, 0.12) * 0.4, zing, reflections(tail(0.5, 1800, 0.1) * 0.9))
    takes('ab_hit', ab_hit, 2, rms_db=-15)

    # a charge reaching full: a bright two-note ping with a shimmer
    save('ab_ready', mix(ring((1568, 2349, 3136), 0.5, (0.18, 0.14, 0.1), (0.45, 0.3, 0.2)),
                         at(ring((2093, 3136, 4186), 0.45, (0.16, 0.12, 0.08), (0.4, 0.25, 0.15)), 0.06),
                         click(0.002, 3000, 12000) * 1.0), rms_db=-19)

    # ============================================================== archetype payoffs (appended last so
    # nothing above changes): each kit's cash-in has its own signature, so you know by ear what just landed
    # Archer Deadeye: a whip-crack of the string, a split-the-air snap, a glassy high ring that bends down
    def pay_deadeye(i):
        d = 1.0
        glass = ring((2637, 3951, 5274), d, (0.25, 0.16, 0.08), (0.5, 0.3, 0.16))
        whistle = sat(tone_glide(3200, 900, 0.3, (1.0, 0.3)) * env(N(0.3), 0.001, 0.08), 2.0) * 0.35
        return mix(click(0.002, 4000, 14000) * 3.0, crack(d, 2000, 11000, 0.01) * 3.0, kick(320, 60, d, 0.008, 0.06, 3.4) * 0.8,
                   sub(80, 40, d, 0.1) * 0.35, at(glass * 1.3, 0.01), whistle, reflections(tail(0.7, 2200, 0.12) * 0.9))
    takes('pay_deadeye', pay_deadeye, 1, rms_db=-14)

    # Mage Flashpoint: a sucking-in rush, then a deep whoomph with a bright sparkle shower and a falling tone
    def pay_flashpoint(i):
        d = 1.4; n = N(d)
        suck = sweep(0.22, 600, 5000, 3.0) * np.linspace(0.2, 1.0, N(0.22)) ** 2 * 1.6
        boom = mix(kick(150, 38, d, 0.02, 0.16, 3.6) * 0.9, sub(60, 30, d, 0.3) * 0.6, crack(d, 200, 2400, 0.08) * 2.4)
        spark = grains(1.0, 420, 3500, 11000, 0.001, 0.004, fall=0.3) * 1.4
        fall = sat(tone_glide(1600, 300, 0.6, (1.0, 0.5, 0.25)) * env(N(0.6), 0.002, 0.18), 2.0) * 0.4
        return mix(suck, at(click(0.003, 2500, 12000) * 2.6, 0.2), at(boom, 0.2), at(spark, 0.22), at(fall, 0.21),
                   at(reflections(tail(1.0, 1400, 0.3) * 1.2), 0.22))
    takes('pay_flashpoint', pay_flashpoint, 1, rms_db=-14)

    # Gunslinger Called Shot: a heavy round, a bell-bright ting, and the cylinder spinning after it
    def pay_called(i):
        d = 1.1
        bell = ring((1760, 3520 * 1.003, 5280 * 0.997, 7040), d, (0.4, 0.2, 0.12, 0.06), (0.55, 0.25, 0.14, 0.06))
        spin = np.zeros(N(0.5))
        for k in range(9):
            c = click(0.002, 3000 + 300 * k, 9000) * (1.0 - k / 10.0)
            s0 = N(0.035 * k + 0.004 * k * k)
            if s0 + len(c) < len(spin): spin[s0:s0 + len(c)] += c
        return mix(click(0.004, 2500, 12000) * 3.0, kick(220, 50, d, 0.01, 0.07, 3.6) * 0.9, crack(d, 700, 7000, 0.03) * 3.0,
                   sub(70, 38, d, 0.12) * 0.45, at(bell * 1.4, 0.006), at(spin * 1.6, 0.32),
                   reflections(tail(0.9, 1600, 0.2) * 1.1))
    takes('pay_called', pay_called, 1, rms_db=-14)

    # Bulwark Shield Slam: a huge plate clang (inharmonic), a body slam under it, and a ringing shimmer
    def pay_slam(i):
        d = 1.2
        f = 330
        clang = ring((f, f * 1.58, f * 2.31, f * 3.47, f * 4.9), d, (0.5, 0.32, 0.22, 0.14, 0.08), (0.6, 0.45, 0.32, 0.18, 0.1))
        return mix(click(0.005, 1500, 9000) * 2.8, kick(170, 40, d, 0.015, 0.12, 3.8) * 1.0, sub(55, 30, d, 0.22) * 0.6,
                   crack(d, 300, 3000, 0.05) * 2.8, at(clang * 1.3, 0.004), reflections(tail(1.0, 1200, 0.25) * 1.2))
    takes('pay_slam', pay_slam, 1, rms_db=-14)


if __name__ == '__main__':
    build()
    print('combat sounds written')
