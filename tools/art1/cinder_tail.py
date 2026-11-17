"""Cinder's own tail on her spring chain: the game .glb (v95_to_game.py's port of a master whose fused tail was cut off)
loses the old kept spiky tail and gets the master's tail instead, unchanged in shape: cut off the master by the same
flood fill as the port's cut (cut_tail_A.py: body capsules stop it), decimated by the port's own make_low (welded, UV seams held) to TAIL_TRIS, placed by the
affine map that takes the master's tail-root ring onto the game body (vertices matched through their shared UVs).
The spring_scarftail_tail chain's rest is laid along the tail's centre line (its clips' keys stay relative to rest) and
the tail is weighted along that chain, so warden_springs.gd swings it as before. Rig and export only: no vertex of the
body or of the tail is moved off its master shape.
Run: blender -b --factory-startup --python tools/art1/cinder_tail.py -- GAME.glb MASTER.glb OUT.glb"""
import heapq
import os
import sys
from collections import Counter, deque

import bmesh
import bpy
import numpy as np
from mathutils import Vector
from mathutils.kdtree import KDTree

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "meshy"))
import bake_warden as BW  # noqa: E402

CHAIN = ["spring_scarftail_tail_%d" % i for i in range(9)]  # root -> tip; the tip bone has no skin of its own
OLD_TAIL = set(CHAIN) | {"tail"}  # the kept tail's bones: faces fully on them are the old tail
ROOT_BONE = "tail"  # the chain's parent: the root ring blends onto it (it rides the hips)
SLOTS = ("skin", "hair", "metal")  # toon slots a tail triangle can take (<slot>-<atlas> game materials)
CAPS = [((0.0, 0.05, 0.97), (0.0, 0.05, 1.54), 0.17),  # cut_tail_A.py's body capsules (fit frame, x squeezed 0.8)
        ((0.12, 0.05, 0.93), (0.14, 0.05, 0.57), 0.115), ((-0.12, 0.05, 0.93), (-0.14, 0.05, 0.57), 0.115),
        ((0.14, 0.05, 0.57), (0.13, 0.04, 0.13), 0.085), ((-0.14, 0.05, 0.57), (-0.13, 0.04, 0.13), 0.085)]
BINS = 48  # centre-line samples along the tail (geodesic distance from the root ring)
TAIL_TRIS = 3000  # the tail's share of the game budget (the old kept tail was 616; 1.5k smeared the flame tip)
FLOATER_VERTS = 60  # loose crumbs under this many vertices are dropped (v95_swap.py's default)
ROOT_GAP = 0.03  # m: tail boundary vertices this close to the body are the root ring
RING_R = 0.10  # m: master body vertices this close to the root ring fit the master -> game map


def import_game(path):
    """The game .glb as v95_swap.py reads it (bone axes as exported, so the rest re-exports unchanged): armature, body."""
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=path, bone_heuristic="BLENDER")
    new = [o for o in bpy.data.objects if o not in before]
    return next(o for o in new if o.type == "ARMATURE"), max((o for o in new if o.type == "MESH"), key=lambda o: len(o.data.vertices))


def select(obs, active):
    bpy.ops.object.mode_set(mode="OBJECT") if bpy.context.object and bpy.context.object.mode != "OBJECT" else None
    bpy.ops.object.select_all(action="DESELECT")
    for o in obs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = active


def seg_d(P, p0, p1):
    p0, p1 = np.array(p0), np.array(p1)
    d = p1 - p0
    t = np.clip(((P - p0) @ d) / (d @ d), 0, 1)
    return np.linalg.norm(P - (p0 + t[:, None] * d), axis=1)


def mesh_arrays(ob):
    me = ob.data
    n = len(me.vertices)
    co = np.empty(n * 3)
    me.vertices.foreach_get("co", co)
    M = np.array(ob.matrix_world)
    co = co.reshape(-1, 3) @ M[:3, :3].T + M[:3, 3]
    uv = np.empty(len(me.loops) * 2)
    me.uv_layers.active.data.foreach_get("uv", uv)
    lv = np.empty(len(me.loops), int)
    me.loops.foreach_get("vertex_index", lv)
    vuv = np.zeros((n, 2))
    vuv[lv] = uv.reshape(-1, 2)
    return co, vuv


def tail_mask(ob, co):
    """cut_tail_A.py's flood fill from the tail seeds, stopped by the body capsules (the port cut the same verts)."""
    F = co * (-1, -1, 1)
    F[:, 2] -= F[:, 2].min()
    S = F * (0.8, 1, 1)
    body = np.zeros(len(F), bool)
    for p0, p1, r in CAPS:
        body |= seg_d(S, np.array(p0) * (0.8, 1, 1), np.array(p1) * (0.8, 1, 1)) < r
    body |= (F[:, 2] > 1.05) | (F[:, 2] < 0.13)
    seeds = (~body) & ((((F[:, 1] < -0.17) & (F[:, 2] < 0.95)) | ((F[:, 1] < -0.11) & (F[:, 2] < 1.05)))
                       | ((F[:, 0] < -0.33) & (F[:, 2] < 0.82)))
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    bm.verts.ensure_lookup_table()
    seen = seeds.copy()
    ring = set()
    q = deque(np.where(seeds)[0].tolist())
    while q:
        v = bm.verts[q.popleft()]
        for e in v.link_edges:
            o = e.other_vert(v).index
            if body[o]:
                ring.add(v.index)
            elif not seen[o]:
                seen[o] = True
                q.append(o)
    bm.free()
    return seen, np.array(sorted(ring)), F


def affine(src, dst):
    """Least-squares affine map src -> dst (3x4), refit without the worst 20%."""
    keep = np.ones(len(src), bool)
    for _ in range(3):
        A = np.c_[src[keep], np.ones(keep.sum())]
        X = np.linalg.lstsq(A, dst[keep], rcond=None)[0]
        err = np.linalg.norm(np.c_[src, np.ones(len(src))] @ X - dst, axis=1)
        keep = err <= np.percentile(err, 80)
    print("TAIL map residual median %.4f m over %d pairs" % (np.median(err[keep]), keep.sum()), flush=True)
    return X


def centre_line(ob, body_pts):
    """Joint points along the tail, root first: on a welded copy (Meshy splits vertices at UV seams), the geodesic
    distance from the root ring (the open boundary touching the body), binned; bin centroids."""
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    bm.verts.ensure_lookup_table()
    co = np.array([v.co[:] for v in bm.verts])
    kd = KDTree(len(body_pts))
    for i, p in enumerate(body_pts):
        kd.insert(p, i)
    kd.balance()
    root = [v.index for v in bm.verts if v.is_boundary and kd.find(v.co)[2] < ROOT_GAP]
    dist = np.full(len(co), np.inf)
    h = [(0.0, i) for i in root]
    dist[root] = 0.0
    heapq.heapify(h)
    while h:
        d, i = heapq.heappop(h)
        if d > dist[i]:
            continue
        for e in bm.verts[i].link_edges:
            o = e.other_vert(bm.verts[i]).index
            nd = d + e.calc_length()
            if nd < dist[o]:
                dist[o] = nd
                heapq.heappush(h, (nd, o))
    bm.free()
    ok = np.isfinite(dist)
    print("TAIL root ring", len(root), "reached", int(ok.sum()), "of", len(co), "length %.3f m" % dist[ok].max(), flush=True)
    edges = np.linspace(0, dist[ok].max() + 1e-6, BINS + 1)
    pts = [co[root].mean(0)]
    for lo, hi in zip(edges[:-1], edges[1:]):
        m = ok & (dist >= lo) & (dist < hi)
        if m.any():
            pts.append(co[m].mean(0))
    pts = np.array(pts)
    s = np.r_[0, np.cumsum(np.linalg.norm(np.diff(pts, axis=0), axis=1))]
    t = np.linspace(0, s[-1], len(CHAIN))
    return np.array([[np.interp(x, s, pts[:, k]) for k in range(3)] for x in t])


def slot_of(rgb, z_fit, y_fit):
    """v95 spec cinder slots for a tail triangle (the box rules above 1.5 m never hit the tail)."""
    mx, mn = rgb.max(), rgb.min()
    v, s = mx, (mx - mn) / mx if mx > 0 else 0
    hh = 0.0
    if mx > mn:
        r, g, b = rgb
        hh = ((g - b) / (mx - mn) % 6 if mx == r else (b - r) / (mx - mn) + 2 if mx == g else (r - g) / (mx - mn) + 4) / 6
    if v < 0.3:
        return "hair" if (y_fit < -0.02 and 0.95 <= z_fit <= 1.55) else "metal"
    if s >= 0.5 and v >= 0.6 and (hh <= 0.12 or hh >= 0.95):
        return "metal"
    return "skin"


def main():
    game_path, master_path, out = sys.argv[sys.argv.index("--") + 1:][:3]
    bpy.ops.wm.read_factory_settings(use_empty=True)
    arm, body = import_game(game_path)
    gco, guv = mesh_arrays(body)
    vmat = np.zeros(len(gco), int)  # a material of each game vertex (before the old tail goes)
    for p in body.data.polygons:
        vmat[list(p.vertices)] = p.material_index
    gmats = [m.name for m in body.data.materials]

    # 1. the old kept tail: faces whose every vertex rides the tail bones only
    on_tail = np.zeros(len(gco), bool)
    tail_gi = {body.vertex_groups[b].index for b in OLD_TAIL if b in body.vertex_groups}
    for v in body.data.vertices:
        w = sum(g.weight for g in v.groups if g.group in tail_gi)
        on_tail[v.index] = w > 0.5 * max(1e-6, sum(g.weight for g in v.groups))
    bm = bmesh.new()
    bm.from_mesh(body.data)
    bm.faces.ensure_lookup_table()
    old = [f for f in bm.faces if all(on_tail[v.index] for v in f.verts)]
    old_mats = sorted({body.material_slots[f.material_index].name for f in old})
    n_old = len(old)
    bmesh.ops.delete(bm, geom=old, context="FACES")
    bm.to_mesh(body.data)
    bm.free()
    print("TAIL old faces removed", n_old, "materials", old_mats, flush=True)

    # 2. the master's tail, the port's body ratio
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=master_path)
    mob = next(o for o in bpy.data.objects if o not in before and o.type == "MESH")
    mco, muv = mesh_arrays(mob)
    seen, ring, F = tail_mask(mob, mco)
    print("TAIL master verts", seen.sum(), "ring", len(ring), flush=True)

    # master -> game map from body verts near the root ring, paired through their UVs (the port kept the master's UVs)
    rc = mco[ring].mean(0)
    near = np.where(~seen & (np.linalg.norm(mco - rc, axis=1) < RING_R))[0]
    gbody = np.where(~on_tail)[0]
    kd = KDTree(len(gbody))
    for k, i in enumerate(gbody):
        kd.insert((guv[i, 0], guv[i, 1], 0.0), k)
    kd.balance()
    src, dst, hit = [], [], []
    for i in near:
        _, k, d = kd.find((muv[i, 0], muv[i, 1], 0.0))
        if d < 2e-4:
            src.append(mco[i])
            dst.append(gco[gbody[k]])
            hit.append(gbody[k])
    X = affine(np.array(src), np.array(dst))

    # 3. tail-only mesh (faces fully inside the cut), decimated, mapped into the game frame
    bm = bmesh.new()
    bm.from_mesh(mob.data)
    bm.verts.ensure_lookup_table()
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not seen[v.index]], context="VERTS")
    bm.to_mesh(mob.data)
    bm.free()
    mob.data.transform(mob.matrix_world)
    mob.matrix_world.identity()
    J = np.c_[centre_line(mob, mco[near]), np.ones(len(CHAIN))] @ X  # on the full tail, then into the game frame
    tail_tris_hi = sum(len(p.vertices) - 2 for p in mob.data.polygons)
    select([mob], mob)
    low = BW.make_low(mob, TAIL_TRIS, FLOATER_VERTS, keep_uv=True)  # the port's own decimation (welded, seams held)
    bpy.data.objects.remove(mob)
    mob = low
    tco, _ = mesh_arrays(mob)
    tco = np.c_[tco, np.ones(len(tco))] @ X
    mob.data.vertices.foreach_set("co", tco.ravel())
    mob.data.update()
    print("TAIL tris", len(mob.data.polygons), "of", tail_tris_hi, "joints", np.round(J, 3).tolist(),
          flush=True)

    # 4. the chain's rest along the centre line
    select([arm], arm)
    bpy.ops.object.mode_set(mode="EDIT")
    Mi = arm.matrix_world.inverted()
    for i, name in enumerate(CHAIN):
        eb = arm.data.edit_bones[name]
        eb.use_connect = False
        h = Mi @ Vector(J[i])
        t = Mi @ Vector(J[i + 1]) if i + 1 < len(J) else h + (h - (Mi @ Vector(J[i - 1]))) * 0.5
        eb.head, eb.tail = h, t
    bpy.ops.object.mode_set(mode="OBJECT")
    for o in bpy.data.objects:  # the tip anchor rides the tip
        if o.name == "anchor_tail_tip":
            o.matrix_world.translation = Vector(J[-1])

    # 5. weights along the chain, slots, then join into the body
    tco = mesh_arrays(mob)[0]
    seg = J[1:] - J[:-1]
    sp = np.zeros(len(tco))
    for k, v in enumerate(tco):
        t = np.clip(((v - J[:-1]) * seg).sum(1) / (seg * seg).sum(1), 0, 1)
        d = np.linalg.norm(J[:-1] + t[:, None] * seg - v, axis=1)
        b = int(d.argmin())
        sp[k] = b + t[b]
    for o in list(mob.vertex_groups):
        mob.vertex_groups.remove(o)
    groups = {n: mob.vertex_groups.new(name=n) for n in [ROOT_BONE] + CHAIN[:-1]}
    last = len(CHAIN) - 2
    for k, s in enumerate(sp):
        b = min(int(s), last)
        f = s - b
        if f < 0.5:
            other = CHAIN[b - 1] if b > 0 else ROOT_BONE
            pairs = [(CHAIN[b], 0.5 + f), (other, 0.5 - f)]
        else:
            other = CHAIN[b + 1] if b < last else None
            pairs = [(CHAIN[b], 1.5 - f if other else 1.0)] + ([(other, f - 0.5)] if other else [])
        for n, w in pairs:
            if w > 1e-4:
                groups[n].add([k], w, "REPLACE")
    # the tail's paint is the atlas the body round its root wears (v95_swap names the master's images by face count,
    # so its body paint can be "v95" or "v95c"): the majority atlas of the root-ring vertices the map paired
    atlas = Counter(gmats[vmat[i]].split("-", 1)[1] for i in hit).most_common(1)[0][0]
    names = [n for n in SLOTS if "%s-%s" % (n, atlas) in gmats]
    for n in names:
        mob.data.materials.append(body.data.materials["%s-%s" % (n, atlas)])
    base = len(mob.data.materials) - len(names)
    img = bpy.data.images[atlas]
    px = np.empty(img.size[0] * img.size[1] * 4, np.float32)
    img.pixels.foreach_get(px)
    px = px.reshape(img.size[1], img.size[0], 4)
    uvl = mob.data.uv_layers.active.data
    for p in mob.data.polygons:
        u = np.mean([uvl[li].uv[:] for li in p.loop_indices], axis=0)
        c = mob.data.polygons[p.index].center
        fz, fy = c.z, c.y  # game frame = the fit frame: soles on z 0, she faces +Y
        rgb = px[int(np.clip(u[1], 0, 1) * (px.shape[0] - 1)), int(np.clip(u[0], 0, 1) * (px.shape[1] - 1)), :3]
        p.material_index = base + names.index(slot_of(rgb, fz, fy))
    print("TAIL atlas", atlas, "slots", {k: sum(1 for p in mob.data.polygons if p.material_index == base + i)
                                         for i, k in enumerate(names)}, flush=True)
    for a in body.data.color_attributes:  # the port's vertex colours are all 1 on the body (COLOR_0, COLOR_1)
        if a.name not in mob.data.color_attributes:
            mob.data.color_attributes.new(a.name, a.data_type, a.domain)
        mob.data.color_attributes[a.name].data.foreach_set("color", [1.0] * 4 * len(mob.data.color_attributes[a.name].data))
    select([body, mob], body)
    bpy.ops.object.join()
    bpy.ops.object.mode_set(mode="OBJECT")
    # glTF export of the rig, clips and mesh (v95_swap.py's settings)
    for o in bpy.data.objects:
        o.select_set(o.type != "MESH" or o == body)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.export_scene.gltf(filepath=out, export_format="GLB", use_selection=True, export_apply=False, export_animations=True,
                              export_animation_mode="ACTIONS", export_skins=True, export_yup=True, export_materials="EXPORT",
                              export_image_format="JPEG", export_jpeg_quality=92, export_extras=False, export_vertex_color="ACTIVE",
                              export_force_sampling=True, export_frame_step=1, export_optimize_animation_size=False,
                              export_def_bones=False)
    print("TAIL exported", out, os.path.getsize(out), "tris", sum(len(p.vertices) - 2 for p in body.data.polygons), flush=True)


main()
