"""Re-bakes a Hero's hand-keyed clips on the armature of its shipped .glb, for when the build's WORK .blend is gone: the
.glb comes in with its bones as exported (bone_heuristic BLENDER, so the rest re-exports unchanged), its clips are
dropped, and the Hero's clip script runs on it as on WORK/<hero>_art1.blend. Take the clips you changed back into the
game .glb with glb_add_clips.py (everything else stays byte for byte).
Run: blender -b --factory-startup --python tools/art1/glb_rebake.py -- GAME.glb CLIPS.py OUT.blend OUT.glb"""
import os
import runpy
import sys

import bpy

game, script, out_blend, out_glb = sys.argv[sys.argv.index("--") + 1:][:4]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=game, bone_heuristic="BLENDER")
next(o for o in bpy.data.objects if o.type == "ARMATURE").name = "Armature"
for o in bpy.data.objects:
    if o.animation_data:
        o.animation_data.action = None
        for tr in list(o.animation_data.nla_tracks):
            o.animation_data.nla_tracks.remove(tr)
for act in list(bpy.data.actions):
    bpy.data.actions.remove(act)
sys.argv = [script, "--", out_blend, out_glb]
runpy.run_path(os.path.abspath(script), run_name="__main__")
