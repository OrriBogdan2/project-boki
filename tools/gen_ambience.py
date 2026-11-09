"""Ambience beds for expeditions that fade in and out by where you are (MusicDir drives them):

    amb_open    grass and bloom country: soft wind through leaves, crickets
    amb_crown   the Crown's gloom: a hollow stone breath with a low two-note drone
    amb_cliff   frost and storm highlands: thin high wind, gusting, fine ice hiss
    amb_ember   the Cinder country: low furnace roar, crackle, heat shimmer
    amb_title   the title screen: calm, a slow breath of air with a faint glassy shimmer
    amb_gust    a layer the weather drives: big wind swells with grit (ash storm, dusk)
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


def open_country(seconds=24.0):
    n = int(SR * (seconds + 2.0)); t = np.arange(n) / SR
    chans = []
    for c in range(2):
        leaves = bpf(rng.standard_normal(n), 1400, 5200) * slow(n, 0.35, 0.05, 0.5) * slow(n, 1.3, 0.4, 1.0)
        air = lpf(rng.standard_normal(n), 700) * slow(n, 0.1, 0.3, 1.0) * 1.2
        chans.append(air + leaves * 0.9)
    out = np.stack(chans, 1)
    # crickets: bursts of a high pulsed tone, each one a little off in pitch, placed on one side
    for _ in range(14):
        s0 = rng.integers(0, n - SR * 3); m = int(SR * rng.uniform(1.5, 2.8)); tt = np.arange(m) / SR
        f = rng.uniform(3600, 4600); rate = rng.uniform(26, 34)
        chirp = np.sin(2 * np.pi * f * tt) * (np.sin(2 * np.pi * rate * tt) > 0.2) * np.sin(np.pi * tt / tt[-1]) ** 2 * 0.045
        pan = rng.uniform(0.1, 0.9)
        out[s0:s0 + m, 0] += chirp * (1 - pan); out[s0:s0 + m, 1] += chirp * pan
    return loop(out)


def crown(seconds=28.0):
    n = int(SR * (seconds + 2.0)); t = np.arange(n) / SR
    chans = []
    for c in range(2):
        breath = svf(rng.standard_normal(n), slow(n, 0.07, 140, 360), 9.0) * (0.25 + 0.75 * slow(n, 0.09, 0.0, 1.0) ** 2) * 0.5
        floor_ = lpf(rng.standard_normal(n), 160) * 1.4
        drone = (np.sin(2 * np.pi * (46.0 + 0.3 * c) * t) + 0.6 * np.sin(2 * np.pi * (69.0 - 0.4 * c) * t)) * 0.1 * slow(n, 0.06, 0.4, 1.0)
        chans.append(breath + floor_ + drone)
    return loop(np.stack(chans, 1))


def cliff(seconds=26.0):
    n = int(SR * (seconds + 2.0))
    chans = []
    for c in range(2):
        gust = slow(n, 0.14, 0.15, 1.0) ** 1.5
        thin = svf(rng.standard_normal(n), slow(n, 0.18, 900, 2300), 14.0) * gust * 0.55
        mid = svf(rng.standard_normal(n), slow(n, 0.1, 350, 700), 6.0) * gust * 0.4
        ice = hpf(rng.standard_normal(n), 6000) * slow(n, 0.3, 0.0, 1.0) ** 3 * 0.05
        chans.append(thin + mid + ice)
    return loop(np.stack(chans, 1))


def ember(seconds=24.0):
    n = int(SR * (seconds + 2.0))
    out = np.zeros((n, 2))
    for c in range(2):
        roar = bpf(rng.standard_normal(n), 70, 380) * slow(n, 0.2, 0.4, 1.0) * 1.8
        shimmer = bpf(rng.standard_normal(n), 3500, 7500) * slow(n, 0.5, 0.0, 1.0) ** 2 * 0.07
        out[:, c] = roar + shimmer
    # crackle: little pops of filtered noise, a few every second
    for _ in range(int(seconds * 7)):
        k = rng.integers(0, n - 800); L = rng.integers(60, 500)
        pop = bpf(rng.standard_normal(L + 64), 1500, 6500)[64:] * np.exp(-np.arange(L) / (L / 4.0)) * rng.uniform(0.1, 0.5)
        pan = rng.uniform(0.1, 0.9)
        out[k:k + L, 0] += pop * (1 - pan); out[k:k + L, 1] += pop * pan
    return loop(out)


def title(seconds=30.0):
    n = int(SR * (seconds + 2.0)); t = np.arange(n) / SR
    out = np.zeros((n, 2))
    for c in range(2):
        air = lpf(rng.standard_normal(n), 520) * (0.4 + 0.6 * slow(n, 0.07, 0.0, 1.0)) * 1.5
        hush = bpf(rng.standard_normal(n), 2000, 4200) * slow(n, 0.1, 0.0, 1.0) ** 2 * 0.1
        out[:, c] = air + hush
    # a faint glassy shimmer: three soft partials that swell and fade, a long way off
    for _ in range(6):
        s0 = rng.integers(0, n - SR * 6); m = int(SR * rng.uniform(4.0, 5.5)); tt = np.arange(m) / SR
        f0 = rng.choice([392.0, 523.25, 587.33, 783.99]) * 2
        g = sum(a * np.sin(2 * np.pi * f0 * r * tt + rng.uniform(0, 6)) for r, a in ((1.0, 1.0), (2.0, 0.35), (3.01, 0.15)))
        g = g * np.sin(np.pi * tt / tt[-1]) ** 3 * 0.012
        pan = rng.uniform(0.2, 0.8)
        out[s0:s0 + m, 0] += g * (1 - pan); out[s0:s0 + m, 1] += g * pan
    return loop(out)


def gust(seconds=22.0):
    n = int(SR * (seconds + 2.0))
    chans = []
    for c in range(2):
        swell = np.clip(slow(n, 0.16, -0.5, 1.0), 0, 1) ** 2
        body = svf(rng.standard_normal(n), 250 + 1100 * swell + slow(n, 0.4, 0, 200), 3.5) * swell * 0.9
        roar = lpf(rng.standard_normal(n), 420) * swell * 0.8
        grit = hpf(rng.standard_normal(n), 3000) * swell ** 3 * 0.09
        chans.append(body + roar + grit)
    return loop(np.stack(chans, 1))


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
    write_ogg('amb_open', open_country(), 0.5)
    write_ogg('amb_crown', crown(), 0.55)
    write_ogg('amb_cliff', cliff(), 0.55)
    write_ogg('amb_ember', ember(), 0.55)
    write_ogg('amb_title', title(), 0.4)
    write_ogg('amb_gust', gust(), 0.6)
