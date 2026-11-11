# The Hollow Crown 2.0 (owner order 11-11)

> "is the map that much bigger? it felt like it wasn't that distinctive and wasn't that big - maybe we need to go further"
> "it also shouldn't feel like an obvious / repetitive shape, there needs to be well thought out parts to the map to make fighting distinct where"

Branch ext/map-v2-1111. Generator: `tools/make_hollowcrown.py` (data: `content/maps/hollowcrown.json`). Shots: `docs/map_v2_shots/`.

## What was wrong with 0.24.4
- **Not that big:** SIZE 216 → 305 doubled the *area* but only stretched each side 1.41x, and the land
  (34,700 m²) sat in 37 % of the square. You cross it in about a minute.
- **One shape, nine times:** the Crown in the middle, a ring of four mid regions that each had "a lv 2 base
  with one lv 6 plateau and a stair", and four outer isles with "a low isle with one raised bit". The same
  terrace recipe was recoloured nine times, so every fight looked alike: hold the plateau, watch the stair.
- **A ring:** every region hung off the Crown by one bridge, in a pie round it.

## The 2.0 idea: a broken continent round the Hollow
The middle of the map is **not land**: it's **the Hollow**, a sunken void where Stormbreak's shards float,
tied together by narrow bridges. The Crown sits on its north rim, not in the centre.
The map changes character from west to east, so it's a gradient, not a ring:
- **West: wide, joined land** (Highwatch, Larkhollow, Thornwood, Saltmere). Short, wide necks between
  them; you can run the whole west side without a bridge fight.
- **East: broken high ground** (Frostgate, the Stormcrown Gaol, Cinder Steps, Duskmoor). Separate rocks,
  sheer drops, long bridges and glide gaps; height decides fights.
- **Centre: the Hollow.** Five shards over the void, every route across it a chokepoint bridge.

Regions differ on purpose in **size** (Frostgate is a 260 m strip, Duskmoor a tight 110 m warren),
**height** (Saltmere's lagoon at 0 m, Highwatch's Lantern at 11 m), **shape** (strip, blob, archipelago,
cliff wall, tower cluster, walled maze) and **how you get in** (one long bridge; four wide necks; only glides).

## Sketch (north up, 540 m a side; `--preview` draws the real one: docs/map_v2_shots/plan.png)

```
 z   0         100        200        300        400        500   x
  0 +-------------------------------------------------------------+
    |                ____FROSTGATE (sniping shelf, lv 10)___       |
    |   HIGHWATCH  _/   Rimefield (lv 4) - uplink A        \_Gaol |
    |   towers lv  ~~Rime Stair                    Gaol Walk~[EYRIE]|
100 |   6/9/11/14     |          Gate Span (35 m)               |  |
    |   (lighthouse)  |               |                  Eyrie Stair
    |      |        __|_______  [ THE CROWN ]  ~ ~ glide ~ ~ CINDER |
200 |   Watch Neck   |       |=Lark  citadel:   bailey 4      STEPS |
    |  LARKHOLLOW    |  open |  Span keep 8,                  cliff |
    |  open plains,  |  flank|        Throne 12 (Heart)       tiers |
    |  rolling swells (lv 0/1)           |  Shard Stair     2/6/10 |
300 |      |                       . . [n] . . . the HOLLOW   /14  |
    |  Thorn Gate                [w]--[ STORMBREAK ]--[e]   uplink B|
    |  THORNWOOD  ===Shard Walk===   shrine table     \     Sunken |
    |  dense forest, Bramble Rise     [s]               \   Forge  |
400 |  (Thornhive lair)               |                DUSKMOOR    |
    |      \___ Salt Walk   SALTMERE (lagoon, lv 0,    ruin maze   |
    |                       rim + causeway lv 2)        (lv 2)     |
500 |                                                               |
    +-------------------------------------------------------------+
```

## Regions: fight type first

| Region | Fight type (on purpose) | Why a squad goes there | Skyline landmark | Palette / biome | Terrain language | Ways in (chokepoints) |
|---|---|---|---|---|---|---|
| **The Crown** | **Siege**: walled citadel, three gates, tiers 4/8/12 | the vault on the Throne (the Heart), the richest chests, Stormcrown Eyrie's bridge | rune ring over the vault | gloom (violet stone) | a crooked bailey (lv 4), a walled keep (lv 8) and the Throne (lv 12); wall runs make courtyards; two flights up the Throne, three up the keep | Gate Span (N, 35 m), Lark Span (W, a flight), Shard Stair (S, a flight); glide in from Cinder or the shelf |
| **Frostgate** | **Long sightlines / sniping**: a 260 m bare shelf 8 m up | best armor (×1.6), the Keep, uplink A below the shelf | hooded ice statue | frost (white/blue) | a high bare ice shelf (lv 10) with a few low benches; the lower Rimefield (lv 4) runs under its south cliff | three long stairs up the shelf (W, two S); Rime Stair from Highwatch, Gate Span to the Crown, Gaol Walk east |
| **Highwatch** | **Vertical towers**: four rock towers of different heights over a low yard | boots (×1.8), the Lantern (the highest point on the map), landings | stone lighthouse | frost, slate-grey granite tint | four stacked towers (lv 6/9/11, and the Lantern 8→14 with a ledge) on a lv 2 yard; each tower one flight up | Rime Stair (E), Watch Neck (S, wide); glides from every tower top |
| **Larkhollow** | **Open, flank-heavy plains** | wild Boki herd (catch one), many landings, light camps, uplink B out in the open | giant tree | meadow (bright green) | the widest open ground: lv 0 with low lv 1 swells, few rock clusters; no walls | four wide ways in from three sides (Watch Neck, Thorn Gate, Lark Span) |
| **Thornwood** | **Dense forest ambush** | the Boki nest, the Thornhive lair on Bramble Rise | blossom arch | bloom (deep green, pink leaf) | a lv 2 wood packed with groves and tall grass, lanes cut through it; Bramble Rise (lv 5) in the north | Thorn Gate (N, wide), Shard Walk (E), Salt Walk (SE) |
| **Saltmere** | **Water edges / causeways** | salt caches (the most chests south), a skiff-free crossing to Duskmoor | white salt obelisk | bloom, white-salt tint | a lv 2 rim round a sunken lv 0 lagoon (tagged deep water for hazards), one causeway across it, an islet cache in the middle | Salt Walk (W), Shard Rise (N), Moor Walk (E) |
| **Stormbreak** | **Chokepoint bridges** | the shrine on the Shrine Table, the middle of everything | twisting crystal spire | storm (blue-grey) | five shards (lv 2) over the Hollow in a crooked chain, the Shrine Table (lv 6) on the biggest; nothing but bridges between them | Shard Stair (Crown), Shard Walk (Thornwood), Shard Rise (Saltmere), Moor Bridge (Duskmoor); Slag Leap glide to Cinder |
| **Duskmoor** | **Close quarters: a ruin maze** | relics (×2.0) in the Moor Chapel, the shortest fights on the map | standing-stone ring | storm, ash-violet tint | a 9 m-cell ruined maze of broken walls (a fifth knocked out so it loops; every wall breached) round the raised Chapel floor (lv 4) | Moor Bridge (NW), Moor Walk (W), Slag Steps (NE, from Cinder) |
| **Cinder Steps** | **Vertical cliff fights + lava edges** | gloves (×1.6), the Sunken Forge lair at the cliff foot, the Kilns on the crest | forge chimney | ember (rust/red) | four cliff tiers climbing east (lv 2 → 6 → 10 → 14) to a sheer east rim, two flights between each tier; slag pools at the cliff feet (tagged lava for hazards) | Eyrie Stair (N, from the Gaol), Slag Steps (S, from Duskmoor); Ember Leap glide from the Crown, nothing else |

## Scale
- **540 m a side** (was 305; 1.77x per side). Land ~2.3x the 0.24.4 map. The final number is the largest
  one the GPU bench holds (see "Perf" below); SIZE is still the one constant (`scale_layout()`).
- **Density:** 30 hunters (10 trios) stay. More land per squad is the point of the order, so the map
  makes up for it with more of everything to find: chests, camps and landings scale with land
  (~0.8x the old per-m² density), and every tile of land is within 40 m of something to take
  (`check_interest`: chest, camp, landing, weapon, shrine, lair, outpost or a train stop). At 4.55 m/s that is
  at most ~18 s between two points of interest on foot: no >25 s empty run.
- **Travel:** the sky train loop runs round the whole map with a stop in every region (12 m/s, ~2 runs' worth);
  bridges are short (≤ 40 m) and the glide gaps are glide-sized. The train check keeps "every leg rides
  faster than running it".
- **Ways Out (the Heart's ring):** `ways_scale` = SIZE / 216 = 2.5; all land is inside the ring's first
  radius (325 m) round the Heart, both lairs and uplinks are inside it when they open, and the Heart Gate
  has ground at 60 m (checked by the generator).

## Hooks for the parallel branches (data only, in each `regions[]` entry)
- `fight`: the fight type id (`siege`, `snipe`, `towers`, `open`, `forest`, `causeway`, `chokepoint`, `maze`, `cliffs`).
- `hazard`: what the region's hazard should be for ext/region-hazards (`lava` Cinder, `water` Saltmere,
  `ice` Frostgate/Highwatch) and `hazard_areas`: `[{kind, poly}]` where it goes (lava pools at Cinder's cliff
  feet, Saltmere's lagoon). Nothing reads them yet; the ground there is ordinary ground today.
- `finals`: 1-2 candidate final-zone centres per region for ext/br-zone, each on fightable ground
  (not on a bridge, stair or lair; ≥ 25 m of land round it). The Crown and Stormbreak have none
  in the void.

## Not in this pass (noted, not built)
- Skiffs: the old map only named "skiff docks" in text; there is no skiff system. The train and glides are the travel.
- In-match shops (separate order): no region uses a shop as its reason yet.
