"""Relaxes a game Warden's skin weights in place: no edge past 1.3x its rest length in any clip, and no triangles cut.
The .glb is imported on its own armature (bone axes as exported, so the rest and the clips re-export unchanged), skin_relax
blends the weights of the stretched vertices toward their neighbours' (CUTS 0: nothing is cut or capped, so the triangle count stays),
and the same exporter settings as v95_swap.py write it back.
Use: blender -b --factory-startup --python tools/art1/relax_glb.py -- art/wardens/<id>/<id>.glb OUT.glb"""
import os
import sys

import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import skin_relax

SRC, OUT = (os.path.abspath(a) for a in sys.argv[sys.argv.index("--") + 1:][:2])


def main():
    bpy.ops.object.select_all(action="SELECT")       # (the factory scene's cube)
    bpy.ops.object.delete()
    bpy.ops.import_scene.gltf(filepath=SRC, bone_heuristic="BLENDER")
    arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
    tris = sum(len(p.vertices) - 2 for o in bpy.data.objects if o.type == "MESH" for p in o.data.polygons)
    skin_relax.CUTS = 0
    skin_relax.MAX_ITER, skin_relax.RINGS = 800, 2        # (the defaults, 60 and 1, stop at about 6x on these; 800 passes take ~30 min)
    skin_relax.relax(arm)
    for act in bpy.data.actions:       # an imported clip ends a hair under its last frame, and the export dropped that frame
        act.use_frame_range = True
        act.frame_start, act.frame_end = round(act.frame_range[0]), round(act.frame_range[1])
    bpy.ops.object.select_all(action="DESELECT")
    for o in bpy.data.objects:
        o.select_set(o.type in ("ARMATURE", "MESH", "EMPTY"))
    bpy.context.view_layer.objects.active = arm
    bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", use_selection=True, export_apply=False, export_animations=True,
                              export_animation_mode="ACTIONS", export_skins=True, export_yup=True, export_materials="EXPORT",
                              export_image_format="JPEG", export_jpeg_quality=92, export_extras=False, export_vertex_color="ACTIVE",
                              export_force_sampling=True, export_frame_step=1, export_optimize_animation_size=False, export_def_bones=False)
    print("RELAX exported", OUT, os.path.getsize(OUT), "tris", tris, flush=True)


main()
