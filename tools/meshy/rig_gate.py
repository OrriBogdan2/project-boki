#!/usr/bin/env python3
"""Rig gate: the RIGGING of a hunter glb as its own PASS/FAIL, separate from the model (owner 11-21).

  python3 tools/meshy/rig_gate.py art/wardens/*/*.glb --out build/rig_gate --json build/rig_gate/r.json
  python3 tools/meshy/rig_gate.py cand.glb --clips-from art/wardens/breaker/breaker.glb   # a fresh rig: the game's clips by bone name

Poses the glb through its own clips (or the donor's, by bone name) for the game states: walk, run, downed,
death, glide, attack (the primary attack clip: lmb*, else the kit's strike-like clip). A glb with no clips of
its own (gil: HunterAnim drives it) borrows --clips-from (default art/wardens/breaker/breaker.glb).
Reuses the CPU skinning of hunter_mesh_check.py and measures, per region, PASS / WARN / FAIL with numbers:

  legs      "see-inside" pixels: the model is splatted into a z-buffer from 4 sides at every sampled pose; a pixel
            whose nearest surface is a leg triangle seen from behind (a hole in the thighs / crotch: the black gap
            in the real renderer) counts. Also the crotch bridge (triangles joining a left-leg vertex to a right-leg
            vertex): their worst stretch in motion.
  hands     hand-bound vertices (hand, finger, thumb bones): the largest move against the wrist, in hand lengths,
            and stretched hand triangles (edge > STRETCH x its bind length).
  arms      arm-torso fusion: triangles that join an arm vertex to a torso vertex below the armpit (skin webbing
            the arm to the body) at rest, and their worst stretch in motion; plus arm vertices weighted to the torso.
  spikes    needle triangles at rest (hunter_mesh_check logic), vertices bound to a far bone, and the worst-pose
            stretched triangles by region (arms / legs / hands / torso / head).

Exit code: 0 = no FAIL, 1 = a FAIL, 2 = read error. The thresholds below were set on the 13 live hunters (RIG_GATE.md).
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
import hunter_mesh_check as H  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent.parent
DONOR = ROOT / "art/wardens/breaker/breaker.glb"
GRAZE = 0.35  # a back face counts only if its normal is this far from edge-on to the camera
FRAMES = 8  # poses per clip
RES = 260  # z-buffer pixels over the body height
VIEWS = {"front": (0, 2), "back": (0, 2), "left": (2, 0), "right": (2, 0)}  # name: (screen-u axis, depth axis)
STATES = {  # state: clip name regex (all matching clips are posed)
    "walk": r"^walk_(f|fl|fr|l|r)$",
    "run": r"^run_(f|fl|fr|l|r)$",
    "downed": r"^downed$",
    "death": r"^death$",
    "glide": r"^glide$",
    "attack": r"^(lmb(_\w+)?|attack\w*|strike\w*|knife|slam|lunge|beam)$",
}
GROUPS = [  # region of a bone: first match wins
    ("hand", r"^(hand|fing|x_fing|thumb|x_thumb|index|x_index|palm)"),
    ("arm", r"^(upper_arm|forearm)"),
    ("leg", r"^(thigh|shin|foot|x_foot)"),
    ("head", r"^(head|jaw|eye|lid|brow|x_brow|x_cheek|x_jaw|neck)"),
    ("cloth", r"^(skirt|cape|scarf|tail|wings|spring_)"),
    ("torso", r"^(hips|root|pauldron)"),
]
# (WARN, FAIL) per metric
LIMITS = {
    "see_inside_pct": (0.3, 1.5),  # % of leg-ROI covered pixels whose nearest surface is a leg back face
    "bridge_stretch": (2.0, 3.5),  # worst edge ratio of an L-leg to R-leg triangle
    "hand_move_len": (0.45, 0.9),  # hand vertex move vs the wrist, in hand lengths
    "hand_stretched": (3, 40),  # stretched hand triangles in the worst pose
    "fused_tris": (20, 120),  # arm-to-torso triangles below the armpit at rest
    "fused_stretch": (2.0, 3.5),  # worst edge ratio of those triangles in motion
    "arm_torso_weight": (0.004, 0.02),  # share of arm vertices with torso weight > 0.3 below the armpit
    "spike_edges": (3, 40),
    "far_bone_verts": (0.0005, 0.02),  # share of vertices
    "stretched_tris": (4, 80),  # worst-pose stretched triangles, whole body
}


class Hunter:
    def __init__(self, path: Path, donor: Path | None):
        self.path = path
        g = H.Glb(path.read_bytes())
        self.g = g
        self.body = H.Body(g)
        self.skin = g.j["skins"][self.body.skin]
        self.jnodes = self.skin["joints"]
        self.ibm = g.acc(self.skin["inverseBindMatrices"]).reshape(-1, 4, 4).transpose(0, 2, 1)
        self.rig = H.Rig(g)
        self.names = [g.j["nodes"][n]["name"].replace("_L", ".L").replace("_R", ".R") for n in self.jnodes]
        self.heads = np.stack([np.linalg.inv(self.ibm[k])[:3, 3] for k in range(len(self.jnodes))])
        self.height = float(self.body.pos[:, 1].max() - self.body.pos[:, 1].min())
        self.clips_from = None
        if not self.rig.clips:
            self.borrow(donor or DONOR)
        self.regions()

    def borrow(self, donor: Path):
        """Use the donor's clips by bone name: rotations as they are, hips and root travel as a delta."""
        dg = H.Glb(donor.read_bytes())
        dr = H.Rig(dg)
        mine = {nd.get("name", "").replace("_L", ".L").replace("_R", ".R"): i for i, nd in enumerate(self.g.j["nodes"])}
        dnames = [nd.get("name", "").replace("_L", ".L").replace("_R", ".R") for nd in dg.j["nodes"]]
        clips = []
        for name, dur, chans in dr.clips:
            out = []
            for node, path, times, vals, interp in chans:
                tgt = mine.get(dnames[node])
                if tgt is None or interp == "CUBICSPLINE":
                    continue
                if path == "translation":
                    if dnames[node] not in ("hips", "root"):
                        continue
                    vals = vals - dr.rest[node][0] + self.rig.rest[tgt][0]
                out.append((tgt, path, times, vals, interp))
            clips.append((name, dur, out))
        self.rig.clips = clips
        self.clips_from = donor.name

    def regions(self):
        kind = []
        for n in self.names:
            kind.append(next((r for r, rx in GROUPS if re.search(rx, n)), "other"))
        self.bone_kind = np.array(kind)
        self.bone_side = np.array([("L" if n.endswith(".L") else "R" if n.endswith(".R") else "") for n in self.names])
        b = self.body
        dom = b.joints[np.arange(len(b.pos)), b.weights.argmax(axis=1)]
        self.vkind = self.bone_kind[dom]
        self.vside = self.bone_side[dom]
        self.vdom = dom

    def bone(self, name: str):
        return self.heads[self.names.index(name)] if name in self.names else None

    def clips_for(self, state: str):
        rx = re.compile(STATES[state])
        return [i for i, c in enumerate(self.rig.clips) if rx.match(c[0])]

    def poses(self, state: str):
        for ci in self.clips_for(state):
            dur = self.rig.clips[ci][1]
            for f in range(FRAMES):
                yield ci, self.rig.world(ci, dur * f / (FRAMES - 1))

    def skinned(self, world):
        return H.skin_positions(self.body, self.ibm, self.jnodes, world)

    def joint_world(self, world, name):
        return world[self.jnodes[self.names.index(name)]][:3, 3] if name in self.names else None


def splat(pos, tris, view, pix, ymin):
    """Z-buffer from one side: (triangle id, seen from behind, 3D point) of the nearest surface in each pixel."""
    ua, da = VIEWS[view]
    face = view in ("front", "left")  # the camera sits on the -depth side (the hunter faces -Z)
    w = int(4 * RES)
    p = pos[tris]
    n = np.cross(p[:, 1] - p[:, 0], p[:, 2] - p[:, 0])
    n /= np.maximum(np.linalg.norm(n, axis=1, keepdims=True), 1e-12)
    away = n[:, da] if face else -n[:, da]
    back = away > GRAZE  # a normal clearly pointing away from the camera (not a silhouette edge)
    sx = (p[:, :, ua] if face else -p[:, :, ua]) / pix + w / 2
    sy = (p[:, :, 1] - ymin) / pix
    dz = p[:, :, da] if face else -p[:, :, da]
    x0, x1 = np.floor(sx.min(1)).astype(int), np.floor(sx.max(1)).astype(int)
    y0, y1 = np.floor(sy.min(1)).astype(int), np.floor(sy.max(1)).astype(int)
    den = (sy[:, 1] - sy[:, 2]) * (sx[:, 0] - sx[:, 2]) + (sx[:, 2] - sx[:, 1]) * (sy[:, 0] - sy[:, 2])
    keys, depths, tids = [], [], []
    k = int(max((x1 - x0).max(), (y1 - y0).max()) + 1) if len(tris) else 0
    k = min(k, 8)  # a triangle wider than 8 px is stamped on its first 8x8 (a stretched sliver is rare and wide)
    for dx in range(k):
        for dy in range(k):
            px, py = x0 + dx + 0.5, y0 + dy + 0.5
            ok = (x0 + dx <= x1) & (y0 + dy <= y1) & (np.abs(den) > 1e-12)
            t = np.nonzero(ok)[0]
            if not len(t):
                continue
            d = den[t]
            l0 = ((sy[t, 1] - sy[t, 2]) * (px[t] - sx[t, 2]) + (sx[t, 2] - sx[t, 1]) * (py[t] - sy[t, 2])) / d
            l1 = ((sy[t, 2] - sy[t, 0]) * (px[t] - sx[t, 2]) + (sx[t, 0] - sx[t, 2]) * (py[t] - sy[t, 2])) / d
            l2 = 1.0 - l0 - l1
            ins = (l0 >= -0.05) & (l1 >= -0.05) & (l2 >= -0.05)  # a little slack: no cracks between neighbours
            t, l0, l1, l2 = t[ins], l0[ins], l1[ins], l2[ins]
            gx, gy = (x0 + dx)[t], (y0 + dy)[t]
            good = (gx >= 0) & (gx < w) & (gy >= 0) & (gy <= RES + 2)
            keys.append((gy * w + gx)[good])
            depths.append((l0 * dz[t, 0] + l1 * dz[t, 1] + l2 * dz[t, 2])[good])
            tids.append(t[good])
    key, depth, tid = np.concatenate(keys), np.concatenate(depths), np.concatenate(tids)
    order = np.lexsort((depth, key))
    ks = key[order]
    first = np.concatenate([[True], ks[1:] != ks[:-1]])
    sel = order[first]
    t = tid[sel]
    px = (key[sel] % w - w / 2 + 0.5) * pix
    hit = np.zeros((len(sel), 3))
    hit[:, ua] = px if face else -px
    hit[:, 1] = (key[sel] // w + 0.5) * pix + ymin
    hit[:, da] = depth[sel] if face else -depth[sel]
    return t, back[t], hit


def see_inside(h: Hunter, world, pos, tkind, roi_names):
    """Covered pixels in the leg ROI, and those whose nearest surface is a leg triangle seen from behind."""
    pts = np.array([q for q in (h.joint_world(world, n) for n in roi_names) if q is not None])
    pad = 0.06 * h.height
    lo, hi = pts.min(0) - pad, pts.max(0) + pad
    covered = inside = 0
    for view in VIEWS:
        tid, back, hit = splat(pos, h.body.tris, view, h.height / RES, float(pos[:, 1].min()))
        m = ((hit >= lo) & (hit <= hi)).all(axis=1)
        covered += int(m.sum())
        inside += int((m & back & (tkind[tid] == "leg")).sum())
    return covered, inside


def tri_kinds(h: Hunter):
    """Region of each triangle: the kind most of its vertices belong to."""
    k = h.vkind[h.body.tris]
    out = k[:, 0].copy()
    same = (k[:, 1] == k[:, 2]) & (k[:, 1] != k[:, 0])
    out[same] = k[same, 1]
    return out


def measure(h: Hunter) -> dict:
    b, hh = h.body, h.height
    tk = tri_kinds(h)
    res: dict = {"tris": len(b.tris), "bones": len(h.names), "clips_from": h.clips_from, "height": round(hh, 3)}
    res["finger_bones"] = int(sum(1 for n, k in zip(h.names, h.bone_kind) if k == "hand" and not n.startswith("hand")))
    tris = b.tris
    bind_len = H.edge_lengths(b.pos, tris)
    big = bind_len > H.VISIBLE_H * hh
    # ---- rest: spikes and far bones (hunter_mesh_check logic)
    r, flags = H.bind_checks(b, hh)
    spike = flags["spike_edges"]
    res["spike_edges"] = int(spike.sum())
    res["spike_by_region"] = {k: int((spike & (tk == k)).sum()) for k in ("arm", "leg", "hand", "torso", "head", "cloth") if (spike & (tk == k)).any()}
    r, _ = H.weight_checks(b, h.ibm, h.jnodes, h.rig, hh)
    res["far_bone_verts"] = r["far_bone_verts"] / len(b.pos)
    res["far_bone_max_h"] = r["far_bone_max_h"]
    # ---- fixed index sets
    vk = h.vkind
    sh = {s: h.bone(f"upper_arm.{s}") for s in "LR"}
    el = {s: h.bone(f"forearm.{s}") for s in "LR"}
    wr = {s: h.bone(f"hand.{s}") for s in "LR"}
    # arm-torso: a triangle with an arm vertex and a torso vertex, below the armpit (a quarter down the upper arm)
    armpit = min(sh[s][1] - 0.25 * (sh[s][1] - el[s][1]) for s in "LR" if sh[s] is not None)
    tvk = vk[tris]
    low = (b.pos[tris][:, :, 1] < armpit).all(axis=1)
    fused = low & (tvk == "arm").any(axis=1) & (tvk == "torso").any(axis=1)
    res["fused_tris"] = int(fused.sum())
    arm_v = (vk == "arm") & (b.pos[:, 1] < armpit)
    torso_w = np.zeros(len(b.pos))
    for slot in range(4):
        torso_w += np.where(h.bone_kind[b.joints[:, slot]] == "torso", b.weights[:, slot], 0.0)
    res["arm_torso_weight"] = float((arm_v & (torso_w > 0.3)).sum() / max(arm_v.sum(), 1))
    # crotch bridge: leg triangles with an L vertex and an R vertex
    vs = h.vside[tris]
    bridge = (tk == "leg") & (vs == "L").any(axis=1) & (vs == "R").any(axis=1)
    bridge |= (vk[tris] == "leg").any(axis=1) & (vs == "L").any(axis=1) & (vs == "R").any(axis=1)
    res["bridge_tris"] = int(bridge.sum())
    # hand set: the wrist frame of each hand
    hand_v = np.nonzero(vk == "hand")[0]
    hand_side = h.vside[hand_v]
    hand_len = 0.0
    for s in "LR":
        pv = b.pos[hand_v[hand_side == s]]
        if len(pv):
            hand_len = max(hand_len, float(np.linalg.norm(pv - wr[s], axis=1).max()))
    hand_len = max(hand_len, 0.04 * hh)
    res["hand_len_m"] = round(hand_len, 3)
    hand_t = (tk == "hand")
    # ---- posed
    worst = {"stretched": (-1, None)}
    per_state: dict = {}
    zb = {"cov": 0, "ins": 0}
    roi = ["thigh.L", "thigh.R", "shin.L", "shin.R"]
    max_bridge = max_fused = max_hand = 1.0
    max_hand_move = 0.0
    n_hand_st = 0
    worst_hand = None
    reg_st: dict = {}
    for state in STATES:
        s_see = s_cov = 0
        s_stretch = 0
        for fi, (ci, world) in enumerate(h.poses(state)):
            sp = h.skinned(world)
            ln = H.edge_lengths(sp, tris)
            ratio = np.where(bind_len > 1e-4 * hh, ln / np.maximum(bind_len, 1e-12), 1.0)
            ratio = np.nan_to_num(ratio, nan=1e3, posinf=1e3)
            st = ((ratio > H.STRETCH_MAX) & (ln > H.VISIBLE_H * hh)).any(axis=1)
            tr = np.where(ln > H.VISIBLE_H * hh, ratio, 1.0).max(axis=1)  # only edges long enough to see
            if bridge.any():
                max_bridge = max(max_bridge, float(tr[bridge].max()))
            if fused.any():
                max_fused = max(max_fused, float(tr[fused].max()))
            n_hand_st = max(n_hand_st, int((st & hand_t).sum()))
            sc = int(st.sum())
            s_stretch = max(s_stretch, sc)
            if sc > worst["stretched"][0]:
                worst["stretched"] = (sc, (state, h.rig.clips[ci][0], fi))
                reg_st = {k: int((st & (tk == k)).sum()) for k in ("arm", "leg", "hand", "torso", "head", "cloth")}
            # hand vs wrist: bind point in the wrist frame vs posed point in the posed wrist frame
            for s in "LR":
                sel = hand_v[hand_side == s]
                if not len(sel):
                    continue
                wj = world[h.jnodes[h.names.index(f"hand.{s}")]] @ h.ibm[h.names.index(f"hand.{s}")]
                loc = (np.linalg.inv(wj) @ np.c_[sp[sel], np.ones(len(sel))].T).T[:, :3]
                mv = float(np.linalg.norm(loc - b.pos[sel], axis=1).max()) / hand_len
                if mv > max_hand_move:
                    max_hand_move, worst_hand = mv, (state, h.rig.clips[ci][0], fi)
            if fi % 2 == 0:  # the z-buffer is the costly part: every other pose
                cov, ins = see_inside(h, world, sp, tk, roi)
                s_cov += cov
                s_see += ins
        zb["cov"] += s_cov
        zb["ins"] += s_see
        per_state[state] = {
            "clips": [h.rig.clips[c][0] for c in h.clips_for(state)],
            "see_inside_pct": round(100.0 * s_see / max(s_cov, 1), 3),
            "stretched_tris": s_stretch,
        }
    res["states"] = per_state
    res["see_inside_pct"] = round(100.0 * zb["ins"] / max(zb["cov"], 1), 3)
    res["bridge_stretch"] = round(max_bridge, 2)
    res["fused_stretch"] = round(max_fused, 2)
    res["hand_move_len"] = round(max_hand_move, 2)
    res["hand_move_at"] = worst_hand
    res["hand_stretched"] = n_hand_st
    res["stretched_tris"] = max(worst["stretched"][0], 0)
    res["stretched_at"] = worst["stretched"][1]
    res["stretched_by_region"] = reg_st
    return res


def level(key: str, v: float) -> str:
    warn, fail = LIMITS[key]
    return "FAIL" if v >= fail else "WARN" if v >= warn else "PASS"


def grade(res: dict) -> dict:
    worse = lambda *ls: "FAIL" if "FAIL" in ls else "WARN" if "WARN" in ls else "PASS"  # noqa: E731
    reg = {
        "legs": worse(level("see_inside_pct", res["see_inside_pct"]), level("bridge_stretch", res["bridge_stretch"])),
        "hands": worse(level("hand_move_len", res["hand_move_len"]), level("hand_stretched", res["hand_stretched"])),
        "arms": worse(
            level("fused_tris", res["fused_tris"]),
            level("fused_stretch", res["fused_stretch"]) if res["fused_tris"] >= LIMITS["fused_tris"][0] else "PASS",
            level("arm_torso_weight", res["arm_torso_weight"]),
        ),
        "spikes": worse(
            level("spike_edges", res["spike_edges"]),
            level("far_bone_verts", res["far_bone_verts"]),
            level("stretched_tris", res["stretched_tris"]),
        ),
    }
    reg["overall"] = worse(*reg.values())
    return reg


def table(rows: list[dict]) -> str:
    out = [
        "| hunter | legs | hands | arms | spikes | see-inside % | bridge x | hand move (len) / stretched | fused tris / x / wt | spikes / stretched tris |",
        "|---|---|---|---|---|---|---|---|---|---|",
    ]
    for r in rows:
        g = r["grade"]
        out.append(
            f"| {r['name']} | {g['legs']} | {g['hands']} | {g['arms']} | {g['spikes']} | {r['see_inside_pct']} | "
            f"{r['bridge_stretch']} | {r['hand_move_len']} / {r['hand_stretched']} | "
            f"{r['fused_tris']} / {r['fused_stretch']} / {r['arm_torso_weight']:.3f} | {r['spike_edges']} / {r['stretched_tris']} |"
        )
    return "\n".join(out)


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("glbs", nargs="+")
    ap.add_argument("--clips-from", help="donor glb whose clips pose a glb that has none of its own")
    ap.add_argument("--json")
    ap.add_argument("--out", help="folder for the markdown table")
    a = ap.parse_args(argv)
    rows = []
    for p in a.glbs:
        path = Path(p)
        try:
            h = Hunter(path, Path(a.clips_from) if a.clips_from else None)
            r = measure(h)
        except Exception as e:  # noqa: BLE001
            print(f"{path}: cannot read: {e}", file=sys.stderr)
            return 2
        r["name"] = path.stem
        r["grade"] = grade(r)
        rows.append(r)
        print(f"{r['name']:10s} {r['grade']['overall']:4s} legs={r['grade']['legs']} hands={r['grade']['hands']} "
              f"arms={r['grade']['arms']} spikes={r['grade']['spikes']}", flush=True)
    md = table(rows)
    print(md)
    if a.out:
        Path(a.out).mkdir(parents=True, exist_ok=True)
        (Path(a.out) / "table.md").write_text(md + "\n")
    if a.json:
        Path(a.json).parent.mkdir(parents=True, exist_ok=True)
        Path(a.json).write_text(json.dumps(rows, indent=1, default=str))
    return 1 if any(r["grade"]["overall"] == "FAIL" for r in rows) else 0


if __name__ == "__main__":
    sys.exit(main())
