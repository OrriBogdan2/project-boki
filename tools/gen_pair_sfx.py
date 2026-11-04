"""Synthesizes the payoff sounds of Tarek (dolm) and Ostra into audio/*.wav (mono, 22.05kHz, 16-bit).

    python3 tools/gen_pair_sfx.py           (then: godot --headless --import)

Pure Python (wave, math, random): no numpy or scipy. Both sounds are original.
  pay_rockfall   a deep stone thump, a crack, then a tumble of rubble falling away
  pay_collapse   a rising shimmer pulled down into a sub-bass implosion with a bright glass tail
"""
import math, random, wave, struct, os

SR = 22050
OUT = os.path.join(os.path.dirname(__file__), '..', 'audio')
rng = random.Random(11)


def n(d): return int(SR * d)


def fade(x, a=0.004, b=0.02):
    na, nb = n(a), n(b)
    for i in range(min(na, len(x))): x[i] *= i / na
    for i in range(min(nb, len(x))): x[len(x) - 1 - i] *= i / nb
    return x


def lowpass(x, hz):
    k = 1.0 - math.exp(-2 * math.pi * hz / SR)
    y, s = [], 0.0
    for v in x:
        s += k * (v - s)
        y.append(s)
    return y


def highpass(x, hz):
    lp = lowpass(x, hz)
    return [a - b for a, b in zip(x, lp)]


def noise(d): return [rng.uniform(-1, 1) for _ in range(n(d))]


def sine_sweep(f0, f1, d, curve=1.0):
    out, ph = [], 0.0
    N = n(d)
    for i in range(N):
        u = (i / max(1, N - 1)) ** curve
        f = f0 * (f1 / f0) ** u
        ph += 2 * math.pi * f / SR
        out.append(math.sin(ph))
    return out


def env_exp(N, tau):
    return [math.exp(-i / SR / tau) for i in range(N)]


def mix(*parts):
    L = max(len(p) for p in parts)
    out = [0.0] * L
    for p in parts:
        for i, v in enumerate(p): out[i] += v
    return out


def at(x, t, total):
    pad = [0.0] * n(t)
    out = pad + x
    return out + [0.0] * max(0, n(total) - len(out))


def level(x, rms=0.13, peak=0.9):
    r = math.sqrt(sum(v * v for v in x) / len(x)) or 1.0
    g = rms / r
    m = max(abs(v) for v in x) * g
    if m > peak: g *= peak / m
    return [v * g for v in x]


def save(name, x):
    x = fade(x)
    with wave.open(os.path.join(OUT, name + '.wav'), 'wb') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes(b''.join(struct.pack('<h', int(max(-1, min(1, v)) * 32767)) for v in x))


def rockfall():
    total = 1.3
    thump = [a * b for a, b in zip(sine_sweep(110, 42, 0.45, 0.8), env_exp(n(0.45), 0.12))]
    crack = [a * b for a, b in zip(highpass(lowpass(noise(0.12), 5200), 1400), env_exp(n(0.12), 0.025))]
    body = [a * b for a, b in zip(lowpass(noise(0.5), 420), env_exp(n(0.5), 0.16))]
    rubble = [0.0] * n(total)
    t = 0.07
    while t < 1.15:
        grain = [a * b for a, b in zip(lowpass(noise(0.03), rng.uniform(900, 2600)), env_exp(n(0.03), 0.008))]
        amp = rng.uniform(0.25, 0.7) * math.exp(-(t - 0.07) * 2.2)
        base = n(t)
        for i, v in enumerate(grain):
            if base + i < len(rubble): rubble[base + i] += v * amp
        t += rng.uniform(0.02, 0.09)
    x = mix(at(thump, 0, total), at([v * 0.8 for v in crack], 0.0, total), at([v * 0.5 for v in body], 0.0, total), rubble)
    save('pay_rockfall', level(x))


def collapse():
    total = 1.25
    rise = [a * (i / n(0.45)) ** 2 for i, a in enumerate(sine_sweep(240, 1500, 0.45, 1.6))]
    shim = [a * (i / n(0.45)) ** 2 for i, a in enumerate(sine_sweep(1800, 2900, 0.45, 1.0))]
    pull = [a * b for a, b in zip(sine_sweep(900, 55, 0.5, 0.55), env_exp(n(0.5), 0.2))]
    sub = [a * b for a, b in zip(sine_sweep(70, 34, 0.7, 0.9), env_exp(n(0.7), 0.25))]
    puff = [a * b for a, b in zip(lowpass(noise(0.35), 1800), env_exp(n(0.35), 0.1))]
    glass = []
    for f, tt, amp in [(2093, 0.0, 0.35), (2637, 0.05, 0.28), (3136, 0.1, 0.22)]:
        d = 0.6
        glass.append(at([math.sin(2 * math.pi * f * i / SR) * math.exp(-i / SR / 0.18) * amp for i in range(n(d))], 0.45 + tt, total))
    x = mix(at([v * 0.5 for v in rise], 0.0, total), at([v * 0.25 for v in shim], 0.0, total), at(pull, 0.42, total), at([v * 1.1 for v in sub], 0.45, total), at([v * 0.5 for v in puff], 0.45, total), *glass)
    save('pay_collapse', level(x))


if __name__ == '__main__':
    rockfall()
    collapse()
    print('wrote pay_rockfall.wav, pay_collapse.wav')
