#!/usr/bin/env python3
"""Per-region triangle counts and finger-bone presence of a Warden .glb (report only, nothing is written).

A skinned triangle belongs to the region of its vertices' dominant bone (majority of its three corners): head, hand
(hand.*, claw and finger bones, per side), forearm, upper_arm, torso, legs, other. A mesh without a skin is a prop (its own line).
Run: python3 tools/art1/glb_regions.py a.glb [b.glb ...] [--json]
Exit 1 when a hand holds under MIN_HAND_SHARE of the skinned triangles (the hand-flattening cause 2, DECIMATE.md)."""

import json
import re
import struct
import sys

import numpy as np

MIN_HAND_SHARE = 0.06  # per hand, of the skinned triangles (the target the 60k decimate protects)
FINGER = re.compile(r"^(fing|thumb|index|middle|ring|pinky)", re.I)
REGIONS = (  # first match on any "._"-separated token of the bone name
    ("hand", re.compile(r"^(hand|claw|fing|thumb|index|middle|ring|pinky)", re.I)),
    ("weapon", re.compile(r"^(weapon|bow|arrow|gun|blade|sword|spear|hammer|shield|staff|lance|muzzle|mag)", re.I)),
    ("head", re.compile(r"^(head|neck|jaw|eye|ear|face|lid|brow)", re.I)),
    ("forearm", re.compile(r"^(forearm|elbow)", re.I)),
    ("upper_arm", re.compile(r"^(upper|arm|shoulder|pauldron)", re.I)),
    ("legs", re.compile(r"^(thigh|shin|foot|toe|leg|knee)", re.I)),
    ("torso", re.compile(r"^(hips|spine|chest|root|pelvis|torso|body)", re.I)),
)
CT = {5120: np.int8, 5121: np.uint8, 5122: np.int16, 5123: np.uint16, 5125: np.uint32, 5126: np.float32}
NC = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}


def load(path):
    raw = open(path, "rb").read()
    n = struct.unpack("<I", raw[12:16])[0]
    j = json.loads(raw[20 : 20 + n])
    return j, raw[28 + n :]


def accessor(j, blob, i):
    a = j["accessors"][i]
    bv = j["bufferViews"][a["bufferView"]]
    dt, nc = np.dtype(CT[a["componentType"]]), NC[a["type"]]
    stride = bv.get("byteStride") or dt.itemsize * nc
    off = bv.get("byteOffset", 0) + a.get("byteOffset", 0)
    buf = np.frombuffer(blob, np.uint8, count=(a["count"] - 1) * stride + dt.itemsize * nc, offset=off)
    rows = np.lib.stride_tricks.as_strided(buf, (a["count"], dt.itemsize * nc), (stride, 1))
    return np.ascontiguousarray(rows).view(dt).reshape(a["count"], nc)


def region_of(bone):
    for tok in re.split(r"[._]", bone):
        for name, rx in REGIONS:
            if rx.search(tok):
                return name
    return "other"


def side_of(bone):
    m = re.search(r"[._]([LR])$|^(Left|Right)", bone)
    return "" if not m else (m.group(1) or m.group(2)[0])


def report(path):
    j, blob = load(path)
    nodes = j["nodes"]
    rows, fingers = {}, []
    for sk in j.get("skins", []):
        fingers += [
            nodes[i]["name"] for i in sk["joints"] if any(FINGER.match(t) for t in re.split(r"[._]", nodes[i]["name"]))
        ]
    prop_tris = {}
    for nd in nodes:
        if "mesh" not in nd:
            continue
        skin = nd.get("skin")
        for pr in j["meshes"][nd["mesh"]]["primitives"]:
            idx = accessor(j, blob, pr["indices"]).reshape(-1, 3) if "indices" in pr else None
            if idx is None:
                continue
            if skin is None:
                prop_tris[nd["name"]] = prop_tris.get(nd["name"], 0) + len(idx)
                continue
            joints = accessor(j, blob, pr["attributes"]["JOINTS_0"]).astype(int)
            wts = accessor(j, blob, pr["attributes"]["WEIGHTS_0"]).astype(np.float32)
            names = [nodes[i]["name"] for i in j["skins"][skin]["joints"]]
            dom = np.array(names, dtype=object)[joints[np.arange(len(joints)), wts.argmax(1)]]
            cls = np.array(
                [region_of(b) + side_of(b) if region_of(b) == "hand" else region_of(b) for b in dom], dtype=object
            )
            for t in idx:
                c = cls[t]
                key = max(set(c), key=list(c).count)
                rows[key] = rows.get(key, 0) + 1
    total = sum(rows.values())
    return {
        "glb": path,
        "skinned_tris": total,
        "regions": rows,
        "props": prop_tris,
        "finger_bones": sorted(set(fingers)),
    }


def main():
    args = [a for a in sys.argv[1:] if a != "--json"]
    out, bad = [], False
    for p in args:
        r = report(p)
        out.append(r)
        t = max(r["skinned_tris"], 1)
        hands = {k: v / t for k, v in r["regions"].items() if k.startswith("hand")}
        bad |= any(v < MIN_HAND_SHARE for v in hands.values()) or len(hands) < 2
        if "--json" not in sys.argv:
            sh = "  ".join("%s %d (%.1f%%)" % (k, v, 100.0 * v / t) for k, v in sorted(r["regions"].items()))
            print(
                "%s: %d skinned tris\n  %s\n  props: %s\n  finger bones: %s"
                % (p, r["skinned_tris"], sh, r["props"] or "none", ", ".join(r["finger_bones"]) or "none")
            )
    if "--json" in sys.argv:
        print(json.dumps(out, indent=1))
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()
