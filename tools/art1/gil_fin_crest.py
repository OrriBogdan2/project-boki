"""Gil's dorsal fin and head crest on gil.glb, placement and export only (their shapes are Meshy create tasks):
each Meshy part is welded and cut to its triangle budget by the port's own make_low (UV seams held), sized and set
in the game frame (his right +X, front +Y, up +Z, soles on 0), given a 1024 px paint and an ink-room colour, and
weighted 1.0 to one bone: `skin-fin-back` on the hips (the upper back behind the collar) and `skin-crest` on the head
(under the hat's brim down the nape). Run (a part already on the file is replaced, so the step can run again):
blender -b --factory-startup --python tools/art1/gil_fin_crest.py -- GAME.glb FIN.glb CREST.glb OUT.glb"""

import math
import os
import sys

import bpy
import numpy as np
from mathutils import Euler, Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gil_sword_bag import export_game, import_game  # noqa: E402

import bake_warden as BW  # noqa: E402  (gil_sword_bag puts tools/meshy on the path)

FIN_TRIS, CREST_TRIS = 1100, 900  # the budgets (fin <= 1200, crest <= 1000)
FLOATER_VERTS = 60  # loose crumbs under this many vertices are dropped
SLABS = 8  # heights a part is cut into to find its root ridge
PAINT_PX = 1024
INK_ALPHA = 1.0  # COLOR_0 alpha 1 = the whole ink room (outline.gdshader INK_ROOM, 0.02 m)
# per part: material, bone, height (m), root-line top and bottom (y, z), spines pointing back (-Y)
PARTS = {
    "fin": {"mat": "skin-fin-back", "bone": "hips", "height": 0.43, "top": (-0.325, 1.08), "bottom": (-0.34, 0.66)},
    "crest": {"mat": "skin-crest", "bone": "head", "height": 0.14, "top": (-0.295, 1.26), "bottom": (-0.315, 1.12)},
}


def load_part(path):
    """The one mesh of a Meshy create .glb, its transform applied."""
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=path)
    new = [o for o in bpy.data.objects if o not in before]
    src = next(o for o in new if o.type == "MESH")
    for o in new:
        if o is not src:
            bpy.data.objects.remove(o)
    src.parent = None
    src.data.transform(src.matrix_world)
    src.matrix_world.identity()
    return src


def paint_of(ob, name):
    """The part's base colour image, cut to PAINT_PX, on a plain game material (rough 0.8, no metal, two-sided)."""
    nodes = ob.data.materials[0].node_tree.nodes
    img = next(n.image for n in nodes if n.type == "TEX_IMAGE").copy()
    img.scale(PAINT_PX, PAINT_PX)
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    mat.use_backface_culling = False
    pb = mat.node_tree.nodes["Principled BSDF"]
    pb.inputs["Metallic"].default_value = 0.0
    pb.inputs["Roughness"].default_value = 0.8
    tex = mat.node_tree.nodes.new("ShaderNodeTexImage")
    tex.image = img
    mat.node_tree.links.new(tex.outputs["Color"], pb.inputs["Base Color"])
    return mat


def place(ob, spec):
    """Roots on +X turned to the back (Meshy's spines point -X, its root ridge +X), the ridge `height` long from
    `top` to `bottom` (y, z) with its centre on that line."""
    ob.data.transform(Euler((0, 0, math.pi / 2)).to_matrix().to_4x4())
    co = np.array([v.co[:] for v in ob.data.vertices])
    z0, z1 = co[:, 2].min(), co[:, 2].max()
    slab = np.minimum(((co[:, 2] - z0) / (z1 - z0) * SLABS).astype(int), SLABS - 1)
    edge = [co[slab == i][np.argsort(co[slab == i][:, 1])[-3:]].mean(0) for i in range(SLABS) if (slab == i).any()]
    edge = np.array(edge)  # the root ridge: the three vertices furthest toward +Y in each slab
    a, b = np.polyfit(edge[:, 2], edge[:, 1], 1)
    end_top, end_bot = np.array([0.0, a * z1 + b, z1]), np.array([0.0, a * z0 + b, z0])
    (ty, tz), (by, bz) = spec["top"], spec["bottom"]
    ob.data.transform(Matrix.Scale(spec["height"] / np.linalg.norm(end_top - end_bot), 4))
    along = (end_top - end_bot)[1:]
    want = np.array([ty - by, tz - bz])
    turn = math.atan2(want[0], want[1]) - math.atan2(along[0], along[1])  # about X, the ridge onto the root line
    ob.data.transform(Euler((-turn, 0, 0)).to_matrix().to_4x4())
    co = np.array([v.co[:] for v in ob.data.vertices])
    mid = (end_top + end_bot) / 2 * (spec["height"] / np.linalg.norm(end_top - end_bot))
    mid = Matrix.Rotation(-turn, 3, "X") @ Vector(mid)
    ob.data.transform(Matrix.Translation((-co[:, 0].mean(), (ty + by) / 2 - mid.y, (tz + bz) / 2 - mid.z)))


def ink_colour(ob):
    ca = ob.data.color_attributes.new("Color", "FLOAT_COLOR", "POINT")
    ca.data.foreach_set("color", np.tile(np.array([1.0, 1.0, 1.0, INK_ALPHA], np.float32), len(ob.data.vertices)))
    ob.data.color_attributes.active_color = ca
    ob.data.color_attributes.render_color_index = ob.data.color_attributes.active_color_index


def main():
    game_path, fin_path, crest_path, out = sys.argv[sys.argv.index("--") + 1 :][:4]
    bpy.ops.wm.read_factory_settings(use_empty=True)
    new = import_game(game_path)
    arm = next(o for o in new if o.type == "ARMATURE")
    for o in [o for o in new if o.type == "MESH" and o.data.materials and o.data.materials[0].name in
              {p["mat"] for p in PARTS.values()}]:
        bpy.data.objects.remove(o)
    kept = [o for o in new if o.type == "MESH" and o.name in bpy.data.objects]
    for key, path, tris in (("fin", fin_path, FIN_TRIS), ("crest", crest_path, CREST_TRIS)):
        spec = PARTS[key]
        src = load_part(path)
        mat = paint_of(src, spec["mat"])
        bpy.ops.object.select_all(action="DESELECT")
        low = BW.make_low(src, tris, FLOATER_VERTS, keep_uv=True)
        bpy.data.objects.remove(src)
        low.data.materials.clear()
        low.data.materials.append(mat)
        place(low, spec)
        ink_colour(low)
        vg = low.vertex_groups.new(name=spec["bone"])
        vg.add(list(range(len(low.data.vertices))), 1.0, "REPLACE")
        low.parent = arm
        low.matrix_parent_inverse = arm.matrix_world.inverted()
        low.modifiers.new("Armature", "ARMATURE").object = arm
        low.name = low.data.name = "Fin" if key == "fin" else "Crest"
        kept.append(low)
        print("GIL", key, "tris", len(low.data.polygons), "bone", spec["bone"], flush=True)
    for o in bpy.data.objects:
        o.select_set(o.type != "MESH" or o in kept)
    export_game(out, arm)


main()
