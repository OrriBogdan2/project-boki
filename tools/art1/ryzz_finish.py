"""ART-1 Sparkle, stage C: rebuilt pieces + the fitted scan -> join, unwrap, paint, skin, export. Budget 15k tris, 8 surfaces.
Run: blender -b --factory-startup --python tools/art1/ryzz_finish.py -- <source.blend> <rig.json> <out.glb>"""
import sys, os, json, math
sys.stdout.reconfigure(line_buffering=True)
import bpy, bmesh
import numpy as np
from mathutils import Vector, Matrix
from mathutils.bvhtree import BVHTree
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, "..", "blender"))
import meshkit as M, ryzz_pieces as K, ryzz_paint as P
from meshkit import smooth, Piece, catmull, sweep
import warden_kit as WK

a = sys.argv[sys.argv.index("--") + 1:]
SRC, RIG, OUT = a[0], a[1], a[2]
ATLAS = 2048
FACE_K = 6.0               # the face's texel density against the body
UNIQ_W = 0.755
EYE_R = (0.76, 0.12, 0.875, 0.22)
MATS = ["skin-ryzz", "leather-ryzz", "hair-ryzz", "metal-ryzz", "glow-ryzz", "glow-arcblue", "glow-wire", "cloth-gum"]      # (8: the skirt and corset share leather's surface)
SCALE = {"lid": 2.0, "palm": 1.4, "finger": 1.5, "thumb": 1.5, "plate": 1.1, "strap": 0.7, "gum": 0.8, "Low": 1.0}
TILE = ("cap", "fringe", "pig", "tie", "sock", "rod", "wire", "chain", "arrow", "nosering", "arc", "buckle")

bpy.ops.wm.open_mainfile(filepath=SRC)
src, low = bpy.data.objects["Src"], bpy.data.objects["Low"]
# the scan's colour at 4k from its png (the box is shared: its 8k maps must never reach Cycles), bottom row first like Blender's UVs
sys.path.insert(0, os.path.join(HERE, "..", "meshy"))
import imgio, subprocess
_tmp = os.path.splitext(OUT)[0] + "_scan4k.png"
subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-i", os.path.join(os.path.dirname(SRC), "..", "runA", "tex0_base_color.png"), "-vf", "scale=4096:4096", _tmp], check=True)
SP = imgio.load(_tmp)[::-1]
sh, sw = SP.shape[:2]
os.remove(_tmp)
for mt_ in list(bpy.data.materials):
    bpy.data.materials.remove(mt_)
for im_ in list(bpy.data.images):
    bpy.data.images.remove(im_)
print("scan colour", sw, sh, SP.mean())
dg = bpy.context.evaluated_depsgraph_get()
bvh = BVHTree.FromObject(low, dg)


def on_surface(pts, off=0.006):
    """Each point snapped just outside the jacket and skin."""
    out = []
    for q in np.asarray(pts, float):
        h = bvh.find_nearest(Vector(q))
        c, nr = np.array(h[0]), np.array(h[1])
        out.append(c + nr * off)
    return np.array(out)


def clear(pts, off=0.012):
    """Lifts points that sit inside or against the body out to `off`, leaves the rest."""
    out = []
    for q in np.asarray(pts, float):
        h = bvh.find_nearest(Vector(q))
        c, nr = np.array(h[0]), np.array(h[1])
        d = (q - c) @ nr
        out.append(q if d >= off else c + nr * off)
    return np.array(out)


def back_y(x, z):
    h = bvh.ray_cast(Vector((x, -0.6, z)), Vector((0, 1, 0)), 1.0)
    return h[0].y if h[0] is not None else -0.11


# ---- the head is the scan's sculpt (it matches the sheet); hair, lids, gum and rings sit on it
_co = np.array([v.co[:] for v in low.data.vertices])
_h = _co[_co[:, 2] > K.NECK_Z + 0.06]
_lo, _hi = _h.min(0), _h.max(0)
K.C[:] = ((_lo[0] + _hi[0]) / 2, (_lo[1] + _hi[1]) / 2 + 0.012, (_lo[2] + _hi[2]) / 2 + 0.008)
K.HS = (_hi[0] - _lo[0] - 0.024) / 0.170       # (without the ears)
print("head", _lo.round(3), _hi.round(3), "C", K.C.round(3), "HS", round(K.HS, 3))


def front_y(x, z):
    h = bvh.ray_cast(Vector((x, 0.5, z)), Vector((0, -1, 0)), 1.0)
    return h[0].y if h[0] is not None else 0.1


def surf(D):
    out = np.zeros(D.shape[:-1])
    o_ = K.C + np.array([0, -0.01, 0]) * K.HS
    for ix in np.ndindex(out.shape):
        d = Vector(tuple(M.norm(D[ix])))
        h = bvh.ray_cast(Vector(tuple(o_ + np.array(d) * 0.4)), -d, 0.4)
        out[ix] = min((0.4 - h[3]) / K.HS, 0.112) if h[0] is not None else 0.1      # (low rays can reach the shoulders)
    return out


K.SURF = surf
NZ = K.NECK_Z
# the scan's own eyes and lips, measured off its paint: the sheet's face has to land on the dents that are really there
_sm0 = src.data
_co0 = np.zeros(len(_sm0.vertices) * 3)
_sm0.vertices.foreach_get("co", _co0)
_co0 = _co0.reshape(-1, 3)
_uv0 = np.zeros(len(_sm0.loops) * 2)
_sm0.uv_layers.active.data.foreach_get("uv", _uv0)
_uv0 = _uv0.reshape(-1, 2)
_vi0 = np.zeros(len(_sm0.loops), np.int64)
_sm0.loops.foreach_get("vertex_index", _vi0)
_vc = np.zeros((len(_co0), 3), np.float32)
_vc[_vi0] = SP[np.clip((_uv0[:, 1] % 1 * sh).astype(int), 0, sh - 1), np.clip((_uv0[:, 0] % 1 * sw).astype(int), 0, sw - 1)]
_near = (_co0[:, 1] > 0.02) & (np.abs(_co0[:, 0]) < 0.082)
_eye = _near & (_vc[:, 2] > _vc[:, 0] * 1.3) & (_vc[:, 2] > 0.3) & (np.abs(_co0[:, 2] - (NZ + 0.137)) < 0.03)
_lip = _near & (np.abs(_co0[:, 0]) < 0.03) & (_vc[:, 0] > _vc[:, 1] * 1.45) & (_vc[:, 0] > 0.45) & (_co0[:, 2] > NZ + 0.03) & (_co0[:, 2] < NZ + 0.09)
_er, _el = _co0[_eye & (_co0[:, 0] > 0)], _co0[_eye & (_co0[:, 0] < 0)]
EYE_X = float((_er[:, 0].mean() - _el[:, 0].mean()) / 2)
EYE_Z = float((_er[:, 2].mean() + _el[:, 2].mean()) / 2)
MOUTH_Z = float(_co0[_lip, 2].mean())
BROW_Z = EYE_Z + 0.023
EYE_W, EYE_H = 0.0285, 0.0205
print("scan landmarks: eye x", round(EYE_X, 4), "z", round(EYE_Z, 4), "(%d, %d verts) mouth z" % (len(_er), len(_el)), round(MOUTH_Z, 4), "(%d)" % int(_lip.sum()))
MOUTH_C = np.array([0.0, front_y(0.0, MOUTH_Z), MOUTH_Z])
LID_A = 0.82


def eye_c(s):
    return np.array([s * EYE_X, front_y(s * EYE_X, EYE_Z) - 0.024, EYE_Z])


def lid_piece(s):
    """The upper lid: closed it lies on the eye, at rest it is turned up about the eyeball, under the brow's skin (claire_finish)."""
    side = "R" if s > 0 else "L"
    c = eye_c(s)
    rows, cols = 5, 9
    v = []
    for j in range(rows):
        t = j / (rows - 1)
        for i in range(cols):
            x = i / (cols - 1) * 2 - 1
            z = 1.12 - 2.0 * t
            q = (s * EYE_X + x * EYE_W, z * EYE_H * (1 - 0.32 * x * x) + EYE_Z)
            v.append((q[0], front_y(q[0], q[1]) + 0.0016, q[1]))
    v = np.array(v)
    ca, sa = math.cos(LID_A), math.sin(LID_A)
    d = v - c
    v2 = np.stack([d[:, 0], d[:, 1] * ca - d[:, 2] * sa, d[:, 1] * sa + d[:, 2] * ca], 1) + c
    f = [[j * cols + i, j * cols + i + 1, (j + 1) * cols + i + 1, (j + 1) * cols + i] for j in range(rows - 1) for i in range(cols - 1)]
    p = Piece("lid" + side, "skin-ryzz", v2, f).rigid("lid." + side)
    p.c = c
    return p


GUM_R = 0.042
gum_c = MOUTH_C + np.array([0.0, GUM_R * 0.92, -0.003])          # centred on the lips, one radius out: it reads in profile (ryzz_bubblegum_ref)
pieces = [K.hair_cap(), K.gum(gum_c, GUM_R), K.nose_ring((0.0, front_y(0.0, NZ + 0.09) + 0.002, NZ + 0.09))]
for s in (1.0, -1.0):
    pieces.append(lid_piece(s))
    pieces += K.tie_band(s)
pieces += K.fringe()
CH = {}
for s in (1.0, -1.0):
    locks, nms, chain = K.pigtail(s)
    pieces += locks
    CH[s] = (nms, chain)
HANDS = {s: K.hand(s) for s in (1.0, -1.0)}
for s in HANDS:
    pieces += HANDS[s]

# ---- the harness on her back, from the master's back view
Z0, Z1 = 1.175, 1.385
OUTL = [(-0.075, Z1), (0.075, Z1), (0.118, 1.345), (0.118, 1.27), (0.082, Z0 + 0.012), (0.05, Z0), (-0.05, Z0), (-0.082, Z0 + 0.012), (-0.118, 1.27), (-0.118, 1.345)]
INNER = [(-0.035, 1.325), (0.035, 1.325), (0.058, 1.285), (0.04, 1.225), (-0.04, 1.225), (-0.058, 1.285)]


def resample(poly, n):
    p = np.array(poly + [poly[0]], float)
    s = np.concatenate([[0], np.cumsum(np.linalg.norm(np.diff(p, axis=0), axis=1))])
    t = np.linspace(0, s[-1], n, endpoint=False)
    return np.stack([np.interp(t, s, p[:, 0]), np.interp(t, s, p[:, 1])], 1)


NP = 20
ro, ri = resample(OUTL, NP), resample(INNER, NP)
rm0 = ro * 0.97 + ri * 0.03
rm1 = ri * 0.97 + ro * 0.03
def lift(r, off):
    return np.array([(x, back_y(x, z) - off, z) for x, z in r])


rings = [lift(ro, 0.002), lift(rm0, 0.014), lift(rm1, 0.014), lift(ri, 0.002)]
vp = np.concatenate(rings)
fp = [[i * NP + j, i * NP + (j + 1) % NP, (i + 1) * NP + (j + 1) % NP, (i + 1) * NP + j] for i in range(3) for j in range(NP)]
plate = Piece("plate", "leather-ryzz", vp, fp).rigid("hips")
plate.rivets = lift(np.array([(-0.09, 1.355), (0.09, 1.355), (-0.1, 1.285), (0.1, 1.285), (-0.06, 1.2), (0.06, 1.2), (0, 1.355), (0, 1.2)]), 0.0155)
pieces.append(plate)
RODB = []
for i in range(4):
    rp, ra, rb, rd = K.rod(i)
    # seat the sockets on the plate
    rx, rz = ra[0], ra[2]
    dy = (back_y(rx, rz) - 0.016) - ra[1]
    for q in rp:
        q.v = q.v + [0, dy, 0]
    pieces += rp
    RODB.append((ra + [0, dy, 0], rb + [0, dy, 0], rd))
TIP = [b for _, b, _ in RODB]

# ---- arcs between the rods: two shapes, flickered by their bones in every clip (the model's idle read; ability lightning is S3's)
rng = np.random.RandomState(7)
for v_ in range(2):
    for i in range(3):
        A_, B_ = TIP[i] - RODB[i][2] * 0.012, TIP[i + 1] - RODB[i + 1][2] * 0.012
        n_ = 8
        pts = []
        for j in range(n_):
            t = j / (n_ - 1)
            q = A_ * (1 - t) + B_ * t + np.array([0, 0, 0.05 * math.sin(t * math.pi)])
            if 0 < j < n_ - 1:
                q = q + rng.uniform(-0.024, 0.024, 3) * [1, 0.6, 1.5]
            pts.append(q)
        pieces.append(sweep("arc%d_%d" % (v_, i), "glow-arcblue" if v_ else "glow-ryzz", pts, K.TRI, np.full(n_, 0.0098), side_hint=np.array([0, 1.0, 0.2]), uv_rect=K.GLOWC_R, room=0.0).rigid("arc.%d" % v_))

# ---- the wires, two down each arm to the copper-capped hand
def wire_w(p):
    z = p[:, 2]
    x = np.abs(p[:, 0])
    arm = smooth(K.SH + 0.015, K.SH + 0.05, x) * 0 + 1
    return z


for s, sd in ((1.0, "R"), (-1.0, "L")):
    Sx = K.SH * s
    for w_i, ctl in enumerate((
            [(s * 0.098, back_y(s * 0.098, 1.20) - 0.01, 1.20), (s * 0.175, -0.095, 1.165), (s * 0.205, -0.055, 1.10), (Sx + s * 0.058, -0.045, 1.055),
             (Sx + s * 0.036, -0.045, 0.985), (Sx + s * 0.024, -0.024, K.HAND_Z + 0.03), (Sx + s * 0.026, -0.012, K.HAND_Z + 0.012)],
            [(s * 0.112, back_y(s * 0.112, 1.31) - 0.01, 1.31), (s * 0.19, -0.1, 1.29), (s * 0.215, -0.05, 1.2), (Sx + s * 0.07, -0.015, 1.1),
             (Sx + s * 0.05, -0.008, 0.99), (Sx + s * 0.03, 0.0, K.HAND_Z + 0.03), (Sx + s * 0.026, 0.006, K.HAND_Z + 0.012)])):
        path = clear(catmull(ctl, 15), 0.010)
        wr = K.wire("wire%d%s" % (w_i, sd), path)
        ring = np.repeat(path, 3, axis=0)
        z = ring[:, 2]
        up = smooth(1.30, 1.17, z)                  # off the plate onto the arm
        w = {"hips": 1 - up}
        fo = smooth(K.ELBOW_Z + 0.03, K.ELBOW_Z - 0.03, z)
        ha = smooth(K.HAND_Z + 0.05, K.HAND_Z + 0.01, z)
        w["upper_arm." + sd] = up * (1 - fo)
        w["forearm." + sd] = up * fo * (1 - ha)
        w["hand." + sd] = up * fo * ha
        wr.w = w
        pieces.append(wr)

# ---- the straps over the bare shoulders, front to the corset, with a buckle
for s, sd in ((1.0, "R"), (-1.0, "L")):
    ctl = [(s * 0.082, -0.10, 1.372), (s * 0.095, -0.02, 1.415), (s * 0.103, 0.06, 1.385), (s * 0.103, 0.105, 1.325), (s * 0.098, 0.135, 1.275)]
    path = on_surface(catmull(ctl, 11), 0.004)
    st = K.strip("strap" + sd, "leather-ryzz", path, 0.0185, 0.0024, hint=np.array([1.0, 0, 0]))
    st.w = {"hips": np.ones(len(st.v))}
    pieces.append(st)
    bc = path[7]
    pieces.append(K.strip("buckle" + sd, "metal-ryzz", [bc + [0, 0.004, 0.014], bc + [0, 0.006, -0.014]], 0.0185, 0.0035, uv=K.COPPER_R, hint=np.array([1.0, 0, 0])).rigid("hips"))

# ---- the chain slung on the skirt, her left hip across, with the arrow
ctl = [(-0.055, 0.118, 0.985), (-0.085, 0.142, 0.92), (0.02, 0.17, 0.875), (0.15, 0.16, 0.86), (0.20, 0.09, 0.91), (0.19, 0.06, 0.975)]
path = on_surface(catmull(ctl, 14), 0.007)
CHAIN_UV = (K.COPPER_R[0], K.COPPER_R[1], K.COPPER_R[2], K.COPPER_R[3])
ch = K.chain_along("chain0", path, step=0.0235, uv=CHAIN_UV, ln=0.028, wid=0.016, th=0.0036).rigid("root")
ch.mat = "metal-ryzz"
pieces.append(ch)
drop = on_surface(catmull([(-0.055, 0.118, 0.985), (-0.058, 0.148, 0.92), (-0.056, 0.168, 0.86)], 5), 0.007)
c1 = K.chain_along("chain1", drop, step=0.0235, uv=CHAIN_UV, ln=0.028, wid=0.016, th=0.0036).rigid("skirt")
c1.mat = "metal-ryzz"
pieces.append(c1)
tipc = drop[-1]
pieces.append(Piece("arrow", "metal-ryzz", [tipc + [-0.018, 0.002, 0.0], tipc + [0.018, 0.002, 0.0], tipc + [0, 0.005, -0.042], tipc + [0, 0.0, 0.006]], [[0, 2, 1], [0, 1, 3]],
                    [[(0.77, 0.34), (0.77, 0.40), (0.86, 0.37)], [(0.77, 0.34), (0.86, 0.37), (0.8, 0.40)]]).rigid("skirt"))

for p in pieces:
    if p.name in ("face", "skull", "cap") or p.name.startswith("lid"):
        p.orient(ref=K.hl((0, -0.01, 0.0)))
    elif p.name.startswith("plate"):
        p.orient(ref=(0, 0, 1.28))
    else:
        p.orient()

# ---- join
names, verts, faces_v, faces_pid, faces_uv, vw, rooms = [], [], [], [], [], [], []
me_l = low.data
gn = {g.index: g.name for g in low.vertex_groups}
names.append("Low")
for v in me_l.vertices:
    verts.append(tuple(v.co))
    vw.append({gn[g.group]: g.weight for g in v.groups if g.weight > 0.01})
    rooms.append(0.0 if v.co.z > K.NECK_Z + 0.03 else 1.0)       # (no ink shell on the sculpt: it breaks into dashes round the eyes and mouth)
# the scan's forearms sit against the skirt in the rest pose: nothing on an arm follows the hips
for d_ in vw:
    arm_ = d_.get("forearm.R", 0) + d_.get("forearm.L", 0) + d_.get("hand.R", 0) + d_.get("hand.L", 0)
    body_ = sum(d_.get(b_, 0) for b_ in ("root", "skirt", "thigh.R", "thigh.L"))
    if arm_ > 0.0 and body_ > 0.0:              # each vertex goes one way: mostly arm, or mostly body (a little arm drags the skirt to the wrist)
        for b_ in (("root", "skirt", "thigh.R", "thigh.L") if arm_ > body_ else ("forearm.R", "forearm.L", "hand.R", "hand.L")):
            d_.pop(b_, None)
# the face's own deformers, soft spots on the sculpt
DEFORM = {}
for s_, sd_ in ((1.0, "R"), (-1.0, "L")):
    DEFORM["mouth." + sd_] = (np.array([s_ * 0.0285, front_y(s_ * 0.0285, MOUTH_Z), MOUTH_Z]), 0.02)
    DEFORM["brow." + sd_] = (np.array([s_ * 0.052, front_y(s_ * 0.052, BROW_Z), BROW_Z]), 0.03)
for i_, q_ in enumerate(verts):
    q_ = np.array(q_)
    if q_[2] < NZ + 0.04 or q_[1] < 0.02:
        continue
    for b_, (c_, r_) in DEFORM.items():
        k_ = float(1 - smooth(r_ * 0.25, r_, np.linalg.norm(q_ - c_)))
        if k_ > 0.01:
            vw[i_] = {"head": 1 - k_, b_: k_}
def on_arm(d_):
    return d_.get("forearm.R", 0) + d_.get("forearm.L", 0) + d_.get("hand.R", 0) + d_.get("hand.L", 0)


cut_ = 0
for pl in me_l.polygons:
    a_ = [on_arm(vw[v]) for v in pl.vertices]
    if max(a_) > 0.5 and min(a_) < 0.05 and pl.center.z < 1.1:      # (the decimate's own bridges from the wrist to the skirt: they'd stretch to a blade)
        cut_ += 1
        continue
    faces_v.append(list(pl.vertices))
    faces_pid.append(0)
    faces_uv.append(None)
print("arm-to-body faces cut", cut_)
for pc in pieces:
    pid = len(names)
    names.append(pc.name)
    base = len(verts)
    verts.extend([tuple(v) for v in pc.v])
    for i in range(len(pc.v)):
        vw.append({b: float(arr[i]) for b, arr in pc.w.items() if arr[i] > 0.005})
    rooms.extend([pc.room] * len(pc.v))
    for j, f in enumerate(pc.f):
        faces_v.append([base + i for i in f])
        faces_pid.append(pid)
        faces_uv.append(pc.uv[j] if pc.uv is not None else None)
me = bpy.data.meshes.new("Body")
me.from_pydata(verts, [], faces_v)
me.update()
ob = bpy.data.objects.new("Body", me)
bpy.context.scene.collection.objects.link(ob)
for m in MATS:
    mt = bpy.data.materials.new(m)
    mt.use_nodes = True
    me.materials.append(mt)
uv = me.uv_layers.new(name="UV")
nf = len(me.polygons)
pid_arr = np.array(faces_pid)
TR = sum(len(p.vertices) - 2 for p in me.polygons)
print("tris", TR, "verts", len(me.vertices))
by = {}
for pl in me.polygons:
    k_ = "".join(c for c in names[faces_pid[pl.index]] if not c.isdigit()).rstrip("RL_")
    by[k_] = by.get(k_, 0) + len(pl.vertices) - 2
print("by piece", sorted(by.items(), key=lambda kv: -kv[1])[:24])


def is_tile(n):
    return n.startswith(TILE) and not n.startswith("rodX")


mat_i = {m: i for i, m in enumerate(MATS)}
PIECE_MAT = {pc.name: pc.mat for pc in pieces}
PBY = {pc.name: pc for pc in pieces}
for i, pl in enumerate(me.polygons):
    n = names[faces_pid[i]]
    if n == "Low":
        continue
    m_ = PIECE_MAT[n]
    if n.startswith(("finger0", "thumb")):
        c = np.mean([verts[v] for v in faces_v[i]], axis=0)
        if np.linalg.norm(c - PBY[n].tip) < 0.024:
            m_ = "metal-ryzz"
    pl.material_index = mat_i[m_]

# ---- unwrap
bpy.context.view_layer.objects.active = ob
ob.select_set(True)
for o in bpy.data.objects:
    if o is not ob:
        o.select_set(False)
bpy.ops.object.mode_set(mode="EDIT")
bpy.ops.mesh.select_mode(type="FACE")
bm = bmesh.from_edit_mesh(me)
bm.faces.ensure_lookup_table()
bpy.context.scene.tool_settings.use_uv_select_sync = True
uniq = [i for i in range(nf) if not is_tile(names[faces_pid[i]])]
for f in bm.faces:
    f.select = False
for i in uniq:
    bm.faces[i].select = True
bmesh.update_edit_mesh(me)
bpy.ops.uv.smart_project(angle_limit=math.radians(66), island_margin=0.0, area_weight=0.0, scale_to_bounds=False)
bm = bmesh.from_edit_mesh(me)
bm.faces.ensure_lookup_table()
PARTS = {"head": "head", "mouth.R": "head", "mouth.L": "head", "brow.R": "head", "brow.L": "head", "upper_arm.R": "armR", "forearm.R": "armR", "hand.R": "armR", "upper_arm.L": "armL", "forearm.L": "armL", "hand.L": "armL", "thigh.R": "legR", "shin.R": "legR",
         "foot.R": "legR", "thigh.L": "legL", "shin.L": "legL", "foot.L": "legL"}
region = {}
for i in range(nf):
    if names[faces_pid[i]] != "Low":
        continue
    tally = {}
    for vi in faces_v[i]:
        for b, w_ in vw[vi].items():
            p_ = PARTS.get(b, "torso")
            tally[p_] = tally.get(p_, 0) + w_
    part = max(tally, key=tally.get) if tally else "torso"
    c = np.mean([verts[v] for v in faces_v[i]], axis=0)
    if part == "head" and c[2] > K.NECK_Z + 0.04 and bm.faces[i].normal.y > 0.3:
        part = "face"       # flat from the front, with its own big share of the atlas
    # (seams at the waist and down the skirt's centre: one big island round its holes folds over itself, and paint lands on the wrong place)
    region[i] = (part, c[1] > 0.0, part == "torso" and c[2] > 1.04, part == "torso" and c[2] <= 1.04 and c[0] > 0.0)
for e in bm.edges:
    lf = [f.index for f in e.link_faces]
    if len(lf) == 2 and lf[0] in region and lf[1] in region:
        e.seam = region[lf[0]] != region[lf[1]]
for f in bm.faces:
    f.select = f.index in region
bmesh.update_edit_mesh(me)
bpy.ops.uv.unwrap(method="CONFORMAL", margin=0.0)
bm = bmesh.from_edit_mesh(me)
bm.faces.ensure_lookup_table()
uvl = bm.loops.layers.uv["UV"]
for i, r_ in region.items():
    if r_[0] == "face":
        for l in bm.faces[i].loops:
            l[uvl].uv = (l.vert.co.x, l.vert.co.z)
# faces the solver squashed to nothing (a 6 cm triangle in 0.002 of the atlas: it takes its neighbour's colour as a hard wedge) get their own flat island
_r, _fi = [], []
for i in region:
    f = bm.faces[i]
    pts = [l[uvl].uv.copy() for l in f.loops]
    a2 = sum(abs((pts[k] - pts[0]).cross(pts[k + 1] - pts[0])) * 0.5 for k in range(1, len(pts) - 1))
    _r.append(a2 / max(f.calc_area(), 1e-9))
    _fi.append(i)
_r = np.array(_r)
_keys = {}
for j_, i in enumerate(_fi):
    _keys.setdefault(region[i], []).append(j_)       # (each island has its own scale: judged against its own median)
_bad = []
for ids_ in _keys.values():
    _med = float(np.median(_r[ids_]))
    _k = math.sqrt(_med)
    for j_ in ids_:
        if _r[j_] < 0.08 * _med:
            i = _fi[j_]
            _bad.append(i)
            f = bm.faces[i]
            ax = int(np.argmax(np.abs(np.array(f.normal))))
            u_, v_ = [(1, 2), (0, 2), (0, 1)][ax]
            for l in f.loops:
                l[uvl].uv = (l.vert.co[u_] * _k, l.vert.co[v_] * _k)
print("squashed faces re-flattened", len(_bad), "of", len(_fi))


def base_name(n):
    return n.rstrip("RL0123456789")


stats = {}
for i in uniq:
    n = names[faces_pid[i]]
    if i in region:
        n = n + region[i][0]
    f = bm.faces[i]
    pts = [l[uvl].uv.copy() for l in f.loops]
    a2 = sum(abs((pts[k] - pts[0]).cross(pts[k + 1] - pts[0])) * 0.5 for k in range(1, len(pts) - 1))
    s_ = stats.setdefault(n, [0.0, 0.0])
    s_[0] += f.calc_area()
    s_[1] += a2
for i in uniq:
    n = names[faces_pid[i]]
    wgt = SCALE.get(base_name(n), 1.0)
    if i in region:
        wgt = {"face": FACE_K, "head": 1.4}.get(region[i][0], 1.0)
        n = n + region[i][0]
    s_ = wgt * math.sqrt(stats[n][0] / max(stats[n][1], 1e-12))
    for l in bm.faces[i].loops:
        l[uvl].uv = l[uvl].uv * s_
bmesh.update_edit_mesh(me)
bpy.ops.mesh.select_all(action="DESELECT")
bm = bmesh.from_edit_mesh(me)
bm.faces.ensure_lookup_table()
for i in uniq:
    bm.faces[i].select = True
bmesh.update_edit_mesh(me)
bpy.ops.uv.pack_islands(rotate=True, scale=True, margin_method="FRACTION", margin=0.0035, shape_method="CONCAVE")
bpy.ops.object.mode_set(mode="OBJECT")
uvd = me.uv_layers["UV"].data
loop_uv = np.zeros(len(me.loops) * 2)
uvd.foreach_get("uv", loop_uv)
loop_uv = loop_uv.reshape(-1, 2)
for pl in me.polygons:
    i = pl.index
    n = names[faces_pid[i]]
    ls = list(pl.loop_indices)
    if not is_tile(n):
        loop_uv[ls, 0] *= UNIQ_W
        continue
    fu = faces_uv[i]
    for l, xy in zip(ls, fu):
        loop_uv[l] = xy
uvd.foreach_set("uv", loop_uv.ravel())
me.update()

print("uv range", np.nanmin(loop_uv, 0), np.nanmax(loop_uv, 0), "nan uv", int(np.isnan(loop_uv).sum()), "nan co", int(np.isnan(np.array(verts)).sum()), "co range", np.nanmin(np.array(verts), 0).round(3), np.nanmax(np.array(verts), 0).round(3))
far = [(names[faces_pid[p_.index]]) for p_ in me.polygons if not np.all(np.isfinite(loop_uv[list(p_.loop_indices)])) or loop_uv[list(p_.loop_indices)].max() > 1.01 or loop_uv[list(p_.loop_indices)].min() < -0.01]
print("uv outside 0-1:", len(far), sorted(set(far))[:20])
# ---- texel maps
me.calc_loop_triangles()
vco = np.array(verts)
vn = np.zeros(len(me.vertices) * 3)
me.vertices.foreach_get("normal", vn)
vn = vn.reshape(-1, 3)
PID = -np.ones((ATLAS, ATLAS), np.int32)
COVER = np.zeros((ATLAS, ATLAS), np.int16)
FID = -np.ones((ATLAS, ATLAS), np.int32)
OVER = 0
POS = np.zeros((ATLAS, ATLAS, 3), np.float32)
NOR = np.zeros((ATLAS, ATLAS, 3), np.float32)
for t in me.loop_triangles:
    if is_tile(names[faces_pid[t.polygon_index]]):
        continue
    uvp = loop_uv[list(t.loops)] * ATLAS - 0.5
    x0, y0 = np.floor(uvp.min(0)).astype(int) - 1
    x1, y1 = np.ceil(uvp.max(0)).astype(int) + 1
    x0, y0, x1, y1 = max(x0, 0), max(y0, 0), min(x1, ATLAS - 1), min(y1, ATLAS - 1)
    if x1 < x0 or y1 < y0:
        continue
    ys, xs = np.mgrid[y0:y1 + 1, x0:x1 + 1]
    a_, b_, c_ = uvp
    den = (b_[1] - c_[1]) * (a_[0] - c_[0]) + (c_[0] - b_[0]) * (a_[1] - c_[1])
    if abs(den) < 1e-9:
        continue
    l0 = ((b_[1] - c_[1]) * (xs - c_[0]) + (c_[0] - b_[0]) * (ys - c_[1])) / den
    l1 = ((c_[1] - a_[1]) * (xs - c_[0]) + (a_[0] - c_[0]) * (ys - c_[1])) / den
    l2 = 1 - l0 - l1
    m = (l0 >= -0.04) & (l1 >= -0.04) & (l2 >= -0.04)
    if not m.any():
        continue
    tv = list(t.vertices)
    w = np.stack([l0[m], l1[m], l2[m]], -1)
    OVER += int((PID[ys[m], xs[m]] >= 0).sum()) if l0.size else 0
    COVER[ys[m], xs[m]] += (l0[m] >= 0.02) & (l1[m] >= 0.02) & (l2[m] >= 0.02)
    POS[ys[m], xs[m]] = w @ vco[tv]
    NOR[ys[m], xs[m]] = w @ vn[tv]
    PID[ys[m], xs[m]] = faces_pid[t.polygon_index]
    FID[ys[m], xs[m]] = t.polygon_index
NOR = M.norm(NOR)
print("texels", (PID >= 0).sum(), "of", ATLAS * ATLAS)
print("uv overlap: texels inside two faces", int((COVER > 1).sum()))
_fm = np.isin(PID, [0]) & (POS[..., 2] > K.NECK_Z + 0.08) & (POS[..., 1] > 0.04)
print("face texels", int(_fm.sum()), "of", int((PID == 0).sum()), "body texels")

me.polygons.foreach_set("use_smooth", [True] * nf)
src.hide_render = low.hide_render = True     # (only the shipped body shades itself; and Cycles leaves the scan's 8k maps unloaded)
ao_img = bpy.data.images.new("ao", ATLAS, ATLAS, float_buffer=True)
sc = bpy.context.scene
sc.render.engine = "CYCLES"
sc.cycles.device = "CPU"
sc.cycles.samples = 32
for mt in me.materials:
    nt = mt.node_tree
    im = nt.nodes.new("ShaderNodeTexImage")
    im.image = ao_img
    nt.nodes.active = im
bpy.ops.object.select_all(action="DESELECT")
ob.select_set(True)
bpy.context.view_layer.objects.active = ob
bpy.context.view_layer.update()
bpy.ops.object.bake(type="AO", use_clear=True, margin=6)
AO = np.array(ao_img.pixels[:], dtype=np.float32).reshape(ATLAS, ATLAS, 4)[..., 0]


def blur(a, m, r):
    def box(z):
        c_ = np.cumsum(np.cumsum(z, 0), 1)
        c_ = np.pad(c_, ((r + 1, r), (r + 1, r)), mode="edge")
        c_[:r + 1, :] = 0
        c_[:, :r + 1] = 0
        return c_[2 * r + 1:, 2 * r + 1:] - c_[:-2 * r - 1, 2 * r + 1:] - c_[2 * r + 1:, :-2 * r - 1] + c_[:-2 * r - 1, :-2 * r - 1]
    return box(a * m) / np.maximum(box(m), 1e-3)


AO = blur(AO, (PID >= 0).astype(np.float32), 3)

# ---- the scan's paint
sm = src.data
sm.calc_loop_triangles()
st_ = sm.loop_triangles
svco = np.zeros(len(sm.vertices) * 3)
sm.vertices.foreach_get("co", svco)
svco = svco.reshape(-1, 3)
tri_v = np.array([t.vertices[:] for t in st_])
tri_l = np.array([t.loops[:] for t in st_])
suv = np.zeros(len(sm.loops) * 2)
sm.uv_layers.active.data.foreach_get("uv", suv)
suv = suv.reshape(-1, 2)
# at rest her arms hang against the hips: arm paint is only for the arm, or the skirt and jacket pick up forearm and glove
_gn = {g.index: g.name for g in src.vertex_groups}
_armg = {i for i, n in _gn.items() if n.startswith(("upper_arm.", "forearm.", "hand."))}
_arm_w = np.zeros(len(sm.vertices), np.float32)
for v in sm.vertices:
    for g in v.groups:
        if g.group in _armg:
            _arm_w[v.index] += g.weight
tri_arm = _arm_w[tri_v].mean(1) > 0.5
ids_body, ids_arm = np.nonzero(~tri_arm)[0], np.nonzero(tri_arm)[0]
tree_body = BVHTree.FromPolygons([tuple(v) for v in svco], [tuple(t) for t in tri_v[ids_body]])
tree_arm = BVHTree.FromPolygons([tuple(v) for v in svco], [tuple(t) for t in tri_v[ids_arm]])
print("scan tris: body", len(ids_body), "arm", len(ids_arm))
def sample_scan(points, on_arm_=None):
    hit_i = np.zeros(len(points), np.int64)
    hit_p = np.zeros((len(points), 3))
    for i, p in enumerate(points):
        arm_ = on_arm_ is not None and on_arm_[i]
        h = (tree_arm if arm_ else tree_body).find_nearest(Vector(p))
        if h[2] is not None:
            hit_i[i] = (ids_arm if arm_ else ids_body)[h[2]]
            hit_p[i] = h[0]
    tv = svco[tri_v[hit_i]]
    v0, v1, v2 = tv[:, 1] - tv[:, 0], tv[:, 2] - tv[:, 0], hit_p - tv[:, 0]
    d00, d01, d11 = (v0 * v0).sum(1), (v0 * v1).sum(1), (v1 * v1).sum(1)
    d20, d21 = (v2 * v0).sum(1), (v2 * v1).sum(1)
    den = np.maximum(d00 * d11 - d01 * d01, 1e-14)
    bv = (d11 * d20 - d01 * d21) / den
    bw = (d00 * d21 - d01 * d20) / den
    bu = 1 - bv - bw
    luv = suv[tri_l[hit_i]]
    uu = bu * luv[:, 0, 0] + bv * luv[:, 1, 0] + bw * luv[:, 2, 0]
    vv = bu * luv[:, 0, 1] + bv * luv[:, 1, 1] + bw * luv[:, 2, 1]
    sx = np.clip((uu % 1) * sw, 0, sw - 1).astype(int)
    sy = np.clip((vv % 1) * sh, 0, sh - 1).astype(int)
    return SP[sy, sx]


low_faces = [i for i in range(nf) if faces_pid[i] == 0]
fc = np.array([np.mean([verts[v] for v in faces_v[i]], axis=0) for i in low_faces])
fc_arm = np.array([region[i][0] in ("armR", "armL") for i in low_faces])
fcol = sample_scan(fc, fc_arm)
for k_, i in enumerate(low_faces):
    r_, g_, b_ = fcol[k_]
    L_ = fcol[k_].mean()
    z_ = fc[k_][2]
    if z_ > K.NECK_Z + 0.03 and b_ > r_ * 1.1:
        m = "hair-ryzz"
    elif r_ > g_ * 1.5 and b_ > g_ * 1.1 and fc[k_][1] < 0.03 and 1.0 < z_ < 1.15:
        m = "skin-ryzz"            # the waist: the corset wraps the front only, bare back (master sheet)
    elif r_ > 0.55 and g_ > 0.3 and b_ > 0.2 and g_ > b_ * 1.05 and r_ < g_ * 1.9 and L_ > 0.4 and not (g_ > 0.6 and b_ < 0.25):
        m = "skin-ryzz"
    elif r_ > g_ * 1.5 and b_ > g_ * 1.1:
        m = "leather-ryzz"       # the corset
    elif 0.78 < z_ < 1.04 and abs(fc[k_][0]) < 0.34:
        m = "leather-ryzz"       # the skirt
    else:
        m = "leather-ryzz"
    me.polygons[i].material_index = mat_i[m]

mask = PID == 0
ys, xs = np.nonzero(mask)
_is_arm = np.zeros(nf, bool)
for i_, r_ in region.items():
    _is_arm[i_] = r_[0] in ("armR", "armL")
col = sample_scan(POS[ys, xs].astype(np.float64), _is_arm[FID[ys, xs]])
OUTC = np.zeros((ATLAS, ATLAS, 3), np.float32)
OUTC[ys, xs] = np.power(np.clip(col, 0, 1), 0.9) * 1.06
OUTC[ys, xs] *= (0.84 + 0.16 * np.clip(AO[ys, xs], 0, 1))[:, None]      # (the scan's paint is already shaded; more leaves a smudge under the chain)
ri, gi, bi = OUTC[..., 0], OUTC[..., 1], OUTC[..., 2]
lumi = OUTC.mean(2)
z_t = POS[..., 2]
# near-black leather lifted to charcoal with a cool cast (the toon rim reads it as gloss otherwise)
rawL = blur(lumi, mask.astype(np.float32), 5)
yel_ = blur(((ri > 0.6) & (gi > 0.5) & (bi < 0.4)).astype(np.float32), mask.astype(np.float32), 6)
dk_k = smooth(0.34, 0.12, blur(OUTC.max(2), mask.astype(np.float32), 2))[..., None] * mask[..., None] * (yel_ < 0.04)[..., None]
OUTC = OUTC + np.array([0.2, 0.18, 0.235], dtype=np.float32) * dk_k
# the neon: bright magenta line art, corset, chest bolt, forearm veins -> the glow key (the shader's model_glow colour)
neon = mask & (ri > 0.86) & (bi > 0.62) & (gi < 0.6) & (ri > gi * 1.6) & (z_t > 0.95)
neon &= (np.abs(POS[..., 0]) < 0.125) | (z_t < 1.09)      # the corset, the chest and the forearms' veins: not the jacket's inner panels
n_b = blur(neon.astype(np.float32), mask.astype(np.float32), 1)
core = n_b > 0.5
print("neon texels", int(core.sum()))
# the forearm's veins, caught by the sleeve hanging over it: leather has no pink
jk = mask & (np.abs(POS[..., 0]) > 0.1) & (z_t > 1.1) & (z_t < 1.36) & (ri > gi * 1.5) & (bi > gi)
OUTC[jk] = np.array([0.17, 0.15, 0.19], dtype=np.float32)
core &= ~jk
# the bare back at the waist: the turnaround's corset band out, the master's skin in
bw = mask & (POS[..., 1] < 0.03) & (z_t > 1.0) & (z_t < 1.16) & (ri > gi * 1.35) & (bi > gi * 0.95) & (ri > 0.42)
OUTC[bw] = P.skin(POS[bw].astype(np.float64), NOR[bw].astype(np.float64), AO[bw].astype(np.float64)).astype(np.float32)
core &= ~bw
# fishnets: from the top of the thigh band to the skirt's hem, repainted crisp
yl = mask & (ri > 0.65) & (gi > 0.55) & (bi < 0.35) & (z_t < 0.8) & (z_t > 0.5) & (np.abs(POS[..., 0]) < 0.17)
BAND = float(np.percentile(z_t[yl], 99)) if yl.any() else 0.68
net = mask & (z_t > BAND + 0.004) & (z_t < 0.84) & (np.hypot(np.abs(POS[..., 0]) - 0.085, POS[..., 1]) < 0.122) & (rawL > 0.33)
print("thigh band top", round(BAND, 3), "net texels", int(net.sum()))
skin_sm = blur(OUTC.mean(2), net.astype(np.float32), 9)
base = P.skin(POS[net].astype(np.float64), NOR[net].astype(np.float64), AO[net].astype(np.float64))
OUTC[net] = P.fishnet(POS[net].astype(np.float64), base).astype(np.float32)
# the skirt's hem: skin-coloured chips the scan left between the pleats go to the skirt's own charcoal
chip = mask & ~net & (z_t > BAND + 0.03) & (z_t < 0.97) & (np.abs(POS[..., 0]) < 0.32) & ~_is_arm[FID]      # (her forearms hang through here at rest)
chip &= (OUTC[..., 0] > OUTC[..., 1] * 1.25) & (OUTC[..., 1] > OUTC[..., 2] * 1.03) & (OUTC.mean(2) > 0.36)      # warm like skin: the skirt's purple isn't
OUTC[chip] = np.array([0.2, 0.18, 0.235], dtype=np.float32)
# the waist: the band's dark smear on the bare midriff (not the navel)
smear = mask & (POS[..., 1] > 0.0) & (z_t > 1.022) & (z_t < 1.06) & (np.abs(POS[..., 0]) < 0.118) & (np.abs(POS[..., 0]) > 0.02) & (OUTC.mean(2) < 0.5)
OUTC[smear] = P.skin(POS[smear].astype(np.float64), NOR[smear].astype(np.float64), np.ones(int(smear.sum())) * 0.8).astype(np.float32)
print("hem chips", int(chip.sum()), "waist smear", int(smear.sum()))


def bil(img, u, v):
    """Bilinear lookup: nearest-pixel paint is what looked blocky up close."""
    u = np.clip(u, 0, img.shape[1] - 1.001)
    v = np.clip(v, 0, img.shape[0] - 1.001)
    x0, y0 = u.astype(int), v.astype(int)
    fx, fy = (u - x0)[:, None], (v - y0)[:, None]
    return ((img[y0, x0] * (1 - fx) + img[y0, x0 + 1] * fx) * (1 - fy) + (img[y0 + 1, x0] * (1 - fx) + img[y0 + 1, x0 + 1] * fx) * fy)


# ---- the master sheet projected on the corset and chest: the detail comes from the art. Registered by the neon outline's bounds, so no hand-placed numbers.
SHEET = "/home/boki/briefs-wt/briefs/art-refs/ryzz_FINAL_sheet.png"
sh_ = imgio.load(SHEET)
SHH, SHW = sh_.shape[:2]
sn = (sh_[..., 0] > 0.8) & (sh_[..., 2] > 0.55) & (sh_[..., 1] < 0.5)
win = np.zeros_like(sn)
win[int(SHH * 0.315):int(SHH * 0.425), int(SHW * 0.15):int(SHW * 0.32)] = True      # the front view's corset
sy_, sx_ = np.nonzero(sn & win)
core_f = core & (POS[..., 1] > 0.0) & (z_t > 1.0) & (z_t < 1.36) & (np.abs(POS[..., 0]) < 0.14)
mz = z_t[core_f]
mx = POS[..., 0][core_f]
if len(sy_) > 200 and len(mz) > 200:
    z0_, z1_ = np.percentile(mz, 1), np.percentile(mz, 99)
    x0_, x1_ = np.percentile(mx, 1), np.percentile(mx, 99)
    v0_, v1_ = np.percentile(sy_, 1), np.percentile(sy_, 99)
    u0_, u1_ = np.percentile(sx_, 1), np.percentile(sx_, 99)
    print("corset map: model x", round(float(x0_), 3), round(float(x1_), 3), "z", round(float(z0_), 3), round(float(z1_), 3), "sheet u", u0_, u1_, "v", v0_, v1_)
    # (sheet u grows toward her left, -X; v grows downward)
    pj = mask & (POS[..., 1] > 0.02) & (NOR[..., 1] > 0.15) & (z_t > z0_ - 0.012) & (z_t < z1_ + 0.012) & (np.abs(POS[..., 0]) < x1_ + 0.012) & (ri > gi * 1.3)
    yy_, xx_ = np.nonzero(pj)
    uu_ = u0_ + (x1_ - POS[yy_, xx_, 0]) / (x1_ - x0_) * (u1_ - u0_)
    vv_ = v0_ + (z1_ - POS[yy_, xx_, 2]) / (z1_ - z0_) * (v1_ - v0_)
    cc_ = bil(sh_, uu_, vv_)
    skin_like = (cc_[:, 1] > cc_[:, 2] * 1.02) & (cc_[:, 0] > 0.6)     # the sheet's skin between the cups stays the scan's
    keep_ = ~skin_like
    new_neon = (cc_[:, 0] > 0.8) & (cc_[:, 2] > 0.55) & (cc_[:, 1] < 0.5)
    OUTC[yy_[keep_], xx_[keep_]] = cc_[keep_].astype(np.float32)
    core[yy_, xx_] = False
    core[yy_[new_neon], xx_[new_neon]] = True
    print("projected texels", int(keep_.sum()), "neon", int(new_neon.sum()))
OUTC[core] = P.KEY
# ---- the face: its own pass. The scan's paint unsharpened (eyes, lashes, brows, lips), the art's pink shadow over the wink
head_m = mask & (z_t > K.NECK_Z + 0.04) & (POS[..., 1] > 0.0)
hb = blur(OUTC.mean(2), head_m.astype(np.float32), 4)
OUTC[head_m] = np.clip(OUTC[head_m] + (OUTC.mean(2) - hb)[head_m][:, None] * 1.1, 0, 1)
# the owner's head sheet, front view, projected on the face: eyes (pink glowing under the bolt, blue), brows, nose, grin. Scaled by its eyes and mouth.
HEAD = "/home/boki/meshy/ryzz_f/ryzz_head_nogum.png"      # (the sheet's first version, her grin: the later one paints the bubble, and that is geometry here)
hd_ = imgio.load(HEAD)
HU, HE, HM = 400.8, 746.4, 840.0                 # the sheet's face centre, eye line and mouth line (px, measured)
SU = 125.0 / (2 * EYE_X)                         # its irises are 125 px apart
SV = (HM - HE) / (EYE_Z - MOUTH_Z)
print("head sheet px/m", round(SU), round(SV))
fm = mask & (POS[..., 1] > 0.0) & (NOR[..., 1] > 0.38) & (z_t > K.NECK_Z + 0.04)      # (front-facing only: the sheet has nothing for her cheeks' sides)
yy_, xx_ = np.nonzero(fm)
px_, pz_ = POS[yy_, xx_, 0], z_t[yy_, xx_]
uu_ = HU - px_ * SU
vv_ = HE + (EYE_Z - pz_) * SV
cc_ = bil(hd_, uu_, vv_)
rr_ = np.hypot(px_ / 0.094, (pz_ - (EYE_Z - 0.03)) / 0.125)
# (the sheet's fringe is geometry here, so its blue goes at the edge of the face; inside it, blue is her brows and eye)
not_hair = (cc_[:, 2] < cc_[:, 0] * 1.0) | (rr_ < 0.74)
kk_ = (1 - smooth(0.86, 1.0, rr_)) * not_hair
cc_ = np.clip(cc_ * np.array([0.965, 1.035, 1.04]), 0, 1)       # (the toon light warms skin: the sheet's rose would go red)
OUTC[yy_, xx_] = (OUTC[yy_, xx_] * (1 - kk_[:, None]) + cc_ * kk_[:, None]).astype(np.float32)
hot_ = (cc_[:, 0] > 0.8) & (cc_[:, 2] > 0.6) & (cc_[:, 1] < 0.45) & (kk_ > 0.5)
hot_ &= np.hypot(px_ - EYE_X, pz_ - EYE_Z) > 0.024        # (the pink eye keeps its painted iris; its glow is the bloom on anchor_eye_glow)
core[yy_, xx_] = False
core[yy_[hot_], xx_[hot_]] = True
# the chest bolt from the head sheet (crisp, a bright heart): registered by its own bounds, like the corset
cb = core & (z_t > 1.362) & (z_t < K.NECK_Z) & (np.abs(POS[..., 0]) < 0.05) & (POS[..., 1] > 0.0)      # (above the corset's neckline, below the choker)
hwin = np.zeros(hd_.shape[:2], bool)
hwin[960:1100, 340:470] = True
hn = hwin & (hd_[..., 0] > 0.8) & (hd_[..., 2] > 0.55) & (hd_[..., 1] < 0.5)
hy, hx = np.nonzero(hn)
if cb.sum() > 100 and len(hy) > 100:
    # placed by its centre at the sheet's own scale, the same as her face: it can't stretch
    xc_, zc_ = float(np.median(POS[..., 0][cb])), float(np.median(z_t[cb]))
    hu_, hv_ = float(np.median(hx)), float(np.median(hy))
    rx_, rz_ = 0.052, 0.066
    pb_ = mask & (POS[..., 1] > 0.0) & (np.abs(POS[..., 0] - xc_) < rx_) & (np.abs(z_t - zc_) < rz_)
    yy_, xx_ = np.nonzero(pb_)
    uu_ = hu_ - (POS[yy_, xx_, 0] - xc_) * SU
    vv_ = hv_ + (zc_ - z_t[yy_, xx_]) * SV
    cc_ = bil(hd_, uu_, vv_)
    bd_ = np.minimum(rx_ - np.abs(POS[yy_, xx_, 0] - xc_), rz_ - np.abs(z_t[yy_, xx_] - zc_))
    kb_ = smooth(0.0, 0.014, bd_)[:, None]
    OUTC[yy_, xx_] = (OUTC[yy_, xx_] * (1 - kb_) + cc_ * kb_).astype(np.float32)
    core[yy_, xx_] = (cc_[:, 0] > 0.86) & (cc_[:, 2] > 0.7) & (cc_[:, 1] < 0.42)
    print("chest bolt at", round(xc_, 3), round(zc_, 3), "texels", len(yy_), "glow", int(core[yy_, xx_].sum()))
# a soft edge on the neon: a hard magenta edge rings yellow in the atlas's JPEG
kf_ = np.clip(blur(core.astype(np.float32), mask.astype(np.float32), 2) * 1.5, 0, 1)[..., None]
OUTC = OUTC * (1 - kf_) + P.KEY.astype(np.float32) * kf_
print("face projected", int((kk_ > 0.5).sum()), "glow", int(hot_.sum()))


def paint(pred, fn):
    ids = [i for i, n in enumerate(names) if pred(n)]
    m = np.isin(PID, ids)
    ys, xs = np.nonzero(m)
    if len(ys):
        OUTC[ys, xs] = fn(POS[ys, xs].astype(np.float64), NOR[ys, xs].astype(np.float64), AO[ys, xs].astype(np.float64))


for sd_, sg_ in (("R", 1.0), ("L", -1.0)):
    paint(lambda n, q="lid" + sd_: n == q, lambda p, n, ao, sg=sg_, c=eye_c(sg_): P.lid(p, n, ao, sg, c, LID_A, EYE_Z, EYE_H))
paint(lambda n: n.startswith("palm"), P.glove)
for s in HANDS:
    for pc in HANDS[s]:
        if pc.name.startswith("palm"):
            continue
        if pc.name.startswith(("finger0", "thumb")):
            def fn(p, n, ao, pc=pc):
                c = P.skin(p, n, ao)
                d = np.linalg.norm(p - pc.tip, axis=-1)
                return P.mix(c, P.ramp(P.shade(n, ao), P.COPPER), P.smooth(0.026, 0.023, d)[..., None])
        else:
            def fn(p, n, ao, pc=pc):
                return P.nail(P.skin(p, n, ao), p, pc.tip, pc.dirn, "#e0559c")
        paint(lambda n, q=pc.name: n == q, fn)
paint(lambda n: n == "plate", lambda p, n, ao: P.harness(p, n, ao, plate.rivets))
paint(lambda n: n.startswith("strap"), P.strap)
gc = next(p for p in pieces if p.name == "gum").c
paint(lambda n: n == "gum", lambda p, n, ao: P.gum(p, n, ao, gc))

known = PID >= 0
for _ in range(10):
    acc = np.zeros_like(OUTC)
    cnt = np.zeros((ATLAS, ATLAS), np.float32)
    for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        k = np.roll(known, (dy, dx), (0, 1))
        acc += np.roll(OUTC, (dy, dx), (0, 1)) * k[..., None]
        cnt += k
    new = (~known) & (cnt > 0)
    OUTC[new] = acc[new] / cnt[new][:, None]
    known |= new


def rect(r):
    return int(r[0] * ATLAS), int(r[1] * ATLAS), int(r[2] * ATLAS), int(r[3] * ATLAS)


x0, y0, x1, y1 = rect(K.HAIR_R)
OUTC[y0:y1, x0:x1] = P.hair_tile(y1 - y0, x1 - x0)
x0, y0, x1, y1 = rect(K.COPPER_R)
OUTC[y0:y1, x0:x1] = P.copper_tile(y1 - y0, x1 - x0)
x0, y0, x1, y1 = rect(K.GLOWC_R)
OUTC[y0:y1, x0:x1] = P.hexc("#ff8fd8")
x0, y0, x1, y1 = rect(K.GLOWW_R)
OUTC[y0:y1, x0:x1] = P.hexc("#ffb27e")
x0, y0, x1, y1 = rect(K.BLACK_R)
OUTC[y0:y1, x0:x1] = P.hexc("#2c2733")

atlas = bpy.data.images.new("ryzz_atlas", ATLAS, ATLAS)
px = np.ones((ATLAS, ATLAS, 4), np.float32)
px[..., :3] = np.clip(OUTC, 0, 1)
atlas.pixels.foreach_set(px.ravel())
atlas.filepath_raw = os.path.join(os.path.dirname(OUT), "atlas.png")
atlas.file_format = "PNG"
atlas.save()
print("atlas saved")
for mt in me.materials:
    nt = mt.node_tree
    for nd in list(nt.nodes):
        if nd.type == "TEX_IMAGE":
            nt.nodes.remove(nd)
    t = nt.nodes.new("ShaderNodeTexImage")
    t.image = atlas
    pb = nt.nodes["Principled BSDF"]
    nt.links.new(t.outputs[0], pb.inputs[0])
    pb.inputs["Roughness"].default_value = 0.7
    pb.inputs["Metallic"].default_value = 0.0
attr = me.color_attributes.new("ink", "FLOAT_COLOR", "POINT")
ic = np.ones((len(me.vertices), 4), np.float32)
ic[:, 3] = rooms
attr.data.foreach_set("color", ic.ravel())
me.color_attributes.active_color = attr

# ---- a relief normal map from the paint (leather grain, pleats, stitches, rivets; the skin stays smooth). hero_toon use_nrm
lum_ = np.clip(OUTC, 0, 1).mean(2)
paintm = (PID >= 0).astype(np.float32)
hp = blur(lum_, paintm, 1) - blur(lum_, paintm, 10)
skinish = (OUTC[..., 0] > OUTC[..., 1] * 1.15) & (lum_ > 0.42) & (OUTC[..., 2] < OUTC[..., 1] * 1.1)
hp = hp * (~skinish) * paintm * (POS[..., 2] < K.NECK_Z + 0.03)
dx = np.roll(hp, -1, 1) - np.roll(hp, 1, 1)
dy = np.roll(hp, -1, 0) - np.roll(hp, 1, 0)
NK = 5.0
nm_ = np.stack([-dx * NK, -dy * NK, np.ones_like(hp)], -1)
nm_ /= np.linalg.norm(nm_, axis=-1, keepdims=True)
nimg = bpy.data.images.new("ryzz_nrm", ATLAS, ATLAS)
nimg.colorspace_settings.name = "Non-Color"
pxn = np.ones((ATLAS, ATLAS, 4), np.float32)
pxn[..., :3] = nm_ * 0.5 + 0.5
nimg.pixels.foreach_set(pxn.ravel())
nimg.filepath_raw = os.path.join(os.path.dirname(OUT), "nrm.png")
nimg.file_format = "PNG"
nimg.save()
for mt in me.materials:
    if mt.name.startswith(("leather", "metal")):
        nt = mt.node_tree
        ti = nt.nodes.new("ShaderNodeTexImage")
        ti.image = nimg
        nmn = nt.nodes.new("ShaderNodeNormalMap")
        nt.links.new(ti.outputs[0], nmn.inputs[1])
        nt.links.new(nmn.outputs[0], nt.nodes["Principled BSDF"].inputs["Normal"])

# ---- armature
rig = json.load(open(RIG))
arm = WK.build_armature(rig)
bpy.context.view_layer.objects.active = arm
bpy.ops.object.mode_set(mode="EDIT")
eb = arm.data.edit_bones


def bone(name, parent, head, tail):
    e = eb.new(name)
    e.head, e.tail = Vector(tuple(head)), Vector(tuple(tail))
    e.parent = eb[parent]
    e.use_connect = False
    return e


for s, side in ((1.0, "R"), (-1.0, "L")):
    c = eye_c(s)
    bone("lid." + side, "head", c, c + np.array([0, 0.03, 0]))
    b = DEFORM["brow." + side][0]
    bone("brow." + side, "head", b, b + np.array([0, 0.03, 0]))
    m_ = DEFORM["mouth." + side][0]
    bone("mouth." + side, "head", m_, m_ + np.array([0, 0.02, 0]))
    ax = np.array([s * K.SH, 0.0, 0.0])
    hd = np.array([s * 0.085, 0.0, K.ANKLE_Z])
    bone("foot." + side, "shin." + side, hd, hd + [0, 0.12, 0])
    fs = HANDS[s]
    f0 = next(p for p in fs if p.name.startswith("finger0"))
    bs = f0.base
    bone("index." + side, "hand." + side, bs, bs + [0, 0, -K.FINGER_L[0][0] * K.HAND_K])
    m2 = bs + [0, 0, -K.FINGER_L[0][0] * K.HAND_K]
    bone("index2." + side, "index." + side, m2, m2 + [0, 0, -0.05])
    f2 = next(p for p in fs if p.name.startswith("finger2"))
    bone("curl." + side, "hand." + side, f2.base, f2.base + [0, 0, -K.FINGER_L[2][0] * K.HAND_K])
    m3 = f2.base + [0, 0, -K.FINGER_L[2][0] * K.HAND_K]
    bone("curl2." + side, "curl." + side, m3, m3 + [0, 0, -0.05])
    tp = next(p for p in fs if p.name.startswith("thumb"))
    tb = K.wrist_at(s) + np.array([0, 0.040, -0.030]) * K.HAND_K
    bone("thumb." + side, "hand." + side, tb, tb + (tp.tip - tb) * 0.8)
    nms, chain = CH[s]
    prev = "head"
    for i, nm in enumerate(nms):
        bone(nm, prev, chain[i], chain[i + 1])
        prev = nm
gc_ = MOUTH_C + np.array([0, 0.008, 0])
bone("gum", "head", gc_, gc_ + [0, 0.06, 0])
for i, (ra, rb, rd) in enumerate(RODB):
    bone("rod.%d" % i, "hips", ra, rb)
    bone("rodlit.%d" % i, "rod.%d" % i, ra, rb)
arc_c = np.array([0.0, -0.32, 1.86])
bone("arc.0", "hips", arc_c, arc_c + [0, 0, 0.05])
bone("arc.1", "hips", arc_c, arc_c + [0, 0, 0.05])
bpy.ops.object.mode_set(mode="OBJECT")
ob.parent = arm
md = ob.modifiers.new("arm", "ARMATURE")
md.object = arm
for vi, d in enumerate(vw):
    tot = sum(d.values())
    for b, w in d.items():
        g = ob.vertex_groups.get(b) or ob.vertex_groups.new(name=b)
        g.add([vi], w / tot if tot > 0 else 0, "REPLACE")

# ---- anchors and FX points: empties on the bones. S3/S4 read these.
A = {"anchor_head_top": ("head", (0, 0.0, K.C[2] + 0.12)), "anchor_chest": ("hips", (0, 0.13, K.SHOULDER_Z - 0.06)),
     "anchor_harness": ("hips", (0, back_y(0, 1.28) - 0.03, 1.28)), "anchor_gum": ("gum", tuple(gum_c))}
for s, side in ((1.0, "R"), (-1.0, "L")):
    fs = HANDS[s]
    f0 = next(p for p in fs if p.name.startswith("finger0"))
    A[("weapon_muzzle" if s > 0 else "anchor_finger_L")] = ("index2." + side, tuple(f0.tip + f0.dirn * 0.012))
    A["anchor_gun_" + side] = ("hand." + side, tuple(f0.base))
    A["anchor_wire_" + side] = ("hand." + side, tuple(K.wrist_at(s) + [s * 0.024, 0.0, -0.02]))
    tp = next(p for p in fs if p.name.startswith("thumb"))
    A["anchor_thumb_" + side] = ("thumb." + side, tuple(tp.tip + tp.dirn * 0.01))
A["anchor_eye_glow"] = ("head", (EYE_X, front_y(EYE_X, EYE_Z) + 0.004, EYE_Z))
for i, (ra, rb, rd) in enumerate(RODB):
    A["anchor_rod_%d" % i] = ("rod.%d" % i, tuple(rb + rd * 0.015))
for nm, (bn, at) in A.items():
    e = bpy.data.objects.new(nm, None)
    bpy.context.scene.collection.objects.link(e)
    e.parent = arm
    e.parent_type = "BONE"
    e.parent_bone = bn
    e.matrix_world = Matrix.Translation(at)

json.dump({"rods": [[list(map(float, r[0])), list(map(float, r[1]))] for r in RODB]}, open(os.path.splitext(OUT)[0] + "_data.json", "w"))
me.polygons.foreach_set("use_smooth", [True] * len(me.polygons))
me.update()
bpy.ops.wm.save_as_mainfile(filepath=os.path.splitext(OUT)[0] + ".blend")
objs = [arm, ob] + [o for o in bpy.data.objects if o.type == "EMPTY"]
for o in list(bpy.data.objects):
    if o.name in ("Src", "Low"):
        bpy.data.objects.remove(o)
WK.export(OUT, objs, image_format="JPEG", colors=True)
print("exported", OUT, os.path.getsize(OUT))
