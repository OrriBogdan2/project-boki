"""A starter Hunter's own stomp (DECISIONS 2026-11-11 "stomping", docs/decisions/0061-stomp-lock.md) as two clips on its v95 rig:
stomp_in   the 0.2 s hold that commits you (Stomp.COMMIT): the weight goes onto the standing leg, the heel comes up
stomp      the fixed 3.0 s finisher (Stomp.TIME): three beats (Stomp.BEATS), each a wind-up and a strike that lands on the
           wisp exactly on Stomp's slam (Stomp.SLAM of the beat: 0.8, 1.8, 2.8 s), the first wind-up the biggest; then a
           hold on the wisp to the kill. Ends of the two clips meet, so the commit flows into the finisher.
Weight is per Hunter (WEIGHT): how high and how fast the foot comes up, how far the pelvis drops into the strike and how
long it takes to come back. Kael lifts slowly and drops dead; Lace flicks a pointed heel and bounces off it.
The keys are posekit targets (pelvis, torso, head, ankles) laid over the Hunter's own idle (frame 0), which is also
where the arms and every other bone stay unless WEIGHT turns a shoulder; posekit's leg IK keeps the standing foot planted.
Run: blender -b --factory-startup --python tools/art1/stomp_clips.py -- <id: kael | vex | hem | dredge | pip | sable | ostra | gil> [glb, default art/wardens/<id>/<id>.glb]
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

# Per Hunter, all right-footed whatever their stomps.json style says (clip-check reads the right foot's beats). lift/reach/drop/crouch/rise/shift in metres, angles in radians,
# times in fractions of a beat. top: when the foot peaks (a later top is a slower wind-up); settle: how long the body
# takes to come back off a strike; toe: the lifted foot's pitch (toe down); lean: forward tilt through the stomp;
# back: the lean back at the top; power: each beat's lift against the first; arms: shoulder turns (forward swing, out)
# at the top and on the strike; "shin": a rig whose shin ends at the ankle (Kael v2, Motley: no foot bone); "both": how far
# the left foot leaves the ground with the right (a two-footed hop: pair it with "rise").
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
    # Grimble (dredge, Junk Jump): the hoard-king; short and heavy under the pack, both feet leave the ground in a pompous
    # hop and come down together with his weight, the bone hook raised like a gavel and brought down, the left arm flung out
    "dredge": {"lift": 0.2, "reach": 0.1, "top": 0.55, "settle": 0.2, "drop": 0.09, "crouch": 0.04, "rise": 0.05, "shift": 0.0,
               "toe": -0.15, "lean": 0.26, "back": 0.1, "twist": -0.1, "power": (1.1, 0.85, 1.2), "both": 0.1,
               "arms": {"top": {"aL": (0.4, 0.55), "aR": (1.2, 0.1)}, "hit": {"aL": (0.15, 0.25), "aR": (0.25, 0.1)}}},
    # Meeko (tender, Pounce): the shy fox-kit pouncing; low and small, a quick hop onto both feet with both fists balled
    # in front, no weight to speak of and a bounce off every landing
    "pip": {"lift": 0.17, "reach": 0.07, "top": 0.38, "settle": 0.1, "drop": 0.03, "crouch": 0.03, "rise": 0.05, "shift": -0.01,
            "toe": -0.4, "lean": 0.34, "back": 0.0, "twist": 0.05, "power": (1.1, 0.9, 1.2), "both": 0.09,
            "arms": {"top": {"aL": (0.7, 0.1), "aR": (0.7, 0.1)}, "hit": {"aL": (0.35, 0.05), "aR": (0.35, 0.05)}}},
    # Sable (thief, Quiet Heel): cold and unbothered; a low, slow, deliberate lift and a heel that lands without a bounce
    # (nothing settles), hunched, both flintlocks left hanging
    "sable": {"lift": 0.24, "reach": 0.14, "top": 0.65, "settle": 0.04, "drop": 0.03, "crouch": 0.07, "rise": 0.0, "shift": -0.03,
              "toe": -0.5, "lean": 0.24, "back": 0.0, "twist": 0.1, "power": (1.0, 1.0, 1.0),
              "arms": {"top": {"aL": (0.1, 0.15), "aR": (0.1, 0.15)}, "hit": {"aL": (0.0, 0.1), "aR": (0.0, 0.1)}}},
    # Motley (ostra, Jester Jig): no legs, a jack-in-the-box on a brass spring: each beat he winds the spring down, shoots
    # up laughing, arms flung wide, head back, and comes down on it with a jolt and a bounce; "rise"/"drop" are the
    # spring's lift in metres. Clip-check follows his hips here
    "ostra": {"spring": True, "lift": 0.0, "reach": 0.0, "top": 0.45, "settle": 0.24, "drop": 0.12, "crouch": 0.03, "rise": 0.17, "shift": 0.0,
              "toe": 0.0, "lean": 0.12, "back": 0.2, "twist": 0.25, "power": (1.1, 1.0, 1.2),
              "arms": {"top": {"aL": (0.3, 0.9), "aR": (0.5, 0.9)}, "hit": {"aL": (0.1, 0.6), "aR": (0.1, 0.6)}}},
    # Gil (gil, Fin Slap): the fish thrilled by everything; a huge eager lift, the boot swung high and slapped down flat
    # and wet, one arm up in delight, the swordfish flung out wide, both slapping down with it
    "gil": {"lift": 0.24, "reach": 0.1, "top": 0.5, "settle": 0.12, "drop": 0.03, "crouch": 0.0, "rise": 0.02, "shift": -0.01,
            "toe": -0.1, "lean": -0.08, "back": 0.1, "twist": -0.1, "power": (1.1, 0.9, 1.15),
            "arms": {"top": {"aL": (1.8, 0.5), "aR": (1.1, 1.0)}, "hit": {"aL": (0.4, 0.3), "aR": (0.3, 0.4)}}},
}


def add3(a, b):
    return tuple(x + y for x, y in zip(a, b))


def unq(q):
    """posekit.eul's inverse: (pitch forward, yaw left, roll right)."""
    e = q.to_euler("YXZ")
    return (-e.x, e.z, e.y)


class StompSolver(Solver):
    """posekit's body and legs only: the arms and everything else stay on the idle (they ride the torso)."""
    NAMES = ("root", "hips", "head", "thigh.L", "shin.L", "foot.L", "thigh.R", "shin.R", "foot.R")

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

    def place(self, pb, P, root_at):
        pb["root"].location = self.R0["root"].inverted() @ (root_at - self.H0["root"])

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


class SpringSolver:
    """Motley has no legs: he rides a brass spring, the hips on its top (the clips key the hips' lift and the rig keeps the root).
    The beat is the spring: "pel" z is the hips' lift in metres, "tor" and "hed" turn them; the feet keys are never read."""
    NAMES = ("hips", "head")

    def __init__(self, arm):
        self.R0 = {n: b.matrix_local.to_quaternion() for n, b in arm.data.bones.items()}
        self.b = {b.name: b for b in arm.data.bones}

    def solve(self, P):
        q_hips = eul(P["tor"])
        return {"hips": q_hips, "head": q_hips @ eul(P["hed"])}, None

    def place(self, pb, P, root_at):
        pb["hips"].location = (0.0, P["pel"][2], 0.0)       # the hips bone's own Y is up


def spring_ready(arm, s):
    """The idle's frame 0 for the spring: the hips' lift and turn, the arms' resting turns."""
    pb = arm.pose.bones
    Q = {n: pb[n].matrix.to_quaternion() @ s.R0[n].inverted() for n in ("hips", "head")}
    p = {"pel": (0.0, 0.0, pb["hips"].location.y), "prt": (0.0, 0.0, 0.0), "tor": unq(Q["hips"]), "hed": unq(Q["hips"].inverted() @ Q["head"]),
         "aL": (0.0, 0.0), "aR": (0.0, 0.0), "FR": (0.0, 0.0, 0.0), "FL": (0.0, 0.0, 0.0), "FRp": 0.0}
    return p, {b.name: (b.location.copy(), b.rotation_quaternion.copy(), b.scale.copy()) for b in pb}


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
    def body(pel=(0, 0, 0), tor=(0, 0, 0), hed=(0, 0, 0)):
        return {"pel": add3(r["pel"], (w["shift"],) + pel[1:]), "tor": add3(r["tor"], tor), "hed": add3(r["hed"], hed)}
    fr, fl = r["FR"], r["FL"]
    plant = (fr[0], fr[1] + w["reach"], fr[2])
    both = w.get("both", 0.0)
    arms = w["arms"]
    set_ = dict(body((0, 0, -w["crouch"]), (w["lean"] * 0.3 - w["back"] * 0.3, 0, 0)), FR=(fr[0], fr[1] + 0.02, fr[2] + 0.04), FRp=w["toe"] * 0.3)
    set_.update({k: tuple(0.3 * x for x in v) for k, v in arms["top"].items()})
    keys = [(0.0, set_)]
    for i, k in enumerate(w["power"]):
        b = float(i)
        top = dict(body((0, -0.01, -w["crouch"] + w["rise"] * k), (w["lean"] * 0.4 - w["back"] * k, w["twist"] * k, 0), (-0.05, 0, 0)),
                   FR=(fr[0], fr[1] + w["reach"] * 0.4, fr[2] + w["lift"] * k), FRp=w["toe"], FL=(fl[0], fl[1], fl[2] + both * k), **arms["top"])
        hang = dict(top, FR=(fr[0], fr[1] + w["reach"] * 0.5, fr[2] + w["lift"] * k * 1.04))
        hit = dict(body((0, 0.02, -w["crouch"] - w["drop"] * k), (w["lean"] + 0.1 * k, 0, 0), (0.15, 0, 0)), FR=plant, FRp=0.0, FL=fl, **arms["hit"])
        settle = dict(hit, **body((0, 0.02, -w["crouch"] - w["drop"] * 0.45), (w["lean"], 0, 0), (0.12, 0, 0)))
        keys += [(b + w["top"], top, "out"), (b + w["top"] + (SLAM - w["top"]) * 0.45, hang), (b + SLAM, hit, "in")]
        if i < BEATS - 1:
            keys.append((b + SLAM + w["settle"], settle, "out"))
    # the hold: weight on the wisp to the kill, head down at it
    hold = dict(keys[-1][1], **body((0, 0.03, -w["crouch"] - w["drop"] * 0.7), (w["lean"] + 0.08, 0, 0), (0.2, 0, 0)))
    keys.append((TIME, hold, "out"))
    return [Clip("stomp_in", COMMIT, [(0.0, {}), (COMMIT, set_)], r), Clip("stomp", TIME, keys, r)]


def bake(arm, clip, s, base, keep):
    """One clip into an action: every bone the idle keys, each frame; the solved ones from the targets, the arms turned at the shoulder."""
    act = bpy.data.actions.new(clip.name)
    act.use_fake_user = True
    arm.animation_data.action = act
    pb = arm.pose.bones
    solved = [b for b in s.NAMES if b in pb]
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
            q_par = Q.get(par.name, Quaternion()) if par else Quaternion()
            pb[nm].rotation_quaternion = (s.R0[nm].inverted() @ q_par.inverted() @ Q[nm] @ s.R0[nm]).normalized()
        s.place(pb, P, root_at)
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
    s = SpringSolver(arm) if w.get("spring") else StompSolver(arm, w.get("shin", 0.0))
    arm.animation_data_create()
    arm.animation_data.action = next(act for act in bpy.data.actions if act.name.split("_")[0] == "idle")
    bpy.context.scene.frame_set(0)
    bpy.context.view_layer.update()
    ready, base = (spring_ready if w.get("spring") else ready_of)(arm, s)
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
