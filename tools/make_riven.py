#!/usr/bin/env python3
"""Builds content/maps/riven.json: the Riven Wilds, the top tier's hand-made expedition map.

The Hollow Crown (tools/make_hollowcrown.py) stays the beginner map; this one is for the Hollow tier
(Data.TIERS "map"; docs/decisions/0014-tier-map.md). It uses the same format and the same building
blocks (tools/mapkit.py), so read make_hollowcrown.py for what each key means. Run it to regenerate the
JSON (never edit it by hand); --preview out.png paints a plan when Pillow is installed.

Layout (336 x 336 tiles = metres, 2.4x the Hollow Crown's area; north up; terraces of 0.8 m):

    [Frostfang]      [Hoarfrost]   [ Rimeholt ]   [Duskcairn]       [Cinderhook]
                [ Gloamwood ]    ||   [ Galewrack ]
    [Larkspur] ~ ~ ~ ~ ~ ~ ~   [ THE RIFT ]   ~ ~ ~ ~ ~ ~ ~ ~ [Windward]      ~ the sky train
                [ Fallowmere ]   ||   [ Slagmarch ]
    [Cloverend]      [Thistlewick] [ Briarmaw ]  [Ashfall]          [Mossreach]

The Rift (core, gloom, 1.6 m) with the Sanctum on top (4.8 m, two flights of stairs); a ring of six
regions (ground level, each with one plateau 3.2 m up its own stairs, five with a boss lair); six
outer isles with the landings and exits, and four corner rocks bridged to them. Every height is
walked up: no perches, no jump pads, no updraft towers. The Rift's two land bridges run north and
south; the four diagonal regions reach it by glide routes. The sky train winds between the region
ring and the outer isles: out near the map's edge round each region, in beside each outer isle,
where it stops.
"""
import math, sys

import mapkit
from mapkit import poly, rocks, thickets

SIZE = 336
C = 168             # the middle of the map
RING_R = 86         # the regions' centres from the middle
REGION_R = 35       # a region's mean radius
COVER_SEED = 77     # the tall grass's fixed seed (mapkit.place_cover)

def polar(r, deg):
    a = math.radians(deg)
    return (C + r * math.cos(a), C + r * math.sin(a))

def blob(cx, cz, r, wobble, lv=0, turn=0.0):
    """An irregular outline: one radius factor per evenly spaced bearing, starting at `turn` degrees."""
    n = len(wobble)
    return poly([(round(cx + math.cos(math.radians(turn + 360.0 * i / n)) * r * f),
                  round(cz + math.sin(math.radians(turn + 360.0 * i / n)) * r * f)) for i, f in enumerate(wobble)], lv)

class Frame:
    """Local coordinates on an island: a = metres toward the middle of the map, b = metres to the side
    (mirrored on alternate regions so the six don't read as one copy turned round)."""
    def __init__(self, c, deg_out, flip=1):
        self.c = c
        a = math.radians(deg_out + 180.0)       # toward the middle
        self.u = (math.cos(a), math.sin(a)); self.v = (-self.u[1] * flip, self.u[0] * flip)

    def at(self, a, b, *more):
        x = self.c[0] + self.u[0] * a + self.v[0] * b; z = self.c[1] + self.u[1] * a + self.v[1] * b
        return [int(round(x)), int(round(z))] + list(more)

    def axis_in(self):
        """The compass side facing the middle (stairs climb away from it, gates face it)."""
        ux, uz = self.u
        return ("e" if ux > 0 else "w") if abs(ux) >= abs(uz) else ("s" if uz > 0 else "n")

def boulder(p, w, h):
    """A boulder block w x h tiles (whole tiles, map axes) from p: wall_size_check wants every piece 3+ tiles."""
    return [p[0], p[1], p[0] + w - 1, p[1] + h - 1]

def auto_ramp(shape, lv0, lv1, d, w, run=1):
    """A flight climbing `d` onto a plateau: its top row is the plateau's first full row from the side it
    is climbed from, along the line through the plateau's middle."""
    dx, dz = mapkit.DIRS[d]; sx, sz = -dz, dx
    pts = shape["poly"]
    cx = round(sum(p[0] for p in pts) / len(pts)); cz = round(sum(p[1] for p in pts) / len(pts))
    full = lambda x, z: all(mapkit.shape_d(shape, x + sx * s + 0.5, z + sz * s + 0.5) < 1.0 for s in range(-(w // 2), w - w // 2))
    t = 0
    while full(cx - dx * (t + 1), cz - dz * (t + 1)): t += 1
    n = (lv1 - lv0) * run
    return mapkit.ramp(cx - dx * (t + n), cz - dz * (t + n), d, w, lv0, lv1, run)

# ------------------------------------------------------------------ the core
SANCTUM = poly([(C - 13, C - 8), (C - 8, C - 13), (C + 8, C - 13), (C + 13, C - 8),
                (C + 13, C + 8), (C + 8, C + 13), (C - 8, C + 13), (C - 13, C + 8)], 6)
rift = dict(id="rift", name="The Rift", role="heart", region=0, biome="gloom", danger=2, poi=[C, C], noise=0.05,
            shapes=[blob(C, C, 37, [1.0, 0.93, 1.02, 0.95, 1.06, 0.92, 1.0, 0.96, 1.04, 0.94, 1.08, 1.06], 2, 8), SANCTUM],
            sheer=[[30, 60], [120, 150], [210, 240], [300, 330]],
            walls=[dict(line=[C - 6, C - 24, C - 2, C - 24]), dict(line=[C + 2, C - 24, C + 6, C - 24]),
                   dict(line=[C - 6, C + 24, C - 2, C + 24]), dict(line=[C + 2, C + 24, C + 6, C + 24]),
                   dict(line=[C - 4, C - 9, C - 1, C - 9]), dict(line=[C + 1, C + 9, C + 4, C + 9]),
                   dict(line=[C - 25, C - 14, C - 25, C - 11]), dict(line=[C + 25, C + 11, C + 25, C + 14])],
            rocks=rocks((C - 28, C - 20, C - 27, C - 19), (C + 26, C - 22, C + 27, C - 21), (C - 26, C + 21, C - 25, C + 22), (C + 25, C + 20, C + 26, C + 21)),
            landings=[],
            chests=[[C, C], [C - 30, C + 2], [C + 30, C - 2], [C + 8, C + 28]],
            camps=[[C - 18, C - 22, "heavy"], [C + 18, C + 22, "heavy"]],
            breakables=[[C + 20, C - 26, "barrel"], [C + 21, C - 26, "crate"], [C - 21, C + 26, "pot"], [C - 20, C + 26, "crate"]],
            wardens=[[C - 4, C - 30], [C + 4, C + 31], [C + 1, C + 2]],
            traps=[[C - 16, C + 14], [C + 16, C - 14]],
            areas=[[C, C - 4, "The Sanctum"], [C - 28, C + 10, "The Fallen Arches"]])
rift["ramps"] = [auto_ramp(SANCTUM, 2, 6, "e", 5), auto_ramp(SANCTUM, 2, 6, "w", 5)]

# ------------------------------------------------------------------ the region ring
# [compass bearing, id, name, biome, role, flip, wobble, plateau name, lair (id, name, boss, entry) or None, extras]
RING = [
    (270, "rimeholt", "Rimeholt", "frost", "camp", 1, [1.0, 0.95, 1.05, 0.98, 0.93, 1.04, 1.0, 0.96, 1.06, 0.97, 0.94, 1.02],
     "Rimeholt Keep", None, {}),
    (330, "galewrack", "Galewrack", "storm", "camp", -1, [0.97, 1.04, 0.95, 1.0, 1.06, 1.04, 1.05, 1.03, 0.96, 1.01, 0.95, 1.05],
     "Thunder Table", ("thunderwell", "The Thunderwell", "serpent", ["dial", "runes"]), {}),
    (30, "slagmarch", "Slagmarch", "ember", "camp", 1, [1.03, 0.96, 1.0, 1.05, 0.95, 0.98, 1.04, 0.94, 1.0, 1.02, 0.96, 1.01],
     "The Kilnworks", ("slagforge", "The Slag Forge", "colossus", ["dial"]), {}),
    (90, "briarmaw", "Briarmaw", "bloom", "nest", -1, [0.98, 1.03, 0.96, 1.05, 1.0, 0.95, 1.02, 0.97, 1.04, 0.95, 1.01, 0.99],
     "Bramble Crown", ("briarhive", "The Briar Hive", "brood", ["dial", "wards"]), {"trees": True, "wild": True}),
    (150, "fallowmere", "Fallowmere", "meadow", "nest", 1, [1.02, 0.97, 1.04, 0.95, 1.0, 1.03, 0.96, 1.01, 0.94, 1.05, 0.98, 0.99],
     "Haystack Rise", ("barrowdeep", "The Barrowdeep", "colossus", ["dial", "runes"]), {"trees": True, "wild": True}),
    (210, "gloamwood", "Gloamwood", "gloom", "shrine", -1, [0.96, 1.02, 1.05, 0.97, 0.99, 1.04, 0.95, 1.0, 1.03, 0.96, 1.02, 0.98],
     "Shrine Hill", ("gloamnest", "The Gloam Nest", "brood", ["dial", "wards"]), {"shrine": True}),
]

YARDS = {"rimeholt": "Hoarwind Field", "galewrack": "Rattling Stones", "slagmarch": "Cinder Pits",
         "briarmaw": "Thornglade", "fallowmere": "Sheaf Commons", "gloamwood": "Lantern Mire"}

def region(spec, index):
    deg, iid, nm, biome, role, flip, wob, high, lair, extra = spec
    c = polar(RING_R, deg)
    F = Frame(c, deg, flip)
    # the plateau sits on the outer half, toward the train and the outer isles
    pc = F.at(-17, -6)
    plat = poly([(pc[0] - 9, pc[1] - 5), (pc[0] - 5, pc[1] - 9), (pc[0] + 5, pc[1] - 9), (pc[0] + 9, pc[1] - 5),
                 (pc[0] + 9, pc[1] + 5), (pc[0] + 5, pc[1] + 9), (pc[0] - 5, pc[1] + 9), (pc[0] - 9, pc[1] + 5)], 4)
    d = dict(id=iid, name=nm, role=role, region=index + 1, biome=biome, danger=1, poi=[int(c[0]), int(c[1])], noise=0.06,
             shapes=[blob(c[0], c[1], REGION_R, wob, 0, deg + 15), plat],
             sheer=[[(deg + 140) % 360, (deg + 200) % 360]],
             ramps=[auto_ramp(plat, 0, 4, {"n": "s", "s": "n", "e": "w", "w": "e"}[F.axis_in()], 4)],
             rocks=[boulder(F.at(4, -20), 2, 2), boulder(F.at(-28, 2), 2, 3), boulder(F.at(18, 18), 3, 2)],
             landings=[F.at(-26, 16), F.at(6, -27)],
             chests=[F.at(-18, -9), F.at(21, -8), F.at(1, -18), F.at(-25, 6)],
             camps=[F.at(12, 2, "heavy"), F.at(-16, -4, "normal"), F.at(15, -18, "light")],
             breakables=[F.at(25, 2, "crate"), F.at(25, 3, "barrel"), F.at(-6, -28, "pot"), F.at(-5, -28, "pot")],
             weapons=[F.at(-8, 4)],
             wardens=[F.at(2, -12), F.at(27, -14)],
             traps=[F.at(6, -9)],
             areas=[F.at(-17, -6, high), F.at(12, -12, YARDS[iid])])
    if extra.get("trees"):
        d["trees"] = thickets(tuple(F.at(-10, 22)), tuple(F.at(10, -26)), tuple(F.at(-29, -8)))
    if extra.get("wild"):
        d["wild"] = [F.at(-12, 14), F.at(-15, 10)]
    if extra.get("shrine"):
        d["shrine"] = F.at(-16, -6)
        d["camps"] = d["camps"][:1] + d["camps"][2:]
    if lair:
        lid, lname, boss, entry = lair
        at = F.at(-1, 17)
        LAIRS.append(dict(id=lid, name=lname, boss=boss, island=iid, at=at, half=7, gate=_gate_toward(at, c), entry=entry))
    return d, F

def _gate_toward(at, c):
    dx, dz = c[0] - at[0], c[1] - at[1]
    return ("e" if dx > 0 else "w") if abs(dx) >= abs(dz) else ("s" if dz > 0 else "n")

LAIRS = []
ring = [region(s, i) for i, s in enumerate(RING)]
RF = {d["id"]: F for d, F in ring}

# ------------------------------------------------------------------ the outer isles and corner rocks
# [bearing, ring radius, id, name, biome, exit kind ("dock" points out over the abyss), wobble]
OUTER = [
    (0, 133, "windward", "Windward Shoal", "storm", "dock", [1.0, 0.94, 1.05, 0.97, 1.02, 0.95, 1.04, 0.98, 0.96, 1.03]),
    (60, 140, "ashfall", "Ashfall Ledge", "ember", "outpost", [0.97, 1.04, 0.95, 1.01, 1.05, 0.96, 1.0, 0.94, 1.03, 0.98]),
    (120, 140, "thistlewick", "Thistlewick", "bloom", "outpost", [1.03, 0.96, 1.0, 1.05, 0.95, 0.99, 1.04, 0.97, 0.94, 1.02]),
    (180, 133, "larkspur", "Larkspur Rest", "meadow", "dock", [0.98, 1.02, 0.95, 1.04, 0.99, 1.03, 0.96, 1.0, 1.05, 0.94]),
    (240, 140, "hoarfrost", "Hoarfrost Isle", "frost", "outpost", [1.02, 0.97, 1.04, 0.95, 1.0, 0.98, 1.05, 0.96, 1.01, 0.97]),
    (300, 140, "duskcairn", "Duskcairn", "gloom", "outpost", [0.96, 1.03, 0.99, 1.05, 0.94, 1.01, 0.97, 1.04, 0.98, 1.02]),
]
OUTER_R = 23

PLACES = {"windward": "Gull Rocks", "ashfall": "Smoking Steps", "thistlewick": "Downy Hollow", "larkspur": "Larkspur Green",
          "hoarfrost": "Rime Pools", "duskcairn": "Standing Cairns"}

def outer_isle(spec, index):
    deg, rr, iid, nm, biome, ex, wob = spec
    c = polar(rr, deg)
    F = Frame(c, deg, 1 if index % 2 else -1)
    d = dict(id=iid, name=nm, role="landing", region=7 + index, biome=biome, danger=0, poi=[int(c[0]), int(c[1])], noise=0.08,
             shapes=[blob(c[0], c[1], OUTER_R, wob, 0, deg)],
             sheer=[[(deg + 120) % 360, (deg + 170) % 360]],
             rocks=[boulder(F.at(2, 9), 3, 2)],
             landings=[F.at(8, -10), F.at(8, 10), F.at(-3, 15)],
             chests=[F.at(-4, -14), F.at(13, 2)],
             camps=[F.at(-2, 6, "light")],
             breakables=[F.at(15, -8, "crate"), F.at(15, -7, "keg"), F.at(-12, 12, "pot")],
             wardens=[F.at(1, -4)],
             areas=[F.at(6, 0, PLACES[iid])])
    if biome in ("bloom", "meadow"):
        d["trees"] = thickets(tuple(F.at(-8, 18)), tuple(F.at(4, -18)))
    out = F.at(-1, 0); oa = (out[0] - c[0], out[1] - c[1])
    if ex == "dock":
        p = F.at(-19, 0)
        DOCKS.append([p[0], p[1], 1 if oa[0] < 0 and abs(oa[0]) >= abs(oa[1]) else (-1 if abs(oa[0]) >= abs(oa[1]) else 0),
                      0 if abs(oa[0]) >= abs(oa[1]) else (1 if oa[1] < 0 else -1)])
    else:
        OUTPOSTS.append(F.at(-10, -2, 1))
    return d, F

DOCKS = []
OUTPOSTS = []
outer = [outer_isle(s, i) for i, s in enumerate(OUTER)]
OF = {d["id"]: F for d, F in outer}

# [bearing, id, name, biome, the outer isle it is bridged to, dock?]
CORNERS = [
    (45, "mossreach", "Mossreach", "bloom", "ashfall", False),
    (135, "cloverend", "Cloverend", "meadow", "thistlewick", True),
    (225, "frostfang", "Frostfang Rock", "frost", "hoarfrost", False),
    (315, "cinderhook", "Cinderhook", "ember", "duskcairn", True),
]

def corner(spec, index):
    deg, iid, nm, biome, link, dock = spec
    c = polar(183, deg)
    F = Frame(c, deg)
    d = dict(id=iid, name=nm, role="landing", region=13 + index, biome=biome, danger=0, poi=[int(c[0]), int(c[1])], noise=0.08,
             shapes=[blob(c[0], c[1], 15, [1.0, 0.92, 1.06, 0.96, 1.03, 0.94, 1.05, 0.97], 0, deg)],
             sheer=[[(deg + 150) % 360, (deg + 210) % 360]],
             landings=[F.at(4, -6), F.at(4, 6)],
             chests=[F.at(-6, 0)],
             camps=[],
             breakables=[F.at(-2, 9, "crate"), F.at(-1, 9, "pot")],
             wardens=[])
    if dock:
        p = F.at(-11, 0)
        DOCKS.append([p[0], p[1], 1 if p[0] > C else -1, 0])
    else:
        HATCHES.append(F.at(-3, -7))
    return d, F

HATCHES = []
corners = [corner(s, i) for i, s in enumerate(CORNERS)]

islands = [rift] + [d for d, _ in ring] + [d for d, _ in outer] + [d for d, _ in corners]
M = mapkit.Map(SIZE, islands)

regions = [dict(id="rift", name="The Rift", biome="gloom", islands=["rift"],
                purpose="Contested core: the vault on the Sanctum, the richest loot and the most Blight. Two land bridges "
                        "(north and south); glide in from the four diagonal regions.")]
PURPOSE = {
    "rimeholt": "Northern frost ridge: the Keep's plateau looks down the Rime Span into the Rift; no lair, the vault's favourite.",
    "galewrack": "Storm-lashed tableland with the Thunderwell (the Sky Serpent) and the longest glide into the Rift.",
    "slagmarch": "Ember country: the Kilnworks plateau over the Slag Forge (the Colossus); the train's Rift run starts at its feet.",
    "briarmaw": "Thick bramble wood, ambush country: a Boki nest, the Briar Hive (the Brood Mother) and the Briar Span to the Rift.",
    "fallowmere": "Long-grass meadow with a Boki nest, Haystack Rise and the Barrowdeep (the Colossus).",
    "gloamwood": "Dim wood round the shrine on Shrine Hill, with the Gloam Nest (the Brood Mother).",
}
for d, _ in ring:
    regions.append(dict(id=d["id"], name=d["name"], biome=d["biome"], islands=[d["id"]], purpose=PURPOSE[d["id"]]))
for d, _ in outer:
    regions.append(dict(id=d["id"], name=d["name"], biome=d["biome"], islands=[d["id"]] + [c[1] for c in CORNERS if c[4] == d["id"]],
                        purpose="Quiet outer landing with a sky-train stop and a way out."))

# ------------------------------------------------------------------ bridges and glides
bridges = [
    # the Rift's two land bridges (straight north and south, so each carries its flight of stairs)
    mapkit.bridge(M, "Rime Span", "rift", "rimeholt", (C, C - 20), (C, C - 70), 2.0),
    mapkit.bridge(M, "Briar Span", "rift", "briarmaw", (C, C + 20), (C, C + 70), 2.0),
]
for i in range(6):          # the ring roads between neighbouring regions
    a = RING[i]; b = RING[(i + 1) % 6]
    pa = polar(RING_R - 6, a[0] + 10); pb = polar(RING_R - 6, b[0] - 10)
    names = ["Hoar Road", "Gale Road", "Slag Road", "Bramble Road", "Fallow Road", "Gloam Road"]
    bridges.append(mapkit.bridge(M, names[i], a[1], b[1], pa, pb, 1.6 if i % 2 else 1.4))
# each outer isle by a bridge to one region beside it (the train dips under these)
OUT_LINK = {"windward": "galewrack", "ashfall": "slagmarch", "thistlewick": "briarmaw", "larkspur": "fallowmere",
            "hoarfrost": "gloamwood", "duskcairn": "rimeholt"}
LINK_NAMES = {"windward": "Windward Causeway", "ashfall": "Ash Causeway", "thistlewick": "Thistle Causeway",
              "larkspur": "Larkspur Causeway", "hoarfrost": "Hoar Causeway", "duskcairn": "Cairn Causeway"}
for d, F in outer:
    r = M.by[OUT_LINK[d["id"]]]
    bridges.append(mapkit.bridge(M, LINK_NAMES[d["id"]], d["id"], r["id"], tuple(d["poi"]), tuple(r["poi"]), 1.5))
for d, F in corners:
    o = M.by[[c[4] for c in CORNERS if c[1] == d["id"]][0]]
    bridges.append(mapkit.bridge(M, "", d["id"], o["id"], tuple(d["poi"]), tuple(o["poi"]), 1.3))

def glide_pair(a, b, name=""):
    """A glide route both ways between two islands, take-off and landing a few metres inside each rim."""
    pa = M.by[a]["poi"]; pb = M.by[b]["poi"]
    L = math.hypot(pb[0] - pa[0], pb[1] - pa[1]); ux, uz = (pb[0] - pa[0]) / L, (pb[1] - pa[1]) / L
    rim = lambda iid, p, s: next(t for t in range(0, int(L)) if not mapkit.inside(M, iid, p[0] + ux * s * t, p[1] + uz * s * t, 0.08))
    ta = rim(a, pa, 1) - 3; tb = rim(b, pb, -1) - 4
    take = [int(round(pa[0] + ux * ta)), int(round(pa[1] + uz * ta))]
    land = [int(round(pb[0] - ux * tb)), int(round(pb[1] - uz * tb))]
    first = dict(a=a, b=b, take=take, land=land)
    if name: first = dict(name=name, **first)
    back_take = [int(round(pb[0] - ux * (tb - 1))), int(round(pb[1] - uz * (tb - 1)))]
    back_land = [int(round(pa[0] + ux * (ta - 1))), int(round(pa[1] + uz * (ta - 1)))]
    return [first, dict(a=b, b=a, take=back_take, land=back_land)]

glides = []
for iid, nm in (("galewrack", "Gale Leap"), ("slagmarch", "Slag Leap"), ("fallowmere", "Fallow Leap"), ("gloamwood", "Gloam Leap")):
    glides += glide_pair(iid, "rift", nm)
for d, _ in outer:          # each outer isle to the other region beside it
    deg = [o[0] for o in OUTER if o[2] == d["id"]][0]
    other = [r[1] for r in RING if abs(((r[0] - deg + 180) % 360) - 180) == 30 and r[1] != OUT_LINK[d["id"]]][0]
    glides += glide_pair(d["id"], other)

lairs = LAIRS
docks = DOCKS
outposts = OUTPOSTS + [RF["briarmaw"].at(20, 10, 1), RF["gloamwood"].at(20, 10, 1)]
# (in opening order: the Rift's two first, so the first hatch is never beside a landing)
hatches = [[C - 22, C + 8], [C + 22, C - 8]] + [RF[r[1]].at(17, -26) for r in RING] + HATCHES

spawn_points = {
    "rare_kin": dict(pick=[4, 4], points=[d["poi"][:2] + [d["name"]] for d, _ in outer] +
                     [RF["briarmaw"].at(-12, 12, "Briarmaw"), RF["fallowmere"].at(-12, 12, "Fallowmere"),
                      RF["rimeholt"].at(8, -14, "Rimeholt"), RF["galewrack"].at(8, -14, "Galewrack")]),
    "vault": dict(pick=[3, 3], points=[RF[r[1]].at(-17, -2, r[7]) for r in RING] + [[C, C - 4, "The Sanctum"]]),
    "cache": dict(pick=[6, 6], points=[OF[o[2]].at(10, 0, o[3]) for o in OUTER] + [RF[r[1]].at(18, -4, r[2]) for r in RING] +
                  [[C - 26, C - 6, "The Rift"], [C + 26, C + 6, "The Rift"]]),
    "boss": dict(pick=[3, 3], points=[L["at"] + [L["name"]] for L in LAIRS]),
}

# ------------------------------------------------------------------ the sky train
# A winding loop through the band between the region ring and the outer isles: out near the edge round
# each region, in by each outer isle (where it stops), with its own swings so no two stretches match.
# [bearing, metres from the middle]; smoothed into a closed curve below.
TRAIN_CTRL = [
    (0, 104), (10, 109), (18, 121), (26, 129), (34, 125), (41, 127), (49, 118), (60, 110),
    # the Rift run: in through the gap between Slagmarch and Briarmaw, round under the Rift's south rim
    # (beneath the Briar Span) and back out between Briarmaw and Fallowmere
    (64, 99), (62, 86), (61, 72), (63, 59), (70, 49), (80, 45), (90, 44), (100, 45), (110, 49),
    (117, 59), (119, 72), (118, 86), (116, 99), (120, 110),
    (128, 114), (136, 123), (145, 130), (155, 126), (164, 116), (172, 109), (180, 104),
    (188, 110), (196, 122), (204, 130), (211, 126), (218, 132), (226, 123), (233, 114), (240, 110),
    (247, 115), (255, 125), (263, 131), (270, 127), (277, 131), (285, 125), (293, 116), (300, 110),
    (307, 115), (315, 124), (323, 131), (331, 126), (339, 131), (347, 120), (354, 106),
]
TRAIN_STOPS = [(o[0], o[3] + " Stop") for o in OUTER]
TRAIN_CLEAR = 4.0       # metres from the track's centre line to any ground (bridges excepted: it dips under)
TRAIN_NEAR = 16.0       # ...and never further than this from some island: it passes close by things

def catmull(points, step=1.0):
    """A closed Catmull-Rom curve through the points, sampled about every `step` metres."""
    out = []
    n = len(points)
    for i in range(n):
        p0, p1, p2, p3 = points[i - 1], points[i], points[(i + 1) % n], points[(i + 2) % n]
        L = math.hypot(p2[0] - p1[0], p2[1] - p1[1]); k = max(2, int(L / step))
        for j in range(k):
            t = j / k; t2 = t * t; t3 = t2 * t
            out.append(tuple(0.5 * (2 * p1[q] + (-p0[q] + p2[q]) * t + (2 * p0[q] - 5 * p1[q] + 4 * p2[q] - p3[q]) * t2 +
                                   (-p0[q] + 3 * p1[q] - 3 * p2[q] + p3[q]) * t3) for q in (0, 1)))
    return out

def train_route():
    path = catmull([polar(r, deg) for deg, r in TRAIN_CTRL], 2.0)
    stops = []
    for deg, nm in TRAIN_STOPS:
        tgt = polar(110, deg)
        k = min(range(len(path)), key=lambda i: math.hypot(path[i][0] - tgt[0], path[i][1] - tgt[1]))
        stops.append(k)
    return dict(path=[[round(x, 1), round(z, 1)] for x, z in path], stops=stops, names=[nm for _, nm in TRAIN_STOPS],
                cars=5, speed=9.0, dwell=6.0)

def train_check(T, lv, owner):
    """The track keeps clear of every island (it dips under bridges only) and each stop has an outer isle
    within pier reach. Returns problems."""
    probs = []
    path = T["path"]
    ground = [(x, z) for (x, z), l in lv.items() if l >= 0]
    grid = {}
    for q in ground: grid.setdefault((q[0] // 8, q[1] // 8), []).append(q)
    worst = 99.0; loneliest = 0.0
    for x, z in path[::3]:
        near = min(math.hypot(q[0] + 0.5 - x, q[1] + 0.5 - z) for gx in range(int(x) // 8 - 3, int(x) // 8 + 4)
                   for gz in range(int(z) // 8 - 3, int(z) // 8 + 4) for q in grid.get((gx, gz), [(9999, 9999)]))
        loneliest = max(loneliest, near)
        if near > TRAIN_NEAR: probs.append("train far from everything at %s (%.1f m)" % ((round(x), round(z)), near))
    for x, z in path:
        for gx in range(int(x) // 8 - 1, int(x) // 8 + 2):
            for gz in range(int(z) // 8 - 1, int(z) // 8 + 2):
                for q in grid.get((gx, gz), []):
                    dd = math.hypot(q[0] + 0.5 - x, q[1] + 0.5 - z)
                    worst = min(worst, dd)
                    if dd < TRAIN_CLEAR: probs.append("train over %s at %s" % (owner[q], (round(x), round(z))))
    for k, nm in zip(T["stops"], T["names"]):
        x, z = path[k]
        near = min(math.hypot(q[0] + 0.5 - x, q[1] + 0.5 - z) for q in ground)
        if near > 13.0: probs.append("%s: no ground within pier reach (%.1f m)" % (nm, near))
    L = sum(math.hypot(path[i][0] - path[i - 1][0], path[i][1] - path[i - 1][1]) for i in range(len(path)))
    print("train loop %.0f m, %d stops, ground %.1f-%.1f m from the track" % (L, len(T["stops"]), worst, loneliest))
    return sorted(set(probs))[:12]

def place_check(lv, stairs):
    """Nothing listed inside a lair's walls or its apron, and lairs keep off plateaus, stairs and bridges."""
    probs = []
    for L in lairs:
        cx, cz = L["at"]; h = L["half"] + 2
        box = lambda p: abs(p[0] - cx) <= h and abs(p[1] - cz) <= h
        for d in islands:
            for k in ("landings", "chests", "camps", "breakables", "weapons", "wild", "wardens", "traps"):
                for p in d.get(k, []):
                    if box(p): probs.append("%s.%s %s inside lair %s" % (d["id"], k, p[:2], L["id"]))
        for e in docks + outposts + hatches:
            if box(e): probs.append("exit %s inside lair %s" % (e[:2], L["id"]))
        lvs = {lv.get((x, z)) for z in range(cz - h, cz + h + 1) for x in range(cx - h, cx + h + 1)}
        if len(lvs) > 1: probs.append("lair %s not on flat ground %s" % (L["id"], lvs))
        if any((x, z) in stairs for z in range(cz - h, cz + h + 1) for x in range(cx - h, cx + h + 1)): probs.append("lair %s on stairs" % L["id"])
    for e in docks + outposts + hatches:
        if (int(e[0]), int(e[1])) not in lv or lv[(int(e[0]), int(e[1]))] < 0: probs.append("exit %s not on ground" % (e[:2],))
    return probs

THREAT = dict(mob=1.25, rarity_lift=1, camp_extra=1)    # harder monsters here (MapThreat): on top of the tier's own

def main():
    M.bridges, M.glides, M.docks, M.outposts, M.hatches, M.lairs = bridges, glides, docks, outposts, hatches, lairs
    lv, owner, stairs = mapkit.rasterize(M)
    C2 = mapkit.place_cover(M, lv, owner, stairs, COVER_SEED)
    T = train_route()
    probs = mapkit.check(M, lv, owner, stairs) + place_check(lv, stairs) + train_check(T, lv, owner)
    mapkit.print_cover(M, C2)
    for p in probs: print("PROBLEM", p)
    mapkit.measure_glides(M, lv, owner)
    if "--preview" in sys.argv:
        def draw_train(dr, s):
            pts = [(x * s, z * s) for x, z in T["path"]]
            dr.line(pts + pts[:1], fill=(255, 140, 60), width=2)
        mapkit.preview(M, sys.argv[sys.argv.index("--preview") + 1], lv, owner, stairs, 3, draw_train)
    ground = sum(1 for l in lv.values() if l >= 0)
    print("ground %d tiles, %d islands, %d chests, %d camps, %d landings, %d exits, %d lairs" % (
        ground, len(islands), sum(len(d.get("chests", [])) for d in islands), sum(len(d.get("camps", [])) for d in islands),
        sum(len(d.get("landings", [])) for d in islands), len(docks) + len(outposts) + len(hatches), len(lairs)))
    for G in glides[::2]: print("glide %-11s -> %-11s gap %.1f m" % (G["a"], G["b"], G["gap"]))
    for B in bridges: print("bridge %-18s span %.1f m" % (B["name"] or (B["a"] + "-" + B["b"]), B["span"]))
    out = dict(id="riven", name="The Riven Wilds", size=SIZE, seed=6161, hand=True,
               notes="Hand-made expedition map for the top tier (tools/make_riven.py; format in tools/make_hollowcrown.py). "
                     "A raised core (the Rift and its Sanctum), a ring of six regions each with one plateau up its stairs and "
                     "most with a boss lair, six outer isles with the landings and exits, four corner rocks, and a winding sky "
                     "train between the ring and the outer isles. Every height is walked up: no perches or jump pads.",
               threat=THREAT, stream=True, regions=regions, islands=islands, bridges=bridges, glides=glides, pads=[], updrafts=[],
               winds=[], train=T, docks=docks, outposts=outposts, hatches=hatches, lairs=lairs, spawn_points=spawn_points)
    print("wrote", mapkit.write("riven", out), "problems:", len(probs))

if __name__ == "__main__":
    main()
