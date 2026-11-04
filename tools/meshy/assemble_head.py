"""A Meshy body run joined to a separate head run (owner 17:05 accuracy pipeline, step 3), in Blender 4.5:

  ~/tools/blender-4.5.15-linux-x64/blender -b --factory-startup --python tools/meshy/assemble_head.py -- <spec.json>

Both dense glbs are in Meshy's frame (+Z up, facing -Y). The head run (from a high-res head sheet) has the better
face; the body run the better body. The head run is registered onto the body by the broken gold collar shards both
carry (their two halves' centroids: the distance between them scales it, their midpoint places it; `head_k` scales
it about that point afterwards, the art's slightly larger head), the body's head is cut above `cut_dz` m over the
shards' top, the head run keeps its non-hair faces above that line within `keep_r` of the neck (face, scarf, ears;
its hair is left to fit_warden's meshy_mane, which takes it from the same head glb), and the two are exported as one
dense glb with both textures, for bake_warden.py. Spec: body, head, out, gold_hsv [h0, h1, s_min, v_min],
hair [s_max, v_min], cut_dz, keep_r, head_k, nudge [x, y, z].
"""
import json
import os
import sys

import bmesh
import bpy
import numpy as np
from mathutils import Vector


def log(*a):
    print("ASSEMBLE", *a, flush=True)


def load(path, name):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=path)
    new = [o for o in bpy.data.objects if o not in before]
    meshes = [o for o in new if o.type == "MESH"]
    for m in meshes:
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
    ob.name = name
    return ob


def face_colours(ob):
    """Each face's texture colour at its UV centre (the base colour image of its material)."""
    me = ob.data
    imgs = []
    for m in me.materials:
        bsdf = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
        im = bsdf.inputs["Base Color"].links[0].from_node.image
        w, h = im.size
        imgs.append((np.array(im.pixels[:], np.float32).reshape(h, w, 4)[..., :3], w, h))
    uv = me.uv_layers.active.data
    cols = np.zeros((len(me.polygons), 3), np.float32)
    for p in me.polygons:
        px, w, h = imgs[p.material_index]
        u = sum(uv[i].uv.x for i in p.loop_indices) / p.loop_total
        v = sum(uv[i].uv.y for i in p.loop_indices) / p.loop_total
        cols[p.index] = px[min(h - 1, max(0, int(v * h))), min(w - 1, max(0, int(u * w)))]
    return cols


def hsv(c):
    mx, mn = c.max(1), c.min(1)
    d = np.maximum(mx - mn, 1e-6)
    r, g, b = c[:, 0], c[:, 1], c[:, 2]
    hh = np.where(mx == r, ((g - b) / d) % 6, np.where(mx == g, (b - r) / d + 2, (r - g) / d + 4)) / 6
    return hh, np.where(mx > 0, (mx - mn) / np.maximum(mx, 1e-6), 0), mx


def shards(ob, cols, sp, zmin, zmax):
    """The gold shards' faces (gold hue, saturated, bright, in a height band): their centres, split left/right."""
    hh, ss, vv = hsv(cols)
    g = sp.get("gold_hsv", [0.08, 0.17, 0.4, 0.55])
    cen = np.array([p.center[:] for p in ob.data.polygons])
    m = (hh > g[0]) & (hh < g[1]) & (ss > g[2]) & (vv > g[3]) & (cen[:, 2] > zmin) & (cen[:, 2] < zmax) \
        & (np.abs(cen[:, 0]) < 0.3)
    pts = cen[m]
    left, right = pts[pts[:, 0] < 0], pts[pts[:, 0] >= 0]
    if len(left) < 10 or len(right) < 10:
        sys.exit("ASSEMBLE: too few shard faces (%d, %d) in z %.2f..%.2f" % (len(left), len(right), zmin, zmax))
    return left.mean(0), right.mean(0), float(pts[:, 2].max())


def main():
    spec = json.load(open(sys.argv[sys.argv.index("--") + 1]))
    bpy.ops.wm.read_factory_settings(use_empty=True)
    body = load(os.path.expanduser(spec["body"]), "Body")
    head = load(os.path.expanduser(spec["head"]), "Head")
    bc, hc = face_colours(body), face_colours(head)
    bl, br, btop = shards(body, bc, spec, *spec.get("body_shard_z", [0.3, 0.75]))
    hl, hr, htop = shards(head, hc, spec, *spec.get("head_shard_z", [-1.0, 1.0]))
    k = float(np.linalg.norm(br - bl) / np.linalg.norm(hr - hl))
    bm_, hm_ = (bl + br) / 2, (hl + hr) / 2
    if spec.get("eyes"):
        # (by the eyes instead: a head sheet draws its collar lower under the chin than the body run does, so the
        # shards put the head 10 cm high. eyes: {body: [x, z, spacing], head: [x, z, spacing]} read on the gridded
        # front renders; the depth from the face's front (the frontmost non-hair faces at eye height))
        e = spec["eyes"]
        k = e["body"][2] / e["head"][2]
        def front_y(ob, cols, x, z):
            hh, ss, vv = hsv(cols)
            cen = np.array([p.center[:] for p in ob.data.polygons])
            m = (np.abs(cen[:, 2] - z) < 0.02) & (np.abs(cen[:, 0] - x) < 0.05) & ~((ss < 0.16) & (vv > 0.55))
            return float(np.percentile(cen[m, 1], 2))
        hm_ = np.array([e["head"][0], front_y(head, hc, e["head"][0], e["head"][1]), e["head"][1]])
        bm_ = np.array([e["body"][0], front_y(body, bc, e["body"][0], e["body"][1]), e["body"][1]])
        log("eyes: head %s -> body %s, scale %.3f" % (np.round(hm_, 3), np.round(bm_, 3), k))
    log("shards: body %s..%s (top %.3f), head %s..%s; scale %.3f" % (
        np.round(bl, 3), np.round(br, 3), btop, np.round(hl, 3), np.round(hr, 3), k))
    # the head run onto the body: scale about its shards' midpoint, move it onto the body's, then head_k about it
    hk = float(spec.get("head_k", 1.0))
    nudge = np.array(spec.get("nudge", [0, 0, 0]), float)
    me = head.data
    co = np.array([v.co[:] for v in me.vertices])
    co = (co - hm_) * k + bm_
    co = (co - bm_) * hk + bm_ + nudge
    for v, p in zip(me.vertices, co):
        v.co = p
    me.update()
    cut = btop + float(spec.get("cut_dz", 0.02))
    keep_r = float(spec.get("keep_r", 0.17))
    # the head run: its non-hair faces above the cut, near the neck
    hh, ss, vv = hsv(hc)
    hs = spec.get("hair", [0.16, 0.55])
    hair = (ss < hs[0]) & (vv > hs[1])
    neck = (bl + br) / 2
    # brow_box [x, z, half_x, half_z, y_max] in the body frame (spec "brows"; default round the eyes when they place
    # the head: 4.5 cm either side, 1.5 cm below to 3.5 cm above, in front of the face's front + 2.5 cm)
    brow_box = spec.get("brows")
    if brow_box is None and spec.get("eyes"):
        brow_box = [bm_[0], bm_[2] + 0.01, 0.045, 0.025, bm_[1] + 0.025]
    bmh = bmesh.new()
    bmh.from_mesh(me)
    bmh.faces.ensure_lookup_table()
    gone = []
    for f in bmh.faces:
        c = f.calc_center_median()
        # (the white brows are hair-coloured: the band round the eyes, at the face's front, stays)
        brow = bool(brow_box) and abs(c.x - brow_box[0]) < brow_box[2] and abs(c.z - brow_box[1]) < brow_box[3] \
            and c.y < brow_box[4]
        if (hair[f.index] and not brow) or c.z < cut or np.hypot(c.x - neck[0], c.y - neck[1]) > keep_r:
            gone.append(f)
    bmesh.ops.delete(bmh, geom=gone, context="FACES")
    bmesh.ops.delete(bmh, geom=[v for v in bmh.verts if not v.link_faces], context="VERTS")
    bmh.to_mesh(me)
    bmh.free()
    log("head run: kept %d faces above z %.3f within %.2f m" % (len(me.polygons), cut, keep_r))
    # the body: its head above the cut, within keep_r of the neck, goes
    bmb = bmesh.new()
    bmb.from_mesh(body.data)
    gone = [f for f in bmb.faces if f.calc_center_median().z > cut
            and np.hypot(f.calc_center_median().x - neck[0], f.calc_center_median().y - neck[1]) < keep_r * 1.15]
    bmesh.ops.delete(bmb, geom=gone, context="FACES")
    bmesh.ops.delete(bmb, geom=[v for v in bmb.verts if not v.link_faces], context="VERTS")
    bmb.to_mesh(body.data)
    bmb.free()
    log("body: cut %d faces of its head" % len(gone))
    bpy.ops.object.select_all(action="DESELECT")
    body.select_set(True)
    head.select_set(True)
    bpy.context.view_layer.objects.active = body
    bpy.ops.object.join()
    ob = bpy.context.view_layer.objects.active
    out = os.path.expanduser(spec["out"])
    os.makedirs(os.path.dirname(out), exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    bpy.ops.export_scene.gltf(filepath=out, use_selection=True, export_format="GLB", export_image_format="JPEG",
                              export_yup=True)
    # the registration, for the mane (meshy_mane's fixed transform) and the log
    json.dump({"k": k, "head_k": hk, "head_mid": hm_.tolist(), "body_mid": bm_.tolist(), "nudge": nudge.tolist(),
               "cut": cut}, open(out + ".reg.json", "w"), indent=1)
    log("wrote", out, "(%d faces)" % len(ob.data.polygons))


main()
