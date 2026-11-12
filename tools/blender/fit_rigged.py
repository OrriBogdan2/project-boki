"""A hand-made, already rigged Warden model fitted to the contract (docs/art/wardens/RIG_CONTRACT.md, PIPELINE.md
"Blender-driven modelling"), in Blender 4.5. No Meshy: the model's own rigid skin weights are kept, renamed onto the
contract bones, and its extra bones become the Warden's variant bones (WardenGlb.EXTRA).

  ~/tools/blender-4.5.15-linux-x64/blender -b --factory-startup --python tools/blender/fit_rigged.py -- <spec.json>

The spec (art/wardens/src/<name>_fit.json) names the source .glb, the rig JSON (`--warden-rig-json`), the scale, and:
- `groups`: each source vertex group -> a part label; `split`: loose parts of one group given another label by
  where they sit (the shoulder domes onto the pauldrons); `carry`: a label that takes another label's re-pose;
  `skin`: a label -> the contract (or variant) bone it rides, where they differ (the boots ride the shin);
- `extra`: variant bones -> [source bone, parent bone] (built where the source bone sits, carried with its part);
- `fit`: how each part is re-posed onto the rig's joints ("seg": a limb from one joint to the next, turned and
  stretched along itself; "move": carried from a source joint to a rig joint; anything else stays);
- `weapon`: a source group cut off into the `weapon` mesh in the Gun node's space (its narrow end on the right
  hand's grip, its mouth forward; `weapon_muzzle` marks the mouth; `solidify` m gives a single-sided shell an inside);
- `materials`: source material -> [glTF name "<slot>-<what>", colour]; `max_tris`; `anchors`;
- `scale_parts` {label: k}: a part scaled about its top after the re-pose (the cargo hook); a `fit` mode "shift"
  moves a part by `by` m as it is (the winch seated on the hull); an anchor with `pos` sits at that point;
- `protect` {parts, ratio}: thin parts decimated on their own, lightly (rods and fingers vanish at the body's ratio);
- `orb` (a glowing sphere on a bone, `replace`-ing a group), `drips` (tar drips hanging from faces that look
  down), `paint` (the ageing atlas: per-material recipes, baked in Cycles): tools/blender/warden_paint.py;
- `strip` (the source's shell pieces dropped) and `hull` (a scripted shell in their place, the art's views
  projected on it): tools/blender/warden_hull.py.
Steps: import, turn to face +Y and scale (Blender frame: the Warden faces +Y, its right +X), split the parts,
re-pose them, cut the weapon, decimate, skin rigidly to the contract armature plus the variant bones, recolour,
sharpen the hard edges, anchors, export.
"""
import json
import math
import os
import sys

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import warden_kit as K  # noqa: E402
import warden_paint as WP  # noqa: E402
import warden_hull as WH  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
# Godot's grips for the held weapon (HunterAnim HOLDS[<weapon>]["gr"]), Gun space
GRIP_R = {"shotgun": (0.0, -0.07, 0.04), "rifle": (0.0, -0.07, 0.04), "_gun": (0.0, -0.08, 0.02)}


def log(*a):
    print("FIT", *a, flush=True)


def import_src(path):
    bpy.ops.import_scene.gltf(filepath=path)
    for o in list(bpy.data.objects):
        if o.type == "MESH" and not o.vertex_groups:      # (the importer's bone-shape icosphere)
            bpy.data.objects.remove(o)
    arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
    ob = next(o for o in bpy.data.objects if o.type == "MESH")
    arm.data.pose_position = "REST"
    for a in list(bpy.data.actions):
        bpy.data.actions.remove(a)
    bones = {b.name: (arm.matrix_world @ b.head_local, arm.matrix_world @ b.tail_local) for b in arm.data.bones}
    mw = ob.matrix_world.copy()
    for m in list(ob.modifiers):
        ob.modifiers.remove(m)
    ob.parent = None
    ob.data.transform(mw)
    ob.matrix_world = Matrix.Identity(4)
    bpy.data.objects.remove(arm)
    return ob, bones


def vertex_parts(ob):
    """Each vertex's source group (the model's skin is rigid: one group per vertex), and its loose part."""
    names = [g.name for g in ob.vertex_groups]
    grp = np.array([names[max(v.groups, key=lambda g: g.weight).group] if v.groups else "" for v in ob.data.vertices],
                   dtype=object)
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    bm.verts.ensure_lookup_table()
    lab = -np.ones(len(bm.verts), int)
    n = 0
    for v in bm.verts:
        if lab[v.index] >= 0:
            continue
        stack = [v]
        lab[v.index] = n
        while stack:
            x = stack.pop()
            for e in x.link_edges:
                o = e.other_vert(x)
                if lab[o.index] < 0:
                    lab[o.index] = n
                    stack.append(o)
        n += 1
    bm.free()
    return grp, lab


def axial(u, k):
    """Scale by k along the unit axis u."""
    m = Matrix.Identity(3)
    for i in range(3):
        for j in range(3):
            m[i][j] += (k - 1.0) * u[i] * u[j]
    return m.to_4x4()


def seg_fit(a, b, c, d):
    """The map taking segment a->b onto c->d: turned about a, stretched along itself, moved to c."""
    u = (b - a).normalized()
    v = (d - c).normalized()
    k = (d - c).length / max((b - a).length, 1e-6)
    rot = u.rotation_difference(v).to_matrix().to_4x4()
    return Matrix.Translation(c) @ rot @ axial(u, k) @ Matrix.Translation(-a)


def split_off(ob, keep_verts, name):
    """The faces on the given vertices become their own object."""
    me = ob.data.copy()
    out = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(out)
    for o, keep in ((out, True), (ob, False)):
        bm = bmesh.new()
        bm.from_mesh(o.data)
        bm.verts.ensure_lookup_table()
        sel = [bm.verts[i] for i in range(len(bm.verts)) if (i in keep_verts) != keep]
        bmesh.ops.delete(bm, geom=sel, context="VERTS")
        bm.to_mesh(o.data)
        bm.free()
    return out


def tris(ob):
    return sum(len(p.vertices) - 2 for p in ob.data.polygons)


def decimate(ob, max_tris, dissolve_deg):
    n0 = tris(ob)
    bpy.context.view_layer.objects.active = ob
    if dissolve_deg > 0:
        m = ob.modifiers.new("planar", "DECIMATE")
        m.decimate_type = "DISSOLVE"
        m.angle_limit = math.radians(dissolve_deg)
        m.delimit = {"MATERIAL", "SEAM", "SHARP"}
        bpy.ops.object.modifier_apply(modifier=m.name)
        tri = ob.modifiers.new("tri", "TRIANGULATE")
        bpy.ops.object.modifier_apply(modifier=tri.name)
    n1 = tris(ob)
    if n1 > max_tris:
        m = ob.modifiers.new("dec", "DECIMATE")
        m.ratio = max_tris / n1
        m.use_collapse_triangulate = True
        m.delimit = {"MATERIAL"}
        bpy.ops.object.modifier_apply(modifier=m.name)
    log("decimate: %d -> %d (planar) -> %d tris" % (n0, n1, tris(ob)))


def sharpen(ob, deg):
    """Hard-surface shading: smooth faces, sharp edges where the faces meet at more than deg."""
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    lim = math.radians(deg)
    for e in bm.edges:
        e.smooth = not (len(e.link_faces) == 2 and e.calc_face_angle(0.0) > lim) and len(e.link_faces) == 2
    for f in bm.faces:
        f.smooth = True
    bm.to_mesh(ob.data)
    bm.free()
    if ob.data.has_custom_normals:
        bpy.context.view_layer.objects.active = ob
        bpy.ops.mesh.customdata_custom_splitnormals_clear()


def lin(h):
    c = K.hexcol(h)
    return tuple(x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c)


def recolour(ob, spec):
    for i, m in enumerate(ob.data.materials):
        if m is None or m.name not in spec:
            continue
        name, col = spec[m.name]
        if bpy.data.materials.get(name):          # (one material a name across the body and the weapon)
            ob.data.materials[i] = bpy.data.materials[name]
            continue
        nm = bpy.data.materials.new(name)
        nm.use_nodes = True
        b = nm.node_tree.nodes["Principled BSDF"]
        b.inputs["Base Color"].default_value = (*lin(col), 1.0)
        b.inputs["Metallic"].default_value = 0.0
        b.inputs["Roughness"].default_value = 1.0
        nm.diffuse_color = (*lin(col), 1.0)
        ob.data.materials[i] = nm


def add_extra(arm, extra, heads):
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="EDIT")
    eb = arm.data.edit_bones
    for name, (src, parent) in extra.items():
        h, t = heads[src]
        e = eb.new(name)
        e.head = h
        e.tail = t if (t - h).length > 1e-3 else h + Vector((0, 0, 0.05))
        e.parent = eb[parent]
        e.use_connect = False
    bpy.ops.object.mode_set(mode="OBJECT")


def main():
    spec = json.load(open(sys.argv[sys.argv.index("--") + 1]))
    K.reset()
    rig = K.load_rig(os.path.join(ROOT, spec["rig"]))
    ob, src_bones = import_src(os.path.expanduser(spec["src"]))
    log("source: %d tris, %d bones" % (tris(ob), len(src_bones)))
    s = float(spec["scale"])
    T = Matrix.Scale(s, 4) @ Matrix.Rotation(math.radians(spec.get("turn", 180.0)), 4, "Z")
    ob.data.transform(T)
    J = {n: (T @ h, T @ t) for n, (h, t) in src_bones.items()}
    grp, lab = vertex_parts(ob)
    for rule in spec.get("strip", []):          # the source's own shell pieces, replaced by `hull` (and the helm)
        keep = WH.strip(ob, grp, lab, rule)
        grp, lab = grp[keep], lab[keep]
    part = np.array([spec["groups"].get(g, g) for g in grp], dtype=object)
    co = np.array([v.co[:] for v in ob.data.vertices])
    # loose parts moved onto another bone by where they sit (Blender frame: the Warden's right is +X)
    for rule in spec.get("split", []):
        for p in np.unique(lab[grp == rule["group"]]):
            m = lab == p
            c = co[m].mean(axis=0)
            if abs(c[0]) > rule["min_abs_x"] and c[2] > rule["min_z"]:
                part[m] = rule["right"] if c[0] > 0 else rule["left"]
    # the weapon comes off before the re-pose (it goes into the Gun node's space)
    wspec = spec.get("weapon")
    weapon = None
    if wspec:
        wv = set(np.nonzero(grp == wspec["group"])[0].tolist())
        weapon = split_off(ob, wv, "weapon")
        keep = np.array([i not in wv for i in range(len(part))])
        part, lab, grp = part[keep], lab[keep], grp[keep]
    # re-pose each part onto the rig's joints
    R = {b: K.bone_head(rig, b) for b in rig["bones"]}
    moves = {}
    for bone, f in spec["fit"].items():
        if f["mode"] == "seg":
            a, b = J[f["from"][0]][0], J[f["from"][1]][0]
            c = R[f["to"][0]]
            d = R[f["to"][1]] if f["to"][1] in R else J[f["to"][1]][0]
            moves[bone] = seg_fit(a, b, c, d)
        elif f["mode"] == "move":
            moves[bone] = Matrix.Translation(R[f["to"]] - J[f["from"]][0])
        elif f["mode"] == "shift":          # (a part moved by `by` m as it is: the winch seated on the hull)
            moves[bone] = Matrix.Translation(Vector(f["by"]))
    me = ob.data
    for i, v in enumerate(me.vertices):
        m = moves.get(spec.get("carry", {}).get(part[i], part[i]))
        if m is not None:
            v.co = m @ v.co
    me.update()
    # parts scaled about their top (a part that hangs: the cargo hook), after the re-pose
    for lbl, k in spec.get("scale_parts", {}).items():
        sel = np.nonzero(part == lbl)[0]
        if len(sel) == 0:
            continue
        pts = np.array([me.vertices[int(i)].co[:] for i in sel])
        top = Vector((float(pts[:, 0].mean()), float(pts[:, 1].mean()), float(pts[:, 2].max())))
        for i in sel:
            v = me.vertices[int(i)]
            v.co = top + (v.co - top) * float(k)
        me.update()
        log("scaled %s x%.2f about its top" % (lbl, float(k)))
    # the variant bones ride their part's move
    heads = {}
    for name, (src, _parent) in spec.get("extra", {}).items():
        carrier = spec.get("carry", {}).get(name, name)
        m = moves.get(carrier, Matrix.Identity(4))
        heads[src] = (m @ J[src][0], m @ J[src][1])
    for name, f in spec["fit"].items():
        log("fit %s: %s" % (name, f))
    # the weapon: narrow end on the right hand's grip, its mouth forward (+Y), its outer side to the right (+X)
    if weapon:
        wc = np.array([v.co[:] for v in weapon.data.vertices])
        cen = wc.mean(axis=0)
        _u, _s, vt = np.linalg.svd(wc - cen, full_matrices=False)
        ax = Vector(vt[0])
        wrist = J[wspec["wrist"]][0]
        if ax.dot(Vector(cen) - wrist) < 0:
            ax = -ax
        t = (wc - cen) @ np.array(ax)
        lo, hi = t.min(), t.max()
        back = Vector(wc[t < lo + 0.08 * (hi - lo)].mean(axis=0))
        mouth = Vector(wc[t > hi - 0.08 * (hi - lo)].mean(axis=0))
        ax = (mouth - back).normalized()
        out = Vector((1, 0, 0))
        side = (out - ax * out.dot(ax)).normalized()
        up = side.cross(ax).normalized()
        side = ax.cross(up).normalized()
        rot = Matrix((side, ax, up)).to_4x4()
        grip = K.g2b(GRIP_R.get(rig["weapon"]["wid"], GRIP_R["_gun"]))
        kw = float(wspec.get("scale", 1.0))
        W = Matrix.Translation(grip + Vector(wspec.get("offset", (0, 0, 0)))) @ Matrix.Scale(kw, 4) @ rot \
            @ Matrix.Translation(-back)
        weapon.data.transform(W)
        weapon.data.update()
        mz = bpy.data.objects.new("weapon_muzzle", None)
        bpy.context.scene.collection.objects.link(mz)
        mz.parent = weapon
        mz.location = W @ mouth
        log("weapon: %d tris, %.3f m from the grip to its mouth at %s" % (tris(weapon), (W @ mouth - grip).length,
                                                                           tuple(round(x, 3) for x in mz.location)))
    # decimate (vertex parts follow the faces: the groups go on before, as vertex groups)
    bone_of = np.array([spec.get("skin", {}).get(p, p) for p in part], dtype=object)
    for b in sorted(set(bone_of.tolist())):
        g = ob.vertex_groups.new(name="_" + b)
        g.add([int(i) for i in np.nonzero(bone_of == b)[0]], 1.0, "REPLACE")
    for g in [g for g in ob.vertex_groups if not g.name.startswith("_")]:
        ob.vertex_groups.remove(g)
    pr = spec.get("protect")
    if pr:
        # thin limbs (the claw arm's rods and fingers, the leg rods) collapse to nothing under the body's ratio, and
        # dense pieces (the boots) take more than their share: each group is split off, decimated at its own ratio
        # and joined back; the rest takes what is left of max_tris
        groups = pr if isinstance(pr, list) else [pr]
        pieces = []
        taken = np.zeros(len(part), bool)
        for grp_spec in groups:
            sel = np.isin(part, grp_spec["parts"]) & ~taken
            taken |= sel
            pieces.append((np.nonzero(sel)[0].tolist(), float(grp_spec.get("ratio", 0.6))))
        # (split from the highest index down is not needed: split_off keeps the mesh's own order per object)
        limbs = []
        idx = np.arange(len(part))
        for keep_ids, ratio in pieces:
            # indices into the current (shrinking) mesh: track the original index in a layer
            limbs.append((keep_ids, ratio))
        lay = ob.data.attributes.new("_orig", "INT", "POINT")
        lay.data.foreach_set("value", idx.astype(np.int32))
        outs = []
        for keep_ids, ratio in limbs:
            want = set(keep_ids)
            cur = np.zeros(len(ob.data.vertices), np.int32)
            ob.data.attributes["_orig"].data.foreach_get("value", cur)
            sel = {i for i, o in enumerate(cur.tolist()) if o in want}
            limb = split_off(ob, sel, "limb")
            decimate(limb, int(tris(limb) * ratio), 0.0)
            outs.append(limb)
        decimate(ob, int(spec["max_tris"]) - sum(tris(o) for o in outs), float(spec.get("dissolve_deg", 0.0)))
        bpy.ops.object.select_all(action="DESELECT")
        for o in outs:
            o.select_set(True)
        ob.select_set(True)
        bpy.context.view_layer.objects.active = ob
        bpy.ops.object.join()
        ob.data.attributes.remove(ob.data.attributes["_orig"])
    if spec.get("drop_small"):
        # fragments the collapse left (a few triangles of a decimated strap or weed: shards floating round the limbs)
        dz = spec["drop_small"]
        bm = bmesh.new()
        bm.from_mesh(ob.data)
        bm.verts.ensure_lookup_table()
        seen = set()
        drop = []
        for v in bm.verts:
            if v.index in seen:
                continue
            comp, stack = [v], [v]
            seen.add(v.index)
            while stack:
                x = stack.pop()
                for e in x.link_edges:
                    o = e.other_vert(x)
                    if o.index not in seen:
                        seen.add(o.index)
                        comp.append(o)
                        stack.append(o)
            co = np.array([q.co[:] for q in comp])
            size = float(np.linalg.norm(co.max(axis=0) - co.min(axis=0)))
            faces = {f for q in comp for f in q.link_faces}
            if size < float(dz["size"]) and len(faces) < int(dz["tris"]):
                drop.extend(comp)
        bmesh.ops.delete(bm, geom=drop, context="VERTS")
        bm.to_mesh(ob.data)
        bm.free()
        log("drop_small: %d vertices" % len(drop))
    else:
        decimate(ob, int(spec["max_tris"]), float(spec.get("dissolve_deg", 0.0)))
    if weapon and tris(weapon) > int(wspec.get("tris", 3000)):
        decimate(weapon, int(wspec.get("tris", 3000)), float(spec.get("dissolve_deg", 0.0)))
    for g in ob.vertex_groups:
        g.name = g.name[1:]
    for v in ob.data.vertices:          # (rigid: one bone a vertex, as the source had it)
        if len(v.groups) > 1:
            best = max(v.groups, key=lambda x: x.weight).group
            for x in list(v.groups):
                if x.group != best:
                    ob.vertex_groups[x.group].remove([v.index])
    # the contract armature, plus the variant bones
    arm = K.build_armature(rig)
    add_extra(arm, spec.get("extra", {}), heads)
    # variant bones with no source bone (the tar pool), built where the spec puts them
    if spec.get("extra_new"):
        bpy.context.view_layer.objects.active = arm
        bpy.ops.object.mode_set(mode="EDIT")
        for name, b in spec["extra_new"].items():
            e = arm.data.edit_bones.new(name)
            e.head, e.tail = Vector(b["head"]), Vector(b["tail"])
            e.parent = arm.data.edit_bones[b["parent"]]
        bpy.ops.object.mode_set(mode="OBJECT")
    missing = [g.name for g in ob.vertex_groups if g.name not in arm.data.bones]
    assert not missing, "groups with no bone: %s" % missing
    ob.parent = arm
    mod = ob.modifiers.new("Armature", "ARMATURE")
    mod.object = arm
    ob.name = ob.data.name = "Body"
    recolour(ob, spec["materials"])
    sharpen(ob, float(spec.get("sharp_deg", 40.0)))
    if weapon and wspec.get("solidify"):
        # a single-sided shell (the horn's flared mouth): give it an inside, or the ink shell shows black through it
        bpy.context.view_layer.objects.active = weapon
        so = weapon.modifiers.new("solid", "SOLIDIFY")
        so.thickness = float(wspec["solidify"])
        so.offset = 1.0
        so.use_even_offset = True
        bpy.ops.object.modifier_apply(modifier=so.name)
        if tris(weapon) > int(wspec.get("tris", 3000)):
            decimate(weapon, int(wspec.get("tris", 3000)), 0.0)
    if weapon:
        recolour(weapon, spec["materials"])
        sharpen(weapon, float(spec.get("sharp_deg", 40.0)))
        weapon.data.name = "weapon"
    # added pieces (a glowing orb for an eye, tar drips) and the painted ageing atlas (tools/blender/warden_paint.py)
    paint = spec.get("paint")
    if spec.get("hull"):
        WH.build(ob, spec["hull"], int(spec.get("seed", 1)))
    for rm in spec.get("remat", []):          # one bone's faces moved from one material to another
        names = [m.name for m in ob.data.materials]
        gi = ob.vertex_groups[rm["group"]].index
        src, dst = names.index(rm["from"]), names.index(rm["to"])
        for p in ob.data.polygons:
            if p.material_index == src and all(any(g.group == gi for g in ob.data.vertices[v].groups)
                                               for v in p.vertices):
                p.material_index = dst
    if spec.get("orb"):
        if spec["orb"].get("replace"):
            WP.remove_group(ob, spec["orb"]["replace"])
        WP.add_orb(ob, spec["orb"])
    if spec.get("extras"):          # (after the orb: it clears the eye bone's old pieces)
        WH.extras(ob, spec["extras"], int(spec.get("seed", 1)))
    if spec.get("drips"):
        WP.add_drips(ob, spec["drips"], int(spec.get("seed", 1)))
    if paint:
        if spec.get("hull", {}).get("project"):
            paint["looks"][spec["hull"]["material"]]["proj"] = WH.projection(ob, spec["hull"])
        painted = [ob] + ([weapon] if weapon else [])
        WP.uv_atlas(painted, float(paint.get("margin", 0.002)))
        WP.bake(painted, paint["looks"], int(paint["size"]), os.path.expanduser(paint["image"]),
                int(paint.get("samples", 24)))
    # anchors: the shared two and the Warden's own
    co = np.array([v.co[:] for v in ob.data.vertices])
    top = float(co[:, 2].max())
    K.anchor(arm, "head", "anchor_head_top", (0, 0, top + 0.07))
    K.anchor(arm, "hips", "anchor_chest", (0, 0.1, K.bone_head(rig, "upper_arm.L").z - 0.14))
    for name, a in spec.get("anchors", {}).items():
        if a.get("pos"):          # (a fixed point: the smoke stack's mouth)
            K.anchor(arm, a["bone"], name, tuple(float(x) for x in a["pos"]))
            continue
        pts = co[np.array([any(g.group == ob.vertex_groups[a["group"]].index for g in v.groups)
                           for v in ob.data.vertices])]
        at = pts.mean(axis=0)
        if a.get("at") == "low":
            at[2] = pts[:, 2].min()
        K.anchor(arm, a["bone"], name, tuple(float(x) for x in at))
    log("tris: body %d, weapon %d; materials %s" % (tris(ob), tris(weapon) if weapon else 0,
                                                     [m.name for m in ob.data.materials]))
    log("top %.3f m; bones %d" % (top, len(arm.data.bones)))
    out = os.path.join(ROOT, spec["out"])
    os.makedirs(os.path.dirname(out), exist_ok=True)
    objs = [arm, ob] + ([weapon] + list(weapon.children) if weapon else []) \
        + [o for o in bpy.data.objects if o.name.startswith("anchor_")]
    K.export(out, objs, "JPEG" if paint else "AUTO")
    log("wrote", out)
    if spec.get("blend"):
        bpy.ops.wm.save_as_mainfile(filepath=os.path.expanduser(spec["blend"]))


main()
