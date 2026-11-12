"""Synthesizes the two hero payoff sounds into audio/*.wav (pure Python, own random stream, so gen_sfx.py output is untouched).

    python3 tools/gen_hero_sfx.py      (then: godot --headless --import)

hero_blowout : Sparkle's payoff. A dry thunder crack, a falling thump and a rising zap with a spark ring on top.
hero_skewer  : Vex's payoff. A thin needle sweep, a metal tick on arrival and a short low thud.
"""
import math, os, random, struct, wave

SR = 22050
OUT = os.path.join(os.path.dirname(__file__), '..', 'audio')
rnd = random.Random(47)

def N(d): return int(SR * d)
def noise(d): return [rnd.gauss(0, 0.35) for _ in range(N(d))]
def lp(x, hz):
    a = 1 - math.exp(-2 * math.pi * hz / SR); y = 0.0; out = []
    for v in x:
        y += a * (v - y); out.append(y)
    return out
def hp(x, hz):
    l = lp(x, hz); return [v - w for v, w in zip(x, l)]
def bp(x, lo, hi): return hp(lp(x, hi), lo)
def env(n, a=0.005, d=0.12): return [min(1.0, (i / SR) / a) * math.exp(-(i / SR) / d) for i in range(n)]
def mul(x, e): return [v * w for v, w in zip(x, e)]
def scale(x, k): return [v * k for v in x]
def tone(f0, f1, d, h2=0.15):
    n = N(d); ph = 0.0; out = []
    for i in range(n):
        f = f0 * (f1 / f0) ** (i / max(1, n - 1)); ph += 2 * math.pi * f / SR
        out.append(math.sin(ph) + h2 * math.sin(2 * ph))
    return out
def bell(f, d=0.5, decay=0.16):
    n = N(d); e = env(n, 0.004, decay)
    return [(math.sin(2 * math.pi * f * i / SR) + 0.4 * math.sin(2 * math.pi * f * 2.76 * i / SR) + 0.2 * math.sin(2 * math.pi * f * 5.4 * i / SR)) * e[i] for i in range(n)]
def mix(*xs):
    n = max(len(x) for x in xs); out = [0.0] * n
    for x in xs:
        for i, v in enumerate(x): out[i] += v
    return out
def at(x, delay): return [0.0] * N(delay) + list(x)
def save(name, x, db=-19.0, tail=0.03):
    x = list(x) + [0.0] * N(tail)
    mean = sum(x) / len(x); x = [v - mean for v in x]
    rms = math.sqrt(sum(v * v for v in x) / len(x)) + 1e-9
    k = 10 ** (db / 20) / rms; x = [v * k for v in x]
    pk = max(abs(v) for v in x); ceil = 10 ** (-3 / 20)
    if pk > ceil: x = [v * ceil / pk for v in x]
    for i in range(min(30, len(x))): x[i] *= i / 30
    with wave.open(os.path.join(OUT, name + '.wav'), 'wb') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes(b''.join(struct.pack('<h', int(max(-1, min(1, v)) * 32767)) for v in x))

# ---- Sparkle: Blowout
save('hero_blowout', mix(
    scale(mul(hp(noise(0.5), 2200), env(N(0.5), 0.001, 0.07)), 1.0),
    scale(mul(tone(210, 48, 0.55), env(N(0.55), 0.002, 0.16)), 1.0),
    scale(at(mul(tone(500, 2400, 0.22), env(N(0.22), 0.01, 0.07)), 0.05), 0.55),
    scale(at(bell(2900, 0.45, 0.09), 0.1), 0.35)), -15)

# ---- Vex: Skewered
save('hero_skewer', mix(
    scale(mul(tone(900, 3200, 0.14), env(N(0.14), 0.002, 0.05)), 0.6),
    scale(at(bell(2100, 0.35, 0.07), 0.12), 0.7),
    scale(at(mul(bp(noise(0.12), 500, 2500), env(N(0.12), 0.001, 0.025)), 0.12), 0.8),
    scale(at(mul(tone(140, 70, 0.2), env(N(0.2), 0.002, 0.06)), 0.12), 0.9)), -17)
print('hero sounds written')
