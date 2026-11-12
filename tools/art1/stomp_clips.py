"""A starter Hunter's own stomp (DECISIONS 2026-11-11 "stomping", docs/decisions/0061-stomp-lock.md) as two clips on its v95 rig:
stomp_in   the 0.2 s hold that commits you (Stomp.COMMIT): the weight goes onto the standing leg, the heel comes up
stomp      the fixed 3.0 s finisher (Stomp.TIME): three beats (Stomp.BEATS), each a wind-up and a strike that lands on the
           wisp exactly on Stomp's slam (Stomp.SLAM of the beat: 0.8, 1.8, 2.8 s), the first wind-up the biggest; then a
           hold on the wisp to the kill. Ends of the two clips meet, so the commit flows into the finisher.
Weight is per Hunter (WEIGHT): how high and how fast the foot comes up, how far the pelvis drops into the strike and how
long it takes to come back. Kael lifts slowly and drops dead; Lace flicks a pointed heel and bounces off it.
The keys are posekit targets (pelvis, torso, head, ankles) laid over the Hunter's own idle (frame 0), which is also
where the arms and every other bone stay unless WEIGHT turns a shoulder; posekit's leg IK keeps the standing foot planted.
Run: blender -b --factory-startup --python tools/art1/stomp_clips.py -- <id: kael | vex | hem | breaker | claire | cinder | tarek | ryzz> [glb, default art/wardens/<id>/<id>.glb]
(the glb is imported, the two clips baked and exported, then copied onto it by glb_add_clips: everything else stays byte for byte)."""
import math
import os
import sys
import tempfile

import bpy
from mathutils import Matrix, Quaternion, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from glb_add_clips import add, read, write
from posekit import Clip, FPS, Solver, eul

COMMIT = 0.2      # s, Stomp.COMMIT: the hold before the finisher starts
TIME = 3.0        # s, Stomp.TIME: the finisher, start to kill
BEATS = 3         # Stomp.BEATS: strikes in TIME
SLAM = 0.8        # Stomp.SLAM: where in a beat the foot lands
NAMES = ("stomp_in", "stomp")

# Per Hunter, all right-footed (their stomps.json styles). lift/reach/drop/crouch/rise/shift in metres, angles in radians,
# times in fractions of a beat. top: when the foot peaks (a later top is a slower wind-up); settle: how long the body
# takes to come back off a strike; toe: the lifted foot's pitch (toe down); lean: forward tilt through the stomp;
# back: the lean back at the top; power: each beat's lift against the first; arms: shoulder turns (forward swing, out)
# at the top and on the strike; "shin": a rig whose shin ends at the ankle (Kael v2, Albert: no foot bone).
# foot: "R" (default), "L" or "both" (a two-footed drop, the hips hop by "hop"); shift is towards the standing leg for either foot;
# grind: the torso yaw driven into the strike; listen: (yaw, roll) of the head on the hold.
WEIGHT = {
    # Kael (juggernaut, Arena Slam): enormous; the knee comes up slowly, the foot falls like a dropped anvil, the hips
    # sink deep and stay down; both fists swing up with the lift and hammer down with the strike
    "kael": {"lift": 0.38, "reach": 0.2, "top": 0.6, "settle": 0.2, "drop": 0.16, "crouch": 0.07, "rise": 0.0, "shift": -0.06,
             "toe": 0.0, "lean": 0.3, "back": 0.12, "twist": 0.12, "power": (1.1, 0.8, 1.2), "shin": 0.30,
             "arms": {"top": {"aL": (0.9, 0.3), "aR": (0.45, 0.2)}, "hit": {"aL": (0.35, 0.1), "aR": (0.15, 0.15)}}},
    # Vex (gunslinger, Boot Heel): a street brawler's heel, leaning in; the cannon arm stays aimed down at the wisp
    "vex": {"lift": 0.34, "reach": 0.2, "top": 0.5, "settle": 0.12, "drop": 0.08, "crouch": 0.03, "rise": 0.01, "shift": -0.04,
            "toe": -0.35, "lean": 0.24, "back": 0.06, "twist": -0.1, "power": (1.1, 0.85, 1.15),
            "arms": {"top": {"aL": (0.2, 0.5), "aR": (-0.55, 0.05)}, "hit": {"aL": (0.05, 0.3), "aR": (-0.75, 0.05)}}},
    # Lace (archer, Needle Heel): light and poised; a quick high flick, a hang on the toes, a pointed heel that barely
    # bends her, the hand stays on her hip and the bow hand floats out for balance
    "hem": {"lift": 0.3, "reach": 0.16, "top": 0.4, "settle": 0.07, "drop": 0.03, "crouch": 0.0, "rise": 0.025, "shift": -0.03,
            "toe": -0.7, "lean": 0.06, "back": 0.04, "twist": 0.06, "power": (1.1, 0.9, 1.1),
            "arms": {"top": {"aL": (0.1, 0.3)}, "hit": {"aL": (0.0, 0.15)}}},
    # Albert (bulwark, Anchor Drop): a hull on two stubs that can't lunge, so the whole ball rocks back on its heels, hops and
    # drops both feet like an anchor; the arms heave up with it and slam down
    "breaker": {"foot": "both", "lift": 0.07, "reach": 0.0, "top": 0.62, "settle": 0.2, "drop": 0.05, "crouch": 0.03, "hop": 0.05, "rise": 0.0,
                "shift": 0.0, "toe": 0.0, "lean": 0.22, "back": 0.15, "twist": 0.0, "power": (1.0, 0.9, 1.25), "shin": 0.05,
                "arms": {"top": {"aL": (1.1, 0.35), "aR": (1.1, 0.35)}, "hit": {"aL": (0.2, 0.1), "aR": (0.0, 0.1)}}},
    # Neve (rimewright, Toe Pick): the festival's show-skater; a high pointed toe that stabs the ice, a counter-turn of the
    # shoulders, arms wide for balance, the finish held like the end of a routine
    "claire": {"lift": 0.34, "reach": 0.16, "top": 0.5, "settle": 0.1, "drop": 0.04, "crouch": 0.0, "rise": 0.02, "shift": -0.03,
               "toe": -1.0, "lean": 0.2, "back": 0.04, "twist": 0.25, "power": (1.1, 0.95, 1.15),
               "arms": {"top": {"aL": (0.1, 0.9), "aR": (0.1, 0.9)}, "hit": {"aL": (0.1, 0.5), "aR": (0.1, 0.5)}}},
    # Cinder (ashwick, Ember Grind): certain, not mad; a slow deliberate lift of the left foot, every beat surer than the last, the
    # heel set and ground in with a turn of the hips, bare hands open at her sides
    "cinder": {"foot": "L", "lift": 0.3, "reach": 0.14, "top": 0.65, "settle": 0.15, "drop": 0.05, "crouch": 0.02, "rise": 0.0, "shift": -0.04,
               "toe": -0.3, "lean": 0.12, "back": 0.04, "twist": 0.2, "grind": 0.35, "power": (1.0, 1.1, 1.25),
               "arms": {"top": {"aL": (0.35, 0.4), "aR": (0.35, 0.4)}, "hit": {"aL": (0.15, 0.55), "aR": (0.15, 0.55)}}},
    # Tenzo (dolm, Stone Listen): the young calm blind one; a short gentle lift and a flat foot set down like feeling for the
    # rock, upright with the chin up, arms a little wide, and on the hold the head turns to listen to the ground
    "tarek": {"lift": 0.3, "reach": 0.1, "top": 0.55, "settle": 0.15, "drop": 0.04, "crouch": 0.02, "rise": 0.0, "shift": -0.04,
              "toe": 0.0, "lean": -0.05, "back": 0.05, "twist": 0.0, "power": (1.0, 1.0, 1.1), "listen": (0.35, 0.15),
              "arms": {"top": {"aL": (0.05, 0.55), "aR": (0.05, 0.55)}, "hit": {"aL": (0.0, 0.35), "aR": (0.0, 0.35)}}},
    # Sparkle (mage, Spark Hop): a street kid, all snap: a quick high left knee, fists thrown up with it, a bouncy strike that
    # springs off the beat, a bigger one each time
    "ryzz": {"foot": "L", "lift": 0.36, "reach": 0.2, "top": 0.35, "settle": 0.12, "drop": 0.07, "crouch": 0.0, "rise": 0.03, "shift": -0.03,
             "toe": -0.5, "lean": 0.18, "back": 0.1, "twist": -0.2, "power": (1.0, 1.15, 1.3),
             "arms": {"top": {"aL": (1.2, 0.5), "aR": (1.2, 0.5)}, "hit": {"aL": (0.5, 0.3), "aR": (0.5, 0.3)}}},
}


def add3(a, b):
    return tuple(x + y for x, y in zip(a, b))


def unq(q):
    """posekit.eul's inverse: (pitch forward, yaw left, roll right)."""
    e = q.to_euler("YXZ")
    return (-e.x, e.z, e.y)


class StompSolver(Solver):
    """posekit's body and legs only: the arms and everything else stay on the idle (they ride the torso)."""

    def __init__(self, arm, shin):
        hips = arm.data.bones["hips"].head_local.z
        super().__init__(arm, {"blade_rest": (1, 0, 0), "edge_rest": (0, 0, 1), "pelvis": hips})
        self.shin = shin
        for sd in "LR":
            if shin:
                self.H0["foot." + sd] = self.H0["shin." + sd] + Vector((0, 0, -shin))
        self.foot_q = {}

    def ankle(self, pb, sd):
        if self.shin:
            return pb["shin." + sd].matrix @ Vector((0, self.shin, 0))
        return pb["foot." + sd].head.copy()

    def solve(self, P):
        piv = Vector((0, 0, self.rig["pelvis"]))
        q_root = eul(P["prt"])
        root_at = piv + Vector(P["pel"]) - q_root @ piv
        q_hips = q_root @ eul(P["tor"])
        Q = {"root": q_root, "hips": q_hips, "head": q_hips @ eul(P["hed"])}
        for sd in "LR":
            hip = q_root @ (self.H0["thigh." + sd] - self.H0["root"]) + root_at
            Q["thigh." + sd], Q["shin." + sd] = self.leg_ik(sd, hip, Vector(P["F" + sd]), Vector(P["K" + sd]), q_root)
            if sd in self.foot_q:
                Q["foot." + sd] = Quaternion((1, 0, 0), P["F" + sd + "p"]) @ self.foot_q[sd]
        return Q, root_at


def ready_of(arm, s):
    """The idle's frame 0 as targets, and every bone's local pose there (the clips' base)."""
    pb = arm.pose.bones
    Q = {n: pb[n].matrix.to_quaternion() @ s.R0[n].inverted() for n in ("root", "hips", "head")}
    piv = Vector((0, 0, s.rig["pelvis"]))
    p = {"pel": tuple(pb["root"].head - piv + Q["root"] @ piv), "prt": unq(Q["root"]), "tor": unq(Q["root"].inverted() @ Q["hips"]),
         "hed": unq(Q["hips"].inverted() @ Q["head"]), "aL": (0.0, 0.0), "aR": (0.0, 0.0)}
    for sd in "LR":
        a = s.ankle(pb, sd)
        p["F" + sd] = tuple(a)
        p["F" + sd + "p"] = 0.0
        p["K" + sd] = tuple(pb["shin." + sd].head - 0.5 * (pb["thigh." + sd].head + a))     # the knee's way, off the idle
        if "foot." + sd in pb:
            s.foot_q[sd] = pb["foot." + sd].matrix.to_quaternion() @ s.R0["foot." + sd].inverted()
    base = {b.name: (b.location.copy(), b.rotation_quaternion.copy(), b.scale.copy()) for b in pb}
    return p, base


def clips(r, w):
    """stomp_in and stomp for the ready pose r and the weight w."""
    feet = {"R": "R", "L": "L", "both": "LR"}[w.get("foot", "R")]
    shift = -w["shift"] if feet == "L" else w["shift"]      # towards the standing leg (WEIGHT is written for the right foot)
    hop = w.get("hop", 0.0)

    def body(pel=(0, 0, 0), tor=(0, 0, 0), hed=(0, 0, 0)):
        return {"pel": add3(r["pel"], (shift,) + pel[1:]), "tor": add3(r["tor"], tor), "hed": add3(r["hed"], hed)}

    def feet_at(dy, dz, pitch):
        out = {}
        for f in feet:
            x, y, z = r["F" + f]
            out["F" + f] = (x, y + dy, z + dz)
            out["F" + f + "p"] = pitch
        return out
    arms = w["arms"]
    twist, grind, listen = w["twist"], w.get("grind", 0.0), w.get("listen", (0.0, 0.0))
    set_ = dict(body((0, 0, -w["crouch"]), (w["lean"] * 0.3 - w["back"] * 0.3, 0, 0)), **feet_at(0.02, 0.04, w["toe"] * 0.3))
    set_.update({k: tuple(0.3 * x for x in v) for k, v in arms["top"].items()})
    keys = [(0.0, set_)]
    for i, k in enumerate(w["power"]):
        b = float(i)
        up = -w["crouch"] + (w["rise"] + hop) * k
        top = dict(body((0, -0.01, up), (w["lean"] * 0.4 - w["back"] * k, twist * k, 0), (-0.05, 0, 0)),
                   **feet_at(w["reach"] * 0.4, w["lift"] * k, w["toe"]), **arms["top"])
        hang = dict(top, **feet_at(w["reach"] * 0.5, w["lift"] * k * 1.04, w["toe"]))
        hit = dict(body((0, 0.02, -w["crouch"] - w["drop"] * k), (w["lean"] + 0.1 * k, grind * k, 0), (0.15, 0, 0)),
                   **feet_at(w["reach"], 0.0, 0.0), **arms["hit"])
        settle = dict(hit, **body((0, 0.02, -w["crouch"] - w["drop"] * 0.45), (w["lean"], grind * k * 0.6, 0), (0.12, 0, 0)))
        keys += [(b + w["top"], top, "out"), (b + w["top"] + (SLAM - w["top"]) * 0.45, hang), (b + SLAM, hit, "in")]
        if i < BEATS - 1:
            keys.append((b + SLAM + w["settle"], settle, "out"))
    # the hold: weight on the wisp to the kill, head down at it
    hold = dict(keys[-1][1], **body((0, 0.03, -w["crouch"] - w["drop"] * 0.7), (w["lean"] + 0.08, grind * 0.6, 0), (0.2, listen[0], listen[1])))
    keys.append((TIME, hold, "out"))
    return [Clip("stomp_in", COMMIT, [(0.0, {}), (COMMIT, set_)], r), Clip("stomp", TIME, keys, r)]


def bake(arm, clip, s, base, keep):
    """One clip into an action: every bone the idle keys, each frame; the solved ones from the targets, the arms turned at the shoulder."""
    act = bpy.data.actions.new(clip.name)
    act.use_fake_user = True
    arm.animation_data.action = act
    pb = arm.pose.bones
    solved = [b for b in ("root", "hips", "head", "thigh.L", "shin.L", "foot.L", "thigh.R", "shin.R", "foot.R") if b in pb]
    n = int(round(clip.dur * FPS)) + 1
    for f in range(n):
        P = clip.sample(clip.dur * f / (n - 1))
        Q, root_at = s.solve(P)
        for nm in keep:
            loc, rot, scl = base[nm]
            pb[nm].rotation_mode = "QUATERNION"
            pb[nm].location, pb[nm].rotation_quaternion, pb[nm].scale = loc, rot, scl
        for nm in solved:
            par = s.b[nm].parent
            q_par = Q[par.name] if par else Quaternion()
            pb[nm].rotation_quaternion = (s.R0[nm].inverted() @ q_par.inverted() @ Q[nm] @ s.R0[nm]).normalized()
        pb["root"].location = s.R0["root"].inverted() @ (root_at - s.H0["root"])
        bpy.context.view_layer.update()
        for sd, out in (("L", 1.0), ("R", -1.0)):
            fwd, side = P["a" + sd]
            if fwd or side:
                b = pb["upper_arm." + sd]
                turn = Quaternion((0, 1, 0), out * side) @ Quaternion((1, 0, 0), fwd)
                b.matrix = Matrix.Translation(b.head) @ turn.to_matrix().to_4x4() @ Matrix.Translation(-b.head) @ b.matrix
        bpy.context.view_layer.update()
        for nm in keep:
            for path in ("location", "rotation_quaternion", "scale"):
                pb[nm].keyframe_insert(path, frame=f)
    arm.animation_data.action = None


def main():
    a = sys.argv[sys.argv.index("--") + 1:]
    hid = a[0]
    src = os.path.abspath(a[1] if len(a) > 1 else os.path.join(HERE, "..", "..", "art", "wardens", hid, hid + ".glb"))
    w = WEIGHT[hid]
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=src, bone_heuristic="BLENDER")
    arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
    bpy.context.scene.render.fps = FPS
    tj, tb = read(src)
    idle = next(an for an in tj["animations"] if an["name"] == "idle")
    keep = sorted({tj["nodes"][ch["target"]["node"]]["name"] for ch in idle["channels"]} & set(arm.pose.bones.keys()))
    s = StompSolver(arm, w.get("shin", 0.0))
    arm.animation_data_create()
    arm.animation_data.action = next(act for act in bpy.data.actions if act.name.split("_")[0] == "idle")
    bpy.context.scene.frame_set(0)
    bpy.context.view_layer.update()
    ready, base = ready_of(arm, s)
    Q, _ = s.solve(ready)
    off = {n: round(math.degrees((arm.pose.bones[n].matrix.to_quaternion() @ s.R0[n].inverted()).rotation_difference(Q[n]).angle), 1) for n in Q}
    print("ready vs idle (deg)", off)
    arm.animation_data.action = None
    for act in list(bpy.data.actions):
        bpy.data.actions.remove(act)
    for c in clips(ready, w):
        bake(arm, c, s, base, keep)
    tmp = os.path.join(tempfile.mkdtemp(), hid + "_stomp.glb")
    bpy.ops.object.select_all(action="DESELECT")
    arm.select_set(True)
    for o in arm.children:
        o.select_set(True)
    bpy.ops.export_scene.gltf(filepath=tmp, export_format="GLB", use_selection=True, export_animations=True, export_animation_mode="ACTIONS", export_skins=True,
                              export_yup=True, export_force_sampling=True, export_frame_step=1, export_optimize_animation_size=False, export_def_bones=False,
                              export_materials="NONE")
    sj, sb = read(tmp)
    for an in sj["animations"]:
        an["channels"] = [ch for ch in an["channels"] if sj["nodes"][ch["target"]["node"]].get("name", "") in keep]
    done = add(tj, tb, sj, sb, lambda nm: nm in NAMES)
    write(src, tj, tb)
    print("added", done, "->", src)


if __name__ == "__main__":
    main()
