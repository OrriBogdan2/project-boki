"""Lace r37 face pass: blend a baked face edit into the H1_tex face atlas, mesh/UVs untouched.

usage: python face37.py BASE.glb OUT.glb C.png W.png [--tex-out T.png] [--quality 92]
  C.png  edit colour baked into H1_tex UV space (bl_proj bake of the camera-space edit)
  W.png  blend weight in the same UV space (facing * visible * face mask), 0..255
Only the H1_tex image bufferView changes; texture size stays native (same as base).
"""
import argparse, io, os, sys
import numpy as np
from PIL import Image

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "hem_r17"))
import glbio  # noqa: E402

ap = argparse.ArgumentParser()
ap.add_argument("base"); ap.add_argument("out"); ap.add_argument("c"); ap.add_argument("w")
ap.add_argument("--tex-out"); ap.add_argument("--quality", type=int, default=92)
ap.add_argument("--image", default="H1_tex")
a = ap.parse_args()

j, b = glbio.load(a.base)
ii = [i for i, im in enumerate(j["images"]) if im.get("name") == a.image]
assert len(ii) == 1, ii
im = j["images"][ii[0]]
vi = im["bufferView"]; bv = j["bufferViews"][vi]
o = bv.get("byteOffset", 0); oldlen = bv["byteLength"]
old = Image.open(io.BytesIO(bytes(b[o:o + bv["byteLength"]]))).convert("RGB")
C = Image.open(a.c).convert("RGB"); Wm = Image.open(a.w).convert("L")
assert C.size == old.size == Wm.size, (C.size, old.size, Wm.size)
w = np.asarray(Wm).astype(np.float32)[..., None] / 255.0
new = np.asarray(old).astype(np.float32) * (1 - w) + np.asarray(C).astype(np.float32) * w
new = Image.fromarray(np.clip(new + 0.5, 0, 255).astype(np.uint8))
if a.tex_out:
    new.save(a.tex_out)
buf = io.BytesIO()
mime = im.get("mimeType", "image/jpeg")
if mime == "image/png":
    new.save(buf, "PNG", optimize=True)
else:
    new.save(buf, "JPEG", quality=a.quality, subsampling=0)
b = glbio.replace_view(j, b, vi, buf.getvalue())
glbio.save(a.out, j, b)
print("H1 px changed (w>0.02):", int((w[..., 0] > 0.02).sum()), "old", oldlen, "->", len(buf.getvalue()), "bytes", mime)
