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
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "blender"))
import warden_kit as K  # noqa: E402

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


def snap(ob, p, r):
    """The middle of the mesh near joint p (vertices within r in the side view, at any depth)."""
    co = np.array([v.co[:] for v in ob.data.vertices])
    d = np.hypot(co[:, 0] - p.x, co[:, 2] - p.z)
    near = co[d < r]
    if len(near) < 8:
        return p
    return Vector((float(near[:, 0].mean()), float((near[:, 1].min() + near[:, 1].max()) * 0.5), float(near[:, 2].mean())))


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
    _fill_weights(ob, arm)
    log("auto weights on %s: %d groups" % (arm.name, len(ob.vertex_groups)))


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


def project(ob, img, pj):
    """Paints one of the art's views straight onto the faces turned toward it inside a box (the face and beret
    from the front, the sigil plate from the side): Meshy's own texture there is softer than the art.
    Orthographic, in the Meshy frame (front = -Y): pj["view"] "front" maps x to the sheet's columns, "side"
    (her left side, facing the sheet's left) maps y; z to the rows. pj: image, box [a0, a1, z0, z1] on the
    mapped axis and z, facing (the least turned normal kept), col0 (a column near the part) and head_z (the
    height whose silhouette lines the columns up), sole_row (the ground line)."""
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
    k, col0, row0 = _register(me, src, pj, ax, sgn, pj.get("register_on"))
    bg = src[ah - 1 - 5, 5, :3]
    painted = 0
    for t in me.loop_triangles:
        n = t.normal
        facing = n.x * sgn if side else (n.y if view == "back" else -n.y)
        if facing < float(pj["facing"]):
            continue
        ps = [me.vertices[i].co for i in t.vertices]
        if not all(x0 <= p[ax] <= x1 and z0 <= p.z <= z1 for p in ps):
            continue
        uvs = np.array([[uv[li].uv.x * w, uv[li].uv.y * h] for li in t.loops])
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
        got = src[ah - 1 - row, col]
        art_px = np.abs(got[:, :3] - bg).sum(axis=1) > 0.12               # (the sheet's grey keeps Meshy's paint)
        dst[ty[art_px], tx[art_px]] = got[art_px]
        painted += 1
    img.pixels = dst.ravel()
    log("projected the art onto %d faces" % painted)


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


def lift(img, gamma, gain):
    """Meshy's albedo is a shade darker than the painted art and the toon shader darkens again: lift its values
    (a gamma and a gain on the stored colour) so the model reads as light as the turnaround in game."""
    px = np.array(img.pixels[:], dtype=np.float32).reshape(-1, 4)
    px[:, :3] = np.clip(np.power(px[:, :3], gamma) * gain, 0.0, 1.0)
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
    double-sided render hides but the game's back-face culling shows as dark triangle holes."""
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(ob.data)
    bm.free()
    ob.data.update()


def soft_normals(ob, iterations):
    """Meshy's surface is lumpy at this density (a triangle's three vertex normals ~50 degrees apart), and the
    toon shader's light/shadow split shows every lump as a facet: the shading normals are the vertex normals
    averaged with their neighbours' `iterations` times (the shape itself stays; a smoothed copy's normals
    flipped on thin parts like hair strands)."""
    if iterations <= 0:
        return
    me = ob.data
    nv = len(me.vertices)
    nrm = np.array([v.normal[:] for v in me.vertices], dtype=np.float64)
    ed = np.array([e.vertices[:] for e in me.edges], dtype=np.int64)
    for _i in range(iterations):
        acc = nrm.copy()
        np.add.at(acc, ed[:, 0], nrm[ed[:, 1]])
        np.add.at(acc, ed[:, 1], nrm[ed[:, 0]])
        nrm = acc / np.maximum(np.linalg.norm(acc, axis=1, keepdims=True), 1e-9)
    me.normals_split_custom_set_from_vertices([tuple(x) for x in nrm[:nv]])


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


def _cut(ob, drop):
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if drop(v.co)], context="VERTS")
    bm.to_mesh(ob.data)
    bm.free()


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
    r = float(ga["r"]) * m.to_scale().x
    start = float(ga.get("from", 0.0))

    def pick(co):
        d = co - e
        u = d.dot(ax) / n
        return start - 0.02 <= u <= 1.06 and (d - ax * d.dot(ax)).length < r
    return split_off(ob, pick, "weapon"), e, t


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
    material slot, a box (Meshy frame) and their painted colour, then recolours their texels: "warm" moves them
    toward a colour keeping their value (skin to the art's tan), "flat" sets the colour with a little of their own
    value (the hair streak's band), "paint" sets it outright (the vents' glow)."""
    w, h = img.size
    px = np.array(img.pixels[:], dtype=np.float32).reshape(h, w, 4)
    uv = ob.data.uv_layers.active.data
    for r in rules:
        box = r.get("box")
        col = np.array(K.hexcol(r["colour"]), np.float32)

        def pick(poly, c, mat, r=r, box=box):
            if r.get("slot") and not mat.startswith(r["slot"]):
                return False
            if box and not (box[0] <= c.x <= box[1] and box[2] <= c.z <= box[3]):
                return False
            if "front" in r and poly.normal.y > -float(r["front"]):
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
        rgb = px[m, :3]
        val = rgb.max(axis=1, keepdims=True) / max(float(col.max()), 1e-3)
        if r["mode"] == "warm":
            out = rgb * (1 - r["k"]) + np.clip(col * val, 0, 1) * r["k"]
        elif r["mode"] == "flat":
            v = np.clip(val, r.get("val_lo", 0.85), r.get("val_hi", 1.05))
            out = np.clip(col * v, 0, 1)
        else:
            out = np.broadcast_to(col, rgb.shape)
        px[m, :3] = out
        log("touch-up %s %s: %d texels" % (r["mode"], r["colour"], int(m.sum())))
    img.pixels = px.ravel()


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
    `back` m behind the Gun's origin (where the elbow is in the hold), scaled to fit. The barrels past `spin`
    (a fraction of the axis) become the child `weapon_spin`, its origin on the axis, which HunterAnim spins."""
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
        for v in ob.data.vertices:
            w = next((x.weight for x in v.groups if x.group == g.index), 0.0)
            if w > 0.0:
                co[v.index] = piv + (co[v.index] - piv) * (1.0 + kk * w)
    gk = float(ck.get("girth", 1.0))
    co[:, 0] *= gk
    co[:, 1] *= gk
    ob.data.vertices.foreach_set("co", co.ravel())
    ob.data.update()


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


def main():
    spec_path = sys.argv[sys.argv.index("--") + 1]
    spec = json.load(open(spec_path))
    K.reset()
    rig = K.load_rig(os.path.join(ROOT, spec["rig"]))
    ob = import_glb(os.path.expanduser(spec["body_glb"]))
    img = base_image(ob)
    drop_floaters(ob, spec.get("floater_verts", 40))
    ids = island_map(ob, img)
    paint_up(img, spec, ids=ids)
    for pj in spec.get("project", []):
        project(ob, img, pj)
    pad(img, ids, int(spec.get("pad", 6)))
    slot_split(ob, img, spec["palette"], spec["glow_min"], "body")
    if spec.get("touch_up"):
        touch_up(ob, img, spec["touch_up"])
    head = None
    if "head" in spec:
        decimate(ob, spec["max_tris"] - int(spec["head"]["tris"]))
        head = head_pass(ob, spec)
    joints = {k: Vector(v) for k, v in spec["joints"].items()}
    # face +Y, hips on the rig's height, feet on the ground, centred between the hips
    turn = Matrix.Rotation(math.radians(spec.get("turn", 180.0)), 4, "Z")
    co = np.array([v.co[:] for v in ob.data.vertices])
    sole = float(co[:, 2].min())
    hip_mid = (joints["hip.L"] + joints["hip.R"]) * 0.5
    k = K.bone_head(rig, "thigh.L").z / (hip_mid.z - sole)
    m = Matrix.Scale(k, 4) @ turn @ Matrix.Translation(Vector((-hip_mid.x, -hip_mid.y, -sole)))
    transform(ob, m)
    if head:
        transform(head, m)
    joints = {n: snap(ob, m @ p, spec.get("snap_r", 0.045)) for n, p in joints.items()}
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
        rj["ankle." + sd] = Vector((rj["knee." + sd].x, rj["knee." + sd].y, 0.06))
        rj["fingers." + sd] = rj["hand." + sd] + Vector((0, 0, -0.08))
    fit = fit_armature(joints)
    auto_weights(ob, fit)
    if head:
        rigid(head, fit, "head")
    pose_to_rig(fit, rj)
    if head:
        _apply_armature(head)
    apply_pose(ob, fit)
    decimate(ob, spec["max_tris"] - (int(spec["head"]["tris"]) if head else 0))
    ob.name = "Body"
    ob.data.name = "Body"
    arm = contract_skin(ob, rig)
    if "chunk" in spec:
        chunk(ob, rig, spec["chunk"])
    if head:
        head.vertex_groups.clear()
        g = head.vertex_groups.new(name="head")
        g.add(list(range(len(head.data.vertices))), 1.0, "REPLACE")
        ob = join(ob, head)
    spin = None
    if gun is not None:
        gun, spin = gun_weapon(gun, ge, gt, rig, spec["gun_arm"])
    else:
        gun = weapon(spec, rig)
    crown = rig["land"]["crown"]
    K.anchor(arm, "head", "anchor_head_top", (0, 0, crown + 0.07))
    K.anchor(arm, "hips", "anchor_chest", (0, 0.1, K.bone_head(rig, "upper_arm.L").z - 0.14))
    for o in [x for x in (ob, gun, spin) if x]:
        # Meshy's own split normals don't survive the decimation (facets): clear them, shade smooth
        bpy.context.view_layer.objects.active = o
        if o.data.has_custom_normals:
            bpy.ops.mesh.customdata_custom_splitnormals_clear()
        outward(o)
        for p in o.data.polygons:
            p.use_smooth = True
        soft_normals(o, spec.get("normal_smooth", 8))
    out = os.path.join(ROOT, os.path.expanduser(spec["out"]))
    log("tris: body %d, weapon %d" % (K.tris([ob]), K.tris([x for x in (gun, spin) if x])))
    # (JPEG: Meshy's painted textures, a third of the PNG's size)
    K.export(out, [arm, ob] + [x for x in (gun, spin) if x] + [o for o in bpy.data.objects if o.name.startswith("anchor_")], "JPEG")
    log("wrote", out)
    if spec.get("blend"):
        bpy.ops.wm.save_as_mainfile(filepath=os.path.expanduser(spec["blend"]))


main()
