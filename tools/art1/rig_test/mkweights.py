# ruff: noqa: F403, F405
# Blender: python mkweights.py -- in.glb out.npz kind [hip_z]
import sys

sys.path.insert(0, "tools/art1/rig_test")
from rigkit import *
import voxel_weights as VW

a = sys.argv[sys.argv.index("--") + 1 :]
src, out, kind = a[:3]
arm, body, ms = load(src)
names, W0 = get_weights(body)
me = body.data
n = len(me.vertices)
P = np.empty(n * 3)
me.vertices.foreach_get("co", P)
P = P.reshape(-1, 3)
E = edges(body)
T = tris(body)
B = arm.data.bones


def head(nm):
    return np.array(arm.matrix_world @ B[nm].head_local)


def tail(nm):
    return np.array(arm.matrix_world @ B[nm].tail_local)


hipz = head("thigh.L")[2]
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
)
dom = W0.argmax(1)
armish = np.array([names[d].startswith(ARMISH) for d in dom])


def smooth01(x):
    x = np.clip(x, 0, 1)
    return x * x * (3 - 2 * x)


m = smooth01((hipz + 0.10 - P[:, 2]) / 0.18)  # 0 above the belt, 1 from just under the hip joints down
m = m * (~armish)


def top4(W):
    if W.shape[1] > 4:
        W = np.maximum(W - np.partition(W, -5, axis=1)[:, -5:-4], 0)
    s = W.sum(1, keepdims=True)
    s[s == 0] = 1
    return W / s


key = np.round(P * 1e5).astype(np.int64)
_, grp = np.unique(key, axis=0, return_inverse=True)
grp = grp.ravel()
ng = grp.max() + 1


def weld(W):
    acc = np.zeros((ng, W.shape[1]))
    np.add.at(acc, grp, W)
    cnt = np.bincount(grp, minlength=ng)[:, None]
    return (acc / cnt)[grp]


Ew = np.unique(np.sort(grp[E], axis=1), axis=0)
Ew = Ew[Ew[:, 0] != Ew[:, 1]]


def nb_smooth(W, mask, passes):
    # on the welded graph: seam duplicates share a node, so they keep identical weights
    Wg = np.zeros((ng, W.shape[1]))
    cn = np.bincount(grp, minlength=ng)[:, None]
    np.add.at(Wg, grp, W)
    Wg /= cn
    mg = np.zeros(ng)
    np.maximum.at(mg, grp, mask)
    e = np.concatenate([Ew, Ew[:, ::-1]])
    deg = np.bincount(e[:, 0], minlength=ng)[:, None] + 1e-9
    for _ in range(passes):
        acc = np.zeros_like(Wg)
        np.add.at(acc, e[:, 0], Wg[e[:, 1]])
        Wg = Wg * (1 - mg[:, None]) + (Wg + acc) / (deg + 1) * mg[:, None]
    return Wg[grp]


def nb_smooth_old(W, mask, passes):
    e = np.concatenate([E, E[:, ::-1]])
    deg = np.bincount(e[:, 0], minlength=n)[:, None] + 1e-9
    for _ in range(passes):
        acc = np.zeros_like(W)
        np.add.at(acc, e[:, 0], W[e[:, 1]])
        Ws = (W + acc) / (deg + 1)
        W = W * (1 - mask[:, None]) + Ws * mask[:, None]
    return W


if kind == "voxel":
    fn = lambda sd: "foot." + sd if "foot." + sd in B else "x_foot." + sd
    J = {
        "pelvis": head("hips"),
        "neck": head("head"),
        "crown": tail("head") + np.array([0, 0, 0.25]),
        "shoulder.R": head("upper_arm.R"),
        "shoulder.L": head("upper_arm.L"),
        "elbow.R": head("forearm.R"),
        "elbow.L": head("forearm.L"),
        "wrist.R": head("hand.R"),
        "wrist.L": head("hand.L"),
        "hip.R": head("thigh.R"),
        "hip.L": head("thigh.L"),
        "knee.R": head("shin.R"),
        "knee.L": head("shin.L"),
        "ankle.R": head(fn("R")),
        "ankle.L": head(fn("L")),
    }
    bones = [
        b
        for b in names
        if b in ("hips", "head")
        or b.split(".")[0] in ("upper_arm", "forearm", "hand", "thigh", "shin", "foot", "x_foot")
    ]
    nm, Wv = VW.weights(P, T, J, bones, {})
    Wn = np.zeros_like(W0)
    for j, b in enumerate(nm):
        Wn[:, names.index(b)] = Wv[:, j]
elif kind == "smooth":
    Wn = nb_smooth(W0, m, 12)
elif kind == "smooth2":
    th = np.array([b.startswith("thigh") for b in names])
    mm = np.maximum(m, np.clip(5 * W0[:, th].sum(1), 0, 1) * (~armish))
    m = mm
    Wn = nb_smooth(W0, m, 20)
elif kind == "tailroot":
    ist = np.array([nm == "tail" or nm.startswith("spring_scarftail_tail") for nm in [names[d] for d in dom]])
    ztop = P[ist, 2].max()
    k = np.clip((ztop - P[:, 2]) / float(os.environ.get("TAILL", "0.12")), 0, 1)
    Hh = np.zeros_like(W0)
    Hh[:, names.index("hips")] = 1
    Wn = np.where(ist[:, None], (1 - k[:, None]) * Hh + k[:, None] * W0, W0)
    m = ist.astype(float)
elif kind in ("auto", "autosm"):
    use = [b for b in names if b == "hips" or b.split(".")[0] in ("thigh", "shin", "foot", "x_foot")]
    for b in B:
        b.use_deform = b.name in use
    c = body.copy()
    c.data = body.data.copy()
    bpy.context.scene.collection.objects.link(c)
    for g in list(c.vertex_groups):
        c.vertex_groups.remove(g)
    for md in list(c.modifiers):
        c.modifiers.remove(md)
    c.parent = None
    rm = c.modifiers.new("rm", "REMESH")
    rm.mode = "VOXEL"
    rm.voxel_size = float(os.environ.get("VOX", "0.018"))
    rm.use_smooth_shade = True
    bpy.context.view_layer.update()
    with bpy.context.temp_override(object=c, active_object=c, selected_objects=[c]):
        bpy.ops.object.modifier_apply(modifier="rm")
    print("PROXY verts", len(c.data.vertices))
    arm.data.pose_position = "REST"
    arm.animation_data.action = None
    bpy.context.view_layer.update()
    with bpy.context.temp_override(
        object=arm, active_object=arm, selected_objects=[c, arm], selected_editable_objects=[c, arm]
    ):
        r = bpy.ops.object.parent_set(type="ARMATURE_AUTO")
        print("PARENT_SET", r, len(c.vertex_groups))
    n2, W2 = get_weights(c)
    print("AUTOGROUPS", {b: int((W2[:, j] > 0).sum()) for j, b in enumerate(n2)})
    from mathutils import kdtree

    pv = np.empty(len(c.data.vertices) * 3)
    c.data.vertices.foreach_get("co", pv)
    pv = pv.reshape(-1, 3)
    kd = kdtree.KDTree(len(pv))
    for i, p in enumerate(pv):
        kd.insert(p, i)
    kd.balance()
    nn = np.array([kd.find(tuple(p))[1] for p in P])
    W2 = W2[nn]
    Wn = np.zeros_like(W0)
    for j, b in enumerate(n2):
        if b in names:
            Wn[:, names.index(b)] = W2[:, j]
    Wn = nb_smooth(np.where(Wn.sum(1, keepdims=True) > 0, Wn, W0), m, 6)
    if kind == "autosm":
        th = np.array([b.startswith("thigh") for b in names])
        m = np.maximum(m, np.clip(5 * W0[:, th].sum(1), 0, 1) * (~armish))
        Wn = nb_smooth(Wn, m, 14)
    missing = Wn.sum(1) == 0
    print("AUTO unweighted verts", int(missing.sum()))
    Wn[missing] = W0[missing]
else:
    raise SystemExit("kind?")
for j, b in enumerate(
    names
):  # no arm bone drives a non-arm vertex below the belt (a hanging hand's reach is not the pants')
    if b.startswith(("upper_arm", "forearm", "hand")):
        Wn[:, j] = 0
Wn = np.where(Wn.sum(1, keepdims=True) > 0, Wn, W0)
Wn = Wn / np.maximum(Wn.sum(1, keepdims=True), 1e-9)
Wf = top4(weld((1 - m[:, None]) * W0 + m[:, None] * Wn))
print(
    "KIND", kind, "verts blended", int((m > 0.5).sum()), "changed (L1>0.2)", int((np.abs(Wf - W0).sum(1) > 0.2).sum())
)
np.savez(out, P=P, names=np.array(names), W=Wf, W0=W0, m=m)
