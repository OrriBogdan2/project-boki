"""Ambience beds for expeditions that fade in and out by where you are (MusicDir drives them):

    amb_abyss   wind over the drop: a deep, slow howl with the odd hollow whistle in it
    amb_ruins   the old world's ruins: a low stone drone, creaks and settling rubble, far-off metal

    python3 tools/gen_ambience.py   (then: godot --headless --import)

Stereo 32 kHz Ogg loops (seamless: the end is crossfaded into the start). Original synthesis with its
own random stream; needs numpy, scipy and ffmpeg.
"""
import os, subprocess, tempfile, wave
import numpy as np
from scipy.signal import butter, sosfilt

SR = 32000
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'audio')
rng = np.random.default_rng(907)


def _sos(kind, hz):
    if kind == 'band':
        return butter(2, [hz[0] / (SR / 2), hz[1] / (SR / 2)], 'band', output='sos')
    return butter(2, hz / (SR / 2), kind, output='sos')


def lpf(x, hz): return sosfilt(_sos('low', hz), x)
def hpf(x, hz): return sosfilt(_sos('high', hz), x)
def bpf(x, lo, hi): return sosfilt(_sos('band', (lo, hi)), x)


def slow(n, rate_hz, lo=0.0, hi=1.0):
    """A slowly wandering control curve between lo and hi."""
    k = max(4, int(n / SR * rate_hz) + 4)
    pts = rng.uniform(lo, hi, k)
    return np.interp(np.linspace(0, k - 3, n), np.arange(k), pts)


def svf(x, freqs, q):
    out = np.empty_like(x); low = band = 0.0; damp = 1.0 / q
    for i in range(len(x)):
        f = 2.0 * np.sin(np.pi * min(freqs[i], SR / 6.5) / SR)
        low += f * band
        band += f * (x[i] - low - damp * band)
        out[i] = band
    return out


def loop(x, fade=2.0):
    f = int(SR * fade)
    w = np.linspace(0, 1, f)[:, None] if x.ndim == 2 else np.linspace(0, 1, f)
    x = x.copy()
    x[:f] = x[:f] * w + x[-f:] * (1 - w)
    return x[:-f]


def abyss(seconds=26.0):
    n = int(SR * (seconds + 2.0))
    chans = []
    for c in range(2):
        base = lpf(rng.standard_normal(n), 380) * (0.5 + 0.5 * slow(n, 0.12, 0.2, 1.0))
        howl = svf(rng.standard_normal(n), slow(n, 0.08, 180, 520), 7.0) * slow(n, 0.1, 0.0, 1.0) ** 2 * 0.35
        whistle = svf(rng.standard_normal(n), slow(n, 0.15, 700, 1300), 18.0) * np.clip(slow(n, 0.2, -1.5, 1.0), 0, 1) ** 2 * 0.05
        chans.append(base + howl + whistle)
    return loop(np.stack(chans, 1))


def ruins(seconds=30.0):
    n = int(SR * (seconds + 2.0)); t = np.arange(n) / SR
    out = np.zeros((n, 2))
    drone = lpf(rng.standard_normal(n), 120) * 2.0 + 0.12 * np.sin(2 * np.pi * 55 * t) * slow(n, 0.1, 0.4, 1.0)
    out += drone[:, None]
    # creaks: a slow pitch-bending resonance, like old timber or iron under strain
    for _ in range(5):
        s0 = rng.integers(0, n - SR * 2); m = int(SR * rng.uniform(0.6, 1.4)); tt = np.arange(m) / SR
        f = rng.uniform(220, 520) * (1 + 0.15 * np.sin(np.pi * tt / tt[-1]))
        src = np.sign(np.sin(2 * np.pi * np.cumsum(rng.uniform(18, 40) * np.ones(m)) / SR)) * 0.5 + rng.standard_normal(m) * 0.2
        c = bpf(src, 150, 900) * np.sin(2 * np.pi * np.cumsum(f) / SR) * np.sin(np.pi * tt / tt[-1]) ** 2 * 0.25
        pan = rng.uniform(0.2, 0.8)
        out[s0:s0 + m, 0] += c * (1 - pan); out[s0:s0 + m, 1] += c * pan
    # settling rubble: little trickles of grit
    for _ in range(9):
        s0 = rng.integers(0, n - SR); m = int(SR * rng.uniform(0.3, 0.8))
        g = np.zeros(m)
        for _ in range(int(m / SR * 60)):
            k = rng.integers(0, m - 200); L = rng.integers(40, 160)
            g[k:k + L] += bpf(rng.standard_normal(L + 64), 1200, 5000)[64:] * np.hanning(L) * rng.uniform(0.2, 1.0)
        g *= np.linspace(1, 0.2, m) * 0.25
        pan = rng.uniform(0.1, 0.9)
        out[s0:s0 + m, 0] += g * (1 - pan); out[s0:s0 + m, 1] += g * pan
    # far-off metal: a struck beam ringing somewhere out of sight
    for _ in range(3):
        s0 = rng.integers(0, n - SR * 3); m = int(SR * 2.5); tt = np.arange(m) / SR
        f0 = rng.uniform(140, 260)
        c = sum(a * np.sin(2 * np.pi * f0 * r * tt) * np.exp(-tt / d) for r, a, d in ((1.0, 0.5, 0.9), (2.76, 0.3, 0.5), (5.4, 0.15, 0.3)))
        c = lpf(c, 1400) * 0.12
        pan = rng.uniform(0.15, 0.85)
        out[s0:s0 + m, 0] += c * (1 - pan); out[s0:s0 + m, 1] += c * pan
    return loop(out)


def write_ogg(name, x, gain=0.6):
    x = x / (np.max(np.abs(x)) or 1) * gain
    tmp = tempfile.NamedTemporaryFile(suffix='.wav', delete=False).name
    with wave.open(tmp, 'wb') as w:
        w.setnchannels(2); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((np.clip(x, -1, 1) * 32767).astype(np.int16).tobytes())
    out = os.path.join(OUT, name + '.ogg')
    subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-i', tmp, '-c:a', 'libvorbis', '-q:a', '1', out], check=True)
    os.unlink(tmp)
    print('%-10s %5.1fs %4d KB' % (name, len(x) / SR, os.path.getsize(out) // 1024))


if __name__ == '__main__':
    write_ogg('amb_abyss', abyss(), 0.6)
    write_ogg('amb_ruins', ruins(), 0.55)
