"""ART-1 Claire (v2, the snow-bunny sheet), stage C: join, unwrap, paint, skin, export. The recipe is kael_finish.py / cinder_finish.py.
Run: blender -b --factory-startup --python tools/art1/claire_finish.py -- <source.blend> <rig.json> <out.glb>"""
import sys, os, json, math
import bpy, bmesh
import numpy as np
from mathutils import Vector, Matrix
from mathutils.bvhtree import BVHTree
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, "..", "blender"))
import meshkit as M, claire_pieces as K, claire_paint as P
from meshkit import smooth, Piece
from paintkit import hexc, mix
import warden_kit as WK

a = sys.argv[sys.argv.index("--") + 1:]
SRC, RIG, OUT = a[0], a[1], a[2]
ATLAS = 2048
MATS = ["skin-face", "skin-body", "cloth-dress", "fur-trim", "ice-horn", "ice-wing", "ice-bright"]
SCALE = {"lid": 2.0, "finger": 1.0, "thumb": 1.0, "palm": 1.0, "ear": 0.8, "tailpuff": 0.6, "braid": 0.8, "flake": 0.5,
         "blade": 0.5, "shaft": 1.1, "head": 0.6, "butt": 0.5, "heart": 0.7, "heartcore": 0.6, "prong": 0.4, "collarA": 0.3, "collarB": 0.3, "Low": 1.0}
FACE_K = 4.6                # texel density on the face against the body

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


def body(q):
    """The scan's torso (its metres, sole at 0) -> rig: pelvis to neck."""
    x, y, z = q
    return np.array([x * K.HK, y * K.HK, K.HIPS_Z + (z - 0.90) * (K.NECK_Z - K.HIPS_Z) / 0.60])


def clear_of_body(path, gap):
    """Each point pushed out along the surface's normal until it sits `gap` off the scan, then smoothed (a plait lies on her, not in her)."""
    path = np.array(path, float)
    for _ in range(3):
        for i, q in enumerate(path):
            h = tree.find_nearest(Vector(q))
            if h[0] is None:
                continue
            hp, hn = np.array(h[0]), np.array(h[1])
            if (q - hp) @ hn < gap[i]:
                path[i] = hp + hn * gap[i]
        path[1:-1] = path[1:-1] * 0.5 + (path[:-2] + path[2:]) * 0.25
    return path


el, er = K.ear(1.0), K.ear(-1.0)
bell_ = json.loads(src["bell"])
panels = [K.skirt_panel(1.0, bell_), K.skirt_panel(-1.0, bell_)]
# the tail: on the skirt's back a hand under the sash (the sheet's back view)
tz_ = body((0, 0, 1.06))[2]
h_ = tree.ray_cast(Vector((0, -0.6, tz_)), Vector((0, 1.0, 0)), 1.0)
TAILC = np.array([0.0, (h_[0].y if h_[0] is not None else -0.13) - 0.03, tz_])
tl = K.tail_puff(TAILC)
# the braid: behind her left ear, over the shoulder and the scarf, down her front past the sash
BRAID = [K.hs((-0.09, -0.04, 1.63)), K.hs((-0.115, 0.0, 1.53)), body((-0.12, 0.07, 1.41)), body((-0.105, 0.11, 1.28)), body((-0.095, 0.12, 1.14)),
         body((-0.10, 0.115, 1.0)), body((-0.105, 0.105, 0.87))]
bp_ = M.catmull(np.array(BRAID), 26)
bp_ = clear_of_body(bp_, np.linspace(0.04, 0.03, 26))
br = K.braid(bp_)
bu_ = 0.8
bi_ = int(round(bu_ * (len(br.path) - 1)))
FLAKE_C = br.path[bi_] + np.array([0, 0.03, 0])
fl = K.snowflake(FLAKE_C, (0, 1.0, 0.0), br.path[bi_ - 1] - br.path[bi_ + 1]).rigid("hips")
sp = K.spear()
lids = [lid_piece(1.0), lid_piece(-1.0)]
hR = K.hand("R", K.GRIP_K, (1.3, 1.45, 0.95))
hL = K.hand("L", (0.0, 1.0, -0.15), (0.32, 0.42, 0.3), 0.07)
for q_ in hR + hL:
    q_.room = 0.2        # (a full ink line round each finger is a black mitt at the match camera)
pieces = [el, er, tl, br, fl, K.blade(1.0), K.blade(-1.0)] + [K.fur_cuff("R"), K.fur_cuff("L")] + K.candy_laces("R", tree) + K.candy_laces("L", tree) + sp + lids + hR + hL + [K.cuff_cap("R"), K.cuff_cap("L")] + panels


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


ear_chain = {}
for sg, p_, sd in ((1.0, el, "R"), (-1.0, er, "L")):
    pts = K.ear_points(p_)
    nm = ["spring_ear%s_%d" % (sd, i) for i in range(len(pts))]
    ear_chain[sd] = (nm, pts)
    chain_w(p_, pts, nm)
braid_pts = K.braid_points(br)
braid_nm = ["spring_scarftail_braid_%d" % i for i in range(len(braid_pts))]
chain_w(br, braid_pts, braid_nm)
chain_w(fl, braid_pts, braid_nm)

for p_ in pieces:
    n_ = p_.name
    if n_.startswith(("flake", "heart", "blade")):
        continue                       # (built wound; two faced)
    if n_.startswith("skirtpanel"):
        continue
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
rooms.extend((0.4 - 0.34 * smooth(0.02, 0.06, np.array([v.co.y for v in me0.vertices])) * smooth(K.NECK_Z + 0.06, K.NECK_Z + 0.1, np.array([v.co.z for v in me0.vertices])) * smooth(0.15, 0.12, np.abs(np.array([v.co.x for v in me0.vertices])))).tolist())
for p in me0.polygons:
    faces_v.append(list(p.vertices))
    faces_pid.append(0)
    faces_uv.append(None)
# the face moves: brows and mouth corners pull the scan's own skin (its paint rides along)
HEAD = np.array(verts)
DEFORM = {}
for sg, sd in ((1.0, "R"), (-1.0, "L")):
    DEFORM["brow." + sd] = (K.hs([sg * 0.055, 0.088, 1.705]), 0.026)
    DEFORM["mouth." + sd] = (K.hs([sg * 0.024, 0.1, 1.60]), 0.015)
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
FACE_C = K.hs([0, 0.0, 1.668])
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
    if part == "head" and c[1] > 0.035 and abs(c[0]) < 0.1 and abs(c[2] - FACE_C[2]) < 0.112:
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
FID = -np.ones((ATLAS, ATLAS), np.int32)
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
    FID[ys[m], xs[m]] = t.polygon_index
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

# each scan face's slot, by its paint (her hair shades as paint on the face's surface: the hair slot's toon goes slate on a pale colour)
is_hair = np.zeros(nf, bool)
arm_face = np.zeros(nf, bool)
low_faces = [i for i in range(nf) if faces_pid[i] == 0]
fc = np.array([np.mean([verts[v] for v in faces_v[i]], axis=0) for i in low_faces])
fcol = sample_scan(fc)
for k_, i in enumerate(low_faces):
    r_, g_, b_ = fcol[k_]
    mx, mn = max(r_, g_, b_), min(r_, g_, b_)
    pink = r_ > b_ * 1.04
    blue = (b_ - r_) > 0.1 and (mx - mn) / max(mx, 0.01) > 0.3
    if i in face_i and pink:
        m = "skin-face"
    elif i in face_i:
        m = "skin-face"
        is_hair[i] = not (abs(fc[k_][0]) < 0.075 and fc[k_][2] < K.hs([0, 0, 1.72])[2])
    elif pink and fc[k_][2] > K.NECK_Z:
        m = "skin-face"
    elif blue and (mx < 0.62):
        m = "cloth-dress"
    else:
        m = "fur-trim"
    me.polygons[i].material_index = mat_i[m]
    arm_face[i] = sum(w_ for b_, w_ in vw[faces_v[i][0]].items() if b_.startswith(("forearm", "upper_arm", "hand"))) > 0.5

mask = PID == 0
ys, xs = np.nonzero(mask)
pp = POS[ys, xs].astype(np.float64)
col = sample_scan(pp)
print("scan paint", col.mean(0))
# the scan drew her glove and cuff into the skirt's sides: those sides take the dress from further round the front
az_ = np.abs(np.arctan2(pp[:, 1], np.abs(pp[:, 0])))
side_ = smooth(0.62, 0.42, az_) * (np.abs(pp[:, 0]) > 0.1) * smooth(0.74, 0.8, pp[:, 2]) * smooth(1.04, 0.98, pp[:, 2]) * (~arm_face[FID[ys, xs]])
sid_ = np.nonzero(side_ > 0.01)[0]
if len(sid_):
    th_ = 0.7
    q_ = pp[sid_].copy()
    sgn_ = np.sign(q_[:, 0])
    q_[:, 0], q_[:, 1] = q_[:, 0] * np.cos(th_) - sgn_ * q_[:, 1] * np.sin(th_), sgn_ * q_[:, 0] * np.sin(th_) + q_[:, 1] * np.cos(th_)
    col[sid_] = col[sid_] * (1 - side_[sid_, None]) + sample_scan(q_) * side_[sid_, None]
col = np.power(np.clip(col, 0, 1), 0.92) * 1.06
OUTC = np.zeros((ATLAS, ATLAS, 3), np.float32)
r_, g_, b_ = col[:, 0], col[:, 1], col[:, 2]
# the dress blues up to the sheet's saturation
sat = (col.max(1) - col.min(1)) / np.maximum(col.max(1), 0.01)
bl = smooth(0.05, 0.2, b_ - r_) * smooth(0.25, 0.5, sat) * smooth(0.72, 0.6, col.max(1))
lum_ = col.mean(1, keepdims=True)
vivid = np.clip((col - lum_) * 1.5 + lum_, 0, 1) * np.array([0.9, 1.06, 1.32])
col = col * (1 - bl[:, None]) + vivid * bl[:, None]
# the white fur and scarf held under the light (a pure white blows out at the match camera), cooled toward the sheet's ice blue
mx_ = col.max(1)
lt = smooth(0.5, 0.8, mx_) * (1 - bl) * (pp[:, 2] < K.NECK_Z + 0.12) + smooth(0.5, 0.8, mx_) * (1 - bl) * (pp[:, 1] < 0.0) * (pp[:, 2] >= K.NECK_Z + 0.12)
lt = lt * ~np.isin(FID[ys, xs], list(face_i))     # (not her face: the neck line crosses it)
col = col * (1 - lt[:, None]) + col * np.array([0.8, 0.87, 0.97]) * lt[:, None]
OUTC[ys, xs] = col
# hair round the face: the sheet's ice blue over the scan's slate, its shading kept
hair_ = is_hair[FID[ys, xs]]
hc = OUTC[ys[hair_], xs[hair_]].astype(np.float64)
OUTC[ys[hair_], xs[hair_]] = P.ramp(np.clip((hc.mean(1) - 0.2) / 0.5, 0, 1), P.HAIR)
# (the face is the scan's own paint: the v2 sheet's face came through the scan whole)

def paint(pred, fn):
    ids = [i for i, n in enumerate(names) if pred(n)]
    m = np.isin(PID, ids)
    yy, xx = np.nonzero(m)
    if len(yy):
        OUTC[yy, xx] = fn(POS[yy, xx].astype(np.float64), NOR[yy, xx].astype(np.float64), AO[yy, xx].astype(np.float64))


paint(lambda n: n.startswith(("palm", "finger", "thumb", "cuffcap")), P.glove)


def panel_paint(p_, n_, ao_, th_=0.72):
    """The dress from further round the front, where the scan is clean."""
    q_ = p_.copy()
    sg_ = np.sign(q_[:, 0])
    q_[:, 0], q_[:, 1] = q_[:, 0] * np.cos(th_) - sg_ * q_[:, 1] * np.sin(th_), sg_ * q_[:, 0] * np.sin(th_) + q_[:, 1] * np.cos(th_)
    c_ = np.power(np.clip(sample_scan(q_), 0, 1), 0.92) * 1.06
    l_ = c_.mean(1, keepdims=True)
    return np.clip(c_ * 0.0 + (np.clip((c_ - l_) * 1.5 + l_, 0, 1) * np.array([0.9, 1.06, 1.32])), 0, 1)


paint(lambda n: n.startswith("skirtpanel"), panel_paint)
paint(lambda n: n == "earR", lambda p, n, ao: P.ear(p, n, ao, el.path, el.wd))
paint(lambda n: n == "earL", lambda p, n, ao: P.ear(p, n, ao, er.path, er.wd))
paint(lambda n: n == "tailpuff", lambda p, n, ao: P.puff(p, n, ao, TAILC))
paint(lambda n: n == "braid", lambda p, n, ao: P.braid(p, n, ao, br.path))
paint(lambda n: n == "flake", P.flake)
paint(lambda n: n.startswith("blade"), P.blade)
paint(lambda n: n == "shaft", P.shaft)
paint(lambda n: n.startswith("lace"), P.lace)
paint(lambda n: n.startswith("bootcuff"), P.puff_cuff)
paint(lambda n: n in ("head", "butt") or n.startswith("prong"), P.crystal)
paint(lambda n: n == "heart", lambda p, n, ao: P.heart(p, n, ao, K.sp(0.683), 0.082))
paint(lambda n: n == "heartcore", lambda p, n, ao: P.heart(p, n, ao, K.sp(0.68), 0.07) * 0.9 + 0.1)
paint(lambda n: n.startswith("collar"), P.collar)
# the lid: her own skin colour, a lash line at its lower edge
skin_c = hexc("#ecd2dc")
for q, sg in ((lids[0], 1.0), (lids[1], -1.0)):
    def liner(p_, qq=q):
        ca, sa = math.cos(-LID_A), math.sin(-LID_A)
        d = p_ - qq.c
        zz = d[:, 1] * sa + d[:, 2] * ca + qq.c[2]
        return smooth(K.eye_c(1.0)[2] - K.EYE_H * K.HK * 0.72, K.eye_c(1.0)[2] - K.EYE_H * K.HK * 0.92, zz)
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

atlas = bpy.data.images.new("claire_atlas", ATLAS, ATLAS)
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
knuck = np.array([-K.SH, 0.0, K.HAND_Z - 0.058])
bone("fingers.L", "hand.L", knuck, knuck + [0, 0, -0.06])
thm = np.array([-K.SH, 0.03, K.HAND_Z - 0.012])
bone("thumb.L", "hand.L", thm, thm + [0, 0.02, -0.05])
for sd in "RL":
    spring(*ear_chain[sd], "head")
spring(braid_nm, braid_pts, "head")
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
b_, e_ = K.spear_frame()
A = {"anchor_head_top": ("head", (0, 0.0, K.NECK_Z + 0.33)), "anchor_chest": ("hips", (0, 0.1, K.SHOULDER_Z - 0.09)),
     "weapon_muzzle": ("hand.R", tuple(K.sp(K.TIP_U))), "anchor_blade_root": ("hand.R", tuple(K.sp(0.74))), "anchor_blade_mid": ("hand.R", tuple(K.sp(0.88))),
     "anchor_eye_r": ("head", tuple(K.eye_c(1.0))), "anchor_eye_l": ("head", tuple(K.eye_c(-1.0))),
     "anchor_skate_r": ("foot.R", (K.THIGH_X, 0.0, 0.01)), "anchor_skate_l": ("foot.L", (-K.THIGH_X, 0.0, 0.01)),
     "anchor_tail_tip": ("root", tuple(TAILC + [0, -0.05, 0])), "anchor_clasp": (braid_nm[3], tuple(FLAKE_C))}
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
