#!/usr/bin/env python3
"""Lays out --wallpose-check --shots-dir frames: one sheet per Hero, a row pair per case (clips alone above, with the
plant and push below), frames left to right from the press or hit. Usage: wall_pose_sheet.py <shots dir> <out dir>."""
import glob
import os
import sys

from PIL import Image, ImageDraw

CELL = 180          # px: a frame in the sheet
LABEL = 120         # px: the row label's width


def main() -> None:
    src, out = sys.argv[1], sys.argv[2]
    os.makedirs(out, exist_ok=True)
    rows: dict = {}
    for f in sorted(glob.glob(os.path.join(src, "*.png"))):
        hero, kind, side, frame = os.path.basename(f)[:-4].split("_")
        rows.setdefault(hero, {}).setdefault((kind, side), []).append((int(frame), f))
    for hero, cases in rows.items():
        order = [(k, s) for k in ("kick", "push", "bounce") for s in ("off", "on") if (k, s) in cases]
        cols = max(len(v) for v in cases.values())
        sheet = Image.new("RGB", (LABEL + cols * CELL, len(order) * CELL), "black")
        draw = ImageDraw.Draw(sheet)
        for r, key in enumerate(order):
            draw.text((6, r * CELL + 6), "%s\n%s" % (key[0], "clips" if key[1] == "off" else "plant"), fill="white")
            for c, (frame, f) in enumerate(sorted(cases[key])):
                img = Image.open(f).convert("RGB").resize((CELL, CELL))
                sheet.paste(img, (LABEL + c * CELL, r * CELL))
                draw.text((LABEL + c * CELL + 4, r * CELL + 4), "f%d" % frame, fill="yellow")
        sheet.save(os.path.join(out, "wall_pose_%s.jpg" % hero), quality=85)


if __name__ == "__main__":
    main()
