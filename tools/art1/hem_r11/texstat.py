import sys, numpy as np
from PIL import Image
uv = np.load('/home/boki/gens/lace-r11/rtx/uv.npz')
for f in sys.argv[1:]:
    im = np.asarray(Image.open(f).convert('RGB')).astype(float); H, W, _ = im.shape
    for k in ('out', 'inn'):
        u = uv[k]; x = np.clip((u[:, 0] * W).astype(int), 0, W - 1); y = np.clip(((1 - u[:, 1]) * H).astype(int), 0, H - 1); c = im[y, x]
        lum = 0.2126 * c[:, 0] + 0.7152 * c[:, 1] + 0.0722 * c[:, 2]; red = ((c[:, 0] > 1.5 * c[:, 1]) & (c[:, 0] > 1.2 * c[:, 2])).mean()
        print('%-34s %s median rgb %s lum %3.0f red %.2f' % (f.split('/')[-2], k, np.median(c, 0).astype(int), np.median(lum), red))
