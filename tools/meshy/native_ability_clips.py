"""Sparkle's, Neve's and Meeko's own ability clips on Meshy's skeleton (art/wardens/<art>/<art>_clips.glb), no Blender.
Reuses the FK, two-bone IK and glTF writer of cinder_native_clips.py (Meshy's rig read from art/wardens/<art>/<art>_meshy.glb):
a pose is a dict of wrists, elbow poles, hand turns and torso leans, sampled at 30 fps and written as rotation tracks.
Wrist targets are in ARM LENGTHS from the shoulder (outward, up, forward), so one pose reads on all three bodies;
metre offsets (hips, ankles) scale with the hips' height. Upper clips (names *_u_*) key torso, head and arms only: the game
lays them over the legs' walk, run or idle (data "kmoves" in content/rules/warden_native.json). Full clips (*_f_*) key every joint.
Timings are the kits' own beats (KMOVES in scripts/match/kmoves_vv.gd, kmoves_care.gd): the release lands on the beat
the kit fires; the poses are our own (DECISIONS 11-07).
Run: ~/venv-img/bin/python -I tools/meshy/native_ability_clips.py [ryzz claire pip]"""

import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, "..", "art1"))
import cinder_native_clips as C  # noqa: E402

REST_HIPS = 1.05  # m: the hips height the metre offsets below are written for
OUT = "art/wardens/%s/%s_clips.glb"


class Body:
    """One Hunter's rig: the shoulder and arm length that turn arm-length targets into metres."""

    def __init__(self, art):
        C.RIG = "art/wardens/%s/%s_meshy.glb" % (art, art)
        C.RIGS = None
        R = C.rig()
        g = R.rest
        sh = R.pos(g, "RightArm")
        self.sh = (-sh[0], sh[1], sh[2])
        self.arm = float(
            C.np.linalg.norm(R.pos(g, "RightForeArm") - sh) + C.np.linalg.norm(R.pos(g, "RightHand") - R.pos(g, "RightForeArm"))
        )
        self.k = float(R.pos(g, "Hips")[1]) / REST_HIPS
        self.rest = C.rest_pose()

    def arm_pose(self, side, w, pole, hand=None, twist=0.0, reach=0.0):
        """One arm: wrist `w` (outward, up, forward) in arm lengths from its shoulder, the elbow's pole direction, the hand bone's direction."""
        L = self.arm
        return {
            "w" + side: (self.sh[0] + L * w[0], self.sh[1] + L * w[1], self.sh[2] + L * w[2]),
            "pole" + side: pole,
            "hand" + side: hand,
            "twist" + side: twist,
            "reach" + side: reach,
        }

    def hips(self, down=0.0, fwd=0.0, pitch=0.0, turn=0.0, tilt=0.0):
        return {"hips": (0.0, -down * self.k, fwd * self.k), "hips_rot": (pitch, turn, tilt)}

    def feet(self, a_out=None, back=0.0, up=0.0):
        """Both ankles planted at rest (default), or trailed `back` m behind and `up` m higher with the toes down."""
        out = {}
        for s in "RL":
            r = self.rest["a" + s]
            out["a" + s] = (r[0], r[1] + up * self.k, r[2] - back * self.k)
            if back or up:
                out["foot" + s] = (0.0, -0.45, -0.9)
        return out


def lean(spine=0.0, twist=0.0, tilt=0.0, head=(0.0, 0.0, 0.0)):
    """Torso lean; `twist` is positive when her right shoulder comes forward (the rig's own sign is the other way)."""
    return C.lean(spine, -twist, tilt, head)


def mirror(side):
    return "L" if side == "R" else "R"


# ---- Sparkle ------------------------------------------------------------------------------------------------
def sparkle_upper(b):
    P = b.arm_pose
    out = {}
    for s, sg in (("R", 1.0), ("L", -1.0)):
        # finger bolt: the hand drawn to the chest, punched out along the cursor (0.06 s: the bolt leaves), the wrist flicked
        # up by the recoil (0.09), held out, home by 0.35
        wind = {**P(s, (0.1, -0.35, 0.45), (0.6, -0.8, -0.3), (0.0, 0.1, 1.0)), **lean(0.04, -0.3 * sg, 0.0)}
        fire = {**P(s, (0.05, 0.0, 0.95), (0.4, -0.9, -0.1), (0.0, 0.0, 1.0), reach=0.3), **lean(-0.05, 0.4 * sg, 0.0)}
        kick = {**P(s, (0.05, 0.1, 0.9), (0.4, -0.9, -0.1), (0.0, 0.5, 1.0), reach=0.3), **lean(0.0, 0.4 * sg, 0.0)}
        held = {**P(s, (0.05, 0.06, 0.92), (0.4, -0.9, -0.1), (0.0, 0.2, 1.0), reach=0.3), **lean(0.0, 0.35 * sg, 0.0)}
        name = "sp_u_lmb_" + s.lower()
        out[name] = (0.35, False, [(0.0, b.rest, "lin"), (0.03, wind, "out"), (0.06, fire, "out"), (0.09, kick, "out"), (0.2, held, "sm"), (0.35, b.rest, "sm")])
    # Storm Rod held: side-on, the rod hand high by the right shoulder, the left arm out ahead to aim (0.12 s in, then held)
    rod = {
        **b.arm_pose("R", (0.3, 0.75, -0.05), (0.8, 0.2, -0.6), (0.0, 1.0, 0.3)),
        **b.arm_pose("L", (0.1, 0.12, 0.88), (0.5, -0.8, -0.2), (0.0, 0.1, 1.0)),
        **lean(0.1, -0.7, 0.0, (0.0, 0.5, 0.0)),
    }
    out["sp_u_rmb_hold"] = (0.12, False, [(0.0, b.rest, "lin"), (0.12, rod, "out")])
    # thrown: the rod arm cocks back (0.06), whips over and releases (0.16), follows through past the hip (0.42), home by 0.7
    cock = {**rod, **b.arm_pose("R", (0.35, 0.8, -0.55), (0.8, 0.3, -0.5), (0.0, 1.0, -0.3)), **lean(0.0, -0.95, 0.0, (0.0, 0.6, 0.0))}
    rel = {**rod, **b.arm_pose("R", (0.12, 0.6, 0.85), (0.6, 0.3, 0.0), (0.0, 0.7, 0.8), reach=0.5), **lean(0.25, 0.5, 0.0, (0.1, 0.0, 0.0))}
    thru = {**rod, **b.arm_pose("R", (0.25, -0.6, 0.55), (0.7, -0.4, 0.0), (0.0, -0.5, 0.8)), **lean(0.4, 0.35, 0.0, (0.2, 0.0, 0.0))}
    out["sp_u_rmb"] = (0.7, False, [(0.0, rod, "lin"), (0.06, cock, "out"), (0.16, rel, "out"), (0.42, thru, "sm"), (0.7, b.rest, "sm")])
    # Skycall: the left arm sweeps out toward the spot (0.07), flicks up high (0.3), stays raised through the countdown
    sweep = {**b.arm_pose("L", (0.9, 0.05, 0.5), (0.5, -0.7, -0.3), (1.0, 0.2, 0.3)), **lean(0.05, 0.2, 0.0)}
    high = {**b.arm_pose("L", (0.2, 0.95, 0.1), (0.8, 0.0, -0.4), (0.0, 1.0, 0.1)), **lean(-0.12, 0.1, 0.1, (-0.35, 0.0, 0.0))}
    high2 = {**high, **b.arm_pose("L", (0.22, 0.97, 0.12), (0.8, 0.0, -0.4), (0.0, 1.0, 0.15))}
    out["sp_u_e"] = (0.5, False, [(0.0, b.rest, "lin"), (0.07, sweep, "out"), (0.14, sweep, "lin"), (0.3, high, "out"), (0.5, high2, "sm")])
    out["sp_u_e_hold"] = (0.8, True, [(0.0, high2, "lin"), (0.4, high, "sm"), (0.8, high2, "sm")])
    # Skycall strike: the raised hand snapped down to the ground as the bolt lands (0.06), settled by 0.55
    snap = {**b.arm_pose("L", (0.15, -0.9, 0.35), (0.5, -0.4, 0.3), (0.0, -1.0, 0.4), reach=0.4), **lean(0.4, 0.0, 0.0, (0.2, 0.0, 0.0))}
    out["sp_u_e_snap"] = (0.55, False, [(0.0, high2, "lin"), (0.06, snap, "in"), (0.3, snap, "lin"), (0.55, b.rest, "sm")])
    return out


def sparkle_full(b):
    P = b.arm_pose
    both_back = {**P("R", (0.25, -0.3, -0.6), (0.7, 0.2, -0.3), (0.0, -0.6, -0.8)), **P("L", (0.25, -0.3, -0.6), (0.7, 0.2, -0.3), (0.0, -0.6, -0.8))}
    out = {}
    # Wirerun held: a low sprinter's crouch leaning into the run, both arms swept back (0.12 s in, then held)
    sprint = {**b.hips(0.2, 0.06, 0.5), **b.feet(), **both_back, **lean(0.3, 0.0, 0.0, (-0.4, 0.0, 0.0))}
    out["sp_f_dash"] = (0.12, False, [(0.0, b.rest, "lin"), (0.12, sprint, "out")])
    # let go (0.05): stretched flat out as the streak, arms trailing, legs behind; held to 0.4, standing again by 0.5
    streak = {**b.hips(-0.08, 0.1, 1.15), **b.feet(back=0.5, up=0.55), **both_back, **lean(-0.15, 0.0, 0.0, (-0.6, 0.0, 0.0))}
    out["sp_f_go"] = (0.5, False, [(0.0, sprint, "lin"), (0.05, streak, "out"), (0.4, streak, "lin"), (0.5, b.rest, "sm")])
    # arrival: she re-forms in a crouch, springs up past standing, settles (0.42 s)
    squash = {**b.hips(0.22, 0.04, 0.35), **b.feet(), **P("R", (0.45, -0.25, 0.2), (0.7, -0.3, -0.3)), **P("L", (0.45, -0.25, 0.2), (0.7, -0.3, -0.3)), **lean(0.15)}
    spring = {**b.hips(-0.03, 0.0, -0.05), **b.feet(), **P("R", (0.55, 0.1, 0.1), (0.8, -0.2, -0.2)), **P("L", (0.55, 0.1, 0.1), (0.8, -0.2, -0.2)), **lean(-0.08)}
    out["sp_f_land"] = (0.42, False, [(0.0, squash, "lin"), (0.14, spring, "out"), (0.42, b.rest, "sm")])
    # Kitefall: the 0.3 s crouch, knees deep, arms swept down and back (held), the launch stretch then the float with both
    # arms wide and up, the dive head first with both fists driven down, the deep landing with a fist to the ground
    crouch = {**b.hips(0.38, 0.0, 0.5), **b.feet(), **both_back, **lean(0.3, 0.0, 0.0, (-0.3, 0.0, 0.0))}
    out["sp_f_x"] = (0.3, False, [(0.0, b.rest, "lin"), (0.1, crouch, "out"), (0.3, dict(crouch, **b.hips(0.42, 0.0, 0.55)), "sm")])
    wide = {**P("R", (0.8, 0.8, 0.0), (0.4, -0.2, -0.6), (0.6, 0.9, 0.0)), **P("L", (0.8, 0.8, 0.0), (0.4, -0.2, -0.6), (0.6, 0.9, 0.0))}
    stretch = {**b.hips(-0.12, 0.0, 0.0), **b.feet(), **wide, **lean(-0.2, 0.0, 0.0, (-0.2, 0.0, 0.0))}
    hang = {**b.hips(-0.1, 0.0, -0.18), **b.feet(back=0.1, up=0.3), **wide, **lean(-0.25, 0.0, 0.0, (-0.3, 0.0, 0.0))}
    out["sp_f_x_air"] = (0.4, False, [(0.0, crouch, "lin"), (0.2, stretch, "out"), (0.4, hang, "sm")])
    dive = {**b.hips(0.0, 0.1, 2.3), **b.feet(back=0.25, up=0.9), **P("R", (0.1, -0.9, 0.5), (0.5, 0.2, -0.3), (0.0, -1.0, 0.3)), **P("L", (0.1, -0.9, 0.5), (0.5, 0.2, -0.3), (0.0, -1.0, 0.3)), **lean(0.1, 0.0, 0.0, (0.2, 0.0, 0.0))}
    out["sp_f_x_dive"] = (0.1, False, [(0.0, hang, "lin"), (0.1, dive, "out")])
    knee = {**b.hips(0.42, 0.06, 0.55), **b.feet(), **P("R", (0.2, -0.95, 0.4), (0.6, 0.0, -0.3), (0.0, -1.0, 0.2)), **P("L", (0.8, 0.0, 0.2), (0.7, -0.3, -0.3)), **lean(0.25)}
    out["sp_f_x_land"] = (0.5, False, [(0.0, dive, "lin"), (0.1, knee, "out"), (0.3, knee, "lin"), (0.5, b.rest, "sm")])
    return out


# ---- Neve ---------------------------------------------------------------------------------------------------
def neve_upper(b):
    P = b.arm_pose
    out = {}
    for s, sg in (("R", 1.0), ("L", -1.0)):
        # Ice Dart: the hand snapped across the body (0.03), whipped out at the cursor with a sharp twist (0.07), home by 0.16
        across = {**P(s, (-0.25, 0.0, 0.5), (0.6, -0.7, -0.3), (-0.3, 0.2, 1.0)), **lean(0.03, -0.3 * sg, 0.0)}
        whip = {**P(s, (0.25, 0.1, 0.9), (0.5, -0.8, -0.1), (0.2, 0.3, 1.0), reach=0.3), **lean(0.0, 0.35 * sg, 0.0)}
        out["nv_u_dart_" + s.lower()] = (0.16, False, [(0.0, b.rest, "lin"), (0.03, across, "out"), (0.07, whip, "out"), (0.16, b.rest, "sm")])
    # a large dart: both hands drawn back to the hip, the torso wound away (0.04), whipped round, both arms slung forward (0.08)
    back = {**P("R", (0.2, -0.45, -0.25), (0.8, -0.3, -0.7)), **P("L", (0.2, -0.45, -0.25), (0.8, -0.3, -0.7)), **lean(0.1, -0.5, 0.0)}
    sling = {**P("R", (0.2, 0.05, 0.92), (0.5, -0.8, -0.1), (0.1, 0.2, 1.0), reach=0.4), **P("L", (0.2, 0.05, 0.92), (0.5, -0.8, -0.1), (0.1, 0.2, 1.0), reach=0.4), **lean(0.2, 0.45, 0.0)}
    out["nv_u_dart_heavy"] = (0.18, False, [(0.0, b.rest, "lin"), (0.04, back, "out"), (0.08, sling, "out"), (0.18, b.rest, "sm")])
    # a beam while skating: both hands driven straight out ahead, a stiff lean into it (0.04 in, held, off by 0.22)
    drive = {**P("R", (0.1, 0.05, 0.95), (0.5, -0.8, -0.1), (0.0, 0.1, 1.0), reach=0.4), **P("L", (0.1, 0.05, 0.95), (0.5, -0.8, -0.1), (0.0, 0.1, 1.0), reach=0.4), **lean(0.3, 0.0, 0.0, (-0.2, 0.0, 0.0))}
    out["nv_u_beam"] = (0.22, False, [(0.0, b.rest, "lin"), (0.04, drive, "out"), (0.14, drive, "lin"), (0.22, b.rest, "sm")])
    # Cryo Spear: both palms drawn in to the chest round the forming spear (held), then a two-handed PUSH on the release:
    # the arms drive out to full reach with the palms flat and the body lunging after them (0.1), held out, settled by 0.55
    gather = {**P("R", (0.12, -0.2, 0.42), (0.9, -0.1, -0.5), (0.0, 0.6, 0.8)), **P("L", (0.12, -0.2, 0.42), (0.9, -0.1, -0.5), (0.0, 0.6, 0.8)), **lean(-0.05)}
    out["nv_u_spear_aim"] = (0.12, False, [(0.0, b.rest, "lin"), (0.12, gather, "out")])
    push = {**P("R", (0.1, 0.05, 0.98), (0.6, -0.5, -0.1), (0.0, 0.7, 0.7), reach=0.6), **P("L", (0.1, 0.05, 0.98), (0.6, -0.5, -0.1), (0.0, 0.7, 0.7), reach=0.6), **lean(0.3, 0.0, 0.0, (-0.1, 0.0, 0.0))}
    out["nv_u_spear"] = (0.55, False, [(0.0, gather, "lin"), (0.05, dict(gather, **lean(-0.12)), "out"), (0.1, push, "out"), (0.28, push, "lin"), (0.55, b.rest, "sm")])
    return out


def neve_full(b):
    P = b.arm_pose
    out = {}
    # Rink Wall: the 0.2 s tell (a deep crouch, both palms drawn back to the hips), then both palms shoved out low and wide as
    # the ice erupts (0.2), the body driving after them, held (0.35), settled by 0.7
    tell = {**b.hips(0.34, -0.02, 0.45), **b.feet(), **P("R", (0.25, -0.5, -0.1), (0.8, -0.3, -0.7)), **P("L", (0.25, -0.5, -0.1), (0.8, -0.3, -0.7)), **lean(0.2, 0.0, 0.0, (-0.3, 0.0, 0.0))}
    shove = {**b.hips(0.26, 0.12, 0.6), **b.feet(), **P("R", (0.5, -0.45, 0.85), (0.6, -0.4, -0.2), (0.3, 0.1, 1.0), reach=0.5), **P("L", (0.5, -0.45, 0.85), (0.6, -0.4, -0.2), (0.3, 0.1, 1.0), reach=0.5), **lean(0.3, 0.0, 0.0, (-0.4, 0.0, 0.0))}
    out["nv_f_wall"] = (0.7, False, [(0.0, b.rest, "lin"), (0.1, tell, "out"), (0.2, tell, "lin"), (0.24, shove, "out"), (0.35, shove, "lin"), (0.7, b.rest, "sm")])
    # Rimelock: a crouch with the arms crossed (0.12), thrown up and out as the rink snaps (0.2), then into the sealed crouch
    cross = {**b.hips(0.18, 0.0, 0.25), **b.feet(), **P("R", (-0.35, -0.2, 0.35), (0.3, -0.5, 0.5), (-0.8, 0.5, 0.3)), **P("L", (-0.35, -0.2, 0.35), (0.3, -0.5, 0.5), (-0.8, 0.5, 0.3)), **lean(0.25, 0.0, 0.0, (0.2, 0.0, 0.0))}
    burst = {**b.hips(0.08, 0.0, 0.0), **b.feet(), **P("R", (0.85, 0.6, 0.2), (0.4, 0.0, -0.5), (0.7, 0.7, 0.0)), **P("L", (0.85, 0.6, 0.2), (0.4, 0.0, -0.5), (0.7, 0.7, 0.0)), **lean(-0.2, 0.0, 0.0, (-0.3, 0.0, 0.0))}
    sealed = {**b.hips(0.3, 0.0, 0.5), **b.feet(), **P("R", (-0.3, -0.05, 0.4), (0.3, -0.5, 0.6), (-0.8, 0.5, 0.3)), **P("L", (-0.3, -0.05, 0.4), (0.3, -0.5, 0.6), (-0.8, 0.5, 0.3)), **lean(0.5, 0.0, 0.0, (0.3, 0.0, 0.0))}
    out["nv_f_rime"] = (0.2, False, [(0.0, b.rest, "lin"), (0.06, cross, "out"), (0.12, burst, "out"), (0.2, sealed, "sm")])
    # skated into the seal: whipped side-on into a braced hockey stop, arms flung out (0.08), grinding on low (0.28), sealed by 0.5
    brace = {**b.hips(0.18, -0.1, -0.2, 1.2), **b.feet(), **P("R", (0.9, 0.2, 0.2), (0.5, -0.2, -0.4), (1.0, 0.1, 0.0)), **P("L", (0.9, 0.2, 0.2), (0.5, -0.2, -0.4), (1.0, 0.1, 0.0)), **lean(-0.3, 0.0, 0.0)}
    out["nv_f_rime_carry"] = (0.5, False, [(0.0, b.rest, "lin"), (0.08, brace, "out"), (0.28, dict(brace, **b.hips(0.24, -0.08, -0.12, 1.1)), "sm"), (0.5, sealed, "sm")])
    # sealed in: hunched over, arms crossed on the chest, knees bent (held)
    out["nv_f_rime_hold"] = (0.4, False, [(0.0, sealed, "lin"), (0.4, dict(sealed, **lean(0.55, 0.0, 0.0, (0.35, 0.0, 0.0))), "sm")])
    # the crash: a deeper crouch (0.04), everything flung wide as the shell bursts, up on the toes (0.1), settled by 0.4
    deep = {**sealed, **b.hips(0.4, 0.0, 0.6)}
    flung = {**b.hips(-0.06, 0.0, -0.1), **b.feet(up=0.04), **P("R", (0.95, 0.5, 0.0), (0.4, 0.0, -0.5), (0.8, 0.6, 0.0)), **P("L", (0.95, 0.5, 0.0), (0.4, 0.0, -0.5), (0.8, 0.6, 0.0)), **lean(-0.3, 0.0, 0.0, (-0.4, 0.0, 0.0))}
    out["nv_f_rime_crash"] = (0.4, False, [(0.0, sealed, "lin"), (0.04, deep, "out"), (0.1, flung, "out"), (0.2, flung, "lin"), (0.4, b.rest, "sm")])
    # an early break: a shrug that pushes the shell off, small and quick
    shrug = {**b.hips(0.1, 0.0, 0.0), **b.feet(), **P("R", (0.6, 0.35, 0.1), (0.7, 0.0, -0.3), (0.7, 0.4, 0.0)), **P("L", (0.6, 0.35, 0.1), (0.7, 0.0, -0.3), (0.7, 0.4, 0.0)), **lean(-0.1)}
    out["nv_f_rime_break"] = (0.3, False, [(0.0, sealed, "lin"), (0.08, shrug, "out"), (0.3, b.rest, "sm")])
    return out


# ---- Meeko --------------------------------------------------------------------------------------------------
def meeko_upper(b):
    P = b.arm_pose
    out = {}
    for s, sg in (("R", 1.0), ("L", -1.0)):
        o = mirror(s)
        # Ember Cast: the fist pulled back to the hip with the torso twisted away (0.04), a straight-arm punch-push at the
        # cursor with the torso unwound past square (0.08), held out (0.18), the other hand rising open (0.3), home by 0.42
        pull = {**P(s, (0.15, -0.55, 0.05), (0.8, -0.3, -0.7), (0.0, 0.2, 1.0)), **P(o, (0.15, -0.1, 0.4), (0.6, -0.5, -0.3), (0.0, 0.5, 0.9)), **lean(0.1, -0.5 * sg, 0.0)}
        punch = {**P(s, (0.08, 0.02, 0.98), (0.5, -0.8, -0.1), (0.0, 0.2, 1.0), reach=0.6), **P(o, (0.3, -0.25, 0.1), (0.8, -0.4, -0.4), (0.0, -0.2, 0.9)), **lean(-0.1, 0.7 * sg, 0.0, (0.0, 0.0, 0.0))}
        held = {**punch, **P(s, (0.08, 0.0, 0.94), (0.5, -0.8, -0.1), (0.0, 0.3, 1.0), reach=0.5)}
        rise = {**P(s, (0.15, -0.3, 0.5), (0.7, -0.5, -0.3), (0.0, 0.5, 0.9)), **P(o, (0.15, 0.0, 0.5), (0.6, -0.4, -0.2), (0.0, 0.7, 0.8)), **lean(0.0, 0.2 * sg, 0.0)}
        out["mk_u_shot_" + s.lower()] = (0.42, False, [(0.0, b.rest, "lin"), (0.04, pull, "out"), (0.08, punch, "out"), (0.18, held, "lin"), (0.3, rise, "sm"), (0.42, b.rest, "sm")])
    # the Empowered ember: a deep coil with both hands back (0.09), a two-handed push with the free arm flung back past it (0.14),
    # held (0.3), then down by 0.55
    coil = {**P("R", (0.2, -0.5, -0.2), (0.8, -0.3, -0.7)), **P("L", (0.2, -0.5, -0.2), (0.8, -0.3, -0.7)), **lean(0.25, -0.5, 0.0, (-0.1, 0.0, 0.0))}
    shove = {**P("R", (0.1, 0.05, 0.98), (0.5, -0.8, -0.1), (0.0, 0.3, 1.0), reach=0.7), **P("L", (0.25, 0.0, 0.85), (0.6, -0.7, -0.2), (0.0, 0.3, 1.0), reach=0.5), **lean(-0.15, 0.6, 0.0, (-0.2, 0.0, 0.0))}
    out["mk_u_shot_emp"] = (0.55, False, [(0.0, b.rest, "lin"), (0.09, coil, "out"), (0.14, shove, "out"), (0.3, shove, "lin"), (0.55, b.rest, "sm")])
    # Burrseed wind-up (a fixed 0.6 s): turned side-on, the casting fist pointed down the lane, the other hand drawn up beside the ear
    wind = {**P("R", (0.1, 0.0, 0.9), (0.5, -0.8, -0.1), (0.0, 0.2, 1.0), reach=0.4), **P("L", (0.15, 0.55, 0.05), (0.9, 0.0, -0.6), (0.0, 1.0, 0.0)), **lean(0.2, 0.9, 0.0, (0.0, -0.6, 0.0))}
    out["mk_u_seed_aim"] = (0.6, False, [(0.0, b.rest, "lin"), (0.12, wind, "out"), (0.6, dict(wind, **lean(0.28, 0.95, 0.0, (0.0, -0.6, 0.0))), "sm")])
    # the seed leaves (0.05 in): a two-handed push, the flare round her (0.12), held, home by 0.55
    seed0 = {**P("R", (0.1, -0.1, 0.4), (0.7, -0.4, -0.4)), **P("L", (0.1, -0.1, 0.4), (0.7, -0.4, -0.4)), **lean(0.1, 0.3, 0.0)}
    seed1 = {**P("R", (0.15, 0.0, 0.97), (0.6, -0.6, -0.1), (0.0, 0.5, 0.8), reach=0.6), **P("L", (0.15, 0.0, 0.97), (0.6, -0.6, -0.1), (0.0, 0.5, 0.8), reach=0.6), **lean(-0.1, 0.0, 0.0, (-0.1, 0.0, 0.0))}
    out["mk_u_seed"] = (0.55, False, [(0.0, wind, "lin"), (0.05, seed0, "out"), (0.12, seed1, "out"), (0.32, seed1, "lin"), (0.55, b.rest, "sm")])
    # Hearthlight lit (mm_hearth): a crouch-bow gathering the light in both cupped hands low in front (0.08), both arms thrust
    # up overhead in a V held forward of her big head so the hands clear it as the rays rise (0.18), held up to 0.4, home by 0.65
    gather = {**P("R", (0.05, -0.6, 0.4), (0.8, -0.4, -0.4), (0.0, 0.3, 1.0)), **P("L", (0.05, -0.6, 0.4), (0.8, -0.4, -0.4), (0.0, 0.3, 1.0)), **lean(0.35, 0.0, 0.0, (0.15, 0.0, 0.0))}
    lift = {**P("R", (0.42, 0.82, 0.38), (0.9, 0.0, -0.4), (0.3, 1.0, 0.3), reach=0.6), **P("L", (0.42, 0.82, 0.38), (0.9, 0.0, -0.4), (0.3, 1.0, 0.3), reach=0.6), **lean(-0.04, 0.0, 0.0, (-0.25, 0.0, 0.0))}
    lifted = {**lift, **P("R", (0.45, 0.8, 0.36), (0.9, 0.0, -0.4), (0.3, 1.0, 0.3)), **P("L", (0.45, 0.8, 0.36), (0.9, 0.0, -0.4), (0.3, 1.0, 0.3)), **lean(-0.02, 0.0, 0.0, (-0.2, 0.0, 0.0))}
    out["mk_u_hearth"] = (0.65, False, [(0.0, b.rest, "lin"), (0.08, gather, "out"), (0.18, lift, "out"), (0.4, lifted, "lin"), (0.65, b.rest, "sm")])
    # Hearthlight thrown (mm_toss): the right hand wound low behind with the torso turned away (0.06), an underhand fling up and
    # out at the cursor with the torso unwound (0.12), the follow-through held to 0.26, home by 0.5
    wind_t = {**P("R", (0.25, -0.65, -0.35), (0.8, -0.3, -0.6), (0.0, -0.3, -1.0)), **P("L", (0.3, -0.1, 0.4), (0.7, -0.5, -0.3), (0.0, 0.4, 0.9)), **lean(0.15, -0.55, 0.0)}
    fling = {**P("R", (0.05, 0.35, 0.92), (0.5, -0.8, -0.1), (0.0, 0.6, 0.8), reach=0.6), **P("L", (0.35, -0.3, -0.1), (0.8, -0.4, -0.4), (0.0, -0.4, -0.9)), **lean(-0.12, 0.6, 0.0, (-0.15, 0.0, 0.0))}
    follow = {**fling, **P("R", (0.05, 0.3, 0.9), (0.5, -0.8, -0.1), (0.0, 0.6, 0.8), reach=0.5), **lean(-0.08, 0.45, 0.0, (-0.1, 0.0, 0.0))}
    out["mk_u_toss"] = (0.5, False, [(0.0, b.rest, "lin"), (0.06, wind_t, "out"), (0.12, fling, "out"), (0.26, follow, "lin"), (0.5, b.rest, "sm")])
    # Hearth Call: the hand pulled back low (0.1), thrust high and out as the plus bursts (0.2), an overshoot, then the channel
    # pose: one hand held high over the tether, the other out for balance (0.33)
    low = {**P("R", (0.3, -0.6, -0.2), (0.8, -0.3, -0.6)), **P("L", (0.5, -0.3, 0.1), (0.8, -0.5, -0.3)), **lean(0.15, -0.3, 0.0)}
    up = {**P("R", (0.25, 0.95, 0.5), (0.7, 0.1, -0.2), (0.0, 1.0, 0.2), reach=0.4), **P("L", (0.8, 0.0, 0.2), (0.7, -0.5, -0.3), (1.0, 0.0, 0.1)), **lean(-0.15, 0.2, 0.0, (-0.3, 0.0, 0.0))}
    chan = {**up, **P("R", (0.2, 0.9, 0.3), (0.7, 0.1, -0.2), (0.0, 1.0, 0.2)), **lean(-0.05, 0.15, 0.0, (-0.2, 0.0, 0.0))}
    out["mk_u_call"] = (0.33, False, [(0.0, b.rest, "lin"), (0.1, low, "out"), (0.2, up, "out"), (0.26, dict(up, **P("R", (0.25, 1.0, 0.55), (0.7, 0.1, -0.2), (0.0, 1.0, 0.2))), "sm"), (0.33, chan, "sm")])
    sway = {**chan, **P("R", (0.22, 0.93, 0.34), (0.7, 0.1, -0.2), (0.05, 1.0, 0.2)), **P("L", (0.85, 0.05, 0.22), (0.7, -0.5, -0.3), (1.0, 0.05, 0.1))}
    out["mk_u_call_hold"] = (0.8, True, [(0.0, chan, "lin"), (0.4, sway, "sm"), (0.8, chan, "sm")])
    # the end: the raised hand swept down to her side, both arms open on the arrival burst (0.14), settled by 0.3
    sweep = {**P("R", (0.25, -0.6, 0.2), (0.7, -0.4, -0.2), (0.0, -1.0, 0.2)), **P("L", (0.8, 0.0, 0.2), (0.7, -0.5, -0.3), (1.0, 0.0, 0.1)), **lean(0.1)}
    open_ = {**P("R", (0.9, 0.2, 0.2), (0.5, -0.4, -0.3), (1.0, 0.2, 0.1)), **P("L", (0.9, 0.2, 0.2), (0.5, -0.4, -0.3), (1.0, 0.2, 0.1)), **lean(-0.12, 0.0, 0.0, (-0.2, 0.0, 0.0))}
    out["mk_u_call_end"] = (0.3, False, [(0.0, chan, "lin"), (0.07, sweep, "out"), (0.14, open_, "out"), (0.3, b.rest, "sm")])
    return out


HEROES = {
    "ryzz": (sparkle_upper, sparkle_full),
    "claire": (neve_upper, neve_full),
    "pip": (meeko_upper, lambda b: {}),
}


def build(art, shot=False):
    b = Body(art)
    upper, full = HEROES[art]
    C.clips = lambda: upper(b)
    C.flights = lambda: full(b)
    C.build(OUT % (art, art), shot)


if __name__ == "__main__":
    arts = [a for a in sys.argv[1:] if not a.startswith("--")] or list(HEROES)
    for a in arts:
        build(a, "--shot" in sys.argv)
