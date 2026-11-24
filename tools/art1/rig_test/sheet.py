import sys
from PIL import Image, ImageDraw, ImageFont

# sheet.py out.png cell clip_frame views(csv) variantdir:label ...   (labels grey/green/red border)
out, cell, cf, views = sys.argv[1:5]
cell = int(cell)
views = views.split(",")
vs = [x.split(":") for x in sys.argv[5:]]
font = ImageFont.load_default(size=max(14, cell // 22)) if hasattr(ImageFont, "load_default") else None
W = Image.new("RGB", (len(views) * cell + 100, len(vs) * cell), (30, 30, 30))
d = ImageDraw.Draw(W)
for i, (dr, lab, col) in enumerate(vs):
    for j, v in enumerate(views):
        im = Image.open(f"{dr}/{cf}_{v}.png").convert("RGB").resize((cell, cell))
        W.paste(im, (100 + j * cell, i * cell))
    d.rectangle([0, i * cell, 99, (i + 1) * cell - 1], outline=col, width=6)
    d.text((8, i * cell + 8), lab, fill=(255, 255, 255), font=font)
W.save(out)
