"""Synthesizes the Hunter Wisp's hum into audio/wisp_hum.wav: the quiet low drone a downed Hunter's
Wisp gives off (docs/decisions/0019-downed-wisp.md), and audio/wisp_hum_end.wav, its fall-away when the
Wisp is revived or bled out: the same drone sinking an octave and fading over 0.9 s. A seamless two-second loop: every partial is a
whole number of cycles long and there are no fades, so Sfx.loop_hold can run it round for as long as
the Hunter is down. Standard library only (no numpy), so any worker can rerun it.

    python3 tools/gen_wisp_sfx.py      (then: godot --headless --import)
"""
import math
import os
import wave

SR = 22050
OUT = os.path.join(os.path.dirname(__file__), '..', 'audio')
LOOP_S = 2.0
# (hz, gain): D2 and its first partials. One partial sits half a hertz off so the drone breathes once
# per loop instead of standing dead still. Every frequency is a multiple of 0.5 Hz: whole cycles in 2 s.
PARTIALS = ((73.5, 1.0), (74.0, 0.55), (110.0, 0.4), (147.0, 0.3), (220.5, 0.1))
RMS_DB = -20.0      # the palette's loudness, under the music (gen_sfx.py)


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


if __name__ == '__main__':
    main()
