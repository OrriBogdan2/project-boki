"""A species whose body is a Meshy scan of the owner's sheet, on the rig it already has. The species' modules stay
as they are: their primitives become the proxy the skin weights read, their bones, props and grown parts move to the
scan through a Fit (landmark pairs measured off the fit sheet), and the scan's own surface, colour and normals become
the body. SCANS holds what a species needs; docs/art/kin/MESHY_BOKI_RECIPE.md is how to fill a row."""

import math
import os
import re

import numpy as np

from boki_meshy import Meshy, MeshShape
from boki_sdf import Cone, Shape, frame, v3

ROOT = os.path.expanduser("~/meshy/boki")  # <ROOT>/<id>/run1: the raw Meshy files, never in git
LUM = np.array([0.3, 0.59, 0.11])
BROW_DARK = 0.55  # a brow is its patch of coat, darker
# id: "height" (game m, before SCALE) and "tris" of the body; "x", "y", "z": (proxy, scan) landmark pairs, x for the
# right side only; "merge": proxy bones whose part the scan has fused into another bone's; "drop": proxy pieces the
# scan has no shape for; "eye_c", "eye_r", "eye_yaw", "face": the Boki face on the scan's head; "sat", "gain": the
# texture's grade; "lid", "brow": hex colours, when the scan's own beside its eyes are wrong for them; "cover": eye
# radii round each Boki eye inside which the scan's own painted eye is painted out (when it shows beside); "sink": how
# far the scan stands above its lowest point (a hanging tail), and "pose": the bones (game-axis euler) that lift such
# a part into the rest pose;
# "limbs": (bone, from, to, radius from, radius to) in scan space, for a part the fit cannot follow (a tail that hangs
# another way): the bone lies along it and the capsule replaces the bone's proxy primitives (".L" also makes ".R");
# "at": {grown part: where its attach point goes on the scan}, when the fit puts it wrong (tools and grown parts move
# whole, never squashed).
SCANS = {
    "kestrike": {
        "height": 0.725,
        "sink": 0.105,
        "tris": 16000,
        "x": [(0.07, 0.09)],
        "y": [(0.0, 0.0), (0.12, 0.076), (0.2, 0.21), (0.43, 0.35), (0.6, 0.527), (0.74, 0.62)],
        "z": [(-0.27, -0.304), (-0.06, -0.152), (0.045, -0.10), (0.15, 0.023), (0.36, 0.29)],
        "merge": {
            "wing1.L": "spine",
            "wing1.R": "spine",
            "wing2.L": "spine",
            "wing2.R": "spine",
            "ear1.L": "head",
            "ear1.R": "head",
            "tfan": "tail2",
        },
        "drop": ("spark",),
        "pose": {"tail1": (-0.6, 0.0, 0.0)},
        "limbs": [
            ("tail1", (0, 0.11, 0.03), (0, 0.03, 0.13), 0.04, 0.07),
            ("tail2", (0, 0.03, 0.13), (0, -0.06, 0.24), 0.07, 0.09),
        ],
        "eye_c": (0.068, 0.433, -0.225),
        "eye_r": (0.037, 0.037, 0.02),
        "eye_yaw": 0.35,
        "face": {},
        "sat": 0.6,
    },
    "cairnback": {
        "height": 0.85,
        "tris": 16000,
        "x": [(0.165, 0.152)],
        "y": [(0.0, 0.0), (0.09, 0.085), (0.21, 0.206), (0.31, 0.262), (0.40, 0.29), (0.66, 0.85)],
        "z": [(-0.45, -0.285), (-0.28, -0.243), (-0.12, -0.176), (0.22, 0.067), (0.3, 0.158), (0.395, 0.273)],
        "merge": {"horn.L": "head", "horn.R": "head", "ear1.L": "head", "ear1.R": "head"},
        "eye_c": (0.045, 0.282, -0.24),
        "eye_r": (0.02, 0.02, 0.012),
        "eye_yaw": 0.6,
        "face": {},
        "sat": 0.8,
        "gain": 1.15,
    },
    "gibbelle": {
        "height": 0.55,
        "tris": 16000,
        "x": [(0.2, 0.2)],
        "y": [(0.0, 0.0), (0.19, 0.31), (0.255, 0.38), (0.44, 0.55)],
        "z": [(-0.24, -0.17), (0.0, 0.0), (0.25, 0.178)],
        "drop": ("puffs",),
        "merge": {"lobe%d" % i: "root" for i in range(7)},
        "eye_c": (0.057, 0.38, -0.135),
        "eye_r": (0.041, 0.042, 0.022),
        "eye_yaw": 0.3,
        "face": {},
        "sat": 0.8,
        "cover": 1.2,
    },
    "goliathite": {
        "height": 0.7,
        "tris": 16000,
        "x": [(0.2, 0.2)],
        "y": [(0.0, 0.0), (0.44, 0.7)],
        "z": [(-0.25, -0.46), (0.25, 0.46)],
        "drop": ("puffs",),
        "merge": {"lobe%d" % i: "root" for i in range(7)},
        "eye_c": (0.081, 0.505, -0.4),
        "eye_r": (0.04, 0.052, 0.024),
        "eye_yaw": 0.3,
        "face": {},
        "sat": 0.8,
        "cover": 1.15,
    },
    "hoarheron": {
        "height": 0.65,
        "tris": 16000,
        "x": [(0.2, 0.17)],
        "y": [(0.0, 0.0), (0.44, 0.65)],
        "z": [(-0.25, -0.5), (0.25, 0.5)],
        "drop": ("puffs",),
        "merge": {"lobe%d" % i: "root" for i in range(7)},
        "eye_c": (0.05, 0.357, -0.372),
        "eye_r": (0.022, 0.022, 0.011),
        "eye_yaw": 0.9,
        "face": {},
        "sat": 0.8,
        "cover": 1.2,
    },
    "floenatee": {
        "height": 0.7,
        "tris": 16000,
        "x": [(0.2, 0.2)],
        "y": [(0.0, 0.0), (0.26, 0.58), (0.44, 0.7)],
        "z": [(-0.22, -0.42), (0.0, 0.0), (0.28, 0.5)],
        "drop": ("puffs",),
        "merge": {"lobe%d" % i: "root" for i in range(7)},
        "eye_c": (0.05, 0.635, -0.455),
        "eye_r": (0.022, 0.022, 0.011),
        "eye_yaw": 0.35,
        "face": {"mouth_y": 0.585, "mouth_z": -0.515},
        "sat": 0.8,
        "cover": 1.6,
    },
}


def grade(col, sat, gain):
    """sRGB colours pulled toward their own grey (in linear light, as the toon shader's `desat` does) and scaled:
    the game's warm light and tonemap push a painted texture's mid colours to pure hues."""
    lin = np.where(col <= 0.04045, col / 12.92, ((col + 0.055) / 1.055) ** 2.4)
    lum = (lin @ LUM)[:, None]
    lin = np.clip((lum + (lin - lum) * sat) * gain, 0, 1)
    return np.where(lin <= 0.0031308, lin * 12.92, 1.055 * lin ** (1 / 2.4) - 0.055)


def piecewise(x, a, b):
    """x through the line segments from knots `a` to `b`, the end segments running on."""
    i = np.clip(np.searchsorted(a, x) - 1, 0, len(a) - 2)
    return b[i] + (x - a[i]) * (b[i + 1] - b[i]) / (a[i + 1] - a[i])


class Fit:
    """Proxy space to scan space and back: each axis piecewise linear through its landmark pairs."""

    def __init__(self, x, y, z):
        mirrored = [(-a, -b) for a, b in x] + [(0.0, 0.0)] + list(x)
        self.knots = [np.array(sorted(pairs), float).T for pairs in (mirrored, y, z)]

    def _through(self, p, src, dst):
        q = np.asarray(p, float)
        return np.stack([piecewise(q[..., i], k[src], k[dst]) for i, k in enumerate(self.knots)], -1)

    def fwd(self, p):
        return self._through(p, 0, 1)

    def back(self, p):
        return self._through(p, 1, 0)


class Fitted:
    """A proxy primitive as the scan's space sees it."""

    def __init__(self, prim, fit, bone=None):
        self.prim, self.fit = prim, fit
        self.name, self.bone, self.k, self.sub = prim.name, bone or prim.bone, prim.k, prim.sub
        box = fit.fwd(np.stack([prim.lo, prim.hi]))
        self.lo, self.hi = box.min(0), box.max(0)

    def d(self, p):
        return self.prim.d(self.fit.back(p))


class Moved:
    """A proxy primitive carried whole to its place on the scan (a tool, a grown part): the fit would squash it."""

    def __init__(self, prim, offset):
        self.prim, self.offset = prim, offset
        self.name, self.bone, self.k, self.sub = prim.name, prim.bone, prim.k, prim.sub
        self.lo, self.hi = prim.lo + offset, prim.hi + offset

    def d(self, p):
        return self.prim.d(p - self.offset)


class Scan:
    """Stands in for a species' creature, paint and anim modules (build_boki.use_species): what it does not
    override is theirs."""

    def __init__(self, species, creature, paint, anim):
        s = SCANS[species]
        self._mods, self._s = (creature, paint, anim), s
        self.fit = Fit(s["x"], s["y"], s["z"])
        self.model = Meshy.get(os.path.join(ROOT, species, "run1"), s["height"], s.get("sink", 0.0))
        self.REST_POSE = s.get("pose", {})
        self.EYE_C, self.EYE_R = v3(*s["eye_c"]), v3(*s["eye_r"])
        face = creature.FACE
        mouth = self.fit.fwd(v3(face["brow_x"], face["mouth_y"], face["mouth_z"]))
        self.FACE = {**face, "brow_x": mouth[0], "mouth_y": mouth[1], "mouth_z": mouth[2], **s["face"]}  # the row wins
        self.BONES = {
            name: (self.fit.fwd(head), self.fit.fwd(tail), parent) for name, (head, tail, parent) in anim.BONES.items()
        }
        self._limbs = []
        for bone, a, b, ra, rb in s.get("limbs", ()):
            for name, sx in ((bone, 1.0), (bone[:-1] + "R", -1.0))[: 2 if bone.endswith(".L") else 1]:
                cone = Cone("limb_" + name, name, v3(*a) * (sx, 1, 1), v3(*b) * (sx, 1, 1), ra, rb)
                self.BONES[name] = (cone.a, cone.b, self.BONES[name][2])
                self._limbs.append(cone)
        self.LID = paint.hexc(s["lid"]) if "lid" in s else self._around_eyes(1.6, 0.0)
        self.LILAC = paint.hexc(s["brow"]) if "brow" in s else self._around_eyes(1.0, 2.4) * BROW_DARK
        deep = self._deepest()
        self.HIDE_AT = {name: tuple(deep - bone[0]) for name, bone in self.BONES.items() if name.startswith("prop_")}
        self._proxy = {p.name: p for p in creature.parts()["body"][0].prims}

    def __getattr__(self, name):
        for mod in self._mods:
            if hasattr(mod, name):
                return getattr(mod, name)
        raise AttributeError(name)

    def _around_eyes(self, ring, lift):
        """The scan's own graded colour beside its eyes (the median of a ring `ring` eye radii wide, `lift` radii
        up): what the lids and brows take, so the face belongs to this coat and not to the proxy's."""
        pts = []
        for sx in (1.0, -1.0):
            right, up, _ = self.eye_frame(sx)
            centre = self.EYE_C * (sx, 1, 1) + up * self.EYE_R[1] * lift
            pts += [
                centre + (right * math.cos(a) * self.EYE_R[0] + up * math.sin(a) * self.EYE_R[1]) * ring
                for a in np.linspace(0, math.tau, 12, endpoint=False)
            ]
        col = grade(self.model.colour(np.array(pts)), self._s.get("sat", 1.0), self._s.get("gain", 1.0))
        return np.median(col, 0)

    def _deepest(self):
        """The point furthest inside the scan: an unused tool collapses there, so its ink shell never shows."""
        lo, hi = self.model.v.min(0), self.model.v.max(0)
        axes = [np.linspace(a, b, 9)[1:-1] for a, b in zip(lo, hi)]
        grid = np.stack(np.meshgrid(*axes, indexing="ij"), -1).reshape(-1, 3)
        loc, nor, _ = self.model.nearest(grid)
        d = grid - loc
        return grid[np.argmax(np.linalg.norm(d, axis=1) * np.where((d * nor).sum(1) < 0, 1.0, -1.0))]

    def eye_frame(self, sx):
        yaw = self._s["eye_yaw"]
        fr = frame(v3(sx * math.sin(yaw), 0.1, -math.cos(yaw)), v3(0, 1, 0))
        if (fr[0] @ v3(sx, 0, 0)) < 0:
            fr[0] = -fr[0]
        return fr

    def _fitted(self, prims):
        merge = self._s.get("merge", {})
        return [Fitted(p, self.fit, merge.get(p.bone)) for p in prims]

    def parts(self):
        drop = self._s.get("drop", ())
        prims = [
            p for name, part in self._mods[0].parts().items() if name not in drop for p in part[0].prims if not p.sub
        ]
        own = {cone.bone for cone in self._limbs}
        prims = [p for p in self._fitted(prims) if p.bone not in own] + self._limbs
        return {"body": (MeshShape(prims, self.model), 0.0035, self._s["tris"])}

    def _moved(self, prims, anchor=None, to=None):
        """`prims` carried as one rigid group: `anchor` (their box centre unless given) goes through the fit, or to
        `to`; their shape does not change."""
        if anchor is None:
            anchor = (np.min([p.lo for p in prims], 0) + np.max([p.hi for p in prims], 0)) / 2
        offset = (self.fit.fwd(anchor) if to is None else v3(*to)) - anchor
        return [Moved(p, offset) for p in prims], offset

    def prop_parts(self):
        return {
            name: (Shape(self._moved(shape.prims)[0]), h, tris)
            for name, (shape, h, tris) in self._mods[0].prop_parts().items()
        }

    def grown_parts(self):
        out = {}
        for pid, (parent, head, look, tris, prims) in self._mods[0].grown_parts().items():
            moved, offset = self._moved(prims, head, self._s.get("at", {}).get(pid))
            out[pid] = (parent, None if head is None else head + offset, look, tris, moved)
        return out

    def paint_piece(self, pc, q, nn, _prim):
        if pc.name != "body":
            return self._mods[1].paint_piece(pc, self.fit.back(q), nn, self._proxy)
        return grade(self.model.colour(self._off_eyes(q)), self._s.get("sat", 1.0), self._s.get("gain", 1.0))

    def _off_eyes(self, q):
        """`q` with the points under a Boki eye moved out to the ring "cover" eye radii round it (met from the front,
        as a bulging eyeball is nearer than the coat beside it): the scan's own painted eye takes the coat around it
        there, so it cannot show beside the eye that covers it."""
        cover = self._s.get("cover", 0.0)
        q = np.array(q, float)
        reach = 2 * self.EYE_R[0]
        for sx in (1.0, -1.0) if cover else ():
            right, up, out = self.eye_frame(sx)
            d = q - self.EYE_C * (sx, 1, 1)
            flat = right * (d @ right)[:, None] + up * (d @ up)[:, None]
            r = np.maximum(np.hypot(d @ right / self.EYE_R[0], d @ up / self.EYE_R[1]), 1e-6)
            under = np.flatnonzero((r < cover) & (np.abs(d @ out) < reach))
            for i, ring in zip(under, q[under] + flat[under] * (cover / r[under] - 1)[:, None]):
                hit = self.model.bvh.ray_cast((ring + out * reach).tolist(), (-out).tolist(), 2 * reach)[0]
                q[i] = ring if hit is None else hit
        return q


def frame_row(species, fit, scale):
    """The species' BokiRig.FRAME row (scripts/match/boki_rig.gd) moved through the fit, to paste back. A point on a
    "limbs" part (a tail tip) still needs reading off the sheet."""
    path = os.path.join(os.path.dirname(__file__), "..", "..", "scripts", "match", "boki_rig.gd")
    found = re.search(r'\t"%s": \{.*?\}\},\n' % species, open(path).read(), re.S)
    if not found:
        return "(no row yet: copy the proxy species' row under this id, then run this again)"
    row = found.group(0)

    def point(m):
        at = fit.fwd(v3(*map(float, m.group(1).split(","))) / scale) * scale
        return "Vector3(%s)" % ", ".join("%.3g" % c for c in at)

    def height(m):
        return '"%s": %.3g' % (m.group(1), fit.fwd(v3(0, float(m.group(2)) / scale, 0))[1] * scale)

    return re.sub(r'"(top|hip)": ([0-9.]+)', height, re.sub(r"Vector3\(([^)]*)\)", point, row))


def fit_sheet(model, bones, eye_c, px=900, span=0.9):
    """The scan from the side, the front and above (1 px = 1 mm at the defaults), a line every 0.1 m (0 the dark
    one; up is +y, the side view faces left), the fitted bones in red and the eye in green: what the landmark
    pairs are read from and checked on."""
    pick = np.random.default_rng(1).choice(len(model.t), min(len(model.t), 600000), replace=False)
    pos = model.v[model.t[pick]].mean(1)
    uv = model.tuv[pick].mean(1)
    texel = np.clip((uv % 1) * (len(model.tex) - 1), 0, len(model.tex) - 1).astype(int)
    col = model.tex[texel[:, 1], texel[:, 0]]
    views = (((2, 1), 0, 1.0), ((0, 1), 2, 1.0), ((0, 2), 1, 1.0))  # (across, up) axes, depth axis, its sign
    lo = {0: -span / 2, 1: -0.05, 2: -span / 2}
    sheet = np.full((px, px * len(views), 3), 0.82)

    def cell(view, p):
        (ax, ay), _, _ = views[view]
        x = (p[..., ax] - lo[ax]) / span * px
        y = (p[..., ay] - lo[ay]) / span * px
        return np.clip(x, 0, px - 1).astype(int) + view * px, np.clip(y, 0, px - 1).astype(int)

    for view, ((ax, ay), depth, sign) in enumerate(views):
        for g in np.arange(-0.4, 0.85, 0.1):
            for axis, across in ((ax, True), (ay, False)):
                at = int((g - lo[axis]) / span * px)
                if 0 <= at < px:
                    shade = 0.25 if abs(g) < 1e-6 else 0.66
                    if across:
                        sheet[:, view * px + at] = shade
                    else:
                        sheet[at, view * px : (view + 1) * px] = shade
        order = np.argsort(pos[:, depth] * sign)
        x, y = cell(view, pos[order])
        for dx, dy in ((0, 0), (1, 0), (0, 1), (1, 1)):
            sheet[np.minimum(y + dy, px - 1), np.minimum(x + dx, px * len(views) - 1)] = col[order]
        for head, tail, _ in bones.values():
            line = np.linspace(np.asarray(head, float), np.asarray(tail, float), 60)
            x, y = cell(view, line)
            sheet[y, x] = (1.0, 0.1, 0.1)
            sheet[y[:3], x[:3] + 1] = (1.0, 1.0, 0.2)
        for sx in (-1, 1):
            turn = np.linspace(0, 6.3, 40)
            ring = eye_c * (sx, 1, 1) + np.stack([np.cos(turn), np.sin(turn), turn * 0], -1) * 0.012
            x, y = cell(view, ring)
            sheet[y, x] = (0.1, 1.0, 0.2)
    return sheet
