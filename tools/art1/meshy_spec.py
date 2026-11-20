"""A v95 swap spec for a new Meshy master (hunter regen 11-20), with no hand-read grid: the `joints` come from Meshy's
auto-rig of the master (meshy_task.py rig), and every other point of the old spec (`head`, `anchors`, the boxes of
`slots` and `regions`) is carried from the old master's body onto the new one by the joints of both:
  a point on the head (above the neck, inside the old head box) keeps its place on the head, scaled neck -> crown;
  a point at a hand (within HAND_R of a wrist) keeps its place at that wrist, scaled by the arm's length;
  any other point takes the body's heights (piecewise linear through sole, ankles, knees, pelvis, shoulders, neck, crown,
  the last stretch carried on above the crown) and its width x the shoulders' (above the pelvis) or the hips' (below).
Points are in the fit frame (V95_SWAP.md: his front +Y, his right +X, soles on z 0). Values of 9 or more are "open".
Run: blender -b --factory-startup --python tools/art1/meshy_spec.py -- OLD_SPEC MASTER RIGGED_GLB OUT_SPEC"""
import json
import os
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", ".."))
sys.path[:0] = [HERE, os.path.join(REPO, "tools", "meshy")]
import glb_add_clips  # noqa: E402

HAND_R = 0.16           # m (old master): an anchor this near a wrist is the hand's (gun, muzzle, thumb, wire)
JOINTS = {"pelvis": "Hips", "neck": "Head", "crown": "head_end"}
for _sd, _side in (("R", "Right"), ("L", "Left")):
    JOINTS.update({"shoulder." + _sd: _side + "Arm", "elbow." + _sd: _side + "ForeArm", "wrist." + _sd: _side + "Hand",
                   "hip." + _sd: _side + "UpLeg", "knee." + _sd: _side + "Leg", "ankle." + _sd: _side + "Foot"})


def accessor(j, b, i):
    a = j["accessors"][i]
    v = j["bufferViews"][a["bufferView"]]
    n = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}[a["type"]]
    dt = {5126: np.float32, 5125: np.uint32, 5123: np.uint16, 5121: np.uint8}[a["componentType"]]
    off = v.get("byteOffset", 0) + a.get("byteOffset", 0)
    stride = v.get("byteStride", 0) or n * np.dtype(dt).itemsize
    raw = np.frombuffer(bytes(b[off:off + stride * (a["count"] - 1) + n * np.dtype(dt).itemsize]), np.uint8)
    rows = np.lib.stride_tricks.as_strided(raw, (a["count"], n * np.dtype(dt).itemsize), (stride, 1))
    return np.ascontiguousarray(rows).view(dt).reshape(a["count"], n).astype(float)


def rig_joints(rigged, vmin, vptp):
    """Meshy's joints in the fit frame: its mesh (centred, +Y up, +Z front) laid on the master's box like meshy_weights."""
    j, b = glb_add_clips.read(rigged)
    R = np.concatenate([accessor(j, b, pr["attributes"]["POSITION"]) for me in j["meshes"] for pr in me["primitives"]])
    sk = j["skins"][0]
    ibm = accessor(j, b, sk["inverseBindMatrices"]).reshape(-1, 4, 4).transpose(0, 2, 1)      # (column-major)
    pos = {j["nodes"][n]["name"]: np.linalg.inv(m)[:3, 3] for n, m in zip(sk["joints"], ibm)}

    def fit(p):         # glTF -> fit: x -> -x (his right +X), z (front) -> y, y (up) -> z
        return np.asarray(p)[..., (0, 2, 1)] * (-1, 1, 1)
    F = fit(R)
    lo, sc = F.min(0), vptp / np.ptp(F, 0)
    out = {k: ((fit(pos[m]) - lo) * sc + vmin) for k, m in JOINTS.items() if m in pos}
    missing = [k for k in JOINTS if k not in out]
    if missing:
        sys.exit("meshy_spec: no Meshy joint for " + ", ".join(missing))
    if out["shoulder.R"][0] < out["shoulder.L"][0]:
        sys.exit("meshy_spec: Meshy's right arm is on his left: the master does not face +Z")
    pl = out["pelvis"]
    out["pelvis"] = np.array([0.0, pl[1], (out["hip.R"][2] + out["hip.L"][2]) / 2])     # (old specs: pelvis at hip height)
    return out


def master_box(path):
    import bpy
    import bake_warden as BW
    bpy.ops.wm.read_factory_settings(use_empty=True)
    high = BW.import_dense(os.path.expanduser(path))
    V = np.array([v.co for v in high.data.vertices]) * (-1, -1, 1)
    V[:, 2] -= V[:, 2].min()
    return V.min(0), np.ptp(V, 0)


def mapper(O, N):
    avg = lambda J, k: (J[k + ".R"] + J[k + ".L"]) / 2       # noqa: E731
    zo = [0.0, avg(O, "ankle")[2], avg(O, "knee")[2], O["pelvis"][2], avg(O, "shoulder")[2], O["neck"][2], O["crown"][2]]
    zn = [0.0, avg(N, "ankle")[2], avg(N, "knee")[2], N["pelvis"][2], avg(N, "shoulder")[2], N["neck"][2], N["crown"][2]]
    top = (zn[-1] - zn[-2]) / (zo[-1] - zo[-2])
    sw = (N["shoulder.R"][0] - N["shoulder.L"][0]) / (O["shoulder.R"][0] - O["shoulder.L"][0])
    hw = (N["hip.R"][0] - N["hip.L"][0]) / (O["hip.R"][0] - O["hip.L"][0])
    sh = zn[-1] / zo[-1]
    sc_head = (N["crown"][2] - N["neck"][2]) / (O["crown"][2] - O["neck"][2])

    def z_of(z):
        return float(np.interp(z, zo, zn)) if z <= zo[-1] else zn[-1] + (z - zo[-1]) * top

    def body(p):
        x, y, z = p
        return [x if abs(x) >= 9 else x * (sw if z > zo[3] else hw),
                y if abs(y) >= 9 else N["pelvis"][1] + (y - O["pelvis"][1]) * sh,
                z if abs(z) >= 9 else z_of(z)]

    def point(p, head_box=None):
        p = np.asarray(p, float)
        for sd in "RL":
            w = O["wrist." + sd]
            if np.linalg.norm(p - w) < HAND_R:
                arm = (np.linalg.norm(N["wrist." + sd] - N["elbow." + sd]) + np.linalg.norm(N["elbow." + sd] - N["shoulder." + sd])) / \
                      (np.linalg.norm(w - O["elbow." + sd]) + np.linalg.norm(O["elbow." + sd] - O["shoulder." + sd]))
                return list(N["wrist." + sd] + (p - w) * arm)
        if p[2] > O["neck"][2] and (head_box is None or (head_box[0] <= p[0] <= head_box[1] and head_box[2] <= p[1] <= head_box[3])):
            return list(N["neck"] + (p - O["neck"]) * sc_head)
        return body(p)

    return point, body, sc_head


def main():
    a = sys.argv[sys.argv.index("--") + 1:]
    old_path, master, rigged, out = a[:4]
    spec = json.load(open(old_path))
    O = {k: np.array(v, float) for k, v in spec["joints"].items()}
    N = rig_joints(rigged, *master_box(master))
    point, body, sc_head = mapper(O, N)
    hb = next((r["box"] for r in spec.get("regions", []) if r.get("bone") == "head"), None)
    new = dict(spec)
    new["master"] = master
    new["joints"] = {k: [round(float(c), 3) for c in N[k]] for k in O}
    if "head" in spec:
        new["head"] = {"centre": [round(c, 3) for c in point(spec["head"]["centre"], hb)], "r": round(spec["head"]["r"] * sc_head, 3)}
    new["anchors"] = {k: [round(float(c), 3) for c in point(v, hb)] for k, v in spec.get("anchors", {}).items()}
    for key in ("slots", "regions"):
        rows = []
        for r in spec.get(key, []):
            r = dict(r)
            if "box" in r:
                b = r["box"]
                lo, hi = body([b[0], b[2], b[4]]), body([b[1], b[3], b[5]])
                r["box"] = [round(float(c), 3) for c in (lo[0], hi[0], lo[1], hi[1], lo[2], hi[2])]
            rows.append(r)
        new[key] = rows
    new["doc"] = "hunter regen 11-20 (tools/art1/meshy_spec.py from %s): joints from Meshy's auto-rig, the rest carried over" % \
        os.path.basename(old_path)
    json.dump(new, open(out, "w"), indent=1)
    O_h, N_h = O["crown"][2], N["crown"][2]
    print("MESHY_SPEC crown %.3f -> %.3f m, neck->crown %.3f -> %.3f, pelvis %.3f -> %.3f -> %s" % (
        O_h, N_h, O["crown"][2] - O["neck"][2], N["crown"][2] - N["neck"][2], O["pelvis"][2], N["pelvis"][2], out), flush=True)


main()
