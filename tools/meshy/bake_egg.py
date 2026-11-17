"""Bakes a Meshy egg into the game's egg model: art/eggs/<kind>.glb (docs/art/EGGS.md).

  blender -b --factory-startup --python tools/meshy/bake_egg.py -- MESHY.glb OUT.glb [--yaw=DEG]

Centres the egg on the ground, fits it to 1 m tall and WIDE wide, turns it by --yaw so its front (the emblem)
faces the game's +Z (Blender's -Y; check with the front render in docs/art/EGGS.md), thins the mesh,
shrinks its colour map, and cuts it at half height into "Cap" and "Cup": EggHatch splits the shell there
when it hatches. No PBR maps: the game draws it with its own toon light and ink.
"""
import math
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

TRIS = 2400        # triangles kept for the whole egg (both halves)
TEX = 512          # px: the colour map's side
SPLIT = 0.5        # the cut, as a fraction of the egg's height (EggHatch's middle)
WIDE = 0.736       # width / height: EggHatch's shell shape (0.92 / 1.25), so its cracks sit on the shell


def main():
    args = sys.argv[sys.argv.index("--") + 1:]
    src, out = args[0], args[1]
    yaw = next((float(a.split("=")[1]) for a in args if a.startswith("--yaw=")), 0.0)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=src)
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    bpy.ops.object.select_all(action="DESELECT")
    for o in meshes:
        o.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    if len(meshes) > 1:
        bpy.ops.object.join()
    egg = bpy.context.view_layer.objects.active
    egg.parent = None
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    me = egg.data
    me.transform(Matrix.Rotation(math.radians(yaw), 4, "Z"))
    lo = Vector([min(v.co[i] for v in me.vertices) for i in range(3)])
    hi = Vector([max(v.co[i] for v in me.vertices) for i in range(3)])
    fit = Matrix.Diagonal((WIDE / (hi.x - lo.x), WIDE / (hi.y - lo.y), 1.0 / (hi.z - lo.z), 1.0))
    me.transform(fit @ Matrix.Translation(-Vector(((lo.x + hi.x) / 2, (lo.y + hi.y) / 2, lo.z))))
    dec = egg.modifiers.new("thin", "DECIMATE")
    dec.ratio = min(1.0, TRIS / max(1, len(me.polygons)))
    bpy.ops.object.modifier_apply(modifier=dec.name)
    bm = bmesh.new()
    bm.from_mesh(me)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.0005)
    bm.to_mesh(me)
    bm.free()
    for p in me.polygons:
        p.use_smooth = True
    for mat in me.materials:
        _base_colour_only(mat)
    cup = egg.copy()
    cup.data = me.copy()
    bpy.context.scene.collection.objects.link(cup)
    _cut(egg, keep_top=True)
    _cut(cup, keep_top=False)
    egg.name = egg.data.name = "Cap"
    cup.name = cup.data.name = "Cup"
    bpy.ops.export_scene.gltf(filepath=out, export_format="GLB", export_image_format="WEBP",
                              export_materials="EXPORT", export_yup=True, export_apply=True)
    print("wrote", out, len(egg.data.polygons) + len(cup.data.polygons), "tris")


def _cut(obj, keep_top):
    """Keeps one side of the half-height plane, leaving the cut open (EggHatch shades the inside)."""
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    geom = bm.verts[:] + bm.edges[:] + bm.faces[:]
    bmesh.ops.bisect_plane(bm, geom=geom, plane_co=(0, 0, SPLIT), plane_no=(0, 0, 1),
                           clear_inner=keep_top, clear_outer=not keep_top)
    bm.to_mesh(obj.data)
    bm.free()


def _base_colour_only(mat):
    """Drops every map but the base colour, shrunk to TEX px."""
    nodes = mat.node_tree.nodes
    bsdf = next(n for n in nodes if n.type == "BSDF_PRINCIPLED")
    for name in ("Metallic", "Roughness", "Normal", "Emission Color"):
        for link in list(bsdf.inputs[name].links):
            mat.node_tree.links.remove(link)
    bsdf.inputs["Metallic"].default_value = 0.0
    bsdf.inputs["Roughness"].default_value = 1.0
    for link in bsdf.inputs["Base Color"].links:
        img = link.from_node.image
        if img and max(img.size) > TEX:
            img.scale(TEX, TEX)


main()
