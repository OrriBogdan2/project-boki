"""Shared building blocks for the per-group sound scripts (tools/gen_sfx_<group>.py).

    import sfx_lib as S
    S.reseed(1234)                       # each script its own random stream
    S.takes_cat('gunslinger_hurt', fn, 3, 'grunt')

It re-uses the synthesis primitives of tools/sfx_combat.py (filters, envelopes, kick, click, crack, sub,
tail, reflections, ring, grains, mix, at, sat) and adds:
  - CATS: one loudness target per category, so every Hunter, Boki and UI sound sits at the same level
    for what it is (docs/AUDIO.md). save_cat / takes_cat level a sound to its category and write it.
  - voice(): a wordless voice (grunt, gasp, cry) from a glottal pulse train through vowel formants.
  - chime(), creak(), fm(), sweep(), rattle(), hiss(): the textures several kits need; shape() and
    soft_in(): click-free envelopes.

44.1 kHz mono 16-bit, written to audio/. Original synthesis, no samples.
"""
import json, os, wave
import numpy as np
import sfx_combat as C
from sfx_combat import (SR, N, T, noise, lpf, hpf, bpf, env, mix, at, sat, kick, click, crack, sub, tail,
                        reflections, ring, grains, level)

__all__ = ['SR', 'N', 'T', 'noise', 'lpf', 'hpf', 'bpf', 'env', 'mix', 'at', 'sat', 'kick', 'click', 'crack',
           'sub', 'tail', 'reflections', 'ring', 'grains', 'level', 'CATS', 'reseed', 'rng', 'save_cat',
           'takes_cat', 'save_loop', 'shape', 'soft_in', 'voice', 'chime', 'creak', 'fm', 'sweep', 'rattle', 'hiss', 'pad']

# Category loudness (content/rules/sfx_levels.json, the same table --sfx-set-check measures against):
# RMS in dBFS over the audible part, and the peak ceiling. The game's volume_db at the call site then
# only expresses intent (a quiet tell, a loud ult), not a fix-up.
_LEVELS = json.load(open(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'content', 'rules',
                                      'sfx_levels.json')))
CATS = _LEVELS['cats']
PEAK_DB = _LEVELS['peak_db']

rng = C.rng


def reseed(seed):
    """Gives the calling script its own random stream (shared by sfx_combat's primitives)."""
    global rng
    C.rng = np.random.default_rng(seed)
    rng = C.rng
    return rng


def save_cat(name, x, cat):
    C.save(name, x, rms_db=CATS[cat], peak_db=PEAK_DB)


def save_loop(name, x, cat, xfade=0.06):
    """A seamless loop for Sfx.loop_start (a minigun spin, a charge hum): the last `xfade` seconds are
    cross-faded into the start, and there is no fade-in or fade-out, so it repeats without a dip or a
    click. Levelled to its category like save_cat."""
    x = hpf(np.asarray(x, dtype=float), 30)
    k = N(xfade)
    ramp = 0.5 - 0.5 * np.cos(np.pi * np.arange(k) / k)
    head = x[:k] * ramp + x[-k:] * (1.0 - ramp)
    x = np.concatenate([head, x[k:-k]])
    pk = np.max(np.abs(x)) or 1.0
    act = np.abs(x) > pk * 0.02
    x = x * (10 ** (CATS[cat] / 20) / (np.sqrt(np.mean(x[act] ** 2)) or 1.0))
    ceil = 10 ** (PEAK_DB / 20)
    knee = ceil * 0.6
    a = np.abs(x)
    x = np.where(a > knee, np.sign(x) * (knee + (ceil - knee) * np.tanh((a - knee) / (ceil - knee))), x)
    with wave.open(os.path.join(C.OUT, name + '.wav'), 'wb') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((np.clip(x, -1, 1) * 32767).astype(np.int16).tobytes())


def takes_cat(name, fn, n, cat):
    """name.wav plus name_1..n.wav, each fn(i) (Sfx plays a different take each time)."""
    C.takes(name, fn, n, rms_db=CATS[cat], peak_db=PEAK_DB)


def pad(x, d):
    """x padded with silence to d seconds (for mixing layers of different lengths)."""
    return np.concatenate([x, np.zeros(max(0, N(d) - len(x)))])


# ------------------------------------------------------------------ envelopes
def shape(d, a, hold, rel):
    """Raised-cosine attack over a, flat for hold, raised-cosine release over rel (length d)."""
    n = N(d); t = np.arange(n) / SR
    up = np.clip(t / max(a, 1e-4), 0, 1)
    down = np.clip((t - a - hold) / max(rel, 1e-4), 0, 1)
    return (0.5 - 0.5 * np.cos(np.pi * up)) * (0.5 + 0.5 * np.cos(np.pi * down))


def soft_in(x, ms=1.5):
    """A short raised-cosine fade-in, so a sound played many times a second never starts on a click."""
    n = N(ms / 1000.0); x = x.copy()
    x[:n] *= 0.5 - 0.5 * np.cos(np.pi * np.arange(n) / n)
    return x


# ------------------------------------------------------------------ textures
def sweep(f0, f1, d, shape='sin', curve=1.0):
    """A tone gliding from f0 to f1 (exponentially; curve > 1 holds the start longer)."""
    n = N(d); u = (np.arange(n) / max(1, n - 1)) ** curve
    f = f0 * (f1 / f0) ** u
    ph = 2 * np.pi * np.cumsum(f) / SR
    if shape == 'saw':
        return 2.0 * ((ph / (2 * np.pi)) % 1.0) - 1.0
    if shape == 'square':
        return np.sign(np.sin(ph))
    return np.sin(ph)


def fm(fc, ratio, index, d, decay=0.3, a=0.002):
    """Two-operator FM: bells and metal (ratio non-integer), electric buzz (high index)."""
    t = T(d)
    mod = np.sin(2 * np.pi * fc * ratio * t) * index * np.exp(-t / max(decay, 1e-3))
    return np.sin(2 * np.pi * fc * t + mod) * env(N(d), a, decay)


def chime(f, d=0.8, decay=0.35, partials=((1.0, 1.0), (2.76, 0.45), (5.4, 0.22), (8.93, 0.1))):
    """A small bell or crystal: inharmonic partials, the high ones dying first."""
    t = T(d); out = np.zeros(N(d))
    for k, g in partials:
        out += g * np.sin(2 * np.pi * f * k * t + rng.uniform(0, 6.28)) * np.exp(-t / (decay / k ** 0.5))
    return out * shape(d, 0.003, 0.0, d * 0.25)


def creak(d, f0=90, f1=60, roughness=0.6, bright=2500):
    """Wood or hull under strain: a slow stick-slip pulse train through a resonant band."""
    n = N(d); t = np.arange(n) / SR
    f = f0 * (f1 / f0) ** (t / d) * (1 + 0.15 * np.sin(2 * np.pi * 3.1 * t))
    ph = np.cumsum(f) / SR
    pulses = (np.diff(np.floor(ph), prepend=0) > 0).astype(float)
    pulses *= 1 + roughness * rng.standard_normal(n)
    body = bpf(pulses, 180, bright) + 0.3 * bpf(pulses, 400, 900)
    return body * env(n, 0.04, d * 0.6)


def rattle(d, rate=40, lo=1800, hi=7000, jitter=0.4, decay=None):
    """Many small metal clicks: a chain, coins, loose junk."""
    n = N(d); out = np.zeros(n)
    count = int(rate * d)
    for _ in range(count):
        s0 = int(rng.uniform(0, max(1, n - N(0.02))))
        g = N(rng.uniform(0.004, 0.012))
        f = rng.uniform(lo, hi)
        tt = np.arange(g) / SR
        out[s0:s0 + g] += np.sin(2 * np.pi * f * tt) * np.exp(-tt / 0.003) * rng.uniform(1 - jitter, 1.0)
    e = env(n, 0.002, decay) if decay else np.ones(n)
    return out * e


def hiss(d, lo=2000, hi=9000, a=0.02, decay=0.3):
    """Steam, gas, a fuse: band noise with a soft start."""
    return bpf(noise(d), lo, hi) * env(N(d), a, decay)


# ------------------------------------------------------------------ voice (wordless)
VOWELS = {   # formant centre frequencies (Hz) and gains: F1, F2, F3
    'ah': ((800, 1.0), (1200, 0.5), (2500, 0.25)),
    'uh': ((600, 1.0), (1000, 0.45), (2400, 0.2)),
    'oh': ((500, 1.0), (850, 0.5), (2500, 0.15)),
    'eh': ((550, 1.0), (1800, 0.45), (2500, 0.25)),
    'ee': ((300, 1.0), (2300, 0.4), (3000, 0.25)),
    'mm': ((280, 1.0), (900, 0.15), (2200, 0.05)),
}


def voice(d, f0, f1, vowel='uh', breath=0.25, rasp=0.0, vib=0.0, scale=1.0, a=0.015, decay=None):
    """A wordless vocal sound: a glottal pulse train gliding f0 -> f1 through a vowel's formants.
    scale shifts the formants (0.85 a bigger body, 1.2 a small one); rasp adds roughness (a growl or
    strain); breath mixes in aspiration noise. Grunts are short (0.12-0.3 s), cries longer."""
    n = N(d); t = np.arange(n) / SR
    f = f0 * (f1 / f0) ** (t / d)
    f = f * (1 + vib * np.sin(2 * np.pi * 5.5 * t)) * (1 + 0.01 * rng.standard_normal(n).cumsum() / np.sqrt(n))
    ph = np.cumsum(f) / SR
    saw = 2.0 * (ph % 1.0) - 1.0
    glottal = lpf(saw, 3500) + rasp * bpf(rng.standard_normal(n), 80, 400) * np.abs(saw)
    src = glottal + breath * hpf(noise(d), 900)
    out = np.zeros(n)
    for fc, g in VOWELS[vowel]:
        fc *= scale
        out += g * bpf(src, fc * 0.82, fc * 1.18)
    tail_fade = shape(d, 0.0, d * 0.7, d * 0.3)      # a release, so the voice never stops dead
    return sat(out * env(n, a, decay if decay else d * 0.45) * tail_fade, 1.5)
