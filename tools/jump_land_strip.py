#!/usr/bin/env python3
"""Strips of the plain jump at the match camera from --jump-land-shots frames (tools/jump_land_shots.gd):
one row per Hunter, the frame before the press, take-off +1/+2/+4 frames, the apex, mid-fall, the frame before
touchdown, touchdown and +2/+4/+6/+9/+12/+15 frames (30 fps), cropped round the Hunter and scaled up.

    python3 tools/jump_land_strip.py <shots-dir> <out.jpg> [--variant run|still] [--label text]
"""
import argparse, json, os, sys
from PIL import Image, ImageDraw

KEYS = [("run", "t", -1), ("off", "t", 1), ("off", "t", 2), ("off", "t", 4), ("apex", "a", 0), ("fall", "a", 5),
        ("pre", "l", -1), ("land", "l", 0), ("", "l", 2), ("", "l", 4), ("", "l", 6), ("", "l", 9), ("", "l", 12),
        ("", "l", 15)]
ORDER = ["gunslinger", "bulwark", "mage", "juggernaut", "archer", "rimewright", "dredge", "tender", "ashwick",
         "dolm", "ostra", "thief"]
CROP_W, CROP_UP, CROP_DOWN, SCALE = 110, 150, 60, 1     # px round the Hunter's feet in a 720 px frame


def cell(frame_dir, i, size):
    im = Image.open(os.path.join(frame_dir, "f%03d.png" % i)).convert("RGB")
    w, h = im.size
    k = w / 720.0
    cx, feet = w // 2, int(h * 0.61)
    box = (int(cx - CROP_W * k), int(feet - CROP_UP * k), int(cx + CROP_W * k), int(feet + CROP_DOWN * k))
    return im.crop(box).resize(size, Image.LANCZOS)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("shots"); ap.add_argument("out")
    ap.add_argument("--variant", default="run"); ap.add_argument("--label", default="")
    a = ap.parse_args()
    cw, ch = CROP_W * 2 * SCALE, (CROP_UP + CROP_DOWN) * SCALE
    ids = [i for i in ORDER if os.path.isdir(os.path.join(a.shots, i, a.variant))]
    if not ids:
        sys.exit("no frames under %s" % a.shots)
    pad, head = 56, 22
    sheet = Image.new("RGB", (pad + cw * len(KEYS), head + ch * len(ids)), (24, 24, 28))
    d = ImageDraw.Draw(sheet)
    d.text((4, 4), "%s jump at the match camera (%s): %s" % (a.variant, a.label, ", ".join(ids)), fill=(230, 230, 230))
    for r, hid in enumerate(ids):
        fd = os.path.join(a.shots, hid, a.variant)
        key = json.load(open(os.path.join(fd, "key.json")))
        base = {"t": key["takeoff"], "a": key["apex"], "l": key["land"]}
        y = head + r * ch
        d.text((4, y + 4), hid[:9], fill=(230, 230, 230))
        for c, (name, k, off) in enumerate(KEYS):
            i = base[k] + off
            if not os.path.exists(os.path.join(fd, "f%03d.png" % i)):
                continue
            x = pad + c * cw
            sheet.paste(cell(fd, i, (cw, ch)), (x, y))
            tag = name if name else ""
            d.text((x + 3, y + ch - 14), "%s%+d" % (tag or {"t": "off", "a": "apex", "l": "land"}[k], off)
                   if off else (name or k), fill=(255, 240, 160))
    sheet.save(a.out, quality=78)
    print("wrote", a.out, sheet.size)


if __name__ == "__main__":
    main()
