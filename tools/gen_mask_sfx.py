"""Synthesizes the Mask moment's sounds (MaskBeat) into audio/mask_*.wav.

    python3 tools/gen_mask_sfx.py      (then: godot --headless --import)

Our own sounds, numpy only (filters are done in the frequency domain). 32 kHz mono, own random stream.
  mask_swell   : 2.6 s. A low drone (two detuned saws at 55 Hz, low-passed, the cut-off opening from 180 to
                 900 Hz) under a crescendo of band-passed air, rising a whole tone over its length.
  mask_impact  : 1.6 s. The Hunter settling in: a deep boom (a 70 Hz sine dropping to 32 Hz), a bright crack of
                 noise and a long low tail of filtered noise.
"""
import os, wave
import numpy as np

SR = 32000
OUT = os.path.join(os.path.dirname(__file__), '..', 'audio')
rng = np.random.default_rng(1183)


def N(d): return int(SR * d)
def T(d): return np.arange(N(d)) / SR


def band(x, lo, hi):
    """Keeps lo..hi Hz (a soft-edged mask in the frequency domain)."""
    f = np.fft.rfftfreq(len(x), 1 / SR)
    k = 1 / (1 + (lo / np.maximum(f, 1)) ** 4) / (1 + (f / hi) ** 4)
    return np.fft.irfft(np.fft.rfft(x) * k, len(x))


def lpf(x, hz): return band(x, 1.0, hz)


def env(n, a, d):
    """Raised-cosine fade-in over a seconds, then an exponential fall with time constant d."""
    t = np.arange(n) / SR
    att = np.where(t < a, 0.5 - 0.5 * np.cos(np.pi * np.clip(t / a, 0, 1)), 1.0)
    return att * np.exp(-np.maximum(0.0, t - a) / d)


def saw(path):
    ph = np.cumsum(path) / SR
    return 2.0 * (ph - np.floor(ph + 0.5))


def at(x, delay): return np.concatenate([np.zeros(N(delay)), x])


def mix(*xs):
    n = max(len(x) for x in xs); o = np.zeros(n)
    for x in xs: o[:len(x)] += x
    return o


def level(x, rms_db=-20.0, ceil_db=-2.0):
    x = np.asarray(x, dtype=float)
    x = x - np.mean(x)
    fi = N(0.003); x[:fi] *= 0.5 - 0.5 * np.cos(np.pi * np.arange(fi) / fi)
    fo = N(0.05); x[-fo:] *= 0.5 + 0.5 * np.cos(np.pi * np.arange(fo) / fo)
    pk = np.max(np.abs(x)); act = np.abs(x) > pk * 0.01
    x = x * (10 ** (rms_db / 20) / (np.sqrt(np.mean(x[act] ** 2)) or 1.0))
    c = 10 ** (ceil_db / 20); k = c * 0.7; m = np.abs(x)
    return np.where(m > k, np.sign(x) * (k + (c - k) * np.tanh((m - k) / (c - k))), x)


def save(name, x, rms_db=-20.0):
    x = level(x, rms_db)
    with wave.open(os.path.join(OUT, name + '.wav'), 'wb') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((np.clip(x, -1, 1) * 32767).astype(np.int16).tobytes())


def swell():
    d = 2.6; t = T(d); k = t / d
    path = 55.0 * 2 ** (2.0 / 12 * k)
    drone = saw(path) + saw(path * 1.006)
    # the cut-off opens: a sum of two low-passed copies, crossfaded
    drone = lpf(drone, 180) * (1 - k) + lpf(drone, 900) * k
    air = band(rng.standard_normal(len(t)), 600, 4000) * k ** 2.2
    grow = np.minimum(1.0, k * 1.15) ** 1.6
    return (drone * 0.8 + air * 0.6) * grow


def impact():
    d = 1.6; t = T(d); n = len(t)
    path = 32.0 + 38.0 * np.exp(-t / 0.12)
    boom = np.sin(2 * np.pi * np.cumsum(path) / SR) * env(n, 0.002, 0.35)
    crack = band(rng.standard_normal(n), 1500, 7000) * env(n, 0.001, 0.025)
    tail = lpf(rng.standard_normal(n), 400) * env(n, 0.01, 0.5) * 0.4
    return boom * 1.3 + crack * 0.7 + tail


if __name__ == '__main__':
    save('mask_swell', swell(), -22)
    save('mask_impact', impact(), -15)
    print('mask sounds written')
