"""A held weapon built as a lathe in the Gun node's space (RIG_CONTRACT: forward -Z in Godot, +Y here; the Muzzle
where the shots leave), for a weapon Meshy can't give cleanly in the hand: Cinder's flamethrower lance (a steel
shaft, brass fittings, a glass chamber with a live flame, a cork-brown nozzle). Fit spec "lance":

  {"sides": 18, "parts": [{"name": "shaft", "slot": "metal", "colour": "b4b8c0", "dark": "6a6e78",
                            "prof": [[z, r], ...]}, ...]}

`prof` runs along the Gun's z (Godot, metres; -z forward) with the radius at each station; each part is one
closed lathe (capped at both ends). Its texture is painted here: the part's colour lit down to `dark` round its
back (a soft band, so the toon light still reads it as round), `stripes` [n, colour] for rings, and for a
`flame` part a hot core along the axis (`core`) fading to `colour` at its ends, with `licks` tongues.
`anchors` [{"name": "anchor_flame", "z": -0.54}]: empties on the weapon at a Gun-space z (a halo's anchor).
Blender 4.5, called from fit_warden.py (it hands in its slot materials)."""
import math

import bmesh
import bpy
import numpy as np

TEX = 512


def _hex(h):
    h = h.lstrip("#")
    return np.array([int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)], np.float32)


def _paint(px, part, v0, v1):
    """Fills the texture rows [v0, v1) of one part: u runs round it (0 = its top), v along it (0 = rear)."""
    h, w = px.shape[:2]
    r0, r1 = int(v0 * h), max(int(v0 * h) + 1, int(v1 * h))
    u = (np.arange(w) + 0.5) / w
    t = (np.arange(r1 - r0) + 0.5) / max(1, r1 - r0)
    col, dark = _hex(part["colour"]), _hex(part.get("dark", part["colour"]))
    shade = 0.5 + 0.5 * np.cos(u * 2.0 * math.pi)          # 1 on top, 0 underneath
    k = (shade ** 0.8)[None, :, None]
    band = dark[None, None, :] * (1 - k) + col[None, None, :] * k
    band = np.repeat(band, r1 - r0, axis=0)
    if part.get("flame"):
        core = _hex(part.get("core", "fff0a0"))
        # hot along its middle, cooler toward the ends; a few tongues licking forward
        along = np.sin(np.clip(t, 0, 1) * math.pi) ** 0.7
        n = int(part.get("licks", 5))
        lick = 0.5 + 0.5 * np.sin(u * 2 * math.pi * n + t[:, None] * 7.0)
        heat = np.clip(along[:, None] * (0.55 + 0.45 * lick), 0, 1)[:, :, None]
        band = col[None, None, :] * (1 - heat) + core[None, None, :] * heat
    if part.get("stripes"):
        n, sc = part["stripes"]
        ring = (np.floor(t * n * 2) % 2 == 0)[:, None, None]
        band = np.where(ring, band, band * 0.0 + _hex(sc)[None, None, :] * (0.6 + 0.4 * k))
    px[r0:r1, :, :3] = band
    px[r0:r1, :, 3] = 1.0


def build(spec, slot_mats, tag="weapon"):
    sides = int(spec.get("sides", 18))
    parts = spec["parts"]
    img = bpy.data.images.new("%s_tex" % tag, TEX, TEX, alpha=False)
    px = np.zeros((TEX, TEX, 4), np.float32)
    me = bpy.data.meshes.new(tag)
    ob = bpy.data.objects.new(tag, me)
    bpy.context.scene.collection.objects.link(ob)
    bm = bmesh.new()
    uvl = bm.loops.layers.uv.new("UVMap")
    slots = []
    for p in parts:
        if p["slot"] not in slots:
            slots.append(p["slot"])
    for s in slots:
        me.materials.append(slot_mats[s])
    n = len(parts)
    for pi, part in enumerate(parts):
        v0, v1 = (pi + 0.06) / n, (pi + 0.94) / n
        _paint(px, part, v0, v1)
        prof = part["prof"]
        rings = []
        for j, (z, r) in enumerate(prof):
            ring = []
            for i in range(sides):
                a = 2 * math.pi * i / sides
                # Godot gun space (x, y, z) -> Blender (x, -z, y); the angle from the top (+y Godot)
                ring.append(bm.verts.new((r * math.sin(a), -z, r * math.cos(a))))
            rings.append(ring)
        mi = slots.index(part["slot"])
        m = len(prof)
        for j in range(m - 1):
            for i in range(sides):
                a, b = rings[j][i], rings[j][(i + 1) % sides]
                c, d = rings[j + 1][(i + 1) % sides], rings[j + 1][i]
                f = bm.faces.new((a, d, c, b))
                f.material_index = mi
                for lp, (uu, vv) in zip(f.loops, ((i, j), (i, j + 1), (i + 1, j + 1), (i + 1, j))):
                    lp[uvl].uv = (uu / sides, v0 + (v1 - v0) * vv / (m - 1))
        for j, flip in ((0, True), (m - 1, False)):
            if prof[j][1] < 1e-4:
                continue
            ring = rings[j] if not flip else list(reversed(rings[j]))
            f = bm.faces.new(ring if not flip else ring)
            f.material_index = mi
            vv = v0 if j == 0 else v1
            for lp in f.loops:
                lp[uvl].uv = (0.5, vv)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me)
    bm.free()
    img.pixels.foreach_set(px.ravel())
    img.update()
    for m in me.materials:
        for nd in m.node_tree.nodes:
            if nd.type == "TEX_IMAGE":
                nd.image = img
    for poly in me.polygons:
        poly.use_smooth = True
    for an in spec.get("anchors", []):
        # (an empty on the weapon, e.g. its flame chamber: warden_look.json "halos" hang a match-zoom glow on it)
        e = bpy.data.objects.new(an["name"], None)
        bpy.context.scene.collection.objects.link(e)
        e.parent = ob
        e.location = (0.0, -float(an["z"]), float(an.get("y", 0.0)))
    return ob, img
