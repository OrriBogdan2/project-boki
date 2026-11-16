"""Ambience beds for expeditions that fade in and out by where you are (MusicDir drives them):

    amb_abyss   wind over the drop: a deep, slow howl with the odd hollow whistle in it
    amb_ruins   the old world's ruins: a low stone drone, creaks and settling rubble, far-off metal
    amb_meadow  grass country: a soft breeze, rustling blades, insects, the odd far bird
    amb_cliffs  bare high rock: wind whistling through crags, hollow thuds, pebbles ticking down
    amb_water   a shore: waves swelling and drawing back, slaps and drips
    amb_gust    weather: wind that builds to a gust and drops away (rain is amb_rain, from gen_music.py)
    amb_blight  a low rumble under the ground: sub tones beating, a slow throb, a distant groan
    amb_title   the title screen: a wide slow drone and sparse bell tones, calm and a little uneasy

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


def put(out, sig, s0, pan):
    """Mix a mono sound into the stereo bed at sample s0, pan 0 (left) .. 1 (right)."""
    e = min(len(out), s0 + len(sig))
    out[s0:e, 0] += sig[:e - s0] * (1 - pan); out[s0:e, 1] += sig[:e - s0] * pan


def stereo(f, n):
    return np.stack([f(n) for _ in range(2)], 1)


def bell(f0, secs, decay):
    """A struck bell: a few inharmonic partials, each fading at its own rate."""
    t = np.arange(int(SR * secs)) / SR
    return sum(a * np.sin(2 * np.pi * f0 * r * t) * np.exp(-t / (decay * d)) for r, a, d in ((1.0, 1.0, 1.0), (2.01, 0.4, 0.6), (3.97, 0.2, 0.35), (5.4, 0.1, 0.2)))


def meadow(seconds=28.0):
    n = int(SR * (seconds + 2.0)); t = np.arange(n) / SR
    breeze = stereo(lambda n: lpf(rng.standard_normal(n), 650) * slow(n, 0.15, 0.3, 1.0) * 1.4, n)
    rustle = stereo(lambda n: bpf(rng.standard_normal(n), 2200, 6500) * slow(n, 0.35, 0.0, 1.0) ** 3 * 0.35, n)
    out = breeze + rustle
    for _ in range(26):      # insects: a chirr of fast pulses, a few of them at a time
        s0 = rng.integers(0, n - SR); m = int(SR * rng.uniform(0.4, 1.6)); tt = np.arange(m) / SR
        hz = rng.uniform(3900, 5200); rate = rng.uniform(22, 38)
        gate = (np.sin(2 * np.pi * rate * tt) > 0.2) * np.sin(np.pi * tt / tt[-1]) ** 2
        put(out, np.sin(2 * np.pi * hz * tt) * gate * rng.uniform(0.03, 0.07), s0, rng.uniform(0.1, 0.9))
    for _ in range(4):       # a far bird: two or three falling whistles
        s0 = rng.integers(0, n - SR * 2); base = rng.uniform(1900, 2800)
        for k in range(rng.integers(2, 4)):
            m = int(SR * 0.16); tt = np.arange(m) / SR
            f = base * (1.25 - 0.4 * tt / tt[-1])
            c = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.sin(np.pi * tt / tt[-1]) * 0.05
            put(out, lpf(c, 3500), s0 + k * int(SR * 0.24), 0.2 + 0.6 * (k % 2))
    return loop(out)


def cliffs(seconds=30.0):
    n = int(SR * (seconds + 2.0))
    out = stereo(lambda n: lpf(rng.standard_normal(n), 260) * slow(n, 0.1, 0.2, 1.0) * 0.35, n)
    for lo, hi, amp in ((420, 640, 1.6), (700, 1000, 1.2), (1100, 1500, 0.8)):     # wind finding the cracks
        out += stereo(lambda n: bpf(rng.standard_normal(n), lo, hi) * np.clip(slow(n, 0.13, -0.6, 1.0), 0, 1) ** 2 * amp, n)
    for _ in range(4):       # a hollow knock in the rock, far below
        s0 = rng.integers(0, n - SR); tt = np.arange(int(SR * 1.2)) / SR
        put(out, np.sin(2 * np.pi * rng.uniform(48, 70) * tt) * np.exp(-tt * 5) * 0.5, s0, rng.uniform(0.2, 0.8))
    for _ in range(14):      # pebbles ticking down a slope
        s0 = rng.integers(0, n - SR); pan = rng.uniform(0.15, 0.85)
        for k in range(rng.integers(3, 9)):
            m = int(SR * 0.03); tt = np.arange(m) / SR
            tick = bpf(rng.standard_normal(m + 64), 1800, 4800)[64:] * np.exp(-tt * 180) * rng.uniform(0.1, 0.35)
            put(out, tick, s0 + int(SR * 0.05 * k ** 1.3), pan)
    return loop(out)


def water(seconds=32.0):
    n = int(SR * (seconds + 2.0)); t = np.arange(n) / SR
    out = np.zeros((n, 2))
    for c in range(2):       # waves: a swell that rises, breaks into hiss and draws back; the two ears out of step
        period = seconds / 4.0; ph = (t / period + c * 0.17 + slow(n, 0.1, -0.04, 0.04)) % 1.0
        swell = np.sin(np.pi * ph ** 0.7) ** 2
        out[:, c] = lpf(rng.standard_normal(n), 900) * swell * 1.2 + bpf(rng.standard_normal(n), 1800, 6000) * swell ** 3 * 0.45
    out += stereo(lambda n: lpf(rng.standard_normal(n), 300) * 0.25, n)
    for _ in range(40):      # slaps and drips: a short rising bubble
        s0 = rng.integers(0, n - SR); m = int(SR * rng.uniform(0.04, 0.1)); tt = np.arange(m) / SR
        f = rng.uniform(350, 900) * (1 + 2.0 * tt / tt[-1])
        put(out, np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-tt * 40) * rng.uniform(0.04, 0.14), s0, rng.uniform(0.1, 0.9))
    return loop(out)


def gust(seconds=24.0):
    n = int(SR * (seconds + 2.0)); t = np.arange(n) / SR
    out = np.zeros((n, 2))
    for c in range(2):
        env = np.zeros(n)
        for _ in range(4):   # each gust builds over a few seconds and drops away quicker
            s0 = rng.integers(0, n - SR * 8); m = int(SR * rng.uniform(4.0, 7.0)); tt = np.arange(m) / m
            env[s0:s0 + m] = np.maximum(env[s0:s0 + m], tt ** 1.8 * (1 - tt) ** 0.8 * 4.5 * rng.uniform(0.6, 1.0))
        body = bpf(rng.standard_normal(n), 250, 900) * (0.15 + env)
        top = bpf(rng.standard_normal(n), 1400, 3800) * env ** 2 * 0.5      # the rush rides on the swell
        flutter = bpf(rng.standard_normal(n), 3000, 7000) * env ** 3 * (0.5 + 0.5 * np.sin(2 * np.pi * 9 * t)) * 0.2
        out[:, c] = body + top + flutter
    return loop(out)


def blight(seconds=30.0):
    n = int(SR * (seconds + 2.0)); t = np.arange(n) / SR
    out = np.zeros((n, 2))
    for c, (a, b) in enumerate(((38.0, 57.0), (38.6, 56.3))):      # two sub tones a hair apart: they beat slowly
        out[:, c] = 0.5 * np.sin(2 * np.pi * a * t) + 0.35 * np.sin(2 * np.pi * b * t)
        out[:, c] += lpf(rng.standard_normal(n), 110) * slow(n, 0.2, 0.3, 1.0) * 2.0
    throb = (0.55 + 0.45 * np.sin(2 * np.pi * t / (seconds / 12.0))) ** 2        # a heartbeat-slow pulse, 12 per loop
    out *= throb[:, None]
    for _ in range(3):       # a groan far off: a sawtooth sinking in pitch through a closing filter
        s0 = rng.integers(0, n - SR * 5); m = int(SR * rng.uniform(3.0, 4.5)); tt = np.arange(m) / SR
        f = rng.uniform(52, 70) * (1 - 0.25 * tt / tt[-1])
        saw = ((np.cumsum(f) / SR) % 1.0) * 2 - 1
        put(out, lpf(saw, 210) * np.sin(np.pi * tt / tt[-1]) ** 2 * 0.5, s0, rng.uniform(0.2, 0.8))
    return loop(out)


def title(seconds=40.0):
    n = int(SR * (seconds + 2.0)); t = np.arange(n) / SR
    out = np.zeros((n, 2))
    for c in range(2):       # a drone on D and A, each voice drifting a few cents, swelling and ebbing
        for hz, amp in ((73.4, 0.5), (110.0, 0.35), (146.8, 0.2), (220.5, 0.1)):
            det = 1 + 0.002 * (1 if c else -1) * np.sin(2 * np.pi * t / rng.uniform(9, 17))
            out[:, c] += amp * np.sin(2 * np.pi * np.cumsum(hz * det) / SR) * slow(n, 0.07, 0.4, 1.0)
        out[:, c] += bpf(rng.standard_normal(n), 3500, 8000) * slow(n, 0.09, 0.0, 1.0) ** 2 * 0.05      # airy shimmer
    for _ in range(7):       # far bell tones on a D minor pentatonic, one every few seconds
        hz = 146.8 * 2 ** (rng.choice([0, 3, 5, 7, 10, 12, 15]) / 12.0)
        s0 = rng.integers(0, n - SR * 6)
        put(out, lpf(bell(hz, 5.0, 1.4), 2500) * 0.08, s0, rng.uniform(0.15, 0.85))
    return loop(out, 3.0)


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
    write_ogg('amb_meadow', meadow(), 0.5)
    write_ogg('amb_cliffs', cliffs(), 0.5)
    write_ogg('amb_water', water(), 0.55)
    write_ogg('amb_gust', gust(), 0.6)
    write_ogg('amb_blight', blight(), 0.7)
    write_ogg('amb_title', title(), 0.5)
