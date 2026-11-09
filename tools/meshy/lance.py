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


def _tube_parts(spec):
    """`tubes` [{"a": [x, y, z], "b": [...], "r", "ribs", "slot", "colour", "dark"}] (Gun space) as lathe parts
    along their own axis ("axis_from"/"axis_to" kept for build to turn them into place)."""
    out = []
    for t in spec.get("tubes", []):
        a, b = np.array(t["a"], float), np.array(t["b"], float)
        L = float(np.linalg.norm(b - a))
        n = int(t.get("ribs", 8))
        prof = [[0.0, 0.0]]
        for k in range(2 * n + 1):
            z = -L * k / (2 * n)
            prof.append([z, float(t["r"]) * (1.18 if k % 2 else 1.0)])
        prof.append([-L, 0.0])
        out.append(dict(t, prof=prof, axis_from=a.tolist(), axis_to=b.tolist(), name=t.get("name", "tube")))
    return out


def build(spec, slot_mats, tag="weapon"):
    sides = int(spec.get("sides", 18))
    parts = spec["parts"] + _tube_parts(spec)
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
        ox, oy = part.get("offset", [0.0, 0.0])         # (a rod beside the axis: the chamber's brass cage)
        sd = int(part.get("sides", sides))
        rings = []
        for j, (z, r) in enumerate(prof):
            ring = []
            for i in range(sd):
                a = 2 * math.pi * i / sd
                # Godot gun space (x, y, z) -> Blender (x, -z, y); the angle from the top (+y Godot)
                ring.append(bm.verts.new((ox + r * math.sin(a), -z, oy + r * math.cos(a))))
            rings.append(ring)
        if "axis_from" in part:
            # (a tube: built along -z from the origin, turned onto its a -> b in Gun space; Blender (x, -z, y))
            A, B = np.array(part["axis_from"]), np.array(part["axis_to"])
            d = (B - A) / max(np.linalg.norm(B - A), 1e-9)
            ref = np.array([0.0, 1.0, 0.0]) if abs(d[1]) < 0.9 else np.array([1.0, 0.0, 0.0])
            ex = np.cross(ref, d)
            ex /= np.linalg.norm(ex)
            ey = np.cross(d, ex)
            for ring in rings:
                for vtx in ring:
                    bx, by, bz = vtx.co
                    gx, gy, gz = bx, bz, -by                 # (back to Godot)
                    q = A + ex * gx + ey * gy + d * (-gz)
                    vtx.co = (q[0], -q[2], q[1])
        mi = slots.index(part["slot"])
        m = len(prof)
        for j in range(m - 1):
            for i in range(sd):
                a, b = rings[j][i], rings[j][(i + 1) % sd]
                c, d = rings[j + 1][(i + 1) % sd], rings[j + 1][i]
                f = bm.faces.new((a, d, c, b))
                f.material_index = mi
                for lp, (uu, vv) in zip(f.loops, ((i, j), (i, j + 1), (i + 1, j + 1), (i + 1, j))):
                    lp[uvl].uv = (uu / sd, v0 + (v1 - v0) * vv / (m - 1))
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
