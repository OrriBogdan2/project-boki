"""Synthesizes the level-up sound into audio/level_up.wav: a warm low swell under a bright rising
four-note bell run (root, third, fifth, octave) that lands on a held shimmer.
Kept apart from gen_sfx.py so rerunning it doesn't reshuffle every other sound.
Same soft palette as gen_sfx.py: fades in, rounded tones, levelled under the music. Original, no samples.

    python3 tools/gen_level_sfx.py      (then: godot --headless --import)
"""
import numpy as np, wave, os
from scipy.signal import butter, sosfilt

SR = 22050
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'audio')
rng = np.random.default_rng(613)


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


def bell(f, d, a=0.006, decay=0.25):
    """A glassy chime: a sine with two quieter inharmonic partials that fade faster."""
    n = N(d); t = T(d)
    x = np.sin(2 * np.pi * f * t) * env(n, a, decay)
    x += 0.18 * np.sin(2 * np.pi * f * 2.0 * t) * env(n, a, decay * 0.6)
    x += 0.10 * np.sin(2 * np.pi * f * 3.01 * t) * env(n, a, decay * 0.3)
    return x


def at(x, delay, total):
    out = np.zeros(total)
    s = N(delay)
    out[s:s + len(x)] += x[:max(0, total - s)]
    return out


def save(name, x, rms_db=-19.0):
    x = np.asarray(x, dtype=float)
    x = hpf(x, 40)
    fi = N(0.003); x[:fi] *= 0.5 - 0.5 * np.cos(np.pi * np.arange(fi) / fi)
    fo = N(0.05); x[-fo:] *= 0.5 + 0.5 * np.cos(np.pi * np.arange(fo) / fo)
    pk = np.max(np.abs(x)) or 1.0
    act = np.abs(x) > pk * 0.01
    x *= 10 ** (rms_db / 20) / (np.sqrt(np.mean(x[act] ** 2)) or 1.0)
    c = 10 ** (-3 / 20); k = c * 0.7
    x = np.where(np.abs(x) > k, np.sign(x) * (k + (c - k) * np.tanh((np.abs(x) - k) / (c - k))), x)
    with wave.open(os.path.join(OUT, name + '.wav'), 'wb') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((np.clip(x, -1, 1) * 32767).astype(np.int16).tobytes())


D = 1.25
total = N(D)
# the run: G4 B4 D5 G5, quick and even, the last one held and a little louder
notes = [(392.0, 0.00, 0.18, 0.75), (493.9, 0.075, 0.18, 0.8), (587.3, 0.15, 0.2, 0.85), (784.0, 0.225, 0.55, 1.0)]
run = np.zeros(total)
for f, t0, dec, g in notes:
    run += at(bell(f, D - t0, 0.004, dec) * g, t0, total)
# a sparkle on top of the last note: a fifth and an octave above, soft and late
run += at(bell(1174.7, 0.9, 0.02, 0.35) * 0.28, 0.26, total)
run += at(bell(1568.0, 0.8, 0.03, 0.3) * 0.16, 0.30, total)
# underneath: a warm low swell (G2 and D3) that rises in and rings out, so it lands with some body
t = T(D)
sw_env = np.minimum(1.0, t / 0.16) ** 2 * np.exp(-np.maximum(0.0, t - 0.2) / 0.35)
swell = (np.sin(2 * np.pi * 98.0 * t) + 0.5 * np.sin(2 * np.pi * 146.8 * t) + 0.12 * np.sin(2 * np.pi * 196.0 * t)) * sw_env
swell = lpf(swell, 700) * 0.42
# air: a band-passed breath that rises with the run
air = bpf(rng.standard_normal(total) * 0.35, 2500, 7000)
air *= np.minimum(1.0, t / 0.25) * np.exp(-np.maximum(0.0, t - 0.25) / 0.25) * 0.22
save('level_up', lpf(run + swell + air, 6500), rms_db=-19.0)
print('level_up written')
