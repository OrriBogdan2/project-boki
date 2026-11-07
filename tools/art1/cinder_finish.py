"""ART-1 Cinder v2 (ids stay `ashwick`, art `cinder`), stage B: join the scan's low mesh with the tail and the flames, unwrap, bake the scan's paint, draw the
molten seams into an emission map, hang the long hair's alpha cards, skin on the shared armature, the FX points, export.
One 2048 colour atlas: the scan's islands, then a strip for the tail, then flat cells at its right edge. A second 2048 for the emission, a small card atlas.
Run: blender -b --factory-startup --python tools/art1/cinder_finish.py -- <source.blend> <rig.json> <out.glb>"""
import sys, os, json, math
import bpy, bmesh
import numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, "..", "blender"))
import cinder_pieces as K
from meshkit import smooth, norm, frames
from paintkit import hexc
import warden_kit as WK

a = sys.argv[sys.argv.index("--") + 1:]
SRC, RIG, OUT = a[0], a[1], a[2]
WORK = os.path.dirname(os.path.abspath(OUT))
ATLAS = 2048
CARDS = 512
UNIQ_W = 0.90                        # the scan's islands' share of the atlas width
TAIL_U = (0.905, 0.972)              # the tail's strip, then the flat cells
CELL = {K.OBSIDIAN: "#1b1520"}
SLOTS = ["skin", "hair", "metal"]
FLAMES = ["flame-hair", "flame-jet"]
MATS = [s + "-cinder" for s in SLOTS] + list(CELL) + FLAMES + ["card-cinder"]
HEEL_J = (0.0, -0.2, -1.0)           # the jets' axis: down and a little back
EMBER = (0.5, 0.95)                  # a hair card's run from root to tip: the ember starts, it's full
SKIN_C, SKIN_DK = "#8d8799", "#4d4656"    # the sheet's scaled grey-violet
OBS_LO, OBS_HI = "#100c15", "#584a6a"     # living obsidian, deep to its sheen
HAIR_LO, HAIR_HI = "#0e0b12", "#2e2733"
SEAM_SHARE = 0.08                   # of the body's texels: restrained, the seams draw lines and no more
HORN = 0.6                           # her horns against her skin
PLUM = 0.33                          # the paint's saturation above which it's armour, not skin
TAIL_GLOW = 0.55                     # the tail's cracks against the shards' seams
rig = json.load(open(RIG))
bpy.ops.wm.open_mainfile(filepath=SRC)
sc = bpy.context.scene
src, low = bpy.data.objects["Src"], bpy.data.objects["Low"]
META = json.loads(sc["cinder"])

gn = {g.index: g.name for g in low.vertex_groups}
lo_co = np.array([v.co[:] for v in low.data.vertices])
lo_w = [{gn[g.group]: g.weight for g in v.groups if g.weight > 0.01} for v in low.data.vertices]
lo_bvh = BVHTree.FromPolygons([tuple(v) for v in lo_co], [list(p.vertices) for p in low.data.polygons])
CARD_CH = {"c": 5, "r": 6, "l": 6}


def surf(x, z, d, gap=0.012):
    """The body's surface at (x, z) seen along d (+1 from the front, -1 from behind): y, `gap` proud of it."""
    hit = lo_bvh.ray_cast(Vector((x, d * 0.6, z)), Vector((0, -d, 0)), 1.0)
    return None if hit[0] is None else hit[0].y + d * gap


def body_y(x, z, d, was):
    y = surf(x, z, d)
    return was if y is None else (max(y, was) if d > 0 else min(y, was))


# The hair's chains: the scan's hair, then on down: to the small of her back behind, to her chest at the sides
hc = [np.array(p, float) for p in META["hairc"]]
for z_ in (1.08, 0.99, 0.91):
    hc.append(np.array((0.0, body_y(0.0, z_, -1, hc[-1][1] + 0.02), z_)))
hr = [np.array(p, float) for p in META["hairr"]]
for z_ in (1.16, 1.11, 1.06, 1.01):
    hr.append(np.array((hr[-1][0] + 0.004, body_y(hr[-1][0] + 0.004, z_, 1, hr[-1][1] - 0.015), z_)))
hl = [p * (-1, 1, 1) for p in hr]
HAIR_PTS = {"c": hc, "r": hr, "l": hl}


def chain_w(g, z):
    """A point at height z on hair chain g: its two nearest bones."""
    pts = HAIR_PTS[g]
    n = CARD_CH[g]
    i = 0
    while i < n - 1 and pts[i + 1][2] > z:
        i += 1
    f = float(np.clip((pts[i][2] - z) / max(pts[i][2] - pts[i + 1][2], 1e-3), 0, 1))
    pre = "spring_scarftail_hair" + g
    d = {"%s_%d" % (pre, i): 1 - f}
    if i + 1 < n:
        d["%s_%d" % (pre, i + 1)] = f
    else:
        d["%s_%d" % (pre, i)] = 1.0
    return d


pl = K.tail((TAIL_U[0], 0.0, TAIL_U[1], 1.0))
sp = K.spines(pl)
K.weight_tail(pl, sp)
hx = {sd: K.J("shin." + sd)[0] for sd in "RL"}
HEELS = [(np.array((hx["R"] + 0.03, -0.075, 0.035)), norm(np.array(HEEL_J))), (np.array((hx["L"] - 0.03, -0.075, 0.035)), norm(np.array(HEEL_J)))]
jets = K.jet_flames(HEELS)


END = {"r": np.array((0.1, surf(0.1, 1.11, 1) or 0.12, 1.11)), "l": np.array((-0.1, surf(-0.1, 1.11, 1) or 0.12, 1.11))}    # the front locks' ends


def hair_flames():
    """Licks of fire off her hair's ends."""
    out = []
    for g, pts, n_, x_ in (("c", hc, 4, 0.11), ("r", hr, 2, 0.022), ("l", hl, 2, 0.022)):
        tip = pts[-1]
        for i in range(n_):
            off = np.array((x_ * ((i + 0.5) / n_ * 2 - 1), 0.0, 0.0))
            lean = np.array((0.015 * (-1) ** i, -0.008 if g == "c" else 0.008, -0.05))
            b = (tip if g == "c" else END[g]) + off + np.array((0, 0, 0.07 if g == "c" else 0.0))
            o = K.strip("hf%s%d" % (g, i), "flame-hair", [b, b + lean * 0.5, b + lean * 1.1 + (0.012, 0, 0), b + lean * 1.8], 0.05, rows=4, hint=(0, 1, 0), seed=0.13 * (i + 3) + 0.3 * len(g), bright=0.15, root=0.8)
            o.rigid("spring_scarftail_hair%s_%d" % (g, CARD_CH[g] - 1))
            out.append(o)
    return out


pieces = [pl] + sp + jets + hair_flames()
verts, faces, fsrc, fraw, vw, rooms = [], [], [], [], [], []
for co, d in zip(lo_co, lo_w):
    verts.append(tuple(co))
    vw.append(d)
    rooms.append(1.0)
for p in low.data.polygons:
    faces.append(list(p.vertices))
    fsrc.append(None)
    fraw.append(None)
for pc in pieces:
    if not getattr(pc, "flame", False):
        pc.orient()
    base = len(verts)
    for i, v in enumerate(pc.v):
        verts.append(tuple(v))
        vw.append({b: float(w[i]) for b, w in pc.w.items() if w[i] > 0.005})
        rooms.append(pc.room)
    for k_, f in enumerate(pc.f):
        faces.append([base + i for i in f])
        fsrc.append(pc.mat)
        fraw.append(pc.uv[k_] if pc.uv is not None else None)
N_LOW = len(low.data.polygons)
me = bpy.data.meshes.new("cinder")
me.from_pydata(verts, [], faces)
me.update()
ob = bpy.data.objects.new("cinder", me)
sc.collection.objects.link(ob)
for m in MATS:
    mt = bpy.data.materials.new(m)
    mt.use_nodes = True
    me.materials.append(mt)
me.uv_layers.new(name="UV")

# ---- unwrap the scan part, then squeeze it left of the strip and the cells
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
cells = {nm: ((TAIL_U[1] + 1.0) / 2 + 0.002, (i + 0.5) / len(CELL)) for i, nm in enumerate(CELL)}
uv = me.uv_layers["UV"]
luv = np.zeros(len(me.loops) * 2)
uv.data.foreach_get("uv", luv)
luv = luv.reshape(-1, 2)
for p in me.polygons:
    ls = list(p.loop_indices)
    if p.index < N_LOW:
        luv[ls, 0] *= UNIQ_W
    elif fsrc[p.index] in cells:
        luv[ls] = cells[fsrc[p.index]]
    elif fraw[p.index] is not None:
        luv[ls] = fraw[p.index]
flame_f = [p.index for p in me.polygons if p.index >= N_LOW and fsrc[p.index] in FLAMES]
flame_l = [l_ for i in flame_f for l_ in me.polygons[i].loop_indices]
raw_l = luv[flame_l].copy()
luv[flame_l] = cells[K.OBSIDIAN]            # (the fire's raw UV spans the whole atlas: out of the bake's way until it's done)
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
bake_tmp = os.environ.get("CINDER_BAKE")
if bake_tmp and os.path.exists(bake_tmp):
    COL = np.load(bake_tmp)
else:
    bpy.ops.object.bake(type="EMIT", use_clear=True, margin=12)
    COL = np.array(atlas.pixels[:], np.float32).reshape(ATLAS, ATLAS, 4)[..., :3].copy()
    if bake_tmp:
        np.save(bake_tmp, COL)
print("baked")

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


# ---- per face: its paint, its slot
fuv = np.zeros((len(me.polygons), 2))
for p in me.polygons:
    fuv[p.index] = luv[list(p.loop_indices)].mean(0)
px = np.clip((fuv * ATLAS).astype(int), 0, ATLAS - 1)
soft = box(COL, 3)                   # the scan's speckle would class a face by one grain
fcol = soft[px[:, 1], px[:, 0]]
mx, mn = fcol.max(1), fcol.min(1)
sat = (mx - mn) / np.maximum(mx, 1e-4)
fc = np.array([np.mean([verts[i] for i in f], axis=0) for f in faces])
fw = [{} for _ in faces]
for i, f in enumerate(faces):
    for vi in f:
        for b, w in vw[vi].items():
            fw[i][b] = fw[i].get(b, 0.0) + w / len(f)
dom = np.array([max(w, key=w.get) if w else "root" for w in fw], dtype=object)
on_hair = np.array([str(b).startswith("spring_scarftail_hair") for b in dom])
slot = np.full(len(faces), "skin", dtype=object)
slot[sat > PLUM] = "metal"
slot[on_hair] = "hair"
hd = fc[:, 2] > 1.34
slot[hd & (slot == "metal")] = "hair"
for i, p in enumerate(me.polygons):
    if i >= N_LOW:
        p.material_index = MATS.index(fsrc[i])
    else:
        p.material_index = MATS.index(slot[i] + "-cinder")
print("slots", {s: int((slot[:N_LOW] == s).sum()) for s in SLOTS})


def class_bake():
    """Per texel: R its part (1 skin, 0.75 armour, 0.5 hair, 0 none), G its height / 2, B its x + 0.5."""
    cls = np.where(slot == "skin", 1.0, np.where(slot == "metal", 0.75, 0.5))
    cls[N_LOW:] = 0.0
    lv = np.zeros(len(me.loops), int)
    me.loops.foreach_get("vertex_index", lv)
    lp = np.repeat(np.arange(len(me.polygons)), [p.loop_total for p in me.polygons])
    cc = np.ones((len(me.loops), 4), np.float32)
    cc[:, 0], cc[:, 1], cc[:, 2] = cls[lp], np.array(verts)[lv, 2] / 2.0, np.array(verts)[lv, 0] + 0.5
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
    bpy.ops.object.bake(type="EMIT", use_clear=True, margin=8)
    me.polygons.foreach_set("material_index", mi)
    me.materials.pop()
    me.color_attributes.remove(ca)
    return np.array(img.pixels[:], np.float32).reshape(ATLAS, ATLAS, 4)


HOT = ("#b32e06", "#ff6a12", "#ffc23a", "#fff2c0")     # the seam's ramp: its edge to its white-yellow core


def ramp_hot(h):
    """h 0..1 through HOT."""
    c = np.array([hexc(x) for x in HOT], np.float32)
    x = np.clip(h, 0, 0.9999) * (len(HOT) - 1)
    i = x.astype(int)
    f = (x - i)[..., None]
    return c[i] * (1 - f) + c[i + 1] * f


EMIT = np.zeros((ATLAS, ATLAS, 3), np.float32)


def repaint(col):
    """Fills the bake's misses, keys the molten seams out of the scan's paint into the emission map and turns the paint round them to the sheet's grey-violet scale and obsidian."""
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
    mx_, mn_ = col.max(-1), col.min(-1)
    sat_ = (mx_ - mn_) / np.maximum(mx_, 1e-4)
    below = z < 1.34
    sk, ar, hr_ = np.abs(part - 1.0) < 0.1, np.abs(part - 0.75) < 0.1, np.abs(part - 0.5) < 0.1
    body = sk | ar
    # per texel, as a shard's edge rarely follows a face: the plum is armour, the grey-violet skin,
    # and what's both saturated and bright the molten line along a shard's edge
    line = (sat_ > 0.26) & (lum > 0.27) & body & below
    shard = (box(sat_ * body, 2) > PLUM) & body & below | ar
    shard &= ~((np.abs(cb[..., 2] - 0.5) < 0.06) & (z > 1.02) & (z < 1.17))    # the belly's bare: the scan's dark slit up it isn't a shard
    sk, ar = body & ~shard & ~line, shard & ~line
    # a seam is a line: only the brightest ridge of it, so the scan's broad red slabs (its hair ends) stay out
    ridge = (lum - blur_in(lum, body, 6)) * (line | (sat_ > 0.3) & body & below)
    cut = np.quantile(ridge[body & below], 1.0 - SEAM_SHARE)
    seam = smooth(cut, cut + 0.05, ridge)
    thick = np.clip(box(seam, 1) * 1.8, 0, 1)
    heat = np.clip(thick * 0.45 + smooth(0.08, 0.2, ridge) * 0.6, 0, 1) * body
    glow = smooth(0.15, 0.6, thick) * body
    lnorm = np.maximum(blur_in(lum, sk, 30), 1e-3)
    t_ = np.clip(lum / lnorm, 0.55, 1.3)[..., None]
    sk_c = hexc(SKIN_DK)[None, None] * (1.3 - t_) / 0.75 + hexc(SKIN_C)[None, None] * (t_ - 0.55) / 0.75
    warm = (sat_ > 0.5) & (z > 1.45)                  # the eyes and lips: left as painted
    col[sk & ~warm] = sk_c[sk & ~warm]
    horn = sk & (z > 1.6)
    col[horn] *= HORN
    lnorm = np.maximum(blur_in(lum, ar, 40), 1e-3)
    t_ = np.clip((lum / lnorm - 0.7) / 0.7, 0, 1)[..., None] ** 1.4
    ob_c = hexc(OBS_LO)[None, None] * (1 - t_) + hexc(OBS_HI)[None, None] * t_
    col[ar | line] = ob_c[ar | line]
    t_ = np.clip(lum / 0.3, 0, 1)[..., None]
    col[hr_] = (hexc(HAIR_LO)[None, None] * (1 - t_) + hexc(HAIR_HI)[None, None] * t_)[hr_]
    hot = ramp_hot(heat * 0.92)
    col[:] = col * (1 - glow[..., None]) + hot * glow[..., None]
    EMIT[:] = hot * (glow * (0.45 + 0.55 * heat))[..., None]
    print("repaint skin", int(sk.sum()), "armour", int(ar.sum()), "hair", int(hr_.sum()), "seam share", round(float(glow[body].mean()), 3))


def paint_tail(col):
    """The tail's strip: overlapping grey-violet scales, the back darker than the belly, the belly warm with the fire inside, cracks fading toward the tip."""
    x0, x1 = int(TAIL_U[0] * ATLAS), int(TAIL_U[1] * ATLAS)
    h, w = ATLAS, x1 - x0
    v, u = np.mgrid[0:h, 0:w] / np.array([h, w])[:, None, None]
    t_, s_, n_ = frames(pl.path, np.array([0, 0, 1.0]))
    dors = norm_rows(K.DORSAL[None] - t_ * (t_ @ K.DORSAL)[:, None])
    ang = np.arctan2((dors * n_).sum(1), (dors * s_).sum(1)) / math.tau
    ang = np.unwrap(ang * math.tau) / math.tau
    d_u = np.interp(v[:, 0], np.linspace(0, 1, len(ang)), ang)[:, None]
    bel = (np.cos((u - d_u) * math.tau) * -0.5 + 0.5)                        # 0 the back, 1 the belly
    rows = v * 150.0
    r_i = rows.astype(int)
    cu = (u * 7.0 + 0.5 * (r_i % 2)) % 1.0
    cv = rows % 1.0
    edge = np.clip(np.maximum(np.abs(cu - 0.5) * 2.0, cv * 0.8), 0, 1)
    sc_ = 1.0 - 0.45 * smooth(0.72, 1.0, edge)
    back = hexc(K.TAIL_C)[None, None] * (1 - v[..., None] * 0.35)
    belly = hexc("#9a5a3a")[None, None] * (1 - smooth(0.3, 0.85, v)[..., None] * 0.65)
    c_ = (back * (1 - smooth(0.45, 0.85, bel)[..., None]) + belly * smooth(0.45, 0.85, bel)[..., None]) * sc_[..., None]
    w1 = np.abs(np.sin(v * 58.0 + 1.6 * np.sin(u * math.tau * 2 + v * 17.0)))
    w2 = np.abs(np.sin(u * math.tau * 2.5 + 2.2 * np.sin(v * 31.0)))
    crack = np.maximum(smooth(0.09, 0.03, w1), smooth(0.05, 0.015, w2) * smooth(0.3, 0.7, np.sin(v * 41.0) * 0.5 + 0.5))
    crack *= (1 - smooth(0.55, 0.95, v)) * (0.35 + 0.65 * bel)
    hot = ramp_hot(crack * 0.55)
    col[0:h, x0:x1] = c_ * (1 - crack[..., None]) + hot * crack[..., None]
    EMIT[0:h, x0:x1] = hot * (crack * TAIL_GLOW)[..., None]


def norm_rows(m_):
    return m_ / np.maximum(np.linalg.norm(m_, axis=1, keepdims=True), 1e-6)


repaint(COL)
paint_tail(COL)
for nm in cells:
    x0 = int((TAIL_U[1] + 0.004) * ATLAS)
    y0 = int((cells[nm][1] - 0.5 / len(CELL)) * ATLAS) + 2
    COL[y0:y0 + ATLAS // len(CELL) - 4, x0:] = hexc(CELL[nm])
luv[flame_l] = raw_l
uv.data.foreach_set("uv", luv.ravel())
me.update()


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
emit_i = save("emit", EMIT, os.path.join(WORK, "emit.jpg"))


# ---- the alpha cards: the long hair below the scan's
def card_atlas():
    """v 1 the root, v 0 the tip: strands of near-black fading to ember, each with its own length."""
    rng = np.random.default_rng(5)
    h, w = CARDS // 2, CARDS
    ys, xs = np.mgrid[0:h, 0:w] / np.array([h, w])[:, None, None]
    down = 1.0 - ys
    a_ = np.zeros((h, w), np.float32)
    for layer, (kk, lmin, lmax, wd) in enumerate(((9, 0.8, 1.0, 0.62), (17, 0.72, 1.0, 0.4), (31, 0.6, 1.0, 0.24))):
        t = (xs * kk + np.sin(down * 4.0 + layer) * 0.2) % 1.0
        i = np.clip((xs * kk).astype(int), 0, kk)
        lens = rng.uniform(lmin, lmax, kk + 1)[i]
        taper = (1.0 - np.clip(down / lens, 0, 1)) ** 0.5
        a_ = np.maximum(a_, ((np.abs(t - 0.5) * 2.0) < wd * taper * 2).astype(np.float32) * (down < lens))
    a_ = np.maximum(a_, smooth(0.42, 0.2, down) * (np.abs(xs - 0.5) < 0.47))
    fade = smooth(EMBER[0], EMBER[1], down + 0.05 * np.sin(xs * 41.0))[..., None]
    streak = (0.78 + 0.22 * np.sin(xs * 150.0 + np.sin(down * 7.0) * 2.0))[..., None]
    dark = hexc(HAIR_LO)[None, None] * 0.6 + hexc(HAIR_HI)[None, None] * 0.4
    emb = ramp_hot(np.clip(fade[..., 0] * 1.05 - 0.1, 0, 1) * 0.75)
    deep = hexc("#6a1a08")[None, None]
    col = dark * (1 - smooth(0.0, 0.3, fade)) + deep * (smooth(0.0, 0.3, fade) - smooth(0.3, 0.7, fade)) + emb * smooth(0.3, 0.7, fade)
    img = np.zeros((h, w, 4), np.float32)
    img[..., :3] = col * streak
    img[..., 3] = box(a_, 1)
    return img


def rows_w(g, z, root):
    d = chain_w(g, z)
    if root:
        return {b: w * (1 - root) for b, w in d.items()} | {"head": root}
    return d


def lock(g, x0, d, z0, z1, wide, u0, out_x=0.0, gap=0.012):
    """One card down the body: its rows sit just proud of the surface seen from d, its width across x. On chain g, its root on the head."""
    rows = []
    N = 5
    was = None
    for i in range(N):
        q = i / (N - 1)
        z = z0 + (z1 - z0) * q
        x = x0 + out_x * q
        y = surf(x, z, d, gap)
        if y is None:
            y = was if was is not None else HAIR_PTS[g][-1][1]
        if was is not None:
            y = max(y, was - 0.03) if d < 0 else min(y, was + 0.03)
        was = y
        rows.append((np.array((x, y, z)), q))
    out = []
    u1 = u0 + 0.28
    cols = []
    for p_, q in rows:
        wd = wide * (0.6 + 0.4 * smooth(0.0, 0.3, q)) * (1 - 0.25 * q)
        l_, r_ = p_ - (wd, 0, 0), p_ + (wd, 0, 0)
        for e in (l_, r_):                       # each edge on the body, so a card wraps her back and no corner stands off it
            y = surf(e[0], e[2], d, gap)
            if y is not None:
                e[1] = max(y, p_[1] - 0.025) if d < 0 else min(y, p_[1] + 0.025)
        cols.append((l_, r_, q))
    for (l0, r0, q0), (l1, r1, q1) in zip(cols, cols[1:]):
        w0, w1 = rows_w(g, l0[2], max(0.0, 1 - q0 * 5)), rows_w(g, l1[2], max(0.0, 1 - q1 * 5))
        out.append(([l0, r0, r1, l1], [(u0, 1 - q0), (u1, 1 - q0), (u1, 1 - q1), (u0, 1 - q1)], [w0, w0, w1, w1]))
    return out


def hair_cards():
    """The master sheet's length: behind, a curtain to the small of her back; before her shoulders, two long locks to her chest."""
    out = []
    rng = np.random.default_rng(3)
    for layer, gap in ((0, 0.012), (1, 0.022)):
        for i in range(7):
            x = -0.08 + 0.16 * i / 6.0 + 0.008 * layer
            ln = 1.0 - 0.12 * abs(i - 3) / 3.0 + rng.uniform(-0.03, 0.03)
            z1 = 1.36 + (0.98 - 1.36) * ln
            out += lock("c", x, -1, 1.36, z1, 0.045, rng.uniform(0, 0.7), out_x=x * 0.06, gap=gap)
        for sg, g in ((1.0, "r"), (-1.0, "l")):
            for i, (x, z1) in enumerate(((0.075, 1.15), (0.1, 1.09), (0.125, 1.12), (0.145, 1.18))):
                out += lock(g, sg * (x + 0.006 * layer), 1, 1.31, z1, 0.026, rng.uniform(0, 0.7), out_x=sg * 0.008, gap=gap)
    return out


cards = hair_cards()
bm = bmesh.new()
bm.from_mesh(me)
uvl = bm.loops.layers.uv["UV"]
card_mi = MATS.index("card-cinder")
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
        t.image = cards_i if mt.name == "card-cinder" else atlas_i
        nt.links.new(t.outputs[0], pb.inputs["Base Color"])
        pb.inputs["Roughness"].default_value = 0.7
        if mt.name == "card-cinder":
            nt.links.new(t.outputs["Alpha"], pb.inputs["Alpha"])
        elif mt.name.split("-")[0] in SLOTS:
            e = nt.nodes.new("ShaderNodeTexImage")
            e.image = emit_i
            nt.links.new(e.outputs[0], pb.inputs["Emission Color"])
            pb.inputs["Emission Strength"].default_value = 1.0


def ink(m_, room):
    """The vertex colour: rgb the fire's seed on flame strips, a the ink shell's room."""
    attr = m_.color_attributes.new("ink", "FLOAT_COLOR", "POINT")
    ic = np.ones((len(m_.vertices), 4), np.float32)
    ic[:, 3] = room
    i_ = len(lo_co)
    for pc in pieces:
        if hasattr(pc, "fire"):
            ic[i_:i_ + len(pc.v), :3] = pc.fire
        i_ += len(pc.v)
    attr.data.foreach_set("color", ic.ravel())
    m_.color_attributes.active_color = attr


dress(me)
ink(me, rooms)

# ---- armature: the contract's, her extras, the springs
arm = WK.build_armature(rig)
bpy.context.view_layer.objects.active = arm
bpy.ops.object.mode_set(mode="EDIT")
eb = arm.data.edit_bones
J = K.J


def add_bone(nm, h, t, parent, roll=None):
    e = eb.new(nm)
    e.head, e.tail = Vector(tuple(h)), Vector(tuple(t))
    e.parent = eb[parent]
    if roll is not None:
        e.align_roll(Vector(tuple(roll)))


def spring(prefix, pts, parent, count):
    prev = parent
    for i in range(count):
        q = pts[i + 1] if i + 1 < len(pts) else pts[i] + (pts[i] - pts[i - 1])
        add_bone("%s_%d" % (prefix, i), pts[i], q, prev)
        prev = "%s_%d" % (prefix, i)


knk, tip, thb = [np.array(META[k], float) for k in ("knuckle", "fingertip", "thumb")]
hand = J("hand.R")
PALM = hand + (knk - hand) * 0.62
for sd, sg, x_m in (("R", 1.0, (1, 1, 1)), ("L", -1.0, (-1, 1, 1))):
    hx_ = J("shin." + sd)[0]
    add_bone("foot." + sd, (hx_, -0.01, K.ANKLE_Z), (hx_, 0.15, 0.025), "shin." + sd, (0, 0, 1))
    EYE = np.array((sg * 0.036, J("head")[1] + 0.085, J("head")[2] + 0.122))
    add_bone("lid." + sd, EYE, EYE + (sg * 0.03, 0, 0), "head", (0, 0, 1))
    add_bone("brow." + sd, EYE + (0, 0.005, 0.03), EYE + (0, 0.035, 0.03), "head")
    add_bone("fingers." + sd, knk * x_m, tip * x_m, "hand." + sd, (-sg, 0, 0))
    add_bone("thumb." + sd, thb[0] * x_m, thb[1] * x_m, "hand." + sd, (-sg, 0, 0))
add_bone("jaw", J("head") + (0, 0.04, 0.05), J("head") + (0, 0.11, 0.03), "head", (0, 0, 1))
for i, (p, ax) in enumerate(HEELS):
    add_bone("jet.%d" % i, p, p + ax * 0.12, "foot." + "RL"[i], (0, 1, 0))
spring("spring_scarftail_hairc", hc, "head", CARD_CH["c"])
spring("spring_scarftail_hairr", hr, "head", CARD_CH["r"])
spring("spring_scarftail_hairl", hl, "head", CARD_CH["l"])
tail_i = [int(round(i * (len(pl.path) - 1) / (K.TAIL_N - 1))) for i in range(K.TAIL_N)]
spring("spring_scarftail_tail", [pl.path[i] for i in tail_i], "root", K.TAIL_N)
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

# ---- FX points. The nozzle is her casting hand now: the kit's Gun/Muzzle follows hand.R
crown = float(rig["land"]["crown"])
OFF = np.array((-K.MUZZLE_OFF, 0.0, 0.0))
A_ = {"anchor_head_top": ("head", (0, 0, crown)), "anchor_crown": ("head", (0, -0.03, crown + 0.07)), "anchor_chest": ("hips", (0, 0.11, K.SHOULDER_Z - 0.13)),
      "weapon_muzzle": ("hand.R", PALM + OFF), "anchor_blade_root": ("hand.R", PALM), "anchor_gun_mid": ("hand.R", PALM * 0.5 + hand * 0.5),
      "anchor_jet_0": ("jet.0", HEELS[0][0]), "anchor_jet_1": ("jet.1", HEELS[1][0]), "anchor_tank": ("hips", (0, -0.12, K.SHOULDER_Z - 0.2)),
      "anchor_tail_tip": ("spring_scarftail_tail_%d" % (K.TAIL_N - 2), pl.path[-1])}
for i_, (bn, at) in enumerate((("hips", (0.0, 0.12, 1.1)), ("hips", (0.0, 0.1, 0.98)), ("forearm.R", (J("forearm.R") + J("hand.R")) / 2), ("forearm.L", (J("forearm.L") + J("hand.L")) / 2))):
    A_["anchor_vial_%d" % i_] = (bn, at)
for nm, (bn, at) in A_.items():
    WK.anchor(arm, bn, nm, tuple(float(v) for v in at))
me.polygons.foreach_set("use_smooth", [True] * len(me.polygons))
me.validate(clean_customdata=False)
me.update()
print("tris", WK.tris([ob]))
sc["palm"] = [float(v) for v in PALM]
for o in list(bpy.data.objects):
    if o.name in ("Src", "Low"):
        bpy.data.objects.remove(o)
bpy.ops.wm.save_as_mainfile(filepath=os.path.splitext(OUT)[0] + ".blend")
WK.export(OUT, [arm, ob] + [o for o in bpy.data.objects if o.type == "EMPTY"], colors=True)
print("exported", OUT, os.path.getsize(OUT))
