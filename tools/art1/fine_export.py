"""The .glb export of a clip set where some clips are keyed faster than the scene (Clips.bake(fps=60): a strike that
crosses the body in a frame or two; at 30 fps the bones' slerp between two keys swings the hand off its path). The glTF
exporter samples bones at whole scene frames, so those clips go out in a second export at their own rate and are spliced
into the .glb by name (glb_add_clips.py). In the .blend they play at the scene's rate (slower)."""
import os

import bpy

import glb_add_clips


def export(arm, rates, out_glb, settings):
    """arm: the armature, one NLA track per clip; rates: {clip: fps} (Clips.rates, one rate); settings: the exporter's."""
    ad = arm.animation_data
    for tr in [x for x in ad.nla_tracks if x.name in rates]:
        ad.nla_tracks.remove(tr)
    bpy.ops.export_scene.gltf(filepath=out_glb, **settings)
    if not rates:
        return
    assert len(set(rates.values())) == 1, rates
    for tr in list(ad.nla_tracks):
        ad.nla_tracks.remove(tr)
    for name in rates:
        act = bpy.data.actions[name]
        ad.action = act
        if len(act.slots) and ad.action_slot is None:
            ad.action_slot = act.slots[0]
        tr = ad.nla_tracks.new()
        tr.name = name
        tr.strips.new(name, 0, act)
        ad.action = None
    scene = bpy.context.scene
    fps = scene.render.fps
    scene.render.fps = next(iter(rates.values()))
    fine = out_glb + ".fine.glb"
    bpy.ops.export_scene.gltf(filepath=fine, **settings)
    scene.render.fps = fps
    tj, tb = glb_add_clips.read(out_glb)
    sj, sb = glb_add_clips.read(fine)
    glb_add_clips.add(tj, tb, sj, sb, lambda n: n in rates)
    glb_add_clips.write(out_glb, tj, tb)
    os.remove(fine)
