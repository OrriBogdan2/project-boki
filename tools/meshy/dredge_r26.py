"""Grimble (dredge) native model, round 26 stage on the r25 glb (plan: gens/hunter-round-1124/grimble/PLAN-1124o.md).

  dredge_r26.py --attack OUT IN   the Attack clip's hands kept apart: Meshy's two-handed slam brought the goo hand to
                                  12-20 cm of the 30-40 cm gauntlet fist, so the goo arm ran through the fist and the
                                  gauntlet forearm through the mouth (geo_check Attack worst 8.4 cm). Each listed arm
                                  turns at its shoulder so its hand sits SHIFT m further out, every key; the neck tilts
                                  back NECK_TILT deg. Measured with tools/anim/geo_check.py (r25d 8.4 cm -> 4.6 cm).

Every stage takes IN.glb and writes OUT.glb (dredge_post.rebuild_stages). numpy/scipy only.
"""

import sys

import dredge_post as d
import native_pack as n
import numpy as np
from scipy.spatial.transform import Rotation as Rot

# (shoulder bone, hand bone, world shift of the hand in m: Meshy's +x is the gauntlet side, +z forward)
SHIFT = (("RightArm", "RightHand", (-0.383, 0.0, 0.115)), ("LeftArm", "LeftHand", (0.12, 0.0, 0.0)))
NECK_TILT = -25.0  # deg about world +x (negative: the head tips back, away from the gauntlet forearm)


def _world(rig, clip, t):
    return rig.pose(clip, t) @ np.linalg.inv(rig.ibm)


def _rot(m):
    return Rot.from_matrix(m[:3, :3] / np.cbrt(np.linalg.det(m[:3, :3])))


def keep_apart(js, b, out, rig):
    """Every Attack rotation key of the two shoulders and the neck turned in world space (parent frame per key)."""
    a = d._clip(js, "Attack")
    names = [nd.get("name") for nd in js["nodes"]]
    todo = []
    jobs = [(bone, hand, np.array(v)) for bone, hand, v in SHIFT] + [("neck", None, None)]
    for bone, hand, v in jobs:
        node = names.index(bone)
        ch, q = d._track(js, b, a, node, "rotation")
        ts = n.floats(js, b, a["samplers"][ch["sampler"]]["input"])[:, 0]
        k0, kp = rig.joints.index(node), rig.joints.index(rig.parent[node])
        new = q.copy()
        for i, t in enumerate(ts):
            w = _world(rig, "Attack", t)
            if hand:
                kh = rig.names.index(hand)
                dv = w[kh][:3, 3] - w[k0][:3, 3]
                tv = dv + v
                dv, tv = dv / np.linalg.norm(dv), tv / np.linalg.norm(tv)
                c = np.cross(dv, tv)
                R = Rot.from_rotvec(c / max(np.linalg.norm(c), 1e-9) * np.arctan2(np.linalg.norm(c), dv @ tv))
            else:
                R = Rot.from_rotvec(np.array([1.0, 0.0, 0.0]) * np.radians(NECK_TILT))
            P = _rot(w[kp])
            new[i] = (P.inv() * R * P * Rot.from_quat(q[i])).as_quat()
        todo.append((ch, new))  # (written after every key is read: rig.pose reads the old buffer)
    for ch, new in todo:
        a["samplers"][ch["sampler"]]["output"] = out.add_floats(new, "VEC4")
    return "Attack keys turned: %s" % ", ".join(j[0] for j in jobs)


STAGES = {"--attack": [("attack apart", keep_apart)]}

if __name__ == "__main__":
    d.rebuild_stages(sys.argv[2], sys.argv[3], STAGES[sys.argv[1]])
