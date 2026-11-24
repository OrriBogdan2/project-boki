"""Keys the slam follow-through into five rig-contract clips in Blender (docs/art/SLAM_FOLLOW.md): a short impact hold,
a recoil and a recovery that ends on the idle carry, at the kit's own length. Only the bones' pose channels are keyed;
no mesh, head or material is touched. The poses are the clip's own (its impact, its recoil rise), so the model keeps its
look; each clip's `KEYS` row says which of them plays when.
Run: blender -b -P tools/art1/slam_follow_keys.py -- <hero glb> <hero> <out source.glb>
  hero: breaker (lmb_slam, x_slam) | tarek (rmb_land) | dredge (quake) | kael (meteor_land)
Then splice onto the shipped glb with no further Blender (tools/art1/glb_add_clips.py, `=<clip>` takes that clip only):
  python3 tools/art1/glb_add_clips.py <glb> <out source.glb> =lmb_slam,=x_slam <glb>
A row of KEYS is (kit s, source clip s, carry weight): the new clip at kit s plays the old clip at source clip s, blended
toward the idle's first frame by the weight (1 = the idle carry). Poses are slerped, the curve through the rows is a
monotone cubic that is flat at both ends, and a row pair with the same source second is a hold. The last 0.05 s sit on the carry: the move's `blend_out` (0.05)
hands the body to the legs there, so the hand-back is not a blend across the recovery."""

import sys

import bpy

FPS_OUT = 60.0
# hero -> clip -> (length s, [(t, src, w), ...])
KEYS = {
    "breaker": {
        # t 0: the swing's last frames, 0.04 s: the impact, to 0.11 s: held, 0.2 s: the recoil's top, then down to the carry
        "lmb_slam": (
            0.5,
            [
                (0.0, 0.05, 0.0),
                (0.04, 0.10, 0.0),
                (0.11, 0.10, 0.0),
                (0.2, 0.233, 0.0),
                (0.45, 0.233, 1.0),
                (0.5, 0.233, 1.0),
            ],
        ),
        "x_slam": (
            0.6,
            [
                (0.0, 0.085, 0.0),
                (0.03, 0.10, 0.0),
                (0.11, 0.10, 0.0),
                (0.24, 0.30, 0.0),
                (0.55, 0.30, 1.0),
                (0.6, 0.30, 1.0),
            ],
        ),
    },
    "tarek": {
        # the landing's crouch held 0.08 s, the rise, the settle (the old clip's frozen stretch), then its recovery at 1:1
        "rmb_land": (
            0.75,
            [
                (0.0, 0.0, 0.0),
                (0.08, 0.0, 0.0),
                (0.17, 0.10, 0.0),
                (0.32, 0.30, 0.0),
                (0.45, 0.43, 0.0),
                (0.70, 0.733, 1.0),
                (0.75, 0.733, 1.0),
            ],
        ),
    },
    "dredge": {
        "quake": (
            0.75,
            [
                (0.0, 0.0, 0.0),
                (0.10, 0.0, 0.0),
                (0.2, 0.25, 0.0),
                (0.3, 0.33, 0.0),
                (0.5, 0.50, 0.0),
                (0.70, 0.733, 1.0),
                (0.75, 0.733, 1.0),
            ],
        ),
    },
    "kael": {
        # the old clip drags the sword along the ground at 0.1-0.18 s and snaps into the carry in its last 0.05 s: the keys
        # start on the settled sword (old 0.2 s), hold it, lift a little (old 0.29 s) and ease the body into the carry
        "meteor_land": (
            0.5,
            [(0.0, 0.20, 0.0), (0.10, 0.20, 0.0), (0.2, 0.29, 0.0), (0.45, 0.29, 1.0), (0.5, 0.29, 1.0)],
        ),
    },
}


def pchip(xs, ys, x):
    """Monotone cubic (Fritsch-Carlson) through the rows, zero slope at both ends."""
    n = len(xs)
    if x <= xs[0]:
        return ys[0]
    if x >= xs[-1]:
        return ys[-1]
    h = [xs[i + 1] - xs[i] for i in range(n - 1)]
    d = [(ys[i + 1] - ys[i]) / h[i] for i in range(n - 1)]
    m = [0.0] * n
    for i in range(1, n - 1):
        m[i] = 0.0 if d[i - 1] * d[i] <= 0 else 2.0 / (1.0 / d[i - 1] + 1.0 / d[i])
    i = max(k for k in range(n - 1) if xs[k] <= x)
    t = (x - xs[i]) / h[i]
    t2, t3 = t * t, t * t * t
    return (
        (2 * t3 - 3 * t2 + 1) * ys[i]
        + (t3 - 2 * t2 + t) * h[i] * m[i]
        + (-2 * t3 + 3 * t2) * ys[i + 1]
        + (t3 - t2) * h[i] * m[i + 1]
    )


def main():
    glb, hero, out = sys.argv[sys.argv.index("--") + 1 :][:3]
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=glb)
    arm = [o for o in bpy.data.objects if o.type == "ARMATURE"][0]
    scene = bpy.context.scene
    fps_in = scene.render.fps
    arm.animation_data_create()
    idle = bpy.data.actions["idle"]

    def sample(action, sec):
        arm.animation_data.action = action
        fr = sec * fps_in
        scene.frame_set(int(fr), subframe=fr - int(fr))
        return {pb.name: (pb.location.copy(), pb.rotation_quaternion.copy(), pb.scale.copy()) for pb in arm.pose.bones}

    carry = sample(idle, 0.0)
    made = []
    for clip, (length, rows) in KEYS[hero].items():
        old = bpy.data.actions[clip]
        ts, srcs, ws = [r[0] for r in rows], [r[1] for r in rows], [r[2] for r in rows]
        assert abs(ts[-1] - length) < 1e-6, (clip, ts[-1], length)
        frames = []
        for k in range(int(round(length * FPS_OUT)) + 1):
            t = min(k / FPS_OUT, length)
            p = sample(old, pchip(ts, srcs, t))
            w = pchip(ts, ws, t)
            frames.append(
                (
                    k,
                    {
                        nm: (
                            p[nm][0].lerp(carry[nm][0], w),
                            p[nm][1].slerp(carry[nm][1], w),
                            p[nm][2].lerp(carry[nm][2], w),
                        )
                        for nm in p
                    },
                )
            )
        old.name = clip + ".old"
        new = bpy.data.actions.new(clip)
        new.use_fake_user = True
        arm.animation_data.action = new
        for k, pose in frames:
            for pb in arm.pose.bones:
                loc, rot, scl = pose[pb.name]
                pb.location, pb.rotation_quaternion, pb.scale = loc, rot, scl
                pb.keyframe_insert("location", frame=k)
                pb.keyframe_insert("rotation_quaternion", frame=k)
                pb.keyframe_insert("scale", frame=k)
        made.append(new)
    for a in list(bpy.data.actions):
        if a not in made:
            bpy.data.actions.remove(a)
    scene.render.fps = int(FPS_OUT)
    arm.animation_data.action = made[0]
    bpy.ops.export_scene.gltf(
        filepath=out,
        export_format="GLB",
        export_animations=True,
        export_animation_mode="ACTIONS",
        export_image_format="NONE",
        export_force_sampling=True,
        export_optimize_animation_size=False,
    )
    print("SLAM_KEYS", hero, [a.name for a in made], "->", out)


if __name__ == "__main__":
    main()
