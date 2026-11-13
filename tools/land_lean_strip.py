#!/usr/bin/env python3
"""Before/after strips from two --land-lean-shots runs (tools/land_lean_shots.gd): per Hunter or Boki, a row from
each run, the frames round the run start, the stop, the jump's (or leap's) landing and a glide's landing.

    python3 tools/land_lean_strip.py <before-dir> <after-dir> <out.jpg> [--ids a,b]
"""
import argparse, json, os, sys
from PIL import Image, ImageDraw

KEYS = [("start", 0), ("start", 2), ("start", 4), ("stop", 0), ("stop", 3), ("stop", 6), ("land", -1), ("land", 1),
        ("land", 3), ("land", 6), ("glide_land", -1), ("glide_land", 1), ("glide_land", 3), ("glide_land", 6)]
CROP = 0.62                  # share of the frame kept round its centre


def cell(path, size):
    im = Image.open(path).convert("RGB")
    w, h = im.size
    c = int(w * CROP / 2)
    return im.crop((w // 2 - c, h // 2 - c, w // 2 + c, h // 2 + c)).resize(size, Image.LANCZOS)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("before"); ap.add_argument("after"); ap.add_argument("out"); ap.add_argument("--ids", default="")
    a = ap.parse_args()
    ids = a.ids.split(",") if a.ids else sorted(d for d in os.listdir(a.after) if os.path.isdir(os.path.join(a.after, d)))
    if not ids:
        sys.exit("no frames under %s" % a.after)
    cw = 120
    pad, head = 90, 20
    sheet = Image.new("RGB", (pad + cw * len(KEYS), head + cw * 2 * len(ids)), (24, 24, 28))
    d = ImageDraw.Draw(sheet)
    for c, (k, off) in enumerate(KEYS):
        d.text((pad + c * cw + 3, 4), "%s%+d" % (k.replace("glide_land", "glide"), off), fill=(255, 240, 160))
    for r, hid in enumerate(ids):
        for j, (tag, root) in enumerate((("before", a.before), ("after", a.after))):
            fd = os.path.join(root, hid)
            y = head + (r * 2 + j) * cw
            d.text((4, y + 4), "%s\n%s" % (hid[:12], tag), fill=(230, 230, 230))
            if not os.path.exists(os.path.join(fd, "key.json")):
                continue
            key = json.load(open(os.path.join(fd, "key.json")))
            for c, (k, off) in enumerate(KEYS):
                p = os.path.join(fd, "f%03d.png" % (key.get(k, -999) + off))
                if os.path.exists(p):
                    sheet.paste(cell(p, (cw, cw)), (pad + c * cw, y))
    sheet.save(a.out, quality=80)
    print("wrote", a.out, sheet.size)


if __name__ == "__main__":
    main()
