# ruff: noqa: F403, F405
import sys, json

sys.path.insert(0, "tools/art1/rig_test")
from rigkit import *
from mathutils import kdtree

a = sys.argv[sys.argv.index("--") + 1 :]
arm, body, ms = load(a[0])
names, W = get_weights(body)
dom = W.argmax(1)
ist = np.array([names[d] == "tail" or names[d].startswith("spring_scarftail_tail") for d in dom])
arm.animation_data.action = None
arm.data.pose_position = "REST"
bpy.context.view_layer.update()
P0 = evalverts(body)
root = ist & (P0[:, 2] >= np.percentile(P0[ist, 2], 85))
ok = (
    ~ist
    & (np.abs(P0[:, 0]) < 0.3)
    & (P0[:, 2] > 0.6)
    & (P0[:, 2] < 1.5)
    & np.array(
        [
            not names[d].startswith(("upper_arm", "forearm", "hand", "fingers", "thumb", "head", "spring", "tail"))
            for d in dom
        ]
    )
)
kd = kdtree.KDTree(int(ok.sum()))
for k, i in enumerate(np.nonzero(ok)[0]):
    kd.insert(P0[i], k)
kd.balance()
idx = np.nonzero(ok)[0]
D = np.array([np.array(idx[kd.find(tuple(p))[1]] and P0[idx[kd.find(tuple(p))[1]]]) - p for p in P0[root]])
d = np.median(D, axis=0)
print("D", np.round(d, 4), "norm", round(float(np.linalg.norm(d)), 4), "mean", np.round(D.mean(0), 3))
# blender (x,y,z) -> gltf (x,z,-y)
json.dump(
    {
        "d_gltf": [float(d[0]), float(d[2]), float(-d[1])],
        "joints": [n for n in names if n == "tail" or n.startswith("spring_scarftail_tail")],
    },
    open(a[1], "w"),
)
print(
    "rootverts weights by bone",
    {names[j]: int((W[root][:, j] > 0.3).sum()) for j in range(len(names)) if (W[root][:, j] > 0.3).sum()},
)
