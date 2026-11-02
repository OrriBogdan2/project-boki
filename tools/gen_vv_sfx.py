"""Synthesizes Vireo's and Venator's ability sounds into audio/vv_*.wav and audio/vn_*.wav (pure Python,
its own random stream, so the other generators' output is untouched). No samples from anywhere.

    python3 tools/gen_vv_sfx.py      (then: godot --headless --import)

Vireo (electric, dry, crackling):
  vv_bolt          finger snap + a short crackle zap (the finger-gun bolt)
  vv_static_full   a 4th Static stack: a high sky crack and a sizzle tail
  vv_surge_charge  Wirerun held: a rising buzz with crackle
  vv_surge_go      Wirerun released: a sharp crack and a falling whoosh
  vv_rod_summon    Storm Rod appears: a bright shimmer-pop
  vv_rod_full      Storm Rod full: a clean high ping with a hum
  vv_rod_throw     Storm Rod thrown: a whip crack and a zipping tail
  vv_orb           a charge orb: a soft hum-pop with a fizz
  vv_sky_place     Skycall placed: a low tick and a static breath
  vv_sky_count     Skycall committed: a rising tone under a crackle
  vv_sky_strike    Skycall lands: a thunder clap with a rumble
Venator (mechanical, punchy, ember-hot):
  vn_rifle   an auto-rifle round: a tight crack, a mid thump, a metallic ring
  vn_cock    the grenade pin pulled: two metal clicks
  vn_throw   the overhand throw: a cloth whoosh
  vn_stick   stuck to a wall or the ground: a clank and a fast beeper
  vn_blast   the cone blast: a deep boom with a gritty spray
  vn_slide   Combat Slide: a gritty scrape
  vn_ion_charge  Ion Cannon cast: a rising whine
  vn_ion_fire    Ion Cannon fire: a wide beam roar and a low kick
  vn_stim    a knock resets the slide: a quick rising two-note
"""
import math, os, random, struct, wave

SR = 22050
OUT = os.path.join(os.path.dirname(__file__), '..', 'audio')
rnd = random.Random(1337)

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
def ramp(n, a=0.3, rel=0.05):
    out = []
    for i in range(n):
        t = i / SR; T = n / SR
        out.append(min(1.0, t / max(1e-4, a)) * min(1.0, (T - t) / max(1e-4, rel)))
    return out
def mul(x, e): return [v * w for v, w in zip(x, e)]
def scale(x, k): return [v * k for v in x]
def tone(f0, f1, d, h2=0.15, sq=0.0):
    n = N(d); ph = 0.0; out = []
    for i in range(n):
        f = f0 * (f1 / f0) ** (i / max(1, n - 1)); ph += 2 * math.pi * f / SR
        s = math.sin(ph)
        if sq: s = (1 - sq) * s + sq * (1.0 if s > 0 else -1.0)
        out.append(s + h2 * math.sin(2 * ph))
    return out
def bell(f, d=0.5, decay=0.16):
    n = N(d); e = env(n, 0.003, decay)
    return [(math.sin(2 * math.pi * f * i / SR) + 0.4 * math.sin(2 * math.pi * f * 2.76 * i / SR) + 0.2 * math.sin(2 * math.pi * f * 5.4 * i / SR)) * e[i] for i in range(n)]
def crackle(d, rate=180, dec=0.004):
    """random sharp clicks: electric crackle"""
    n = N(d); out = [0.0] * n
    t = 0
    while t < n:
        t += int(SR / rate * rnd.uniform(0.3, 1.7))
        a = rnd.uniform(0.4, 1.0) * rnd.choice([-1, 1])
        for j in range(N(dec * 4)):
            if t + j < n: out[t + j] += a * math.exp(-j / (SR * dec)) * rnd.uniform(0.6, 1.0)
    return out
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

# ------------------------------------------------------------ Vireo
snap = mul(bp(noise(0.03), 1800, 6000), env(N(0.03), 0.0005, 0.006))
save('vv_bolt', mix(scale(snap, 1.3),
    scale(at(mul(hp(crackle(0.16, 420, 0.0015), 1500), env(N(0.16), 0.002, 0.06)), 0.01), 0.9),
    scale(at(mul(tone(1900, 700, 0.1, 0.1, 0.5), env(N(0.1), 0.002, 0.03)), 0.01), 0.35)), -18)
save('vv_static_full', mix(scale(mul(hp(noise(0.35), 3000), env(N(0.35), 0.001, 0.05)), 1.0),
    scale(mul(hp(crackle(0.5, 300, 0.002), 2000), env(N(0.5), 0.01, 0.2)), 0.7),
    scale(at(bell(3300, 0.4, 0.1), 0.02), 0.3)), -16)
n = N(0.65)
save('vv_surge_charge', mix(scale(mul(tone(120, 360, 0.65, 0.5, 0.7), ramp(n, 0.5, 0.05)), 0.6),
    scale(mul(hp(crackle(0.65, 260, 0.0015), 1800), ramp(n, 0.4, 0.05)), 0.8)), -19)
save('vv_surge_go', mix(scale(mul(hp(noise(0.25), 2500), env(N(0.25), 0.0005, 0.03)), 1.2),
    scale(mul(bp(noise(0.45), 300, 2500), [math.sin(math.pi * i / N(0.45)) for i in range(N(0.45))]), 0.6),
    scale(mul(tone(900, 160, 0.4, 0.2, 0.4), env(N(0.4), 0.003, 0.15)), 0.4)), -15)
save('vv_rod_summon', mix(scale(mul(tone(500, 1500, 0.2, 0.3), env(N(0.2), 0.002, 0.08)), 0.6),
    scale(mul(hp(crackle(0.3, 350, 0.0015), 2000), env(N(0.3), 0.004, 0.12)), 0.7),
    scale(bell(1800, 0.3, 0.08), 0.3)), -18)
save('vv_rod_full', mix(scale(bell(2400, 0.5, 0.18), 0.8), scale(mul(tone(240, 240, 0.4, 0.3, 0.3), env(N(0.4), 0.01, 0.15)), 0.4)), -17)
save('vv_rod_throw', mix(scale(mul(hp(noise(0.06), 2000), env(N(0.06), 0.0005, 0.01)), 1.4),
    scale(mul(tone(2600, 500, 0.3, 0.1, 0.6), env(N(0.3), 0.002, 0.1)), 0.5),
    scale(mul(hp(crackle(0.35, 300, 0.0015), 1800), env(N(0.35), 0.003, 0.12)), 0.7)), -15)
save('vv_orb', mix(scale(mul(tone(330, 300, 0.4, 0.4), env(N(0.4), 0.01, 0.15)), 0.7),
    scale(mul(hp(crackle(0.4, 120, 0.002), 1500), env(N(0.4), 0.01, 0.15)), 0.5)), -19)
save('vv_sky_place', mix(scale(mul(tone(200, 140, 0.1, 0.2), env(N(0.1), 0.001, 0.03)), 0.8),
    scale(mul(bp(noise(0.3), 1500, 6000), env(N(0.3), 0.03, 0.1)), 0.4)), -19)
n = N(0.8)
save('vv_sky_count', mix(scale(mul(tone(180, 720, 0.8, 0.3, 0.3), ramp(n, 0.7, 0.03)), 0.5),
    scale(mul(hp(crackle(0.8, 160, 0.002), 1800), ramp(n, 0.6, 0.03)), 0.6)), -20)
save('vv_sky_strike', mix(scale(mul(hp(noise(0.12), 1500), env(N(0.12), 0.0005, 0.02)), 1.5),
    scale(mul(lp(noise(1.1), 220), env(N(1.1), 0.01, 0.35)), 1.6),
    scale(mul(tone(110, 45, 0.6), env(N(0.6), 0.003, 0.2)), 0.8),
    scale(mul(hp(crackle(0.5, 250, 0.002), 2000), env(N(0.5), 0.002, 0.15)), 0.5)), -14)

# ------------------------------------------------------------ Venator
save('vn_rifle', mix(scale(mul(bp(noise(0.06), 1200, 7000), env(N(0.06), 0.0005, 0.012)), 1.3),
    scale(mul(tone(160, 70, 0.09), env(N(0.09), 0.001, 0.03)), 0.9),
    scale(at(bell(3100, 0.12, 0.03), 0.005), 0.18)), -17)
clk = mul(bp(noise(0.02), 2000, 8000), env(N(0.02), 0.0005, 0.004))
save('vn_cock', mix(scale(clk, 1.0), scale(at(clk, 0.09), 0.8), scale(at(bell(2300, 0.1, 0.03), 0.09), 0.2)), -20)
save('vn_throw', scale(mul(bp(noise(0.3), 400, 2200), [math.sin(math.pi * i / N(0.3)) ** 2 for i in range(N(0.3))]), 1.0), -20)
beeps = mix(*[at(mul(tone(1800, 1800, 0.04, 0.0, 0.8), env(N(0.04), 0.001, 0.02)), 0.12 + 0.11 * k * (1 - 0.06 * k)) for k in range(7)])
save('vn_stick', mix(scale(mul(bp(noise(0.08), 600, 4000), env(N(0.08), 0.0005, 0.02)), 1.2), scale(bell(900, 0.25, 0.06), 0.4), scale(beeps, 0.45)), -18)
save('vn_blast', mix(scale(mul(lp(noise(0.9), 400), env(N(0.9), 0.002, 0.25)), 1.8),
    scale(mul(tone(90, 35, 0.5), env(N(0.5), 0.002, 0.18)), 1.0),
    scale(mul(hp(noise(0.4), 2500), env(N(0.4), 0.001, 0.08)), 0.6)), -13)
n = N(0.55)
save('vn_slide', scale(mul(bp(noise(0.55), 250, 1800), [math.sin(math.pi * i / n) * (0.7 + 0.3 * math.sin(i / SR * 90)) for i in range(n)]), 1.0), -20)
n = N(0.62)
save('vn_ion_charge', mix(scale(mul(tone(300, 1600, 0.62, 0.3), ramp(n, 0.58, 0.02)), 0.7),
    scale(mul(tone(605, 3220, 0.62, 0.0), ramp(n, 0.6, 0.02)), 0.2)), -20)
save('vn_ion_fire', mix(scale(mul(bp(noise(0.9), 200, 5000), env(N(0.9), 0.002, 0.3)), 1.2),
    scale(mul(tone(70, 40, 0.5), env(N(0.5), 0.001, 0.2)), 1.2),
    scale(mul(tone(1200, 400, 0.7, 0.4, 0.5), env(N(0.7), 0.002, 0.25)), 0.35)), -13)
save('vn_stim', mix(scale(mul(tone(660, 660, 0.08, 0.2), env(N(0.08), 0.002, 0.04)), 0.7),
    scale(at(mul(tone(990, 990, 0.12, 0.2), env(N(0.12), 0.002, 0.06)), 0.08), 0.7)), -19)
print('vireo + venator sounds written')
