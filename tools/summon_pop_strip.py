#!/usr/bin/env python3
"""Joins --summon-pop-shots frames into one sheet: a row per type, a column per moment of the burst.

python3 tools/summon_pop_strip.py <shots-dir> <out.jpg>
"""

import json, os, sys
from PIL import Image, ImageDraw

d, out = sys.argv[1], sys.argv[2]
key = json.load(open(os.path.join(d, "key.json")))
types = key.get("order", list(key["types"]))
cols = len(key["us"])
first = Image.open(os.path.join(d, "%s_0.png" % types[0])).convert("RGB")
w, h = first.size
k = 0.5
cw, ch = int(w * k), int(h * k)
sheet = Image.new("RGB", (cols * cw, 24 + len(types) * ch), (24, 24, 28))
dr = ImageDraw.Draw(sheet)
for r, t in enumerate(types):
    info = key["types"][t]
    dr.text(
        (4, 6),
        "rows: "
        + ", ".join("%s (%s, type #%s)" % (x, key["types"][x]["species"], key["types"][x]["type_col"]) for x in types),
        fill=(230, 230, 230),
    )
    for c in range(cols):
        im = Image.open(os.path.join(d, "%s_%d.png" % (t, c))).convert("RGB").resize((cw, ch), Image.LANCZOS)
        sheet.paste(im, (c * cw, 24 + r * ch))
        dr.text((c * cw + 4, 24 + r * ch + 4), "u=%.2f" % key["us"][c], fill=(255, 255, 255))
sheet.save(out, quality=88)
print(out)
