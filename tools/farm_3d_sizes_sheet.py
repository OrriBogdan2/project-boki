#!/usr/bin/env python3
"""Size sheet from --farm-3d-sizes output: python3 -I tools/farm_3d_sizes_sheet.py <shots dir> <out.png>
The dir holds 1_farm_cam.png, 2_eye_row.png, 3_mid.png and heights.json. Plain labels, heights burned in."""
import json
import sys
from PIL import Image, ImageDraw, ImageFont

src, out = sys.argv[1], sys.argv[2]
hs = json.load(open(src + "/heights.json"))
F = "/usr/share/fonts/truetype/dejavu/DejaVuSans%s.ttf"
big, mid, small = (ImageFont.truetype(F % "-Bold", s) for s in (34, 26, 22))
reg = ImageFont.truetype(F % "", 22)

W, H = 1280, 720
shots = [("1  Farm camera, close third person (Albert from behind, the others ahead)", "1_farm_cam.png"),
         ("2  Eye level, 3/4, all 5 hunters + 4 Boki in one row (Albert nearest)", "2_eye_row.png"),
         ("3  Mid distance, hunters back row, Boki in front", "3_mid.png")]
sheet = Image.new("RGB", (W * 2, H * 2 + 120), (24, 24, 28))
d = ImageDraw.Draw(sheet)
d.text((20, 16), "Farm 3D sizes, redo: 5 hunters + 4 Boki, idle poses, 1920x1080 stills shown at 2/3 size", font=big, fill="white")
for i, (label, f) in enumerate(shots):
    im = Image.open(f"{src}/{f}").convert("RGB").resize((W, H), Image.LANCZOS)
    x, y = (i % 2) * W, 120 + (i // 2) * H
    sheet.paste(im, (x, y))
    d.rectangle((x, y, x + W, y + 40), fill=(0, 0, 0))
    d.text((x + 12, y + 6), label, font=small, fill="white")

# heights panel (4th cell)
x0, y0 = W, 120 + H
d.rectangle((x0, y0, x0 + W, y0 + H), fill=(16, 16, 20))
sc, ms = hs["farm_scale"], hs["match_scale"]
y = y0 + 12
d.text((x0 + 20, y), f"Height in metres as drawn. Farm scale {sc:.2f} (the farm ignores match_hunter_scale).", font=mid, fill="white")
y += 36
d.text((x0 + 20, y), f"A match draws hunters x{ms:.3f} (1.12 x 1.10, PR #985 merged in locally).", font=small, fill="white")
y += 40
cols = [20, 250, 440, 640, 860]
for c, t in zip(cols, ["", "body top", "with extras", "match: body", "match: with"]):
    d.text((x0 + c + (0 if c == 20 else 0), y), t, font=small, fill=(200, 200, 200))
y += 32
for name, r in hs["hunters"].items():
    row = [name, r["body"], r["full"], r["match_body"], r["match_full"]]
    for c, v in zip(cols, row):
        d.text((x0 + c, y), v if isinstance(v, str) else f"{v:.2f} m", font=mid, fill="white")
    y += 34
y += 10
d.text((x0 + 20, y), "Boki (farm size)", font=small, fill=(200, 200, 200))
d.text((x0 + 250, y), "body top", font=small, fill=(200, 200, 200))
d.text((x0 + 440, y), "with ears/tufts", font=small, fill=(200, 200, 200))
y += 32
for name, r in hs["boki"].items():
    d.text((x0 + 20, y), name, font=mid, fill="white")
    d.text((x0 + 250, y), f"{r['body']:.2f} m", font=mid, fill="white")
    d.text((x0 + 440, y), f"{r['full']:.2f} m", font=mid, fill="white")
    y += 34
y += 8
alb, spk = hs["hunters"]["Albert"]["body"], hs["hunters"]["Sparkle"]["body"]
notes = [
    "body top = skinned body mesh, no sail, props or pet; hair baked into it stays in.",
    "with extras = adds separate hair, ears, tufts (not weapon, sail, pet).",
]
if alb < spk:
    notes.append(f"SIZE-DATA BUG (not fixed here): Albert {alb:.2f} m is shorter than Sparkle {spk:.2f} m.")
notes.append("Crofthorn (the orange cow) shading is out of scope: crofthorn-toon-redo is running.")
for n in notes:
    d.text((x0 + 20, y), n, font=reg, fill=(255, 120, 120) if n.startswith("SIZE") else (200, 200, 200))
    y += 28
sheet.save(out)
print("wrote", out, sheet.size)
