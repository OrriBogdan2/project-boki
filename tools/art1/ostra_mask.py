"""Ostra's porcelain mask, sculpted as a height field on an egg (ART-1). No bpy here: numpy only, so the sculpt can be
previewed and painted from the same arrays. u, v are the mask's plane: u -1..1 his left..right as drawn with +x his right,
v -1 (chin) .. 1 (forehead). Coordinates of the features come from ostra_mask_sheet (front) and ostra_head_sheet (side)."""
import numpy as np

CHIN, TOP = 1.455, 1.835        # z of the mask's ends (blender space, the rig's y)
HALF_W = 0.138                  # half width at the cheek
BACK = -0.035                   # y of the mask's rim plane (the head bone is on y = 0)
DEPTH = 0.165                   # how far the face comes forward of the rim
NECK_Y = 0.03                   # the mask sits forward of the neck


def sm(a, b, x):
    t = np.clip((x - a) / (b - a), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def gauss(u, v, cu, cv, su, sv, rot=0.0):
    du, dv = u - cu, v - cv
    if rot:
        c, s = np.cos(rot), np.sin(rot)
        du, dv = c * du + s * dv, -s * du + c * dv
    return np.exp(-(du * du / (su * su) + dv * dv / (sv * sv)))


def seg_dist(u, v, pts):
    """distance to a polyline, and the 0..1 along it"""
    pts = np.asarray(pts, float)
    best = np.full(u.shape, 1e9)
    along = np.zeros(u.shape)
    n = len(pts) - 1
    for i in range(n):
        a, b = pts[i], pts[i + 1]
        ab = b - a
        t = np.clip(((u - a[0]) * ab[0] + (v - a[1]) * ab[1]) / (ab @ ab), 0.0, 1.0)
        d = np.hypot(u - a[0] - t * ab[0], v - a[1] - t * ab[1])
        m = d < best
        best = np.where(m, d, best)
        along = np.where(m, (i + t) / n, along)
    return best, along


def lips(u):
    """the mouth's upper and lower edge at u: a huge crescent, the corners driven up into the cheeks"""
    au = np.abs(u) / 0.80
    top = -0.385 + 0.20 * au ** 2.4
    bot = -0.72 + 0.53 * au ** 2.0
    return top, bot


def mouth_mask(u, v, feather=0.012):
    top, bot = lips(u)
    inside = sm(-feather, feather, top - v) * sm(-feather, feather, v - bot)
    return inside * (np.abs(u) < 0.80)


def teeth(u, v):
    """-> height of the clenched rows inside the mouth, the seam between the rows, a mask of the teeth"""
    top, bot = lips(u)
    mid = top + (bot - top) * 0.50
    n = 13.0
    cell = u * n / 0.8
    bump = np.abs(np.sin(np.pi * cell * 0.5 + np.pi / 2)) ** 0.45    # rounded tooth by tooth
    rows = np.minimum(sm(0.0, 0.012, top - v - 0.012), sm(0.0, 0.012, v - bot - 0.012))
    seam = np.exp(-((v - mid) / 0.012) ** 2)
    return rows * (0.55 + 0.45 * bump) * (1.0 - 0.8 * seam), seam, rows


def eyes():
    return (0.43, 0.235), (-0.43, 0.235)


def eye_socket(u, v):
    """0..1 how deep in an eye socket"""
    au = np.abs(u)
    # almond tipped up and out, its top cut flat by the brow: the anger
    slant = v - 0.235 - 0.34 * (au - 0.43)
    du = (au - 0.42) / 0.235
    dv = slant / 0.112
    d = np.sqrt(du * du + dv * dv)
    return sm(1.05, 0.74, d) * sm(0.095, 0.05, slant)


def height(u, v):
    """the sculpt, in units of DEPTH (1 is the nose tip's reach), over the egg"""
    au = np.abs(u)
    h = np.zeros(u.shape)
    # brow ridge: a heavy V driven down to the nose bridge, the anger
    d, a = seg_dist(au, v, [(0.045, 0.235), (0.22, 0.375), (0.52, 0.53), (0.80, 0.60)])
    h += 0.25 * np.exp(-(d / (0.06 + 0.04 * a)) ** 2) * (1.0 - 0.45 * a)
    # the furrow between the brows, two short creases
    d2, _ = seg_dist(au, v, [(0.075, 0.30), (0.10, 0.52)])
    h -= 0.075 * np.exp(-(d2 / 0.022) ** 2)
    # forehead dome and temple
    h += 0.08 * gauss(u, v, 0, 0.8, 0.55, 0.4)
    # the eye sockets
    h -= 0.15 * gauss(au, v, 0.43, 0.22, 0.25, 0.15, 0.1)
    s = eye_socket(u, v)
    h -= 0.12 * s
    # cheek apples, shoved up by the grin
    h += 0.2 * gauss(au, v, 0.50, -0.02, 0.24, 0.18, -0.5)
    # the nose: a long blade with a hooked tip and wings
    bridge = np.exp(-(u / (0.075 + 0.05 * sm(0.1, -0.2, v))) ** 2) * sm(0.34, 0.12, v) * sm(-0.32, -0.18, v)
    h += 0.30 * bridge * (0.6 + 0.4 * sm(0.2, -0.2, v))
    h += 0.24 * gauss(u, v, 0.0, -0.205, 0.09, 0.08)
    h += 0.12 * gauss(au, v, 0.165, -0.235, 0.075, 0.055)
    h -= 0.1 * gauss(au, v, 0.07, -0.285, 0.05, 0.03)
    # the fold from the nose wing round the grin, cut deep
    d3, _ = seg_dist(au, v, [(0.20, -0.20), (0.45, -0.20), (0.72, -0.08), (0.86, 0.05)])
    h -= 0.085 * np.exp(-(d3 / 0.03) ** 2)
    h += 0.06 * np.exp(-((d3 - 0.06) / 0.05) ** 2) * (v < -0.1)
    # lips: a rim round the mouth, then the deep cut and the teeth inside
    top, bot = lips(u)
    rim = np.exp(-((v - top - 0.035) / 0.035) ** 2) + 1.2 * np.exp(-((v - bot + 0.04) / 0.05) ** 2)
    h += 0.09 * rim * (au < 0.84)
    corner = gauss(au, v, 0.80, -0.2, 0.05, 0.05)
    h -= 0.08 * corner
    m = mouth_mask(u, v)
    t, seam, rows = teeth(u, v)
    h = h * (1.0 - m) + m * (h * 0.4 - 0.26 + 0.14 * t)
    # chin: a hard knob and the groove over it
    h += 0.17 * gauss(u, v, 0, -0.875, 0.2, 0.09)
    h -= 0.06 * gauss(u, v, 0, -0.76, 0.26, 0.03) * (1.0 - m)
    # the jaw's corner
    h += 0.05 * gauss(au, v, 0.55, -0.6, 0.18, 0.2, 0.7)
    return h


def outline(v):
    """half width of the mask at v (the egg: full cheek, narrow chin)"""
    t = (v + 1.0) * 0.5
    w = np.sin(np.pi * np.clip(t, 0, 1) ** 0.72) ** 0.62
    return np.maximum(w, 0.0)


def shape(u, v):
    """(u, v) on the mask -> blender xyz, u is measured to the mask's edge at that row"""
    w = outline(v)
    x = u * w * HALF_W
    z = CHIN + (v + 1.0) * 0.5 * (TOP - CHIN)
    # the egg's front: full at the middle, back at the rim, leaning forward at the chin (the jut of the grin)
    r = np.sqrt(np.clip(1.0 - u * u, 0.0, 1.0)) * np.sqrt(np.clip(1.0 - (v * 0.92) ** 2, 0.02, 1.0))
    y = BACK + NECK_Y + DEPTH * (0.52 * r ** 0.8 + 0.1 * (1.0 - v) * 0.5 * r) - 0.05 * sm(0.58, 0.95, v)
    return x, y, z


def surface(N=361, M=481):
    """the sculpt on a dense grid: positions (M, N, 3) and uv (M, N, 2) in the 0..1 of the mask's texture"""
    us = np.linspace(-1, 1, N)
    vs = np.linspace(-1, 1, M)
    u, v = np.meshgrid(us, vs)
    # the grid's u is taken across the outline, so the mask's edge is the grid's edge
    x, y, z = shape(u, v)
    pu = np.divide(x, HALF_W)       # plane coordinates the sculpt is drawn in
    h = height(pu, v)
    edge = sm(1.0, 0.86, np.abs(u)) * sm(1.0, 0.93, np.abs(v))
    y = y + DEPTH * h * edge
    return np.dstack((x, y, z)), np.dstack((pu * 0.5 + 0.5, v * 0.5 + 0.5)), pu, v, h
