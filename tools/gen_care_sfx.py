"""Synthesizes the support pair's sounds into audio/*.wav (pure Python, own random stream, so gen_sfx.py output is untouched).

    python3 tools/gen_care_sfx.py      (then: godot --headless --import)

tend_* : Moosh Moosh's warm, wooden and lantern-bright sounds. rime_* : Tamsin's glassy, gliding, cracking ones.
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

# ---- Moosh Moosh: wood, wick and lantern glass
def chirp(f0, f1, d, a=0.004, dec=0.08): return mul(tone(f0, f1, d, 0.1), env(N(d), a, dec))
def hiss(d, lo, hi, a=0.003, dec=0.05): return mul(bp(noise(d), lo, hi), env(N(d), a, dec))
def rise(d, lo, hi):
    n = N(d); x = bp(noise(d), lo, hi)
    return [v * (i / n) ** 1.5 for i, v in enumerate(x)]
def trem(x, hz, depth=0.5): return [v * (1 - depth + depth * math.sin(2 * math.pi * hz * i / SR)) for i, v in enumerate(x)]
def sparkle(n, d, lo=2400, hi=5200, gap=0.03):
    return mix(*[at(scale(bell(rnd.uniform(lo, hi), 0.25, 0.05), rnd.uniform(0.3, 0.7)), i * gap + rnd.uniform(0, gap * 0.5)) for i in range(n)]) if n else [0.0]

# ---- Moosh Moosh: wood, wick and lantern glass
# Moon Shot: a soft wooden flick, a moth-wing whoosh and a little lantern chime on top
save('tend_ember', mix(scale(chirp(900, 420, 0.12, 0.003, 0.04), 0.5), scale(hiss(0.14, 1500, 5000, 0.002, 0.03), 0.5), scale(bell(1320, 0.18, 0.05), 0.3)), -23)
# the Empowered shot: the same flick, deeper, with a brighter two-note chime
save('tend_ember_emp', mix(scale(chirp(700, 300, 0.18, 0.003, 0.06), 0.6), scale(hiss(0.2, 1200, 4500, 0.002, 0.05), 0.5), scale(bell(1320, 0.3, 0.08), 0.5), scale(at(bell(1760, 0.3, 0.08), 0.05), 0.45)), -21)
# Burrseed held: a dry rattle of seed husks rising under the fingers
save('tend_seed_aim', mix(scale(trem(rise(0.6, 600, 2400), 22, 0.7), 0.7), scale(mul(tone(180, 260, 0.6), env(N(0.6), 0.2, 0.6)), 0.3)), -26)
# Burrseed thrown: a whippy wooden snap and a rush of air
save('tend_seed', mix(chirp(300, 620, 0.14, 0.003, 0.05), scale(hiss(0.22, 400, 1800, 0.01, 0.07), 0.6), scale(hiss(0.05, 2000, 6000, 0.001, 0.01), 0.5)), -20)
# Burrseed sticks: a thorny thock and the disc humming up under the foe
save('tend_stick', mix(hiss(0.1, 700, 3000, 0.002, 0.03), scale(chirp(220, 150, 0.1, 0.002, 0.03), 0.6), scale(mul(tone(330, 440, 0.6), env(N(0.6), 0.1, 0.4)), 0.35)), -21)
# Burrseed bursts: roots cracking out of the ground with a low thump and a violet shimmer
save('tend_root', mix(scale(mul(lp(noise(0.5), 900), env(N(0.5), 0.02, 0.16)), 0.9), scale(chirp(110, 55, 0.45, 0.005, 0.15), 0.8), at(scale(hiss(0.25, 1200, 4000, 0.003, 0.05), 0.5), 0.04), scale(at(sparkle(5, 0.3, 1800, 3200, 0.04), 0.06), 0.5)), -17)
# Hearthlight lit: three warm bells climbing and a breath of rising air
save('tend_hearth', mix(bell(587, 0.7, 0.28), scale(at(bell(784, 0.6, 0.24), 0.08), 0.7), scale(at(bell(988, 0.5, 0.2), 0.16), 0.5), scale(rise(0.35, 800, 3000), 0.3)), -21)
# Hearthlight thrown: a quick airy swoop
save('tend_toss', mix(scale(hiss(0.24, 500, 2600, 0.04, 0.08), 0.5), chirp(500, 1100, 0.2, 0.02, 0.08)), -21)
# ... landing on the cursor: a soft glassy bloom
save('tend_land', mix(bell(880, 0.5, 0.18), scale(bell(1320, 0.4, 0.14), 0.5), scale(mul(lp(noise(0.3), 600), env(N(0.3), 0.01, 0.1)), 0.5)), -21)
save('tend_flare', mix(bell(523, 0.9, 0.35), scale(bell(659, 0.9, 0.3), 0.8), scale(bell(784, 0.9, 0.3), 0.7), scale(hiss(0.5, 1500, 6000, 0.01, 0.15), 0.4)), -18)
# Relay Step: a light hop, a skip of cloth and wood
save('tend_hop', mix(scale(hiss(0.16, 600, 2500, 0.004, 0.05), 0.7), scale(chirp(420, 260, 0.08, 0.002, 0.03), 0.5)), -23)
# ... through a teammate: a bright little two-bell "pass"
save('tend_relay', mix(bell(1046, 0.4, 0.12), scale(at(bell(1568, 0.4, 0.12), 0.06), 0.8)), -21)
# Bearer: hoisting someone onto the pack: a grunt of leather and a wooden creak
save('tend_pickup', mix(scale(mul(lp(noise(0.3), 500), env(N(0.3), 0.03, 0.1)), 0.8), scale(trem(chirp(160, 120, 0.3, 0.02, 0.15), 30, 0.6), 0.6)), -20)
# Kindled to 5: a crackle of catching embers
save('tend_kindled', mix(*[at(scale(hiss(0.03, 2000, 7000, 0.001, 0.008), rnd.uniform(0.4, 1.0)), rnd.uniform(0, 0.25)) for _ in range(9)] + [scale(chirp(260, 520, 0.2, 0.01, 0.1), 0.4)]), -21)

# ---- Tamsin: ice, blades, glass
# Ice Dart: a thin glassy flick
save('rime_shard', mix(scale(chirp(2300, 1500, 0.07, 0.002, 0.025), 0.6), scale(mul(hp(noise(0.08), 3500), env(N(0.08), 0.001, 0.02)), 0.6)), -24)
# ... skating: a heavier, straighter crack of a lance of ice
save('rime_beam', mix(scale(chirp(1600, 900, 0.12, 0.002, 0.05), 0.7), scale(mul(hp(noise(0.14), 2500), env(N(0.14), 0.001, 0.04)), 0.7), scale(bell(2600, 0.2, 0.05), 0.3)), -21)
# Ice Spear held: crystal growing in the hand, a rising glassy shimmer
save('rime_spear_aim', mix(scale(rise(0.6, 3000, 8000), 0.5), scale(sparkle(8, 0.6, 2600, 5600, 0.06), 0.6)), -26)
save('rime_lance', mix(scale(chirp(380, 1500, 0.2, 0.01, 0.08), 0.7), scale(hiss(0.25, 1500, 6000, 0.02, 0.09), 0.7)), -20)
# the spear lands: a crunch into ice and the slow zone's cold whistle
save('rime_zone', mix(hiss(0.12, 1000, 4000, 0.001, 0.03), scale(mul(tone(1200, 1000, 0.8), env(N(0.8), 0.2, 0.5)), 0.25), scale(sparkle(4, 0.4, 3000, 5000, 0.08), 0.4)), -21)
# ... detonating: a deep crack and a spray of glass
save('rime_burst', mix(mul(hp(noise(0.45), 2500), env(N(0.45), 0.002, 0.11)), scale(chirp(700, 160, 0.3, 0.003, 0.1), 0.7), scale(bell(2200, 0.4, 0.1), 0.4), scale(at(sparkle(6, 0.4, 3000, 6000, 0.03), 0.03), 0.5)), -16)
save('rime_splinter', mix(mul(hp(noise(0.7), 1800), env(N(0.7), 0.001, 0.18)), scale(chirp(160, 55, 0.5, 0.002, 0.14), 0.9), scale(bell(1800, 0.7, 0.16), 0.5), scale(at(bell(2600, 0.5, 0.12), 0.06), 0.4), scale(at(sparkle(8, 0.5, 2500, 6000, 0.025), 0.04), 0.5)), -14)
sk = noise(0.6); e = env(N(0.6), 0.04, 0.5)
save('rime_run', scale([v * (0.5 + 0.5 * math.sin(2 * math.pi * 9 * i / SR)) * e[i] for i, v in enumerate(bp(sk, 2000, 7000))], 0.8), -26)
# the hockey stop: a hard scrape of blades
save('rime_stop', mix(scale(mul(bp(noise(0.3), 2500, 8000), env(N(0.3), 0.005, 0.12)), 0.9), scale(trem(hiss(0.3, 1500, 5000, 0.005, 0.12), 60, 0.5), 0.5)), -21)
# the wall's tell: a sparkle gathering at her feet
save('rime_wall_tell', mix(scale(sparkle(6, 0.25, 3000, 6500, 0.03), 0.8), scale(rise(0.22, 4000, 9000), 0.4)), -24)
save('rime_wall', mix(scale(chirp(120, 80, 0.5, 0.01, 0.15), 0.9), scale(hiss(0.5, 600, 3500, 0.03, 0.15), 0.7), scale(bell(1400, 0.5, 0.15), 0.4), scale(mul(lp(noise(0.35), 300), env(N(0.35), 0.005, 0.12)), 0.8)), -16)
save('rime_freeze', mix(bell(1900, 0.5, 0.14), scale(hiss(0.3, 3000, 8000, 0.002, 0.07), 0.6), scale(chirp(240, 120, 0.2, 0.002, 0.06), 0.5)), -19)
# the air dash: a spinning whirl of cold air
save('rime_flip', mix(scale(trem(hiss(0.3, 900, 5000, 0.03, 0.12), 14, 0.6), 0.8), scale(bell(3000, 0.2, 0.06), 0.3)), -22)
# the frost shield on a teammate: a soft crystalline chime
save('rime_ward', mix(bell(1568, 0.5, 0.16), scale(at(bell(2093, 0.45, 0.14), 0.05), 0.6), scale(sparkle(3, 0.3, 3000, 5000, 0.05), 0.4)), -21)
# ---- the ultimates on X (appended last, so the random stream above is unchanged)
def choir(d, notes, vib=5.0):
    n = N(d); out = [0.0] * n
    for f in notes:
        ph = 0.0
        for i in range(n):
            ph += 2 * math.pi * f * (1 + 0.004 * math.sin(2 * math.pi * vib * i / SR)) / SR
            out[i] += math.sin(ph) + 0.3 * math.sin(2 * ph) + 0.12 * math.sin(3 * ph)
    return mul(out, env(n, d * 0.35, d * 0.9))
# Hearth Call cast: a soft rising choir swell under a lantern chime
save('tend_call', mix(scale(choir(1.1, [392, 494, 587]), 0.5), bell(784, 0.6, 0.22), scale(at(bell(1175, 0.5, 0.18), 0.07), 0.5), scale(rise(0.5, 900, 3500), 0.25)), -18)
# ... the channel: a low warm hum, replayed under the sparkles
save('tend_call_hum', mix(scale(trem(choir(0.6, [294, 440]), 4, 0.3), 0.7), scale(sparkle(3, 0.4, 2600, 4200, 0.12), 0.3)), -24)
# ... the teammate arrives: a bright two-bell chime and a whoosh in
save('tend_arrive', mix(scale(rise(0.25, 600, 4000), 0.6), at(bell(1046, 0.7, 0.25), 0.18), scale(at(bell(1568, 0.6, 0.2), 0.24), 0.7), scale(at(choir(0.6, [523, 659, 784]), 0.18), 0.35)), -16)
# Rimelock sealed: a crackling freeze closing in, a glassy ring
save('rime_lock', mix(*[at(scale(hiss(0.04, 2500, 8000, 0.001, 0.01), rnd.uniform(0.3, 0.9)), i * 0.025 + rnd.uniform(0, 0.02)) for i in range(14)] + [scale(chirp(900, 2200, 0.35, 0.02, 0.2), 0.4), scale(bell(2400, 0.6, 0.2), 0.4)]), -18)
# ... the hold: ice creaking under strain
save('rime_creak', mix(scale(trem(mul(bp(noise(0.35), 300, 1400), env(N(0.35), 0.05, 0.2)), 38, 0.8), 0.9), scale(chirp(180, 140, 0.3, 0.05, 0.15), 0.4)), -22)
# ... the crash: a deep boom and a glassy shatter spraying out
save('rime_crash', mix(scale(chirp(90, 38, 0.8, 0.003, 0.3), 1.0), mul(hp(noise(0.9), 2200), env(N(0.9), 0.001, 0.22)), scale(bell(1700, 0.9, 0.25), 0.5), scale(at(bell(2500, 0.7, 0.2), 0.04), 0.4), scale(at(sparkle(14, 0.8, 2500, 7000, 0.035), 0.03), 0.6)), -12)
# ... an early break: one short crack of the shell
save('rime_crack', mix(mul(hp(noise(0.2), 2000), env(N(0.2), 0.001, 0.05)), scale(chirp(400, 200, 0.12, 0.002, 0.05), 0.5)), -19)
print('support sounds written')
