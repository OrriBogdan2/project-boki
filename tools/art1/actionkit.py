"""ART-1 action set (item 145): the three shared actions every Hero gets its own motion for, in the keys posekit solves.
stomp: one finishing stomp, a loop of the game's cycle (Life stomp_cycle 0.7 s); the right foot lifts, the heel comes down on the beat at 0.7 of the cycle (Life hit_at).
drink: one tonic (Hunter DRINK_TIME 1.1 s), a one-shot for the upper body: the flask to the mouth, the head back, two swallows, down again.
revive: down on the right knee beside the fallen, the hands pressing, a loop.
A Hero's clips file gives its ready pose and what is its own: `hold` {"stomp": {...}, "drink": {...}, "revive": {...}} are pose keys laid over the shared ones
(its free hand, its weapon, how far its feet reach); `mouth` is where the flask meets the face, in armature space."""

CYCLE = 0.7     # s, Life.R["stomp_cycle"]
SLAM = 0.49     # s into the cycle the heel lands: 0.7 of it (Life: hit_at = cycle * 0.7)
DRINK = 1.1     # s, Hunter.DRINK_TIME


def shift(p, **d):
    """p with these vector keys moved by the given amounts."""
    o = dict(p)
    for k, v in d.items():
        o[k] = tuple(a + b for a, b in zip(o[k], v))
    return o


def ride(p, dz, hands):
    """The hand targets follow the hips down or up by dz (the arms keep their length)."""
    return shift(p, **{k: (0.0, 0.0, dz) for k in hands})


def stomp(C, ready, a_z, hands, over=None):
    """The right foot goes up and forward on the weight of the left, hangs, then drops flat on the beat: the hips and chest take the hit, and the body rebounds into the
    next lift. reach: how far forward the heel lands (m)."""
    o = dict(over or {})
    reach, lift = o.pop("reach", 0.22), o.pop("lift", 0.5)
    fr = ready["FR"]
    s0 = ride(dict(ready, **o.get("set", {})), -0.02, hands)
    s0 = dict(s0, pel=(ready["pel"][0] - 0.035, ready["pel"][1], ready["pel"][2] - 0.02), FR=(fr[0], fr[1], a_z + 0.03), FRp=0.2)
    up1 = dict(s0, FR=(fr[0], fr[1] + 0.1, a_z + 0.34), FRp=0.3, pel=(ready["pel"][0] - 0.05, ready["pel"][1], ready["pel"][2] + 0.0),
               tor=(ready["tor"][0] - 0.08, ready["tor"][1], ready["tor"][2]), hed=(ready["hed"][0] - 0.06, ready["hed"][1], ready["hed"][2]))
    top = dict(up1, FR=(fr[0], fr[1] + 0.18, a_z + lift), FRp=0.1, pel=(ready["pel"][0] - 0.05, ready["pel"][1], ready["pel"][2] + 0.01),
               tor=(ready["tor"][0] - 0.2, ready["tor"][1], ready["tor"][2]), prt=(ready["prt"][0] - 0.06, ready["prt"][1], ready["prt"][2]),
               hed=(ready["hed"][0] - 0.1, ready["hed"][1], ready["hed"][2]))
    top = ride(dict(top, **o.get("top", {})), 0.02, hands)
    hit = dict(top, FR=(fr[0], fr[1] + reach, a_z), FRp=-0.05, pel=(ready["pel"][0] - 0.01, ready["pel"][1] + 0.03, ready["pel"][2] - 0.16),
               tor=(ready["tor"][0] + 0.28, ready["tor"][1], ready["tor"][2]), prt=(ready["prt"][0] + 0.16, ready["prt"][1], ready["prt"][2]),
               hed=(ready["hed"][0] + 0.12, ready["hed"][1], ready["hed"][2]))
    hit = ride(dict(hit, **o.get("hit", {})), -0.14, hands)
    rebound = dict(hit, pel=(ready["pel"][0] - 0.02, ready["pel"][1] + 0.02, ready["pel"][2] - 0.1), tor=(ready["tor"][0] + 0.18, ready["tor"][1], ready["tor"][2]),
                   prt=(ready["prt"][0] + 0.1, ready["prt"][1], ready["prt"][2]), hed=(ready["hed"][0] + 0.06, ready["hed"][1], ready["hed"][2]))
    rebound = ride(rebound, 0.04, hands)
    return C("stomp", CYCLE, [(0.0, s0), (0.2, up1, "out"), (0.38, top), (SLAM, hit, "in"), (0.57, rebound, "out"), (CYCLE, s0)], loop=True)


def drink(C, ready, mouth, over=None):
    """The free hand brings the flask to the mouth, the head tips back, two swallows, then it comes down. The legs are the walk's own (the clip plays on the upper body)."""
    o = dict(over or {})
    key = o.pop("hand", "LP")
    hed = ready["hed"]
    sip = dict(ready, **{key: mouth, "hed": (hed[0] - 0.34, hed[1], hed[2]), "tor": (ready["tor"][0] - 0.06, ready["tor"][1], ready["tor"][2]),
                         "brow": -0.2, "lid": 0.5})
    sip.update(o.get("sip", {}))
    gulp = dict(sip, hed=(hed[0] - 0.4, hed[1], hed[2]))
    tilt = dict(sip, hed=(hed[0] - 0.46, hed[1], hed[2]), **{key: (mouth[0], mouth[1] - 0.03, mouth[2] + 0.015)})
    lift = dict(ready, **{key: (mouth[0] * 0.5 + ready[key][0] * 0.5, mouth[1] * 0.6, ready[key][2] * 0.5 + mouth[2] * 0.5 - 0.08)}, hed=(hed[0] - 0.1, hed[1], hed[2]))
    return C("drink", DRINK, [(0.0, ready), (0.14, lift), (0.28, sip, "out"), (0.45, tilt), (0.54, gulp), (0.64, tilt), (0.72, gulp), (0.84, sip), (1.0, lift), (DRINK, ready)])


def revive(C, ready, a_z, hands, over=None):
    """On the right knee, the left foot out before it, leaning over: both hands press down and ease, a slow pair of pulses every loop. over["kneel"]: the Hero's
    hands and weapon on the fallen."""
    fl, fr = ready["FL"], ready["FR"]
    kn = dict(ready, pel=(ready["pel"][0], 0.05, ready["pel"][2] - 0.46), prt=(0.2, ready["prt"][1], ready["prt"][2]), tor=(0.3, ready["tor"][1] * 0.5, ready["tor"][2]),
              hed=(0.18, 0.0, 0.0), FL=(fl[0], 0.34, a_z), FR=(fr[0] * 0.8, -0.3, a_z + 0.07), FLp=0.0, FRp=0.8, FLy=0.1, FRy=-0.2, brow=0.5, lid=0.1)
    kn.update((over or {}).get("kneel", {}))
    low = shift(dict(kn, tor=(kn["tor"][0] + 0.04, kn["tor"][1], kn["tor"][2]), pel=(kn["pel"][0], kn["pel"][1], kn["pel"][2] - 0.012)), **{k: (0.0, 0.0, -0.045) for k in hands})
    return C("revive", 1.6, [(0.0, kn), (0.2, low, "out"), (0.4, kn), (0.8, kn), (1.0, low, "out"), (1.2, kn), (1.6, kn)], loop=True, base=kn)


def clips(C, ready, a_z, hands, mouth, hold=None):
    h = hold or {}
    return [stomp(C, ready, a_z, hands, h.get("stomp")), drink(C, ready, mouth, h.get("drink")), revive(C, ready, a_z, hands, h.get("revive"))]
