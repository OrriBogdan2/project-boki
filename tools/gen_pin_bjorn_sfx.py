"""Synthesizes Pin's and Bjorn's ability sounds into audio/*.wav (mono, 22.05 kHz, 16-bit).

    python3 tools/gen_pin_bjorn_sfx.py      (then: godot --headless --import)

Pure Python (math, random, wave): no numpy. Every sound is original, made here from noise, sines and
envelopes; its own random stream, so no other generator's output changes. Sfx loads these on first use.

Pin (archer)
  pin_draw         the bow drawn: a rising wooden creak of the limbs and a soft string stretch
  pin_stage        Empowered ready: a small bright ping with a short shimmer
  pin_super        Supercharged ready: a fuller two-note chime over a low swell
  pin_perfect      the perfect release: a clean metallic shing that rings up and out
  pin_overdraw     held too long: a dull, falling creak
  pin_loose        an Empowered arrow: a taut twang and a thin air whip
  pin_loose_super  a Supercharged arrow: a heavy twang, a tearing whoosh, a bass punch
  pin_super_hit    the Supercharged hit: a glassy crack with a teal ring
  pin_heavy_draw   the Heavy Shot's draw: a deep, slow creak
  pin_heavy        the Heavy Shot loosed: a thick thrum and a low whoosh
  pin_heavy_hit    the Heavy Shot landing: a meaty thunk and a short dust burst
  pin_hail         Hail Wall cast: a flight of arrows swishing up
  pin_rain         the rain starting: a hush of many shafts falling
  pin_patter       one arrow of the rain striking: a small dry tick
  pin_spirit       Spirit Walk: a quick roll whoosh into an airy, hollow shimmer
  pin_spirit_end   Spirit Walk ending: a soft falling chime
Bjorn (bulwark)
  bjorn_throw      the hammer thrown: a heavy whoof and a tumbling whirr
  bjorn_recall     the hammer called back: a rising whirr
  bjorn_catch      the catch: a leather-and-iron slap
  bjorn_plant      the hammer landing: a thud with a ringing iron hum
  bjorn_spin       one turn of the hammer spinning in his hand: a deep whoosh
  bjorn_glint      the swing at full charge: a bright ting
  bjorn_slam       the Crushing Blow: a heavy boom, a crackle of fire, a ground thump
  bjorn_whirl      the 360 Smash's spin: a circling whoosh into a clang
  bjorn_shield_up  the aegis raised: a warm hum swelling in
  bjorn_block      the aegis stopping a hit: a bright clang
  bjorn_break      the aegis broken: a shattering ring and falling shards
  bjorn_bash       the Bash: a shield thump
  bjorn_purify     Mending Ground cast: a soft rising chord
  bjorn_purify_burst  the heal landing: a bright chord bloom
"""
import math, os, random, struct, wave

SR = 22050
OUT = os.path.join(os.path.dirname(__file__), '..', 'audio')
rnd = random.Random(2711)


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
def env(n, a=0.005, d=0.12): return [min(1.0, (i / SR) / max(1e-4, a)) * math.exp(-(i / SR) / d) for i in range(n)]
def swell(n, a): return [min(1.0, (i / SR) / a) ** 2 for i in range(n)]
def mul(x, e): return [v * w for v, w in zip(x, e)]
def scale(x, k): return [v * k for v in x]
def tone(f0, f1, d, h2=0.15, h3=0.0):
    n = N(d); ph = 0.0; out = []
    for i in range(n):
        f = f0 * (f1 / f0) ** (i / max(1, n - 1)); ph += 2 * math.pi * f / SR
        out.append(math.sin(ph) + h2 * math.sin(2 * ph) + h3 * math.sin(3 * ph))
    return out
def bell(f, d=0.5, decay=0.16, parts=(1.0, 2.76, 5.4), amps=(1.0, 0.4, 0.2)):
    n = N(d); e = env(n, 0.003, decay)
    return [sum(a * math.sin(2 * math.pi * f * p * i / SR) for p, a in zip(parts, amps)) * e[i] for i in range(n)]
def creak(d, f0, f1, rate=38.0):
    # a stick-slip creak: a buzzy tone gated by fast irregular pulses
    n = N(d); out = []; ph = 0.0; g = 0.0
    for i in range(n):
        u = i / max(1, n - 1)
        f = f0 + (f1 - f0) * u; ph += 2 * math.pi * f / SR
        if rnd.random() < rate / SR: g = 1.0
        g *= 0.997
        out.append((math.sin(ph) + 0.5 * math.sin(3 * ph) + 0.3 * math.sin(5 * ph)) * (0.25 + g))
    return bp(out, 150, 2400)
def whoosh(d, lo, hi, peak=0.5):
    n = N(d); x = noise(d)
    out = []; y = 0.0
    for i, v in enumerate(x):
        u = i / max(1, n - 1)
        hz = lo + (hi - lo) * math.sin(math.pi * u)
        a = 1 - math.exp(-2 * math.pi * hz / SR); y += a * (v - y)
        out.append(y * math.sin(math.pi * min(1.0, u / peak if u < peak else (1 - u) / (1 - peak) * 0.5 + 0.5)) * (1.0 - u) ** 0.5)
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
    for i in range(min(200, len(x))): x[-1 - i] *= i / 200
    with wave.open(os.path.join(OUT, name + '.wav'), 'wb') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes(b''.join(struct.pack('<h', int(max(-1, min(1, v)) * 32767)) for v in x))

def twang(f, d, decay, bright=1.0):
    n = N(d); e = env(n, 0.001, decay)
    return [(math.sin(2 * math.pi * f * i / SR) + 0.5 * bright * math.sin(2 * math.pi * f * 2.01 * i / SR) + 0.25 * bright * math.sin(2 * math.pi * f * 3.02 * i / SR)) * e[i] for i in range(n)]
def thud(f0, f1, d, decay):
    return mul(tone(f0, f1, d, 0.3), env(N(d), 0.002, decay))
def click(d=0.01, lo=2000, hi=9000):
    return mul(bp(noise(d), lo, hi), env(N(d), 0.0005, d * 0.3))

# ------------------------------------------------------------------ Pin
def pin():
    save('pin_draw', mix(mul(creak(0.5, 180, 320, 55), swell(N(0.5), 0.35)), scale(mul(bp(noise(0.5), 2500, 7000), swell(N(0.5), 0.45)), 0.25)), -22)
    save('pin_stage', mix(bell(2350, 0.35, 0.08), scale(at(bell(3520, 0.25, 0.05), 0.03), 0.5), scale(click(0.006, 4000, 11000), 0.6)), -20)
    save('pin_super', mix(bell(1568, 0.6, 0.18), scale(at(bell(2349, 0.55, 0.16), 0.06), 0.7),
                          scale(mul(tone(110, 160, 0.5, 0.2), mul(swell(N(0.5), 0.15), env(N(0.5), 0.001, 0.2))), 0.6)), -18)
    save('pin_perfect', mix(scale(mul(hp(noise(0.4), 5000), env(N(0.4), 0.002, 0.06)), 0.8),
                            bell(2960, 0.7, 0.22, (1.0, 1.5, 2.99), (1.0, 0.5, 0.3)), scale(at(mul(tone(1800, 4200, 0.25, 0.0), env(N(0.25), 0.01, 0.08)), 0.01), 0.35)), -16)
    save('pin_overdraw', mul(creak(0.45, 260, 140, 25), env(N(0.45), 0.02, 0.2)), -24)
    save('pin_loose', mix(twang(196, 0.35, 0.06), scale(mul(bp(noise(0.25), 1800, 6000), env(N(0.25), 0.001, 0.05)), 0.9), scale(click(0.008, 3000, 9000), 0.8)), -18)
    save('pin_loose_super', mix(twang(147, 0.5, 0.09, 1.3), scale(whoosh(0.45, 600, 5200, 0.2), 1.2), scale(thud(140, 50, 0.3, 0.07), 0.9), scale(click(0.01, 2500, 10000), 1.0)), -15)
    save('pin_super_hit', mix(scale(mul(hp(noise(0.3), 2500), env(N(0.3), 0.001, 0.04)), 1.3), bell(2637, 0.6, 0.15, (1.0, 2.0, 3.01), (0.8, 0.3, 0.2)), scale(thud(180, 60, 0.3, 0.06), 0.7)), -15)
    save('pin_heavy_draw', mul(creak(0.8, 110, 210, 30), swell(N(0.8), 0.6)), -22)
    save('pin_heavy', mix(twang(98, 0.6, 0.12, 0.9), scale(whoosh(0.5, 300, 2200, 0.25), 1.0), scale(thud(110, 45, 0.35, 0.08), 1.0)), -15)
    save('pin_heavy_hit', mix(thud(160, 55, 0.4, 0.08), scale(mul(lp(noise(0.35), 1600), env(N(0.35), 0.002, 0.1)), 0.9), scale(click(0.01, 1500, 6000), 1.0)), -15)
    vol = [0.0] * N(0.7)
    for k in range(7):
        sw = scale(mul(bp(noise(0.3), 1500 + 300 * k, 6000), env(N(0.3), 0.04, 0.08)), 0.6)
        vol = mix(vol, at(sw, 0.04 * k))
    save('pin_hail', mix(vol, scale(twang(220, 0.3, 0.05), 0.4)), -18)
    save('pin_rain', mul(mix(bp(noise(1.0), 1500, 7000), scale(lp(noise(1.0), 600), 0.4)), mul(swell(N(1.0), 0.25), env(N(1.0), 0.001, 0.6))), -21)
    save('pin_patter', mix(scale(click(0.012, 1200, 5000), 1.0), scale(thud(400, 200, 0.05, 0.015), 0.4)), -22)
    save('pin_spirit', mix(scale(whoosh(0.3, 400, 3500, 0.3), 1.0),
                           scale(at(mul(mix(tone(660, 990, 0.7, 0.0), scale(tone(990, 1480, 0.7, 0.0), 0.6)), mul(swell(N(0.7), 0.15), env(N(0.7), 0.001, 0.3))), 0.12), 0.4),
                           scale(at(mul(bp(noise(0.7), 3000, 9000), env(N(0.7), 0.1, 0.25)), 0.12), 0.3)), -18)
    save('pin_spirit_end', mix(bell(1320, 0.5, 0.14), scale(at(bell(990, 0.5, 0.14), 0.08), 0.7)), -22)

# ------------------------------------------------------------------ Bjorn
def bjorn():
    whirr = [0.0] * N(0.5)
    for k in range(5):
        whirr = mix(whirr, at(scale(whoosh(0.12, 200, 1300, 0.5), 0.8 - k * 0.12), 0.09 * k))
    save('bjorn_throw', mix(scale(whoosh(0.25, 150, 1500, 0.3), 1.3), whirr, scale(thud(90, 50, 0.2, 0.05), 0.5)), -16)
    rise = [0.0] * N(0.5)
    for k in range(6):
        rise = mix(rise, at(scale(whoosh(0.1, 250 + 80 * k, 1400 + 200 * k, 0.5), 0.3 + k * 0.1), 0.075 * k))
    save('bjorn_recall', rise, -17)
    save('bjorn_catch', mix(scale(mul(lp(noise(0.12), 2400), env(N(0.12), 0.001, 0.02)), 1.2), scale(bell(820, 0.3, 0.06, (1.0, 2.4, 3.9), (0.6, 0.3, 0.2)), 0.6)), -18)
    save('bjorn_plant', mix(thud(120, 45, 0.5, 0.1), scale(bell(310, 1.0, 0.35, (1.0, 2.32, 3.7), (0.7, 0.35, 0.2)), 0.5), scale(mul(lp(noise(0.3), 900), env(N(0.3), 0.002, 0.08)), 0.8)), -15)
    save('bjorn_spin', scale(whoosh(0.28, 120, 900, 0.45), 1.0), -20)
    save('bjorn_glint', mix(bell(3135, 0.4, 0.1, (1.0, 2.0), (1.0, 0.3)), scale(click(0.005, 5000, 11000), 0.6)), -19)
    fire = mul(mix(bp(noise(0.6), 600, 4000), scale(hp(noise(0.6), 3000), 0.3)), [rnd.uniform(0.3, 1.0) * math.exp(-i / SR / 0.25) for i in range(N(0.6))])
    save('bjorn_slam', mix(thud(95, 32, 0.7, 0.18), scale(mul(lp(noise(0.5), 700), env(N(0.5), 0.002, 0.12)), 1.0), scale(at(fire, 0.02), 0.6), scale(whoosh(0.15, 300, 2500, 0.8), 0.7)), -13)
    save('bjorn_whirl', mix(scale(whoosh(0.35, 200, 1800, 0.6), 1.2), scale(at(bell(520, 0.5, 0.12, (1.0, 2.6, 4.1), (0.6, 0.35, 0.2)), 0.28), 0.6), scale(at(thud(130, 50, 0.3, 0.06), 0.28), 0.7)), -15)
    save('bjorn_shield_up', mul(mix(tone(140, 220, 0.5, 0.4, 0.2), scale(tone(280, 440, 0.5, 0.0), 0.3), scale(bp(noise(0.5), 1500, 5000), 0.15)), mul(swell(N(0.5), 0.2), env(N(0.5), 0.001, 0.35))), -21)
    save('bjorn_block', mix(bell(740, 0.45, 0.1, (1.0, 1.59, 2.43, 3.6), (0.8, 0.5, 0.3, 0.15)), scale(click(0.01, 2000, 9000), 1.0)), -17)
    shards = [0.0] * N(0.9)
    for k in range(10):
        shards = mix(shards, at(scale(bell(rnd.uniform(1800, 4200), 0.25, 0.05), rnd.uniform(0.2, 0.5)), rnd.uniform(0.03, 0.6)))
    save('bjorn_break', mix(scale(mul(hp(noise(0.4), 1800), env(N(0.4), 0.001, 0.07)), 1.3), bell(440, 0.8, 0.2, (1.0, 1.58, 2.31, 3.47), (0.6, 0.4, 0.3, 0.2)), shards, scale(thud(110, 40, 0.4, 0.08), 0.6)), -14)
    save('bjorn_bash', mix(thud(130, 55, 0.35, 0.07), scale(bell(380, 0.4, 0.08, (1.0, 1.6, 2.4), (0.5, 0.3, 0.2)), 0.6), scale(mul(lp(noise(0.2), 1500), env(N(0.2), 0.001, 0.04)), 0.9)), -15)
    chord = mix(*[scale(mul(tone(f, f * 1.003, 1.2, 0.1), mul(swell(N(1.2), 0.6), env(N(1.2), 0.001, 0.9))), a) for f, a in [(392, 0.6), (494, 0.5), (587, 0.45), (784, 0.25)]])
    save('bjorn_purify', mix(chord, scale(mul(bp(noise(1.2), 3000, 9000), swell(N(1.2), 0.8)), 0.12)), -20)
    bloom = mix(*[scale(at(bell(f, 0.9, 0.3, (1.0, 2.0, 3.0), (1.0, 0.25, 0.1)), dt), a) for f, a, dt in [(784, 0.6, 0.0), (988, 0.5, 0.04), (1175, 0.45, 0.08), (1568, 0.3, 0.12)]])
    save('bjorn_purify_burst', mix(bloom, scale(whoosh(0.4, 800, 5000, 0.2), 0.5)), -16)

if __name__ == '__main__':
    pin()
    bjorn()
    print('wrote pin_* and bjorn_* sounds')
