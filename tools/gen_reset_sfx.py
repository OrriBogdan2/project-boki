"""Synthesizes the "reset" cue (a dash or ability comes straight back) into audio/reset_{a,b,c}.wav.

    python3 tools/gen_reset_sfx.py      (then: godot --headless --import)

Three original variants of one idea: a crisp, bright "it's back" ding. Each has an attack under 10 ms
(a raised-cosine fade-in of 2 to 3 ms), a glassy partial set with energy at 4 to 7 kHz over a warmer
body, an upward step in pitch, and a short shimmering tail, 0.45 to 0.6 s in all. Sample rate is 32 kHz so
the glassy partials (up to ~9 kHz) have room. Own random stream, so no other generator's output moves.
The variant the game plays is the "reset_cue" setting (Settings > Gameplay > Reset cue sound), default a.

  a : two struck bells a perfect fifth apart, D6 then A6 (1175 Hz, 1760 Hz), 70 ms apart, the second one
      longer. Each bell is a warm sine at half its pitch (body) plus the glass partials 1, 2, 3, 4.2, 5.4 and
      6.5 x the pitch; the tail is the upper partials shimmering at 13 Hz.
  b : one bright bell (G6, 1568 Hz) that glides up 3 semitones into pitch in the first ~40 ms (all
      partials ride the glide), with a burst of band-passed sparkle noise (5 to 9 kHz) and a few random
      tiny pings at 4.5 to 7 kHz scattered over the first 0.3 s.
  c : a soft "whoomp" (a sine rising 130 to 210 Hz over 90 ms with a puff of low-passed noise) under a
      high crystalline ping (5.2 kHz with a 6.9 kHz partial) and a second quieter ping at 6.3 kHz.
"""
import math, os, wave
import numpy as np
from scipy.signal import butter, sosfilt

SR = 32000
OUT = os.path.join(os.path.dirname(__file__), '..', 'audio')
rng = np.random.default_rng(1105)


def N(d): return int(SR * d)
def T(d): return np.arange(N(d)) / SR


def _sos(kind, hz):
    if kind == 'band':
        lo, hi = hz
        return butter(2, [lo / (SR / 2), min(hi, SR * 0.45) / (SR / 2)], 'band', output='sos')
    return butter(2, min(hz, SR * 0.45) / (SR / 2), kind, output='sos')

def lpf(x, hz): return sosfilt(_sos('low', hz), x)
def bpf(x, lo, hi): return sosfilt(_sos('band', (lo, hi)), x)


def env(n, a, d):
    """Raised-cosine fade-in over a seconds, then an exponential fall with time constant d."""
    t = np.arange(n) / SR
    att = np.where(t < a, 0.5 - 0.5 * np.cos(np.pi * np.clip(t / a, 0, 1)), 1.0)
    return att * np.exp(-np.maximum(0.0, t - a) / d)


def partials(path, parts, d, a=0.002):
    """Sum of sines at multiples of a (possibly gliding) base frequency path.
    parts: (ratio, gain, decay seconds). path is an array of Hz, one per sample."""
    n = len(path); ph = 2 * np.pi * np.cumsum(path) / SR; out = np.zeros(n)
    for r, g, dec in parts:
        out += g * np.sin(ph * r) * env(n, a, dec)
    return out


GLASS = [(1.0, 1.0, 0.20), (2.0, 0.5, 0.15), (3.0, 0.55, 0.12), (4.0, 0.45, 0.10), (4.2, 0.55, 0.10), (5.4, 0.45, 0.08)]


def bell(f, d, k=1.0, body=0.5):
    """A struck glass bell: warm body at f/2 plus the glass partials; k stretches the decay."""
    path = np.full(N(d), float(f))
    glass = partials(path, [(r, g, dec * k) for r, g, dec in GLASS], d)
    return glass + body * np.sin(2 * np.pi * (f / 2) * T(d)) * env(N(d), 0.003, 0.11 * k)


def shimmer(freqs, d, hz=13.0, depth=0.5, decay=0.2):
    """A few high partials (Hz), amplitude-wobbling out of step: the sparkling tail."""
    t = T(d); out = np.zeros(N(d))
    for i, f in enumerate(freqs):
        wob = 1.0 - depth + depth * (0.5 + 0.5 * np.sin(2 * np.pi * hz * t + i * 1.9))
        out += np.sin(2 * np.pi * f * t) * wob
    return out / len(freqs) * env(N(d), 0.01, decay)


def at(x, delay): return np.concatenate([np.zeros(N(delay)), x])

def mix(*xs):
    n = max(len(x) for x in xs); o = np.zeros(n)
    for x in xs: o[:len(x)] += x
    return o


def level(x, rms_db=-20.0, ceil_db=-2.5):
    x = np.asarray(x, dtype=float)
    x = x - np.mean(x)
    fi = N(0.002); x[:fi] *= 0.5 - 0.5 * np.cos(np.pi * np.arange(fi) / fi)
    fo = N(0.04); x[-fo:] *= 0.5 + 0.5 * np.cos(np.pi * np.arange(fo) / fo)
    pk = np.max(np.abs(x)); act = np.abs(x) > pk * 0.01
    x = x * (10 ** (rms_db / 20) / (np.sqrt(np.mean(x[act] ** 2)) or 1.0))
    c = 10 ** (ceil_db / 20); k = c * 0.7; m = np.abs(x)
    return np.where(m > k, np.sign(x) * (k + (c - k) * np.tanh((m - k) / (c - k))), x)


def save(name, x, rms_db=-20.0):
    x = level(x, rms_db)
    with wave.open(os.path.join(OUT, name + '.wav'), 'wb') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((np.clip(x, -1, 1) * 32767).astype(np.int16).tobytes())


def variant_a():
    d = 0.56
    lo = bell(1175.0, 0.3, 0.6)
    hi = bell(1760.0, d - 0.07, 1.15)
    return mix(lo * 0.8, at(hi, 0.07) * 1.0, at(shimmer([4935.0, 5280.0, 6345.0, 7040.0], 0.42), 0.09) * 0.5)


def variant_b():
    d = 0.5; n = N(d); t = np.arange(n) / SR
    path = 1568.0 * 2 ** (-3.0 / 12 * np.exp(-t / 0.018))          # 3 semitones below, up into pitch in ~40 ms
    glass = partials(path, [(r, g, dec * 1.1) for r, g, dec in GLASS], d)
    body = 0.5 * np.sin(2 * np.pi * np.cumsum(path / 2) / SR) * env(n, 0.003, 0.12)
    spark = bpf(rng.standard_normal(N(0.2)), 5000, 9000) * env(N(0.2), 0.002, 0.05)
    pings = np.zeros(n)
    for _ in range(7):
        f = rng.uniform(4500, 7000); s0 = N(rng.uniform(0.03, 0.3)); g = N(0.09)
        pings[s0:s0 + g] += np.sin(2 * np.pi * f * np.arange(g) / SR) * env(g, 0.002, 0.025) * rng.uniform(0.15, 0.4)
    return mix(glass, body, spark * 0.8, pings)


def variant_c():
    d = 0.6; n = N(d); t = np.arange(n) / SR
    rise = 130.0 + 80.0 * (1 - np.exp(-t / 0.035))
    whoomp = np.sin(2 * np.pi * np.cumsum(rise) / SR) * env(n, 0.004, 0.13)
    whoomp += 0.5 * lpf(rng.standard_normal(n), 500) * env(n, 0.003, 0.045)
    ping1 = (np.sin(2 * np.pi * 5200 * T(0.5)) + 0.4 * np.sin(2 * np.pi * 6900 * T(0.5))) * env(N(0.5), 0.002, 0.15)
    ping2 = np.sin(2 * np.pi * 6300 * T(0.35)) * env(N(0.35), 0.002, 0.1)
    return mix(whoomp * 1.1, at(ping1, 0.03) * 0.55, at(ping2, 0.1) * 0.3, at(shimmer([4400.0, 5700.0], 0.35, 11.0, 0.5, 0.12), 0.1) * 0.15)


if __name__ == '__main__':
    save('reset_a', variant_a(), -20)
    save('reset_b', variant_b(), -20)
    save('reset_c', variant_c(), -20)
    print('reset cues written')
