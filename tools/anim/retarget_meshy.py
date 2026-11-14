# blender -b --factory-startup --python retarget_meshy.py -- target.glb out.glb name=meshy.glb [name=...]
# World-space rotation retarget from a Meshy (Mixamo-style) rig onto the Boki warden contract bones.
import bpy, sys, math
from mathutils import Matrix, Vector, Quaternion

a = sys.argv[sys.argv.index("--") + 1 :]
LOOPS = ("idle", "run")
MAP = {
    "root": "Hips",
    "hips": "Spine",
    "head": "Head",
    "upper_arm.L": "LeftArm",
    "forearm.L": "LeftForeArm",
    "hand.L": "LeftHand",
    "upper_arm.R": "RightArm",
    "forearm.R": "RightForeArm",
    "hand.R": "RightHand",
    "thigh.L": "LeftUpLeg",
    "shin.L": "LeftLeg",
    "foot.L": "LeftFoot",
    "thigh.R": "RightUpLeg",
    "shin.R": "RightLeg",
    "foot.R": "RightFoot",
}
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=a[0])
T = next(o for o in bpy.data.objects if o.type == "ARMATURE")
keep = set(bpy.data.actions)
sc = bpy.context.scene


def rot(m):
    return m.to_3x3().normalized().to_quaternion()


for spec in a[2:]:
    name, path = spec.split("=", 1)
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=path)
    new = [o for o in bpy.data.objects if o not in before]
    S = next(o for o in new if o.type == "ARMATURE")
    S.matrix_world = Matrix.Rotation(math.pi, 4, "Z") @ S.matrix_world  # Meshy faces -Y, wardens face +Y
    sact = S.animation_data.action
    f0, f1 = [int(x) for x in sact.frame_range]
    srest = {b.name: S.matrix_world @ b.matrix_local for b in S.data.bones}
    trest = {b.name: b.matrix_local.copy() for b in T.data.bones}
    scale = trest["hips"].translation.z / srest["Hips"].translation.z
    act = bpy.data.actions.new(name)
    act.use_fake_user = True
    T.animation_data_create()
    T.animation_data.action = act
    for pb in T.pose.bones:
        pb.matrix_basis = Matrix()
    frames = list(range(f0, f1 + 1))
    hp = []
    for f in frames:
        sc.frame_set(f)
        hp.append((S.matrix_world @ S.pose.bones["Hips"].matrix).translation.copy())
    for i, f in enumerate(frames):
        sc.frame_set(f)
        sw = {n: S.matrix_world @ S.pose.bones[n].matrix for n in set(MAP.values())}
        bpy.context.view_layer.update()
        for tb in [
            "root",
            "hips",
            "head",
            "upper_arm.L",
            "forearm.L",
            "hand.L",
            "upper_arm.R",
            "forearm.R",
            "hand.R",
            "thigh.L",
            "shin.L",
            "foot.L",
            "thigh.R",
            "shin.R",
            "foot.R",
        ]:
            if tb not in T.pose.bones:
                continue
            sb = MAP[tb]
            d = rot(sw[sb]) @ rot(srest[sb]).inverted()
            want = d @ rot(trest[tb])
            pb = T.pose.bones[tb]
            if tb == "root":
                off = (hp[i] - srest["Hips"].translation) * scale
                if name.split("_")[-1] in LOOPS:  # in place: drop the drift, keep the bob and sway
                    t = i / max(1, len(frames) - 1)
                    drift = hp[0].lerp(hp[-1], t) - hp[0]
                    off -= Vector((drift.x, drift.y, 0)) * scale
                    off.x -= (hp[0].x - srest["Hips"].translation.x) * scale
                    off.y -= (hp[0].y - srest["Hips"].translation.y) * scale
                hip_head = trest["hips"].translation + off
                loc = hip_head - want.to_matrix() @ rot(trest["root"]).inverted().to_matrix() @ (
                    trest["hips"].translation - trest["root"].translation
                )
                pb.matrix = Matrix.LocRotScale(loc, want, None)
            else:
                par = pb.parent
                rel = rot(trest[par.name]).inverted() @ rot(trest[tb])
                q = (rot(par.matrix) @ rel).inverted() @ want
                pb.rotation_mode = "QUATERNION"
                pb.rotation_quaternion = q
                pb.location = (0, 0, 0)
            bpy.context.view_layer.update()
            pb.keyframe_insert("rotation_quaternion", frame=f - f0 + 1)
            if tb == "root":
                pb.keyframe_insert("location", frame=f - f0 + 1)
    for o in new:
        bpy.data.objects.remove(o)
    print("RETARGET", name, len(frames), "frames scale", round(scale, 3))
for ac in list(bpy.data.actions):
    if ac not in keep and ac.users == 0 and not ac.use_fake_user:
        bpy.data.actions.remove(ac)
T.animation_data.action = None
bpy.ops.export_scene.gltf(filepath=a[1], export_format="GLB", export_animation_mode="ACTIONS")
