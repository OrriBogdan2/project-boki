"""Kael v2's garden clips on the v2 rig (DECISIONS 2026-11-09): pet, give and cheer, copied onto kael.glb by glb_add_clips (everything else in it stays byte for byte).
The v2 rig has no feet, lids, brows or fingers: the shin ends at the ankle (kael_rig.json, 0.30 m), the rest is posekit's contract. His ready pose is not written out
but read off his own v2 idle (frame 0), so the three start and end on his stance and weight; a key here is what he does differently. The Unbroken is enormous and grim:
he goes down on one knee with the sword grounded in his right fist, the left hand (the big one) does the tending slowly, as if it might break; his cheer is the sword
raised once, no hop.
Run: blender -b --factory-startup --python tools/art1/kael_garden.py -- <kael.glb> [out.glb, default: the input]"""
import math
import os
import sys
import tempfile

import bpy
from mathutils import Quaternion, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import gardenkit
import kael_pieces as K
from glb_add_clips import add, read, write
from posekit import Clip, Solver, ang_dir as D, bake, FPS

SHIN = 0.30          # kael_rig.json: knee 0.492, ankle 0.192
NAMES = ("pet", "give", "cheer")


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
    fl, fr = ready["FL"], ready["FR"]

    def C(name, dur, keys, loop=False, base=ready):
        return Clip(name, dur, keys, base, loop)
    # on the right knee, the left foot out before it, the sword grounded on a slant out to his right front with the right fist resting on it
    tend = dict(ready, pel=(ready["pel"][0], 0.05, ready["pel"][2] - 0.46), prt=(0.2, ready["prt"][1], ready["prt"][2]), tor=(0.3, ready["tor"][1] * 0.5, ready["tor"][2]),
                hed=(0.34, 0.0, 0.0), FL=(fl[0], 0.34, a_z), FR=(fr[0] * 0.8, -0.3, a_z + 0.07), FLp=0.0, FRp=0.8, FLy=0.1, FRy=-0.2, G=(0.32, 0.18, 0.56),
                BE=be(-55, -29), skirt=0.4)
    pet_a = dict(tend, LP=(-0.05, 0.66, 0.74))
    give = dict(tend, LP=(-0.08, 0.66, 0.6), hed=(0.4, 0.0, 0.0))
    g = ready["G"]
    # the cheer: a dip, then the sword up and out to his right in the fist, the left fist raised once and held; no hop (he is too heavy and has too much left to carry)
    peak = dict(ready, G=(g[0] + 0.1, g[1] + 0.1, g[2] + 0.72), BE=be(-10, 64, (0, 1, 0)), LP=(-0.36, 0.2, 1.7), hed=(-0.2, 0.0, 0.0), pel=(ready["pel"][0], ready["pel"][1], ready["pel"][2] + 0.02), skirt=-0.2)
    P = {"kneel": tend, "pet_a": pet_a, "pet_b": dict(pet_a, LP=(-0.05, 0.52, 0.76), tor=(0.28, ready["tor"][1] * 0.5, ready["tor"][2])),
         "give": give, "give_in": dict(give, LP=(-0.08, 0.56, 0.6)),
         "dip": dict(ready, pel=(ready["pel"][0], ready["pel"][1], ready["pel"][2] - 0.14), tor=(0.24, ready["tor"][1], ready["tor"][2]), skirt=0.3),
         "up": dict(peak, G=(g[0] + 0.06, g[1] + 0.06, g[2] + 0.4), LP=(-0.3, 0.2, 1.3)), "peak": peak,
         "pump": dict(peak, G=(g[0] + 0.1, g[1] + 0.08, g[2] + 0.62), LP=(-0.36, 0.2, 1.6))}
    return gardenkit.clips(C, ready, P, {"lead": 0.12, "snap": 0.1})


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
