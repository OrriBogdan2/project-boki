"""Side-by-side viewer: python3 gview.py OUT.jpg id1 id2 ...
Each id is a job id (all runs _1.._4 found in git, one row per id) or a full stem (id_N).
Optional --w=480 sets the cell width. Labels: id on the left, run number on each cell."""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from bload import load, stems
from PIL import Image, ImageDraw

args = [a for a in sys.argv[1:] if not a.startswith('--')]
W = int(next((a.split('=')[1] for a in sys.argv if a.startswith('--w=')), 480))
out, ids = args[0], args[1:]
have = set(stems())
rows = []
for i in ids:
    runs = [i] if i in have else [f'{i}_{n}' for n in range(1, 7) if f'{i}_{n}' in have]
    rows.append((i, runs))
cols = max((len(r) for _, r in rows), default=1)
LBL = 22
H = W
sheet = Image.new('RGB', (cols * W, len(rows) * (H + LBL)), 'white')
d = ImageDraw.Draw(sheet)
for y, (i, runs) in enumerate(rows):
    top = y * (H + LBL)
    d.text((4, top + 4), i if runs else f'{i}  (no output yet)', fill='black')
    for x, s in enumerate(runs):
        im = load(s)
        im.thumbnail((W, H))
        sheet.paste(im, (x * W + (W - im.width) // 2, top + LBL + (H - im.height) // 2))
        d.text((x * W + 6, top + LBL + 4), s.rsplit('_', 1)[1], fill='red')
sheet.save(out, quality=88)
print(out, sheet.size)
