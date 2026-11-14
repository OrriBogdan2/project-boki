"""A Hero's game .glb as the .blend its *_clips.py script keys on, for a re-key where the source .blend is not at hand:
the armature (bone axes as exported, so the clips re-export onto the same rest), the mesh and anchors, no actions (the
clip script keys fresh ones under the clips' own names). Each prop=name sets the scene property the clip script reads
(hem_clips "pinch", cinder_clips "palm") to the rest-pose world position of that empty (an anchor) or the tail of that
bone, where the *_finish.py build stored it. Control first: re-bake an untouched clip and compare it with the glb's.
Run: blender -b --factory-startup --python tools/art1/clip_blend.py -- <game.glb> <out.blend> [prop=name ...]"""
import sys

import bpy

a = sys.argv[sys.argv.index("--") + 1:]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=a[0], bone_heuristic="BLENDER")
arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
arm.data.pose_position = "REST"
bpy.context.view_layer.update()
for kv in a[2:]:
    key, name = kv.split("=")
    ob = bpy.data.objects.get(name)
    at = ob.matrix_world.translation if ob else arm.matrix_world @ arm.data.bones[name].tail_local
    bpy.context.scene[key] = [float(v) for v in at]
    print("prop", key, name, [round(float(v), 4) for v in at])
arm.data.pose_position = "POSE"
if arm.animation_data:
    arm.animation_data.action = None
for act in list(bpy.data.actions):
    bpy.data.actions.remove(act)
bpy.ops.wm.save_as_mainfile(filepath=a[1])
