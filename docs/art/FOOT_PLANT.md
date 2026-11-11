# Foot planting (`FootPlant`, `--foot-plant-check`)

The clips and HunterAnim pose the legs for flat ground. On a flight of stairs, at its foot and on a stone stand
the feet used to float or sink. `scripts/match/foot_plant.gd` now plants them after the pose:

- **Where the ground is:** `World.ground_at` under each ankle (a stone stand from `StoneStand.top_under` counts),
  against the ground under the body. Ground more than `REACH_DOWN` (0.3 m) lower is a ledge: the foot stays on
  the lip. More than `REACH_UP` (0.3 m) higher is a wall or a rock: the foot stays put. A body off the terrain
  (mounted, on a train car) is left alone.
- **How:** the hips drop for the lower foot and a two-bone IK (hip and knee) bends each leg to its ground. The knee
  stays a hinge, bending the way the clip bent it; the foot bone keeps the clip's turn. The move follows the ground at
  `RATE` (30/s), so a tile edge does not pop. It is weighted out in the air, gliding, downed, diving, mantling and
  rolling.
- **Which body:** a .glb Hunter is planted on its bones (root, thighs, shins) by `FootPlant.bones` from WardenGlb's
  Sync, once the clips have posed. The procedural body (Settings: Warden models off) is planted on the rig nodes.
  Motley's clips hover (`rig_root`), so his feet are left alone.
- **Who:** only the local Hunter and those within `NEAR` (14 m) of them, and never under animation LOD (a Hunter
  posed every 3rd or 6th frame). Off, nothing is sampled and the pose stays exactly the clip's.
- **Wiring:** one line in `Hunter.render` (`anim.feet.plant`), one in the Sync, one `feet` var on HunterAnim.

## Check

`godot --headless --path . -- --foot-plant-check` runs every Hunter on a two-tile flight of stairs
(the slope) and at its foot (the tier step: one foot on the flat, one on the flight), standing and walking up. A flat
twin gives the clip's own ankle height. Per frame the planted ankle's height over the ground under it is held
against the twin's, scored only while that foot is down and the ground is in reach. It passes within 0.035 m, and
planting off must leave the pose exactly the clip's.

| | stand, off | stand, on | walk, off | walk, on |
|---|---|---|---|---|
| worst over the 11 planted Hunters | 0.157 m (Dredge) | 0.001 m | 0.245 m (Kael) | 0.030 m (Vex) |

Strips: `jobq submit --needs gpu --tree <tree> --out shots -- --foot-plant-shots --shots-dir=shots` writes
`<id>.png` per Hunter: slope stand, slope walk, step stand and step walk side on. Planting is off in the top row and
on in the bottom row. The sheets from jobq 20261109-110427-32399 (RTX run) are in `docs/art/foot_plant/<id>.jpg`.

## Cost

`--perf-bench --bench-hunters=30 --bench-secs=60 --bench-farm=5` on an RTX 4090 (jobq, forward_plus, medium).
Before is origin/main with only the `--bench-hunters` option; after is this branch:

| | wall avg | p99 | match script avg | hunters step |
|---|---|---|---|---|
| before (20261109-104150-10079) | 108.6 ms | 221.5 ms | 70.25 ms | 19.62 ms |
| after (20261109-104154-20975) | 104.1 ms | 276.6 ms | 65.20 ms | 18.00 ms |

At 30 Hunters this load is CPU-bound in match script, and the two runs differ by run-to-run noise. The averages
show no cost. The p99 gap comes from mid-match script hitches that add no new nodes, so one run each cannot pin it
on planting. Far Hunters and those under animation LOD sample nothing.
