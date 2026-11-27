#!/usr/bin/env python3
"""Size sheet from --farm-3d-sizes output: python3 -I tools/farm_3d_sizes_sheet.py <shots dir> <out.png>
The dir holds 1_farm_cam.png, 2_eye_row.png, 3_mid.png (+ their .json name spots) and heights.json.
Plain player names burned onto the stills, measured heights in a table; a green row edge = within 3% of the reference."""
import json
import sys

from PIL import Image, ImageDraw, ImageFont

src, out = sys.argv[1], sys.argv[2]
hs = json.load(open(src + "/heights.json"))
F = "/usr/share/fonts/truetype/dejavu/DejaVuSans%s.ttf"
big, mid, small, tag = (ImageFont.truetype(F % "-Bold", s) for s in (34, 26, 22, 24))
# Reference body height (m, weapons off): our crown at match_k 1 x the archetype's body.match_k, from the size-parity
# sheet (gens/size-parity-1127 hsize.log + match_k.json).
REF = {"Albert": 2.093, "Kael": 2.002, "Sparkle": 2.144, "Meeko": 1.759, "Cinder": 1.168}
# Crown in a match at the same sizes (tools/hunter_size_sheet.gd, idle averaged, the final match_k).
MATCH = {"Albert": 2.096, "Kael": 2.002, "Sparkle": 2.145, "Meeko": 1.759, "Cinder": 1.168}
TOL = 0.03
GREEN, GREY, RED = (40, 170, 70), (150, 150, 150), (210, 50, 50)
BOKI_CM = {"Vespyx": "cindle", "Mycroll": "burrlet", "Prismander": "puddlet", "Crofthorn": "heatherhorn"}

W, H = 1280, 720
shots = [("1  Farm camera, close third person", "1_farm_cam"), ("2  Eye level, one row", "2_eye_row"),
         ("3  Mid distance", "3_mid")]
sheet = Image.new("RGB", (W * 2, H * 2 + 90), (24, 24, 28))
d = ImageDraw.Draw(sheet)
d.text((20, 20), "Farm, hunters and Boki at their sizes (idle, real GPU, 1920x1080 stills at 2/3)", font=big, fill="white")
for i, (label, f) in enumerate(shots):
    im = Image.open(f"{src}/{f}.png").convert("RGB")
    sc = W / im.width
    im = im.resize((W, H), Image.LANCZOS)
    x, y = (i % 2) * W, 90 + (i // 2) * H
    tile = ImageDraw.Draw(im)
    placed = []  # label boxes so far: a label that would touch one drops a row lower
    for who, (px, py) in sorted(json.load(open(f"{src}/{f}.json")).items(), key=lambda kv: kv[1][0]):
        px, py = px * sc, py * sc
        w = tile.textlength(who, font=tag)
        lvl = 0
        while True:
            ty = py + 6 + lvl * 34
            box = (px - w / 2 - 6, ty, px + w / 2 + 6, ty + 32)
            if not any(box[0] < o[2] + 4 and o[0] < box[2] + 4 and box[1] < o[3] + 2 and o[1] < box[3] + 2
                       for o in placed):
                break
            lvl += 1
        placed.append(box)
        tile.line((px, py, px, ty), fill="white", width=2)
        tile.rectangle((px - w / 2 - 6, ty, px + w / 2 + 6, ty + 32), fill=(0, 0, 0))
        tile.text((px - w / 2, ty + 2), who, font=tag, fill="white")
    sheet.paste(im, (x, y))
    d.rectangle((x, y, x + W, y + 40), fill=(0, 0, 0))
    d.text((x + 12, y + 6), label, font=small, fill="white")

x0, y0 = W, 90 + H
d.rectangle((x0, y0, x0 + W, y0 + H), fill=(16, 16, 20))
y = y0 + 14
cols = [24, 250, 470, 700, 960]
for c, t in zip(cols, ["Hunter", "reference", "match idle", "farm pose", "with weapon"]):
    d.text((x0 + c, y), t, font=small, fill=(200, 200, 200))
y += 38
for name, r in hs["hunters"].items():
    ref, got = REF[name], MATCH[name]
    gap = got / ref - 1
    col = GREEN if abs(gap) <= TOL else RED
    d.rectangle((x0 + 10, y - 2, x0 + 16, y + 30), fill=col)
    for c, v in zip(cols, [name, f"{ref:.2f} m", f"{got:.2f} m", f"{r['body']:.2f} m", f"{r['full']:.2f} m"]):
        d.text((x0 + c, y), v, font=mid, fill="white")
    y += 40
y += 22
for c, t in zip(cols, ["Boki", "", "drawn", "with ears", ""]):
    d.text((x0 + c, y), t, font=small, fill=(200, 200, 200))
y += 38
for who, sp in BOKI_CM.items():
    r = hs["boki"][sp]
    d.text((x0 + cols[0], y), who, font=mid, fill="white")
    d.text((x0 + cols[2], y), f"{r['body']:.2f} m", font=mid, fill="white")
    d.text((x0 + cols[3], y), f"{r['full']:.2f} m", font=mid, fill="white")
    y += 40
y += 18
for n in ["Heights are the top of the skull over the feet; hair, ears and weapon left out. With weapon: tallest point.",
          "reference = reference body height, weapons off. match idle = the same sizes in a match (green edge: within 3%).",
          "farm pose = measured on these stills: the farm's idle stands straighter than a match's idle clip."]:
    d.text((x0 + 24, y), n, font=ImageFont.truetype(F % "", 20), fill=(200, 200, 200))
    y += 28
sheet.save(out)
print("wrote", out, sheet.size)
