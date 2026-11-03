"""Shared building blocks for the hand-made expedition maps (tools/make_hollowcrown.py, tools/make_riven.py).

A map script lists its islands, bridges, exits and lairs as plain data, wraps them in a Map and calls
the helpers here: shape tests, bridge ends pulled to the rims, a tile model (rasterize) for checks and
the preview, the layout checks, and the hiding cover (place_cover: per-biome shares from
content/rules/keys.json, planted as patches with a fixed seed, so a run always writes the same map).
The format the engine reads is described in tools/make_hollowcrown.py.
"""
import json, math, os, random

LEVEL = 0.8
DIRS = {"n": (0, -1), "s": (0, 1), "e": (1, 0), "w": (-1, 0)}


class Map:
    """One map's data: the lists the helpers below read. Bridges and exits can be filled in later."""
    def __init__(self, size, islands, bridges=(), docks=(), outposts=(), hatches=(), lairs=(), glides=()):
        self.size = size
        self.islands = islands
        self.by = {d["id"]: d for d in islands}
        self.bridges = list(bridges)
        self.docks = list(docks)
        self.outposts = list(outposts)
        self.hatches = list(hatches)
        self.lairs = list(lairs)
        self.glides = list(glides)
        self.inisle = {}


# ------------------------------------------------------------------ shapes
def poly(pts, lv=0, **k):
    return dict(poly=[list(p) for p in pts], lv=lv, **k)

def circle(x, z, r, lv=0, **k):
    return dict(circle=[x, z], r=r, lv=lv, **k)

def ramp(x, z, d, w, lv0, lv1, run=1):
    return dict(at=[x, z], dir=d, w=w, **{"from": lv0}, to=lv1, run=run)

def rocks(*rects):
    return [list(r) for r in rects]

def thickets(*at):
    """Trees come in groves of three, never alone: a lone tree is a post a throw can clip."""
    return [[x + dx, z + dz] for x, z in at for dx, dz in ((0, 0), (1, 0), (0, 1))]

def shape_d(S, x, z):
    if "circle" in S:
        cx, cz = S["circle"]; return math.hypot(x - cx, z - cz) / S["r"]
    if "poly" in S:
        P = S["poly"]
        inside = False; dmin = 1e9
        n = len(P)
        for i in range(n):
            ax, az = P[i]; bx, bz = P[(i + 1) % n]
            if (az > z) != (bz > z) and x < (bx - ax) * (z - az) / (bz - az) + ax:
                inside = not inside
            vx, vz = bx - ax, bz - az; L2 = vx * vx + vz * vz
            t = max(0, min(1, ((x - ax) * vx + (z - az) * vz) / L2)) if L2 else 0
            dmin = min(dmin, math.hypot(x - ax - vx * t, z - az - vz * t))
        return 1.0 - min(dmin, 6.0) / 6.0 if inside else 1.0 + dmin / 6.0
    return 99

def shape_box(S):
    """[x0, z0, x1, z1] around a shape (whole tiles)."""
    if "circle" in S:
        cx, cz = S["circle"]; r = S["r"]
        return [int(cx - r) - 1, int(cz - r) - 1, int(cx + r) + 2, int(cz + r) + 2]
    xs = [p[0] for p in S["poly"]]; zs = [p[1] for p in S["poly"]]
    return [int(min(xs)) - 1, int(min(zs)) - 1, int(max(xs)) + 2, int(max(zs)) + 2]

def base_level(M, iid, x, z):
    lv = -1
    for S in M.by[iid]["shapes"]:
        if shape_d(S, x, z) < 1.0: lv = max(lv, S.get("lv", 0))
    return lv

def inside(M, iid, x, z, margin=0.0):
    return shape_d(M.by[iid]["shapes"][0], x, z) < 1.0 - margin

def bridge(M, name, a, b, p0, p1, r, dig=2.5):
    """A bridge along p0 -> p1: the ends are pulled to the rims, then pushed a little way inside."""
    (x0, z0), (x1, z1) = p0, p1
    L = math.hypot(x1 - x0, z1 - z0); ux, uz = (x1 - x0) / L, (z1 - z0) / L
    t_a = 0.0; t = 0.0
    while t < L:
        if inside(M, a, x0 + ux * t, z0 + uz * t, 0.02): t_a = t
        t += 0.25
    t_b = L; t = t_a + 0.5
    while t <= L:
        if inside(M, b, x0 + ux * t, z0 + uz * t, 0.02): t_b = t; break
        t += 0.25
    fa = (round(x0 + ux * (t_a - dig), 1), round(z0 + uz * (t_a - dig), 1))
    fb = (round(x0 + ux * (t_b + dig), 1), round(z0 + uz * (t_b + dig), 1))
    assert inside(M, a, *fa) and inside(M, b, *fb), (name, fa, fb)
    return dict(name=name, a=a, b=b, **{"from": list(fa)}, to=list(fb), r=r, span=round(t_b - t_a, 1))

# ------------------------------------------------------------------ a tile model, for checks and the preview
def rasterize(M):
    lv = {}; owner = {}; stairs = {}
    for d in M.islands:
        x0, z0, x1, z1 = shape_box(d["shapes"][0])
        for z in range(max(0, z0), min(M.size, z1)):
            for x in range(max(0, x0), min(M.size, x1)):
                if (x, z) in lv: continue
                if shape_d(d["shapes"][0], x + 0.5, z + 0.5) >= 1.0: continue
                l = base_level(M, d["id"], x + 0.5, z + 0.5)
                lv[(x, z)] = l; owner[(x, z)] = d["id"]
    for d in M.islands:
        for R in d.get("ramps", []):
            dx, dz = DIRS[R["dir"]]; sx, sz = -dz, dx
            n = (R["to"] - R["from"]) * R.get("run", 1)
            for k in range(n):
                step = k // R.get("run", 1); stair = (k % R.get("run", 1)) == 0
                l = R["from"] + step + (0 if stair else 1)
                for s in range(-(R["w"] // 2), R["w"] - R["w"] // 2):
                    q = (R["at"][0] + dx * k + sx * s, R["at"][1] + dz * k + sz * s)
                    assert q in lv and owner[q] == d["id"], ("ramp off its island", d["id"], q)
                    lv[q] = l
                    if stair: stairs[q] = (dx, dz)
                    else: stairs.pop(q, None)
            for back in (1, 2, 3):      # room to walk onto the bottom step: 3 tiles of ground at its foot
                foot = (R["at"][0] - dx * back, R["at"][1] - dz * back)
                assert lv.get(foot) == R["from"], ("ramp foot not on open ground", d["id"], R, foot, lv.get(foot))
            top = (R["at"][0] + dx * n, R["at"][1] + dz * n)
            assert lv.get(top) == R["to"], ("ramp doesn't land on its plateau", d["id"], R, lv.get(top))
    for B in M.bridges:
        (x0, z0), (x1, z1) = B["from"], B["to"]
        L = math.hypot(x1 - x0, z1 - z0)
        for z in range(int(min(z0, z1) - B["r"] - 1), int(max(z0, z1) + B["r"] + 2)):
            for x in range(int(min(x0, x1) - B["r"] - 1), int(max(x0, x1) + B["r"] + 2)):
                px, pz = x + 0.5, z + 0.5
                t = max(0, min(1, ((px - x0) * (x1 - x0) + (pz - z0) * (z1 - z0)) / (L * L)))
                if math.hypot(px - x0 - (x1 - x0) * t, pz - z0 - (z1 - z0) * t) > B["r"] or (x, z) in lv: continue
                lv[(x, z)] = -2; owner[(x, z)] = B["a"]
    return lv, owner, stairs

def check(M, lv, owner, stairs):
    probs = []
    def ground(p, what):
        q = (int(p[0]), int(p[1]))
        if q not in lv: probs.append("%s %s not on ground" % (what, p))
        elif q in stairs: probs.append("%s %s on a stair" % (what, p))
    for d in M.islands:
        for k in ["landings", "chests", "camps", "breakables", "weapons", "wild", "wardens", "traps"]:
            for p in d.get(k, []): ground(p, "%s.%s" % (d["id"], k))
    for L in M.lairs:
        cx, cz = L["at"]; h = L["half"]
        lvs = set(); own = set()
        for z in range(cz - h - 2, cz + h + 3):
            for x in range(cx - h - 2, cx + h + 3):
                if (x, z) not in lv: probs.append("lair %s over the void at %s" % (L["id"], (x, z))); break
                lvs.add(lv[(x, z)]); own.add(owner[(x, z)])
        if len(own) > 1: probs.append("lair %s spans islands %s" % (L["id"], own))
    # Warden posts keep clear of camps and exits (9 m) and landings (8 m), as the Blight wants
    camps = [c for d in M.islands for c in d.get("camps", [])]
    lands = [c for d in M.islands for c in d.get("landings", [])]
    exits = [e[:2] for e in M.docks + M.outposts + M.hatches]
    for d in M.islands:
        for wp in d.get("wardens", []):
            for lst, r, what in ((camps, 9, "camp"), (exits, 9, "exit"), (lands, 8, "landing")):
                for q in lst:
                    if math.hypot(wp[0] - q[0], wp[1] - q[1]) < r: probs.append("warden %s too close to %s %s" % (wp, what, q[:2]))
    for B in M.bridges:
        assert owner.get((int(B["from"][0]), int(B["from"][1]))) == B["a"], B
    return probs

def gap(a, b, owner):
    A = [p for p, o in owner.items() if o == a]; B = [p for p, o in owner.items() if o == b]
    edgeA = [p for p in A if any((p[0] + dx, p[1] + dz) not in owner for dx, dz in DIRS.values())]
    edgeB = [p for p in B if any((p[0] + dx, p[1] + dz) not in owner for dx, dz in DIRS.values())]
    return min(math.hypot(p[0] - q[0], p[1] - q[1]) for p in edgeA[::2] for q in edgeB[::2])

def measure_glides(M, lv, owner):
    own = {p: o for p, o in owner.items() if lv[p] != -2}
    for G in M.glides:
        G["gap"] = round(gap(G["a"], G["b"], own), 1)

TINT = {"gloom": (120, 100, 160), "storm": (110, 130, 170), "ember": (200, 120, 80), "frost": (200, 220, 235),
        "bloom": (110, 190, 110), "meadow": (140, 190, 90)}

def preview(M, path, lv, owner, stairs, scale=4, extra=None):
    """A painted plan of the map: biomes by height, stairs, cover, loot, camps, lairs, exits, glides.
    extra(draw, scale) draws anything else on top (the sky train)."""
    from PIL import Image, ImageDraw
    S = scale
    img = Image.new("RGB", (M.size * S, M.size * S), (24, 26, 40))
    dr = ImageDraw.Draw(img)
    for (x, z), l in lv.items():
        if l == -2:
            c = (150, 145, 140)
        else:
            b = TINT.get(M.by[owner[(x, z)]].get("biome", ""), (150, 150, 150))
            k = 0.45 + l * 0.065
            c = tuple(min(255, int(v * k)) for v in b)
        if (x, z) in stairs: c = (230, 210, 150)
        dr.rectangle([x * S, z * S, x * S + S - 1, z * S + S - 1], fill=c)
    for d in M.islands:
        for R in d.get("rocks", []):
            dr.rectangle([R[0] * S, R[1] * S, (R[2] + 1) * S - 1, (R[3] + 1) * S - 1], fill=(70, 70, 70))
        for t in d.get("trees", []):
            dr.ellipse([t[0] * S, t[1] * S, t[0] * S + S, t[1] * S + S], fill=(30, 90, 40))
        for b in d.get("bush", []):
            for q in _disc(b[0], b[1], b[2]):
                dr.rectangle([q[0] * S, q[1] * S, q[0] * S + S - 1, q[1] * S + S - 1], fill=(30, 140, 50))
        for c in d.get("chests", []):
            dr.rectangle([c[0] * S, c[1] * S, c[0] * S + S, c[1] * S + S], fill=(255, 215, 0))
        for c in d.get("landings", []):
            dr.ellipse([c[0] * S - 3, c[1] * S - 3, c[0] * S + 3, c[1] * S + 3], outline=(255, 255, 255))
        for c in d.get("camps", []):
            dr.ellipse([c[0] * S - 3, c[1] * S - 3, c[0] * S + 3, c[1] * S + 3], fill=(220, 40, 40))
        for c in d.get("wardens", []):
            dr.ellipse([c[0] * S - 2, c[1] * S - 2, c[0] * S + 2, c[1] * S + 2], fill=(160, 0, 200))
        dr.text((d["poi"][0] * S - 20, d["poi"][1] * S), d["name"], fill=(255, 255, 255))
    for L in M.lairs:
        cx, cz = L["at"]; h = L["half"]
        dr.rectangle([(cx - h) * S, (cz - h) * S, (cx + h + 1) * S, (cz + h + 1) * S], outline=(255, 80, 60), width=2)
    for o in M.outposts:
        dr.rectangle([o[0] * S - 6, o[1] * S - 6, o[0] * S + 6, o[1] * S + 6], outline=(120, 255, 200), width=2)
    for o in M.docks:
        dr.rectangle([o[0] * S - 5, o[1] * S - 5, o[0] * S + 5, o[1] * S + 5], outline=(120, 200, 255), width=2)
    for G in M.glides:
        dr.line([G["take"][0] * S, G["take"][1] * S, G["land"][0] * S, G["land"][1] * S], fill=(255, 255, 120), width=1)
    if extra: extra(dr, S)
    img.save(path)

# ------------------------------------------------------------------ hiding cover
# The tall grass is computed, not listed by hand (docs/decisions/0009-keys-and-cover.md). Each biome has
# a share of its walkable ground to cover (content/rules/keys.json "cover"): bloom a lot, meadow some,
# gloom a little, storm and ember less, frost almost none. Cover comes as PATCHES of 3-6 overlapping
# clumps, put where a fight wants it: beside chests and camps, along the flanks of the lanes between
# landmarks, at cliff edges and bridge heads, around the heart's pillars, and in sight of every way out
# in the bush biomes. Nothing grows on stairs, ramps, bridges, landing drop circles, lair floors or
# across a lane: lanes keep a clear corridor. The seed is fixed, so a map is the same every run.
BUSH_BIOMES = ("bloom", "meadow", "gloom", "storm")     # where Shrublings may live: also where exits get cover
COVER = {   # share of the biome's ground (inside the keys.json range), clump radius, clumps per patch, smallest patch worth planting (tiles), long bands along lanes?
    "bloom":  dict(share=0.18, r=(2.2, 3.2), n=(5, 6), least=40, band=False, gap=2, sp=0.88),
    "meadow": dict(share=0.1, r=(1.4, 2.0), n=(4, 6), least=14, band=True, gap=2),
    "gloom":  dict(share=0.06, r=(1.3, 1.9), n=(3, 5), least=10, band=False, gap=2),
    "storm":  dict(share=0.03, r=(1.1, 1.6), n=(3, 4), least=8, band=False, gap=2),
    "ember":  dict(share=0.024, r=(1.0, 1.5), n=(3, 3), least=6, band=False, gap=2),
    "frost":  dict(share=0.004, r=(0.9, 1.2), n=(3, 3), least=3, band=False, gap=2),
}
LANE_HALF = 1.7         # a lane keeps this much clear on each side of its centre line
LANDING_R = 5.5         # squads come down inside this circle: no cover
EXIT_R = {"dock": 3.5, "outpost": 5.5, "hatch": 3.5}
SIGHT_R = 13.0          # a patch this close, in a clear line, is "in sight" of a way out

def targets():
    p = os.path.join(os.path.dirname(__file__), "..", "content", "rules", "keys.json")
    with open(p) as f:
        return json.load(f)["cover"]["biome_targets"]

def _disc(cx, cz, r, jitter=0.05):
    out = set()
    for z in range(int(cz - r - 1), int(cz + r + 2)):
        for x in range(int(cx - r - 1), int(cx + r + 2)):
            if math.hypot(x + 0.5 - cx, z + 0.5 - cz) <= r + jitter: out.add((x, z))
    return out

def _disc_r(cx, cz, r):
    return _disc(cx, cz, r, 0.0)

def _seg_dist(px, pz, a, b):
    vx, vz = b[0] - a[0], b[1] - a[1]; L2 = vx * vx + vz * vz
    t = max(0.0, min(1.0, ((px - a[0]) * vx + (pz - a[1]) * vz) / L2)) if L2 else 0.0
    return math.hypot(px - a[0] - vx * t, pz - a[1] - vz * t)

def _wall_tiles(W):
    out = set()
    if "line" in W:
        x0, z0, x1, z1 = W["line"]
        for x in range(min(x0, x1), max(x0, x1) + 1):
            for z in range(min(z0, z1), max(z0, z1) + 1): out.add((x, z))
    elif "box" in W:
        x0, z0, x1, z1 = W["box"]
        for x in range(x0, x1 + 1):
            for z in range(z0, z1 + 1):
                if x in (x0, x1) or z in (z0, z1): out.add((x, z))
    elif "ring" in W:
        cx, cz, r = W["ring"][:3]
        out |= {q for q in _disc(cx, cz, r + 0.7) if q not in _disc(cx, cz, r - 0.7)}
    return out

def ramp_tiles(R):
    dx, dz = DIRS[R["dir"]]; sx, sz = -dz, dx
    n = (R["to"] - R["from"]) * R.get("run", 1)
    out = set()
    for k in range(-6, n + 3):          # the flight, its landing, and the approach to its foot
        for s in range(-(R["w"] // 2) - 2, R["w"] - R["w"] // 2 + 2):
            out.add((R["at"][0] + dx * k + sx * s, R["at"][1] + dz * k + sz * s))
    return out

def _landmarks(M, d):
    """The places on an island a lane runs between."""
    pts = [tuple(p[:2]) for k in ("landings", "chests", "camps") for p in d.get(k, [])]
    for ek in (M.docks, M.outposts, M.hatches):
        pts += [tuple(e[:2]) for e in ek if (int(e[0]), int(e[1])) in M.inisle[d["id"]]]
    for R in d.get("ramps", []):
        dx, dz = DIRS[R["dir"]]
        pts.append((R["at"][0] - dx * 5, R["at"][1] - dz * 5))
    for B in M.bridges:
        if B["a"] == d["id"]: pts.append(tuple(B["from"]))
        if B["b"] == d["id"]: pts.append(tuple(B["to"]))
    return pts

def _lanes(M, d):
    """A spanning tree over the island's landmarks: the lanes people walk."""
    pts = _landmarks(M, d)
    if len(pts) < 2: return []
    inT = [0]; edges = []
    while len(inT) < len(pts):
        best = None
        for i in inT:
            for j in range(len(pts)):
                if j in inT: continue
                L = math.hypot(pts[i][0] - pts[j][0], pts[i][1] - pts[j][1])
                if best is None or L < best[0]: best = (L, i, j)
        edges.append((pts[best[1]], pts[best[2]])); inT.append(best[2])
    return edges

class Cover:
    def __init__(self, M, lv, owner, stairs):
        self.M = M
        self.lv, self.owner, self.stairs = lv, owner, stairs
        for d in M.islands: M.inisle[d["id"]] = {p for p, o in owner.items() if o == d["id"] and lv[p] >= 0}
        self.solid = set(); self.hard = set(); self.lanes = {}; self.things = {}
        for d in M.islands:
            for R in d.get("rocks", []):
                for z in range(R[1], R[3] + 1):
                    for x in range(R[0], R[2] + 1): self.solid.add((x, z))
            for t in d.get("trees", []) + d.get("crates", []) + d.get("pillars", []): self.solid.add((int(t[0]), int(t[1])))
            for W in d.get("walls", []): self.solid |= _wall_tiles(W)
        self.hard |= self.solid
        for d in M.islands:
            for R in d.get("ramps", []): self.hard |= ramp_tiles(R)
            for k in ("chests", "weapons", "wild", "wardens", "traps", "breakables"):
                for p in d.get(k, []): self.hard |= _disc_r(p[0] + 0.5, p[1] + 0.5, 1.7)
            if d.get("shrine"): self.hard |= _disc_r(d["shrine"][0], d["shrine"][1], 3.0)
            for p in d.get("camps", []): self.hard |= _disc_r(p[0] + 0.5, p[1] + 0.5, 3.6)
            for p in d.get("landings", []): self.hard |= _disc_r(p[0] + 0.5, p[1] + 0.5, LANDING_R)
        for L in M.lairs:
            h = L["half"]
            for z in range(L["at"][1] - h - 2, L["at"][1] + h + 3):
                for x in range(L["at"][0] - h - 2, L["at"][0] + h + 3): self.hard.add((x, z))
        for ek, kind in ((M.docks, "dock"), (M.outposts, "outpost"), (M.hatches, "hatch")):
            for e in ek: self.hard |= _disc_r(e[0] + 0.5, e[1] + 0.5, EXIT_R[kind])
        for (x, z), l in lv.items():
            if l == -2:
                for dx in range(-2, 3):
                    for dz in range(-2, 3): self.hard.add((x + dx, z + dz))
        for q in stairs:
            for dx in range(-2, 3):
                for dz in range(-2, 3): self.hard.add((q[0] + dx, q[1] + dz))
        for d in M.islands:
            self.lanes[d["id"]] = _lanes(M, d)
        self.lane_tiles = set()
        for iid, lanes in self.lanes.items():
            for a, b in lanes:
                for z in range(int(min(a[1], b[1]) - 3), int(max(a[1], b[1]) + 4)):
                    for x in range(int(min(a[0], b[0]) - 3), int(max(a[0], b[0]) + 4)):
                        if _seg_dist(x + 0.5, z + 0.5, a, b) < LANE_HALF: self.lane_tiles.add((x, z))
        self.hard |= self.lane_tiles
        self.bush = {}          # tile -> patch id
        self.patches = []

    def void_ok(self, x, z):
        for r in (1, 2):
            for dz in range(-r, r + 1):
                for dx in range(-r, r + 1):
                    if max(abs(dx), abs(dz)) == r and (x + dx, z + dz) not in self.lv: return False
        return True

    def tile_ok(self, q, iid):
        return self.owner.get(q) == iid and self.lv.get(q, -1) >= 0 and q not in self.stairs and self.void_ok(*q)

    def clump_tiles(self, iid, cx, cz, r):
        """The tiles the engine would turn to grass, or None when the clump would touch something it must not.
        The engine fattens each circle by up to 0.3 at random per tile, so what must stay clear is checked
        with that much margin."""
        tiles = _disc(cx, cz, r); keep = set(); lvl = None
        for q in _disc(cx, cz, r, 0.32):
            if not self.tile_ok(q, iid): continue
            if q in self.hard: return None
            l = self.lv[q]
            if lvl is None: lvl = l
            elif l != lvl: return None
            if q in tiles: keep.add(q)
        if not tiles or len(keep) < 0.7 * len(tiles): return None
        return keep

    def gap_ok(self, tiles, gap):
        for (x, z) in tiles:
            for dx in range(-gap, gap + 1):
                for dz in range(-gap, gap + 1):
                    if (x + dx, z + dz) in self.bush and (x + dx, z + dz) not in tiles: return False
        return True

    def patch(self, rng, iid, c, cfg, heading=None, n_max=None):
        """3-6 overlapping clumps grown from c. Returns (clumps, tiles) or None."""
        n = rng.randint(*cfg["n"])
        if n_max: n = min(n, n_max)
        clumps = []; tiles = set()
        for k in range(n):
            r = round(rng.uniform(*cfg["r"]), 1)
            placed = False
            for _try in range(10):
                if k == 0: pos = c
                else:
                    prev = clumps[-1] if (cfg["band"] and heading is not None) else clumps[rng.randrange(len(clumps))]
                    a = (heading + rng.uniform(-0.5, 0.5)) if (cfg["band"] and heading is not None) else rng.uniform(0, math.tau)
                    dist = (prev[2] + r) * cfg.get("sp", 0.62)
                    pos = (prev[0] + math.cos(a) * dist, prev[1] + math.sin(a) * dist)
                pos = (round(pos[0], 1), round(pos[1], 1))
                t = self.clump_tiles(iid, pos[0], pos[1], r)
                if t is None or (k and not (t & tiles) and not any(math.hypot(pos[0] - q[0], pos[1] - q[1]) < (r + q[2]) * 0.75 for q in clumps)): continue
                clumps.append((pos[0], pos[1], r)); tiles |= t; placed = True; break
            if not placed and k == 0: return None
        if len(clumps) < 3 or len(tiles) < cfg["least"]: return None
        return clumps, tiles

    def plant(self, iid, clumps, tiles, why):
        pid = len(self.patches)
        for q in tiles: self.bush[q] = pid
        self.patches.append(dict(island=iid, clumps=clumps, tiles=tiles, why=why))

    def los(self, a, b):
        L = math.hypot(b[0] - a[0], b[1] - a[1]); n = max(2, int(L / 0.5))
        for i in range(n + 1):
            x = a[0] + (b[0] - a[0]) * i / n; z = a[1] + (b[1] - a[1]) * i / n
            q = (int(x), int(z))
            if self.lv.get(q, -1) < 0 and self.lv.get(q, -1) != -2 or q in self.solid: return False
        return True

def place_cover(M, lv, owner, stairs, seed):
    """Fills every island's "bush" and returns the Cover (patches, shares) for the report."""
    T = targets()
    C = Cover(M, lv, owner, stairs)
    INISLE = M.inisle
    ground = {}                     # biome -> walkable tiles; island -> tiles
    for d in M.islands:
        n = sum(1 for q in INISLE[d["id"]] if q not in C.solid and q not in C.stairs)
        ground[d["id"]] = n
    bground = {}
    for d in M.islands: bground[d["biome"]] = bground.get(d["biome"], 0) + ground[d["id"]]
    # a biome's cover is shared out over its islands by their ground; a perch stays bare
    budget = {}
    for b in bground:
        mid = COVER[b]["share"]
        assert T[b][0] <= mid <= T[b][1], ("cover share outside the target", b, mid)
        ids = [d for d in M.islands if d["biome"] == b and not d.get("perch")]
        tot = sum(ground[d["id"]] for d in ids)
        for d in ids: budget[d["id"]] = mid * bground[b] * ground[d["id"]] / max(1, tot)
    for d in M.islands: budget.setdefault(d["id"], 0.0)
    room = lambda d: sum(1 for q in INISLE[d["id"]] if q not in C.hard and C.void_ok(*q)) / max(1, ground[d["id"]])
    carry = {}                      # cover an island had no room for goes to the roomier islands of its biome
    for d in sorted(M.islands, key=room):
        iid = d["id"]; cfg = COVER[d["biome"]]
        rng = random.Random("%d:%s" % (seed, iid))
        want = budget[iid] + carry.get(d["biome"], 0.0)
        if want <= 0: d["bush"] = []; continue
        _cover_island(M, C, d, cfg, rng, want, lv)
        have = sum(len(p["tiles"]) for p in C.patches if p["island"] == iid)
        carry[d["biome"]] = max(0.0, want - have)
        d["bush"] = [[round(c[0], 1), round(c[1], 1), c[2]] for p in C.patches if p["island"] == iid for c in p["clumps"]]
    return C

def _cover_island(M, C, d, cfg, rng, want, lv):
    """Plants one island's patches: one in sight of each way out first, then the deliberate spots."""
    iid = d["id"]; INISLE = M.inisle
    have = lambda: sum(len(p["tiles"]) for p in C.patches if p["island"] == iid)
    anchors = {"exit": [], "chest": [], "camp": [], "bridge": [], "flank": [], "cliff": [], "pillar": []}
    ring = lambda c, r0, r1, k: [(c[0] + math.cos(a) * rr, c[1] + math.sin(a) * rr)
                                 for rr in [rng.uniform(r0, r1) for _ in range(k)] for a in [rng.uniform(0, math.tau)]]
    if d["biome"] in BUSH_BIOMES:
        for ek in (M.docks, M.outposts, M.hatches):
            for e in ek:
                if (int(e[0]), int(e[1])) in INISLE[iid]: anchors["exit"].append(((e[0] + 0.5, e[1] + 0.5), None))
    rm = sum(cfg["r"]) / 2.0            # a clump this big, plus what must stay clear of it
    for p in d.get("chests", []): anchors["chest"] += [(q, None) for q in ring((p[0] + 0.5, p[1] + 0.5), 2.5 + rm, 4.0 + rm, 24)]
    for p in d.get("camps", []): anchors["camp"] += [(q, None) for q in ring((p[0] + 0.5, p[1] + 0.5), 4.4 + rm, 6.4 + rm, 24)]
    for B in M.bridges:
        for end, isl in ((B["from"], B["a"]), (B["to"], B["b"])):
            if isl != iid: continue
            (x0, z0), (x1, z1) = B["from"], B["to"]; L = math.hypot(x1 - x0, z1 - z0); ux, uz = (x1 - x0) / L, (z1 - z0) / L
            sgn = 1 if end is B["from"] else -1
            for side in (-1, 1):
                for back in (3.5, 5.0):
                    anchors["bridge"].append(((end[0] + ux * sgn * back - uz * side * (B["r"] + 2.8 + rm), end[1] + uz * sgn * back + ux * side * (B["r"] + 2.8 + rm)), (ux, uz)))
    for a, b in C.lanes[iid]:
        L = math.hypot(b[0] - a[0], b[1] - a[1])
        if L < 8: continue
        ux, uz = (b[0] - a[0]) / L, (b[1] - a[1]) / L
        for t in (0.15, 0.3, 0.45, 0.6, 0.75, 0.9):
            for side in (-1, 1):
                off = LANE_HALF + 0.9 + rm + rng.uniform(0.0, 1.8)
                anchors["flank"].append(((a[0] + ux * L * t - uz * side * off, a[1] + uz * L * t + ux * side * off), (math.atan2(uz, ux))))
    for q in sorted(INISLE[iid]):       # a cliff edge: three or four tiles from the drop
        vd = next((r for r in range(1, 7) if any(max(abs(dx), abs(dz)) == r and (q[0] + dx, q[1] + dz) not in lv
                                                   for dx in range(-r, r + 1) for dz in range(-r, r + 1))), 7)
        if vd in (3, 4) and (q[0] * 3 + q[1] * 7) % 13 == 0: anchors["cliff"].append(((q[0] + 0.5, q[1] + 0.5), None))
    for p in d.get("pillars", []):
        anchors["pillar"] += [(q, None) for q in ring((p[0] + 0.5, p[1] + 0.5), 1.4 + rm, 2.6 + rm, 6)]
    lanes_here = C.lanes[iid]       # any other open spot beside a lane, once the deliberate places are used up
    for q in sorted(INISLE[iid]):
        if q in C.hard or not C.void_ok(*q) or not lanes_here: continue
        dl = min(_seg_dist(q[0] + 0.5, q[1] + 0.5, a, b) for a, b in lanes_here)
        if LANE_HALF + rm + 0.4 <= dl <= LANE_HALF + rm + 5.0: anchors["flank"].append(((q[0] + 0.5, q[1] + 0.5), None))
    for k in anchors:
        if k != "flank": rng.shuffle(anchors[k])
    deliberate = anchors["flank"][:]; rng.shuffle(deliberate)
    anchors["flank"] = deliberate
    why_order = ["exit", "chest", "bridge", "camp", "flank", "cliff", "pillar"]

    def try_anchor(kind, c, hd):
        for _ in range(5 if kind != "exit" else 1):
            cc = (round(c[0], 1), round(c[1], 1))
            P = C.patch(rng, iid, cc, cfg, heading=hd if kind in ("flank", "bridge") else None)
            if P and C.gap_ok(P[1], cfg["gap"]) and (kind == "exit" or have() + len(P[1]) <= want * 1.05 + 3):
                return P
            c = (c[0] + rng.uniform(-0.8, 0.8), c[1] + rng.uniform(-0.8, 0.8))
        return None

    # a patch in sight of each way out comes first, whatever the share
    for c, hd in anchors["exit"]:
        cands = [(q[0] + 0.5, q[1] + 0.5) for q in sorted(INISLE[iid])
                 if 4.5 <= math.hypot(q[0] + 0.5 - c[0], q[1] + 0.5 - c[1]) <= SIGHT_R - 2.0 and q not in C.hard and C.los(c, (q[0] + 0.5, q[1] + 0.5))]
        rng.shuffle(cands)
        for t in cands[:120]:
            P = try_anchor("exit", t, None)
            if P and C.los(c, (sum(q[0] for q in P[0]) / len(P[0]), sum(q[1] for q in P[0]) / len(P[0]))):
                C.plant(iid, P[0], P[1], "exit"); break
    for rnd in range(40):
        if have() >= want * 0.97: break
        progressed = False
        for kind in why_order[1:]:
            if have() >= want * 0.97: break
            lst = anchors[kind]
            while lst:
                c, hd = lst.pop()
                P = try_anchor(kind, c, hd)
                if P:
                    C.plant(iid, P[0], P[1], kind); progressed = True; break
        if not progressed: break

def cover_report(M, C):
    T = targets()
    ground = {}; bush = {}
    for d in M.islands:
        for q in M.inisle[d["id"]]:
            if q in C.solid or q in C.stairs: continue
            ground[d["biome"]] = ground.get(d["biome"], 0) + 1
            if q in C.bush: bush[d["biome"]] = bush.get(d["biome"], 0) + 1
    rows = []
    for b in ("bloom", "meadow", "gloom", "storm", "ember", "frost"):
        share = bush.get(b, 0) / max(1, ground.get(b, 1))
        rows.append((b, share, T[b]))
    return rows

def print_cover(M, C):
    for b, share, tg in cover_report(M, C):
        print('cover %-7s %5.1f %%  (target %.1f-%.1f %%)' % (b, share * 100, tg[0] * 100, tg[1] * 100))
    print('cover patches', len(C.patches), 'clumps', sum(len(p['clumps']) for p in C.patches))

def write(map_id, out):
    path = os.path.join(os.path.dirname(__file__), "..", "content", "maps", "%s.json" % map_id)
    with open(path, "w") as f:
        json.dump(out, f, indent=1)
    return os.path.normpath(path)
