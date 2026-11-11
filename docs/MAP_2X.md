# The Hollow Crown at 2x: audit against the owner's order (Nov 7)

Branch ext/map-2x-0245 = ext/release-integ-0244 (with ext/map-regions) + ext/map-2x-flat2-rebased + ext/hot-zone.
Design: docs/decisions/0022-hollow-crown-2x.md. Regions: docs/MAP_REGIONS.md. Shots: docs/map2x_shots/ (top-down, and slanted from the south, north-east and north-west: `--map-overview [--map-angle --map-yaw=<deg>]`; small cover is past its visibility range at that height).

| Order point | State | What is there |
|---|---|---|
| Double the size, one SIZE constant | done | `SIZE = 305` in tools/make_hollowcrown.py (216 design grid × √2 = 2x the land); everything with a body keeps its size. |
| More squads, same squads per m² | partial | Data.MATCH_PLAYERS 20 → 30 (10 trios). 2x land wants 40; 40 was not frame-time flat on the GPU box (0022), so it is capped at 30: about 0.75 of today's density. |
| Sky train is the fast travel: winding loop, every region, stops that matter | done | A 938 m closed loop with 10 halts (one per outer region, Eyrie and Ash Halts for the Crown's Gaols); a lap is 177 s; every leg rides faster than running it (`check_train`). Each stop's deck sits level with its pier (7 of 10 piers are on 1.6-3.2 m terraces), so you step on and off. |
| The Crown: a reason to go | done | The vault on the Throne, two boss Gaols, the richest chests (most Blight). |
| Frostgate | done | Best armor (armor ×1.6 region lean on the frost biome's ×1.8) and the Keep's high ground. Leans slots, not rarity: "gold" armor there comes from the Crown/hot zone steps. |
| Cinder Steps | done | Gloves and weapon tunings (glove ×1.6), three camps to level on (light, normal, heavy). |
| Stormbreak | done | The shrine, boots (storm biome ×1.8), Storm Halt. (Its Shardfall pad went, see below.) |
| Thornwood | done | The Boki nest (Boki habitat), the Thornhive lair, an uplink. |
| Larkhollow | done | Wild Boki graze in the Hollow (Boki habitat), a skiff dock. |
| Highwatch | done | Boots ×1.8, the Lookout, an uplink. |
| Duskmoor | done | Relics (passive ×2.0) in the Moor Chapel ruins, a skiff dock. |
| Saltmere | done | The outer ring's most chests along the salt river, an uplink. |
| A shop as a reason to go | missing (big) | No in-match shops exist yet; that is the separate "Utilities and shops" order (each shop a fixed set). |
| No flat filler | done | Every region has 3-5 terrace levels; land more than 12 m from any feature (terrace edge, cover, rock, chest, camp, landing): 0-0.6 % per region. Only the two Gaol islands are one level (10 % and 6 % open), and they hold the boss lair arenas. |
| No jump-pad-only floating islands (BIGGER_MAP note) | done | Shardfall (pad-only perch, kept by map-regions) is removed in the merge. |
| Hot drop zone per match, on drop map and minimap | done | `scripts/match/hot_zone.gd`: one non-Crown region per match from the shared match seed, +1 rarity step, ringed and labelled on the drop/full map and ringed on the minimap; bot squads weigh it. `--hot-zone-check`. |
| …and it changes from match to match | partial (small) | It is re-picked from each match's seed, so it repeats the last match's region 1 time in 8. ext/hot-zone's "never twice in a row" needed a lobby field and a Net bump; dropped with its duplicate HotZone. |

## Camps (28, was 19)
Laid out in `CAMPS` in tools/make_hollowcrown.py (one table, design coordinates), asserted by `--camp-layout-check` on the generated map. 12 light, 9 normal, 7 heavy = 79 monsters (2 / 3 / 4 each).

| Region | Camps |
|---|---|
| Larkhollow, Highwatch, Duskmoor, Saltmere | 2 light + 1 normal (the normal is the nearest to the centre) |
| Frostgate, Cinder Steps, Stormbreak, Thornwood | 1 light + 1 normal + 1 heavy (heavy nearest the centre, light farthest) |
| The Crown | 3 heavy + 1 normal (the normal farthest); none on the Throne or the Gaols |

Rules, all asserted: camps in a region 30-70 m apart (every pair); 14 m from a train halt; 20 m from a lair gate, a vault point and a way-out seat (dock, outpost, hatch); cover (tall grass or a rock, tree, wall) within 12 m; within 190 m of the map centre; on flat, level, clear ground (2 tiles each way: no slope, stair or prop); a region's biggest camp is its nearest to the centre. Camps were moved to meet a rule, the check was not loosened: every camp of the old 19 moved (the 2x land and the 30-70 m spacing leave no old spot in place). Second pass (job 20261111-003215-a5): Larkhollow's west light camp moved one tile into cover and its east light one tile north-east (49,21 -> 50,20 design), which keeps the meadow grass share at 9.7 % (at 49,21 it fell to 8.5 %, under `--cover-check`'s band); all three Highwatch camps moved (the old ones stood on the Lookout's broken ground and the yard's slope) and the yard got two boulders for cover, since the Lookout plateau and the yard are too narrow to space three camps 30 m apart at covered spots; the Duskmoor normal camp moved one tile onto level ground and got a boulder beside it. It sits 2 m from the (176, 172) landing, the only level spot that spaces Duskmoor's three camps. The Stormbreak heavy camp moved one tile north (157,118 -> 157,117): the generated storm grass is seed-sensitive and at 118 no storm spot had 3 patches in a Shrubling's sprint range (`--cover-check`). The Highwatch Warden post moved from the Lookout's west end to its east end (182,19 -> 192,19), since Warden posts keep 9 m from camps (make_hollowcrown.py's own check) and the Lookout light camp is the only covered spot there that spaces Highwatch's three camps.

## Merge notes
- ext/hot-zone and ext/map-regions both built a `HotZone`. The build's (map-regions) stays: region based, no Net change, region loot leans, bot drop weighting. ext/hot-zone's island version, `content/rules/hot_zone.json`, the lobby `hot` field and its Net bump are dropped.
- Both branches had the far-monster 20 Hz step; one `Mob._far_step` stays (the build's time-based one, which `--perf-throttle-check` tests).
- Net.VERSION 0.24.4: the 2x map and 30-hunter expeditions ship in the 0.24.4 release (owner 11-10), so no separate bump.

## Checks
- **Sky train in the 0.24.4 build:** its Hollow Crown has no train at all (`--train-check` stops at "the map has a sky train"). This branch brings it back as the winding loop.
- **Fast suite** (suite-fast.sh is hetzner-only, so on w2: all 223 registered `-check` flags, xvfb + opengl3, branch; base re-run on every branch red). 56 branch reds on the first pass, 46 the same on base. Fixed here: `--cover-check` (ambush cover, Saltmere dock), `--perf-throttle-check` far-monster case, `--rolling-check` (map size from the layout), 4 of `--train-check`'s rider cases (check pushed off the car beside land). Load flakes that pass alone: hold-pose, hot-zone, hp-regen, music-leave, wallhug, weapon-clip.
- **Fixed in the second pass (job 20261110-083254-a1, rpc1):**
  - `--train-check` 0 failures: stops ramp the deck up to their pier's height (the rider no longer has to climb a 1.6 m step at Frost Halt); a train kill over the abyss boxes on the nearest ground within 40 m (the 14 m reach was 1x-sized, so the box fell back 200 m to the last safe spot); the check asserts every stop's deck vs pier and the box on the nearest ground.
  - `--keys-check` 0 failures: the Shrubling hides only in grass on its own terrace (it walks flat), so it never picks three unreachable patches below the Shrine Table.
  - SkyTrain: one reach cull before the per-car tests (`_near_train`), so the far hunters, monsters, Boki and pickups skip the matrix inverses.
  - Re-run after the merge of ext/release-integ-0244 b80a3d67b: `--train-check`, `--keys-check`, `--cover-check` (85/0), `--ping-check`, `--arena-check` (106/0); `--simtest --teams=10 --squad=3 --god` headless ran to its end, no script errors (bots finished the player at 121 s). `health --strict`: only `tools/move_feel_check.gd` long_line 32 -> 34, the same file and baseline as the base (a base red).
- **GPU re-run** (same bench, rp1-0, one run each; base = ext/release-integ-0244 b80a3d67b, jobq 20261110-085718-15405 / 20261110-085834-18950): wall avg 48.8 -> 50.4 ms (**+1.6 ms, +3 %**), p99 78.6 -> 77.2 ms, match script 20.95 -> 21.05 ms, draws 1062 -> 890, tris 735k -> 468k, nodes 7094 -> 9873. The sky train still steps 0.67 ms (the reach cull did not move it: the cost is in its placing/visuals, not the hit tests); mobs +0.8, separation +0.9, kins +0.4, bots -1.6.
- **ext/matchmaker-map-2x** is already in ext/release-integ-0244 (TRIO_SLOTS 18).
- **Full match on the new map:** `--simtest --teams=10 --squad=3 --god` (30 hunters, headless) ran to its end with no script errors: fights, revives, truces and extractions; it ended at 310 s sim when the autoplayed player bled out.
- **GPU frame time** (`--perf-bench --bench-secs=60 --bench-view=1920x1080`, rp1-1 RTX 4090, two runs each):

| | base 0.24.4 | 2x branch | change |
|---|---|---|---|
| wall avg ms | 46.0 / 47.3 | 50.2 / 50.6 | **+3.8 ms (+8 %)** |
| wall p99 ms | 76.9 / 73.6 | 106.4 / 83.3 | +20 ms |
| match script avg ms | 18.5 / 22.3 | 20.0 / 20.8 | about even |
| GPU ms | 5.1 / 0.8 | 4.6 / 3.1 | not the cost |
| draws | 900 / 836 | 921 / 926 | +2 to +11 % |
| objects / nodes | 1924-2054 / 7008-7057 | 2217-2341 / 9924-9999 | +8-22 % / +42 % |

  The bigger map costs frame time, CPU-side: per-frame steps up are the sky train (0.6-0.7 ms; the build had none), mobs (+0.7), separation (+0.8) and Boki (+0.4); bots are down 2.7-4 ms (SimLod). Visibility ranges hold the draws: +2-11 % draws for 2x land. The 2x shows +3,000 nodes (more camps, props, cover). Big item: a perf pass on SkyTrain.tick (cull pickups, mobs and Boki far from the train before the per-car tests), awake far camps and node count.

## Big items left
- In-match shops (the "Utilities and shops" order) so a shop can be a region's reason.
- 40 hunters (true same density) needs the frame time above to come down first.
