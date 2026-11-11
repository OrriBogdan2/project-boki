"""Ambience beds for expeditions that fade in and out by where you are (MusicDir drives them):

    amb_abyss   wind over the drop: a deep, slow howl with the odd hollow whistle in it
    amb_ruins   the old world's ruins: a low stone drone, creaks and settling rubble, far-off metal

and each map region's own low bed (the layout's regions[].bed; one plays at a time, crossfading):

    amb_heights wind on the heights: a bright gusting rush with a thin whistle in the strongest gusts
    amb_shore   water by the shore isles: slow swells washing in and drawing back, small laps, a drip
    amb_woods   insects in the wood: crickets trilling in a few voices, a far buzzing swell, leaves
    amb_heart   the hum round the Heart: a deep drone of slowly beating partials that breathes

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


def at(x, db):
    """x scaled to an RMS of db (dBFS): sets a layer's place in a bed's mix."""
    return x * (10 ** (db / 20) / (np.sqrt(np.mean(x ** 2)) or 1))


def pan_into(out, k, x, pan):
    """Adds the mono x into the stereo out from sample k, pan 0 (left) .. 1 (right)."""
    out[k:k + len(x), 0] += x * (1 - pan)
    out[k:k + len(x), 1] += x * pan


def heights(seconds=20.0):
    n = int(SR * (seconds + 2.0))
    gust = slow(n, 0.16) ** 2              # one gust curve for both ears, so the rush moves as one
    chans = []
    for _ in range(2):
        rush = at(bpf(rng.standard_normal(n), 220, 2400) * (0.25 + 0.75 * gust), -20)
        body = at(lpf(rng.standard_normal(n), 160) * (0.6 + 0.4 * slow(n, 0.06)), -23)
        whistle = at(svf(rng.standard_normal(n), slow(n, 0.1, 850, 1600), 24.0), -30) * gust ** 2 * 2.0
        chans.append(rush + body + whistle)
    return loop(np.stack(chans, 1))


def shore(seconds=24.0):
    n = int(SR * (seconds + 2.0)); out = np.zeros((n, 2))
    k = 0
    while k < n - SR:   # swells: soft noise rising as it washes in, brighter at the top, then a long draw back
        m = min(int(SR * rng.uniform(5.5, 8.5)), n - k); tt = np.arange(m) / SR
        rise = rng.uniform(1.4, 2.2)
        env = np.where(tt < rise, np.sin(np.pi / 2 * tt / rise) ** 2, np.exp(-(tt - rise) / rng.uniform(1.4, 2.4)))
        wash = at(lpf(rng.standard_normal(m), 700), -18) + at(bpf(rng.standard_normal(m), 900, 3200), -24) * env
        pan_into(out, k, wash * env, rng.uniform(0.3, 0.7))
        k += int(m * rng.uniform(0.55, 0.8))     # the next swell comes in before this one has drawn back
    for _ in range(int(seconds * 1.6)):    # small laps against the rock
        L = int(SR * rng.uniform(0.06, 0.22)); k = rng.integers(0, n - L)
        pan_into(out, k, at(bpf(rng.standard_normal(L), 250, 1100), -26) * np.hanning(L) * rng.uniform(0.3, 1.0),
                 rng.uniform(0.1, 0.9))
    for _ in range(int(seconds / 3)):      # the odd drip: a tiny bubble, its pitch rising as it closes
        L = int(SR * 0.08); k = rng.integers(0, n - L); tt = np.arange(L) / SR
        f = rng.uniform(700, 1300) * (1 + 1.5 * tt / tt[-1])
        pan_into(out, k, np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-tt / 0.018) * 0.03, rng.uniform(0.1, 0.9))
    return loop(out)


def woods(seconds=20.0):
    n = int(SR * (seconds + 2.0)); t = np.arange(n) / SR; out = np.zeros((n, 2))
    for c in range(2):                      # the wood's own air, and leaves stirring now and then
        out[:, c] += at(lpf(rng.standard_normal(n), 300), -27)
        out[:, c] += at(bpf(rng.standard_normal(n), 1800, 6000) * slow(n, 0.3) ** 3, -34)
    for _ in range(5):   # crickets: a chirp of 3-6 quick pulses every 0.4-0.9 s, each its own pitch and place
        rate = rng.uniform(26, 36); period = rng.uniform(0.4, 0.9); pulse = int(SR * 0.6 / rate)
        gate = np.zeros(n); k = int(SR * rng.uniform(0, period))
        while k < n - SR:
            for j in range(rng.integers(3, 7)):
                s = k + int(j * SR / rate)
                gate[s:s + pulse] = np.hanning(pulse)
            k += int(SR * period * rng.uniform(0.85, 1.15))
            if rng.random() < 0.12:
                k += int(SR * rng.uniform(1.0, 3.0))    # a rest
        voice = np.sin(2 * np.pi * rng.uniform(3900, 5300) * t) * gate
        pan_into(out, 0, at(voice, rng.uniform(-36, -28)), rng.uniform(0.1, 0.9))
    m = int(SR * 9); tt = np.arange(m) / SR      # a far buzzing swell up in the canopy
    buzz = bpf(rng.standard_normal(m), 3800, 7000) * (0.6 + 0.4 * np.sin(2 * np.pi * 95 * tt))
    pan_into(out, rng.integers(0, n - m), at(buzz, -32) * np.sin(np.pi * tt / tt[-1]) ** 2, rng.uniform(0.2, 0.8))
    return loop(out)


def heart(seconds=24.0):
    """Every partial makes whole cycles in the loop, so the drone needs no crossfade at the seam."""
    n = int(SR * seconds); t = np.arange(n) / SR

    def hz(f): return round(f * seconds) / seconds

    breath = 0.7 + 0.3 * np.sin(2 * np.pi * hz(0.25) * t)
    out = np.zeros((n, 2))
    for c, beat in ((0, 0.0), (1, hz(0.33))):     # the right ear a third of a hertz sharp: a slow beat between them
        partials = ((55, 1.0), (110, 0.55), (165, 0.3), (220, 0.2), (275, 0.1))
        drone = sum(a * np.sin(2 * np.pi * (hz(f) + beat * r) * t + rng.uniform(0, 2 * np.pi))
                    for r, (f, a) in enumerate(partials, 1))
        shimmer = sum(np.sin(2 * np.pi * hz(f) * t + rng.uniform(0, 2 * np.pi)) for f in (880, 1320, 1760))
        out[:, c] = at(np.tanh(drone * 0.8) * breath, -20) + at(shimmer, -40) * (1 + np.sin(2 * np.pi * hz(1 / 6) * t + c))
    return out + loop(np.stack([at(lpf(rng.standard_normal(n + 2 * SR), 200), -32) for _ in range(2)], 1))


def write_ogg(name, x, gain=0.6, rms_db=None):
    """gain: the peak; rms_db: the RMS a region bed sits at instead (so one region is as loud as the next),
    its peak still kept under gain."""
    x = x / (np.max(np.abs(x)) or 1) * gain
    if rms_db is not None:
        x = x * min(10 ** (rms_db / 20) / np.sqrt(np.mean(x ** 2)), 1.0)
    tmp = tempfile.NamedTemporaryFile(suffix='.wav', delete=False).name
    with wave.open(tmp, 'wb') as w:
        w.setnchannels(2); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((np.clip(x, -1, 1) * 32767).astype(np.int16).tobytes())
    out = os.path.join(OUT, name + '.ogg')
    subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-i', tmp, '-c:a', 'libvorbis', '-q:a', '1', out], check=True)
    os.unlink(tmp)
    rms = 20 * np.log10(np.sqrt(np.mean(x ** 2)))
    print('%-11s %5.1fs %4d KB  rms %.1f dB' % (name, len(x) / SR, os.path.getsize(out) // 1024, rms))


if __name__ == '__main__':
    write_ogg('amb_abyss', abyss(), 0.6)
    write_ogg('amb_ruins', ruins(), 0.55)
    # the region beds: one level for all (the peak ceiling is content/rules/sfx_levels.json's -1 dB)
    write_ogg('amb_heights', heights(), 0.89, -21.0)
    write_ogg('amb_shore', shore(), 0.89, -21.0)
    write_ogg('amb_woods', woods(), 0.89, -23.0)     # insects sit where the ear is keenest: a little lower
    write_ogg('amb_heart', heart(), 0.89, -20.0)     # a low drone reads quieter than its level: a little higher
