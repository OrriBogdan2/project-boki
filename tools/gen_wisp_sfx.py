"""Synthesizes the Hunter Wisp's hum into audio/wisp_hum.wav: the quiet low drone a downed Hunter's
Wisp gives off (docs/decisions/0019-downed-wisp.md). A seamless two-second loop: every partial is a
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


def main():
    n = int(SR * LOOP_S)
    x = [sum(g * math.sin(2 * math.pi * f * i / SR) for f, g in PARTIALS) for i in range(n)]
    rms = math.sqrt(sum(v * v for v in x) / n)
    k = 10 ** (RMS_DB / 20) / rms
    frames = b''.join(int(max(-0.95, min(0.95, v * k)) * 32767).to_bytes(2, 'little', signed=True) for v in x)
    with wave.open(os.path.join(OUT, 'wisp_hum.wav'), 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(frames)


if __name__ == '__main__':
    main()
