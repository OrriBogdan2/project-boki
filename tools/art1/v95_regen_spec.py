"""Gil regen 11-20: a candidate swap spec from gil_v95.json, the joints read off v95_grid.py's renders of the candidate.
python3 tools/art1/v95_regen_spec.py NAME MASTER COL_Y HEAD_Y ARM_Y(shoulder,elbow,wrist) OUT
python3 tools/art1/v95_regen_spec.py NAME MASTER --joints JOINTS.json OUT    (r2: the joints measured off the mesh,
    gens/hunter-regen-1120/gil/r2/scripts/joints.py: body column, head, and the arm's own elbow and wrist x/y/z)"""
import json, sys
M = None
if sys.argv[3] == "--joints":
    name, master, M, out = sys.argv[1], sys.argv[2], json.load(open(sys.argv[4])), sys.argv[5]
    col, head_y = M["col"], M["head_y"]
    arm = ",".join(str(round(M[k][1] - col, 3)) for k in ("shoulder", "elbow", "wrist"))
else:
    name, master, col, head_y, arm, out = sys.argv[1], sys.argv[2], float(sys.argv[3]), float(sys.argv[4]), sys.argv[5], sys.argv[6]
s = json.load(open("art/wardens/src/gil_v95.json"))
dy = col - 0.2                     # the old master's body column stood at y 0.2
sy, ey, wy = [float(v) for v in arm.split(",")]
s["doc"] = "Gil regen 11-20 candidate %s (ext/hunter-regen-gil-1120): gil_v95.json with this master's joints; y shifted by %.2f" % (name, dy)
s["master"] = master
s["own"] = {"drop_mats": []}       # (the turnaround has no swordfish: nothing to drop; gil.glb's own swordfish stays)
s["head"] = {"centre": [0.0, head_y, 1.41], "r": 0.22}
J = {"pelvis": [0, col, 0.55], "neck": [0, col + 0.04, 1.27], "crown": [0, head_y, 1.6],
     "shoulder": [0.21, col + sy, 1.19], "elbow": [0.39, col + ey, 1.0], "wrist": [0.48, col + wy, 0.82],
     "hip": [0.12, col, 0.51], "knee": [0.12, col, 0.29], "ankle": [0.12, col - 0.02, 0.11]}
if M:                              # (the arm's measured x and z: an A-pose wider or lower than the template's)
    J["elbow"] = M["elbow"]
    J["wrist"] = M["wrist"]
s["joints"] = {}
for k, v in J.items():
    if k in ("pelvis", "neck", "crown"):
        s["joints"][k] = v
    else:
        s["joints"][k + ".R"] = v
        s["joints"][k + ".L"] = [-v[0], v[1], v[2]]
def shift(b):
    b = list(b)
    for i in (2, 3):
        if abs(b[i]) < 8:
            b[i] = round(b[i] + dy, 3)
    return b
for r in s["regions"]:
    r["box"] = shift(r["box"])
for r in s["slots"]:
    if "box" in r:
        r["box"] = shift(r["box"])
s["anchors"] = {"anchor_head_top": [0.0, head_y - 0.05, 1.68], "anchor_chest": [0.0, col + 0.2, 1.0]}
json.dump(s, open(out, "w"), indent=1)
print("spec", name, out)
