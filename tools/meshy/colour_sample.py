"""Colours of an image's regions, for the fit's ramps and for checking a look change (Blender's Python: numpy):
  python3 -I tools/meshy/colour_sample.py IMG name:x0,y0,x1,y1[:filter] [...]
  python3 -I tools/meshy/colour_sample.py --compare A.png B.png x0,y0,x1,y1     (skin-like pixels picked in A)
filter: green, skin, brass, grey, dark (or none). Prints the region's hue/sat/value range and its p5..p95 colours by
luminance (a ramp, dark to light)."""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import numpy as np  # noqa: E402
import imgio  # noqa: E402


def hsv(rgb):
    mx = rgb.max(-1)
    mn = rgb.min(-1)
    d = np.maximum(mx - mn, 1e-6)
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    h = np.where(mx == r, ((g - b) / d) % 6, np.where(mx == g, (b - r) / d + 2, (r - g) / d + 4)) / 6
    return h, np.where(mx > 0, (mx - mn) / np.maximum(mx, 1e-6), 0), mx


FILTERS = {
    "green": lambda h, s, v: (h > 0.2) & (h < 0.5) & (s > 0.3),
    "skin": lambda h, s, v: ((h > 0.85) | (h < 0.12)) & (s > 0.03) & (s < 0.5) & (v > 0.45),
    "brass": lambda h, s, v: (h > 0.04) & (h < 0.18) & (s > 0.3),
    "grey": lambda h, s, v: (s < 0.2) & (v > 0.2) & (v < 0.8),
    "dark": lambda h, s, v: v < 0.35,
}


def hexc(c):
    return "#%02x%02x%02x" % tuple((np.clip(c, 0, 1) * 255).astype(int))


def region(im, name, box, flt):
    x0, y0, x1, y1 = box
    reg = im[y0:y1, x0:x1].reshape(-1, 3)
    h, s, v = hsv(reg)
    sel = FILTERS[flt](h, s, v) if flt in FILTERS else np.ones(len(reg), bool)
    r = reg[sel]
    if len(r) == 0:
        print("%-14s none" % name)
        return
    lum = r @ np.array([0.3, 0.59, 0.11])
    cols = []
    for q in (5, 25, 50, 75, 95):
        t = np.percentile(lum, q)
        near = r[np.abs(lum - t) < 0.02]
        cols.append(hexc(near.mean(0) if len(near) else r[np.argmin(np.abs(lum - t))]))
    hh, ss, vv = h[sel], s[sel], v[sel]
    print("%-14s n=%6d hue %.2f-%.2f sat %.2f-%.2f val %.2f-%.2f | ramp %s" % (
        name, len(r), np.percentile(hh, 5), np.percentile(hh, 95), np.percentile(ss, 5), np.percentile(ss, 95),
        np.percentile(vv, 5), np.percentile(vv, 95), " ".join(cols)))


def compare(a_path, b_path, box):
    x0, y0, x1, y1 = box
    a, b = imgio.load(a_path)[y0:y1, x0:x1], imgio.load(b_path)[y0:y1, x0:x1]
    h, s, v = hsv(a)
    skin = (a[..., 0] >= a[..., 1]) & (s > 0.05) & (s < 0.4) & (v > 0.5)
    for lab, im in (("A", a), ("B", b)):
        c = np.median(im[skin], axis=0)
        print("%s n=%5d skin median %s  r-b %+.3f g-b %+.3f" % (lab, int(skin.sum()), hexc(c), c[0] - c[2], c[1] - c[2]))


def main(a):
    if a[0] == "--compare":
        return compare(a[1], a[2], [int(x) for x in a[3].split(",")])
    im = imgio.load(a[0])
    for spec in a[1:]:
        parts = spec.split(":")
        region(im, parts[0], [int(x) for x in parts[1].split(",")], parts[2] if len(parts) > 2 else "")


main(sys.argv[1:])
