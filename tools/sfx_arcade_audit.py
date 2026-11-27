"""Flags the sounds that read arcade: python3 tools/sfx_arcade_audit.py [out.tsv].

Per base sound (its takes folded together) it measures, with the numbers of tools/sfx_stats.py:
  bright   share of energy above 4 kHz over 35%, or centroid over 3.2 kHz (thin, over-bright highs)
  bleep    over 65% of the energy sits within 8% of one frequency above 400 Hz (a pure tone: synth bleep, chiptune coin)
  rising   a short sound (under 0.7 s) whose centroid climbs more than 40% from its first third to its last
           (a pitched-up sweep)
  dry      under 4% of the energy after the first 120 ms (no tail, no room)
  one-take only one file (the same sample on every repeat; Sfx only varies its pitch)
Prints the flag counts per group and writes every sound to the TSV.
"""
import collections, glob, os, re, sys
import numpy as np
from sfx_stats import load

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "audio")


def flags(x, sr):
    spec = np.abs(np.fft.rfft(x * np.hanning(len(x)))) ** 2
    f = np.fft.rfftfreq(len(x), 1.0 / sr)
    tot = spec.sum() or 1.0
    cent = float((spec * f).sum() / tot)
    out = []
    if spec[f > 4000].sum() / tot > 0.35 or cent > 3200:
        out.append("bright")
    fp = f[int(np.argmax(spec))]
    if fp > 400 and spec[(f > 0.92 * fp) & (f < 1.08 * fp)].sum() / tot > 0.65 and len(x) / sr < 1.5:
        out.append("bleep")
    third = len(x) // 3
    if len(x) / sr < 0.7 and third > 256:
        c = [float((np.abs(np.fft.rfft(x[a:a + third])) ** 2 * np.fft.rfftfreq(third, 1 / sr)).sum()
                   / max(np.sum(np.abs(np.fft.rfft(x[a:a + third])) ** 2), 1e-12)) for a in (0, 2 * third)]
        if c[1] > 1.4 * c[0] and c[0] > 0:
            out.append("rising")
    e = x * x
    if e.sum() > 0 and e[int(0.12 * sr):].sum() / e.sum() < 0.04:
        out.append("dry")
    return out, cent


def main():
    groups = collections.defaultdict(list)
    for p in sorted(glob.glob(os.path.join(ROOT, "*.wav"))):
        groups[re.sub(r"(_hold)?(_\d+)?$", "", os.path.basename(p)[:-4])].append(p)
    rows = []
    for base, paths in groups.items():
        x, sr = load(paths[0])
        if len(x) < 512:
            continue
        fl, cent = flags(x, sr)
        if len(paths) == 1:
            fl.append("one-take")
        rows.append((base, len(paths), round(len(x) / sr, 2), round(cent), ",".join(fl)))
    cnt = collections.Counter(t for r in rows for t in r[4].split(",") if t)
    print(len(rows), "sounds;", dict(cnt))
    if len(sys.argv) > 1:
        with open(sys.argv[1], "w") as fh:
            fh.write("sound\ttakes\tdur_s\tcentroid_hz\tflags\n")
            fh.writelines("\t".join(map(str, r)) + "\n" for r in rows)


if __name__ == "__main__":
    main()
