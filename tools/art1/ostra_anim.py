"""Ostra's clips (ART-1): blender -b ostra.blend --python tools/art1/ostra_anim.py -- [only,clips] [--export out.glb]
Hand-keyed on poses (ostra_pose.py), sampled per frame, one action per clip. Times are the kit's: each action clip runs on the kit move's
own clock (scripts/match/kmoves_stone.gd; the key times in the comments are its beats) and WardenClips seeks it from there. His character
(docs: archetype personality): unnervingly still, leaning in with his head tipped, a puppeteer's fingers forever working; when he moves it is
sudden and jerky, the marionette a hand has yanked, then still again. The legs are smoke: the wisp and the coat answer on their springs."""
import math, os, sys
import bpy
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ostra_clips as C
import ostra_pose as PS

FPS = 60


def write_action(arm, rig, name, spec):
    keys = PS.channel_keys(spec["keys"], spec.get("base", {}))
    length = spec["len"]
    step = spec.get("step", 2 if length < 1.2 else 3)
    nf = int(round(length * FPS / step))
    add = spec.get("add")
    act = bpy.data.actions.new(name)
    act.use_fake_user = True
    tracks = {}
    for i in range(nf + 1):
        t = i / nf * length
        P = PS.sample(keys, t)
        if add:
            add(P, t)
        for bone, (q, tr, sc) in rig.solve(P, t).items():
            d = tracks.setdefault(bone, {"r": [], "t": [], "s": []})
            d["r"].append((t, q))
            if tr is not None:
                d["t"].append((t, tr))
            if sc is not None:
                d["s"].append((t, sc))
    arm.animation_data_create()
    arm.animation_data.action = act
    for bone, d in tracks.items():
        path = 'pose.bones["%s"]' % bone
        prev = None
        for t, q in d["r"]:          # (keep the quaternions on one side, so a blend takes the short way)
            if prev is not None and prev.dot(q) < 0:
                q.negate()
            prev = q
        for prop, idx, seq in (("rotation_quaternion", 4, d["r"]), ("location", 3, d["t"]), ("scale", 3, d["s"])):
            if not seq:
                continue
            for a in range(idx):
                fc = act.fcurves.new(path + "." + prop, index=a, action_group=bone)
                fc.keyframe_points.add(len(seq))
                flat = []
                for t, v in seq:
                    flat += [t * FPS + 1, v[a]]
                fc.keyframe_points.foreach_set("co", flat)
                for kp in fc.keyframe_points:
                    kp.interpolation = "LINEAR"
                fc.update()
    return act


def main():
    a = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    only = a[0].split(",") if a and a[0] != "all" and not a[0].startswith("--") else None
    arm = bpy.data.objects["Armature"]
    for pb in arm.pose.bones:
        pb.rotation_mode = "QUATERNION"
    rig = PS.Rig(arm)
    bpy.context.scene.render.fps = FPS
    for nm, sp in C.CLIPS.items():
        if only is None or nm in only:
            write_action(arm, rig, nm, sp)
            print("CLIP", nm, sp["len"])
    if "--save" in a:
        bpy.ops.wm.save_as_mainfile(filepath=a[a.index("--save") + 1])
    if "--export" in a:
        path = a[a.index("--export") + 1]
        arm.animation_data.action = None
        bpy.ops.object.select_all(action="SELECT")
        bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_apply=False, export_animations=True,
                                  export_animation_mode="ACTIONS", export_force_sampling=False, export_optimize_animation_size=True,
                                  export_optimize_animation_keep_anim_armature=False, export_frame_step=1, export_skins=True,
                                  export_yup=True, export_materials="EXPORT", export_image_format="JPEG", export_jpeg_quality=92,
                                  export_extras=False, export_def_bones=False, export_rest_position_armature=True,
                                  export_animation_mode_all=False if False else None) if False else \
            bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_apply=False, export_animations=True,
                                      export_animation_mode="ACTIONS", export_force_sampling=False, export_optimize_animation_size=True,
                                      export_optimize_animation_keep_anim_armature=False, export_skins=True, export_yup=True,
                                      export_materials="EXPORT", export_image_format="JPEG", export_jpeg_quality=92, export_extras=False)


main()
