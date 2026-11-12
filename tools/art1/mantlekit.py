"""ART-1 ledge climb (the mantle clip), in the keys posekit solves. The game plays it in two parts (scripts/heroes/warden_clips.gd `_mantle`):
the first `rise` s of the clip are the climb, and their time is how far up the face the Hunter is (0 at the grab, 1 at the lip), so the hands
and feet can never lag the body; the rest (the tail) plays in real time once he is over: the pop, the landing, the run taking over.
The clip does not move the Hunter (the body rises by itself and the model rides it), so the lip comes down past him: its top is `surface(k)`
above his feet. His hands go on it while he hangs and pivots over it, he pushes off, and the lead foot steps onto it.
A Hero's clips file gives its READY pose and these numbers (cfg):
  az ankle height, hx hands' half-spread, dz / lk the Hero's Solver.remap numbers (keys are written for another build: hands move by dz, feet's air height stretches by lk), hands {key: side} (LP left = -1, G right = 1; a Hero whose right arm is a weapon leaves G out and gives it in `extra`),
  rise / tail seconds, w how far the torso folds over the lip (a heavy Hero more), nod how far the head and chest drop on the landing,
  extra {phase: {keys}} the Hero's own face, tail, weapon and wings on each phase: reach, over, step, up, top, pop, land."""

DEEP = 1.4        # m: the face a typical rise climbs (a jump's reach), so the lip starts about shoulder-high
SOLE = 0.12       # m: the body ends this far above the lip (hunter.gd `_ledge_rise`), then pops


def surface(k):
    """Height of the lip's top over the Hunter's feet at progress k of the rise."""
    return DEEP * (1.0 - k) - SOLE


def clip(C, base, cfg):
    az, hx, hands = cfg["az"], cfg["hx"], cfg["hands"]
    rise, tail, w, nod = cfg.get("rise", 0.4), cfg.get("tail", 0.4), cfg.get("w", 1.0), cfg.get("nod", 0.0)
    ex = cfg.get("extra", {})
    dz, lk = cfg.get("dz", 0.0), cfg.get("lk", 1.0)

    def air(h):
        """An ankle key `h` m over the ground, as the Solver will read it."""
        return az + h / lk

    def on_lip(k, y):
        return {key: (side * hx, y, surface(k) + 0.05 - dz) for key, side in hands.items()}

    def pose(phase, p):
        return dict(p, **ex.get(phase, {}))

    reach = dict(base, **on_lip(0.0, 0.34), pel=(0.0, 0.0, 0.0), prt=(-0.12, 0.0, 0.0), tor=(0.05, 0.0, 0.0), hed=(-0.34, 0.0, 0.0),
                 FL=(-0.11, 0.20, air(0.22)), FR=(0.11, 0.25, air(0.40)), FLp=0.0, FRp=0.0)
    over = dict(reach, **on_lip(0.25, 0.36), pel=(0.0, 0.08, -0.02), prt=(0.42 * w, 0.0, 0.0), tor=(0.38 * w, 0.0, 0.0), hed=(-0.5, 0.0, 0.0),
                FL=(-0.11, 0.06, air(0.12)), FR=(0.11, 0.30, air(0.56)))
    step = dict(over, **on_lip(0.5, 0.36), pel=(0.0, 0.05, 0.0), prt=(0.32 * w, 0.0, 0.0), tor=(0.28 * w, 0.0, 0.0), hed=(-0.4, 0.0, 0.0),
                FL=(-0.11, 0.00, air(0.26)), FR=(0.11, 0.30, air(surface(0.5) + 0.02)))
    up = dict(base, pel=(0.0, 0.02, 0.0), prt=(0.24 * w, 0.0, 0.0), tor=(0.16 * w, 0.0, 0.0), hed=(-0.15, 0.0, 0.0),
              FL=(-0.11, 0.28, air(0.32)), FR=(0.12, 0.12, air(surface(0.75) + 0.02)))
    top = dict(up, FL=(-0.11, 0.20, air(0.06)), FR=(0.12, -0.04, az), prt=(0.22 * w, 0.0, 0.0))
    pop = dict(top, FL=(-0.11, 0.12, air(0.14)), FR=(0.12, -0.12, air(0.18)))
    land = dict(base, prt=(0.2 * w + nod, 0.0, 0.0), tor=(0.12 * w + nod, 0.0, 0.0), hed=(-0.1 - nod, 0.0, 0.0), pel=(0.0, 0.0, -0.04 * w),
                FL=(-0.11, 0.22, az), FR=(0.12, -0.18, air(0.03)))
    phases = [("reach", reach), ("over", over), ("step", step), ("up", up), ("top", top)]
    keys = [(rise * i / 4.0, pose(n, p), "out" if n == "over" else "smooth") for i, (n, p) in enumerate(phases)]
    keys += [(rise + tail * 0.3, pose("pop", pop)), (rise + tail * 0.7, pose("land", land), "out"), (rise + tail, base)]
    return C("mantle", rise + tail, keys)
