"""grid.py OUT.jpg rows=dir:letter:colour,... cols=run_0,run_1,... view=''|eye|knee [w=300]: one row per variant, one column per clip frame. Border colour only."""

import sys
from PIL import Image, ImageDraw, ImageFont

out = sys.argv[1]
kw = dict(a.split("=", 1) for a in sys.argv[2:])
rows = [r.split(":") for r in kw["rows"].split(",")]
cols = kw["cols"].split(",")
view = kw.get("view", "")
COL = {"grey": (150, 150, 150), "green": (40, 200, 70), "red": (220, 50, 50)}
T = int(kw.get("w", 300))
B = 6
sfx = ("_" + view) if view else ""
ims = [[Image.open("%s/%s%s.jpg" % (d, c, sfx)).convert("RGB") for c in cols] for d, _, _ in rows]
w, h = ims[0][0].size
th = int(h * T / w)
S = Image.new("RGB", (len(cols) * (T + 2 * B) + 60, len(rows) * (th + 2 * B)), (30, 30, 30))
dr = ImageDraw.Draw(S)
ft = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 40)
for r, (d, L, c) in enumerate(rows):
    y = r * (th + 2 * B)
    dr.text((10, y + th // 2 - 20), L, fill=COL[c], font=ft)
    for i, im in enumerate(ims[r]):
        x = 60 + i * (T + 2 * B)
        dr.rectangle([x, y, x + T + 2 * B - 1, y + th + 2 * B - 1], fill=COL[c])
        S.paste(im.resize((T, th)), (x + B, y + B))
S.save(out, quality=88)
print(out, S.size)
