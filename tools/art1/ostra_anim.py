"""Motley's clips (ART-1; id ostra): blender -b ostra.blend --python tools/art1/ostra_anim.py -- [only,clips] [--export out.glb]
Hand-keyed on poses (ostra_pose.py), sampled at 30 fps from frame 0, one action per clip. Times are the kit's: each action clip runs on the kit
move's own clock (scripts/match/kmoves_stone.gd) and WardenClips seeks it from there. His character: a jack-in-the-box. Still and grinning on
his spring, then sudden: everything is compress, release, overshoot, wobble. The box goes first, the body follows late."""
import math, os, sys
import bpy
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import anim_kit as A
import ostra_clips as C
import ostra_pose as PS

FPS = 30
WAVE = 7.0          # rad/s: the fingers' ripple; a loop's is rounded to whole turns of its length, so the seam closes
BREATH_AT = (0.0, -0.05, 1.06)     # x_breath's head: behind the waist, so the chest swells forward and up


def rib_cage(p):
    """x_breath's share of a hips-skinned point: the chest between the waist and the ruff, fading at the edges"""
    up = min(max((p.z - 1.06) / 0.08, 0.0), 1.0) * min(max((1.40 - p.z) / 0.08, 0.0), 1.0)
    return up * min(max((0.21 - abs(p.x)) / 0.05, 0.0), 1.0)


def write_action(arm, rig, name, spec):
    keys = PS.channel_keys(spec["keys"], spec.get("base", {}))
    length = spec["len"]
    step = 1
    nf = int(round(length * FPS / step))
    add = spec.get("add")
    wave = round(WAVE * length / math.tau) * math.tau / length if spec.get("loop") else WAVE
    act = bpy.data.actions.new(name)
    act.use_fake_user = True
    tracks = {}
    for i in range(nf + 1):
        t = i / nf * length
        P = PS.sample(keys, t)
        P["wph"] = t * wave
        if spec.get("loop"):
            P["crank"] = t / length * 360.0 * spec.get("turns", 1)
        if add:
            add(P, t)
        for bone, (q, tr, sc) in rig.solve(P).items():
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
                    flat += [t * FPS, v[a]]
                fc.keyframe_points.foreach_set("co", flat)
                for kp in fc.keyframe_points:
                    kp.interpolation = "LINEAR"
                fc.update()
    if act.slots:       # (assigned, the slot takes the armature's id type: the glTF exporter lists only those)
        arm.animation_data.action_slot = act.slots[0]
    return act


def main():
    a = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    only = a[0].split(",") if a and a[0] != "all" and not a[0].startswith("--") else None
    arm = bpy.data.objects["Armature"]
    A.add_breath(arm, BREATH_AT, rib_cage)
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
                                  export_animation_mode="ACTIONS", export_force_sampling=False, export_optimize_animation_size=False,
                                  export_skins=True, export_yup=True, export_materials="EXPORT", export_image_format="JPEG",
                                  export_jpeg_quality=92, export_extras=False)


main()
