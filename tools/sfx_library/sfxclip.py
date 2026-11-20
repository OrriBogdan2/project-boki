"""Shared clip maths for the sfx library tools: decode, find events, measure, cut and level.
Needs numpy and ffmpeg. Audio is only ever read from the private library and measured here."""

import math
import subprocess

import numpy as np

SR = 44100
HOP = 220  # 5 ms
LEAD = int(0.004 * SR)  # kept before the onset
BANDS = {"low": (20, 250), "mid": (250, 2000), "high": (2000, 6000), "air": (6000, 20000)}


def decode(path, max_s=40.0):
    cmd = ["ffmpeg", "-v", "error", "-t", str(max_s), "-i", path, "-ac", "1", "-ar", str(SR), "-f", "f32le", "-"]
    return np.frombuffer(subprocess.run(cmd, capture_output=True).stdout, dtype=np.float32).copy()


def db(v):
    return 20 * math.log10(max(float(v), 1e-9))


def env_db(x, hop=HOP):
    """RMS in dBFS per `hop` samples (window 2 hops)."""
    n = len(x) // hop
    if n < 2:
        return np.full(1, db(np.sqrt(np.mean(x**2))) if len(x) else -120.0)
    p = np.convolve(x * x, np.ones(2 * hop) / (2 * hop), mode="same")[hop // 2 : n * hop : hop][:n]
    return 10 * np.log10(np.maximum(p, 1e-12))


def active_rms_db(x):
    pk = float(np.max(np.abs(x)))
    act = np.abs(x) > pk * 0.02
    return db(np.sqrt(np.mean(x[act] ** 2)))


def events(x, floor_db=-60.0, span_db=40.0, gap_s=0.12, min_s=0.03):
    """[(start, end)] sample ranges of sounds in x: louder than span_db under the file peak, merged over short gaps."""
    e = env_db(x)
    on = e > max(float(e.max()) - span_db, floor_db)
    out, i, n = [], 0, len(on)
    while i < n:
        if not on[i]:
            i += 1
            continue
        j = i
        while j < n and (on[j] or on[j : j + int(gap_s * SR / HOP) + 1].any()):
            j += 1
        if (j - i) * HOP >= min_s * SR:
            seg = np.abs(x[i * HOP : j * HOP])
            first = int(np.argmax(seg > seg.max() * 0.08))
            out.append((max(0, i * HOP + first - LEAD), j * HOP))
        i = j + 1
    return out


def cut(x, start, end, max_s, fade_s=0.015):
    """Event x[start:end] kept to max_s; a clip that is cut short gets a longer fade (0.06 s)."""
    cap = int(max_s * SR)
    fade = int((fade_s if end - start <= cap else 0.06) * SR)
    y = x[start : min(end + fade, start + cap)].copy()
    fade = min(fade, len(y) // 2)
    if fade:
        y[-fade:] *= np.linspace(1, 0, fade)
    return y


def loop_cut(x, start, length_s, xfade_s=0.25):
    """A seamless loop from a steady stretch: the last xfade_s is cross-faded into the head (equal power)."""
    n, k = int(length_s * SR), int(xfade_s * SR)
    y = x[start : start + n].copy()
    t = np.linspace(0, np.pi / 2, k)
    head = y[:k] * np.sin(t) + y[-k:] * np.cos(t)
    return np.concatenate([head, y[k:-k]])


def centroid(y, sr=SR):
    sp = np.abs(np.fft.rfft(y * np.hanning(len(y)))) ** 2
    f = np.fft.rfftfreq(len(y), 1 / sr)
    return float((f * sp).sum() / max(sp.sum(), 1e-12))


def features(y, noise_db):
    """Measurements of a trimmed clip y (noise_db: quietest stretch of its source file)."""
    pk = float(np.max(np.abs(y)))
    e = env_db(y, 110)  # 2.5 ms
    pk_i = int(np.argmax(np.abs(y)))
    lo = int(np.argmax(np.abs(y) > pk * 0.1))
    f = {"len": len(y) / SR, "peak_db": db(pk), "rms_db": active_rms_db(y), "attack_ms": (pk_i - lo) / SR * 1000}
    f["snr"] = f["peak_db"] - noise_db
    f["clip"] = float(np.mean(np.abs(y) > 0.99))
    below = np.nonzero(e < float(e.max()) - 30)[0]
    after = below[below > int(np.argmax(e))]
    f["decay_ms"] = (int(after[0]) * 2.5) if len(after) else len(y) / SR * 1000
    w = y[: int(0.5 * SR)]
    sp = np.abs(np.fft.rfft(w * np.hanning(len(w)))) ** 2 + 1e-18
    fr = np.fft.rfftfreq(len(w), 1 / SR)
    f["centroid"] = float((fr * sp).sum() / sp.sum())
    f["rolloff"] = float(fr[min(len(fr) - 1, int(np.searchsorted(np.cumsum(sp) / sp.sum(), 0.85)))])
    band = (fr > 100) & (fr < 10000)
    f["flat"] = float(np.exp(np.mean(np.log(sp[band]))) / np.mean(sp[band]))
    for name, (a, b) in BANDS.items():
        f[name] = float(sp[(fr >= a) & (fr < b)].sum() / sp.sum())
    third = max(len(y) // 3, 256)
    f["rise"] = centroid(y[-third:]) / max(centroid(y[:third]), 1.0)
    f["env_cv"] = float(np.std(e) / max(abs(float(np.mean(e))), 1.0))
    return f


def level(y, rms_db, peak_db=-1.0):
    """Gain so the active part sits at rms_db without the peak passing peak_db (as tools/sfx_lib.py does)."""
    g = min(10 ** ((rms_db - active_rms_db(y)) / 20), 10 ** (peak_db / 20) / float(np.max(np.abs(y))))
    return y * g


def write_audio(y, path):
    """Mono SR file by extension: .wav 16-bit, .mp3 or .ogg."""
    codec = {"wav": ["-c:a", "pcm_s16le"], "mp3": ["-c:a", "libmp3lame", "-q:a", "3"], "ogg": ["-c:a", "libvorbis"]}
    cmd = ["ffmpeg", "-v", "error", "-y", "-f", "f32le", "-ar", str(SR), "-ac", "1", "-i", "-"]
    p = subprocess.Popen(cmd + codec[path.rsplit(".", 1)[1]] + [path], stdin=subprocess.PIPE)
    p.communicate(np.clip(y, -1, 1).astype(np.float32).tobytes())
