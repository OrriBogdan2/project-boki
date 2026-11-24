"""heelcap13.py -- lower the back heel kick (rig keys only) so the slim closed-back skirt needs less flare.
blender -b -P heelcap13.py -- IN.glb OUT.glb [clips=run,Jump_Run,Crouch_Walk_with_Torch zcap=0.55 back=0.04 reset_sw=1 measure=1]
Per frame and leg: if the foot is behind the hips (y > hips.y + back) and its head is above zcap (world z), the knee
(Leg bone) key is slerped toward its rest rotation until the foot is at zcap (bisection); the per-frame factor is
smoothed over +-2 frames so nothing pops. Thigh, hips, feet keys and every other clip are untouched."""

import bpy, sys, json
from mathutils import Quaternion

A = sys.argv[sys.argv.index("--") + 1 :]
SRC, OUT = A[0], A[1]
O = dict(a.split("=") for a in A if "=" in a)
CLIPS = O.get("clips", "run,Jump_Run,Crouch_Walk_with_Torch").split(",")
ZCAP, BACK = float(O.get("zcap", 0.55)), float(O.get("back", 0.04))
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SRC)
arm = [o for o in bpy.data.objects if o.type == "ARMATURE"][0]
W = arm.matrix_world
sc = bpy.context.scene
arm.animation_data_create()
I = Quaternion()


def foot(side):
    return W @ arm.pose.bones[side + "Foot"].head


def hips():
    return W @ arm.pose.bones["Hips"].head


rep = {}
for c in CLIPS:
    act = bpy.data.actions[c]
    arm.animation_data.action = act
    f0, f1 = int(act.frame_range[0]), int(act.frame_range[1])
    fr = list(range(f0, f1 + 1))
    keys = {s: {} for s in ("Left", "Right")}
    fac = {s: {} for s in ("Left", "Right")}
    before = {s: [] for s in ("Left", "Right")}
    for f in fr:
        sc.frame_set(f)
        for s in ("Left", "Right"):
            pb = arm.pose.bones[s + "Leg"]
            pb.rotation_mode = "QUATERNION"
            q = pb.rotation_quaternion.copy()
            keys[s][f] = q
            p, h = foot(s), hips()
            before[s].append((round(p.z, 3), round(p.y - h.y, 3)))
            t = 0.0
            if p.y - h.y > BACK and p.z > ZCAP:
                lo, hi = 0.0, 1.0
                for _ in range(14):
                    m = (lo + hi) / 2
                    pb.rotation_quaternion = q.slerp(I, m)
                    bpy.context.view_layer.update()
                    if foot(s).z > ZCAP:
                        lo = m
                    else:
                        hi = m
                t = hi
                pb.rotation_quaternion = q
                bpy.context.view_layer.update()
            fac[s][f] = t
    for s in fac:  # temporal smoothing: max over +-2 frames with falloff
        sm = {}
        for f in fr:
            sm[f] = max(fac[s].get(f + d, 0) * (1, 0.75, 0.4)[abs(d)] for d in range(-2, 3))
        fac[s] = sm
    dp = {s: 'pose.bones["%sLeg"].rotation_quaternion' % s for s in fac}
    rs = O.get("reset_sw") == "1"  # SkirtSw keys of the capped clips back to rest (refine13 re-solves them)
    for fc in [x for x in act.fcurves if x.data_path in dp.values() or (rs and "SkirtSw" in x.data_path)]:
        act.fcurves.remove(fc)
    after = {s: [] for s in fac}
    for f in fr:
        sc.frame_set(f)
        for s in fac:
            pb = arm.pose.bones[s + "Leg"]
            pb.rotation_quaternion = keys[s][f].slerp(I, fac[s][f])
            pb.keyframe_insert("rotation_quaternion", frame=f, group=s + "Leg")
        if rs:
            for b in [b for b in arm.pose.bones if b.name.startswith("SkirtSw")]:
                b.rotation_mode = "QUATERNION"
                b.rotation_quaternion = I
                b.keyframe_insert("rotation_quaternion", frame=f, group=b.name)
    for f in fr:
        sc.frame_set(f)
        for s in fac:
            p, h = foot(s), hips()
            after[s].append((round(p.z, 3), round(p.y - h.y, 3)))
    rep[c] = {
        s: {
            "max_foot_z_before": max(z for z, _ in before[s]),
            "max_foot_z_after": max(z for z, _ in after[s]),
            "frames_changed": sum(1 for f in fr if fac[s][f] > 0.01),
            "max_factor": round(max(fac[s].values()), 2),
        }
        for s in fac
    }
    print("HEELCAP", c, json.dumps(rep[c]), flush=True)
if O.get("measure") == "1":
    sys.exit(0)
bpy.ops.export_scene.gltf(
    filepath=OUT,
    export_format="GLB",
    export_animation_mode="ACTIONS",
    export_yup=True,
    export_apply=False,
    export_skins=True,
    export_all_influences=True,
    export_morph=False,
)
print("wrote", OUT)
