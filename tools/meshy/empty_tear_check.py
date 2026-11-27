"""Does the Empty's cloak tear when the rig moves? Poses each Empty .glb's skin in a run and a jump (the arms and
legs swung about their bone heads) and counts the cloth/trim vertex pairs that sat within PAIR_M of each other at
rest and end up further apart than TEAR_M. Exits 1 if a pose is over its ceiling.

    python3 tools/meshy/empty_tear_check.py [art/wardens/empty_f/empty_f.glb ...]

The fitted Meshy models tore 40-55k pairs this way (the cloak was bound to the arms and had ~18k open edges); the
knitted weights (empty_reweight.py) leave under 3k.
"""

import json
import struct
import sys

import numpy as np
from scipy.spatial import cKDTree

PAIR_M = 0.012  # m: neighbours at rest
TEAR_M = 0.05  # m: further apart than this in a pose is a tear
CEILINGS = {"run_a": 800, "run_b": 800, "jump": 3000}  # pairs torn per pose
CLOAK = ("cloth", "trim")
PARENT = {
    "forearm.L": "upper_arm.L",
    "forearm.R": "upper_arm.R",
    "hand.L": "forearm.L",
    "hand.R": "forearm.R",
    "shin.L": "thigh.L",
    "shin.R": "thigh.R",
}
# bone -> degrees about X, from the rest pose
POSES = {
    "run_a": {"thigh.L": 40, "thigh.R": -40, "shin.L": -35, "upper_arm.L": -45, "upper_arm.R": 45, "forearm.L": -40, "forearm.R": -40},
    "run_b": {"thigh.L": -40, "thigh.R": 40, "shin.R": -35, "upper_arm.L": 45, "upper_arm.R": -45, "forearm.L": -40, "forearm.R": -40},
    "jump": {"thigh.L": 50, "thigh.R": 20, "shin.L": -60, "shin.R": -30, "upper_arm.L": -70, "upper_arm.R": -70, "forearm.L": -30, "forearm.R": -30},
}  # fmt: skip
COMPONENTS = {5121: np.uint8, 5123: np.uint16, 5125: np.uint32, 5126: np.float32}
WIDTH = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}


def load(path):
    data = open(path, "rb").read()
    json_len = struct.unpack("<I", data[12:16])[0]
    return json.loads(data[20 : 20 + json_len]), data[20 + json_len + 8 :]


def read(doc, blob, index):
    acc = doc["accessors"][index]
    view = doc["bufferViews"][acc["bufferView"]]
    width = WIDTH[acc["type"]]
    start = view.get("byteOffset", 0) + acc.get("byteOffset", 0)
    out = np.frombuffer(blob, COMPONENTS[acc["componentType"]], acc["count"] * width, start)
    return out.reshape(acc["count"], width)


def swing(head, degrees):
    a = np.radians(degrees)
    rot = np.eye(4)
    rot[1:3, 1:3] = [[np.cos(a), -np.sin(a)], [np.sin(a), np.cos(a)]]
    to_head = np.eye(4)
    to_head[:3, 3] = head
    from_head = np.eye(4)
    from_head[:3, 3] = -head
    return to_head @ rot @ from_head


def torn_pairs(path):
    doc, blob = load(path)
    skin = doc["skins"][0]
    names = [doc["nodes"][j]["name"] for j in skin["joints"]]
    inverse_bind = read(doc, blob, skin["inverseBindMatrices"]).reshape(-1, 4, 4)
    heads = {n: np.linalg.inv(inverse_bind[i].T)[:3, 3] for i, n in enumerate(names)}
    pos, joints, weights, slots = [], [], [], []
    for prim in doc["meshes"][0]["primitives"]:
        at = prim["attributes"]
        pos.append(read(doc, blob, at["POSITION"]))
        joints.append(read(doc, blob, at["JOINTS_0"]).astype(int))
        weights.append(read(doc, blob, at["WEIGHTS_0"]))
        slots += [doc["materials"][prim["material"]]["name"].split("-")[0]] * len(pos[-1])
    pos, joints, weights = np.concatenate(pos).astype(float), np.concatenate(joints), np.concatenate(weights)
    cloak = np.flatnonzero(np.isin(slots, CLOAK))
    pairs = np.array(list(cKDTree(pos[cloak]).query_pairs(PAIR_M)))
    a, b = cloak[pairs[:, 0]], cloak[pairs[:, 1]]
    rest = np.linalg.norm(pos[a] - pos[b], axis=1)
    homog = np.concatenate([pos, np.ones((len(pos), 1))], axis=1)
    out = {}
    for pose, degrees in POSES.items():
        moved = {}
        for n in names:
            parent = moved.get(PARENT.get(n), np.eye(4))
            moved[n] = parent @ swing(heads[n], degrees.get(n, 0))
        mats = np.array([moved[n] for n in names])
        posed = sum(weights[:, k : k + 1] * np.einsum("nij,nj->ni", mats[joints[:, k]], homog)[:, :3] for k in range(4))
        out[pose] = int((np.linalg.norm(posed[a] - posed[b], axis=1) - rest > TEAR_M).sum())
    return out


def main():
    paths = sys.argv[1:] or ["art/wardens/empty_f/empty_f.glb", "art/wardens/empty_m/empty_m.glb"]
    bad = 0
    for path in paths:
        for pose, n in torn_pairs(path).items():
            over = n > CEILINGS[pose]
            bad += over
            print(
                "EMPTY_TEAR %s %s %s: %d pairs torn (ceiling %d)"
                % ("FAIL" if over else "ok  ", path, pose, n, CEILINGS[pose])
            )
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()
