"""Keep the live head on a rebuilt game glb (job rebuild-dredge-1119): both glbs are the same Warden on the same skeleton
(v95_swap output from the same game.glb), so the live glb's head triangles (every vertex dominated by a HEAD bone), with
their vertex data, skin and own materials/images, are copied byte-identical in bind space into the new glb, whose own
head triangles are dropped. Face pixels and face geometry stay the live ones. Plain glTF/numpy, no Blender.
Run: python3 -I tools/art1/glb_head_keep.py REPO OLD_GLB NEW_GLB OUT_GLB"""
import json
import struct
import sys

import numpy as np

repo, old_p, new_p, out_p = sys.argv[1:5]
sys.path.insert(0, repo + "/tools")
import hunter_mesh_check as H  # noqa: E402

HEAD = {"head", "eye", "lid", "brow", "jaw"} | {"spring_hangmono_%d" % i for i in range(4)}
CT = {5120: np.int8, 5121: np.uint8, 5122: np.int16, 5123: np.uint16, 5125: np.uint32, 5126: np.float32}
NC = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}


def load(p):
    g = H.Glb(open(p, "rb").read())
    return g, g.j, bytearray(g.bin)


def acc_raw(g, i):
    """Accessor data in its own component type (no normalisation)."""
    a = g.j["accessors"][i]
    bv = g.j["bufferViews"][a["bufferView"]]
    dt = np.dtype(CT[a["componentType"]])
    n = NC[a["type"]]
    st = bv.get("byteStride", dt.itemsize * n)
    off = bv.get("byteOffset", 0) + a.get("byteOffset", 0)
    return np.ndarray((a["count"], n), dtype=dt, buffer=g.bin, offset=off, strides=(st, dt.itemsize)).copy()


go, jo, _ = load(old_p)
gn, jn, binn = load(new_p)
names_o = [jo["nodes"][n]["name"] for n in jo["skins"][0]["joints"]]
names_n = [jn["nodes"][n]["name"] for n in jn["skins"][0]["joints"]]
remap = np.array([names_n.index(nm) for nm in names_o])
ibm_o = acc_raw(go, jo["skins"][0]["inverseBindMatrices"]).reshape(-1, 16)
ibm_n = acc_raw(gn, jn["skins"][0]["inverseBindMatrices"]).reshape(-1, 16)
dev = max(float(np.abs(ibm_o[i] - ibm_n[remap[i]]).max()) for i in range(len(names_o)))
print("IBM max deviation old vs new", round(dev, 6))
assert dev < 1e-3, "skeletons differ: a head copied in bind space would sit wrong"


def add_view(data, target=None):
    while len(binn) % 4:
        binn.append(0)
    off = len(binn)
    binn.extend(data)
    v = {"buffer": 0, "byteOffset": off, "byteLength": len(data)}
    if target:
        v["target"] = target
    jn["bufferViews"].append(v)
    return len(jn["bufferViews"]) - 1


def add_acc(arr, ctype, typ, target=None, minmax=False):
    arr = np.ascontiguousarray(arr.astype(CT[ctype]))
    a = {"bufferView": add_view(arr.tobytes(), target), "componentType": ctype, "count": int(arr.shape[0]), "type": typ}
    if minmax:
        a["min"] = arr.min(0).tolist()
        a["max"] = arr.max(0).tolist()
    jn["accessors"].append(a)
    return len(jn["accessors"]) - 1


def dominant(g, j, prim, names):
    J = acc_raw(g, prim["attributes"]["JOINTS_0"])
    W = g.acc(prim["attributes"]["WEIGHTS_0"]).reshape(-1, 4)
    return np.array([names[J[i, k]] in HEAD for i, k in enumerate(W.argmax(1))])


# 1. drop the new glb's head triangles
dropped = 0
for m in jn["meshes"]:
    kept = []
    for pr in m["primitives"]:
        hv = dominant(gn, jn, pr, names_n)
        idx = acc_raw(gn, pr["indices"]).reshape(-1, 3)
        keep = ~hv[idx].all(1)
        dropped += int((~keep).sum())
        if keep.any():      # (a primitive left with no triangles is invalid glTF: Godot refuses the whole file)
            pr["indices"] = add_acc(idx[keep].reshape(-1, 1), 5125, "SCALAR", 34963)
            kept.append(pr)
    m["primitives"] = kept
print("new head tris dropped", dropped)

# 2. copy the old head's materials, textures and images
img_map, tex_map, mat_map, samp_map = {}, {}, {}, {}


def copy_image(i):
    if i not in img_map:
        im = dict(jo["images"][i])
        bv = jo["bufferViews"][im.pop("bufferView")]
        data = go.bin[bv.get("byteOffset", 0): bv.get("byteOffset", 0) + bv["byteLength"]]
        im["bufferView"] = add_view(data)
        im["name"] = "v95live" + im.get("name", str(i))
        jn["images"].append(im)
        img_map[i] = len(jn["images"]) - 1
    return img_map[i]


def copy_tex(t):
    if t not in tex_map:
        tx = dict(jo["textures"][t])
        tx["source"] = copy_image(tx["source"])
        if "sampler" in tx:
            s = tx["sampler"]
            if s not in samp_map:
                jn.setdefault("samplers", []).append(jo["samplers"][s])
                samp_map[s] = len(jn["samplers"]) - 1
            tx["sampler"] = samp_map[s]
        jn["textures"].append(tx)
        tex_map[t] = len(jn["textures"]) - 1
    return tex_map[t]


def fix_tex_refs(o):
    if isinstance(o, dict):
        for k, v in o.items():
            if k == "index" and "texCoord" in o or (k == "index" and isinstance(v, int) and len(o) <= 3):
                o[k] = copy_tex(v)
            else:
                fix_tex_refs(v)
    elif isinstance(o, list):
        for v in o:
            fix_tex_refs(v)


def copy_mat(mi):
    if mi not in mat_map:
        m = json.loads(json.dumps(jo["materials"][mi]))
        fix_tex_refs(m)
        m["name"] = m.get("name", "") + "-livehead"
        jn["materials"].append(m)
        mat_map[mi] = len(jn["materials"]) - 1
    return mat_map[mi]


# 3. copy the old head triangles as new primitives on the new mesh
added = 0
mesh_n = jn["meshes"][0]
for pr in jo["meshes"][0]["primitives"]:
    hv = dominant(go, jo, pr, names_o)
    idx = acc_raw(go, pr["indices"]).reshape(-1, 3)
    sel = hv[idx].all(1)
    if not sel.any():
        continue
    tris = idx[sel]
    used = np.unique(tris)
    loc = np.full(len(hv), -1)
    loc[used] = np.arange(len(used))
    attrs = {}
    for k, ai in pr["attributes"].items():
        a = jo["accessors"][ai]
        arr = acc_raw(go, ai)[used]
        if k == "JOINTS_0":
            arr = remap[arr.astype(int)]
            attrs[k] = add_acc(arr, 5123, "VEC4", 34962)
            continue
        new = add_acc(arr, a["componentType"], a["type"], 34962, minmax=(k == "POSITION"))
        if a.get("normalized"):
            jn["accessors"][new]["normalized"] = True
        attrs[k] = new
    np_ = {"attributes": attrs, "indices": add_acc(loc[tris].reshape(-1, 1), 5125, "SCALAR", 34963)}
    if "material" in pr:
        np_["material"] = copy_mat(pr["material"])
    mesh_n["primitives"].append(np_)
    added += len(tris)
print("live head tris added", added)

jn["buffers"][0]["byteLength"] = len(binn)
while len(binn) % 4:
    binn.append(0)
js = json.dumps(jn, separators=(",", ":")).encode()
js += b" " * ((4 - len(js) % 4) % 4)
with open(out_p, "wb") as f:
    f.write(struct.pack("<III", 0x46546C67, 2, 12 + 8 + len(js) + 8 + len(binn)))
    f.write(struct.pack("<II", len(js), 0x4E4F534A) + js)
    f.write(struct.pack("<II", len(binn), 0x004E4942) + bytes(binn))
print("wrote", out_p)
