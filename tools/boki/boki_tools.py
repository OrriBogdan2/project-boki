"""A hatchet and a pick, skinned to their own bones, collapsed except in the clips that use them."""
import numpy as np

from boki_sdf import Cone, Shape, v3

SIDE = v3(1, 0, 0)


def axe_blade(base, axis, up):
    """A fan from the eye of the axe to a straight cutting edge."""
    c1 = base + up * 0.155 + axis * 0.080
    c2 = base + up * 0.155 - axis * 0.090
    flat = {"flat": 0.24, "flat_axis": SIDE}
    return [Cone("b0", "prop_axe", base, (c1 + c2) * 0.5, 0.034, 0.078, k=0.0, **flat),
            Cone("b1", "prop_axe", base, c1, 0.030, 0.012, k=0.01, **flat),
            Cone("b2", "prop_axe", base, c2, 0.030, 0.012, k=0.01, **flat),
            Cone("b3", "prop_axe", c1, c2, 0.012, 0.012, k=0.01, **flat)]


def tools(grip, axis, side=SIDE):
    """name -> (Shape, step, tris). `grip` is where it is held, `axis` the way the handle runs; the blade is on the
    `up` side of the handle, cross(side, axis): pass -SIDE to put it on the other edge."""
    up = np.cross(side, axis)
    end = grip + axis * 0.30
    return {
        "axe_handle": (Shape([Cone("h", "prop_axe", grip, end, 0.017, 0.015, k=0)]), 0.004, 12),
        "axe_blade": (Shape(axe_blade(end - axis * 0.045, axis, up)), 0.003, 56),
        "pick_handle": (Shape([Cone("h", "prop_pick", grip, end, 0.017, 0.015, k=0)]), 0.004, 12),
        "pick_head": (Shape([Cone("a", "prop_pick", end, end + up * 0.17 - axis * 0.06, 0.034, 0.006, k=0.0),
                             Cone("b", "prop_pick", end, end - up * 0.17 - axis * 0.06, 0.034, 0.006, k=0.005)]),
                      0.003, 56),
    }
