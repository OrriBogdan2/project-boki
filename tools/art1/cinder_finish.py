"""ART-1 Cinder, stage C: join, unwrap, paint, skin, export. The recipe is kael_finish.py's; fire is strips with raw UV (no atlas).
Run: blender -b --factory-startup --python tools/art1/cinder_finish.py -- <source.blend> <rig.json> <out.glb> <face plate.png>"""
import sys, os, json, math
import bpy, bmesh
import numpy as np
from mathutils import Vector, Matrix
from mathutils.bvhtree import BVHTree
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, "..", "blender"))
import meshkit as M, cinder_pieces as K, cinder_paint as P
from meshkit import smooth
import warden_kit as WK

a = sys.argv[sys.argv.index("--") + 1:]
SRC, RIG, OUT, PLATE, PLATE_S = a[0], a[1], a[2], a[3], a[4]
ATLAS = 2048
HEADT = 1024                         # the head's own texture: about 2x the body's density on the face
MATS = ["skin-cinder-hot", "skin-cinderhead-hot", "leather-cinder", "metal-cinder", "flame-hair", "flame-jet", "flame-liquid"]
SCALE = {"ggface": 2.2, "gface": 1.6, "face": 3.6, "jaw": 3.6, "lid": 2.4, "finger": 1.7, "thumb": 1.7, "palm": 1.8, "skull": 0.5, "tail": 0.9, "gface": 1.6, "lens": 1.6, "fin": 1.3,
         "fang": 2.0, "mouthb": 0.4, "rivet": 0.5, "Low": 1.0}

bpy.ops.wm.open_mainfile(filepath=SRC)
src, low = bpy.data.objects["Src"], bpy.data.objects["Low"]
# (decimation leaves stray flipped faces; the game culls them, and you see through her: the red sternum facet)
bm0 = bmesh.new()
bm0.from_mesh(low.data)
bmesh.ops.recalc_face_normals(bm0, faces=bm0.faces)
bm0.to_mesh(low.data)
bm0.free()

tl = K.tail()
tl_fl = K.tail_flames(tl)
locks, chains = K.hair()
K.weight_falls(locks, chains)
tail_pts = [tuple(np.interp(t_, np.linspace(0, 1, len(tl.path)), tl.path[:, i]) for i in range(3)) for t_ in np.linspace(0.02, 1.0, K.TAIL_N)]
K.weight_tail(tl, tl_fl, tail_pts)
tk, tips = K.tank()
vl, spots = K.vials()
pieces = K.face_parts() + [K.mouth_back(), K.teeth(), K.skull()] + K.fangs() + K.goggles() + [K.fin(1.0), K.fin(-1.0)] + locks + [tl] + tl_fl + tk + K.jet_flames(tips) + K.gun() + K.hoses() + vl
for s in (1.0, -1.0):
    pieces.append(K.lids(s))
    pieces += K.brows(s)
hR = K.hand("R", K.GRIP_K, (1.3, 1.4, 0.9), 0.0)
hL = K.hand("L", (0.0, 1.0, -0.15), (0.45, 0.6, 0.4), 0.05)
pieces += hR + hL

for p_ in pieces:
    n_ = p_.name
    if getattr(p_, "flame", False):
        continue
    if n_ in ("face", "jaw", "skull", "strap"):
        p_.orient(tuple(K.C))
    elif n_.startswith("fin"):
        pass                # (two sheets back to back, wound as built)
    elif n_ == "mouthb" or n_ == "rack":
        p_.orient((0, -0.2, K.C[2] if n_ == "mouthb" else K.HIPS_Z + 0.1))
    elif n_.startswith("lid"):
        p_.orient(tuple(K.hl(K.EYE * [1 if n_.endswith("R") else -1, 1, 1])))
    else:
        p_.orient()

# (the ink shell folds on so small a face: no room on it)
for p_ in pieces:
    if p_.name in ("face", "jaw", "mouthb", "skull", "teeth") or p_.name.startswith(("lid", "brow", "fang", "fin", "lens")):
        p_.room = 0.0
    elif p_.name.startswith(("finger", "thumb")):
        p_.room = 0.3

# ---- one mesh: the scan first, then the pieces
faces_v, faces_pid, faces_uv, verts, vw, rooms, colors = [], [], [], [], [], [], []
names = []
me0 = low.data
pid0 = 0
names.append("Low")
verts.extend([tuple(v.co) for v in me0.vertices])
gn = {g.index: g.name for g in low.vertex_groups}
for v in me0.vertices:
    vw.append({gn[g.group]: g.weight for g in v.groups if g.weight > 0.01})
# (no ink room in the cleavage: the shell folds in the hollow and shows as a dark red facet)
rooms.extend([0.0 if abs(v.co.x) < 0.1 and v.co.y > 0.02 and 1.06 < v.co.z < 1.34 else 1.0 for v in me0.vertices])
colors.extend([(1.0, 1.0, 1.0)] * len(me0.vertices))
for p in me0.polygons:
    faces_v.append(list(p.vertices))
    faces_pid.append(0)
    faces_uv.append(None)
is_fl = {}
for pc in pieces:
    pid = len(names)
    names.append(pc.name)
    is_fl[pc.name] = getattr(pc, "flame", False)
    base = len(verts)
    verts.extend([tuple(v) for v in pc.v])
    for i in range(len(pc.v)):
        vw.append({b: float(arr[i]) for b, arr in pc.w.items() if arr[i] > 0.005})
    rooms.extend([pc.room] * len(pc.v))
    fc_ = getattr(pc, "fire", (1.0, 1.0, 1.0))
    colors.extend([(fc_[0], fc_[1], fc_[2] if len(fc_) > 2 else 1.0)] * len(pc.v))
    for j, f in enumerate(pc.f):
        faces_v.append([base + i for i in f])
        faces_pid.append(pid)
        faces_uv.append(pc.uv[j] if pc.uv is not None else None)
is_fl["Low"] = False

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
pid_arr = np.array(faces_pid)
print("tris", sum(len(p.vertices) - 2 for p in me.polygons), "verts", len(me.vertices))


def base_name(n):
    return n.rstrip("RL0123456789_").rstrip("_")


mat_i = {m: i for i, m in enumerate(MATS)}
PIECE_MAT = {pc.name: pc.mat for pc in pieces}
for i, p in enumerate(me.polygons):
    n = names[faces_pid[i]]
    if n != "Low":
        p.material_index = mat_i[PIECE_MAT[n]]

# ---- unwrap the unique pieces
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
uniq = [i for i in range(nf) if not is_fl[names[faces_pid[i]]]]
for f in bm.faces:
    f.select = False
for i in uniq:
    bm.faces[i].select = True
bmesh.update_edit_mesh(me)
bpy.ops.uv.smart_project(angle_limit=math.radians(66), island_margin=0.0, area_weight=0.0, scale_to_bounds=False)
bm = bmesh.from_edit_mesh(me)
bm.faces.ensure_lookup_table()
uvl = bm.loops.layers.uv["UV"]
PARTS = {"upper_arm.R": "armR", "forearm.R": "armR", "pauldron.R": "armR", "hand.R": "armR", "upper_arm.L": "armL", "forearm.L": "armL",
         "pauldron.L": "armL", "hand.L": "armL", "thigh.R": "legR", "shin.R": "legR", "foot.R": "legR", "thigh.L": "legL", "shin.L": "legL",
         "foot.L": "legL"}
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
    region[i] = (part, c[1] > 0.0)
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
for i in uniq:                       # flat maps where a clean sheet of paint matters
    n = names[faces_pid[i]]
    f = bm.faces[i]
    if n in ("face", "jaw"):
        off = 4 if n == "face" else 6
        for l in f.loops:
            l[uvl].uv = (l.vert.co.x * 1.0 + off, l.vert.co.z - 1.4 + 6)
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
    wgt = SCALE.get(base_name(n), 1.0)
    if i in region:
        n = n + region[i][0]
    s = wgt * math.sqrt(stats[n][0] / max(stats[n][1], 1e-12))
    for l in bm.faces[i].loops:
        l[uvl].uv = l[uvl].uv * s
bmesh.update_edit_mesh(me)
is_head = {n: PIECE_MAT.get(n) == K.HEAD_MAT for n in names}
for grp, mg in ((False, 0.003), (True, 0.006)):       # the body's atlas and the head's own texture each fill 0..1
    bpy.ops.mesh.select_all(action="DESELECT")
    bm = bmesh.from_edit_mesh(me)
    bm.faces.ensure_lookup_table()
    for i in uniq:
        bm.faces[i].select = is_head[names[faces_pid[i]]] == grp
    bmesh.update_edit_mesh(me)
    bpy.ops.uv.pack_islands(rotate=True, scale=True, margin_method="FRACTION", margin=mg, shape_method="CONCAVE")
bpy.ops.object.mode_set(mode="OBJECT")
uvd = me.uv_layers["UV"].data
loop_uv = np.zeros(len(me.loops) * 2)
uvd.foreach_get("uv", loop_uv)
loop_uv = loop_uv.reshape(-1, 2)
for p in me.polygons:
    i = p.index
    n = names[faces_pid[i]]
    if is_fl[n]:
        for l, (x, y) in zip(p.loop_indices, faces_uv[i]):
            loop_uv[l] = (x, 1.0 - y)      # (glTF flips V: the shader reads v root to tip)
uvd.foreach_set("uv", loop_uv.ravel())
me.update()

# ---- texel maps
me.calc_loop_triangles()
vco = np.array(verts)
vn = np.zeros(len(me.vertices) * 3)
me.vertices.foreach_get("normal", vn)
vn = vn.reshape(-1, 3)


def texel_maps(size, head):
    PID_ = -np.ones((size, size), np.int32)
    POS_ = np.zeros((size, size, 3), np.float32)
    NOR_ = np.zeros((size, size, 3), np.float32)
    for t in me.loop_triangles:
        n = names[faces_pid[t.polygon_index]]
        if is_fl[n] or is_head[n] != head:
            continue
        uvp = loop_uv[list(t.loops)] * size - 0.5
        x0, y0 = np.floor(uvp.min(0)).astype(int) - 1
        x1, y1 = np.ceil(uvp.max(0)).astype(int) + 1
        x0, y0, x1, y1 = max(x0, 0), max(y0, 0), min(x1, size - 1), min(y1, size - 1)
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
        POS_[ys[m], xs[m]] = w @ vco[tv]
        NOR_[ys[m], xs[m]] = w @ vn[tv]
        PID_[ys[m], xs[m]] = faces_pid[t.polygon_index]
    return PID_, POS_, M.norm(NOR_)


PID, POS, NOR = texel_maps(ATLAS, False)
PID2, POS2, NOR2 = texel_maps(HEADT, True)
print("texels", (PID >= 0).sum(), "of", ATLAS * ATLAS)

# ---- ambient occlusion, baked by Cycles
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
head_loops = np.array([l for p in me.polygons if is_head[names[faces_pid[p.index]]] for l in p.loop_indices], np.int64)
uv_bake = loop_uv.copy()
uv_bake[head_loops, 0] += 1.0                     # (out of the 0..1 tile: only the body's islands bake into this image)
uvd.foreach_set("uv", uv_bake.ravel())
bpy.ops.object.bake(type="AO", use_clear=True, margin=6)
uvd.foreach_set("uv", loop_uv.ravel())
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

# ---- the scan's paint on the shipped body: nearest surface
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
    return SP[sy, sx]


# each scan face's slot, by its paint: leather where it's brown; a crack stays skin
low_faces = [i for i in range(nf) if faces_pid[i] == 0]
fc = np.array([np.mean([verts[v] for v in faces_v[i]], axis=0) for i in low_faces])
# (the median of the middle and corners: an orange crack's bleed through one point doesn't make a face leather)
fcorn = [sample_scan(np.array([verts[faces_v[i][k]] for i in low_faces])) for k in range(3)]
fcol = np.median(np.stack([sample_scan(fc)] + fcorn, 0), 0)
for k_, i in enumerate(low_faces):
    r_, g_, b_ = fcol[k_]
    mx = max(r_, g_, b_)
    brown = r_ > b_ * 1.34 and r_ < 0.5 and g_ > b_ * 0.95
    grey_hi = (mx - min(r_, g_, b_)) / max(mx, 0.01) < 0.12 and mx > 0.42
    m = "metal-cinder" if grey_hi else ("leather-cinder" if brown else "skin-cinder-hot")
    if grey_hi and abs(fc[k_][0]) < 0.085 and fc[k_][2] > 0.95:
        m = "skin-cinder-hot"          # (the pale neckline is skin, not a buckle: on the metal slot it shaded red-brown)
    me.polygons[i].material_index = mat_i[m]

mask = PID == 0
ys, xs = np.nonzero(mask)
col = sample_scan(POS[ys, xs])
col = np.power(np.clip(col, 0, 1), 0.9) * 1.12
# near-black up to a readable charcoal
dk = (col.max(1) < 0.22)[:, None]
col = col * (1 - dk) + (col * 1.35 + np.array([0.05, 0.045, 0.05])) * dk
OUTC = np.zeros((ATLAS, ATLAS, 3), np.float32)
OUTC[ys, xs] = col
OUTC[ys, xs] *= (0.6 + 0.4 * np.clip(AO[ys, xs], 0, 1))[:, None]
# the scan's magma: rims to the edge colour, hearts to the key, so hero_toon's glow_key lights them per texel
r_, g_, b_ = col[:, 0], col[:, 1], col[:, 2]
k1 = smooth(0.22, 0.4, r_ - b_) * smooth(0.36, 0.5, r_)
k2 = smooth(0.42, 0.62, r_ - b_) * smooth(0.5, 0.72, r_)
c2 = col * (1 - k1[:, None]) + P.HOT_RIM * k1[:, None]
c2 = c2 * (1 - k2[:, None]) + P.HOT * k2[:, None]
# the skin down to the sheet's warm charcoal (the scan runs light and lilac); leather and the cracks stay
sk = np.clip(1.0 - smooth(0.05, 0.13, r_ - b_), 0, 1)[:, None]
lum_ = c2.mean(1, keepdims=True)
c2 = c2 * (1 - sk) + np.clip(0.2 + 0.55 * (lum_ - 0.2), 0.1, 0.42) * np.array([1.16, 0.95, 1.0]) * sk
OUTC[ys, xs] = c2

# ---- the rebuilt pieces
def paint(pred, fn):
    ids = [i for i, n in enumerate(names) if pred(n)]
    m = np.isin(PID, ids)
    ys, xs = np.nonzero(m)
    if len(ys):
        OUTC[ys, xs] = fn(POS[ys, xs].astype(np.float64), NOR[ys, xs].astype(np.float64), AO[ys, xs].astype(np.float64))


import imgio_blender as IB
plates = (IB.load(PLATE), IB.load(PLATE_S))
paint(lambda n: n == "skull", P.skull)
segs = [q.claw for q in hR + hL if hasattr(q, "claw")]
paint(lambda n: n.startswith(("palm", "finger", "thumb")), lambda p, n, ao: P.claws(P.hands(p, n, ao), p, segs))
paint(lambda n: n == "tail", lambda p, n, ao: P.tail(p, n, ao, tl.path, tl.wd))
paint(lambda n: n.startswith(("tankfoot", "tankring", "stack", "bar", "gpipe", "gauge")), P.copper)
paint(lambda n: n.startswith("rivet"), P.brass)
gf = next(q for q in tk if q.name == "gface")
paint(lambda n: n == "gface", lambda p, n, ao: P.gauge(p, *gf.gauge))
paint(lambda n: n.startswith(("gogR", "gogB")), lambda p, n, ao: P.brass(p, n, np.maximum(ao, 0.8)))
paint(lambda n: n.startswith("vcap"), P.cork)
for q in pieces:
    if q.name.startswith("lens"):
        paint(lambda n, nm=q.name: n == nm, lambda p, n, ao, fr=q.frame: P.lens(p, fr))
paint(lambda n: n in ("strap", "rack", "hband0", "hstrapR", "hstrapL", "gunfore") or n.startswith("vloop"), P.leather)
paint(lambda n: n in ("hose", "coilL", "coilR"), P.hose)
paint(lambda n: n in ("gunbarrel", "gunpipe"), P.copper)
paint(lambda n: n == "gunhead", P.steel)
paint(lambda n: n.startswith(("gunbody", "guncol", "gunbase", "gunguard", "guntrig", "gunclamp", "gunstay", "ggauge", "gunknob")), P.brass)
gf2 = next(q for q in pieces if q.name == "ggface")
paint(lambda n: n == "ggface", lambda p, n, ao: P.gauge(p, *gf2.gauge))
paint(lambda n: n == "gungrip", lambda p, n, ao: P.wrap(p, n, ao, K.GRIP_AT, K.GRIP_K))

# ---- the head's own texture
OUT2 = np.zeros((HEADT, HEADT, 3), np.float32)


def paint2(pred, fn):
    ids = [i for i, n in enumerate(names) if pred(n)]
    ys, xs = np.nonzero(np.isin(PID2, ids))
    if len(ys):
        OUT2[ys, xs] = fn(POS2[ys, xs].astype(np.float64), NOR2[ys, xs].astype(np.float64))


paint2(lambda n: n in ("face", "jaw"), lambda p, n: P.face(plates, p, n, np.ones(len(p))))
paint2(lambda n: n == "mouthb", lambda p, n: np.broadcast_to(P.hexc("#120708"), p.shape))
paint2(lambda n: n.startswith("fang"), lambda p, n: np.broadcast_to(P.hexc("#f4efe6"), p.shape))
paint2(lambda n: n == "teeth", lambda p, n: np.broadcast_to(P.hexc("#e6dfd2"), p.shape))
paint2(lambda n: n.startswith("lid"), lambda p, n: P.skin(p, n, np.ones(len(p))) * 0.72)
paint2(lambda n: n.startswith("brow"), lambda p, n: np.broadcast_to(P.hexc("#ff7a1c"), p.shape))
for sd, sg in (("R", 1.0), ("L", -1.0)):
    root = K.hl(np.array([sg * 0.074, -0.004, -0.006]))
    paint2(lambda n, q="fin" + sd: n == q, lambda p, n, r=root: P.fin_new(p, n, np.ones(len(p)), r))


def dilate(img, pid, size):
    known = pid >= 0
    for _ in range(10):
        acc = np.zeros_like(img)
        cnt = np.zeros((size, size), np.float32)
        for dy, dx_ in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            k = np.roll(known, (dy, dx_), (0, 1))
            acc += np.roll(img, (dy, dx_), (0, 1)) * k[..., None]
            cnt += k
        new = (~known) & (cnt > 0)
        img[new] = acc[new] / cnt[new][:, None]
        known |= new


dilate(OUTC, PID, ATLAS)
dilate(OUT2, PID2, HEADT)

atlas = bpy.data.images.new("cinder_atlas", ATLAS, ATLAS)
px = np.ones((ATLAS, ATLAS, 4), np.float32)
px[..., :3] = np.clip(OUTC, 0, 1)
atlas.pixels.foreach_set(px.ravel())
atlas.filepath_raw = os.path.join(os.path.dirname(OUT), "atlas.png")
atlas.file_format = "PNG"
atlas.save()
print("atlas saved")
headt = bpy.data.images.new("cinder_head", HEADT, HEADT)
px = np.ones((HEADT, HEADT, 4), np.float32)
px[..., :3] = np.clip(OUT2, 0, 1)
headt.pixels.foreach_set(px.ravel())
headt.filepath_raw = os.path.join(os.path.dirname(OUT), "head.png")
headt.file_format = "PNG"
headt.save()

# ---- materials
for mt in me.materials:
    nt = mt.node_tree
    for nd in list(nt.nodes):
        if nd.type == "TEX_IMAGE":
            nt.nodes.remove(nd)
    pb = nt.nodes["Principled BSDF"]
    pb.inputs["Roughness"].default_value = 0.7
    pb.inputs["Metallic"].default_value = 0.0
    if mt.name.startswith("flame"):
        continue
    t = nt.nodes.new("ShaderNodeTexImage")
    t.image = headt if "cinderhead" in mt.name else atlas
    nt.links.new(t.outputs[0], pb.inputs[0])

# ---- ink room; fire's seed in the colour
attr = me.color_attributes.new("ink", "FLOAT_COLOR", "POINT")
ic = np.ones((len(me.vertices), 4), np.float32)
ic[:, 3] = rooms
ic[:, :3] = np.array(colors, np.float32)
attr.data.foreach_set("color", ic.ravel())
me.color_attributes.active_color = attr

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


for s, side in ((1.0, "R"), (-1.0, "L")):
    c = K.hl(K.EYE * [s, 1, 1] + [0, -0.004, 0])
    bone("lid." + side, "head", c, c + Vector((0, 0.03, 0)))
    b = K.hl(np.array([s * 0.042, 0.088, 0.018]))
    bone("brow." + side, "head", b, b + Vector((0, 0.03, 0)))
    f = K.hl(np.array([s * 0.074, -0.004, -0.006]))
    bone("fin." + side, "head", f, f + Vector((s * 0.03, -0.02, 0.03)))
jw = K.hl(np.array([0.0, 0.0, -0.045]))
bone("jaw", "head", jw, jw + Vector((0, 0.05, -0.02)))
for sd, sx in (("R", 1.0), ("L", -1.0)):
    hd = np.array([sx * K.THIGH_X, 0.0, K.ANKLE_Z])
    bone("foot." + sd, "shin." + sd, hd, hd + [0, 0.12, 0])
knuck = np.array([-K.SH, 0.0, K.HAND_Z - 0.06])
bone("fingers.L", "hand.L", knuck, knuck + [0, 0, -0.06])
th = np.array([-K.SH, 0.03, K.HAND_Z - 0.015])
bone("thumb.L", "hand.L", th, th + [0, 0.02, -0.05])
for i, (p, ax) in enumerate(tips):
    bone("jet.%d" % i, "hips", p, p + ax * 0.12)
for g, pts in chains.items():
    spring(["spring_scarftail_hair%s_%d" % (g, i) for i in range(len(pts))], [tuple(p) for p in pts], "head")
spring(["spring_scarftail_tail_%d" % i for i in range(K.TAIL_N)], tail_pts, "root")
bpy.ops.object.mode_set(mode="OBJECT")
ob.parent = arm
md = ob.modifiers.new("arm", "ARMATURE")
md.object = arm
for vi, d in enumerate(vw):
    tot = sum(d.values())
    for b, w in d.items():
        g = ob.vertex_groups.get(b) or ob.vertex_groups.new(name=b)
        g.add([vi], w / tot if tot > 0 else 0, "REPLACE")

# ---- anchors and FX points: empties on the bones (RIG_CONTRACT, item 76b)
g = K.GRIP_AT
A = {"anchor_head_top": ("head", (0, 0.0, K.C[2] + 0.12)), "anchor_chest": ("hips", (0, 0.1, K.SHOULDER_Z - 0.09)),
     "weapon_muzzle": ("hand.R", tuple(K.gun_at(K.MUZZLE, K.BORE))), "anchor_blade_root": ("hand.R", tuple(K.gun_at(0.14, K.BORE))),
     "anchor_gun_mid": ("hand.R", tuple(K.gun_at(0.5, K.BORE))),
     "anchor_jet_0": ("jet.0", tuple(tips[0][0])), "anchor_jet_1": ("jet.1", tuple(tips[1][0])), "anchor_tank": ("hips", tuple(K.TANK_C + [0, -0.05, (K.GL0 + K.GL1) / 2])),
     "anchor_tail_tip": ("spring_scarftail_tail_%d" % (K.TAIL_N - 2), tuple(tl.path[-1])), "anchor_crown": ("head", tuple(K.C + [0, -0.03, 0.2]))}
for i_, sp in enumerate(spots):
    A["anchor_vial_%d" % i_] = ("root", tuple(sp))
for nm, (bn, at) in A.items():
    e = bpy.data.objects.new(nm, None)
    bpy.context.scene.collection.objects.link(e)
    e.parent = arm
    e.parent_type = "BONE"
    e.parent_bone = bn
    e.matrix_world = Matrix.Translation(at)

me.polygons.foreach_set("use_smooth", [True] * len(me.polygons))
me.update()
bpy.ops.wm.save_as_mainfile(filepath=os.path.splitext(OUT)[0] + ".blend")
objs = [arm, ob] + [o for o in bpy.data.objects if o.type == "EMPTY"]
for o in list(bpy.data.objects):
    if o.name in ("Src", "Low"):
        bpy.data.objects.remove(o)
WK.export(OUT, objs, image_format="JPEG", colors=True)
print("exported", OUT, os.path.getsize(OUT))
