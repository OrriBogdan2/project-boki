"""Re-keys the clips of a built Boki .glb from its species' skeleton and clips module and writes it back, the body, face,
skin and atlases as they are. For a scanned species whose raw Meshy model is not at hand (`build_boki.py` needs it for
the bake): the .glb is read back into Blender, its actions are replaced by the module's CLIPS, it is exported again.
A module with SCAN_LEGS (a scan on the borrowed Glomwort rig) gets its legs first, if the file has none yet
(scan_legs.py: bones added, the file's own kept), and its planted clips are solved on the file's bones.

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
import scan_legs


def hidden_props(arm):
    """Where the file keys its unused props (collapsed inside the body), read off its idle: `HIDE_AT` as the build had it."""
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
    bpy.ops.import_scene.gltf(filepath=glb)
    arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
    have = {b.name for b in arm.data.bones}
    legs = getattr(anim, "LEG_BONES", {})
    assert have in (set(anim.BONES), set(anim.BONES) | set(legs)), "the file's skeleton is not the module's"
    if legs and not set(legs) <= have:
        body = next(o for o in bpy.data.objects if o.type == "MESH" and o.name == "Body")
        scan_legs.add(arm, body, anim.SCAN_LEGS)
    clips = anim.CLIPS
    if legs:
        fitted = scan_legs.game_bones(arm, build_boki.SCALE)
        clips = {n: c[:-1] + (c[-1].refit(fitted) if hasattr(c[-1], "refit") else c[-1],) for n, c in clips.items()}
    boki_rig.HIDE_AT.clear()
    boki_rig.HIDE_AT.update(hidden_props(arm))
    boki_rig.SCALED = set(getattr(anim, "SCALED", ()))
    arm.animation_data.action = None
    for action in list(bpy.data.actions):
        bpy.data.actions.remove(action)
    boki_rig.make_clips(arm, clips)
    boki_rig.export(glb, tangents=True)
    glb_tangents.fix(glb)


main()
