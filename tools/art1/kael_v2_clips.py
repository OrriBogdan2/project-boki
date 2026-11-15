"""Kael v2's own keyed clips on the v2 rig (his other clips are the first Kael's, retargeted by kael_retarget.py). For now the three shared actions (item 145,
tools/art1/actionkit.py): stomp, drink, revive (the kneel beside a teammate; it replaces the retargeted rise-from-downed, which no state plays any more).
The v2 rig has no feet, lids, brows or fingers: the shin ends at the ankle (kael_rig.json, 0.30 m), the rest is posekit's contract. His ready pose is not
written out but read off his own v2 idle (frame 0), so the actions start and end on his stance and weight; a key here is what he does differently.
He is enormous and grim: the stomp is a slow lift and a dead drop, the sword stays in his right fist through all of it, the left hand drinks and presses.
Run: blender -b --factory-startup --python tools/art1/kael_v2_clips.py -- <kael.glb> [out.glb, default: the input]
(the glb is imported, the clips baked and exported, then copied onto the input by glb_add_clips: everything else in it stays byte for byte)."""
import math
import os
import sys
import tempfile

import bpy
from mathutils import Quaternion, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import actionkit
import kael_pieces as K
from glb_add_clips import add, read, write
from posekit import Clip, Solver, ang_dir as D, bake, FPS

SHIN = 0.30          # kael_rig.json: knee 0.492, ankle 0.192
NAMES = ("stomp", "drink", "revive")
MOUTH = (-0.07, 0.24, 1.53)     # the left wrist with the flask at his lips (armature space, standing)


def be(a, e, edge=(0, 0, 1)):
    return (D(a, e), edge)


def rig_of(arm):
    """posekit's rest data for the v2 build: the fist the sword is skinned in (kael_finish), the blade along kael_pieces.GRIP_DIR, its edge in the sagittal plane."""
    hr = arm.data.bones["hand.R"].head_local
    hl = arm.data.bones["hand.L"].head_local
    b = Vector(K.GRIP_DIR).normalized()
    e = b.cross(Vector((1, 0, 0))).normalized()
    e = e if e.z > 0 else -e
    return {"grip_rest": tuple(hr + Vector((0, 0, -0.08))), "blade_rest": tuple(b), "edge_rest": tuple(e), "pelvis": arm.data.bones["hips"].head_local.z,
            "hilt_l": 0.12, "lhand": {"k": (0, 1, -0.15), "o": (-1, 0, 0), "palm": tuple(hl + Vector((0.006, 0, -0.05)))}}


def solver(arm):
    s = Solver(arm, rig_of(arm))
    for sd in "LR":
        s.H0["foot." + sd] = s.H0["shin." + sd] + Vector((0, 0, -SHIN))
    return s


def unq(q):
    """posekit.eul's inverse: (pitch forward, yaw left, roll right)."""
    e = q.to_euler("YXZ")
    return (-e.x, e.z, e.y)


def ready_of(arm, s, clip="idle", frame=0):
    """His stance as posekit targets, read off a clip of his own by forward kinematics."""
    arm.animation_data_create()
    arm.animation_data.action = bpy.data.actions[clip]
    bpy.context.scene.frame_set(frame)
    bpy.context.view_layer.update()
    pb = arm.pose.bones
    Q = {n: pb[n].matrix.to_quaternion() @ s.R0[n].inverted() for n in ("root", "hips", "head", "hand.R")}
    piv = Vector((0, 0, s.rig["pelvis"]))
    root_at = pb["root"].head.copy()
    pel = root_at - piv + Q["root"] @ piv
    blade = Q["hand.R"] @ Vector(s.rig["blade_rest"])
    edge = Q["hand.R"] @ Vector(s.rig["edge_rest"])
    G = pb["hand.R"].matrix @ (s.b["hand.R"].matrix_local.inverted() @ Vector(s.rig["grip_rest"]))

    def ankle(sd):
        return pb["shin." + sd].matrix @ Vector((0, SHIN, 0))
    p = {"pel": tuple(pel), "prt": unq(Q["root"]), "tor": unq(Q["root"].inverted() @ Q["hips"]), "hed": unq(Q["hips"].inverted() @ Q["head"]),
         "G": tuple(G), "BE": (tuple(blade), tuple(edge)), "Lw": 0.0, "LP": tuple(pb["hand.L"].head), "FL": tuple(ankle("L")), "FR": tuple(ankle("R")),
         "FLy": 0.22, "FRy": -0.42, "FLp": 0.0, "FRp": 0.0, "skirt": 0.0}
    arm.animation_data.action = None
    return p


def clips(ready):
    a_z = 0.5 * (ready["FL"][2] + ready["FR"][2])
    g, lp = ready["G"], ready["LP"]

    def C(name, dur, keys, loop=False, base=ready):
        return Clip(name, dur, keys, base, loop)
    # the stomp: the sword drawn up and out to his right so the foot comes down clear of the blade; the left fist balls and swings back for the drop
    stomp = {"set": {"G": (g[0] + 0.06, g[1] - 0.04, g[2] + 0.04), "BE": be(-30, -38, (0.5, 0.2, 0.85))},
             "top": {"G": (g[0] + 0.12, g[1] - 0.1, g[2] + 0.16), "BE": be(-48, -20, (0.5, 0.0, 0.85)), "LP": (lp[0] - 0.06, lp[1] + 0.14, lp[2] + 0.2), "skirt": -0.3},
             "hit": {"G": (g[0] + 0.1, g[1] - 0.02, g[2] - 0.02), "BE": be(-34, -44, (0.5, 0.2, 0.85)), "LP": (lp[0] - 0.04, lp[1] - 0.12, lp[2] - 0.02), "skirt": 0.45},
             "reach": 0.2, "lift": 0.46}
    # the drink: only the left arm and the head; the sword hand stays where it was
    drink = {"sip": {}}
    # the revive kneel: the sword grounded on a slant out to his right front (fist to tip ~1.25 m, the point just in the ground, clear of the fallen),
    # the right fist resting on it; the left hand presses on the fallen
    kneel = {"kneel": {"G": (0.32, 0.18, 0.56), "BE": be(-55, -29, (0, 0, 1)), "LP": (-0.12, 0.52, 0.3), "skirt": 0.4, "hed": (0.34, 0.0, 0.0)}}
    return [actionkit.stomp(C, ready, a_z, ("G", "LP"), stomp), actionkit.drink(C, ready, MOUTH, drink), actionkit.revive(C, ready, a_z, ("LP",), kneel)]


def extras(P):
    return {"skirt": (Quaternion((1, 0, 0), 0.35 * P["skirt"]), None)} if P else {}


def keep(nm):
    return not (nm.startswith("spring") or nm.startswith("anchor") or nm in ("weapon_muzzle",))


if __name__ == "__main__":
    a = sys.argv[sys.argv.index("--") + 1:]
    src = os.path.abspath(a[0])
    out = os.path.abspath(a[1]) if len(a) > 1 else src
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=src, bone_heuristic="BLENDER")
    arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
    bpy.context.scene.render.fps = FPS
    s = solver(arm)
    ready = ready_of(arm, s)
    print("ready", {k: (tuple(round(x, 3) for x in v) if isinstance(v, tuple) and not isinstance(v[0], tuple) else v) for k, v in ready.items()})
    Q, _ = s.solve(ready)
    arm.animation_data.action = bpy.data.actions["idle"]
    bpy.context.scene.frame_set(0)
    bpy.context.view_layer.update()
    off = {n: round(math.degrees((arm.pose.bones[n].matrix.to_quaternion() @ s.R0[n].inverted()).rotation_difference(Q[n]).angle), 1)
           for n in ("hips", "head", "upper_arm.R", "forearm.R", "hand.R", "upper_arm.L", "forearm.L", "thigh.L", "shin.L", "thigh.R", "shin.R")}
    print("ready vs idle (deg)", off)
    arm.animation_data.action = None
    for act in list(bpy.data.actions):
        bpy.data.actions.remove(act)
    for c in clips(ready):
        bake(arm, c, s, extras)
    tmp = os.path.join(tempfile.mkdtemp(), "kael_actions.glb")
    bpy.ops.object.select_all(action="DESELECT")
    arm.select_set(True)
    for o in arm.children:
        o.select_set(True)
    bpy.ops.export_scene.gltf(filepath=tmp, export_format="GLB", use_selection=True, export_animations=True, export_animation_mode="ACTIONS", export_skins=True,
                              export_yup=True, export_force_sampling=True, export_frame_step=1, export_optimize_animation_size=False, export_def_bones=False,
                              export_materials="NONE")
    sj, sb = read(tmp)
    for an in sj["animations"]:
        an["channels"] = [ch for ch in an["channels"] if keep(sj["nodes"][ch["target"]["node"]].get("name", ""))]
    tj, tb = read(src)
    done = add(tj, tb, sj, sb, lambda n: n in NAMES)
    write(out, tj, tb)
    print("added", done, "->", out)
