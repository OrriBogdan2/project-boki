"""Mend a sound whose tail stops short (docs/AUDIO.md, the mix pass; tools/loudness_report.py --tails finds them).

    python3 tools/sfx_tail.py audio/br_rumble.wav --extend 0.3 --fade 0.35
    python3 tools/sfx_tail.py audio/br_crack.wav --fade 0.1

--extend S  grows the sound by S seconds: its own last S seconds, mirrored (so the join has no step), run on past the end
--fade S    a raised-cosine fade to silence over the last S seconds (after any extension)
For sounds with no generator in tools/ (or none that runs here); a generated one should get the fade in its
generator instead. Standard library only; 16-bit PCM wav, any channel count. Rewrites the file in place, so run it
once per sound (it is not idempotent: every --extend grows the file again).
"""
import argparse, array, math, sys, wave


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('wav')
    ap.add_argument('--extend', type=float, default=0.0)
    ap.add_argument('--fade', type=float, default=0.0)
    a = ap.parse_args()
    with wave.open(a.wav) as w:
        p = w.getparams()
        raw = w.readframes(p.nframes)
    if p.sampwidth != 2:
        sys.exit('16-bit PCM only')
    ch = p.nchannels
    s = array.array('h', raw)
    if sys.byteorder == 'big':
        s.byteswap()
    frames = [list(s[i:i + ch]) for i in range(0, len(s), ch)]
    ext = min(int(a.extend * p.framerate), len(frames))
    if ext:
        frames += frames[-ext:][::-1]
    fade = min(int(a.fade * p.framerate), len(frames))
    for k in range(fade):
        g = 0.5 + 0.5 * math.cos(math.pi * (k + 1) / fade)
        f = frames[len(frames) - fade + k]
        for c in range(ch):
            f[c] = int(round(f[c] * g))
    out = array.array('h', [v for f in frames for v in f])
    if sys.byteorder == 'big':
        out.byteswap()
    with wave.open(a.wav, 'wb') as w:
        w.setparams(p)
        w.writeframes(out.tobytes())
    print('%s: %.2f s -> %.2f s' % (a.wav, p.nframes / p.framerate, len(frames) / p.framerate))


if __name__ == '__main__':
    main()
