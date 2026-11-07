"""ART-1 Ravel v2 (ids stay `hem`), stage B: join the scan's low mesh with the scripted pieces, unwrap, bake the scan's paint,
the alpha cards (the frayed thread hem, the smoke at her hair's ends), skin on the shared armature, the FX points, export.
One 2048 colour atlas (the pieces on flat cells at its right edge) and a small RGBA card atlas. Recipe: kael_finish.py.
Meshes: `hem` (body), `bow_mesh`, `arrow_mesh`, all skinned, as the kit's rig expects. Run:
blender -b --factory-startup --python tools/art1/hem_finish.py -- <source.blend> <rig.json> <out.glb>"""
import sys, os, json, math
import bpy, bmesh
import numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, "..", "blender"))
import hem_pieces as H
from meshkit import smooth
from paintkit import hexc
import warden_kit as WK

a = sys.argv[sys.argv.index("--") + 1:]
SRC, RIG, OUT = a[0], a[1], a[2]
WORK = os.path.dirname(os.path.abspath(OUT))
ATLAS = 2048
CARDS = 512
UNIQ_W = 0.94                        # the scan's islands' share of the atlas width; the flat cells sit to its right
CELL = {H.SKIN: "#ded3d1", H.THREAD: "#7a1230", H.BOW: "#2b2129", H.BOW_HI: "#4a3a48", H.STEEL: "#b4b3bd", H.STEEL_DK: "#5d5b66",
        H.PIN: "#cfcdd5", "leather-vane": "#a5835c"}
HEM_C, SMOKE_C = (0.0, 0.0, 0.62, 1.0), (0.64, 0.0, 1.0, 1.0)    # card cells (u0, v0, u1, v1)
SLOTS = ["skin", "hair", "cloth", "leather", "metal"]
MATS = [s + "-hem" for s in SLOTS] + list(CELL) + ["card-hem"]
BELT_Z = 0.965                       # the spool belt's height on the fitted scan
SPOOL_X = (-0.15, -0.105, -0.06, 0.06, 0.105, 0.15)
HEM_TOP = 0.56                       # z: the cards start tucked up inside the skirt's hem
HEM_N = 46                           # hanging strips round the skirt
SLIT = 0.36                          # rad either side of the front: the slit, no fringe
SKIRT_Z = (HEM_TOP - 0.04, BELT_Z - 0.06)    # z: the scan's skirt, between its hem and the belt
PORCELAIN = "#dbd0dc"                # the sheet's lilac porcelain skin
SKIRT_LO, SKIRT_HI, SKIRT_RED = "#21111c", "#5c3352", "#6e1733"    # the skirt: plum folds dark to light, its red hem fade
rig = json.load(open(RIG))
bpy.ops.wm.open_mainfile(filepath=SRC)
sc = bpy.context.scene
src, low = bpy.data.objects["Src"], bpy.data.objects["Low"]
META = json.loads(sc["hem"])
J = H.joints(RIG)

gn = {g.index: g.name for g in low.vertex_groups}
lo_co = np.array([v.co[:] for v in low.data.vertices])
lo_w = [{gn[g.group]: g.weight for g in v.groups if g.weight > 0.01} for v in low.data.vertices]
head_v = np.array([d.get("head", 0) > 0.5 for d in lo_w])
top = lo_co[head_v & (lo_co[:, 2] > lo_co[:, 2].max() - 0.075)]
BUN = top.mean(0)
print("bun", BUN.round(3))

lo_bvh = BVHTree.FromPolygons([tuple(v) for v in lo_co], [list(p.vertices) for p in low.data.polygons])


def belt_at(x):
    """The belt's surface at x (from whichever side's nearer): point, outward normal."""
    sg = 1.0 if abs(x) < 0.2 else 0.0
    hit = lo_bvh.ray_cast(Vector((x * 0.6, 0.4 * (1 if sg else 0.2), BELT_Z)), Vector((x * 0.4 / max(abs(x), 1e-6) * 0, -1, 0)).normalized(), 0.8)
    p = np.array(hit[0]) if hit[0] is not None else np.array((x, 0.1, BELT_Z))
    return p, np.array((p[0], p[1] * 2.0, 0.0)) / max(np.hypot(p[0], p[1] * 2.0), 1e-6)


pieces = H.fist(J) + H.rigid(H.spools(belt_at, SPOOL_X), "hips") + H.rigid(H.back_needle(1) + H.back_needle(-1) + H.lash() + H.strings(), "hips") + H.rigid(H.bun_pins(BUN), "head") + H.rigid(H.shoulder_mask(J), "upper_arm.L")
verts, faces, fsrc, vw, rooms = [], [], [], [], []
for co, d in zip(lo_co, lo_w):
    verts.append(tuple(co))
    vw.append(d)
    rooms.append(1.0)
for p in low.data.polygons:
    faces.append(list(p.vertices))
    fsrc.append(None)
for pc in pieces:
    pc.orient()
    base = len(verts)
    for i, v in enumerate(pc.v):
        verts.append(tuple(v))
        vw.append({b: float(w[i]) for b, w in pc.w.items() if w[i] > 0.005})
        rooms.append(pc.room)
    for f in pc.f:
        faces.append([base + i for i in f])
        fsrc.append(pc.mat)
N_LOW = len(low.data.polygons)
me = bpy.data.meshes.new("hem")
me.from_pydata(verts, [], faces)
me.update()
ob = bpy.data.objects.new("hem", me)
sc.collection.objects.link(ob)
for m in MATS:
    mt = bpy.data.materials.new(m)
    mt.use_nodes = True
    me.materials.append(mt)
me.uv_layers.new(name="UV")

# ---- unwrap the scan part, then squeeze it left of the flat cells
for o in bpy.data.objects:
    o.select_set(False)
bpy.context.view_layer.objects.active = ob
ob.select_set(True)
bpy.ops.object.mode_set(mode="EDIT")
bm = bmesh.from_edit_mesh(me)
bm.faces.ensure_lookup_table()
for f in bm.faces:
    f.select = f.index < N_LOW
bmesh.update_edit_mesh(me)
bpy.ops.uv.smart_project(angle_limit=math.radians(66), island_margin=0.0, area_weight=0.0, scale_to_bounds=False)
bpy.ops.uv.pack_islands(rotate=True, scale=True, margin_method="FRACTION", margin=0.005, shape_method="CONCAVE")
bpy.ops.object.mode_set(mode="OBJECT")
cells = {nm: ((UNIQ_W + 1.0) / 2, (i + 0.5) / len(CELL)) for i, nm in enumerate(CELL)}
uv = me.uv_layers["UV"]
luv = np.zeros(len(me.loops) * 2)
uv.data.foreach_get("uv", luv)
luv = luv.reshape(-1, 2)
for p in me.polygons:
    ls = list(p.loop_indices)
    if p.index < N_LOW:
        luv[ls, 0] *= UNIQ_W
    else:
        luv[ls] = cells[fsrc[p.index]]
uv.data.foreach_set("uv", luv.ravel())
me.update()

# ---- bake the scan's paint
for mt in src.data.materials:
    nt = mt.node_tree
    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    tex = bsdf.inputs["Base Color"].links[0].from_socket
    em = nt.nodes.new("ShaderNodeEmission")
    nt.links.new(tex, em.inputs["Color"])
    nt.links.new(em.outputs[0], next(n for n in nt.nodes if n.type == "OUTPUT_MATERIAL").inputs["Surface"])
atlas = bpy.data.images.new("atlas", ATLAS, ATLAS)
for mt in me.materials:
    t = mt.node_tree.nodes.new("ShaderNodeTexImage")
    t.image = atlas
    mt.node_tree.nodes.active = t
sc.render.engine = "CYCLES"
sc.cycles.device = "CPU"
sc.cycles.samples = 1
sc.render.bake.use_selected_to_active = True
sc.render.bake.cage_extrusion = 0.03
sc.render.bake.max_ray_distance = 0.08
for o in bpy.data.objects:
    o.select_set(False)
src.select_set(True)
ob.select_set(True)
bpy.context.view_layer.objects.active = ob
bpy.ops.object.bake(type="EMIT", use_clear=True, margin=12)
COL = np.array(atlas.pixels[:], np.float32).reshape(ATLAS, ATLAS, 4)[..., :3].copy()
print("baked")

# ---- per face: its paint, its slot
fuv = np.zeros((len(me.polygons), 2))
for p in me.polygons:
    fuv[p.index] = luv[list(p.loop_indices)].mean(0)
px = np.clip((fuv * ATLAS).astype(int), 0, ATLAS - 1)
fcol = COL[px[:, 1], px[:, 0]]
mx, mn = fcol.max(1), fcol.min(1)
sat = (mx - mn) / np.maximum(mx, 1e-4)
fc = np.array([np.mean([verts[i] for i in f], axis=0) for f in faces])
fw = [{} for _ in faces]
for i, f in enumerate(faces):
    for vi in f:
        for b, w in vw[vi].items():
            fw[i][b] = fw[i].get(b, 0.0) + w / len(f)
dom = np.array([max(w, key=w.get) if w else "root" for w in fw], dtype=object)
on_head = np.array([b == "head" or str(b).startswith("spring_tail") for b in dom])
legs = np.array([str(b).startswith(("shin", "foot")) for b in dom])
dark = mx < 0.3
slot = np.full(len(faces), "cloth", dtype=object)
slot[(sat < 0.3) & (mx > 0.42)] = "skin"
slot[(sat < 0.22) & (mx > 0.3) & (mx <= 0.42)] = "metal"
slot[(mx > 0.45) & (sat < 0.5) & np.array([str(b).startswith(("thigh", "shin")) for b in dom])] = "skin"
slot[dark & (legs | (fc[:, 2] < 0.98))] = "leather"              # the boots, the skirt and the belt: one plum look
slot[dark & on_head] = "hair"
slot[(slot == "cloth") & np.array([str(b).startswith(("thigh", "shin")) for b in dom])] = "skin"    # the legs at the slit: no corset there
for i, p in enumerate(me.polygons):
    p.material_index = MATS.index(fsrc[i]) if i >= N_LOW else MATS.index(slot[i] + "-hem")
print("slots", {s: int((slot[:N_LOW] == s).sum()) for s in SLOTS})


def box(a_, r):
    """Box blur of radius r over the first two axes."""
    for ax in (0, 1):
        p_ = np.pad(a_, [(r + 1, r) if i == ax else (0, 0) for i in range(a_.ndim)], mode="edge")
        c_ = np.cumsum(p_, axis=ax)
        n_ = a_.shape[ax]
        a_ = (np.take(c_, np.arange(2 * r + 1, 2 * r + 1 + n_), axis=ax) - np.take(c_, np.arange(n_), axis=ax)) / (2 * r + 1)
    return a_


def blur_in(v, m_, r):
    """Blur of v over the texels in mask m_ only (no bleed across islands)."""
    w_ = box(m_.astype(np.float32), r)
    if v.ndim == 3:
        return box(v * m_[..., None], r) / np.maximum(w_, 1e-4)[..., None]
    return box(v * m_, r) / np.maximum(w_, 1e-4)


def class_bake():
    """Per texel: R its part (1 skin to repaint, 0.75 skirt to dye, 0.5 the rest, 0 no island), G its height / 2."""
    skirt = (slot == "leather") & ~legs & (fc[:, 2] > SKIRT_Z[0]) & (fc[:, 2] < SKIRT_Z[1])
    cls = np.where((slot == "skin") & ~on_head, 1.0, np.where(skirt, 0.75, 0.5))
    cls[N_LOW:] = 0.5
    lv = np.zeros(len(me.loops), int)
    me.loops.foreach_get("vertex_index", lv)
    lp = np.repeat(np.arange(len(me.polygons)), [p.loop_total for p in me.polygons])
    cc = np.ones((len(me.loops), 4), np.float32)
    cc[:, 0], cc[:, 1], cc[:, 2] = cls[lp], np.array(verts)[lv, 2] / 2.0, 0.0
    ca = me.color_attributes.new("cls", "FLOAT_COLOR", "CORNER")
    ca.data.foreach_set("color", cc.ravel())
    tm = bpy.data.materials.new("tmp_cls")
    tm.use_nodes = True
    nt = tm.node_tree
    at_, em = nt.nodes.new("ShaderNodeAttribute"), nt.nodes.new("ShaderNodeEmission")
    at_.attribute_name = "cls"
    nt.links.new(at_.outputs["Color"], em.inputs["Color"])
    nt.links.new(em.outputs[0], nt.nodes["Material Output"].inputs["Surface"])
    img = bpy.data.images.new("cls", ATLAS, ATLAS, float_buffer=True)
    t_ = nt.nodes.new("ShaderNodeTexImage")
    t_.image = img
    nt.nodes.active = t_
    me.materials.append(tm)
    mi = np.zeros(len(me.polygons), np.int32)
    me.polygons.foreach_get("material_index", mi)
    me.polygons.foreach_set("material_index", np.full(len(mi), len(me.materials) - 1, np.int32))
    sc.render.bake.use_selected_to_active = False
    src.select_set(False)
    bpy.ops.object.bake(type="EMIT", use_clear=True, margin=0)
    me.polygons.foreach_set("material_index", mi)
    me.materials.pop()
    me.color_attributes.remove(ca)
    return np.array(img.pixels[:], np.float32).reshape(ATLAS, ATLAS, 4)


def repaint(col):
    """Fills the bake's misses (black texels in an island), smooths the skin to porcelain keeping the red stitches, the dark
    cracks and the cream joints, and dyes the skirt plum with a red fade at its hem."""
    cb = class_bake()
    part, z = cb[..., 0], cb[..., 1] * 2.0
    cover = part > 0.25
    miss = cover & (col.max(-1) < 0.012)
    print("misses", int(miss.sum()))
    for _ in range(10):
        ok = cover & ~miss
        est = blur_in(col, ok, 2)
        got = miss & (box(ok.astype(np.float32), 2) > 0.01)
        col[got] = est[got]
        miss &= ~got
    lum = col @ np.array((0.3, 0.59, 0.11), np.float32)
    mx, mn = col.max(-1), col.min(-1)
    sat = (mx - mn) / np.maximum(mx, 1e-4)
    sk = np.abs(part - 1.0) < 0.1
    base = blur_in(lum, sk, 12)
    ref = float(np.median(lum[sk]))
    shade = np.clip(base / ref, 0.74, 1.05) * 0.88 + np.clip(lum / ref, 0.6, 1.2) * 0.12
    red = smooth(0.6, 0.8, sat) * (col[..., 0] > col[..., 1] + 0.2) * (lum < 0.4)    # dark crimson only, not the scan's pink
    crack = smooth(0.05, 0.14, base - lum)
    warm = smooth(0.04, 0.1, col[..., 1] - col[..., 2]) * smooth(0.1, 0.2, sat)
    keep = np.clip(np.maximum(np.maximum(red, crack), warm), 0, 1)[..., None]
    skin_c = hexc(PORCELAIN)[None, None] * shade[..., None]
    col[sk] = (skin_c * (1 - keep) + col * keep)[sk]
    sd = np.abs(part - 0.75) < 0.1
    t_ = np.clip(lum / 0.26, 0, 1.4)[..., None]
    plum = hexc(SKIRT_LO)[None, None] * (1 - t_) + hexc(SKIRT_HI)[None, None] * t_
    fade = (smooth(HEM_TOP + 0.12, HEM_TOP, z) * 0.75)[..., None]
    dye = plum * (1 - fade) + hexc(SKIRT_RED)[None, None] * (0.55 + 0.6 * t_) * fade
    col[sd] = dye[sd]
    print("repaint skin", int(sk.sum()), "skirt", int(sd.sum()), "ref", round(ref, 3))


repaint(COL)
for nm in cells:
    x0, y0 = int((UNIQ_W + 0.004) * ATLAS), int((cells[nm][1] - 0.5 / len(CELL)) * ATLAS) + 2
    COL[y0:y0 + ATLAS // len(CELL) - 4, x0:] = hexc(CELL[nm])


def save(img_name, arr, path, fmt="JPEG"):
    im = bpy.data.images.new(img_name, arr.shape[1], arr.shape[0], alpha=arr.shape[2] == 4)
    pxl = np.ones((arr.shape[0], arr.shape[1], 4), np.float32)
    pxl[..., :arr.shape[2]] = np.clip(arr, 0, 1)
    im.pixels.foreach_set(pxl.ravel())
    im.filepath_raw = path
    im.file_format = fmt
    im.save()
    return im


atlas_i = save("atlas", COL, os.path.join(WORK, "atlas.jpg"))


# ---- the alpha cards
def card_atlas():
    """v 1 is the edge a card hangs from. Left: the frayed hem, plum cloth at the root, tongues and loose threads to crimson.
    Right: smoke, soft dark wisps that thin away."""
    rng = np.random.default_rng(5)
    h, w = CARDS // 2, CARDS
    img = np.zeros((h, w, 4), np.float32)
    ys, xs = np.mgrid[0:h, 0:w] / np.array([h, w])[:, None, None]
    down = 1.0 - ys
    # hem
    u0, _, u1, _ = HEM_C
    cx = (xs - u0) / (u1 - u0)
    plum, red, deep = hexc("#3e2238"), hexc("#9c1636"), hexc(SKIRT_RED)
    a_ = np.zeros((h, w), np.float32)
    k = 15
    for layer, (kk, lmin, lmax, wd) in enumerate(((k, 0.45, 0.8, 0.5), (k * 2 + 1, 0.55, 1.0, 0.22), (k * 3 + 2, 0.7, 1.0, 0.1))):
        t = (cx * kk + np.sin(down * 5.0 + layer) * 0.18) % 1.0
        i = np.clip((cx * kk).astype(int), 0, kk)
        lens = rng.uniform(lmin, lmax, kk + 1)[i]
        taper = (1.0 - np.clip(down / lens, 0, 1)) ** 0.55
        a_ = np.maximum(a_, ((np.abs(t - 0.5) * 2.0) < wd * taper * 2).astype(np.float32) * (down < lens))
    a_ = np.maximum(a_, (down < 0.14).astype(np.float32))
    m = (cx >= 0) & (cx <= 1)
    tint = smooth(0.18, 0.62, down + 0.06 * np.sin(cx * 57.0))
    streak = 0.8 + 0.2 * np.sin(cx * 140.0 + np.sin(down * 8.0) * 2.0)
    col = plum[None, None] * (1 - tint[..., None]) + (deep[None, None] * (1 - down[..., None]) + red[None, None] * down[..., None]) * tint[..., None]
    img[m, :3] = (col * streak[..., None])[m]
    img[m, 3] = a_[m]
    # smoke
    u0, _, u1, _ = SMOKE_C
    cx = (xs - u0) / (u1 - u0)
    m = (cx >= 0) & (cx <= 1)
    wob = 0.5 + 0.16 * np.sin(down * 7.0 + 0.6) + 0.09 * np.sin(down * 15.0 + cx * 3.0)
    d = np.abs(cx - wob) / (0.46 * (1.0 - down * 0.62))
    wisp = np.clip(1.0 - d, 0, 1) ** 0.8 * (1.0 - smooth(0.3, 1.0, down))
    wisp *= 0.72 + 0.28 * np.sin(cx * 21.0 + down * 12.0)
    img[m, :3] = hexc("#191419")
    img[m, 3] = np.clip(wisp, 0, 1)[m] * 0.92
    return img


def chain_weights(prefix, s, base):
    """Weights at chain parameter s (0..1), on top of a dict of base weights that fades out."""
    s6 = min(max(s, 0.0), 0.999) * 6.0
    i = int(s6)
    f = s6 - i
    d = {b: w * (1 - s) for b, w in base.items()}
    d["%s_%d" % (prefix, i)] = d.get("%s_%d" % (prefix, i), 0.0) + (1 - f) * s
    if i < 5:
        d["%s_%d" % (prefix, i + 1)] = f * s
    return d


def hem_cards():
    """Round the skirt, hanging strips: long at the sides and the back, none at the slit. Each swings on its side's chain."""
    out = []
    bvh = BVHTree.FromPolygons(verts[:len(lo_co)], faces[:N_LOW])
    rng = np.random.default_rng(11)
    z0 = HEM_TOP
    for k_ in range(HEM_N):
        th = math.tau * (k_ + 0.5) / HEM_N                # 0 the front, + toward her left... x = -sin
        off = abs((th + math.pi) % math.tau - math.pi)
        if off < SLIT:
            continue
        d = np.array((-math.sin(th), math.cos(th), 0.0))
        hit = bvh.ray_cast(Vector((d[0] * 0.5, d[1] * 0.5, z0)), Vector((-d[0], -d[1], 0.0)), 0.6)
        r = (Vector((hit[0].x, hit[0].y, 0)).length if hit[0] is not None else 0.2) + 0.002
        # the fringe's length: short by the slit, long at the sides, a shade shorter dead behind
        ln = 0.18 + 0.25 * smooth(SLIT, 1.5, off) - 0.04 * smooth(2.3, 3.14, off) + rng.uniform(-0.02, 0.03)
        hw = math.pi * r / HEM_N * 1.9
        t_ = np.array((math.cos(th), math.sin(th), 0.0))
        p = d * r + np.array((0, 0, z0))
        rows = [p + d * (0.035 * q * q) + np.array((0, 0, -ln * q)) for q in (0.0, 0.34, 0.68, 1.0)]
        chain = "spring_scarftailR" if d[0] > 0 else "spring_scarftailL"
        thigh = "thigh.R" if d[0] > 0 else "thigh.L"
        u = rng.uniform(0, 0.8)
        uu = (HEM_C[0] + (HEM_C[2] - HEM_C[0]) * u, HEM_C[0] + (HEM_C[2] - HEM_C[0]) * (u + 0.2))
        for r_i in range(3):
            q0, q1 = r_i / 3.0, (r_i + 1) / 3.0
            ws = [chain_weights(chain, q * 0.4 + 0.05, {"root": 0.5, thigh: 0.5}) for q in (q0, q1)]
            quad = [rows[r_i] - t_ * hw, rows[r_i] + t_ * hw, rows[r_i + 1] + t_ * hw, rows[r_i + 1] - t_ * hw]
            uvq = [(uu[0], 1 - q0), (uu[1], 1 - q0), (uu[1], 1 - q1), (uu[0], 1 - q1)]
            out.append((quad, uvq, [ws[0], ws[0], ws[1], ws[1]]))
    return out


def smoke_cards():
    """Her hair's ends dissolve: crossed strips of smoke off the tail's last metres of chain, drifting out and back."""
    out = []
    tail = np.array(META["tail"])
    tip, d0 = tail[-1], (tail[-1] - tail[-3]) / np.linalg.norm(tail[-1] - tail[-3])
    rng = np.random.default_rng(2)
    for k_, (dx, ln, wd, drift) in enumerate(((-0.035, 0.15, 0.05, -0.04), (0.035, 0.16, 0.05, 0.04), (0.0, 0.2, 0.055, 0.0), (-0.06, 0.11, 0.04, -0.06), (0.06, 0.12, 0.04, 0.06), (0.0, 0.14, 0.05, 0.03))):
        at = tip + np.array((dx, -0.008 * (k_ % 3), 0.04))
        side = np.array((1.0, 0.0, 0.0))
        pts = [at + d0 * ln * q + side * drift * q * q + np.array((0, -0.03 * q, 0)) for q in (0.0, 0.4, 0.75, 1.0)]
        wt = (1.0, 1.15, 1.35, 1.5)
        for r_i in range(3):
            q0, q1 = r_i / 3.0, (r_i + 1) / 3.0
            w_ = [{"spring_tail_5": 1 - q * 0.3, "spring_tail_6": q * 0.3} for q in (q0, q1)]
            quad = [pts[r_i] - side * wd * wt[r_i], pts[r_i] + side * wd * wt[r_i], pts[r_i + 1] + side * wd * wt[r_i + 1], pts[r_i + 1] - side * wd * wt[r_i + 1]]
            uvq = [(SMOKE_C[0], 1 - q0), (SMOKE_C[2], 1 - q0), (SMOKE_C[2], 1 - q1), (SMOKE_C[0], 1 - q1)]
            out.append((quad, uvq, [w_[0], w_[0], w_[1], w_[1]]))
    return out


cards = hem_cards() + smoke_cards()
bm = bmesh.new()
bm.from_mesh(me)
uvl = bm.loops.layers.uv["UV"]
card_mi = MATS.index("card-hem")
for quad, uvq, ws in cards:
    vs = [bm.verts.new(Vector(tuple(p))) for p in quad]
    for d in ws:
        vw.append(d)
        rooms.append(0.0)
    f = bm.faces.new(vs)
    f.material_index = card_mi
    for l_, q in zip(f.loops, uvq):
        l_[uvl].uv = q
bm.to_mesh(me)
bm.free()
print("cards", len(cards))
cards_i = save("cards", card_atlas(), os.path.join(WORK, "cards.png"), "PNG")


def dress(m_):
    for mt in m_.materials:
        nt = mt.node_tree
        for nd in list(nt.nodes):
            if nd.type == "TEX_IMAGE":
                nt.nodes.remove(nd)
        pb = nt.nodes["Principled BSDF"]
        t = nt.nodes.new("ShaderNodeTexImage")
        t.image = cards_i if mt.name == "card-hem" else atlas_i
        nt.links.new(t.outputs[0], pb.inputs["Base Color"])
        pb.inputs["Roughness"].default_value = 0.7
        if mt.name == "card-hem":
            nt.links.new(t.outputs["Alpha"], pb.inputs["Alpha"])


def ink(m_, room):
    attr = m_.color_attributes.new("ink", "FLOAT_COLOR", "POINT")
    ic = np.ones((len(m_.vertices), 4), np.float32)
    ic[:, 3] = room
    attr.data.foreach_set("color", ic.ravel())
    m_.color_attributes.active_color = attr


dress(me)
ink(me, rooms)

# ---- the separate rigid meshes, on the flat cells
c, A, Sd = H.grip_frame(J)
bxf = lambda p: H.bow_to_model(np.array(p, float), J)
hip = J["hips"]
# the arrow rests tucked in the belt at her right hip, tip down and back, among the pins
ar_at = np.array((0.215, 0.09, hip[2] + 0.22))
ar_y = np.array((-0.02, -0.34, -0.94))
ar_y = ar_y / np.linalg.norm(ar_y)
ar_x = np.cross(ar_y, (0.3, 0.6, 0.74))
ar_x = ar_x / np.linalg.norm(ar_x)
ar_z = np.cross(ar_x, ar_y)


def mesh_of(name, pcs):
    sv, sf, smat, sw, sr = [], [], [], [], []
    for pc in pcs:
        pc.orient()
        o = len(sv)
        sv += [tuple(v) for v in pc.v]
        sf += [[o + i for i in f] for f in pc.f]
        smat += [pc.mat] * len(pc.f)
        sw += [{b: float(w[i]) for b, w in pc.w.items() if w[i] > 0.005} for i in range(len(pc.v))]
        sr += [pc.room] * len(pc.v)
    m_ = bpy.data.meshes.new(name)
    m_.from_pydata(sv, [], sf)
    m_.update()
    o_ = bpy.data.objects.new(name, m_)
    sc.collection.objects.link(o_)
    wm = sorted(set(smat))
    for mn_ in wm:
        mt = bpy.data.materials.new(mn_)
        mt.use_nodes = True
        m_.materials.append(mt)
    dress(m_)
    uvw = m_.uv_layers.new(name="UV")
    for p in m_.polygons:
        p.material_index = wm.index(smat[p.index])
        for li in p.loop_indices:
            uvw.data[li].uv = cells[smat[p.index]]
    ink(m_, sr)
    return o_, sw


bow_ob, bow_w = mesh_of("bow_mesh", H.bow(J))
arrow_ob, arrow_w = mesh_of("arrow_mesh", H.rigid(H.arrow(ar_at, ar_x, ar_y, ar_z), "arrow"))

# ---- armature: the contract's, her extras, the springs
arm = WK.build_armature(rig)
bpy.context.view_layer.objects.active = arm
bpy.ops.object.mode_set(mode="EDIT")
eb = arm.data.edit_bones


def add_bone(nm, h, t, parent, roll=None):
    e = eb.new(nm)
    e.head, e.tail = Vector(tuple(h)), Vector(tuple(t))
    e.parent = eb[parent]
    if roll is not None:
        e.align_roll(Vector(tuple(roll)))


def spring(prefix, pts, parent):
    prev = parent
    for i in range(len(pts) - 1):
        e = eb.new("%s_%d" % (prefix, i))
        e.head, e.tail = Vector(tuple(pts[i])), Vector(tuple(pts[i + 1]))
        e.parent = eb[prev]
        prev = e.name


for sd, sg in (("R", 1.0), ("L", -1.0)):
    hx = J["shin." + sd][0]
    add_bone("foot." + sd, (hx, 0, 0.082), (hx, 0.17, 0.03), "shin." + sd, (0, 0, 1))
    EYE = np.array((sg * 0.036, J["head"][1] + 0.085, J["head"][2] + 0.122))
    add_bone("lid." + sd, EYE, EYE + (sg * 0.03, 0, 0), "head", (0, 0, 1))
    add_bone("brow." + sd, EYE + (0, 0.005, 0.03), EYE + (0, 0.035, 0.03), "head")
for nm, k in (("fing_a", "fing_a"), ("fing_b", "fing_b"), ("thumb", "thumb")):
    p = np.array(META[k], float)
    roll = (0, 1, 0) if nm != "thumb" else (0, 0, 1)
    add_bone(nm + "1.R", p[0], p[1], "hand.R", roll)
    add_bone(nm + "2.R", p[1], p[2], nm + "1.R", roll)
Y, Zs = H.STRING_Y, H.STRING_Z
add_bone("bow", c, c + A * 0.1, "hand.L", tuple(Sd))
add_bone("bow_t", bxf((0, 0.02, 0.11)), bxf((0, Y, Zs)), "bow", tuple(A))
add_bone("bow_b", bxf((0, 0.02, -0.11)), bxf((0, Y, -Zs)), "bow", tuple(A))
add_bone("bow_s", bxf((0, Y, 0)), bxf((0, Y - 0.05, 0)), "bow", tuple(A))
add_bone("arrow", ar_at, ar_at + ar_y * 0.2, "hips", tuple(ar_z))
tail = META["tail"]
tail = tail + [[tail[-1][0], tail[-1][1] - 0.02, tail[-1][2] - 0.3]]
spring("spring_tail", tail[:8], "head")
for sd in "RL":
    p0, p1 = [np.array(v, float) for v in META["skirt_chain"][sd]]
    spring("spring_scarftail" + sd, [p0 + (p1 - p0) * i / 7.0 for i in range(8)], "hips")
bpy.ops.object.mode_set(mode="OBJECT")


def skin(o_, weights):
    o_.parent = arm
    md = o_.modifiers.new("arm", "ARMATURE")
    md.object = arm
    for vi, d in enumerate(weights):
        tot = sum(d.values())
        for b, w in d.items():
            g = o_.vertex_groups.get(b) or o_.vertex_groups.new(name=b)
            g.add([vi], w / tot if tot > 0 else 0, "REPLACE")


skin(ob, vw)
skin(bow_ob, bow_w)
skin(arrow_ob, arrow_w)

# ---- FX points
crown = float(rig["land"]["crown"])
A_ = {"anchor_head_top": ("head", (0, 0, crown)), "anchor_chest": ("hips", (0, 0.11, J["upper_arm.R"][2] - 0.13)),
      "anchor_nock": ("bow", bxf((0, Y, 0))), "weapon_muzzle": ("bow", bxf((0, 0.05, 0))), "anchor_bow_root": ("bow", bxf((0, -0.10, 0))),
      "halo_bow_top": ("bow_t", bxf((0, Y, Zs))), "halo_bow_mid": ("bow", bxf((0, Y, 0))), "halo_bow_low": ("bow_b", bxf((0, Y, -Zs)))}
for nm, (bn, at) in A_.items():
    WK.anchor(arm, bn, nm, tuple(float(v) for v in at))
for m_ in (me, bow_ob.data, arrow_ob.data):
    m_.polygons.foreach_set("use_smooth", [True] * len(m_.polygons))
    m_.validate(clean_customdata=False)
    m_.update()
print("tris body", WK.tris([ob]), "bow", WK.tris([bow_ob]), "arrow", WK.tris([arrow_ob]), "total", WK.tris([ob, bow_ob, arrow_ob]))
sc["pinch"] = [float(v) for v in META["fing_a"][2]]
for o in list(bpy.data.objects):
    if o.name in ("Src", "Low"):
        bpy.data.objects.remove(o)
bpy.ops.wm.save_as_mainfile(filepath=os.path.splitext(OUT)[0] + ".blend")
WK.export(OUT, [arm, ob, bow_ob, arrow_ob] + [o for o in bpy.data.objects if o.type == "EMPTY"], colors=True)
print("exported", OUT, os.path.getsize(OUT))
