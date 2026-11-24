"""finuv.py IN.glb OUT.glb [RAD]: Head-bone fin verts (near the pale fin, behind the head) whose texel is near black (lum<0.2) take the UV of
the nearest pale fin vertex, so the thin fin never samples the dark padding/hat texels (the black patch seen from above)."""
import io, json, struct, sys, numpy as np
from PIL import Image
from scipy.spatial import cKDTree
from glbp import load, acc, img
src, dst = sys.argv[1:3]; RAD = float(sys.argv[3]) if len(sys.argv) > 3 else 0.03
j, b = load(src); bl = bytearray(b)
im = np.asarray(Image.open(io.BytesIO(img(j, b, 0))).convert("RGB")).astype(float) / 255
jn = [j["nodes"][i]["name"] for i in j["skins"][0]["joints"]]; tot = 0
for p in j["meshes"][0]["primitives"]:
    A = p["attributes"]; pos = acc(j, b, A["POSITION"]); J = acc(j, b, A["JOINTS_0"]).astype(int); W = acc(j, b, A["WEIGHTS_0"])
    main = J[np.arange(len(J)), W.argmax(1)]; uv = acc(j, b, A["TEXCOORD_0"]).copy(); H, Wd, _ = im.shape
    lum = im[(uv[:, 1] % 1 * (H - 1)).astype(int), (uv[:, 0] % 1 * (Wd - 1)).astype(int)].mean(1)
    base = np.array([jn[k] == "Head" for k in main]) & (pos[:, 2] < -0.02) & (pos[:, 1] > 1.3)
    pale = base & (lum > 0.5)
    if not pale.sum(): continue
    d, _ = cKDTree(pos[pale]).query(pos); ylo, yhi = pos[pale,1].min() - 0.005, pos[pale,1].max() + 0.002; zlo, zhi = pos[pale,2].min() - 0.005, pos[pale,2].max()
    near = base & (d < RAD) & (pos[:,1] > ylo) & (pos[:,1] < yhi) & (pos[:,2] > zlo) & (pos[:,2] < zhi); dark = near & (lum < 0.2)
    _, k = cKDTree(pos[pale]).query(pos[dark]); uv[dark] = uv[pale][k]; tot += int(dark.sum())
    a = j["accessors"][A["TEXCOORD_0"]]; bv = j["bufferViews"][a["bufferView"]]; o = bv.get("byteOffset", 0) + a.get("byteOffset", 0)
    assert a["componentType"] == 5126 and "byteStride" not in bv
    bl[o:o + uv.nbytes] = uv.astype("<f4").tobytes()
print("uv snapped:", tot)
hdr = json.dumps(j, separators=(",", ":")).encode(); hdr += b" " * ((4 - len(hdr) % 4) % 4)
open(dst, "wb").write(b"glTF" + struct.pack("<II", 2, 20 + len(hdr) + 8 + len(bl)) + struct.pack("<I", len(hdr)) + b"JSON" + hdr + struct.pack("<I", len(bl)) + b"BIN\0" + bytes(bl))
