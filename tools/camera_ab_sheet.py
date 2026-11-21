#!/usr/bin/env python3
"""Side-by-side sheets for docs/CAMERA_AB.md: python3 tools/camera_ab_sheet.py <shots-dir> <out-dir>
Reads <hero>_<moment>_<style>.png from `godot -- --camera-ab-shots` and writes <out-dir>/<hero>.jpg: one row per
moment, the Supervive camera (flag off) on the left, source_scale (flag on) on the right."""
import sys
from pathlib import Path
from PIL import Image, ImageDraw

HEROES = {"archer": "Lace", "juggernaut": "Kael", "gunslinger": "Vex", "bulwark": "Albert"}
MOMENTS = [("fight", "open ground fight"), ("glide", "ledge drop, gliding"), ("squads", "3 squads at range")]
STYLES = [("supervive", "flag off: Supervive"), ("source_scale", "flag on: source_scale")]
TILE = (960, 540)    # px of each shot on the sheet
LABEL_H = 28         # px of the caption strip over each shot


def sheet(shots: Path, hero: str, name: str) -> Image.Image:
    out = Image.new("RGB", (TILE[0] * 2, (TILE[1] + LABEL_H) * len(MOMENTS)), "black")
    draw = ImageDraw.Draw(out)
    for r, (moment, mlabel) in enumerate(MOMENTS):
        for c, (style, slabel) in enumerate(STYLES):
            x, y = c * TILE[0], r * (TILE[1] + LABEL_H)
            draw.text((x + 8, y + 8), "%s, %s, %s" % (name, mlabel, slabel), fill="white")
            img = Image.open(shots / ("%s_%s_%s.png" % (hero, moment, style))).convert("RGB")
            out.paste(img.resize(TILE, Image.LANCZOS), (x, y + LABEL_H))
    return out


if __name__ == "__main__":
    src, dst = Path(sys.argv[1]), Path(sys.argv[2])
    dst.mkdir(parents=True, exist_ok=True)
    for hero, name in HEROES.items():
        sheet(src, hero, name).save(dst / ("%s.jpg" % name.lower()), quality=85)
