"""Synthesizes the key and Shrubling sounds into audio/: rustle (leaves shaking as it pops up or dives),
squeak (a small high chirp when it is hit), key_get (a bright two-note jingle) and lock_rattle (a
padlock jiggled with no key). Original, no samples; same soft palette as gen_sfx.py.
Kept apart so rerunning it doesn't reshuffle every other sound.

    python3 tools/gen_key_sfx.py      (then: godot --headless --import)
"""
import numpy as np, wave, os
from scipy.signal import butter, sosfilt

SR = 22050
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'audio')
rng = np.random.default_rng(970)


def N(d): return int(SR * d)
def T(d): return np.arange(N(d)) / SR
def lpf(x, hz): return sosfilt(butter(2, hz / (SR / 2), 'low', output='sos'), x)
def hpf(x, hz): return sosfilt(butter(2, hz / (SR / 2), 'high', output='sos'), x)
def bpf(x, lo, hi): return sosfilt(butter(2, [lo / (SR / 2), hi / (SR / 2)], 'band', output='sos'), x)


def env(n, a, decay):
    t = np.arange(n) / SR
    na = max(1, N(a))
    e = np.exp(-np.maximum(0.0, t - a) / decay)
    e[:na] *= 0.5 - 0.5 * np.cos(np.pi * np.arange(na) / na)
    return e


def save(name, x, rms_db=-20.0):
    x = np.asarray(x, dtype=float)
    x = hpf(x, 60)
    fi = N(0.004); x[:fi] *= 0.5 - 0.5 * np.cos(np.pi * np.arange(fi) / fi)
    fo = N(0.04); x[-fo:] *= 0.5 + 0.5 * np.cos(np.pi * np.arange(fo) / fo)
    pk = np.max(np.abs(x)) or 1.0
    act = np.abs(x) > pk * 0.01
    x *= 10 ** (rms_db / 20) / (np.sqrt(np.mean(x[act] ** 2)) or 1.0)
    c = 10 ** (-3 / 20); k = c * 0.7
    x = np.where(np.abs(x) > k, np.sign(x) * (k + (c - k) * np.tanh((np.abs(x) - k) / (c - k))), x)
    with wave.open(os.path.join(OUT, name + '.wav'), 'wb') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((np.clip(x, -1, 1) * 32767).astype(np.int16).tobytes())


# rustle: band-limited noise in a few quick swells, like leaves shaken
d = 0.42; t = T(d); n = len(t)
nz = bpf(rng.standard_normal(n), 1800, 6500)
swell = np.zeros(n)
for t0, g in [(0.0, 1.0), (0.07, 0.8), (0.14, 0.9), (0.22, 0.55), (0.3, 0.35)]:
    s = N(t0); L = min(N(0.1), n - s)
    swell[s:s + L] += g * np.sin(np.pi * np.arange(L) / L) ** 2
save('rustle', nz * swell * env(n, 0.005, 0.5), -21.0)

# squeak: a quick upward chirp with a little vibrato, thin and cartoonish
d = 0.22; t = T(d); n = len(t)
f = 1500 + 1500 * (t / d) ** 0.6 + 60 * np.sin(2 * np.pi * 38 * t)
ph = 2 * np.pi * np.cumsum(f) / SR
x = np.sin(ph) + 0.35 * np.sin(2 * ph) + 0.12 * np.sin(3 * ph)
save('squeak', lpf(x, 7000) * env(n, 0.006, 0.08), -20.0)

# key_get: two bright bell notes, a rising third
def bell(fr, d, decay):
    t = T(d); n = len(t)
    return (np.sin(2 * np.pi * fr * t) + 0.2 * np.sin(2 * np.pi * fr * 2.01 * t)) * env(n, 0.003, decay)

d = 0.7; x = np.zeros(N(d))
for t0, fr in [(0.0, 880.0), (0.09, 1174.7)]:
    s = N(t0); b = bell(fr, d - t0, 0.16); x[s:s + len(b)] += b
save('key_get', x, -19.0)

# lock_rattle: three dull metallic clicks
d = 0.38; x = np.zeros(N(d))
for t0, g in [(0.0, 1.0), (0.1, 0.8), (0.19, 0.6)]:
    s = N(t0); L = N(0.09); tt = np.arange(L) / SR
    cl = (bpf(rng.standard_normal(L), 900, 3200) * 0.6 + np.sin(2 * np.pi * 540 * tt) * 0.5) * np.exp(-tt / 0.018)
    x[s:s + L] += g * cl
save('lock_rattle', x, -22.0)
print('wrote rustle, squeak, key_get, lock_rattle')
