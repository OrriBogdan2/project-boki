"""Breaker's sculpt (ART-1): the shapes, as signed distance fields (tools/art1/sculpt_kit.py). Everything is built
from the rig's own joints (art/wardens/src/breaker_rig.json), so he stays on the contract armature.
Art: docs/art/gen/wardens_r3/breaker_front / head_sheet / hammer_sheet / shield_sheet (ext/imagegen), BREAKER_KIT.md."""
import json
import math
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
import sculpt_kit as S
from sculpt_kit import Field, cap, ell, sph, path, box, cyl, icicle, fbm, smooth, vnoise

# labels (the paint's regions)
HAND = 1.32
SKIN, BELLY, NAIL, LIP, GUM, TOOTH, TUSK, NOSE, EAR_IN, LID, BARN = 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11


def joints(rig_path):
    with open(rig_path) as f:
        rig = json.load(f)
    return {k: np.array([v["head"][0], -v["head"][2], v["head"][1]], np.float32) for k, v in rig["bones"].items()}


def _bump(amp, f, oct=3):
    return lambda x, y, z: (fbm(x, y, z, f, oct) - 0.5) * amp


def barnacle(fld, c, n, r=0.018, lab=BARN):
    """A barnacle: a low ring with a pit, seated on the surface at c, facing n."""
    c, n = np.array(c, np.float32), np.array(n, np.float32) / np.linalg.norm(n)
    fld.add(cap(c - n * r * 0.4, c + n * r * 0.12, r, r * 0.68), k=r * 0.3, lab=lab)
    fld.sub(sph(c + n * r * 0.72, r * 0.42), k=r * 0.12, lab=lab)


def body(J, vox=0.0045):
    """The skin from the neck down: torso, arms and legs blended only where they join."""
    lo, hi = (-0.78, -0.46, -0.02), (0.78, 0.5, 1.5)
    hx, sh, tx = J["hand.R"][0], J["upper_arm.R"], J["thigh.R"]
    sx = float(sh[0])
    wob = _bump(0.016, 7.0)
    t = Field(lo, hi, vox)
    # the torso: a hunched barrel, the chest and belly hanging forward, a hump of back and traps up to the skull
    t.add(ell((0, -0.03, 1.03), (0.37, 0.28, 0.30)), 0.05, SKIN, "hips", wob)
    t.add(ell((0, -0.15, 1.16), (0.31, 0.2, 0.2)), 0.1, SKIN, "hips", wob)
    for s in (-1, 1):
        t.add(cap((s * 0.1, -0.08, 1.32), (s * 0.34, -0.04, 1.2), 0.11, 0.13), 0.08, SKIN, "hips", wob)
        t.add(ell((s * 0.165, 0.2, 1.055), (0.175, 0.085, 0.125), (0, 0.15 * s, 0)), 0.05, SKIN, "hips")     # pecs
        t.add(ell((s * 0.2, 0.16, 0.9), (0.13, 0.09, 0.08)), 0.09, SKIN, "hips")         # the fold under them
        t.add(ell((s * 0.13, -0.15, 0.62), (0.145, 0.115, 0.125)), 0.08, SKIN, "hips")      # the seat
        t.add(ell((s * 0.24, -0.17, 1.03), (0.12, 0.1, 0.17)), 0.06, SKIN, "hips")       # the lats
    t.add(cap((0, -0.02, 1.2), (0, 0.03, 1.39), 0.15, 0.125), 0.05, SKIN, "hips", wob)   # the neck, into the head
    t.add(ell((0, 0.09, 0.76), (0.262, 0.285, 0.275)), 0.09, BELLY, "hips", wob)         # the belly
    t.add(ell((0, 0.13, 0.66), (0.22, 0.2, 0.15)), 0.08, BELLY, "hips")
    t.add(ell((0, 0.0, 0.6), (0.285, 0.23, 0.16)), 0.08, SKIN, "hips")                  # the hips
    t.sub(ell((0, 0.376, 0.72), (0.016, 0.02, 0.022)), 0.02)                            # the navel
    t.sub(cap((0, 0.26, 1.15), (0, 0.32, 0.93), 0.012, 0.018), 0.05)                    # the breastbone's valley
    t.sub(cap((s * 0, -0.27, 1.2), (0, -0.25, 0.85), 0.01, 0.012), 0.05)                # the spine's valley

    # arms, each on its own field so nothing bridges to the belly
    out = t
    for s in (-1, 1):
        n = "R" if s > 0 else "L"
        a = Field(lo, hi, vox)
        S1 = np.array((s, 1, 1), np.float32)
        def p(x, y, z):
            return np.array((s * (sx + x), y, z), np.float32)

        def q(x, y, z):      # (the hand, oversized about the wrist)
            return np.array((s * (sx + x * HAND), y * HAND, 0.61 + (z - 0.61) * HAND), np.float32)
        ua, fa, hd = "upper_arm." + n, "forearm." + n, "hand." + n
        a.add(ell(p(0.03, 0, 1.13), (0.165, 0.175, 0.15)), 0.04, SKIN, "pauldron." + n, wob)   # the deltoid cap
        a.add(ell(p(0.0, 0.015, 1.02), (0.135, 0.145, 0.15)), 0.06, SKIN, ua, wob)
        a.add(cap(p(-0.005, 0.03, 1.0), p(0, 0.03, 0.87), 0.118, 0.1), 0.05, SKIN, ua)        # biceps
        a.add(cap(p(0.015, -0.04, 1.02), p(0.01, -0.03, 0.86), 0.105, 0.09), 0.05, SKIN, ua)  # triceps
        a.add(sph(p(0, -0.02, 0.84), 0.095), 0.05, SKIN, fa)                                  # the elbow
        a.add(ell(p(0.012, 0.012, 0.735), (0.132, 0.13, 0.135)), 0.05, SKIN, fa, wob)         # the huge forearm
        a.add(cap(p(0, 0, 0.72), p(0, 0, 0.625), 0.11, 0.088), 0.04, SKIN, fa)
        # the hand: palm side in, knuckles out; the fingers curl toward the body
        ins = -1.0   # toward the body, in p() space
        H = HAND
        a.add(ell(q(0.005, 0.0, 0.55), (0.078 * H, 0.095 * H, 0.075 * H)), 0.03, SKIN, hd)     # palm
        a.add(ell(q(0.04, 0.0, 0.565), (0.05 * H, 0.085 * H, 0.06 * H)), 0.02, SKIN, hd)       # the back of the hand
        for i, yo in enumerate((0.071, 0.024, -0.024, -0.069)):
            l = (1.0, 1.08, 1.03, 0.86)[i]
            k = q(0.03, yo, 0.49)
            m1 = q(0.022, yo, 0.49 - 0.056 * l)
            m2 = q(-0.012, yo, 0.49 - 0.1 * l)
            tp = q(-0.05, yo, 0.49 - 0.118 * l)
            a.add(sph(k, 0.029 * H), 0.012, SKIN, hd)
            a.add(path((k, m1), (0.027 * H, 0.025 * H)), 0.008, SKIN, "x_fing." + n)
            a.add(path((m1, m2, tp), (0.025 * H, 0.024 * H, 0.021 * H)), 0.006, SKIN, "x_fing2." + n)
            a.add(ell(tp + np.array((ins * s * 0.006, 0, -0.016), np.float32), (0.024, 0.023, 0.014)), 0.003, NAIL, "x_fing2." + n)
        t0, t1, t2 = q(-0.02, 0.07, 0.59), q(-0.03, 0.125, 0.535), q(-0.06, 0.14, 0.49)
        a.add(ell(q(-0.02, 0.055, 0.565), (0.05 * H, 0.05 * H, 0.06 * H)), 0.03, SKIN, hd)
        a.add(path((t0, t1), (0.036 * H, 0.03 * H)), 0.015, SKIN, "x_thumb." + n)
        a.add(path((t1, t2), (0.03 * H, 0.025 * H)), 0.01, SKIN, "x_thumb." + n)
        # join: a wide blend at the shoulder, nothing below the armpit
        a.grp = 1 if s > 0 else 2
        out = out.merge(a, kfn=lambda x, y, z: 0.1 * smooth(0.97, 1.12, z))

    # legs, each on its own field
    for s in (-1, 1):
        n = "R" if s > 0 else "L"
        lg = Field(lo, hi, vox)
        lx = float(s * tx[0])
        kz = float(J["shin.R"][2])
        th, sn, ft = "thigh." + n, "shin." + n, "x_foot." + n
        lg.add(cap((lx * 1.04, -0.01, 0.6), (lx * 1.02, 0.005, kz + 0.05), 0.158, 0.118), 0.05, SKIN, th, wob)
        lg.add(ell((lx * 1.08, 0.04, 0.47), (0.12, 0.12, 0.12)), 0.06, SKIN, th)
        lg.add(sph((lx, 0.02, kz + 0.01), 0.108), 0.04, SKIN, sn)                            # the knee
        lg.add(ell((lx * 1.04, -0.045, kz - 0.09), (0.112, 0.112, 0.135)), 0.05, SKIN, sn, wob)    # the calf
        lg.add(cap((lx, 0, kz - 0.06), (lx, 0, 0.09), 0.1, 0.082), 0.04, SKIN, sn)
        # the bare ogre foot: broad and long, toes splayed; a heel, a high arch
        lg.add(ell((lx, -0.045, 0.06), (0.078, 0.082, 0.06)), 0.04, SKIN, ft)                 # heel
        lg.add(ell((lx + s * 0.008, 0.075, 0.062), (0.112, 0.15, 0.063)), 0.04, SKIN, ft, wob)
        lg.add(cap((lx, -0.01, 0.11), (lx + s * 0.005, 0.1, 0.075), 0.08, 0.05), 0.04, SKIN, ft)
        toes = [(-0.075, 0.232, 0.042, 0.04), (-0.022, 0.256, 0.032, 0.034), (0.024, 0.25, 0.031, 0.032),
                (0.065, 0.232, 0.029, 0.03), (0.1, 0.2, 0.026, 0.027)]
        for dx, y, r, zr in toes:
            c = (lx + s * dx * 1.0 + s * 0.006, y, zr)
            lg.add(ell(c, (r * 1.05, r * 1.5, zr)), 0.018, SKIN, ft)
            lg.add(ell((c[0], y + r * 0.95, zr + zr * 0.32), (r * 0.8, r * 0.62, zr * 0.42)), 0.003, NAIL, ft)
        lg.d = np.maximum(lg.d, -(np.arange(lg.n[2], dtype=np.float32)[None, None, :] * vox + lo[2]))    # flat on the ground
        lg.grp = 3 if s > 0 else 4
        out = out.merge(lg, kfn=lambda x, y, z: 0.09 * smooth(0.5, 0.6, z))

    # the crotch and groin, to tie the legs in under the skirt, and barnacles on the arm, the shoulder and the back
    for c, nrm, r in (((-0.5, 0.09, 1.1), (-0.8, 0.6, 0.2), 0.02), ((-0.52, 0.03, 1.03), (-1, 0.2, 0), 0.016),
                      ((-0.46, 0.13, 1.0), (-0.6, 0.8, 0), 0.013), ((0.1, -0.3, 1.1), (0.2, -1, 0.1), 0.022),
                      ((0.2, -0.28, 1.2), (0.3, -1, 0.2), 0.018), ((-0.05, -0.31, 1.03), (0, -1, 0), 0.016),
                      ((0.16, -0.31, 0.95), (0.2, -1, 0), 0.014), ((-0.14, -0.3, 1.18), (-0.2, -1, 0.3), 0.015),
                      ((0.51, 0.04, 1.08), (1, 0.3, 0), 0.016)):
        c = out.project(np.array([c], np.float32))[0]
        nr = out.grad(np.array([c], np.float32))[0]
        barnacle(out, c, nr, r)
    return out


def head(J, vox=0.0016):
    """The head at high resolution: a small bald skull low between the shoulders, a heavy underbite in a huge grin."""
    lo, hi = (-0.2, -0.17, 1.2), (0.2, 0.28, 1.58)
    h = Field(lo, hi, vox)
    bn = "head"
    wob = _bump(0.006, 16.0)
    h.add(ell((0, 0.015, 1.455), (0.122, 0.137, 0.102)), 0.03, SKIN, bn, wob)             # the skull
    h.add(ell((0, 0.075, 1.385), (0.117, 0.1, 0.09)), 0.05, SKIN, bn, wob)                # the face mass
    h.add(cap((0, -0.02, 1.25), (0, 0.0, 1.4), 0.125, 0.11), 0.04, SKIN, bn)              # the neck stub under the skull
    # the jaw: wide, thrust forward past the upper lip
    h.add(ell((0, 0.105, 1.335), (0.118, 0.095, 0.062)), 0.04, SKIN, bn, wob)
    h.add(ell((0, 0.165, 1.315), (0.08, 0.05, 0.04)), 0.035, SKIN, bn)                    # the chin
    for s in (-1, 1):
        h.add(ell((s * 0.092, 0.075, 1.335), (0.04, 0.055, 0.045)), 0.03, SKIN, bn)       # the jaw's corner
        # the brow: a heavy overhanging ridge, angled down toward the nose: fierce and glad at once
        h.add(cap((s * 0.012, 0.135, 1.468), (s * 0.055, 0.128, 1.484), 0.018, 0.021), 0.03, SKIN, bn)
        h.add(cap((s * 0.055, 0.128, 1.484), (s * 0.103, 0.09, 1.474), 0.021, 0.014), 0.03, SKIN, bn)
        # the cheeks, shoved up by the grin
        h.add(ell((s * 0.082, 0.128, 1.402), (0.046, 0.04, 0.034)), 0.03, SKIN, bn)
        h.add(cap((s * 0.04, 0.165, 1.385), (s * 0.106, 0.11, 1.37), 0.016, 0.012), 0.022, SKIN, bn)   # the laugh fold
        # the ears: small, pointed, swept back
        h.add(ell((s * 0.122, -0.002, 1.435), (0.012, 0.034, 0.042), (0.55, 0, 0)), 0.012, SKIN, bn)
        h.add(cap((s * 0.127, -0.01, 1.455), (s * 0.142, -0.05, 1.482), 0.017, 0.004), 0.012, SKIN, bn)
        h.add(cap((s * 0.124, 0.0, 1.41), (s * 0.13, -0.005, 1.395), 0.012, 0.01), 0.008, SKIN, bn)
        h.sub(ell((s * 0.134, -0.008, 1.44), (0.008, 0.02, 0.028), (0.55, 0, 0)), 0.006, EAR_IN)
        # the eye sockets
        h.sub(ell((s * 0.056, 0.15, 1.449), (0.034, 0.03, 0.02), (0, 0.12 * s, 0)), 0.012)
        # puffy lids and bags under them
        h.add(cap((s * 0.03, 0.143, 1.463), (s * 0.08, 0.128, 1.46), 0.0105, 0.009), 0.006, LID, "x_lid." + ("R" if s > 0 else "L"))
        h.add(cap((s * 0.03, 0.147, 1.436), (s * 0.085, 0.127, 1.438), 0.012, 0.01), 0.01, SKIN, bn)
    # the broken nose: a bent bridge and a fat bulb
    h.add(cap((0.0, 0.135, 1.47), (0.008, 0.172, 1.425), 0.019, 0.022), 0.018, SKIN, bn)
    h.add(ell((0.01, 0.184, 1.404), (0.03, 0.033, 0.028)), 0.018, NOSE, bn)
    for s in (-1, 1):
        h.add(ell((0.01 + s * 0.031, 0.172, 1.396), (0.019, 0.021, 0.016)), 0.01, NOSE, bn)
        h.sub(ell((0.01 + s * 0.015, 0.195, 1.378), (0.0085, 0.01, 0.0065)), 0.006, NOSE)
    # the mouth: a wide open grin; the upper lip arches, the lower one thrust out, carved down to the gums
    arc = lambda u, a, b: (u, a - 0.07 * (u / 0.1) ** 2 * 0.62, b)
    mo = []
    for u in np.linspace(-0.098, 0.098, 13):
        u = float(u)
        y = 0.186 - 0.066 * (u / 0.098) ** 2
        mo.append((u, y, 1.343 + 0.033 * (u / 0.098) ** 2))
    h.sub(path(mo, [0.012 + 0.021 * (1 - (m[0] / 0.098) ** 2) ** 0.8 for m in mo]), 0.007, GUM)
    # lips
    up = [(m[0], m[1] + 0.006, m[2] + 0.021 * (1 - (m[0] / 0.098) ** 2) + 0.011) for m in mo]
    dn = [(m[0], m[1] + 0.011, m[2] - 0.023 * (1 - (m[0] / 0.098) ** 2) - 0.012) for m in mo]
    h.add(path(up, [0.0065] * len(up)), 0.008, LIP, bn)
    h.add(path(dn, [0.0095] * len(dn)), 0.01, LIP, "x_jaw")
    # the mouth's dark inside, the gums and teeth (upper row, crooked; lower row bigger)
    h.add(ell((0, 0.1, 1.345), (0.085, 0.06, 0.033)), 0.002, GUM, bn)
    for i, u in enumerate((-0.058, -0.04, -0.0205, 0.0, 0.021, 0.041, 0.059)):
        y = 0.178 - 0.066 * (u / 0.098) ** 2
        z = 1.352 + 0.015 * (u / 0.098) ** 2 + 0.001 * (i % 2)
        w = 0.0105 + 0.002 * (i in (2, 3, 4))
        h.add(box((u, y - 0.012, z), (w * 0.86, 0.008, 0.0125 - 0.0015 * (i % 3)), 0.0028, (0, 0, -u * 4)), 0.0, TOOTH, bn)
    for i, u in enumerate((-0.03, -0.01, 0.012, 0.033)):
        y = 0.19 - 0.066 * (u / 0.098) ** 2
        h.add(box((u, y - 0.012, 1.326), (0.0095, 0.008, 0.0105), 0.0028, (0, 0, -u * 4)), 0.0, TOOTH, "x_jaw")
    # the tusks, up from the lower jaw past the lip
    for s in (-1, 1):
        a, b = (s * 0.061, 0.166, 1.322), (s * 0.072, 0.165, 1.408)
        h.add(path((a, (s * 0.07, 0.172, 1.365), b), (0.0155, 0.0135, 0.0015)), 0.002, TUSK, "x_jaw")
    # barnacles on the crown, and the crown's own lumps
    for c, n, r in (((-0.075, 0.09, 1.525), (-0.5, 0.5, 0.8), 0.0105), ((0.055, 0.0, 1.552), (0.3, 0, 1), 0.0125),
                    ((0.082, 0.085, 1.52), (0.5, 0.5, 0.8), 0.008), ((-0.02, -0.06, 1.545), (0, -0.4, 1), 0.01),
                    ((0.113, 0.03, 1.5), (0.9, 0.2, 0.5), 0.0075), ((-0.1, -0.03, 1.51), (-0.7, -0.2, 0.6), 0.0085),
                    ((0.098, 0.128, 1.42), (0.6, 0.6, 0.2), 0.0052), ((0.086, 0.14, 1.438), (0.6, 0.6, 0.2), 0.0042)):
        barnacle(h, c, n, r)
    return h


def eyes(J):
    """The glowing eyes: blank, pale almonds tucked under the lids."""
    return [((s * 0.056, 0.139, 1.449), 0.02) for s in (-1, 1)]


# ------------------------------------------------------------------ what he wears
def onsurf(fld, pts, off=0.0):
    """Points dropped onto a field's surface, standing `off` proud of it."""
    p = fld.project(np.array(pts, np.float32), 4)
    return p + fld.grad(p) * off


def ring_at(fld, z, n=40, rmax=0.7, off=0.01, zf=None):
    """A closed loop hugging the surface at height z (zf(angle) bends it)."""
    pts = []
    for i in range(n + 1):
        a = i / n * math.tau
        zz = z + (zf(a) if zf else 0.0)
        r = rmax
        for _ in range(60):
            q = np.array([[math.sin(a) * r, math.cos(a) * r, zz]], np.float32)
            if float(fld.sample(q)[0]) < off:
                break
            r -= 0.012
        pts.append((math.sin(a) * r, math.cos(a) * r, zz))
    return np.array(pts, np.float32)


def tear(x, y, z, big=0.05, fine=0.018):
    """A ragged hem: long rips plus small nicks."""
    return (fbm(x, y, z, 9.0, 3) - 0.5) * big * 2.2 + (np.abs(vnoise(x, y, z, 42.0) - 0.5) - 0.2) * fine * 3


def mantle(J, skin):
    """The sailcloth mantle over both shoulders and the upper back, fur along its outer rim. Hangs in two torn panels
    in front, open down the chest; behind it stops below the shoulder blades, so the kelp and barnacles show under it."""
    f = skin.like()
    x, y, z = f.grid()
    fold = (fbm(x, y * 0.6, z * 0.35, 9.0, 3) - 0.5) * 0.03
    sh = np.abs(skin.d - 0.022 - fold) - 0.0085
    ax = np.abs(x)
    fr = smooth(-0.14, 0.14, y)                  # 1 in front, 0 behind
    # the hem's height: in front it falls from the shoulder's outside down a long panel, then climbs to the V of the
    # neck; behind it is a straight tattered line under the shoulder blades
    panel = 0.86 + 0.48 * smooth(0.26, 0.09, ax) ** 1.3 + 0.24 * smooth(0.34, 0.5, ax)
    back = 0.98 + 0.13 * smooth(0.36, 0.52, ax)
    hem = panel * fr + back * (1 - fr) + tear(x, y, z, 0.06, 0.024)
    keep = z - hem
    # off the arm: stops round the deltoid; off the neck
    keep = np.minimum(keep, 0.53 - ax + (fbm(x, y, z, 11.0, 2) - 0.5) * 0.05)
    # off the neck and clear of the head and beard: the collar opens wide in front
    neck = np.sqrt(x * x + (y - 0.05) ** 2 * 0.55) - (0.175 + 0.03 * smooth(1.26, 1.34, z))
    keep = np.minimum(keep, 1.33 - z)
    keep = np.minimum(keep, neck)
    f.d = np.maximum(sh, -keep).astype(np.float32)
    f.lab[:] = 1
    # fur on the rim round the shoulders and across the back: a shaggy roll
    fx = f.like()
    band = np.abs(z - (hem + 0.03)) - 0.042
    outer = smooth(0.25, 0.43, ax) * fr + (1 - fr)
    shag = (vnoise(x * 2.2, y * 2.2, z * 0.5, 26.0) - 0.5) * 0.05
    fd = np.maximum(np.abs(skin.d - 0.03 - fold) - 0.021 + shag, band + (fbm(x, y, z, 16.0, 2) - 0.5) * 0.05)
    fd = np.maximum(fd, 0.5 - outer * 1.0)
    fd = np.maximum(fd, -keep - 0.035)
    fx.d = fd.astype(np.float32)
    fx.lab[:] = 2
    f.d = np.minimum(f.d, fx.d)
    f.lab = np.where(fx.d < 0.002, np.uint8(2), f.lab)
    return f


def shorts(J, skin):
    """Tattered sea-trousers: cloth over the thighs, torn off round the knee."""
    f = skin.like()
    x, y, z = f.grid()
    sh = np.abs(skin.d - 0.012 - (fbm(x, y, z * 0.5, 12.0, 2) - 0.5) * 0.02) - 0.008
    hem = 0.235 + tear(x, y, z, 0.05, 0.03)
    f.d = np.maximum(np.maximum(sh, hem - z), z - 0.72).astype(np.float32)
    f.d = np.maximum(f.d, np.abs(x) - 0.42)
    f.lab[:] = 1
    return f


def rags(J, skin):
    """The hanging rags at the waist: a front apron and a back one, each a curved torn sheet off the belt."""
    lo, hi = (-0.5, -0.5, 0.15), (0.5, 0.5, 0.74)
    out = {}
    for nm, ang, half, low in (("front", 0.0, 0.8, 0.26), ("back", math.pi, 0.95, 0.3)):
        f = Field(lo, hi, 0.0045)
        x, y, z = f.grid()
        a = np.arctan2(x, y if nm == "front" else -y)
        r = np.sqrt(x * x + y * y)
        fold = (fbm(x, y, z * 0.3, 8.0, 2) - 0.5) * 0.05
        rz = 0.3 + (0.71 - z) * 0.2 + 0.07 * (nm == "front")
        sh = np.abs(r - rz - fold) - 0.007
        hem = low + tear(x, y, z, 0.075, 0.03) + 0.1 * (np.abs(a) / half) ** 2
        d = np.maximum(np.maximum(sh, hem - z), np.abs(a) - half + (fbm(x, y, z, 9.0, 2) - 0.5) * 0.25)
        d = np.maximum(d, z - 0.7)
        f.d = d.astype(np.float32)
        f.lab[:] = 1
        out[nm] = f
    return out


def braid_path(top, tip, lobes, ph, amp):
    """One strand of a three-strand plait from top to tip."""
    top, tip = np.array(top, np.float32), np.array(tip, np.float32)
    pts = []
    n = lobes * 6
    for i in range(n + 1):
        t = i / n
        c = top + (tip - top) * t
        c = c + np.array((math.sin(t * lobes * math.tau + ph), 0, 0), np.float32) * amp * (1.0 - 0.45 * t)
        c = c + np.array((0, math.sin(t * lobes * math.tau * 2 + ph * 2), 0), np.float32) * amp * 0.45
        pts.append(c)
    return pts


def beard(J):
    """The red beard: whiskers down the jaw into three plaits (the centre the longest), silver rings, frozen tufts.
    Returns (field, the plaits as [(name, top, ring, tip)] for the spring chains)."""
    lo, hi = (-0.24, -0.04, 0.86), (0.24, 0.47, 1.52)
    f = Field(lo, hi, 0.0022)
    bn = "head"
    plaits = [("braidR", (0.105, 0.17, 1.285), (0.135, 0.345, 1.095), (0.138, 0.36, 1.015)),
              ("braidL", (-0.105, 0.17, 1.285), (-0.135, 0.345, 1.095), (-0.138, 0.36, 1.015)),
              ("braidC", (0.0, 0.215, 1.255), (0.0, 0.385, 0.985), (0.0, 0.405, 0.9))]
    # sideburns and the jaw's fringe
    streak = lambda x, y, z: (vnoise(x * 3.2, y * 3.2, z * 0.5, 34.0) - 0.5) * 0.012
    for s in (-1, 1):
        f.add(path(((s * 0.124, 0.03, 1.43), (s * 0.13, 0.06, 1.36), (s * 0.114, 0.12, 1.285)), (0.014, 0.024, 0.032)),
              0.03, 1, bn, streak)
        f.add(ell((s * 0.06, 0.165, 1.262), (0.06, 0.05, 0.038)), 0.03, 1, bn, streak)
    f.add(ell((0, 0.185, 1.25), (0.05, 0.05, 0.04)), 0.03, 1, bn, streak)
    rings = []
    for nm, top, ring, tip in plaits:
        c = nm.endswith("C")
        w = 0.062 if c else 0.048
        for i in range(3):
            st = braid_path(top, ring, 5 if c else 4, i * math.tau / 3, w * 0.5)
            rr = [w * 0.62 * (1 - 0.4 * j / (len(st) - 1)) for j in range(len(st))]
            f.add(path(st, rr), 0.006, 1, bn)
        # the tuft under the ring, flaring then coming to a frozen point
        t0, t1 = np.array(ring, np.float32), np.array(tip, np.float32)
        f.add(path((t0, t0 * 0.6 + t1 * 0.4, t1), (w * 0.36, w * 0.56, 0.004)), 0.006, 2, bn, streak)
        # a smaller split in the tuft
        for s in (-1, 1):
            e = t1 + np.array((s * w * 0.42, 0, 0.022), np.float32)
            f.add(path((t0 * 0.5 + t1 * 0.5, e), (w * 0.3, 0.003)), 0.006, 2, bn, streak)
        rings.append((t0.copy(), w * 0.6))
    return f, plaits, rings


def ice(J, skin, mantle_f):
    """Icicles: off the mantle's hem, the shoulders, the right forearm, as the art."""
    f = Field((-0.75, -0.42, 0.45), (0.75, 0.46, 1.42), 0.0028)
    rng = np.random.default_rng(11)
    sites = []
    # the mantle's hem, front and back
    for x in (-0.44, -0.36, -0.28, -0.2, 0.2, 0.26, 0.34, 0.42):
        sites.append((x, 0.24, 0.98, 0.012, 0.13))
    for x in (-0.4, -0.27, -0.13, 0.0, 0.14, 0.25, 0.38):
        sites.append((x, -0.33, 1.02, 0.012, 0.12))
    sn = []
    for x, y, zt, r, l in sites:
        # (walk down from the shoulder until the mantle ends)
        z0 = None
        for z in np.arange(1.3, 0.75, -0.012):
            for yy in np.arange(y + 0.16 * (1 if y > 0 else -1), 0.0, -0.02 * (1 if y > 0 else -1)):
                q = np.array([[x, yy, z]], np.float32)
                if float(mantle_f.sample(q)[0]) < 0.0:
                    z0 = (x, yy, z)
                    break
        if z0 is not None:
            sn.append(z0)
    for a in sn:
        l = float(rng.uniform(0.07, 0.15))
        r = float(rng.uniform(0.009, 0.015))
        b = (a[0] + float(rng.uniform(-0.01, 0.01)), a[1], a[2] - l)
        f.add(icicle((a[0], a[1], a[2] + 0.015), b, r), 0.004, 1, "hips")
    # the forearm that holds the hammer in the art: drips off the elbow and wrist
    for s in (-1, 1):
        n = "R" if s > 0 else "L"
        for dx, dy, z, l in ((0.1, -0.1, 0.73, 0.1), (0.13, -0.05, 0.7, 0.14), (0.14, 0.02, 0.69, 0.1), (0.11, 0.07, 0.71, 0.07)):
            a = (s * (float(J["forearm.R"][0]) + dx), dy, z)
            f.add(icicle(a, (a[0] + 0.004 * s, a[1], z - l), 0.012), 0.004, 1, "forearm." + n)
        # shoulder spikes
        for dx, dy, h in ((0.33, -0.08, 0.1), (0.27, -0.13, 0.12), (0.4, -0.05, 0.07)):
            a = (s * dx, dy, 1.24 if dx < 0.3 else 1.2)
            f.add(icicle(a, (a[0] + s * 0.03, a[1] - 0.03, a[2] + h), 0.018), 0.004, 1, "pauldron." + n)
    return f


def kelp(J, skin):
    """Frozen kelp straps: on the shoulders and hanging down the back."""
    f = Field((-0.62, -0.42, 0.75), (0.62, 0.3, 1.5), 0.003)
    strands = [((0.42, 0.0, 1.27), (0.5, 0.02, 1.38), 0.016), ((0.37, -0.05, 1.28), (0.34, -0.09, 1.42), 0.015),
               ((-0.43, -0.02, 1.27), (-0.55, -0.02, 1.34), 0.015), ((-0.34, -0.06, 1.29), (-0.42, -0.1, 1.42), 0.014)]
    for a, b, r in strands:
        a, b = np.array(a, np.float32), np.array(b, np.float32)
        pts = [a + (b - a) * t + np.array((0.018 * math.sin(t * 7), 0.012 * math.cos(t * 6), 0), np.float32) for t in np.linspace(0, 1, 7)]
        f.add(path(pts, [r * (1 - 0.8 * t) for t in np.linspace(0, 1, 7)]), 0.002, 1, "pauldron.R" if a[0] > 0 else "pauldron.L")
    for x, top, l in ((-0.07, 1.04, 0.2), (0.17, 1.03, 0.16)):
        pts = onsurf(skin, [(x + 0.02 * math.sin(t * 7), -0.34, top - l * t) for t in np.linspace(0, 1, 8)], 0.006)
        f.add(path(pts, [0.018 * (1 - 0.7 * t) for t in np.linspace(0, 1, 8)]), 0.002, 1, "hips")
    return f


def teddy(at):
    """The teddy bear trinket, stitched and worn (at: where its head's rope ties on; it hangs below)."""
    a = np.array(at, np.float32)
    f = Field(a + (-0.09, -0.08, -0.2), a + (0.09, 0.08, 0.02), 0.0016)
    O = lambda x, y, z: a + np.array((x, y, z), np.float32)
    bn = "spring_teddy_0"
    f.add(sph(O(0, 0, -0.04), 0.036), 0.0, 1, bn)                     # the head
    f.add(ell(O(0, 0.03, -0.047), (0.017, 0.016, 0.013)), 0.008, 2, bn)   # the muzzle
    f.add(sph(O(0, 0.046, -0.044), 0.0052), 0.001, 3, bn)              # the nose
    for s in (-1, 1):
        f.add(sph(O(s * 0.033, 0, -0.012), 0.015), 0.005, 1, bn)        # ears
        f.add(sph(O(s * 0.016, 0.031, -0.029), 0.0042), 0.001, 3, bn)   # bead eyes
        f.add(path((O(s * 0.024, 0, -0.09), O(s * 0.054, 0.012, -0.115)), (0.016, 0.013)), 0.006, 1, bn)   # arms
        f.add(path((O(s * 0.02, 0, -0.14), O(s * 0.032, 0.022, -0.168)), (0.019, 0.017)), 0.006, 1, bn)    # legs
    f.add(ell(O(0, 0, -0.11), (0.033, 0.03, 0.043)), 0.012, 1, bn)      # the body
    return f


def compass(c, n):
    """The brass ship's compass, on the mantle: a case, a rim and a loop; the rose is painted."""
    c, n = np.array(c, np.float32), np.array(n, np.float32)
    n = n / np.linalg.norm(n)
    f = Field(c - 0.075, c + 0.075, 0.0014)
    f.add(cap(c - n * 0.012, c + n * 0.004, 0.056, 0.055), 0.002, 1, "pauldron.L")
    f.add(cap(c + n * 0.006, c + n * 0.011, 0.058, 0.056), 0.002, 1, "pauldron.L")
    f.sub(cap(c + n * 0.009, c + n * 0.03, 0.045, 0.045), 0.002, 2)
    up = np.array((0, 0, 1), np.float32)
    f.add(sph(c + up * 0.064, 0.012), 0.002, 1, "pauldron.L")
    return f


def hammer():
    """The hammer, upright with its grip on the origin (haft along +Z, the block's middle at z = 0.62, as BjornFx
    finds the head): a plain block of glacier ice, two riveted iron bands, an iron socket, a rope-wrapped oak haft,
    an iron end cap, icicles. Returns (ice field, iron field, wood field)."""
    lo, hi = (-0.42, -0.26, -0.62), (0.42, 0.26, 0.98)
    BW, BD, BH = 0.29, 0.175, 0.17     # half width (along the swing's sides), half depth, half height
    zc = 0.62
    I = Field(lo, hi, 0.0035)
    lump = lambda x, y, z: (fbm(x, y, z, 6.0, 3) - 0.5) * 0.028
    I.add(box((0, 0, zc), (BW, BD, BH), 0.03), 0.0, 1, "x_weapon", lump)
    rng = np.random.default_rng(5)
    for x in (-0.26, -0.18, -0.08, 0.05, 0.13, 0.26):
        l = float(rng.uniform(0.05, 0.13))
        for y in (0.14, -0.14):
            xx = x + float(rng.uniform(-0.02, 0.02))
            I.add(icicle((xx, y, zc - BH + 0.01), (xx, y, zc - BH - l), 0.016), 0.006, 2, "x_weapon")
    I.add(box((0, 0, zc + BH + 0.002), (BW - 0.03, BD - 0.02, 0.016), 0.012), 0.02, 3, "x_weapon",
          lambda x, y, z: (fbm(x, y, z, 11.0, 2) - 0.55) * 0.03)     # the snow on top
    M = Field(lo, hi, 0.0035)
    for x in (-0.15, 0.15):
        M.add(box((x, 0, zc), (0.046, BD + 0.014, BH + 0.014), 0.012), 0.0, 1, "x_weapon",
              lambda x, y, z: (fbm(x, y, z, 14.0, 2) - 0.5) * 0.008)
        for y, z in ((BD + 0.015, 0.09), (BD + 0.015, 0.0), (BD + 0.015, -0.09), (-BD - 0.015, 0.09), (-BD - 0.015, 0.0), (-BD - 0.015, -0.09)):
            M.add(sph((x, y, zc + z), 0.0145), 0.002, 2, "x_weapon")
        for y in (-0.09, 0.0, 0.09):
            M.add(sph((x, y, zc + BH + 0.015), 0.0145), 0.002, 2, "x_weapon")
    M.add(cap((0, 0, zc - BH - 0.075), (0, 0, zc - BH + 0.02), 0.055, 0.065), 0.003, 1, "x_weapon")   # the socket
    M.add(cap((0, 0, -0.46), (0, 0, -0.39), 0.058, 0.056), 0.004, 1, "x_weapon")                     # the end cap
    M.add(cyl((0, 0, -0.5), "z", 0.066, 0.045), 0.006, 1, "x_weapon")
    W = Field(lo, hi, 0.0035)
    gnarl = lambda x, y, z: (fbm(x * 1.2, y * 1.2, z * 0.2, 16.0, 2) - 0.5) * 0.012
    W.add(cap((0, 0, -0.45), (0, 0, zc - BH), 0.038, 0.043), 0.0, 1, "x_weapon", gnarl)
    for z0, z1, turns in ((-0.2, -0.04, 4.0), (0.19, 0.32, 3.0)):
        ts = np.linspace(0, 1, int(turns * 14))
        W.add(path([(0.043 * math.cos(t * turns * math.tau), 0.043 * math.sin(t * turns * math.tau), z0 + (z1 - z0) * t) for t in ts], [0.0115] * len(ts)), 0.003, 2, None)
    return I, M, W, zc


def shield():
    """The prow shield, flat against the left forearm: drawn in its own frame, face toward -Y, up +Z, grip at the
    origin. A pointed heater of oak planks, an iron rim with rivets, the top planks broken off, the bearded
    figurehead carved flat in relief, icicles off the foot and rim; a rope grip and strap behind."""
    lo, hi = (-0.34, -0.16, -0.74), (0.34, 0.1, 0.62)
    W = Field(lo, hi, 0.0032)

    def outline(x, z):
        """Negative inside the shield's face: a heater's sides, coming to the keel's point at the foot."""
        side = np.abs(x) - (0.275 - 0.03 * smooth(0.1, 0.3, z) - 0.23 * smooth(-0.1, -0.56, z) ** 1.35)
        return np.maximum(side, np.maximum(z - 0.3, -0.56 - z))
    x, y, z = W.grid()
    bow = 0.05 * (x / 0.28) ** 2                # the face bellies out
    plate = np.abs(y + 0.01 - bow) - 0.018
    W.d = np.maximum(plate, outline(x, z)).astype(np.float32)
    W.lab[:] = 1
    # the planks standing broken above the rim
    for px, top, w in ((-0.2, 0.42, 0.058), (-0.1, 0.5, 0.05), (0.0, 0.47, 0.055), (0.09, 0.55, 0.045), (0.19, 0.44, 0.052)):
        pts = ((px, -0.0, 0.26), (px + 0.008, -0.0, top - 0.03), (px + 0.018, -0.0, top + 0.03))
        W.add(path(pts, (w, w * 0.9, 0.004)), 0.0, 1, None)
    W.d = np.maximum(W.d, np.abs(W.grid()[1] + 0.01 - bow) - 0.019)
    # the figurehead: a long-haired bearded face in low relief (never past the rim)
    R = lambda p, k=0.015: W.add(p, k, 2, None)
    fz = 0.055
    R(ell((0, -0.03, fz + 0.05), (0.082, 0.04, 0.1)), 0.02)                      # the head
    for s in (-1, 1):
        R(ell((s * 0.085, -0.02, fz + 0.04), (0.04, 0.03, 0.13)), 0.02)           # the hair
        R(cap((s * 0.09, -0.018, fz - 0.05), (s * 0.06, -0.018, fz - 0.2), 0.04, 0.018), 0.02)
        W.sub(ell((s * 0.033, -0.065, fz + 0.062), (0.021, 0.014, 0.0105)), 0.008, 2)     # the eye
        R(cap((s * 0.006, -0.063, fz + 0.09), (s * 0.058, -0.052, fz + 0.1), 0.012, 0.008), 0.012)   # the brow
    R(cap((0, -0.07, fz + 0.09), (0, -0.082, fz + 0.03), 0.012, 0.019), 0.012)    # the nose
    R(ell((0, -0.05, fz - 0.1), (0.07, 0.04, 0.13)), 0.02)                        # the beard
    R(cap((0, -0.05, fz - 0.18), (0, -0.03, fz - 0.33), 0.05, 0.012), 0.02)
    for s in (-1, 1):
        R(cap((s * 0.01, -0.07, fz + 0.012), (s * 0.05, -0.058, fz - 0.03), 0.009, 0.006), 0.008)   # the moustache
    # the beard's carved locks
    bx = W.grid()
    W.d = W.d + np.where(W.lab == 2, np.sin((bx[0] * 95.0 + np.sin(bx[2] * 22.0) * 1.2)) * 0.0028, 0.0).astype(np.float32)
    M = Field(lo, hi, 0.0032)
    rim = np.abs(outline(x, z) + 0.024) - 0.03
    M.d = np.maximum(rim, np.abs(y + 0.018 - bow) - 0.034).astype(np.float32)
    M.lab[:] = 1
    # rivets along the rim
    pts = []
    for zz in np.arange(-0.46, 0.29, 0.09):
        for sd in (-1, 1):
            q = np.arange(0.33, 0.0, -0.004)
            xx = q[np.argmax(outline(q, np.full(q.shape, zz, np.float32)) < -0.022)]
            pts.append((sd * float(xx), zz))
    for xx in np.arange(-0.2, 0.21, 0.1):
        pts.append((float(xx), 0.274))
    for px, pz in pts:
        M.add(sph((px, -0.052 + 0.05 * (px / 0.28) ** 2, pz), 0.0125), 0.002, 2, None)
    # the back: a rope grip and a riveted strap
    M.add(box((0, 0.03, 0.12), (0.2, 0.012, 0.022), 0.006), 0.0, 3, None)
    I = Field((-0.34, -0.16, -0.95), (0.34, 0.1, 0.34), 0.003)
    rng = np.random.default_rng(3)
    for xx, zz, l in ((-0.03, -0.54, 0.2), (0.03, -0.54, 0.26), (0.08, -0.46, 0.16), (-0.09, -0.45, 0.14), (0.15, -0.34, 0.13),
                      (-0.16, -0.32, 0.1)):
        I.add(icicle((xx, -0.01, zz), (xx * 1.05, -0.01, zz - l), 0.02), 0.004, 1, None)
    for xx in (-0.19, -0.13, 0.15, 0.2):
        l = float(rng.uniform(0.05, 0.1))
        I.add(icicle((xx, -0.03, 0.245), (xx, -0.04, 0.245 - l), 0.012), 0.003, 1, None)
    return W, M, I


def brows(hd):
    """The brows: fat red strokes on the ridge, on their own bones."""
    f = Field((-0.15, 0.04, 1.44), (0.15, 0.19, 1.54), 0.0014)
    streak = lambda x, y, z: (vnoise(x * 0.5, y, z * 3.2, 170.0) - 0.5) * 0.007
    for s in (-1, 1):
        pts = [(s * 0.016, 0.16, 1.469), (s * 0.045, 0.16, 1.487), (s * 0.075, 0.15, 1.493), (s * 0.1, 0.125, 1.482), (s * 0.116, 0.1, 1.462)]
        pts = onsurf(hd, pts, 0.003)
        f.add(path(pts, (0.0085, 0.0125, 0.0115, 0.009, 0.003)), 0.004, 1, None, streak)
    return f
