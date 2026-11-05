"""ART-1 Sable, stage C: join, unwrap, paint, skin, export. The recipe is claire_finish.py / kael_finish.py.
Run: blender -b --factory-startup --python tools/art1/sable_finish.py -- <source.blend> <rig.json> <out.glb>"""
import sys, os, json, math
import bpy, bmesh
import numpy as np
from mathutils import Vector, Matrix
from mathutils.bvhtree import BVHTree
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, "..", "blender"))
import meshkit as M, sable_pieces as K, sable_paint as P
from meshkit import smooth, Piece
from kael_paint import hexc, mix
import warden_kit as WK

a = sys.argv[sys.argv.index("--") + 1:]
SRC, RIG, OUT = a[0], a[1], a[2]
ATLAS = 2048
MATS = ["skin-face", "cloth-coat", "leather-dark", "metal-silver", "hair-braid", "hair-feather", "card-wing", "glow-rune"]     # S1's limit: <= 8
SCALE = {"lid": 2.0, "finger": 1.0, "thumb": 1.0, "palm": 1.0, "antenna": 0.9, "braid": 0.8, "tuft": 0.7, "tie": 0.5, "wing": 1.3, "tail": 0.7, "lining": 0.35,
         "barrel": 1.6, "stock": 1.1, "rod": 0.4, "cap": 0.6, "lock": 1.2, "cock": 0.8, "frizzen": 0.8, "guard": 0.5, "mouth": 1.0, "crystal": 0.8, "runeA": 5.0, "runeB": 5.0,
         "key": 0.8, "keyring": 0.6, "keyshaft": 0.8, "keybit": 0.6, "bolaA": 0.9, "bolaB": 0.9, "cordA": 0.3, "cordB": 0.3, "gemchain": 0.4, "gemframe": 0.8, "gemstone": 1.4, "Low": 1.0}
FACE_K = 3.4                # texel density on the face against the body

bpy.ops.wm.open_mainfile(filepath=SRC)
src, low = bpy.data.objects["Src"], bpy.data.objects["Low"]

# ---- the scan as a surface
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
    v0, v1 = tv[:, 1] - tv[:, 0], tv[:, 2] - tv[:, 0]
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


# ---- the upper lids: closed, each one lies just on the eye; at rest it is turned up about the eyeball, under the brow's skin
LID_A = 0.82


def lid_piece(s):
    side = "R" if s > 0 else "L"
    c = K.eye_c(s).copy()
    c[1] -= 0.024
    rows, cols = 5, 9
    W_, H_ = K.EYE_W * K.HK * 1.32, K.EYE_H * K.HK * 1.32
    v = []
    for j in range(rows):
        t = j / (rows - 1)                         # 0 top, 1 the lash line
        for i in range(cols):
            x = (i / (cols - 1) * 2 - 1)
            z = 1.12 - 2.0 * t
            q = np.array([K.eye_c(s)[0] + x * W_, 0.3, K.eye_c(s)[2] + z * H_ * (1 - 0.32 * x * x)])
            h = tree.ray_cast(Vector(q), Vector((0, -1, 0)), 0.5)
            y = h[0].y if h[0] is not None else K.eye_c(s)[1]
            v.append((q[0], y + 0.0016, q[2]))
    v = np.array(v)
    ca, sa = math.cos(LID_A), math.sin(LID_A)
    d = v - c
    v2 = np.stack([d[:, 0], d[:, 1] * ca - d[:, 2] * sa, d[:, 1] * sa + d[:, 2] * ca], 1) + c
    f = []
    for j in range(rows - 1):
        for i in range(cols - 1):
            q = j * cols + i
            f.append([q, q + 1, q + 1 + cols, q + cols])
    p = Piece("lid" + side, "skin-body", v2, f).rigid("lid." + side)
    p.c = c
    return p


ant = [K.antenna(1.0), K.antenna(-1.0)]
br = K.braid()
ties = [K.braid_tie(br, 0.03, "tieA", 0.034), K.braid_tie(br, 0.965, "tieB", 0.029)]
tuft = K.braid_tuft(br)
top_z, r0 = float(src.get("hem_z", 0.8)), (float(src.get("hem_rx", 0.165)), float(src.get("hem_ry", 0.128)))
hip_cy = float(src.get("hem_cy", -0.012))
tails = [K.coat_tail(1.0, top_z=top_z, r0=r0, cy=hip_cy), K.coat_tail(-1.0, top_z=top_z, r0=r0, cy=hip_cy)]
wings = [K.wing(1.0), K.wing(-1.0)]
lids = [lid_piece(1.0), lid_piece(-1.0)]
hR, hL = K.hand("R"), K.hand("L")
pR, pL = K.pistol("R"), K.pistol("L")
BY = K.hem_front_y(top_z, r0, hip_cy) if hasattr(K, "hem_front_y") else 0.115
TOP_K = (0.052, BY, K.BELT_Z)
TOP_B = (0.128, BY - 0.052, K.BELT_Z - 0.005)
TOP_G = (-0.112, BY - 0.04, K.BELT_Z - 0.005)
ks = K.keys(TOP_K)
bl = K.bola(TOP_B)
gm, GEM_C = K.gem(TOP_G)
pieces = ant + [br, tuft] + ties + [t for pr in tails for t in pr] + wings + lids + hR + hL + pR + pL + ks + bl + gm

def chain_w(p, pts, names, tip_free=True):
    """Weights along a polyline of chain joints, blended between neighbours; the last bone (the tip) has no skin."""
    pts = np.array(pts)
    n = len(pts) - 1
    a_, b_ = pts[:-1], pts[1:]
    best = np.full(len(p.v), 9e9)
    us = np.zeros(len(p.v))
    for i in range(n):
        ab = b_[i] - a_[i]
        t = (p.v - a_[i]) @ ab / (ab @ ab)
        t2 = np.clip(t, 0, 1)
        d = np.linalg.norm(p.v - (a_[i] + t2[:, None] * ab), axis=1)
        m = d < best
        best[m] = d[m]
        us[m] = i + t2[m]
    w = {b: np.zeros(len(p.v)) for b in names[:n]}
    for i in range(len(p.v)):
        u = us[i] - 0.5
        k = int(np.clip(np.floor(u), 0, n - 1))
        f = float(np.clip(u - k, 0, 1))
        k2 = min(k + 1, n - 1)
        if us[i] < 0.5:
            k, k2, f = 0, 0, 0.0
        w[names[k]][i] += 1 - f
        w[names[k2]][i] += f
    p.w = w


ant_chain = {}
for p_, sd in ((ant[0], "R"), (ant[1], "L")):
    pts = K.antenna_points(p_)
    nm = ["spring_ant%s_%d" % (sd, i) for i in range(len(pts))]
    ant_chain[sd] = (nm, pts)
    chain_w(p_, pts, nm)
braid_pts = [tuple(br.path[int(round(t * (len(br.path) - 1)))]) for t in np.linspace(0.0, 1.0, K.BRAID_N - 1)] + [tuple(tuft.path[-1])]
braid_nm = ["spring_braid_%d" % i for i in range(K.BRAID_N)]
for q in [br, tuft] + ties:
    chain_w(q, braid_pts, braid_nm)
wing_chain = {}
for sg, p_, sd in ((1.0, wings[0], "R"), (-1.0, wings[1], "L")):
    pts = K.wing_points(sg)
    nm = ["spring_wing%s_%d" % (sd, i) for i in range(len(pts))]
    wing_chain[sd] = (nm, pts)
    chain_w(p_, pts, nm)
# the coat tails: two chains a panel, the vertices blended across the columns and along the rows; the front's middle follows its thigh a little
tail_chain = {}
for sg, (o_, i_), sd in ((1.0, tails[0], "R"), (-1.0, tails[1], "L")):
    G = o_.grid
    ptf, ptb = K.tail_chain(G, 0.2), K.tail_chain(G, 0.8)
    nf_, nb_ = ["spring_scarftail_coat%sf_%d" % (sd, i) for i in range(4)], ["spring_scarftail_coat%sb_%d" % (sd, i) for i in range(4)]
    tail_chain[sd] = ((nf_, ptf), (nb_, ptb))
    for q in (o_, i_):
        n = len(q.v)
        w = {}

        def add(b, arr):
            w[b] = w.get(b, np.zeros(n)) + arr
        kb = smooth(0.2, 0.8, q.colf)
        rr = np.clip(q.rowf, 0, 1) * 2.999
        k0 = np.floor(rr).astype(int)
        fr = rr - k0
        thigh = 0.42 * np.sin(np.clip(q.rowf * 1.25, 0, 1) * np.pi) * (1 - kb) * smooth(0.0, 0.25, q.rowf)
        root = smooth(0.12, 0.0, q.rowf)
        rest = 1 - thigh - root
        for j in range(3):
            lo = (k0 == j).astype(float)
            for nm_, k_ in ((nf_, 1 - kb), (nb_, kb)):
                add(nm_[j], rest * k_ * lo * (1 - fr))
                if j < 2:
                    add(nm_[j + 1], rest * k_ * lo * fr)
                else:
                    add(nm_[2], rest * k_ * lo * fr)
        add("root", root)
        add("thigh." + sd, thigh)
        q.w = w
# the hangers
hang = {}
for nm, top, drop, ps in (("keys", TOP_K, 0.12, ks), ("bola", TOP_B, 0.2, bl), ("gem", TOP_G, 0.2, gm)):
    pts = K.hang_path(top, drop)
    names_ = ["spring_hang%s_%d" % (nm, i) for i in range(len(pts))]
    hang[nm] = (names_, pts)
    for q in ps:
        q.rigid(names_[0]) if False else None
        z_ = (np.asarray(top)[2] - q.v[:, 2]) / drop
        q.w = {names_[0]: np.clip(1 - z_ * 1.6, 0, 1), names_[1]: 1 - np.clip(1 - z_ * 1.6, 0, 1)}

for p_ in pieces:
    n_ = p_.name
    if n_.startswith(("antenna", "wing", "tail", "lining", "gemstone", "crystal", "rune")):
        continue                       # (built wound; two faced)
    if n_.startswith("lid"):
        p_.orient(tuple(p_.c))
    else:
        p_.orient()

# ---- one mesh: the scan first, then the pieces
faces_v, faces_pid, faces_uv, verts, vw, rooms = [], [], [], [], [], []
names = ["Low"]
me0 = low.data
verts.extend([tuple(v.co) for v in me0.vertices])
gn = {g.index: g.name for g in low.vertex_groups}
for v in me0.vertices:
    vw.append({gn[g.group]: g.weight for g in v.groups if g.weight > 0.01})
rooms.extend([1.0] * len(me0.vertices))
for p in me0.polygons:
    faces_v.append(list(p.vertices))
    faces_pid.append(0)
    faces_uv.append(None)
# the face moves: brows and mouth corners pull the scan's own skin (its paint rides along)
HEAD = np.array(verts)
DEFORM = {}
for sg, sd in ((1.0, "R"), (-1.0, "L")):
    DEFORM["brow." + sd] = (K.hs(K.BROW * [sg, 1, 1]), 0.026)
    DEFORM["mouth." + sd] = (K.hs(K.MOUTH * [sg, 1, 1]), 0.015)
for b, (c_, r_) in DEFORM.items():
    d_ = np.linalg.norm((HEAD - c_) * [1, 0.6, 1.1], axis=1)
    k_ = np.exp(-(d_ / r_) ** 2) * (HEAD[:, 1] > 0.06)
    for i in np.nonzero(k_ > 0.03)[0].tolist():
        q = vw[i]
        if q.get("head", 0) > 0.5:
            f_ = float(k_[i])
            for kk in list(q):
                q[kk] *= 1 - f_
            q[b] = f_
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
        faces_uv.append(None)

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


def base_name(n):
    return n.rstrip("RL0123456789_").rstrip("_")


mat_i = {m: i for i, m in enumerate(MATS)}
PIECE_MAT = {pc.name: pc.mat for pc in pieces}
for i, p in enumerate(me.polygons):
    n = names[faces_pid[i]]
    if n != "Low":
        p.material_index = mat_i[PIECE_MAT[n]]

# ---- unwrap: the scan by body part with seams, the face flat from the front, the pieces by Smart UV
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
for f in bm.faces:
    f.select = True
bmesh.update_edit_mesh(me)
bpy.ops.uv.smart_project(angle_limit=math.radians(66), island_margin=0.0, area_weight=0.0, scale_to_bounds=False)
bm = bmesh.from_edit_mesh(me)
bm.faces.ensure_lookup_table()
uvl = bm.loops.layers.uv["UV"]
PARTS = {"upper_arm.R": "armR", "forearm.R": "armR", "hand.R": "armR", "upper_arm.L": "armL", "forearm.L": "armL", "hand.L": "armL", "thigh.R": "legR", "shin.R": "legR", "foot.R": "legR",
         "thigh.L": "legL", "shin.L": "legL", "foot.L": "legL", "head": "head", "brow.R": "head", "brow.L": "head", "mouth.R": "head", "mouth.L": "head"}
FACE_C = K.hs([0, 0.0, K.EYE[2] - 0.005])
region, face_i = {}, set()
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
    if part == "head" and c[1] > 0.035 and abs(c[0]) < 0.092 and abs(c[2] - FACE_C[2]) < 0.112:
        face_i.add(i)
        region[i] = ("face", True)
    else:
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
for i in face_i:
    for l in bm.faces[i].loops:
        l[uvl].uv = (l.vert.co.x + 4.0, l.vert.co.z - 1.4 + 6)
stats = {}
for i in range(nf):
    n = names[faces_pid[i]]
    key = n + region[i][0] if i in region else n
    f = bm.faces[i]
    pts = [l[uvl].uv.copy() for l in f.loops]
    a2 = 0.0
    for k in range(1, len(pts) - 1):
        a2 += abs((pts[k] - pts[0]).cross(pts[k + 1] - pts[0])) * 0.5
    s = stats.setdefault(key, [0.0, 0.0])
    s[0] += f.calc_area()
    s[1] += a2
for i in range(nf):
    n = names[faces_pid[i]]
    wgt = SCALE.get(base_name(n), 1.0)
    key = n
    if i in region:
        key = n + region[i][0]
        if i in face_i:
            wgt = FACE_K
    s = wgt * math.sqrt(stats[key][0] / max(stats[key][1], 1e-12))
    for l in bm.faces[i].loops:
        l[uvl].uv = l[uvl].uv * s
bmesh.update_edit_mesh(me)
bpy.ops.mesh.select_all(action="SELECT")
bpy.ops.uv.select_all(action="SELECT")
bpy.ops.uv.pack_islands(rotate=True, scale=True, margin_method="FRACTION", margin=0.003, shape_method="CONCAVE")
bpy.ops.object.mode_set(mode="OBJECT")
uvd = me.uv_layers["UV"].data
loop_uv = np.zeros(len(me.loops) * 2)
uvd.foreach_get("uv", loop_uv)
loop_uv = loop_uv.reshape(-1, 2)

# ---- texel maps
me.calc_loop_triangles()
vco = np.array(verts)
vn = np.zeros(len(me.vertices) * 3)
me.vertices.foreach_get("normal", vn)
vn = vn.reshape(-1, 3)
PID = -np.ones((ATLAS, ATLAS), np.int32)
POS = np.zeros((ATLAS, ATLAS, 3), np.float32)
NOR = np.zeros((ATLAS, ATLAS, 3), np.float32)
for t in me.loop_triangles:
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
NOR = M.norm(NOR)
print("texels", (PID >= 0).sum(), "of", ATLAS * ATLAS)

# ---- ambient occlusion, baked by Cycles
ao_img = bpy.data.images.new("ao", ATLAS, ATLAS, float_buffer=True)
sc = bpy.context.scene
sc.render.engine = "CYCLES"
sc.cycles.device = "CPU"
sc.cycles.samples = 24
sc.render.bake.margin = 6
sc.render.bake.use_clear = True
for mt in me.materials:
    nt = mt.node_tree
    tn = nt.nodes.new("ShaderNodeTexImage")
    tn.image = ao_img
    nt.nodes.active = tn
src.hide_render = True
low.hide_render = True
bpy.ops.object.select_all(action="DESELECT")
ob.select_set(True)
bpy.context.view_layer.objects.active = ob
bpy.context.view_layer.update()
bpy.ops.object.bake(type="AO", use_clear=True, margin=6)
AO = np.array(ao_img.pixels[:], dtype=np.float32).reshape(ATLAS, ATLAS, 4)[..., 0]


def blur(a_, m, r):
    def box(z):
        c_ = np.cumsum(np.cumsum(z, 0), 1)
        c_ = np.pad(c_, ((r + 1, r), (r + 1, r)), mode="edge")
        c_[:r + 1, :] = 0
        c_[:, :r + 1] = 0
        return c_[2 * r + 1:, 2 * r + 1:] - c_[:-2 * r - 1, 2 * r + 1:] - c_[2 * r + 1:, :-2 * r - 1] + c_[:-2 * r - 1, :-2 * r - 1]
    return box(a_ * m) / np.maximum(box(m), 1e-3)


AO = blur(AO, (PID >= 0).astype(np.float32), 3)

# each scan face's slot, by its paint: the face and neck skin, the white hair cap, everything else the coat
low_faces = [i for i in range(nf) if faces_pid[i] == 0]
fc = np.array([np.mean([verts[v] for v in faces_v[i]], axis=0) for i in low_faces])
fcol = sample_scan(fc)
for k_, i in enumerate(low_faces):
    r_, g_, b_ = fcol[k_]
    lum = (r_ + g_ + b_) / 3
    z_ = fc[k_][2]
    if z_ > K.NECK_Z - 0.09 and lum > 0.62:
        m = "hair-braid" if z_ > K.NECK_Z + 0.02 else "skin-face"
    elif z_ > K.NECK_Z - 0.16 and lum > 0.27:
        m = "skin-face"
    else:
        m = "cloth-coat"
    me.polygons[i].material_index = mat_i[m]

mask = PID == 0
ys, xs = np.nonzero(mask)
pp = POS[ys, xs].astype(np.float64)
col = sample_scan(pp)
print("scan paint", col.mean(0))
OUTC = np.zeros((ATLAS, ATLAS, 3), np.float32)
OUTC[ys, xs] = P.scan_grade(np.clip(col, 0, 1), pp, AO[ys, xs].astype(np.float64))


def paint(pred, fn):
    ids = [i for i, n in enumerate(names) if pred(n)]
    m = np.isin(PID, ids)
    yy, xx = np.nonzero(m)
    if len(yy):
        OUTC[yy, xx] = fn(POS[yy, xx].astype(np.float64), NOR[yy, xx].astype(np.float64), AO[yy, xx].astype(np.float64))


paint(lambda n: n.startswith("palm"), P.glove)
paint(lambda n: n.startswith(("finger", "thumb")), P.skin)
paint(lambda n: n.startswith("antenna"), lambda p, n, ao: P.feather(p, n, ao))
paint(lambda n: n == "braid", lambda p, n, ao: P.braid(p, n, ao, br.path))
paint(lambda n: n == "tuft", P.tuft)
paint(lambda n: n.startswith("tie"), P.silver)
for q_ in tails:
    paint(lambda n, nm=q_[0].name: n == nm, lambda p, n, ao, g=q_[0].grid: P.coat_outer(p, n, ao, g))
    paint(lambda n, nm=q_[1].name: n == nm, lambda p, n, ao: P.lining(p, n, ao))
for w_ in wings:
    paint(lambda n, nm=w_.name: n == nm, lambda p, n, ao, q=w_: P.wing(p, n, ao, q.root, q.along, q.across))
paint(lambda n: n.startswith(("barrel", "rod", "lock", "cock", "frizzen", "guard", "cap")), P.silver_engraved)
paint(lambda n: n.startswith("stock"), P.wood)
paint(lambda n: n.startswith("mouth"), P.mouth_glow)
paint(lambda n: n.startswith("rune"), P.runes)
paint(lambda n: n.startswith("crystal") or n == "gemstone", P.crystal)
paint(lambda n: n.startswith(("keyring", "keyshaft", "keybit", "gemchain", "gemframe")), P.silver)
paint(lambda n: n.startswith("bola"), P.bola)
paint(lambda n: n.startswith("cord"), P.glove)
skin_c = sample_scan([K.hs(K.EYE + [0.03, 0.0, -0.035])])[0] * 1.03
for q, sg in ((lids[0], 1.0), (lids[1], -1.0)):
    def liner(p_, qq=q):
        ca, sa = math.cos(-LID_A), math.sin(-LID_A)
        d = p_ - qq.c
        zz = d[:, 1] * sa + d[:, 2] * ca + qq.c[2]
        return smooth(K.eye_c(1.0)[2] - K.EYE_H * K.HK * 0.62, K.eye_c(1.0)[2] - K.EYE_H * K.HK * 0.9, zz)
    paint(lambda n, nm=q.name: n == nm, lambda p, n, ao, ll=liner: P.lid(p, n, ao, skin_c, ll))

known = PID >= 0
for _ in range(10):
    acc = np.zeros_like(OUTC)
    cnt = np.zeros((ATLAS, ATLAS), np.float32)
    for dy, dx_ in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        k = np.roll(known, (dy, dx_), (0, 1))
        acc += np.roll(OUTC, (dy, dx_), (0, 1)) * k[..., None]
        cnt += k
    new = (~known) & (cnt > 0)
    OUTC[new] = acc[new] / cnt[new][:, None]
    known |= new

atlas = bpy.data.images.new("sable_atlas", ATLAS, ATLAS)
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
    pb = nt.nodes["Principled BSDF"]
    pb.inputs["Roughness"].default_value = 0.7
    pb.inputs["Metallic"].default_value = 0.0
    tn = nt.nodes.new("ShaderNodeTexImage")
    tn.image = atlas
    nt.links.new(tn.outputs[0], pb.inputs[0])

attr = me.color_attributes.new("ink", "FLOAT_COLOR", "POINT")
ic = np.ones((len(me.vertices), 4), np.float32)
ic[:, 3] = rooms
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
    e.head, e.tail = Vector(tuple(head)), Vector(tuple(tail))
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
    c = lids[0 if s > 0 else 1].c
    bone("lid." + side, "head", c, c + np.array([0, 0.03, 0]))
    for nm in ("brow.", "mouth."):
        b = DEFORM[nm + side][0]
        bone(nm + side, "head", b, b + np.array([0, 0.03, 0]))
    hd = np.array([s * K.THIGH_X, 0.0, K.ANKLE_Z])
    bone("foot." + side, "shin." + side, hd, hd + [0, 0.12, 0])
for sd in "RL":
    spring(*ant_chain[sd], "head")
    spring(*wing_chain[sd], "root")
    for nm_, pts in tail_chain[sd]:
        spring(nm_, pts, "root")
spring(braid_nm, braid_pts, "head")
for nm_, pts in hang.values():
    spring(nm_, pts, "root")
bpy.ops.object.mode_set(mode="OBJECT")
ob.parent = arm
md = ob.modifiers.new("arm", "ARMATURE")
md.object = arm
for vi, d in enumerate(vw):
    tot = sum(d.values())
    for b, w in d.items():
        g = ob.vertex_groups.get(b) or ob.vertex_groups.new(name=b)
        g.add([vi], w / tot if tot > 0 else 0, "REPLACE")

# ---- anchors and FX points: empties on the bones (RIG_CONTRACT, item 76b). S3/S4 hang the muzzle puff and shots here.
BV = 0.052
pr_, pl_ = K.P_at("R"), K.P_at("L")
A = {"anchor_head_top": ("head", (0, 0.0, K.NECK_Z + 0.34)), "anchor_chest": ("hips", (0, 0.1, K.SHOULDER_Z - 0.09)),
     "weapon_muzzle": ("hand.R", tuple(pr_(K.MUZZLE_U + 0.01, BV))), "weapon_muzzle_l": ("hand.L", tuple(pl_(K.MUZZLE_U + 0.01, BV))),
     "anchor_blade_root": ("hand.R", tuple(pr_(0.0, BV))), "anchor_blade_mid": ("hand.R", tuple(pr_(0.2, BV))),
     "anchor_blade_root_l": ("hand.L", tuple(pl_(0.0, BV))),
     "anchor_pan_r": ("hand.R", tuple(pr_(0.007, BV + 0.05, 0.016))), "anchor_pan_l": ("hand.L", tuple(pl_(0.007, BV + 0.05, 0.016))),
     "anchor_hand_r": ("hand.R", tuple(K.grip("R"))), "anchor_hand_l": ("hand.L", tuple(K.grip("L"))),
     "anchor_eye_r": ("head", tuple(K.eye_c(1.0))), "anchor_eye_l": ("head", tuple(K.eye_c(-1.0))),
     "anchor_gem": (hang["gem"][0][1], tuple(GEM_C)), "anchor_bola": (hang["bola"][0][1], tuple(np.asarray(TOP_B) + [0, 0, -0.21])),
     "anchor_wing_r": ("root", tuple(wings[0].root)), "anchor_wing_l": ("root", tuple(wings[1].root))}
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
