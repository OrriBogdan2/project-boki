"""Synthesizes the opening drop's sounds (owner item 107) into audio/drop_*.wav. All ours: filtered noise and sines, no
samples. Standard library only; each sound is gain-set to its category's loudness (LUFS over its loudest 400 ms, measured
with ffmpeg's EBU R128 meter) under a peak ceiling, so the set sits with the rest of the mix. tools/sfx_loudness.py reads
the result.

    python3 tools/gen_drop_sfx.py [names...]      (then: godot --headless --import)
"""
import math, os, random, re, struct, subprocess, sys, wave

SR = 44100
LOOP_SR = 22050                  # the wind loops: they're long and nothing in them needs the top octave
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'audio')
CEILING_DB = -3.0                # file peak
TARGET = {'wind_low': -19.0, 'wind_high': -21.0, 'jump': -18.0, 'cloud': -19.0, 'snap': -14.0, 'land': -13.0}
R = random.Random(107)


def N(s, sr=SR):
    return int(s * sr)


def noise(n):
    return [R.uniform(-1, 1) for _ in range(n)]


def mix(*layers):
    out = [0.0] * max(len(x) for x in layers)
    for x in layers:
        for i, v in enumerate(x):
            out[i] += v
    return out


def biquad(x, kind, f0, q=0.707, sr=SR):
    """One RBJ biquad; f0 is a value or a function of 0..1 along the sound (re-solved every 32 samples)."""
    out = [0.0] * len(x)
    x1 = x2 = y1 = y2 = 0.0
    b0 = b1 = b2 = a1 = a2 = 0.0
    n = max(1, len(x))
    for i, v in enumerate(x):
        if i % 32 == 0:
            f = f0(i / n) if callable(f0) else f0
            w = 2 * math.pi * min(f, sr * 0.45) / sr
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


def env(x, f):
    n = max(1, len(x))
    return [v * f(i / n) for i, v in enumerate(x)]


def decay(x, tau, attack=0.002, sr=SR):
    a = max(1, N(attack, sr))
    return [v * min(1.0, i / a) * math.exp(-i / (tau * sr)) for i, v in enumerate(x)]


def sine_sweep(s, f, sr=SR):
    """A sine whose pitch is f(0..1)."""
    out, ph = [], 0.0
    n = N(s, sr)
    for i in range(n):
        ph += 2 * math.pi * f(i / n) / sr
        out.append(math.sin(ph))
    return out


def looped(make, secs, xfade, sr):
    """A seamless loop: the tail of a longer take fades into its head."""
    body = make(secs + xfade)
    n, x = N(secs, sr), N(xfade, sr)
    out = body[:n]
    for i in range(x):
        k = i / x
        out[i] = out[i] * math.sqrt(k) + body[n + i] * math.sqrt(1 - k)
    return out


def wind_low(s):
    """The body of the fall: a wide low roar that swells and leans, never quite steady."""
    n = N(s, LOOP_SR)
    roar = biquad(noise(n), 'lp', lambda u: 240 + 90 * math.sin(u * s * 1.3), 0.8, LOOP_SR)
    chest = biquad(noise(n), 'bp', lambda u: 95 + 30 * math.sin(u * s * 0.8 + 1.0), 0.9, LOOP_SR)
    air = biquad(noise(n), 'bp', lambda u: 620 + 240 * math.sin(u * s * 1.9 + 2.0), 0.7, LOOP_SR)
    sway = lambda u: 0.78 + 0.22 * math.sin(u * s * 2.3) * math.sin(u * s * 0.9 + 0.7)
    return env(mix([v * 0.9 for v in roar], [v * 1.2 for v in chest], [v * 0.16 for v in air]), sway)


def wind_high(s):
    """The tearing edge that comes in with speed: a hiss with a moving whistle in it and a flutter of cloth."""
    n = N(s, LOOP_SR)
    hiss = biquad(noise(n), 'bp', lambda u: 2300 + 900 * math.sin(u * s * 1.7), 0.6, LOOP_SR)
    whistle = biquad(noise(n), 'bp', lambda u: 1250 + 520 * math.sin(u * s * 2.9 + 1.0) + 170 * math.sin(u * s * 7.3), 7.0, LOOP_SR)
    flap = lambda u: 0.66 + 0.34 * abs(math.sin(u * s * 2 * math.pi * 11.0 + 3 * math.sin(u * s * 1.1)))
    return env(mix([v * 0.5 for v in hiss], [v * 1.1 for v in whistle]), flap)


def jump():
    """Stepping off: a soft boot on the ship's edge, then the air rising past you."""
    s = 1.5
    rise = biquad(noise(N(s)), 'bp', lambda u: 240 * (1600 / 240) ** (u ** 0.8), 1.1)
    rise = env(rise, lambda u: min(1.0, (u / 0.72)) ** 2 * (1.0 if u < 0.72 else ((1 - u) / 0.28) ** 1.2))
    step = decay(biquad(noise(N(0.12)), 'lp', 900), 0.03)
    low = decay(sine_sweep(0.3, lambda u: 90 - 40 * u), 0.08, 0.004)
    return mix(rise, [v * 0.7 for v in step], [v * 0.55 for v in low])


def cloud():
    """Through the cloud deck: a soft wet rush past the ear, muffled in the middle."""
    s = 1.3
    body = biquad(noise(N(s)), 'lp', lambda u: 500 + 3000 * abs(u - 0.5) ** 1.2 * 2, 0.8)
    body = env(body, lambda u: (u / 0.42 if u < 0.42 else (1 - u) / 0.58) ** 1.6)
    hush = env(biquad(noise(N(s)), 'bp', 3200, 0.7), lambda u: (u / 0.2 if u < 0.2 else (1 - u) / 0.8) ** 3)
    return mix(body, [v * 0.12 for v in hush])


def snap():
    """The glider catching: a dry crack of canvas, the bang of air filling it, a short flutter dying out."""
    crack = decay(biquad(noise(N(0.06)), 'hp', 1500), 0.0065, 0.0004)
    crack2 = [0.0] * N(0.021) + [v * 0.55 for v in decay(biquad(noise(N(0.05)), 'bp', 2400, 0.9), 0.008, 0.0004)]
    bang = decay(biquad(noise(N(0.4)), 'bp', lambda u: 520 - 300 * u, 0.8), 0.07, 0.001)
    whump = decay(sine_sweep(0.5, lambda u: 120 * (46 / 120) ** (u ** 0.6)), 0.13, 0.003)
    n = N(0.62)
    flutter = biquad(noise(n), 'bp', lambda u: 1300 - 700 * u, 1.0)
    flutter = env(flutter, lambda u: (0.5 + 0.5 * math.sin(u * 0.62 * 2 * math.pi * (34 - 18 * u))) ** 2 * (1 - u) ** 2.2)
    tail = [0.0] * N(0.035) + flutter
    x = mix([v * 0.8 for v in crack], [v * 0.7 for v in crack2], [v * 0.9 for v in bang], [v * 1.0 for v in whump], [v * 0.3 for v in tail])
    return [math.tanh(v * 2.4) for v in x]        # squeezed: the crack keeps its edge, the body comes up


def land():
    """Boots into the ground: a body-felt thud, a knock on top, grit spraying out and a breath of dust."""
    s = 1.2
    thud = decay(sine_sweep(0.8, lambda u: 78 * (36 / 78) ** (u ** 0.55)), 0.17, 0.0025)
    knock = decay(biquad(noise(N(0.2)), 'bp', 300, 1.0), 0.03, 0.001)
    clap = decay(biquad(noise(N(0.1)), 'bp', 1400, 0.8), 0.012, 0.0006)
    grit = [0.0] * N(s)
    for g in range(46):
        at = N(0.02 + R.random() ** 1.7 * 0.62)
        f = R.uniform(1500, 5200)
        grain = decay(biquad(noise(N(0.022)), 'bp', f, 2.0), 0.004, 0.0003)
        k = R.uniform(0.2, 0.9) * (1 - at / N(s)) ** 1.5
        for i, v in enumerate(grain):
            if at + i < len(grit):
                grit[at + i] += v * k
    dust = env(biquad(noise(N(s)), 'bp', 900, 0.6), lambda u: min(1.0, u / 0.06) * (1 - u) ** 3)
    return mix([v * 0.95 for v in thud], [v * 0.8 for v in knock], [v * 0.45 for v in clap], [v * 0.26 for v in grit], [v * 0.08 for v in dust])


def write(path, x, sr):
    with wave.open(path, 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(sr)
        w.writeframes(b''.join(struct.pack('<h', int(max(-1.0, min(1.0, v)) * 32767)) for v in x))


def lufs(path):
    log = subprocess.run(['ffmpeg', '-hide_banner', '-nostats', '-loglevel', 'verbose', '-i', path, '-af',
        'apad=pad_dur=0.5,ebur128=framelog=verbose', '-f', 'null', '-'], capture_output=True, text=True).stderr
    return max(float(v) for v in re.findall(r'\bM:\s*(-?[\d.]+)', log))


def finish(name, x, target, sr):
    """Fades the very ends (not a loop's), then sets loudness to `target` under the peak ceiling."""
    path = os.path.join(OUT, name + '.wav')
    peak = max(abs(v) for v in x) or 1.0
    x = [v / peak * 0.5 for v in x]
    write(path, x, sr)
    k = 10 ** ((target - lufs(path)) / 20)
    k = min(k, 10 ** (CEILING_DB / 20) / 0.5)
    write(path, [v * k for v in x], sr)
    print('%-16s %.2f s' % (name, len(x) / sr))


def fade_ends(x):
    f = N(0.004)
    t = N(0.05)
    x = list(x)
    for i in range(f):
        x[i] *= i / f
    for i in range(t):
        x[-1 - i] *= i / t
    return x


ALL = {
    'drop_wind_low': lambda: finish('drop_wind_low', looped(wind_low, 8.0, 1.0, LOOP_SR), TARGET['wind_low'], LOOP_SR),
    'drop_wind_high': lambda: finish('drop_wind_high', looped(wind_high, 6.0, 1.0, LOOP_SR), TARGET['wind_high'], LOOP_SR),
    'drop_jump': lambda: finish('drop_jump', fade_ends(jump()), TARGET['jump'], SR),
    'drop_cloud': lambda: finish('drop_cloud', fade_ends(cloud()), TARGET['cloud'], SR),
    'drop_snap': lambda: finish('drop_snap', fade_ends(snap()), TARGET['snap'], SR),
    'drop_land': lambda: finish('drop_land', fade_ends(land()), TARGET['land'], SR),
}

if __name__ == '__main__':
    for name in sys.argv[1:] or ALL:
        ALL[name]()
