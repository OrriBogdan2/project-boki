"""ART-1 Vex v2, stage C (recipe: kael_finish.py): join, unwrap, paint, skin, export. Six slots: skin-vex, cloth-vex, leather-vex, metal-vex, brass-vex,
hair-mane. Nothing glows (v2: no glowing lines, the mechanical eye is marked by its brass wire only).
Run: blender -b --factory-startup --python tools/art1/vex_finish.py -- <source.blend> <rig.json> <out.glb>"""
import sys, os, json, math
import bpy, bmesh
import numpy as np
from mathutils import Vector, Matrix
from mathutils.bvhtree import BVHTree
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, "..", "blender"))
import meshkit as M, vex_parts as VP, vex_cannon as VC, vex_head as VH, vex_arm as VA, vex_paint as P
from paintkit import ramp, hexc, mix, lit
from meshkit import smooth
import warden_kit as WK

a = sys.argv[sys.argv.index("--") + 1:]
SRC, RIG, OUT = a[0], a[1], a[2]
ATLAS = 2048
RAW = os.path.expanduser(os.environ.get("VEX_RAW", "~/meshy/vex_v2"))      # the Meshy run (never in git)
UNIQ_W = 0.755
HAIR_R = (UNIQ_W + 0.005, 0.40, 1.0, 1.0)
BELT_R = (UNIQ_W + 0.005, 0.30, 1.0, 0.395)
MATS = ["skin-vex", "cloth-vex", "leather-vex", "metal-vex", "brass-vex", "hair-mane"]
SCALE = {"hscan": 2.4, "lidU": 2.2, "Low": 1.75, "cuff": 1.6, "receiver": 1.6, "drum": 1.6}

bpy.ops.wm.open_mainfile(filepath=SRC)
src, low = bpy.data.objects["Src"], bpy.data.objects["Low"]
dg = bpy.context.evaluated_depsgraph_get()
bvh_src = BVHTree.FromObject(src, dg)
bvh_low = BVHTree.FromObject(low, dg)
hsrc, hlow = bpy.data.objects["HeadSrc"], bpy.data.objects["HeadLow"]
bvh_hs = BVHTree.FromObject(hsrc, dg)
parts = VP.build(bvh_src, bvh_low, bvh_hs)
pieces = parts["pieces"]
# the head scan as a piece, its faces sorted to slots by paint below
hv = np.array([tuple(v.co) for v in hlow.data.vertices])
gn_ = {g.index: g.name for g in hlow.vertex_groups}
hw = {"head": np.zeros(len(hv)), "hips": np.zeros(len(hv))}
for i_, v_ in enumerate(hlow.data.vertices):
    for g_ in v_.groups:
        hw[gn_[g_.group]][i_] = g_.weight
hscan = M.Piece("hscan", "skin-vex", hv, [list(p.vertices) for p in hlow.data.polygons], weights=hw, room=0.2)
pieces.insert(0, hscan)
for p_ in parts["braid"]:
    t_ = getattr(p_, "t", None)
    p_.shade = np.full(len(p_.v), 0.85) if t_ is None else (0.74 + 0.26 * smooth(0.0, 0.22, t_))


def is_tile(n):
    return n.startswith(("braid", "btip", "ammo")) and not n.startswith("braidtie")


def slot_of(pm):
    return {"metal-belt": "metal-vex"}.get(pm, pm)


# ---- one mesh
faces_v, faces_pid, faces_uv, verts, vw, rooms, shades, names = [], [], [], [], [], [], [], []
names.append("Low")
me0 = low.data
verts.extend([tuple(v.co) for v in me0.vertices])
gn = {g.index: g.name for g in low.vertex_groups}
for v in me0.vertices:
    vw.append({gn[g.group]: g.weight for g in v.groups if g.weight > 0.01})
rooms.extend([1.0] * len(me0.vertices))
shades.extend([1.0] * len(me0.vertices))
for p in me0.polygons:
    faces_v.append(list(p.vertices))
    faces_pid.append(0)
    faces_uv.append(None)
for pc in pieces:
    pid = len(names)
    names.append(pc.name)
    base = len(verts)
    verts.extend([tuple(v) for v in pc.v])
    for i in range(len(pc.v)):
        vw.append({b: float(arr[i]) for b, arr in pc.w.items() if arr[i] > 0.005})
    rooms.extend([pc.room] * len(pc.v))
    shades.extend(getattr(pc, "shade", np.ones(len(pc.v))).tolist())
    for j, f in enumerate(pc.f):
        faces_v.append([base + i for i in f])
        faces_pid.append(pid)
        faces_uv.append(pc.uv[j] if pc.uv is not None else None)
me = bpy.data.meshes.new("Body")
me.from_pydata(verts, [], faces_v)
me.polygons.foreach_set("use_smooth", [True] * len(me.polygons))
me.update()
ob = bpy.data.objects.new("Body", me)
bpy.context.scene.collection.objects.link(ob)
for m in MATS:
    mt = bpy.data.materials.new(m)
    mt.use_nodes = True
    me.materials.append(mt)
uv = me.uv_layers.new(name="UV")
nf = len(me.polygons)
print("tris", sum(len(p.vertices) - 2 for p in me.polygons), "verts", len(me.vertices))
mat_i = {m: i for i, m in enumerate(MATS)}
PIECE_MAT = {pc.name: slot_of(pc.mat) for pc in pieces}
for i, p in enumerate(me.polygons):
    n = names[faces_pid[i]]
    p.material_index = mat_i[PIECE_MAT[n]] if n != "Low" else 0

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
uvl = bm.loops.layers.uv["UV"]
PARTS = {"upper_arm.L": "armL", "forearm.L": "armL", "hand.L": "armL", "thigh.R": "legR", "shin.R": "legR", "foot.R": "legR", "thigh.L": "legL", "shin.L": "legL", "foot.L": "legL"}
region = {}
for i in range(nf):
    if faces_pid[i] != 0:
        continue
    tally = {}
    for vi in faces_v[i]:
        for b, w_ in vw[vi].items():
            p_ = PARTS.get(b, "torso")
            tally[p_] = tally.get(p_, 0) + w_
    part = max(tally, key=tally.get) if tally else "torso"
    c = np.mean([verts[v] for v in faces_v[i]], axis=0)
    region[i] = (part, c[1] > -0.01)
for e in bm.edges:
    lf = [f.index for f in e.link_faces]
    if len(lf) == 2 and lf[0] in region and lf[1] in region:
        e.seam = region[lf[0]] != region[lf[1]]
for f in bm.faces:
    f.select = f.index in region
bmesh.update_edit_mesh(me)
bpy.ops.uv.unwrap(method="ANGLE_BASED", margin=0.0)
bm = bmesh.from_edit_mesh(me)
bm.faces.ensure_lookup_table()
uvl = bm.loops.layers.uv["UV"]
stats = {}
for i in uniq:
    n = names[faces_pid[i]]
    if i in region:
        n = n + region[i][0]
    f = bm.faces[i]
    pts = [l[uvl].uv.copy() for l in f.loops]
    a2 = 0.0
    for k in range(1, len(pts) - 1):
        a2 += abs((pts[k] - pts[0]).cross(pts[k + 1] - pts[0])) * 0.5
    s = stats.setdefault(n, [0.0, 0.0])
    s[0] += f.calc_area()
    s[1] += a2
for i in uniq:
    n = names[faces_pid[i]]
    k = n.rstrip("RL0123456789_")
    wgt = SCALE.get(k, 0.7)
    if i in region:
        n = n + region[i][0]
    s = wgt * math.sqrt(stats[n][0] / max(stats[n][1], 1e-12))
    for l in bm.faces[i].loops:
        l[uvl].uv = l[uvl].uv * s
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
for p in me.polygons:
    i = p.index
    n = names[faces_pid[i]]
    ls = list(p.loop_indices)
    if not is_tile(n):
        loop_uv[ls, 0] *= UNIQ_W
        continue
    fu = faces_uv[i]
    r = BELT_R if n.startswith("ammo") else HAIR_R
    if fu is None:
        for l in ls:
            loop_uv[l] = ((r[0] + r[2]) / 2, (r[1] + r[3]) / 2)
        continue
    for l, (x, y) in zip(ls, fu):
        loop_uv[l] = (r[0] + (r[2] - r[0]) * x, r[1] + (r[3] - r[1]) * y)
uvd.foreach_set("uv", loop_uv.ravel())
me.update()

# ---- texel maps
me.calc_loop_triangles()
vco = np.array(verts)
vn = np.zeros(len(me.vertices) * 3)
me.vertices.foreach_get("normal", vn)
vn = vn.reshape(-1, 3)
PID = -np.ones((ATLAS, ATLAS), np.int32)
FACEI = -np.ones((ATLAS, ATLAS), np.int32)
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
    POS[ys[m], xs[m]] = w @ vco[tv]
    NOR[ys[m], xs[m]] = w @ vn[tv]
    PID[ys[m], xs[m]] = faces_pid[t.polygon_index]
    FACEI[ys[m], xs[m]] = t.polygon_index
NOR = M.norm(NOR)
print("texels", (PID >= 0).sum(), "of", ATLAS * ATLAS)

# ---- AO
ao_img = bpy.data.images.new("ao", ATLAS, ATLAS, float_buffer=True)
sc = bpy.context.scene
sc.render.engine = "CYCLES"
sc.cycles.device = "CPU"
sc.cycles.samples = 32
sc.render.bake.margin = 6
sc.render.bake.use_clear = True
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
st = sm.loop_triangles
svco = np.zeros(len(sm.vertices) * 3)
sm.vertices.foreach_get("co", svco)
svco = svco.reshape(-1, 3)
tri_v = np.array([t.vertices[:] for t in st])
tri_l = np.array([t.loops[:] for t in st])
suv = np.zeros(len(sm.loops) * 2)
sm.uv_layers.active.data.foreach_get("uv", suv)
suv = suv.reshape(-1, 2)
tree = BVHTree.FromPolygons([tuple(v) for v in svco], [tuple(t) for t in tri_v])
im = None
for mt in sm.materials:
    pb_ = next(n_ for n_ in mt.node_tree.nodes if n_.type == "BSDF_PRINCIPLED")
    lk = pb_.inputs[0].links
    nd = lk[0].from_node if lk else None
    while nd is not None and nd.type != "TEX_IMAGE":
        nd = nd.inputs[0].links[0].from_node if nd.inputs and nd.inputs[0].links else None
    if nd is not None:
        im = nd.image
sw, sh = im.size
SP = np.zeros(sw * sh * im.channels, np.float32)
im.pixels.foreach_get(SP)
SP = SP.reshape(sh, sw, im.channels)[..., :3]
print("source atlas", im.name, sw, sh, SP.mean())


def sample_scan(points):
    hit_i = np.zeros(len(points), np.int64)
    hit_p = np.zeros((len(points), 3))
    for i, p in enumerate(points):
        h = tree.find_nearest(Vector(p))
        if h[2] is not None:
            hit_i[i] = h[2]
            hit_p[i] = h[0]
    tv = svco[tri_v[hit_i]]
    v0 = tv[:, 1] - tv[:, 0]
    v1 = tv[:, 2] - tv[:, 0]
    v2 = hit_p - tv[:, 0]
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
    LAST[:] = [sx, sy]
    return SP[sy, sx]


LAST = [None, None]
NRM = P.imgio.load(os.path.join(RAW, "runA", "tex0_normal.png"))[::-1]
print("normal map", NRM.shape)


Z_BELT = VC.J("hips")[2] + 0.02
Z_BOOT = VC.J("shin.R")[2] - 0.22          # below this: the boots
low_faces = [i for i in range(nf) if faces_pid[i] == 0]
fc = np.array([np.mean([verts[v] for v in faces_v[i]], axis=0) for i in low_faces])
fcol = sample_scan(fc)
L_ = fcol.mean(1)
sat = (fcol.max(1) - fcol.min(1)) / np.maximum(fcol.max(1), 0.01)
# a face with any skin at its corners is skin
cs_ = [sample_scan(np.array([verts[faces_v[i][q_ % len(faces_v[i])]] for i in low_faces])) for q_ in (0, 1, 2)]
skinny = np.any([(c_x[:, 0] > c_x[:, 1] * 1.1) & (c_x[:, 0] < c_x[:, 1] * 1.6) & (c_x.mean(1) > 0.36) for c_x in cs_], axis=0)
for k_, i in enumerate(low_faces):
    r_, g_, b_ = fcol[k_]
    z = fc[k_][2]
    if skinny[k_] and sat[k_] > 0.05:
        m = "skin-vex"
    elif g_ > r_ * 1.08 and g_ > b_ * 1.2:
        m = "cloth-vex"              # the jacket; below the belt, the trousers' paint splatter
    elif sat[k_] < 0.16 and L_[k_] > 0.42:
        m = "metal-vex"
    elif r_ > g_ * 1.6 and z > Z_BELT:
        m = "cloth-vex"              # the jacket's red trim and orange stripes
    elif r_ > g_ * 1.08 and L_[k_] > 0.3:
        m = "skin-vex"
    elif z < Z_BOOT:
        m = "leather-vex"
    else:
        m = "cloth-vex"
    me.polygons[i].material_index = mat_i[m]

mask = PID == 0
ys, xs = np.nonzero(mask)
col = sample_scan(POS[ys, xs])
# the scan's high detail (seams, stitching, panel lines) painted in as cavity: hero_toon has no normal-map path
sx_, sy_ = LAST
nz_ = NRM[(sy_ * NRM.shape[0] // sh), (sx_ * NRM.shape[1] // sw), 2]
cav = np.clip(1.0 - 2.4 * np.clip(0.93 - nz_, 0, 0.45), 0.45, 1.0)[:, None]
col = np.power(np.clip(col, 0, 1), 0.88) * 1.1 * cav
dk = (col.max(1) < 0.2)[:, None]
col = col * (1 - dk) + (col * 1.3 + np.array([0.08, 0.08, 0.09])) * dk
OUTC = np.zeros((ATLAS, ATLAS, 3), np.float32)
OUTC[ys, xs] = col
OUTC[ys, xs] *= (0.66 + 0.34 * np.clip(AO[ys, xs], 0, 1))[:, None]

# (a back-cut face is skin whatever the scan's black said)
for k_, i in enumerate(low_faces):
    q_ = fc[k_]
    if q_[1] < -0.0 and Z_BELT + 0.012 < q_[2] < VC.J("upper_arm.R")[2] - 0.03 and abs(q_[0]) < 0.2 and not (fcol[k_][1] > fcol[k_][0] * 1.02 and L_[k_] > 0.34):
        me.polygons[i].material_index = mat_i["skin-vex"]

def paint(pred, fn):
    ids = [i for i, n in enumerate(names) if pred(n)]
    m = np.isin(PID, ids)
    ys_, xs_ = np.nonzero(m)
    if len(ys_):
        OUTC[ys_, xs_] = fn(POS[ys_, xs_].astype(np.float64), NOR[ys_, xs_].astype(np.float64), AO[ys_, xs_].astype(np.float64))


# the head: its own scan's paint, at high density; slots by that paint
hid = names.index("hscan")
hm = hsrc.data
hm.calc_loop_triangles()
hst = hm.loop_triangles
hco = np.zeros(len(hm.vertices) * 3)
hm.vertices.foreach_get("co", hco)
hco = hco.reshape(-1, 3)
htv = np.array([t.vertices[:] for t in hst])
htl = np.array([t.loops[:] for t in hst])
huv = np.zeros(len(hm.loops) * 2)
hm.uv_layers.active.data.foreach_get("uv", huv)
huv = huv.reshape(-1, 2)
htree = BVHTree.FromPolygons([tuple(v) for v in hco], [tuple(t) for t in htv])
him = next(n_.image for mt in hm.materials for n_ in mt.node_tree.nodes if n_.type == "TEX_IMAGE" and "ase" in (n_.image.name + "ase"))
for mt in hm.materials:
    pb_ = next(n_ for n_ in mt.node_tree.nodes if n_.type == "BSDF_PRINCIPLED")
    nd = pb_.inputs[0].links[0].from_node if pb_.inputs[0].links else None
    while nd is not None and nd.type != "TEX_IMAGE":
        nd = nd.inputs[0].links[0].from_node if nd.inputs and nd.inputs[0].links else None
    if nd is not None:
        him = nd.image
hw_, hh_ = him.size
HP = np.zeros(hw_ * hh_ * him.channels, np.float32)
him.pixels.foreach_get(HP)
HP = HP.reshape(hh_, hw_, him.channels)[..., :3]


def sample_head(points):
    hi = np.zeros(len(points), np.int64)
    hp = np.zeros((len(points), 3))
    for i, p in enumerate(points):
        h = htree.find_nearest(Vector(p))
        if h[2] is not None:
            hi[i], hp[i] = h[2], h[0]
    tv = hco[htv[hi]]
    v0, v1, v2 = tv[:, 1] - tv[:, 0], tv[:, 2] - tv[:, 0], hp - tv[:, 0]
    d00, d01, d11 = (v0 * v0).sum(1), (v0 * v1).sum(1), (v1 * v1).sum(1)
    d20, d21 = (v2 * v0).sum(1), (v2 * v1).sum(1)
    den = np.maximum(d00 * d11 - d01 * d01, 1e-14)
    bv, bw = (d11 * d20 - d01 * d21) / den, (d00 * d21 - d01 * d20) / den
    bu = 1 - bv - bw
    luv = huv[htl[hi]]
    uu = bu * luv[:, 0, 0] + bv * luv[:, 1, 0] + bw * luv[:, 2, 0]
    vv = bu * luv[:, 0, 1] + bv * luv[:, 1, 1] + bw * luv[:, 2, 1]
    return HP[np.clip((vv % 1) * hh_, 0, hh_ - 1).astype(int), np.clip((uu % 1) * hw_, 0, hw_ - 1).astype(int)]


hfaces = [i for i in range(nf) if faces_pid[i] == hid]
hfc = np.array([np.mean([verts[v] for v in faces_v[i]], axis=0) for i in hfaces])
hcol = sample_head(hfc)
for k_, i in enumerate(hfaces):
    r_, g_, b_ = hcol[k_]
    l_ = (r_ + g_ + b_) / 3
    st_ = (max(r_, g_, b_) - min(r_, g_, b_)) / max(max(r_, g_, b_), 0.01)
    if g_ > r_ * 1.12 and g_ > b_ * 1.04:
        m = "hair-mane"
    elif st_ < 0.13:
        m = "metal-vex"
    elif r_ > g_ * 1.2 and g_ > b_ * 1.45:
        m = "brass-vex"
    elif l_ < 0.3:
        m = "leather-vex"
    else:
        m = "skin-vex"
    me.polygons[i].material_index = mat_i[m]
m = PID == hid
ys_, xs_ = np.nonzero(m)
hc = sample_head(POS[ys_, xs_])
hc = np.clip(hc, 0, 1)
gr_ = (hc[:, 1] > hc[:, 0] * 1.12) & (hc[:, 1] > hc[:, 2] * 1.04)
g0_ = hc[gr_].mean(1, keepdims=True)
hc[gr_] = np.clip((g0_ + (hc[gr_] - g0_) * 1.35) * np.array([1.25, 1.32, 1.25]) + np.array([0.02, 0.04, 0.03]), 0, 1)             # the sheet's teal-green hair, a touch more colour under the toon light
skn_ = (hc[:, 0] > hc[:, 1] * 1.1) & (hc[:, 0] < hc[:, 1] * 1.7) & (hc.mean(1) > 0.22)
hc[skn_] = np.clip(hc[skn_] * np.array([1.3, 1.24, 1.2]), 0, 1)
OUTC[ys_, xs_] = hc * (0.84 + 0.16 * np.clip(AO[ys_, xs_], 0, 1))[:, None]
# the body's skin: clean and warm (the scan's is pale and mottled); the trousers: the sheet's charcoal, not black
fm0 = np.array([p.material_index for p in me.polygons])
TMAT = np.where(FACEI >= 0, fm0[np.maximum(FACEI, 0)], -1)
skin_t = mask & (TMAT == mat_i["skin-vex"])
OUTC = P.clean_skin(OUTC, skin_t, blur)
pants = mask & (POS[..., 2] < Z_BELT) & (POS[..., 2] > Z_BOOT) & (OUTC.max(2) < 0.32) & ~((OUTC[..., 1] > OUTC[..., 0] * 1.2) & (OUTC[..., 1] > 0.25))
OUTC[pants] = OUTC[pants] * 1.2 + np.array([0.075, 0.07, 0.055], np.float32)
# the jacket: her lime green, the scan's paint washed it out
c0_ = OUTC
jm = mask & (POS[..., 2] > Z_BELT) & (c0_[..., 1] > c0_[..., 0] * 1.02) & (c0_[..., 1] > c0_[..., 2] * 1.12) & (c0_.mean(2) > 0.2) & (c0_[..., 1] < c0_[..., 0] * 1.6)
g_ = OUTC[jm].mean(1, keepdims=True)
OUTC[jm] = np.clip((g_ + (OUTC[jm] - g_) * 1.4) * np.array([0.98, 1.08, 0.82], np.float32), 0, 1)

SKIN = lambda p, n, ao: ramp(np.clip(lit(n, ao) * 1.05, 0, 1), [hexc("#8c5a5c"), hexc("#c58a84"), hexc("#e5ac9f"), hexc("#f3c9bb"), hexc("#fde4d7")])
paint(lambda n: n == "lidUL", lambda p, n, ao: mix(SKIN(p, n, ao), hexc("#2a2024"), smooth(0.9, 0.78, np.arctan2(p[..., 2] - parts["lid_c"][2], p[..., 1] - parts["lid_c"][1]))))
paint(lambda n: n.startswith("ebrow"), lambda p, n, ao: np.broadcast_to(hexc("#2b3a35"), p.shape).copy())
paint(lambda n: n in ("cuff", "receiver", "drum"), P.gun_brass)
paint(lambda n: n in ("bullet", "coin", "wristband", "robopanel", "robofore", "palm", "thumbL", "elbowball") or n.startswith(("braidtie", "hipcoin", "finger")), P.brass)
paint(lambda n: n.startswith(("boss", "gcollar", "gspindle", "gband", "barrel", "drumface", "chain")), P.steel)
paint(lambda n: n.startswith(("elbowcap", "fpad", "thumbpad")), lambda p, n, ao: P.steel(p, n, ao, P.BLACKM))
paint(lambda n: n == "gren0", lambda p, n, ao: ramp(np.clip(lit(n, ao) * 1.12, 0, 1), [hexc("#2c3a14"), hexc("#55702a"), hexc("#86a843"), hexc("#b9d77a")]))

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


x0, y0, x1, y1 = rect(HAIR_R)
OUTC[y0:y1, x0:x1] = P.hair_tile(y1 - y0, x1 - x0)
x0, y0, x1, y1 = rect(BELT_R)
OUTC[y0:y1, x0:x1] = P.belt_tile(y1 - y0, x1 - x0)

atlas = bpy.data.images.new("vex_atlas", ATLAS, ATLAS)
px = np.ones((ATLAS, ATLAS, 4), np.float32)
px[..., :3] = np.clip(OUTC, 0, 1)
atlas.pixels.foreach_set(px.ravel())
atlas.filepath_raw = os.path.join(os.path.dirname(OUT), "atlas.png")
atlas.file_format = "PNG"
atlas.save()

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
ic[:, 0] = ic[:, 1] = ic[:, 2] = shades
attr.data.foreach_set("color", ic.ravel())
me.color_attributes.active_color = attr

# ---- the normal map: the scans' detail on the shipped mesh; rebuilt pieces stay flat
nrm_img = bpy.data.images.new("vex_normal", ATLAS, ATLAS)
nrm_img.colorspace_settings.name = "Non-Color"
for mt in me.materials:
    nt = mt.node_tree
    n_ = nt.nodes.new("ShaderNodeTexImage")
    n_.image = nrm_img
    nt.nodes.active = n_
sc.cycles.samples = 4
sc.render.bake.use_selected_to_active = True
sc.render.bake.cage_extrusion = 0.014
sc.render.bake.max_ray_distance = 0.03
sc.render.bake.normal_space = "TANGENT"
for o in bpy.data.objects:
    o.select_set(False)
src.hide_render = hsrc.hide_render = False
src.select_set(True)
hsrc.select_set(True)
ob.select_set(True)
bpy.context.view_layer.objects.active = ob
bpy.ops.object.bake(type="NORMAL", use_clear=True, margin=6)
NR = np.array(nrm_img.pixels[:], dtype=np.float32).reshape(ATLAS, ATLAS, 4)[..., :3]
flat = ~((PID == 0) | (PID == names.index("hscan")))
NR[flat] = (0.5, 0.5, 1.0)
px_n = np.ones((ATLAS, ATLAS, 4), np.float32)
px_n[..., :3] = NR
nrm_img.pixels.foreach_set(px_n.ravel())
nrm_img.filepath_raw = os.path.join(os.path.dirname(OUT), "normal.png")
nrm_img.file_format = "PNG"
nrm_img.save()
ob.select_set(True)
for mt in me.materials:
    nt = mt.node_tree
    n_ = next(q for q in nt.nodes if q.type == "TEX_IMAGE" and q.image is nrm_img)
    nm_ = nt.nodes.new("ShaderNodeNormalMap")
    nt.links.new(n_.outputs[0], nm_.inputs["Color"])
    nt.links.new(nm_.outputs[0], nt.nodes["Principled BSDF"].inputs["Normal"])
print("normal baked")

# ---- armature
rig = json.load(open(RIG))
arm = WK.build_armature(rig)
bpy.context.view_layer.objects.active = arm
bpy.ops.object.mode_set(mode="EDIT")
eb = arm.data.edit_bones


def bone(name, parent, head, tail):
    e = eb.new(name)
    e.head, e.tail = Vector(head), Vector(tail)
    e.parent = eb[parent]
    e.use_connect = False
    return e


def spring(names_, pts, parent):
    prev = parent
    for i, n in enumerate(names_):
        p = Vector(pts[i])
        q = Vector(pts[i + 1]) if i + 1 < len(pts) else p + (p - Vector(pts[i - 1]))
        bone(n, prev, p, q)
        prev = n


L0 = parts["lid_c"]
bone("lid.L", "head", L0, L0 + np.array([0, 0.03, 0]))
for s, side in ((1.0, "R"), (-1.0, "L")):
    b = np.array([s * 0.05, VH.EYE_FRONT_Y[0], VH.EYE_Z + 0.03])
    bone("brow." + side, "head", b, b + [0, 0.03, 0])
for sd, sx in (("R", 1.0), ("L", -1.0)):
    th = VC.J("shin." + sd)
    hd = np.array([th[0], 0.0, 0.16])
    bone("foot." + sd, "shin." + sd, hd, hd + [0, 0.12, 0])
kn = VA.WR + np.array([0, 0, -0.082])
bone("fingers.L", "hand.L", kn, kn + [0, 0, -0.06])
th_ = VA.WR + np.array([0, 0.04, -0.024])
bone("thumb.L", "hand.L", th_, th_ + [0, 0.02, -0.05])
bone("coin", "hand.L", parts["coin"], parts["coin"] + np.array([0, 0, 0.04]))
LP = VC.C(VC.PIVOT_S, 0, VC.DRUM_F)
bone("launcher", "forearm.R", LP, LP + np.array([0, 0, 0.1]))
GP = VC.C(VC.REC_S1, 0, VC.GATLING_F)
bone("gatling", "forearm.R", GP, GP + np.array([0, 0, -0.1]))
spring(parts["bnames"], [tuple(p) for p in parts["bpts"]], "head")
bpy.ops.object.mode_set(mode="OBJECT")
ob.parent = arm
md = ob.modifiers.new("arm", "ARMATURE")
md.object = arm
for vi, d in enumerate(vw):
    tot = sum(d.values())
    for b, w in d.items():
        g = ob.vertex_groups.get(b) or ob.vertex_groups.new(name=b)
        g.add([vi], w / tot if tot > 0 else 0, "REPLACE")

# ---- FX points (the mechanical eye is her left: the brass wire's)
EYE_M = tuple(VH.surf(bvh_hs, -VH.EYE_X * VH.SK * 0.95, VH.EYE_Z, 0.006))
A = dict(VC.empties())
A.update({"anchor_head_top": ("head", (0, VH.HC[1], VH.TOP + 0.03)), "anchor_chest": ("hips", (0, 0.12, VC.J("upper_arm.R")[2] - 0.1)),
          "anchor_eye_glow": ("head", EYE_M), "anchor_lens": ("head", EYE_M),
          "anchor_spine": ("hips", (0, -0.14, VC.J("upper_arm.R")[2] - 0.2)), "anchor_coin": ("coin", tuple(parts["coin"])),
          "anchor_left_hand": ("hand.L", tuple(VA.WR + np.array([0, 0, -0.1]))), "palm_emitter": ("hand.L", tuple(VA.WR + np.array([0.04, 0, -0.075]))), "anchor_pack": ("hips", (-0.1, -0.13, VC.J("upper_arm.R")[2] - 0.05))})
for nm, (bn, at) in A.items():
    e = bpy.data.objects.new(nm, None)
    bpy.context.scene.collection.objects.link(e)
    e.parent = arm
    e.parent_type = "BONE"
    e.parent_bone = bn
    e.matrix_world = Matrix.Translation(at)

me.polygons.foreach_set("use_smooth", [True] * len(me.polygons))
me.update()
for o in list(bpy.data.objects):
    if o.name in ("Src", "Low", "HeadSrc", "HeadLow"):
        bpy.data.objects.remove(o)
bpy.ops.wm.save_as_mainfile(filepath=os.path.splitext(OUT)[0] + ".blend")
objs = [arm, ob] + [o for o in bpy.data.objects if o.type == "EMPTY"]
WK.export(OUT, objs, image_format="JPEG", colors=True)
print("exported", OUT, os.path.getsize(OUT))
