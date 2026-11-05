"""Synthesizes Kael's sounds into audio/jug_*.wav: 44.1 kHz layers of our own synthesis (modal metal, filtered noise
fire, sub drops, source-filter grunts with no words) over the CC0 foley in tools/sfx_src/kenney_rpg (Kenney's RPG Audio:
docs/ASSET_CREDITS.md). Standard library only; ffmpeg decodes the foley. Every sound is gain-set to its category's
loudness (LUFS over its loudest 400 ms) and a peak ceiling, so the set mixes evenly; tools/sfx_loudness.py measures it.

    python3 tools/gen_kael_sfx.py [names...]      (then: godot --headless --import)
"""
import math, os, random, struct, subprocess, sys, tempfile, wave

SR = 44100
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..')
OUT = os.path.join(ROOT, 'audio')
FOLEY = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'sfx_src', 'kenney_rpg')
CEILING_DB = -3.0                # file peak, all categories
# LUFS (loudest 400 ms) per category
TARGET = {'impact': -15.0, 'cast': -18.0, 'swing': -19.0, 'hit': -19.0, 'tick': -21.0, 'voice': -20.0, 'step': -24.0, 'wind': -21.0}
# s at the most per category: past this a tail fades out, so repeats and busy fights don't smear
MAX_S = {'impact': 1.6, 'cast': 1.0, 'swing': 0.6, 'hit': 0.7, 'tick': 0.7, 'voice': 1.4, 'step': 0.35, 'wind': 0.8}
R = random.Random(5150)


def N(s):
    return int(s * SR)


def zeros(n):
    return [0.0] * n


def noise(s):
    return [R.uniform(-1, 1) for _ in range(N(s))]


def mix(*layers):
    out = zeros(max(len(x) for x in layers))
    for x in layers:
        for i, v in enumerate(x):
            out[i] += v
    return out


def at(x, s):
    return zeros(N(s)) + x


def gain(x, k):
    return [v * k for v in x]


def biquad(x, kind, f0, q=0.707):
    """One RBJ biquad, fixed or (f0 a function of 0..1) swept along the sound."""
    out = zeros(len(x))
    x1 = x2 = y1 = y2 = 0.0
    sweep = callable(f0)
    b0 = b1 = b2 = a1 = a2 = 0.0
    n = max(1, len(x))
    for i, v in enumerate(x):
        if i % 32 == 0 or i == 0 and not sweep:
            f = f0(i / n) if sweep else f0
            w = 2 * math.pi * min(f, SR * 0.45) / SR
            c, s = math.cos(w), math.sin(w)
            al = s / (2 * q)
            a0 = 1 + al
            if kind == 'lp':
                b0, b1, b2 = (1 - c) / 2, 1 - c, (1 - c) / 2
            elif kind == 'hp':
                b0, b1, b2 = (1 + c) / 2, -(1 + c), (1 + c) / 2
            else:
                b0, b1, b2 = al, 0.0, -al
            a1, a2 = -2 * c, 1 - al
            b0, b1, b2, a1, a2 = b0 / a0, b1 / a0, b2 / a0, a1 / a0, a2 / a0
        y = b0 * v + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
        x2, x1, y2, y1 = x1, v, y1, y
        out[i] = y
    return out


def lp(x, f, q=0.707):
    return biquad(x, 'lp', f, q)


def hp(x, f, q=0.707):
    return biquad(x, 'hp', f, q)


def bp(x, f, q=1.0):
    return biquad(x, 'bp', f, q)


def decay(x, tau, attack=0.002):
    a = max(1, N(attack))
    return [v * min(1.0, i / a) * math.exp(-i / (tau * SR)) for i, v in enumerate(x)]


def swell(x, peak=0.5, power=2.0):
    """Rises to its top at `peak` of the way, then falls: a sweep past the ear."""
    n = max(1, len(x))
    out = zeros(n)
    for i, v in enumerate(x):
        u = i / n
        e = (u / peak) if u < peak else (1 - u) / (1 - peak)
        out[i] = v * e ** power
    return out


def rise(x, power=2.0):
    n = max(1, len(x))
    return [v * (i / n) ** power for i, v in enumerate(x)]


def tail_off(x, s=0.02):
    n = min(len(x), N(s))
    out = list(x)
    for i in range(n):
        out[-1 - i] *= i / n
    return out


def sat(x, drive=2.0):
    k = math.tanh(drive)
    return [math.tanh(v * drive) / k for v in x]


def sub(f0, f1, s, tau, curve=0.06):
    """A sine falling from f0 to f1 Hz: the body of a hit."""
    out = zeros(N(s))
    ph = 0.0
    for i in range(len(out)):
        t = i / SR
        f = f1 + (f0 - f1) * math.exp(-t / curve)
        ph += 2 * math.pi * f / SR
        out[i] = math.sin(ph) * math.exp(-t / tau) * min(1.0, i / 40)
    return out


def tone(f0, f1, s, wave_kind='sine'):
    """A glide from f0 to f1 Hz."""
    out = zeros(N(s))
    ph = 0.0
    n = max(1, len(out))
    for i in range(n):
        ph += 2 * math.pi * (f0 + (f1 - f0) * i / n) / SR
        p = ph % (2 * math.pi)
        out[i] = math.sin(ph) if wave_kind == 'sine' else (p / math.pi - 1.0)
    return out


def modal(modes, s, strike=0.0008):
    """Struck metal: (Hz, level, decay s) partials, inharmonic, with a little beating."""
    n = N(s)
    out = zeros(n)
    for f, a, d in modes:
        w = 2 * math.pi * f / SR
        w2 = 2 * math.pi * (f * 1.003) / SR
        k = math.exp(-1.0 / (d * SR))
        e = a
        p = R.uniform(0, 6.28)
        for i in range(n):
            out[i] += e * (math.sin(w * i + p) + 0.4 * math.sin(w2 * i + p))
            e *= k
    a = max(1, N(strike))
    return [v * min(1.0, i / a) for i, v in enumerate(out)]


def blade_ring(f, s=0.5, level=1.0, tau=0.2):
    return gain(modal([(f, 1.0, tau), (f * 2.76, 0.5, tau * 0.6), (f * 5.4, 0.28, tau * 0.35), (f * 8.93, 0.14, tau * 0.2)], s), level)


def link(f):
    return modal([(f, 1.0, 0.018), (f * 1.73, 0.6, 0.012), (f * 2.9, 0.35, 0.007)], 0.06)


def rattle(s, count, f_lo=1500, f_hi=3400, level=1.0):
    """Chain links knocking: `count` little struck pieces spread over s seconds."""
    out = zeros(N(s) + N(0.07))
    for _ in range(count):
        o = N(R.uniform(0, s))
        lk = link(R.uniform(f_lo, f_hi))
        amp = level * R.uniform(0.3, 1.0)
        for i, v in enumerate(lk):
            out[o + i] += v * amp
    return out


def fire(s, level=1.0, crackle=60.0):
    """Burning: low roar with a wandering level, plus sparse crackle."""
    n = N(s)
    roar = lp(noise(s), 420)
    slow = 0.0
    wander = zeros(n)
    for i in range(n):
        slow += (R.uniform(-1, 1) - slow) * 0.0009
        wander[i] = 0.65 + slow * 7.0
    body = [roar[i] * max(0.15, wander[i]) for i in range(n)]
    hiss = hp(bp(noise(s), 2400, 0.6), 700)
    out = mix(gain(body, 1.0), gain(hiss, 0.12))
    for _ in range(int(s * crackle)):
        o = N(R.uniform(0, s * 0.98))
        c = decay(bp(noise(0.012), R.uniform(1400, 5200), 2.0), 0.003)
        amp = R.uniform(0.2, 0.9)
        for i, v in enumerate(c):
            if o + i < n:
                out[o + i] += v * amp
    return gain(out, level)


def whoosh(s, f_lo, f_hi, peak=0.45, q=1.1, power=1.6):
    def f(u):
        e = u / peak if u < peak else (1 - u) / (1 - peak)
        return f_lo + (f_hi - f_lo) * e
    return swell(biquad(noise(s), 'bp', f, q), peak, power)


def room(x, wet=0.16, size=0.05):
    """A short dark tail: a few feedback combs, damped."""
    tail = N(0.35)
    out = list(x) + zeros(tail)
    bus = zeros(len(out))
    for d, fb in ((size, 0.72), (size * 1.33, 0.68), (size * 1.71, 0.64), (size * 2.13, 0.6)):
        delay = N(d)
        buf = zeros(len(out))
        lo = 0.0
        for i in range(len(out)):
            src = out[i] if i < len(x) else 0.0
            back = buf[i - delay] if i >= delay else 0.0
            lo += (back - lo) * 0.35
            buf[i] = src + lo * fb
            bus[i] += back
    return tail_off(mix(out, gain(bus, wet * 0.5)), 0.08)


_cache = {}
def foley(name):
    """A CC0 foley file (mono float), decoded once."""
    if name not in _cache:
        src = os.path.join(FOLEY, name + '.ogg')
        raw = subprocess.run(['ffmpeg', '-loglevel', 'error', '-i', src, '-ac', '1', '-ar', str(SR), '-f', 's16le', '-'],
                             capture_output=True, check=True).stdout
        vals = struct.unpack('<%dh' % (len(raw) // 2), raw)
        _cache[name] = [v / 32768.0 for v in vals]
        pk = max(abs(v) for v in _cache[name]) or 1.0
        _cache[name] = [v / pk for v in _cache[name]]
    return _cache[name]


def resample(x, rate):
    """Plays x back `rate` times as fast: lower and longer below 1, for heft."""
    n = int(len(x) / rate)
    out = zeros(n)
    for i in range(n):
        p = i * rate
        j = int(p)
        if j + 1 >= len(x):
            break
        out[i] = x[j] + (x[j + 1] - x[j]) * (p - j)
    return out


def grunt(s, f0, f1, formants, breath=0.12, rough=0.25, level=1.0):
    """A wordless vocal: a jittered pulse train through formant filters, with breath and a rough edge."""
    n = N(s)
    src = zeros(n)
    ph = 0.0
    jit = 0.0
    for i in range(n):
        u = i / n
        jit += (R.uniform(-1, 1) - jit) * 0.004
        f = (f0 + (f1 - f0) * u) * (1.0 + jit * 0.5)
        ph += f / SR
        if ph >= 1.0:
            ph -= 1.0
        # a glottal pulse: quick close, soft open
        pulse = (ph / 0.62) ** 2 * (3 - 2 * ph / 0.62) if ph < 0.62 else 1.0 - (ph - 0.62) / 0.38
        src[i] = (pulse - 0.5) * 2.0 * (1.0 + rough * math.sin(2 * math.pi * f * 0.5 * i / SR))
    air = bp(noise(s), 1500, 0.5)
    src = [src[i] + air[i] * breath * 3.0 for i in range(n)]
    voiced = zeros(n)
    for f, q, a in formants:
        v = bp(src, f, q)
        voiced = [voiced[i] + v[i] * a for i in range(n)]
    voiced = lp(voiced, 3400)
    return gain(sat(voiced, 1.6), level)


def vocal_env(x, attack=0.03, hold=0.3, release=0.5):
    n = len(x)
    out = zeros(n)
    for i, v in enumerate(x):
        u = i / n
        if u < attack:
            e = u / attack
        elif u < hold:
            e = 1.0
        else:
            e = max(0.0, 1.0 - (u - hold) / max(0.001, release)) ** 1.6
        out[i] = v * e
    return tail_off(out, 0.01)


def lufs_400(x):
    """Loudest 400 ms in LUFS: BS.1770 K-weighting (44.1 kHz) over a 100 ms hop. Short sounds are padded with silence."""
    b = (1.53091, -2.65098, 1.16902, -1.66365, 0.71265)
    h = (1.0, -2.0, 1.0, -1.98916, 0.98919)
    def run(sig, c):
        o = zeros(len(sig))
        x1 = x2 = y1 = y2 = 0.0
        for i, v in enumerate(sig):
            y = c[0] * v + c[1] * x1 + c[2] * x2 - c[3] * y1 - c[4] * y2
            x2, x1, y2, y1 = x1, v, y1, y
            o[i] = y
        return o
    k = run(run(list(x) + zeros(N(0.4)), b), h)
    win = N(0.4)
    hop = N(0.1)
    sq = [v * v for v in k]
    tot = sum(sq[:win])
    best = tot
    i = 0
    while i + win + hop < len(sq):
        tot += sum(sq[i + win:i + win + hop]) - sum(sq[i:i + hop])
        i += hop
        best = max(best, tot)
    return -0.691 + 10 * math.log10(max(best / win, 1e-12))


def trimmed(x, category):
    """Cut below -54 dB of the peak at the end, capped to the category's length, the last third of a cap faded."""
    pk = max(abs(v) for v in x) or 1.0
    end = len(x)
    while end > 1 and abs(x[end - 1]) < pk * 0.002:
        end -= 1
    cap = N(MAX_S[category])
    if end <= cap:
        return tail_off(x[:end], 0.012)
    out = list(x[:cap])
    fade = cap // 3
    for i in range(fade):
        out[-1 - i] *= (i / fade) ** 1.5
    return out


def write(name, x, category):
    """Sets the sound's level for its category, keeps the peak under the ceiling, writes it."""
    x = trimmed(x, category)
    pk = max(abs(v) for v in x) or 1.0
    x = [v / pk for v in x]
    want = TARGET[category]
    k = 10 ** ((want - lufs_400(x)) / 20)
    ceil = 10 ** (CEILING_DB / 20)
    if k > ceil:
        # louder than the ceiling allows: lean on a soft clip, then set the level again
        x = gain(sat(x, min(k / ceil, 4.0)), 1.0)
        k = min(10 ** ((want - lufs_400(x)) / 20), ceil / max(abs(v) for v in x))
    x = gain(x, k)
    frames = struct.pack('<%dh' % len(x), *[int(max(-1.0, min(1.0, v)) * 32767) for v in x])
    with wave.open(os.path.join(OUT, name + '.wav'), 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(frames)
    print('%-22s %-7s %5.2fs' % (name, category, len(x) / SR))


# ------------------------------------------------------------------ the sounds
def slash(take):
    """LMB: a heavy blade cutting air, a flame licking after it, a touch of steel."""
    pitch = (1.0, 1.08, 0.93)[take]
    air = whoosh(0.26, 380 * pitch, 2600 * pitch, 0.38, 0.9)
    lick = at(hp(lp(fire(0.2, 1.0, 90), 2800), 200), 0.05)
    steel = at(gain(hp(resample(foley('drawKnife%d' % (1 + take % 2)), 1.25), 700), 0.28), 0.0)
    return room(mix(gain(air, 1.0), gain(decay(lick, 0.08), 0.4), steel), 0.1)


def blade_hit(take):
    """LMB connecting: the blade biting, short and dry, so it can repeat."""
    chop = resample(foley('chop'), (0.82, 0.74, 0.9)[take])
    return mix(gain(chop, 0.9), gain(sub(170, 70, 0.14, 0.05), 0.75), gain(blade_ring(1500 + 180 * take, 0.16, 1.0, 0.04), 0.14))


def tip():
    """The tip sweet spot: a bright ring on top of the hit."""
    return room(mix(gain(blade_ring(1120, 0.5, 1.0, 0.13), 0.55), gain(resample(foley('chop'), 0.9), 0.6), gain(sub(220, 90, 0.2, 0.06), 0.6)), 0.14)


def wave_fire():
    """Searing Wave: a wall of fire thrown forward: whoomp, roar, gone."""
    thump = gain(sub(130, 48, 0.4, 0.13), 0.9)
    throw = whoosh(0.72, 180, 1500, 0.22, 0.7, 1.2)
    roar = decay(fire(0.8, 1.0, 110), 0.28, 0.02)
    return room(mix(thump, gain(throw, 0.9), gain(roar, 1.1)), 0.12)


def wave_full():
    """The full wave's gold edge: a high rising shimmer of hot metal."""
    return mix(gain(decay(blade_ring(620, 0.8, 1.0, 0.35), 0.3), 0.5), gain(whoosh(0.5, 1500, 5200, 0.3, 1.6), 0.5))


def slam_wind():
    """The Slam's 0.6s wind-up: the sword dragged up, leather and steel, a rising heat."""
    n = 0.58
    rumble = rise(lp(noise(n), 240), 1.4)
    heat = rise(hp(fire(n, 1.0, 40), 300), 1.8)
    leather = gain(resample(foley('cloth3'), 0.8), 0.6)
    scrape = at(gain(hp(resample(foley('drawKnife1'), 0.62), 500), 0.5), 0.14)
    return tail_off(mix(gain(rumble, 0.9), gain(heat, 0.7), leather, scrape))


def slam_hit():
    """The Finishing Slam landing: blade into stone, the ground splitting, flame."""
    body = gain(sub(115, 36, 0.8, 0.22), 1.0)
    crack = decay(hp(noise(0.12), 900), 0.02)
    rock = gain(lp(resample(foley('chop'), 0.42), 1800), 1.0)
    clang = gain(resample(foley('metalPot2'), 0.5), 0.38)
    burn = at(decay(fire(0.75, 1.0, 80), 0.3), 0.05)
    return room(sat(mix(body, gain(crack, 0.6), rock, clang, gain(burn, 0.5)), 1.5), 0.2, 0.06)


def sweet():
    """The sweet spot: a high clean bell of steel over a short crack, the payoff you learn to hear."""
    return room(mix(gain(blade_ring(880, 0.8, 1.0, 0.3), 0.8), gain(blade_ring(1319, 0.7, 1.0, 0.24), 0.5), gain(decay(hp(noise(0.08), 1400), 0.015), 0.5), gain(sub(200, 80, 0.2, 0.07), 0.5)), 0.2)


def charge():
    """The Lunge charging (0.5 s to full): a held breath of heat, a rising strain of metal."""
    s = 0.62
    drone = rise(mix(gain(tone(62, 124, s, 'saw'), 0.5), gain(tone(93, 248, s, 'saw'), 0.3)), 0.9)
    drone = biquad(drone, 'lp', lambda u: 240 + 1500 * u, 1.6)
    hiss = rise(hp(fire(s, 1.0, 60), 500), 1.8)
    strain = rise(lp(resample(foley('creak1'), 0.7)[:N(s)], 2600), 1.0)
    return tail_off(mix(gain(sat(drone, 2.0), 0.9), gain(hiss, 0.6), gain(strain, 0.35)))


def full():
    """Charged, and the perfect-release cue: one hard, clear ping you can act on."""
    return room(mix(gain(blade_ring(1568, 0.5, 1.0, 0.16), 0.9), gain(blade_ring(2349, 0.4, 1.0, 0.1), 0.5), gain(sub(160, 120, 0.12, 0.04), 0.35)), 0.2)


def lunge():
    """The fling: a body leaving the ground at speed."""
    kick = gain(sub(140, 60, 0.26, 0.09), 0.9)
    rush = whoosh(0.44, 220, 1900, 0.3, 0.8, 1.3)
    flame = decay(fire(0.44, 1.0, 100), 0.2)
    gear = gain(resample(foley('beltHandle1'), 0.75), 0.4)
    return room(mix(kick, gain(rush, 1.0), gain(flame, 0.55), gear), 0.1)


def lunge_hit():
    """The Lunge connecting: steel through armour, heavy."""
    body = gain(sub(150, 42, 0.55, 0.16), 1.0)
    pot = gain(resample(foley('metalPot1'), 0.55), 0.55)
    chop = gain(resample(foley('chop'), 0.55), 0.9)
    burst = at(decay(fire(0.5, 1.0, 120), 0.18), 0.02)
    return room(sat(mix(body, pot, chop, gain(burst, 0.5)), 1.6), 0.18, 0.05)


def drop():
    """The Meteor Drop's press: he hauls himself up, wind and leather."""
    return tail_off(mix(gain(whoosh(0.32, 240, 1200, 0.65, 0.9), 0.9), gain(resample(foley('cloth1'), 0.7), 0.5), gain(rise(fire(0.3, 1.0, 60), 1.4), 0.5)))


def dive():
    """The dive: falling fire."""
    def f(u):
        return 500 + 2600 * u * u
    roar = rise(biquad(noise(0.42), 'bp', f, 0.7), 1.1)
    return tail_off(mix(gain(roar, 1.0), gain(rise(fire(0.42, 1.0, 120), 1.2), 0.8)))


def meteor():
    """The Meteor Drop landing, his biggest sound: the ground breaking, a long sub, rocks falling after."""
    body = gain(sub(88, 27, 1.3, 0.42, 0.09), 1.0)
    crack = decay(hp(noise(0.16), 650), 0.035)
    slam = gain(lp(resample(foley('chop'), 0.34), 1400), 1.0)
    clang = gain(resample(foley('metalPot3'), 0.42), 0.32)
    burn = at(decay(fire(1.1, 1.0, 70), 0.42), 0.05)
    debris = zeros(N(1.2))
    for _ in range(16):
        o = N(R.uniform(0.12, 1.05))
        c = resample(foley('footstep0%d' % R.choice((0, 2, 4, 6))), R.uniform(0.7, 1.3))
        amp = R.uniform(0.07, 0.22)
        for i, v in enumerate(c):
            if o + i < len(debris):
                debris[o + i] += v * amp
    return room(sat(mix(body, gain(crack, 0.8), slam, clang, gain(burn, 0.55), debris), 1.5), 0.22, 0.07)


def spin():
    """Cinder Spin: the sword round him twice in a roar of flame."""
    a = whoosh(0.22, 320, 2300, 0.5, 0.9)
    b = at(whoosh(0.26, 280, 2000, 0.5, 0.9), 0.14)
    burn = decay(fire(0.55, 1.0, 120), 0.22)
    return room(mix(gain(a, 0.9), gain(b, 1.0), gain(burn, 0.7), gain(sub(120, 60, 0.3, 0.1), 0.5)), 0.12)


def haul_hit():
    """The Haul Slam: the chain's weight behind the Slam, gold."""
    return room(sat(mix(gain(sub(100, 34, 1.0, 0.3), 1.0), gain(lp(resample(foley('chop'), 0.4), 1500), 0.9), gain(resample(foley('metalPot1'), 0.46), 0.45), gain(blade_ring(698, 0.8, 1.0, 0.3), 0.22), at(rattle(0.3, 24, 1100, 2500, 0.5), 0.03)), 1.5), 0.2, 0.06)


def dash_wind():
    """Rampage's crouch: boots biting, a breath of flame."""
    return tail_off(mix(gain(resample(foley('dropLeather'), 0.9), 0.8), gain(rise(lp(fire(0.14, 1.0, 40), 1800), 1.0), 0.6)))


def dash():
    """Rampage's drive: a heavy body on fire, not a sprinter's dash."""
    kick = gain(sub(120, 52, 0.3, 0.11), 1.0)
    rush = whoosh(0.34, 200, 1300, 0.28, 0.8, 1.2)
    flame = decay(fire(0.4, 1.0, 100), 0.17)
    return room(mix(kick, gain(rush, 0.9), gain(flame, 0.8)), 0.09)


def chain():
    """E thrown: the chain whipping out, links running."""
    run = rattle(0.3, 26, 1500, 3600, 1.0)
    return room(mix(gain(whoosh(0.34, 700, 3400, 0.3, 1.2), 0.5), run, gain(resample(foley('handleCoins'), 0.8), 0.7)), 0.08)


def hook():
    """The hook biting: iron into something, and the chain slapping after it."""
    return room(mix(gain(resample(foley('metalLatch'), 0.75), 1.0), gain(sub(190, 90, 0.16, 0.05), 0.7), at(rattle(0.2, 12, 1200, 2800, 0.6), 0.03), gain(blade_ring(1020, 0.3, 1.0, 0.08), 0.3)), 0.1)


def taut():
    """The chain pulled tight: links catching in a run, an iron creak."""
    return mix(rattle(0.2, 14, 800, 1700, 1.0), gain(lp(resample(foley('creak2'), 0.8), 2600)[:N(0.32)], 0.8))


def reel():
    """The haul: links screaming through, dragged along. As long as a curved 13 m pull (0.65 s); it thins toward its
    end so a shorter pull's arrival sound takes over."""
    run = decay(rattle(0.62, 58, 1300, 3200, 1.0), 0.42)
    return room(mix(run, gain(whoosh(0.66, 500, 2000, 0.2, 0.8, 1.2), 0.5), gain(resample(foley('handleCoins2'), 0.7), 0.5)), 0.08)


def arrive():
    """The pull ends: boots skidding in, the chain falling slack."""
    return mix(gain(resample(foley('footstep02'), 0.6), 0.9), gain(sub(120, 60, 0.14, 0.05), 0.5), at(rattle(0.26, 12, 900, 2100, 0.5), 0.06))


def snap():
    """The chain breaking or missing: a dull clank and links falling."""
    return room(mix(gain(resample(foley('metalClick'), 0.62), 1.0), at(rattle(0.34, 16, 1000, 2600, 0.7), 0.04)), 0.1)


def guard():
    """Gilded Riposte's guard: a gold note rising under a planted blade, 0.65 s."""
    s = 0.72
    note = rise(mix(gain(tone(196, 233, s, 'saw'), 0.5), gain(tone(294, 349, s, 'saw'), 0.3)), 0.6)
    note = biquad(note, 'lp', lambda u: 500 + 1800 * u, 1.3)
    plant = gain(lp(resample(foley('chop'), 0.5), 1600), 0.8)
    bell = at(gain(blade_ring(784, 0.6, 1.0, 0.28), 0.34), 0.02)
    return room(mix(gain(sat(note, 1.6), 0.75), plant, bell, gain(sub(110, 70, 0.2, 0.08), 0.5)), 0.16)


def ting():
    """A hit blocked by the guard: bright, short, and it climbs with each block (the kit raises its pitch)."""
    return room(mix(gain(blade_ring(1976, 0.3, 1.0, 0.07), 1.0), gain(blade_ring(2960, 0.24, 1.0, 0.05), 0.5), gain(decay(hp(noise(0.03), 3000), 0.006), 0.4)), 0.12)


def riposte():
    """The answer: the cleave ripping upward."""
    up = whoosh(0.3, 300, 3400, 0.65, 0.9, 1.3)
    return room(mix(gain(up, 1.0), gain(sub(90, 200, 0.26, 0.12, 0.2), 0.5), gain(resample(foley('drawKnife2'), 0.8), 0.4)), 0.12)


def riposte_hit():
    """The cleave landing: the ult's signature, gold ring on a heavy cut."""
    return room(sat(mix(gain(sub(130, 40, 0.8, 0.24), 1.0), gain(resample(foley('chop'), 0.5), 0.9), gain(blade_ring(523, 1.0, 1.0, 0.42), 0.4), gain(blade_ring(784, 0.9, 1.0, 0.34), 0.28), gain(resample(foley('metalPot2'), 0.6), 0.3)), 1.4), 0.24, 0.07)


def enrage():
    """Enraged: a low roar in his own voice, fire catching around it."""
    ROAR = [(460, 5.0, 1.0), (980, 5.0, 0.7), (2300, 6.0, 0.25), (3000, 7.0, 0.1)]
    voice = vocal_env(grunt(0.82, 92, 74, ROAR, 0.1, 0.6), 0.08, 0.5, 0.5)
    catch = at(decay(fire(0.8, 1.0, 140), 0.32, 0.04), 0.05)
    return room(mix(voice, gain(catch, 0.5), gain(sub(90, 45, 0.5, 0.2), 0.55)), 0.2, 0.06)


HURT = ([(560, 6.0, 1.0), (1050, 6.0, 0.55), (2400, 7.0, 0.18)], [(640, 6.0, 1.0), (1190, 6.0, 0.6), (2390, 7.0, 0.18)],
        [(490, 6.0, 1.0), (900, 6.0, 0.55), (2500, 7.0, 0.16)], [(700, 5.0, 1.0), (1220, 6.0, 0.5), (2600, 7.0, 0.14)])


def hurt(take):
    """A short grunt through the teeth, four takes."""
    s = (0.2, 0.24, 0.17, 0.27)[take]
    f = (118, 108, 128, 100)[take]
    return vocal_env(grunt(s, f, f * 0.74, HURT[take], 0.14, 0.45), 0.08, 0.3, 0.7)


def downed():
    """Going down: a long falling groan, the breath going out of him, no words."""
    ah = grunt(0.95, 112, 62, [(640, 5.0, 1.0), (1050, 5.0, 0.55), (2400, 7.0, 0.14)], 0.2, 0.7)
    breath = at(decay(bp(noise(0.5), 900, 0.7), 0.16, 0.05), 0.75)
    fall = at(gain(resample(foley('dropLeather'), 0.7), 0.5), 0.5)
    return room(mix(vocal_env(ah, 0.06, 0.35, 0.65), gain(breath, 0.2), fall), 0.12)


def step(surface, take):
    """A heavy boot on a surface: the foley's foot lowered for his weight, a thud under it, a little iron on him."""
    foot = resample(foley('footstep0%d' % (take * 2)), {'grass': 0.8, 'stone': 0.74, 'snow': 0.7, 'wood': 0.72}[surface])
    thud = gain(sub(95, 58, 0.14, 0.05), 0.75)
    gear = at(gain(rattle(0.08, 4, 1800, 3200, 1.0), 0.1), 0.012)
    if surface == 'grass':
        tex = gain(hp(decay(noise(0.14), 0.05), 1500), 0.2)
        return mix(gain(lp(foot, 3400), 0.8), thud, tex, gear)
    if surface == 'snow':
        crunch = rattle(0.12, 40, 2200, 5200, 0.5)
        return mix(gain(lp(foot, 2200), 0.5), gain(thud, 0.8), crunch)
    if surface == 'wood':
        board = gain(modal([(240, 1.0, 0.04), (410, 0.6, 0.03), (780, 0.3, 0.015)], 0.12), 0.7)
        return mix(gain(foot, 0.7), thud, board, gear)
    return mix(gain(hp(foot, 200), 1.0), gain(thud, 0.8), gain(decay(hp(noise(0.03), 2500), 0.008), 0.25), gear)


def build():
    jobs = [('jug_slash_%d' % (i + 1), lambda i=i: slash(i), 'swing') for i in range(3)]
    jobs += [('jug_blade_hit_%d' % (i + 1), lambda i=i: blade_hit(i), 'hit') for i in range(3)]
    jobs += [('jug_tip', tip, 'hit'), ('jug_wave', wave_fire, 'cast'), ('jug_wave_full', wave_full, 'tick'), ('jug_slam_wind', slam_wind, 'wind'),
             ('jug_slam_hit', slam_hit, 'impact'), ('jug_sweet', sweet, 'hit'), ('jug_charge', charge, 'wind'), ('jug_full', full, 'tick'),
             ('jug_lunge', lunge, 'cast'), ('jug_lunge_hit', lunge_hit, 'impact'), ('jug_drop', drop, 'wind'), ('jug_dive', dive, 'cast'),
             ('jug_meteor', meteor, 'impact'), ('jug_spin', spin, 'cast'), ('jug_haul_hit', haul_hit, 'impact'), ('jug_dash_wind', dash_wind, 'tick'),
             ('jug_dash', dash, 'cast'), ('jug_chain', chain, 'cast'), ('jug_hook', hook, 'hit'), ('jug_taut', taut, 'tick'), ('jug_reel', reel, 'cast'),
             ('jug_arrive', arrive, 'tick'), ('jug_snap', snap, 'tick'), ('jug_guard', guard, 'cast'), ('jug_ting', ting, 'tick'),
             ('jug_riposte', riposte, 'cast'), ('jug_riposte_hit', riposte_hit, 'impact'), ('jug_enrage', enrage, 'cast'), ('jug_downed', downed, 'voice')]
    jobs += [('jug_hurt_%d' % (i + 1), lambda i=i: hurt(i), 'voice') for i in range(4)]
    for surface in ('grass', 'stone', 'snow', 'wood'):
        jobs += [('jug_step_%s_%d' % (surface, i + 1), lambda s=surface, i=i: step(s, i), 'step') for i in range(3)]
    return jobs


def main():
    only = sys.argv[1:]
    for name, fn, category in build():
        if only and not any(name.startswith(o) for o in only):
            continue
        write(name, fn(), category)


if __name__ == '__main__':
    main()
