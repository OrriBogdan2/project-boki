"""Per-ability sounds for Linwick and Dredge (kitfix pass), pure Python (no numpy), original synthesis.
Run: python3 tools/sfx_linwick_dredge.py, then: godot --headless --import. 44.1 kHz mono 16-bit.
The names are registered at run time by scripts/arch/kits/ld_sfx.gd (LDSfx.NAMES)."""
import math, os, random, struct, wave

SR = 44100
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'audio')
rnd = random.Random(90517)

def n(d): return int(SR * d)
def lp(x, hz):
    a = 1.0 - math.exp(-2 * math.pi * hz / SR); y = 0.0; out = []
    for v in x:
        y += a * (v - y); out.append(y)
    return out
def hp(x, hz):
    l = lp(x, hz); return [a - b for a, b in zip(x, l)]
def bp(x, lo, hi): return hp(lp(x, hi), lo)
def noise(d): return [rnd.uniform(-1, 1) for _ in range(n(d))]
def env(x, a=0.002, tau=0.1):
    return [v * min(1.0, i / max(1, a * SR)) * math.exp(-(i / SR) / tau) for i, v in enumerate(x)]
def ramp(x, a, b):
    N = len(x); return [v * (a + (b - a) * i / max(1, N)) for i, v in enumerate(x)]
def sine(d, f0, f1=None):
    f1 = f0 if f1 is None else f1; N = n(d); out = []; p = 0.0
    for i in range(N):
        f = f0 + (f1 - f0) * (i / N); p += 2 * math.pi * f / SR; out.append(math.sin(p))
    return out
def saw(d, f0, f1=None):
    f1 = f0 if f1 is None else f1; N = n(d); out = []; p = 0.0
    for i in range(N):
        f = f0 + (f1 - f0) * (i / N); p = (p + f / SR) % 1.0; out.append(2 * p - 1)
    return out
def pad(x, d): return [0.0] * n(d) + x
def mix(*parts):
    L = max(len(p[0]) for p in parts); out = [0.0] * L
    for x, g in parts:
        for i, v in enumerate(x): out[i] += v * g
    return out
def crackle(d, count, decay=10.0):
    x = [0.0] * n(d)
    for _ in range(count):
        i = rnd.randrange(0, max(1, n(d) - 80))
        for j in range(60): x[i + j] += rnd.uniform(-1, 1) * math.exp(-j / decay)
    return x
def fade_out(x, d=0.03):
    N = len(x); k = n(d)
    return [v * min(1.0, (N - i) / max(1, k)) for i, v in enumerate(x)]
def norm(x, peak=0.8):
    m = max(abs(v) for v in x) or 1.0
    return [max(-1.0, min(1.0, v / m * peak)) for v in x]
def save(name, x, peak=0.8):
    x = norm(fade_out(x), peak)
    with wave.open(os.path.join(OUT, name + '.wav'), 'wb') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes(b''.join(struct.pack('<h', int(v * 32000)) for v in x))

# ---------------------------------------------------------------- Linwick
# pilot: a gas tick and a soft blue whoomp as the pilot catches
save('lw_pilot', mix((env(hp(noise(0.04), 3000), 0.0005, 0.01), 0.6), (pad(env(lp(noise(0.25), 900), 0.02, 0.08), 0.03), 0.7), (pad(env(sine(0.2, 220, 140), 0.01, 0.06), 0.03), 0.4)))
# the hose roar: a broad, breathy jet with a low rumble and fine crackle (one 0.5 s take the kit re-triggers)
jet = ramp(bp(noise(0.55), 250, 3200), 0.6, 1.0)
save('lw_roar', mix((jet, 0.8), (lp(noise(0.55), 160), 0.9), (hp(crackle(0.55, 22, 8.0), 2500), 0.35)), 0.7)
# Cinder Shot release: a tight whoosh that climbs, with a cough of flame
save('lw_bolt', mix((env(bp(noise(0.35), 600, 4000), 0.01, 0.12), 0.8), (env(sine(0.3, 180, 520), 0.004, 0.09), 0.45), (env(lp(noise(0.08), 700), 0.001, 0.02), 0.7)))
# Cinder Shot hit: a bright crack, then embers fizzling away
save('lw_bolt_hit', mix((env(hp(noise(0.08), 1800), 0.0005, 0.02), 0.9), (env(sine(0.4, 140, 60), 0.002, 0.1), 0.6), (pad(env(hp(crackle(0.6, 30, 6.0), 3000), 0.01, 0.25), 0.04), 0.5)))
# Soot Ram: a rushing roar into a heavy fiery thud
rush = ramp(bp(noise(0.22), 300, 2500), 0.2, 1.0)
save('lw_bash', mix((rush + [0.0] * n(0.3), 0.7), (pad(env(sine(0.4, 110, 45), 0.002, 0.14), 0.2), 0.9), (pad(env(lp(noise(0.3), 1200), 0.002, 0.1), 0.2), 0.6)))
save('lw_bash_hit', mix((env(sine(0.5, 95, 40), 0.001, 0.16), 1.0), (env(bp(noise(0.4), 200, 2000), 0.001, 0.12), 0.7), (pad(env(hp(crackle(0.5, 20, 7.0), 2200), 0.01, 0.2), 0.05), 0.4)))
# Furnace Cloak: a 0.2 s inhale (rising hiss), then the sunburst boom, then a low swirling hum for the shield
inhale = [v * (i / n(0.2)) ** 2 for i, v in enumerate(bp(noise(0.2), 800, 5000))]
boom = env(sine(0.7, 85, 38), 0.002, 0.22)
hum = env(mix((sine(1.2, 150), 0.5), (sine(1.2, 151.7), 0.5)), 0.08, 0.5)
save('lw_shield', mix((inhale + [0.0] * n(1.4), 0.6), (pad(boom, 0.2), 1.0), (pad(env(lp(noise(0.5), 2200), 0.002, 0.14), 0.2), 0.7), (pad(hum, 0.3), 0.25)))
# Flashover: a burn upgrades - a deep whump with a hiss that swells
save('lw_blaze', mix((env(sine(0.6, 130, 50), 0.003, 0.2), 0.9), (ramp(env(bp(noise(0.6), 900, 4000), 0.05, 0.3), 1.0, 0.3), 0.5), (hp(crackle(0.6, 28, 7.0), 2000), 0.4)))
# the fire trail lays down: a sizzle like water on a hot plate
save('lw_trail', mix((env(hp(noise(0.7), 2500), 0.03, 0.3), 0.7), (hp(crackle(0.7, 50, 4.0), 3500), 0.5)), 0.6)
# Linwick's air hop (the class air dash): a short flame-jet puff
save('lw_hop', mix((env(bp(noise(0.25), 400, 3000), 0.005, 0.07), 0.8), (env(sine(0.2, 260, 120), 0.003, 0.05), 0.4)))

# ---------------------------------------------------------------- Dredge
# scattergun: a fat low boom with a metal ring and a slug rattle
save('dr_shot', mix((env(sine(0.4, 120, 55), 0.0005, 0.08), 1.0), (env(lp(noise(0.25), 2400), 0.0005, 0.05), 0.9), (env(sine(0.4, 1460), 0.001, 0.06), 0.12), (pad(env(hp(crackle(0.2, 8, 5.0), 3000), 0.002, 0.05), 0.06), 0.25)))
# Grapnel throw: rope whirring off the drum (a ratchet), a whip of air
rat = [0.0] * n(0.4)
for k in range(16):
    i = n(0.012 + k * 0.022)
    for j in range(200): rat[i + j] += math.sin(j * 0.9) * math.exp(-j / 40.0)
save('dr_throw', mix((rat, 0.5), (env(bp(noise(0.4), 500, 3500), 0.03, 0.12), 0.7), (env(sine(0.35, 300, 700), 0.01, 0.1), 0.25)))
# the claw bites: a clamp and a chain clank
save('dr_grab', mix((env(hp(noise(0.05), 1500), 0.0003, 0.012), 0.8), (env(sine(0.5, 610), 0.001, 0.1), 0.45), (env(sine(0.5, 1290), 0.001, 0.07), 0.3), (env(sine(0.5, 95, 70), 0.001, 0.08), 0.6)))
# the reel: a slow, heavy drum ratchet with a strained rope creak
rr = [0.0] * n(1.0)
for k in range(12):
    i = n(0.02 + k * 0.08)
    for j in range(500): rr[i + j] += (math.sin(j * 0.32) + 0.4 * math.sin(j * 0.71)) * math.exp(-j / 90.0)
save('dr_reel', mix((rr, 0.6), (lp(saw(1.0, 70, 82), 400), 0.25)))
# Barge: a shove of air into a meaty shoulder thud
save('dr_barge', mix((ramp(bp(noise(0.2), 150, 1500), 1.0, 0.2), 0.7), (env(sine(0.4, 75, 40), 0.002, 0.12), 1.0), (env(lp(noise(0.12), 700), 0.001, 0.04), 0.6)))
# Anchor Drop wind-up: a creaking heave (rising saw through a low pass)
save('dr_anchor_wind', mix((env(lp(saw(0.4, 55, 110), 600), 0.08, 0.3), 0.6), (env(bp(noise(0.4), 300, 1200), 0.1, 0.2), 0.4)))
# the dive: a falling whistle
save('dr_dive', mix((env(sine(0.6, 1100, 380), 0.02, 0.4), 0.35), (env(bp(noise(0.6), 600, 2400), 0.05, 0.4), 0.5)))
# the air smash lands: a huge quake - a sub thud, a bell-like iron clang and a long rumble
save('dr_quake', mix((env(sine(1.2, 70, 30), 0.001, 0.35), 1.0), (env(sine(1.2, 196), 0.002, 0.3), 0.35), (env(sine(1.2, 297), 0.002, 0.25), 0.25), (env(lp(noise(1.2), 500), 0.002, 0.45), 0.8)))
# Dredge's air hop (the class air dash): a heavy whump of air
save('dr_hop', mix((env(bp(noise(0.25), 120, 1200), 0.005, 0.08), 0.8), (env(sine(0.25, 90, 60), 0.003, 0.07), 0.6)))
print('ok')
