#!/usr/bin/env python3
"""Builds content/maps/hollowcrown.json: the Hollow Crown, a hand-made expedition map.

Every coordinate here is chosen by hand (no randomness). The engine reads the JSON; this script only
keeps the numbers readable, works out bridge ends from the island outlines, checks the layout
(lairs on flat ground, spots on open ground, ramps landing where they should) and can draw a
preview: python3 tools/make_hollowcrown.py --preview out.png

Layout (216 x 216 tiles = metres, north up, heights in terraces of 0.8 m):

                  [Highwatch]           outer isles: lv 0, quiet landings, docks / uplinks
     [Larkhollow]   [  Frostgate  ]--   mid ring:    lv 2, one raised plateau each (lv 6)
          |          ||  Gate Span  [Stormcrown Gaol]   core: lv 4, the Throne at lv 8
     [Cinder ]   [ THE CROWN ]=====/
     [Steps  ]   [  (Throne) ]   [Stormbreak]
          \\ Ash   ||Bramble  * Shardfall (perch, lv 10)
     [Ashen Gaol] [ Thornwood ]------[Duskmoor]
     [Saltmere]

Heights are few and deliberate: the map climbs toward the middle (outer 0 m, ring 1.6 m, Crown
3.2 m, Throne 6.4 m). Inside an island there is at most one raised plateau, 4 terraces (3.2 m) up:
too high to jump and grab, so it's reached by its stairs (or by gliding onto it). A plateau's stairs
are its chokepoints. Bridges between different heights carry their own flight of stairs.

FORMAT (what World.generate_authored reads; keys beyond Skyreach's are marked +):
  hand (+)            true: nothing is placed by dice. No auto stairs, no random rocks, no random
                      chests/camps/breakables/spawns: only what the layout lists. The match seed only
                      rolls spawn plan picks, live lairs, loot, the Blight and the weather.
  regions (+)         [{id, name, purpose, biome, islands: [ids]}] named regions (map legend, docs)
  islands[]           id, name, role, region, biome, danger, poi, noise (coast wobble), sheer arcs
    shapes            circle / ellipse / rect / capsule / poly (+, [[x,z],...]) each with "lv";
                      the first shape is the outline, later ones raise tiers inside it
    ramps (+)         [{at:[x,z], dir:"n|s|e|w", w, from, to, run}] a flight of stairs: its bottom
                      row starts at `at` (centre of its width) and rises toward dir, one terrace
                      per `run` tiles (run 2 puts a landing between steps)
    walls             line / ring / box, as before; pillars [[x,z]] (ruins)
    rocks (+)         [[x0,z0,x1,z1]] boulder blocks (inclusive tile rects)
    trees (+)         [[x,z]] single trees (they block like rocks)
    crates (+)        [[x,z]] camp supply piles (block)
    bush              [[x,z,r]] tall grass to hide in
    landings (+)      [[x,z]] where squads come down (World.spawns)
    camps (+)         [[x,z,"light|normal|heavy"]] monster camps (which monsters: rolled)
    chests            [[x,z,tier]];  breakables (+) [[x,z,"crate|pot|barrel"]];  weapons (+) [[x,z]]
    wild (+)          [[x,z]] wild Boki;  shrine (+) [x,z]
    wardens (+)       [[x,z]] Blight Warden posts (how many stand: rolled by danger)
    traps (+)         [[x,z]] where the region's traps go (which trap: the biome's list)
    areas (+)         [[x,z,"Name"]] named places inside an island (map labels)
  bridges             {name, a, b, from, to, r}; ends at different heights get a flight (+)
  glides              [a, b] or (+) {a, b, take:[x,z], land:[x,z], name}: glide routes for bots
  pads, updrafts, winds, docks, outposts, hatches, lairs, spawn_points: as Skyreach
"""
import json, math, os, sys

SIZE = 216
LEVEL = 0.8

def poly(pts, lv=0, **k):
    return dict(poly=[list(p) for p in pts], lv=lv, **k)

def circle(x, z, r, lv=0, **k):
    return dict(circle=[x, z], r=r, lv=lv, **k)

def ramp(x, z, d, w, lv0, lv1, run=1):
    return dict(at=[x, z], dir=d, w=w, **{"from": lv0}, to=lv1, run=run)

def rocks(*rects):
    return [list(r) for r in rects]

# ------------------------------------------------------------------ the islands
islands = [
    # ---- THE CROWN (contested core): a broken stone crown. A wide lower terrace (lv 4) rings the
    # Throne (lv 8), whose only ways up are the West and East Stairs. The vault sits on the Throne.
    # Four bridges land on the terrace (N, S and the two Gaols); the west and east sides face glide gaps.
    dict(id="crown", name="The Crown", role="heart", region=0, biome="gloom", danger=2, poi=[108, 108], noise=0.05,
         shapes=[poly([(88, 84), (128, 84), (136, 94), (136, 122), (126, 132), (90, 132), (80, 122), (80, 96)], 4),
                 poly([(99, 98), (117, 98), (122, 103), (122, 113), (117, 118), (99, 118), (94, 113), (94, 103)], 8)],
         sheer=[[300, 330], [120, 150]],
         ramps=[ramp(90, 108, "e", 5, 4, 8), ramp(125, 108, "w", 5, 4, 8)],
         walls=[dict(line=[99, 90, 103, 90]), dict(line=[113, 90, 117, 90]),
                dict(line=[99, 126, 103, 126]), dict(line=[113, 126, 117, 126]),
                dict(line=[104, 101, 106, 101]), dict(line=[110, 101, 112, 101]),
                dict(line=[104, 115, 106, 115]), dict(line=[110, 115, 112, 115])],
         pillars=[[100, 104], [116, 104], [100, 112], [116, 112], [86, 102], [86, 114], [130, 102], [130, 114]],
         rocks=rocks((84, 88, 85, 89), (130, 88, 131, 89), (84, 126, 85, 127), (130, 126, 131, 127)),
         bush=[[84, 118, 1.8], [132, 98, 1.8]],
         landings=[],
         chests=[[108, 108, 2], [84, 108, 1], [132, 108, 1]],
         camps=[[94, 88, "heavy"], [122, 128, "heavy"]],
         breakables=[[126, 88, "barrel"], [127, 88, "crate"], [89, 128, "pot"], [90, 128, "crate"]],
         wardens=[[118, 92], [98, 124], [108, 110]],
         traps=[[96, 96], [120, 120]]),
    # ---- The Gaols: two lair rocks bridged to the Crown, the best (and most fought-over) bosses.
    dict(id="gaol_ne", name="Stormcrown Gaol", role="camp", region=0, biome="storm", danger=2, poi=[157, 79], noise=0.05,
         shapes=[poly([(146, 56), (164, 52), (172, 60), (170, 78), (158, 85), (146, 79), (142, 66)], 4)],
         sheer=[[200, 260]],
         rocks=rocks((147, 81, 148, 81)), bush=[],
         chests=[[164, 79, 1]], camps=[], breakables=[[150, 78, "pot"], [151, 79, "pot"]],
         wardens=[], traps=[]),
    dict(id="gaol_sw", name="Ashen Gaol", role="camp", region=0, biome="ember", danger=2, poi=[71, 150], noise=0.05,
         shapes=[poly([(48, 138), (62, 133), (74, 139), (77, 156), (68, 166), (52, 164), (44, 152)], 4)],
         sheer=[[20, 80]],
         rocks=rocks((72, 158, 72, 159)), bush=[],
         chests=[[62, 161, 1]], camps=[], breakables=[[51, 140, "barrel"], [52, 140, "crate"]],
         wardens=[], traps=[]),
    # ---- FROSTGATE (north): a long frozen ridge. The Keep (lv 6, walled) on its east end looks straight
    # down the Gate Span into the Crown; reach it by the West Stair or the narrow South Stair. The open
    # Rimefield to the west has boulders for cover and a light camp.
    dict(id="frostgate", name="Frostgate", role="camp", region=1, biome="frost", danger=1, poi=[90, 44], noise=0.06,
         shapes=[poly([(70, 40), (84, 26), (108, 22), (132, 25), (146, 38), (142, 56), (124, 66), (96, 66), (78, 58)], 2),
                 poly([(116, 30), (134, 30), (142, 40), (138, 54), (116, 54)], 6)],
         sheer=[[20, 70]],
         ramps=[ramp(112, 42, "e", 5, 2, 6), ramp(127, 57, "n", 3, 2, 6)],
         walls=[dict(box=[120, 33, 136, 50], gates=["w", "s"], gate_w=3)],
         rocks=rocks((84, 38, 85, 39), (96, 50, 98, 50), (102, 32, 103, 32), (102, 33, 102, 34), (88, 56, 89, 56)),
         trees=[[78, 46], [80, 49], [92, 29], [95, 28], [112, 60], [117, 61]],
         bush=[[100, 60, 1.8], [80, 36, 1.4]],
         landings=[[84, 32]],
         chests=[[128, 41, 1], [76, 44, 0]],
         camps=[[92, 44, "light"], [131, 44, "normal"]],
         breakables=[[106, 26, "crate"], [107, 26, "barrel"], [122, 62, "pot"]],
         weapons=[[104, 56]],
         wardens=[[100, 42], [126, 52]],
         traps=[[90, 54]],
         areas=[[128, 42, "Frostgate Keep"], [84, 54, "Rimefield"]]),
    # ---- CINDER STEPS (west): the Kilns (lv 6) on the north half overlook the Crown's west face; one
    # wide stair comes down into the Forge Yard. The Ash Bridge runs south to the Ashen Gaol.
    dict(id="cinder", name="Cinder Steps", role="camp", region=2, biome="ember", danger=1, poi=[42, 104], noise=0.06,
         shapes=[poly([(30, 62), (46, 54), (60, 60), (66, 78), (64, 104), (60, 122), (46, 128), (32, 120), (24, 96), (26, 74)], 2),
                 poly([(34, 66), (46, 61), (56, 65), (60, 78), (56, 84), (36, 84), (32, 74)], 6)],
         sheer=[[150, 210]],
         ramps=[ramp(46, 87, "n", 5, 2, 6)],
         rocks=rocks((34, 96, 35, 97), (55, 96, 55, 99), (39, 116, 41, 116), (39, 117, 39, 117), (58, 112, 59, 113)),
         crates=[[50, 104], [51, 104]],
         trees=[[30, 88], [28, 104], [62, 90]],
         bush=[[30, 110, 1.6], [56, 72, 1.4]],
         landings=[[38, 120], [58, 66]],
         chests=[[46, 70, 1], [52, 118, 0]],
         camps=[[46, 76, "normal"], [42, 100, "light"]],
         breakables=[[60, 68, "barrel"], [33, 90, "crate"], [34, 90, "crate"], [52, 124, "pot"]],
         weapons=[[38, 108]],
         wardens=[[50, 96], [40, 66]],
         traps=[[48, 110]],
         areas=[[46, 70, "The Kilns"], [40, 114, "Forge Yard"]]),
    # ---- STORMBREAK (east): a storm-lashed tableland. The Shrine Table (lv 6) rises in the middle, up
    # the West Ramp (a long flight with landings). The Moor Steps run south to Duskmoor.
    dict(id="storm", name="Stormbreak", role="shrine", region=3, biome="storm", danger=1, poi=[176, 115], noise=0.06,
         shapes=[poly([(156, 96), (172, 90), (188, 96), (195, 114), (190, 134), (178, 146), (162, 142), (154, 124)], 2),
                 poly([(168, 102), (182, 102), (186, 114), (180, 128), (168, 128), (164, 118), (164, 110)], 6)],
         sheer=[[340, 20]],
         ramps=[ramp(156, 114, "e", 5, 2, 6, run=2)],
         rocks=rocks((160, 100, 161, 101), (186, 130, 187, 131), (168, 136, 170, 136)),
         trees=[[176, 94], [190, 104], [158, 132]],
         bush=[[164, 138, 1.6], [188, 120, 1.4]],
         landings=[[186, 100], [176, 140]],
         chests=[[172, 108, 1], [184, 132, 0]],
         camps=[[180, 112, "normal"], [162, 104, "light"]],
         breakables=[[170, 96, "crate"], [171, 96, "pot"], [158, 128, "barrel"]],
         weapons=[[190, 126]],
         wardens=[[172, 132], [178, 106]],
         traps=[[166, 120]],
         shrine=[174, 118]),
    # ---- THORNWOOD (south): a low bramble wood full of tall grass and blossom trees, the Boki nest in
    # its west glade and the Thornhive lair at its east end, with an uplink outpost by the nest.
    dict(id="thorn", name="Thornwood", role="nest", region=4, biome="bloom", danger=1, poi=[96, 170], noise=0.06,
         shapes=[poly([(84, 154), (104, 150), (126, 152), (142, 158), (147, 172), (137, 186), (112, 192), (90, 188), (78, 174)], 2)],
         sheer=[[60, 110]],
         trees=[[90, 158], [93, 157], [104, 156], [110, 186], [113, 187], [86, 180], [100, 182], [116, 162], [118, 182]],
         rocks=rocks((108, 172, 109, 173)),
         bush=[[88, 164, 2.2], [102, 178, 2.0], [108, 160, 1.8], [92, 184, 1.6], [114, 168, 1.6]],
         landings=[[86, 168]],
         chests=[[100, 166, 0], [114, 176, 0]],
         camps=[[98, 160, "light"]],
         wild=[[94, 172], [97, 168]],
         breakables=[[82, 172, "pot"], [83, 173, "pot"], [138, 160, "crate"]],
         weapons=[[106, 186]],
         wardens=[[112, 168]],
         traps=[[104, 172]]),
    # ---- the outer isles: low, quiet, monster-light landings, each with a way out of the match.
    dict(id="lark", name="Larkhollow", role="landing", region=5, biome="meadow", danger=0, poi=[34, 30], noise=0.08,
         shapes=[poly([(16, 16), (36, 10), (52, 18), (55, 34), (44, 46), (22, 44), (12, 30)], 0),
                 circle(26, 24, 5.5, 2)],
         sheer=[[90, 150]],
         trees=[[40, 16], [44, 20], [18, 34]],
         bush=[[36, 38, 1.6]],
         landings=[[34, 30], [46, 36], [20, 38]],
         chests=[[26, 24, 1], [42, 28, 0]],
         camps=[], breakables=[[30, 40, "crate"], [31, 40, "barrel"]],
         wardens=[[40, 40]],
         areas=[[26, 22, "Lark Stones"]]),
    dict(id="highwatch", name="Highwatch", role="landing", region=6, biome="frost", danger=0, poi=[184, 22], noise=0.08,
         shapes=[poly([(170, 12), (192, 10), (204, 22), (202, 40), (186, 46), (172, 38), (166, 24)], 0)],
         sheer=[[0, 60]],
         rocks=rocks((178, 18, 179, 18)), trees=[[196, 34], [174, 30]],
         bush=[[194, 16, 1.4]],
         landings=[[180, 36], [196, 28], [174, 20]],
         chests=[[198, 24, 0]],
         camps=[], breakables=[[184, 40, "crate"], [185, 40, "pot"]],
         wardens=[[178, 30]]),
    dict(id="duskmoor", name="Duskmoor", role="landing", region=7, biome="storm", danger=0, poi=[186, 184], noise=0.08,
         shapes=[poly([(176, 168), (196, 164), (206, 178), (202, 198), (184, 206), (170, 196), (168, 180)], 0)],
         sheer=[[150, 210]],
         trees=[[180, 172], [194, 196], [174, 190]],
         rocks=rocks((188, 184, 189, 185)),
         bush=[[196, 176, 1.6]],
         landings=[[180, 182], [196, 188], [186, 200]],
         chests=[[192, 172, 0]],
         camps=[[178, 194, "light"]], breakables=[[200, 184, "barrel"], [200, 185, "crate"]],
         wardens=[[186, 190]]),
    dict(id="saltmere", name="Saltmere", role="landing", region=8, biome="bloom", danger=0, poi=[24, 184], noise=0.08,
         shapes=[poly([(14, 170), (30, 164), (44, 172), (46, 190), (34, 204), (16, 202), (8, 186)], 0)],
         sheer=[[150, 210]],
         trees=[[14, 180], [36, 198], [40, 178]],
         bush=[[20, 196, 1.6]],
         landings=[[16, 190], [34, 176], [28, 198]],
         chests=[[38, 186, 0]],
         camps=[], breakables=[[18, 176, "pot"], [19, 176, "pot"]],
         wardens=[[30, 190]]),
    # ---- Shardfall: a high shard of rock over the south-east gap (lv 10). A one-way launch pad from
    # Stormbreak or the updraft beside it takes you up; from there you glide down onto the Crown,
    # Thornwood or Stormbreak. A rich chest and the best view of the Thornhive and the Crown's south.
    dict(id="shard", name="Shardfall", role="perch", region=0, biome="gloom", danger=2, poi=[148, 144], noise=0.03, perch=True,
         shapes=[circle(148, 144, 4.6, 10)], sheer=[], chests=[[148, 144, 2]]),
]

BY = {d["id"]: d for d in islands}

regions = [
    dict(id="crown", name="The Crown", biome="gloom", islands=["crown", "gaol_ne", "gaol_sw", "shard"],
         purpose="Contested core: the vault on the Throne, two boss Gaols, the richest loot and the most Blight. "
                 "Every route in is a bridge or a glide over open air."),
    dict(id="frostgate", name="Frostgate", biome="frost", islands=["frostgate"],
         purpose="Northern ridge and Keep: high ground over the Gate Span, a camp to level on, Rimefield cover."),
    dict(id="cinder", name="Cinder Steps", biome="ember", islands=["cinder"],
         purpose="Western forge country: the Kilns overlook the Crown's west face; the Ash Bridge to the Ashen Gaol."),
    dict(id="storm", name="Stormbreak", biome="storm", islands=["storm"],
         purpose="Eastern tableland with the shrine on the Shrine Table; launch pad up to Shardfall."),
    dict(id="thorn", name="Thornwood", biome="bloom", islands=["thorn"],
         purpose="Southern wood: tall grass ambushes, the Boki nest, the Thornhive lair and its uplink."),
    dict(id="lark", name="Larkhollow", biome="meadow", islands=["lark"], purpose="Quiet NW landing with a skiff dock."),
    dict(id="highwatch", name="Highwatch", biome="frost", islands=["highwatch"], purpose="Quiet NE landing with an uplink outpost."),
    dict(id="duskmoor", name="Duskmoor", biome="storm", islands=["duskmoor"], purpose="Quiet SE landing with a skiff dock."),
    dict(id="saltmere", name="Saltmere", biome="bloom", islands=["saltmere"], purpose="Quiet SW landing with an uplink outpost."),
]

# ------------------------------------------------------------------ geometry helpers
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

def base_level(iid, x, z):
    lv = -1
    for S in BY[iid]["shapes"]:
        if shape_d(S, x, z) < 1.0: lv = max(lv, S.get("lv", 0))
    return lv

def inside(iid, x, z, margin=0.0):
    return shape_d(BY[iid]["shapes"][0], x, z) < 1.0 - margin

def bridge(name, a, b, p0, p1, r, dig=2.5):
    """A bridge along p0 -> p1: the ends are pulled to the rims, then pushed a little way inside."""
    (x0, z0), (x1, z1) = p0, p1
    L = math.hypot(x1 - x0, z1 - z0); ux, uz = (x1 - x0) / L, (z1 - z0) / L
    t_a = 0.0; t = 0.0
    while t < L:
        if inside(a, x0 + ux * t, z0 + uz * t, 0.02): t_a = t
        t += 0.25
    t_b = L; t = t_a + 0.5
    while t <= L:
        if inside(b, x0 + ux * t, z0 + uz * t, 0.02): t_b = t; break
        t += 0.25
    fa = (round(x0 + ux * (t_a - dig), 1), round(z0 + uz * (t_a - dig), 1))
    fb = (round(x0 + ux * (t_b + dig), 1), round(z0 + uz * (t_b + dig), 1))
    assert inside(a, *fa) and inside(b, *fb), (name, fa, fb)
    return dict(name=name, a=a, b=b, **{"from": list(fa)}, to=list(fb), r=r, span=round(t_b - t_a, 1))

# Bridges: the core's four ways in (axis-aligned where the ends differ in height, so the bridge
# carries a straight flight), then the ring roads out to the outer isles.
bridges = [
    bridge("Gate Span", "frostgate", "crown", (108, 60), (108, 90), 2.2),
    bridge("Bramble Span", "thorn", "crown", (108, 156), (108, 128), 1.6),
    bridge("Gaol Walk", "crown", "gaol_ne", (130, 89), (150, 79), 1.4),
    bridge("Ash Walk", "crown", "gaol_sw", (86, 127), (70, 142), 1.4),
    bridge("Ash Bridge", "cinder", "gaol_sw", (54, 122), (54, 140), 1.6),
    bridge("Lark Road", "lark", "frostgate", (50, 30), (82, 30), 1.6),
    bridge("Watch Road", "highwatch", "frostgate", (172, 30), (138, 30), 1.6),
    bridge("Moor Steps", "storm", "duskmoor", (176, 140), (176, 172), 1.6),
    bridge("Salt Road", "saltmere", "thorn", (40, 182), (84, 182), 1.4),
]

# Glide routes (bots take them; players can glide anywhere). Gaps are edge to edge, measured below.
glides = [
    dict(name="Kiln Leap", a="cinder", b="crown", take=[63, 100], land=[84, 104]),
    dict(a="crown", b="cinder", take=[81, 112], land=[60, 112]),
    dict(name="Storm Leap", a="storm", b="crown", take=[155, 106], land=[133, 106]),
    dict(a="crown", b="storm", take=[135, 112], land=[158, 112]),
    dict(a="lark", b="cinder", take=[30, 44], land=[34, 64]),
    dict(a="cinder", b="lark", take=[38, 58], land=[34, 42]),
    dict(a="highwatch", b="gaol_ne", take=[186, 44], land=[162, 60]),
    dict(a="gaol_ne", b="highwatch", take=[166, 56], land=[184, 40]),
    dict(a="gaol_ne", b="storm", take=[166, 76], land=[172, 96]),
    dict(a="storm", b="gaol_ne", take=[168, 94], land=[164, 74]),
    dict(a="saltmere", b="gaol_sw", take=[42, 172], land=[52, 160]),
    dict(a="gaol_sw", b="saltmere", take=[50, 160], land=[38, 174]),
    dict(a="duskmoor", b="thorn", take=[170, 182], land=[142, 176]),
    dict(a="thorn", b="duskmoor", take=[144, 176], land=[172, 182]),
    # down from Shardfall (one way)
    dict(a="shard", b="crown", take=[145, 141], land=[128, 126]),
    dict(a="shard", b="thorn", take=[147, 147], land=[136, 166]),
    dict(a="shard", b="storm", take=[151, 141], land=[164, 136]),
]
pads = [["storm", "shard", True]]
updrafts = [dict(at=[141, 150], top=10)]

lairs = [
    dict(id="eyrie", name="Stormcrown Eyrie", boss="serpent", island="gaol_ne", at=[157, 66], half=7, gate="s", entry=["dial", "runes"]),
    dict(id="forge", name="The Sunken Forge", boss="colossus", island="gaol_sw", at=[60, 150], half=7, gate="e", entry=["dial"]),
    dict(id="hive", name="The Thornhive", boss="brood", island="thorn", at=[127, 172], half=7, gate="w", entry=["dial", "wards"]),
]
# exits: skiff docks on the quiet NW/SE isles (pointing out to open sky), walled uplink outposts on
# the NE/SW isles and in Thornwood (each a short run from a boss lair), rift hatches in the ring.
docks = [[15, 30, -1, 0], [201, 184, 1, 0]]
outposts = [[190, 26, 1], [26, 186, 1], [92, 178, 1]]
hatches = [[124, 92], [100, 36], [36, 82], [182, 98], [118, 158]]

spawn_points = {
    "rare_kin": dict(pick=[3, 3], points=[[30, 30, "Larkhollow"], [192, 22, "Highwatch"], [192, 190, "Duskmoor"],
                                          [20, 182, "Saltmere"], [94, 176, "Nest Glade"], [82, 50, "Rimefield"],
                                          [32, 104, "Forge Yard"], [186, 124, "Stormbreak"]]),
    "vault": dict(pick=[2, 2], points=[[128, 46, "Frostgate Keep"], [42, 70, "The Kilns"], [178, 116, "Shrine Table"],
                                       [104, 164, "Thornwood"], [86, 112, "The Crown"]]),
    "cache": dict(pick=[4, 4], points=[[40, 22, "Larkhollow"], [182, 28, "Highwatch"], [184, 192, "Duskmoor"],
                                       [30, 180, "Saltmere"], [104, 44, "Frostgate"], [54, 108, "Cinder Steps"],
                                       [184, 108, "Stormbreak"], [120, 182, "Thornwood"], [132, 118, "The Crown"],
                                       [166, 70, "Stormcrown Gaol"]]),
    "boss": dict(pick=[2, 2], points=[[157, 66, "Stormcrown Eyrie"], [60, 150, "The Sunken Forge"], [127, 172, "The Thornhive"]]),
}

# ------------------------------------------------------------------ a tile model, for checks and the preview
DIRS = {"n": (0, -1), "s": (0, 1), "e": (1, 0), "w": (-1, 0)}

def rasterize():
    lv = {}; owner = {}; stairs = {}
    for d in islands:
        for z in range(SIZE):
            for x in range(SIZE):
                if (x, z) in lv: continue
                if shape_d(d["shapes"][0], x + 0.5, z + 0.5) >= 1.0: continue
                l = base_level(d["id"], x + 0.5, z + 0.5)
                lv[(x, z)] = l; owner[(x, z)] = d["id"]
    for d in islands:
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
            top = (R["at"][0] + dx * n, R["at"][1] + dz * n)
            assert lv.get(top) == R["to"], ("ramp doesn't land on its plateau", d["id"], R, lv.get(top))
    for B in bridges:
        (x0, z0), (x1, z1) = B["from"], B["to"]
        L = math.hypot(x1 - x0, z1 - z0)
        for z in range(int(min(z0, z1) - B["r"] - 1), int(max(z0, z1) + B["r"] + 2)):
            for x in range(int(min(x0, x1) - B["r"] - 1), int(max(x0, x1) + B["r"] + 2)):
                px, pz = x + 0.5, z + 0.5
                t = max(0, min(1, ((px - x0) * (x1 - x0) + (pz - z0) * (z1 - z0)) / (L * L)))
                if math.hypot(px - x0 - (x1 - x0) * t, pz - z0 - (z1 - z0) * t) > B["r"] or (x, z) in lv: continue
                lv[(x, z)] = -2; owner[(x, z)] = B["a"]
    return lv, owner, stairs

def check(lv, owner, stairs):
    probs = []
    def ground(p, what):
        q = (int(p[0]), int(p[1]))
        if q not in lv or lv[q] == -2 and False: probs.append("%s %s not on ground" % (what, p))
        elif q in stairs: probs.append("%s %s on a stair" % (what, p))
    for d in islands:
        for k in ["landings", "chests", "camps", "breakables", "weapons", "wild", "wardens", "traps"]:
            for p in d.get(k, []): ground(p, "%s.%s" % (d["id"], k))
    for L in lairs:
        cx, cz = L["at"]; h = L["half"]
        lvs = set(); own = set()
        for z in range(cz - h - 2, cz + h + 3):
            for x in range(cx - h - 2, cx + h + 3):
                if (x, z) not in lv: probs.append("lair %s over the void at %s" % (L["id"], (x, z))); break
                lvs.add(lv[(x, z)]); own.add(owner[(x, z)])
        if len(own) > 1: probs.append("lair %s spans islands %s" % (L["id"], own))
    for B in bridges:
        assert owner.get((int(B["from"][0]), int(B["from"][1]))) == B["a"], B
    return probs

def preview(path, lv, owner, stairs):
    from PIL import Image, ImageDraw
    S = 4
    img = Image.new("RGB", (SIZE * S, SIZE * S), (24, 26, 40))
    dr = ImageDraw.Draw(img)
    tint = {"gloom": (120, 100, 160), "storm": (110, 130, 170), "ember": (200, 120, 80), "frost": (200, 220, 235),
            "bloom": (110, 190, 110), "meadow": (140, 190, 90)}
    for (x, z), l in lv.items():
        if l == -2:
            c = (150, 145, 140)
        else:
            b = tint.get(BY[owner[(x, z)]].get("biome", ""), (150, 150, 150))
            k = 0.45 + l * 0.065
            c = tuple(min(255, int(v * k)) for v in b)
        if (x, z) in stairs: c = (230, 210, 150)
        dr.rectangle([x * S, z * S, x * S + S - 1, z * S + S - 1], fill=c)
    for d in islands:
        for R in d.get("rocks", []):
            dr.rectangle([R[0] * S, R[1] * S, (R[2] + 1) * S - 1, (R[3] + 1) * S - 1], fill=(70, 70, 70))
        for t in d.get("trees", []):
            dr.ellipse([t[0] * S, t[1] * S, t[0] * S + S, t[1] * S + S], fill=(30, 90, 40))
        for c in d.get("chests", []):
            dr.rectangle([c[0] * S, c[1] * S, c[0] * S + S, c[1] * S + S], fill=(255, 215, 0))
        for c in d.get("landings", []):
            dr.ellipse([c[0] * S - 3, c[1] * S - 3, c[0] * S + 3, c[1] * S + 3], outline=(255, 255, 255))
        for c in d.get("camps", []):
            dr.ellipse([c[0] * S - 3, c[1] * S - 3, c[0] * S + 3, c[1] * S + 3], fill=(220, 40, 40))
        for c in d.get("wardens", []):
            dr.ellipse([c[0] * S - 2, c[1] * S - 2, c[0] * S + 2, c[1] * S + 2], fill=(160, 0, 200))
        dr.text((d["poi"][0] * S - 20, d["poi"][1] * S), d["name"], fill=(255, 255, 255))
    for L in lairs:
        cx, cz = L["at"]; h = L["half"]
        dr.rectangle([(cx - h) * S, (cz - h) * S, (cx + h + 1) * S, (cz + h + 1) * S], outline=(255, 80, 60), width=2)
    for o in outposts:
        dr.rectangle([o[0] * S - 6, o[1] * S - 6, o[0] * S + 6, o[1] * S + 6], outline=(120, 255, 200), width=2)
    for o in docks:
        dr.rectangle([o[0] * S - 5, o[1] * S - 5, o[0] * S + 5, o[1] * S + 5], outline=(120, 200, 255), width=2)
    for G in glides:
        dr.line([G["take"][0] * S, G["take"][1] * S, G["land"][0] * S, G["land"][1] * S], fill=(255, 255, 120), width=1)
    img.save(path)

def gap(a, b, owner):
    A = [p for p, o in owner.items() if o == a]; B = [p for p, o in owner.items() if o == b]
    edgeA = [p for p in A if any((p[0] + dx, p[1] + dz) not in owner for dx, dz in DIRS.values())]
    edgeB = [p for p in B if any((p[0] + dx, p[1] + dz) not in owner for dx, dz in DIRS.values())]
    return min(math.hypot(p[0] - q[0], p[1] - q[1]) for p in edgeA[::2] for q in edgeB[::2])

def main():
    lv, owner, stairs = rasterize()
    probs = check(lv, owner, stairs)
    for p in probs: print("PROBLEM", p)
    for G in glides:
        own = {p: o for p, o in owner.items() if lv[p] != -2}
        G["gap"] = round(gap(G["a"], G["b"], own), 1)
    if "--preview" in sys.argv:
        preview(sys.argv[sys.argv.index("--preview") + 1], lv, owner, stairs)
    for G in glides[::2]: print("glide %-10s -> %-10s gap %.1f m" % (G["a"], G["b"], G["gap"]))
    for B in bridges: print("bridge %-13s span %.1f m" % (B["name"], B["span"]))
    out = dict(id="hollowcrown", name="The Hollow Crown", size=SIZE, seed=5150, hand=True,
               notes="Hand-made expedition map (tools/make_hollowcrown.py; the format is described there). "
                     "A raised core (the Crown, its Throne and two boss Gaols), a ring of four regions each with one "
                     "plateau reached by stairs, and four quiet outer isles with the exits. Nothing is placed by dice "
                     "except what the match rolls: which spawn points, lairs and camps are live, loot, the Blight, weather.",
               regions=regions, islands=islands, bridges=bridges, glides=glides, pads=pads, updrafts=updrafts,
               winds=[], docks=docks, outposts=outposts, hatches=hatches, lairs=lairs, spawn_points=spawn_points)
    path = os.path.join(os.path.dirname(__file__), "..", "content", "maps", "hollowcrown.json")
    with open(path, "w") as f:
        json.dump(out, f, indent=1)
    print("wrote", os.path.normpath(path), "problems:", len(probs))

if __name__ == "__main__":
    main()
