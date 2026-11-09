"""A new hull for a hand-made Warden (tools/blender/fit_rigged.py `strip` and `hull`; Dredge r3): the source's own
shell pieces are dropped, and a scripted one is built in their place: a dented sphere, raised plate bands, and
angular layered shoulder plates (lames) instead of smooth domes. Its colour comes from the art: front, side and back
views of the hull alone, projected onto it along their axes (warden_paint's `project` look).

Frames: `strip` runs on the source mesh in its own frame (before the fit's turn and scale); `hull` in the fit's
frame (Blender, the Warden facing +Y, his right +X), after the decimation, its pieces rigid on the hull bones.
"""
import math
import os
import random

import bmesh
import bpy
import numpy as np
from mathutils import Vector

import warden_paint as WP


def strip(ob, grp, lab, rule):
    """Deletes the loose parts of `rule["group"]` whose middle sits inside the shell (within `r` of `centre`,
    between `z` heights) and that are painted one of `materials` (the drips, weed and barnacles stay). Returns the
    kept-vertex mask."""
    me = ob.data
    co = np.array([v.co[:] for v in me.vertices])
    mats = [m.name if m else "" for m in me.materials]
    fmat = {}
    for p in me.polygons:
        fmat.setdefault(int(lab[p.vertices[0]]), []).append(mats[p.material_index])
    c0 = np.array(rule["centre"])
    drop = np.zeros(len(co), bool)
    n = 0
    for p in np.unique(lab[grp == rule["group"]]):
        m = lab == p
        c = co[m].mean(axis=0)
        names = fmat.get(int(p), [])
        main = max(set(names), key=names.count) if names else ""
        if np.linalg.norm(c - c0) < rule["r"] and rule["z"][0] < c[2] < rule["z"][1] and main in rule["materials"]:
            drop |= m
            n += 1
    bm = bmesh.new()
    bm.from_mesh(me)
    bm.verts.ensure_lookup_table()
    bmesh.ops.delete(bm, geom=[bm.verts[i] for i in np.nonzero(drop)[0]], context="VERTS")
    bm.to_mesh(me)
    bm.free()
    print("HULL stripped %d parts, %d vertices" % (n, int(drop.sum())))
    return ~drop


def _sphere_patch(c, r, lat0, lat1, lon0, lon1, nlat, nlon, thick, rnd=None, dents=()):
    """A shell patch of the sphere (latitudes and longitudes in degrees), `thick` deep, dented."""
    bm = bmesh.new()

    def pt(la, lo, rr):
        la, lo = math.radians(la), math.radians(lo)
        d = Vector((math.cos(la) * math.sin(lo), math.cos(la) * math.cos(lo), math.sin(la)))
        k = 1.0
        for dc, dr, dd in dents:
            a = d.angle(dc)
            if a < dr:
                k -= dd * (1.0 - (a / dr) ** 2) ** 2
        return c + d * rr * k

    full = abs((lon1 - lon0) - 360.0) < 1e-6
    rows = []
    for layer, rr in ((0, r), (1, r - thick)):
        grid = []
        for i in range(nlat + 1):
            la = lat0 + (lat1 - lat0) * i / nlat
            row = []
            for j in range(nlon if full else nlon + 1):
                lo = lon0 + (lon1 - lon0) * j / nlon
                row.append(bm.verts.new(pt(la, lo, rr)))
            grid.append(row)
        rows.append(grid)
    W = nlon if full else nlon + 1
    for layer, grid in enumerate(rows):
        for i in range(nlat):
            for j in range(nlon):
                a, b = grid[i][j], grid[i][(j + 1) % W]
                cc, d = grid[i + 1][(j + 1) % W], grid[i + 1][j]
                bm.faces.new((a, b, cc, d) if layer == 0 else (d, cc, b, a))
    if thick > 0:
        o, n_ = rows
        edges = [[(i, 0) for i in range(nlat + 1)], [(i, W - 1) for i in range(nlat + 1)]] if not full else []
        edges += [[(0, j) for j in range(W)] + ([(0, 0)] if full else []),
                  [(nlat, j) for j in range(W)] + ([(nlat, 0)] if full else [])]
        for e in edges:
            for (i0, j0), (i1, j1) in zip(e, e[1:]):
                try:
                    bm.faces.new((o[i0][j0], o[i1][j1], n_[i1][j1], n_[i0][j0]))
                except ValueError:
                    pass
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    bmesh.ops.triangulate(bm, faces=bm.faces[:])
    return bm


def _lame(cx, cz, r, a0, a1, y0, y1, facets, thick):
    """An angular shoulder plate: a faceted arc about the Y axis (front to back) through (cx, cz), from angle a0
    to a1 (degrees, 0 = out along +X), y0..y1 long, `thick` deep."""
    bm = bmesh.new()
    rings = []
    for rr in (r, r - thick):
        ring = []
        for k in range(facets + 1):
            a = math.radians(a0 + (a1 - a0) * k / facets)
            for y in (y0, y1):
                ring.append(bm.verts.new((cx + math.cos(a) * rr, y, cz + math.sin(a) * rr)))
        rings.append(ring)
    o, i = rings
    for k in range(facets):
        a, b, c, d = 2 * k, 2 * k + 1, 2 * k + 3, 2 * k + 2
        bm.faces.new((o[a], o[b], o[c], o[d]))
        bm.faces.new((i[d], i[c], i[b], i[a]))
        bm.faces.new((o[a], o[d], i[d], i[a]))      # front edge
        bm.faces.new((o[c], o[b], i[b], i[c]))      # back edge
    for a, b in ((0, 1), (2 * facets, 2 * facets + 1)):
        bm.faces.new((o[a], i[a], i[b], o[b]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    bmesh.ops.triangulate(bm, faces=bm.faces[:])
    return bm


def build(ob, spec, seed=1):
    """The new hull (fit frame): the dented sphere and its plate bands on `bone`, the lames on the pauldrons."""
    rnd = random.Random(seed)
    c = Vector(spec["centre"])
    r = float(spec["r"])
    mat = WP._mat_index(ob, spec["material"], spec.get("colour", "7d6c3e"))
    dents = []
    for _ in range(int(spec.get("dents", 14))):
        la, lo = rnd.uniform(-60, 70), rnd.uniform(0, 360)
        d = Vector((math.cos(math.radians(la)) * math.sin(math.radians(lo)),
                    math.cos(math.radians(la)) * math.cos(math.radians(lo)), math.sin(math.radians(la))))
        dd = spec.get("dent_depth", [0.02, 0.05])
        dents.append((d, math.radians(rnd.uniform(7, 15)), rnd.uniform(dd[0], dd[1])))
    nl, nb = spec.get("res", [26, 44])
    WP._append(ob, _sphere_patch(c, r, -88, 88, 0, 360, nl, nb, 0.0, dents=dents), spec["bone"], mat)
    for b in spec.get("bands", []):
        WP._append(ob, _sphere_patch(c, r * (1.0 + b["off"]), b["lat"][0], b["lat"][1], b.get("lon", [0, 360])[0],
                                     b.get("lon", [0, 360])[1], b.get("nlat", 2), b.get("nlon", 28),
                                     r * b["thick"], dents=dents), spec["bone"], mat)
    # the shoulder plates: faceted bands of a sphere about each shoulder, stacked down and out like lames, each a
    # little wider than the one above so they overlap; on the outer half (front, out, back)
    for sx, bone in ((1.0, spec["pauldron_r"]), (-1.0, spec["pauldron_l"])):
        sc = c + Vector((sx * spec["shoulder"][0], spec["shoulder"][1], spec["shoulder"][2]))
        mid = 90.0 if sx > 0 else 270.0
        for lm in spec["lames"]:
            WP._append(ob, _sphere_patch(sc, lm["r"], lm["lat"][0], lm["lat"][1], mid - lm["lon"], mid + lm["lon"],
                                         lm.get("rows", 1), lm.get("facets", 7), lm.get("thick", 0.02), dents=dents[:4]),
                       bone, mat)
    for t in spec.get("tears", []):
        _tear(ob, c, r, t, mat, WP._mat_index(ob, spec.get("gash_material", "cloth-flesh"), "5a1a1c"), spec["bone"],
              rnd)
    # torn holes: a jagged ring of plate teeth peeled out over a glowing gash, on the hull or a shoulder pod (whose
    # outer edge is the front view's outline), so the outline itself breaks
    for b in spec.get("bursts", []):
        bc, br, bone = c, r, spec["bone"]
        if b.get("pod"):
            sx = 1.0 if b["pod"] == "r" else -1.0
            bc = c + Vector((sx * spec["shoulder"][0], spec["shoulder"][1], spec["shoulder"][2]))
            br = spec["lames"][int(b.get("lame", 1))]["r"]
            bone = spec["pauldron_r"] if sx > 0 else spec["pauldron_l"]
        _burst(ob, bc, br, b, WP._mat_index(ob, b.get("material", "metal-brass"), "7a6238"),
               WP._mat_index(ob, spec.get("gash_material", "cloth-flesh"), "5a1a1c"),
               WP._mat_index(ob, spec.get("hole_material", "leather-recess"), "1a120c"), bone, rnd)
    print("HULL built: %d tris in all" % sum(len(p.vertices) - 2 for p in ob.data.polygons))


def _dir(la, lo):
    la, lo = math.radians(la), math.radians(lo)
    return Vector((math.cos(la) * math.sin(lo), math.cos(la) * math.cos(lo), math.sin(la)))


def _tear(ob, c, r, t, mat, gash_mat, bone, rnd):
    """A tear in the hull: a jagged dark gash along the surface (from `at` [lat, lon] toward `to`), and a plate
    flap beside it peeled `flap` degrees out about the gash's line, so the outline breaks."""
    a, b = _dir(*t["at"]), _dir(*t["to"])
    n = int(t.get("teeth", 7))
    w = float(t.get("w", 0.02))
    bm = bmesh.new()
    top, bot = [], []
    for i in range(n + 1):
        k = i / n
        d = a.slerp(b, k).normalized()
        side = d.cross(b - a).normalized()
        ww = w * (0.35 + 0.65 * math.sin(math.pi * k)) * (1.0 if i % 2 else 0.55) * rnd.uniform(0.8, 1.2)
        p = c + d * r * 1.004
        top.append(bm.verts.new(p + side * ww))
        bot.append(bm.verts.new(p - side * ww * 0.6))
    for i in range(n):
        bm.faces.new((top[i], top[i + 1], bot[i + 1], bot[i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    for f in bm.faces:              # (the gash faces outward)
        if f.normal.dot(f.calc_center_median() - c) < 0:
            f.normal_flip()
    bmesh.ops.triangulate(bm, faces=bm.faces[:])
    WP._append(ob, bm, bone, gash_mat)
    if t.get("no_flap"):
        return
    # the flap: a small patch of plate on one side of the gash, turned out about the gash's chord
    la0, lo0 = t["at"]
    la1, lo1 = t["to"]
    off = t.get("side", [4.0, 0.0])
    fl = _sphere_patch(c, r * 1.008, min(la0, la1) + off[0], max(la0, la1) + off[0] + t.get("tall", 5.0),
                       min(lo0, lo1) + off[1], max(lo0, lo1) + off[1] + t.get("wide", 2.0), 1, 4,
                       r * 0.035)
    pa, pb = c + a * r, c + b * r
    axis = (pb - pa).normalized()
    from mathutils import Matrix
    rot = Matrix.Translation(pa) @ Matrix.Rotation(math.radians(t.get("flap", 25.0)), 4, axis) @ \
        Matrix.Translation(-pa)
    for v in fl.verts:
        v.co = rot @ v.co
    WP._append(ob, fl, bone, mat)


def _burst(ob, c, r, b, mat, gash_mat, dark_mat, bone, rnd):
    """A torn hole at `at` [lat, lon] on the sphere (c, r): a jagged glowing disc `rh` m across and `n` plate teeth
    round it, each a thick wedge from the hole's rim pointing in over it and bent `bend` degrees out of the surface;
    dark inside, the red glow only at its heart."""
    d = _dir(*b["at"])
    u = d.cross(Vector((0, 0, 1)))
    if u.length < 1e-3:
        u = d.cross(Vector((1, 0, 0)))
    u.normalize()
    v = d.cross(u).normalized()
    rh, n = float(b["rh"]), int(b.get("n", 7))
    thick = float(b.get("thick", 0.008))

    def surf(rho, a, lift=1.004):          # a point on the sphere rho m from the hole's centre, at angle a
        q = (d * r + (u * math.cos(a) + v * math.sin(a)) * rho).normalized()
        return c + q * r * lift

    # the hole: a dark fan, its rim jagged, and the red glow deep in it (a smaller fan)
    segs = n * 2
    for k_r, lift, m in ((1.0, 1.003, dark_mat), (0.5, 1.004, gash_mat)):
        bm = bmesh.new()
        mid = bm.verts.new(surf(0.0, 0.0, lift))
        ring = [bm.verts.new(surf(rh * k_r * (1.12 if k % 2 else 0.92) * rnd.uniform(0.9, 1.1), 2 * math.pi * k / segs,
                                  lift)) for k in range(segs)]
        for k in range(segs):
            bm.faces.new((mid, ring[k], ring[(k + 1) % segs]))
        for f in bm.faces:
            if f.normal.dot(d) < 0:
                f.normal_flip()
        WP._append(ob, bm, bone, m)
    # the teeth
    bend = math.radians(float(b.get("bend", 45.0)))
    for k in range(n):
        a = 2 * math.pi * (k + rnd.uniform(-0.2, 0.2)) / n
        w = math.pi / n * rnd.uniform(0.7, 0.95)
        p0, p1 = surf(rh * 1.05, a - w, 1.006), surf(rh * 1.05, a + w, 1.006)
        base = (p0 + p1) * 0.5
        nrm = (base - c).normalized()
        e = (base - (c + d * r)).normalized()
        e = (e - nrm * e.dot(nrm)).normalized()
        L = rh * rnd.uniform(0.6, 1.15)
        bk = bend * rnd.uniform(0.7, 1.25)
        tip = base - e * L * math.cos(bk) + nrm * L * math.sin(bk)
        bm = bmesh.new()
        top = [bm.verts.new(p) for p in (p0, p1, tip)]
        bot = [bm.verts.new(p - nrm * thick) for p in (p0, p1, tip)]
        bm.faces.new(top)
        bm.faces.new(bot[::-1])
        for i in range(3):
            j = (i + 1) % 3
            bm.faces.new((top[i], bot[i], bot[j], top[j]))
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
        bmesh.ops.triangulate(bm, faces=bm.faces[:])
        WP._append(ob, bm, bone, mat)


def hull_box(ob, material):
    """The bounds of the faces painted `material` (the hull): min and max corners."""
    mi = [i for i, m in enumerate(ob.data.materials) if m and m.name == material][0]
    co = np.array([ob.data.vertices[v].co[:] for p in ob.data.polygons if p.material_index == mi for v in p.vertices])
    return co.min(axis=0), co.max(axis=0)


def image_box(path, tol=0.06):
    """The bounds (0..1, v up) of what is not the background in an image of the hull on flat grey."""
    im = bpy.data.images.load(path, check_existing=True)
    w, h = im.size
    px = np.array(im.pixels[:], dtype=np.float32).reshape(h, w, 4)[:, :, :3]
    grey = px[5:25, 5:25].reshape(-1, 3).mean(axis=0)
    fg = np.abs(px - grey).max(axis=2) > tol
    ys, xs = np.nonzero(fg)
    # the background filled with the hull's own middle colour: a face no view quite covers (a plate's underside,
    # an edge past the drawn outline) takes plain brass, not the sheet's grey
    full = np.array(im.pixels[:], dtype=np.float32).reshape(h, w, 4)
    full[~fg, :3] = np.median(px[fg], axis=0) * 0.85
    im.pixels = full.ravel()
    im.pack()
    return im, (xs.min() / w, ys.min() / h, xs.max() / w, ys.max() / h)


def projection(ob, spec):
    """The `project` recipe warden_paint bakes: per view its image and the linear map from the hull's bounds in
    that view onto the hull's bounds in the image (u = a * axis + b, v = c * z + d)."""
    lo, hi = hull_box(ob, spec["material"])
    out = {}
    for view, axis, flip in (("front", 0, True), ("back", 0, False), ("side", 1, True)):
        if view not in spec["project"]:
            continue
        img, (u0, v0, u1, v1) = image_box(os.path.expanduser(spec["project"][view]))
        pad = spec.get("project_pad", {}).get(view, [0, 0, 0, 0])
        u0, v0, u1, v1 = u0 + pad[0], v0 + pad[1], u1 + pad[2], v1 + pad[3]
        a = (u1 - u0) / (hi[axis] - lo[axis])
        if flip:
            a, b = -a, u0 + hi[axis] * a
        else:
            b = u0 - lo[axis] * a
        cz = (v1 - v0) / (hi[2] - lo[2])
        out[view] = {"image": img, "axis": axis, "u": (a, b), "v": (cz, v0 - lo[2] * cz)}
    return out


def _tube(pts, r, segs=6, thin=True):
    """A thin tube through the points (a tar strand: thinner in the middle unless `thin` is off)."""
    bm = bmesh.new()
    rings = []
    for i, p in enumerate(pts):
        t = (pts[min(i + 1, len(pts) - 1)] - pts[max(i - 1, 0)]).normalized()
        u = t.cross(Vector((0, 0, 1)))
        if u.length < 1e-3:
            u = t.cross(Vector((1, 0, 0)))
        u.normalize()
        v = t.cross(u)
        k = 1.0 - 0.45 * math.sin(math.pi * i / (len(pts) - 1)) if thin else 1.0      # (tar stretches thin)
        rings.append([bm.verts.new(p + (u * math.cos(2 * math.pi * j / segs) + v * math.sin(2 * math.pi * j / segs))
                                   * r * k) for j in range(segs)])
    for a, b in zip(rings, rings[1:]):
        for j in range(segs):
            bm.faces.new((a[j], a[(j + 1) % segs], b[(j + 1) % segs], b[j]))
    bmesh.ops.triangulate(bm, faces=bm.faces[:])
    return bm


def extras(ob, spec, seed=1):
    """The rest of the dressing (fit frame), each piece rigid on its bone:
    - `cracks`: sharp cracks over a lens dome (centre, radius R, the crack ends' radial reach [from, to]),
      zig-zag strips lying just over the glass;
    - `shines`: small glossy highlights (a sphere on a glow slot);
    - `strands`: tar strands sagging between two points;
    - `pool`: a puddle of tar on the ground (on its own bone, which the kit hides off the ground);
    - `glows`: emissive cores (the red light inside the hull)."""
    rnd = random.Random(seed)
    cr = spec.get("cracks")
    if cr:
        C, R = Vector(cr["centre"]), float(cr["R"])
        mat = WP._mat_index(ob, cr["material"], cr["colour"])
        bm = bmesh.new()
        for k in range(int(cr["n"])):
            ang = 2 * math.pi * k / cr["n"] + rnd.uniform(-0.35, 0.35)
            r0, r1 = cr["reach"]
            prev = None
            steps = 5
            for s in range(steps + 1):
                d = r0 + (r1 - r0) * s / steps
                a = ang + rnd.uniform(-0.18, 0.18)
                x, z = math.cos(a) * d, math.sin(a) * d
                y = C.y + math.sqrt(max(R * R - x * x - z * z, 0.0)) + 0.0015
                ov = cr.get("over")
                if ov and d < ov["r"]:          # (across the glass in front of the orb, not on it)
                    y = max(y, ov["y"] - 0.006 * (d / ov["r"]) ** 2)
                w = cr["w"] * (1.0 - 0.7 * s / steps)
                side = Vector((-math.sin(a), 0, math.cos(a))) * w
                p = Vector((C.x + x, y, C.z + z))
                cur = (bm.verts.new(p + side), bm.verts.new(p - side))
                if prev:
                    bm.faces.new((prev[0], prev[1], cur[1], cur[0]))
                prev = cur
        for f in bm.faces:
            if f.normal.y < 0:
                f.normal_flip()
        bmesh.ops.triangulate(bm, faces=bm.faces[:])
        WP._append(ob, bm, cr["bone"], mat)
    for sh in spec.get("shines", []):
        WP.add_orb(ob, sh)
    for g in spec.get("glows", []):
        WP.add_orb(ob, g)
    for j in spec.get("joints", []):          # ball joints seating a limb in its socket
        WP.add_orb(ob, {"at": j["at"], "r": j["r"], "bone": j["bone"], "material": j["material"],
                        "colour": j.get("colour", "4c4844")})
    tar = None
    for st in spec.get("strands", []):
        tar = WP._mat_index(ob, st["material"], st.get("colour", "1a1416"))
        a, b = Vector(st["a"]), Vector(st["b"])
        pts = [a.lerp(b, i / 8) + Vector((0, 0, -st["sag"] * 4 * (i / 8) * (1 - i / 8))) for i in range(9)]
        WP._append(ob, _tube(pts, st["r"]), st["bone"], tar)
    pl = spec.get("pool")
    if pl:
        mat = WP._mat_index(ob, pl["material"], pl.get("colour", "1a1416"))
        bm = bmesh.new()
        n = int(pl.get("segs", 28))
        mid = bm.verts.new((pl["at"][0], pl["at"][1], pl.get("z", 0.004)))
        ring = []
        for i in range(n):
            a = 2 * math.pi * i / n
            rr = pl["r"] * (0.75 + 0.25 * math.sin(3 * a + 1.3) + rnd.uniform(-0.08, 0.08))
            ring.append(bm.verts.new((pl["at"][0] + math.cos(a) * rr, pl["at"][1] + math.sin(a) * rr * 0.8,
                                      pl.get("z", 0.004))))
        for i in range(n):
            bm.faces.new((mid, ring[i], ring[(i + 1) % n]))
        WP._append(ob, bm, pl["bone"], mat)
    # on the hull's surface (centre, r): tar runs down it, raised plates (a hatch), pipes standing off it
    hc, hr = Vector(spec.get("hull_centre", (0, 0, 0))), float(spec.get("hull_r", 0.0))

    def on(la, lo, off=0.0):
        return hc + _dir(la, lo) * hr * (1.0 + off)

    for rn in spec.get("runs", []):
        tar = WP._mat_index(ob, rn["material"], rn.get("colour", "1a1416"))
        la0, lo = rn["at"]
        la1 = rn.get("to", -62.0)
        pts = [on(la0 + (la1 - la0) * i / 6, lo + rnd.uniform(-1.5, 1.5), 0.012) for i in range(7)]
        last = pts[-1]
        pts += [last + Vector((0, 0, -rn["hang"] * k / 2)) for k in (1, 2)]
        WP._append(ob, _tube(pts, rn["r"], 5), rn["bone"], tar)
        if rn.get("bulb"):          # (a heavy run ends in a drop: the art's big black drips read at the match camera)
            WP.add_orb(ob, {"at": tuple(pts[-1] + Vector((0, 0, -rn["r"] * 0.6))), "r": rn["r"] * float(rn["bulb"]),
                            "bone": rn["bone"], "material": rn["material"], "colour": rn.get("colour", "1a1416")})
    for pl in spec.get("plates", []):
        mat = WP._mat_index(ob, pl["material"], pl.get("colour", "6c6762"))
        WP._append(ob, _sphere_patch(hc, hr * (1.0 + pl["off"]), pl["lat"][0], pl["lat"][1], pl["lon"][0], pl["lon"][1],
                                     1, pl.get("nlon", 3), hr * pl["thick"]), pl["bone"], mat)
    for pp in spec.get("pipes", []):
        mat = WP._mat_index(ob, pp["material"], pp.get("colour", "6c6762"))
        ctrl = [on(la, lo, off) for la, lo, off in pp["path"]]
        pts = []
        for a, b in zip(ctrl, ctrl[1:]):
            pts += [a.lerp(b, k / 4) for k in range(4)]
        pts.append(ctrl[-1])
        bm = _tube(pts, pp["r"], 8, thin=False)
        WP._append(ob, bm, pp["bone"], mat)
    for row in spec.get("rivet_rows", []):          # rivet heads along the plate bands
        mat = WP._mat_index(ob, row.get("material", "metal-iron"), "4c4844")
        lo0, lo1 = row.get("lon", [0, 360])
        for k in range(int(row["n"])):
            lo = lo0 + (lo1 - lo0) * (k + 0.5) / row["n"]
            bm = bmesh.new()
            bmesh.ops.create_icosphere(bm, subdivisions=int(row.get("subdiv", 0)), radius=row["r"])
            for v in bm.verts:
                v.co.z *= 0.6
            p0 = on(row["lat"], lo, row["off"] + 0.01)
            n0 = _dir(row["lat"], lo)
            rot = Vector((0, 0, 1)).rotation_difference(n0).to_matrix()
            for v in bm.verts:
                v.co = p0 + rot @ v.co
            WP._append(ob, bm, row.get("bone", "hips"), mat)
    hm = spec.get("helm")
    if hm:
        _helm(ob, hm, hc, hr)
    print("HULL extras: %d tris in all" % sum(len(p.vertices) - 2 for p in ob.data.polygons))


def _lathe(profile, origin, axis, segs, cap=False):
    """A surface of revolution: `profile` [(radius, distance along the axis)] turned about `axis` from `origin`."""
    axis = Vector(axis).normalized()
    u = axis.cross(Vector((0, 0, 1)))
    if u.length < 1e-3:
        u = axis.cross(Vector((1, 0, 0)))
    u.normalize()
    v = axis.cross(u)
    bm = bmesh.new()
    rings = []
    for rad, along in profile:
        rings.append([bm.verts.new(Vector(origin) + axis * along + (u * math.cos(2 * math.pi * k / segs)
                                                                    + v * math.sin(2 * math.pi * k / segs)) * rad)
                      for k in range(segs)])
    for a, b in zip(rings, rings[1:]):
        for k in range(segs):
            bm.faces.new((a[k], a[(k + 1) % segs], b[(k + 1) % segs], b[k]))
    if cap:
        bm.faces.new(rings[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    bmesh.ops.triangulate(bm, faces=bm.faces[:])
    return bm


def _helm(ob, hm, hc, hr):
    """The porthole helm: a brass collar from the hull out to one riveted lip round the lens, dark in its recess,
    and the small grilled port beside it (the art's helm, in place of the source's stacked rings)."""
    c = Vector(hm["centre"])
    ax = Vector((0, 1, 0))
    brass = WP._mat_index(ob, hm["material"], hm.get("colour", "a88a4e"))
    dark = WP._mat_index(ob, hm["recess_material"], hm.get("recess_colour", "201814"))
    R, lip, inner = hm["R"], hm["lip"], hm["inner"]
    y0, y1 = hm["y0"], hm["y1"]
    prof = [(R * 0.96, y0 - c.y), (R, y1 - c.y - 0.012), (lip, y1 - c.y - 0.004), (lip * 0.97, y1 - c.y + 0.006),
            (R * 0.9, y1 - c.y + 0.01), (inner, y1 - c.y + 0.004)]
    WP._append(ob, _lathe(prof, c, ax, int(hm.get("segs", 24))), hm["bone"], brass)
    WP._append(ob, _lathe([(inner, y1 - c.y + 0.004), (inner * 0.98, y1 - c.y - 0.02), (0.002, y1 - c.y - 0.022)],
                          c, ax, 16), hm["bone"], dark)
    if hm.get("lens_material"):          # (a whole lens dome: the source's decimated glass had holes)
        glass = WP._mat_index(ob, hm["lens_material"], "8c949c")
        WP._append(ob, _lathe([(inner, y1 - c.y + 0.004), (inner * 0.72, y1 - c.y + 0.012), (0.002, y1 - c.y + 0.016)],
                              c, ax, 20), hm["bone"], glass)
    n = int(hm.get("rivets", 8))
    for k in range(n):
        a = 2 * math.pi * (k + 0.5) / n
        p = c + Vector((math.cos(a), 0, math.sin(a))) * (R * 0.5 + lip * 0.5) + Vector((0, y1 - c.y + 0.008, 0))
        bm = bmesh.new()
        bmesh.ops.create_icosphere(bm, subdivisions=0, radius=hm.get("rivet_r", 0.006))
        for v in bm.verts:
            v.co += p
        WP._append(ob, bm, hm["bone"], brass)
    pt = hm.get("port")
    if pt:
        d = _dir(*pt["at"])
        base = hc + d * hr * 0.97
        r = pt["r"]
        WP._append(ob, _lathe([(r * 1.05, 0.0), (r * 1.1, 0.03), (r * 1.25, 0.036), (r * 1.15, 0.046), (r * 0.85, 0.044)],
                              base, d, 16), hm["bone"], brass)
        pdk = hm.get("port_dark")
        pd = WP._mat_index(ob, pdk["material"], pdk["colour"]) if pdk else dark
        WP._append(ob, _lathe([(r * 0.85, 0.044), (0.002, 0.036)], base, d, 12), hm["bone"], pd)
        # the grille: three bars across it
        u = d.cross(Vector((0, 0, 1))).normalized()
        w = d.cross(u)
        for k in (-1, 0, 1):
            bm = bmesh.new()
            bmesh.ops.create_cube(bm, size=1.0)
            for v in bm.verts:
                v.co = base + d * 0.044 + u * (v.co.x * r * 1.7) + w * (v.co.y * 0.006 + k * r * 0.5) + d * v.co.z * 0.006
            WP._append(ob, bm, hm["bone"], brass)
