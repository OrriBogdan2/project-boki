"""Synthesizes the Hunter Wisp's hum into audio/wisp_hum.wav: the quiet low drone a downed Hunter's
Wisp gives off (docs/decisions/0019-downed-wisp.md), and audio/wisp_hum_end.wav, its fall-away when the
Wisp is revived or bled out: the same drone sinking an octave and fading over 0.9 s. A seamless two-second loop: every partial is a
whole number of cycles long and there are no fades, so Sfx.loop_hold can run it round for as long as
the Hunter is down. Also the two Boki summon cues (BokiWispPop, docs/AUDIO.md): audio/wisp_burst.wav, a bright
bloom as the Boki bursts out of its wisp, and audio/wisp_fold.wav, a soft inward swish as it folds back in.
Standard library only (no numpy), so any worker can rerun it.

    python3 tools/gen_wisp_sfx.py      (then: godot --headless --import)
"""
import math
import os
import random
import wave

SR = 22050
OUT = os.path.join(os.path.dirname(__file__), '..', 'audio')
LOOP_S = 2.0
# (hz, gain): D2 and its first partials. One partial sits half a hertz off so the drone breathes once
# per loop instead of standing dead still. Every frequency is a multiple of 0.5 Hz: whole cycles in 2 s.
PARTIALS = ((73.5, 1.0), (74.0, 0.55), (110.0, 0.4), (147.0, 0.3), (220.5, 0.1))
RMS_DB = -20.0      # the palette's loudness, under the music (gen_sfx.py)
BOKI_RMS_DB = -19.0  # the "boki" category (content/rules/sfx_levels.json), measured over the audible part
PEAK_DB = -1.5       # under the category's -1 dB peak ceiling
BURST_S = 0.45
FOLD_S = 0.3


END_S = 0.9


def save(name, x):
    rms = math.sqrt(sum(v * v for v in x) / len(x))
    k = 10 ** (RMS_DB / 20) / rms
    frames = b''.join(int(max(-0.95, min(0.95, v * k)) * 32767).to_bytes(2, 'little', signed=True) for v in x)
    with wave.open(os.path.join(OUT, name + '.wav'), 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(frames)


def save_boki(name, x):
    """Levels x to the boki category: RMS over the samples above 2% of the peak, peak under PEAK_DB."""
    pk = max(abs(v) for v in x)
    act = [v for v in x if abs(v) > pk * 0.02]
    k = 10 ** (BOKI_RMS_DB / 20) / math.sqrt(sum(v * v for v in act) / len(act))
    k = min(k, 10 ** (PEAK_DB / 20) / pk)
    frames = b''.join(int(v * k * 32767).to_bytes(2, 'little', signed=True) for v in x)
    with wave.open(os.path.join(OUT, name + '.wav'), 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(frames)


def air(n, seed, k=0.35):
    """Soft airy noise: white noise through a one-pole low-pass (k is the pole, higher = darker)."""
    rng = random.Random(seed)
    y, out = 0.0, []
    for _ in range(n):
        y = k * y + (1.0 - k) * rng.uniform(-1.0, 1.0)
        out.append(y)
    return out


def burst():
    """A bright bloom: a bell-like chord opens as a rising glide (a soft 'pwip'), with a breath of air."""
    n = int(SR * BURST_S)
    gust = air(n, 1141)
    out, ph = [], [0.0, 0.0, 0.0]
    for i in range(n):
        u = i / n
        t = i / SR
        glide = 1.0 - math.exp(-t * 22.0)                      # 0 to 1 within about 0.1 s
        f = 520.0 + 760.0 * glide                              # 520 Hz rising to 1280 Hz
        for j, r in enumerate((1.0, 2.0, 3.0)):
            ph[j] += 2 * math.pi * f * r / SR
        attack = min(i / (0.012 * SR), 1.0)
        body = (math.sin(ph[0]) + 0.35 * math.sin(ph[1]) + 0.12 * math.sin(ph[2])) * attack * math.exp(-t * 7.5)
        ring_ = math.sin(2 * math.pi * 1980.0 * t) * attack * math.exp(-t * 11.0) * 0.3   # the sparkle on top
        breath = gust[i] * attack * math.exp(-t * 16.0) * 0.45
        out.append((body + ring_ + breath) * (1.0 - u ** 6))
    return out


def fold():
    """A soft inward swish: an airy band sweeps down and in while a quiet tone falls and shrinks."""
    n = int(SR * FOLD_S)
    gust = air(n, 2207, 0.0)
    out, ph, lp = [], 0.0, 0.0
    for i in range(n):
        u = i / n
        k = 0.15 + 0.8 * u                                      # the low-pass closes: bright to dull
        lp = k * lp + (1.0 - k) * gust[i]
        swell = math.sin(math.pi * min(u * 1.4, 1.0) ** 0.7) * (1.0 - u) ** 0.5
        ph += 2 * math.pi * (1500.0 - 1000.0 * u ** 0.6) / SR   # 1500 Hz sinking to 500 Hz
        tone = math.sin(ph) * min(i / (0.02 * SR), 1.0) * (1.0 - u) ** 2 * 0.35
        out.append((lp * 1.8 * swell + tone) * min((n - i) / (0.02 * SR), 1.0))
    return out


def hum_end():
    n = int(SR * END_S)
    out, ph = [], 0.0
    for i in range(n):
        k = i / n
        ph += 2 * math.pi * PARTIALS[0][0] * (2.0 - k ** 0.7) / SR      # 147 Hz sinking to 73.5 Hz
        fade = min(i / (0.03 * SR), 1.0) * (1.0 - k) ** 2
        out.append(fade * sum(g * math.sin(ph * r) for r, g in ((1.0, 1.0), (2.0, 0.4), (3.0, 0.25))))
    return out


def main():
    n = int(SR * LOOP_S)
    save('wisp_hum', [sum(g * math.sin(2 * math.pi * f * i / SR) for f, g in PARTIALS) for i in range(n)])
    save('wisp_hum_end', hum_end())
    save_boki('wisp_burst', burst())
    save_boki('wisp_fold', fold())


if __name__ == '__main__':
    main()
