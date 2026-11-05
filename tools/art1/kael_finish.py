"""ART-1 Kael, stage C: join, unwrap, paint, skin, export.
Run: blender -b --factory-startup --python tools/art1/kael_finish.py -- <source.blend> <rig.json> <out.glb> [clips.py]"""
import sys, os, json, math
import bpy, bmesh
import numpy as np
from mathutils import Vector, Matrix
from mathutils.bvhtree import BVHTree
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, "..", "blender"))
import meshkit as M, kael_pieces as K, kael_paint as P
from meshkit import smooth
import warden_kit as WK

a = sys.argv[sys.argv.index("--") + 1:]
SRC, RIG, OUT = a[0], a[1], a[2]
HEAD_GLB = os.path.expanduser("~/meshy/kael_h/bake/low.glb")
ART_PATH = os.path.expanduser("~/art1kael/ref2/kael_art_fb.png")
ATLAS = 2048
UNIQ_W = 0.755                       # the unique islands' share of the atlas width; the tiles sit to its right
HAIR_R = (UNIQ_W + 0.005, 0.40, 0.90, 1.0)
BLADE_R = (0.905, 0.40, 1.0, 1.0)
CHAIN_R = (UNIQ_W + 0.005, 0.30, 0.875, 0.395)
HOOK_R = (0.88, 0.30, 1.0, 0.395)
EYE_R = (UNIQ_W + 0.005, 0.20, 0.875, 0.295)
EYE2_R = (UNIQ_W + 0.005, 0.10, 0.875, 0.195)
GLOW_R = (0.88, 0.20, 1.0, 0.295)
HALO_R = (0.88, 0.10, 1.0, 0.195)
MATS = ["skin-kael", "skin-kael-hot", "cloth-kael", "cloth-ember-hot", "metal-kael", "hair-mane", "skin-head-hot", "metal-sword-hot"]
SCALE = {"face": 4.0, "lidU": 2.6, "lidD": 2.6, "mask": 1.2, "cowl": 2.0, "cowlcore": 0.2, "stail": 0.7, "palm": 2.0, "finger": 1.8,
         "thumb": 1.8, "skull": 0.4, "blade": 0.75, "guard": 1.4, "grip": 1.6, "pommel": 1.6, "Low": 2.4, "maskfit": 2.0}

bpy.ops.wm.open_mainfile(filepath=SRC)
src, low = bpy.data.objects["Src"], bpy.data.objects["Low"]
depsgraph = bpy.context.evaluated_depsgraph_get()
bvh_low = BVHTree.FromObject(low, depsgraph)


def load_rgb(path):
    im_ = bpy.data.images.load(path)
    w_, h_ = im_.size
    px_ = np.zeros(w_ * h_ * im_.channels, np.float32)
    im_.pixels.foreach_get(px_)
    return px_.reshape(h_, w_, im_.channels)[::-1, :, :3]


def tile_uv(r, uv):
    u0, v0, u1, v1 = r
    return [[(u0 + (u1 - u0) * u, v0 + (v1 - v0) * v) for u, v in face] for face in uv]


hair_tile_uv = (0, 0, 1, 1)
WEAP = load_rgb(os.path.expanduser("~/art1kael/ref2/kael_weapons_full.png"))
tails = [K.scarf_tail("R"), K.scarf_tail("L")]
pieces = list(tails)
pieces += K.hand("R", K.GRIP_DIR, (1.25, 1.35, 0.9), 0.0)
pieces += K.hand("L", (0.0, 1.0, -0.15), (0.55, 0.75, 0.5), 0.05)
locks = K.mane()[1:]         # (no cap: the head scan has the crown)
locks = [l_ for l_ in locks if l_.name.startswith(("back", "over"))]
chains = K.mane_chains(locks)
pieces += locks
pieces.append(K.wrist_chain((0, 0, 1, 1)))
hang, hook, hang_pts = K.hanging_chain((0, 0, 1, 1))
cuff, cuff_pts = None, None
pieces += [hang, hook] + K.blade(WEAP) + K.hilt((0, 0, 1, 1))

# ---- faces wound outward (the game culls back faces)
HEAD_C = tuple(K.C)
for p_ in pieces:
    n_ = p_.name
    if n_.startswith("stail") or n_ == "headscan" or n_ == "maskfit":
        pass        # (two sheets back to back, wound as built)
    else:
        p_.orient()

# ---- the hair's depth: root shade and layers, in the vertex colour (warden_look hair: vertex_ao)
for p_ in locks:
    layer = 0.86 if p_.name.startswith("back") else 1.0
    p_.shade = np.ones(len(p_.v)) if p_.name.startswith("sweep") else layer * (0.72 + 0.28 * smooth(0.0, 0.22, p_.t))

# ---- weights of the spring-hung pieces
def along_chain(p, names, pts, top_bone):
    pts = np.asarray(pts)
    w = {n: np.zeros(len(p.v)) for n in names[:-1]}
    for i, v in enumerate(p.v):
        d = (pts[0][2] - v[2]) / max(pts[0][2] - pts[-1][2], 1e-6)
        x = np.clip(d, 0, 0.9999) * (len(names) - 1)
        b = int(x)
        w[names[b]][i] = 1.0                 # rigid links
    p.w = w


HANG = ["spring_hangwarchain_%d" % i for i in range(len(hang_pts))]
along_chain(hang, HANG, hang_pts, "hand.R")
hook.w = {HANG[-2]: np.ones(len(hook.v))}
TAIL_N = 9
TAILS = {}
for p_ in tails:
    g_ = p_.name[-1].lower()
    names_ = ["spring_scarftail_%s_%d" % (g_, i) for i in range(TAIL_N)]
    idx = np.linspace(0.04, 1.0, TAIL_N)
    s_ = np.linspace(0, 1, len(p_.path))
    TAILS[g_] = (names_, [tuple(np.interp(t_, s_, p_.path[:, i]) for i in range(3)) for t_ in idx])
    w_ = {n: np.zeros(len(p_.v)) for n in names_[:-1]}
    w_["hips"] = np.zeros(len(p_.v))
    for i, t_ in enumerate(p_.t):
        u = float(smooth(0.03, 0.1, t_))
        x = np.clip((t_ - 0.04) / 0.96, 0, 0.9999) * (TAIL_N - 1)
        b_ = int(x)
        q = x - b_
        w_["hips"][i] = 1 - u
        w_[names_[b_]][i] += u * (1 - q)
        w_[names_[min(b_ + 1, TAIL_N - 2)]][i] += u * q
    p_.w = w_

# ---- the head: its own Meshy run from the sculpt sheet, baked to a dense low mesh with its own texture (tools/art1/kael_head_bake.json)
bpy.ops.import_scene.gltf(filepath=HEAD_GLB)
head_ob = next(o for o in bpy.context.selected_objects if o.type == "MESH")
head_img = None
for nd in head_ob.data.materials[0].node_tree.nodes:
    if nd.type == "TEX_IMAGE":
        head_img = nd.image
h_mw = head_ob.matrix_world.copy()
hv = np.array([h_mw @ v.co for v in head_ob.data.vertices])
# (glTF splits a vertex at every UV seam: welded here, or each island shades as a hard shard)
_, h_first, h_map = np.unique(np.round(hv, 5), axis=0, return_index=True, return_inverse=True)
hv = hv[h_first]
hv_m = hv.copy()                                                  # (the scan's own frame: the sheet projects in it)
hv = np.stack([-hv[:, 0], -hv[:, 1], hv[:, 2]], 1)                # (Meshy frame faces -Y: to +Y)
band = (hv[:, 2] > K.SCAN_EYE_Z - 0.3) & (hv[:, 2] < K.SCAN_EYE_Z + 0.1) & (np.abs(hv[:, 0]) < 0.3)
nose_y = hv[band, 1].max()
face_at = np.array([K.SCAN_EYE_X, nose_y, K.SCAN_EYE_Z])
hs_ = K.EYE_GAP / K.SCAN_EYE_GAP
hv = (hv - face_at) * hs_
# the scarf opens out below the chin to the sheet's width and reaches the chest
drop = -(hv[:, 2] + K.CHIN_DROP)
kd = smooth(0.0, 0.11, drop)
hv[:, 0] *= 1 + K.SCARF_WIDEN * kd
hv[:, 1] = (hv[:, 1] + K.NOSE_DEPTH) * (1 + K.SCARF_WIDEN * 0.7 * kd) - K.NOSE_DEPTH
hv[:, 2] -= np.maximum(drop, 0.0) * 0.45
hv = hv + np.array([0.0, K.NOSE_Y, K.EYE_Z])
hf = [[int(h_map[i_]) for i_ in p.vertices] for p in head_ob.data.polygons]
hu = head_ob.data.uv_layers[0].data
huv = [[tuple(hu[li].uv) for li in p.loop_indices] for p in head_ob.data.polygons]
hk = 1.0 - smooth(K.NECK_Z - 0.09, K.NECK_Z + 0.03, hv[:, 2])         # (0 on the head, 1 down on the shoulders)
hw = {"head": 1 - hk, "hips": hk}
for sd_, sg_ in (("R", 1.0), ("L", -1.0)):
    c_ = K.hl(np.array([sg_ * 0.04, 0.09, 0.043]))
    hw["brow." + sd_] = (1 - smooth(0.012, 0.03, np.linalg.norm(hv - c_, axis=1))) * (hv[:, 1] > 0.05)
    hw["head"] = hw["head"] - hw["brow." + sd_] * hw["head"]
head_bvh = BVHTree.FromPolygons([tuple(v_) for v_ in hv], [tuple(f_) for f_ in hf])
mask_pc = K.mask_on(head_bvh)
pieces.append(mask_pc)
head_pc = M.Piece("headscan", "skin-head-hot", hv, hf, huv, weights=hw, room=0.1)
pieces.append(head_pc)
head_tex = np.zeros(head_img.size[0] * head_img.size[1] * head_img.channels, np.float32)
head_img.pixels.foreach_get(head_tex)
head_tex = head_tex.reshape(head_img.size[1], head_img.size[0], head_img.channels)
# the sculpt sheet's main view projected on the front of the head (scar, brows, stubble, fissures come from the art), then graded
# by class to flat ramps the toon light keeps dark and clean
SHEET = load_rgb(os.path.expanduser("~/art1kael/ref2/kael_head.png"))
H_, W_ = head_tex.shape[:2]
hvn = np.zeros_like(hv_m)
for f_ in hf:
    p0_ = hv_m[f_[0]]
    n_ = np.cross(hv_m[f_[1]] - p0_, hv_m[f_[2]] - p0_)
    hvn[f_] += n_
hvn = M.norm(hvn)
HP = np.zeros((H_, W_, 3), np.float32)
HN = np.zeros((H_, W_, 3), np.float32)
HM = np.zeros((H_, W_), bool)
for f_, u_ in zip(hf, huv):
    for k_ in range(1, len(f_) - 1):
        ids_ = [f_[0], f_[k_], f_[k_ + 1]]
        q_ = np.array([u_[0], u_[k_], u_[k_ + 1]]) * [W_, H_] - 0.5
        x0_, y0_ = np.maximum(np.floor(q_.min(0)).astype(int) - 1, 0)
        x1_, y1_ = np.ceil(q_.max(0)).astype(int) + 1
        x1_, y1_ = min(x1_, W_ - 1), min(y1_, H_ - 1)
        if x1_ < x0_ or y1_ < y0_:
            continue
        yy_, xx_ = np.mgrid[y0_:y1_ + 1, x0_:x1_ + 1]
        d_ = (q_[1, 1] - q_[2, 1]) * (q_[0, 0] - q_[2, 0]) + (q_[2, 0] - q_[1, 0]) * (q_[0, 1] - q_[2, 1])
        if abs(d_) < 1e-9:
            continue
        l0_ = ((q_[1, 1] - q_[2, 1]) * (xx_ - q_[2, 0]) + (q_[2, 0] - q_[1, 0]) * (yy_ - q_[2, 1])) / d_
        l1_ = ((q_[2, 1] - q_[0, 1]) * (xx_ - q_[2, 0]) + (q_[0, 0] - q_[2, 0]) * (yy_ - q_[2, 1])) / d_
        l2_ = 1 - l0_ - l1_
        m_ = (l0_ >= -0.03) & (l1_ >= -0.03) & (l2_ >= -0.03)
        w_ = np.stack([l0_[m_], l1_[m_], l2_[m_]], -1)
        HP[yy_[m_], xx_[m_]] = w_ @ hv_m[ids_]
        HN[yy_[m_], xx_[m_]] = w_ @ hvn[ids_]
        HM[yy_[m_], xx_[m_]] = True
ys_, xs_ = np.nonzero(HM)
px_ = np.clip((K.SHEET_FRONT[0] + (HP[ys_, xs_, 0] + K.SCAN_EYE_X) * K.SHEET_FRONT[2]).astype(int), 0, SHEET.shape[1] - 1)
py_ = np.clip((K.SHEET_FRONT[1] - (HP[ys_, xs_, 2] - K.SCAN_EYE_Z) * K.SHEET_FRONT[2]).astype(int), 0, SHEET.shape[0] - 1)
art_ = SHEET[py_, px_]
ch_ = head_tex[..., :3]
sc_ = ch_[ys_, xs_]
hair_ = lambda c_: ((c_.max(1) - c_.min(1)) < 0.14) & (c_.mean(1) > 0.42)
facing_ = -M.norm(HN[ys_, xs_])[:, 1]
k_ = smooth(0.3, 0.6, facing_) * (~hair_(art_)) * (~hair_(sc_))
ch_[ys_, xs_] = sc_ * (1 - k_[:, None]) + art_ * k_[:, None]
ch_[...] = P.grade_head(ch_)
head_tex[..., :3] = ch_
# (a new image: the exporter writes an imported image's packed original, whatever its pixels say)
head_new = bpy.data.images.new("kael_head", head_img.size[0], head_img.size[1])
head_new.pixels.foreach_set(head_tex.ravel())
head_new.filepath_raw = os.path.join(os.path.dirname(OUT), "head.png")
head_new.file_format = "PNG"
head_new.save()
head_img = head_new
head_tex = head_tex[..., :3]
bpy.data.objects.remove(head_ob)

# ---- one mesh: the scan first, then the pieces
faces_v, faces_pid, faces_uv, verts, vw, rooms, shades = [], [], [], [], [], [], []
names = []


def add_ob(ob, name, room):
    pid = len(names)
    names.append(name)
    me = ob.data
    base = len(verts)
    verts.extend([tuple(v.co) for v in me.vertices])
    gn = {g.index: g.name for g in ob.vertex_groups}
    for v in me.vertices:
        d = {gn[g.group]: g.weight for g in v.groups if g.weight > 0.01}
        vw.append(d)
    rooms.extend([room] * len(me.vertices))
    shades.extend([1.0] * len(me.vertices))
    mn = [m.name for m in me.materials]
    for p in me.polygons:
        faces_v.append([base + i for i in p.vertices])
        faces_pid.append(pid)
        faces_uv.append(None)
    return mn, pid


low_mats, low_pid = add_ob(low, "Low", 1.0)
low_poly_mat = [low_mats[p.material_index] for p in low.data.polygons]
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
pid_arr = np.array(faces_pid)
print("tris", sum(len(p.vertices) - 2 for p in me.polygons), "verts", len(me.vertices))


def base_name(n):
    return n.rstrip("RL0123456789_").rstrip("_")


def is_tile(n):
    return n == "headscan" or n == "blade" or n.startswith(("sweep", "fore", "back", "over", "brow", "chain_", "hook", "eye", "core"))


# material per face
mat_i = {m: i for i, m in enumerate(MATS)}
PIECE_MAT = {pc.name: pc.mat for pc in pieces}
for i, p in enumerate(me.polygons):
    n = names[faces_pid[i]]
    if n == "Low":
        m = low_poly_mat[i]
        m2 = "skin-kael"          # (by the scan's paint, below)
    else:
        pm = PIECE_MAT[n]
        m2 = {"metal-chain": "metal-kael", "metal-hook": "metal-kael", "metal-blade": "metal-sword-hot", "glow-sword": "metal-sword-hot", "metal-guard": "metal-kael", "metal-kael": "metal-kael",
              "leather-grip": "cloth-kael", "hair-brow": "hair-mane"}.get(pm, pm)
        if n.startswith(("cowl", "stail", "coreh")):
            m2 = "cloth-ember-hot"
        if n == "eye" + K.GLOW_EYE:
            m2 = "eyes-glow-hot"    # the eye under the scar glows
    p.material_index = mat_i[m2]

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
uvl = bm.loops.layers.uv["UV"]
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
# the scan unwraps by body part: seams between parts and round each limb's sides, so the paint stays in big clean islands
PARTS = {"upper_arm.R": "armR", "forearm.R": "armR", "pauldron.R": "armR", "hand.R": "armR", "upper_arm.L": "armL", "forearm.L": "armL",
         "pauldron.L": "armL", "hand.L": "armL", "thigh.R": "legR", "shin.R": "legR", "foot.R": "legR", "thigh.L": "legL", "shin.L": "legL",
         "foot.L": "legL"}
region = {}
for i in range(nf):
    n = names[faces_pid[i]]
    if n != "Low":
        continue
    tally = {}
    for vi in faces_v[i]:
        for b, w_ in vw[vi].items():
            p_ = PARTS.get(b, "torso")
            tally[p_] = tally.get(p_, 0) + w_
    part = max(tally, key=tally.get) if tally else "torso"
    c = np.mean([verts[v] for v in faces_v[i]], axis=0)
    limb_x = {"armR": K.SH, "armL": -K.SH}.get(part)
    front = c[1] > 0.0
    region[i] = (part, front)
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
# flat maps where a clean sheet of paint matters: the face from the front, the mask and cowl round the neck
for i in uniq:
    n = names[faces_pid[i]]
    f = bm.faces[i]
    if n == "face":
        for l in f.loops:
            l[uvl].uv = (l.vert.co.x * 1.0 + 4, l.vert.co.z - 1.4 + 6)
    elif n == "mask":
        off = 7
        cs = [(math.atan2(l.vert.co.x, l.vert.co.y) * 0.75) for l in f.loops]
        # (the seam at the back: faces straddling it unroll on one side)
        if max(cs) - min(cs) > 2.2:
            cs = [c + 2 * math.pi * 0.75 if c < 0 else c for c in cs]
        for l, c in zip(f.loops, cs):
            l[uvl].uv = (c * 0.14 + off, l.vert.co.z - 1.2 + 6)
# scale each piece to its texel density
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
    k = base_name(n)
    wgt = SCALE.get(k, 1.0)
    if i in region:
        wgt *= 1.5 if region[i][0] == "armR" else 1.0
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
# the unique block into its share; the tiles to their rectangles
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
    if n == "headscan":
        for l, (x, y) in zip(ls, fu):
            loop_uv[l] = (x, y)
        continue
    if n == "blade":
        r = BLADE_R
    elif n.startswith(("chain_", "wrap")):
        r = CHAIN_R
    elif n.startswith("hook"):
        r = HOOK_R
    elif n.startswith("eye"):
        r = EYE_R
    elif n.startswith("coreh"):
        r = HALO_R
    elif n.startswith("core"):
        r = GLOW_R
    else:
        r = HAIR_R
    if n.startswith("eye"):
        r = EYE2_R if n == "eye" + K.GLOW_EYE else EYE_R
        pc = next(q for q in pieces if q.name == n)
        ev = np.array(p.vertices) - (faces_v[i][0] - pc.f[i - faces_pid.index(faces_pid[i])][0])
        coords = pc.eye_uv[ev]
        for l, (x, y) in zip(ls, coords):
            loop_uv[l] = (r[0] + (r[2] - r[0]) * (x * 0.5 + 0.5), r[1] + (r[3] - r[1]) * (y / 1.5 + 0.5))
        continue
    if fu is None:
        for l in ls:
            loop_uv[l] = ((r[0] + r[2]) / 2, (r[1] + r[3]) / 2)
        continue
    for l, (x, y) in zip(ls, fu):
        loop_uv[l] = (r[0] + (r[2] - r[0]) * x, r[1] + (r[3] - r[1]) * y)
uvd.foreach_set("uv", loop_uv.ravel())
me.update()

dbg = {}
for p_ in me.polygons:
    n_ = names[faces_pid[p_.index]]
    if not is_tile(n_):
        b_ = dbg.setdefault(n_, [9, 9, -9, -9, 0])
        q_ = loop_uv[list(p_.loop_indices)]
        b_[0], b_[1] = min(b_[0], q_[:, 0].min()), min(b_[1], q_[:, 1].min())
        b_[2], b_[3] = max(b_[2], q_[:, 0].max()), max(b_[3], q_[:, 1].max())
        b_[4] += 1
for k_, v_ in dbg.items():
    print("uv", k_, [round(float(x), 3) for x in v_])
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
    n = names[faces_pid[t.polygon_index]]
    if is_tile(n):
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
NOR = M.norm(NOR)
print("texels", (PID >= 0).sum(), "of", ATLAS * ATLAS)

# ---- ambient occlusion, baked by Cycles on the unique islands
ao_img = bpy.data.images.new("ao", ATLAS, ATLAS, float_buffer=True)
sc = bpy.context.scene
sc.render.engine = "CYCLES"
sc.cycles.device = "CPU"
sc.cycles.samples = 48
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
    """Box blur of a over the mask m (normalised), radius r."""
    def box(z):
        c_ = np.cumsum(np.cumsum(z, 0), 1)
        c_ = np.pad(c_, ((r + 1, r), (r + 1, r)), mode="edge")
        c_[:r + 1, :] = 0
        c_[:, :r + 1] = 0
        return c_[2 * r + 1:, 2 * r + 1:] - c_[:-2 * r - 1, 2 * r + 1:] - c_[2 * r + 1:, :-2 * r - 1] + c_[:-2 * r - 1, :-2 * r - 1]
    return box(a * m) / np.maximum(box(m), 1e-3)


AO = blur(AO, (PID >= 0).astype(np.float32), 3)

# ---- the scan's paint on the shipped body: nearest surface; the sword arm from the clean left arm
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
    """The scan's paint at the nearest surface to each point (display values)."""
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


# each scan face's slot, by its paint
low_faces = [i for i in range(nf) if faces_pid[i] == low_pid]
fc = np.array([np.mean([verts[v] for v in faces_v[i]], axis=0) for i in low_faces])
fcol = sample_scan(fc)
L_ = fcol.mean(1)
sat = (fcol.max(1) - fcol.min(1)) / np.maximum(fcol.max(1), 0.01)
for k_, i in enumerate(low_faces):
    r_, g_, b_ = fcol[k_]
    if sat[k_] < 0.14 and L_[k_] > 0.34:
        m = "metal-kael"
    elif sat[k_] < 0.24:
        m = "cloth-kael"
    elif L_[k_] > 0.5 or (r_ > g_ * 1.7 and b_ > g_ * 0.7):
        m = "cloth-kael"      # the bandages, the scan's own scarf
    elif region[i][0] == "armR" and r_ > g_ * 1.1:
        m = "skin-kael-hot"
    elif region[i][0] in ("armL", "torso") and r_ > g_ * 1.25:
        m = "skin-kael"
    else:
        m = "cloth-kael"
    me.polygons[i].material_index = mat_i[m]

# ---- the flat art projected on the body: front and back turnaround views through the bones (kael_source art_map); where the art
# has no body (grey ground, hair or tails over it), or the surface turns side on, the scan's own paint
ART = np.load(os.path.splitext(SRC)[0] + "_art.npz")
ART_IMG = load_rgb(ART_PATH)


def bary_of(points):
    hit_i = np.zeros(len(points), np.int64)
    hit_p = np.zeros((len(points), 3))
    for i, p in enumerate(points):
        h = tree.find_nearest(Vector(p))
        if h[2] is not None:
            hit_i[i] = h[2]
            hit_p[i] = h[0]
    tv = svco[tri_v[hit_i]]
    v0, v1, v2 = tv[:, 1] - tv[:, 0], tv[:, 2] - tv[:, 0], hit_p - tv[:, 0]
    d00, d01, d11 = (v0 * v0).sum(1), (v0 * v1).sum(1), (v1 * v1).sum(1)
    d20, d21 = (v2 * v0).sum(1), (v2 * v1).sum(1)
    den = np.maximum(d00 * d11 - d01 * d01, 1e-14)
    bv = (d11 * d20 - d01 * d21) / den
    bw = (d00 * d21 - d01 * d20) / den
    return hit_i, np.stack([1 - bv - bw, bv, bw], 1)


mask = PID == low_pid
ys, xs = np.nonzero(mask)
points = POS[ys, xs]
col = sample_scan(points)
col = np.power(np.clip(col, 0, 1), 0.85) * 1.1
hi_, bc_ = bary_of(points)
nrm_ = NOR[ys, xs]
h_, w_ = ART_IMG.shape[:2]
for nm_, sign_ in (("front", 1.0), ("back", -1.0)):
    uvq = (ART[nm_][tri_v[hi_]] * bc_[..., None]).sum(1)
    ix = np.clip(uvq[:, 0].round().astype(int), 0, w_ - 1)
    iy = np.clip(uvq[:, 1].round().astype(int), 0, h_ - 1)
    a_ = ART_IMG[iy, ix]
    m_ = a_.max(1)
    sat_ = (m_ - a_.min(1)) / np.maximum(m_, 0.01)
    ground = (sat_ < 0.05) & (a_.mean(1) > 0.68) & (a_.mean(1) < 0.83)
    white = (sat_ < 0.1) & (a_.mean(1) > 0.84)
    red = (a_[:, 0] > 0.22) & (a_[:, 0] > a_[:, 1] * 2.4) & (a_[:, 0] > a_[:, 2] * 1.7)
    drop = ground | white | (red if nm_ == "back" else (red & (points[:, 2] < K.HAND_Z)))
    k = smooth(0.12, 0.42, nrm_[:, 1] * sign_) * (~drop)
    col = col * (1 - k[:, None]) + a_ * k[:, None]
OUTC = np.zeros((ATLAS, ATLAS, 3), np.float32)
OUTC[ys, xs] = col
ART_DONE = True
# a little of the shared light's occlusion on the scan too
OUTC[ys, xs] *= (0.88 + 0.12 * np.clip(AO[ys, xs], 0, 1))[:, None]

# flat class ramps for the match camera: each class keeps its forms (a band of its own light) and dark line work, the mottling goes
lumi = OUTC.mean(2)
r_, g_, b_ = OUTC[..., 0], OUTC[..., 1], OUTC[..., 2]
hi_ = OUTC.max(2)
sat_t = (hi_ - OUTC.min(2)) / np.maximum(hi_, 0.01)
isbody = PID == low_pid
hotish = (r_ > 0.72) & (g_ > 0.48) & (b_ < 0.75) & (sat_t > 0.2)
red_t = isbody & (r_ > g_ * 2.0) & (r_ > b_ * 1.6) & ~hotish
silver_t = isbody & (sat_t < 0.2) & (lumi > 0.36) & ~hotish
dark_t = isbody & (sat_t < 0.34) & (lumi <= 0.36) & (b_ >= r_ * 0.9)
skin_t = isbody & (r_ > b_ * 1.02) & ~hotish & ~red_t & ~silver_t & ~dark_t
for cls_, ramp_, base_, gain_, wide_ in ((skin_t, P.SKIN2, 0.4, 3.0, 0.7), (silver_t, P.SILVER, 0.48, 3.4, 1.6), (dark_t, P.DARK, 0.34, 2.2, 0.7), (red_t, P.RED, 0.45, 2.2, 0.7)):
    fm_ = cls_.astype(np.float32)
    l1_ = blur(lumi, fm_, 2)
    l2_ = blur(lumi, fm_, 18)
    mean_ = float(np.sum(lumi * fm_) / max(fm_.sum(), 1.0))
    t_ = np.clip(base_ + (l1_ - l2_) * gain_ + (l2_ - mean_) * wide_, 0, 1)
    new_ = P.ramp(t_, ramp_) + np.minimum(lumi - l1_, 0.0)[..., None] * 0.8
    OUTC = np.where(cls_[..., None], np.clip(new_, 0, 1).astype(np.float32), OUTC)
# the art's fissures to the keyed hot colour, so they glow
hotm = (PID == low_pid) & (OUTC[..., 0] > 0.8) & (OUTC[..., 1] > 0.6) & (OUTC[..., 2] < 0.72) & (POS[..., 0] > 0.1)
OUTC[hotm] = P.HOT
rimm = (PID == low_pid) & (OUTC[..., 0] > 0.6) & (OUTC[..., 2] < 0.3) & (OUTC[..., 1] > 0.3) & (POS[..., 0] > 0.1)
OUTC[rimm] = P.HOT_RIM

# ---- the rebuilt pieces
def paint(names_pred, fn):
    ids = [i for i, n in enumerate(names) if names_pred(n)]
    m = np.isin(PID, ids)
    ys, xs = np.nonzero(m)
    if len(ys):
        OUTC[ys, xs] = fn(POS[ys, xs].astype(np.float64), NOR[ys, xs].astype(np.float64), AO[ys, xs].astype(np.float64))


def mask_art(p, n, ao):
    """The band over the mouth from the sculpt sheet's own scarf, front view: his right is image left."""
    px = np.clip((K.SHEET_CX - p[:, 0] * K.SHEET_K).astype(int), 0, SHEET.shape[1] - 1)
    py = np.clip((K.SHEET_EYE_Y + (K.EYE_Z - p[:, 2]) * K.SHEET_K).astype(int), 0, SHEET.shape[0] - 1)
    return P.grade_head(SHEET[py, px][None, :, :])[0]


paint(lambda n: n == "maskfit", mask_art)
paint(lambda n: n.startswith(("palm", "finger", "thumb")) and n.endswith("L"), P.skin)


def right_hand(p, n, ao):
    c = P.skin(p, n, ao)
    d = K.HAND_Z + 0.03 - p[..., 2]
    # bandage from the wrist to past the knuckles; the finger ends bare, like the sheet
    tip = np.linalg.norm(p - (K.GRIP_AT + np.array([0, 0.03, -0.02])), axis=-1)
    bare = smooth(0.0, 0.015, (p[..., 0] - K.SH) * -1 - 0.012) * (d > 0.03)
    b = P.bandage(p, n, ao, None, p[..., 2] * 0.9 + p[..., 1] * 0.6)
    return P.mix(b, c, np.clip(bare, 0, 1))


paint(lambda n: n.startswith(("palm", "finger", "thumb")) and n.endswith("R"), right_hand)
paint(lambda n: n == "guard", lambda p, n, ao: P.iron(p, n, ao, 0.3))
paint(lambda n: n == "grip", P.grip)
paint(lambda n: n == "pommel", lambda p, n, ao: P.iron(p, n, ao, 0.1))
for p_ in tails:
    paint(lambda n, q=p_.name: n == q, lambda p, n, ao, sp=p_.burns: P.burnt(P.cloth(p, n, np.maximum(ao, 0.75)), p, sp))

# dilate past the island edges
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
x0, y0, x1, y1 = rect(CHAIN_R)
OUTC[y0:y1, x0:x1] = P.chain_tile(y1 - y0, x1 - x0)
x0, y0, x1, y1 = rect(HOOK_R)
OUTC[y0:y1, x0:x1] = P.hook_tile(y1 - y0, x1 - x0)
x0, y0, x1, y1 = rect(GLOW_R)
OUTC[y0:y1, x0:x1] = P.HOT

# the blade's tile: the sheet's own paint, its white core keyed hot, its stone a step down for the toon light
x0, y0, x1, y1 = rect(BLADE_R)
crop_ = WEAP[K.W_TIP:K.W_GUARD, K.W_X0:K.W_X1][::-1]
iy_ = ((np.arange(y1 - y0) + 0.5) / (y1 - y0) * crop_.shape[0]).astype(int)
ix_ = ((np.arange(x1 - x0) + 0.5) / (x1 - x0) * crop_.shape[1]).astype(int)
tile_ = crop_[iy_][:, ix_].copy()
lt_ = tile_.mean(2)
stone_ = lt_ < 0.62
tile_[stone_] *= 0.56
tile_[lt_ > 0.8] = P.HOT
OUTC[y0:y1, x0:x1] = tile_
x0, y0, x1, y1 = rect(HALO_R)
OUTC[y0:y1, x0:x1] = (0.52, 0.4, 0.2)       # (keyed part hot: the gold round the core)

atlas = bpy.data.images.new("kael_atlas", ATLAS, ATLAS)
px = np.ones((ATLAS, ATLAS, 4), np.float32)
px[..., :3] = np.clip(OUTC, 0, 1)
atlas.pixels.foreach_set(px.ravel())
atlas.filepath_raw = os.path.join(os.path.dirname(OUT), "atlas.png")
atlas.file_format = "PNG"
atlas.save()
print("atlas saved")

# ---- materials
for mt in me.materials:
    nt = mt.node_tree
    for nd in list(nt.nodes):
        if nd.type == "TEX_IMAGE":
            nt.nodes.remove(nd)
    t = nt.nodes.new("ShaderNodeTexImage")
    t.image = head_img if mt.name == "skin-head-hot" else atlas
    pb = nt.nodes["Principled BSDF"]
    nt.links.new(t.outputs[0], pb.inputs[0])
    pb.inputs["Roughness"].default_value = 0.7
    pb.inputs["Metallic"].default_value = 0.0

# ---- ink room
attr = me.color_attributes.new("ink", "FLOAT_COLOR", "POINT")
ic = np.ones((len(me.vertices), 4), np.float32)
ic[:, 3] = rooms
ic[:, 0] = ic[:, 1] = ic[:, 2] = shades
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
    c = K.hl(K.EYE * [s, 1, 1])
    bone("lid." + side, "head", c, c + Vector((0, 0.03, 0)))
    b = K.hl(np.array([s * 0.035, 0.09, 0.045]))
    bone("brow." + side, "head", b, b + Vector((0, 0.03, 0)))
for sd, sx in (("R", 1.0), ("L", -1.0)):
    hd = np.array([sx * 0.1191, 0.0, K.ANKLE_Z])
    bone("foot." + sd, "shin." + sd, hd, hd + [0, 0.12, 0])
knuck = np.array([-K.SH, 0.0, K.HAND_Z - 0.07])
bone("fingers.L", "hand.L", knuck, knuck + [0, 0, -0.06])
th = np.array([-K.SH, 0.03, K.HAND_Z - 0.015])
bone("thumb.L", "hand.L", th, th + [0, 0.02, -0.05])
for g, pts in chains.items():
    spring(["spring_mane_%s_%d" % (g, i) for i in range(K.CHAIN_BONES)], [tuple(p) for p in pts], "head")
spring(HANG, [tuple(p) for p in hang_pts], "hand.R")
for g_, (nm_, pts_) in TAILS.items():
    spring(nm_, pts_, "hips")
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
b_, e_, n_ = K.sword_frame()
g = K.GRIP_AT + b_ * K.GUARD_OFF
A = {"anchor_head_top": ("head", (0, 0.0, K.C[2] + 0.12)), "anchor_chest": ("hips", (0, 0.12, K.SHOULDER_Z - 0.09)),
     "anchor_arm_up": ("upper_arm.R", (K.SH, 0.02, K.SHOULDER_Z - 0.07)), "anchor_arm_elbow": ("forearm.R", (K.SH, 0.03, K.ELBOW_Z + 0.01)),
     "anchor_arm_fore": ("forearm.R", (K.SH, 0.03, K.ELBOW_Z - 0.09)), "anchor_chain": ("forearm.R", (K.SH + 0.05, 0.0, K.HAND_Z + 0.02)),
     "weapon_muzzle": ("hand.R", tuple(g + b_ * K.BLADE_LEN)), "anchor_blade_root": ("hand.R", tuple(g + b_ * 0.05)),
     "anchor_blade_mid": ("hand.R", tuple(g + b_ * K.BLADE_LEN * 0.55)),
     "anchor_hook_mouth": (HANG[-2], tuple(np.array(hang_pts[0]) + [-0.10, 0, -0.5]))}
# the embers and eyes, found on the head's own paint: the hottest spots, kept apart
vi_ = np.array([faces_v[i_][j_] for i_ in range(nf) if names[faces_pid[i_]] == "headscan" for j_ in range(len(faces_v[i_]))])
uu_ = np.array([u_ for i_ in range(nf) if names[faces_pid[i_]] == "headscan" for u_ in faces_uv[i_]])
hh_, hw_ = head_tex.shape[:2]
cc_ = head_tex[np.clip((uu_[:, 1] * hh_).astype(int), 0, hh_ - 1), np.clip((uu_[:, 0] * hw_).astype(int), 0, hw_ - 1)]
hot_ = (cc_[:, 0] - cc_[:, 2]).argsort()[::-1]
picks_ = []
for i_ in hot_[:600]:
    p_ = vco[vi_[i_]]
    if all(np.linalg.norm(p_ - q_) > 0.06 for q_ in picks_):
        picks_.append(p_)
    if len(picks_) >= 5:
        break
for i_, p_ in enumerate(picks_):
    A["anchor_ember_%d" % i_] = ("hips" if p_[2] < K.NECK_Z else "head", tuple(p_))
for sd_, sg_ in (("", 1.0), ("_l", -1.0)):
    A["anchor_eye_glow" + sd_] = ("head", (sg_ * K.EYE_GAP * 0.5, K.NOSE_Y - 0.018, K.EYE_Z))
for nm, (bn, at) in A.items():
    e = bpy.data.objects.new(nm, None)
    bpy.context.scene.collection.objects.link(e)
    e.parent = arm
    e.parent_type = "BONE"
    e.parent_bone = bn
    pb = arm.data.bones[bn]
    # (parent-bone space: from the bone's tail)
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
