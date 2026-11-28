"""sheet37.py OUT green|red LIVEDIR NEWDIR file... : owner sheet, LIVE row (grey border, tag L) over NEW row (green = better
than live / red = worse, tag A), 512 px panels, panel numbers burned in, no verdict words. Each column is cropped to the same
square box around the hunter in both renders (union of the two silhouettes vs the median background), so LIVE and NEW sit
at the same scale. REF=path[,path] adds a reference column on the right (no border colour, tag R)."""
import sys, os
import numpy as np
from PIL import Image, ImageDraw, ImageFont

out, col, ld, nd = sys.argv[1:5]; fs = sys.argv[5:]
C = {'green': (40, 190, 50), 'red': (210, 40, 40)}[col]; GREY = (128, 128, 128)
T, B = 512, 8; cw = T + 2 * B
try: FONT = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf', 30)
except OSError: FONT = ImageFont.load_default()


def bbox(im):
    a = np.asarray(im).astype(int); bg = np.median(a.reshape(-1, 3), 0); m = np.abs(a - bg).sum(2) > 60
    ys, xs = np.nonzero(m); return (xs.min(), ys.min(), xs.max(), ys.max()) if len(xs) else (0, 0, im.width - 1, im.height - 1)


def tile(im, c, tag, num):
    s = T / max(im.size); im = im.resize((max(1, int(im.width * s)), max(1, int(im.height * s))), Image.LANCZOS)
    t = Image.new('RGB', (cw, cw), c if c else (24, 24, 28)); t.paste(Image.new('RGB', (T, T), (24, 24, 28)), (B, B))
    t.paste(im, (B + (T - im.width) // 2, B + (T - im.height) // 2))
    d = ImageDraw.Draw(t); lab = '%s%d' % (tag, num); w = d.textlength(lab, font=FONT)
    d.rectangle([B + 6, B + 6, B + 18 + w, B + 46], fill=(0, 0, 0)); d.text((B + 12, B + 9), lab, fill=(255, 255, 255), font=FONT)
    return t


refs = [r for r in os.environ.get('REF', '').split(',') if r]
S = Image.new('RGB', ((len(fs) + len(refs)) * cw, 2 * cw), (24, 24, 28))
for i, f in enumerate(fs):
    ims = [Image.open(os.path.join(d, f)).convert('RGB') for d in (ld, nd)]
    bs = [bbox(im) for im in ims]
    x0, y0 = min(b[0] for b in bs), min(b[1] for b in bs); x1, y1 = max(b[2] for b in bs), max(b[3] for b in bs)
    cx, cy, h = (x0 + x1) / 2, (y0 + y1) / 2, max(x1 - x0, y1 - y0) * 0.56 + 6
    box = (int(cx - h), int(cy - h), int(cx + h), int(cy + h))
    S.paste(tile(ims[0].crop(box), GREY, 'L', i + 1), (i * cw, 0))
    S.paste(tile(ims[1].crop(box), C, 'A', i + 1), (i * cw, cw))
for k, r in enumerate(refs):
    im = Image.open(r).convert('RGB'); x = (len(fs) + k) * cw
    S.paste(tile(im, None, 'R', k + 1), (x, 0 if k == 0 else cw))
S.save(out, quality=90); print(out, S.size)
