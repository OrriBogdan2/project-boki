"""sheet20.py OUT.jpg BORDER_A suffix crop(x0,y0,x1,y1) cell L_DIR A_DIR [B_DIR BORDER_B]: rows per frame: L (grey) over A (and B); columns = clips."""
import sys, os
from PIL import Image, ImageDraw
OUT, BA, suf, crop, cell = sys.argv[1], sys.argv[2], sys.argv[3], [float(v) for v in sys.argv[4].split(',')], int(sys.argv[5])
TG = os.environ.get('TAGS', 'L,A').split(','); srcs = [(TG[0], sys.argv[6], 'grey'), (TG[1], sys.argv[7], BA)] + ([('B', sys.argv[8], sys.argv[9])] if len(sys.argv) > 9 else [])
col = {'green': (40, 200, 60), 'red': (220, 30, 30), 'grey': (140, 140, 140)}
clips = ['idle', 'run', 'dash', 'jump', 'attack', 'hit']
rows = [(f, s) for f in range(3) for s in srcs]
S = Image.new('RGB', (len(clips) * (cell + 12), len(rows) * (cell + 12)), 'white')
for ri, (f, (tag, d, bc)) in enumerate(rows):
    for ci, c in enumerate(clips):
        p = os.path.join(d, f'{c}_{f}{suf}.jpg'); im = Image.open(p).convert('RGB') if os.path.exists(p) else Image.new('RGB', (cell, cell))
        w, h = im.size; im = im.crop((int(crop[0] * w), int(crop[1] * h), int(crop[2] * w), int(crop[3] * h))).resize((cell, cell))
        b = Image.new('RGB', (cell + 12, cell + 12), col[bc]); b.paste(im, (6, 6)); dr = ImageDraw.Draw(b)
        t = f'{tag} {c} f{f}'; dr.rectangle((6, 6, 14 + len(t) * 6, 20), fill='black'); dr.text((10, 8), t, fill='white')
        S.paste(b, (ci * (cell + 12), ri * (cell + 12)))
S.save(OUT, quality=88); print(OUT, S.size)
