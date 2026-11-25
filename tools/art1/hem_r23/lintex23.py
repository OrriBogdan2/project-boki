# lintex23.py SKIRT_TEX.jpg OUT.jpg [k_r k_g k_b] : the skirt lining texture: the skirt's own texture scaled to a deep wine
# (the turnaround's lining is darker red/plum than the outside), same UV.
import sys, numpy as np
from PIL import Image
k = np.array([float(x) for x in sys.argv[3:6]]) if len(sys.argv) > 5 else np.array([0.55, 0.45, 0.70])
im = np.asarray(Image.open(sys.argv[1]).convert('RGB')).astype(float)
o = np.clip(im * k, 0, 255).astype(np.uint8); Image.fromarray(o).save(sys.argv[2], quality=90)
print('median in', np.median(im.reshape(-1, 3), 0), 'out', np.median(o.reshape(-1, 3), 0))
