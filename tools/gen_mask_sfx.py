"""Synthesizes the Mask moment's sounds (MaskBeat, content/rules/mask_moment.json) into audio/mask_*.wav.

    python3 tools/gen_mask_sfx.py      (then: godot --headless --import)

Our own sounds, numpy only (filters are done in the frequency domain). 32 kHz mono, own random stream.
  mask_swell   : 2.6 s. A low drone (two detuned saws at 55 Hz, low-passed, the cut-off opening from 180 to
                 900 Hz) under a crescendo of band-passed air, rising a whole tone over its length.
  mask_heart   : 0.55 s. One heartbeat, "lub-dub": two thumps (a 48 Hz then a 60 Hz sine with a fast pitch drop
                 and a puff of low noise), 0.16 s apart. MaskBeat plays it several times, closer and closer.
  mask_whisper : 1.1 s. A breathy whisper: noise through three formant bands (vowel-like, gliding), shaped into
                 four soft syllables, with a hiss on top.
  mask_impact  : 1.6 s. The snap back: a deep boom (a 70 Hz sine dropping to 32 Hz), a bright crack of noise and
                 a long low tail of filtered noise.
  mask_sting   : 1.5 s. A short heroic stab: a rising three-note motif (root, fifth, octave) on a bright
                 brass-like stack of harmonics over a held chord. MaskBeat sets the pitch per Hunter (the motif).
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


def thump(f0, d=0.28):
    t = T(d)
    path = f0 * (1 + 1.4 * np.exp(-t / 0.02))
    body = np.sin(2 * np.pi * np.cumsum(path) / SR) * env(len(t), 0.004, 0.07)
    puff = lpf(rng.standard_normal(len(t)), 260) * env(len(t), 0.002, 0.03)
    return body + puff * 0.6


def heart():
    return mix(thump(48.0), at(thump(60.0) * 0.75, 0.16), np.zeros(N(0.55)))


def whisper():
    d = 1.1; t = T(d); n = len(t)
    src = rng.standard_normal(n)
    out = np.zeros(n)
    for lo, hi, g in [(500, 900, 0.8), (1100, 1900, 1.0), (2300, 3200, 0.6)]:
        out += band(src, lo, hi) * g
    syll = np.zeros(n)
    for s0, ln in [(0.05, 0.18), (0.3, 0.14), (0.5, 0.22), (0.78, 0.25)]:
        a = N(s0); m = N(ln)
        syll[a:a + m] += np.sin(np.pi * np.arange(m) / m) ** 1.5
    hiss = band(rng.standard_normal(n), 4500, 9000) * 0.35
    return (out + hiss) * syll


def impact():
    d = 1.6; t = T(d); n = len(t)
    path = 32.0 + 38.0 * np.exp(-t / 0.12)
    boom = np.sin(2 * np.pi * np.cumsum(path) / SR) * env(n, 0.002, 0.35)
    crack = band(rng.standard_normal(n), 1500, 7000) * env(n, 0.001, 0.025)
    tail = lpf(rng.standard_normal(n), 400) * env(n, 0.01, 0.5) * 0.4
    return boom * 1.3 + crack * 0.7 + tail


def brass(f, d, a=0.02):
    t = T(d); out = np.zeros(len(t))
    for h in range(1, 9):
        out += np.sin(2 * np.pi * f * h * t) / h ** 1.1
    return lpf(out, 3200) * env(len(t), a, d * 0.45)


def sting():
    root = 220.0
    notes = [(root, 0.0, 0.5), (root * 1.5, 0.12, 0.5), (root * 2.0, 0.24, 1.2)]
    motif = mix(*[at(brass(f, d), s) for f, s, d in notes])
    chord = mix(brass(root / 2, 1.5, 0.05), brass(root * 0.75, 1.5, 0.05) * 0.6) * 0.5
    return mix(motif, at(chord, 0.24))


if __name__ == '__main__':
    save('mask_swell', swell(), -22)
    save('mask_heart', heart(), -16)
    save('mask_whisper', whisper(), -24)
    save('mask_impact', impact(), -15)
    save('mask_sting', sting(), -18)
    print('mask sounds written')
