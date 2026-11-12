"""Scripted parts for a fitted Warden (tools/meshy/fit_warden.py, docs/art/wardens/PIPELINE.md "Stage 1 props"),
in Blender 4.5. Pieces a Meshy scan can't give cleanly, or that must move on their own bones:

- wings(): see-through wings as alpha cards (the `card` slot, WardenGlb.CARD): one subdivided quad per wing,
  its outline, veins, eyespots and sheen painted into a small RGBA atlas here; each wing rides a chain of
  `spring_<name>_<i>` bones under the hips that the game swings (WardenGlb.Springs).
- crossbows(): Sable's twin hand crossbows (silver tiller and limbs, a dark grip, a violet string and a
  glowing bolt) as the `weapon` mesh in the Gun node's space, its twin `weapon_offhand` placed for the twin
  hold's left hand (HunterAnim HOLDS["twin"]: gr, gl).
- lantern(): Pip's hearth lantern (a copper cage, glowing panes, a bail) hanging from her right hand on a short
  spring chain, so it swings as she runs.
- spring_region(): body vertices in a box (a fluffy tail) re-skinned onto a spring chain along a path.
- gem(): a faceted glowing crystal (Sable's red pendant) set on the body's surface, riding a bone.

Frames: the body parts are in the fitted frame (Blender, +Z up, her front +Y, her right +X, soles on Z = 0); the
weapon in the Gun node's (forward +Y, up +Z, right +X).
"""
import math

import bpy
import numpy as np
from mathutils import Matrix, Vector

import warden_parts as WP

hexcol = WP.hexcol


def log(*a):
    print("WARDENPROPS", *a, flush=True)


def _mat(name, img, alpha=False, closest=False):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    bsdf = nt.nodes.get("Principled BSDF")
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = img
    if closest:
        tex.interpolation = "Closest"
    nt.links.new(tex.outputs[0], bsdf.inputs["Base Color"])
    if alpha:
        nt.links.new(tex.outputs[1], bsdf.inputs["Alpha"])
        m.blend_method = "BLEND" if hasattr(m, "blend_method") else m.blend_method
    bsdf.inputs["Roughness"].default_value = 0.8
    return m


def _skin(ob, arm, groups):
    """groups: {bone: [vertex indices]} (weight 1)."""
    for bone, vids in groups.items():
        g = ob.vertex_groups.get(bone) or ob.vertex_groups.new(name=bone)
        g.add([int(v) for v in vids], 1.0, "REPLACE")
    ob.parent = arm
    mod = ob.modifiers.new("Armature", "ARMATURE")
    mod.object = arm


# ------------------------------------------------------------------------------------------------ wings
def _wing_px(kind, w, h, L, W, look):
    """One wing's RGBA texels (h rows along the wing, root at row 0; w columns across)."""
    v = (np.arange(h)[:, None] + 0.5) / h * np.ones((1, w))          # 0 root .. 1 tip
    u = (np.arange(w)[None, :] + 0.5) / w * np.ones((h, 1))          # 0 .. 1 across
    x = (u - 0.5) * W                                                  # metres across
    y = v * L                                                          # metres along
    pw = float(look.get("power", 0.7))
    root_w = float(look.get("root_w", 0.12))
    shape = root_w + (1.0 - root_w) * np.sin(np.pi * np.clip(v, 0, 1) ** float(look.get("skew", 0.8))) ** pw
    half = 0.5 * W * shape * 0.97
    d = np.abs(x) / np.maximum(half, 1e-4)                             # 0 middle .. 1 outline
    inside = d < 1.0
    rgba = np.zeros((h, w, 4), np.float32)
    base = hexcol(look["base"])
    tint = [hexcol(c) for c in look.get("tints", [look["base"]])]
    # iridescent drift: the base leans toward each tint in turn across and along the wing
    ph = np.sin(v * 7.0 + u * 4.0) * 0.5 + 0.5
    ph2 = np.sin(v * 4.0 - u * 6.0 + 1.3) * 0.5 + 0.5
    col = base[None, None] * np.ones((h, w, 1))
    k = float(look.get("tint_k", 0.35))
    for i, tc in enumerate(tint):
        wgt = (ph if i % 2 == 0 else ph2)[..., None] * k / max(1, len(tint) / 2)
        col = col * (1 - wgt) + tc[None, None] * wgt
    a = np.full((h, w), float(look.get("alpha", 0.6)), np.float32)
    # a brighter, more solid band toward the outline, then the outline itself
    rim = np.clip((d - 0.78) / 0.16, 0, 1)
    col = col * (1 - rim[..., None] * 0.4) + hexcol(look.get("rim", look["base"]))[None, None] * rim[..., None] * 0.4
    a = a + (float(look.get("rim_alpha", 0.85)) - a) * rim
    edge = d > float(look.get("edge", 0.94))
    col[edge] = hexcol(look["edge_col"])
    a[edge] = float(look.get("edge_alpha", 0.95))
    # veins fanning from the root
    nv = int(look.get("veins", 6))
    vc = hexcol(look["vein"])
    vw = float(look.get("vein_w", 0.004))
    for i in range(nv):
        f = (i + 0.5) / nv * 2.0 - 1.0                                  # -1 .. 1 across
        xv = f * half * (0.85 - 0.1 * np.abs(f)) * np.clip(v * 1.6, 0.0, 1.0) ** 0.5
        lane = np.abs(x - xv) < vw * (1.0 - 0.6 * v)
        col[lane & inside] = col[lane & inside] * 0.3 + vc * 0.7
        a[lane & inside] = np.maximum(a[lane & inside], float(look.get("vein_alpha", 0.85)))
    # cross veins (cells) on a fairy wing
    for c in look.get("cells", []):
        lane = (np.abs(y - float(c) * L) < vw * 0.8) & (d < 0.95)
        col[lane] = col[lane] * 0.3 + vc * 0.7
        a[lane] = np.maximum(a[lane], float(look.get("vein_alpha", 0.85)))
    # eyespots: concentric rings (centre along the wing, radius in metres)
    for e in look.get("eyes", []):
        cy, r = float(e[0]) * L, float(e[1])
        rr = np.hypot(x / 1.0, (y - cy) / float(e[2]) if len(e) > 2 else (y - cy))
        for rad, cc, al in look["eye_rings"]:
            m = (rr < r * float(rad)) & inside
            col[m] = hexcol(cc)
            a[m] = np.maximum(a[m], float(al))
    # outside the outline the colour is the outline's (alpha 0), so the filtered edge doesn't go dark
    rgba[..., :3] = np.where(inside[..., None], col, hexcol(look["edge_col"])[None, None])
    rgba[..., 3] = np.where(inside, a, 0.0)
    return rgba


def wings(arm, specs, look, tag="wing", tex_w=128, tex_h=256):
    """Every wing in specs as one card mesh: a quad strip from `root` toward `tip` (`across`: the width's
    direction, `width` m), `rows` rows, on a spring chain of `bones` bones under `parent` (hips). The atlas holds
    one column per wing kind (look[kind])."""
    kinds = sorted({sp.get("kind", "fore") for sp in specs})
    cols = len(kinds)
    W_img, H_img = tex_w * cols, tex_h
    px = np.zeros((H_img, W_img, 4), np.float32)
    lens = {}
    for sp in specs:
        lens.setdefault(sp.get("kind", "fore"), (float((Vector(sp["tip"]) - Vector(sp["root"])).length), float(sp["width"])))
    for ci, kd in enumerate(kinds):
        L, W = lens[kd]
        px[:, ci * tex_w:(ci + 1) * tex_w] = _wing_px(kd, tex_w, tex_h, L, W, look[kd])
    img = bpy.data.images.new(tag + "_atlas", W_img, H_img, alpha=True)
    img.file_format = "PNG"
    bld = WP.Builder()
    chains = []
    for sp in specs:
        ci = kinds.index(sp.get("kind", "fore"))
        root, tip = np.array(sp["root"], float), np.array(sp["tip"], float)
        ax = tip - root
        L = np.linalg.norm(ax)
        t = ax / L
        acr = np.array(sp["across"], float)
        acr = acr - t * acr.dot(t)
        acr /= np.linalg.norm(acr)
        bow = np.array(sp.get("bow", [0, 0, 0]), float)           # the card's curve (m, at its middle)
        rows = int(sp.get("rows", 8))
        W = float(sp["width"])
        v0 = len(bld.v)
        for i in range(rows + 1):
            f = i / rows
            c = root + ax * f + bow * math.sin(math.pi * f)
            for j, s in enumerate((-0.5, 0.0, 0.5)):
                bld.v.append(c + acr * W * s + bow * 0.25 * (1 - 4 * s * s))
                u0, u1 = ci / cols, (ci + 1) / cols
                bld.uv.append((u0 + (u1 - u0) * (s + 0.5), 1.0 - f))
                bld.part.append("card")
                bld.s.append(f * L)
        for i in range(rows):
            for j in range(2):
                a = v0 + i * 3 + j
                bld.f.append((a, a + 1, a + 4, a + 3))
        chains.append((sp, root, tip, v0, len(bld.v), L))
    ob = bld.object("Wings")
    # (the atlas rows run root -> tip top -> bottom in the image; Blender's v is up: flip)
    px2 = px[::-1].copy()
    img.pixels = px2.ravel()
    img.pack()
    ob.data.materials.append(_mat("card-" + tag, img, alpha=True))
    for sp, root, tip, v0, v1, L in chains:
        nb = int(sp.get("bones", 3))
        p = np.stack([root + (tip - root) * k / 20.0 for k in range(21)])
        names, spans = WP.chain_bones(arm, sp["name"], sp.get("parent", "hips"), p, L, nb, tip + (tip - root) * 0.02)
        WP.weights(ob, [(vi, bld.s[vi]) for vi in range(v0, v1)], names, spans)
    ob.parent = arm
    mod = ob.modifiers.new("Armature", "ARMATURE")
    mod.object = arm
    log("wings: %d cards, %d tris, atlas %dx%d" % (len(specs), sum(len(f) - 2 for f in bld.f), W_img, H_img))
    return ob


# ------------------------------------------------------------------------------------------------ flat atlas
class Cells:
    """A small atlas of flat colour cells (n x n), one per part: uv box per name."""

    def __init__(self, colours, n=4, size=64):
        self.n, self.size = n, size
        self.box = {}
        px = np.ones((size, size, 4), np.float32)
        cs = size // n
        for i, (name, c) in enumerate(colours.items()):
            r, q = divmod(i, n)
            px[r * cs:(r + 1) * cs, q * cs:(q + 1) * cs, :3] = hexcol(c)
            pad = 0.25 / n
            self.box[name] = (q / n + pad, r / n + pad, (q + 1) / n - pad, (r + 1) / n - pad)
        self.px = px

    def image(self, name):
        img = bpy.data.images.new(name, self.size, self.size, alpha=False)
        img.pixels = self.px.ravel()
        img.file_format = "PNG"
        img.pack()
        return img


def _box(bld, c, half, cell, part):
    """An axis-aligned box (centre c, half sizes) as a 4-sided prism along Y."""
    c = np.asarray(c, float)
    hx, hy, hz = half
    r = math.hypot(hx, hz)
    a = c - np.array([0, hy, 0])
    b = c + np.array([0, hy, 0])
    base = len(bld.v)
    bld.prism(a, b, r, 4, cell, part, 0.0, rot=math.pi / 4)
    # squash the round prism to the box's own x/z sizes
    for i in range(base, len(bld.v)):
        p = bld.v[i] - c
        bld.v[i] = c + np.array([p[0] * hx / (r / math.sqrt(2)), p[1], p[2] * hz / (r / math.sqrt(2))])


def _arc(bld, pts, radii, cell, part, sides=6):
    bld.tube(pts, radii, sides, cell[0], cell[2], cell[1], cell[3], part, [0.0] * len(pts), cap_end=True, cap_start=True)


def crossbow(bld, cells, g, look):
    """One hand crossbow, its grip at g (Gun frame: forward +Y, up +Z, right +X)."""
    g = np.asarray(g, float)
    L = float(look.get("length", 0.3))
    th = float(look.get("thick", 1.0))     # the parts' thickness (reads at the match camera)
    span = float(look.get("span", 0.3))
    top = g + np.array([0, 0, 0.045])
    # the pistol grip (leather) under the tiller, raked back
    _arc(bld, [g + np.array([0, -0.015, -0.05]), g + np.array([0, 0.0, 0.0]), top + np.array([0, 0.01, -0.01])],
         [0.017 * th, 0.018 * th, 0.017 * th], cells.box["grip"], "grip")
    # the tiller (silver): a long slim box, a butt behind the grip
    _box(bld, top + np.array([0, L * 0.5 - 0.06, 0.0]), (0.016 * th, L * 0.5, 0.017 * th),
         cells.box["scroll" if "scroll" in cells.box else "silver"], "tiller")
    _box(bld, top + np.array([0, L * 0.5 - 0.06, 0.02]), (0.007, L * 0.45, 0.005), cells.box["dark"], "rail")
    front = top + np.array([0, L - 0.07, 0.0])
    # the prod: recurved limbs across the front
    for sx in (-1.0, 1.0):
        pts, rad = [], []
        for k in range(9):
            f = k / 8
            x = sx * f * span * 0.5
            y = -0.07 * f ** 2 + 0.025 * max(0.0, f - 0.8) / 0.2
            pts.append(front + np.array([x, y, 0.004 * math.sin(f * math.pi)]))
            rad.append(0.011 * th * (1 - 0.55 * f))
        _arc(bld, pts, rad, cells.box["silver"], "limb")
        tipp = pts[-1]
        nock = top + np.array([0, L * 0.22, 0.02])
        _arc(bld, [tipp, nock], [0.0022, 0.0022], cells.box["string"], "string", sides=4)
    # the bolt on the rail: a dark shaft and a glowing violet head
    b0 = top + np.array([0, L * 0.22, 0.03])
    b1 = top + np.array([0, L + 0.02, 0.03])
    _arc(bld, [b0, b1], [0.0045, 0.0045], cells.box["dark"], "shaft", sides=5)
    bk = float(look.get("bolt_k", 1.0))     # the glowing head's size (reads at the match camera)
    head = [b1, b1 + np.array([0, 0.02 * bk, 0]), b1 + np.array([0, 0.06 * bk, 0])]
    bld.tube(head, [0.013 * bk, 0.011 * bk, 0.0005], 6, *[cells.box["bolt"][i] for i in (0, 2, 1, 3)], "bolt", [0.0] * 3,
             cap_start=True)
    if look.get("stirrup"):
        # the stirrup: a trapezoid loop past the prod (sable_crossbow_sheet)
        a0, a1 = front + np.array([-0.022, 0.0, 0.0]), front + np.array([0.022, 0.0, 0.0])
        b0, b1 = front + np.array([-0.035, 0.07, 0.0]), front + np.array([0.035, 0.07, 0.0])
        for p0, p1 in ((a0, b0), (b0, b1), (b1, a1)):
            bld.prism(p0, p1, 0.006, 4, cells.box["silver"], "stirrup", 0.0, rot=math.pi / 4)
    for sx in (-1.0, 1.0):     # the fletching
        _box(bld, b0 + np.array([sx * 0.008, 0.02, 0.0]), (0.006, 0.02, 0.0015), cells.box["string"], "fletch")


def _scrollwork(cells, name, line):
    """A cell painted with engraved scrollwork (sable_crossbow_sheet's tiller): spirals in a running vine, dark
    engraved lines with a light edge on the silver."""
    u0, v0, u1, v1 = cells.box[name]
    n = cells.size
    x0, x1, y0, y1 = int(u0 * n), int(u1 * n), int(v0 * n), int(v1 * n)
    base = cells.px[y0, x0, :3].copy()
    dark, lite = hexcol(line), np.minimum(base * 1.25, 1.0)
    h = y1 - y0
    w = x1 - x0
    yy, xx = np.mgrid[0:h, 0:w]
    f = (xx % (w / 4.0)) / (w / 4.0)            # across one face (4 faces round the tiller)
    t = yy / max(h - 1, 1) * 6.0                 # along the tiller: six motifs
    k = np.floor(t)
    ft = t - k
    side = np.where(k % 2 == 0, 1.0, -1.0)
    cx, cy = 0.5 + 0.18 * side, 0.5
    dx, dy = f - cx, ft - cy
    r = np.hypot(dx, dy * 0.8)
    a = np.arctan2(dy, dx)
    spiral = np.abs(((r * 26.0 - a * side) / (2 * math.pi)) % 1.0 - 0.5) < 0.12
    spiral &= r < 0.34
    vine = np.abs(f - (0.5 + 0.25 * np.sin(ft * 2 * math.pi + k * math.pi))) < 0.035
    m = spiral | vine
    edge = np.roll(m, 1, axis=0) & ~m
    px = cells.px[y0:y1, x0:x1, :3]
    px[m] = dark
    px[edge] = lite


def crossbows(rig_grips, look):
    """The `weapon` (right hand) and its child `weapon_offhand` (left), each modelled whole about the right grip."""
    cols = dict(look["colours"])
    if look.get("scroll"):
        cols.setdefault("scroll", cols["silver"])
    cells = Cells(cols, n=4, size=256)
    if look.get("scroll"):
        _scrollwork(cells, "scroll", look.get("scroll_line", "4a4e5c"))
    img = cells.image("crossbow_atlas")
    gr = Vector(rig_grips["gr"])
    gl = Vector(rig_grips["gl"])
    obs = []
    for name in ("weapon", "weapon_offhand"):
        bld = WP.Builder()
        crossbow(bld, cells, gr, look)
        ob = bld.object(name)
        mats = {}
        for slot in ("metal", "leather", "glow"):
            ob.data.materials.append(_mat("%s-crossbow" % slot, img, closest=False))
            mats[slot] = len(ob.data.materials) - 1
        for poly in ob.data.polygons:
            pt = bld.part[poly.vertices[0]]
            poly.material_index = mats["glow"] if pt == "bolt" else mats["leather"] if pt in ("grip", "string", "fletch", "shaft", "rail") else mats["metal"]
        for poly in ob.data.polygons:
            poly.use_smooth = False
        obs.append(ob)
        log("%s: %d tris" % (name, sum(len(f) - 2 for f in bld.f)))
    pitch = float(look.get("pitch", 0.0))
    if pitch:
        # (the crossbow tipped about its grip: the twin hold's rest points it down by the thigh as the art holds it)
        rot = Matrix.Translation(gr) @ Matrix.Rotation(pitch, 4, "X") @ Matrix.Translation(-gr)
        for ob in obs:
            ob.data.transform(rot)
    w, off = obs
    off.parent = w
    off.location = gl - gr        # (HunterAnim's twin hold hands a mesh at x < -0.04 to the left hand)
    return w, off


# ------------------------------------------------------------------------------------------------ the lantern
def lantern(arm, spec, look, tag="lantern"):
    """A small caged lantern hanging under the paw `hand` bone's grip point `at` (fitted frame), on a spring
    chain spring_<name>_0..1 under the hand: it swings as she moves."""
    cells = Cells(look["colours"], n=2, size=256)
    if look.get("arch"):
        _arch_panes(cells, look)
    img = cells.image(tag + "_atlas")
    at = np.array(spec["at"], float)               # the bail's top, in the paw
    s = float(spec.get("size", 1.0))
    bld = WP.Builder()
    top = at - np.array([0, 0, 0.03 * s])          # the ring's bottom
    bld.torus(at - np.array([0, 0, 0.012 * s]), [1, 0, 0], 0.014 * s, 0.0035 * s, 12, 4, cells.box["copper"], "frame", 0.0)
    h = 0.13 * s
    r = 0.045 * s
    cap0 = top - np.array([0, 0, 0.01 * s])
    # the roof: a little four-sided cone, a cap ring
    bld.tube([top, cap0, cap0 - np.array([0, 0, 0.025 * s])], [0.008 * s, 0.03 * s, r * 1.15], 4,
             *[cells.box["copper"][i] for i in (0, 2, 1, 3)], "frame", [0.0] * 3, cap_start=True)
    body0 = cap0 - np.array([0, 0, 0.025 * s])
    body1 = body0 - np.array([0, 0, h])
    # the glowing panes (a square column) and the copper posts at its corners
    bld.prism(body1, body0, r * 0.95, 4, cells.box["glass"], "glass", 0.0, rot=math.pi / 4)
    for k in range(4):
        ang = math.pi / 4 + k * math.pi / 2
        off = np.array([math.cos(ang), math.sin(ang), 0]) * r * 1.02
        bld.prism(body0 + off, body1 + off, 0.006 * s, 4, cells.box["copper"], "frame", 0.0)
    for z in (body0, body1, (body0 + body1) * 0.5):
        bld.torus(z, [0, 0, 1], r * 1.02, 0.005 * s, 4, 4, cells.box["copper"], "frame", 0.0)
    # the base and a little foot
    bld.tube([body1, body1 - np.array([0, 0, 0.02 * s]), body1 - np.array([0, 0, 0.03 * s])],
             [r * 1.15, r * 1.05, r * 0.6], 4, *[cells.box["copper"][i] for i in (0, 2, 1, 3)], "frame", [0.0] * 3,
             cap_end=True)
    ob = bld.object("Lantern")
    mats = {}
    for slot in ("metal", "glow"):
        ob.data.materials.append(_mat("%s-%s" % (slot, tag), img, closest=True))
        mats[slot] = len(ob.data.materials) - 1
    for poly in ob.data.polygons:
        poly.material_index = mats["glow"] if bld.part[poly.vertices[0]] == "glass" else mats["metal"]
        poly.use_smooth = False
    bottom = body1 - np.array([0, 0, 0.03 * s])
    p = np.stack([at + (bottom - at) * k / 10.0 for k in range(11)])
    names, _spans = WP.chain_bones(arm, spec.get("name", "lantern"), spec.get("parent", "hand.R"), p, float(np.linalg.norm(bottom - at)), 1, bottom)
    _skin(ob, arm, {names[0]: range(len(ob.data.vertices))})
    # an empty at the flame, riding the lantern's bone: WardenGlb's look puts its light there
    e = bpy.data.objects.new("anchor_" + spec.get("name", "lantern"), None)
    bpy.context.scene.collection.objects.link(e)
    e.parent = arm
    e.parent_type = "BONE"
    e.parent_bone = names[0]
    bpy.context.view_layer.update()
    e.matrix_world = Matrix.Translation(Vector(((body0 + body1) * 0.5).tolist()))
    log("lantern: %d tris, %.2f m" % (sum(len(f) - 2 for f in bld.f), float(np.linalg.norm(bottom - at))))
    return ob


def _arch_panes(cells, look):
    """The glass cell painted as four pointed-arch windows side by side (one per face of the square lantern, the
    portrait's): a dark copper frame round each arch, a warm flame inside, brightest at its heart."""
    u0, v0, u1, v1 = cells.box["glass"]
    n = cells.size
    x0, x1, y0, y1 = int(u0 * n), int(u1 * n), int(v0 * n), int(v1 * n)
    frame = hexcol(look.get("frame", "4a2410"))
    glass = hexcol(look["colours"]["glass"])
    core = hexcol(look.get("core", "fff4c8"))
    w = (x1 - x0) / 4.0
    for py in range(y0, y1):
        for px in range(x0, x1):
            f = ((px - x0) % w) / w                  # 0..1 across this face
            t = (py - y0) / max(1, (y1 - y0) - 1)    # 0 bottom .. 1 top of the face
            ax = abs(f - 0.5) * 2.0                  # 0 middle .. 1 edge
            # the arch: straight sides up to 0.6, then a pointed top to 0.92
            half = 0.72 if t < 0.6 else 0.72 * max(0.0, 1.0 - ((t - 0.6) / 0.32)) ** 0.8
            inside = ax < half and 0.08 < t < 0.92
            if not inside:
                c = frame
            else:
                r = math.hypot((f - 0.5) * 1.4, (t - 0.4) * 1.0)
                k = max(0.0, 1.0 - r / float(look.get("core_r", 0.45)))
                c = glass * (1 - k) + core * k
            cells.px[py, px, :3] = c


# ------------------------------------------------------------------------------------------------ a tail
def spring_region(ob, arm, spec):
    """Body vertices inside `box` [x0, x1, y0, y1, z0, z1] (fitted frame; null = open) re-skinned onto a spring
    chain of `bones` bones along `path` (root first) under `parent`: each vertex by its nearest point on the path;
    within `blend` m of the root it keeps part of its old weights (no seam where the tail meets the body)."""
    co = np.array([v.co[:] for v in ob.data.vertices])
    b = [(-1e9 if x is None else x) if i % 2 == 0 else (1e9 if x is None else x) for i, x in enumerate(spec["box"])]
    sel = ((co[:, 0] >= b[0]) & (co[:, 0] <= b[1]) & (co[:, 1] >= b[2]) & (co[:, 1] <= b[3])
           & (co[:, 2] >= b[4]) & (co[:, 2] <= b[5]))
    path = np.array(spec["path"], float)
    p, L = WP.resample(path, 60)
    s_arr = WP.arclen(p)
    names, spans = WP.chain_bones(arm, spec["name"], spec.get("parent", "hips"), p, L, int(spec.get("bones", 4)),
                                  p[-1] + (p[-1] - p[-2]) * 0.5)
    idx = np.nonzero(sel)[0]
    d = np.linalg.norm(co[idx][:, None, :] - p[None, :, :], axis=2)
    near = d.argmin(axis=1)
    s = s_arr[near]
    blend = float(spec.get("blend", 0.06))
    groups = [ob.vertex_groups.get(nm) or ob.vertex_groups.new(name=nm) for nm in names]
    mids = np.array([(a + c) * 0.5 for a, c in spans])
    lens = np.array([max(c - a, 1e-3) for a, c in spans])
    for vi, sv in zip(idx, s):
        keep = max(0.0, 1.0 - sv / blend) if blend > 0 else 0.0
        v = ob.data.vertices[int(vi)]
        for g in v.groups:
            g.weight *= keep
        w = np.clip(1.0 - np.abs(sv - mids) / lens, 0.0, 1.0)
        if sv <= mids[0]:
            w[:] = 0.0
            w[0] = 1.0
        if sv >= mids[-1]:
            w[:] = 0.0
            w[-1] = 1.0
        w = w / max(w.sum(), 1e-6) * (1.0 - keep)
        for gi in np.nonzero(w > 1e-3)[0]:
            groups[gi].add([int(vi)], float(w[gi]), "REPLACE")
    log("spring region %s: %d verts on %d bones, %.2f m" % (spec["name"], len(idx), len(names), L))


# ------------------------------------------------------------------------------------------------ a gem
def gem(arm, body, spec, tag="gem"):
    """A long faceted crystal on the `glow` slot, its middle `out` m in front of the body's surface where a ray
    from the front (+Y) at `at` [x, z] meets it, hanging point down, riding `bone` rigidly (the pendant on the
    chest). A small `metal` cap and bail on top."""
    from mathutils.bvhtree import BVHTree
    dg = bpy.context.evaluated_depsgraph_get()
    ev = body.evaluated_get(dg)
    me = ev.to_mesh()
    bvh = BVHTree.FromPolygons([body.matrix_world @ v.co for v in me.vertices], [list(p.vertices) for p in me.polygons])
    ev.to_mesh_clear()
    x, z = spec["at"]
    hit = bvh.ray_cast(Vector((x, 1.0, z)), Vector((0, -1, 0)))
    y = (hit[0].y if hit[0] is not None else 0.1) + float(spec.get("out", 0.012))
    c = np.array([x, y, z], float)
    L, r = float(spec.get("length", 0.05)), float(spec.get("r", 0.012))
    cells = Cells({"gem": spec.get("colour", "ff2a48"), "cap": spec.get("cap", "c8ccd6"), "core": spec.get("core", "ffd0d8")},
                  size=256)
    if spec.get("facets"):
        # (facets: the gem's cell striped across its 6 sides, light / dark by `facets`, toward `core` by the middle of
        # its length, so the glow reads as a cut crystal and not a flat blob)
        u0, v0, u1, v1 = cells.box["gem"]
        n = cells.size
        x0, x1, y0, y1 = int(u0 * n) - 2, int(u1 * n) + 2, int(v0 * n) - 2, int(v1 * n) + 2
        base, core = hexcol(spec.get("colour", "ff2a48")), hexcol(spec.get("core", "ffd0d8"))
        for x in range(x0, x1):
            j = min(5, max(0, int((x / n - u0) / (u1 - u0) * 6)))
            k = float(spec["facets"][j % len(spec["facets"])])
            for y in range(y0, y1):
                t = min(1.0, max(0.0, (y / n - v0) / (v1 - v0)))
                mid = max(0.0, 1.0 - abs(t - 0.35) / 0.35) * float(spec.get("core_k", 0.35)) * k
                cells.px[y, x, :3] = np.clip(base * k * (1 - mid) + core * mid, 0, 1)
    img = cells.image(tag + "_atlas")
    bld = WP.Builder()
    top = c + np.array([0, 0, L * 0.45])
    bot = c - np.array([0, 0, L * 0.55])
    bld.tube([top, top - np.array([0, 0, L * 0.2]), c - np.array([0, 0, L * 0.1]), bot],
             [r * 0.35, r, r * 0.9, 0.0005], 6, *[cells.box["gem"][i] for i in (0, 2, 1, 3)], "gem", [0.0] * 4,
             cap_start=True)
    bld.prism(top, top + np.array([0, 0, 0.008]), r * 0.45, 6, cells.box["cap"], "cap", 0.0)
    bld.torus(top + np.array([0, 0, 0.014]), [1, 0, 0], 0.005, 0.0015, 10, 4, cells.box["cap"], "cap", 0.0)
    ob = bld.object("Gem")
    mats = {}
    for slot in ("glow", "metal"):
        ob.data.materials.append(_mat("%s-%s" % (slot, tag), img, closest=False))
        mats[slot] = len(ob.data.materials) - 1
    for poly in ob.data.polygons:
        poly.material_index = mats["glow"] if bld.part[poly.vertices[0]] == "gem" else mats["metal"]
        poly.use_smooth = False
    _skin(ob, arm, {spec.get("bone", "hips"): range(len(ob.data.vertices))})
    # an empty at the gem, riding its bone: the look's light gives it a glowing halo
    e = bpy.data.objects.new("anchor_" + tag, None)
    bpy.context.scene.collection.objects.link(e)
    e.parent = arm
    e.parent_type = "BONE"
    e.parent_bone = spec.get("bone", "hips")
    bpy.context.view_layer.update()
    mid = np.array([ob.matrix_world @ v.co for v in ob.data.vertices]).mean(axis=0)     # (the gem's own middle)
    e.matrix_world = Matrix.Translation(Vector(mid.tolist()))
    log("gem at %s: %d tris" % (tuple(round(float(v), 3) for v in c), sum(len(f) - 2 for f in bld.f)))
    return ob


# ------------------------------------------------------------------------------------------------ a fluffy tail
def fluff_tail(arm, spec, tag="tail"):
    """A big fluffy fox tail as its own geometry (the art's size): a tube along `path` whose radius follows
    `radii`, its cross-section scalloped into fur clumps that twist along it and its end drawn to a soft tip;
    painted `base` fading to `tip` over the last `tip_from` of its length, with stroke lines along the fur. It rides
    a spring chain of `bones` bones under `parent` (the contract tail bone)."""
    path = np.array(spec["path"], float)
    p, L = WP.resample(path, int(spec.get("samples", 48)))
    s_arr = WP.arclen(p)
    rr = np.interp(s_arr / max(L, 1e-6), np.linspace(0, 1, len(spec["radii"])), spec["radii"])
    t, nrm, bin_ = WP.frames(p, spec.get("side", [1.0, 0.0, 0.0]))
    sides = int(spec.get("sides", 18))
    clumps = int(spec.get("clumps", 7))
    bld = WP.Builder()
    base = len(bld.v)
    k = len(p)
    for i in range(k):
        f = s_arr[i] / L
        for j in range(sides + 1):
            a = 2 * math.pi * j / sides
            amp = float(spec.get("fluff", 0.16))
            sc = 1.0 + amp * max(0.0, math.cos(clumps * a + f * 9.0)) ** 2 - amp * 0.35
            off = rr[i] * sc * (math.cos(a) * nrm[i] + math.sin(a) * bin_[i])
            bld.v.append(p[i] + off)
            bld.uv.append((j / sides, f))
            bld.part.append("fur")
            bld.s.append(s_arr[i])
    row = sides + 1
    for i in range(k - 1):
        for j in range(sides):
            a0 = base + i * row + j
            bld.f.append((a0, a0 + 1, a0 + row + 1, a0 + row))
    for i, cap in ((0, False), (k - 1, True)):
        c = len(bld.v)
        bld.v.append(p[i] + (t[i] * rr[i] * 0.6 if cap else -t[i] * rr[i] * 0.3))
        bld.uv.append((0.5, 1.0 if cap else 0.0))
        bld.part.append("fur")
        bld.s.append(s_arr[i])
        for j in range(sides):
            a0 = base + i * row + j
            bld.f.append((a0, a0 + 1, c) if cap else (a0 + 1, a0, c))
    ob = bld.object("Tail")
    size = 256
    v = (np.arange(size)[:, None] + 0.5) / size * np.ones((1, size))
    u = (np.arange(size)[None, :] + 0.5) / size * np.ones((size, 1))
    c0, c1 = hexcol(spec["base"]), hexcol(spec["tip"])
    dark = hexcol(spec.get("shade", spec["base"]))
    tf = float(spec.get("tip_from", 0.7))
    m = np.clip((v - tf) / max(1.0 - tf, 1e-3), 0, 1)[..., None] ** 0.8
    col = c0 * (1 - m) + c1 * m
    strokes = 0.5 + 0.5 * np.sin(u * 2 * math.pi * 24 + np.sin(v * 17.0) * 2.5 + v * 30.0)
    col = col * (1 - 0.16 * strokes[..., None] * (1 - m)) + dark * 0.16 * strokes[..., None] * (1 - m)
    px = np.ones((size, size, 4), np.float32)
    px[..., :3] = col
    img = bpy.data.images.new(tag + "_atlas", size, size, alpha=False)
    img.pixels = px.ravel()
    img.file_format = "PNG"
    img.pack()
    ob.data.materials.append(_mat("%s-%s" % (spec.get("slot", "fur"), tag), img))
    names, spans = WP.chain_bones(arm, spec.get("name", "tail"), spec.get("parent", "tail"), p, L,
                                  int(spec.get("bones", 5)), p[-1] + t[-1] * 0.02)
    WP.weights(ob, [(vi, bld.s[vi]) for vi in range(len(bld.v))], names, spans)
    ob.parent = arm
    mod = ob.modifiers.new("Armature", "ARMATURE")
    mod.object = arm
    log("tail: %.2f m, %d tris" % (L, sum(len(f) - 2 for f in bld.f)))
    return ob


def cape(arm, body, spec, tag="cape"):
    """A cloth cape down the back as its own geometry (pip_front, the turnaround's back: the scan's cape is only
    a collar). Rows from `z0` (the shoulders) to `z1` (the waist, above the tail's root), half-width `w0` to `w1`;
    each row is laid `out` m behind the body's furthest-back point under it (a ray from behind at every column)
    and never comes forward going down, so it hangs off the shoulder blades; the sides wrap forward by `wrap`
    (x the square of the across), `folds` soft vertical folds `fold` m deep, more toward the hem. Two layers
    (both sides read), painted `colours` dark to light down the folds; rides `bone` rigidly."""
    from mathutils.bvhtree import BVHTree
    dg = bpy.context.evaluated_depsgraph_get()
    ev = body.evaluated_get(dg)
    me = ev.to_mesh()
    bvh = BVHTree.FromPolygons([body.matrix_world @ v.co for v in me.vertices], [list(q.vertices) for q in me.polygons])
    ev.to_mesh_clear()
    nu, nv = int(spec.get("nu", 24)), int(spec.get("nv", 14))
    z0, z1 = float(spec["z0"]), float(spec["z1"])
    w0, w1 = float(spec["w0"]), float(spec["w1"])
    out, wrap = float(spec.get("out", 0.02)), float(spec.get("wrap", 0.07))
    folds, fold = float(spec.get("folds", 3)), float(spec.get("fold", 0.012))
    rows = []
    y_prev = None
    for i in range(nv + 1):
        v = i / nv
        z = z0 + (z1 - z0) * v
        w = w0 + (w1 - w0) * v ** 0.8
        ys = []
        for j in range(nu + 1):
            x = -w + 2 * w * j / nu
            if abs(x) > w * 0.85:
                continue
            hit = bvh.ray_cast(Vector((x, -2.0, z)), Vector((0.0, 1.0, 0.0)))
            if hit[0] is not None:
                ys.append(hit[0].y)
        # (the row's back by the median of its hits, never behind `y_lo`: a satchel or a scan's stub on the back
        # pushed a min-of-hits cape half a metre out)
        yb = (float(np.median(ys)) if ys else (y_prev + out if y_prev is not None else -0.12)) - out
        yb = max(yb, float(spec.get("y_lo", -0.22)))
        if y_prev is not None:
            yb = min(yb, y_prev)
        y_prev = yb
        row = []
        for j in range(nu + 1):
            u = j / nu
            a = 2 * u - 1
            fy = fold * (0.4 + 0.6 * v) * (0.5 - 0.5 * math.cos(2 * math.pi * folds * u))
            row.append(np.array([w * a, yb + wrap * a * a - fy, z]))
        rows.append(row)
    cells = None
    size = 64
    cols = [hexcol(c) for c in spec.get("colours", ["1f3d44", "2c555c", "3a6870"])]
    px = np.ones((size, size, 4), np.float32)
    for yy in range(size):
        for xx in range(size):
            u, v = (xx + 0.5) / size, (yy + 0.5) / size
            k = 0.5 - 0.5 * math.cos(2 * math.pi * folds * u)          # 0 on a fold's ridge .. 1 in its valley
            t = max(0.0, min(1.0, 0.85 - 0.55 * k - 0.25 * (1 - v)))
            x = t * (len(cols) - 1)
            i0 = min(int(x), len(cols) - 2)
            f = x - i0
            px[yy, xx, :3] = cols[i0] * (1 - f) + cols[i0 + 1] * f
    img = bpy.data.images.new(tag + "_atlas", size, size, alpha=False)
    img.pixels = px.ravel()
    img.file_format = "PNG"
    img.pack()
    bld = WP.Builder()
    thick = float(spec.get("thick", 0.006))
    for layer in (0, 1):
        base = len(bld.v)
        for i, row in enumerate(rows):
            for j, pnt in enumerate(row):
                bld.v.append(pnt + np.array([0.0, thick * layer, 0.0]))
                bld.uv.append((j / nu, 1.0 - i / nv))
                bld.part.append("cape")
                bld.s.append(0.0)
        rl = nu + 1
        for i in range(nv):
            for j in range(nu):
                a0 = base + i * rl + j
                q = (a0, a0 + 1, a0 + rl + 1, a0 + rl)
                bld.f.append(q if layer == 0 else q[::-1])
    ob = bld.object("Cape")
    # (the outer layer faces back, -y, the inner one the body: recalc_face_normals guesses on an open sheet)
    half = len(bld.f) // 2
    for k, poly in enumerate(ob.data.polygons):
        want = -1.0 if k < half else 1.0
        if poly.normal.y * want < 0:
            poly.flip()
    ob.data.update()
    ob.data.materials.append(_mat("%s-%s" % (spec.get("slot", "cloth"), tag), img))
    for poly in ob.data.polygons:
        poly.use_smooth = True
    _skin(ob, arm, {spec.get("bone", "hips"): range(len(ob.data.vertices))})
    log("cape: rows %.2f..%.2f m, back at y %.3f..%.3f, %d tris" % (z0, z1, rows[0][nu // 2][1], rows[-1][nu // 2][1],
                                                                     sum(len(f) - 2 for f in bld.f)))
    return ob


# ------------------------------------------------------------------------------------------------ a flower crown
def flower_crown(arm, body, spec, tag="flowers"):
    """Small five-petal flowers (white petals, a yellow middle, a leaf between some) set on the head's surface
    along an arc over the top of the head (pip_head_sheet's crown): `n` flowers from angle a0 to a1 (deg, 0 = her
    right ear, 90 = the crown's top, 180 = her left ear) on a circle `r` round the head centre `centre`, tipped
    `tilt` deg back; each ray-cast onto the body and lifted `out` m. Rides the head bone rigidly."""
    from mathutils.bvhtree import BVHTree
    dg = bpy.context.evaluated_depsgraph_get()
    ev = body.evaluated_get(dg)
    me = ev.to_mesh()
    bvh = BVHTree.FromPolygons([body.matrix_world @ v.co for v in me.vertices], [list(q.vertices) for q in me.polygons])
    ev.to_mesh_clear()
    cells = Cells({"petal": spec.get("petal", "fbf7f2"), "heart": spec.get("heart", "f2c040"),
                   "leaf": spec.get("leaf", "5f9a48"), "petal_shade": spec.get("petal_shade", "e8d8e0")}, n=2, size=64)
    img = cells.image(tag + "_atlas")
    bld = WP.Builder()
    c = Vector(spec["centre"])
    n = int(spec.get("n", 9))
    tilt = math.radians(float(spec.get("tilt", 20.0)))
    rad = float(spec.get("r", 0.2))
    fs = float(spec.get("size", 0.028))
    rng = np.random.default_rng(3)
    placed = 0
    for i in range(n):
        if spec.get("ring"):
            # a ring round the head (on the goggles' strap): a full circle in the horizontal plane, its front
            # tipped `tilt` deg down
            a = 2 * math.pi * i / n
            d = Vector((math.cos(a), math.sin(a), -math.sin(tilt) * math.sin(a))).normalized()
        else:
            a = math.radians(float(spec["a0"]) + (float(spec["a1"]) - float(spec["a0"])) * i / max(n - 1, 1))
            d = Vector((math.cos(a), -math.sin(tilt) * math.sin(a), math.cos(tilt) * math.sin(a)))
        hit = bvh.ray_cast(c + d * rad, -d)
        if hit[0] is None:
            continue
        nrm = hit[1].normalized()
        at = hit[0] + nrm * float(spec.get("out", 0.006))
        e1 = nrm.orthogonal().normalized()
        e2 = nrm.cross(e1).normalized()
        sz = fs * rng.uniform(0.8, 1.15)
        spin = rng.uniform(0, 2 * math.pi)
        for k in range(5):
            ang = spin + 2 * math.pi * k / 5
            dirv = e1 * math.cos(ang) + e2 * math.sin(ang)
            pc = at + dirv * sz * 0.55 + nrm * sz * 0.08
            # a petal: a flat, slightly cupped disc (a squashed prism)
            pa = np.array(pc - nrm * sz * 0.03)
            pb = np.array(pc + nrm * sz * 0.03)
            v0 = len(bld.v)
            bld.prism(pa, pb, sz * 0.38, 8, cells.box["petal"] if k % 2 else cells.box["petal_shade"], "petal", 0.0)
            # stretch it along the petal's direction
            dv = np.array(dirv[:])
            for vi in range(v0, len(bld.v)):
                q = bld.v[vi] - np.array(pc[:])
                along = q.dot(dv)
                bld.v[vi] = np.array(pc[:]) + q + dv * along * 0.5
        bld.prism(np.array(at[:]), np.array((at + nrm * sz * 0.16)[:]), sz * 0.22, 8, cells.box["heart"], "heart", 0.0)
        if i % 2 == 0:
            ld = e2 * math.cos(spin) - e1 * math.sin(spin)
            lp = at + ld * sz * 1.1 - nrm * sz * 0.05
            v0 = len(bld.v)
            bld.prism(np.array((lp - nrm * sz * 0.02)[:]), np.array((lp + nrm * sz * 0.02)[:]), sz * 0.3, 6,
                      cells.box["leaf"], "leaf", 0.0)
            ldn = np.array(ld[:])
            for vi in range(v0, len(bld.v)):
                q = bld.v[vi] - np.array(lp[:])
                bld.v[vi] = np.array(lp[:]) + q + ldn * q.dot(ldn) * 0.9
        placed += 1
    ob = bld.object("Flowers")
    ob.data.materials.append(_mat("%s-%s" % (spec.get("slot", "leather"), tag), img, closest=True))
    for poly in ob.data.polygons:
        poly.use_smooth = False
    _skin(ob, arm, {spec.get("bone", "head"): range(len(ob.data.vertices))})
    log("flower crown: %d flowers, %d tris" % (placed, sum(len(f) - 2 for f in bld.f)))
    return ob


# ------------------------------------------------------------------------------------------------ laces
def laces(arm, body, spec, tag="laces"):
    """A criss-cross lacing across the open back (Sable's turnaround back): `rows` crossings between the two
    edges x = +-`half` from z0 to z1, each lace a thin tube laid on the body's surface (rays from behind, -Y), with
    a small eyelet at each end; silver on the metal slot, riding `bone`."""
    from mathutils.bvhtree import BVHTree
    dg = bpy.context.evaluated_depsgraph_get()
    ev = body.evaluated_get(dg)
    me = ev.to_mesh()
    bvh = BVHTree.FromPolygons([body.matrix_world @ v.co for v in me.vertices], [list(q.vertices) for q in me.polygons])
    ev.to_mesh_clear()
    cells = Cells({"lace": spec.get("colour", "d8dae6"), "eyelet": spec.get("eyelet", "8a8ca0")}, n=2, size=32)
    img = cells.image(tag + "_atlas")
    out = float(spec.get("out", 0.004))
    r = float(spec.get("r", 0.0035))

    def on(x, z):
        hit = bvh.ray_cast(Vector((x, -1.0, z)), Vector((0, 1, 0)))
        return np.array((hit[0] + hit[1] * out)[:]) if hit[0] is not None else None
    bld = WP.Builder()
    n = int(spec.get("rows", 5))
    z0, z1, hw = float(spec["z0"]), float(spec["z1"]), float(spec["half"])
    zs = [z0 + (z1 - z0) * i / n for i in range(n + 1)]
    for i in range(n):
        for a, b in (((-hw, zs[i]), (hw, zs[i + 1])), ((hw, zs[i]), (-hw, zs[i + 1]))):
            pts = [on(a[0] + (b[0] - a[0]) * k / 8, a[1] + (b[1] - a[1]) * k / 8) for k in range(9)]
            pts = [q for q in pts if q is not None]
            if len(pts) > 1:
                bld.tube(pts, [r] * len(pts), 5, *[cells.box["lace"][j] for j in (0, 2, 1, 3)], "lace", [0.0] * len(pts))
    for z in zs:
        for x in (-hw, hw):
            q = on(x, z)
            if q is not None:
                bld.torus(q, [0, -1, 0], r * 1.8, r * 0.7, 8, 4, cells.box["eyelet"], "eyelet", 0.0)
    ob = bld.object("Laces")
    ob.data.materials.append(_mat("metal-%s" % tag, img))
    _skin(ob, arm, {spec.get("bone", "hips"): range(len(ob.data.vertices))})
    log("laces: %d rows, %d tris" % (n, sum(len(f) - 2 for f in bld.f)))
    return ob
