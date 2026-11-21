#!/usr/bin/env python3
"""Two-rigger pilot (docs/art/wardens/RIG_GATE.md): the same hunter mesh rigged by different automatic riggers,
each fitted to the RIG_CONTRACT by replacing only the BODY skin weights of the shipped contract glb, then judged by
tools/meshy/rig_gate.py. The contract armature, the clips, the accessories (weapon, shield, cloth, springs) and the
mesh stay the shipped glb's, so the gate compares the riggers' weights and nothing else.

  rig_pilot.py meshy  OUT_DIR static_z.glb [--no-fingers]   Meshy auto-rig of a +Z-facing static glb (5 credits)
  rig_pilot.py fit-meshy  SHIPPED.glb OUT_DIR/rigged_character_glb.glb OUT.glb [--turn 180]
  rig_pilot.py fit-json   SHIPPED.glb autoweight.json OUT.glb   (Blender heat weights from tools/blender/rig_pilot.py)
  rig_pilot.py sheet OUT.png hero live_dir=grey A=dir=green|red B=dir=green|red   the rig frames side by side

fit-meshy maps the Meshy (Mixamo-named) bones onto contract bones (spine -> hips, neck/head -> head, arm/forearm/hand,
every finger -> hand, up-leg/leg/foot/toe -> thigh/shin), aligns the Meshy mesh to the shipped one (turn, scale,
shift on the bounding boxes), and gives each shipped body vertex the weights of the nearest Meshy vertex.
"""

from __future__ import annotations

import argparse
import base64
import json
import re
import struct
import sys
from pathlib import Path

import numpy as np

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
sys.path.insert(0, str(HERE.parent))
import hunter_mesh_check as H  # noqa: E402

BODY_BONES = ("hips", "head", "upper_arm", "forearm", "hand", "thigh", "shin", "x_fing", "x_thumb", "x_foot")
MESHY_MAP = [  # (regex on the Meshy bone name, contract bone); {s} is the side
    (r"^(Left|Right)HandThumb|^(Left|Right)Hand(Index|Middle|Ring|Pinky)", "hand.{s}"),
    (r"^(Left|Right)Hand$", "hand.{s}"),
    (r"^(Left|Right)ForeArm$", "forearm.{s}"),
    (r"^(Left|Right)Arm$", "upper_arm.{s}"),
    (r"^(Left|Right)Shoulder$", "hips"),
    (r"^(Left|Right)UpLeg$", "thigh.{s}"),
    (r"^(Left|Right)Leg$", "shin.{s}"),
    (r"^(Left|Right)(Foot|ToeBase|Toe_End)", "shin.{s}"),
    (r"^(Neck|Head|HeadTop_End)", "head"),
    (r"^(Hips|Spine)", "hips"),
]


def meshy_rig(out: Path, glb: Path, fingers: bool):
    import meshy_task as mt

    body = {
        "model_url": "data:application/octet-stream;base64," + base64.b64encode(glb.read_bytes()).decode(),
        "height_meters": 1.55,
        "include_fingers": fingers,
    }
    mt.post(str(out), "rigging", body, {"source": str(glb)})


def contract_name(bone: str) -> str | None:
    s = "L" if bone.lower().startswith("left") else "R"
    for rx, to in MESHY_MAP:
        if re.search(rx, bone.replace("mixamorig:", ""), re.I):
            return to.format(s=s)
    return None


def contract_of(nodes: list, parent: list, jnodes: list) -> list:
    """Contract bone of each joint: its own name, else its nearest named ancestor's (Meshy's finger and face bones
    come out as Bone_030...)."""
    out = []
    for n in jnodes:
        c, k = None, n
        while c is None and k != -1:
            c = contract_name(nodes[k].get("name", ""))
            k = parent[k]
        out.append(c)
    return out


def align(src: np.ndarray, dst: np.ndarray, turn: float) -> np.ndarray:
    """Meshy mesh -> shipped frame: turn about up, scale on the height, centre the feet on the shipped feet."""
    a = np.radians(turn)
    rot = np.array([[np.cos(a), 0, np.sin(a)], [0, 1, 0], [-np.sin(a), 0, np.cos(a)]])
    p = src @ rot.T
    k = (dst[:, 1].max() - dst[:, 1].min()) / (p[:, 1].max() - p[:, 1].min())
    p = p * k
    p[:, 1] += dst[:, 1].min() - p[:, 1].min()
    p[:, [0, 2]] += (dst[:, [0, 2]].min(0) + dst[:, [0, 2]].max(0)) / 2 - (p[:, [0, 2]].min(0) + p[:, [0, 2]].max(0)) / 2
    return p


def patch(data: bytes, joints: np.ndarray, weights: np.ndarray) -> bytes:
    """Rewrite JOINTS_0 / WEIGHTS_0 of every skinned primitive (in Body order) inside a glb."""
    g = H.Glb(data)
    j = g.j
    buf = bytearray(data)
    start = None
    off = 12
    while off < len(data):
        ln, kind = struct.unpack_from("<II", data, off)
        if kind == 0x004E4942:
            start = off + 8
            break
        off += 8 + ln
    base = 0
    for nd in j["nodes"]:
        if "mesh" not in nd:
            continue
        for p in j["meshes"][nd["mesh"]]["primitives"]:
            at = p["attributes"]
            if "POSITION" not in at or p.get("mode", 4) != 4:
                continue
            n = j["accessors"][at["POSITION"]]["count"]
            for key, arr in (("JOINTS_0", joints), ("WEIGHTS_0", weights)):
                if key not in at:
                    continue
                acc = j["accessors"][at[key]]
                bv = j["bufferViews"][acc["bufferView"]]
                ct = H.CT[acc["componentType"]]
                size = np.dtype(ct).itemsize * 4
                stride = bv.get("byteStride") or size
                o0 = start + bv.get("byteOffset", 0) + acc.get("byteOffset", 0)
                chunk = arr[base : base + n]
                if key == "WEIGHTS_0" and acc["componentType"] != 5126:
                    chunk = np.round(chunk * np.iinfo(ct).max)
                rec = chunk.astype(ct)
                for i in range(n):
                    buf[o0 + i * stride : o0 + i * stride + size] = rec[i].tobytes()
            base += n
    return bytes(buf)


def new_skin(h, shipped_names, vert_weights: list[dict]) -> tuple[np.ndarray, np.ndarray]:
    """JOINTS/WEIGHTS for every vertex: the shipped ones, except the body vertices that got `vert_weights[i]`."""
    b = h.body
    joints, weights = b.joints.copy(), b.weights.copy()
    idx = {n: k for k, n in enumerate(shipped_names)}
    for i, w in enumerate(vert_weights):
        if not w:
            continue
        items = sorted(((idx[k], v) for k, v in w.items() if k in idx), key=lambda t: -t[1])[:4]
        tot = sum(v for _, v in items)
        if tot <= 0:
            continue
        joints[i] = 0
        weights[i] = 0.0
        for s, (jn, v) in enumerate(items):
            joints[i, s], weights[i, s] = jn, v / tot
    return joints, weights


def body_verts(h, shipped_names) -> np.ndarray:
    b = h.body
    dom = b.joints[np.arange(len(b.pos)), b.weights.argmax(axis=1)]
    return np.array([shipped_names[k].split(".")[0] in BODY_BONES for k in dom])


def load(shipped: Path):
    sys.path.insert(0, str(HERE))
    import rig_gate as R

    h = R.Hunter(shipped, None)
    return h, h.names


def nearest(a: np.ndarray, b: np.ndarray) -> np.ndarray:
    from scipy.spatial import cKDTree

    return cKDTree(a).query(b)[1]


def fit_meshy(shipped: Path, rigged: Path, out: Path, turn: float):
    h, names = load(shipped)
    g = H.Glb(rigged.read_bytes())
    mb = H.Body(g)
    skin = g.j["skins"][mb.skin]
    mnames = [g.j["nodes"][n]["name"] for n in skin["joints"]]
    # the rigger's mesh in the node's world frame is the skin space; align it to the shipped mesh
    rig = H.Rig(g)
    heads = np.stack([np.linalg.inv(ibm)[:3, 3] for ibm in g.acc(skin["inverseBindMatrices"]).reshape(-1, 4, 4).transpose(0, 2, 1)])
    dom = h.body.joints[np.arange(len(h.body.pos)), h.body.weights.argmax(axis=1)]
    no_weapon = np.array([not names[k].startswith(("x_weapon", "weapon")) for k in dom])  # the rigger saw no weapon
    both = align(np.concatenate([mb.pos, heads]), h.body.pos[no_weapon], turn)
    mp, heads = both[: len(mb.pos)], both[len(mb.pos) :]
    err = {}
    for mn, cn in (("Hips", "hips"), ("Head", "head"), ("LeftArm", "upper_arm.L"), ("LeftForeArm", "forearm.L"),
                   ("LeftHand", "hand.L"), ("LeftUpLeg", "thigh.L"), ("LeftLeg", "shin.L"), ("RightArm", "upper_arm.R"),
                   ("RightUpLeg", "thigh.R"), ("RightLeg", "shin.R")):
        if mn in mnames and cn in names:
            err[cn] = round(100 * float(np.linalg.norm(heads[mnames.index(mn)] - h.heads[names.index(cn)])), 1)
    print("joint offset vs contract heads (cm):", err, "mean", round(float(np.mean(list(err.values()))), 1))
    body = body_verts(h, names)
    ib = np.nonzero(body)[0]
    nn = nearest(mp, h.body.pos[ib])
    to = contract_of(g.j["nodes"], rig.parent, skin["joints"])
    per = []
    for vi in nn:
        w: dict = {}
        for jn, wt in zip(mb.joints[vi], mb.weights[vi]):
            c = to[jn]
            if c is not None and wt > 0:
                w[c] = w.get(c, 0.0) + float(wt)
        per.append(w)
    vw = [None] * len(h.body.pos)
    for i, w in zip(ib, per):
        vw[i] = w
    joints, weights = new_skin(h, names, vw)
    out.write_bytes(patch(shipped.read_bytes(), joints, weights))
    print(f"fit-meshy: {len(ib)} body verts re-weighted from {len(mnames)} Meshy bones -> {out}")
    unmapped = sorted({n for n, t in zip(mnames, to) if t is None})
    print("unmapped Meshy bones:", unmapped)


def fit_json(shipped: Path, js: Path, out: Path):
    h, names = load(shipped)
    d = json.loads(js.read_text())
    pts = np.array(d["pos"])
    body = body_verts(h, names)
    ib = np.nonzero(body)[0]
    nn = nearest(pts, h.body.pos[ib])
    vw = [None] * len(h.body.pos)
    for i, k in zip(ib, nn):
        vw[i] = d["w"][k]
    joints, weights = new_skin(h, names, vw)
    out.write_bytes(patch(shipped.read_bytes(), joints, weights))
    print(f"fit-json: {len(ib)} body verts re-weighted -> {out}")


def sheet(out: Path, hero: str, cols: list[str]):
    """One row per rig frame (state x level x side), one column per rigger; the border colour is the verdict
    (grey = the live rig, green = better than live, red = worse), the letters are in rank order."""
    from PIL import Image, ImageDraw

    colour = {"grey": (150, 150, 150), "green": (40, 190, 80), "red": (210, 50, 50)}
    spec = [c.split("=") for c in cols]
    states = [(s, lv, az) for s in ("walk", "run", "attack") for lv in ("eye", "knee") for az in ("f", "b")]
    cw, ch = 560, 315
    img = Image.new("RGB", (len(spec) * (cw + 12) + 12, len(states) * (ch + 12) + 12), (24, 24, 24))
    dr = ImageDraw.Draw(img)
    for r, (st, lv, az) in enumerate(states):
        for c, (name, folder, verdict) in enumerate(spec):
            f = Path(folder) / f"{hero}_{st}_{lv}_{az}.png"
            x, y = 12 + c * (cw + 12), 12 + r * (ch + 12)
            if f.exists():
                img.paste(Image.open(f).convert("RGB").resize((cw, ch)), (x, y))
            dr.rectangle([x - 4, y - 4, x + cw + 3, y + ch + 3], outline=colour[verdict], width=4)
            if r == 0:
                dr.text((x + 8, y + 6), name, fill=(255, 255, 255))
    img.save(out)
    print("sheet ->", out)


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    sub = ap.add_subparsers(dest="cmd", required=True)
    m = sub.add_parser("meshy")
    m.add_argument("out")
    m.add_argument("glb")
    m.add_argument("--no-fingers", action="store_true")
    f = sub.add_parser("fit-meshy")
    f.add_argument("shipped")
    f.add_argument("rigged")
    f.add_argument("out")
    f.add_argument("--turn", type=float, default=180.0)
    sh = sub.add_parser("sheet")
    sh.add_argument("out")
    sh.add_argument("hero")
    sh.add_argument("cols", nargs="+")
    j = sub.add_parser("fit-json")
    j.add_argument("shipped")
    j.add_argument("json")
    j.add_argument("out")
    a = ap.parse_args()
    if a.cmd == "meshy":
        meshy_rig(Path(a.out), Path(a.glb), not a.no_fingers)
    elif a.cmd == "sheet":
        sheet(Path(a.out), a.hero, a.cols)
    elif a.cmd == "fit-meshy":
        fit_meshy(Path(a.shipped), Path(a.rigged), Path(a.out), a.turn)
    else:
        fit_json(Path(a.shipped), Path(a.json), Path(a.out))


if __name__ == "__main__":
    main()
