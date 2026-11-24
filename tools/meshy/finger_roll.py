"""Finger bone roll of a Meshy auto-rig (include_fingers), made the same on every finger joint: a turn about a joint's
local +z closes that finger toward the palm. No Blender: edits the nodes' rest rotations, their children's rest
transforms and the skins' inverse bind matrices in place; the mesh and every joint position stay where they were.

Why: Meshy rolls each finger joint as it likes. Lace's roll changes between the joints of one finger (index 1 and 2
turn toward the palm about z, index 3 sideways), so a fist about local z swings her fingertips sideways and the skin
crumples into shards; on Kael's and Lace's right hands +z closes the fingers toward the back of the hand.
- Fingers: z = bone direction x palm side; the palm side is the knuckle-plane normal signed toward the thumb.
- Thumbs: they close across the palm, toward a point THUMB_AIM in front of the knuckles.
Called by finger_weights.clean before the weights are blended."""

import re

import numpy as np

FINGER = re.compile(r"^(?:mixamorig:)?(Left|Right)Hand(Thumb|Index|Middle|Ring|Pinky)([123])$")
THUMB_AIM = 0.3  # x the wrist-to-knuckle length: how far in front of the knuckles the thumb aims


def quat_mat(q):
    x, y, z, w = q
    return np.array(
        [
            [1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
            [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
            [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)],
        ]
    )


def mat_quat(m):
    """Unit quaternion [x, y, z, w] of a rotation matrix."""
    t = np.trace(m)
    if t > 0:
        s = 2 * np.sqrt(t + 1)
        q = [(m[2, 1] - m[1, 2]) / s, (m[0, 2] - m[2, 0]) / s, (m[1, 0] - m[0, 1]) / s, s / 4]
    else:
        i = int(np.argmax(np.diag(m)))
        a, b = (i + 1) % 3, (i + 2) % 3
        s = 2 * np.sqrt(1 + m[i, i] - m[a, a] - m[b, b])
        q = [0.0, 0.0, 0.0, (m[b, a] - m[a, b]) / s]
        q[i], q[a], q[b] = s / 4, (m[a, i] + m[i, a]) / s, (m[b, i] + m[i, b]) / s
    q = np.array(q)
    return q / np.linalg.norm(q)


def local(nd):
    m = np.eye(4)
    m[:3, :3] = quat_mat(nd.get("rotation", [0, 0, 0, 1]))
    m[:3, 3] = nd.get("translation", [0, 0, 0])
    return m


def worlds(nodes, par):
    out = {}

    def get(i):
        if i not in out:
            out[i] = get(par[i]) @ local(nodes[i]) if i in par else local(nodes[i])
        return out[i]

    for i in range(len(nodes)):
        get(i)
    return out


def unit(v):
    return v / max(np.linalg.norm(v), 1e-12)


def knuckles(pos, side):
    """Rest positions of the hand's finger joints 1, index first (pos: joint name -> rest position)."""
    return [pos[side + "Hand" + f + "1"] for f in ("Index", "Middle", "Ring", "Pinky") if side + "Hand" + f + "1" in pos]


def palm_normal(pos, side):
    """The hand's knuckle-plane normal (either side of the palm), or None without two fingers."""
    base = knuckles(pos, side)
    if len(base) < 2 or side + "Hand" not in pos:
        return None
    n = np.cross(np.mean(base, axis=0) - pos[side + "Hand"], base[0] - base[-1])
    return unit(n) if np.linalg.norm(n) > 1e-9 else None


def closing_sign(pos, side, pn, votes):
    """+1 when the palm is on pn's side. The thumb lies on the palm's side of the knuckles (Kael, Lace, Grimble: 22 to
    79 mm off them), so its last joint decides; without a thumb, the vote of the joints' own turns (a weak fallback:
    Meshy's roll is wrong on half of Kael's and Lace's hands)."""
    thumb = [pos[side + "HandThumb" + k] for k in "4321" if side + "HandThumb" + k in pos]
    base = knuckles(pos, side)
    off = float((thumb[0] - np.mean(base, axis=0)) @ pn) if thumb else 0.0
    if abs(off) > 0.005:
        return 1 if off > 0 else -1
    return 1 if sum(votes) >= 0 else -1


def orient(j, accessor):
    """Rolls every finger joint 1..3 so a turn about local +z closes it toward the palm. accessor(idx) gives an
    accessor's writable [count, n] view (finger_weights.accessor bound to the glb). Returns {side: joints rolled}; a rig
    with matrix or scaled nodes is left as it is (returns {})."""
    nodes = j["nodes"]
    if any("matrix" in nd or np.abs(np.array(nd.get("scale", [1, 1, 1])) - 1).max() > 1e-3 for nd in nodes):
        return {}  # (a Blender export's 0.9999998 scales count as 1)
    par = {c: i for i, nd in enumerate(nodes) for c in nd.get("children", [])}
    W = worlds(nodes, par)
    by = {nd.get("name", "").removeprefix("mixamorig:"): i for i, nd in enumerate(nodes)}
    pos = {nm: W[i][:3, 3] for nm, i in by.items()}
    new, report = {}, {}
    for side in ("Left", "Right"):
        pn = palm_normal(pos, side)
        if pn is None:
            continue
        chain = []
        for nm, i in by.items():
            m = FINGER.match(nm)
            if m and m[1] == side:
                tip = by.get(nm[:-1] + str(int(m[3]) + 1))
                kids = nodes[i].get("children", [])
                to = W[tip][:3, 3] if tip is not None else (W[kids[0]][:3, 3] if kids else None)
                if to is not None and np.linalg.norm(to - W[i][:3, 3]) > 1e-6:
                    chain.append((i, unit(to - W[i][:3, 3])))
        if not chain:
            continue
        votes = [float(np.cross(W[i][:3, 2], d) @ pn) for i, d in chain]
        close = pn * closing_sign(pos, side, pn, votes)
        base = np.mean(knuckles(pos, side), axis=0)
        palm = base + close * THUMB_AIM * np.linalg.norm(base - pos[side + "Hand"])
        for i, d in chain:
            y = unit(W[i][:3, 1])
            z = np.cross(d, unit(palm - W[i][:3, 3]) if "Thumb" in nodes[i]["name"] else close)
            z = z - (z @ y) * y
            if np.linalg.norm(z) < 0.2:  # the bone points at its target: no roll to give it
                continue
            z = unit(z)
            m = W[i].copy()
            m[:3, :3] = np.stack([np.cross(y, z), y, z], axis=1)
            new[i] = m
        report[side] = len(new) - sum(report.values())
    if not new:
        return report
    W2 = dict(W)
    W2.update(new)
    for i, nd in enumerate(nodes):
        if i in new or par.get(i) in new:
            loc = (np.linalg.inv(W2[par[i]]) @ W2[i]) if i in par else W2[i]
            nd["rotation"] = [float(v) for v in mat_quat(loc[:3, :3])]
            nd["translation"] = [float(v) for v in loc[:3, 3]]
            nd.pop("scale", None)
    for skin in j.get("skins", []):
        ibm = accessor(skin["inverseBindMatrices"]).reshape(-1, 4, 4)  # column-major: ibm[k].T is the matrix
        for k, ni in enumerate(skin["joints"]):
            if ni in new:
                ibm[k] = (np.linalg.inv(W2[ni]) @ W[ni] @ ibm[k].T.astype(np.float64)).T.astype(ibm.dtype)
    return report
