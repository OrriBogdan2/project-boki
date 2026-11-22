"""Re-keys the clips of a built Boki .glb from its species' skeleton and clips module and writes it back, the body,
face, skin and atlases as they are. For a scanned species whose raw Meshy model is not at hand (`build_boki.py`
needs it for the bake): the .glb is read back into Blender, its actions are replaced by the module's CLIPS, it
is exported again. A file that `auto_legs.py` gave real legs keeps its leg bones and its walk and run (the
planted-paw trot): only the other clips are re-keyed, with the legs at rest as auto_legs keys them.

  blender -b --factory-startup --python tools/boki/reclip.py -- --species=<id>
"""
import os
import sys

import bpy

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import boki_rig
import build_boki
import glb_tangents

# auto_legs.py's bones by how many it adds (.L and .R each): a quadruped's 12, a biped's 6
LEG_BONES = {12: ("fleg1", "fleg2", "fpaw", "hleg1", "hleg2", "hpaw"), 6: ("hleg1", "hleg2", "hpaw")}


def hidden_props(arm):
    """Where the file keys its unused props (collapsed inside the body), read off its idle: `HIDE_AT` as the build
    had it."""
    arm.animation_data.action = bpy.data.actions["idle"]
    bpy.context.scene.frame_set(1)
    out = {}
    for b in arm.pose.bones:
        if b.name.startswith("prop_"):
            w = b.bone.matrix_local.to_quaternion() @ b.location / boki_rig.CLIP_SCALE
            out[b.name] = (w.x, w.z, -w.y)      # boki_rig.game_axis back again
    return out


def main():
    species = next(a[10:] for a in sys.argv if a.startswith("--species="))
    build_boki.use_species(species)
    anim = build_boki.anim
    glb = os.path.join(build_boki.REPO, "art/kin", species, species + ".glb")
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.scene.render.fps = 30       # the clips are keyed at 30 fps: the importer's 24 would re-time kept ones
    bpy.ops.import_scene.gltf(filepath=glb)
    arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
    extra = {b.name for b in arm.data.bones} - set(anim.BONES)
    assert set(anim.BONES) <= {b.name for b in arm.data.bones}, "the file's skeleton is not the module's"
    legs = {b + s for b in LEG_BONES.get(len(extra), ()) for s in (".L", ".R")}
    assert not extra or extra == legs, "unknown bones %s" % extra
    keep = {"walk", "run"} if extra else set()      # auto_legs' trot: the module's walk and run would glide the paws
    boki_rig.HIDE_AT.clear()
    boki_rig.HIDE_AT.update(hidden_props(arm))
    boki_rig.SCALED = set(getattr(anim, "SCALED", ()))
    arm.animation_data.action = None
    for action in list(bpy.data.actions):
        if action.name in keep:
            action.use_fake_user = True
        else:
            bpy.data.actions.remove(action)
    boki_rig.make_clips(arm, {k: v for k, v in anim.CLIPS.items() if k not in keep})
    print("RECLIP", species, "kept", sorted(keep), "re-keyed", sorted(set(anim.CLIPS) - keep))
    boki_rig.export(glb, tangents=True)
    glb_tangents.fix(glb)


main()
