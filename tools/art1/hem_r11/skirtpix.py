import sys, glob, numpy as np
from PIL import Image
for d in sys.argv[1:]:
    L = []; rs = []
    for f in sorted(glob.glob(d + '/*_eye.jpg')) + sorted(glob.glob(d + '/*_knee.jpg')):
        a = np.asarray(Image.open(f).convert('RGB')).astype(float); m = (a[..., 0] > 1.8 * a[..., 1]) & (a[..., 0] > 1.8 * a[..., 2]) & (a[..., 0] > 40)
        if m.sum() < 200: continue
        c = a[m]; L.append(np.median(0.2126 * c[:, 0] + 0.7152 * c[:, 1] + 0.0722 * c[:, 2])); rs.append(np.median(c, 0))
    print(d.split('/')[-1], 'skirt-red px median lum %.0f rgb %s (frames %d)' % (np.median(L), np.median(rs, 0).astype(int), len(L)))
