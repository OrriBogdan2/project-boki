#!/usr/bin/env python3
"""Builds content/maps/hollowcrown.json: the Hollow Crown, a hand-made expedition map.

Every coordinate here is chosen by hand, except the tall grass: place_cover() plants that from rules
(per-biome share, patches beside chests, camps, lanes, cliffs, bridge heads, in sight of the exits) with a
fixed seed, so a run always writes the same map. The engine reads the JSON; this script keeps the numbers
readable, works out bridge ends from the island outlines, checks the layout (lairs on flat ground, spots
on open ground, ramps landing where they should), prints the cover share per biome and can draw a
preview: python3 tools/make_hollowcrown.py --preview out.png. Never edit the JSON by hand.

Layout (drawn on the 216 DESIGN grid; scale_layout() spreads it over SIZE x SIZE tiles = metres, so
the map is ~2x the land at SIZE 305; north up, heights in terraces of 0.8 m):

                  [Highwatch]           outer isles: lv 0, quiet landings, docks / uplinks
     [Larkhollow]   [  Frostgate  ]--   mid ring:    lv 2, one raised plateau each (lv 6)
          |          ||  Gate Span  [Stormcrown Gaol]   core: lv 4, the Throne at lv 8
     [Cinder ]   [ THE CROWN ]=====/
     [Steps  ]   [  (Throne) ]   [Stormbreak]
          \\ Ash   ||Bramble
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
    walls             line / ring / box, as before; pillars [[x,z]] (ruins; none here, a lone post is a
                      throw-clipping trap, so tools/wall_size_check.gd wants every block piece 3+ tiles)
    rocks (+)         [[x0,z0,x1,z1]] boulder blocks (inclusive tile rects)
    trees (+)         [[x,z]] trees (they block like rocks; keep them in groves of 3+, see thickets())
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
  pads, updrafts, winds, docks, outposts, hatches, lairs, spawn_points: as Skyreach
  train (+)           {cars, speed, dwell, pier_below, path:[[x,z],...] (a closed winding loop, splined
                      from TRAIN_WAY), stations:[[x,z]] (points on the path), names}: the sky train
"""
import json, math, os, random, sys

SIZE = 305          # the map's side in tiles (= metres): the one number to change to grow the map
DESIGN = 216        # the grid every coordinate below is written on; scale_layout() maps it onto SIZE
K = SIZE / DESIGN
LEVEL = 0.8

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
                dict(line=[104, 115, 106, 115]), dict(line=[110, 115, 112, 115]),
                dict(line=[99, 104, 101, 104]), dict(line=[115, 104, 117, 104]),
                dict(line=[99, 112, 101, 112]), dict(line=[115, 112, 117, 112]),
                dict(line=[86, 101, 86, 103]), dict(line=[86, 113, 86, 115]),
                dict(line=[130, 101, 130, 103]), dict(line=[130, 113, 130, 115])],
         rocks=rocks((86, 90, 87, 91), (130, 88, 131, 89), (85, 126, 86, 127), (129, 126, 130, 127)),
         landings=[],
         chests=[[108, 108], [84, 108], [132, 108]],
         camps=[[94, 88, "heavy"], [122, 128, "heavy"]],
         breakables=[[126, 88, "barrel"], [127, 88, "crate"], [89, 128, "pot"], [90, 128, "crate"]],
         wardens=[[114, 94], [98, 124], [108, 110]],
         traps=[[96, 96], [120, 120]]),
    # ---- The Gaols: two lair rocks bridged to the Crown, the best (and most fought-over) bosses.
    dict(id="gaol_ne", name="Stormcrown Gaol", role="camp", region=0, biome="storm", danger=2, poi=[157, 79], noise=0.05, landmark="",
         shapes=[poly([(146, 56), (164, 52), (172, 60), (170, 78), (158, 85), (146, 79), (142, 66)], 4)],
         sheer=[[200, 260]],
         rocks=rocks((149, 79, 151, 79)),
         chests=[[164, 79]], camps=[], breakables=[[150, 78, "pot"], [151, 79, "pot"]],
         wardens=[[160, 81]], traps=[]),
    dict(id="gaol_sw", name="Ashen Gaol", role="camp", region=0, biome="ember", danger=2, poi=[56, 162], noise=0.05, landmark="",
         shapes=[poly([(48, 138), (62, 133), (74, 139), (77, 156), (68, 166), (52, 164), (44, 152)], 4)],
         sheer=[[20, 80]],
         rocks=rocks((72, 158, 72, 160)),
         chests=[[62, 161]], camps=[], breakables=[[51, 140, "keg"], [52, 140, "crate"]],
         wardens=[[74, 146]], traps=[]),
    # ---- FROSTGATE (north): a long frozen ridge. The Keep (lv 6, walled) on its east end looks straight
    # down the Gate Span into the Crown; reach it by the West Stair or the narrow South Stair. The open
    # Rimefield to the west has boulders for cover and a light camp.
    dict(id="frostgate", name="Frostgate", role="camp", region=1, biome="frost", danger=1, poi=[90, 44], noise=0.06,
         shapes=[poly([(70, 40), (84, 26), (108, 22), (132, 25), (146, 38), (142, 56), (124, 66), (96, 66), (78, 58)], 2),
                 poly([(116, 30), (134, 30), (142, 40), (138, 54), (116, 54)], 6)],
         sheer=[[20, 70]],
         ramps=[ramp(112, 42, "e", 5, 2, 6), ramp(127, 57, "n", 3, 2, 6)],
         walls=[dict(box=[120, 33, 136, 50], gates=["w", "s"], gate_w=3)],
         rocks=rocks((84, 38, 85, 39), (96, 50, 98, 50), (102, 32, 103, 32), (102, 33, 102, 34), (88, 56, 90, 56)),
         landings=[[84, 32]],
         chests=[[128, 41], [76, 44]],
         camps=[[92, 44, "light"], [131, 44, "normal"]],
         breakables=[[106, 26, "crate"], [107, 26, "barrel"], [122, 62, "pot"]],
         weapons=[[104, 56]],
         wardens=[[104, 48], [126, 52]],
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
         crates=[[50, 104], [51, 104], [50, 105]],
         landings=[[38, 120], [58, 66]],
         chests=[[46, 70], [52, 118]],
         camps=[[46, 76, "normal"], [42, 100, "light"]],
         breakables=[[60, 68, "keg"], [33, 90, "crate"], [34, 90, "crate"], [52, 124, "pot"]],
         weapons=[[38, 108]],
         wardens=[[56, 92], [40, 66]],
         traps=[[48, 110]],
         areas=[[46, 70, "The Kilns"], [40, 114, "Forge Yard"]]),
    # ---- STORMBREAK (east): a storm-lashed tableland. The Shrine Table (lv 6) rises in the middle, up
    # the South Ramp (a long flight with landings). The Moor Steps run south to Duskmoor.
    dict(id="storm", name="Stormbreak", role="shrine", region=3, biome="storm", danger=1, poi=[176, 115], noise=0.06,
         shapes=[poly([(156, 96), (172, 90), (188, 96), (195, 114), (190, 134), (178, 146), (162, 142), (154, 124)], 2),
                 poly([(168, 102), (182, 102), (186, 114), (180, 128), (168, 128), (164, 118), (164, 110)], 6)],
         sheer=[[340, 20]],
         ramps=[ramp(174, 135, "n", 5, 2, 6, run=2)],
         rocks=rocks((160, 100, 161, 101), (186, 130, 187, 131), (168, 136, 170, 136),
                     (158, 112, 158, 115), (190, 106, 190, 109), (160, 132, 162, 132)),
         landings=[[186, 100], [176, 140]],
         chests=[[172, 108], [184, 132]],
         camps=[[180, 112, "normal"], [162, 104, "light"]],
         breakables=[[170, 96, "crate"], [171, 96, "pot"], [158, 128, "barrel"]],
         weapons=[[190, 126]],
         wardens=[[172, 132], [170, 122]],
         traps=[[166, 120]],
         shrine=[174, 118]),
    # ---- THORNWOOD (south): a low bramble wood full of tall grass and blossom trees, the Boki nest in
    # its west glade and the Thornhive lair at its east end on Bramble Rise (lv 4, stairs from the
    # wood), with an uplink outpost by the nest.
    dict(id="thorn", name="Thornwood", role="nest", region=4, biome="bloom", danger=1, poi=[96, 170], noise=0.06,
         shapes=[poly([(84, 154), (104, 150), (126, 152), (142, 158), (147, 172), (137, 186), (112, 192), (90, 188), (78, 174)], 2),
                 poly([(126, 160), (140, 162), (144, 172), (136, 182), (124, 176), (122, 166)], 4)],
         ramps=[ramp(120, 170, "e", 3, 2, 4, run=2)],
         sheer=[[60, 110]],
         trees=thickets((104, 156), (86, 180), (118, 182)),
         rocks=rocks((108, 172, 109, 173)),
         landings=[[86, 168]],
         chests=[[100, 166], [114, 176], [134, 172]],
         camps=[[98, 160, "light"]],
         wild=[[94, 172], [97, 168]],
         breakables=[[82, 172, "pot"], [83, 173, "pot"], [138, 160, "crate"]],
         weapons=[[106, 186]],
         wardens=[[112, 168]],
         traps=[[104, 172]],
         areas=[[133, 170, "Bramble Rise"]]),
    # ---- the outer isles: low, monster-light landings, each with a way out of the match and its own
    # shape and reason to come (docs/MAP_REGIONS.md).
    # Larkhollow: a grassy bowl ringed by three rim mounds (lv 2) with gaps for ways in. Wild Boki
    # graze in the bowl; the rims are the cover, the giant tree on the north coast the landmark.
    dict(id="lark", name="Larkhollow", role="landing", region=5, biome="meadow", danger=0, poi=[32, 28], noise=0.08,
         landmark="giant_tree",
         shapes=[poly([(16, 16), (36, 10), (52, 18), (55, 34), (44, 46), (22, 44), (12, 30)], 0),
                 poly([(20, 16), (34, 13), (40, 16), (36, 19), (26, 19), (21, 22)], 2),
                 poly([(43, 21), (48, 24), (47, 34), (43, 37), (42, 30)], 2),
                 poly([(21, 34), (25, 33), (28, 36), (34, 39), (32, 41), (22, 40), (19, 37)], 2)],
         sheer=[[90, 150]],
         landings=[[34, 30], [50, 28], [14, 26]],
         chests=[[28, 26], [42, 40]],
         camps=[], breakables=[[30, 22, "crate"], [31, 22, "keg"]],
         wild=[[30, 30], [36, 26], [34, 34]],
         wardens=[],
         areas=[[32, 28, "The Hollow"]]),
    # Highwatch: the Lookout, a cliff shelf (lv 4) on the north coast, one stair up from the yard. It
    # looks over the Gaol and the Watch Road; boulders on top are the only cover. The lighthouse
    # beside it is the landmark, the uplink in the yard the way out.
    dict(id="highwatch", name="Highwatch", role="landing", region=6, biome="frost", danger=0, poi=[184, 22], noise=0.08,
         landmark="lighthouse",
         shapes=[poly([(170, 12), (192, 10), (204, 22), (202, 40), (186, 46), (172, 38), (166, 24)], 0),
                 poly([(174, 13), (191, 11), (197, 16), (194, 23), (180, 23), (174, 18)], 4)],
         sheer=[[0, 60]],
         ramps=[ramp(182, 26, "n", 3, 0, 4)],
         rocks=rocks((178, 15, 180, 16), (190, 14, 191, 15)),
         landings=[[180, 36], [196, 30], [172, 28]],
         chests=[[185, 15], [198, 34]],
         camps=[], breakables=[[184, 40, "crate"], [185, 40, "pot"]],
         wardens=[[182, 19]],
         areas=[[184, 15, "The Lookout"]]),
    # Duskmoor: the ruined chapel on a raised floor (lv 2), its broken walls the cover, with the stone
    # ring beside it as the landmark. Relics turn up in the ruins; the skiff dock is the way out.
    dict(id="duskmoor", name="Duskmoor", role="landing", region=7, biome="storm", danger=0, poi=[188, 184], noise=0.08,
         landmark="menhirs",
         shapes=[poly([(176, 168), (196, 164), (206, 178), (202, 198), (184, 206), (170, 196), (168, 180)], 0),
                 poly([(182, 176), (195, 176), (197, 190), (184, 192), (181, 186)], 2)],
         sheer=[[150, 210]],
         ramps=[ramp(180, 184, "e", 3, 0, 2), ramp(190, 192, "n", 3, 0, 2)],
         walls=[dict(line=[184, 179, 188, 179]), dict(line=[191, 179, 194, 179]),
                dict(line=[194, 180, 194, 183]), dict(line=[186, 188, 186, 190]),
                dict(line=[173, 188, 173, 191]), dict(line=[198, 168, 201, 168])],
         rocks=rocks((190, 186, 191, 187)),
         landings=[[176, 176], [200, 192], [186, 200]],
         chests=[[190, 182], [192, 170]],
         camps=[[178, 194, "light"]], breakables=[[200, 184, "keg"], [200, 185, "crate"]],
         wardens=[[188, 172]],
         areas=[[189, 184, "Moor Chapel"]]),
    # Saltmere: a dry salt river winds north to south between two raised banks (lv 2). The riverbed is
    # a sunken lane with salt caches along it; the banks look down into it. The salt obelisk is the
    # landmark, the uplink at the river's bend the way out.
    dict(id="saltmere", name="Saltmere", role="landing", region=8, biome="bloom", danger=0, poi=[26, 186], noise=0.08,
         landmark="obelisk",
         shapes=[poly([(14, 170), (30, 164), (44, 172), (46, 190), (34, 204), (16, 202), (8, 186)], 0),
                 poly([(14, 171), (23, 167), (24, 176), (21, 184), (22, 194), (25, 202), (16, 201), (9, 186)], 2),
                 poly([(31, 166), (43, 173), (45, 190), (35, 202), (31, 198), (32, 190), (31, 180), (33, 172)], 2)],
         sheer=[[150, 210]],
         ramps=[ramp(23, 180, "w", 3, 0, 2), ramp(30, 192, "e", 3, 0, 2)],
         landings=[[14, 190], [38, 178], [28, 198]],
         chests=[[14, 182], [26, 196], [36, 180]],
         camps=[], breakables=[[18, 176, "pot"], [19, 176, "pot"]],
         wardens=[],
         areas=[[27, 184, "Salt River"]]),
]

BY = {d["id"]: d for d in islands}

# The second wave: what the doubled map adds to each island (same design grid), so chests, camps,
# landings and exits per square metre stay about where the 216 m map had them. Every pick fills ground
# that scaling opened up: a far corner, the other side of a plateau, the stretch between two landmarks.
MORE = {
    "crown": dict(chests=[[98, 89], [118, 128]], camps=[[86, 118, "heavy"]],
                  breakables=[[132, 96, "crate"], [133, 96, "pot"]], wardens=[[90, 98]], traps=[[108, 128]]),
    "gaol_ne": dict(chests=[[147, 62]]),
    "gaol_sw": dict(chests=[[48, 150]]),
    "frostgate": dict(chests=[[94, 30], [100, 62]], camps=[[80, 48, "heavy"]], landings=[[110, 28], [118, 62], [74, 46]],
                      breakables=[[78, 52, "crate"], [79, 52, "pot"]], weapons=[[120, 60]], wardens=[[120, 27]]),
    "cinder": dict(chests=[[30, 100], [46, 93]], camps=[[34, 110, "heavy"]], landings=[[28, 84], [54, 112], [36, 116]],
                   breakables=[[46, 123, "barrel"]], wardens=[[62, 94]], traps=[[30, 80]]),
    "storm": dict(chests=[[190, 110], [160, 136]], camps=[[160, 116, "heavy"]], landings=[[158, 104], [190, 120], [166, 94]],
                  breakables=[[188, 106, "crate"], [189, 106, "keg"]]),
    "thorn": dict(chests=[[88, 184], [132, 184]], camps=[[116, 158, "heavy"]], landings=[[96, 186], [138, 166], [90, 160]],
                  wild=[[90, 176]], breakables=[[124, 154, "crate"], [125, 154, "pot"]], wardens=[[130, 158]]),
    "lark": dict(chests=[[44, 18]], camps=[[40, 20, "normal"]], landings=[[48, 26], [28, 14]], breakables=[[22, 18, "pot"]]),
    "highwatch": dict(chests=[[172, 30]], camps=[[194, 16, "normal"]], landings=[[200, 34], [186, 28]],
                      breakables=[[200, 32, "keg"]]),
    "duskmoor": dict(chests=[[194, 192]], camps=[[200, 176, "normal"]], landings=[[176, 172], [176, 200]]),
    "saltmere": dict(chests=[[20, 196]], camps=[[36, 192, "normal"]], landings=[[14, 180], [40, 180]]),
}
for _iid, _more in MORE.items():
    for _k, _pts in _more.items(): BY[_iid].setdefault(_k, []).extend(_pts)

# One line each in docs/MAP_REGIONS.md. "loot" leans chests on top of the biome's lean (BiomeRun):
# slot weights multiply, rarity steps add. Every region can be the match's hot drop zone (HotZone).
regions = [
    dict(id="crown", name="The Crown", biome="gloom", islands=["crown", "gaol_ne", "gaol_sw"],
         purpose="The vault on the Throne, two boss Gaols and the richest chests, under the most Blight."),
    dict(id="frostgate", name="Frostgate", biome="frost", islands=["frostgate"], loot={"slots": {"armor": 1.6}},
         purpose="The best armor on the map, and the Keep's high ground over the Gate Span."),
    dict(id="cinder", name="Cinder Steps", biome="ember", islands=["cinder"], loot={"slots": {"glove": 1.6}},
         purpose="Forge country: gloves and weapon tunings from the Kilns, a camp to level on."),
    dict(id="storm", name="Stormbreak", biome="storm", islands=["storm"],
         purpose="The shrine on the Shrine Table, boots, and Storm Halt (sky train) off its east rim."),
    dict(id="thorn", name="Thornwood", biome="bloom", islands=["thorn"],
         purpose="The Boki nest and the Thornhive lair; tall-grass ambushes and an uplink by the nest."),
    dict(id="lark", name="Larkhollow", biome="meadow", islands=["lark"],
         purpose="Wild Boki graze in the Hollow; a calm place to catch one, with a skiff dock out."),
    dict(id="highwatch", name="Highwatch", biome="frost", islands=["highwatch"], loot={"slots": {"boots": 1.8}},
         purpose="The Lookout over the Gaol and the Watch Road, boots, and an uplink out."),
    dict(id="duskmoor", name="Duskmoor", biome="storm", islands=["duskmoor"], loot={"slots": {"passive": 2.0}},
         purpose="Relics in the Moor Chapel ruins, and a skiff dock out."),
    dict(id="saltmere", name="Saltmere", biome="bloom", islands=["saltmere"],
         purpose="Salt caches along the dry river, the outer ring's most chests, and an uplink out."),
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
BRIDGES = [
    ("Gate Span", "frostgate", "crown", (108, 60), (108, 90), 2.2),
    ("Bramble Span", "thorn", "crown", (108, 156), (108, 128), 1.6),
    ("Gaol Walk", "crown", "gaol_ne", (130, 89), (150, 79), 1.4),
    ("Ash Walk", "crown", "gaol_sw", (86, 127), (70, 142), 1.4),
    ("Ash Bridge", "cinder", "gaol_sw", (54, 122), (54, 140), 1.6),
    ("Lark Road", "lark", "frostgate", (50, 30), (82, 30), 1.6),
    ("Watch Road", "highwatch", "frostgate", (172, 30), (138, 30), 1.6),
    ("Moor Steps", "storm", "duskmoor", (176, 140), (176, 172), 1.6),
    ("Salt Road", "saltmere", "thorn", (40, 182), (84, 182), 1.4),
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
]

lairs = [
    dict(id="eyrie", name="Stormcrown Eyrie", boss="serpent", island="gaol_ne", at=[157, 66], half=7, gate="s", entry=["dial", "runes"]),
    dict(id="forge", name="The Sunken Forge", boss="colossus", island="gaol_sw", at=[60, 150], half=7, gate="e", entry=["dial"]),
    dict(id="hive", name="The Thornhive", boss="brood", island="thorn", at=[127, 172], half=7, gate="w", entry=["dial", "wards"]),
]
# exits: skiff docks on the quiet NW/SE isles (pointing out to open sky), walled uplink outposts on
# the NE/SW isles and in Thornwood (each a short run from a boss lair), rift hatches in the ring.
docks = [[15, 30, -1, 0], [201, 184, 1, 0], [24, 200, 0, 1], [96, 27, 0, -1]]
outposts = [[190, 26, 1], [26, 186, 1], [92, 178, 1], [188, 193, 1], [30, 108, 1]]
hatches = [[124, 92], [100, 36], [36, 82], [182, 98], [118, 158], [166, 132], [124, 186], [92, 120]]

spawn_points = {
    "rare_kin": dict(pick=[5, 5], points=[[30, 30, "Larkhollow"], [192, 22, "Highwatch"], [192, 190, "Duskmoor"],
                                          [20, 182, "Saltmere"], [94, 176, "Nest Glade"], [82, 50, "Rimefield"],
                                          [32, 104, "Forge Yard"], [186, 124, "Stormbreak"]]),
    "vault": dict(pick=[3, 3], points=[[128, 46, "Frostgate Keep"], [42, 70, "The Kilns"], [178, 116, "Shrine Table"],
                                       [104, 164, "Thornwood"], [86, 112, "The Crown"]]),
    "cache": dict(pick=[7, 7], points=[[40, 22, "Larkhollow"], [182, 28, "Highwatch"], [184, 192, "Duskmoor"],
                                       [30, 180, "Saltmere"], [104, 44, "Frostgate"], [54, 108, "Cinder Steps"],
                                       [184, 108, "Stormbreak"], [120, 182, "Thornwood"], [132, 118, "The Crown"],
                                       [166, 70, "Stormcrown Gaol"], [96, 58, "Frostgate"], [162, 132, "Stormbreak"],
                                       [90, 182, "Thornwood"], [30, 96, "Cinder Steps"]]),
    "boss": dict(pick=[3, 3],     # all three lairs live: twice the hunters (40) on twice the land
                 points=[[157, 66, "Stormcrown Eyrie"], [60, 150, "The Sunken Forge"], [127, 172, "The Thornhive"]]),
}

# ------------------------------------------------------------------ onto the real grid
def sc(v):
    return round(v * K)

def sc_pt(p):
    return [sc(p[0]), sc(p[1])] + list(p[2:])

def sc_shape(S):
    S = dict(S)
    if "poly" in S: S["poly"] = [[round(x * K, 1), round(z * K, 1)] for x, z in S["poly"]]
    if "circle" in S: S["circle"] = [round(v * K, 1) for v in S["circle"]]; S["r"] = round(S["r"] * K, 1)
    return S

def sc_ramp(R):
    """A flight keeps its width and its step count; its top lands where the scaled plateau rim is."""
    dx, dz = DIRS[R["dir"]]; n = (R["to"] - R["from"]) * R.get("run", 1)
    top = (sc(R["at"][0] + dx * n), sc(R["at"][1] + dz * n))
    return dict(R, at=[top[0] - dx * n, top[1] - dz * n])

def sc_cluster(pts):
    """Groves and crate piles keep their shape: each cluster of three moves with its first piece."""
    out = []
    for i, p in enumerate(pts):
        a = pts[i - i % 3]
        out.append([sc(a[0]) + p[0] - a[0], sc(a[1]) + p[1] - a[1]])
    return out

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

def sc_wall(W):
    W = dict(W)
    for k in ("line", "box"):
        if k in W: W[k] = [sc(v) for v in W[k]]
    return W

POINT_KEYS = ("landings", "chests", "camps", "breakables", "weapons", "wild", "wardens", "traps", "areas")

def scale_layout():
    """Everything above is drawn on the DESIGN grid; this maps it onto SIZE (one constant to grow the map).
    Land, gaps and distances scale; things with a body (stairs, boulders, groves, lairs, bridge widths) keep their size."""
    for d in islands:
        d["poi"] = sc_pt(d["poi"])
        d["shapes"] = [sc_shape(S) for S in d["shapes"]]
        d["ramps"] = [sc_ramp(R) for R in d.get("ramps", [])]
        d["walls"] = [sc_wall(W) for W in d.get("walls", [])]
        d["rocks"] = sc_rocks(d.get("rocks", []))
        for k in ("trees", "crates"):
            if k in d: d[k] = sc_cluster(d[k])
        for k in POINT_KEYS:
            if k in d: d[k] = [sc_pt(p) for p in d[k]]
        if "shrine" in d: d["shrine"] = sc_pt(d["shrine"])
    for G in glides:
        G["take"] = sc_pt(G["take"]); G["land"] = sc_pt(G["land"])
    for L in lairs: L["at"] = sc_pt(L["at"])
    for lst in (docks, outposts, hatches):
        lst[:] = [sc_pt(e) for e in lst]
    for sp in spawn_points.values(): sp["points"] = [sc_pt(p) for p in sp["points"]]
    bridges[:] = [bridge(n, a, b, sc_pt(p0), sc_pt(p1), r) for n, a, b, p0, p1, r in BRIDGES]

DIRS = {"n": (0, -1), "s": (0, 1), "e": (1, 0), "w": (-1, 0)}
bridges = []
scale_layout()


# ------------------------------------------------------------------ the sky train
# The map's fast travel: a winding, irregular loop out through the void channels toward the outer isles
# (BIGGER_MAP.md), clockwise from the Lark Halt, with a stop in every region. Waypoints are on the design
# grid; the loop is a closed Catmull-Rom spline through them, written out every TRAIN_PT metres.
# SkyTrain runs legs at speed/1.5 on average (it eases in and out) and waits `dwell` s at each stop.
TRAIN_PT = 2.0          # m between written path points (TrainRoute resamples every 0.5 m)
TRAIN_CLEAR = 3.4       # m: between stops the track keeps this far from any ground but a bridge (else it dives under a rim)
PIER_REACH = 8.0        # m: a stop's pier (along the track's normal) reaches ground within this on one side (TrainRoute looks out to 16.7 m)
STOP_BRIDGE = 11.0      # m: a stop keeps this clear of bridges (the deck dives 4.6 m under one over ~8 m, never at a pier)
RUN_SPEED = 4.55        # m/s: the fastest frame on foot (content/rules/hunter_move.json "speed")
TRAIN_WAY = [(52, 44), (62, 26), (74, 14), (108, 19), (140, 13), (164, 19), (157, 34), (155, 46), (168, 49),
             (179, 58), (175, 70), (184, 86), (200, 98), (197, 110), (203, 124), (198, 140), (192, 154), (186, 161),
             (176, 157), (158, 162), (156, 180), (146, 198), (112, 195), (80, 197), (56, 199), (51, 188),
             (52, 176), (43, 167), (40, 157), (42, 146), (34, 134), (18, 118), (21, 96), (18, 74), (22, 56), (40, 52)]
TRAIN_STOPS = [((52, 44), "Lark Halt"), ((108, 19), "Frost Halt"), ((164, 19), "Watch Halt"), ((175, 70), "Eyrie Halt"),
               ((197, 110), "Storm Halt"), ((186, 161), "Moor Halt"), ((112, 195), "Bramble Halt"), ((43, 167), "Salt Halt"),
               ((42, 146), "Ash Halt"), ((21, 96), "Cinder Halt")]
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
    exits = [e[:2] for e in docks + outposts + hatches]
    for d in islands:
        for wp in d.get("wardens", []):
            for lst, r, what in ((camps, 9, "camp"), (exits, 9, "exit"), (lands, 8, "landing")):
                for q in lst:
                    if math.hypot(wp[0] - q[0], wp[1] - q[1]) < r: probs.append("warden %s too close to %s %s" % (wp, what, q[:2]))
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
    for o in docks:
        dr.rectangle([o[0] * S - 5, o[1] * S - 5, o[0] * S + 5, o[1] * S + 5], outline=(120, 200, 255), width=2)
    for G in glides:
        dr.line([G["take"][0] * S, G["take"][1] * S, G["land"][0] * S, G["land"][1] * S], fill=(255, 255, 120), width=1)
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
    for ek in (docks, outposts, hatches):
        pts += [tuple(e[:2]) for e in ek if (int(e[0]), int(e[1])) in INISLE[d["id"]]]
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
        for ek, kind in ((docks, "dock"), (outposts, "outpost"), (hatches, "hatch")):
            for e in ek: self.hard |= _disc_r(e[0] + 0.5, e[1] + 0.5, EXIT_R[kind])
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
            for ek in (docks, outposts, hatches):
                for e in ek:
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

def main():
    lv, owner, stairs = rasterize()
    C = place_cover(lv, owner, stairs)
    probs = check(lv, owner, stairs)
    tp, stops, legs, loop = check_train(lv, owner)
    probs += tp
    for b, share, tg in cover_report(C, lv, owner):
        print('cover %-7s %5.1f %%  (target %.1f-%.1f %%)' % (b, share * 100, tg[0] * 100, tg[1] * 100))
    print('cover patches', len(C.patches), 'clumps', sum(len(p['clumps']) for p in C.patches))
    for p in probs: print("PROBLEM", p)
    for G in glides:
        own = {p: o for p, o in owner.items() if lv[p] != -2}
        G["gap"] = round(gap(G["a"], G["b"], own), 1)
    if "--preview" in sys.argv:
        preview(sys.argv[sys.argv.index("--preview") + 1], lv, owner, stairs)
    for G in glides[::2]: print("glide %-10s -> %-10s gap %.1f m" % (G["a"], G["b"], G["gap"]))
    for B in bridges: print("bridge %-13s span %.1f m" % (B["name"], B["span"]))
    print("train loop %.0f m, %d stops, a lap %.0f s" % (loop, len(stops), sum(l[2] for l in legs)))
    for (nm, isl, d), (a, b, ride, run) in zip(stops, legs):
        print("train %-12s (%-9s pier %4.1f m) -> %-12s ride %3.0f s, run %s" % (nm, isl, d, b, ride, "%.0f s" % run if run < 1e9 else "no way on foot"))
    out = dict(id="hollowcrown", name="The Hollow Crown", size=SIZE, seed=5150, hand=True,
               notes="Hand-made expedition map (tools/make_hollowcrown.py; the format is described there). "
                     "A raised core (the Crown, its Throne and two boss Gaols), a ring of four regions each with one "
                     "plateau reached by stairs, and four quiet outer isles with the exits. Nothing is placed by dice "
                     "except what the match rolls: which spawn points, lairs and camps are live, loot, the Blight, weather.",
               regions=regions, islands=islands, bridges=bridges, glides=glides, pads=[], updrafts=[],
               winds=[], train=train, docks=docks, outposts=outposts, hatches=hatches, lairs=lairs, spawn_points=spawn_points)
    path = os.path.join(os.path.dirname(__file__), "..", "content", "maps", "hollowcrown.json")
    with open(path, "w") as f:
        json.dump(out, f, indent=1)
    print("wrote", os.path.normpath(path), "problems:", len(probs))

if __name__ == "__main__":
    main()
