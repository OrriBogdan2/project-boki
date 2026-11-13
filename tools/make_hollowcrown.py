#!/usr/bin/env python3
"""Builds content/maps/hollowcrown.json: the Hollow Crown, a hand-made expedition map (2.0: docs/MAP_V2.md).

The outlines, plateaus, stairs, bridges, walls, boulders and the places that matter (vault, tower tops,
lairs, exits, the shrine) are chosen by hand. The rest is laid out here by fixed rules and fixed seeds, so
a run always writes the same map: fill() spreads each island's chests, camps, landings, breakables,
weapons, Warden posts and trap spots farthest-first over its open ground (no stretch of land is far from
something to take: check_interest()), groves() packs Thornwood with trees round its lanes, maze() lays
Duskmoor's ruin walls, and place_cover() plants the tall grass. The engine reads the JSON; this script
keeps the numbers readable, works out bridge ends and stair feet, checks the layout and prints the cover
share per biome. It can draw a plan: python3 tools/make_hollowcrown.py --preview out.png. Never edit the
JSON by hand.

Layout (540 x 540 tiles = metres, north up; heights in terraces of 0.8 m). The middle of the map is the
Hollow, a void with Stormbreak's five shards tied by bridges; the Crown sits on its north rim. The west
is wide joined land, the east broken high ground. Each region is a different fight (docs/MAP_V2.md):

         [Highwatch]   [=========== Frostgate shelf ===========]   [Stormcrown
          towers        Rimefield (uplink A)                       Gaol]
             ||                    | Gate Span                       |
        [Larkhollow]=Lark Span=[ THE CROWN ]  ~ Ember Leap ~   [Cinder Steps]
         open plains (uplink B)   citadel                        cliff tiers,
             ||                     \\ Shard Stair                Sunken Forge
        [Thornwood]==Shard Walk==[Thorn sh.][STORMBREAK][Ember sh.]   |Slag Steps
         forest                [Salt sh.]  [Crown sh.]  \\==[Duskmoor] maze
              \\==Salt Walk==[ Saltmere lagoon ]==Moor Walk==//

FORMAT (what World.generate_authored reads; keys beyond Skyreach's are marked +):
  hand (+)            true: nothing is placed by dice. No auto stairs, no random rocks, no random
                      chests/camps/breakables/spawns: only what the layout lists. The match seed only
                      rolls spawn plan picks, live lairs, loot, the Blight and the weather.
  regions (+)         [{id, name, purpose, biome, islands: [ids], fight, hazard, hazard_areas, finals}]
                      named regions (map legend, docs). fight: the fight type; hazard / hazard_areas
                      [{kind, poly}]: where a region hazard goes (ext/region-hazards); finals: candidate
                      final-zone centres on fightable ground (ext/br-zone). The engine reads none of these
                      four yet.
  islands[]           id, name, role, region, biome, danger, poi, noise (coast wobble), sheer arcs,
                      colors (+, a few of the biome's ground colours replaced: a region's own tint)
    shapes            circle / ellipse / rect / capsule / poly (+, [[x,z],...]) each with "lv";
                      the first shape is the outline, later ones raise tiers inside it
    ramps (+)         [{at:[x,z], dir:"n|s|e|w", w, from, to, run}] a flight of stairs: its bottom
                      row starts at `at` (centre of its width) and rises toward dir, one terrace
                      per `run` tiles (run 2 puts a landing between steps). Written here with up():
                      from a spot on the lower ground toward dir; `at` is worked out so the top row
                      meets the plateau's edge
    walls             line / ring / box, as before (a lone post is a throw-clipping trap, so
                      tools/wall_size_check.gd wants every block piece 3+ tiles)
    rocks (+)         [[x0,z0,x1,z1]] boulder blocks (inclusive tile rects)
    trees (+)         [[x,z]] trees (they block like rocks; always in groves of 3, see thickets())
    crates (+)        [[x,z]] camp supply piles (block)
    bush              [[x,z,r]] tall grass to hide in: computed by place_cover() below, not listed by hand
    landings (+)      [[x,z]] where squads come down (World.spawns)
    camps (+)         [[x,z,"light|normal|heavy"]] monster camps (which monsters: rolled)
    chests            [[x,z]] (one locked chest type);  breakables (+) [[x,z,"crate|pot|barrel|keg"]];  weapons (+) [[x,z]]
    wild (+)          [[x,z]] wild Boki;  shrine (+) [x,z]
    wardens (+)       [[x,z]] Blight Warden posts (how many stand: rolled by danger)
    traps (+)         [[x,z]] where the region's traps go (which trap: the biome's list)
    areas (+)         [[x,z,"Name"]] named places inside an island (map labels)
  bridges             {name, a, b, from, to, r}; ends at different heights get a flight (+)
  glides              [a, b] or (+) {a, b, take:[x,z], land:[x,z], name}: glide routes for bots
  pads, updrafts, winds, heart (the Heart site [x, z]), outposts, lairs, spawn_points: as Skyreach
  ways_scale (+)     the Ways Out radii and bands over the 216 m design (SIZE / 216; tools/ways_out_sites.py)
  train (+)           {cars, speed, dwell, pier_below, path:[[x,z],...] (a closed winding loop, splined
                      from TRAIN_WAY), stations:[[x,z]] (points on the path), names}: the sky train
"""
import json, math, os, random, sys
import ways_out_sites

SIZE = 540          # the map's side in tiles (= metres): the one number to change to grow the map
DESIGN = 540        # the grid every coordinate below is written on; scale_layout() maps it onto SIZE
K = SIZE / DESIGN
WAYS = SIZE / 216   # the Ways Out rule's scale (its numbers are metres on the 216 m design)
LEVEL = 0.8

def poly(pts, lv=0, **k):
    return dict(poly=[list(p) for p in pts], lv=lv, **k)

def rect(x0, z0, x1, z1, lv):
    return poly([(x0, z0), (x1, z0), (x1, z1), (x0, z1)], lv)

def circle(x, z, r, lv=0, **k):
    return dict(circle=[x, z], r=r, lv=lv, **k)

def up(x, z, d, w, lv0, lv1, run=1):
    """A flight from the lower ground at (x, z) toward d, up to the first ground at lv1: resolve_ramps()
    puts its foot so the top row lands on the plateau's edge."""
    return dict(near=[x, z], dir=d, w=w, **{"from": lv0}, to=lv1, run=run)

def rocks(*rects):
    return [list(r) for r in rects]

# ------------------------------------------------------------------ the islands
# `fill` (popped before writing): how many of each kind fill() adds on top of the hand-placed ones.
# Camps are listed by tier.
islands = [
    # ---- THE CROWN (siege): a walled citadel on the Hollow's north rim. A crooked bailey (lv 4) holds the
    # keep (lv 8, three flights up) and the Throne (lv 12, two flights) with the vault. Wall runs split the
    # bailey into yards and flank its three gates: the Gate Span (N), the Lark Span (W), the Shard Stair (S).
    dict(id="crown", name="The Crown", role="heart", region=0, biome="gloom", danger=2, poi=[285, 212], noise=0.05,
         shapes=[poly([(222, 160), (262, 140), (300, 146), (338, 168), (362, 204), (360, 244), (340, 278), (302, 290),
                       (264, 272), (234, 240), (212, 200)], 4),
                 poly([(250, 170), (300, 162), (330, 180), (334, 215), (312, 240), (270, 244), (246, 222), (240, 192)], 8),
                 poly([(268, 196), (298, 192), (308, 212), (296, 230), (272, 230), (262, 214)], 12)],
         sheer=[[330, 30], [60, 120]],
         ramps=[up(228, 206, "e", 5, 4, 8), up(290, 262, "n", 5, 4, 8), up(348, 198, "w", 4, 4, 8),
                up(285, 178, "s", 4, 8, 12), up(250, 214, "e", 3, 8, 12)],
         walls=[dict(line=[282, 150, 282, 155]), dict(line=[298, 150, 298, 155]),
                dict(line=[220, 228, 224, 228]), dict(line=[220, 244, 224, 244]),
                dict(line=[286, 268, 286, 273]), dict(line=[306, 266, 306, 271]),
                dict(line=[256, 156, 268, 156]), dict(line=[312, 158, 324, 158]),
                dict(line=[340, 214, 350, 214]), dict(line=[318, 252, 328, 252]),
                dict(line=[228, 182, 228, 194]), dict(line=[250, 254, 262, 254])],
         rocks=rocks((236, 168, 237, 169), (338, 188, 339, 189), (266, 262, 267, 263), (338, 240, 339, 241)),
         chests=[[285, 212], [300, 205]],
         areas=[[285, 212, "The Throne"], [318, 205, "The Keep"]],
         fill=dict(chests=4, camps=["heavy", "heavy", "normal"], landings=4, breakables=9, weapons=1, wardens=4, traps=3)),
    # ---- Stormcrown Gaol: the Crown's boss rock, off Frostgate's east end.
    dict(id="gaol_ne", name="Stormcrown Gaol", role="camp", region=0, biome="storm", danger=2, poi=[466, 100], noise=0.05, landmark="",
         shapes=[poly([(440, 72), (478, 66), (500, 88), (496, 124), (470, 138), (444, 128), (432, 100)], 4)],
         sheer=[[200, 260]],
         fill=dict(chests=2, breakables=3, wardens=1)),
    # ---- FROSTGATE (sniping): a 260 m ice shelf 8 m up (lv 10), bare but for a few low benches, with the
    # walled Keep on its east end. The Rimefield (lv 4) runs under its south cliff: uplink A stands there,
    # in plain view of the shelf. Three long stairs up the shelf.
    dict(id="frostgate", name="Frostgate", role="camp", region=1, biome="frost", danger=1, poi=[300, 60], noise=0.05,
         shapes=[poly([(172, 52), (215, 30), (300, 22), (380, 26), (428, 36), (428, 74), (370, 90), (310, 104), (250, 110),
                       (195, 102), (168, 80)], 4),
                 poly([(192, 50), (226, 22), (300, 12), (380, 16), (414, 30), (412, 64), (355, 72), (300, 82), (245, 88),
                       (205, 84), (186, 70)], 10)],
         sheer=[[20, 160]],
         ramps=[up(178, 64, "e", 5, 4, 10), up(232, 104, "n", 5, 4, 10, run=2), up(334, 88, "n", 4, 4, 10)],
         walls=[dict(box=[384, 44, 404, 62], gates=["w", "s"], gate_w=3)],
         rocks=rocks((238, 58, 241, 58), (276, 46, 277, 47), (300, 66, 303, 66), (318, 44, 318, 46), (348, 56, 351, 56),
                     (262, 76, 262, 78), (214, 72, 215, 73), (208, 92, 209, 93), (380, 80, 381, 81)),
         chests=[[394, 53]],
         areas=[[394, 53, "Frostgate Keep"], [290, 96, "Rimefield"], [300, 50, "The Shelf"]],
         fill=dict(chests=5, camps=["light", "normal", "normal", "heavy"], landings=8, breakables=9, weapons=2, wardens=3, traps=1)),
    # ---- HIGHWATCH (towers): four rock towers over a low yard (lv 2): the Spur (lv 9), the Bellcliff
    # (lv 11), the Ward (lv 6) and the Lantern (a lv 8 ledge, then lv 14: the map's highest ground). One
    # flight up each; tower tops see each other, so fights go up and across.
    dict(id="highwatch", name="Highwatch", role="landing", region=6, biome="frost", danger=1, poi=[99, 82], noise=0.07,
         landmark="lighthouse", colors={"top": "b9c2c9", "top2": "9aa6b0", "side": "5f6670"},
         shapes=[poly([(40, 62), (92, 48), (140, 60), (152, 98), (146, 150), (124, 190), (72, 194), (36, 164), (26, 112)], 2),
                 rect(76, 62, 118, 108, 8), rect(90, 72, 108, 92, 14),
                 rect(44, 104, 68, 128, 9), rect(104, 118, 130, 146, 11), rect(60, 146, 86, 170, 6)],
         sheer=[[300, 360]],
         ramps=[up(68, 85, "e", 4, 2, 8), up(99, 104, "n", 3, 8, 14), up(56, 136, "n", 3, 2, 9),
                up(94, 132, "e", 3, 2, 11), up(73, 180, "n", 3, 2, 6)],
         rocks=rocks((96, 76, 98, 76), (102, 86, 104, 86), (50, 110, 52, 110), (120, 136, 121, 137), (64, 152, 66, 152)),
         chests=[[99, 80], [56, 116], [117, 126], [78, 158]],
         areas=[[99, 82, "The Lantern"], [117, 132, "Bellcliff"], [56, 116, "The Spur"]],
         fill=dict(chests=2, camps=["heavy", "light"], landings=6, breakables=6, weapons=1, wardens=2, traps=1)),
    # ---- LARKHOLLOW (open plains): the widest open ground, low (lv 0) with a few gentle swells (lv 1)
    # and boulder clusters. Ways in from three sides; wild Boki graze in the middle.
    dict(id="lark", name="Larkhollow", role="landing", region=5, biome="meadow", danger=0, poi=[110, 262], noise=0.08,
         landmark="giant_tree",
         shapes=[poly([(22, 214), (70, 202), (128, 202), (196, 222), (206, 250), (196, 270), (204, 300), (168, 332), (110, 336),
                       (52, 330), (34, 292), (50, 270), (16, 252)], 0),
                 circle(62, 250, 11, 1), circle(118, 236, 13, 1), circle(150, 292, 12, 1), circle(92, 296, 10, 1), circle(178, 262, 9, 1)],
         sheer=[[150, 210]],
         rocks=rocks((60, 232, 61, 233), (62, 233, 62, 234), (138, 256, 140, 257), (100, 278, 101, 279), (170, 300, 172, 300),
                     (40, 286, 41, 287), (186, 244, 186, 246)),
         wild=[[100, 262], [106, 268], [96, 270], [112, 258], [90, 256]],
         areas=[[110, 262, "The Graze"]],
         fill=dict(chests=6, camps=["light", "light", "normal", "normal"], landings=10, breakables=6, weapons=1, wardens=2)),
    # ---- THORNWOOD (forest ambush): a lv 2 wood packed with groves and tall grass, lanes cut between its
    # places; Bramble Rise (lv 6, stairs only) in the north holds the Thornhive. The Boki nest is in the west glade.
    dict(id="thorn", name="Thornwood", role="nest", region=4, biome="bloom", danger=1, poi=[130, 410], noise=0.07,
         shapes=[poly([(38, 346), (105, 342), (170, 346), (222, 362), (230, 410), (206, 452), (168, 446), (150, 466), (92, 460),
                       (52, 432), (30, 392)], 2),
                 poly([(108, 348), (162, 352), (172, 376), (146, 390), (110, 382)], 6)],
         sheer=[[30, 90]],
         ramps=[up(130, 398, "n", 4, 2, 6), up(186, 372, "w", 3, 2, 6)],
         wild=[[62, 404], [66, 410], [58, 412]],
         areas=[[140, 368, "Bramble Rise"], [62, 408, "Nest Glade"]],
         groves=95,
         fill=dict(chests=7, camps=["light", "normal", "normal", "heavy"], landings=7, breakables=8, weapons=1, wardens=3, traps=2)),
    # ---- SALTMERE (water edges): a lv 2 salt rim round a sunken lagoon (lv 0, the hazard branch's deep
    # water), one causeway across it and a cache islet in the east pool.
    dict(id="saltmere", name="Saltmere", role="landing", region=8, biome="bloom", danger=0, poi=[290, 490], noise=0.06,
         landmark="obelisk", colors={"top": "dcd8c8", "top2": "c4bda6", "side": "9a8f78"},
         shapes=[poly([(232, 462), (290, 452), (348, 466), (356, 498), (322, 522), (262, 526), (224, 506)], 0),
                 poly([(232, 462), (290, 452), (348, 466), (346, 478), (290, 471), (240, 478)], 2),
                 poly([(224, 506), (232, 462), (250, 466), (248, 512)], 2),
                 poly([(348, 466), (356, 498), (336, 512), (332, 474)], 2),
                 poly([(248, 512), (262, 526), (322, 522), (336, 512), (320, 508), (260, 508)], 2),
                 rect(286, 470, 294, 509, 2), circle(314, 492, 6, 2)],
         sheer=[[60, 120]],
         ramps=[up(266, 500, "s", 3, 0, 2), up(310, 484, "n", 3, 0, 2), up(256, 486, "w", 3, 0, 2), up(326, 500, "e", 3, 0, 2)],
         chests=[[314, 492]],
         areas=[[290, 490, "The Lagoon"]],
         fill=dict(chests=4, camps=["normal"], landings=4, breakables=6, wardens=1, traps=1)),
    # ---- DUSKMOOR (close quarters): a ruin maze of broken walls on 10 m cells (maze()) round the raised
    # Moor Chapel floor (lv 4). Short sightlines everywhere; relics in the ruins.
    dict(id="duskmoor", name="Duskmoor", role="landing", region=7, biome="storm", danger=1, poi=[418, 430], noise=0.05,
         landmark="menhirs", colors={"top": "8a7c96", "top2": "6f6380", "side": "4a4054"},
         shapes=[poly([(372, 392), (430, 384), (470, 404), (474, 446), (446, 476), (392, 478), (364, 452), (360, 414)], 2),
                 rect(408, 420, 428, 440, 4)],
         sheer=[[0, 60]],
         ramps=[up(418, 446, "n", 3, 2, 4), up(402, 430, "e", 3, 2, 4)],
         maze=dict(x=366, z=388, cols=12, rows=10, cell=9, seed=7, keep=(404, 416, 432, 444)),
         chests=[[418, 430]],
         areas=[[418, 430, "Moor Chapel"]],
         fill=dict(chests=6, camps=["light", "normal", "heavy"], landings=3, breakables=9, weapons=1, wardens=2, traps=2)),
    # ---- STORMBREAK (chokepoints): five shards over the Hollow, bridges only. The Shrine Table (lv 6) on
    # the biggest; every way across the middle of the map is a narrow bridge.
    dict(id="storm", name="Stormbreak", role="shrine", region=3, biome="storm", danger=1, poi=[300, 368], noise=0.05,
         shapes=[poly([(282, 350), (306, 346), (324, 360), (322, 384), (302, 394), (282, 386), (274, 368)], 2),
                 poly([(290, 358), (310, 356), (316, 370), (306, 380), (290, 377)], 6)],
         sheer=[[0, 360]],
         ramps=[up(300, 389, "n", 3, 2, 6)],
         shrine=[300, 367],
         chests=[[308, 364]],
         areas=[[300, 367, "Shrine Table"]],
         fill=dict(camps=["normal"], landings=1, breakables=3, wardens=1, traps=1)),
] + [dict(id=i, name=n, role="landing", region=3, biome="storm", danger=1, poi=p, noise=0.05, landmark="",
          shapes=[poly(s, 2)], sheer=[[0, 360]], fill=dict(chests=1, landings=1, breakables=2))
     for i, n, p, s in (("storm_n", "Crown Shard", [334, 318], [(320, 306), (344, 304), (352, 318), (342, 332), (324, 330)]),
                        ("storm_w", "Thorn Shard", [250, 338], [(236, 326), (258, 320), (266, 338), (254, 352), (236, 346)]),
                        ("storm_e", "Ember Shard", [374, 368], [(360, 356), (382, 352), (392, 368), (380, 382), (362, 378)]),
                        ("storm_s", "Salt Shard", [262, 420], [(248, 408), (272, 404), (280, 420), (266, 434), (248, 428)]))] + [
    # ---- CINDER STEPS (cliffs): a cliff wall climbing east in four tiers (lv 2, 6, 10, 14) to a sheer
    # east rim, two flights between each, switching sides. Uplink B and the Sunken Forge sit on the foot (lv 2), slag pools
    # (lava, for the hazard branch) at the cliff feet. Only the Gaol and Duskmoor bridge in; from the Crown
    # you glide (Ember Leap).
    dict(id="cinder", name="Cinder Steps", role="camp", region=2, biome="ember", danger=1, poi=[490, 240], noise=0.06,
         shapes=[poly([(402, 162), (445, 156), (500, 162), (526, 190), (528, 260), (516, 330), (490, 372), (450, 378),
                       (410, 350), (392, 300), (396, 240), (388, 190)], 2),
                 poly([(430, 170), (504, 172), (540, 196), (540, 340), (494, 380), (440, 352), (426, 300), (428, 230)], 6),
                 poly([(462, 180), (506, 182), (540, 210), (540, 300), (504, 330), (478, 336), (458, 300), (456, 230)], 10),
                 poly([(488, 190), (512, 192), (540, 220), (540, 270), (500, 298), (484, 292), (482, 230)], 14)],
         sheer=[[300, 60]],
         ramps=[up(410, 214, "e", 5, 2, 6), up(452, 370, "n", 4, 2, 6), up(440, 240, "e", 4, 6, 10),
                up(466, 345, "n", 4, 6, 10), up(474, 240, "e", 4, 10, 14), up(495, 312, "n", 3, 10, 14)],
         rocks=rocks((436, 200, 437, 201), (470, 196, 471, 197), (498, 230, 499, 231), (444, 316, 445, 317), (416, 184, 417, 185)),
         crates=[[420, 250], [421, 250], [420, 251]],
         chests=[[500, 244], [474, 168]],
         areas=[[498, 240, "The Kilns"], [414, 300, "Forge Yard"]],
         fill=dict(chests=8, camps=["light", "normal", "normal", "heavy"], landings=6, breakables=9, weapons=2, wardens=3, traps=2)),
]

BY = {d["id"]: d for d in islands}

# One line each in docs/MAP_REGIONS.md (fight types: docs/MAP_V2.md). "loot" leans chests on top of the
# biome's lean (BiomeRun): slot weights multiply, rarity steps add. Every region but the Crown can be the
# match's hot drop zone (HotZone).
regions = [
    dict(id="crown", name="The Crown", biome="gloom", islands=["crown", "gaol_ne"], fight="siege", hazard="",
         purpose="The vault on the Throne, the Stormcrown Eyrie and the richest chests, behind walls and gates, under the most Blight.",
         finals=[[262, 190], [318, 252]]),
    dict(id="frostgate", name="Frostgate", biome="frost", islands=["frostgate"], loot={"slots": {"armor": 1.6}}, fight="snipe", hazard="ice",
         purpose="The best armor on the map and the long shelf to shoot from; uplink A in the Rimefield below it.",
         finals=[[300, 58], [228, 70]]),
    dict(id="cinder", name="Cinder Steps", biome="ember", islands=["cinder"], loot={"slots": {"glove": 1.6}}, fight="cliffs", hazard="lava",
         hazard_areas=[dict(kind="lava", poly=[[398, 172], [420, 168], [424, 186], [402, 190]]),
                       dict(kind="lava", poly=[[418, 346], [438, 358], [432, 368], [414, 358]])],
         purpose="Forge country: gloves and weapon tunings up the cliff tiers, the Sunken Forge and uplink B at the foot.",
         finals=[[470, 250]]),
    dict(id="storm", name="Stormbreak", biome="storm", islands=["storm", "storm_n", "storm_w", "storm_e", "storm_s"],
         fight="chokepoint", hazard="",
         purpose="The shrine on the Shrine Table, in the middle of the Hollow: every way across is a bridge.",
         finals=[[300, 370]]),
    dict(id="thorn", name="Thornwood", biome="bloom", islands=["thorn"], fight="forest", hazard="",
         purpose="The Boki nest and the Thornhive lair; ambushes in the trees and tall grass.",
         finals=[[110, 420], [180, 412]]),
    dict(id="lark", name="Larkhollow", biome="meadow", islands=["lark"], fight="open", hazard="",
         purpose="Wild Boki graze on the open plain; the most landings, the widest flanks.",
         finals=[[110, 262], [60, 280]]),
    dict(id="highwatch", name="Highwatch", biome="frost", islands=["highwatch"], loot={"slots": {"boots": 1.8}}, fight="towers", hazard="ice",
         purpose="Boots, and the towers: the Lantern is the highest ground on the map.",
         finals=[[96, 130]]),
    dict(id="duskmoor", name="Duskmoor", biome="storm", islands=["duskmoor"], loot={"slots": {"passive": 2.0}}, fight="maze", hazard="",
         purpose="Relics in the Moor Chapel and its ruin maze: the closest fights on the map.",
         finals=[[418, 430]]),
    dict(id="saltmere", name="Saltmere", biome="bloom", islands=["saltmere"], fight="causeway", hazard="water",
         hazard_areas=[dict(kind="water", poly=[[250, 478], [285, 472], [285, 508], [252, 508]]),
                       dict(kind="water", poly=[[295, 472], [332, 476], [334, 508], [295, 508]])],
         purpose="Salt caches round the lagoon and on its islet; fights on the rim and the one causeway.",
         finals=[[290, 490]]),
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

# Bridges: the Crown's three gates, the west's wide necks, the east's long stairs and the Hollow's
# shard bridges. Ends at different heights carry a flight, so those bridges run along an axis.
BRIDGES = [
    ("Gate Span", "frostgate", "crown", (290, 100), (290, 150), 2.2),
    ("Lark Span", "lark", "crown", (190, 230), (238, 230), 2.0),
    ("Shard Stair", "crown", "storm_n", (330, 270), (330, 312), 1.8),
    ("Rime Stair", "highwatch", "frostgate", (146, 76), (182, 76), 1.8),
    ("Watch Neck", "highwatch", "lark", (100, 184), (100, 212), 6.0),
    ("Thorn Gate", "lark", "thorn", (80, 320), (80, 352), 6.0),
    ("Bramble Neck", "lark", "thorn", (150, 324), (150, 356), 4.0),
    ("Gaol Walk", "frostgate", "gaol_ne", (420, 62), (448, 84), 1.6),
    ("Eyrie Stair", "gaol_ne", "cinder", (470, 132), (470, 170), 1.6),
    ("Shrine Walk", "storm_n", "storm", (330, 326), (306, 356), 1.4),
    ("Ember Walk", "storm_n", "storm_e", (344, 328), (370, 360), 1.4),
    ("Thorn Walk", "storm_w", "storm", (260, 344), (284, 362), 1.4),
    ("Salt Shard Walk", "storm_s", "storm", (270, 410), (290, 384), 1.4),
    ("Shard Walk", "thorn", "storm_w", (220, 366), (244, 344), 1.6),
    ("Shard Rise", "storm_s", "saltmere", (262, 430), (266, 466), 1.6),
    ("Moor Bridge", "storm_e", "duskmoor", (380, 378), (392, 400), 1.6),
    ("Moor Walk", "saltmere", "duskmoor", (346, 486), (384, 456), 1.6),
    ("Slag Steps", "cinder", "duskmoor", (452, 368), (446, 400), 1.6),
    ("Salt Walk", "thorn", "saltmere", (212, 444), (240, 474), 1.6),
]

# Glide routes (bots take them; players can glide anywhere). Gaps are edge to edge, measured below.
glides = [
    dict(name="Ember Leap", a="crown", b="cinder", take=[358, 214], land=[402, 214]),
    dict(a="cinder", b="crown", take=[398, 252], land=[354, 240]),
    dict(name="Slag Leap", a="storm_e", b="cinder", take=[386, 360], land=[404, 340]),
    dict(a="cinder", b="storm_e", take=[402, 344], land=[384, 362]),
    dict(name="Bramble Leap", a="lark", b="storm_w", take=[204, 300], land=[244, 330]),
    dict(a="storm_w", b="lark", take=[240, 330], land=[200, 304]),
]

lairs = [
    dict(id="eyrie", name="Stormcrown Eyrie", boss="serpent", island="gaol_ne", at=[466, 100], half=7, gate="w", entry=["dial", "runes"]),
    dict(id="forge", name="The Sunken Forge", boss="colossus", island="cinder", at=[410, 280], half=7, gate="n", entry=["dial"]),
    dict(id="hive", name="The Thornhive", boss="brood", island="thorn", at=[140, 368], half=7, gate="s", entry=["dial", "wards"]),
]
# exits: two walled uplink outposts in the Ways Out band from the Heart, ~100 degrees apart round it
# (tools/ways_out_sites.py has the rule): the Rimefield under Frostgate's shelf, and Larkhollow's open plain.
outposts = [[296, 92, 1], [164, 224, 1]]
heart = [285, 212]                        # the Heart site: the Throne

# Spawn plan points; "cache" adds one per island from fill() (the farthest open spot from its chests).
spawn_points = {
    "rare_kin": dict(pick=[5, 5], points=[[100, 268, "Larkhollow"], [66, 140, "Highwatch"], [440, 460, "Duskmoor"],
                                          [270, 462, "Saltmere"], [62, 406, "Nest Glade"], [250, 98, "Rimefield"],
                                          [414, 320, "Forge Yard"], [356, 346, "Stormbreak"]]),
    "vault": dict(pick=[3, 3], points=[[394, 56, "Frostgate Keep"], [99, 84, "The Lantern"], [300, 369, "Shrine Table"],
                                       [418, 434, "Moor Chapel"], [496, 252, "The Kilns"]]),
    "cache": dict(pick=[7, 7], points=[]),
    "boss": dict(pick=[3, 3], points=[[466, 100, "Stormcrown Eyrie"], [410, 280, "The Sunken Forge"], [140, 368, "The Thornhive"]]),
}

# ------------------------------------------------------------------ onto the real grid
def sc(v):
    return round(v * K)

def sc_pt(p):
    return [sc(p[0]), sc(p[1])] + list(p[2:])

def sc_poly(P):
    return [[round(x * K, 1), round(z * K, 1)] for x, z in P]

def sc_shape(S):
    S = dict(S)
    if "poly" in S: S["poly"] = sc_poly(S["poly"])
    if "circle" in S: S["circle"] = [round(v * K, 1) for v in S["circle"]]; S["r"] = round(S["r"] * K, 1)
    return S

def sc_rect(R):
    """A boulder keeps its size; its corner moves."""
    return [sc(R[0]), sc(R[1]), sc(R[0]) + R[2] - R[0], sc(R[1]) + R[3] - R[1]]

def sc_rocks(rects):
    """Boulders that touch (corners too) are one piece: they move together, by their first one's offset,
    so an authored L stays an L (scaled corners one by one, it split into posts)."""
    out = []
    for i, R in enumerate(rects):
        for j in range(i):
            Q = rects[j]
            if R[0] <= Q[2] + 1 and Q[0] <= R[2] + 1 and R[1] <= Q[3] + 1 and Q[1] <= R[3] + 1:
                dx, dz = out[j][0] - Q[0], out[j][1] - Q[1]
                out.append([R[0] + dx, R[1] + dz, R[2] + dx, R[3] + dz]); break
        else:
            out.append(sc_rect(R))
    return out

def sc_cluster(pts):
    """Crate piles keep their shape: each cluster of three moves with its first piece."""
    out = []
    for i, p in enumerate(pts):
        a = pts[i - i % 3]
        out.append([sc(a[0]) + p[0] - a[0], sc(a[1]) + p[1] - a[1]])
    return out

def sc_wall(W):
    W = dict(W)
    for k in ("line", "box"):
        if k in W: W[k] = [sc(v) for v in W[k]]
    return W

POINT_KEYS = ("landings", "chests", "camps", "breakables", "weapons", "wild", "wardens", "traps", "areas")

def scale_layout():
    """Everything above is drawn on the DESIGN grid; this maps it onto SIZE (one constant to grow the map).
    Land, gaps and distances scale; things with a body (stairs, boulders, walls' thickness, lairs, bridge
    widths, maze cells, groves) keep their size."""
    for d in islands:
        d["poi"] = sc_pt(d["poi"])
        d["shapes"] = [sc_shape(S) for S in d["shapes"]]
        d["ramps"] = [dict(R, near=sc_pt(R["near"])) for R in d.get("ramps", [])]
        d["walls"] = [sc_wall(W) for W in d.get("walls", [])]
        d["rocks"] = sc_rocks(d.get("rocks", []))
        if "crates" in d: d["crates"] = sc_cluster(d["crates"])
        for k in POINT_KEYS:
            if k in d: d[k] = [sc_pt(p) for p in d[k]]
        if "shrine" in d: d["shrine"] = sc_pt(d["shrine"])
        if "maze" in d:
            M = d["maze"]; d["maze"] = dict(M, x=sc(M["x"]), z=sc(M["z"]), keep=tuple(sc(v) for v in M["keep"]))
    for R in regions:
        R["finals"] = [sc_pt(p) for p in R["finals"]]
        for H in R.get("hazard_areas", []): H["poly"] = sc_poly(H["poly"])
    for G in glides:
        G["take"] = sc_pt(G["take"]); G["land"] = sc_pt(G["land"])
    for L in lairs: L["at"] = sc_pt(L["at"])
    outposts[:] = [sc_pt(e) for e in outposts]
    heart[:] = sc_pt(heart)
    for sp in spawn_points.values(): sp["points"] = [sc_pt(p) for p in sp["points"]]
    bridges[:] = [bridge(n, a, b, sc_pt(p0), sc_pt(p1), r) for n, a, b, p0, p1, r in BRIDGES]

DIRS = {"n": (0, -1), "s": (0, 1), "e": (1, 0), "w": (-1, 0)}

def resolve_ramps():
    """Each up() flight: walk from its spot toward its direction to the first tile of its top level; the
    flight's top row is that tile, so its foot (`at`) is one flight-length back."""
    for d in islands:
        out = []
        for R in d.get("ramps", []):
            dx, dz = DIRS[R["dir"]]; x, z = R.pop("near")
            assert base_level(d["id"], x + 0.5, z + 0.5) == R["from"], ("stair spot not on its lower level", d["id"], x, z, R)
            for _ in range(80):
                x += dx; z += dz
                if base_level(d["id"], x + 0.5, z + 0.5) >= R["to"]: break
            else:
                raise AssertionError(("stair never meets its plateau", d["id"], R))
            n = (R["to"] - R["from"]) * R.get("run", 1)
            out.append(dict(at=[x - dx * n, z - dz * n], **R))
        d["ramps"] = out

def maze(d):
    """Duskmoor's ruins: a maze on square cells (depth-first, fixed seed), then a fifth of its walls
    knocked out so it loops instead of dead-ending, and every wall left broken by one gap. Pieces stay
    3+ tiles (wall_size_check). Cells off the island or in the `keep` box (the Chapel) get no walls."""
    M = d.pop("maze"); rng = random.Random(M["seed"]); c = M["cell"]
    cols, rows = M["cols"], M["rows"]
    k0x, k0z, k1x, k1z = M["keep"]
    def ok(x0, z0, x1, z1):
        if not all(inside(d["id"], x + 0.5, z + 0.5, 0.35) for x, z in ((x0, z0), (x1, z1))): return False
        return not (x1 >= k0x and x0 <= k1x and z1 >= k0z and z0 <= k1z)
    seen = {(0, 0)}; stack = [(0, 0)]; open_ = set()
    while stack:
        cx, cz = stack[-1]
        nb = [(cx + a, cz + b) for a, b in ((1, 0), (-1, 0), (0, 1), (0, -1)) if 0 <= cx + a < cols and 0 <= cz + b < rows and (cx + a, cz + b) not in seen]
        if not nb: stack.pop(); continue
        n = rng.choice(nb); open_.add(frozenset(((cx, cz), n))); seen.add(n); stack.append(n)
    walls = []
    for cz in range(rows):
        for cx in range(cols):
            for a, b in ((1, 0), (0, 1)):
                n = (cx + a, cz + b)
                if n[0] >= cols or n[1] >= rows or frozenset(((cx, cz), n)) in open_ or rng.random() < 0.2: continue
                x0, z0 = M["x"] + (cx + a) * c, M["z"] + (cz + b) * c          # the shared edge's first corner
                x1, z1 = (x0, z0 + c) if a else (x0 + c, z0)
                if not ok(x0, z0, x1, z1): continue
                g = rng.randint(3, c - 5)                                      # a 2-tile breach
                if a:
                    walls += [dict(line=[x0, z0, x0, z0 + g - 1]), dict(line=[x0, z0 + g + 2, x0, z1])]
                else:
                    walls += [dict(line=[x0, z0, x0 + g - 1, z0]), dict(line=[x0 + g + 2, z0, x1, z0])]
    d.setdefault("walls", []).extend(w for w in walls if max(abs(w["line"][2] - w["line"][0]), abs(w["line"][3] - w["line"][1])) >= 2)

bridges = []
scale_layout()
resolve_ramps()


# ------------------------------------------------------------------ the sky train
# The map's fast travel: a winding, irregular loop out through the void channels toward the outer isles
# clockwise from the Lark Halt round the whole map, with a stop in every region. Waypoints are on the design
# grid; the loop is a closed Catmull-Rom spline through them, written out every TRAIN_PT metres.
# SkyTrain runs legs at speed/1.5 on average (it eases in and out) and waits `dwell` s at each stop.
TRAIN_PT = 2.0          # m between written path points (TrainRoute resamples every 0.5 m)
TRAIN_CLEAR = 3.4       # m: between stops the track keeps this far from any ground but a bridge (else it dives under a rim)
PIER_REACH = 8.0        # m: a stop's pier (along the track's normal) reaches ground within this on one side (TrainRoute looks out to 16.7 m)
STOP_BRIDGE = 11.0      # m: a stop keeps this clear of bridges (the deck dives 4.6 m under one over ~8 m, never at a pier)
RUN_SPEED = 4.55        # m/s: the fastest frame on foot (content/rules/hunter_move.json "speed")
TRAIN_WAY = [(202, 268), (220, 244), (204, 198), (178, 160), (156, 120), (160, 70), (176, 40), (198, 31), (228, 12), (300, 6),
             (350, 8), (400, 10), (440, 30), (441, 52), (426, 92), (410, 130), (378, 170), (373, 200), (388, 226), (378, 270),
             (372, 300), (404, 345), (412, 369), (440, 380), (468, 389), (482, 406), (479, 429), (484, 452), (474, 484), (440, 490), (400, 491),
             (360, 510), (330, 528), (299, 528), (260, 534), (226, 522), (200, 486), (180, 468), (192, 455), (214, 462),
             (228, 446), (240, 430), (238, 404), (232, 372), (230, 330), (214, 300)]
TRAIN_STOPS = [((202, 268), "Lark Halt"), ((156, 120), "Watch Halt"), ((198, 31), "Frost Halt"), ((426, 92), "Eyrie Halt"),
               ((388, 226), "Cinder Halt"), ((479, 429), "Moor Halt"), ((299, 528), "Salt Halt"), ((192, 455), "Thorn Halt"),
               ((230, 330), "Shard Halt")]
train = dict(cars=4, speed=12.0, dwell=6.0, pier_below=5, path=[], stations=[], names=[n for _, n in TRAIN_STOPS])

def _spline(W, step):
    """Closed Catmull-Rom through the scaled waypoints, sampled about every `step` m."""
    P = [(x * K, z * K) for x, z in W]; n = len(P); out = []
    for i in range(n):
        p0, p1, p2, p3 = P[i - 1], P[i], P[(i + 1) % n], P[(i + 2) % n]
        L = math.hypot(p2[0] - p1[0], p2[1] - p1[1]); m = max(1, int(L / step))
        for j in range(m):
            t = j / m; t2 = t * t; t3 = t2 * t
            out.append(tuple(round(0.5 * (2 * p1[c] + (-p0[c] + p2[c]) * t + (2 * p0[c] - 5 * p1[c] + 4 * p2[c] - p3[c]) * t2
                                        + (-p0[c] + 3 * p1[c] - 3 * p2[c] + p3[c]) * t3), 1) for c in (0, 1)))
    return out

def lay_train():
    train["path"] = [list(p) for p in _spline(TRAIN_WAY, TRAIN_PT)]
    for (x, z), _ in TRAIN_STOPS:      # each stop snaps onto the loop
        q = min(train["path"], key=lambda p: math.hypot(p[0] - x * K, p[1] - z * K))
        train["stations"].append(list(q))

def _arc(path):
    s = [0.0]
    for i in range(1, len(path) + 1):
        a, b = path[i - 1], path[i % len(path)]; s.append(s[-1] + math.hypot(b[0] - a[0], b[1] - a[1]))
    return s

def _walk(lv, start):
    """Metres on foot from a tile to every tile (land and bridges; stairs and terraces cost nothing extra)."""
    import heapq
    dist = {start: 0.0}; q = [(0.0, start)]
    while q:
        d, p = heapq.heappop(q)
        if d > dist.get(p, 1e9): continue
        for dx in (-1, 0, 1):
            for dz in (-1, 0, 1):
                nq = (p[0] + dx, p[1] + dz)
                if nq == p or nq not in lv: continue
                nd = d + (1.4142 if dx and dz else 1.0)
                if nd < dist.get(nq, 1e9): dist[nq] = nd; heapq.heappush(q, (nd, nq))
    return dist

def check_train(lv, owner):
    """The loop clears the land between stops, every stop has ground for a pier, and riding from one stop
    to the next beats running it (on foot over land and bridges; no glides)."""
    probs = []; rows = []
    path = train["path"]; arc = _arc(path); L = arc[-1]
    idx = [path.index(st) for st in train["stations"]]
    s_st = [arc[i] for i in idx]
    land = [p for p, l in lv.items() if l != -2]
    grid = {}
    for p in land: grid.setdefault((p[0] // 8, p[1] // 8), []).append(p)
    def nearest_land(x, z, r):
        best = (1e9, None)
        for gx in range(int(x - r) // 8, int(x + r) // 8 + 1):
            for gz in range(int(z - r) // 8, int(z + r) // 8 + 1):
                for p in grid.get((gx, gz), []):
                    d = math.hypot(p[0] + 0.5 - x, p[1] + 0.5 - z)
                    if d < best[0]: best = (d, p)
        return best
    for i, (x, z) in enumerate(path):
        if min(abs((arc[i] - s + L / 2) % L - L / 2) for s in s_st) < 6.0: continue
        d, p = nearest_land(x, z, TRAIN_CLEAR)
        if d < TRAIN_CLEAR: probs.append("train at %s within %.1f m of %s ground" % ((x, z), d, owner[p]))
    ground_at = []
    for st, nm, k in zip(train["stations"], train["names"], idx):
        a, b = path[k - 1], path[(k + 1) % len(path)]
        f = math.hypot(b[0] - a[0], b[1] - a[1]); nx, nz = (b[1] - a[1]) / f, -(b[0] - a[0]) / f
        hit = None
        for t in range(int(1.7 * 2), int(PIER_REACH * 2) + 1):     # out along the normal, either side, like TrainRoute
            for sgn in (1, -1):
                q = (int(st[0] + nx * sgn * t / 2), int(st[1] + nz * sgn * t / 2))
                if hit is None and q in lv and lv[q] != -2 and lv[q] < train["pier_below"]: hit = (q, t / 2)
        if hit is None: probs.append("stop %s: no ground for a pier within %.0f m" % (nm, PIER_REACH))
        ground_at.append(hit[0] if hit else None); rows.append((nm, owner.get(hit[0], "?") if hit else "-", hit[1] if hit else 0))
    for st, nm in zip(train["stations"], train["names"]):      # (a bridge this near would pull the deck down at the pier)
        if any(l == -2 and math.hypot(p[0] + 0.5 - st[0], p[1] + 0.5 - st[1]) < STOP_BRIDGE for p, l in lv.items()):
            probs.append("stop %s within %.0f m of a bridge" % (nm, STOP_BRIDGE))
    reached = {next(r["id"] for r in regions if owner.get(p) in r["islands"]) for p in ground_at if p}
    for r in regions:
        if r["id"] not in reached: probs.append("the train doesn't stop in %s" % r["name"])
    legs = []
    for i in range(len(s_st)):
        j = (i + 1) % len(s_st)
        ride = ((s_st[j] - s_st[i]) % L) / train["speed"] * 1.5 + train["dwell"]
        a, b = ground_at[i], ground_at[j]
        run = _walk(lv, a).get(b, float("inf")) / RUN_SPEED if a and b else float("inf")
        legs.append((train["names"][i], train["names"][j], ride, run))
        if ride >= run: probs.append("riding %s -> %s (%.0f s) doesn't beat running it (%.0f s)" % (legs[-1][:3] + (run,)))
    return probs, rows, legs, L

lay_train()

# ------------------------------------------------------------------ a tile model, for checks and the preview

def rasterize():
    lv = {}; owner = {}; stairs = {}
    for d in islands:
        P = [q for S in d["shapes"][:1] for q in (S["poly"] if "poly" in S else
             [[S["circle"][0] - S["r"], S["circle"][1] - S["r"]], [S["circle"][0] + S["r"], S["circle"][1] + S["r"]]])]
        x0, x1 = max(0, int(min(p[0] for p in P)) - 7), min(SIZE, int(max(p[0] for p in P)) + 8)
        z0, z1 = max(0, int(min(p[1] for p in P)) - 7), min(SIZE, int(max(p[1] for p in P)) + 8)
        for z in range(z0, z1):
            for x in range(x0, x1):
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
            for back in (1, 2, 3):      # room to walk onto the bottom step: 3 tiles of ground at its foot
                foot = (R["at"][0] - dx * back, R["at"][1] - dz * back)
                assert lv.get(foot) == R["from"], ("ramp foot not on open ground", d["id"], R, foot, lv.get(foot))
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
        for R in d.get("rocks", []):      # a boulder half over the void is clipped to a post
            if any((x, z) not in lv for x in range(R[0], R[2] + 1) for z in range(R[1], R[3] + 1)):
                probs.append("%s rock %s over the void" % (d["id"], R))
            touch = [Q for Q in d["rocks"] if Q is not R and R[0] <= Q[2] + 1 and Q[0] <= R[2] + 1 and R[1] <= Q[3] + 1 and Q[1] <= R[3] + 1]
            if not touch and (R[2] - R[0] + 1) * (R[3] - R[1] + 1) < 3:     # (tools/wall_size_check.gd: no block piece under 3 tiles)
                probs.append("%s rock %s under 3 tiles" % (d["id"], R))
    for L in lairs:
        cx, cz = L["at"]; h = L["half"]
        lvs = set(); own = set()
        for z in range(cz - h - 2, cz + h + 3):
            for x in range(cx - h - 2, cx + h + 3):
                if (x, z) not in lv: probs.append("lair %s over the void at %s" % (L["id"], (x, z))); break
                lvs.add(lv[(x, z)]); own.add(owner[(x, z)])
        if len(own) > 1: probs.append("lair %s spans islands %s" % (L["id"], own))
    # Warden posts keep clear of camps and exits (9 m) and landings (8 m), as the Blight wants
    camps = [c for d in islands for c in d.get("camps", [])]
    lands = [c for d in islands for c in d.get("landings", [])]
    exits = [e[:2] for e in outposts]
    for d in islands:
        for wp in d.get("wardens", []):
            for lst, r, what in ((camps, 9, "camp"), (exits, 9, "exit"), (lands, 8, "landing")):
                for q in lst:
                    if math.hypot(wp[0] - q[0], wp[1] - q[1]) < r: probs.append("warden %s too close to %s %s" % (wp, what, q[:2]))
    on_ground = lambda x, z: (int(x), int(z)) in lv and (int(x), int(z)) not in stairs
    sites, arc = ways_out_sites.check(heart, outposts, lairs, on_ground, scale=WAYS)
    probs += sites
    print("heart gate: %d degrees of seeded angle are clear (%s)" % (len(arc), "%d..%d" % (arc[0], arc[-1]) if arc else "none"))
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
    for g in range(0, SIZE, 50):            # a 50 m grid, for reading coordinates off the plan
        dr.line([g * S, 0, g * S, SIZE * S], fill=(40, 44, 64)); dr.line([0, g * S, SIZE * S, g * S], fill=(40, 44, 64))
    for d in islands:
        for W in d.get("walls", []):
            for q in _wall_tiles(W): dr.rectangle([q[0] * S, q[1] * S, q[0] * S + S - 1, q[1] * S + S - 1], fill=(40, 36, 46))
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
    for L in lairs:
        cx, cz = L["at"]; h = L["half"]
        dr.rectangle([(cx - h) * S, (cz - h) * S, (cx + h + 1) * S, (cz + h + 1) * S], outline=(255, 80, 60), width=2)
    for o in outposts:
        dr.rectangle([o[0] * S - 6, o[1] * S - 6, o[0] * S + 6, o[1] * S + 6], outline=(120, 255, 200), width=2)
    for G in glides:
        dr.line([G["take"][0] * S, G["take"][1] * S, G["land"][0] * S, G["land"][1] * S], fill=(255, 255, 120), width=1)
    for R in regions:
        for H in R.get("hazard_areas", []):
            dr.polygon([c * S for q in H["poly"] for c in q], outline=(255, 90, 40) if H["kind"] == "lava" else (60, 160, 255))
        for f in R["finals"]:
            dr.line([f[0] * S - 8, f[1] * S - 8, f[0] * S + 8, f[1] * S + 8], fill=(255, 255, 255), width=2)
            dr.line([f[0] * S - 8, f[1] * S + 8, f[0] * S + 8, f[1] * S - 8], fill=(255, 255, 255), width=2)
    P = train["path"]
    dr.line([c * S for q in P + P[:1] for c in q], fill=(255, 150, 60), width=2)
    for q in train["stations"]:
        dr.ellipse([q[0] * S - 6, q[1] * S - 6, q[0] * S + 6, q[1] * S + 6], fill=(255, 150, 60))
    img.save(path)

def gap(a, b, owner):
    A = [p for p, o in owner.items() if o == a]; B = [p for p, o in owner.items() if o == b]
    edgeA = [p for p in A if any((p[0] + dx, p[1] + dz) not in owner for dx, dz in DIRS.values())]
    edgeB = [p for p in B if any((p[0] + dx, p[1] + dz) not in owner for dx, dz in DIRS.values())]
    return min(math.hypot(p[0] - q[0], p[1] - q[1]) for p in edgeA[::2] for q in edgeB[::2])

# ------------------------------------------------------------------ hiding cover
# The tall grass is computed here, not listed by hand (docs/decisions/0009-keys-and-cover.md). Each
# biome has a share of its walkable ground to cover (content/rules/keys.json "cover"): bloom a lot,
# meadow some, gloom a little, storm and ember less, frost almost none. Cover comes as PATCHES of 3-6
# overlapping clumps, put where a fight wants it: beside chests and camps, along the flanks of the
# lanes between landmarks, at cliff edges and bridge heads, around the heart's pillars, and in sight
# of every way out in the bush biomes. Nothing grows on stairs, ramps, bridges, landing drop circles,
# lair floors or across a lane: lanes keep a clear corridor. The seed is fixed, so the map is the same
# every time this script runs.
COVER_SEED = 61
BUSH_BIOMES = ("bloom", "meadow", "gloom", "storm")     # where Shrublings may live: also where exits get cover
AMBUSH_BIOMES = ("bloom", "meadow")     # where every chest and camp gets a patch beside it (--cover-check)
AMBUSH_R = (1.3, 1.9)   # m: clump radius of that patch (small enough to fit between a chest and its lanes)
AMBUSH_LEAST = 12       # tiles: the smallest such patch
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
EXIT_R = 5.5            # an outpost yard keeps this clear
SIGHT_R = 13.0          # a patch this close, in a clear line, is "in sight" of a way out

def _targets():
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

def _landmarks(d):
    """The places on an island a lane runs between."""
    pts = [tuple(p[:2]) for k in ("landings", "chests", "camps") for p in d.get(k, [])]
    pts += [tuple(e[:2]) for e in outposts if (int(e[0]), int(e[1])) in INISLE[d["id"]]]
    for R in d.get("ramps", []):
        dx, dz = DIRS[R["dir"]]
        pts.append((R["at"][0] - dx * 5, R["at"][1] - dz * 5))
    for B in bridges:
        if B["a"] == d["id"]: pts.append(tuple(B["from"]))
        if B["b"] == d["id"]: pts.append(tuple(B["to"]))
    return pts

def _lanes(d):
    """A spanning tree over the island's landmarks: the lanes people walk."""
    pts = _landmarks(d)
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

INISLE = {}

class Cover:
    def __init__(self, lv, owner, stairs):
        self.lv, self.owner, self.stairs = lv, owner, stairs
        for d in islands: INISLE[d["id"]] = {p for p, o in owner.items() if o == d["id"] and lv[p] >= 0}
        self.solid = set(); self.hard = set(); self.lanes = {}; self.things = {}
        for d in islands:
            for R in d.get("rocks", []):
                for z in range(R[1], R[3] + 1):
                    for x in range(R[0], R[2] + 1): self.solid.add((x, z))
            for t in d.get("trees", []) + d.get("crates", []) + d.get("pillars", []): self.solid.add((int(t[0]), int(t[1])))
            for W in d.get("walls", []): self.solid |= _wall_tiles(W)
        self.hard |= self.solid
        for d in islands:
            for R in d.get("ramps", []): self.hard |= ramp_tiles(R)
            for k in ("chests", "weapons", "wild", "wardens", "traps", "breakables"):
                for p in d.get(k, []): self.hard |= _disc_r(p[0] + 0.5, p[1] + 0.5, 1.7)
            if d.get("shrine"): self.hard |= _disc_r(d["shrine"][0], d["shrine"][1], 3.0)
            for p in d.get("camps", []): self.hard |= _disc_r(p[0] + 0.5, p[1] + 0.5, 3.6)
            for p in d.get("landings", []): self.hard |= _disc_r(p[0] + 0.5, p[1] + 0.5, LANDING_R)
        for L in lairs:
            h = L["half"]
            for z in range(L["at"][1] - h - 2, L["at"][1] + h + 3):
                for x in range(L["at"][0] - h - 2, L["at"][0] + h + 3): self.hard.add((x, z))
        for e in outposts: self.hard |= _disc_r(e[0] + 0.5, e[1] + 0.5, EXIT_R)
        for (x, z), l in lv.items():
            if l == -2:
                for dx in range(-2, 3):
                    for dz in range(-2, 3): self.hard.add((x + dx, z + dz))
        for q in stairs:
            for dx in range(-2, 3):
                for dz in range(-2, 3): self.hard.add((q[0] + dx, q[1] + dz))
        for d in islands:
            self.lanes[d["id"]] = _lanes(d)
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

def place_cover(lv, owner, stairs):
    """Fills every island's "bush" and returns the Cover (patches, shares) for the report."""
    T = _targets()
    C = Cover(lv, owner, stairs)
    ground = {}                     # biome -> walkable tiles; island -> tiles
    for d in islands:
        n = sum(1 for q in INISLE[d["id"]] if q not in C.solid and q not in C.stairs)
        ground[d["id"]] = n
    bground = {}
    for d in islands: bground[d["biome"]] = bground.get(d["biome"], 0) + ground[d["id"]]
    # a biome's cover is shared out over its islands by their ground; a perch stays bare
    budget = {}
    for b in bground:
        mid = COVER[b]["share"]
        assert T[b][0] <= mid <= T[b][1], ("cover share outside the target", b, mid)
        ids = [d for d in islands if d["biome"] == b and not d.get("perch")]
        tot = sum(ground[d["id"]] for d in ids)
        for d in ids: budget[d["id"]] = mid * bground[b] * ground[d["id"]] / max(1, tot)
    for d in islands: budget.setdefault(d["id"], 0.0)
    room = lambda d: sum(1 for q in INISLE[d["id"]] if q not in C.hard and C.void_ok(*q)) / max(1, ground[d["id"]])
    carry = {}                      # cover an island had no room for goes to the roomier islands of its biome
    for d in sorted(islands, key=room):
        iid = d["id"]; cfg = COVER[d["biome"]]
        rng = random.Random("%d:%s" % (COVER_SEED, iid))
        want = budget[iid] + carry.get(d["biome"], 0.0)
        if want <= 0: d["bush"] = []; continue
        have = lambda: sum(len(p["tiles"]) for p in C.patches if p["island"] == iid)
        anchors = {"exit": [], "chest": [], "camp": [], "bridge": [], "flank": [], "cliff": [], "pillar": []}
        ring = lambda c, r0, r1, k: [(c[0] + math.cos(a) * rr, c[1] + math.sin(a) * rr)
                                     for rr in [rng.uniform(r0, r1) for _ in range(k)] for a in [rng.uniform(0, math.tau)]]
        if d["biome"] in BUSH_BIOMES:
            for e in outposts:
                if (int(e[0]), int(e[1])) in INISLE[iid]: anchors["exit"].append(((e[0] + 0.5, e[1] + 0.5), None))
        rm = sum(cfg["r"]) / 2.0            # a clump this big, plus what must stay clear of it
        for p in d.get("chests", []): anchors["chest"] += [(q, None) for q in ring((p[0] + 0.5, p[1] + 0.5), 2.5 + rm, 4.0 + rm, 24)]
        for p in d.get("camps", []): anchors["camp"] += [(q, None) for q in ring((p[0] + 0.5, p[1] + 0.5), 4.4 + rm, 6.4 + rm, 24)]
        for B in bridges:
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
        # then, in bloom and meadow, a small patch beside each chest and camp (ambush play), whatever the share
        if d["biome"] in AMBUSH_BIOMES:
            small = dict(cfg, r=AMBUSH_R, n=(3, 4), least=AMBUSH_LEAST)
            for p, r0, r1 in [(p, 3.0, 5.5) for p in d.get("chests", [])] + [(p, 4.6, 6.2) for p in d.get("camps", [])]:
                for c in ring((p[0] + 0.5, p[1] + 0.5), r0, r1, 40):
                    P = C.patch(rng, iid, (round(c[0], 1), round(c[1], 1)), small)
                    if P and C.gap_ok(P[1], cfg["gap"]):
                        C.plant(iid, P[0], P[1], "chest"); break
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
        carry[d["biome"]] = max(0.0, want - have())
        d["bush"] = [[round(c[0], 1), round(c[1], 1), c[2]] for p in C.patches if p["island"] == iid for c in p["clumps"]]
    return C

def cover_report(C, lv, owner):
    T = _targets()
    ground = {}; bush = {}
    for d in islands:
        for q in INISLE[d["id"]]:
            if q in C.solid or q in C.stairs: continue
            ground[d["biome"]] = ground.get(d["biome"], 0) + 1
            if q in C.bush: bush[d["biome"]] = bush.get(d["biome"], 0) + 1
    rows = []
    for b in ("bloom", "meadow", "gloom", "storm", "ember", "frost"):
        share = bush.get(b, 0) / max(1, ground.get(b, 1))
        rows.append((b, share, T[b]))
    return rows

# ------------------------------------------------------------------ filling the land
FILL_SEED = 11
FILL_GRID = 2           # m between the spots fill() and groves() look at
FILL_EDGE = 4           # m: a filled spot keeps this far from the void
BREAK_KINDS = ("crate", "pot", "barrel", "keg")
GROVE_GAP = 6.5         # m between two groves' first trees
INTEREST_R = 40.0       # m: no land is farther than this from something to take or ride (~18 s at a run between two;
                        # owner 11-11: no >25 s empty runs)
FINAL_R = 25.0          # m: a candidate final-zone centre has this much fightable ground round it...
FINAL_LAND = 0.55       # ...at least this share of it land

def _blocked(lv, stairs):
    """Where a filled spot or a grove may not go: anything solid and a step round it, stairs and their
    approaches, bridges and their heads, lair floors, exit yards and the shrine."""
    B = set(stairs)
    for d in islands:
        for R in d.get("rocks", []): B |= {(x, z) for x in range(R[0] - 1, R[2] + 2) for z in range(R[1] - 1, R[3] + 2)}
        for p in d.get("trees", []) + d.get("crates", []): B |= _disc_r(p[0] + 0.5, p[1] + 0.5, 1.6)
        for W in d.get("walls", []):
            for q in _wall_tiles(W): B |= {(q[0] + dx, q[1] + dz) for dx in (-1, 0, 1) for dz in (-1, 0, 1)}
        for R in d.get("ramps", []): B |= ramp_tiles(R)
        if d.get("shrine"): B |= _disc_r(d["shrine"][0], d["shrine"][1], 4.0)
    for L in lairs:
        h = L["half"] + 3; x, z = L["at"][:2]
        B |= {(x + dx, z + dz) for dx in range(-h, h + 1) for dz in range(-h, h + 1)}
    for e in outposts: B |= _disc_r(e[0] + 0.5, e[1] + 0.5, EXIT_R + 1.5)
    for (x, z), l in lv.items():
        if l == -2: B |= {(x + dx, z + dz) for dx in range(-3, 4) for dz in range(-3, 4)}
    return B

def _open_spots(iid, lv, B, edge):
    """Every FILL_GRID-th tile of an island that is clear, `edge` m from the void and on flat ground."""
    return sorted(q for q in INISLE[iid] if q[0] % FILL_GRID == 0 and q[1] % FILL_GRID == 0 and q not in B
                  and all(lv.get((q[0] + dx, q[1] + dz), -1) >= 0 for dx in range(-edge, edge + 1, 2) for dz in range(-edge, edge + 1, 2))
                  and all(lv.get((q[0] + dx, q[1] + dz)) == lv[q] for dx in (-2, 0, 2) for dz in (-2, 0, 2)))

def _seeds(d):
    pts = [tuple(p[:2]) for k in POINT_KEYS if k != "areas" for p in d.get(k, [])]
    pts += [tuple(e[:2]) for e in outposts if (int(e[0]), int(e[1])) in INISLE[d["id"]]]
    pts += [tuple(L["at"]) for L in lairs if L["island"] == d["id"]]
    pts += [tuple(B["from"]) for B in bridges if B["a"] == d["id"]] + [tuple(B["to"]) for B in bridges if B["b"] == d["id"]]
    if d.get("shrine"): pts.append(tuple(d["shrine"]))
    return pts

def fill(lv, B):
    """Each island's `fill` counts, farthest-first: every new spot is the open spot farthest from all the
    island's places so far, so chests, camps and landings spread evenly and no corner is left empty.
    Warden posts keep the Blight's distances (9 m from camps and exits, 8 m from landings). Also picks each
    island's cache spawn point: its open spot farthest from everything once it is full."""
    camps = lambda: [c for d in islands for c in d.get("camps", [])]
    lands = lambda: [c for d in islands for c in d.get("landings", [])]
    for d in islands:
        F = d.pop("fill", {})
        cands = _open_spots(d["id"], lv, B, FILL_EDGE)
        if not cands: continue
        mind = [1e9] * len(cands)
        def add(p):
            for i, q in enumerate(cands):
                dd = math.hypot(q[0] - p[0], q[1] - p[1])
                if dd < mind[i]: mind[i] = dd
        for p in _seeds(d): add(p)
        for kind in ("landings", "camps", "chests", "weapons", "breakables", "traps", "wardens"):
            want = F.get(kind, 0)
            for k in range(len(want) if isinstance(want, list) else want):
                ok = range(len(cands))
                if kind == "wardens":
                    near = [(c, 9) for c in camps()] + [(e, 9) for e in outposts] + [(c, 8) for c in lands()]
                    ok = [i for i in ok if all(math.hypot(cands[i][0] - p[0], cands[i][1] - p[1]) >= r for p, r in near)]
                i = max(ok, key=lambda j: mind[j])
                q = cands[i]
                tag = [want[k]] if kind == "camps" else [BREAK_KINDS[len(d.get(kind, [])) % 4]] if kind == "breakables" else []
                d.setdefault(kind, []).append([q[0], q[1]] + tag); add(q)
        i = max(range(len(cands)), key=lambda j: mind[j])
        spawn_points["cache"]["points"].append([cands[i][0], cands[i][1], d["name"]])

def groves(lv, B):
    """An island's `groves`: groves of three trees on its open ground, GROVE_GAP apart, clear of its lanes
    and places (shuffled with a fixed seed, so the wood looks grown, not planted in rows)."""
    for d in islands:
        n = d.pop("groves", 0)
        if not n: continue
        rng = random.Random("groves:%d:%s" % (FILL_SEED, d["id"]))
        pts = _seeds(d); lanes = _lanes(d)
        cands = _open_spots(d["id"], lv, B, 3); rng.shuffle(cands)
        got = []
        for q in cands:
            if len(got) >= n: break
            c = (q[0] + 0.5, q[1] + 0.5)
            if any(math.hypot(c[0] - p[0], c[1] - p[1]) < 4.5 for p in pts): continue
            if any(_seg_dist(c[0], c[1], a, b) < LANE_HALF + 2.2 for a, b in lanes): continue
            if any(math.hypot(q[0] - g[0], q[1] - g[1]) < GROVE_GAP for g in got): continue
            got.append(q)
        d["trees"] = d.get("trees", []) + [[x + dx, z + dz] for x, z in got for dx, dz in ((0, 0), (1, 0), (0, 1))]

def clear_maze(d, stairs):
    """Maze walls give way to the island's stairs and bridge heads."""
    keep = set()
    for R in d.get("ramps", []): keep |= ramp_tiles(R)
    for B in bridges:
        for end, isl in ((B["from"], B["a"]), (B["to"], B["b"])):
            if isl == d["id"]: keep |= _disc_r(end[0], end[1], 5.0)
    d["walls"] = [W for W in d["walls"] if not (_wall_tiles(W) & keep)]

def interests():
    pts = [(p[0], p[1]) for d in islands for k in ("chests", "camps", "landings", "weapons") for p in d.get(k, [])]
    pts += [tuple(d["shrine"][:2]) for d in islands if d.get("shrine")]
    pts += [tuple(L["at"]) for L in lairs] + [tuple(e[:2]) for e in outposts] + [tuple(s) for s in train["stations"]]
    return pts

def check_interest(lv, owner):
    """The farthest any land is from something to take or ride, per region (problems past INTEREST_R)."""
    grid = {}
    for p in interests(): grid.setdefault((int(p[0]) // 20, int(p[1]) // 20), []).append(p)
    reg = {i: r["id"] for r in regions for i in r["islands"]}
    worst = {}; probs = []
    for (x, z), l in lv.items():
        if l < 0 or (x + z) % 3: continue
        best = 1e9
        for r in range(0, 5):
            for gx in range(x // 20 - r, x // 20 + r + 1):
                for gz in range(z // 20 - r, z // 20 + r + 1):
                    if max(abs(gx - x // 20), abs(gz - z // 20)) != r: continue
                    for p in grid.get((gx, gz), ()): best = min(best, math.hypot(p[0] - x, p[1] - z))
            if best <= r * 20: break
        R = reg[owner[(x, z)]]
        if best > worst.get(R, (0, None))[0]: worst[R] = (best, (x, z))
    for R, (dd, at) in worst.items():
        if dd > INTEREST_R: probs.append("%s: land at %s is %.0f m from anything to take (want <= %.0f)" % (R, at, dd, INTEREST_R))
    return probs, worst

def check_reach(lv):
    """All land starts inside the Blight ring's first radius round the Heart."""
    r0 = ways_out_sites.RING_R0 * WAYS
    far = max((math.hypot(x + 0.5 - heart[0], z + 0.5 - heart[1]), (x, z)) for (x, z) in lv)
    return (["land at %s is %.0f m from the Heart, outside the ring's first %.0f m" % (far[1], far[0], r0)] if far[0] > r0 else []), far[0]

def check_finals(lv, stairs):
    probs = []
    for R in regions:
        for p in R["finals"]:
            q = (int(p[0]), int(p[1]))
            if lv.get(q, -1) < 0 or q in stairs: probs.append("%s final %s not on open ground" % (R["id"], p)); continue
            disc = _disc_r(p[0] + 0.5, p[1] + 0.5, FINAL_R)
            share = sum(1 for t in disc if t in lv) / len(disc)
            if share < FINAL_LAND: probs.append("%s final %s: only %.0f %% land within %.0f m" % (R["id"], p, share * 100, FINAL_R))
    return probs

def main():
    lv, owner, stairs = rasterize()
    for d in islands: INISLE[d["id"]] = {p for p, o in owner.items() if o == d["id"] and lv[p] >= 0}
    for d in islands:
        if "maze" in d: maze(d); clear_maze(d, stairs)
    B = _blocked(lv, stairs)
    fill(lv, B)
    groves(lv, _blocked(lv, stairs))
    C = place_cover(lv, owner, stairs)
    probs = check(lv, owner, stairs)
    tp, stops, legs, loop = check_train(lv, owner)
    probs += tp
    ip, worst = check_interest(lv, owner); probs += ip
    rp, far = check_reach(lv); probs += rp
    probs += check_finals(lv, stairs)
    for b, share, tg in cover_report(C, lv, owner):
        print('cover %-7s %5.1f %%  (target %.1f-%.1f %%)' % (b, share * 100, tg[0] * 100, tg[1] * 100))
    print('cover patches', len(C.patches), 'clumps', sum(len(p['clumps']) for p in C.patches))
    reg = {i: r["id"] for r in regions for i in r["islands"]}
    for r in regions:
        n = sum(1 for p, o in owner.items() if lv[p] >= 0 and reg[o] == r["id"])
        print("region %-10s %-10s %6d m2  farthest from a place %4.0f m" % (r["id"], r["fight"], n, worst.get(r["id"], (0,))[0]))
    total = lambda k: sum(len(d.get(k, [])) for d in islands)
    print("land %d m2 in %d x %d; farthest land from the Heart %.0f m; chests %d camps %d landings %d breakables %d trees %d walls %d"
          % (sum(1 for l in lv.values() if l >= 0), SIZE, SIZE, far, total("chests"), total("camps"), total("landings"),
             total("breakables"), total("trees"), total("walls")))
    for p in probs: print("PROBLEM", p)
    for G in glides:
        own = {p: o for p, o in owner.items() if lv[p] != -2}
        G["gap"] = round(gap(G["a"], G["b"], own), 1)
    if "--preview" in sys.argv:
        preview(sys.argv[sys.argv.index("--preview") + 1], lv, owner, stairs)
    for G in glides[::2]: print("glide %-10s -> %-10s gap %.1f m" % (G["a"], G["b"], G["gap"]))
    for B_ in bridges: print("bridge %-13s span %.1f m" % (B_["name"], B_["span"]))
    print("train loop %.0f m, %d stops, a lap %.0f s" % (loop, len(stops), sum(l[2] for l in legs)))
    for (nm, isl, d), (a, b, ride, run) in zip(stops, legs):
        print("train %-12s (%-9s pier %4.1f m) -> %-12s ride %3.0f s, run %s" % (nm, isl, d, b, ride, "%.0f s" % run if run < 1e9 else "no way on foot"))
    out = dict(id="hollowcrown", name="The Hollow Crown", size=SIZE, seed=5150, hand=True,
               notes="Hand-made expedition map (tools/make_hollowcrown.py; the format is described there; the design is "
                     "docs/MAP_V2.md). A broken continent round the Hollow: wide joined land in the west, broken high "
                     "ground in the east, Stormbreak's shards in the void between, the walled Crown on its north rim; "
                     "each region a different fight. Nothing is placed by dice except what the match rolls: which spawn "
                     "points, lairs and camps are live, loot, the Blight, weather.",
               regions=regions, islands=islands, bridges=bridges, glides=glides, pads=[], updrafts=[],
               winds=[], train=train, heart=heart, ways_scale=round(WAYS, 3), outposts=outposts, lairs=lairs, spawn_points=spawn_points)
    path = os.path.join(os.path.dirname(__file__), "..", "content", "maps", "hollowcrown.json")
    with open(path, "w") as f:
        json.dump(out, f, indent=1)
    print("wrote", os.path.normpath(path), "problems:", len(probs))

if __name__ == "__main__":
    main()
