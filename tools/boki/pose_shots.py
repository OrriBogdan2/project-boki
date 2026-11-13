"""blender -b <species>.blend --python tools/boki/pose_shots.py -- out_prefix clip:frame [clip:frame ...]
[--views=s,q,b]:
the rigged body in a clip's pose (props and grown parts hide as in game), flat-lit, for checking the skin of a build
(docs/art/kin/MESHY_BOKI_RECIPE.md). Writes <out_prefix>_<clip><frame>_<view>.png; views: f, q, s, b, t."""
import sys

import bpy

args = sys.argv[sys.argv.index("--") + 1:]
views = "s,q,b"
for a in args:
    if a.startswith("--views="):
        views = a[8:]
s = bpy.context.scene
s.render.engine = "BLENDER_WORKBENCH"
s.display.shading.light = "STUDIO"
s.display.shading.color_type = "TEXTURE"
s.render.resolution_x = s.render.resolution_y = 700
s.view_settings.view_transform = "Standard"
cam = bpy.data.objects.new("c", bpy.data.cameras.new("c"))
s.collection.objects.link(cam)
s.camera = cam
cam.data.type = "ORTHO"
cam.data.ortho_scale = 1.1
tgt = bpy.data.objects.new("t", None)
s.collection.objects.link(tgt)
tgt.location = (0, 0, 0.32)
con = cam.constraints.new("TRACK_TO")
con.target, con.track_axis, con.up_axis = tgt, "TRACK_NEGATIVE_Z", "UP_Y"
rig = bpy.data.objects["Rig"]
rig.animation_data_create()
at = {"f": (0, 3, 0.4), "q": (1.6, 2.4, 0.8), "s": (3, 0, 0.35), "b": (-1.2, -2.7, 1.0), "t": (0, 0.01, 3)}
for spec in [a for a in args[1:] if not a.startswith("--")]:
    clip, frame = spec.split(":")
    rig.animation_data.action = bpy.data.actions[clip]
    s.frame_set(int(frame))
    for v in views.split(","):
        cam.location = at[v]
        s.render.filepath = "%s_%s%s_%s.png" % (args[0], clip, frame, v)
        bpy.ops.render.render(write_still=True)
