"""refsheet37.py OUT green|red REF LIVE NEW : one row, reference (no border, tag R1) | live (grey, L1) | new (green/red, A1),
512 px panels, no verdict words. Each arg may be PATH or PATH@x0,y0,x1,y1 (crop box in source pixels)."""
import sys
from PIL import Image, ImageDraw, ImageFont

out, col = sys.argv[1:3]; srcs = sys.argv[3:6]
C = {'green': (40, 190, 50), 'red': (210, 40, 40)}[col]
T, B = 512, 8; cw = T + 2 * B
try: FONT = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf', 30)
except OSError: FONT = ImageFont.load_default()
S = Image.new('RGB', (3 * cw, cw), (24, 24, 28))
for i, (s, c, tag) in enumerate(zip(srcs, [None, (128, 128, 128), C], ['R1', 'L1', 'A1'])):
    p, _, box = s.partition('@'); im = Image.open(p).convert('RGB')
    if box: im = im.crop(tuple(int(v) for v in box.split(',')))
    k = T / max(im.size); im = im.resize((int(im.width * k), int(im.height * k)), Image.LANCZOS)
    t = Image.new('RGB', (cw, cw), c or (24, 24, 28)); t.paste(Image.new('RGB', (T, T), (24, 24, 28)), (B, B))
    t.paste(im, (B + (T - im.width) // 2, B + (T - im.height) // 2))
    d = ImageDraw.Draw(t); w = d.textlength(tag, font=FONT)
    d.rectangle([B + 6, B + 6, B + 18 + w, B + 46], fill=(0, 0, 0)); d.text((B + 12, B + 9), tag, fill=(255, 255, 255), font=FONT)
    S.paste(t, (i * cw, 0))
S.save(out, quality=90); print(out, S.size)
