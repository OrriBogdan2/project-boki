import sys
from PIL import Image

out = sys.argv[1]
files = sys.argv[2:]
ims = [Image.open(f).convert("RGB") for f in files]
w, h = ims[0].size
cols = 4
rows = (len(ims) + cols - 1) // cols
W = Image.new("RGB", (cols * w, rows * h))
for i, im in enumerate(ims):
    W.paste(im, ((i % cols) * w, (i // cols) * h))
W.save(out, quality=88)
