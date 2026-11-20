"""A thin cloth shell's inside, for tools/art1/v95_swap.py's `lining` spec key (docs in add_lining)."""
import bmesh
import numpy as np

F = np.float32


def hsv(rgb):
    """(hue, saturation, value) arrays of [n, 3] rgb in 0..1."""
    mx, mn = rgb.max(1), rgb.min(1)
    d = np.maximum(mx - mn, 1e-6)
    r, g, b = rgb.T
    h = np.where(mx == r, ((g - b) / d) % 6, np.where(mx == g, (b - r) / d + 2, (r - g) / d + 4)) / 6
    return h, (mx - mn) / np.maximum(mx, 1e-6), mx


def verts(ob):
    a = np.empty(len(ob.data.vertices) * 3)
    ob.data.vertices.foreach_get("co", a)
    return a.reshape(-1, 3)


def face_paint(me):
    """[faces, 3] hue, saturation, value of each face's paint (its UV centre in its material's image)."""
    imgs = []
    for m in me.materials:
        node = next((n for n in m.node_tree.nodes if n.type == "TEX_IMAGE"), None) if m.node_tree else None
        imgs.append(node.image if node else None)
    uv = np.empty(len(me.loops) * 2, F)
    me.uv_layers["UVMap"].data.foreach_get("uv", uv)
    uv = uv.reshape(-1, 2) % 1.0
    ls = np.empty(len(me.polygons), np.int32)
    lt = np.empty(len(me.polygons), np.int32)
    mi = np.empty(len(me.polygons), np.int32)
    me.polygons.foreach_get("loop_start", ls)
    me.polygons.foreach_get("loop_total", lt)
    me.polygons.foreach_get("material_index", mi)
    c = np.add.reduceat(uv, ls, axis=0) / lt[:, None]
    rgb = np.zeros((len(ls), 3), F)
    for k, img in enumerate(imgs):
        m = mi == k
        if img is None or not m.any():
            continue
        w, h = img.size
        px = np.empty(w * h * 4, F)
        img.pixels.foreach_get(px)
        px = px.reshape(h, w, 4)[..., :3]
        rgb[m] = px[np.clip((c[m, 1] * h).astype(int), 0, h - 1), np.clip((c[m, 0] * w).astype(int), 0, w - 1)]
    return np.stack(hsv(rgb), 1)


def add_lining(low, rules):
    """`lining` [{"box": [x0, x1, y0, y1, z0, z1], "h": [lo, hi] (a range may wrap: lo > hi), "s": [lo, hi], "v": [lo, hi],
    "inset": m, "skip_bones": [prefix, ...]}]: every face whose centre is in the box and whose paint is in the ranges gets a twin, wound the other way and
    `inset` m inside it, with the same paint and weights. The toon outline is an inverted hull, so a face that shows its back
    to the camera draws black: a loincloth is a thin shell, and from behind and low the inside of its far panel showed
    through the gap under the hem as a black hole; the twin is that inside, drawn as cloth. Its ink room is 0. A rule with no
    paint ranges lines every face in its box (but faces with a vertex led by a skip_bones bone) (Grimble's crotch: cloth faces painted skin-dark showed their backs)."""
    me = low.data
    hsv_f = face_paint(me)
    V = verts(low)
    cen = np.array([V[list(p.vertices)].mean(0) for p in me.polygons])
    gname = {g.index: g.name for g in low.vertex_groups}
    top = [gname[max(v.groups, key=lambda e: e.weight).group] if len(v.groups) else "" for v in me.vertices]
    bm = bmesh.new()
    bm.from_mesh(me)
    bm.faces.ensure_lookup_table()
    col = bm.verts.layers.float_color["Col"]
    done = np.zeros(len(cen), bool)     # (a face in two rules' boxes gets one twin)
    for r in rules:
        b = r["box"]
        m = (cen[:, 0] >= b[0]) & (cen[:, 0] <= b[1]) & (cen[:, 1] >= b[2]) & (cen[:, 1] <= b[3]) & (cen[:, 2] >= b[4]) & (cen[:, 2] <= b[5])
        for i, key in enumerate("hsv"):
            if key in r:
                lo, hi = r[key]
                m &= (hsv_f[:, i] >= lo) & (hsv_f[:, i] <= hi) if lo <= hi else (hsv_f[:, i] >= lo) | (hsv_f[:, i] <= hi)
        if r.get("skip_bones"):     # (a face on a thigh is closed skin: its twin is never seen, and its inset pinches)
            skip = np.array([any(top[i].startswith(b) for b in r["skip_bones"]) for i in range(len(top))])
            m &= ~np.array([skip[list(p.vertices)].any() for p in me.polygons])
        m &= ~done
        done |= m
        bm.faces.ensure_lookup_table()
        faces = [bm.faces[i] for i in np.nonzero(m)[0]]
        dup = bmesh.ops.duplicate(bm, geom=faces)["geom"]
        twin = [g for g in dup if isinstance(g, bmesh.types.BMFace)]
        bmesh.ops.reverse_faces(bm, faces=twin)
        bm.normal_update()
        for v in {v for f in twin for v in f.verts}:
            v.co += v.normal * float(r.get("inset", 0.004))
            c = v[col]
            v[col] = (c[0], c[1], c[2], 0.0)
        print("SWAP lining: %d faces" % len(twin), flush=True)
    bm.to_mesh(me)
    bm.free()
    me.update()
