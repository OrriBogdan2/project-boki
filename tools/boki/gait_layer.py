"""Lays a species' own body motion over the walk and run `auto_legs.py` keyed (the planted-paw trot), leaving the legs
exactly as they are: the module's `GAIT` maps "walk" and "run" to a function of t (0..1 round the loop) that returns
rotations for the body bones (root, hips, spine, neck, head), added on top of the keyed ones. Run it once after
`reclip.py` on a file whose walk and run are still the plain trot (to redo it, run `auto_legs.py` again first).

  blender -b --factory-startup --python tools/boki/gait_layer.py -- --species=<id>
"""

import os
import sys

import bpy

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import boki_rig
import build_boki
import glb_tangents

BODY = ("root", "hips", "spine", "neck", "head")


def layer(arm, name, fn):
    action = bpy.data.actions[name]
    arm.animation_data.action = action
    first, last = int(action.frame_range[0]), int(action.frame_range[1])
    rest = {b.name: b.bone.matrix_local.to_quaternion() for b in arm.pose.bones}
    for f in range(first, last + 1):
        bpy.context.scene.frame_set(f)
        pose = fn((f - first) / (last - first))
        for b in arm.pose.bones:
            if b.name in BODY and b.name in pose:
                b.rotation_quaternion = b.rotation_quaternion @ (
                    rest[b.name].inverted() @ boki_rig.quat_of(*pose[b.name]) @ rest[b.name]
                )
                b.keyframe_insert("rotation_quaternion", frame=f)


def main():
    species = next(a[10:] for a in sys.argv if a.startswith("--species="))
    build_boki.use_species(species)
    glb = os.path.join(build_boki.REPO, "art/kin", species, species + ".glb")
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.scene.render.fps = 30  # the clips are keyed at 30 fps: the importer's 24 would re-time them
    bpy.ops.import_scene.gltf(filepath=glb)
    arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
    for action in bpy.data.actions:
        action.use_fake_user = True
    for name, fn in build_boki.anim.GAIT.items():
        layer(arm, name, fn)
    arm.animation_data.action = None
    print("GAIT_LAYER", species, sorted(build_boki.anim.GAIT))
    boki_rig.export(glb, tangents=True)
    glb_tangents.fix(glb)


main()
