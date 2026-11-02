"""Synthesizes the support pair's sounds into audio/*.wav (pure Python, own random stream, so gen_sfx.py output is untouched).

    python3 tools/gen_care_sfx.py      (then: godot --headless --import)

tend_* : Linnet's warm, wooden and lantern-bright sounds. rime_* : Tamsin's glassy, gliding, cracking ones.
"""
import math, os, random, struct, wave

SR = 22050
OUT = os.path.join(os.path.dirname(__file__), '..', 'audio')
rnd = random.Random(31)

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

# ---- Linnet: wood, wick and lantern glass
save('tend_ember', mix(scale(mul(tone(900, 420, 0.12), env(N(0.12), 0.003, 0.04)), 0.6), scale(mul(bp(noise(0.12), 1500, 5000), env(N(0.12), 0.002, 0.02)), 0.5)), -23)
save('tend_seed', mix(mul(tone(300, 520, 0.16), env(N(0.16), 0.004, 0.06)), scale(mul(bp(noise(0.2), 400, 1600), env(N(0.2), 0.01, 0.07)), 0.5)), -21)
save('tend_stick', mix(mul(bp(noise(0.12), 700, 3000), env(N(0.12), 0.002, 0.03)), scale(mul(tone(220, 150, 0.1), env(N(0.1), 0.002, 0.03)), 0.6)), -21)
save('tend_root', mix(scale(mul(lp(noise(0.5), 900), env(N(0.5), 0.03, 0.18)), 0.9), scale(mul(tone(110, 62, 0.4), env(N(0.4), 0.01, 0.14)), 0.7), at(scale(mul(bp(noise(0.2), 1200, 4000), env(N(0.2), 0.004, 0.05)), 0.5), 0.05)), -18)
save('tend_hearth', mix(bell(587, 0.7, 0.28), scale(at(bell(784, 0.6, 0.24), 0.08), 0.7), scale(at(bell(988, 0.5, 0.2), 0.16), 0.5)), -21)
save('tend_toss', mix(scale(mul(bp(noise(0.3), 500, 2600), env(N(0.3), 0.06, 0.1)), 0.5), mul(tone(500, 1000, 0.25), env(N(0.25), 0.02, 0.1))), -21)
save('tend_flare', mix(bell(523, 0.9, 0.35), scale(bell(659, 0.9, 0.3), 0.8), scale(bell(784, 0.9, 0.3), 0.7), scale(mul(bp(noise(0.5), 1500, 6000), env(N(0.5), 0.01, 0.15)), 0.4)), -18)

# ---- Tamsin: ice, blades, glass
save('rime_shard', mix(scale(mul(tone(2300, 1500, 0.07), env(N(0.07), 0.002, 0.025)), 0.6), scale(mul(hp(noise(0.08), 3500), env(N(0.08), 0.001, 0.02)), 0.6)), -24)
save('rime_lance', mix(scale(mul(tone(380, 1500, 0.2), env(N(0.2), 0.01, 0.08)), 0.7), scale(mul(bp(noise(0.25), 1500, 6000), env(N(0.25), 0.02, 0.09)), 0.7)), -20)
save('rime_burst', mix(mul(hp(noise(0.4), 2500), env(N(0.4), 0.002, 0.1)), scale(mul(tone(700, 200, 0.25), env(N(0.25), 0.003, 0.08)), 0.6), scale(bell(2200, 0.4, 0.1), 0.4)), -17)
save('rime_splinter', mix(mul(hp(noise(0.7), 1800), env(N(0.7), 0.001, 0.18)), scale(mul(tone(160, 55, 0.5), env(N(0.5), 0.002, 0.14)), 0.9), scale(bell(1800, 0.7, 0.16), 0.5), scale(at(bell(2600, 0.5, 0.12), 0.06), 0.4)), -14)
sk = noise(0.6); e = env(N(0.6), 0.04, 0.5)
save('rime_run', scale([v * (0.5 + 0.5 * math.sin(2 * math.pi * 9 * i / SR)) * e[i] for i, v in enumerate(bp(sk, 2000, 7000))], 0.8), -26)
save('rime_wall', mix(scale(mul(tone(120, 80, 0.5), env(N(0.5), 0.01, 0.15)), 0.9), scale(mul(bp(noise(0.5), 600, 3500), env(N(0.5), 0.03, 0.15)), 0.7), scale(bell(1400, 0.5, 0.15), 0.4)), -17)
save('rime_freeze', mix(bell(1900, 0.5, 0.14), scale(mul(bp(noise(0.3), 3000, 8000), env(N(0.3), 0.002, 0.07)), 0.6), scale(mul(tone(240, 120, 0.2), env(N(0.2), 0.002, 0.06)), 0.5)), -19)
print('support sounds written')
