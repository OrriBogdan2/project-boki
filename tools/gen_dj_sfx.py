"""Synthesizes Sable's ability sounds into audio/*.wav (pure Python, own random stream,
so gen_sfx.py and gen_care_sfx.py output is untouched). Every sound is ours, made from tones and noise.

    python3 tools/gen_dj_sfx.py      (then: godot --headless --import)

dj_*  : Sable: bright, glassy, quick (spinning bolts, a whirled cord, a blink).
(Kael's jug_* sounds moved to tools/gen_kael_sfx.py.)
"""
import math, os, random, struct, wave

SR = 22050
OUT = os.path.join(os.path.dirname(__file__), '..', 'audio')
rnd = random.Random(57)

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


def chirp(f0, f1, d, a=0.004, dec=0.08, h2=0.15): return mul(tone(f0, f1, d, h2), env(N(d), a, dec))
def hiss(d, lo, hi, a=0.003, dec=0.05): return mul(bp(noise(d), lo, hi), env(N(d), a, dec))
def rise(n, a=0.4):
    return [min(1.0, (i / max(1, n - 1)) ** a) for i in range(n)]
def whirl(d, rate0, rate1, f):
    # a cord whirled overhead: noise pulsing faster and faster
    n = N(d); out = []; ph = 0.0; x = bp(noise(d), f * 0.6, f * 1.6)
    for i in range(n):
        r = rate0 + (rate1 - rate0) * i / n; ph += 2 * math.pi * r / SR
        out.append(x[i] * (0.35 + 0.65 * max(0.0, math.sin(ph)) ** 2))
    return out

# ---- Sable
save('dj_bolt', mix(chirp(1800, 900, 0.12, 0.002, 0.04, 0.3), scale(hiss(0.12, 2500, 7000, 0.001, 0.025), 0.6), scale(chirp(3600, 2400, 0.06, 0.001, 0.02), 0.25)), -22)
save('dj_bolt_emp', mix(chirp(600, 1500, 0.22, 0.004, 0.12, 0.4), scale(hiss(0.35, 1500, 8000, 0.002, 0.1), 0.9), scale(at(chirp(2200, 700, 0.3, 0.002, 0.12), 0.04), 0.6), scale(mul(lp(noise(0.3), 300), env(N(0.3), 0.002, 0.08)), 0.7)), -17)
save('dj_fizzle', mix(scale(hiss(0.2, 1800, 6000, 0.01, 0.07), 0.8), scale(chirp(1200, 500, 0.15, 0.005, 0.05), 0.3)), -26)
save('dj_cartwheel', mix(mul(bp(noise(0.3), 500, 2600), [math.sin(math.pi * i / N(0.3)) ** 2 for i in range(N(0.3))]), scale(at(chirp(2400, 3200, 0.08, 0.002, 0.04), 0.24), 0.4)), -21)
save('dj_heal', mix(bell(659, 0.8, 0.3), scale(at(bell(880, 0.7, 0.28), 0.06), 0.7), scale(at(bell(1319, 0.6, 0.22), 0.12), 0.5), scale(mul(bp(noise(0.6), 2000, 7000), env(N(0.6), 0.05, 0.2)), 0.25)), -20)
save('dj_jackpot', mix(scale(mul(tone(300, 900, 0.4), rise(N(0.4))), 0.6), scale(hiss(0.5, 1500, 6000, 0.05, 0.2), 0.5), scale(at(bell(1047, 0.5, 0.2), 0.38), 0.8), scale(at(bell(1568, 0.5, 0.18), 0.42), 0.6)), -18)
save('dj_blade', mix(chirp(2600, 1400, 0.09, 0.001, 0.03), scale(hiss(0.1, 3000, 8000, 0.001, 0.02), 0.7)), -24)
save('dj_bola_whirl', mix(whirl(0.45, 6, 16, 900), scale(mul(tone(180, 260, 0.45), env(N(0.45), 0.1, 0.4)), 0.25)), -21)
save('dj_bola_throw', mix(mul(bp(noise(0.25), 400, 2200), env(N(0.25), 0.01, 0.09)), scale(chirp(700, 300, 0.2, 0.004, 0.08), 0.5), scale(hiss(0.08, 3000, 8000, 0.001, 0.02), 0.4)), -20)
save('dj_bola_wrap', mix(scale(chirp(500, 380, 0.25, 0.002, 0.08, 0.5), 0.7), scale(at(chirp(500, 380, 0.2, 0.002, 0.07, 0.5), 0.07), 0.5), scale(hiss(0.3, 1500, 5000, 0.002, 0.1), 0.6), scale(at(bell(1200, 0.3, 0.1), 0.02), 0.4)), -19)
save('dj_knife_throw', mix(mul(bp(noise(0.2), 900, 4000), env(N(0.2), 0.03, 0.06)), scale(chirp(1600, 2400, 0.12, 0.01, 0.05), 0.4)), -21)
save('dj_blink', mix(scale(chirp(400, 2400, 0.14, 0.002, 0.06), 0.7), scale(hiss(0.25, 2000, 8000, 0.002, 0.08), 0.7), scale(at(bell(1760, 0.3, 0.1), 0.1), 0.4)), -19)

# ---- the ultimates (X)
# Sable's Encore: the ring opening (a rising shimmer that lands on two bells), the whirr while the blades
# fly (2s of pulsing air), and the quick thunk of a blade landing
save('dj_encore', mix(scale(mul(whirl(0.45, 8, 22, 2400), rise(N(0.45), 0.5)), 0.8), scale(mul(tone(500, 1400, 0.45), rise(N(0.45), 0.6)), 0.35), scale(at(bell(1319, 0.5, 0.2), 0.4), 0.7), scale(at(bell(1976, 0.4, 0.16), 0.44), 0.5)), -18)
wn = N(2.0)
save('dj_encore_whirr', mul(whirl(2.0, 14, 14, 1800), [min(1.0, i / N(0.15)) * min(1.0, (wn - i) / N(0.3)) for i in range(wn)]), -25)
save('dj_encore_hit', mix(chirp(520, 180, 0.08, 0.001, 0.03, 0.5), scale(hiss(0.05, 2500, 7000, 0.001, 0.012), 0.6), scale(mul(lp(noise(0.06), 400), env(N(0.06), 0.001, 0.02)), 0.6)), -22)
print('dj sounds written')
