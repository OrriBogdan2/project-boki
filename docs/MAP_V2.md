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
    |               [====== FROSTGATE: bare ice shelf, lv 10 =====]|
    |  HIGHWATCH   Rime  Rimefield (lv 4): uplink A   Keep  Gaol   |
    |  towers lv   Stair          |                   Walk [EYRIE] |
100 |  6/9/11/14                  | Gate Span (36 m)    Gaol rock |
    |  (Lantern)                  |                         |      |
    |     || Watch Neck     [ THE CROWN ]                Eyrie Stair
200 |  LARKHOLLOW  =Lark Span= walled citadel  ~Ember Leap~ CINDER |
    |  open plain,  (30 m)    bailey 4 / keep 8 /         STEPS:   |
    |  uplink B               Throne 12 (Heart)           cliff    |
    |     ||  Thorn Gate,        \ Shard Stair            tiers    |
300 |     ||  Bramble Neck   [Thorn Shard] [Crown Shard]  2/6/10/14 |
    |  THORNWOOD  =Shard Walk=      [STORMBREAK]--[Ember Shard] Forge|
    |  dense forest,   the Hollow   Shrine Table  ~Slag Leap~      |
400 |  Bramble Rise    (void)  [Salt Shard]       DUSKMOOR maze    |
    |  (Thornhive)                 |  Shard Rise   Moor Chapel lv 4 |
    |        \=Salt Walk= SALTMERE lagoon (lv 0) =Moor Walk=       |
500 |                     rim + causeway lv 2                       |
    +-------------------------------------------------------------+
```
## Regions: fight type first

| Region | Fight type (on purpose) | Why a squad goes there | Skyline landmark | Palette / biome | Terrain language | Ways in (chokepoints) |
|---|---|---|---|---|---|---|
| **The Crown** | **Siege**: walled citadel, three gates, tiers 4/8/12 | the vault on the Throne (the Heart), the richest chests, Stormcrown Eyrie's bridge | rune ring over the vault | gloom (violet stone) | a crooked bailey (lv 4), a walled keep (lv 8) and the Throne (lv 12); wall runs make courtyards; two flights up the Throne, three up the keep | Gate Span (N, 35 m), Lark Span (W, a flight), Shard Stair (S, a flight); glide in from Cinder or the shelf |
| **Frostgate** | **Long sightlines / sniping**: a 260 m bare shelf 8 m up | best armor (×1.6), the Keep, uplink A below the shelf | hooded ice statue | frost (white/blue) | a high bare ice shelf (lv 10) with a few low benches; the lower Rimefield (lv 4) runs under its south cliff | three long stairs up the shelf (W, two S); Rime Stair from Highwatch, Gate Span to the Crown, Gaol Walk east |
| **Highwatch** | **Vertical towers**: four rock towers of different heights over a low yard | boots (×1.8), the Lantern (the highest point on the map), landings | stone lighthouse | frost, slate-grey granite tint | four stacked towers (lv 6/9/11, and the Lantern 8→14 with a ledge) on a lv 2 yard; each tower one flight up | Rime Stair (E), Watch Neck (S, wide); glides from every tower top |
| **Larkhollow** | **Open, flank-heavy plains** | wild Boki herd (catch one), many landings, light camps, uplink B out in the open | giant tree | meadow (bright green) | the widest open ground: lv 0 with low lv 1 swells, few rock clusters; no walls | four wide ways in from three sides (Watch Neck, Thorn Gate, Lark Span) |
| **Thornwood** | **Dense forest ambush** | the Boki nest, the Thornhive lair on Bramble Rise | blossom arch | bloom (deep green, pink leaf) | a lv 2 wood packed with groves and tall grass, lanes cut through it; Bramble Rise (lv 6) in the north | Thorn Gate (N, wide), Shard Walk (E), Salt Walk (SE) |
| **Saltmere** | **Water edges / causeways** | salt caches (the most chests south), a skiff-free crossing to Duskmoor | white salt obelisk | bloom, white-salt tint | a lv 2 rim round a sunken lv 0 lagoon (tagged deep water for hazards), one causeway across it, an islet cache in the middle | Salt Walk (W), Shard Rise (N), Moor Walk (E) |
| **Stormbreak** | **Chokepoint bridges** | the shrine on the Shrine Table, the middle of everything | twisting crystal spire | storm (blue-grey) | five shards (lv 2) over the Hollow in a crooked chain, the Shrine Table (lv 6) on the biggest; nothing but bridges between them | Shard Stair (Crown), Shard Walk (Thornwood), Shard Rise (Saltmere), Moor Bridge (Duskmoor); Slag Leap glide to Cinder |
| **Duskmoor** | **Close quarters: a ruin maze** | relics (×2.0) in the Moor Chapel, the shortest fights on the map | standing-stone ring | storm, ash-violet tint | a 9 m-cell ruined maze of broken walls (a fifth knocked out so it loops; every wall breached) round the raised Chapel floor (lv 4) | Moor Bridge (NW), Moor Walk (W), Slag Steps (NE, from Cinder) |
| **Cinder Steps** | **Vertical cliff fights + lava edges** | gloves (×1.6), the Sunken Forge lair at the cliff foot, the Kilns on the crest | forge chimney | ember (rust/red) | four cliff tiers climbing east (lv 2 → 6 → 10 → 14) to a sheer east rim, two flights between each tier; slag pools at the cliff feet (tagged lava for hazards) | Eyrie Stair (N, from the Gaol), Slag Steps (S, from Duskmoor); Ember Leap glide from the Crown, nothing else |

## Scale
- **540 m a side** (was 305; 1.77x per side, 3.1x the square). **Land 138,200 m²: 4.0x** the 0.24.4 map
  (34,700 m²; it used 37 % of its square, this one 47 %). SIZE is still the one constant (`scale_layout()`).
  Per region (m²): Cinder 25.6k, Lark 20.5k, Crown 19.6k (with its Gaol), Thornwood 19.5k, Frostgate 17.6k,
  Highwatch 14.7k, Duskmoor 8.6k, Saltmere 7.5k, Stormbreak 4.5k (five shards).
- **Density:** 30 hunters (10 trios) stay, so there is ~4x the land per squad: that is the point of the
  order, and the Blight ring (and ext/br-zone's phases) pulls them together. What there is to find:
  60 chests (was 39), 26 camps (19), 53 landings (38), 76 breakables (40), 285 trees in Thornwood,
  107 ruin wall pieces in Duskmoor. Chests per m² are lower than before on purpose: the bonus-key economy
  (`--keys-check`, 20-30 % bonus keys over locked chests) is set by camps' elites against chests, so
  7 filler chests became 2 heavy camps. Every tile of land is within 40 m of something to take
  (`check_interest`: chest, camp, landing, weapon, shrine, lair, outpost or a train stop); worst per region
  25-40 m. At 4.55 m/s that is at most ~18 s between two points of interest on foot: no >25 s empty run.
- **Travel:** the sky train loop (1.67 km, 9 halts, one in every region, a lap ~265 s) runs round the map
  and through the Hollow; every leg rides faster than running it (by 4-32 s; `check_train`). Bridges
  are 12-38 m; glides (Ember Leap, Slag Leap, Bramble Leap) for bots across the bigger gaps.
- **Ways Out (the Heart's ring):** `ways_scale` = SIZE / 216 = 2.5; all land is inside the ring's first
  radius (325 m; farthest land 320 m) round the Heart, the three lairs and two uplinks are inside it when
  they open, and the Heart Gate has 45 degrees of ground at 60 m, SE of the Throne (checked by the generator
  and `--ways-out-map-check`).

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

## Checks (rpc3, temp XDG, branch on release-integ-0245 272368589)
- `--train-check` 0 failures (6 reds fixed in the check: the rider stretch is now open air both sides, so the edge test runs, and only bots keep the edge guard, so it runs on a bot), `--keys-check` 90/0, `--cover-check` 85/0, `--arena-check` 106/0, `--ways-out-map-check` 0, `--minimap-check` 0, `--obstacle-check` 0, `--cliff-mantle-check` 0, import 0 errors, `health --strict` OK.
- `--simtest --teams=10 --squad=3 --god` headless: no script errors (two seeds: 160 s sim to "finished"; the other ended "team wiped" at 56 s, as base does at 138 s).
- GPU frame time (`--perf-bench --bench-secs=60 --bench-view=1920x1080`, RTX 4090): base 272368589 (jobq 20261112-005356-06135) match wall avg 54.9 ms, p99 193.3 ms (627 frames over 50 ms; build.generate 2.9 s). The first branch run (20261112-005528-29609) aborted at startup on the GPU worker (`realloc(): invalid next size`, heap corruption, 87 s in, before the match); the same bench headless on rpc5 ran clean (match wall avg 12.3 ms, p99 18.8 ms; no renderer, so not a frame-time number). The retry (20261112-023445-27381, rp1-0) aborted the same way, ~90 s into the match build. The same abort hit four unrelated jobs on rp1-1/rp1-2 on 11-11 (inv-shots, boki-carry-check, first15-shots), and the 540 m match builds and runs with no abort under a real renderer on rpc5 (OpenGL, llvmpipe: build.generate 3.1 s, 754 draws, 323k tris, 10k nodes; frame times are software-GL, not comparable). So it's a Vulkan-path heap corruption on the rp1 workers that this map's larger build sets off; it has no GPU frame time yet. Needs a GPU bench on a non-rp1 worker (or a Vulkan backtrace) before merge.
- Rechecked on rpc5 at 814caef87: import 0 errors, `--train-check` 0, `--keys-check` 90/0, `--cover-check` 85/0, `--arena-check` 106/0, `--simtest --teams=10 --squad=3 --god` no script errors, `health --strict` OK.

## Fit with the parallel branches (read 11-12)
- ext/br-zone-1111 centres the final area on a seeded dock/outpost exit, not on `finals`. This map has two outposts (uplink A in the Rimefield, uplink B in Larkhollow), both fightable ground, so every final lands in Frostgate or Larkhollow. At integration, pick from `regions[].finals` (14 centres in 7 regions) so finals spread over the fight types.
- ext/region-hazards-1111 uses the same `hazard_areas: [{kind, poly}]` shape, but its polygons and generator edits are drawn for the 305 m layout: they conflict with this generator rewrite and must be redrawn on the v2 regions (Cinder slag pools, Saltmere lagoon, Frostgate/Highwatch ice) when both merge.
