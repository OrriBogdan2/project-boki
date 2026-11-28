"""Re-keys the clips of a built Boki .glb from its species' clips module and writes it back, the body, face, skin
and atlases as they are. For a scanned species whose raw Meshy model is not at hand (`build_boki.py` needs it for
the bake): the .glb is read back into Blender, its actions are replaced by the module's CLIPS, it is exported again.

A file that `auto_legs.py` gave real legs keeps its planted-paw gait: for the clips in the module's `KEEP_LEGS`
(walk, run) the file's leg-bone curves and its root/hips height and squash are kept and laid under the module's
body turns, so the paws still plant (the stride and the clip's length are the file's). Every other clip is the
module's, the legs at rest.

  blender -b --factory-startup --python tools/boki/reclip_own.py -- --species=<id>
"""
import os
import re
import sys

import bpy

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import boki_rig
import build_boki
import glb_tangents

LEG_BONES = {12: ("fleg1", "fleg2", "fpaw", "hleg1", "hleg2", "hpaw"), 6: ("hleg1", "hleg2", "hpaw")}
BONE = re.compile(r'pose\.bones\["(.+?)"\]\.(\w+)')


def hidden_props(arm):
    """Where the file keys its unused props (collapsed inside the body), read off its idle."""
    arm.animation_data.action = bpy.data.actions["idle"]
    bpy.context.scene.frame_set(1)
    out = {}
    for b in arm.pose.bones:
        if b.name.startswith("prop_"):
            w = b.bone.matrix_local.to_quaternion() @ b.location / boki_rig.CLIP_SCALE
            out[b.name] = (w.x, w.z, -w.y)      # boki_rig.game_axis back again
    return out


def owned(path, legs):
    """Does the gait own this curve: a leg bone's, or the height and squash of root and hips."""
    m = BONE.match(path)
    return bool(m) and (m.group(1) in legs or (m.group(1) in ("root", "hips") and m.group(2) in ("location", "scale")))


def capture(action, legs):
    first = min(k.co[0] for fc in action.fcurves for k in fc.keyframe_points)
    last = max(k.co[0] for fc in action.fcurves for k in fc.keyframe_points)
    curves = [(fc.data_path, fc.array_index, fc.group.name if fc.group else "",
               [(k.co[0] - first, k.co[1], k.interpolation) for k in fc.keyframe_points])
              for fc in action.fcurves if owned(fc.data_path, legs)]
    return (last - first) / bpy.context.scene.render.fps, curves


def lay(action, curves):
    for fc in [f for f in action.fcurves if owned(f.data_path, LEG_NAMES)]:
        action.fcurves.remove(fc)
    for path, idx, group, keys in curves:
        fc = action.fcurves.new(data_path=path, index=idx, action_group=group or None)
        fc.keyframe_points.add(len(keys))
        for k, (f, v, interp) in zip(fc.keyframe_points, keys):
            k.co = (f + 1, v)
            k.interpolation = interp
        fc.update()


def main():
    global LEG_NAMES
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
    LEG_NAMES = {b + s for b in LEG_BONES.get(len(extra), ()) for s in (".L", ".R")}
    assert not extra or extra == LEG_NAMES, "unknown bones %s" % extra
    keep = [n for n in getattr(anim, "KEEP_LEGS", ()) if extra]
    gait = {n: capture(bpy.data.actions[n], LEG_NAMES) for n in keep}
    boki_rig.HIDE_AT.clear()
    boki_rig.HIDE_AT.update(hidden_props(arm))
    boki_rig.SCALED = set(getattr(anim, "SCALED", ()))
    arm.animation_data.action = None
    for action in list(bpy.data.actions):
        bpy.data.actions.remove(action)
    clips = {n: ((gait[n][0] if n in gait else v[0]), v[1], v[2]) for n, v in anim.CLIPS.items()}
    boki_rig.make_clips(arm, clips)
    for n in keep:
        lay(bpy.data.actions[n], gait[n][1])
    print("RECLIP", species, "legs kept under", keep, "re-keyed", sorted(clips))
    boki_rig.export(glb, tangents=True)
    glb_tangents.fix(glb)


main()
