"""Painted ageing for a flat-coloured Warden model (tools/blender/fit_rigged.py `paint`, `orb`, `drips`): one atlas
baked in Cycles from each material's colour with grime in the crevices (ambient occlusion), verdigris and rust
patches, dents as painted light and shade, scratches and worn edges, a painted highlight on glossy tar, and cracks
over glass. Plus the pieces it adds to the mesh: an emissive orb (a glowing eye) and tar drips hanging from the
surfaces that face down, each riding the bone of the part it hangs from.

All in the fit's frame (Blender, the Warden facing +Y, metres). The game shades the atlas like any painted .glb
(WardenGlb: "<slot>-<what>" materials sharing one base-colour texture).
"""
import math
import random

import bmesh
import bpy
import numpy as np
from mathutils import Vector

LIGHT = Vector((-0.45, 0.55, 0.7)).normalized()       # the painted key light: up, front, from the left


def lin(c):
    return tuple(x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c)


def hexlin(h):
    h = h.lstrip("#")
    return lin(tuple(int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)))


def _material(name, col):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*hexlin(col), 1.0)
    b.inputs["Metallic"].default_value = 0.0
    b.inputs["Roughness"].default_value = 1.0
    m.diffuse_color = (*hexlin(col), 1.0)
    return m


def _mat_index(ob, name, col):
    for i, m in enumerate(ob.data.materials):
        if m and m.name == name:
            return i
    ob.data.materials.append(_material(name, col))
    return len(ob.data.materials) - 1


def _append(ob, bm_new, bone, mat):
    """Joins the geometry in bm_new into ob, on material slot mat, rigid on bone."""
    me = bpy.data.meshes.new("_add")
    bm_new.to_mesh(me)
    bm_new.free()
    for m in ob.data.materials:          # (the slots first: an index past the slots falls back to 0)
        me.materials.append(m)
    for p in me.polygons:
        p.material_index = mat
        p.use_smooth = True
    tmp = bpy.data.objects.new("_add", me)
    bpy.context.scene.collection.objects.link(tmp)
    g = tmp.vertex_groups.new(name=bone)
    g.add(list(range(len(me.vertices))), 1.0, "REPLACE")
    bpy.ops.object.select_all(action="DESELECT")
    tmp.select_set(True)
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.join()


def remove_group(ob, group):
    """Deletes the vertices riding one bone (the eye's old asterisk)."""
    if group not in ob.vertex_groups:          # (already stripped from the source)
        return
    gi = ob.vertex_groups[group].index
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    dl = bm.verts.layers.deform.active
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if gi in v[dl]], context="VERTS")
    bm.to_mesh(ob.data)
    bm.free()


def add_orb(ob, spec):
    """A glowing orb: a sphere (flattened front to back by `depth`) on the given bone."""
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=12, v_segments=8, radius=float(spec["r"]))
    for v in bm.verts:
        v.co.y *= float(spec.get("depth", 1.0))
        v.co += Vector(spec["at"])
    _append(ob, bm, spec["bone"], _mat_index(ob, spec["material"], spec["colour"]))


def _drip(r, length, segs=6):
    """A hanging drip along -Z from the origin: a neck that thins, a bead near the end, a point."""
    prof = [(0.0, 1.0), (0.18, 0.72), (0.45, 0.5), (0.72, 0.46), (0.86, 0.78), (0.95, 0.55)]
    bm = bmesh.new()
    rings = []
    for t, k in prof:
        ring = []
        for i in range(segs):
            a = 2 * math.pi * i / segs
            ring.append(bm.verts.new((math.cos(a) * r * k, math.sin(a) * r * k, -t * length)))
        rings.append(ring)
    tip = bm.verts.new((0, 0, -length))
    for ra, rb in zip(rings, rings[1:]):
        for i in range(segs):
            j = (i + 1) % segs
            bm.faces.new((ra[i], ra[j], rb[j], rb[i]))
    for i in range(segs):
        bm.faces.new((rings[-1][i], rings[-1][(i + 1) % segs], tip))
    bmesh.ops.triangulate(bm, faces=bm.faces[:])
    return bm


def add_drips(ob, rules, seed=1):
    """Tar drips hanging from faces that look down: for each rule, `count` spread-out faces of a bone's group
    (optionally one material, within a z band), each drip hanging straight down from just inside the face."""
    rnd = random.Random(seed)
    me = ob.data
    names = {g.index: g.name for g in ob.vertex_groups}
    vg = np.array([names[max(v.groups, key=lambda g: g.weight).group] if v.groups else "" for v in me.vertices],
                  dtype=object)
    mats = [m.name if m else "" for m in me.materials]
    made = []
    for rule in rules:
        cand = []
        for p in me.polygons:
            if vg[p.vertices[0]] != rule["group"] or p.normal.z > float(rule.get("max_nz", -0.25)):
                continue
            if "material" in rule and mats[p.material_index] != rule["material"]:
                continue
            c = p.center
            z0, z1 = rule.get("z", (-9.0, 9.0))
            if not z0 <= c.z <= z1:
                continue
            if "box" in rule:
                x0, x1, y0, y1 = rule["box"]
                if not (x0 <= c.x <= x1 and y0 <= c.y <= y1):
                    continue
            cand.append((c.copy(), p.normal.copy()))
        if not cand:
            print("PAINT no faces for drips", rule)
            continue
        picks = [cand[rnd.randrange(len(cand))]]
        while len(picks) < int(rule["count"]) and len(picks) < len(cand):
            best = max(cand, key=lambda q: min((q[0] - p[0]).length for p in picks))
            picks.append(best)
        for c, n in picks:
            r = rnd.uniform(*rule["r"])
            ln = rnd.uniform(*rule["len"])
            bm = _drip(r, ln)
            at = c - n * r * 0.6 + Vector((0, 0, r * 0.5))
            for v in bm.verts:
                v.co += at
            made.append((bm, rule.get("bone", rule["group"])))
    tar = _mat_index(ob, rules[0]["tar"], rules[0].get("tar_colour", "1a1416"))
    for bm, bone in made:
        _append(ob, bm, bone, tar)
    print("PAINT drips: %d" % len(made))


def uv_atlas(objs, margin):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(60), island_margin=margin, area_weight=0.0,
                             correct_aspect=True, scale_to_bounds=False)
    bpy.ops.uv.pack_islands(margin=margin, rotate=True)
    bpy.ops.object.mode_set(mode="OBJECT")


def _bake_tree(m, look, img):
    """The bake's node tree for one material: its colour aged by `look` (its ageing recipe) as an emission."""
    nt = m.node_tree
    N = nt.nodes
    L = nt.links
    for n in list(N):
        N.remove(n)
    out = N.new("ShaderNodeOutputMaterial")
    emi = N.new("ShaderNodeEmission")
    L.new(emi.outputs[0], out.inputs["Surface"])
    tex = N.new("ShaderNodeTexImage")
    tex.image = img
    N.active = tex

    def rgb(h):
        n = N.new("ShaderNodeRGB")
        n.outputs[0].default_value = (*hexlin(h), 1.0)
        return n.outputs[0]

    def val(x):
        n = N.new("ShaderNodeValue")
        n.outputs[0].default_value = x
        return n.outputs[0]

    def math_(op, a, b=None, clamp=False):
        n = N.new("ShaderNodeMath")
        n.operation = op
        n.use_clamp = clamp
        for i, s in enumerate((a, b)):
            if s is None:
                continue
            if isinstance(s, (int, float)):
                n.inputs[i].default_value = float(s)
            else:
                L.new(s, n.inputs[i])
        return n.outputs[0]

    def mix(fac, a, b):
        n = N.new("ShaderNodeMix")
        n.data_type = "RGBA"
        for s, i in ((fac, 0), (a, 6), (b, 7)):
            if isinstance(s, (int, float)):
                n.inputs[i].default_value = float(s)
            else:
                L.new(s, n.inputs[i])
        return n.outputs[2]

    def ramp(x, lo, hi):          # smoothstep lo..hi
        n = N.new("ShaderNodeMapRange")
        n.interpolation_type = "SMOOTHSTEP"
        n.inputs["From Min"].default_value = lo
        n.inputs["From Max"].default_value = hi
        L.new(x, n.inputs["Value"])
        return n.outputs[0]

    co = N.new("ShaderNodeTexCoord").outputs["Object"]
    col = rgb(look["colour"])
    if look.get("proj"):
        col = _projected(N, L, co, look["proj"], math_, col)
        if look.get("mask"):          # (a disc where the model has its own piece in front: the image's copy fades)
            d = N.new("ShaderNodeVectorMath")
            d.operation = "DISTANCE"
            L.new(co, d.inputs[0])
            d.inputs[1].default_value = look["mask"]["at"]
            r_ = float(look["mask"]["r"])
            col = mix(math_("SUBTRACT", 1.0, ramp(d.outputs["Value"], r_ * 0.8, r_)), col, rgb(look["colour"]))
        if look.get("tint"):          # (the art's olive brass warmed toward tarnished brass and copper)
            tn = N.new("ShaderNodeVectorMath")
            tn.operation = "MULTIPLY"
            L.new(col, tn.inputs[0])
            tn.inputs[1].default_value = look["tint"]
            col = tn.outputs[0]
        if look.get("gain", 1.0) != 1.0:          # (lifted: the art's views are painted in a darker light)
            g = N.new("ShaderNodeVectorMath")
            g.operation = "SCALE"
            L.new(col, g.inputs[0])
            g.inputs["Scale"].default_value = float(look["gain"])
            col = g.outputs[0]
    if look.get("glass"):
        # cracks across the lens and the eye's red light bleeding into it
        vor = N.new("ShaderNodeTexVoronoi")
        vor.feature = "DISTANCE_TO_EDGE"
        vor.inputs["Scale"].default_value = float(look.get("crack_scale", 26.0))
        L.new(co, vor.inputs["Vector"])
        crack = math_("SUBTRACT", 1.0, ramp(vor.outputs["Distance"], 0.0, 0.05))
        d = N.new("ShaderNodeVectorMath")
        d.operation = "DISTANCE"
        L.new(co, d.inputs[0])
        d.inputs[1].default_value = look["eye_at"]
        halo = math_("SUBTRACT", 1.0, ramp(d.outputs["Value"], look["eye_r"] * 0.6, look["eye_r"] * 3.2))
        col = mix(halo, col, rgb(look["halo"]))
        col = mix(math_("MULTIPLY", crack, float(look.get("crack_k", 0.85))), col, rgb(look["crack"]))
        L.new(col, emi.inputs["Color"])
        return
    if look.get("tar"):
        # black and glossy: a painted highlight where the surface faces the key light
        nrm = N.new("ShaderNodeNewGeometry").outputs["Normal"]
        dot = N.new("ShaderNodeVectorMath")
        dot.operation = "DOT_PRODUCT"
        L.new(nrm, dot.inputs[0])
        dot.inputs[1].default_value = LIGHT
        hi = ramp(dot.outputs["Value"], 0.55, 0.85)
        L.new(mix(math_("MULTIPLY", hi, 0.8), col, rgb(look.get("shine", "8a7a80"))), emi.inputs["Color"])
        return
    ao = N.new("ShaderNodeAmbientOcclusion")
    ao.samples = 16
    ao.inputs["Distance"].default_value = float(look.get("ao_dist", 0.06))
    grime = math_("SUBTRACT", 1.0, ao.outputs["AO"])
    grime = ramp(grime, 0.05, 0.7)
    # dents: a bumped normal's light against the surface's own, painted in
    if look.get("dents", 0.0) > 0:
        vd = N.new("ShaderNodeTexVoronoi")
        vd.inputs["Scale"].default_value = float(look.get("dent_scale", 7.0))
        vd.inputs["Randomness"].default_value = 1.0
        L.new(co, vd.inputs["Vector"])
        h = ramp(vd.outputs["Distance"], 0.0, 0.5)
        bump = N.new("ShaderNodeBump")
        bump.inputs["Strength"].default_value = 1.0
        bump.inputs["Distance"].default_value = 0.05
        L.new(h, bump.inputs["Height"])
        d1 = N.new("ShaderNodeVectorMath")
        d1.operation = "DOT_PRODUCT"
        L.new(bump.outputs["Normal"], d1.inputs[0])
        d1.inputs[1].default_value = LIGHT
        d0 = N.new("ShaderNodeVectorMath")
        d0.operation = "DOT_PRODUCT"
        L.new(N.new("ShaderNodeNewGeometry").outputs["Normal"], d0.inputs[0])
        d0.inputs[1].default_value = LIGHT
        shade = math_("MULTIPLY", math_("SUBTRACT", d1.outputs["Value"], d0.outputs["Value"]), look["dents"])
        lit = math_("ADD", 1.0, shade)
        cm = N.new("ShaderNodeMix")
        cm.data_type = "RGBA"
        cm.blend_type = "MULTIPLY"
        cm.inputs[0].default_value = 1.0
        L.new(col, cm.inputs[6])
        cc = N.new("ShaderNodeCombineColor")
        for i in range(3):
            L.new(lit, cc.inputs[i])
        L.new(cc.outputs[0], cm.inputs[7])
        col = cm.outputs[2]
    # patches: verdigris (brass) or rust (iron), gathered in the crevices
    for key, scale in (("patina", 4.0), ("rust", 6.0)):
        if key not in look:
            continue
        nz = N.new("ShaderNodeTexNoise")
        nz.inputs["Scale"].default_value = float(look.get(key + "_scale", scale))
        nz.inputs["Detail"].default_value = 6.0
        nz.inputs["Roughness"].default_value = 0.6
        if look.get(key + "_streak"):          # (stretched down the surface: streaks running from the seams)
            mp = N.new("ShaderNodeMapping")
            mp.inputs["Scale"].default_value = (1.0, 1.0, 0.18)
            L.new(co, mp.inputs["Vector"])
            L.new(mp.outputs[0], nz.inputs["Vector"])
        else:
            L.new(co, nz.inputs["Vector"])
        patch = ramp(math_("ADD", nz.outputs["Fac"], math_("MULTIPLY", grime, 0.35)), look[key + "_at"],
                     look[key + "_at"] + 0.08)
        if look.get(key + "_crevice"):          # (only in the crevices: accents, not a tint over the surface)
            patch = math_("MULTIPLY", patch, ramp(grime, 0.25, 0.65))
        col = mix(math_("MULTIPLY", patch, look.get(key + "_k", 0.85)), col, rgb(look[key]))
    # scratches: thin bright lines along a stretched noise
    if look.get("scratch"):
        mp = N.new("ShaderNodeMapping")
        mp.inputs["Scale"].default_value = (3.0, 3.0, 28.0)
        mp.inputs["Rotation"].default_value = (0.5, 0.9, 0.3)
        L.new(co, mp.inputs["Vector"])
        sn = N.new("ShaderNodeTexNoise")
        sn.inputs["Scale"].default_value = 9.0
        sn.inputs["Detail"].default_value = 2.0
        L.new(mp.outputs[0], sn.inputs["Vector"])
        line = math_("SUBTRACT", 1.0, ramp(math_("ABSOLUTE", math_("SUBTRACT", sn.outputs["Fac"], 0.5)), 0.004, 0.02))
        mask = N.new("ShaderNodeTexNoise")
        mask.inputs["Scale"].default_value = 3.0
        L.new(co, mask.inputs["Vector"])
        line = math_("MULTIPLY", line, ramp(mask.outputs["Fac"], 0.5, 0.6))
        col = mix(math_("MULTIPLY", line, 0.7), col, rgb(look["scratch"]))
    # worn edges: the convex edges rubbed light
    if look.get("edge"):
        pt = N.new("ShaderNodeNewGeometry").outputs["Pointiness"]
        col = mix(math_("MULTIPLY", ramp(pt, 0.53, 0.62), 0.6), col, rgb(look["edge"]))
    # a painted highlight: the upper curves catching the key light, warm and bright
    if look.get("highlight"):
        hn = N.new("ShaderNodeVectorMath")
        hn.operation = "DOT_PRODUCT"
        L.new(N.new("ShaderNodeNewGeometry").outputs["Normal"], hn.inputs[0])
        hn.inputs[1].default_value = LIGHT
        band = ramp(hn.outputs["Value"], look.get("highlight_at", 0.55), look.get("highlight_at", 0.55) + 0.3)
        col = mix(math_("MULTIPLY", band, look.get("highlight_k", 0.7)), col, rgb(look["highlight"]))
    # plate seams: dark lines at even longitudes (and any latitudes) about a centre, with a thin bright edge
    sm = look.get("seams")
    if sm:
        rel = N.new("ShaderNodeVectorMath")
        rel.operation = "SUBTRACT"
        L.new(co, rel.inputs[0])
        rel.inputs[1].default_value = sm["centre"]
        sp = N.new("ShaderNodeSeparateXYZ")
        L.new(rel.outputs[0], sp.inputs[0])
        lines = None
        lon = math_("MULTIPLY", math_("ARCTAN2", sp.outputs[0], sp.outputs[1]), float(sm["n"]) / (2 * math.pi))
        dist = math_("ABSOLUTE", math_("SUBTRACT", math_("FRACT", lon), 0.5))
        lines = math_("SUBTRACT", 1.0, ramp(math_("SUBTRACT", 0.5, dist), float(sm["w"]) * 0.5, float(sm["w"])))
        for z in sm.get("z", []):
            dz = math_("ABSOLUTE", math_("SUBTRACT", sp.outputs[2], z))
            lines = math_("MAXIMUM", lines, math_("SUBTRACT", 1.0, ramp(dz, 0.003, 0.007)))
        col = mix(math_("MULTIPLY", lines, float(sm.get("k", 0.7))), col, rgb(sm["colour"]))
    # grime last: the crevices darkened toward the grime colour
    col = mix(math_("MULTIPLY", grime, look.get("grime_k", 0.75)), col, rgb(look.get("grime", "1c1612")))
    L.new(col, emi.inputs["Color"])


def _projected(N, L, co, proj, math_, fallback):
    """The art's views of the hull projected along their axes (warden_hull.projection), blended by how squarely
    each face looks down that axis (front +Y, back -Y, side either X)."""
    sep = N.new("ShaderNodeSeparateXYZ")
    L.new(co, sep.inputs[0])
    nrm = N.new("ShaderNodeSeparateXYZ")
    L.new(N.new("ShaderNodeNewGeometry").outputs["Normal"], nrm.inputs[0])
    acc = None
    wsum = None
    for view, pj in proj.items():
        u = math_("ADD", math_("MULTIPLY", sep.outputs[pj["axis"]], pj["u"][0]), pj["u"][1])
        v = math_("ADD", math_("MULTIPLY", sep.outputs[2], pj["v"][0]), pj["v"][1])
        cv = N.new("ShaderNodeCombineXYZ")
        L.new(u, cv.inputs[0])
        L.new(v, cv.inputs[1])
        t = N.new("ShaderNodeTexImage")
        t.image = pj["image"]
        t.extension = "EXTEND"
        L.new(cv.outputs[0], t.inputs["Vector"])
        if view == "front":
            w = math_("MAXIMUM", nrm.outputs[1], 0.0)
        elif view == "back":
            w = math_("MAXIMUM", math_("MULTIPLY", nrm.outputs[1], -1.0), 0.0)
        else:
            w = math_("ABSOLUTE", nrm.outputs[0])
        w = math_("ADD", math_("POWER", w, 4.0), 0.002 if view == "front" else 0.0)
        part = N.new("ShaderNodeVectorMath")
        part.operation = "SCALE"
        L.new(t.outputs[0], part.inputs[0])
        L.new(w, part.inputs["Scale"])
        if acc is None:
            acc, wsum = part.outputs[0], w
        else:
            add = N.new("ShaderNodeVectorMath")
            add.operation = "ADD"
            L.new(acc, add.inputs[0])
            L.new(part.outputs[0], add.inputs[1])
            acc, wsum = add.outputs[0], math_("ADD", wsum, w)
    # faces looking up or down (no view sees them: plate undersides) take the plain colour
    wz = math_("POWER", math_("ABSOLUTE", nrm.outputs[2]), 4.0)
    part = N.new("ShaderNodeVectorMath")
    part.operation = "SCALE"
    L.new(fallback, part.inputs[0])
    L.new(wz, part.inputs["Scale"])
    add = N.new("ShaderNodeVectorMath")
    add.operation = "ADD"
    L.new(acc, add.inputs[0])
    L.new(part.outputs[0], add.inputs[1])
    acc, wsum = add.outputs[0], math_("ADD", wsum, wz)
    div = N.new("ShaderNodeVectorMath")
    div.operation = "SCALE"
    L.new(acc, div.inputs[0])
    L.new(math_("DIVIDE", 1.0, wsum), div.inputs["Scale"])
    return div.outputs[0]


def bake(objs, looks, size, path, samples=24):
    """Bakes every material named in `looks` (glTF name -> recipe) into one atlas image at `path`."""
    img = bpy.data.images.new("atlas", size, size, alpha=False)
    img.generated_color = (0.0, 0.0, 0.0, 1.0)
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.samples = samples
    sc.render.bake.margin = 6
    sc.render.bake.use_clear = True
    keep = {}
    for o in objs:
        for m in o.data.materials:
            if m and m.name in looks and m.name not in keep:
                keep[m.name] = m.copy()
                _bake_tree(m, looks[m.name], img)
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.bake(type="EMIT")
    img.filepath_raw = path
    img.file_format = "PNG"
    img.save()
    # the export's materials: the atlas as the base colour of every painted material
    for name in keep:
        m = bpy.data.materials[name]
        for n in list(m.node_tree.nodes):
            m.node_tree.nodes.remove(n)
        out = m.node_tree.nodes.new("ShaderNodeOutputMaterial")
        b = m.node_tree.nodes.new("ShaderNodeBsdfPrincipled")
        b.inputs["Roughness"].default_value = 1.0
        t = m.node_tree.nodes.new("ShaderNodeTexImage")
        t.image = img
        m.node_tree.links.new(t.outputs[0], b.inputs["Base Color"])
        m.node_tree.links.new(b.outputs[0], out.inputs["Surface"])
    print("PAINT baked %d materials into %s" % (len(keep), path))
    return img
