"""Leg graft: a Hunter's fused trouser legs (a web of cloth between the thighs) swapped for Meshy-made separated legs, on the
game .glb, every other triangle, UV, texture, weight and clip kept as it is (PART-LOCK; same family as pigtail_graft.py and
head_graft.py). Used for Tenzo (tarek), 11-20: the rig test (docs/art/wardens/RIG_TEST_1120.md) showed weights cannot remove
the web because it is modelled cloth.

 1. Live: the body's trouser faces (a `cloth*` material, a dark low-saturation texel: not the orange sash, not the cream
    wraps) whose centre lies under CUT (the crotch) and over ANKLE are deleted.
 2. Meshy: a multi-image-to-3d of the live views with the legs drawn apart (Meshy image-to-image) is turned to face +Y,
    scaled and moved onto the live body (soles and height, then a trimmed similarity ICP on the legs' outer surface),
    and its own trouser faces (same colour test, under CUT + OVERLAP so the new tops tuck under the kept hips cloth) are
    kept, cleaned of specks, and decimated to the deleted faces' count x DENSITY.
 3. The new faces get the material `cloth-v95p` (the live cloth material with Meshy's paint, scaled to TEX and graded
    per channel to the live trousers' mean and spread, no emission), the nearest live trouser vertex's colour attribute
    and weights (a start: run tools/art1/rig_test/mkweights.py `auto` after this for bone-heat weights), and join the body.
Run: blender -b --factory-startup --python tools/meshy/leg_graft.py -- LIVE.glb MESHY.glb OUT.glb [--cut 1.06]
     [--overlap 0.04] [--ankle 0.2] [--density 1.15] [--tex 2048]
Coordinates are the game .glb's in Blender (z up, his front +Y, metres); Meshy's raw frame faces -Y."""
import argparse
import sys

import bmesh
import bpy
import numpy as np
from mathutils import Matrix

ap = argparse.ArgumentParser()
ap.add_argument("live"); ap.add_argument("meshy"); ap.add_argument("out")
ap.add_argument("--cut", type=float, default=1.06)
ap.add_argument("--overlap", type=float, default=0.08)
ap.add_argument("--ankle", type=float, default=0.43, help="live trouser faces under this stay (the cuffs: the legs are apart there)")
ap.add_argument("--mankle", type=float, default=0.33, help="Meshy trouser faces over this are kept (they overlap the live cuffs)")
ap.add_argument("--close", type=int, default=8, help="rings of closing (grow, then shrink) to fill colour-test holes")
ap.add_argument("--density", type=float, default=1.15)
ap.add_argument("--tex", type=int, default=2048)
ap.add_argument("--min-island", type=int, default=150)
ap.add_argument("--vmax", type=float, default=0.62)
ap.add_argument("--smax", type=float, default=0.40)
ap.add_argument("--xmax", type=float, default=0.32)
ap.add_argument("--dry", action="store_true", help="export the live body with the cut only")
o = ap.parse_args(sys.argv[sys.argv.index("--") + 1:])


def pixels(img):
    w, h = img.size
    a = np.empty(w * h * 4, np.float32); img.pixels.foreach_get(a)
    return a.reshape(h, w, 4)[..., :3], w, h


def hsv(rgb):
    mx = rgb.max(1); mn = rgb.min(1); d = mx - mn + 1e-9
    r, g, b = rgb.T
    h = np.where(mx == r, (g - b) / d % 6, np.where(mx == g, (b - r) / d + 2, (r - g) / d + 4)) * 60
    return h, d / (mx + 1e-9), mx


def trouser(rgb):
    """Brown, low-saturation cloth (linear-light texels, sRGB-converted here): not the orange sash (saturated), not the
    blue-grey slate, not the cream wraps (bright)."""
    srgb = np.where(rgb <= 0.0031308, rgb * 12.92, 1.055 * np.power(np.clip(rgb, 0, 1), 1 / 2.4) - 0.055)
    h, s, v = hsv(srgb)
    return ((v < o.vmax) & (s < o.smax) & ((h < 45) | (h > 330) | (s < 0.08))) | (v < 0.18)  # near-black: hue is noise


def nn(ref, q):
    """Nearest ref point to each q: (distance, index). mathutils KD-tree (Blender ships no scipy)."""
    from mathutils.kdtree import KDTree
    kd = KDTree(len(ref))
    for i, p in enumerate(ref): kd.insert(p, i)
    kd.balance()
    r = [kd.find(p) for p in q]
    return np.array([x[2] for x in r]), np.array([x[1] for x in r])


def face_texels(ob, imgs_by_mat):
    """Base-colour texel (linear) at each polygon's UV centre."""
    me = ob.data; n = len(me.polygons)
    uv = np.empty(len(me.loops) * 2, np.float32); me.uv_layers.active.data.foreach_get("uv", uv); uv = uv.reshape(-1, 2)
    ls = np.empty(n, np.int32); me.polygons.foreach_get("loop_start", ls)
    lt = np.empty(n, np.int32); me.polygons.foreach_get("loop_total", lt)
    mi = np.empty(n, np.int32); me.polygons.foreach_get("material_index", mi)
    acc = np.zeros((n, 2)); np.add.at(acc, np.repeat(np.arange(n), lt), uv[np.concatenate([np.arange(s, s + t) for s, t in zip(ls, lt)])])
    c = acc / lt[:, None]
    out = np.zeros((n, 3), np.float32)
    for k, (px, w, h) in imgs_by_mat.items():
        sel = mi == k
        x = np.clip((c[sel, 0] % 1) * w, 0, w - 1).astype(int); y = np.clip((c[sel, 1] % 1) * h, 0, h - 1).astype(int)
        out[sel] = px[y, x]
    return out, mi


def base_image(mat):
    """The image behind the Principled Base Color: direct (Meshy), or through a Mix node's first input (the v95 bake)."""
    pb = [n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED"]
    if not pb or not pb[0].inputs["Base Color"].links: return None
    nd = pb[0].inputs["Base Color"].links[0].from_node
    for _ in range(6):
        if nd.type == "TEX_IMAGE": return nd.image
        ins = [i for i in nd.inputs if i.links and i.type == "RGBA"] or [i for i in nd.inputs if i.links]
        if not ins: return None
        nd = ins[0].links[0].from_node
    return None


def centres(ob):
    me = ob.data; c = np.empty(len(me.polygons) * 3, np.float32); me.polygons.foreach_get("center", c)
    M = np.array(ob.matrix_world); c = c.reshape(-1, 3)
    return c @ M[:3, :3].T + M[:3, 3]


def verts(ob):
    me = ob.data; v = np.empty(len(me.vertices) * 3, np.float32); me.vertices.foreach_get("co", v)
    M = np.array(ob.matrix_world); v = v.reshape(-1, 3)
    return v @ M[:3, :3].T + M[:3, 3]


def grow(ob, sel, geo, n):
    """n rings of growth (n > 0, inside geo) or shrink (n < 0) of a face set; faces touching through shared positions
    (UV seams do not split them). Same closing as head_graft.py's hair zone."""
    me = ob.data; P = verts(ob)
    lt = np.empty(len(me.polygons), np.int32); me.polygons.foreach_get("loop_total", lt)
    assert (lt == 3).all(), "triangles expected"
    T = np.empty(len(me.polygons) * 3, np.int32); me.polygons.foreach_get("vertices", T); T = T.reshape(-1, 3)
    _, weld = np.unique(np.round(P / 1e-5).astype(np.int64), axis=0, return_inverse=True)
    W = weld.ravel()[T]
    for _ in range(abs(n)):
        mark = np.zeros(W.max() + 1, bool)
        if n > 0:
            mark[W[sel].ravel()] = True; sel = geo & mark[W].any(1)
        else:
            mark[W[~sel].ravel()] = True; sel = sel & ~mark[W].any(1)
    return sel


def fill_holes(bm, tag):
    """Holes: where Meshy's sash (or its shadow) lay on the trouser surface the colour test cut it away, and the
    decimation can open a few more. Boundary loops that touch neither the waist rim nor the cuff rims are filled; each
    new corner takes a UV from the same vertex's old faces."""
    bnd = [e for e in bm.edges if e.is_boundary]; comp = {}; par = {}

    def root(v):
        while par.get(v, v) != v: v = par[v]
        return v
    for e in bnd:
        a, b = root(e.verts[0].index), root(e.verts[1].index)
        if a != b: par[a] = b
    for e in bnd: comp.setdefault(root(e.verts[0].index), []).append(e)
    fill = []
    for es in comp.values():
        z = [v.co.z for e in es for v in e.verts]
        if min(z) > o.mankle + 0.04 and max(z) < o.cut + o.overlap - 0.03 and len(es) < 2000: fill += es
    # fan fill (a centre vertex, one triangle per edge wound against its face): holes_fill skips loops that are not
    # simple cycles (bow-tie vertices), which Meshy's cut-outs often are
    uvl = bm.loops.layers.uv.active; tri = []; nl = 0
    for es in comp.values():
        if es[0] not in fill: continue
        nl += 1
        c = bm.verts.new(sum((v.co for e in es for v in e.verts), es[0].verts[0].co * 0) / (2 * len(es)))
        uvs = []
        for e in es:
            l = e.link_loops[0]  # the old face's corner at l.vert, its edge runs l.vert -> l.link_loop_next.vert
            a_, b_ = l.vert, l.link_loop_next.vert
            try: f = bm.faces.new((b_, a_, c))
            except ValueError: continue
            ua, ub = l[uvl].uv.copy(), l.link_loop_next[uvl].uv.copy(); uvs += [ua, ub]
            for fl in f.loops:
                fl[uvl].uv = ub if fl.vert is b_ else ua if fl.vert is a_ else fl[uvl].uv
            tri.append(f)
        if uvs:
            m = sum((u for u in uvs), uvs[0] * 0) / len(uvs)
            for fl in c.link_loops: fl[uvl].uv = m
    for f in tri: f.material_index = 0
    newf = range(nl)
    print("HOLES", tag, len(newf), "loops ->", len(tri), "tris", flush=True)


def similarity(A, B):
    """s, R, t with s R A + t ~ B (Umeyama)."""
    ma, mb = A.mean(0), B.mean(0); a, b = A - ma, B - mb
    U, S, Vt = np.linalg.svd(b.T @ a / len(A)); D = np.eye(3); D[2, 2] = np.sign(np.linalg.det(U @ Vt))
    R = U @ D @ Vt; s = (S * np.diag(D)).sum() / (a ** 2).sum(1).mean()
    return s, R, mb - s * R @ ma


# --- live
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=o.live)
arm = [x for x in bpy.data.objects if x.type == "ARMATURE"][0]
arm.data.pose_position = "REST"
body = max([x for x in bpy.data.objects if x.type == "MESH" and x.vertex_groups], key=lambda x: len(x.data.vertices))
live_objs = set(bpy.data.objects)
mats = body.data.materials
imgs = {k: pixels(base_image(m)) for k, m in enumerate(mats) if m.name.startswith("cloth")}
tex, mi = face_texels(body, imgs)
fc = centres(body)
cloth = np.isin(mi, list(imgs))
pants = cloth & trouser(tex) & (fc[:, 2] < o.cut) & (fc[:, 2] > o.ankle) & (np.abs(fc[:, 0]) < o.xmax)
print("LIVE faces", len(fc), "trouser faces cut", int(pants.sum()), flush=True)
LV = verts(body)
# the live trousers' own vertices (for colour, weights and the grade), before the cut
me = body.data
pv_idx = np.unique(np.concatenate([np.array(me.polygons[i].vertices) for i in np.nonzero(pants)[0]]))
live_pants_rgb = tex[pants]
col_name = me.color_attributes.active_color.name if me.color_attributes.active_color else None
vg_names = [g.name for g in body.vertex_groups]
Wlive = np.zeros((len(me.vertices), len(vg_names)), np.float32)
for v in me.vertices:
    for g in v.groups: Wlive[v.index, g.group] = g.weight
Clive = None
if col_name:
    ca = me.color_attributes[col_name]
    cbuf = np.empty(len(ca.data) * 4, np.float32); ca.data.foreach_get("color", cbuf); cbuf = cbuf.reshape(-1, 4)
    if ca.domain == "CORNER":
        lv = np.empty(len(me.loops), np.int32); me.loops.foreach_get("vertex_index", lv)
        Clive = np.zeros((len(me.vertices), 4), np.float32); Clive[lv] = cbuf
    else:
        Clive = cbuf
bm = bmesh.new(); bm.from_mesh(me); bm.faces.ensure_lookup_table()
bmesh.ops.delete(bm, geom=[bm.faces[i] for i in np.nonzero(pants)[0]], context="FACES_ONLY")
loose = [v for v in bm.verts if not v.link_faces]
bmesh.ops.delete(bm, geom=loose, context="VERTS")
bm.to_mesh(me); bm.free(); me.update()
if o.dry:
    bpy.ops.object.select_all(action="DESELECT"); body.select_set(True)
    bpy.ops.export_scene.gltf(filepath=o.out, export_format="GLB", use_selection=True, export_animations=False, export_skins=False)
    print("DRY exported", o.out); sys.exit(0)

# --- meshy
bpy.ops.import_scene.gltf(filepath=o.meshy)
new = [x for x in bpy.data.objects if x not in live_objs]
mob = max([x for x in new if x.type == "MESH"], key=lambda x: len(x.data.vertices))
for x in new:
    if x.type == "MESH" and x is not mob: bpy.data.objects.remove(x)
mw = mob.matrix_world.copy(); mob.parent = None; mob.matrix_world = mw
mob.data.transform(mob.matrix_world); mob.matrix_world = Matrix.Identity(4)
mob.data.transform(Matrix.Rotation(np.pi, 4, "Z"))  # Meshy faces -Y; the game body faces +Y
MV = verts(mob)
lz0, lz1 = LV[:, 2].min(), LV[:, 2].max(); mz0, mz1 = MV[:, 2].min(), MV[:, 2].max()
s = (lz1 - lz0) / (mz1 - mz0)
band = lambda P: (P[:, 2] > 0.25) & (P[:, 2] < 1.0) & (np.abs(P[:, 0]) > 0.1) & (np.abs(P[:, 0]) < 0.35)
t = np.array([0, 0, lz0 - s * mz0]); MVs = MV * s + t
t[:2] += LV[band(LV)][:, :2].mean(0) - MVs[band(MVs)][:, :2].mean(0)
S, R, T = s, np.eye(3), t
from mathutils.kdtree import KDTree
lv_band = LV[band(LV)]; kd = KDTree(len(lv_band))
for i, p in enumerate(lv_band): kd.insert(p, i)
kd.balance()
rng = np.random.default_rng(0)
for it in range(20):
    P = (MV * S) @ R.T + T; Q = P[band(P)]
    if len(Q) > 15000: Q = Q[rng.choice(len(Q), 15000, replace=False)]
    r = [kd.find(p) for p in Q]; d = np.array([x[2] for x in r]); ix = np.array([x[1] for x in r])
    keep = d < np.quantile(d, 0.8)
    s2, R2, t2 = similarity(Q[keep], lv_band[ix[keep]])
    S, R, T = s2 * S, R2 @ R, s2 * R2 @ T + t2
print("FIT scale %.4f, mean err %.4f m" % (S, float(np.mean(d[keep]))), flush=True)
M4 = Matrix.Identity(4)
for i in range(3):
    for j in range(3): M4[i][j] = S * R[i, j]
    M4[i][3] = T[i]
mob.data.transform(M4)
mm = mob.data.materials
mimgs = {k: pixels(base_image(m)) for k, m in enumerate(mm) if base_image(m)}
mtex, _ = face_texels(mob, mimgs)
mfc = centres(mob)
_b = (mfc[:, 2] < o.cut) & (mfc[:, 2] > o.ankle) & (np.abs(mfc[:, 0]) < o.xmax)
_sr = np.where(mtex <= 0.0031308, mtex * 12.92, 1.055 * np.power(np.clip(mtex, 0, 1), 1 / 2.4) - 0.055); _h, _s, _v = hsv(_sr[_b])
print("MESHY imgs", {k: v[1:] for k, v in mimgs.items()}, "band h/s/v pct", [np.round(np.percentile(a, [10, 50, 90]), 2) for a in (_h, _s, _v)], flush=True)
geo = (mfc[:, 2] < o.cut + o.overlap) & (mfc[:, 2] > o.mankle) & (np.abs(mfc[:, 0]) < o.xmax + 0.05)
keep = trouser(mtex) & geo
n0 = int(keep.sum()); keep = grow(mob, grow(mob, keep, geo, o.close), geo, -o.close)
print("MESHY closing", n0, "->", int(keep.sum()), flush=True)
print("MESHY band faces", int(((mfc[:, 2] < o.cut) & (mfc[:, 2] > o.ankle) & (np.abs(mfc[:, 0]) < o.xmax)).sum()), "trouser", int(keep.sum()), flush=True)
bm = bmesh.new(); bm.from_mesh(mob.data); bm.faces.ensure_lookup_table()
bmesh.ops.delete(bm, geom=[bm.faces[i] for i in np.nonzero(~keep)[0]], context="FACES")
# specks: islands under min-island faces
bm.faces.ensure_lookup_table(); seen = set(); drop = []
for f in bm.faces:
    if f.index in seen: continue
    isl = []; st = [f]; seen.add(f.index)
    while st:
        g = st.pop(); isl.append(g)
        for e in g.edges:
            for h in e.link_faces:
                if h.index not in seen: seen.add(h.index); st.append(h)
    if len(isl) < o.min_island: drop += isl
bmesh.ops.delete(bm, geom=drop, context="FACES")
# Meshy splits vertices at UV seams; welded, so the decimation cannot open cracks along them (UVs live on the loops)
bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
fill_holes(bm, "meshy")
bm.to_mesh(mob.data); bm.free()
nkeep = len(mob.data.polygons)
target = int(pants.sum() * o.density)
if nkeep > target:
    dm = mob.modifiers.new("dec", "DECIMATE"); dm.ratio = target / nkeep
    with bpy.context.temp_override(object=mob, active_object=mob):
        bpy.ops.object.modifier_apply(modifier="dec")
    bm = bmesh.new(); bm.from_mesh(mob.data); bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    fill_holes(bm, "decimated"); bm.to_mesh(mob.data); bm.free()
print("MESHY trouser faces", nkeep, "->", len(mob.data.polygons), "(live cut", int(pants.sum()), ")", flush=True)

# --- material: the live cloth material with Meshy's paint, graded to the live trousers
src = base_image(mm[0]); w, h = src.size
im = src.copy(); im.scale(min(o.tex, w), min(o.tex, h)); im.name = "v95p"
px = np.empty(im.size[0] * im.size[1] * 4, np.float32); im.pixels.foreach_get(px); px = px.reshape(-1, 4)
mt = mtex[keep]; lm, ls_ = live_pants_rgb.mean(0), live_pants_rgb.std(0) + 1e-4; nm_, ns = mt.mean(0), mt.std(0) + 1e-4
px[:, :3] = np.clip((px[:, :3] - nm_) / ns * ls_ + lm, 0, 1)
im.pixels.foreach_set(px.ravel()); im.update()
im.file_format = "JPEG"
print("GRADE live mean", np.round(lm, 3), "meshy", np.round(nm_, 3), flush=True)
cm = [m for m in mats if m.name == "cloth-v95"][0].copy(); cm.name = "cloth-v95p"
for nd in cm.node_tree.nodes:
    if nd.type == "TEX_IMAGE":
        if nd.image == base_image(cm): nd.image = im
        else:
            for l in list(nd.outputs[0].links): cm.node_tree.links.remove(l)
            cm.node_tree.nodes.remove(nd)
for nd in cm.node_tree.nodes:
    if nd.type == "BSDF_PRINCIPLED":
        nd.inputs["Emission Color"].default_value = (0, 0, 0, 1); nd.inputs["Emission Strength"].default_value = 0.0
mob.data.materials.clear(); mob.data.materials.append(cm)
for p in mob.data.polygons: p.material_index = 0

# --- weights and colour from the nearest live trouser vertex (bone-heat weights come after, mkweights.py auto)
NV = verts(mob)
_, ix = nn(LV[pv_idx], NV); src_v = pv_idx[ix]
for g in list(mob.vertex_groups): mob.vertex_groups.remove(g)
gs = [mob.vertex_groups.new(name=n) for n in vg_names]
for i, sv in enumerate(src_v):
    for j in np.nonzero(Wlive[sv] > 1e-4)[0]: gs[j].add([i], float(Wlive[sv, j]), "REPLACE")
if col_name:
    for a in list(mob.data.color_attributes): mob.data.color_attributes.remove(a)
    ca = mob.data.color_attributes.new(col_name, "FLOAT_COLOR", me.color_attributes[col_name].domain)
    if ca.domain == "CORNER":
        lv = np.empty(len(mob.data.loops), np.int32); mob.data.loops.foreach_get("vertex_index", lv)
        ca.data.foreach_set("color", Clive[src_v][lv].ravel())
    else:
        ca.data.foreach_set("color", Clive[src_v].ravel())
uvn = body.data.uv_layers.active.name
if mob.data.uv_layers: mob.data.uv_layers.active.name = uvn
for x in list(mob.data.attributes):
    if x.name not in (col_name, uvn) and not x.name.startswith(".") and x.name not in ("position", "sharp_face", "material_index") and x.domain != "CORNER":
        try: mob.data.attributes.remove(x)
        except Exception: pass

# --- join, parent stays the live body's
bpy.ops.object.select_all(action="DESELECT")
mob.select_set(True); body.select_set(True); bpy.context.view_layer.objects.active = body
bpy.ops.object.join()
print("JOINED faces", len(body.data.polygons), "mats", [m.name for m in body.data.materials], flush=True)
arm.data.pose_position = "POSE"
bpy.ops.object.select_all(action="SELECT")
bpy.ops.export_scene.gltf(filepath=o.out, export_format="GLB", use_selection=True, export_apply=False, export_animations=True,
                          export_animation_mode="ACTIONS", export_skins=True, export_yup=True, export_materials="EXPORT",
                          export_image_format="JPEG", export_jpeg_quality=92, export_extras=False, export_vertex_color="ACTIVE",
                          export_force_sampling=True, export_frame_step=1, export_optimize_animation_size=False, export_def_bones=False)
print("GRAFT exported", o.out, flush=True)
