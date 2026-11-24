"""r10 copy of lace-face-dress-1123/tools/liner.py + slit mask: liner faces are left out where the skirt itself is open
over a large area (the front slit: no skirt vert within +-AW azimuth bins and +-ZW z bins), so it closes the tier gaps and
small holes but keeps the slit.
blender -b -P liner.py -- IN.glb OUT.glb [key=val]: closed red liner shell inside the Meshy skirt (outer + flipped inner),
radius = low percentile of the skirt radius per (azimuth, z) bin minus INS, kept >= leg surface + LCL, bottom per azimuth
just above the ragged hem, weights = inverse-distance mean of the 6 nearest skirt verts, UV = nearest skirt vert."""
import bpy, bmesh, sys, math, numpy as np
from mathutils import Vector, kdtree
A = sys.argv[sys.argv.index('--') + 1:]; IN, OUT = A[0], A[1]; O = dict(a.split('=') for a in A[2:])
INS = float(O.get('ins', 0.006)); LCL = float(O.get('lcl', 0.02)); PCT = float(O.get('pct', 15)); BOFF = float(O.get('boff', 0.03))
ZTOP = float(O.get('ztop', 1.02)); NT = int(O.get('nt', 120)); NZ = int(O.get('nz', 48))
bpy.ops.wm.read_factory_settings(use_empty=True); bpy.ops.import_scene.gltf(filepath=IN)
if 'Icosphere' in bpy.data.objects: bpy.data.objects.remove(bpy.data.objects['Icosphere'], do_unlink=True)
arm = [o for o in bpy.data.objects if o.type == 'ARMATURE'][0]; AW = arm.matrix_world
sk = bpy.data.objects['Skirt']; SM = sk.matrix_world; SMI = SM.inverted()
bl = AW @ arm.data.bones['LeftUpLeg'].head_local; br = AW @ arm.data.bones['RightUpLeg'].head_local
C = np.array([(bl.x + br.x) / 2, (bl.y + br.y) / 2]); print('axis', C)
P = np.array([SM @ v.co for v in sk.data.vertices])
th = np.arctan2(P[:, 1] - C[1], P[:, 0] - C[0]); r = np.hypot(P[:, 0] - C[0], P[:, 1] - C[1]); z = P[:, 2]
ti = ((th + np.pi) / (2 * np.pi) * NT).astype(int) % NT
# legs: body verts dominated by leg bones
body = bpy.data.objects['head_graft']; BM_ = body.matrix_world
LEG = {'LeftUpLeg', 'LeftLeg', 'RightUpLeg', 'RightLeg'}; gname = {g.index: g.name for g in body.vertex_groups}
LP = []
for v in body.data.vertices:
    if not v.groups: continue
    g = max(v.groups, key=lambda g: g.weight)
    if gname[g.group] in LEG: LP.append(BM_ @ v.co)
LP = np.array(LP); lth = np.arctan2(LP[:, 1] - C[1], LP[:, 0] - C[0]); lr = np.hypot(LP[:, 0] - C[0], LP[:, 1] - C[1])
lti = ((lth + np.pi) / (2 * np.pi) * NT).astype(int) % NT
# bottom per azimuth: low percentile of hem z in a +-3 bin window
bot = np.zeros(NT)
for k in range(NT):
    m = np.isin(ti, [(k + d) % NT for d in range(-3, 4)])
    bot[k] = np.percentile(z[m], 8) + BOFF
bot = np.convolve(np.r_[bot[-4:], bot, bot[:4]], np.ones(9) / 9, 'valid'); print('bottom z %.3f-%.3f' % (bot.min(), bot.max()))
# radius grid
zr = np.linspace(bot.min(), ZTOP, 64); R = np.full((NT, len(zr)), np.nan); RL = np.zeros((NT, len(zr)))
dz = zr[1] - zr[0]
for k in range(NT):
    mk = np.isin(ti, [(k + d) % NT for d in (-1, 0, 1)]); ml = np.isin(lti, [(k + d) % NT for d in (-1, 0, 1)])
    for j, zz in enumerate(zr):
        m = mk & (np.abs(z - zz) < 1.5 * dz)
        if m.sum() >= 3: R[k, j] = np.percentile(r[m], PCT)
        m2 = ml & (np.abs(LP[:, 2] - zz) < 1.5 * dz)
        if m2.any(): RL[k, j] = lr[m2].max()
for k in range(NT):   # fill gaps along z
    row = R[k]; ok = ~np.isnan(row)
    R[k] = np.interp(zr, zr[ok], row[ok])
for _ in range(2):   # smooth
    R = (np.roll(R, 1, 0) + np.roll(R, -1, 0) + 2 * R) / 4
    R[:, 1:-1] = (R[:, :-2] + R[:, 2:] + 2 * R[:, 1:-1]) / 4
RS = R.copy(); R = np.maximum(R - INS, RL + LCL); R = np.minimum(R, RS + 0.004)
print('legs push: bins %d' % int(((RL + LCL) > RS - INS).sum()))
def rad(k, zz): return np.interp(zz, zr, R[k % NT])
# mesh
bm = bmesh.new(); grid = []
for k in range(NT):
    t = -np.pi + (k + 0.5) / NT * 2 * np.pi; col = []
    for j in range(NZ + 1):
        zz = bot[k] + (ZTOP - bot[k]) * j / NZ; rr = rad(k, zz)
        col.append(bm.verts.new(SMI @ Vector((C[0] + rr * math.cos(t), C[1] + rr * math.sin(t), zz))))
    grid.append(col)
AWN = int(O.get('aw', 2)); ZW = float(O.get('zw', 3.0)); BYK = [np.where(np.isin(ti, [(k + d) % NT for d in range(-AWN, AWN + 1)]))[0] for k in range(NT)]
def occ(k, zz):
    ii = BYK[k % NT]; return bool(ii.size) and bool((np.abs(z[ii] - zz) < ZW * dz).any())
outer = []; skipped = 0
for k in range(NT):
    a, b = grid[k], grid[(k + 1) % NT]
    for j in range(NZ):
        zc = bot[k] + (ZTOP - bot[k]) * (j + 0.5) / NZ
        if not (occ(k, zc) and occ(k + 1, zc)): skipped += 1; continue
        outer.append(bm.faces.new((a[j], b[j], b[j + 1], a[j + 1])))   # outward winding checked below
print('slit mask: skipped %d of %d liner faces' % (skipped, NT * NZ))
for v in [v for v in bm.verts if not v.link_faces]: bm.verts.remove(v)
bm.normal_update()
f = outer[0]; c = f.calc_center_median(); cw = SM @ c
if (SM.to_3x3() @ f.normal).dot(Vector((cw.x - C[0], cw.y - C[1], 0))) < 0:
    for f in outer: f.normal_flip()
bm.normal_update()
# inner flipped copy, 2 mm inside
ret = bmesh.ops.duplicate(bm, geom=outer); nf = [g for g in ret['geom'] if isinstance(g, bmesh.types.BMFace)]
nv = [g for g in ret['geom'] if isinstance(g, bmesh.types.BMVert)]
for v in nv:
    w = SM @ v.co; d = Vector((w.x - C[0], w.y - C[1], 0)); d.normalize(); v.co = SMI @ (w - d * 0.002)
for f in nf: f.normal_flip()
bm.normal_update()
# weights + uv from the skirt
kd = kdtree.KDTree(len(P))
for i, p in enumerate(P): kd.insert(Vector(p), i)
kd.balance()
uvs = np.zeros((len(P), 2)); me = sk.data
for l in me.loops: uvs[l.vertex_index] = me.uv_layers.active.data[l.index].uv
dl = bm.verts.layers.deform.verify(); uvl = bm.loops.layers.uv.verify()
sw = [{g.group: g.weight for g in v.groups} for v in me.vertices]
vuv = {}
for v in bm.verts:
    hits = kd.find_n(SM @ v.co, 6); acc = {}; tw = 0
    for co, i, d in hits:
        w = 1.0 / max(d, 0.003); tw += w
        for g, x in sw[i].items(): acc[g] = acc.get(g, 0) + w * x
    s = sum(acc.values())
    for g, x in acc.items():
        if x / s > 0.01: v[dl][g] = x / s
    vuv[v] = uvs[hits[0][1]]
for f in bm.faces:
    for l in f.loops: l[uvl].uv = vuv[l.vert]
n0 = len(me.polygons)
if O.get('dropinner', '1') == '1':   # the old flipped skirt copy is the second half of the faces (build_b step 5); the liner replaces it
    b2 = bmesh.new(); b2.from_mesh(me); b2.faces.ensure_lookup_table(); h = len(b2.faces) // 2
    def outw(f):
        c = SM @ f.calc_center_median(); return (SM.to_3x3() @ f.normal).dot(Vector((c.x - C[0], c.y - C[1], 0))) > 0
    print('outward share first half %.2f second half %.2f' % (np.mean([outw(f) for f in b2.faces[:h]]), np.mean([outw(f) for f in b2.faces[h:]])))
    bmesh.ops.delete(b2, geom=list(b2.faces[h:]), context='FACES'); b2.to_mesh(me); b2.free(); me.update()
tmp = bpy.data.meshes.new('liner'); bm.to_mesh(tmp); bm.free()
lo = bpy.data.objects.new('Liner', tmp); bpy.context.scene.collection.objects.link(lo); lo.matrix_world = SM
for g in sk.vertex_groups: lo.vertex_groups.new(name=g.name)
lm = me.materials[0].copy(); lm.name = 'skirt-liner'; lo.data.materials.append(lm)   # own primitive: checks can tell it apart
bpy.ops.object.select_all(action='DESELECT'); lo.select_set(True); sk.select_set(True); bpy.context.view_layer.objects.active = sk
bpy.ops.object.join()
print('skirt faces %d -> %d' % (n0, len(sk.data.polygons)))
bpy.ops.export_scene.gltf(filepath=OUT, export_format='GLB', export_animation_mode='ACTIONS', export_yup=True, export_apply=False, export_skins=True, export_morph=False)
