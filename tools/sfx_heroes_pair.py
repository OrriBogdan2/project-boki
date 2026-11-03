"""Sounds for Dredge and Cinder (id ashwick), pure Python (no numpy). Run: python3 tools/sfx_heroes_pair.py
then: godot --headless --import. 44.1 kHz mono 16-bit, original synthesis."""
import math, os, random, struct, wave

SR = 44100
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'audio')
rnd = random.Random(7741)

def n(d): return int(SR * d)

def lp(x, hz):
    a = 1.0 - math.exp(-2 * math.pi * hz / SR); y = 0.0; out = []
    for v in x:
        y += a * (v - y); out.append(y)
    return out

def hp(x, hz):
    l = lp(x, hz); return [a - b for a, b in zip(x, l)]

def noise(d): return [rnd.uniform(-1, 1) for _ in range(n(d))]

def env(x, a=0.002, tau=0.1):
    return [v * min(1.0, i / max(1, a * SR)) * math.exp(-(i / SR) / tau) for i, v in enumerate(x)]

def sine(d, f0, f1=None, ph=0.0):
    f1 = f0 if f1 is None else f1; N = n(d); out = []; p = ph
    for i in range(N):
        f = f0 + (f1 - f0) * (i / N); p += 2 * math.pi * f / SR; out.append(math.sin(p))
    return out

def mix(*parts):
    L = max(len(p[0]) for p in parts); out = [0.0] * L
    for x, g in parts:
        for i, v in enumerate(x): out[i] += v * g
    return out

def norm(x, peak=0.8):
    m = max(abs(v) for v in x) or 1.0
    return [max(-1.0, min(1.0, v / m * peak)) for v in x]

def save(name, x):
    x = norm(x)
    with wave.open(os.path.join(OUT, name + '.wav'), 'wb') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes(b''.join(struct.pack('<h', int(v * 32000)) for v in x))

# Dredge: a rope whip-crack, then a chain clank
crack = env(hp(noise(0.12), 2500), 0.0005, 0.02)
clank = mix((env(sine(0.5, 540), 0.001, 0.12), 0.5), (env(sine(0.5, 1130), 0.001, 0.08), 0.35), (env(sine(0.5, 1710), 0.001, 0.05), 0.25))
whoosh = env(lp(noise(0.3), 1800), 0.05, 0.1)
save('dr_haul', mix((whoosh, 0.6), (crack + [0.0] * n(0.0), 0.0), ([0.0] * n(0.14) + crack, 0.9), ([0.0] * n(0.16) + clank, 0.6)))
# Dredge: the anchor lands: a deep gong thud
thud = env(sine(0.9, 95, 45), 0.002, 0.25)
gong = mix((env(sine(1.4, 196), 0.004, 0.5), 0.5), (env(sine(1.4, 313), 0.004, 0.4), 0.35), (env(sine(1.4, 481), 0.004, 0.3), 0.25))
save('dr_anchor', mix((thud, 1.0), (gong, 0.6), (env(lp(noise(0.25), 900), 0.001, 0.06), 0.7)))
# stack gained: a bright brass bell
save('pay_salvage', mix((env(sine(1.1, 880), 0.002, 0.35), 0.6), (env(sine(1.1, 1318), 0.002, 0.25), 0.4), (env(sine(1.1, 2217), 0.002, 0.15), 0.25), (env(sine(1.1, 440), 0.002, 0.5), 0.4)))
# Cinder: the torch roar, a looping-friendly hiss with crackle
base = env(lp(noise(0.45), 2200), 0.06, 0.3)
crk = [0.0] * n(0.45)
for _ in range(14):
    i = rnd.randrange(0, n(0.4)); 
    for j in range(60): crk[i + j] += rnd.uniform(-1, 1) * math.exp(-j / 12.0)
save('as_flame', mix((base, 0.8), (hp(crk, 1500), 0.5), (env(sine(0.45, 110, 90), 0.05, 0.3), 0.3)))
# a foe flashes over: a soft whump and a crackle burst
whump = env(sine(0.6, 150, 55), 0.003, 0.18)
crk2 = [0.0] * n(0.7)
for _ in range(40):
    i = rnd.randrange(0, n(0.6))
    for j in range(40): crk2[i + j] += rnd.uniform(-1, 1) * math.exp(-j / 8.0)
save('as_ignite', mix((whump, 1.0), (env(lp(noise(0.5), 1200), 0.01, 0.2), 0.5), (hp(crk2, 2000), 0.5)))
# the cloak goes off: a rising roar that breaks on a boom
rise = [v * (i / n(0.5)) for i, v in enumerate(lp(noise(0.5), 1400))]
boom = [0.0] * n(0.5) + env(sine(0.5, 90, 40), 0.002, 0.2)
save('as_cloak', mix((rise + [0.0] * n(0.5), 0.8), (boom, 1.0), ([0.0] * n(0.5) + env(lp(noise(0.5), 2500), 0.002, 0.15), 0.7)))
print('ok')
