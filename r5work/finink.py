"""finink.py IN.glb OUT.glb [ALPHA [RAD]]: sets COLOR_0 alpha (ink room) to ALPHA (default 0) on the head-fin vertices
(Head-dominant, behind the face z<-0.02, y>1.3, pale skin texture (luminance>0.5)) so the ink shell cannot poke through the thin fin."""
import io, json, struct, sys, numpy as np
from PIL import Image
from glbp import load, acc, img
from scipy.spatial import cKDTree
src, dst = sys.argv[1:3]; al = float(sys.argv[3]) if len(sys.argv) > 3 else 0.0
RAD = float(sys.argv[4]) if len(sys.argv) > 4 else 0.0   # also the Head-bone verts within RAD m of the pale fin verts (its dark root and tip texels)
j, b = load(src); bl = bytearray(b)
im = np.asarray(Image.open(io.BytesIO(img(j, b, 0))).convert("RGB")).astype(float) / 255
sk = j["skins"][0]["joints"]; jn = [j["nodes"][i]["name"] for i in sk]
tot = 0
for p in j["meshes"][0]["primitives"]:
    A = p["attributes"]; pos = acc(j, b, A["POSITION"]); J = acc(j, b, A["JOINTS_0"]).astype(int); W = acc(j, b, A["WEIGHTS_0"])
    main = J[np.arange(len(J)), W.argmax(1)]
    uv = acc(j, b, A["TEXCOORD_0"]); H, Wd, _ = im.shape
    lum = im[(uv[:, 1] % 1 * (H - 1)).astype(int), (uv[:, 0] % 1 * (Wd - 1)).astype(int)].mean(1)
    fin = np.array([jn[k] == "Head" for k in main]) & (pos[:, 2] < -0.02) & (pos[:, 1] > 1.3) & (lum > 0.5)
    if RAD > 0 and fin.sum():
        base = np.array([jn[k] == "Head" for k in main]) & (pos[:, 2] < -0.02) & (pos[:, 1] > 1.3)
        d, _ = cKDTree(pos[fin]).query(pos[base]); near = base.copy(); near[base] = d < RAD; fin = fin | near
    a = j["accessors"][A["COLOR_0"]]; bv = j["bufferViews"][a["bufferView"]]; o = bv.get("byteOffset", 0) + a.get("byteOffset", 0)
    assert a["type"] == "VEC4" and a["componentType"] == 5126 and "byteStride" not in bv
    col = np.frombuffer(bl, "<f4", a["count"] * 4, o).reshape(-1, 4).copy(); col[fin, 3] = al
    bl[o:o + col.nbytes] = col.astype("<f4").tobytes(); tot += int(fin.sum())
    if fin.sum(): print("bbox", pos[fin].min(0).round(3), pos[fin].max(0).round(3))
print("fin verts set:", tot)
hdr = json.dumps(j, separators=(",", ":")).encode(); hdr += b" " * ((4 - len(hdr) % 4) % 4)
open(dst, "wb").write(b"glTF" + struct.pack("<II", 2, 20 + len(hdr) + 8 + len(bl)) + struct.pack("<I", len(hdr)) + b"JSON" + hdr + struct.pack("<I", len(bl)) + b"BIN\0" + bytes(bl))
