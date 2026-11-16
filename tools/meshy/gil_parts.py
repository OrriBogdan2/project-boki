"""Gil's pieces on top of the fitted body (fit_warden's out), in Blender 4.5:

  B tools/meshy/gil_parts.py -- <fit.glb> <swordfish.glb> <out.glb>

- The swordfish rapier in his RIGHT hand (never mirrored): Meshy's swordfish cut to ~1.6k triangles, its
  texture to 1024, held by the narrow root of its tail (the fork behind the fist, the bill forward and a little
  down, as Kael's sword), weighted 1.0 to hand.R so every pose carries it; `metal-swordfish`. The fit spec's
  `weapon_empty` hides the procedural weapon. Kael's FX empties (weapon_muzzle at the bill's tip,
  anchor_blade_mid, anchor_blade_root) sit on hand.R.
- The fish tail (turnaround): a tapered tube out from under the back hem, down and back to a forked caudal fin
  at boot height, in his own plane (a thin line from behind); rigid on hips, `skin-tail`.
- The dorsal fin on the upper back behind the collar: a ray fin, blue at the root and orange at the edge,
  rigid on hips, `skin-fin`.
Fitted frame: his right +X, front +Y, up +Z, soles on 0. Every new mesh gets the ink-room colour (COLOR_0 alpha).
"""
import math
import os
import sys

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "blender"))
import warden_kit as K  # noqa: E402

FISH_LEN = 0.74          # bill tip to tail fork, metres (g3: about half his height)
FISH_TRIS = 1600
FISH_TEX = 1024
BILL_DIR = Vector((0.0, 1.0, -0.55)).normalized()   # forward and a little down from the hanging hand
SKIN = (0.32, 0.56, 0.80)       # the tail's blue (the scan's skin, a little lighter)
FIN_ROOT = (0.36, 0.58, 0.82)
FIN_EDGE = (0.95, 0.56, 0.32)


def log(*a):
    print("GILPARTS", *a, flush=True)


def ink_back():
    """decimate_warden._ink_back: unwire the importer's COLOR_0 mix so the ink room's alpha goes out whole."""
    for mat in bpy.data.materials:
        nt = mat.node_tree
        if nt is None:
            continue
        for vc in [n for n in nt.nodes if n.type == "VERTEX_COLOR"]:
            for mix in [lk.to_node for lk in vc.outputs[0].links if lk.to_node.type == "MIX"]:
                tex = next((lk.from_socket for i in mix.inputs if i.name == "A" for lk in i.links), None)
                for lk in [lk for o in mix.outputs for lk in o.links]:
                    if tex is not None:
                        nt.links.new(tex, lk.to_socket)
                nt.nodes.remove(mix)
            nt.nodes.remove(vc)


def ink_colour(ob, alpha):
    ca = ob.data.color_attributes.new("Color", "FLOAT_COLOR", "POINT")
    vals = np.tile(np.array([1.0, 1.0, 1.0, alpha], np.float32), len(ob.data.vertices))
    ca.data.foreach_set("color", vals)
    ob.data.color_attributes.active_color = ca
    ob.data.color_attributes.render_color_index = ob.data.color_attributes.active_color_index


def rigid(ob, arm, bone):
    g = ob.vertex_groups.new(name=bone)
    g.add(list(range(len(ob.data.vertices))), 1.0, "REPLACE")
    ob.parent = arm
    ob.matrix_parent_inverse = arm.matrix_world.inverted()
    mod = ob.modifiers.new("Armature", "ARMATURE")
    mod.object = arm


def flat_mat(name, img):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get("Principled BSDF")
    tex = m.node_tree.nodes.new("ShaderNodeTexImage")
    tex.image = img
    m.node_tree.links.new(tex.outputs[0], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.8
    return m


def ramp_image(name, w=64):
    """u 0..0.25 solid skin blue; u 0.3..1 the fin ramp, root blue to orange edge (rows: soft ray stripes)."""
    h = 16
    px = np.zeros((h, w, 4), np.float32)
    for i in range(w):
        u = (i + 0.5) / w
        if u < 0.28:
            c = np.array(SKIN)
        else:
            t = min(1.0, max(0.0, (u - 0.3) / 0.7)) ** 1.3
            c = np.array(FIN_ROOT) * (1 - t) + np.array(FIN_EDGE) * t
        for j in range(h):
            k = 0.88 + 0.12 * math.cos(2 * math.pi * j / h * 3)    # (the rays, faint)
            px[j, i, :3] = c * (k if u >= 0.28 else 1.0)
            px[j, i, 3] = 1.0
    img = bpy.data.images.new(name, w, h, alpha=False)
    img.pixels = px.ravel()
    img.pack()
    return img


def sheet(name, outline, root_pts, th=0.006):
    """A flat fin from a closed outline (n x 3) fanned from its centroid, solidified th thick; UV u by the
    distance from the nearest root point (0.3 at the root -> 1 at the farthest edge)."""
    P = np.array(outline, np.float64)
    c = P.mean(axis=0)
    bm = bmesh.new()
    vc = bm.verts.new(c)
    vs = [bm.verts.new(p) for p in P]
    n = len(vs)
    for i in range(n):
        bm.faces.new((vc, vs[i], vs[(i + 1) % n]))
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    md = ob.modifiers.new("solid", "SOLIDIFY")
    md.thickness = th
    md.offset = 0.0
    bpy.context.view_layer.objects.active = ob
    with bpy.context.temp_override(object=ob, active_object=ob):
        bpy.ops.object.modifier_apply(modifier=md.name)
    R = np.array(root_pts, np.float64)
    co = np.array([v.co[:] for v in ob.data.vertices])
    d = np.min(np.linalg.norm(co[:, None, :] - R[None, :, :], axis=2), axis=1)
    u = 0.3 + 0.7 * d / max(d.max(), 1e-6)
    uvl = ob.data.uv_layers.new(name="UVMap")
    for loop in ob.data.loops:
        uvl.data[loop.index].uv = (float(u[loop.vertex_index]), 0.5 + 0.4 * (co[loop.vertex_index][2] % 0.05) / 0.05)
    return ob


def tube(name, path, radii, sides=10):
    p = np.array(path, np.float64)
    bm = bmesh.new()
    rings = []
    for i in range(len(p)):
        t = p[min(i + 1, len(p) - 1)] - p[max(i - 1, 0)]
        t /= np.linalg.norm(t)
        a = np.cross(t, [1.0, 0.0, 0.0])
        if np.linalg.norm(a) < 1e-6:
            a = np.cross(t, [0.0, 1.0, 0.0])
        a /= np.linalg.norm(a)
        b = np.cross(t, a)
        ring = []
        for k in range(sides):
            ang = 2 * math.pi * k / sides
            # (flattened side to side like a fish's body)
            ring.append(bm.verts.new(p[i] + radii[i] * (0.62 * math.cos(ang) * b + math.sin(ang) * a)))
        rings.append(ring)
    for i in range(len(rings) - 1):
        for k in range(sides):
            bm.faces.new((rings[i][k], rings[i][(k + 1) % sides], rings[i + 1][(k + 1) % sides], rings[i + 1][k]))
    bm.faces.new(list(reversed(rings[0])))
    bm.faces.new(rings[-1])
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    uvl = ob.data.uv_layers.new(name="UVMap")
    for loop in ob.data.loops:
        uvl.data[loop.index].uv = (0.12, 0.5)
    return ob


def back_y(bvh, z, x=0.0):
    """The body's back surface (most -Y hit) at height z, by a ray from behind."""
    loc, _n, _i, _d = bvh.ray_cast(Vector((x, -2.0, z)), Vector((0.0, 1.0, 0.0)))
    return None if loc is None else loc.y


def swordfish(path, arm):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=path)
    new = [o for o in bpy.data.objects if o not in before]
    meshes = [o for o in new if o.type == "MESH"]
    for o in new:
        o.select_set(o in meshes)
    bpy.context.view_layer.objects.active = meshes[0]
    for o in meshes:
        o.parent = None
    if len(meshes) > 1:
        bpy.ops.object.join()
    fish = bpy.context.view_layer.objects.active
    with bpy.context.temp_override(selected_editable_objects=[fish], active_object=fish, object=fish):
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    for o in new:
        if o != fish and o.name in bpy.data.objects:
            bpy.data.objects.remove(o)
    fish.name = "Swordfish"
    n0 = sum(len(p.vertices) - 2 for p in fish.data.polygons)
    md = fish.modifiers.new("dec", "DECIMATE")
    md.ratio = min(1.0, FISH_TRIS / max(1, n0))
    md.use_collapse_triangulate = True
    with bpy.context.temp_override(object=fish, active_object=fish):
        bpy.ops.object.modifier_apply(modifier=md.name)
    co = np.array([v.co[:] for v in fish.data.vertices])
    ext = co.max(axis=0) - co.min(axis=0)
    ax = int(np.argmax(ext))
    s = co[:, ax]
    lo, hi = s.min(), s.max()
    L = hi - lo
    others = [i for i in range(3) if i != ax]

    def spread(a, b):
        m = (s >= a) & (s <= b)
        return float(np.ptp(co[m][:, others], axis=0).max()) if m.sum() > 2 else 0.0
    bill_hi = spread(hi - 0.12 * L, hi) < spread(lo, lo + 0.12 * L)
    tail_end = lo if bill_hi else hi
    sign = 1.0 if bill_hi else -1.0
    # the grip: the narrowest slice 4..30% in from the tail end (the root of the fork)
    best, grip_s = 1e9, None
    for f in np.linspace(0.04, 0.30, 14):
        c = tail_end + sign * f * L
        w = spread(c - 0.02 * L, c + 0.02 * L)
        if 0.0 < w < best:
            best, grip_s = w, c
    m = np.abs(s - grip_s) < 0.03 * L
    grip = co[m].mean(axis=0)
    tip = co[np.argmax(sign * s)]
    # fish frame: long axis toward the bill, up = the axis of the bigger spread among the other two (the fins)
    d_long = np.zeros(3)
    d_long[ax] = sign
    sp = np.ptp(co[:, others], axis=0)
    up_ax = others[int(np.argmax(sp))] if abs(sp[0] - sp[1]) > 0.05 * L else 2 if ax != 2 else 1
    d_up = np.zeros(3)
    d_up[up_ax] = 1.0
    # target frame on the hand
    hb = arm.data.bones["hand.R"]
    Mw = arm.matrix_world
    h0, h1 = Mw @ hb.head_local, Mw @ hb.tail_local
    fist = h0 + (h1 - h0) * 0.6 + Vector((0.0, 0.015, 0.0))
    t_long = BILL_DIR
    t_up = (Vector((0.0, 0.0, 1.0)) - t_long * t_long.z).normalized()
    src = Matrix((Vector(d_long), Vector(d_up), Vector(np.cross(d_long, d_up)))).transposed()
    dst = Matrix((t_long, t_up, t_long.cross(t_up))).transposed()
    R = dst @ src.inverted()
    k = FISH_LEN / L
    M = Matrix.Translation(fist) @ R.to_4x4() @ Matrix.Diagonal((k, k, k, 1.0)) @ Matrix.Translation(-Vector(grip))
    fish.data.transform(M)
    tip_w = M @ Vector(tip)
    for mat in fish.data.materials:
        if mat is None or not mat.use_nodes:
            continue
        for nd in mat.node_tree.nodes:
            if nd.type == "TEX_IMAGE" and nd.image and max(nd.image.size) > FISH_TEX:
                nd.image.scale(FISH_TEX, FISH_TEX)
                nd.image.pack()
    # one material, base colour only (Meshy's metal/roughness/normal unused under the toon ramp)
    base = None
    for mat in fish.data.materials:
        if mat and mat.use_nodes:
            bsdf = mat.node_tree.nodes.get("Principled BSDF")
            if bsdf and bsdf.inputs["Base Color"].links:
                base = bsdf.inputs["Base Color"].links[0].from_node.image
    fish.data.materials.clear()
    fish.data.materials.append(flat_mat("metal-swordfish", base))
    for a in list(fish.data.color_attributes):
        fish.data.color_attributes.remove(a)
    ink_colour(fish, 0.35)
    rigid(fish, arm, "hand.R")
    # (Kael's FX empties: weapon_muzzle at the tip, anchor_blade_mid / _root along it, all on hand.R)
    K.anchor(arm, "hand.R", "weapon_muzzle", tip_w)
    K.anchor(arm, "hand.R", "anchor_blade_mid", (tip_w + fist) / 2)
    K.anchor(arm, "hand.R", "anchor_blade_root", fist + (tip_w - fist).normalized() * 0.08)
    log("swordfish: %d -> %d tris, length %.2f, grip %s, tip %s, bill on %s end" % (
        n0, sum(len(p.vertices) - 2 for p in fish.data.polygons), FISH_LEN, tuple(round(x, 3) for x in fist),
        tuple(round(x, 3) for x in tip_w), "+" if bill_hi else "-"))
    return fish


def main():
    a = sys.argv[sys.argv.index("--") + 1:]
    fit, fish_glb, out = a[0], a[1], a[2]
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=fit)
    ink_back()
    arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
    body = [o for o in bpy.data.objects if o.type == "MESH"]
    dg = bpy.context.evaluated_depsgraph_get()
    bvh = BVHTree.FromObject(max(body, key=lambda o: len(o.data.vertices)), dg)
    bone = arm.data.bones
    Mw = arm.matrix_world
    hips = (Mw @ bone["hips"].head_local).z
    knee = (Mw @ bone["shin.L"].head_local).z
    sh = (Mw @ bone["upper_arm.L"].head_local).z
    log("hips %.3f knee %.3f shoulder %.3f" % (hips, knee, sh))

    img = ramp_image("gil_fin")
    # the tail: from inside the coat at the hips' back, down and back under the hem to a fork at boot height
    z0, z1, z2 = hips * 0.95, knee * 0.95, knee * 0.55
    yb = [back_y(bvh, z) for z in (z0, z1, z2)]
    yb = [y if y is not None else -0.12 for y in yb]
    y0 = yb[0] + 0.07       # (root inside the body)
    path = [(0, y0, z0), (0, yb[1] - 0.02, z1 + 0.02), (0, min(yb[1], yb[2]) - 0.10, (z1 + z2) / 2),
            (0, min(yb[1], yb[2]) - 0.17, z2)]
    radii = [0.06, 0.05, 0.036, 0.022]
    tail = tube("Tail", path, radii)
    pc = np.array(path[-1], np.float64)
    fin_o = [pc + (0, 0.01, 0.02), pc + (0, -0.12, 0.13), pc + (0, -0.20, 0.17), pc + (0, -0.14, 0.06),
             pc + (0, -0.11, 0.0), pc + (0, -0.15, -0.06), pc + (0, -0.21, max(-0.10, 0.02 - pc[2])),
             pc + (0, -0.10, max(-0.06, 0.03 - pc[2])), pc + (0, 0.01, -0.02)]
    caud = sheet("TailFin", fin_o, [pc], th=0.008)
    # the dorsal fin: on the upper back behind the collar, rays up and back
    zt, zb = sh + 0.02, sh - 0.16
    ys = [back_y(bvh, z) for z in (zt, (zt + zb) / 2, zb)]
    ys = [y if y is not None else -0.15 for y in ys]
    r0 = np.array((0, ys[0] + 0.03, zt))
    r1 = np.array((0, ys[2] + 0.03, zb))
    dfin = [r0, r0 + (0, -0.07, 0.07), r0 + (0, -0.09, 0.03), (r0 + r1) / 2 + (0, -0.13, 0.04),
            (r0 + r1) / 2 + (0, -0.12, -0.0), r1 + (0, -0.13, 0.0), r1 + (0, -0.08, -0.03), r1]
    dors = sheet("Dorsal", dfin, [r0, (r0 + r1) / 2, r1], th=0.006)
    mskin = flat_mat("skin-tail", img)
    mfin = flat_mat("skin-fin", img)
    tail.data.materials.append(mskin)
    for ob in (caud, dors):
        ob.data.materials.append(mfin)
    # tail and its fin in one mesh
    with bpy.context.temp_override(active_object=tail, selected_editable_objects=[tail, caud]):
        bpy.ops.object.join()
    for ob, al in ((tail, 0.4), (dors, 0.15)):
        ink_colour(ob, al)
        rigid(ob, arm, "hips")
    fish = swordfish(fish_glb, arm)
    objs = [o for o in bpy.data.objects]
    meshes = [o for o in objs if o.type == "MESH"]
    log("tris: " + ", ".join("%s %d" % (o.name, K.tris([o])) for o in meshes), "total", K.tris(meshes))
    K.export(out, objs, colors=True)
    log("wrote", out)


main()
