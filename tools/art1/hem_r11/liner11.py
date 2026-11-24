"""liner11.py -- Lace r11 S2+S4. blender -b -P liner11.py -- IN.glb OUT.glb TEX.png [key=val]
IN = outer skirt only (rig11 mode=A output, liner removed). 1) skirt-meshy gets the Meshy retexture TEX (UVs unchanged).
2) Hidden liner shell, solid wine (median of TEX under the outward faces), INSIDE the outer cloth: radius = 15th percentile
of the outer radius per (azimuth, z) bin minus ins (10 mm), NO leg push; weights = those of the single nearest outer vertex;
no liner faces in the slit sector below zslit; then 8 frames x every clip: any liner face with a vertex outside the outer cloth
(radial ray from the posed hip axis hits the outer first) is deleted, and the test is repeated until 0.
Rig/export only (a hidden shell is rig work)."""

import bpy, bmesh, sys, math, numpy as np
from mathutils import Vector, kdtree
from mathutils.bvhtree import BVHTree

EMBED = "RIG11" in globals()  # exec'd from rig11 (same Blender session: one import/export round trip only)
if not EMBED:
    A = sys.argv[sys.argv.index("--") + 1 :]
    IN, OUT, TEX = A[:3]
    O = dict(a.split("=") for a in A[3:])
else:
    TEX = O["tex"]
INS = float(O.get("ins", 0.010))
PCT = float(O.get("pct", 15))
BOFF = float(O.get("boff", 0.03))
ZTOP = float(O.get("ztop", 1.02))
NT = int(O.get("nt", 120))
NZ = int(O.get("nz", 40))
SLZ = float(O.get("zslit", 0.80))
SLA = (float(O.get("sla0", -177)), float(O.get("sla1", -33)))
NF = int(O.get("nf", 8))
BCL = float(O.get("bcl", 0.012))
if not EMBED:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=IN)
    body = bpy.data.objects["head_graft"]
    arm = [o for o in bpy.data.objects if o.type == "ARMATURE"][0]
if "Icosphere" in bpy.data.objects:
    bpy.data.objects.remove(bpy.data.objects["Icosphere"], do_unlink=True)
AW = arm.matrix_world
sk = bpy.data.objects["Skirt"]
SM = sk.matrix_world
SMI = SM.inverted()
me = sk.data
# --- 1. texture
img = bpy.data.images.load(TEX)
img.name = "r11_skirt"
img.pack()
mo = [m for m in me.materials if m.name.startswith("skirt-meshy")][0]
for nd in mo.node_tree.nodes:
    if nd.type == "TEX_IMAGE":
        nd.image = img
W_, H_ = img.size
px = np.empty(W_ * H_ * 4, np.float32)
img.pixels.foreach_get(px)
px = px.reshape(H_, W_, 4)
uvl = me.uv_layers.active.data
cols = []
for p in me.polygons:
    u, v = np.mean([uvl[l].uv[:] for l in range(p.loop_start, p.loop_start + p.loop_total)], 0)
    cols.append(px[min(int(v * H_), H_ - 1), min(int(u * W_), W_ - 1), :3])
c_lin = np.median(np.array(cols), 0)
print("liner colour (linear)", c_lin.round(3))
# --- 2. liner shell
bl = AW @ arm.data.bones["LeftUpLeg"].head_local
br = AW @ arm.data.bones["RightUpLeg"].head_local
C = np.array([(bl.x + br.x) / 2, (bl.y + br.y) / 2])
P = np.array([SM @ v.co for v in me.vertices])
th = np.arctan2(P[:, 1] - C[1], P[:, 0] - C[0])
r = np.hypot(P[:, 0] - C[0], P[:, 1] - C[1])
z = P[:, 2]
ti = ((th + np.pi) / (2 * np.pi) * NT).astype(int) % NT
bot = np.zeros(NT)
for k in range(NT):
    m = np.isin(ti, [(k + d) % NT for d in range(-3, 4)])
    bot[k] = np.percentile(z[m], 8) + BOFF if m.any() else z.min() + BOFF
bot = np.convolve(np.r_[bot[-4:], bot, bot[:4]], np.ones(9) / 9, "valid")
zr = np.linspace(bot.min(), ZTOP, 64)
dz = zr[1] - zr[0]
R = np.full((NT, len(zr)), np.nan)
for k in range(NT):
    mk = np.isin(ti, [(k + d) % NT for d in (-2, -1, 0, 1, 2)])
    for j, zz in enumerate(zr):
        m = mk & (np.abs(z - zz) < 1.5 * dz)
        if m.sum() >= 3:
            R[k, j] = np.percentile(r[m], PCT)
for k in range(NT):
    row = R[k]
    ok = ~np.isnan(row)
    R[k] = np.interp(zr, zr[ok], row[ok]) if ok.any() else np.nan
bad = np.isnan(R[:, 0])
for k in np.where(bad)[0]:  # empty azimuth (slit): borrow the nearest filled bin
    d = [(abs((kk - k + NT // 2) % NT - NT // 2), kk) for kk in range(NT) if not bad[kk]]
    R[k] = R[min(d)[1]]
for _ in range(2):
    R = (np.roll(R, 1, 0) + np.roll(R, -1, 0) + 2 * R) / 4
    R[:, 1:-1] = (R[:, :-2] + R[:, 2:] + 2 * R[:, 1:-1]) / 4
R = R - INS
bm = bmesh.new()
grid = []
NV0 = len(me.vertices)
twin = {}
for v in me.vertices:
    twin[v.index] = bm.verts.new(
        v.co - v.normal * 0.002
    )  # inner twin of every outer face: flipped, 2 mm inside, solid wine
bm.verts.ensure_lookup_table()
tfaces = []
for p in me.polygons:
    try:
        tfaces.append((bm.faces.new([twin[i] for i in reversed(p.vertices)]), list(reversed(p.vertices))))
    except ValueError:
        pass
for k in range(NT):
    tt = -np.pi + (k + 0.5) / NT * 2 * np.pi
    col = []
    for j in range(NZ + 1):
        zz = bot[k] + (ZTOP - bot[k]) * j / NZ
        rr = float(np.interp(zz, zr, R[k]))
        col.append(bm.verts.new(SMI @ Vector((C[0] + rr * math.cos(tt), C[1] + rr * math.sin(tt), zz))))
    grid.append(col)
outer = []
for k in range(NT):
    a, b = grid[k], grid[(k + 1) % NT]
    for j in range(NZ):
        deg = math.degrees(-np.pi + (k + 0.5) / NT * 2 * np.pi)
        zc = bot[k] + (ZTOP - bot[k]) * (j + 0.5) / NZ
        if SLA[0] < deg < SLA[1] and zc < SLZ:
            continue  # nothing inside the slit
        outer.append(bm.faces.new((a[j], b[j], b[j + 1], a[j + 1])))
bm.normal_update()
f = outer[len(outer) // 2]
cw = SM @ f.calc_center_median()
if (SM.to_3x3() @ f.normal).dot(Vector((cw.x - C[0], cw.y - C[1], 0))) < 0:
    for f in outer:
        f.normal_flip()
ret = bmesh.ops.duplicate(bm, geom=outer)
nf = [g for g in ret["geom"] if isinstance(g, bmesh.types.BMFace)]
nv = [g for g in ret["geom"] if isinstance(g, bmesh.types.BMVert)]
for v in nv:
    w = SM @ v.co
    d = Vector((w.x - C[0], w.y - C[1], 0))
    d.normalize()
    v.co = SMI @ (w - d * 0.002)
for f in nf:
    f.normal_flip()
bm.normal_update()
kd = kdtree.KDTree(len(P))
[kd.insert(Vector(p), i) for i, p in enumerate(P)]
kd.balance()
uvs = np.zeros((len(P), 2))
for l in me.loops:
    uvs[l.vertex_index] = uvl[l.index].uv
dl = bm.verts.layers.deform.verify()
uvm = bm.loops.layers.uv.verify()
sw = [{g.group: g.weight for g in v.groups} for v in me.vertices]
vuv = {}
inv = {tv: i for i, tv in twin.items()}
for v in bm.verts:
    i = inv[v] if v in inv else kd.find(SM @ v.co)[1]
    for g, x in sw[i].items():
        v[dl][g] = x
    vuv[v] = uvs[i]
for f in bm.faces:
    for l in f.loops:
        l[uvm].uv = vuv[l.vert]
# liner material: copy of skirt-meshy with a solid image
for i_ in reversed(range(len(me.materials))):
    if me.materials[i_] and me.materials[i_].name.startswith("skirt-liner"):
        me.materials.pop(index=i_)
for m_ in [m_ for m_ in bpy.data.materials if m_.name.startswith("skirt-liner")]:
    bpy.data.materials.remove(m_)
ml = mo.copy()
ml.name = "skirt-liner"
sol = bpy.data.images.new("r11_skirt_inner", 16, 16)
sol.pixels.foreach_set(np.tile(np.r_[c_lin, 1.0], 256).astype(np.float32))
sol.pack()
for nd in ml.node_tree.nodes:
    if nd.type == "TEX_IMAGE":
        nd.image = sol
tmp = bpy.data.meshes.new("liner")
bm.to_mesh(tmp)
bm.free()
tmp.materials.append(ml)
lo = bpy.data.objects.new("Liner", tmp)
bpy.context.scene.collection.objects.link(lo)
lo.matrix_world = SM
for g in sk.vertex_groups:
    lo.vertex_groups.new(name=g.name)
n_outer = len(me.polygons)
bpy.ops.object.select_all(action="DESELECT")
lo.select_set(True)
sk.select_set(True)
bpy.context.view_layer.objects.active = sk
bpy.ops.object.join()
me = sk.data
print("skirt faces: outer %d + liner %d" % (n_outer, len(me.polygons) - n_outer))
# --- 3. sample frames: liner faces with a vertex outside the outer cloth are deleted, until none
ms = [m.name for m in me.materials]
li = ms.index("skirt-liner")
NV = len(me.vertices)
fverts = [list(p.vertices) for p in me.polygons]
isl = np.array([p.material_index == li for p in me.polygons])
lvert = sorted({v for f, q in zip(fverts, isl) if q for v in f if not (NV0 <= v < 2 * NV0)})
arm.animation_data_create()
sc = bpy.context.scene
killed = set()
frames = []
for act in bpy.data.actions:
    f0, f1 = act.frame_range
    frames += [(act, int(round(f))) for f in np.linspace(f0, f1, NF)]


def sample():
    out = set()
    for act, f in frames:
        arm.animation_data.action = act
        sc.frame_set(f)
        bpy.context.view_layer.update()
        dg = bpy.context.evaluated_depsgraph_get()
        se = sk.evaluated_get(dg)
        m_ = se.to_mesh()
        co = np.empty(NV * 3, np.float32)
        m_.vertices.foreach_get("co", co)
        se.to_mesh_clear()
        W = np.c_[co.reshape(-1, 3), np.ones(NV)] @ np.array(SM).T
        W = W[:, :3]
        tris = [(f_[0], f_[1], f_[2]) for f_, q in zip(fverts, isl) if not q and len(f_) == 3] + [
            (f_[0], f_[2], f_[3]) for f_, q in zip(fverts, isl) if not q and len(f_) == 4
        ]
        tree = BVHTree.FromPolygons([Vector(x) for x in W], tris)
        hp = AW @ arm.pose.bones["Hips"].head
        bad = set()
        be = body.evaluated_get(dg)
        bme = be.to_mesh()
        BW = np.array([body.matrix_world @ v.co for v in bme.vertices])
        bt = [tuple(p_.vertices) for p_ in bme.polygons]
        be.to_mesh_clear()
        btree = BVHTree.FromPolygons([Vector(x) for x in BW], bt)
        for v in lvert:
            p = Vector(W[v])
            o = Vector((hp.x, hp.y, p.z))
            d = p - o
            L = d.length
            if L < 1e-4:
                continue
            h = tree.ray_cast(p + d / L * 0.001, d / L, 0.8)
            loc, nrm, _, dist = btree.find_nearest(p, 0.3)
            if loc is not None and dist < BCL:
                bad.add(v)  # inside the body (or within BCL of it): drop
            if h[0] is None:
                bad.add(v)  # nothing of the outer cloth beyond this liner vertex: it shows
        out |= bad
    return out


print("DBG lvert", len(lvert), "frames", len(frames), "bodyverts", len(body.data.vertices))
for it in range(6):
    bad = sample()
    print("pass %d: liner verts not covered by the outer cloth: %d" % (it, len(bad)))
    if not bad:
        break
    bm2 = bmesh.new()
    bm2.from_mesh(me)
    bm2.verts.ensure_lookup_table()
    bm2.faces.ensure_lookup_table()
    kill = [f for f in bm2.faces if f.material_index == li and any(v.index in bad for v in f.verts)]
    bmesh.ops.delete(bm2, geom=kill, context="FACES")
    bmesh.ops.delete(bm2, geom=[v for v in bm2.verts if not v.link_faces], context="VERTS")
    bm2.to_mesh(me)
    bm2.free()
    me.update()
    NV = len(me.vertices)
    fverts = [list(p.vertices) for p in me.polygons]
    isl = np.array([p.material_index == li for p in me.polygons])
    lvert = sorted({v for f, q in zip(fverts, isl) if q for v in f if not (NV0 <= v < 2 * NV0)})
    print("  liner faces now", int(isl.sum()))
if not EMBED:
    bpy.ops.export_scene.gltf(
        filepath=OUT,
        export_format="GLB",
        export_animation_mode="ACTIONS",
        export_yup=True,
        export_apply=False,
        export_skins=True,
        export_morph=False,
        export_image_format="JPEG",
    )
print("wrote", OUT)
