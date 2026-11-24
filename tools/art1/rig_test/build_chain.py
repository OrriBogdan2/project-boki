# ruff: noqa: F403, F405
# Blender: build_chain.py -- in.glb out.glb [share=0.7] [follow=0.5]: skirt chain bones (hip-pivot half-follow of the thighs) + hanging-vertex weights, clips baked
import sys

sys.path.insert(0, "tools/art1/rig_test")
from rigkit import *

a = sys.argv[sys.argv.index("--") + 1 :]
src, out = a[:2]
share = float(a[2]) if len(a) > 2 else 0.7
follow = float(a[3]) if len(a) > 3 else 0.5
arm, body, ms = load(src)
names, W0 = get_weights(body)
me = body.data
n = len(me.vertices)
P = np.empty(n * 3)
me.vertices.foreach_get("co", P)
P = P.reshape(-1, 3)
B = arm.data.bones


def head(nm):
    return np.array(B[nm].head_local)


def tail(nm):
    return np.array(B[nm].tail_local)


hz = head("thigh.L")[2]


# leg radius: median distance of thigh/shin-dominated verts to their bone segment
def segd(Pp, h, t):
    u = t - h
    s = np.clip(((Pp - h) @ u) / (u @ u), 0, 1)
    return np.linalg.norm(Pp - (h + s[:, None] * u), axis=1)


dom = W0.argmax(1)
nmd = [names[d] for d in dom]
legs = [b for b in ("thigh.L", "thigh.R", "shin.L", "shin.R") if b in B]
dleg = np.min([segd(P, head(b), tail(b)) for b in legs], axis=0)
isleg = np.array([x.split(".")[0] in ("thigh", "shin", "x_foot", "foot") for x in nmd])
R = float(np.median(dleg[isleg]))
print("LEG R", round(R, 3))
ARMISH = (
    "upper_arm",
    "forearm",
    "hand",
    "pauldron",
    "head",
    "spring",
    "lip",
    "jaw",
    "x_fing",
    "x_thumb",
    "x_shield",
    "x_weapon",
    "fingers",
    "thumb",
    "lid",
    "brow",
    "tail",
    "jet",
    "x_fish",
)
armish = np.array([x.startswith(ARMISH) for x in nmd])
sm = lambda x: (lambda y: y * y * (3 - 2 * y))(np.clip(x, 0, 1))
hang = sm((dleg - 1.0 * R) / (0.8 * R)) * sm((hz + 0.05 - P[:, 2]) / 0.10) * (~armish)
print("hanging verts", int((hang > 0.5).sum()))
# bones
bpy.context.view_layer.objects.active = arm
bpy.ops.object.mode_set(mode="EDIT")
eb = arm.data.edit_bones
hipb = eb["hips"]
ph = np.array(eb["hips"].head)


def add(nm, hd, tl):
    b = eb.new(nm)
    b.head = hd
    b.tail = tl
    b.parent = hipb
    b.use_connect = False
    b.use_deform = True
    return b


dz = np.array([0, 0, -0.12])
add("skchain_L", head("thigh.L"), head("thigh.L") + dz)
add("skchain_R", head("thigh.R"), head("thigh.R") + dz)
add("skchain_F", ph + np.array([0, 0.05, 0]), ph + np.array([0, 0.05, -0.12]))
add("skchain_B", ph + np.array([0, -0.05, 0]), ph + np.array([0, -0.05, -0.12]))
bpy.ops.object.mode_set(mode="OBJECT")
# weights
hipj = names.index("hips")
cn = ["skchain_L", "skchain_R", "skchain_F", "skchain_B"]
Wn = np.zeros((n, len(names) + 4))
Wn[:, : len(names)] = W0
xs = P[:, 0]
ys = P[:, 1]
side = np.abs(xs) > 0.6 * np.abs(ys)
pick = np.where(side, np.where(xs < 0, 0, 1), np.where(ys > 0, 2, 3))  # L is -x (thigh.L at -x)
C = np.zeros((n, len(names) + 4))
C[:, hipj] = 1 - share
C[np.arange(n), len(names) + pick] = share
Wf = (1 - hang[:, None]) * Wn + hang[:, None] * C
key = np.round(P * 1e5).astype(np.int64)
_, g = np.unique(key, axis=0, return_inverse=True)
g = g.ravel()
acc = np.zeros((g.max() + 1, Wf.shape[1]))
np.add.at(acc, g, Wf)
Wf = (acc / np.bincount(g)[:, None])[g]
if Wf.shape[1] > 4:
    Wf = np.maximum(Wf - np.partition(Wf, -5, axis=1)[:, -5:-4], 0)
Wf /= Wf.sum(1, keepdims=True)
set_weights(body, names + cn, Wf)
# bake: each clip, each frame
pb = arm.pose.bones
for c in cn:
    pb[c].rotation_mode = "QUATERNION"
rest = {b: (np.array(B[b].matrix_local)) for b in ["hips", "thigh.L", "thigh.R"] + cn}


def worldrot(bn):
    M = np.array(arm.matrix_world @ pb[bn].matrix)
    R0 = rest[bn][:3, :3]
    return mathutils.Matrix(M[:3, :3]) @ mathutils.Matrix(R0).inverted()  # delta from rest, world


for act in list(bpy.data.actions):
    if not len(act.fcurves) and not hasattr(act, "slots"):
        continue
    f0, f1 = [int(round(x)) for x in act.frame_range]
    for f in range(f0, f1 + 1):
        pose(arm, act.name, f)
        Rh = worldrot("hips").to_quaternion()
        Rl = worldrot("thigh.L").to_quaternion()
        Rr = worldrot("thigh.R").to_quaternion()
        Rfb = Rl.slerp(Rr, 0.5)
        tgt = {
            "skchain_L": Rh.slerp(Rl, follow),
            "skchain_R": Rh.slerp(Rr, follow),
            "skchain_F": Rh.slerp(Rfb, follow),
            "skchain_B": Rh.slerp(Rfb, follow),
        }
        for c, q in tgt.items():
            M = pb[c].matrix.copy()
            Rw = q.to_matrix().to_4x4()
            newm = mathutils.Matrix.Translation(M.translation) @ Rw @ mathutils.Matrix(rest[c]).to_3x3().to_4x4()
            # pivot: rotate about the bone head
            pb[c].matrix = newm
            bpy.context.view_layer.update()
            pb[c].keyframe_insert("rotation_quaternion", frame=f)
print("baked", len(bpy.data.actions), "actions")
bpy.ops.export_scene.gltf(
    filepath=out,
    export_format="GLB",
    export_animations=True,
    export_animation_mode="ACTIONS",
    export_image_format="JPEG",
    export_jpeg_quality=92,
    export_apply=False,
    export_yup=True,
)
print("EXPORTED", out)
