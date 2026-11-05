"""Ostra's hand-keyed clips: the table ostra_anim.py samples. Key = (t, {channels}, easing into it). See ostra_pose.NEUTRAL for the channels."""
import math

# his two signature holds
ORB_UP = {"hR": (0.31, 0.20, 1.05), "fR": (0.05, 0.75, 0.65), "pR": (-0.25, -0.45, 0.85), "eR": (1.0, -0.7, -0.6), "cR": 0.5, "sR": 0.8}
OFF_LOW = {"hL": (-0.31, 0.12, 0.88), "fL": (-0.45, 0.35, -0.8), "pL": (0.3, 0.85, 0.2), "eL": (-1.0, -0.5, 0.0), "cL": 0.35, "sL": 1.0}
STILL = dict(ORB_UP, **OFF_LOW, spine=(14.0, -6.0, 3.0), head=(-8.0, 6.0, 13.0), brow=-0.8, cheek=0.3, lid=0.3, jaw=0.0)


def idle_add(P, t):
    """the breath, and the fingers forever working"""
    k = math.sin(t / 3.2 * 2 * math.pi)
    s = P["spine"]
    P["spine"] = (s[0] + 1.2 * k, s[1], s[2])
    P["wR"] = 0.13
    P["wL"] = 0.2


CLIPS = {
    "idle": {"len": 3.2, "step": 3, "base": STILL, "add": idle_add, "keys": [
        (0.0, {}),
        (1.3, {}),
        # the puppet's tick: his head yanked to the other side, held, back
        (1.42, {"head": (-8.0, -10.0, -9.0), "brow": -0.5, "cheek": 0.7}, "snap"),
        (2.3, {"head": (-6.0, -8.0, -10.0)}),
        (2.42, {"head": (-8.0, 6.0, 13.0), "brow": -0.8, "cheek": 0.3}, "snap"),
        (3.2, {}),
    ]},
}
