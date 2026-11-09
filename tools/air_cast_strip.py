#!/usr/bin/env python3
"""Before/after strips of a Hunter's air cast from --air-cast-shots frames (tools/air_cast_shots.gd): the row
above has the planted stance (the move's "air_legs" taken out), the row below the fall legs under the cast; the
frame before the press, the cast on the way up and over the apex, the frame before touchdown, the landing and
after it (30 fps), cropped round the Hunter.

    python3 tools/air_cast_strip.py <shots-dir> <out-dir>      (one <out-dir>/<id>.jpg per Hunter filmed)
"""
import json, os, sys
from PIL import Image, ImageDraw

KEYS = [("press", "p", -1), ("", "p", 2), ("", "p", 4), ("", "p", 7), ("", "p", 10), ("", "p", 14),
        ("pre", "l", -1), ("land", "l", 0), ("", "l", 3), ("", "l", 6), ("", "l", 10)]
CROP_W, CROP_TOP, CROP_BOTTOM = 150, 0.06, 0.9       # px half-width round the centre; top and bottom as frame parts


def cell(frame_dir, i, size):
    im = Image.open(os.path.join(frame_dir, "f%03d.png" % i)).convert("RGB")
    w, h = im.size
    k = w / 480.0
    box = (int(w / 2 - CROP_W * k), int(h * CROP_TOP), int(w / 2 + CROP_W * k), int(h * CROP_BOTTOM))
    return im.crop(box).resize(size, Image.LANCZOS)


def strip(hdir, out):
    cw, ch = CROP_W * 2, int(480 * (CROP_BOTTOM - CROP_TOP))
    pad, head = 52, 22
    sheet = Image.new("RGB", (pad + cw * len(KEYS), head + ch * 2), (24, 24, 28))
    d = ImageDraw.Draw(sheet)
    for r, variant in enumerate(["before", "after"]):
        fd = os.path.join(hdir, variant)
        key = json.load(open(os.path.join(fd, "key.json")))
        if r == 0:
            d.text((4, 4), "%s: %s pressed on the way up a standing jump (before: planted legs; after: fall legs)"
                   % (os.path.basename(hdir), key["move"]), fill=(230, 230, 230))
        base = {"p": key["press"], "l": key["land"]}
        y = head + r * ch
        d.text((4, y + 4), variant, fill=(230, 230, 230))
        for c, (name, k, off) in enumerate(KEYS):
            i = base[k] + off
            if not os.path.exists(os.path.join(fd, "f%03d.png" % i)):
                continue
            x = pad + c * cw
            sheet.paste(cell(fd, i, (cw, ch)), (x, y))
            tag = name or ("press" if k == "p" else "land")
            d.text((x + 3, y + ch - 14), "%s%+d" % (tag, off) if off else tag,
                   fill=(255, 160, 140) if i >= key["end"] else (255, 240, 160))
    sheet.save(out, quality=80)
    print("wrote", out, sheet.size)


def main():
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    shots, out = sys.argv[1], sys.argv[2]
    os.makedirs(out, exist_ok=True)
    for hid in sorted(os.listdir(shots)):
        if os.path.isfile(os.path.join(shots, hid, "after", "key.json")):
            strip(os.path.join(shots, hid), os.path.join(out, hid + ".jpg"))


if __name__ == "__main__":
    main()
