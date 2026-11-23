"""Synthesizes the breakables' sounds into audio/: break_wood (a crate or barrel splintering),
break_clay (a pot shattering into shards), break_metal (a keg's iron hoops bursting open) and
fuse_hiss (a lit powder keg hissing). Original, no samples; same soft palette as gen_sfx.py.
Kept apart so rerunning it doesn't reshuffle every other sound.

    python3 tools/gen_break_sfx.py      (then: godot --headless --import)
"""
import numpy as np, wave, os
from scipy.signal import butter, sosfilt

SR = 22050
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'audio')
rng = np.random.default_rng(1140)


def N(d): return int(SR * d)
def T(d): return np.arange(N(d)) / SR
def lpf(x, hz): return sosfilt(butter(2, hz / (SR / 2), 'low', output='sos'), x)
def hpf(x, hz): return sosfilt(butter(2, hz / (SR / 2), 'high', output='sos'), x)
def bpf(x, lo, hi): return sosfilt(butter(2, [lo / (SR / 2), min(hi, 10500) / (SR / 2)], 'band', output='sos'), x)


def save(name, x, rms_db=-19.0):
    x = np.asarray(x, dtype=float)
    x = hpf(x, 60)
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


def clacks(d, hits, lo, hi, ring, decay):
    """Short dry clacks (wood or shards): (time, gain, pitch) triples, each a filtered noise tick plus a ringing body."""
    x = np.zeros(N(d))
    for t0, g, pitch in hits:
        s = N(t0); L = min(N(0.12), len(x) - s); tt = np.arange(L) / SR
        tick = bpf(rng.standard_normal(L), lo * pitch, hi * pitch) * np.exp(-tt / decay)
        body = np.sin(2 * np.pi * ring * pitch * tt) * np.exp(-tt / (decay * 1.4))
        x[s:s + L] += g * (tick + 0.35 * body)
    return x


# break_wood: a hard crack, then planks clattering away
d = 0.5
crack = bpf(rng.standard_normal(N(d)), 500, 3800) * np.exp(-T(d) / 0.05)
thump = np.sin(2 * np.pi * (150 - 70 * T(d) / d) * T(d)) * np.exp(-T(d) / 0.07)
x = crack + 0.9 * thump + clacks(d, [(0.04, 0.8, 1.0), (0.09, 0.7, 0.8), (0.15, 0.55, 1.2), (0.23, 0.4, 0.9), (0.31, 0.25, 1.1)], 700, 2600, 320, 0.02)
save('break_wood', x, -19.0)

# break_clay: a bright smash, then a tinkle of shards
d = 0.55
smash = bpf(rng.standard_normal(N(d)), 1200, 7500) * np.exp(-T(d) / 0.035)
thud = np.sin(2 * np.pi * 210 * T(d)) * np.exp(-T(d) / 0.035)
shards = clacks(d, [(0.05, 0.7, 1.4), (0.1, 0.6, 1.7), (0.14, 0.55, 1.2), (0.2, 0.45, 1.9), (0.27, 0.35, 1.5), (0.35, 0.22, 2.0)], 2500, 8500, 2400, 0.012)
save('break_clay', smash + 0.6 * thud + shards, -20.0)

# break_metal: hoops bursting with a dull clang, a rattle of staves
d = 0.6
t = T(d)
clang = sum(np.sin(2 * np.pi * f * t) * np.exp(-t / dec) for f, dec in [(310, 0.16), (587, 0.1), (941, 0.07), (1480, 0.04)])
burst = lpf(rng.standard_normal(N(d)), 3500) * np.exp(-t / 0.06)
rattle = clacks(d, [(0.06, 0.6, 0.9), (0.12, 0.5, 0.7), (0.2, 0.4, 1.0), (0.28, 0.3, 0.8)], 500, 2200, 260, 0.025)
save('break_metal', 0.5 * clang + burst + rattle, -19.0)

# fuse_hiss: a lit fuse, noise with a fizz that rises and crackles
d = 0.55
t = T(d)
hiss = hpf(rng.standard_normal(N(d)), 2500) * (0.55 + 0.45 * t / d)
crackle = (rng.random(N(d)) > 0.9985) * rng.standard_normal(N(d)) * 6.0
crackle = bpf(crackle, 1500, 6000)
save('fuse_hiss', (hiss + crackle) * np.minimum(1.0, t / 0.03), -23.0)
print('wrote break_wood, break_clay, break_metal, fuse_hiss')
