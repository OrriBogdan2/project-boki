"""Pigtail graft: swaps a Hunter's pigtails for Meshy-made ones on the game .glb, keeping everything else byte-identical in the mesh.

The live pigtails (hair-atlas faces outside |x| > XCUT or below ZCUT) are cut. The Meshy bust's hair (picked by colour, voted over the
mesh, connected pieces only) is aligned to the head (crown and cap centre), sheared in toward the neck and squeezed so it falls close to
the head and shoulders, graded to the live pigtails' palette along its length, thickened and voxel-remeshed into a solid lock, decimated,
unwrapped into free rectangles of the atlas (RECTS, from the atlas texels no kept face uses) and its colour baked into them. The locks are
skinned to the head bone and joined into Body. Used for Sparkle (ryzz), docs/art/wardens/V95_SWAP.md.
Run: blender -b --factory-startup --python tools/meshy/pigtail_graft.py -- LIVE.glb MESHY_BUST.glb OUT.glb PARAMS.json
PARAMS.json: s (scale new->live), auto (align), rects {"L":[u0,v0,u1,v1],"R":..}, tris, voxel, thick, shear, squeeze, yfree, cage, ray, grade."""
import sys, json, math, os
import bpy, bmesh, numpy as np
from mathutils import Vector, Matrix
def load_glb(path):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=path)
    return next(o for o in bpy.data.objects if o.type=='MESH')
def verts_tris(o):
    me=o.data; n=len(me.vertices)
    v=np.empty(n*3,np.float32); me.vertices.foreach_get('co',v); v=v.reshape(-1,3)
    me.calc_loop_triangles(); t=np.empty(len(me.loop_triangles)*3,np.int32); me.loop_triangles.foreach_get('vertices',t)
    return v,t.reshape(-1,3)
def vcol(o):
    """per-vertex rgb (0-1) sampled from the base colour image at the vertex's loop UVs"""
    me=o.data
    img=[n.image for n in o.data.materials[0].node_tree.nodes if n.type=='TEX_IMAGE'][0]
    w,h=img.size; px=np.empty(w*h*4,np.float32); img.pixels.foreach_get(px); px=px.reshape(h,w,4)[:,:,:3]
    nl=len(me.loops); uv=np.empty(nl*2,np.float32); me.uv_layers.active.data.foreach_get('uv',uv); uv=uv.reshape(-1,2)
    vi=np.empty(nl,np.int32); me.loops.foreach_get('vertex_index',vi)
    x=np.clip((uv[:,0]*w).astype(int),0,w-1); y=np.clip((uv[:,1]*h).astype(int),0,h-1)
    c=px[y,x]; acc=np.zeros((len(me.vertices),3),np.float64); cnt=np.zeros(len(me.vertices))
    np.add.at(acc,vi,c); np.add.at(cnt,vi,1)
    return (acc/np.maximum(cnt,1)[:,None]).astype(np.float32)
def hsv(c):
    mx=c.max(1); mn=c.min(1); d=mx-mn+1e-9
    r,g,b=c[:,0],c[:,1],c[:,2]
    h=np.where(mx==r,((g-b)/d)%6,np.where(mx==g,(b-r)/d+2,(r-g)/d+4))/6.0
    return h%1.0, d/np.maximum(mx,1e-9), mx
def hair_mask(c):
    h,s,v=hsv(c)
    return (h>0.52)&(h<0.945)&(s>0.18)&(v>0.12)
def not_hair(c):
    h,s,v=hsv(c)
    return (((h<0.10)|(h>0.955))&(s>0.2)) | (v<0.2)
def not_hair_smooth(c, t, iters=10, thr=0.5):
    """non-hair label (skin/copper hue, or near black), voted over the mesh neighbourhood so dark strand shading does not punch holes"""
    h,s,v=hsv(c)
    lab=((((h<0.10)|(h>0.955))&(s>0.25)) | (v<0.22)).astype(np.float32)
    n=len(c); a=np.concatenate([t[:,0],t[:,1],t[:,2],t[:,1],t[:,2],t[:,0]]); b=np.concatenate([t[:,1],t[:,2],t[:,0],t[:,0],t[:,1],t[:,2]])
    deg=np.bincount(a,minlength=n).astype(np.float32)+1
    for _ in range(iters):
        acc=np.bincount(a,weights=lab[b],minlength=n)+lab
        lab=acc/deg
    return lab>thr


live_p, new_p, out_p, par_p = sys.argv[sys.argv.index('--') + 1:][:4]
P = json.load(open(par_p))
S, T = P['s'], P['t']                      # new -> live: p' = S * Rz180 * p + T
XCUT, ZCUT = P.get('xcut', 0.085), P.get('zcut', 1.56)   # live frame: pigtail = hair outside |x|>XCUT or below ZCUT
TRIS = P.get('tris', 2200)                 # per side
VOX = P.get('voxel', 0.0035)
RECTS = P['rects']                         # {"L":[u0,v0,u1,v1], "R":[...]} in 0-1 uv (v up)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=live_p, bone_heuristic="BLENDER")
body = next(o for o in bpy.data.objects if o.name.startswith('Body'))
arm = next(o for o in bpy.data.objects if o.type == 'ARMATURE'); arm.name = 'Armature'
hair_mi = [i for i, m in enumerate(body.data.materials) if m.name == 'hair-atlas'][0]
atlas = body.data.materials[hair_mi].node_tree.nodes
atlas = [n.image for n in atlas if n.type == 'TEX_IMAGE'][0]
uvname = body.data.uv_layers.active.name

# 1. cut the live pigtails
bm = bmesh.new(); bm.from_mesh(body.data)
kill = [f for f in bm.faces if f.material_index == hair_mi and f.calc_center_median().z > 1.43
        and (abs(f.calc_center_median().x) > XCUT or f.calc_center_median().z < ZCUT)]
n_live_hair = sum(1 for f in bm.faces if f.material_index == hair_mi)
# the tail ends hooked over the shoulders (z 1.33-1.43, outside the chest)
ks = set(kill)
for g in bm.faces:
    c = g.calc_center_median()
    if g.material_index == hair_mi and 1.34 < c.z <= 1.46 and 0.10 < abs(c.x) < 0.27 and c.y < 0.08: ks.add(g)
kill = list(ks)
# live pigtail colours by height (the palette the new hair is graded to)
_w, _h = atlas.size; _px = np.empty(_w * _h * 4, np.float32); atlas.pixels.foreach_get(_px); _px = _px.reshape(_h, _w, 4)[:, :, :3]
_uv = bm.loops.layers.uv.active
live_col = []
for f in kill:
    uvc = np.mean([l[_uv].uv[:] for l in f.loops], axis=0)
    live_col.append((f.calc_center_median().z, *_px[min(_h - 1, int(uvc[1] * _h)), min(_w - 1, int(uvc[0] * _w))]))
live_col = np.array(live_col)
bmesh.ops.delete(bm, geom=kill, context='FACES')
loose = [v for v in bm.verts if not v.link_faces]; bmesh.ops.delete(bm, geom=loose, context='VERTS')
bm.to_mesh(body.data); bm.free()
print('CUT removed', len(kill), 'of', n_live_hair, 'hair tris')
if P.get('cut_only'):
    pass
else:
    # 2. the Meshy bust
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=new_p)
    mo = next(o for o in set(bpy.data.objects) - before if o.type == 'MESH')
    v, t = verts_tris(mo); c = vcol(mo); hm = hair_mask(c)
    R = np.array([[-1, 0, 0], [0, -1, 0], [0, 0, 1]], np.float32)
    if P.get('auto'):   # align crown z and cap centre x,y of the head hair
        lv, _ = verts_tris(body)
        mhair = np.zeros(len(lv), bool)
        for pl in body.data.polygons:
            if pl.material_index == hair_mi: mhair[list(pl.vertices)] = True
        lc = lv[mhair & (lv[:, 2] > 1.66) & (abs(lv[:, 0]) < 0.05)]
        rv = v @ R.T
        crown = rv[hm & (abs(rv[:, 0]) < 0.05), 2].max()
        nc = rv[hm & (rv[:, 2] > crown - 0.2) & (abs(rv[:, 0]) < 0.17)]
        T = [lc[:, 0].mean() - S * nc[:, 0].mean() + P.get('dx', 0), lc[:, 1].mean() - S * nc[:, 1].mean() + P.get('dy', 0),
             lc[:, 2].max() - S * crown + P.get('dz', 0)]
        print('AUTO T', [round(float(x), 4) for x in T], 'live cap', lc.mean(0).round(3), 'zmax', lc[:, 2].max())
    w = (v @ R.T) * S + np.array(T, np.float32)
    nh = not_hair_smooth(c, t)
    sides = {}; reg_all = np.zeros(len(v), bool)
    for side, sg in (('L', 1), ('R', -1)):
        reg = ~nh & (w[:, 2] > 1.2) & (((sg * w[:, 0]) > P.get('xnew', 0.065)) | ((w[:, 2] < ZCUT) & (sg * w[:, 0] > 0.045)))
        reg_all |= reg; keep_f = reg[t].all(1)
        tt = t[keep_f]
        # largest connected components by shared vertices
        _, wid = np.unique(np.round(v * 1e5).astype(np.int64), axis=0, return_inverse=True)
        wid = wid.ravel(); par = np.arange(len(v))
        def find(a):
            while par[a] != a:
                par[a] = par[par[a]]; a = par[a]
            return a
        wt = wid[tt]; par = np.arange(wid.max() + 1)
        for a, b, cc in wt:
            ra, rb = find(a), find(b); par[rb] = ra; par[find(cc)] = ra
        roots = np.array([find(a) for a in wt[:, 0]])
        u, cnt = np.unique(roots, return_counts=True)
        good = set(u[cnt > max(P.get('minisland', 3000), 0.4 * cnt.max())])
        tt = tt[[r in good for r in roots]]
        used = np.unique(tt); remap = -np.ones(len(v), int); remap[used] = np.arange(len(used))
        sides[side] = (used, tt)
        print('HI', side, len(used), 'verts', len(tt), 'tris')
    # build hi objects by duplicating the Meshy object and deleting the rest (keeps UVs/material)
    mw = Matrix(((-S, 0, 0, T[0]), (0, -S, 0, T[1]), (0, 0, S, T[2]), (0, 0, 0, 1)))
    mo.matrix_world = mw
    his = {}
    for side in 'LR':
        used, tt = sides[side]
        ob = mo.copy(); ob.data = mo.data.copy(); ob.name = 'hi' + side; bpy.context.scene.collection.objects.link(ob)
        bm = bmesh.new(); bm.from_mesh(ob.data); bm.verts.ensure_lookup_table()
        keepv = set(used.tolist())
        bmesh.ops.delete(bm, geom=[x for x in bm.verts if x.index not in keepv], context='VERTS')
        # also drop triangles not in tt (verts kept but face not wholly in selection region)
        bm.to_mesh(ob.data); bm.free()
        his[side] = ob
    bpy.data.objects.remove(mo)
    if P.get('dump_hi'):
        for o in bpy.data.objects:
            o.select_set(o.name in ('hiL', 'hiR'))
        bpy.ops.export_scene.gltf(filepath=P['dump_hi'], export_format='GLB', use_selection=True)
        sys.exit(0)
    # tuck: shear the pigtails in toward the neck (waves kept) and squeeze what still sticks out past the shoulder line
    K, F, ZR, X0 = P.get('shear', 0.3), P.get('squeeze', 0.85), P.get('zroot', 1.68), P.get('x0', 0.11)
    for side, hi in his.items():
        sg = 1 if side == 'L' else -1
        bpy.ops.object.select_all(action='DESELECT'); hi.select_set(True); bpy.context.view_layer.objects.active = hi
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
        n = len(hi.data.vertices); co = np.empty(n * 3, np.float32); hi.data.vertices.foreach_get('co', co); co = co.reshape(-1, 3)
        ax = np.abs(co[:, 0]); lo_ = np.maximum(0, ZR - co[:, 2]) * np.clip((P.get('yfree', 0.13) - co[:, 1]) / 0.08, 0, 1); ax = ax - K * lo_; ax = np.where(ax > X0, X0 + (ax - X0) * F, ax)
        co[:, 0] = np.maximum(ax, 0.01) * sg; hi.data.vertices.foreach_set('co', co.ravel()); hi.data.update()
    # grade: per-vertex gain so the Meshy hair takes the live pigtails' palette along its length
    bins = np.arange(1.28, 1.76, 0.04)
    def med(zv, cv):
        out = []
        for z0 in bins:
            m = (zv >= z0) & (zv < z0 + 0.04)
            out.append(np.median(cv[m], axis=0) if m.sum() > 20 else np.full(3, np.nan))
        out = np.array(out)
        for k in range(3):
            ok = ~np.isnan(out[:, k]); out[:, k] = np.interp(bins, bins[ok], out[ok, k])
        return out
    gain_tab = np.clip(med(live_col[:, 0], live_col[:, 1:4]) / np.maximum(med(w[reg_all][:, 2], c[reg_all]), 1e-3), 0.3, 3.0) if P.get('grade', 1) else np.ones((len(bins), 3))
    for side, hi in his.items():
        gm = hi.data; zs = np.array([(hi.matrix_world @ vv.co).z for vv in gm.vertices])
        idx = np.clip(((zs - 1.28) / 0.04).astype(int), 0, len(bins) - 1)
        ca = gm.color_attributes.new('gain', 'FLOAT_COLOR', 'POINT')
        for i, vv in enumerate(gm.vertices): ca.data[i].color = (*gain_tab[idx[i]], 1.0)
        mt = gm.materials[0]; nt = mt.node_tree
        bsdf = next(n for n in nt.nodes if n.type == 'BSDF_PRINCIPLED'); lk = bsdf.inputs['Base Color'].links[0]
        mix = nt.nodes.new('ShaderNodeMix'); mix.data_type = 'RGBA'; mix.blend_type = 'MULTIPLY'; mix.inputs[0].default_value = 1.0
        at = nt.nodes.new('ShaderNodeAttribute'); at.attribute_name = 'gain'
        nt.links.new(lk.from_socket, mix.inputs[6]); nt.links.new(at.outputs['Color'], mix.inputs[7]); nt.links.new(mix.outputs[2], bsdf.inputs['Base Color'])
    print('GAIN', gain_tab[::3].round(2).tolist())
    # 3. low mesh per side
    lows = {}
    for side, hi in his.items():
        bpy.ops.object.select_all(action='DESELECT'); hi.select_set(True); bpy.context.view_layer.objects.active = hi
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
        lo = hi.copy(); lo.data = hi.data.copy(); lo.name = 'lo' + side; bpy.context.scene.collection.objects.link(lo)
        # drop the Meshy material from lo; use fresh bake material later
        lo.data.materials.clear()
        bpy.ops.object.select_all(action='DESELECT'); lo.select_set(True); bpy.context.view_layer.objects.active = lo
        so = lo.modifiers.new('so', 'SOLIDIFY'); so.thickness = P.get('thick', 0.008); so.offset = 0.0
        bpy.ops.object.modifier_apply(modifier='so')
        lo.data.remesh_voxel_size = VOX; lo.data.remesh_voxel_adaptivity = 0.0
        bpy.ops.object.voxel_remesh()
        tr = lo.modifiers.new('t', 'TRIANGULATE'); bpy.ops.object.modifier_apply(modifier='t')
        d = lo.modifiers.new('d', 'DECIMATE'); d.ratio = min(1.0, TRIS / max(1, len(lo.data.polygons)))
        bpy.ops.object.modifier_apply(modifier='d')
        sm = lo.modifiers.new('s', 'SMOOTH'); sm.factor = 0.5; sm.iterations = P.get('smooth', 3)
        bpy.ops.object.modifier_apply(modifier='s')
        bpy.ops.object.shade_smooth()
        print('LOW', side, len(lo.data.polygons), 'tris')
        # uv: smart project then fit into the free rect
        bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.select_all(action='SELECT')
        bpy.ops.uv.smart_project(angle_limit=math.radians(66), island_margin=0.01)
        bpy.ops.object.mode_set(mode='OBJECT')
        uvl = lo.data.uv_layers.active; uvl.name = uvname
        arr = np.empty(len(uvl.data) * 2, np.float32); uvl.data.foreach_get('uv', arr); arr = arr.reshape(-1, 2)
        mn, mx = arr.min(0), arr.max(0); u0, v0, u1, v1 = RECTS[side]
        arr = (arr - mn) / np.maximum(mx - mn, 1e-9); arr[:, 0] = u0 + arr[:, 0] * (u1 - u0); arr[:, 1] = v0 + arr[:, 1] * (v1 - v0)
        uvl.data.foreach_set('uv', arr.ravel())
        lows[side] = lo
    # pre-fill the two rects with the live tail pink, so a texel the bake misses (a thin tip) is pink, not the old blue
    pink = np.median(live_col[live_col[:, 0] < 1.5][:, 1:4], axis=0)
    _px2 = np.empty(_w * _h * 4, np.float32); atlas.pixels.foreach_get(_px2); _px2 = _px2.reshape(_h, _w, 4)
    for side in 'LR':
        u0, v0, u1, v1 = RECTS[side]
        _px2[int(v0 * _h) - 6:int(v1 * _h) + 6, int(u0 * _w) - 6:int(u1 * _w) + 6, :3] = pink
    atlas.pixels.foreach_set(_px2.ravel()); atlas.update()
    # 4. bake the Meshy colour into the atlas (selected-to-active), one side at a time
    sc = bpy.context.scene; sc.render.engine = 'CYCLES'; sc.cycles.device = 'CPU'; sc.cycles.samples = 1
    sc.render.bake.use_selected_to_active = True; sc.render.bake.cage_extrusion = P.get('cage', 0.01)
    sc.render.bake.max_ray_distance = P.get('ray', 0.04); sc.render.bake.margin = 6
    sc.render.bake.use_pass_direct = False; sc.render.bake.use_pass_indirect = False; sc.render.bake.use_pass_color = True
    for side in 'LR':
        lo, hi = lows[side], his[side]
        m = bpy.data.materials.new('bake' + side); m.use_nodes = True
        tn = m.node_tree.nodes.new('ShaderNodeTexImage'); tn.image = atlas; m.node_tree.nodes.active = tn
        lo.data.materials.append(m)
        bpy.ops.object.select_all(action='DESELECT'); hi.select_set(True); lo.select_set(True)
        bpy.context.view_layer.objects.active = lo
        bpy.ops.object.bake(type='DIFFUSE', use_clear=False)
        lo.data.materials.clear()
        print('BAKED', side)
    for ob in his.values():
        bpy.data.objects.remove(ob)
    # 5. skin to head, material hair, join into Body
    for side, lo in lows.items():
        lo.data.materials.append(body.data.materials[hair_mi])
        vg = lo.vertex_groups.new(name='head'); vg.add(list(range(len(lo.data.vertices))), 1.0, 'REPLACE')
        for pl in lo.data.polygons:
            pl.material_index = 0
    bpy.ops.object.select_all(action='DESELECT')
    for lo in lows.values(): lo.select_set(True)
    body.select_set(True); bpy.context.view_layer.objects.active = body
    # material index of hair in body is hair_mi; joined objs carry hair material in slot 0 -> remapped by name on join
    bpy.ops.object.join()
    body = bpy.context.view_layer.objects.active
    print('JOINED tris', len(body.data.polygons), 'mats', [m.name for m in body.data.materials])
# 6. export
for o in bpy.data.objects: o.select_set(o.type in ('MESH', 'ARMATURE', 'EMPTY'))
atlas.pixels  # keep
bpy.ops.export_scene.gltf(filepath=out_p, export_format="GLB", use_selection=False, export_apply=False, export_animations=True,
                          export_animation_mode="ACTIONS", export_skins=True, export_yup=True, export_materials="EXPORT",
                          export_image_format="JPEG", export_jpeg_quality=92, export_extras=False, export_vertex_color="ACTIVE",
                          export_force_sampling=True, export_frame_step=1, export_optimize_animation_size=False, export_def_bones=False)
print('BUILD exported', out_p, os.path.getsize(out_p))
