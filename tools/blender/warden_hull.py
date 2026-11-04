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
        dents.append((d, math.radians(rnd.uniform(7, 15)), rnd.uniform(0.02, 0.05)))
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
                                         1, lm.get("facets", 7), lm.get("thick", 0.02), dents=dents[:4]), bone, mat)
    for t in spec.get("tears", []):
        _tear(ob, c, r, t, mat, WP._mat_index(ob, spec.get("gash_material", "cloth-flesh"), "5a1a1c"), spec["bone"],
              rnd)
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
    ys, xs = np.nonzero(np.abs(px - grey).max(axis=2) > tol)
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
