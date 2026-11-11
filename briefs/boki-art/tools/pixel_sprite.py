"""Finish step for the px9 pixel sprites (run from the repo root, after `git fetch origin ext/agent-briefs`):
python3 briefs/boki-art/tools/pixel_sprite.py [Name[:stem[:holes]] ...]  (no names = every manifest Boki, stem px9_<name>_1;
                                               holes = also clear white gaps enclosed by the body, e.g. inside a coil)
python3 briefs/boki-art/tools/pixel_sprite.py --sheet [out.jpg]      (contact sheet of briefs/boki-art/pixel/*.png on grey)
For each Boki: flood-fill the white background from the image edges, crop to the creature, quantise to 14 colours,
resample to 80px on the long side taking the dominant colour per cell, save briefs/boki-art/pixel/<Name>.png with hard alpha."""
import sys, os, json, numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__))); import bload
A = 'briefs/boki-art/'; OUT = A + 'pixel/'; SIZE = 80; COLS = 14

def background(rgb, holes=False):
    """Near-white pixels connected to the image edge; with holes=True also large pure-white pockets enclosed by the body."""
    a = rgb.astype(np.int16); light = (a.min(2) > 222) & ((a.max(2) - a.min(2)) < 26)
    lab, n = ndimage.label(light)
    edge = np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]])); edge = edge[edge > 0]
    bg = np.isin(lab, edge)
    if holes and n:
        pure = ndimage.mean(a.min(2) > 242, lab, range(1, n + 1)); sz = ndimage.sum(light, lab, range(1, n + 1))
        bg |= np.isin(lab, np.where((pure > 0.85) & (sz > light.size * 0.002))[0] + 1)
    return bg

def finish(im, holes=False):
    rgb = np.asarray(im.convert('RGB'))
    fg = ~background(rgb, holes)
    fg = ndimage.binary_opening(fg, iterations=1)                  # JPEG specks on the edge
    lab, n = ndimage.label(fg)
    if n:
        sz = ndimage.sum(fg, lab, range(1, n + 1)); keep = np.where(sz >= max(60, sz.max() * 0.002))[0] + 1
        fg = np.isin(lab, keep)
    ys, xs = np.where(fg); y0, y1, x0, x1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
    rgb, fg = rgb[y0:y1, x0:x1], fg[y0:y1, x0:x1]
    h, w = fg.shape; s = SIZE / max(h, w); oh, ow = max(1, round(h * s)), max(1, round(w * s))
    # one palette from the creature's pixels only
    pal_im = Image.fromarray(rgb[fg].reshape(1, -1, 3)).quantize(COLS, method=Image.MEDIANCUT, dither=Image.NONE)
    pal = np.array(pal_im.getpalette()[:COLS * 3], np.uint8).reshape(-1, 3)
    idx = np.full((h, w), COLS, np.int32)                          # COLS = background
    idx[fg] = np.asarray(pal_im).reshape(-1)
    cy = np.minimum((np.arange(h) * oh) // h, oh - 1); cx = np.minimum((np.arange(w) * ow) // w, ow - 1)
    cell = (cy[:, None] * ow + cx[None, :]).reshape(-1)
    cnt = np.zeros((oh * ow, COLS + 1), np.int32); np.add.at(cnt, (cell, idx.reshape(-1)), 1)
    solid = cnt[:, :COLS].sum(1) * 2 >= cnt.sum(1)                 # at least half the cell is creature
    dom = cnt[:, :COLS].argmax(1)
    out = np.zeros((oh * ow, 4), np.uint8); out[:, :3] = pal[dom]; out[:, 3] = solid * 255
    return Image.fromarray(out.reshape(oh, ow, 4), 'RGBA')

def sheet(path, scale=2, per_row=16):
    names = sorted(f[:-4] for f in os.listdir(OUT) if f.endswith('.png'))
    c = SIZE * scale + 8; rows = (len(names) + per_row - 1) // per_row
    sh = Image.new('RGB', (per_row * c, rows * (c + 12)), (150, 150, 160)); d = ImageDraw.Draw(sh)
    for i, n in enumerate(names):
        im = Image.open(OUT + n + '.png'); im = im.resize((im.width * scale, im.height * scale), Image.NEAREST)
        x, y = (i % per_row) * c, (i // per_row) * (c + 12)
        sh.paste(im, (x + 4 + (SIZE * scale - im.width) // 2, y + 4 + SIZE * scale - im.height), im)
        d.text((x + 3, y + c - 2), n[:14], fill=(20, 20, 30))
    sh.save(path, quality=88); print(len(names), 'sprites ->', path)

if __name__ == '__main__':
    if sys.argv[1:2] == ['--sheet']: sheet(sys.argv[2] if len(sys.argv) > 2 else '/tmp/pixel_sheet.jpg'); sys.exit()
    m = json.load(open(A + 'LIVE_MANIFEST.json')); os.makedirs(OUT, exist_ok=True)
    todo = [(a.split(':') + [f'px9_{a.lower()}_1', ''])[:3] if ':' in a else (a, f'px9_{a.lower()}_1', '') for a in sys.argv[1:]] or [(n, f'px9_{n.lower()}_1', '') for n in m]
    bad = []
    for n, stem, opt in todo:
        try: finish(bload.load(stem), opt == 'holes').save(OUT + n + '.png')
        except FileNotFoundError: bad.append(n)
    print(len(todo) - len(bad), 'written to', OUT, '| no render:', bad)
