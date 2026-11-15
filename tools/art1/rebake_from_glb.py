"""Re-keys clips of a shipped Warden on the game .glb itself, with no .blend: imports the .glb (bone axes as exported, the same way v95_swap.py does),
drops its actions and runs the hero's clip script on that armature (the keys in vex_clips.py / ostra_clips.py), writing a .glb with only the clips asked for.
Unchanged keys come back to within 1e-6, so a re-timed clip is the keys and nothing else. Then copy the clip onto the game .glb:
  blender -b --python tools/art1/rebake_from_glb.py -- <vex|ostra> <game.glb> <out.glb> <clip,clip>
  python3 tools/art1/glb_add_clips.py <game.glb> <out.glb> =<clip>[,=<clip>] [new.glb]   (a key without "=" is a prefix: it would also replace swap_aim for swap)
(A track that never moves is left out of the baked clip: the bone stays at its rest pose, as in the clips already shipped.)"""
import os
import sys
import bpy

HERE = os.path.dirname(os.path.abspath(__file__))
SCRIPTS = {"vex": "vex_clips.py", "ostra": "ostra_anim.py"}


def main():
    hero, glb, out, clips = sys.argv[sys.argv.index("--") + 1:][:4]
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=glb, bone_heuristic="BLENDER")
    for act in list(bpy.data.actions):
        bpy.data.actions.remove(act)
    bpy.context.scene.frame_start, bpy.context.scene.frame_end = 0, 600
    path = os.path.join(HERE, SCRIPTS[hero])
    src = open(path).read()
    if hero == "vex":                                 # (the script opens its own .blend; the armature is already here)
        sys.argv = ["blender", "--", glb, out, clips]
        src = src.replace("bpy.ops.wm.open_mainfile(filepath=a[0])", "pass")
    else:                                             # (reads the armature "Armature"; --export writes the .glb)
        next(o for o in bpy.data.objects if o.type == "ARMATURE").name = "Armature"
        sys.argv = ["blender", "--", clips, "--export", out]
    sys.path.insert(0, HERE)
    exec(compile(src, path, "exec"), {"__name__": "__main__", "__file__": path})


main()
