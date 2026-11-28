#!/usr/bin/env python3
"""Lay out the PNGs --mob-turnaround-shots wrote as one sheet per mob (docs/art/mobs/TURNAROUND_SPEC.md order).

usage: mob_turnaround_sheet.py <shots dir> <out dir> [flags.tsv]
Row 1: front | 3/4 | side | back. Row 2: match camera next to a Hunter | wind-up | death.
flags.tsv: kind <TAB> tile <TAB> red|green (tile = front, three_q, side, back, match, windup, death, or whole);
a tile's border is its verdict as colour only: red = flagged, green = ok. No text on the sheet.
"""
import csv
import os
import sys
from PIL import Image, ImageDraw

TILES = [["front", "three_q", "side", "back"], ["match", "windup", "death"]]
S, PAD, B = 512, 14, 10
BG = (232, 232, 238)
COL = {"red": (214, 40, 40), "green": (40, 170, 70), "grey": (150, 150, 160)}


def sheet(src, kind, flags):
    w = PAD + 4 * (S + PAD)
    im = Image.new("RGB", (w, PAD + 2 * (S + PAD)), BG)
    d = ImageDraw.Draw(im)
    for r, row in enumerate(TILES):
        for c, name in enumerate(row):
            p = os.path.join(src, kind, name + ".png")
            x, y = PAD + c * (S + PAD), PAD + r * (S + PAD)
            if os.path.exists(p):
                im.paste(Image.open(p).convert("RGB").resize((S, S)), (x, y))
            v = flags.get((kind, name)) or flags.get((kind, "whole")) or "grey"
            d.rectangle([x - B // 2, y - B // 2, x + S + B // 2 - 1, y + S + B // 2 - 1], outline=COL[v], width=B)
    return im


def main():
    src, out = sys.argv[1], sys.argv[2]
    flags = {}
    if len(sys.argv) > 3:
        for row in csv.reader(open(sys.argv[3]), delimiter="\t"):
            if len(row) == 3 and not row[0].startswith("#"):
                flags[(row[0], row[1])] = row[2]
    os.makedirs(out, exist_ok=True)
    for kind in sorted(os.listdir(src)):
        if os.path.isdir(os.path.join(src, kind)):
            sheet(src, kind, flags).save(os.path.join(out, kind + "_turnaround.png"))
            print(kind)


if __name__ == "__main__":
    main()
