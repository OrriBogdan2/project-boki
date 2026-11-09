"""A clean game mesh baked from Meshy's dense one (docs/art/wardens/PIPELINE.md, r3), in Blender 4.5:

  ~/tools/blender-4.5.15-linux-x64/blender -b --factory-startup --python tools/meshy/bake_warden.py -- <spec.json>

Meshy's should_remesh=false output is ~1.2M triangles with an 8k texture cut into thousands of UV crumbs.
Decimating that mesh with its UVs kept (r2) smears the texture across the crumbs. Instead:
 1. Import the dense mesh (Meshy's frame: +Z up, facing -Y) and keep it as the bake source.
 2. The low mesh: a welded copy, its floaters dropped, decimated (collapse, no UV limits) to `tris`, of which
    `head_tris` go to the head (`head`: centre, r).
 3. New UVs: flat projections of a smoothed copy, islands that overlap themselves projected again closer to
    the real surface; the head's islands scaled `head_uv` times (more texels on the face); packed.
 4. Bake the dense mesh's base colour onto them (Cycles, selected to active, as emission: no light baked
    in), each island's edge extended `margin_px` into the gaps.
 5. Export the low mesh and its texture (atlas.png beside it) as a .glb in Meshy's frame and pose:
    fit_warden.py's `body_glb`.
The spec (art/wardens/src/<name>_bake.json): high, out, tris, head {centre, r}, head_tris, head_uv, uv_smooth,
uv_angle, uv_margin, tex, cage, ray, margin_px, floater_verts.
"""
import json
import math
import os
import sys

import bmesh
import bpy
import numpy as np
from mathutils import Vector


def log(*a):
    print("BAKEWARDEN", *a, flush=True)


def import_dense(path):
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
    ob.name = "High"
    return ob


def base_image(ob):
    bsdf = next(n for n in ob.data.materials[0].node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    return bsdf.inputs["Base Color"].links[0].from_node.image


def tris(ob):
    return sum(len(p.vertices) - 2 for p in ob.data.polygons)


def make_low(high, n_tris, floater_verts, head=None, head_tris=0):
    """A welded copy of the dense mesh (Meshy splits its vertices along UV seams), decimated with no UV limits.
    With a head budget, in two passes: the body to n_tris - head_tris with the head (`head`: centre, r) held,
    then the head to head_tris with the body held (left to itself the collapse keeps ~5k of 36k on the head,
    and the monocle and the strands over the face come out jagged)."""
    me = high.data.copy()
    low = bpy.data.objects.new("Low", me)
    bpy.context.scene.collection.objects.link(low)
    bm = bmesh.new()
    bm.from_mesh(me)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    _drop_small_parts(bm, floater_verts)
    bm.to_mesh(me)
    bm.free()
    me.materials.clear()
    while me.uv_layers:
        me.uv_layers.remove(me.uv_layers[0])
    bpy.ops.object.select_all(action="DESELECT")
    bpy.context.view_layer.objects.active = low
    low.select_set(True)
    if not head or head_tris <= 0:
        _decimate(low, n_tris / max(tris(low), 1), None)
    else:
        c, r = Vector(head["centre"]), float(head["r"])
        co = np.array([v.co[:] for v in me.vertices])
        inside = np.clip((r * 1.03 - np.linalg.norm(co - np.array(c), axis=1)) / (r * 0.06), 0.0, 1.0)
        for name, w in (("body", 1.0 - inside), ("head", inside)):
            g = low.vertex_groups.new(name=name)
            for i in np.nonzero(w > 0.0)[0]:
                g.add([int(i)], float(w[i]), "REPLACE")
        n_head = sum(1 for p in me.polygons if (p.center - c).length < r)
        # (a held region doesn't count: the ratio is of the whole mesh)
        _decimate(low, (n_head + n_tris - head_tris) / tris(low), "body")
        _decimate(low, n_tris / tris(low), "head")
        low.vertex_groups.clear()
    log("low: %d -> %d tris" % (tris(high), tris(low)))
    return low


def _decimate(ob, ratio, group):
    m = ob.modifiers.new("dec", "DECIMATE")
    m.ratio = min(1.0, ratio)
    m.use_collapse_triangulate = True
    if group:
        m.vertex_group = group
    bpy.ops.object.modifier_apply(modifier=m.name)


def _drop_small_parts(bm, min_verts):
    bm.verts.ensure_lookup_table()
    seen = set()
    small = []
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
        if len(part) < min_verts:
            small.extend(part)
    bmesh.ops.delete(bm, geom=small, context="VERTS")
    log("floaters: dropped %d verts" % len(small))


def unwrap(low, head, head_uv, margin, angle, smooth):
    """UVs from Smart UV Projects of smoothed copies (the decimated surface's small bumps would cut it into
    thousands of crumbs, which mipmaps blend into mud at the match camera): each island a flat projection, so
    the texel density stays even (an angle-based unwrap squeezed the face to a third). Smoothing folds small
    parts into their neighbours (the monocle onto the face) and their island then overlaps itself, so those
    islands are projected again from a less smoothed copy, down to the real surface. The head's islands are
    scaled head_uv x (more texels on the face), then everything is packed."""
    low.data.uv_layers.new(name="UVMap")
    nl = len(low.data.loops)
    uv = np.zeros(nl * 2, np.float32)
    pending = set(range(len(low.data.polygons)))
    for level, limit in ((smooth, angle), (smooth // 3, angle), (smooth // 10, angle), (0, angle), (0, angle * 0.5)):
        proxy = bpy.data.objects.new("Proxy", low.data.copy())
        bpy.context.scene.collection.objects.link(proxy)
        bpy.context.view_layer.objects.active = proxy
        if level > 0:
            m = proxy.modifiers.new("smooth", "SMOOTH")
            m.factor = 0.8
            m.iterations = level
            bpy.ops.object.modifier_apply(modifier=m.name)
        for p in proxy.data.polygons:
            p.select = p.index in pending
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.uv.smart_project(angle_limit=math.radians(limit), island_margin=0.0, area_weight=0.0,
                                 correct_aspect=True, scale_to_bounds=False)
        bpy.ops.object.mode_set(mode="OBJECT")
        got = np.empty(nl * 2, np.float32)
        proxy.data.uv_layers.active.data.foreach_get("uv", got)
        for f in pending:
            for li in low.data.polygons[f].loop_indices:
                uv[li * 2:li * 2 + 2] = got[li * 2:li * 2 + 2]
        bpy.data.objects.remove(proxy)
        low.data.uv_layers[0].data.foreach_set("uv", uv)
        pending = _self_overlapping(low) & pending
        log("UVs (smoothed %d, %d degrees): %d faces in self-overlapping islands" % (level, limit, len(pending)))
        if not pending:
            break
    bpy.context.view_layer.objects.active = low
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.context.scene.tool_settings.use_uv_select_sync = True
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.average_islands_scale()
    bpy.ops.object.mode_set(mode="OBJECT")
    if head and head_uv != 1.0:
        _scale_islands(low, Vector(head["centre"]), float(head["r"]), head_uv)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.context.scene.tool_settings.use_uv_select_sync = True
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.pack_islands(rotate=True, scale=True, margin_method="FRACTION", margin=margin, shape_method="CONCAVE")
    bpy.ops.object.mode_set(mode="OBJECT")


def _self_overlapping(low, n=1024, far=0.02):
    """The faces of every UV island that covers a texel twice with faces more than `far` m apart."""
    bm = bmesh.new()
    bm.from_mesh(low.data)
    lay = bm.loops.layers.uv.active
    bm.faces.ensure_lookup_table()
    out = set()
    for faces in _islands(bm, lay):
        owner = {}
        hit = False
        for f in faces:
            c = f.calc_center_median()
            uvs = [lp[lay].uv * n for lp in f.loops]
            for k in range(1, len(uvs) - 1):
                for px in _texels((uvs[0], uvs[k], uvs[k + 1])):
                    o = owner.get(px)
                    if o is not None and (o - c).length > far:
                        hit = True
                        break
                    owner[px] = c
                if hit:
                    break
            if hit:
                break
        if hit:
            out.update(f.index for f in faces)
    bm.free()
    return out


def _texels(tri):
    """The texel centres inside a UV triangle (pixel units), shrunk a little so shared edges don't count."""
    xs = [p.x for p in tri]
    ys = [p.y for p in tri]
    a, b, c = tri
    d = (b.y - c.y) * (a.x - c.x) + (c.x - b.x) * (a.y - c.y)
    if abs(d) < 1e-12:
        return
    for y in range(int(min(ys)), int(max(ys)) + 1):
        for x in range(int(min(xs)), int(max(xs)) + 1):
            qx, qy = x + 0.5, y + 0.5
            l1 = ((b.y - c.y) * (qx - c.x) + (c.x - b.x) * (qy - c.y)) / d
            l2 = ((c.y - a.y) * (qx - c.x) + (a.x - c.x) * (qy - c.y)) / d
            if l1 > 0.05 and l2 > 0.05 and 1.0 - l1 - l2 > 0.05:
                yield (x, y)


def _scale_islands(low, centre, r, k):
    """Islands (UV-connected faces) with most of their area within r of centre grow k x about their middle."""
    bm = bmesh.new()
    bm.from_mesh(low.data)
    lay = bm.loops.layers.uv.active
    bm.faces.ensure_lookup_table()
    islands = _islands(bm, lay)
    grown = 0
    for faces in islands:
        area = sum(f.calc_area() for f in faces)
        inside = sum(f.calc_area() for f in faces if (f.calc_center_median() - centre).length < r)
        if area <= 0 or inside / area < 0.5:
            continue
        uvs = [lp[lay].uv for f in faces for lp in f.loops]
        mid = sum((Vector(u) for u in uvs), Vector((0, 0))) / len(uvs)
        for f in faces:
            for lp in f.loops:
                lp[lay].uv = mid + (lp[lay].uv - mid) * k
        grown += 1
    bm.to_mesh(low.data)
    bm.free()
    log("head: %d of %d islands grown x%.2f" % (grown, len(islands), k))


def _islands(bm, lay):
    seen = set()
    out = []
    for f in bm.faces:
        if f.index in seen:
            continue
        group, stack = [], [f]
        seen.add(f.index)
        while stack:
            g = stack.pop()
            group.append(g)
            for lp in g.loops:
                for other in lp.edge.link_faces:
                    if other.index in seen:
                        continue
                    lo = next(x for x in other.loops if x.edge == lp.edge)
                    a0, a1 = lp[lay].uv, lp.link_loop_next[lay].uv
                    b0, b1 = lo[lay].uv, lo.link_loop_next[lay].uv
                    if ((a0 - b1).length < 1e-6 and (a1 - b0).length < 1e-6) or \
                            ((a0 - b0).length < 1e-6 and (a1 - b1).length < 1e-6):
                        seen.add(other.index)
                        stack.append(other)
        out.append(group)
    return out


def bake_colour(high, low, size, cage, ray, margin_px):
    """The dense mesh's base colour (as emission, so nothing of the scene's light) onto the low mesh's UVs."""
    src = base_image(high)
    for m in high.data.materials:
        nt = m.node_tree
        tex = next(n for n in nt.nodes if n.type == "TEX_IMAGE" and n.image == src)
        tex.interpolation = "Cubic"
        em = nt.nodes.new("ShaderNodeEmission")
        nt.links.new(tex.outputs["Color"], em.inputs["Color"])
        out = next(n for n in nt.nodes if n.type == "OUTPUT_MATERIAL")
        nt.links.new(em.outputs[0], out.inputs["Surface"])
    img = bpy.data.images.new("baked", size, size, alpha=False)
    mat = bpy.data.materials.new("baked")
    mat.use_nodes = True
    node = mat.node_tree.nodes.new("ShaderNodeTexImage")
    node.image = img
    mat.node_tree.nodes.active = node
    low.data.materials.append(mat)
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.samples = 4
    sc.render.bake.margin = margin_px
    sc.render.bake.margin_type = "EXTEND"
    bpy.ops.object.select_all(action="DESELECT")
    high.select_set(True)
    low.select_set(True)
    bpy.context.view_layer.objects.active = low
    bpy.ops.object.bake(type="EMIT", use_selected_to_active=True, cage_extrusion=cage, max_ray_distance=ray,
                        margin=margin_px, margin_type="EXTEND", use_clear=True)
    log("baked %dx%d" % (size, size))
    return img


def export(low, img, path):
    img.name = "atlas"          # (the fit's .glb then writes it as <name>_atlas.jpg)
    img.filepath_raw = os.path.join(os.path.dirname(path), "atlas.png")
    img.file_format = "PNG"
    img.save()
    bsdf = low.data.materials[0].node_tree.nodes.get("Principled BSDF")
    node = next(n for n in low.data.materials[0].node_tree.nodes if n.type == "TEX_IMAGE")
    low.data.materials[0].node_tree.links.new(node.outputs[0], bsdf.inputs["Base Color"])
    for p in low.data.polygons:
        p.use_smooth = True
    bpy.ops.object.select_all(action="DESELECT")
    low.select_set(True)
    bpy.context.view_layer.objects.active = low
    bpy.ops.export_scene.gltf(filepath=path, use_selection=True, export_format="GLB", export_yup=True,
                              export_image_format="AUTO", export_texcoords=True, export_normals=True,
                              export_materials="EXPORT")
    log("wrote", path, "tris", tris(low))


def main():
    spec = json.load(open(sys.argv[sys.argv.index("--") + 1]))
    bpy.ops.wm.read_factory_settings(use_empty=True)
    high = import_dense(os.path.expanduser(spec["high"]))
    low = make_low(high, int(spec.get("tris", 36000)), int(spec.get("floater_verts", 60)), spec.get("head"),
                   int(spec.get("head_tris", 0)))
    unwrap(low, spec.get("head"), float(spec.get("head_uv", 2.0)), float(spec.get("uv_margin", 0.0008)),
           float(spec.get("uv_angle", 66.0)), int(spec.get("uv_smooth", 30)))
    img = bake_colour(high, low, int(spec.get("tex", 4096)), float(spec.get("cage", 0.008)),
                            float(spec.get("ray", 0.03)), int(spec.get("margin_px", 16)))
    export(low, img, os.path.expanduser(spec["out"]))
    if spec.get("blend"):
        bpy.ops.wm.save_as_mainfile(filepath=os.path.expanduser(spec["blend"]))


main()
