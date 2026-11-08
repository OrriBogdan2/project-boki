"""A Meshy model fitted to the Warden contract (docs/art/wardens/PIPELINE.md, RIG_CONTRACT.md), in Blender 4.5:

  ~/tools/blender-4.5.15-linux-x64/blender -b --factory-startup --python tools/meshy/fit_warden.py -- <spec.json>

The spec (art/wardens/src/<name>_fit.json) names the Meshy body and weapon .glb files, the rig JSON
(`godot --headless -- --warden-rig-json`), and the body's joints as measured on the Meshy mesh (its own
frame: Blender, +Z up, metres). Steps:
 1. Import the body, drop floaters (loose bits under `floater_verts`), turn it to face +Y, scale it so its
    hip joints meet the rig's, stand it on Z = 0 centred between the hips.
 2. Pose it into the contract's rest pose: a fit armature on the mesh's own joints (A-pose) is bound with
    automatic weights, each bone is turned and stretched onto the rig's joint (arms hanging, legs straight,
    neck and head on the rig's), and the pose is applied to the mesh.
 3. Decimate to `max_tris`, keeping the UVs and Meshy's base-colour texture.
 4. Split the faces into the toon slots (RIG_CONTRACT "Materials") by the colour each face is painted, all
    sharing the one texture.
 5. Skin to the contract armature (automatic weights; root, skirt, scarf and the pauldrons don't deform).
 6. The weapon: its long axis onto the Gun node's forward (+Y here), the barrel's end on the Muzzle, the
    strips hanging down, pieces closed up along the axis; scaled to `weapon_len`.
 7. Anchors, then the .glb.
"""
import json
import math
import os
import sys

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector, geometry

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "blender"))
import warden_kit as K  # noqa: E402
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bow_parts  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
FIT_BONES = [  # bone, head joint, tail joint, parent
    ("hips", "pelvis", "neck", None), ("head", "neck", "crown", "hips"),
    ("upper_arm.L", "shoulder.L", "elbow.L", "hips"), ("forearm.L", "elbow.L", "hand.L", "upper_arm.L"),
    ("hand.L", "hand.L", "fingers.L", "forearm.L"),
    ("upper_arm.R", "shoulder.R", "elbow.R", "hips"), ("forearm.R", "elbow.R", "hand.R", "upper_arm.R"),
    ("hand.R", "hand.R", "fingers.R", "forearm.R"),
    ("thigh.L", "hip.L", "knee.L", "hips"), ("shin.L", "knee.L", "ankle.L", "thigh.L"),
    ("thigh.R", "hip.R", "knee.R", "hips"), ("shin.R", "knee.R", "ankle.R", "thigh.R"),
]
NO_DEFORM = ["root", "skirt", "scarf", "pauldron.L", "pauldron.R", "cape", "tail", "wings"]


def log(*a):
    print("FITWARDEN", *a, flush=True)


def import_glb(path):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=path)
    new = [o for o in bpy.data.objects if o not in before]
    meshes = [o for o in new if o.type == "MESH"]
    for o in new:
        if o.type != "MESH":
            for m in meshes:
                if m.parent == o:
                    mw = m.matrix_world.copy()
                    m.parent = None
                    m.matrix_world = mw
    bpy.ops.object.select_all(action="DESELECT")
    for m in meshes:
        m.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    if len(meshes) > 1:
        bpy.ops.object.join()
    ob = bpy.context.view_layer.objects.active
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    for o in new:
        if o.name in bpy.data.objects and o is not ob:
            bpy.data.objects.remove(o)
    return ob


def base_image_of(ob):
    """The texture of an object whose materials are the slot materials (one image)."""
    for m in ob.data.materials:
        for n in m.node_tree.nodes:
            if n.type == "TEX_IMAGE" and n.image:
                return n.image
    return None


def base_image(ob):
    mat = ob.data.materials[0]
    bsdf = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    link = bsdf.inputs["Base Color"].links[0]
    return link.from_node.image


def drop_floaters(ob, min_verts):
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)     # (Meshy splits vertices along UV seams)
    bm.verts.ensure_lookup_table()
    seen = set()
    small = []
    for v in bm.verts:
        if v.index in seen:
            continue
        part = []
        stack = [v]
        seen.add(v.index)
        while stack:
            x = stack.pop()
            part.append(x)
            for e in x.link_edges:
                o = e.other_vert(x)
                if o.index not in seen:
                    seen.add(o.index)
                    stack.append(o)
        if len(part) < min_verts:
            small.extend(part)
    bmesh.ops.delete(bm, geom=small, context="VERTS")
    bm.to_mesh(ob.data)
    bm.free()
    log("floaters: dropped %d verts" % len(small))


def transform(ob, m):
    ob.data.transform(m)
    ob.data.update()


def snap(ob, p, r, keep_y=False):
    """The middle of the mesh near joint p (vertices within r in the side view, at any depth). keep_y: the
    given depth stays (hair hanging behind the neck or a backpack behind the shoulders move a depth midpoint)."""
    co = np.array([v.co[:] for v in ob.data.vertices])
    d = np.hypot(co[:, 0] - p.x, co[:, 2] - p.z)
    near = co[d < r]
    if len(near) < 8:
        return p
    y = p.y if keep_y else float((near[:, 1].min() + near[:, 1].max()) * 0.5)
    return Vector((float(near[:, 0].mean()), y, float(near[:, 2].mean())))


def fit_armature(joints):
    data = bpy.data.armatures.new("Fit")
    arm = bpy.data.objects.new("Fit", data)
    bpy.context.scene.collection.objects.link(arm)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="EDIT")
    for name, h, t, par in FIT_BONES:
        e = data.edit_bones.new(name)
        e.head = joints[h]
        e.tail = joints[t]
        if par:
            e.parent = data.edit_bones[par]
    bpy.ops.object.mode_set(mode="OBJECT")
    return arm


def auto_weights(ob, arm):
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    arm.select_set(True)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.parent_set(type="ARMATURE_AUTO")
    if not any(sum(x.weight for x in v.groups) > 1e-4 for v in ob.data.vertices):
        _proxy_weights(ob, arm)
    _fill_weights(ob, arm)
    log("auto weights on %s: %d groups" % (arm.name, len(ob.vertex_groups)))


def _proxy_weights(ob, arm, voxel=0.012):
    """Bone heat found no solution on the whole scan (Kael: the skirt's plates and the scarf pass through each
    other): it runs on a watertight voxel remesh of the body instead, and the weights come back onto the scan
    from the nearest proxy face (interpolated)."""
    px = ob.copy()
    px.data = ob.data.copy()
    px.vertex_groups.clear()
    px.modifiers.clear()
    px.parent = None
    bpy.context.scene.collection.objects.link(px)
    rm = px.modifiers.new("Remesh", "REMESH")
    rm.mode = "VOXEL"
    rm.voxel_size = voxel
    bpy.ops.object.select_all(action="DESELECT")
    bpy.context.view_layer.objects.active = px
    px.select_set(True)
    bpy.ops.object.modifier_apply(modifier="Remesh")
    arm.select_set(True)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.parent_set(type="ARMATURE_AUTO")
    for g in px.vertex_groups:
        if ob.vertex_groups.get(g.name) is None:
            ob.vertex_groups.new(name=g.name)
    dt = ob.modifiers.new("WeightsFromProxy", "DATA_TRANSFER")
    dt.object = px
    dt.use_vert_data = True
    dt.data_types_verts = {"VGROUP_WEIGHTS"}
    dt.vert_mapping = "POLYINTERP_NEAREST"
    dt.layers_vgroup_select_src = "ALL"
    dt.layers_vgroup_select_dst = "NAME"
    bpy.ops.object.select_all(action="DESELECT")
    bpy.context.view_layer.objects.active = ob
    ob.select_set(True)
    while ob.modifiers[0].name != dt.name:
        bpy.ops.object.modifier_move_up(modifier=dt.name)
    bpy.ops.object.modifier_apply(modifier=dt.name)
    log("bone heat on a %.3f m voxel proxy (%d verts), weights transferred" % (voxel, len(px.data.vertices)))
    bpy.data.objects.remove(px)


def _fill_weights(ob, arm):
    """Bone heat fails on pieces it can't solve (loose parts, the joined head): every vertex left without a
    weight takes its nearest weighted vertex's weights, or, with none near, the nearest deforming bone's."""
    groups = {g.index: g for g in ob.vertex_groups}
    has = np.array([sum(x.weight for x in v.groups) > 1e-4 for v in ob.data.vertices])
    co = np.array([v.co[:] for v in ob.data.vertices])
    missing = np.nonzero(~has)[0]
    if len(missing) == 0:
        return
    from mathutils.kdtree import KDTree
    done = np.nonzero(has)[0]
    if len(done) > 0:
        kd = KDTree(len(done))
        for i in done:
            kd.insert(co[i], int(i))
        kd.balance()
    segs = [(b.name, Vector(b.head_local), Vector(b.tail_local)) for b in arm.data.bones if b.use_deform]
    for i in missing:
        src = None
        if len(done) > 0:
            _p, j, d = kd.find(co[i])
            if d < 0.06:
                src = ob.data.vertices[j]
        if src is not None:
            for x in src.groups:
                groups[x.group].add([int(i)], x.weight, "REPLACE")
            continue
        p = Vector(co[i])
        best = min(segs, key=lambda sg: _seg_dist(p, sg[1], sg[2]))
        g = ob.vertex_groups.get(best[0]) or ob.vertex_groups.new(name=best[0])
        g.add([int(i)], 1.0, "REPLACE")
    log("weights filled for %d of %d vertices" % (len(missing), len(co)))


def _seg_dist(p, a, b):
    ab = b - a
    t = max(0.0, min(1.0, (p - a).dot(ab) / max(ab.length_squared, 1e-9)))
    return (a + ab * t - p).length


def pose_to_rig(arm, rig_joints):
    """Turns and stretches each fit bone onto the rig's joints, parents first."""
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="POSE")
    for name, h, t, _par in FIT_BONES:
        pb = arm.pose.bones[name]
        rest = arm.data.bones[name].matrix_local
        head = rig_joints[h]
        rest_dir = (rest.to_3x3() @ Vector((0, 1, 0))).normalized()
        rest_len = arm.data.bones[name].length
        if name == "head":
            want = rest_dir * rest_len                                   # (the head keeps its own tilt)
        elif name.startswith("hand."):
            want = (rig_joints[t] - head).normalized() * rest_len        # (hangs on, its own size)
        else:
            want = rig_joints[t] - head
        rot = rest_dir.rotation_difference(want.normalized()).to_matrix().to_4x4()
        k = want.length / rest_len
        m = Matrix.Translation(head) @ rot @ rest.to_3x3().to_4x4() @ Matrix.Diagonal((1.0, k, 1.0, 1.0))
        pb.matrix = m
        bpy.context.view_layer.update()
    bpy.ops.object.mode_set(mode="OBJECT")


def _apply_armature(ob):
    bpy.context.view_layer.objects.active = ob
    for m in list(ob.modifiers):
        if m.type == "ARMATURE":
            bpy.ops.object.modifier_apply(modifier=m.name)
    ob.vertex_groups.clear()
    mw = ob.matrix_world.copy()
    ob.parent = None
    ob.matrix_world = mw


def apply_pose(ob, arm):
    bpy.context.view_layer.objects.active = ob
    for m in list(ob.modifiers):
        if m.type == "ARMATURE":
            bpy.ops.object.modifier_apply(modifier=m.name)
    ob.vertex_groups.clear()
    mw = ob.matrix_world.copy()
    ob.parent = None
    ob.matrix_world = mw
    bpy.data.objects.remove(arm)


def decimate(ob, max_tris):
    tris = sum(len(p.vertices) - 2 for p in ob.data.polygons)
    if tris > max_tris:
        m = ob.modifiers.new("dec", "DECIMATE")
        m.ratio = max_tris / tris
        m.use_collapse_triangulate = True
        m.delimit = {"UV"}            # keep the texture's islands whole (the sigil, the face)
        bpy.context.view_layer.objects.active = ob
        bpy.ops.object.modifier_apply(modifier=m.name)
    log("decimate: %d -> %d tris" % (tris, sum(len(p.vertices) - 2 for p in ob.data.polygons)))


def slot_split(ob, img, palette, glow_min, tag):
    """Each face onto the toon slot of the palette colour nearest its painted colour; one material per slot and
    texture, named "<slot>-<tag>" (the loader reads the slot before the dash), all on this piece's texture."""
    w, h = img.size
    px = np.array(img.pixels[:], dtype=np.float32).reshape(h, w, 4)
    uv = ob.data.uv_layers.active.data
    pal = np.array([K.hexcol(c) for _s, c in palette], dtype=np.float32)
    names = [s for s, _c in palette]
    mats = slot_materials(img, [s for s in K.SLOTS if s != "team"], tag)
    ob.data.materials.clear()
    order = list(mats)
    for s in order:
        ob.data.materials.append(mats[s])
    counts = {}
    for p in ob.data.polygons:
        u = sum(uv[i].uv.x for i in p.loop_indices) / p.loop_total
        v = sum(uv[i].uv.y for i in p.loop_indices) / p.loop_total
        c = px[min(h - 1, max(0, int(v * h))), min(w - 1, max(0, int(u * w))), :3]     # (stored sRGB)
        if c[0] >= glow_min[0] and c[1] >= glow_min[1] and c[2] <= glow_min[2]:
            s = "glow"
        else:
            s = names[int(np.argmin(((pal - c) ** 2).sum(axis=1)))]
        p.material_index = order.index(s)
        counts[s] = counts.get(s, 0) + 1
    log("slots (%s):" % tag, counts)


def _face_islands(ob):
    """Each face's UV island (faces joined across edges whose UVs match on both sides)."""
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    lay = bm.loops.layers.uv.active
    bm.faces.ensure_lookup_table()
    island = [-1] * len(bm.faces)
    n = 0
    for f in bm.faces:
        if island[f.index] >= 0:
            continue
        stack = [f]
        island[f.index] = n
        while stack:
            g = stack.pop()
            for lp in g.loops:
                e = lp.edge
                for other in e.link_faces:
                    if island[other.index] >= 0:
                        continue
                    lo = next(x for x in other.loops if x.edge == e)
                    a0, a1 = lp[lay].uv, lp.link_loop_next[lay].uv
                    b0, b1 = lo[lay].uv, lo.link_loop_next[lay].uv
                    if ((a0 - b1).length < 1e-5 and (a1 - b0).length < 1e-5) or \
                            ((a0 - b0).length < 1e-5 and (a1 - b1).length < 1e-5):
                        island[other.index] = n
                        stack.append(other)
        n += 1
    bm.free()
    return np.array(island)


def _hsv(c):
    mx, mn = float(c.max()), float(c.min())
    d = max(mx - mn, 1e-6)
    if mx == c[0]:
        h = ((c[1] - c[2]) / d) % 6
    elif mx == c[1]:
        h = (c[2] - c[0]) / d + 2
    else:
        h = (c[0] - c[1]) / d + 4
    return h / 6.0, (mx - mn) / mx if mx > 0 else 0.0, mx


def slot_rules(ob, img, rules, glow_min, tag, default="skin", vote="island"):
    """The toon slots by body region and painted colour (rules: first match wins; else `default`), then every
    UV island takes its area's majority slot, so neighbouring triangles of one part never land on different
    slots (a tinted slot beside an untinted one read as a patchwork of facets). A rule: slot, box [x0, x1, y0,
    y1, z0, z1] in the Meshy frame (null: open; "absx": |x|), circle [x, z, r] (within r of x, z), hsv
    [h0, h1, s0, s1, v0, v1] (null: any).
    vote N (a number) instead: each face takes its neighbours' majority N times (a baked low mesh's UV islands
    are whole parts, too big to vote on: the face and the hair would share one)."""
    w, h = img.size
    px = np.array(img.pixels[:], dtype=np.float32).reshape(h, w, 4)
    uv = ob.data.uv_layers.active.data
    names = [s for s in K.SLOTS if s != "team"] + ["fur"]
    names += sorted(set(r["slot"] for r in rules) - set(names))      # (a slot of a Warden's own: Ostra's void)
    mats = slot_materials(img, names, tag)
    ob.data.materials.clear()
    order = list(mats)
    for sl in order:
        ob.data.materials.append(mats[sl])
    inf = float("inf")
    slot = []
    area = []
    for p in ob.data.polygons:
        u = sum(uv[i].uv.x for i in p.loop_indices) / p.loop_total
        v = sum(uv[i].uv.y for i in p.loop_indices) / p.loop_total
        c = px[min(h - 1, max(0, int(v * h))), min(w - 1, max(0, int(u * w))), :3]
        cen = p.center
        got = default
        if c[0] >= glow_min[0] and c[1] >= glow_min[1] and c[2] <= glow_min[2]:
            got = "glow"
        else:
            hh, ss, vv = _hsv(c)
            for r in rules:
                b = [(-inf if x is None else x) if i % 2 == 0 else (inf if x is None else x)
                     for i, x in enumerate(r.get("box") or [None] * 6)]
                x = abs(cen.x) if r.get("absx") else cen.x
                if not (b[0] <= x <= b[1] and b[2] <= cen.y <= b[3] and b[4] <= cen.z <= b[5]):
                    continue
                if r.get("circle") and not _in_ellipse(cen.x, cen.z, r["circle"]):
                    continue                    # (a round part seen from the front: the eye plate)
                q = r.get("hsv")
                if q:
                    q = [(0.0, 1.0)[i % 2] if x is None else x for i, x in enumerate(q)]
                    hue_ok = q[0] <= hh <= q[1] if q[0] <= q[1] else (hh >= q[0] or hh <= q[1])
                    if not (hue_ok and q[2] <= ss <= q[3] and q[4] <= vv <= q[5]):
                        continue
                got = r["slot"]
                break
        slot.append(got)
        area.append(p.area)
    if vote != "island":
        slot = _neighbour_vote(ob, slot, area, int(vote))
        counts = {}
        for p, sl in zip(ob.data.polygons, slot):
            p.material_index = order.index(sl)
            counts[sl] = counts.get(sl, 0) + 1
        log("slots by rule (%s, neighbour vote x%d):" % (tag, int(vote)), counts)
        return None
    isl = _face_islands(ob)
    votes = {}
    for i, (sl, a) in enumerate(zip(slot, area)):
        d = votes.setdefault(int(isl[i]), {})
        d[sl] = d.get(sl, 0.0) + a
    counts = {}
    for i, p in enumerate(ob.data.polygons):
        d = votes[int(isl[i])]
        sl = slot[i] if slot[i] == "glow" and d.get("glow", 0.0) > 0.25 * sum(d.values()) else max(d, key=d.get)
        p.material_index = order.index(sl)
        counts[sl] = counts.get(sl, 0) + 1
    log("slots by rule (%s, %d islands):" % (tag, int(isl.max()) + 1), counts)
    return {k: max(d, key=d.get) for k, d in votes.items()}


def _neighbour_vote(ob, slot, area, iterations):
    """A mode filter on the faces: each takes the slot with the most area among itself and its edge neighbours,
    `iterations` times (a lone face or a thin run of faces joins what surrounds it); glow stays where it is."""
    names = sorted(set(slot))
    lab = np.array([names.index(x) for x in slot])
    ar = np.array(area)
    glow = lab == names.index("glow") if "glow" in names else np.zeros(len(lab), bool)
    pairs = np.array([e for e in _face_pairs(ob)], dtype=np.int64).reshape(-1, 2)
    for _i in range(iterations):
        votes = np.zeros((len(lab), len(names)))
        votes[np.arange(len(lab)), lab] += ar
        np.add.at(votes, (pairs[:, 0], lab[pairs[:, 1]]), ar[pairs[:, 1]])
        np.add.at(votes, (pairs[:, 1], lab[pairs[:, 0]]), ar[pairs[:, 0]])
        if "glow" in names:
            votes[:, names.index("glow")] = -1.0
        lab = np.where(glow, lab, votes.argmax(axis=1))
    return [names[i] for i in lab]


def _face_pairs(ob):
    """The faces sharing each edge, as (face, face) pairs."""
    by_edge = {}
    for p in ob.data.polygons:
        for k in p.edge_keys:
            by_edge.setdefault(k, []).append(p.index)
    for fs in by_edge.values():
        if len(fs) == 2:
            yield fs


def project(ob, img, pj):
    """Paints one of the art's views straight onto the faces turned toward it inside a box (the face and beret
    from the front, the sigil plate from the side): Meshy's own texture there is softer than the art.
    Orthographic, in the Meshy frame (front = -Y): pj["view"] "front" maps x to the sheet's columns, "side"
    (her left side, facing the sheet's left) maps y; z to the rows. pj: image, box [a0, a1, z0, z1] on the
    mapped axis and z, facing (the least turned normal kept), col0 (a column near the part) and head_z (the
    height whose silhouette lines the columns up), sole_row (the ground line).
    Options for a face from a portrait (Face rules, PIPELINE.md):
    - warp {"mesh": [[a, z], ...], "art": [[col, row], ...], "smooth"}: a thin-plate spline through landmarks
      (the eyes, brows, nose, mouth corners, chin) instead of the one scale and offset, so a portrait drawn with
      its own tilt and proportions lands on the mesh's features;
    - feather [f0, f1]: the art blends in from facing f0 to full at f1 (no hard edge where faces turn away);
    - mask {"skin": hsv, "box": [c0, r0, c1, r1], "close", "erode", "blur"} (art pixels): the art is taken only
      inside its own face, eroded past its ink outline (a projected contour line is the jaw "seam"), blurred
      into a soft edge;
    - slots [names]: only faces of these toon slots; exclude_circles [[a, z, r]]: never inside these (the eye
      plate); skip_art: one [h0, h1, sat_min, val_max] or a list; skip_art_box [[c0, r0, c1, r1]]: art pixels
      never taken (the portrait's plate and its bracket)."""
    view = pj.get("view", "front")
    side = view == "side"
    ax = 1 if side else 0
    # side: +1 her left side (normals +x, front to the sheet's left), -1 her right; back: her right on the right
    sgn = float(pj.get("sign", 1.0)) if side else (-1.0 if view == "back" else 1.0)
    art = bpy.data.images.load(os.path.expanduser(pj["image"]))
    aw, ah = art.size
    src = np.array(art.pixels[:], dtype=np.float32).reshape(ah, aw, 4)
    w, h = img.size
    dst = np.array(img.pixels[:], dtype=np.float32).reshape(h, w, 4)
    me = ob.data
    me.calc_loop_triangles()
    uv = me.uv_layers.active.data
    x0, x1, z0, z1 = pj["box"]
    warp = None
    if "warp" in pj:
        warp = _tps_fit(pj["warp"]["mesh"], pj["warp"]["art"], float(pj["warp"].get("smooth", 1e-3)))
        vco = np.array([v.co[:] for v in me.vertices])
        vcr = warp(np.stack([vco[:, ax], vco[:, 2]], axis=1))
        res = warp(np.array(pj["warp"]["mesh"], float)) - np.array(pj["warp"]["art"], float)
        log("warp: %d landmarks, residual %.2f px max" % (len(res), float(np.abs(res).max())))
    elif "k" in pj:
        # (a registration measured on the mesh's own render, tools: the figure-height guess can be cm off)
        k, col0, row0 = float(pj["k"]), float(pj["col0_at"]), float(pj["row0_at"])
    else:
        k, col0, row0 = _register(me, src, pj, ax, sgn, pj.get("register_on"))
    keep = pj.get("keep_hue")        # [h0, h1, sat_min]: texels already painted this colour keep it (hair)
    # skip_art [h0, h1, sat_min, val_max] (or a list of them): art pixels of this colour are not projected
    skips = pj.get("skip_art") or []
    if skips and not isinstance(skips[0], (list, tuple)):
        skips = [skips]
    mask = _art_mask(src, pj["mask"]) if "mask" in pj else None
    line = pj.get("line")
    lcol = np.array(K.hexcol(line["colour"]), np.float32) if line else None
    if pj.get("inpaint"):
        # the art's own hair across the face and the plate's bracket filled from the skin around them (skipping
        # them left patches of the old paint inside the new face); "outside": past the face's eroded outline too,
        # fading to the skin's mid tone, so the art's edge never lands on the cheek (the jaw seam) and the blend
        # into the body's skin happens under the hair; then nothing is skipped and only the box's edge fades
        out = mask < 0.5 if (pj["inpaint"] == "outside" and mask is not None) else None
        src = _inpaint_art(src, pj["mask"]["box"], skips, pj.get("skip_art_box") or [], out, int(pj.get("hole_open", 0)),
                           pj.get("skip_art_poly"), int(pj.get("poly_grow", 6)))
        skips = []
        if out is not None:
            mask = _box_fade(src.shape[:2], pj["mask"]["box"], int(pj["mask"].get("edge", 24)))
    feather = pj.get("feather")
    f_min = float(feather[0]) if feather else float(pj["facing"])
    slots = pj.get("slots")
    names = [m.name for m in me.materials]
    circles = pj.get("exclude_circles") or []
    bg = src[ah - 1 - 5, 5, :3]
    painted = 0
    for t in me.loop_triangles:
        n = t.normal
        facing = n.x * sgn if side else (n.y if view == "back" else -n.y)
        if facing < f_min:
            continue
        if slots and not any(names[t.material_index].startswith(sl + "-") for sl in slots):
            continue
        ps = [me.vertices[i].co for i in t.vertices]
        fe = float(pj.get("box_feather", 0.0))
        if fe > 0.0:
            # (box_feather m: a triangle reaching into the box paints, faded by its distance from the box's edge;
            # no stepped edge where whole triangles stopped: Hem's mask at 3/4)
            if not any(x0 - fe <= p[ax] <= x1 + fe and z0 - fe <= p.z <= z1 + fe for p in ps):
                continue
        elif not all(x0 <= p[ax] <= x1 and z0 <= p.z <= z1 for p in ps):
            continue
        ca, cz = sum(p[ax] for p in ps) / 3.0, sum(p.z for p in ps) / 3.0
        if any(_in_ellipse(ca, cz, c) for c in circles):
            continue
        wf = 1.0
        if feather:
            f = min(1.0, max(0.0, (facing - feather[0]) / max(feather[1] - feather[0], 1e-6)))
            wf = f * f * (3.0 - 2.0 * f)
        uvs = np.array([[uv[li].uv.x * w, uv[li].uv.y * h] for li in t.loops])
        if warp is not None:
            cr = vcr[list(t.vertices)]
        else:
            cr = np.array([[col0 + sgn * p[ax] / k, row0 - p.z / k] for p in ps])
        lo = np.floor(uvs.min(axis=0)).astype(int)
        hi = np.ceil(uvs.max(axis=0)).astype(int)
        xs, ys = np.meshgrid(np.arange(lo[0], hi[0] + 1), np.arange(lo[1], hi[1] + 1))
        pts = np.stack([xs.ravel() + 0.5, ys.ravel() + 0.5], axis=1)
        a, b, c = uvs
        d = (b[1] - c[1]) * (a[0] - c[0]) + (c[0] - b[0]) * (a[1] - c[1])
        if abs(d) < 1e-9:
            continue
        l1 = ((b[1] - c[1]) * (pts[:, 0] - c[0]) + (c[0] - b[0]) * (pts[:, 1] - c[1])) / d
        l2 = ((c[1] - a[1]) * (pts[:, 0] - c[0]) + (a[0] - c[0]) * (pts[:, 1] - c[1])) / d
        l3 = 1 - l1 - l2
        inside = (l1 >= -0.01) & (l2 >= -0.01) & (l3 >= -0.01)
        if not inside.any():
            continue
        q = np.outer(l1[inside], cr[0]) + np.outer(l2[inside], cr[1]) + np.outer(l3[inside], cr[2])
        col = np.clip(q[:, 0].astype(int), 0, aw - 1)
        row = np.clip(q[:, 1].astype(int), 0, ah - 1)
        tx = np.clip(pts[inside, 0].astype(int), 0, w - 1)
        ty = np.clip(pts[inside, 1].astype(int), 0, h - 1)
        if line:
            # (crisp lines: the art sampled bilinearly, its "greenness" thresholded, painted one flat colour; the
            # skin around them is left as it is, so the lines sit on clean skin)
            fx, fy = np.clip(q[:, 0] - 0.5, 0, aw - 1.001), np.clip(q[:, 1] - 0.5, 0, ah - 1.001)
            x0_, y0_ = fx.astype(int), fy.astype(int)
            ax_, ay_ = (fx - x0_)[:, None], (fy - y0_)[:, None]
            b = lambda yy, xx: src[ah - 1 - yy, xx, :3]
            smp = (b(y0_, x0_) * (1 - ax_) + b(y0_, x0_ + 1) * ax_) * (1 - ay_) + \
                (b(y0_ + 1, x0_) * (1 - ax_) + b(y0_ + 1, x0_ + 1) * ax_) * ay_
            score = smp[:, 1] - np.maximum(smp[:, 0], smp[:, 2])
            # (`max`: brighter greens are a trim, not a tattoo: Vex's crop-top piping beside her chest circuits)
            on = (score > float(line.get("threshold", 0.12))) & (score < float(line.get("max", 9.0)))
            if on.any():
                dst[ty[on], tx[on], :3] = lcol
                painted += 1
            continue
        got = src[ah - 1 - row, col]
        art_px = np.abs(got[:, :3] - bg).sum(axis=1) > 0.12               # (the sheet's grey keeps Meshy's paint)
        if skips:
            # (art pixels of these colours stay off: the hair's shadows, the portrait's own hair and brass)
            ha, sa, va = _hsv_px(got[:, :3])
            for sk in skips:
                art_px &= ~((ha >= sk[0]) & (ha <= sk[1]) & (sa >= sk[2]) & (va <= sk[3]) &
                            (va >= (sk[4] if len(sk) > 4 else 0.0)))
        for bx in ([] if pj.get("inpaint") else pj.get("skip_art_box") or []):
            art_px &= ~((col >= bx[0]) & (col <= bx[2]) & (row >= bx[1]) & (row <= bx[3]))
        if pj.get("only_art"):
            # (only art pixels of these colours go on: the mask's violet mouth, eyes, tear and crack over Meshy's
            # porcelain, which keeps its own paint)
            ha, sa, va = _hsv_px(got[:, :3])
            oa = pj["only_art"]
            hue_ok = (ha >= oa[0]) & (ha <= oa[1]) if oa[0] <= oa[1] else (ha >= oa[0]) | (ha <= oa[1])
            art_px &= hue_ok & (sa >= oa[2]) & (sa <= oa[3]) & (va >= oa[4]) & (va <= oa[5])
        if keep:
            cur = dst[ty, tx, :3]
            hh, ss, _vv = _hsv_px(cur)
            art_px &= ~((hh >= keep[0]) & (hh <= keep[1]) & (ss >= keep[2]))
        wt = np.full(len(col), wf, np.float32)
        if mask is not None:
            wt *= mask[row, col]
        if fe > 0.0:
            pv = np.array([p[:] for p in ps])
            wp = np.outer(l1[inside], pv[0]) + np.outer(l2[inside], pv[1]) + np.outer(l3[inside], pv[2])
            dd = np.minimum.reduce([wp[:, ax] - x0, x1 - wp[:, ax], wp[:, 2] - z0, z1 - wp[:, 2]])
            eb = np.clip(dd / fe, 0.0, 1.0)
            wt *= (eb * eb * (3 - 2 * eb)).astype(np.float32)
        art_px &= wt > 1e-3
        if not art_px.any():
            continue
        wv = wt[art_px][:, None]
        cur = dst[ty[art_px], tx[art_px], :3]
        dst[ty[art_px], tx[art_px], :3] = cur * (1.0 - wv) + got[art_px, :3] * wv
        painted += 1
    img.pixels = dst.ravel()
    log("projected the art onto %d faces" % painted)


def _in_polys(shape, polys, r0=0, c0=0):
    """(h, w bool) pixels inside any polygon [[col, row], ...] (even-odd rule), for a region at (r0, c0)."""
    hh, ww = shape
    yy, xx = np.mgrid[r0:r0 + hh, c0:c0 + ww]
    xx = xx + 0.5
    yy = yy + 0.5
    out = np.zeros(shape, bool)
    for poly in polys:
        q = np.asarray(poly, float)
        inside = np.zeros(shape, bool)
        for (x1, y1), (x2, y2) in zip(q, np.roll(q, -1, axis=0)):
            if y1 == y2:
                continue
            cross = ((y1 > yy) != (y2 > yy)) & (xx < x1 + (yy - y1) * (x2 - x1) / (y2 - y1))
            inside ^= cross
        out |= inside
    return out


def _inpaint_art(src, box, skips, boxes, outside=None, hole_open=0, polys=None, poly_grow=0):
    """The art (Blender rows, bottom up) with its pixels of the skip colours inside box [c0, r0, c1, r1] (rows top
    down), and inside the skip boxes, filled from the pixels around them: grown in from the edges (each hole
    pixel the mean of its filled neighbours), then smoothed inside the holes. outside (rows top down, the whole
    art): pixels to fill as well; there the fill fades to the kept pixels' mid tone with its distance (a long
    grown fill streaks)."""
    ah, aw = src.shape[:2]
    out = src.copy()
    td = out[::-1]                                          # (a view: rows top down)
    c0, r0, c1, r1 = box
    reg = td[r0:r1, c0:c1, :3].copy()
    hue, sat, val = _hsv_px(reg)
    hole = np.zeros(reg.shape[:2], bool)
    for sk in skips:
        hole |= (hue >= sk[0]) & (hue <= sk[1]) & (sat >= sk[2]) & (val <= sk[3]) & (val >= (sk[4] if len(sk) > 4 else 0.0))
    if hole_open > 0:
        # (an opening: the hair's strands are thick, the circuit lines, dots and trims of the same hue thin)
        full = (2 * hole_open + 1) ** 2
        core = _box_sum(hole.astype(np.float64), hole_open) > full - 0.5
        hole = _box_sum(core.astype(np.float64), hole_open + 5) > 0.5
    for bx in boxes:
        hole[max(0, bx[1] - r0):max(0, bx[3] - r0), max(0, bx[0] - c0):max(0, bx[2] - c0)] = True
    if polys:
        # (parts of the art left out by outline: Vex's jaw panels, a faint line at the model's scale)
        pm = _in_polys(hole.shape, polys, r0, c0)
        if poly_grow > 0:
            pm = _box_sum(pm.astype(np.float64), poly_grow) > 0.5
        hole |= pm
    if outside is not None:
        hole |= outside[r0:r1, c0:c1]
    known = ~hole
    keep = reg[known]
    lum = keep @ np.array([0.3, 0.59, 0.11], np.float32)
    mid_sel = (lum >= np.percentile(lum, 35)) & (lum <= np.percentile(lum, 75))
    mid = np.median(keep[mid_sel], axis=0) if mid_sel.any() else keep.mean(axis=0)
    dist = np.zeros(hole.shape, np.float32)
    acc_rgb = reg
    for _it in range(600):
        if known.all():
            break
        acc = np.zeros_like(acc_rgb)
        cnt = np.zeros(known.shape + (1,), np.float32)
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            k = np.roll(np.roll(known, dy, 0), dx, 1)
            acc += np.roll(np.roll(acc_rgb, dy, 0), dx, 1) * k[..., None]
            cnt += k[..., None]
        grow = ~known & (cnt[..., 0] > 0)
        if not grow.any():
            break
        acc_rgb[grow] = acc[grow] / cnt[grow]
        dist[grow] = _it + 1
        known |= grow
    if outside is not None:
        f = np.exp(-dist / 14.0)[..., None]
        acc_rgb[hole] = (acc_rgb * f + mid[None, None] * (1.0 - f))[hole]
    for _it in range(10 if outside is not None else 6):
        b = acc_rgb.copy()
        for ax_ in (0, 1):                  # (a separable 7-px box, twice over: no streaks left)
            b = sum(np.roll(b, k, ax_) for k in range(-3, 4)) / 7.0
        acc_rgb[hole] = b[hole]
    td[r0:r1, c0:c1, :3] = acc_rgb
    log("art inpainted: %d pixels" % int(hole.sum()))
    return out


def _in_ellipse(a, z, c):
    """Inside a circle [a, z, r] or an ellipse [a, z, ra, rz] (an eye plate taller than it is wide)."""
    ra, rz = (c[2], c[2]) if len(c) < 4 else (c[2], c[3])
    return ((a - c[0]) / ra) ** 2 + ((z - c[1]) / rz) ** 2 <= 1.0


def _box_fade(shape, box, edge):
    """0..1 over the art (rows top down): 1 inside box [c0, r0, c1, r1], fading to 0 over `edge` px at its sides."""
    hh, ww = shape
    c0, r0, c1, r1 = box
    yy, xx = np.mgrid[0:hh, 0:ww]
    d = np.minimum.reduce([xx - c0, c1 - xx, yy - r0, r1 - yy]).astype(np.float32)
    f = np.clip(d / max(edge, 1), 0.0, 1.0)
    return (f * f * (3.0 - 2.0 * f)).astype(np.float32)


def _tps_fit(src, dst, smooth):
    """A thin-plate spline from src points (n x 2) to dst (n x 2) with `smooth` regularisation (landmarks read
    off renders are a few pixels off; an exact fit would wiggle): returns f(points m x 2) -> m x 2."""
    src = np.asarray(src, float)
    dst = np.asarray(dst, float)
    mu = src.mean(axis=0)
    sd = float(src.std(axis=0).mean()) or 1.0
    s = (src - mu) / sd
    n = len(s)

    def kern(d2):
        return np.where(d2 > 1e-12, 0.5 * d2 * np.log(np.maximum(d2, 1e-12)), 0.0)      # r^2 log r
    a = np.zeros((n + 3, n + 3))
    a[:n, :n] = kern(((s[:, None] - s[None]) ** 2).sum(-1)) + smooth * np.eye(n)
    pm = np.hstack([np.ones((n, 1)), s])
    a[:n, n:] = pm
    a[n:, :n] = pm.T
    rhs = np.zeros((n + 3, 2))
    rhs[:n] = dst
    coef = np.linalg.solve(a, rhs)

    def f(p):
        q = (np.asarray(p, float) - mu) / sd
        out = np.empty((len(q), 2))
        for i0 in range(0, len(q), 20000):
            qq = q[i0:i0 + 20000]
            out[i0:i0 + 20000] = kern(((qq[:, None] - s[None]) ** 2).sum(-1)) @ coef[:n] + \
                np.hstack([np.ones((len(qq), 1)), qq]) @ coef[n:]
        return out
    return f


def _box_sum(m, r):
    """The sum over a (2r+1)^2 box around every pixel (zeros outside), by an integral image."""
    hh, ww = m.shape
    ii = np.zeros((hh + 1, ww + 1))
    ii[1:, 1:] = np.cumsum(np.cumsum(m, axis=0), axis=1)
    y0 = np.clip(np.arange(hh) - r, 0, hh)
    y1 = np.clip(np.arange(hh) + r + 1, 0, hh)
    x0 = np.clip(np.arange(ww) - r, 0, ww)
    x1 = np.clip(np.arange(ww) + r + 1, 0, ww)
    return ii[y1][:, x1] - ii[y0][:, x1] - ii[y1][:, x0] + ii[y0][:, x0]


def _art_mask(src, mk):
    """Where the art's face may be taken from (rows top down, the art's own pixels): its skin, closed over the
    features it encloses (eyes, brows, lips), eroded past its ink outline, blurred into a 0..1 soft edge."""
    ah, aw = src.shape[:2]
    rgb = src[::-1, :, :3]
    hue, sat, val = _hsv_px(rgb)
    def in_range(q):
        hue_ok = (hue >= q[0]) & (hue <= q[1]) if q[0] <= q[1] else (hue >= q[0]) | (hue <= q[1])
        return hue_ok & (sat >= q[2]) & (sat <= q[3]) & (val >= q[4]) & (val <= q[5])
    if "exclude" in mk:
        # (everything but these: a face sheet whose plate and jaw panels belong to the face)
        m = np.ones((ah, aw), bool)
        for q in mk["exclude"]:
            m &= ~in_range(q)
    else:
        m = in_range(mk["skin"])
    c0, r0, c1, r1 = mk["box"]
    box = np.zeros((ah, aw), bool)
    box[r0:r1, c0:c1] = True
    m = (m & box).astype(np.float64)
    full = lambda r: (2 * r + 1) ** 2
    rc, re, rb = int(mk.get("close", 24)), int(mk.get("erode", 6)), int(mk.get("blur", 10))
    m = (_box_sum(m, rc) > 0.5).astype(np.float64)                       # close: dilate ...
    m = (_box_sum(m, rc) > full(rc) - 0.5).astype(np.float64)            # ... then erode
    m = (_box_sum(m, re) > full(re) - 0.5).astype(np.float64)            # past the outline
    m = _box_sum(m, rb) / full(rb)
    m = _box_sum(m, rb) / full(rb)                                       # (two box blurs: a soft edge)
    log("art mask: %.0f%% of its box" % (100.0 * (m > 0.5).sum() / max(box.sum(), 1)))
    return m.astype(np.float32)


def _register(me, src, pj, ax, sgn=1.0, other=None):
    """Lines the mesh up with the art: the figure's full height (the art's first and last non-grey rows, the
    ground line left out, against the mesh's top and soles) gives the scale and rows; the head's middle at
    `head_z` (the art's run there against the mesh's) gives the columns."""
    ah, aw = src.shape[:2]
    img = src[::-1, :, :3]                                              # row 0 = top
    bg = img[5, 5]
    fg = np.abs(img - bg).sum(axis=2) > 0.12
    rows = np.nonzero(fg[:, : aw].sum(axis=1) > 3)[0]
    top = rows.min()
    bottom = int(pj.get("sole_row", rows.max()))
    co = np.array([v.co[:] for v in (other or me).vertices])     # (a head registers on the body it sits on)
    zt, zb = co[:, 2].max(), co[:, 2].min()
    k = (zt - zb) / (bottom - top)
    row0 = top + zt / k
    hz = float(pj["head_z"])
    band = co[np.abs(co[:, 2] - hz) < 0.01]
    x0, x1 = pj.get("head_box", pj["box"])[:2]
    band = band[(band[:, ax] > x0) & (band[:, ax] < x1)]
    mx = (band[:, ax].min() + band[:, ax].max()) * 0.5
    r = int(row0 - hz / k)
    guess = int(pj["col0"])
    cols = np.nonzero(fg[r])[0]
    run = cols[np.abs(cols - guess) < 90]
    ac = (run.min() + run.max()) * 0.5
    col0 = ac - sgn * mx / k
    log("registered the art: %.5f m/px, x = 0 at column %.1f, z = 0 at row %.1f" % (k, col0, row0))
    return k, col0, row0


def sheet_palette(path, n=18, seed=1):
    """The sheet's own flat colours: k-means over the figure's pixels (the grey ground left out)."""
    art = bpy.data.images.load(os.path.expanduser(path))
    aw, ah = art.size
    px = np.array(art.pixels[:], dtype=np.float32).reshape(-1, 4)[:, :3]
    bg = px[5 * aw + 5]
    fig = px[np.abs(px - bg).sum(axis=1) > 0.15]
    fig = fig[(fig.max(axis=1) > 0.12)]                     # (not the ink lines)
    rng = np.random.default_rng(seed)
    pts = fig[rng.choice(len(fig), min(30000, len(fig)), replace=False)]
    cent = pts[rng.choice(len(pts), n, replace=False)]
    for _it in range(12):
        lab = np.argmin(((pts[:, None] - cent[None]) ** 2).sum(axis=2), axis=1)
        for c in range(n):
            if (lab == c).any():
                cent[c] = pts[lab == c].mean(axis=0)
    return cent


def flatten(img, pal, snap, median=True, ids=None):
    """Toward the sheet's flat painted values: a 3x3 median takes out Meshy's grain and streaks, then each texel
    moves `snap` of the way to the nearest sheet colour (keeping its own light and shade)."""
    w, h = img.size
    px = np.array(img.pixels[:], dtype=np.float32).reshape(h, w, 4)
    rgb = px[..., :3]
    if median:
        pad = np.pad(rgb, ((1, 1), (1, 1), (0, 0)), mode="edge")
        out = np.empty_like(rgb)
        for y0 in range(0, h, 256):
            y1 = min(h, y0 + 256)
            stack = np.stack([pad[y0 + dy:y1 + dy, dx:dx + w] for dy in range(3) for dx in range(3)])
            out[y0:y1] = np.median(stack, axis=0)
        if ids is not None:
            # (only where the whole 3x3 is one island: the median never reads across a crumb's edge)
            ip = np.pad(ids, 1, mode="edge")
            same = np.ones((h, w), bool)
            for dy in range(3):
                for dx in range(3):
                    same &= ip[dy:dy + h, dx:dx + w] == ids
            out = np.where(same[..., None], out, rgb)
        rgb = out
    flat = rgb.reshape(-1, 3)
    near = np.empty_like(flat)
    for a in range(0, len(flat), 1 << 18):
        b = flat[a:a + (1 << 18)]
        idx = np.argmin(((b[:, None] - pal[None]) ** 2).sum(axis=2), axis=1)
        near[a:a + (1 << 18)] = pal[idx]
    # keep the texel's own value (light, shade) and take the sheet colour's hue and saturation
    lum = flat.mean(axis=1, keepdims=True)
    tone = near * (lum / np.maximum(near.mean(axis=1, keepdims=True), 1e-3))
    flat = flat * (1 - snap) + np.clip(tone, 0, 1) * snap
    px[..., :3] = flat.reshape(h, w, 3)
    img.pixels = px.ravel()


def repaint(img, rules):
    """Pulls the texels of one colour family onto the sheet's flat colour (the scarf's pale streaks and dark
    flecks): rule {hue: [h0, h1], sat_min, colour, k}; the texel keeps a little of its own value."""
    import colorsys  # noqa: F401  (vectorised below)
    w, h = img.size
    px = np.array(img.pixels[:], dtype=np.float32).reshape(-1, 4)
    rgb = px[:, :3]
    mx = rgb.max(axis=1)
    mn = rgb.min(axis=1)
    d = np.maximum(mx - mn, 1e-6)
    hue = np.where(mx == rgb[:, 0], ((rgb[:, 1] - rgb[:, 2]) / d) % 6,
                   np.where(mx == rgb[:, 1], (rgb[:, 2] - rgb[:, 0]) / d + 2, (rgb[:, 0] - rgb[:, 1]) / d + 4)) / 6
    sat = np.where(mx > 0, (mx - mn) / np.maximum(mx, 1e-6), 0)
    for r in rules:
        sel = (hue >= r["hue"][0]) & (hue <= r["hue"][1]) & (sat >= r["sat_min"]) & (mx >= r.get("val_min", 0.0))
        col = np.array(K.hexcol(r["colour"]), dtype=np.float32)
        val = (mx[sel] / max(col.max(), 1e-3)).clip(0.75, 1.15)[:, None]
        rgb[sel] = rgb[sel] * (1 - r["k"]) + np.clip(col * val, 0, 1) * r["k"]
        log("repaint %s: %d texels" % (r["colour"], int(sel.sum())))
    px[:, :3] = rgb
    img.pixels = px.ravel()


def paint_up(img, spec, snap=None, head=False, ids=None):
    """Meshy's albedo toward the sheet's painted look: lifted, flattened onto the sheet's palette."""
    if "palette_from" in spec:
        global _SHEET_PAL
        if _SHEET_PAL is None:
            _SHEET_PAL = sheet_palette(spec["palette_from"])
        flatten(img, _SHEET_PAL, spec.get("snap", 0.5) if snap is None else snap, ids=ids)
    lift(img, *spec["lift"])
    if spec.get("repaint") and not head:
        repaint(img, spec["repaint"])


_SHEET_PAL = None


def island_map(ob, img):
    """Which UV island each texel belongs to (-1: none). Meshy's layout is thousands of crumbs, so any filter or
    mipmap that reads across a crumb's edge mixes in an unrelated part's colour (v2's patchy facets): the
    paint-up filters within an island only, and pad() grows each island's colour into the gaps."""
    w, h = img.size
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    lay = bm.loops.layers.uv.active
    bm.faces.ensure_lookup_table()
    island = [-1] * len(bm.faces)
    n = 0
    for f in bm.faces:
        if island[f.index] >= 0:
            continue
        stack = [f]
        island[f.index] = n
        while stack:
            g = stack.pop()
            for lp in g.loops:
                e = lp.edge
                for other in e.link_faces:
                    if island[other.index] >= 0:
                        continue
                    lo = next(x for x in other.loops if x.edge == e)
                    # the same island only if the shared edge has the same UVs on both sides
                    a0, a1 = lp[lay].uv, lp.link_loop_next[lay].uv
                    b0, b1 = lo[lay].uv, lo.link_loop_next[lay].uv
                    if ((a0 - b1).length < 1e-5 and (a1 - b0).length < 1e-5) or \
                            ((a0 - b0).length < 1e-5 and (a1 - b1).length < 1e-5):
                        island[other.index] = n
                        stack.append(other)
        n += 1
    ids = np.full((h, w), -1, np.int32)
    for f in bm.faces:
        uvs = [lp[lay].uv for lp in f.loops]
        for k in range(1, len(uvs) - 1):
            _raster(ids, (uvs[0], uvs[k], uvs[k + 1]), island[f.index], w, h)
    bm.free()
    log("UV islands: %d, %.0f%% of the texture" % (n, 100.0 * (ids >= 0).mean()))
    return ids


def _raster(ids, tri, val, w, h):
    p = np.array([[t.x * w, t.y * h] for t in tri])
    lo = np.maximum(np.floor(p.min(axis=0)).astype(int) - 1, 0)
    hi = np.minimum(np.ceil(p.max(axis=0)).astype(int) + 1, [w - 1, h - 1])
    if (hi < lo).any():
        return
    xs, ys = np.meshgrid(np.arange(lo[0], hi[0] + 1), np.arange(lo[1], hi[1] + 1))
    q = np.stack([xs.ravel() + 0.5, ys.ravel() + 0.5], axis=1)
    a, b, c = p
    d = (b[1] - c[1]) * (a[0] - c[0]) + (c[0] - b[0]) * (a[1] - c[1])
    if abs(d) < 1e-12:
        return
    l1 = ((b[1] - c[1]) * (q[:, 0] - c[0]) + (c[0] - b[0]) * (q[:, 1] - c[1])) / d
    l2 = ((c[1] - a[1]) * (q[:, 0] - c[0]) + (a[0] - c[0]) * (q[:, 1] - c[1])) / d
    inside = (l1 >= -0.02) & (l2 >= -0.02) & (1 - l1 - l2 >= -0.02)
    ids[q[inside, 1].astype(int), q[inside, 0].astype(int)] = val


def pad(img, ids, steps):
    """Grows each island's edge colour `steps` texels into the empty gaps around it (mipmaps then fetch the
    island's own colour at its edge, not a neighbour's)."""
    w, h = img.size
    px = np.array(img.pixels[:], dtype=np.float32).reshape(h, w, 4)
    filled = ids >= 0
    for _s in range(steps):
        acc = np.zeros_like(px)
        cnt = np.zeros((h, w, 1), np.float32)
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            src = np.roll(np.roll(filled, dy, 0), dx, 1)
            acc += np.roll(np.roll(px, dy, 0), dx, 1) * src[..., None]
            cnt += src[..., None]
        grow = (~filled) & (cnt[..., 0] > 0)
        px[grow] = acc[grow] / cnt[grow]
        filled = filled | grow
    img.pixels = px.ravel()


def shrink(img, size):
    """The atlas down to size x size by whole-texel box averages (the bake runs at 4096 for a clean, supersampled
    result; the game gets 2048: 16 MB of VRAM per Warden uncompressed, a quarter of 4096's)."""
    w, h = img.size
    f = w // size
    if f <= 1:
        return
    px = np.array(img.pixels[:], dtype=np.float32).reshape(h // f, f, w // f, f, 4).mean(axis=(1, 3))
    img.scale(w // f, h // f)
    img.pixels = px.ravel()
    img.pack()
    log("atlas %d -> %d px" % (w, w // f))


def lift(img, gamma, gain, sat=1.0):
    """Meshy's albedo is a shade darker than the painted art and the toon shader darkens again: lift its values
    (a gamma and a gain on the stored colour) so the model reads as light as the turnaround in game, and its
    colours `sat` x as far from their grey (the art's orange and navy pop at the match camera)."""
    px = np.array(img.pixels[:], dtype=np.float32).reshape(-1, 4)
    rgb = np.power(px[:, :3], gamma) * gain
    grey = rgb.mean(axis=1, keepdims=True)
    px[:, :3] = np.clip(grey + (rgb - grey) * sat, 0.0, 1.0)
    img.pixels = px.ravel()
    img.pack()


def slot_materials(img, slots, tag):
    out = {}
    for s in slots:
        m = bpy.data.materials.new("%s-%s" % (s, tag))
        m.use_nodes = True
        bsdf = m.node_tree.nodes.get("Principled BSDF")
        tex = m.node_tree.nodes.new("ShaderNodeTexImage")
        tex.image = img
        m.node_tree.links.new(tex.outputs[0], bsdf.inputs["Base Color"])
        bsdf.inputs["Roughness"].default_value = 0.8
        bsdf.inputs["Metallic"].default_value = 0.0
        out[s] = m
    return out


def head_pass(body, spec):
    """Swaps the body's head for the head model (Meshy from the portrait and the profile): the body's head is cut
    above `cut_z` within `r` of the head's axis (the scarf below stays), the new head is scaled to the body's
    beret width, its beret top and middle put on the body's, its own neck cut at cut_z_head (and its shoulders beyond r_head), and joined."""
    hs = spec["head"]
    head = import_glb(os.path.expanduser(hs["glb"]))
    if hs.get("mirror"):
        # (the portrait draws the lens over her left eye; her block, the turnaround and the profile, her right)
        transform(head, Matrix.Diagonal((-1.0, 1.0, 1.0, 1.0)))
        bm = bmesh.new()
        bm.from_mesh(head.data)
        bmesh.ops.reverse_faces(bm, faces=bm.faces)
        bm.to_mesh(head.data)
        bm.free()
    img = base_image(head)
    paint_up(img, spec, hs.get("snap", 0.25), head=True)
    slot_split(head, img, spec["palette"], spec["glow_min"], "head")
    bco = np.array([v.co[:] for v in body.data.vertices])
    cut, r, ax = float(hs["cut_z"]), float(hs["r"]), Vector(hs["axis"])
    near = (np.hypot(bco[:, 0] - ax.x, bco[:, 1] - ax.y) < r)
    top = bco[near][:, 2].max()
    band = bco[near & (bco[:, 2] > top - float(hs["beret_h"]))]
    b_w = band[:, 0].max() - band[:, 0].min()
    b_mid = Vector((float((band[:, 0].max() + band[:, 0].min()) / 2), float((band[:, 1].max() + band[:, 1].min()) / 2), top))
    hco = np.array([v.co[:] for v in head.data.vertices])
    h_top = hco[:, 2].max()
    hb = hco[hco[:, 2] > h_top - float(hs["beret_h_head"])]
    k = b_w / (hb[:, 0].max() - hb[:, 0].min())
    h_mid = Vector((float((hb[:, 0].max() + hb[:, 0].min()) / 2), float((hb[:, 1].max() + hb[:, 1].min()) / 2), h_top))
    m = Matrix.Translation(b_mid) @ Matrix.Rotation(math.radians(hs.get("turn", 0.0)), 4, "Z") @ Matrix.Scale(k, 4) \
        @ Matrix.Translation(-h_mid)
    transform(head, m)
    for pj in hs.get("project", []):
        pj = dict(pj, register_on=body.data)
        project(head, img, pj)
    hcut, hr = float(hs.get("cut_z_head", cut)), float(hs.get("r_head", r))
    _cut(head, lambda co: co.z < hcut or math.hypot(co.x - b_mid.x, co.y - b_mid.y) > hr and co.z < b_mid.z - 0.12)
    _cut(body, lambda co: co.z > cut and math.hypot(co.x - ax.x, co.y - ax.y) < r)
    decimate(head, int(hs["tris"]))
    log("head pass: scale %.3f, cut at %.3f" % (k, cut))
    return head


def outward(ob):
    """Consistent outward winding: Meshy's triangles come wound either way (about 8% inward), which Blender's
    double-sided render hides but the game's back-face culling shows as dark triangle holes. A piece cut open
    (the gun-arm) can come out of the recalculation inside out: each part whose signed volume about its own
    middle is negative is turned over (the game culls its outside and draws the ink shell over it, black)."""
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    flipped = 0
    for part in _face_parts(bm):
        c = sum((v.co for f in part for v in f.verts), Vector()) / sum(len(f.verts) for f in part)
        vol = 0.0
        for f in part:
            p = [v.co - c for v in f.verts]
            for k in range(1, len(p) - 1):
                vol += p[0].dot(p[k].cross(p[k + 1]))
        if vol < 0.0:
            bmesh.ops.reverse_faces(bm, faces=part)
            flipped += 1
    bm.to_mesh(ob.data)
    bm.free()
    ob.data.update()
    if flipped:
        log("%s: %d inside-out parts turned over" % (ob.name, flipped))


def _face_parts(bm):
    seen = set()
    for f in bm.faces:
        if f.index in seen:
            continue
        part, stack = [], [f]
        seen.add(f.index)
        while stack:
            g = stack.pop()
            part.append(g)
            for e in g.edges:
                for o in e.link_faces:
                    if o.index not in seen:
                        seen.add(o.index)
                        stack.append(o)
        yield part


def cap_holes(ob, max_rim, flat=False):
    """Closes the openings a cut leaves (the stump the gun-arm came off, the gun's back end): the game's ink
    shell is drawn from the inside of a grown copy, so through an opening it shows as a black hole. Only
    openings whose rim is shorter than `max_rim` m: a long, twisted rim (where the cut ran along the ammo belt)
    made a cap that stood out as a dark slab. Each cap's corners take the UVs of the rim's own faces; flat:
    the whole cap takes one rim texel (a rim across several UV islands smeared unrelated paint over the cap)."""
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    lay = bm.loops.layers.uv.active
    rim = set(e for e in bm.edges if e.is_boundary)
    small = []
    while rim:
        loop, stack = [], [rim.pop()]
        while stack:
            e = stack.pop()
            loop.append(e)
            for v in e.verts:
                for o in v.link_edges:
                    if o in rim:
                        rim.discard(o)
                        stack.append(o)
        if sum(e.calc_length() for e in loop) <= max_rim:
            small.extend(loop)
    rim_uv = {v.index: v.link_loops[0][lay].uv.copy() for e in small for v in e.verts if v.link_loops}
    caps = bmesh.ops.holes_fill(bm, edges=small, sides=0)["faces"]
    for f in caps:
        one = next((rim_uv[lp.vert.index] for lp in f.loops if lp.vert.index in rim_uv), None) if flat else None
        for lp in f.loops:
            if one is not None:
                lp[lay].uv = one
            elif lp.vert.index in rim_uv:
                lp[lay].uv = rim_uv[lp.vert.index]
    bmesh.ops.triangulate(bm, faces=caps)
    bm.to_mesh(ob.data)
    bm.free()
    log("%s: %d openings capped" % (ob.name, len(caps)))


def soft_normals(ob, iterations):
    """Meshy's surface is lumpy at this density, and the toon shader's light/shadow split shows every lump as a
    facet: the shading normals are the vertex normals averaged with their neighbours' `iterations` times (the
    shape itself stays). Each neighbour counts by how much it faces the same way (squared): across a thin hair
    strand or a candle the two sides face apart and don't mix, so their normals never cancel or flip."""
    if iterations <= 0:
        return
    me = ob.data
    nv = len(me.vertices)
    nrm = np.array([v.normal[:] for v in me.vertices], dtype=np.float64)
    ed = np.array([e.vertices[:] for e in me.edges], dtype=np.int64)
    for _i in range(iterations):
        w = np.clip((nrm[ed[:, 0]] * nrm[ed[:, 1]]).sum(axis=1), 0.0, 1.0)[:, None] ** 2
        acc = nrm.copy()
        np.add.at(acc, ed[:, 0], nrm[ed[:, 1]] * w)
        np.add.at(acc, ed[:, 1], nrm[ed[:, 0]] * w)
        nrm = acc / np.maximum(np.linalg.norm(acc, axis=1, keepdims=True), 1e-9)
    me.normals_split_custom_set_from_vertices([tuple(x) for x in nrm[:nv]])


def ink_room(ob, full):
    """How far the game's ink shell may grow out of each vertex without poking through the model: half the
    room along its shading normal, inward (a hair strand's, a frayed hem's or a candle's thickness) or outward
    (a fold or the gap to the next part), as a fraction of `full` m in the vertex colour's alpha (Godot's
    outline shader with ink_mask: thin and folded parts get a thin line instead of a ragged black fringe; the
    colour stays white, and an opaque glTF material ignores the alpha, so other viewers show the atlas as is)."""
    from mathutils.bvhtree import BVHTree
    me = ob.data
    tree = BVHTree.FromPolygons([v.co.copy() for v in me.vertices], [p.vertices[:] for p in me.polygons])
    nrm = np.zeros((len(me.vertices), 3))
    for lp in me.loops:
        nrm[lp.vertex_index] += lp.normal[:]
    nrm /= np.maximum(np.linalg.norm(nrm, axis=1, keepdims=True), 1e-9)
    room = np.empty(len(me.vertices), np.float32)
    for v in me.vertices:
        n = Vector(nrm[v.index])
        best = full * 2.0
        for d in (n, -n):
            hit = tree.ray_cast(v.co + d * 1e-4, d, best)
            if hit[0] is not None:
                best = min(best, hit[3])
        room[v.index] = min(1.0, best * 0.5 / full)
    attr = me.color_attributes.new("ink", "FLOAT_COLOR", "POINT")
    col = np.ones((len(me.vertices), 4), np.float32)
    col[:, 3] = room
    attr.data.foreach_set("color", col.ravel())
    me.color_attributes.active_color = attr
    log("%s: ink room, %d%% of vertices with less than a full line" % (ob.name, int(100 * (room < 0.999).mean())))


def rigid(ob, arm, bone):
    """A piece that rides one bone whole (the head pass: bone heat can't solve it joined to the body)."""
    g = ob.vertex_groups.get(bone) or ob.vertex_groups.new(name=bone)
    g.add(list(range(len(ob.data.vertices))), 1.0, "REPLACE")
    ob.parent = arm
    mod = ob.modifiers.new("Armature", "ARMATURE")
    mod.object = arm


def join(a, b):
    bpy.ops.object.select_all(action="DESELECT")
    a.select_set(True)
    b.select_set(True)
    bpy.context.view_layer.objects.active = a
    bpy.ops.object.join()
    return a


def _cut_lens(ob, ls):
    """The scan's own lens under the geometry one (lens()): faces within cut_r of its axis and in front of
    `cut_back` m behind its centre go (Meshy's lens came out with a spike)."""
    c, n = Vector(ls["centre"]), Vector(ls["normal"]).normalized()
    r, back = float(ls["cut_r"]), float(ls.get("cut_back", 0.004))

    def drop(co):
        d = co - c
        a = d.dot(n)
        return a > -back and (d - n * a).length < r
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    gone = [f for f in bm.faces if all(drop(v.co) for v in f.verts) or drop(f.calc_center_median())]
    bmesh.ops.delete(bm, geom=gone, context="FACES")
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    bm.to_mesh(ob.data)
    bm.free()
    log("lens cut: %d faces" % len(gone))


def _cut(ob, drop):
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if drop(v.co)], context="VERTS")
    bm.to_mesh(ob.data)
    bm.free()


def weight_rules(ob, img, rules):
    """Pieces bone heat gives to the wrong bone where two parts touch in Meshy's pose: every
    vertex inside a rule's box (the fitted frame: her right +X, front +Y, soles on 0) whose painted colour
    matches one of its hsv ranges [h0, h1, s0, s1, v0, v1] (all colours without) and, with `slots`, is on a face
    of one of those toon slots, goes wholly to the rule's bone (Vex's ammo drum on her back went with the gun-arm and rose over her shoulder blades)."""
    w, h = img.size
    px = np.array(img.pixels[:], dtype=np.float32).reshape(h, w, 4)
    uv = ob.data.uv_layers.active.data
    col = np.zeros((len(ob.data.vertices), 3))
    cnt = np.zeros(len(ob.data.vertices))
    for lp in ob.data.loops:
        u, v = uv[lp.index].uv
        col[lp.vertex_index] += px[min(h - 1, max(0, int(v * h))), min(w - 1, max(0, int(u * w))), :3]
        cnt[lp.vertex_index] += 1
    col /= np.maximum(cnt, 1)[:, None]
    vslots = [set() for _ in ob.data.vertices]
    for p in ob.data.polygons:
        m = ob.data.materials[p.material_index] if p.material_index < len(ob.data.materials) else None
        for i in p.vertices:
            vslots[i].add(m.name.split("-")[0] if m else "")
    for r in rules:
        b = r["box"]
        g = ob.vertex_groups.get(r["bone"]) or ob.vertex_groups.new(name=r["bone"])
        moved = 0
        for vx in ob.data.vertices:
            c = vx.co
            if not (b[0] <= c.x <= b[1] and b[2] <= c.y <= b[3] and b[4] <= c.z <= b[5]):
                continue
            if r.get("slots") and not vslots[vx.index] & set(r["slots"]):
                continue
            hh, ss, vv = _hsv(col[vx.index])
            if "hsv" in r and not any(q[0] <= hh <= q[1] and q[2] <= ss <= q[3] and q[4] <= vv <= q[5] for q in r["hsv"]):
                continue
            for x in vx.groups:
                ob.vertex_groups[x.group].add([vx.index], 0.0, "REPLACE")
            g.add([vx.index], 1.0, "REPLACE")
            moved += 1
        log("weight rule %s: %d vertices" % (r["bone"], moved))


def release(ob, bones, to="hips"):
    """The weights of bones whose geometry left the body (a gun-arm's forearm and hand: the weapon now) go to
    `to`: the ammo belt that fed Vex's gun stayed on her forearm and was dragged across her back whenever the
    arm moved (handed to the upper arm instead, it still was)."""
    idx = [ob.vertex_groups[b].index for b in bones if b in ob.vertex_groups]
    if not idx:
        return
    dest = ob.vertex_groups.get(to) or ob.vertex_groups.new(name=to)
    moved = 0
    for v in ob.data.vertices:
        gone = sum(g.weight for g in v.groups if g.group in idx)
        if gone <= 0.0:
            continue
        have = next((g.weight for g in v.groups if g.group == dest.index), 0.0)
        for i in idx:
            ob.vertex_groups[i].remove([v.index])
        dest.add([v.index], have + gone, "REPLACE")
        moved += 1
    log("released %s to %s: %d vertices" % (", ".join(bones), to, moved))


def arm_reach(ob, rig_arm, spec):
    """Coat that bone heat gave to a hanging arm (the rest pose: arms straight down) though it hangs away from
    it: every vertex riding mostly an arm chain, above the wrist and below `z_max`, farther than `r` from the
    line down the arm goes wholly to `to` (hips). Ostra's coat flap beside his orb arm rose with it as a spike."""
    names = {g.index: g.name for g in ob.vertex_groups}
    dest = ob.vertex_groups.get(spec.get("to", "hips")) or ob.vertex_groups.new(name=spec.get("to", "hips"))
    r, zmax = float(spec.get("r", 0.075)), float(spec.get("z_max", 1.2))
    moved = 0
    for sd in ("R", "L"):
        bones = ("upper_arm." + sd, "forearm." + sd, "hand." + sd)
        top = np.array(rig_arm.data.bones[bones[0]].head_local[:])
        wrist = np.array(rig_arm.data.bones[bones[2]].head_local[:])
        ax = (wrist - top) / max(np.linalg.norm(wrist - top), 1e-9)
        for v in ob.data.vertices:
            tot = sum(g.weight for g in v.groups) or 1.0
            if sum(g.weight for g in v.groups if names.get(g.group) in bones) <= 0.5 * tot:
                continue
            co = np.array(v.co[:])
            if co[2] > zmax or co[2] < wrist[2]:
                continue
            d = co - top
            if np.linalg.norm(d - ax * d.dot(ax)) <= r:
                continue
            for g in list(v.groups):
                ob.vertex_groups[g.group].add([v.index], 0.0, "REPLACE")
            dest.add([v.index], 1.0, "REPLACE")
            moved += 1
    if spec.get("binarize"):
        # (below z_max a vertex rides an arm wholly or not at all: coat beside the hanging hand that bone heat gave
        # a third of its weight to the arm was dragged half way up with the raised orb hand, a long spike)
        split = 0
        for sd in ("R", "L"):
            bones = {"upper_arm." + sd, "forearm." + sd, "hand." + sd}
            for v in ob.data.vertices:
                if v.co.z > zmax:
                    continue
                gs = [(names.get(g.group), g.group, g.weight) for g in v.groups]
                a = sum(w for n, _i, w in gs if n in bones)
                tot = sum(w for _n, _i, w in gs) or 1.0
                if a <= 1e-4 or a >= tot - 1e-4:
                    continue
                keep_arm = a > 0.5 * tot
                rest = [(i, w) for n, i, w in gs if (n in bones) == keep_arm]
                sw = sum(w for _i, w in rest) or 1.0
                for _n, i, _w in gs:
                    ob.vertex_groups[i].add([v.index], 0.0, "REPLACE")
                for i, w in rest:
                    ob.vertex_groups[i].add([v.index], w / sw, "REPLACE")
                split += 1
        log("arm reach: %d vertices made wholly arm or wholly body below z %.2f" % (split, zmax))
    log("arm reach: %d vertices off the arms to %s" % (moved, dest.name))


def cut_straddle(ob, spec):
    """Cut the faces that join a hanging arm to the body below the shoulder (`z_max`, the rest pose): Meshy fused
    Ostra's sleeves and gloves to the coat beside them, and with the orb hand raised those faces stretched into a
    sheet from his hip to his hand. A face goes when its vertices ride mostly different chains (an arm's
    upper_arm/forearm/hand against the rest)."""
    names = {g.index: g.name for g in ob.vertex_groups}
    arms = {"R": ("upper_arm.R", "forearm.R", "hand.R"), "L": ("upper_arm.L", "forearm.L", "hand.L")}

    def chain(v):
        s = sum(g.weight for g in v.groups) or 1.0
        for k, bones in arms.items():
            if sum(g.weight for g in v.groups if names.get(g.group) in bones) > 0.5 * s:
                return k
        return "B"
    ch = [chain(v) for v in ob.data.vertices]
    zmax = float(spec.get("z_max", 1.2))
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    bm.faces.ensure_lookup_table()
    cut = [f for f in bm.faces if f.calc_center_median().z < zmax and len({ch[v.index] for v in f.verts}) > 1]
    bmesh.ops.delete(bm, geom=cut, context="FACES")
    # (and the slivers the cut leaves hanging: small islands below the shoulder)
    small = int(spec.get("min_island", 0))
    dropped = 0
    if small:
        bm.faces.ensure_lookup_table()
        seen = set()
        gone = []
        for f0 in bm.faces:
            if f0.index in seen:
                continue
            isl, stack = [], [f0]
            seen.add(f0.index)
            while stack:
                f = stack.pop()
                isl.append(f)
                for e in f.edges:
                    for g in e.link_faces:
                        if g.index not in seen:
                            seen.add(g.index)
                            stack.append(g)
            if len(isl) < small and all(f.calc_center_median().z < zmax for f in isl):
                gone += isl
        dropped = len(gone)
        bmesh.ops.delete(bm, geom=gone, context="FACES")
        bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    bm.to_mesh(ob.data)
    bm.free()
    log("cut straddle: %d faces between the arms and the body below z %.2f, %d sliver faces" % (len(cut), zmax, dropped))


def keep_weights(ob):
    """The fit's weights (bone heat on the A-pose, arms clear of the body) kept as point attributes "w_<bone>"
    through the pose and the decimation: on the contract's rest pose the hanging arms touch the hips, and bone
    heat there hands the flank to the upper arm (a skin flap from elbow to knee whenever the arm lifts)."""
    groups = {g.index: g.name for g in ob.vertex_groups}
    n = len(ob.data.vertices)
    w = {name: np.zeros(n, np.float32) for name in groups.values()}
    for v in ob.data.vertices:
        for x in v.groups:
            w[groups[x.group]][v.index] = x.weight
    for name, arr in w.items():
        a = ob.data.attributes.new("w_" + name, "FLOAT", "POINT")
        a.data.foreach_set("value", arr)


def fit_weights(ob, arm):
    """The contract skin from the kept fit weights (keep_weights), normalised; bones the fit has no group for
    (root, the pauldrons, skirt, tail) get none here."""
    names = [a.name[2:] for a in ob.data.attributes if a.name.startswith("w_")]
    n = len(ob.data.vertices)
    ws = {}
    for nm in names:
        arr = np.empty(n, np.float32)
        ob.data.attributes["w_" + nm].data.foreach_get("value", arr)
        ws[nm] = np.clip(arr, 0.0, 1.0)
    tot = np.maximum(sum(ws.values()), 1e-6)
    ob.vertex_groups.clear()
    for nm, arr in ws.items():
        if arm.data.bones.get(nm) is None:
            continue
        g = ob.vertex_groups.new(name=nm)
        arr = arr / tot
        for i in np.nonzero(arr > 1e-3)[0]:
            g.add([int(i)], float(arr[i]), "REPLACE")
    _fill_weights(ob, arm)
    log("contract skin from the fit's weights: %d groups" % len(ob.vertex_groups))


def contract_skin(ob, rig):
    arm = K.build_armature(rig)
    for b in arm.data.bones:
        b.use_deform = b.name not in NO_DEFORM
    auto_weights(ob, arm)
    return arm


def weapon(spec, rig):
    w = import_glb(os.path.expanduser(spec["weapon_glb"]))
    co = np.array([v.co[:] for v in w.data.vertices])
    c = co.mean(axis=0)
    _u, _s, vt = np.linalg.svd(co - c, full_matrices=False)
    ax = Vector(vt[0])
    t = (co - c) @ vt[0]
    lo, hi = t.min(), t.max()
    # the barrel end is the slimmer one
    def spread(sel):
        q = co[sel] - c
        return np.linalg.norm(q - np.outer(q @ vt[0], vt[0]), axis=1).mean()
    end_lo = spread(t < lo + 0.1 * (hi - lo))
    end_hi = spread(t > hi - 0.1 * (hi - lo))
    if end_lo < end_hi:
        ax = -ax
        t = -t
        lo, hi = -hi, -lo
    # the strips hang down: the far side of the middle third points down
    mid = (t > lo + 0.33 * (hi - lo)) & (t < hi - 0.33 * (hi - lo))
    q = co[mid] - c
    perp = q - np.outer(q @ np.array(ax), np.array(ax))
    far = perp[np.argmax(np.linalg.norm(perp, axis=1))]
    down = Vector(far).normalized()
    up = -down
    side = ax.cross(up).normalized()
    up = side.cross(ax).normalized()
    basis = Matrix((side, ax, up)).transposed().to_4x4()       # rifle frame -> world columns
    k = float(spec["weapon_len"]) / (hi - lo)
    muzzle = K.g2b(rig["weapon"]["muzzle"])
    # the barrel's end on the muzzle (a little past it), the rifle's axis along +Y, up +Z
    tip = Vector(c) + ax * hi
    m = Matrix.Translation(muzzle + Vector((0, 0.03, 0))) @ Matrix.Scale(k, 4) @ basis.inverted() @ Matrix.Translation(-tip)
    w.data.transform(m)
    w.data.update()
    _close_gaps(w)
    img = base_image(w)
    paint_up(img, spec)
    slot_split(w, img, spec["palette"], spec["glow_min"], "weapon")
    w.name = "weapon"
    w.data.name = "weapon"
    return w


def split_off(ob, pick, name):
    """The faces whose vertices all pass pick(co) become their own object (materials kept)."""
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    faces = [f for f in bm.faces if all(pick(v.co) for v in f.verts)]
    other = bmesh.new()
    other.from_mesh(ob.data)
    keep = set(f.index for f in faces)
    bmesh.ops.delete(other, geom=[f for f in other.faces if f.index not in keep], context="FACES")
    bmesh.ops.delete(bm, geom=faces, context="FACES")
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    bmesh.ops.delete(other, geom=[v for v in other.verts if not v.link_faces], context="VERTS")
    bm.to_mesh(ob.data)
    bm.free()
    me = ob.data.copy()
    other.to_mesh(me)
    other.free()
    out = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(out)
    log("split %s: %d verts" % (name, len(me.vertices)))
    return out


def gun_arm(ob, ga, m):
    """A weapon fused to the arm (Vex's minigun): the faces along the axis from the elbow to the muzzle end, within
    `r` of it, come off the body (axis points in the Meshy frame, y found on the mesh; m the body's transform)."""
    e = snap(ob, m @ Vector(ga["elbow"]), 0.06)
    t = snap(ob, m @ Vector(ga["tip"]), 0.06)
    ax = t - e
    n = ax.length
    ax.normalize()
    sc = m.to_scale().x
    r = float(ga["r"]) * sc
    # (a gun that hangs by the waist and hip: its reach toward her body (r_in) and to the front and back (r_side)
    # is less than on its outer side (r), and near the elbow it is slenderer still: r_elbow over the first `taper`)
    r_in = float(ga.get("r_in", ga["r"])) * sc
    r_side = float(ga.get("r_side", ga["r"])) * sc
    r0 = float(ga.get("r_elbow", ga["r"])) * sc
    taper = float(ga.get("taper", 0.4))
    start = float(ga.get("from", 0.0))
    inward = Vector((-1.0, 0.0, 0.0))           # (her right arm: her body is toward -X in the fitted frame)
    inward = (inward - ax * inward.dot(ax)).normalized()

    def pick(co):
        d = co - e
        u = d.dot(ax) / n
        if not start - 0.02 <= u <= 1.06:
            return False
        rv = d - ax * d.dot(ax)
        dist = rv.length
        c = rv.dot(inward) / max(dist, 1e-9)
        rr = r_in if c > 0.5 else (r if c < -0.3 else r_side)
        rr = min(rr, r0 + (rr - r0) * min(1.0, max(0.0, u / taper)))
        return dist < rr
    return split_off(ob, pick, "weapon"), e, t


def one_slot(ob, slot):
    """Every face but the glowing ones onto one slot (the gun-arm is all metal: no skin or hair tint on it)."""
    names = [m.name for m in ob.data.materials]
    si = next(i for i, n in enumerate(names) if n.startswith(slot + "-"))
    gi = [i for i, n in enumerate(names) if n.startswith("glow")]
    for p in ob.data.polygons:
        if p.material_index not in gi:
            p.material_index = si


def reglow(ob, img, glow_min):
    """Faces painted bright enough (the gun's vents) onto the piece's glow material, with a threshold of its own."""
    w, h = img.size
    px = np.array(img.pixels[:], dtype=np.float32).reshape(h, w, 4)
    uv = ob.data.uv_layers.active.data
    gi = next(i for i, m in enumerate(ob.data.materials) if m.name.startswith("glow"))
    n = 0
    for p in ob.data.polygons:
        u = sum(uv[i].uv.x for i in p.loop_indices) / p.loop_total
        v = sum(uv[i].uv.y for i in p.loop_indices) / p.loop_total
        c = px[min(h - 1, max(0, int(v * h))), min(w - 1, max(0, int(u * w))), :3]
        if c[0] >= glow_min[0] and c[1] >= glow_min[1] and c[2] <= glow_min[2]:
            p.material_index = gi
            n += 1
    log("reglow: %d faces" % n)


def face_mask(ob, img, pick):
    """Texels (h, w bool) covered by the faces pick(polygon, centre, material name) accepts."""
    w, h = img.size
    ids = np.full((h, w), -1, np.int32)
    me = ob.data
    uv = me.uv_layers.active.data
    me.calc_loop_triangles()
    names = [m.name for m in me.materials]
    for t in me.loop_triangles:
        poly = me.polygons[t.polygon_index]
        if not pick(poly, poly.center, names[poly.material_index] if names else ""):
            continue
        _raster(ids, [uv[li].uv for li in t.loops], 1, w, h)
    return ids > 0


def touch_up(ob, img, rules):
    """The cleanup pass on the atlas, by geometry (credit-free; the owner's 04:20 notes): each rule picks faces by
    material slot(s), a box (x, z in the Meshy frame), a sector (azimuth about a vertical axis), whether they face
    the front, and their painted colour, then recolours their texels: "warm" moves them
    toward a colour keeping their value (skin to the art's tan), "flat" sets the colour with a little of their own
    value (the hair streak's band), "paint" sets it outright (the vents' glow)."""
    w, h = img.size
    px = np.array(img.pixels[:], dtype=np.float32).reshape(h, w, 4)
    uv = ob.data.uv_layers.active.data
    for r in rules:
        box = r.get("box")
        col = np.array(K.hexcol(r.get("colour", "808080")), np.float32)

        def pick(poly, c, mat, r=r, box=box):
            if r.get("slot") and not mat.startswith(r["slot"]):
                return False
            if r.get("slots") and not any(mat.startswith(x) for x in r["slots"]):
                return False
            if "sector" in r:
                # azimuth about a vertical axis at sector.centre [x, y]: 0 the front (-Y), +90 her left (+X)
                sc = r["sector"]
                az = math.degrees(math.atan2(c.x - sc["centre"][0], -(c.y - sc["centre"][1])))
                if not (sc["az"][0] <= az <= sc["az"][1]):
                    return False
            if box and not (box[0] <= c.x <= box[1] and box[2] <= c.z <= box[3]):
                return False
            nb = r.get("not_box")
            if nb and nb[0] <= c.x <= nb[1] and nb[2] <= c.z <= nb[3] and poly.normal.y < 0.3:
                return False      # (the face's own front: the art projected there stays)
            if "front" in r and poly.normal.y > -float(r["front"]):
                return False
            if "side_only" in r and poly.normal.y < -float(r["side_only"]):
                return False        # (faces turned away from the front only: a front projection's glancing smears)
            if "skip_hue" in r:
                # (keeps a piece of another colour in the box: the brass bolt in the bun)
                u = sum(uv[i].uv.x for i in poly.loop_indices) / poly.loop_total
                v = sum(uv[i].uv.y for i in poly.loop_indices) / poly.loop_total
                q = px[min(h - 1, int(v * h)), min(w - 1, int(u * w)), :3]
                sk = r["skip_hue"]
                if sk[0] <= _hue(q) <= sk[1] and (q.max() - q.min()) / max(q.max(), 1e-6) >= sk[2] and q.max() > 0.35:
                    return False
            if "val_max" in r:
                # (dark texels only: a crease's old paint where the projection did not reach)
                u = sum(uv[i].uv.x for i in poly.loop_indices) / poly.loop_total
                v = sum(uv[i].uv.y for i in poly.loop_indices) / poly.loop_total
                if px[min(h - 1, int(v * h)), min(w - 1, int(u * w)), :3].max() > float(r["val_max"]):
                    return False
            if "sat_max" in r:
                # (the grey parts only: a gunmetal gain leaves the brass bands alone)
                u = sum(uv[i].uv.x for i in poly.loop_indices) / poly.loop_total
                v = sum(uv[i].uv.y for i in poly.loop_indices) / poly.loop_total
                q = px[min(h - 1, int(v * h)), min(w - 1, int(u * w)), :3]
                if (q.max() - q.min()) / max(q.max(), 1e-6) > float(r["sat_max"]):
                    return False
            if "hue" in r:
                u = sum(uv[i].uv.x for i in poly.loop_indices) / poly.loop_total
                v = sum(uv[i].uv.y for i in poly.loop_indices) / poly.loop_total
                q = px[min(h - 1, int(v * h)), min(w - 1, int(u * w)), :3]
                mx, mn = q.max(), q.min()
                sat = (mx - mn) / max(mx, 1e-6)
                hue = _hue(q)
                if not (r["hue"][0] <= hue <= r["hue"][1] and sat >= r.get("sat_min", 0.0)):
                    return False
            return True
        m = face_mask(ob, img, pick)
        if r["mode"] == "fill":
            n_bad = _fill_texels(px, m, r["fill_hsv"], int(r.get("iterations", 80)), col, int(r.get("erode", 0)))
            log("touch-up fill %s: %d of %d texels" % (r.get("name", ""), n_bad, int(m.sum())))
            continue
        if r["mode"] in ("cap", "desat"):
            n_t = _texel_tone(px, m, r)
            log("touch-up %s %s: %d of %d texels" % (r["mode"], r.get("name", ""), n_t, int(m.sum())))
            continue
        rgb = px[m, :3]
        val = rgb.max(axis=1, keepdims=True) / max(float(col.max()), 1e-3)
        if r["mode"] == "warm":
            out = rgb * (1 - r["k"]) + np.clip(col * val, 0, 1) * r["k"]
        elif r["mode"] == "flat":
            v = np.clip(val, r.get("val_lo", 0.85), r.get("val_hi", 1.05))
            out = np.clip(col * v, 0, 1)
        elif r["mode"] == "gain":
            # (darker or lighter, keeping the paint's own shading; k of the way to the colour's hue)
            g = np.clip(rgb * float(r["gain"]), 0, 1)
            out = g * (1 - r.get("k", 0.0)) + np.clip(col * (g.max(axis=1, keepdims=True) / max(float(col.max()), 1e-3)), 0, 1) * r.get("k", 0.0)
        else:
            out = np.broadcast_to(col, rgb.shape)
        px[m, :3] = out
        log("touch-up %s %s: %d texels" % (r["mode"], r["colour"], int(m.sum())))
    img.pixels = px.ravel()


def _texel_tone(px, m, r):
    """Texel by texel inside the picked faces' texels `m`: "cap" compresses values above `cap` (by `k`: a skin's
    blown highlights, Vex's upper chest), "desat" takes `k` of the saturation out of texels whose hue is within
    `hue` [h0, h1] (h0 > h1 wraps) and saturation at least `sat_min` (her eyeshadow's magenta to the face sheet's
    smoky plum). Returns the texels changed."""
    rgb = px[..., :3]
    hq, sq, vq = _hsv_px(rgb)
    k = float(r.get("k", 0.4))
    if r["mode"] == "cap":
        t = float(r["cap"])
        sel = m & (vq > t)
        nv = t + (vq[sel] - t) * k
        rgb[sel] = rgb[sel] * (nv / np.maximum(vq[sel], 1e-6))[:, None]
    else:
        h0, h1 = r["hue"]
        hue_ok = (hq >= h0) & (hq <= h1) if h0 <= h1 else (hq >= h0) | (hq <= h1)
        sel = m & hue_ok & (sq >= float(r.get("sat_min", 0.0)))
        grey = rgb[sel].mean(axis=1, keepdims=True)
        rgb[sel] = rgb[sel] * (1.0 - k) + grey * k
    px[..., :3] = rgb
    return int(sel.sum())


def _fill_texels(px, m, q, iterations, col, erode=0):
    """Texels of a colour (hsv [h0, h1, s0, s1, v0, v1]) inside the picked faces' texels `m`, filled from the
    other texels of `m` around them, a ring at a time (Vex's chest: Meshy's blurry tattoos on the skin): the skin
    closes over them in its own shading, no flat patch. Texels no ring reaches take `col`. Returns their count."""
    if not m.any():
        return 0
    # (on the picked texels' bounding box only, a margin round it: the whole atlas, 80 rings, was minutes)
    rr, cc = np.nonzero(m)
    ra, rb = max(0, rr.min() - 2), min(m.shape[0], rr.max() + 3)
    ca, cb = max(0, cc.min() - 2), min(m.shape[1], cc.max() + 3)
    full_px, px, m = px, px[ra:rb, ca:cb], m[ra:rb, ca:cb]
    hq, sq, vq = _hsv_px(px[..., :3])
    hue_ok = (hq >= q[0]) & (hq <= q[1]) if q[0] <= q[1] else (hq >= q[0]) | (hq <= q[1])
    bad = m & hue_ok & (sq >= q[2]) & (sq <= q[3]) & (vq >= q[4]) & (vq <= q[5])
    inner = m.copy()
    for _i in range(erode):
        # (`erode` texels in from the faces' edge stay: a strap's own painted edge beside its cloth)
        inner &= np.roll(inner, 1, 0) & np.roll(inner, -1, 0) & np.roll(inner, 1, 1) & np.roll(inner, -1, 1)
    bad &= inner
    known = m & ~bad
    acc = px[..., :3].copy()
    for _i in range(iterations):
        tot = np.zeros_like(acc)
        cnt = np.zeros(acc.shape[:2], np.float32)
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            kn = np.roll(known, (dy, dx), (0, 1))
            tot += np.roll(acc, (dy, dx), (0, 1)) * kn[..., None]
            cnt += kn
        new = bad & ~known & (cnt > 0)
        if not new.any():
            break
        acc[new] = tot[new] / cnt[new][:, None]
        known |= new
    px[bad & known, :3] = acc[bad & known]
    px[bad & ~known, :3] = col
    full_px[ra:rb, ca:cb] = px
    return int(bad.sum())


def stamp_lines(ob, img, sp):
    """The art's thin lines (Vex's circuit tattoos, her gorget's seams) as vector strokes of one width (r3g): the
    art's line pixels in `art_box` (greenness g - max(r, b) above `threshold`, outside `skip_art_box`) thinned to
    their centre lines, each centre pixel (and the step to its neighbours) mapped onto the mesh by the view's
    registration (k, col0_at, row0_at, or the face's `warp`), ray-cast from the front onto the faces of `slots`
    inside `box`, and stamped there as an anti-aliased disc `width` m across in `colour`, never past those faces'
    texels (no bleed onto the jacket). The art's own soft edges and shading never reach the atlas."""
    from mathutils.bvhtree import BVHTree
    art = bpy.data.images.load(os.path.expanduser(sp["image"]))
    aw, ah = art.size
    src = np.array(art.pixels[:], dtype=np.float32).reshape(ah, aw, 4)
    c0, r0, c1, r1 = (int(v) for v in sp["art_box"])
    rows, cols = np.arange(r0, r1 + 1), np.arange(c0, c1 + 1)
    sub = src[ah - 1 - rows][:, cols, :3]
    on = (sub[..., 1] - np.maximum(sub[..., 0], sub[..., 2])) > float(sp.get("threshold", 0.08))
    if sp.get("max"):
        on &= (sub[..., 1] - np.maximum(sub[..., 0], sub[..., 2])) < float(sp["max"])
    for bx in sp.get("skip_art_box", []):
        on[max(0, bx[1] - r0):max(0, bx[3] - r0 + 1), max(0, bx[0] - c0):max(0, bx[2] - c0 + 1)] = False
    op = int(sp.get("open_px", 0))
    if op:
        # (wide areas of the colour are not lines: a lock of hair, a rim light; an opening finds and drops them)
        e = on.copy()
        for _i in range(op):
            e &= np.roll(e, 1, 0) & np.roll(e, -1, 0) & np.roll(e, 1, 1) & np.roll(e, -1, 1)
        for _i in range(op + 1):
            e |= np.roll(e, 1, 0) | np.roll(e, -1, 0) | np.roll(e, 1, 1) | np.roll(e, -1, 1)
        wide = on & e
        on &= ~e
    sk = _thin(on)
    ri, ci = np.nonzero(sk)
    pts = [(c0 + c, r0 + r) for r, c in zip(ri, ci)]
    if op and sp.get("keep_wide"):
        # (the wide parts stamped whole: the round nodes of a face's circuit, where no hair is in the box)
        wr, wc = np.nonzero(wide)
        pts += [(c0 + c, r0 + r) for r, c in zip(wr, wc)]
    skset = set(zip(ri.tolist(), ci.tolist()))
    for r, c in zip(ri.tolist(), ci.tolist()):
        for dr, dc in ((0, 1), (1, -1), (1, 0), (1, 1)):
            if (r + dr, c + dc) in skset:
                pts.append((c0 + c + dc * 0.5, r0 + r + dr * 0.5))
    pts = np.array(pts, float)
    if "warp" in sp:
        inv = _tps_fit(sp["warp"]["art"], sp["warp"]["mesh"], float(sp["warp"].get("smooth", 1e-3)))
        xz = inv(pts)
    else:
        k = float(sp["k"])
        xz = np.stack([(pts[:, 0] - float(sp["col0_at"])) * k, (float(sp["row0_at"]) - pts[:, 1]) * k], 1)
    me = ob.data
    me.calc_loop_triangles()
    names = [m.name for m in me.materials]
    slots = tuple(x + "-" for x in sp.get("slots", ["skin"]))
    x0, x1, z0, z1 = sp["box"]
    tris = [t for t in me.loop_triangles if names[t.material_index].startswith(slots)
            and all(x0 <= me.vertices[i].co.x <= x1 and z0 <= me.vertices[i].co.z <= z1 for i in t.vertices)]
    if not tris:
        log("stamp %s: no faces" % sp.get("name", ""))
        return
    tree = BVHTree.FromPolygons([v.co.copy() for v in me.vertices], [t.vertices[:] for t in tris])
    w, h = img.size
    px = np.array(img.pixels[:], dtype=np.float32).reshape(h, w, 4)
    uv = me.uv_layers.active.data

    def pick(poly, c, mat):
        return mat.startswith(slots) and x0 <= c.x <= x1 and z0 <= c.z <= z1
    allowed = face_mask(ob, img, pick)
    cover = np.zeros((h, w), np.float32)
    half = float(sp.get("width", 0.002)) * 0.5
    n_hit = 0
    for x, z in xz:
        hit = tree.ray_cast(Vector((x, -1.0, z)), Vector((0.0, 1.0, 0.0)), 2.0)
        if hit[0] is None:
            continue
        t = tris[hit[2]]
        a, b, c = (me.vertices[i].co for i in t.vertices)
        ua, ub, uc = (Vector((uv[li].uv.x * w, uv[li].uv.y * h, 0.0)) for li in t.loops)
        q = geometry.barycentric_transform(hit[0], a, b, c, ua, ub, uc)
        # texels per metre on this triangle: its UV area over its area
        area3 = max((b - a).cross(c - a).length, 1e-12)
        area2 = abs((ub - ua).cross(uc - ua).z)
        rt = max(0.6, half * math.sqrt(area2 / area3))
        cx, cy = q.x, q.y
        xs = np.arange(int(cx - rt - 1), int(cx + rt + 2))
        ys = np.arange(int(cy - rt - 1), int(cy + rt + 2))
        xs, ys = xs[(xs >= 0) & (xs < w)], ys[(ys >= 0) & (ys < h)]
        if not len(xs) or not len(ys):
            continue
        gx, gy = np.meshgrid(xs, ys)
        d = np.hypot(gx + 0.5 - cx, gy + 0.5 - cy)
        cov = np.clip(rt + 0.5 - d, 0.0, 1.0)
        cover[gy, gx] = np.maximum(cover[gy, gx], cov)
        n_hit += 1
    cover *= allowed
    col = np.array(K.hexcol(sp["colour"]), np.float32)
    px[..., :3] = px[..., :3] * (1.0 - cover[..., None]) + col * cover[..., None]
    img.pixels = px.ravel()
    log("stamp %s: %d line pixels in the art, %d stamped, %d texels" % (sp.get("name", ""), int(sk.sum()), n_hit,
                                                                       int((cover > 0.5).sum())))


def _thin(m):
    """Zhang-Suen thinning of a boolean mask to one-pixel lines."""
    m = m.astype(np.uint8)
    while True:
        changed = False
        for step in (0, 1):
            pd = np.pad(m, 1)
            nb = [pd[:-2, 1:-1], pd[:-2, 2:], pd[1:-1, 2:], pd[2:, 2:], pd[2:, 1:-1], pd[2:, :-2], pd[1:-1, :-2],
                  pd[:-2, :-2]]          # (N, NE, E, SE, S, SW, W, NW)
            b = sum(x.astype(np.int32) for x in nb)
            a = sum(((nb[i] == 0) & (nb[(i + 1) % 8] == 1)).astype(np.int32) for i in range(8))
            n_, e_, s_, w_ = nb[0], nb[2], nb[4], nb[6]
            if step == 0:
                c = ((n_ * e_ * s_) == 0) & ((e_ * s_ * w_) == 0)
            else:
                c = ((n_ * e_ * w_) == 0) & ((n_ * s_ * w_) == 0)
            rem = (m == 1) & (b >= 2) & (b <= 6) & (a == 1) & c
            if rem.any():
                m[rem] = 0
                changed = True
        if not changed:
            return m.astype(bool)


def _hue(q):
    mx, mn = q.max(), q.min()
    d = max(mx - mn, 1e-6)
    if mx == q[0]:
        hh = ((q[1] - q[2]) / d) % 6
    elif mx == q[1]:
        hh = (q[2] - q[0]) / d + 2
    else:
        hh = (q[0] - q[1]) / d + 4
    return hh / 6


def delete_boxes(ob, boxes):
    """Faces whose centre is inside a box [x0, x1, y0, y1, z0, z1] go: the ammo belt's loop, left dangling once the gun-arm is
    cut off (it ran from the back drum to the gun)."""
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    gone = [f for f in bm.faces if any(b[0] <= f.calc_center_median().x <= b[1] and b[2] <= f.calc_center_median().y
                                       <= b[3] and b[4] <= f.calc_center_median().z <= b[5] for b in boxes)]
    bmesh.ops.delete(bm, geom=gone, context="FACES")
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    bm.to_mesh(ob.data)
    bm.free()
    log("deleted %d faces in %d boxes" % (len(gone), len(boxes)))


def vents(gun, img, vt):
    """The gun's vents: the dark recessed faces along its housing (y band in the Gun's frame) onto the glow slot,
    painted the art's ember orange (Meshy paints them dull grey)."""
    w, h = img.size
    px = np.array(img.pixels[:], dtype=np.float32).reshape(h, w, 4)
    uv = gun.data.uv_layers.active.data
    gi = next(i for i, m in enumerate(gun.data.materials) if m.name.startswith("glow"))
    y0, y1 = vt["y"]

    def pick(poly, c, _mat):
        if not (y0 <= c.y <= y1):
            return False
        u = sum(uv[i].uv.x for i in poly.loop_indices) / poly.loop_total
        v = sum(uv[i].uv.y for i in poly.loop_indices) / poly.loop_total
        if px[min(h - 1, int(v * h)), min(w - 1, int(u * w)), :3].max() > vt["val_max"]:
            return False
        poly.material_index = gi
        return True
    m = face_mask(gun, img, pick)
    px[m, :3] = np.array(K.hexcol(vt["colour"]), np.float32)
    img.pixels = px.ravel()
    log("vents: %d texels" % int(m.sum()))


def gun_weapon(gun, e, t, rig, ga):
    """The cut-off gun-arm into the Gun node's space (Blender: forward +Y, her right +X, up +Z): its axis along
    +Y, the side that faced out from her body to her right, the barrels' end on the Muzzle and the back end
    `back` m behind the Gun's origin (where the elbow is in the hold), scaled to fit; faces in `trim_boxes`
    (that frame) go. The barrels past `spin` (a fraction of the axis) become the child `weapon_spin`, its
    origin on the axis, which HunterAnim spins."""
    ax = (t - e).normalized()
    out = Vector((1, 0, 0))                          # (her right, in the rig frame)
    side = (out - ax * out.dot(ax)).normalized()
    up = side.cross(ax).normalized()
    side = ax.cross(up).normalized()
    rot = Matrix((side, ax, up)).to_4x4()            # rows: world -> gun frame
    muzzle = K.g2b(rig["weapon"]["muzzle"])
    back = -float(ga.get("back", 0.12))
    k = (muzzle.y - back) / (t - e).length
    m = Matrix.Translation(Vector((0, back, muzzle.z))) @ Matrix.Scale(k, 4) @ rot @ Matrix.Translation(-e)
    transform(gun, m)
    decimate(gun, int(ga.get("tris", 6000)))
    if "vents" in ga:
        vents(gun, base_image_of(gun), ga["vents"])
    if ga.get("trim_boxes"):
        delete_boxes(gun, ga["trim_boxes"])     # (in the Gun's frame: the feed belt that hung off its back end)
        drop_floaters(gun, int(ga.get("loose_verts", 300)) // 10)
    sp = float(ga.get("spin", 0.62))
    cut_y = back + sp * (muzzle.y - back)
    spin = split_off(gun, lambda co: co.y > cut_y, "weapon_spin")
    co = np.array([v.co[:] for v in spin.data.vertices])
    c = Vector((float((co[:, 0].min() + co[:, 0].max()) / 2), cut_y, float((co[:, 2].min() + co[:, 2].max()) / 2)))
    transform(spin, Matrix.Translation(-c))
    spin.location = c
    spin.parent = gun
    log("gun-arm: scale %.3f, %.3f m long, spins past %.3f" % (k, muzzle.y - back, cut_y))
    return gun, spin


def chunk(ob, rig, ck):
    """Game proportions over the art's (they read at the match camera): the head and the free hand grown about
    their joints by their skin weight, and the whole body a little thicker about its vertical axis."""
    co = np.array([v.co[:] for v in ob.data.vertices])
    for bone, key in (("head", "head"), ("hand.L", "hand")):
        g = ob.vertex_groups.get(bone)
        if g is None or key not in ck:
            continue
        piv = np.array(K.bone_head(rig, bone)[:])
        kk = float(ck[key]) - 1.0
        # (head_x: the head a little wider than that again, a face that read small and gaunt: Vex r3h)
        kx = float(ck.get("head_x", 1.0)) - 1.0 if bone == "head" else 0.0
        for v in ob.data.vertices:
            w = next((x.weight for x in v.groups if x.group == g.index), 0.0)
            if w > 0.0:
                co[v.index] = piv + (co[v.index] - piv) * (1.0 + kk * w)
                co[v.index, 0] = piv[0] + (co[v.index, 0] - piv[0]) * (1.0 + kx * w)
    if "fingers" in ck:
        # (long spidery fingers: both hands stretched down from the wrist by their skin weight, Ostra's claws)
        fk = float(ck["fingers"]) - 1.0
        for bone in ("hand.L", "hand.R"):
            g = ob.vertex_groups.get(bone)
            if g is None:
                continue
            pz = K.bone_head(rig, bone).z
            for v in ob.data.vertices:
                w = next((x.weight for x in v.groups if x.group == g.index), 0.0)
                if w > 0.0 and co[v.index, 2] < pz:
                    co[v.index, 2] = pz + (co[v.index, 2] - pz) * (1.0 + fk * w)
    if "feet" in ck:
        # (the feet grown about each ankle's ground point, with a fade up the shin: the art's big wrapped feet)
        fk, top = float(ck["feet"]) - 1.0, float(ck.get("feet_top", 0.16))
        for side in (-1.0, 1.0):
            m = (co[:, 2] < top) & (co[:, 0] * side > 0.0)
            if not m.any():
                continue
            cx, cy = float(np.median(co[m, 0])), float(np.median(co[m, 1]))
            w = np.clip(1.0 - co[m, 2] / top, 0.0, 1.0)[:, None]
            piv = np.array([cx, cy, 0.0])
            co[m] = piv + (co[m] - piv) * (1.0 + fk * w)
    # "limbs" {bone: k}: the vertices on a bone (by skin weight) pushed out from the line through its head and
    # its child's head by k (Pip's chubby thighs and chest fluff); "hips" uses the line from hips to head
    child = {"thigh.L": "shin.L", "thigh.R": "shin.R", "hips": "head", "upper_arm.L": "forearm.L",
             "upper_arm.R": "forearm.R", "forearm.L": "hand.L", "forearm.R": "hand.R"}
    for bone, k in (ck.get("limbs") or {}).items():
        g = ob.vertex_groups.get(bone)
        if g is None:
            continue
        a = np.array(K.bone_head(rig, bone)[:])
        if bone in child:
            b = np.array(K.bone_head(rig, child[bone])[:])
        else:                         # (a shin: on along its thigh's line)
            par = {"shin.L": "thigh.L", "shin.R": "thigh.R"}.get(bone)
            b = a + (a - np.array(K.bone_head(rig, par)[:])) if par else a + np.array([0.0, 0.0, -0.3])
        ax = (b - a) / max(np.linalg.norm(b - a), 1e-6)
        kk = float(k) - 1.0
        for v in ob.data.vertices:
            w = next((x.weight for x in v.groups if x.group == g.index), 0.0)
            if w > 0.0:
                d = co[v.index] - a
                rad = d - ax * d.dot(ax)
                co[v.index] = co[v.index] + rad * kk * w
    gk = float(ck.get("girth", 1.0))
    co[:, 0] *= gk
    co[:, 1] *= gk
    ob.data.vertices.foreach_set("co", co.ravel())
    ob.data.update()


def shrink_box(ob, sb):
    """A bulky piece pulled in (fitted frame, the rest pose): the vertices of `slots` (all without) inside `box`
    [x0, x1, y0, y1, z0, z1] move toward the vertical axis through `centre` [x, y] by `k` of their distance
    (Sable's fur collar standing out behind her neck), fading over `fade` m from the box's edges."""
    b = [(-1e9 if x is None else x) if i % 2 == 0 else (1e9 if x is None else x) for i, x in enumerate(sb["box"])]
    slots = sb.get("slots")
    on = np.zeros(len(ob.data.vertices), bool)
    for p in ob.data.polygons:
        if slots is None or any(ob.data.materials[p.material_index].name.startswith(x + "-") for x in slots):
            on[list(p.vertices)] = True
    co = np.array([v.co[:] for v in ob.data.vertices])
    inside = on & (co[:, 0] >= b[0]) & (co[:, 0] <= b[1]) & (co[:, 1] >= b[2]) & (co[:, 1] <= b[3]) \
        & (co[:, 2] >= b[4]) & (co[:, 2] <= b[5])
    fade = float(sb.get("fade", 0.03))
    dz = np.minimum(co[:, 2] - b[4], b[5] - co[:, 2])
    w = np.clip(dz / max(fade, 1e-4), 0.0, 1.0) * inside
    cx, cy = sb["centre"]
    k = float(sb["k"])
    co[:, 0] = cx + (co[:, 0] - cx) * (1.0 - (1.0 - k) * w)
    co[:, 1] = cy + (co[:, 1] - cy) * (1.0 - (1.0 - k) * w)
    ob.data.vertices.foreach_set("co", co.ravel())
    ob.data.update()
    log("shrink: %d vertices toward (%.2f, %.2f) x%.2f" % (int(inside.sum()), cx, cy, k))


def _close_gaps(w):
    """Loose pieces along the rifle (the stock the hand hid in the sheet comes back apart and at an angle): each
    is turned onto the rifle's axis and slid forward until it meets the rest, on the axis line."""
    bm = bmesh.new()
    bm.from_mesh(w.data)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    parts = []
    seen = set()
    for v in bm.verts:
        if v.index in seen:
            continue
        part, stack = [], [v]
        seen.add(v.index)
        while stack:
            x = stack.pop()
            part.append(x)
            for e in x.link_edges:
                o = e.other_vert(x)
                if o.index not in seen:
                    seen.add(o.index)
                    stack.append(o)
        parts.append(part)
    parts.sort(key=len, reverse=True)
    main = np.array([v.co[:] for v in parts[0]])
    back = main[:, 1].min()
    tail = main[main[:, 1] < back + 0.04]
    for part in parts[1:]:
        if len(part) < 30:
            continue
        co = np.array([v.co[:] for v in part])
        if co[:, 1].max() > back + 0.02:
            continue                  # (a piece alongside the rifle, not behind it)
        c = co.mean(axis=0)
        _u, _s, vt = np.linalg.svd(co - c, full_matrices=False)
        ax = Vector(vt[0])
        if ax.y > 0:
            ax = -ax                  # pointing back, away from the receiver
        rot = ax.rotation_difference(Vector((0, -1, 0))).to_matrix()
        for v in part:
            v.co = rot @ (v.co - Vector(c))
        front = max(v.co.y for v in part)
        shift = Vector((float(tail[:, 0].mean()), back - front + 0.01, float(tail[:, 2].mean())))
        for v in part:
            v.co += shift
    bm.to_mesh(w.data)
    bm.free()


def smooth_atlas(img, ids, it, sigma_s, sigma_r):
    """Edge-preserving smoothing of the atlas within UV islands (a bilateral filter): Meshy's painted grain and
    speckle go, the edges between colours (a trim, a tattoo line, the eye) stay. The flat painted read of the art."""
    w, h = img.size
    px = np.array(img.pixels[:], dtype=np.float32).reshape(h, w, 4)
    rgb = px[..., :3].copy()
    rad = int(math.ceil(sigma_s * 2))
    offs = [(dy, dx) for dy in range(-rad, rad + 1) for dx in range(-rad, rad + 1) if dy * dy + dx * dx <= rad * rad]
    for _i in range(it):
        out = np.empty_like(rgb)
        for y0 in range(0, h, 512):
            y1 = min(h, y0 + 512)
            ya, yb = max(0, y0 - rad), min(h, y1 + rad)
            blk = rgb[ya:yb]
            bid = ids[ya:yb]
            acc = np.zeros((y1 - y0, w, 3), np.float32)
            wsum = np.zeros((y1 - y0, w, 1), np.float32)
            c = rgb[y0:y1]
            ci = ids[y0:y1]
            for dy, dx in offs:
                sh = np.roll(blk, (-dy, -dx), axis=(0, 1))[y0 - ya:y0 - ya + (y1 - y0)]
                si = np.roll(bid, (-dy, -dx), axis=(0, 1))[y0 - ya:y0 - ya + (y1 - y0)]
                d2 = ((sh - c) ** 2).sum(axis=2, keepdims=True)
                wt = np.exp(-(dy * dy + dx * dx) / (2 * sigma_s * sigma_s) - d2 / (2 * sigma_r * sigma_r))
                wt = wt * (si == ci)[..., None]
                acc += sh * wt
                wsum += wt
            out[y0:y1] = acc / np.maximum(wsum, 1e-6)
        rgb = np.where((ids >= 0)[..., None], out, rgb)
    px[..., :3] = rgb
    img.pixels = px.ravel()
    log("smoothed the atlas: %d passes, sigma %.1f px / %.2f" % (it, sigma_s, sigma_r))


def _hsv_px(rgb):
    mx = rgb.max(axis=-1)
    mn = rgb.min(axis=-1)
    d = np.maximum(mx - mn, 1e-6)
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    hue = np.where(mx == r, ((g - b) / d) % 6, np.where(mx == g, (b - r) / d + 2, (r - g) / d + 4)) / 6.0
    sat = np.where(mx > 1e-6, (mx - mn) / np.maximum(mx, 1e-6), 0.0)
    return hue, sat, mx


def ramp_paint(ob, img, rules):
    """The paint-over by colour ramps (owner: flat, clean, bright painted colour): each rule takes the texels of
    its slots' faces whose own colour passes its hsv filter [h0, h1, s0, s1, v0, v1] (h0 > h1 wraps), and maps
    their brightness (between the rule's `lum` or its own 3rd and 97th percentiles) onto a ramp of the art's
    colours, dark to light: the shading Meshy painted stays, the colours become the art's."""
    w, h = img.size
    px = np.array(img.pixels[:], dtype=np.float32).reshape(h, w, 4)
    rgb = px[..., :3]
    hue, sat, val = _hsv_px(rgb)
    lum = rgb @ np.array([0.3, 0.59, 0.11], np.float32)
    for r in rules:
        slots = r.get("slots")
        box = r.get("box")          # [x0, x1, y0, y1, z0, z1] on the face's centre, null for open

        def pick(poly, c, mat, slots=slots, box=box):
            if slots is not None and not any(mat.startswith(x + "-") for x in slots):
                return False
            if box:
                b = [(-1e9 if x is None else x) if i % 2 == 0 else (1e9 if x is None else x) for i, x in enumerate(box)]
                return b[0] <= c.x <= b[1] and b[2] <= c.y <= b[3] and b[4] <= c.z <= b[5]
            return True
        m = face_mask(ob, img, pick)
        q = r.get("hsv")
        if q:
            h0, h1, s0, s1, v0, v1 = q
            hue_ok = (hue >= h0) & (hue <= h1) if h0 <= h1 else (hue >= h0) | (hue <= h1)
            m &= hue_ok & (sat >= s0) & (sat <= s1) & (val >= v0) & (val <= v1)
        if not m.any():
            log("ramp %s: no texels" % r.get("name", "?"))
            continue
        lo, hi = r.get("lum") or (float(np.percentile(lum[m], 3)), float(np.percentile(lum[m], 97)))
        t = np.clip((lum[m] - lo) / max(hi - lo, 1e-3), 0.0, 1.0) ** float(r.get("gamma", 1.0))
        cols = np.array([K.hexcol(c) for c in r["ramp"]], np.float32)
        x = t * (len(cols) - 1)
        i0 = np.clip(np.floor(x).astype(int), 0, len(cols) - 2)
        f = (x - i0)[:, None]
        new = cols[i0] * (1 - f) + cols[i0 + 1] * f
        k = float(r.get("k", 1.0))
        rgb[m] = rgb[m] * (1 - k) + new * k
        log("ramp %s: %d texels, lum %.3f..%.3f" % (r.get("name", "?"), int(m.sum()), lo, hi))
    px[..., :3] = rgb
    img.pixels = px.ravel()


def _erode(m, r):
    return ~_dilate(~m, r)


def _dilate(m, r):
    out = m.copy()
    for ax in (0, 1):
        acc = out.copy()
        for d in range(1, r + 1):
            acc |= np.roll(out, d, axis=ax) | np.roll(out, -d, axis=ax)
        out = acc
    return out


def split_part(ob, arm, img, sp):
    """A piece cut off the body as its own mesh (Tarek's stone bracers, Ostra's mask): the faces whose centre is in
    one of `boxes` (the fitted frame on the contract's rest pose: his right +X, front +Y, soles on 0) and whose
    painted colour matches `hsv` [h0, h1, s0, s1, v0, v1] (if given) and whose vertices all ride mostly one of
    `bones` (if given: the forearms, not the hip the hanging arm touches), still skinned as they were, on one material
    "<slot>-<name>" over the body's atlas. `emit` paints an emission layer for it (the material's emissive
    texture, which WardenGlb puts on the toon shader's emit layer): "dark" lights the texels darker than `k` x the
    part's median (the cracks between a bracer's stone plates) in `colour`; "hsv" lights the texels in its range
    (a mask's glowing mouth and eyes) with their own colour x `gain`."""
    w, h = img.size
    px = np.array(img.pixels[:], dtype=np.float32).reshape(h, w, 4)
    uv = ob.data.uv_layers.active.data
    inf = float("inf")
    pick = set()
    on_bones = None
    if sp.get("bones"):
        gi = {ob.vertex_groups[b].index for b in sp["bones"] if b in ob.vertex_groups}
        on_bones = [bool(v.groups) and max(v.groups, key=lambda x: x.weight).group in gi for v in ob.data.vertices]
    for p in ob.data.polygons:
        if on_bones is not None and not all(on_bones[i] for i in p.vertices):
            continue
        c = p.center
        if not any(b[0] <= c.x <= b[1] and b[2] <= c.y <= b[3] and b[4] <= c.z <= b[5]
                   for b in [[(-inf, inf)[i % 2] if x is None else x for i, x in enumerate(bx)] for bx in sp["boxes"]]):
            continue
        if sp.get("hsv"):
            u = sum(uv[i].uv.x for i in p.loop_indices) / p.loop_total
            v = sum(uv[i].uv.y for i in p.loop_indices) / p.loop_total
            hh, ss, vv = _hsv(px[min(h - 1, max(0, int(v * h))), min(w - 1, max(0, int(u * w))), :3])
            if not any((q[0] <= hh <= q[1] if q[0] <= q[1] else (hh >= q[0] or hh <= q[1])) and q[2] <= ss <= q[3]
                       and q[4] <= vv <= q[5] for q in sp["hsv"]):
                continue
        pick.add(p.index)
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    other = bmesh.new()
    other.from_mesh(ob.data)
    bmesh.ops.delete(other, geom=[f for f in other.faces if f.index not in pick], context="FACES")
    bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.index in pick], context="FACES")
    for b in (bm, other):
        bmesh.ops.delete(b, geom=[v for v in b.verts if not v.link_faces], context="VERTS")
    bm.to_mesh(ob.data)
    bm.free()
    me = ob.data.copy()
    other.to_mesh(me)
    other.free()
    part = bpy.data.objects.new(sp["name"].capitalize(), me)
    bpy.context.scene.collection.objects.link(part)
    for g in ob.vertex_groups:
        part.vertex_groups.new(name=g.name)
    part.parent = arm
    mod = part.modifiers.new("Armature", "ARMATURE")
    mod.object = arm
    # its material: the atlas, and an emission layer drawn on the part's own texels
    m = bpy.data.materials.new("%s-%s" % (sp["slot"], sp["name"]))
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get("Principled BSDF")
    tex = m.node_tree.nodes.new("ShaderNodeTexImage")
    tex.image = img
    m.node_tree.links.new(tex.outputs[0], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.8
    me.materials.clear()
    me.materials.append(m)
    for p in me.polygons:
        p.material_index = 0
    e = sp.get("emit")
    lit = 0
    if e:
        ids = np.full((h, w), -1, np.int32)
        uvp = me.uv_layers.active.data
        for p in me.polygons:
            li = list(p.loop_indices)
            for k in range(1, len(li) - 1):
                _raster(ids, [uvp[li[0]].uv, uvp[li[k]].uv, uvp[li[k + 1]].uv], 1, w, h)
        mask = ids >= 0
        rgb = px[..., :3]
        lum = rgb @ np.array([0.299, 0.587, 0.114], np.float32)
        out = np.zeros((h, w, 4), np.float32)
        out[..., 3] = 1.0
        if e["mode"] == "dark":
            med = float(np.median(lum[mask]))
            k = np.clip((float(e.get("k", 0.6)) * med - lum) / max(0.15 * med, 1e-3) + 0.5, 0.0, 1.0) * mask
            out[..., :3] = k[..., None] * np.array(K.hexcol(e.get("colour", "ff9a30")), np.float32)
        else:
            q = e["hsv"]
            mx, mn = rgb.max(axis=2), rgb.min(axis=2)
            ss = (mx - mn) / np.maximum(mx, 1e-4)
            hh = np.zeros_like(mx)
            d = np.maximum(mx - mn, 1e-6)
            r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
            hh = np.where(mx == r, ((g - b) / d) % 6.0, np.where(mx == g, (b - r) / d + 2.0, (r - g) / d + 4.0)) / 6.0
            hue_ok = (hh >= q[0]) & (hh <= q[1]) if q[0] <= q[1] else (hh >= q[0]) | (hh <= q[1])
            k = hue_ok & (ss >= q[2]) & (ss <= q[3]) & (mx >= q[4]) & (mx <= q[5]) & mask
            if e.get("enclosed"):
                # (only what the porcelain closes round: the eyes, mouth, tear and crack inside the white face,
                # not a violet hood half that the split took along with it)
                white = mask & (ss < 0.3) & (mx > 0.55)
                k &= _erode(_dilate(white, int(e["enclosed"])), int(e["enclosed"]))
            k = k.astype(np.float32)
            out[..., :3] = k[..., None] * np.clip(rgb * float(e.get("gain", 1.4)), 0.0, 1.0)
        lit = int((out[..., :3].max(axis=2) > 0.1).sum())
        em = bpy.data.images.new("%s_emit" % sp["name"], w, h, alpha=False)
        em.pixels = out.ravel()
        em.pack()
        et = m.node_tree.nodes.new("ShaderNodeTexImage")
        et.image = em
        m.node_tree.links.new(et.outputs[0], bsdf.inputs["Emission Color"])
        bsdf.inputs["Emission Strength"].default_value = 1.0
    log("split %s: %d faces, %d emission texels" % (sp["name"], len(pick), lit))
    return part


def hair_spring(ob, arm, hs):
    """Hair the scan fused into one mass, on a spring chain after all (Tarek's locs): a chain of `bones`
    spring_<name>_<i> bones from `top` straight to `bottom` under `parent` (the head), and every vertex of the
    `slot` (hair) faces inside the box [box_lo, box_hi] handed from the parent to the chain by how far down the
    chain it hangs: wholly the parent's at the roots (the first `root` share of the length), wholly the chain's
    below, so the locs' ends trail and swing while the scalp stays put (WardenGlb.Springs)."""
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    import warden_parts as WP
    top, bot = np.array(hs["top"], np.float64), np.array(hs["bottom"], np.float64)
    pts = np.array([top + (bot - top) * f for f in np.linspace(0.0, 1.0, 8)])
    L = float(np.linalg.norm(bot - top))
    names, spans = WP.chain_bones(arm, hs["name"], hs.get("parent", "head"), pts, L, int(hs.get("bones", 3)), bot)
    lo, hi = hs["box_lo"], hs["box_hi"]
    slot = hs.get("slot", "hair")
    on = {i for i, m in enumerate(ob.data.materials) if m and m.name.split("-")[0] == slot}
    verts = set()
    for p in ob.data.polygons:
        if p.material_index in on:
            verts.update(p.vertices)
    groups = [ob.vertex_groups.get(n) or ob.vertex_groups.new(name=n) for n in names]
    mids = np.array([(a + b) * 0.5 for a, b in spans])
    lens = np.array([max(b - a, 1e-3) for a, b in spans])
    ax = (bot - top) / max(L, 1e-6)
    root = float(hs.get("root", 0.15)) * L
    moved = 0
    for vi in verts:
        co = np.array(ob.data.vertices[vi].co[:])
        if not all(lo[i] <= co[i] <= hi[i] for i in range(3)):
            continue
        sv = float(np.clip((co - top) @ ax, 0.0, L))
        f = min(1.0, max(0.0, (sv - root) / max(root, 1e-6)))
        f = f * f * (3.0 - 2.0 * f)
        if f <= 0.0:
            continue
        w = np.clip(1.0 - np.abs(sv - mids) / lens, 0.0, 1.0)
        if sv <= mids[0]:
            w[:] = 0.0
            w[0] = 1.0
        if sv >= mids[-1]:
            w[:] = 0.0
            w[-1] = 1.0
        w = w / max(w.sum(), 1e-6)
        for x in ob.data.vertices[vi].groups:
            ob.vertex_groups[x.group].add([vi], x.weight * (1.0 - f), "REPLACE")
        for gi in np.nonzero(w > 1e-3)[0]:
            groups[gi].add([vi], float(w[gi] * f), "ADD")
        moved += 1
    log("hair spring %s: %d bones, %d vertices" % (hs["name"], len(names), moved))


def emit_art(ob, img, el):
    """An emission mask projected from the art (Sparkle's pink scar, choker charm, corset piping and forearm veins: the
    scan paints them as plain pink, the art draws them as neon). In Meshy's frame, before the fit (the mesh still
    stands as the front view does), every texel of a face in one of `boxes` that faces the camera (normal -Y) gets
    its surface point, which the front view's registration puts on the art: `image`, `px_per_m`, `col_at` / `row_at`
    (the art's pixel at Meshy's x = 0 / z = 0). The art's neon pixels there (`hsv` ranges [h0, h1, s0, s1, v0, v1])
    light it with the art's own colour. Returns the mask (rgb, the atlas's size); emit_attach() puts it on."""
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    import imgio
    w, h = img.size
    art = imgio.load(os.path.expanduser(el["image"]))
    ah, aw = art.shape[:2]
    me = ob.data
    me.calc_loop_triangles()
    uvl = me.uv_layers.active.data
    inf = float("inf")
    boxes = [[(-inf, inf)[i % 2] if x is None else x for i, x in enumerate(bx)] for bx in el["boxes"]]
    co = np.array([v.co[:] for v in me.vertices])
    out = np.zeros((h, w, 3), np.float32)
    # (`strict`: regions, in Meshy's frame, with their own tighter hsv: the charm's core, not the art's glow
    # halo on the skin round it)
    strict = el.get("strict", [])
    reg = np.full((h, w), -1, np.int16)
    k_px, c0, r0 = float(el["px_per_m"]), float(el["col_at"]), float(el["row_at"])
    face_min = float(el.get("facing", 0.2))
    nt = 0
    for tri in me.loop_triangles:
        c = co[list(tri.vertices)].mean(axis=0)
        if not any(b[0] <= c[0] <= b[1] and b[2] <= c[1] <= b[3] and b[4] <= c[2] <= b[5] for b in boxes):
            continue
        if -tri.normal.y < face_min:
            continue
        nt += 1
        P = co[list(tri.vertices)]
        q = np.array([[uvl[li].uv.x * w, uvl[li].uv.y * h] for li in tri.loops])
        lo = np.maximum(np.floor(q.min(axis=0)).astype(int) - 1, 0)
        hi = np.minimum(np.ceil(q.max(axis=0)).astype(int) + 1, [w - 1, h - 1])
        if (hi < lo).any():
            continue
        xs, ys = np.meshgrid(np.arange(lo[0], hi[0] + 1), np.arange(lo[1], hi[1] + 1))
        t = np.stack([xs.ravel() + 0.5, ys.ravel() + 0.5], axis=1)
        a_, b_, c_ = q
        d = (b_[1] - c_[1]) * (a_[0] - c_[0]) + (c_[0] - b_[0]) * (a_[1] - c_[1])
        if abs(d) < 1e-12:
            continue
        l1 = ((b_[1] - c_[1]) * (t[:, 0] - c_[0]) + (c_[0] - b_[0]) * (t[:, 1] - c_[1])) / d
        l2 = ((c_[1] - a_[1]) * (t[:, 0] - c_[0]) + (a_[0] - c_[0]) * (t[:, 1] - c_[1])) / d
        l3 = 1 - l1 - l2
        ins = (l1 >= -0.02) & (l2 >= -0.02) & (l3 >= -0.02)
        if not ins.any():
            continue
        pos = np.outer(l1[ins], P[0]) + np.outer(l2[ins], P[1]) + np.outer(l3[ins], P[2])
        col = np.clip((c0 + pos[:, 0] * k_px).astype(int), 0, aw - 1)
        row = np.clip((r0 - pos[:, 2] * k_px).astype(int), 0, ah - 1)
        out[t[ins, 1].astype(int), t[ins, 0].astype(int)] = art[row, col]
        for si, st in enumerate(strict):
            b = st["box"]
            inb = ((pos[:, 0] >= b[0]) & (pos[:, 0] <= b[1]) & (pos[:, 1] >= b[2]) & (pos[:, 1] <= b[3])
                   & (pos[:, 2] >= b[4]) & (pos[:, 2] <= b[5]))
            reg[t[ins, 1].astype(int)[inb], t[ins, 0].astype(int)[inb]] = si
    rgb = out
    mx, mn = rgb.max(axis=2), rgb.min(axis=2)
    ss = (mx - mn) / np.maximum(mx, 1e-4)
    dd = np.maximum(mx - mn, 1e-6)
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    hh = np.where(mx == r, ((g - b) / dd) % 6.0, np.where(mx == g, (b - r) / dd + 2.0, (r - g) / dd + 4.0)) / 6.0
    def neon(qs):
        k = np.zeros((h, w), np.float32)
        for q in qs:
            hue_ok = (hh >= q[0]) & (hh <= q[1]) if q[0] <= q[1] else (hh >= q[0]) | (hh <= q[1])
            k = np.maximum(k, (hue_ok & (ss >= q[2]) & (ss <= q[3]) & (mx >= q[4]) & (mx <= q[5])).astype(np.float32))
        return k
    k = neon(el["hsv"])
    for si, st in enumerate(strict):
        k = np.where(reg == si, neon(st["hsv"]), k)
    mask = k[..., None] * np.clip(rgb * float(el.get("gain", 1.2)), 0.0, 1.0)
    # (Blender images run bottom up, as the UVs)
    log("emit from the art: %d triangles in the boxes, %d texels lit" % (nt, int((k > 0).sum())))
    return mask


def paint_art(ob, img, pa):
    """The art painted over the finished atlas by an orthographic front projection with its own registration
    (Sparkle's face from the head sheet, which draws it at 3.5x the front view's pixels): in Meshy's frame, before the
    fit, every texel of a face on one of `slots` inside `box` [x0, x1, z0, z1] that faces the camera (normal -Y)
    takes the art's pixel at col = col_at + x * kx, row = row_at - z * ky, blended by `k` and feathered over
    `feather` m from the box's edges; art pixels in a `keep` hsv range (the art's hair) leave the scan's own."""
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    import imgio
    w, h = img.size
    px = np.array(img.pixels[:], dtype=np.float32).reshape(h, w, 4)
    art = imgio.load(os.path.expanduser(pa["image"]))
    ah, aw = art.shape[:2]
    me = ob.data
    me.calc_loop_triangles()
    uvl = me.uv_layers.active.data
    co = np.array([v.co[:] for v in me.vertices])
    x0, x1, z0, z1 = pa["box"]
    fe = float(pa.get("feather", 0.01))
    kx, ky, c0, r0 = float(pa["kx"]), float(pa["ky"]), float(pa["col_at"]), float(pa["row_at"])
    slots = pa.get("slots", ["skin"])
    kk = float(pa.get("k", 1.0))
    keep = pa.get("keep", [])
    n = 0
    for tri in me.loop_triangles:
        P = co[list(tri.vertices)]
        c = P.mean(axis=0)
        if not (x0 - fe <= c[0] <= x1 + fe and z0 - fe <= c[2] <= z1 + fe) or -tri.normal.y < float(pa.get("facing", 0.25)):
            continue
        m = me.materials[me.polygons[tri.polygon_index].material_index]
        if m is None or m.name.split("-")[0] not in slots:
            continue
        q = np.array([[uvl[li].uv.x * w, uvl[li].uv.y * h] for li in tri.loops])
        lo = np.maximum(np.floor(q.min(axis=0)).astype(int) - 1, 0)
        hi = np.minimum(np.ceil(q.max(axis=0)).astype(int) + 1, [w - 1, h - 1])
        if (hi < lo).any():
            continue
        xs, ys = np.meshgrid(np.arange(lo[0], hi[0] + 1), np.arange(lo[1], hi[1] + 1))
        t = np.stack([xs.ravel() + 0.5, ys.ravel() + 0.5], axis=1)
        a_, b_, c_ = q
        d = (b_[1] - c_[1]) * (a_[0] - c_[0]) + (c_[0] - b_[0]) * (a_[1] - c_[1])
        if abs(d) < 1e-12:
            continue
        l1 = ((b_[1] - c_[1]) * (t[:, 0] - c_[0]) + (c_[0] - b_[0]) * (t[:, 1] - c_[1])) / d
        l2 = ((c_[1] - a_[1]) * (t[:, 0] - c_[0]) + (a_[0] - c_[0]) * (t[:, 1] - c_[1])) / d
        l3 = 1 - l1 - l2
        ins = (l1 >= -0.02) & (l2 >= -0.02) & (l3 >= -0.02)
        if not ins.any():
            continue
        pos = np.outer(l1[ins], P[0]) + np.outer(l2[ins], P[1]) + np.outer(l3[ins], P[2])
        col = np.clip((c0 + pos[:, 0] * kx).astype(int), 0, aw - 1)
        row = np.clip((r0 - pos[:, 2] * ky).astype(int), 0, ah - 1)
        src = art[row, col]
        wgt = np.clip(np.minimum.reduce([pos[:, 0] - x0, x1 - pos[:, 0], pos[:, 2] - z0, z1 - pos[:, 2]]) / fe + 0.0,
                      0.0, 1.0) * kk
        if keep:
            hh, ss, vv = _hsv_px(src[None])
            hh, ss, vv = hh[0], ss[0], vv[0]
            for kq in keep:
                hit = (hh >= kq[0]) & (hh <= kq[1]) & (ss >= kq[2]) & (ss <= kq[3]) & (vv >= kq[4]) & (vv <= kq[5])
                wgt = np.where(hit, 0.0, wgt)
        ty, tx = t[ins, 1].astype(int), t[ins, 0].astype(int)
        px[ty, tx, :3] = px[ty, tx, :3] * (1 - wgt[:, None]) + src * wgt[:, None]
        n += int((wgt > 0).sum())
    img.pixels = px.ravel()
    log("paint %s from the art: %d texels" % (pa.get("name", "?"), n))


spec_emit_atlas = []


def net_paint(ob, img, nt):
    """A fishnet over skin (Sparkle's thighs; the scan paints it as a tan blur): skin texels of faces in `box` (Meshy
    frame) darkened along a diamond lattice in surface space, lines `line` m wide every `pitch` m on the two
    diagonals of (x or y, z), to `colour`."""
    w, h = img.size
    px = np.array(img.pixels[:], dtype=np.float32).reshape(h, w, 4)
    me = ob.data
    me.calc_loop_triangles()
    uvl = me.uv_layers.active.data
    co = np.array([v.co[:] for v in me.vertices])
    x0, x1, z0, z1 = nt["box"]
    pitch, line = float(nt.get("pitch", 0.018)), float(nt.get("line", 0.0035))
    col = np.array(K.hexcol(nt.get("colour", "1c1418")), np.float32)
    kk = float(nt.get("k", 0.85))
    n = 0
    for tri in me.loop_triangles:
        P = co[list(tri.vertices)]
        c = P.mean(axis=0)
        if not (x0 <= c[0] <= x1 and z0 <= c[2] <= z1):
            continue
        m = me.materials[me.polygons[tri.polygon_index].material_index]
        if m is None or not m.name.startswith("skin"):
            continue
        q = np.array([[uvl[li].uv.x * w, uvl[li].uv.y * h] for li in tri.loops])
        lo = np.maximum(np.floor(q.min(axis=0)).astype(int) - 1, 0)
        hi = np.minimum(np.ceil(q.max(axis=0)).astype(int) + 1, [w - 1, h - 1])
        if (hi < lo).any():
            continue
        xs, ys = np.meshgrid(np.arange(lo[0], hi[0] + 1), np.arange(lo[1], hi[1] + 1))
        t = np.stack([xs.ravel() + 0.5, ys.ravel() + 0.5], axis=1)
        a_, b_, c_ = q
        d = (b_[1] - c_[1]) * (a_[0] - c_[0]) + (c_[0] - b_[0]) * (a_[1] - c_[1])
        if abs(d) < 1e-12:
            continue
        l1 = ((b_[1] - c_[1]) * (t[:, 0] - c_[0]) + (c_[0] - b_[0]) * (t[:, 1] - c_[1])) / d
        l2 = ((c_[1] - a_[1]) * (t[:, 0] - c_[0]) + (a_[0] - c_[0]) * (t[:, 1] - c_[1])) / d
        l3 = 1 - l1 - l2
        ins = (l1 >= -0.02) & (l2 >= -0.02) & (l3 >= -0.02)
        if not ins.any():
            continue
        pos = np.outer(l1[ins], P[0]) + np.outer(l2[ins], P[1]) + np.outer(l3[ins], P[2])
        # (round the leg: its angle about the leg's own axis, so the net wraps the thigh, not just the front)
        cx = np.where(pos[:, 0] > 0, float(nt.get("leg_x", 0.08)), -float(nt.get("leg_x", 0.08)))
        u = np.arctan2(pos[:, 1], pos[:, 0] - cx) * float(nt.get("leg_r", 0.065))
        on = np.zeros(len(pos), bool)
        for dd in (pos[:, 2] + u, pos[:, 2] - u):
            f = (dd / pitch) % 1.0
            on |= f < line / pitch
        ty, tx = t[ins, 1].astype(int), t[ins, 0].astype(int)
        px[ty[on], tx[on], :3] = px[ty[on], tx[on], :3] * (1 - kk) + col * kk
        n += int(on.sum())
    img.pixels = px.ravel()
    log("fishnet: %d texels" % n)


def emit_attach(ob, img, mask, parts=()):
    """The emission mask (from emit_art, at the bake's size) down to the atlas's size, as every body material's
    emission texture: WardenGlb puts it on the toon shader's emit layer, in the archetype's model_glow colour."""
    w, h = img.size
    f = mask.shape[1] // w
    if f > 1:
        mask = mask.reshape(h, f, w, f, 3).mean(axis=(1, 3))
    ea = spec_emit_atlas[0] if spec_emit_atlas else None
    if ea:
        # (pieces that glow in their own painted colour, not the Warden's glow colour: Sparkle's hazard bands, a faint
        # yellow that the match camera's far_emit lifts so they read at distance; the shader keeps yellow untinted)
        px = np.array(img.pixels[:], dtype=np.float32).reshape(h, w, 4)[..., :3]
        hh, ss, vv = _hsv_px(px)
        sel = face_mask(ob, img, lambda poly, c, mat: any(mat.startswith(x + "-") for x in ea["slots"]))
        k = np.zeros((h, w), bool)
        for q in ea["hsv"]:
            k |= (hh >= q[0]) & (hh <= q[1]) & (ss >= q[2]) & (ss <= q[3]) & (vv >= q[4]) & (vv <= q[5])
        k &= sel
        mask = np.where(k[..., None], np.clip(px * float(ea.get("gain", 0.3)), 0, 1), mask)
        log("emit from the atlas: %d texels" % int(k.sum()))
    out = np.ones((h, w, 4), np.float32)
    out[..., :3] = mask
    em = bpy.data.images.new("%s_emit" % ob.name.lower(), w, h, alpha=False)
    em.pixels = out.ravel()
    em.pack()
    for m in ob.data.materials:
        if m is None:
            continue
        nt = m.node_tree
        bsdf = nt.nodes.get("Principled BSDF")
        et = nt.nodes.new("ShaderNodeTexImage")
        et.image = em
        nt.links.new(et.outputs[0], bsdf.inputs["Emission Color"])
        bsdf.inputs["Emission Strength"].default_value = 1.0
    log("emit layer on %d materials, %d texels lit" % (len(ob.data.materials), int((mask.max(axis=2) > 0.05).sum())))


def _rel(arm, sp, keys):
    """A part spec whose points are given relative to a bone's head ("rel": bone name, the fitted frame) moved
    onto that bone: the lens and the braids ride the head, the hoses the hips, wherever the rig puts them."""
    if not sp or "rel" not in sp:
        return sp
    o = arm.data.bones[sp["rel"]].head_local
    out = dict(sp)
    for k in keys:
        v = sp[k]
        if v and isinstance(v[0], (list, tuple)):
            out[k] = [[p[0] + o.x, p[1] + o.y, p[2] + o.z] for p in v]
        else:
            out[k] = [v[0] + o.x, v[1] + o.y, v[2] + o.z]
    return out


def face_plate(ob, ps, warp_spec):
    """A plate drawn on a face sheet (Vex's angular brass eye plate; Meshy built a round one) as a decal mesh joined
    into the body in the Meshy frame: the outline (sheet px) mapped onto the mesh through the inverse of the face's
    warp, a grid inside it ray-cast onto the face, lifted `depth` m off it with a bevelled edge (`edge` px), and
    UV-mapped onto the sheet itself, so its rivets, panels and shading are the sheet's. Material "<slot>-plate"."""
    from mathutils.bvhtree import BVHTree
    img_path = os.path.expanduser(ps["image"])
    art = bpy.data.images.load(img_path)
    aw, ah = art.size
    inv = _tps_fit(warp_spec["art"], warp_spec["mesh"], float(warp_spec.get("smooth", 1e-3)))
    poly = np.asarray(ps["outline"], float)
    step = float(ps.get("step", 8.0))
    c0, r0 = np.floor(poly.min(axis=0)).astype(int)
    c1, r1 = np.ceil(poly.max(axis=0)).astype(int)
    cols = np.arange(c0, c1 + step, step)
    rows = np.arange(r0, r1 + step, step)
    gc, gr = np.meshgrid(cols, rows)
    inside = _pts_in_poly(np.stack([gc.ravel(), gr.ravel()], 1), poly).reshape(gc.shape)
    for hc, hr, rad in ps.get("holes", []):
        # (a hole where a part of its own shows through: the glowing lens dome)
        inside &= np.hypot(gc - hc, gr - hr) > rad
    # the distance of each grid point to the outline (px), for the bevel
    pts = np.stack([gc.ravel(), gr.ravel()], 1)
    dist = np.full(len(pts), 1e9)
    for a, b in zip(poly, np.roll(poly, -1, axis=0)):
        ab = b - a
        t = np.clip(((pts - a) @ ab) / max(ab @ ab, 1e-9), 0.0, 1.0)
        dist = np.minimum(dist, np.linalg.norm(pts - (a + np.outer(t, ab)), axis=1))
    dist = dist.reshape(gc.shape)
    xz = inv(pts).reshape(gc.shape + (2,))
    # (onto the face and its metal only: the bangs hang in front of the plate)
    names = [m.name for m in ob.data.materials]
    keep = tuple(x + "-" for x in ps.get("onto", ["skin", "metal", "glow"]))
    tree = BVHTree.FromPolygons([v.co.copy() for v in ob.data.vertices],
                                [p.vertices[:] for p in ob.data.polygons if names[p.material_index].startswith(keep)])
    depth, edge = float(ps.get("depth", 0.004)), float(ps.get("edge", 18.0))
    dome = _plate_dome(ob, ps.get("dome"), gc, gr, inside, xz, tree)
    vid = -np.ones(gc.shape, int)
    verts, uvs = [], []
    for i in range(gc.shape[0]):
        for j in range(gc.shape[1]):
            if not inside[i, j]:
                continue
            if dome is not None and dome["d"][i, j] < dome["r_out"]:
                p, n = dome["at"](i, j)
            else:
                x, z = xz[i, j]
                hit = tree.ray_cast(Vector((x, -1.0, z)), Vector((0.0, 1.0, 0.0)), 2.0)
                if hit[0] is None:
                    continue
                p, n = hit[0], (Vector(hit[1]) if hit[1].y < 0 else -Vector(hit[1]))
            k = min(1.0, dist[i, j] / edge)
            k = k * k * (3.0 - 2.0 * k)
            verts.append(p + n * (0.0006 + depth * k))
            uvs.append((gc[i, j] / aw, 1.0 - gr[i, j] / ah))
            vid[i, j] = len(verts) - 1
    faces, glowing = [], []
    gcirc = ps.get("glow_circles", [])
    for i in range(gc.shape[0] - 1):
        for j in range(gc.shape[1] - 1):
            q = [vid[i, j], vid[i, j + 1], vid[i + 1, j + 1], vid[i + 1, j]]
            if min(q) >= 0:
                faces.append((q[0], q[3], q[2], q[1]))
                # (a lens drawn on the sheet glows: its faces take the glow slot, same sheet texture)
                fc, fr = gc[i, j] + step * 0.5, gr[i, j] + step * 0.5
                glowing.append(any(math.hypot(fc - c, fr - r) < rad for c, r, rad in gcirc))
    me = bpy.data.meshes.new("Plate")
    me.from_pydata([tuple(v) for v in verts], [], faces)
    me.update()
    lay = me.uv_layers.new(name=ob.data.uv_layers.active.name)
    for poly_ in me.polygons:
        for li in poly_.loop_indices:
            lay.data[li].uv = uvs[me.loops[li].vertex_index]
    pl = bpy.data.objects.new("Plate", me)
    bpy.context.scene.collection.objects.link(pl)
    for poly_ in me.polygons:
        poly_.use_smooth = True
    art.pack()
    for slot in [ps.get("slot", "metal")] + (["glow"] if any(glowing) else []):
        m = bpy.data.materials.new("%s-plate" % slot)
        m.use_nodes = True
        bsdf = m.node_tree.nodes.get("Principled BSDF")
        tex = m.node_tree.nodes.new("ShaderNodeTexImage")
        tex.image = art
        m.node_tree.links.new(tex.outputs[0], bsdf.inputs["Base Color"])
        me.materials.append(m)
    for poly_, g in zip(me.polygons, glowing):
        poly_.material_index = 1 if g else 0
    # (the body's own materials first: joined, the plate's faces keep theirs)
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    pl.select_set(True)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.join()
    log("face plate: %d faces from %d outline points, %d glowing" % (len(faces), len(poly), sum(glowing)))


def _plate_dome(ob, dm, gc, gr, inside, xz, tree):
    """The lens a plate sheet draws, as a smooth dome (Vex r3f): Meshy sculpted a horn under it, which the decal
    draped into a green spike. Inside `r_out` px of the lens's centre the decal lies on the plane of the face
    just around the horn (fitted robustly to the hits `fit_skip`..`fit_out` px from the centre), bulging `height`
    m inside `r` px and blending back onto the face over the last `band` px; the scan's faces standing in front of
    that plane near the lens's axis (the horn) go, under the dome. (A wide fit fails: across the plate the face
    turns 5 cm away toward the temple, and rays through the bangs hit the back of the head.)"""
    if not dm:
        return None
    dc, dr = (float(v) for v in dm["centre"])
    r_in, r_out = float(dm["r"]), float(dm["r_out"])
    skip, f_out, band = float(dm.get("fit_skip", 85)), float(dm.get("fit_out", 115)), float(dm.get("band", 25))
    dpx = np.hypot(gc - dc, gr - dr)
    hits = {}
    for i, j in zip(*np.nonzero(inside & (dpx <= max(r_out, f_out)))):
        x, z = xz[i, j]
        hit = tree.ray_cast(Vector((x, -1.0, z)), Vector((0.0, 1.0, 0.0)), 2.0)
        if hit[0] is not None:
            hits[(i, j)] = (np.array(hit[0][:]), np.array((hit[1] if hit[1].y < 0 else -hit[1])[:]))
    pts = np.array([q for ij, (q, _n) in hits.items() if skip <= dpx[ij] <= f_out])
    if len(pts) < 8:
        log("plate dome: only %d hits to fit, no dome" % len(pts))
        return None
    keep = np.abs(pts[:, 1] - np.median(pts[:, 1])) < 0.02     # (rays past the face: the back of the head)
    for _r in range(4):
        pc = pts[keep].mean(axis=0)
        pn = np.linalg.svd(pts[keep] - pc)[2][2]
        res = (pts - pc) @ pn
        mad = float(np.median(np.abs(res[keep]))) * 1.48
        keep = np.abs(res) < max(2.5 * mad, 0.0015)
    pn = pn if pn[1] < 0 else -pn          # (toward the viewer, -Y)
    rms = float(np.sqrt(np.mean(((pts[keep] - pc) @ pn) ** 2)))

    def on_plane(x, z):
        return np.array([x, pc[1] - (pn[0] * (x - pc[0]) + pn[2] * (z - pc[2])) / pn[1], z])
    ci = np.unravel_index(int(np.argmin(np.where(inside, dpx, 1e9))), dpx.shape)
    c3 = on_plane(*xz[ci])
    # the horn: hits inside the fit's ring standing more than `stand` m in front of the plane; the cut its width
    stand, top, lat = float(dm.get("stand", 0.0025)), 0.0, []
    for ij, (q, _n) in hits.items():
        if dpx[ij] >= skip:
            continue
        a = float((q - c3) @ pn)
        top = max(top, a)
        if a > stand:
            d = q - c3
            lat.append(float(np.linalg.norm(d - pn * a)))
    r_cut = min(float(dm.get("cut_max", 0.016)), max(lat) + 0.002) if lat else 0.0
    n_cut = 0
    if r_cut > 0.0:
        bm = bmesh.new()
        bm.from_mesh(ob.data)
        drop = []
        for f in bm.faces:
            d = np.array(f.calc_center_median()[:]) - c3
            a = float(d @ pn)
            if a > -float(dm.get("cut_back", 0.0015)) and np.linalg.norm(d - pn * a) < r_cut:
                drop.append(f)
        n_cut = len(drop)
        bmesh.ops.delete(bm, geom=drop, context="FACES")
        bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
        bm.to_mesh(ob.data)
        bm.free()
    height = float(dm.get("height", 0.003))
    log("plate dome: plane on %d of %d hits (rms %.2f mm); the horn stood %.1f mm, %.1f mm wide: %d faces cut"
        % (int(keep.sum()), len(pts), rms * 1000, top * 1000, r_cut * 2000, n_cut))

    def at(i, j):
        x, z = xz[i, j]
        p, n = on_plane(x, z), pn.copy()
        t = min(1.0, dpx[i, j] / r_in)
        p = p + n * height * max(0.0, 1.0 - t * t)
        h = hits.get((i, j))
        w = (dpx[i, j] - (r_out - band)) / band
        if h is not None and w > 0.0 and abs(float((h[0] - c3) @ pn)) < 0.012:
            w = min(1.0, w)
            w = w * w * (3.0 - 2.0 * w)
            p = p * (1.0 - w) + h[0] * w
            n = n * (1.0 - w) + h[1] * w
            n = n / np.linalg.norm(n)
        return Vector(p), Vector(n)
    return {"d": dpx, "r_out": r_out, "at": at}


def _pts_in_poly(pts, poly):
    """Which points (n x 2) are inside a polygon (even-odd rule)."""
    x, y = pts[:, 0] + 1e-6, pts[:, 1] + 1e-6
    inside = np.zeros(len(pts), bool)
    for (x1, y1), (x2, y2) in zip(poly, np.roll(poly, -1, axis=0)):
        if y1 == y2:
            continue
        cross = ((y1 > y) != (y2 > y)) & (x < x1 + (y - y1) * (x2 - x1) / (y2 - y1))
        inside ^= cross
    return inside


def reslot(ob, img, rs):
    """Faces of one slot moved to another by their painted colour inside a box (after the paint-overs): Vex's gorget
    seams, painted green from the face sheet on the metal slot, onto the glow slot (the hair in front of them is the
    hair slot, so it never glows). rs: from, to, box [x0, x1, y0, y1, z0, z1] (null open), hsv [h0, h1, s0, s1, v0,
    v1] on the face's centre texel."""
    w, h = img.size
    px = np.array(img.pixels[:], dtype=np.float32).reshape(h, w, 4)
    uv = ob.data.uv_layers.active.data
    names = [m.name for m in ob.data.materials]
    to = next((i for i, n in enumerate(names) if n.startswith(rs["to"] + "-")), None)
    if to is None:
        # (a slot no rule gave, e.g. brass split off the metal: the source slot's material, same atlas)
        src = next(m for m in ob.data.materials if m.name.startswith(rs["from"] + "-"))
        m = src.copy()
        m.name = rs["to"] + "-" + src.name.split("-", 1)[1]
        ob.data.materials.append(m)
        to = len(ob.data.materials) - 1
    inf = float("inf")
    b = [(-inf if x is None else x) if i % 2 == 0 else (inf if x is None else x) for i, x in enumerate(rs["box"])]
    q = rs["hsv"]
    n = 0
    for p in ob.data.polygons:
        if not names[p.material_index].startswith(rs["from"] + "-"):
            continue
        c = p.center
        if not (b[0] <= c.x <= b[1] and b[2] <= c.y <= b[3] and b[4] <= c.z <= b[5]):
            continue
        u = sum(uv[i].uv.x for i in p.loop_indices) / p.loop_total
        v = sum(uv[i].uv.y for i in p.loop_indices) / p.loop_total
        hh, ss, vv = _hsv(px[min(h - 1, int(v * h)), min(w - 1, int(u * w)), :3])
        if q[0] <= hh <= q[1] and q[2] <= ss <= q[3] and q[4] <= vv <= q[5]:
            p.material_index = to
            n += 1
    log("reslot %s -> %s: %d faces" % (rs["from"], rs["to"], n))


def _rig_joint(rig, name):
    """A fit joint's place on the rig (fit spec joint names: hip.L, shoulder.L, neck, ...)."""
    bone = {"hip": "thigh", "shoulder": "upper_arm", "elbow": "forearm", "hand": "hand", "knee": "shin"}
    if name == "neck":
        return K.bone_head(rig, "head")
    if name == "pelvis":
        return K.bone_head(rig, "hips")
    part, side = name.split(".")
    return K.bone_head(rig, "%s.%s" % (bone[part], side))


def grow_slot(ob, g):
    """A part Meshy made too small (Cinder's fin-crest, a fan that hides behind her skull): the vertices of the
    faces on slot `slot` within `box` (Meshy's frame, [x0, x1, y0, y1, z0, z1], null open) are pushed away from
    `centre` by up to `k`, eased in from `r0` to `r1` metres out so the part's base stays on the body."""
    names = [m.name for m in ob.data.materials]
    vs = set()
    for p in ob.data.polygons:
        if names[p.material_index].startswith(g["slot"] + "-"):
            vs.update(p.vertices)
    b = [(-1e9 if x is None else x) if i % 2 == 0 else (1e9 if x is None else x) for i, x in enumerate(g.get("box") or [None] * 6)]
    c = Vector(g["centre"])
    k, r0, r1 = float(g["k"]), float(g["r0"]), float(g["r1"])
    n = 0
    for vi in vs:
        v = ob.data.vertices[vi]
        q = v.co
        if not (b[0] <= q.x <= b[1] and b[2] <= q.y <= b[3] and b[4] <= q.z <= b[5]):
            continue
        d = (q - c).length
        t = min(1.0, max(0.0, (d - r0) / max(r1 - r0, 1e-6)))
        t = t * t * (3.0 - 2.0 * t)
        if t > 0.0:
            v.co = c + (q - c) * (1.0 + (k - 1.0) * t)
            n += 1
    ob.data.update()
    log("grow %s: %d vertices, x%.2f" % (g["slot"], n, k))


def tail_chain(ob, arm, ts):
    """The tail on a spring chain (RIG_CONTRACT "Spring chains"): `bones` spring_tail_<i> bones under the hips along
    the posed tail's own centreline (the middle of its vertices per stretch of "tail_s"), each tail vertex between
    the two nearest, the root's first `blend` metres eased in from the hips so the tail grows out of them."""
    import warden_parts as WP
    a = ob.data.attributes.get("tail_s")
    n = len(ob.data.vertices)
    s = np.zeros(n, np.float32)
    a.data.foreach_get("value", s)
    sel = np.nonzero(s >= 0.0)[0]
    co = np.array([v.co[:] for v in ob.data.vertices])
    L = float(s[sel].max())
    nb = int(ts.get("bones", 7))
    k = max(nb * 3, 12)
    pts = []
    for i in range(k + 1):
        lo, hi = L * (i - 0.5) / k, L * (i + 0.5) / k
        m = sel[(s[sel] >= lo) & (s[sel] < hi)]
        if len(m):
            pts.append(co[m].mean(axis=0))
    p = np.array(pts)
    pj = np.linspace(0.0, L, len(p))           # (each centreline point's marked arc length)
    rot = None
    if ts.get("curl"):
        p, rot = _curl(ob, sel, s, co, p, pj, ts["curl"])
        co = np.array([v.co[:] for v in ob.data.vertices])
    tip = co[sel[np.argmax(s[sel])]]
    names, spans = WP.chain_bones(arm, "tail", "hips", p, L, nb, tip)
    for g in ob.vertex_groups:
        g.remove([int(i) for i in sel])
    # (the chain's own arc lengths: the posed centreline is a little shorter than the marked one)
    Lp = float(WP.arclen(p)[-1])
    WP.weights(ob, [(int(vi), float(s[vi]) * Lp / L) for vi in sel], names, spans)
    blend = float(ts.get("blend", 0.12))
    hips = ob.vertex_groups.get("hips") or ob.vertex_groups.new(name="hips")
    gi = {g.index: g for g in ob.vertex_groups}
    for vi in sel:
        t = float(np.clip(s[vi] / blend, 0.0, 1.0)) if blend > 0 else 1.0
        if t >= 1.0:
            continue
        for x in ob.data.vertices[int(vi)].groups:
            gi[x.group].add([int(vi)], x.weight * t, "REPLACE")
        hips.add([int(vi)], 1.0 - t, "ADD")
    log("tail chain: %d bones over %.2f m, %d vertices" % (nb, Lp, len(sel)))
    if not ts.get("fin"):
        return None
    # a fin along the tail's ridge (the crest's rays carried on: Cinder r3), on the same chain
    fs = ts["fin"]
    f0, f1 = fs.get("span", [0.15, 0.97])
    ks = [i for i in range(len(p)) if f0 * L <= pj[i] <= f1 * L]
    base, ups, sa = [], [], []
    for i in ks:
        up = rot[i] @ np.array([0.0, 0.0, 1.0]) if rot is not None else np.array([0.0, 0.0, 1.0])
        m = sel[np.abs(s[sel] - pj[i]) < L / k]
        if not len(m):
            continue
        top = float(((co[m] - p[i]) @ up).max())
        base.append(p[i] + up * (top - float(fs.get("sink", 0.012))))
        ups.append(up)
        sa.append(pj[i] * Lp / L)
    bld = WP.Builder()
    WP.ribbon_fin(bld, WP.resample(np.array(base), int(fs.get("samples", 90)))[0],
                  _resample_dirs(np.array(ups), int(fs.get("samples", 90))),
                  np.linspace(sa[0], sa[-1], int(fs.get("samples", 90))), fs)
    fin = bld.object("TailFin")
    img = bpy.data.images.new("tailfin_atlas", WP.MEM_TEX, WP.MEM_TEX, alpha=False)
    img.pixels = WP.membrane_atlas(ts["fin_atlas"]).ravel()
    img.pack()
    mi = WP._mats(fin, img, ("fur", "glow"), "tailfin")
    for poly in fin.data.polygons:
        poly.material_index = mi["glow"] if all(bld.part[v] == "edge" for v in poly.vertices) else mi["fur"]
    WP.weights(fin, [(vi, bld.s[vi]) for vi in range(len(bld.v))], names, spans)
    fin.parent = arm
    mod = fin.modifiers.new("Armature", "ARMATURE")
    mod.object = arm
    log("tail fin: %d tris" % sum(len(f) - 2 for f in bld.f))
    return fin


def drop_slot(ob, rule):
    """The faces of slot `slot` whose centre is inside `box` (Meshy's frame) removed: a part rebuilt as geometry
    (Cinder's fin-crest on the head: a fan of rays now, fit spec "fins")."""
    names = [m.name for m in ob.data.materials]
    b = [(-1e9 if x is None else x) if i % 2 == 0 else (1e9 if x is None else x) for i, x in enumerate(rule["box"])]
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    gone = [f for f in bm.faces if names[f.material_index].startswith(rule["slot"] + "-")
            and b[0] <= f.calc_center_median().x <= b[1] and b[2] <= f.calc_center_median().y <= b[3]
            and b[4] <= f.calc_center_median().z <= b[5]]
    bmesh.ops.delete(bm, geom=gone, context="FACES")
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    bm.to_mesh(ob.data)
    bm.free()
    ob.data.update()
    log("drop %s: %d faces" % (rule["slot"], len(gone)))


def _curl(ob, sel, s, co, p, pj, cs):
    """The tail curled up into a loop (Cinder's art): from arc length `from` on, the centreline bends about the
    horizontal axis across it there by 1/`radius` a metre, up to `turn` degrees, and every tail vertex goes with
    its stretch of the centreline (its offset turned the same). Returns the new centreline and each point's turn."""
    s0, rho, turn = float(cs["from"]), float(cs["radius"]), math.radians(float(cs["turn"]))
    i0 = int(np.searchsorted(pj, s0))
    t0 = p[min(i0 + 1, len(p) - 1)] - p[max(i0 - 1, 0)]
    t0[2] = 0.0
    t0 /= max(np.linalg.norm(t0), 1e-9)
    axis = np.cross(t0, np.array([0.0, 0.0, 1.0]))          # (the tangent turns from t0 toward up)
    th = np.clip((pj - s0) / rho, 0.0, turn)
    rot = [_rotm(axis, a) for a in th]
    q = p.copy()
    for i in range(1, len(p)):
        q[i] = q[i - 1] + rot[i] @ (p[i] - p[i - 1])
    lift = float(cs.get("lift", 0.0))
    for i in range(len(q)):
        q[i, 2] += lift * min(1.0, max(0.0, (pj[i] - s0) / max(rho, 1e-6)))
    # each vertex: its offset from the old centreline at its arc length, turned and put on the new one
    for vi in sel:
        x = float(s[vi])
        i = int(np.clip(np.searchsorted(pj, x), 1, len(p) - 1))
        f = (x - pj[i - 1]) / max(pj[i] - pj[i - 1], 1e-9)
        old = p[i - 1] * (1 - f) + p[i] * f
        new = q[i - 1] * (1 - f) + q[i] * f
        a = th[i - 1] * (1 - f) + th[i] * f
        ob.data.vertices[int(vi)].co = Vector(new + _rotm(axis, a) @ (co[vi] - old))
    ob.data.update()
    log("tail curl: from %.2f m, radius %.2f m, %.0f degrees" % (s0, rho, math.degrees(float(th.max()))))
    return q, rot


def _rotm(axis, ang):
    axis = axis / np.linalg.norm(axis)
    x, y, z = axis
    c, s_, C = math.cos(ang), math.sin(ang), 1 - math.cos(ang)
    return np.array([[c + x * x * C, x * y * C - z * s_, x * z * C + y * s_],
                     [y * x * C + z * s_, c + y * y * C, y * z * C - x * s_],
                     [z * x * C - y * s_, z * y * C + x * s_, c + z * z * C]])


def _resample_dirs(d, n):
    """Unit directions resampled evenly along their index to n."""
    x = np.linspace(0, len(d) - 1, n)
    out = np.stack([np.interp(x, np.arange(len(d)), d[:, i]) for i in range(3)], axis=1)
    return out / np.maximum(np.linalg.norm(out, axis=1, keepdims=True), 1e-9)


def tail_to_hips(ob):
    """The tail rides the hips rigidly through the fit's pose (bone heat hands its ground loop to the shins)."""
    a = ob.data.attributes.get("tail_s")
    if a is None:
        return
    s = np.zeros(len(ob.data.vertices), np.float32)
    a.data.foreach_get("value", s)
    idx = [int(i) for i in np.nonzero(s >= 0.0)[0]]
    for g in ob.vertex_groups:
        g.remove(idx)
    g = ob.vertex_groups.get("hips") or ob.vertex_groups.new(name="hips")
    g.add(idx, 1.0, "REPLACE")


def tail_mark(ob, ts, m):
    """A tail (Cinder): the vertices within `r` of its centreline (`path`, Meshy's frame, root first; moved into
    the fitted frame by the fit's own transform) and behind `y_cut` (the fitted frame: front +Y) get their arc
    length along it in the point attribute "tail_s" (-1 elsewhere), which rides the pose and the decimation."""
    path = np.array([(m @ Vector(p))[:] for p in ts["path"]])
    co = np.array([v.co[:] for v in ob.data.vertices])
    s, d = _tail_s(co, path)
    sel = (d < float(ts.get("r", 0.2))) & (co[:, 1] < float(ts.get("y_cut", -0.08)))
    a = ob.data.attributes.get("tail_s") or ob.data.attributes.new("tail_s", "FLOAT", "POINT")
    a.data.foreach_set("value", np.where(sel, s, -1.0).astype(np.float32))
    log("tail: %d vertices, %.2f m along" % (int(sel.sum()), float(s[sel].max()) if sel.any() else 0.0))


def _tail_s(co, path):
    """Each point's arc length along a polyline and its distance from it (nearest segment)."""
    seg = path[1:] - path[:-1]
    ln = np.linalg.norm(seg, axis=1)
    s0 = np.concatenate([[0.0], np.cumsum(ln)])[:-1]
    best_d = np.full(len(co), np.inf)
    best_s = np.zeros(len(co))
    for i in range(len(seg)):
        t = np.clip(((co - path[i]) @ seg[i]) / max(ln[i] ** 2, 1e-9), 0.0, 1.0)
        q = path[i] + t[:, None] * seg[i]
        d = np.linalg.norm(co - q, axis=1)
        better = d < best_d
        best_d[better] = d[better]
        best_s[better] = s0[i] + t[better] * ln[i]
    return best_s, best_d



def deform(ob, items):
    """Reshape the scan's body before the rig fit (Meshy frame: +Z up, facing -Y, his right -X): each item moves
    and scales the vertices within `r` of its centre `c`, by a smooth fall-off (1 at the centre, 0 at r), so a
    bulge (Kael's oversized trapezius and deltoids, the hump behind his neck) shrinks without a seam. `move`
    [dx, dy, dz] m; `scale` [sx, sy, sz] about the centre; `mirror_x` repeats it on the other side."""
    co = np.array([v.co[:] for v in ob.data.vertices])
    for it in items:
        cs = [np.array(it["c"], float)]
        if it.get("mirror_x"):
            cs.append(cs[0] * np.array([-1.0, 1.0, 1.0]))
        for c in cs:
            sgn = np.sign(c[0]) if it.get("mirror_x") and c[0] != 0 else 1.0
            mv = np.array(it.get("move", [0, 0, 0]), float) * np.array([sgn, 1.0, 1.0])
            sc = np.array(it.get("scale", [1, 1, 1]), float)
            r = float(it["r"])
            d = np.linalg.norm(co - c, axis=1)
            w = np.clip(1.0 - (d / r) ** 2, 0.0, 1.0) ** 2
            n = int((w > 0).sum())
            co = co + w[:, None] * (mv + (co - c) * (sc - 1.0))
            log("deform: %d verts at %s (r %.2f)" % (n, tuple(np.round(c, 3)), r))
    for v, p in zip(ob.data.vertices, co):
        v.co = p
    ob.data.update()


def cut_strands(ob, img, cs):
    """(From ext/warden-meshy-pin.) Hair strands Meshy hung in front of the face (they cross the mask in the 3/4 view): dark-painted faces in the
    face's box (Meshy frame, front -Y) lying in front of the face's own surface (the nearest light-painted
    vertices in the front view, `gap` m) are removed."""
    w, h = img.size
    px = np.array(img.pixels[:], dtype=np.float32).reshape(h, w, 4)
    me = ob.data
    uv = me.uv_layers.active.data
    x0, x1, z0, z1 = cs["box"]
    co = np.array([v.co[:] for v in me.vertices])
    vcol = np.zeros(len(co))
    vn = np.zeros(len(co))
    dark = []
    for p in me.polygons:
        u = sum(uv[i].uv.x for i in p.loop_indices) / p.loop_total
        v = sum(uv[i].uv.y for i in p.loop_indices) / p.loop_total
        lum = float(px[min(h - 1, max(0, int(v * h))), min(w - 1, max(0, int(u * w))), :3].mean())
        for i in p.vertices:
            vcol[i] += lum
            vn[i] += 1
        c = p.center
        if lum < float(cs.get("dark", 0.2)) and x0 <= c.x <= x1 and z0 <= c.z <= z1:
            dark.append(p.index)
    vlum = vcol / np.maximum(vn, 1)
    inbox = (co[:, 0] >= x0) & (co[:, 0] <= x1) & (co[:, 2] >= z0) & (co[:, 2] <= z1)
    face = co[inbox & (vlum > float(cs.get("light", 0.45)))]
    gap = float(cs.get("gap", 0.004))
    drop = []
    for i in dark:
        c = me.polygons[i].center
        dd = np.hypot(face[:, 0] - c.x, face[:, 2] - c.z)
        if len(dd) and dd.min() < 0.015 and c.y < face[int(np.argmin(dd)), 1] - gap:
            drop.append(i)
    bm = bmesh.new()
    bm.from_mesh(me)
    bm.faces.ensure_lookup_table()
    bmesh.ops.delete(bm, geom=[bm.faces[i] for i in drop], context="FACES")
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    bm.to_mesh(me)
    bm.free()
    log("cut %d strand faces in front of the face" % len(drop))


def lengthen(ob, img, ln):
    """A long coat drawn longer than the scan's (Hem: mid-calf with an asymmetric tail): the vertices of the coat's
    faces (painted in one of `hsv`, outside the legs' own radius `leg_r` round each leg's line) below `from_z`
    (fitted frame, soles on 0) move down, by `k` x their drop below from_z, `k_back` at the back (-Y) and more on
    the `tail` side (+X her right, -X her left) for the asymmetric tail."""
    w, h = img.size
    px = np.array(img.pixels[:], dtype=np.float32).reshape(h, w, 4)
    me = ob.data
    uv = me.uv_layers.active.data
    coat = np.zeros(len(me.vertices), bool)
    for p in me.polygons:
        u = sum(uv[i].uv.x for i in p.loop_indices) / p.loop_total
        v = sum(uv[i].uv.y for i in p.loop_indices) / p.loop_total
        hh, ss, vv = _hsv(px[min(h - 1, int(v * h)), min(w - 1, int(u * w)), :3])
        if any((q[0] <= hh <= q[1] if q[0] <= q[1] else (hh >= q[0] or hh <= q[1])) and q[2] <= ss <= q[3]
               and q[4] <= vv <= q[5] for q in ln["hsv"]):
            coat[list(p.vertices)] = True
    co = np.array([v.co[:] for v in me.vertices])
    z0 = float(ln["from_z"])
    legs = [np.array(x) for x in ln["legs"]]
    off_leg = np.ones(len(co), bool)
    for lx in legs:
        off_leg &= np.hypot(co[:, 0] - lx[0], co[:, 1] - lx[1]) > float(ln.get("leg_r", 0.075))
    sel = coat & off_leg & (co[:, 2] < z0)
    back = np.clip(-co[:, 1] / 0.12, 0.0, 1.0)
    tail = np.clip(co[:, 0] * float(ln.get("tail", 1.0)) / 0.15, 0.0, 1.0)
    k = float(ln["k"]) + (float(ln.get("k_back", ln["k"])) - float(ln["k"])) * back + float(ln.get("k_tail", 0.0)) * tail * back
    drop = (z0 - co[:, 2]) * k
    co[sel, 2] = np.maximum(co[sel, 2] - drop[sel], float(ln.get("floor", 0.12)))     # (the coat only)
    fl = float(ln.get("flare", 0.0))
    if fl > 0.0:
        # (the hem flares out from the body's axis as it falls: the art's long coat swings wide below the knees)
        rad = np.hypot(co[sel, 0], co[sel, 1])
        k_out = 1.0 + fl * drop[sel] / np.maximum(rad, 0.05)
        co[sel, 0] *= k_out
        co[sel, 1] *= k_out
    me.vertices.foreach_set("co", co.ravel())
    me.update()
    if ln.get("hem_colour"):
        # (the scan's dark dagged hem and lining, stretched, read as a zig-zag: the stretched coat's dark texels
        # take the coat's colour)
        moved = set(np.nonzero(sel)[0].tolist())
        col = np.array(K.hexcol(ln["hem_colour"]), np.float32)
        m = face_mask(ob, img, lambda poly, c, mat: all(v in moved for v in poly.vertices))
        q = px[..., :3]
        dark = m & (q.max(axis=2) < float(ln.get("hem_val", 0.22)))
        q[dark] = col * (0.75 + 0.5 * q[dark].max(axis=1, keepdims=True) / max(float(ln.get("hem_val", 0.22)), 1e-3))
        px[..., :3] = q
        img.pixels = px.ravel()
        log("hem: %d dark texels to the coat's colour" % int(dark.sum()))
    log("lengthened the coat: %d vertices" % int(sel.sum()))


def tape_bands(ob, img, tb):
    """A cloth wrap read as wrapped tape (Hem's tape-measure forearm wraps): the faces of the wrap's colour in each
    box (the Meshy frame) are banded along the limb, every other `period` m of height a little darker, with a thin
    dark line between bands."""
    w, h = img.size
    px = np.array(img.pixels[:], dtype=np.float32).reshape(h, w, 4)
    me = ob.data
    uv = me.uv_layers.active.data
    per = float(tb.get("period", 0.012))
    n = 0
    for bx in tb["boxes"]:
        def pick(poly, c, mat, bx=bx):
            if not (bx[0] <= c.x <= bx[1] and bx[2] <= c.y <= bx[3] and bx[4] <= c.z <= bx[5]):
                return False
            u = sum(uv[i].uv.x for i in poly.loop_indices) / poly.loop_total
            v = sum(uv[i].uv.y for i in poly.loop_indices) / poly.loop_total
            hh, ss, vv = _hsv(px[min(h - 1, int(v * h)), min(w - 1, int(u * w)), :3])
            q = tb["hsv"]
            return q[0] <= hh <= q[1] and q[2] <= ss <= q[3] and q[4] <= vv <= q[5]
        for band in (0, 1):
            def pb(poly, c, mat, band=band, pick=pick):
                return pick(poly, c, mat) and int(math.floor(c.z / per)) % 2 == band
            m = face_mask(ob, img, pb)
            k = float(tb.get("dark", 0.8)) if band else 1.0
            px[m, :3] = px[m, :3] * k
            n += int(m.sum())
    img.pixels = px.ravel()
    log("tape bands: %d texels" % n)


def split_off_faces(ob, faces, name):
    """These faces (indices) of ob become their own object (vertex weights kept)."""
    me = ob.data
    keep = set(faces)
    mine = me.copy()
    bm = bmesh.new()
    bm.from_mesh(mine)
    bm.faces.ensure_lookup_table()
    bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.index not in keep], context="FACES")
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    bm.to_mesh(mine)
    bm.free()
    bm = bmesh.new()
    bm.from_mesh(me)
    bm.faces.ensure_lookup_table()
    bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.index in keep], context="FACES")
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    bm.to_mesh(me)
    bm.free()
    out = bpy.data.objects.new(name, mine)
    bpy.context.scene.collection.objects.link(out)
    return out


def split_piece(ob, img, pc):
    """A piece the art draws as its own object (Hem's porcelain half-mask over her nose and mouth) comes off the
    body as its own skinned mesh: the faces inside `box` (the fitted frame) facing `facing` or more toward the
    front (+Y), painted in one of the `hsv` ranges [h0, h1, s0, s1, v0, v1]; the selection is closed `close` face
    rings (the red stitches, the painted lips inside it) and its largest connected part kept. It is pushed `push`
    m out along its normals (a lip off the face) and goes on its own material `<slot>-<name>` (same atlas)."""
    w, h = img.size
    px = np.array(img.pixels[:], dtype=np.float32).reshape(h, w, 4)
    me = ob.data
    uv = me.uv_layers.active.data
    b = pc["box"]
    pick = set()
    for p in me.polygons:
        c = p.center
        if not (b[0] <= c.x <= b[1] and b[2] <= c.y <= b[3] and b[4] <= c.z <= b[5]):
            continue
        if p.normal.y < float(pc.get("facing", -1.0)):
            continue
        u = sum(uv[i].uv.x for i in p.loop_indices) / p.loop_total
        v = sum(uv[i].uv.y for i in p.loop_indices) / p.loop_total
        hh, ss, vv = _hsv(px[min(h - 1, max(0, int(v * h))), min(w - 1, max(0, int(u * w))), :3])
        if any((q[0] <= hh <= q[1] if q[0] <= q[1] else (hh >= q[0] or hh <= q[1])) and q[2] <= ss <= q[3]
               and q[4] <= vv <= q[5] for q in pc["hsv"]):
            pick.add(p.index)
    bm = bmesh.new()
    bm.from_mesh(me)
    bm.faces.ensure_lookup_table()

    def nbrs(i):
        return {g.index for e in bm.faces[i].edges for g in e.link_faces if g.index != i}

    def inbox(i):
        c = bm.faces[i].calc_center_median()
        return b[0] <= c.x <= b[1] and b[2] <= c.y <= b[3] and b[4] <= c.z <= b[5]
    n = int(pc.get("close", 2))
    for _k in range(n):
        pick |= {j for i in list(pick) for j in nbrs(i) if inbox(j)}
    for _k in range(n):
        pick = {i for i in pick if nbrs(i) <= pick or len(nbrs(i) - pick) <= 1}
    # the largest connected part
    left, best = set(pick), set()
    while left:
        seed = left.pop()
        comp, stack = {seed}, [seed]
        while stack:
            for j in nbrs(stack.pop()):
                if j in left:
                    left.discard(j)
                    comp.add(j)
                    stack.append(j)
        if len(comp) > len(best):
            best = comp
    bm.free()
    piece = split_off_faces(ob, best, pc["name"])
    for g in ob.vertex_groups:
        piece.vertex_groups.new(name=g.name)
    piece.parent = ob.parent
    for md in ob.modifiers:
        if md.type == "ARMATURE":
            nm = piece.modifiers.new(md.name, "ARMATURE")
            nm.object = md.object
    pm = piece.data
    pm.update()
    push = float(pc.get("push", 0.003))
    for vx in pm.vertices:
        vx.co = vx.co + vx.normal * push
    mat = slot_materials(img, [pc["slot"]], pc["name"])[pc["slot"]]
    pm.materials.clear()
    pm.materials.append(mat)
    for p in pm.polygons:
        p.material_index = 0
    log("piece %s: %d faces" % (pc["name"], len(pm.polygons)))
    return piece


def main():
    spec_path = sys.argv[sys.argv.index("--") + 1]
    spec = json.load(open(spec_path))
    K.reset()
    rig = K.load_rig(os.path.join(ROOT, spec["rig"]))
    ob = import_glb(os.path.expanduser(spec["body_glb"]))
    img = base_image(ob)
    drop_floaters(ob, spec.get("floater_verts", 40))
    if spec.get("cut_boxes"):
        delete_boxes(ob, spec["cut_boxes"])     # (in Meshy's frame: a strand it floats in front of the face)
    if "cut_strands" in spec:
        cut_strands(ob, img, spec["cut_strands"])
        drop_floaters(ob, spec.get("floater_verts", 40))
    ids = island_map(ob, img)
    paint_up(img, spec, ids=ids)
    for pj in spec.get("project", []):
        project(ob, img, pj)
    pad(img, ids, int(spec.get("pad", 6)))
    if "slot_rules" in spec:
        slot_rules(ob, img, spec["slot_rules"], spec["glow_min"], "body", vote=spec.get("slot_vote", "island"))
        for g in spec.get("grow", []):
            grow_slot(ob, g)
    else:
        slot_split(ob, img, spec["palette"], spec["glow_min"], "body")
    if spec.get("touch_up"):
        touch_up(ob, img, spec["touch_up"])
        pad(img, ids, int(spec.get("pad", 6)))       # (the touched islands' new colour into their margins too)
    if spec.get("smooth"):
        sm = spec["smooth"]
        smooth_atlas(img, ids, int(sm.get("iterations", 2)), float(sm.get("sigma_s", 2.0)), float(sm.get("sigma_r", 0.07)))
    if spec.get("ramps"):
        ramp_paint(ob, img, spec["ramps"])
        for _i in range(int(spec.get("despeckle", 0))):
            # (lone texels the ramps left, a green fleck on a black edge: a 3x3 median within each island)
            flatten(img, np.zeros((1, 3), np.float32), 0.0, ids=ids)
        pad(img, ids, int(spec.get("pad", 6)))
    if spec.get("project_late"):
        # the art painted over the finished atlas (the face, the chest's straps and tattoos): after the ramps,
        # so its colours stay the art's; each with a registration measured on the mesh's own render
        for pj in spec["project_late"]:
            project(ob, img, pj)
        pad(img, ids, int(spec.get("pad", 6)))
        pad(img, ids, int(spec.get("pad", 6)))
    if spec.get("touch_up_late"):
        touch_up(ob, img, spec["touch_up_late"])
        pad(img, ids, int(spec.get("pad", 6)))
    for pj in spec.get("project_after", []):
        # (after the clean-up: crisp tattoo lines on the clean skin, `line` mode; `stamp`: the art's lines as
        # vector strokes of one width)
        if pj.get("mode") == "stamp":
            stamp_lines(ob, img, pj)
        else:
            project(ob, img, pj)
    for rs in spec.get("reslot_late", []):
        reslot(ob, img, rs)
    if spec.get("plate"):
        face = next(pj for pj in spec["project_late"] if pj.get("name") == spec["plate"].get("warp_from", "face"))
        face_plate(ob, spec["plate"], face["warp"])
    for pa in spec.get("paint_art", []):
        paint_art(ob, img, pa)
    if spec.get("fishnet"):
        net_paint(ob, img, spec["fishnet"])
    emask = emit_art(ob, img, spec["emit_art"]) if spec.get("emit_art") else None
    if spec.get("tape_bands"):
        tape_bands(ob, img, spec["tape_bands"])
        pad(img, ids, int(spec.get("pad", 6)))
    if spec.get("deform"):
        deform(ob, spec["deform"])
    head = None
    if "head" in spec:
        decimate(ob, spec["max_tris"] - int(spec["head"]["tris"]))
        head = head_pass(ob, spec)
    joints = {k: Vector(v) for k, v in spec["joints"].items()}
    # face +Y, hips on the rig's height, feet on the ground, centred between the hips
    turn = Matrix.Rotation(math.radians(spec.get("turn", 180.0)), 4, "Z")
    co = np.array([v.co[:] for v in ob.data.vertices])
    # (a hovering body with no feet, Ostra: where its ground would be, below the hem; else its lowest point)
    sole = float(spec["sole_z"]) if "sole_z" in spec else float(co[:, 2].min())
    hip_mid = (joints["hip.L"] + joints["hip.R"]) * 0.5
    if "scale_joints" in spec:
        # (a body whose proportions differ from the rig's: the span between two joints, e.g. hip to shoulder, gets
        # the rig's length, and the pose compresses or stretches the rest; scaling by the hips' height instead
        # would stretch a long-legged body's torso and arms)
        a, b = spec["scale_joints"]
        k = (_rig_joint(rig, b).z - _rig_joint(rig, a).z) / (joints[b].z - joints[a].z)
    else:
        k = K.bone_head(rig, "thigh.L").z / (hip_mid.z - sole)
    m = Matrix.Scale(k, 4) @ turn @ Matrix.Translation(Vector((-hip_mid.x, -hip_mid.y, -sole)))
    transform(ob, m)
    ob["meshy_to_fit"] = [x for row in m for x in row]     # (scripted pieces placed from the art's views)
    if head:
        transform(head, m)
    joints = {n: snap(ob, m @ p, spec.get("snap_r", 0.045), not spec.get("snap_y", True)) for n, p in joints.items()}
    gun = None
    if "gun_arm" in spec:
        gun, ge, gt = gun_arm(ob, spec["gun_arm"], m)
        if spec.get("delete_boxes"):
            delete_boxes(ob, spec["delete_boxes"])      # (the fitted frame: her right +X, front +Y, soles on 0)
        drop_floaters(ob, int(spec["gun_arm"].get("loose_verts", 1500)))     # (bits the cut left hanging)
        if "glow_min" in spec["gun_arm"]:
            reglow(gun, img, spec["gun_arm"]["glow_min"])
            if "glow_colour" in spec["gun_arm"]:
                touch_up(gun, img, [{"mode": "paint", "slot": "glow", "colour": spec["gun_arm"]["glow_colour"]}])
        if "slot" in spec["gun_arm"]:
            one_slot(gun, spec["gun_arm"]["slot"])

    joints["pelvis"] = (joints["hip.L"] + joints["hip.R"]) * 0.5
    log("scale %.3f; joints:" % k, {n: tuple(round(x, 3) for x in p) for n, p in joints.items()})
    # into the contract's rest pose
    rj = {
        "pelvis": K.bone_head(rig, "hips"), "neck": K.bone_head(rig, "head"),
        "crown": K.bone_head(rig, "head") + Vector((0, 0, rig["land"]["crown"] - K.bone_head(rig, "head").z)),
    }
    for sd in ("L", "R"):
        rj["shoulder." + sd] = K.bone_head(rig, "upper_arm." + sd)
        rj["elbow." + sd] = K.bone_head(rig, "forearm." + sd)
        rj["hand." + sd] = K.bone_head(rig, "hand." + sd)
        rj["hip." + sd] = K.bone_head(rig, "thigh." + sd)
        rj["knee." + sd] = K.bone_head(rig, "shin." + sd)
        # (ankle_z: a skate or a heel stands the ankle higher than a flat foot: Claire's boot and blade are
        # ~0.2 m below it; at 0.06 they went through the ground)
        rj["ankle." + sd] = Vector((rj["knee." + sd].x, rj["knee." + sd].y, float(spec.get("ankle_z", 0.06))))
        rj["fingers." + sd] = rj["hand." + sd] + Vector((0, 0, -0.08))
    if "tail" in spec:
        tail_mark(ob, spec["tail"], m)
    fit = fit_armature(joints)
    auto_weights(ob, fit)
    if spec.get("weight_rules"):
        weight_rules(ob, img, spec["weight_rules"])
    if "tail" in spec:
        tail_to_hips(ob)
    if spec.get("fit_weights"):
        keep_weights(ob)
    if head:
        rigid(head, fit, "head")
    pose_to_rig(fit, rj)
    if head:
        _apply_armature(head)
    apply_pose(ob, fit)
    decimate(ob, spec["max_tris"] - (int(spec["head"]["tris"]) if head else 0))
    if spec.get("lengthen"):
        lengthen(ob, img, spec["lengthen"])
    ob.name = "Body"
    ob.data.name = "Body"
    arm = contract_skin(ob, rig)
    if spec.get("fit_weights"):
        fit_weights(ob, arm)
    if spec.get("weight_rules_late"):
        # (the same on the contract's rest pose, the frame the game skins: arms straight down, the boxes read
        # off the exported model; Ostra's glove fingers that bone heat gave to the thigh beside them stretched
        # into a sheet from his hip to his raised orb hand)
        weight_rules(ob, img, spec["weight_rules_late"])
    if spec.get("arm_reach"):
        arm_reach(ob, arm, spec["arm_reach"])
    if spec.get("cut_straddle"):
        cut_straddle(ob, spec["cut_straddle"])
    if "gun_arm" in spec:
        release(ob, spec["gun_arm"].get("bones", ["forearm.R", "hand.R"]))
    if "chunk" in spec:
        chunk(ob, rig, spec["chunk"])
    for sb in spec.get("shrink", []):
        shrink_box(ob, sb)
    if spec.get("cut_fitted"):
        # (the fitted rest pose: a piece the scan has that is rebuilt as geometry, Pip's tail)
        delete_boxes(ob, spec["cut_fitted"])
        drop_floaters(ob, int(spec.get("cut_floaters", 60)))
    for hs in spec.get("hair_springs", []):
        hair_spring(ob, arm, _rel(arm, hs, ("top", "bottom", "box_lo", "box_hi")))
    tail_fin = None
    if "tail" in spec:
        sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
        tail_fin = tail_chain(ob, arm, spec["tail"])
    parts = [tail_fin] if tail_fin else []
    extras = []         # (empties: an orbit's pivot, an empty weapon)
    if spec.get("weapon_empty"):
        # (a Warden whose weapon is part of the body, Tarek's stone bracers: an empty `weapon`, so WardenGlb hides
        # the procedural one and the Gun node, its Muzzle and grips stay as they are)
        we = bpy.data.objects.new("weapon", None)
        bpy.context.scene.collection.objects.link(we)
        we.parent = arm
        extras.append(we)
    if any(spec.get(k) for k in ("lens", "braids", "hoses", "orbits", "halo", "wisp", "studs", "orb", "gauntlets", "claws")):
        sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
        import warden_parts as WP
        lens_s = _rel(arm, spec.get("lens"), ("centre",))
        if lens_s:
            # ("geometry": false when the face sheet's own lens is the plate decal's: the anchor stays for the halo)
            if lens_s.get("geometry", True):
                if lens_s.get("cut_r"):
                    _cut_lens(ob, lens_s)
                parts.append(WP.lens(arm, lens_s))
            # (an anchor on the lens: the game hangs the lens's match-zoom halo on it, warden_look.json "halos")
            K.anchor(arm, "head", "anchor_" + lens_s.get("anchor", "lens"), tuple(lens_s["centre"]))
        if spec.get("braids"):
            parts.append(WP.braids([ob], arm, [_rel(arm, b, ("path",)) for b in spec["braids"]], spec["braid_colours"],
                                   tag=spec.get("braid_tag", "braid")))
        if spec.get("hoses"):
            parts.append(WP.hoses([ob], arm, [_rel(arm, h, ("path",)) for h in spec["hoses"]], spec["hose_colours"]))
        for o in spec.get("orbits", []):
            got = WP.orbit_props(arm, _rel(arm, o, ("centre",)))
            extras.append(got[0])
            parts += [x for x in got[1:] if x.type == "MESH"]
            extras += [x for x in got[1:] if x.type != "MESH"]
        if spec.get("gauntlets"):
            got = WP.gauntlets(arm, spec["gauntlets"])
            parts.append(got[0])
            extras += got[1:]
        if spec.get("halo"):
            parts.append(WP.crescent(arm, _rel(arm, spec["halo"], ("centre",))))
        if spec.get("orb"):
            orb_s = _rel(arm, spec["orb"], ("centre",))
            parts.append(WP.orb(arm, orb_s))
            if orb_s.get("anchor"):
                # (the orb's match-zoom glow hangs on it, warden_look.json "halos")
                K.anchor(arm, orb_s.get("bone", "hand.R"), "anchor_" + orb_s["anchor"], tuple(orb_s["centre"]))
        if spec.get("wisp"):
            parts.append(WP.wisp(arm, spec["wisp"]))
        if spec.get("claws"):
            got = WP.claws(ob, arm, spec["claws"])
            if got:
                parts.append(got)
        for sd in spec.get("studs", []):
            got = WP.studs(ob, arm, sd)
            if got:
                parts.append(got)
    if spec.get("scripted"):
        # a Warden's own scripted pieces (tools/meshy/<module>.py build(): Sparkle's pigtails and back rods)
        sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
        import importlib
        parts += importlib.import_module(spec["scripted"]["module"]).build(ob, arm, rig, K, spec["scripted"])
    props = []
    if any(k in spec for k in ("wings", "lantern", "springs", "crossbows", "gem", "fluff_tail", "flower_crown", "cape", "laces")):
        sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
        import warden_props as WPR
        for sr in spec.get("springs", []):
            WPR.spring_region(ob, arm, sr)       # (a fluffy tail of the scan itself on a spring chain)
        if spec.get("wings"):
            parts.append(WPR.wings(arm, spec["wings"], spec["wing_look"]))
        if spec.get("lantern"):
            parts.append(WPR.lantern(arm, spec["lantern"], spec["lantern_look"]))
        if spec.get("crossbows"):
            props = list(WPR.crossbows(spec["crossbows"], spec["crossbows"]))
        if spec.get("gem"):
            parts.append(WPR.gem(arm, ob, spec["gem"]))
        if spec.get("laces"):
            parts.append(WPR.laces(arm, ob, spec["laces"]))
        if spec.get("fluff_tail"):
            parts.append(WPR.fluff_tail(arm, spec["fluff_tail"]))
        if spec.get("flower_crown"):
            parts.append(WPR.flower_crown(arm, ob, spec["flower_crown"]))
        if spec.get("cape"):
            parts.append(WPR.cape(arm, ob, spec["cape"]))
    for pc in spec.get("pieces", []):
        parts.append(split_piece(ob, img, pc))
    if spec.get("shears") or spec.get("lapel_needle"):
        import hem_parts
        if spec.get("shears"):
            parts.append(hem_parts.shears(arm, spec["shears"]))
        if spec.get("lapel_needle"):
            parts.append(hem_parts.lapel_needle(arm, spec["lapel_needle"]))
    if spec.get("thimbles"):
        import hem_parts
        parts.append(hem_parts.thimbles(ob, arm, spec["thimbles"]))
    if spec.get("needles"):
        # Hem's quiver needles, cut from the scan (`cut_boxes`) and built clean (tools/meshy/hem_parts.py)
        import hem_parts
        parts.append(hem_parts.needles(arm, spec["needles"], m, float(spec.get("chunk", {}).get("girth", 1.0))))
    built = {"weapon": None, "extra": []}
    if spec.get("parts"):
        # scripted pieces (tools/meshy/hard_parts.py): a held weapon or shield, wing cards, a tail, the feet check
        sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
        import hard_parts as HP
        built = HP.build(spec, ob, arm, rig)
    if spec.get("fins") or spec.get("vials") or spec.get("dorsal"):
        sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
        import warden_parts as WP
        if spec.get("fins"):
            parts.append(WP.fins(arm, [_rel(arm, f, ("centre",)) for f in spec["fins"]], spec["fin_atlas"])[0])
        if spec.get("vials"):
            parts.append(WP.vials(ob, arm, spec["vials"]))
    if spec.get("dorsal"):
        import warden_parts as WP
        parts.append(WP.dorsal(ob, arm, spec["dorsal"], spec["fin_atlas"]))
    if head:
        head.vertex_groups.clear()
        g = head.vertex_groups.new(name="head")
        g.add(list(range(len(head.data.vertices))), 1.0, "REPLACE")
        ob = join(ob, head)
    spin = None
    if gun is not None:
        gun, spin = gun_weapon(gun, ge, gt, rig, spec["gun_arm"])
    elif "bow" in spec:
        # a held bow, built by script (tools/meshy/bow_parts.py), with its nocked arrow as the Mag
        bw = spec["bow"]
        gun = bow_parts.build_bow(float(bw.get("height", 1.25)), float(bw.get("depth", 0.13)))
        gun["built"] = 1
        # (arrow false: only the needle's eye and its red thread sit at the nock, the Mag, so nothing sticks forward
        # off the bow at rest; the shot itself is the projectile)
        spin = bow_parts.build_arrow(tip_y=float(bw.get("tip", 0.78)), shaft=bw.get("arrow", True))
        spin.parent = gun
        spin["built"] = 1
        K.anchor(arm, "hand.R", "anchor_nock", K.bone_head(rig, "hand.R"))
        for nm, z in bw.get("halo_anchors", {}).items():
            # (on the bow itself, along the string: the bow's halos at the match camera follow it)
            e = bpy.data.objects.new(nm, None)
            bpy.context.scene.collection.objects.link(e)
            e.parent = gun
            e.location = (0.0, 0.06, float(z))
    elif "lance" in spec:
        # (a held weapon built as a lathe in the Gun's space: Cinder's flamethrower lance; tools/meshy/lance.py)
        sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
        import lance as LANCE
        gun, _limg = LANCE.build(spec["lance"], slot_materials(None, [s for s in K.SLOTS if s != "team"], "weapon"))
    elif spec.get("weapon_glb") and built["weapon"] is None:
        gun = weapon(spec, rig)
    held = [x for x in [built["weapon"]] + built["extra"] if x is not None and x.parent is None]
    parts += [x for x in built["extra"] if x.parent is not None]
    crown = rig["land"]["crown"]
    K.anchor(arm, "head", "anchor_head_top", (0, 0, crown + 0.07))
    K.anchor(arm, "hips", "anchor_chest", (0, 0.1, K.bone_head(rig, "upper_arm.L").z - 0.14))
    for an in spec.get("anchors", []):
        if "between" in an:
            # (extra anchors for warden_look "bloom": a point between two bone heads, rigid on `bone`: Kael)
            a, b = (K.bone_head(rig, n) for n in an["between"])
            t = float(an.get("t", 0.5))
            K.anchor(arm, an["bone"], an["name"], tuple(a[i] + (b[i] - a[i]) * t for i in range(3)))
            continue
        # (an anchor at the centre of one slot's faces on one side, the fitted frame: Claire's glowing irises,
        # for their match-zoom halos, warden_look.json "halos"; side -1 her left (-X), +1 her right, 0 both)
        mi = [i for i, m in enumerate(ob.data.materials) if m.name.startswith(an["slot"] + "-")]
        sd = float(an.get("side", 0))
        cs = [p.center for p in ob.data.polygons if p.material_index in mi and (sd == 0 or p.center.x * sd > 0)
              and float(an.get("z_min", -9.0)) <= p.center.z]
        if not cs:
            log("anchor %s: no %s faces" % (an["name"], an["slot"]))
            continue
        c = sum(cs, Vector()) / len(cs) + Vector(an.get("offset", [0.0, 0.0, 0.0]))
        K.anchor(arm, an.get("bone", "head"), "anchor_" + an["name"], tuple(c))
        log("anchor %s: %d faces, at %.3f %.3f %.3f" % (an["name"], len(cs), c.x, c.y, c.z))
    for o in [x for x in (ob, gun, spin) if x]:
        # Meshy's own split normals don't survive the decimation (facets): clear them, shade smooth
        if o.get("built"):
            continue                  # (a scripted piece: its facets are drawn on purpose)
        bpy.context.view_layer.objects.active = o
        if o.data.has_custom_normals:
            bpy.ops.mesh.customdata_custom_splitnormals_clear()
        if "cap_holes" in spec:
            cap_holes(o, float(spec["cap_holes"]), spec.get("cap_flat", False))
        outward(o)
        for p in o.data.polygons:
            p.use_smooth = True
        soft_normals(o, spec.get("normal_smooth", 8))
        if "ink_room" in spec:
            ink_room(o, float(spec["ink_room"]))
    for sp in (spec.get("parts") or {}).get("split", []):
        piece = HP.split(ob, arm, sp)               # (Claire's horns: their own mesh, on the head bone)
        if sp.get("drop"):
            bpy.data.objects.remove(piece)           # (the scan's horns, replaced by scripted ones: cut and gone)
        else:
            parts.append(piece)
    for o in parts + props + held:
        if o.name in spec.get("smooth_parts", []):
            # (a piece cut from the scan, Hem's mask: its decimated facets shaded smooth)
            if o.data.has_custom_normals:
                bpy.context.view_layer.objects.active = o
                bpy.ops.mesh.customdata_custom_splitnormals_clear()
            for p in o.data.polygons:
                p.use_smooth = True
            soft_normals(o, int(spec.get("normal_smooth", 8)) * 2)
        if "ink_room" in spec:
            ink_room(o, float(spec["ink_room"]))
    if "atlas_px" in spec:
        shrink(img, int(spec["atlas_px"]))
    for sp in spec.get("split", []):
        got = split_part(ob, arm, img, sp)
        if sp.get("drop"):
            bpy.data.objects.remove(got)     # (cut off the body and not exported: a rebuilt part replaces it)
        else:
            parts.append(got)
    for key in ("face_marks", "eye_marks"):
        if spec.get(key):
            sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
            import warden_parts as WP
            fm = spec[key]
            tgt = next((o for o in parts if o.name == fm.get("on", "Mask")), ob)
            got = WP.face_marks(tgt, arm, fm)
            if got:
                parts.append(got)
    if emask is not None:
        if spec.get("emit_atlas"):
            spec_emit_atlas.append(spec["emit_atlas"])
        emit_attach(ob, img, emask)
    out = os.path.join(ROOT, os.path.expanduser(spec["out"]))
    log("tris: body %d, weapon %d" % (K.tris([ob]), K.tris([x for x in (gun, spin) if x] + props)))
    # (JPEG: Meshy's painted textures, a third of the PNG's size)
    if parts:
        log("tris: parts %s" % {o.name: K.tris([o]) for o in parts})
    fmt = "JPEG"
    if any(m.name.startswith("card-") for o in parts for m in o.data.materials):
        # (alpha cards keep their PNG's alpha: every other texture still goes out as JPEG)
        fmt = "AUTO"
        tmp = os.path.join(os.path.dirname(os.path.expanduser(spec.get("blend", "/tmp/x"))), "jpg")
        os.makedirs(tmp, exist_ok=True)
        for im in bpy.data.images:
            if not im.name.startswith("wing") and im.size[0] > 0 and im.users:
                # (the exporter keeps an image's own format: saved as a .jpg file it goes out as JPEG)
                im.filepath_raw = os.path.join(tmp, im.name.replace(".", "_") + ".jpg")
                im.file_format = "JPEG"
                bpy.context.scene.render.image_settings.quality = 92
                im.save()
                im.source = "FILE"
    if held:
        log("tris: held %s" % {o.name: K.tris([o]) for o in held})
    K.export(out, [arm, ob] + parts + extras + props + held + [x for x in (gun, spin) if x] + [o for o in bpy.data.objects if o.name.startswith(("anchor_", "halo_"))], fmt,
             colors="ink_room" in spec)
    log("wrote", out)
    if spec.get("blend"):
        bpy.ops.wm.save_as_mainfile(filepath=os.path.expanduser(spec["blend"]))


main()
