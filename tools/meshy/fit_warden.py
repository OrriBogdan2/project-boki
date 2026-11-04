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
    log("auto weights on %s: %d groups" % (arm.name, len(ob.vertex_groups)))


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


def slot_split(ob, img, palette, glow_min, mats):
    """Each face onto the toon slot of the palette colour nearest its painted colour."""
    w, h = img.size
    px = np.array(img.pixels[:], dtype=np.float32).reshape(h, w, 4)
    uv = ob.data.uv_layers.active.data
    pal = np.array([K.hexcol(c) for _s, c in palette], dtype=np.float32)
    names = [s for s, _c in palette]
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
    log("slots:", counts)


def project(ob, img, pj):
    """Paints one of the art's views straight onto the faces turned toward it inside a box (the face and beret
    from the front, the sigil plate from the side): Meshy's own texture there is softer than the art.
    Orthographic, in the Meshy frame (front = -Y): pj["view"] "front" maps x to the sheet's columns, "side"
    (her left side, facing the sheet's left) maps y; z to the rows. pj: image, box [a0, a1, z0, z1] on the
    mapped axis and z, facing (the least turned normal kept), col0 (a column near the part) and head_z (the
    height whose silhouette lines the columns up), sole_row (the ground line)."""
    side = pj.get("view", "front") == "side"
    ax = 1 if side else 0
    art = bpy.data.images.load(os.path.expanduser(pj["image"]))
    aw, ah = art.size
    src = np.array(art.pixels[:], dtype=np.float32).reshape(ah, aw, 4)
    w, h = img.size
    dst = np.array(img.pixels[:], dtype=np.float32).reshape(h, w, 4)
    me = ob.data
    me.calc_loop_triangles()
    uv = me.uv_layers.active.data
    x0, x1, z0, z1 = pj["box"]
    k, col0, row0 = _register(me, src, pj, ax)
    bg = src[ah - 1 - 5, 5, :3]
    painted = 0
    for t in me.loop_triangles:
        n = t.normal
        if (n.x if side else -n.y) < float(pj["facing"]):
            continue
        ps = [me.vertices[i].co for i in t.vertices]
        if not all(x0 <= p[ax] <= x1 and z0 <= p.z <= z1 for p in ps):
            continue
        uvs = np.array([[uv[li].uv.x * w, uv[li].uv.y * h] for li in t.loops])
        cr = np.array([[col0 + p[ax] / k, row0 - p.z / k] for p in ps])
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


def _register(me, src, pj, ax):
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
    co = np.array([v.co[:] for v in me.vertices])
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
    col0 = ac - mx / k
    log("registered the art: %.5f m/px, x = 0 at column %.1f, z = 0 at row %.1f" % (k, col0, row0))
    return k, col0, row0


def lift(img, gamma, gain):
    """Meshy's albedo is a shade darker than the painted art and the toon shader darkens again: lift its values
    (a gamma and a gain on the stored colour) so the model reads as light as the turnaround in game."""
    px = np.array(img.pixels[:], dtype=np.float32).reshape(-1, 4)
    px[:, :3] = np.clip(np.power(px[:, :3], gamma) * gain, 0.0, 1.0)
    img.pixels = px.ravel()
    img.pack()


def slot_materials(img, slots):
    out = {}
    for s in slots:
        m = bpy.data.materials.new(s)
        m.use_nodes = True
        bsdf = m.node_tree.nodes.get("Principled BSDF")
        tex = m.node_tree.nodes.new("ShaderNodeTexImage")
        tex.image = img
        m.node_tree.links.new(tex.outputs[0], bsdf.inputs["Base Color"])
        bsdf.inputs["Roughness"].default_value = 0.8
        bsdf.inputs["Metallic"].default_value = 0.0
        out[s] = m
    return out


def contract_skin(ob, rig):
    arm = K.build_armature(rig)
    for b in arm.data.bones:
        b.use_deform = b.name not in NO_DEFORM
    auto_weights(ob, arm)
    return arm


def weapon(spec, rig, mats):
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
    lift(img, *spec["lift"])
    slot_split(w, img, spec["palette"], spec["glow_min"], slot_materials(img, list(mats)))
    w.name = "weapon"
    w.data.name = "weapon"
    return w


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
    lift(img, *spec["lift"])
    for pj in spec.get("project", []):
        project(ob, img, pj)
    joints = {k: Vector(v) for k, v in spec["joints"].items()}
    # face +Y, hips on the rig's height, feet on the ground, centred between the hips
    turn = Matrix.Rotation(math.radians(spec.get("turn", 180.0)), 4, "Z")
    co = np.array([v.co[:] for v in ob.data.vertices])
    sole = float(co[:, 2].min())
    hip_mid = (joints["hip.L"] + joints["hip.R"]) * 0.5
    k = K.bone_head(rig, "thigh.L").z / (hip_mid.z - sole)
    m = Matrix.Scale(k, 4) @ turn @ Matrix.Translation(Vector((-hip_mid.x, -hip_mid.y, -sole)))
    transform(ob, m)
    joints = {n: snap(ob, m @ p, spec.get("snap_r", 0.045)) for n, p in joints.items()}
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
    pose_to_rig(fit, rj)
    apply_pose(ob, fit)
    decimate(ob, spec["max_tris"])
    mats = slot_materials(img, [s for s in K.SLOTS if s != "team"])
    slot_split(ob, img, spec["palette"], spec["glow_min"], mats)
    ob.name = "Body"
    ob.data.name = "Body"
    arm = contract_skin(ob, rig)
    gun = weapon(spec, rig, mats)
    crown = rig["land"]["crown"]
    K.anchor(arm, "head", "anchor_head_top", (0, 0, crown + 0.07))
    K.anchor(arm, "hips", "anchor_chest", (0, 0.1, K.bone_head(rig, "upper_arm.L").z - 0.14))
    for o in (ob, gun):
        for p in o.data.polygons:
            p.use_smooth = True       # (Meshy's triangles come flat; smooth normals keep the toon terminator soft)
    out = os.path.join(ROOT, spec["out"])
    log("tris: body %d, weapon %d" % (K.tris([ob]), K.tris([gun])))
    # (JPEG: Meshy's painted textures, a third of the PNG's size)
    K.export(out, [arm, ob, gun] + [o for o in bpy.data.objects if o.name.startswith("anchor_")], "JPEG")
    log("wrote", out)
    if spec.get("blend"):
        bpy.ops.wm.save_as_mainfile(filepath=os.path.expanduser(spec["blend"]))


main()
