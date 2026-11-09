"""The key poses of every Hero's mantle and ledge clips (climb_clips.py). Positions are in metres in model space (+X his
right, +Y up, forward -Z, origin at his feet) written as fractions of his own height S (the head's height) so a squat
Hero and a tall one share the numbers. Hands and feet are where they are IN THE WORLD relative to his feet as the game
lifts him: the lip is LIP up at the start and level with his feet at the end, so a hand on it sinks as he rises.
mantle: time = progress up the face (0..1 over MANTLE_S, WardenClips maps the body's rise to it).
ledge: the float back up from the abyss, played on its own clock and held on its last pose."""

MANTLE_S = 0.8     # s: a deep mantle returns to the top in ~0.8 s (hunter.gd LRISE_SPEED footage)
LEDGE_S = 1.0      # s: the float up the side, then the pull over the lip


def pose(**kw):
    base = {"lift": 0.0, "fwd": 0.0, "side": 0.0, "body": (0.0, 0.0, 0.0), "hips": (0.0, 0.0, 0.0), "head": (0.0, 0.0, 0.0)}
    base.update(kw)
    return base


class Dim:
    """A rig's own scale: height S, shoulder and hip half-widths."""
    def __init__(self, rig):
        wp = rig.base[1]
        self.S = wp[rig.idx["head"]][1]
        self.sx = abs(wp[rig.idx["upper_arm.L"]][0])
        self.hx = abs(wp[rig.idx["thigh.L"]][0]) if "thigh.L" in rig.idx else 0.0

    def hand(self, side, k_up, fwd, out=0.0):
        """A hand `k_up` of his height up, `fwd` of it in front, `out` of it wider than his shoulder."""
        return ((1 if side == "R" else -1) * (self.sx + out * self.S), k_up * self.S, -fwd * self.S)

    def foot(self, side, up, fwd):
        return ((1 if side == "R" else -1) * self.hx, up * self.S, -fwd * self.S)


ELB = {"L": (-0.5, -0.3, 0.9), "R": (0.5, -0.3, 0.9)}       # elbows back and out
KNEE = {"L": (-0.15, 0.1, -1.0), "R": (0.15, 0.1, -1.0)}    # knees forward


def limbs(d, lh, rh, lf, rf, fpl=0.0, fpr=0.0, elb=None, knee=None):
    out = {"hand_L": lh, "hand_R": rh, "foot_L": lf, "foot_R": rf, "foot_pitch_L": fpl, "foot_pitch_R": fpr}
    for s in "LR":
        out["pole_hand_" + s] = (elb or ELB)[s]
        out["pole_foot_" + s] = (knee or KNEE)[s]
    return out


# ---------------------------------------------------------------- Sparkle (ryzz): a scrambling pull, one knee up
def ryzz(rig):
    d = Dim(rig)
    lip = 0.62     # of his height: the lip at the start (chest high)

    def hands(k, fwd=0.26):
        y = lip * (1 - k) + 0.06 * k + 0.02
        return d.hand("L", y, fwd, 0.04), d.hand("R", y, fwd, 0.04)

    def key(k, lift, pitch, lf, rf, fpl, fpr, hips=(0.0, 0.0, 0.0), head=-10.0, fwd=0.0, roll=0.0):
        lh, rh = hands(k)
        return pose(lift=lift * d.S, fwd=fwd * d.S, body=(pitch, roll, 0.0), hips=hips, head=(head, 0, 0), **limbs(d, lh, rh, lf, rf, fpl, fpr))

    f = d.foot
    mantle = [
        (0.00, key(0.0, 0.00, 6, f("L", 0.02, 0.10), f("R", 0.04, 0.10), 0, 0), "out"),
        (0.20, key(0.25, 0.03, 18, f("L", 0.18, 0.22), f("R", 0.04, 0.12), 10, 0, head=-15), "out"),
        (0.45, key(0.5, 0.05, 28, f("L", 0.46, 0.30), f("R", 0.14, 0.18), 25, 0, hips=(8, 0, 0), head=-20, roll=3), "smooth"),
        (0.70, key(0.75, 0.05, 30, f("L", 0.52, 0.34), f("R", 0.34, 0.14), 20, 30, hips=(4, 0, 0), head=-20), "smooth"),
        (1.00, key(1.0, 0.02, 10, f("L", 0.10, 0.20), f("R", 0.08, 0.10), 0, 10, head=-6, fwd=0.04), "out"),
    ]
    mantle = [(t * MANTLE_S, p, e) for t, p, e in mantle]

    def hang(y, fwd=0.14, pitch=-4):
        return pose(lift=0.04 * d.S, body=(pitch, 0, 0), head=(-8, 0, 0),
                    **limbs(d, d.hand("L", y, fwd, 0.02), d.hand("R", y, fwd, 0.02), f("L", 0.05, 0.02), f("R", 0.02, -0.02), 25, -20,
                            elb={"L": (-0.6, -0.5, 0.2), "R": (0.6, -0.5, 0.2)}))
    ledge = [
        (0.00, hang(1.08), "smooth"),
        (0.35, hang(1.12, pitch=-6), "smooth"),
        (0.65, pose(lift=0.08 * d.S, body=(12, 0, 0), head=(-14, 0, 0),
                    **limbs(d, d.hand("L", 0.78, 0.26, 0.04), d.hand("R", 0.78, 0.26, 0.04), f("L", 0.20, 0.20), f("R", 0.04, 0.0), 10, -10)), "smooth"),
        (1.00, pose(lift=0.06 * d.S, body=(24, 0, 0), head=(-18, 0, 0),
                    **limbs(d, d.hand("L", 0.42, 0.28, 0.04), d.hand("R", 0.42, 0.28, 0.04), f("L", 0.44, 0.30), f("R", 0.06, 0.04), 20, 0)), "out"),
    ]
    ledge = [(t * LEDGE_S, p, e) for t, p, e in ledge]
    return {"mantle": mantle, "ledge": ledge}




# ---------------------------------------------------------------- Sable (sable): a kip over the lip, legs kicked up behind
def sable(rig):
    d = Dim(rig)
    f = d.foot

    def key(lh, rh, lf, rf, sh, pitch, hips=(0.0, 0.0, 0.0), head=-8.0, fpl=0.0, fpr=0.0, roll=0.0, fwd=0.0, elb=None):
        return pose(shoulder=(sh[0] * d.S, sh[1] * d.S), body=(pitch, roll, 0.0), hips=hips, head=(head, 0, 0),
                    **limbs(d, lh, rh, lf, rf, fpl, fpr, elb=elb))
    out = {"L": (-0.9, -0.1, 0.4), "R": (0.9, -0.1, 0.4)}
    mantle = [
        (0.00, key(d.hand("L", 0.64, 0.24, 0.05), d.hand("R", 0.64, 0.24, 0.05), f("L", 0.02, 0.08), f("R", 0.03, 0.10), (0.87, 0.03), 8), "out"),
        (0.18, key(d.hand("L", 0.50, 0.30, 0.05), d.hand("R", 0.50, 0.30, 0.05), f("L", 0.03, 0.10), f("R", 0.03, 0.12), (0.80, 0.10), 22,
                   hips=(6, 0, 0), head=-14), "out"),
        (0.45, key(d.hand("L", 0.30, 0.34, 0.05), d.hand("R", 0.30, 0.34, 0.05), f("L", 0.62, -0.30), f("R", 0.70, -0.34), (0.58, 0.16), 66,
                   hips=(10, 0, 0), head=-28, fpl=-40, fpr=-40), "smooth"),
        (0.72, key(d.hand("L", 0.20, 0.30, 0.20), d.hand("R", 0.20, 0.30, 0.20), f("L", 0.22, 0.20), f("R", 0.30, 0.10), (0.74, 0.10), 30,
                   hips=(4, 0, 0), head=-14, fpl=15, fpr=25, elb=out), "smooth"),
        (1.00, key(d.hand("L", 0.34, 0.26, 0.26), d.hand("R", 0.34, 0.26, 0.26), f("L", 0.04, 0.12), f("R", 0.05, 0.02), (0.88, 0.04), 8,
                   head=-4, elb=out), "out"),
    ]
    mantle = [(t * MANTLE_S, p, e) for t, p, e in mantle]

    def hang(y, lf, rf, pitch=-4, sway=0.0, fwd=0.14):
        return key(d.hand("L", y, fwd, 0.02), d.hand("R", y, fwd, 0.02), lf, rf, (0.92, 0.0), pitch, head=-8, fpl=25, fpr=-20, roll=sway,
                   elb={"L": (-0.6, -0.5, 0.2), "R": (0.6, -0.5, 0.2)})
    ledge = [
        (0.00, hang(1.10, f("L", 0.06, 0.03), f("R", 0.02, -0.02), sway=2), "smooth"),
        (0.30, hang(1.14, f("L", 0.03, -0.04), f("R", 0.06, 0.04), -6, -2), "smooth"),
        (0.58, hang(1.10, f("L", 0.10, 0.08), f("R", 0.05, 0.04), 2, 0), "smooth"),
        (0.80, key(d.hand("L", 0.62, 0.28, 0.04), d.hand("R", 0.62, 0.28, 0.04), f("L", 0.50, -0.20), f("R", 0.62, -0.26), (0.66, 0.12), 46,
                   hips=(8, 0, 0), head=-24, fpl=-30, fpr=-30), "smooth"),
        (1.00, key(d.hand("L", 0.40, 0.28, 0.12), d.hand("R", 0.40, 0.28, 0.12), f("L", 0.20, 0.12), f("R", 0.26, 0.04), (0.78, 0.08), 20,
                   hips=(4, 0, 0), head=-12), "out"),
    ]
    ledge = [(t * LEDGE_S, p, e) for t, p, e in ledge]
    return {"mantle": mantle, "ledge": ledge}


# ---------------------------------------------------------------- Albert (breaker): shield planted, a heave, the hammer dragged
def breaker(rig):
    d = Dim(rig)
    f = d.foot
    drag = d.hand("R", 0.20, -0.10, 0.04)

    def key(lh, rh, lift, pitch, hips=(0.0, 0.0, 0.0), head=-6.0, roll=0.0, fwd=0.0, lf=None, rf=None):
        return pose(lift=lift * d.S, fwd=fwd * d.S, body=(pitch, roll, 0.0), hips=hips, head=(head, 0, 0),
                    **limbs(d, lh, rh, lf or f("L", 0.04, 0.06), rf or f("R", 0.04, 0.06), 0, 0,
                            elb={"L": (-0.9, -0.2, 0.5), "R": (0.9, -0.2, 0.5)}))
    mantle = [
        (0.00, key(d.hand("L", 0.50, 0.30, 0.02), drag, 0.00, 4), "smooth"),
        (0.25, key(d.hand("L", 0.40, 0.34, 0.02), drag, -0.03, 14, hips=(6, 0, 0), head=-12, roll=-3), "smooth"),
        (0.55, key(d.hand("L", 0.18, 0.34, 0.02), d.hand("R", 0.30, 0.20, 0.06), 0.04, 24, hips=(10, 0, 0), head=-16, roll=3), "smooth"),
        (0.80, key(d.hand("L", 0.10, 0.30, 0.04), d.hand("R", 0.14, 0.24, 0.08), 0.05, 16, hips=(4, 0, 0), head=-8), "smooth"),
        (1.00, key(d.hand("L", 0.30, 0.20, 0.02), d.hand("R", 0.26, 0.04, 0.04), 0.01, 4, head=-4), "out"),
    ]
    mantle = [(t * MANTLE_S, p, e) for t, p, e in mantle]

    def hang(y, pitch=-3, roll=0.0):
        return key(d.hand("L", y, 0.10, 0.02), d.hand("R", y - 0.10, 0.08, 0.04), 0.02, pitch, head=-6, roll=roll)
    ledge = [
        (0.00, hang(1.06, -3, 2), "smooth"),
        (0.40, hang(1.10, -4, -2), "smooth"),
        (0.70, key(d.hand("L", 0.52, 0.32, 0.02), d.hand("R", 0.40, 0.24, 0.06), 0.05, 14, hips=(6, 0, 0), head=-14), "smooth"),
        (1.00, key(d.hand("L", 0.30, 0.32, 0.02), d.hand("R", 0.20, 0.16, 0.06), 0.04, 20, hips=(8, 0, 0), head=-14), "out"),
    ]
    ledge = [(t * LEDGE_S, p, e) for t, p, e in ledge]
    return {"mantle": mantle, "ledge": ledge}


# ---------------------------------------------------------------- Motley (ostra): no legs; he rises on his hover and settles
def ostra(rig):
    d = Dim(rig)

    def key(lift, pitch, lh, rh, roll=0.0, head=0.0, hips=(0.0, 0.0, 0.0)):
        return pose(lift=lift * d.S, body=(pitch, roll, 0.0), hips=hips, head=(head, 0, 0),
                    hand_L=lh, hand_R=rh, pole_hand_L=(-0.6, -0.5, 0.4), pole_hand_R=(0.6, -0.5, 0.4))
    mantle = [
        (0.00, key(0.00, 0, d.hand("L", 0.50, 0.12, 0.04), d.hand("R", 0.50, 0.12, 0.04)), "out"),
        (0.30, key(0.14, -10, d.hand("L", 0.80, 0.10, 0.22), d.hand("R", 0.80, 0.10, 0.22), roll=2, head=6), "smooth"),
        (0.60, key(0.20, 8, d.hand("L", 0.66, 0.20, 0.30), d.hand("R", 0.66, 0.20, 0.30), roll=-2, head=-6, hips=(4, 0, 0)), "smooth"),
        (1.00, key(0.04, 2, d.hand("L", 0.46, 0.12, 0.08), d.hand("R", 0.46, 0.12, 0.08), head=-2), "out"),
    ]
    mantle = [(t * MANTLE_S, p, e) for t, p, e in mantle]
    ledge = [
        (0.00, key(0.04, 0, d.hand("L", 0.74, 0.10, 0.20), d.hand("R", 0.74, 0.10, 0.20), roll=3), "smooth"),
        (0.35, key(0.10, -6, d.hand("L", 0.80, 0.10, 0.24), d.hand("R", 0.80, 0.10, 0.24), roll=-3, head=4), "smooth"),
        (0.70, key(0.20, 8, d.hand("L", 0.66, 0.18, 0.30), d.hand("R", 0.66, 0.18, 0.30), roll=2, head=-6), "smooth"),
        (1.00, key(0.06, 2, d.hand("L", 0.50, 0.12, 0.10), d.hand("R", 0.50, 0.12, 0.10), head=-2), "out"),
    ]
    ledge = [(t * LEDGE_S, p, e) for t, p, e in ledge]
    return {"mantle": mantle, "ledge": ledge}


HEROES = {"ryzz": {"clips": ryzz}, "sable": {"clips": sable}, "breaker": {"clips": breaker, "foot_names": {"foot.L": "x_foot.L", "foot.R": "x_foot.R"}},
          "ostra": {"clips": ostra, "legs": False}}
