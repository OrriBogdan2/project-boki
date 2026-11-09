#!/usr/bin/env python3
"""Before/after strips of each Hunter's ground dash from two --dash-shots folders (dash_frames.gd, a GPU run):
   python3 tools/dash_travel_strip.py <before_dir> <after_dir> <out_dir>
Per Hunter one JPG: the top row the first folder's frames, the bottom row the second's, N frames from the press at
the shots' own cadence (SHOT_EVERY drawn frames each), the time under each. docs/art/anim_audit/DASH_TRAVEL.md."""
import os
import re
import sys

from PIL import Image, ImageDraw

FRAMES = 9          # tiles per row
TILE_W = 300        # px, the shot scaled to this width
SHOT_DT = 4 / 60.0  # s between saved shots (SHOT_EVERY at 60 fps)


def shots(folder):
    """{arch: [(frame, path)]} of each Hunter's first use, in frame order."""
    out = {}
    for name in sorted(os.listdir(folder)):
        m = re.match(r"(\w+)_(\d+)_(\d+)\.png$", name)
        if m and m.group(2) == "0":
            out.setdefault(m.group(1), []).append((int(m.group(3)), os.path.join(folder, name)))
    return out


def row(paths):
    tiles = []
    for frame, path in paths[:FRAMES]:
        img = Image.open(path).convert("RGB")
        w, h = img.size
        crop = img.crop((w // 4, h // 6, w * 3 // 4, h * 5 // 6))     # the Hunter sits mid-screen
        crop = crop.resize((TILE_W, int(crop.height * TILE_W / crop.width)))
        draw = ImageDraw.Draw(crop)
        draw.text((6, 4), "%.2f s" % (frame / 60.0), fill=(255, 255, 255))
        tiles.append(crop)
    if not tiles:
        return None
    sheet = Image.new("RGB", (TILE_W * len(tiles), tiles[0].height), (20, 20, 20))
    for i, t in enumerate(tiles):
        sheet.paste(t, (i * TILE_W, 0))
    return sheet


def main(before, after, out):
    os.makedirs(out, exist_ok=True)
    a, b = shots(before), shots(after)
    for arch in sorted(set(a) | set(b)):
        rows = [r for r in (row(a.get(arch, [])), row(b.get(arch, []))) if r is not None]
        sheet = Image.new("RGB", (max(r.width for r in rows), sum(r.height for r in rows) + 4 * (len(rows) - 1)), (0, 0, 0))
        y = 0
        for r in rows:
            sheet.paste(r, (0, y))
            y += r.height + 4
        sheet.save(os.path.join(out, "dash_travel_%s.jpg" % arch), quality=82)
        print(arch, sheet.size)


if __name__ == "__main__":
    main(*sys.argv[1:4])
