# Foot planting (`FootPlant`, `--foot-plant-check`)

The clips and HunterAnim pose the legs for flat ground. On a flight of stairs, at its foot and on a stone stand
the feet used to float or sink. `scripts/match/foot_plant.gd` now plants them after the pose:

- **Where the ground is:** `World.ground_at` under each ankle (a stone stand from `StoneStand.top_under` counts),
  against the ground under the body. Ground more than `REACH_DOWN` (0.3 m) lower is a ledge: the foot stays on
  the lip. More than `REACH_UP` (0.3 m) higher is a wall or a rock: the foot stays put. A body off the terrain
  (mounted, on a train car) is left alone.
- **How:** the hips drop for the lower foot and a two-bone IK (hip and knee) bends each leg to its ground. The knee
  stays a hinge, bending the way the clip bent it; the foot bone keeps the clip's turn. The swinging foot follows the
  ground at `RATE` (30/s), so a tile edge does not pop; the lower foot (it bears the weight) stands on its ground at
  once and the hips drop at least as far as it needs. It is weighted out in the air, gliding, diving, mantling and
  rolling.
- **Steps and rocks:** the body's height is the game's (`Hunter.pos.y`) and its ground counts a rock it overlaps as
  `Ent.ground` does (its radius). Walked onto a higher rock or up a terrace, the drawn body eases up
  (`Hunter.step_vis`; `StoneStand.stand` for a rock's top, which used to pop it up in one frame) and the feet stay on
  the top meanwhile (`lag`, not eased); the body's height going up or down a step at once keeps the feet where they
  were (`lift` rebased). Tenzo on his rocks, the ridge and steps between rocks: `--rock-feet-check` (below).
- **Which body:** a .glb Hunter is planted on its bones (root, thighs, shins) by `FootPlant.bones` from WardenGlb's
  Sync, once the clips have posed. The procedural body (Settings: Warden models off) is planted on the rig nodes.
  Motley's clips hover (`rig_root`), so his feet are left alone.
- **Who:** only the local Hunter and those within `NEAR` (14 m) of them, and never under animation LOD (a Hunter
  posed every 3rd or 6th frame). Off, nothing is sampled and the pose stays exactly the clip's.
- **Wiring:** one line in `Hunter.render` (`anim.feet.plant`, with `pos.y` and `r`), one in the Sync, one `feet` var
  on HunterAnim; `Hunter._physics` calls `StoneStand.stand` where it set `pos.y` to the ground.

## Check

`godot --headless --path . -- --foot-plant-check` runs every Hunter on a two-tile flight of stairs
(the slope) and at its foot (the tier step: one foot on the flat, one on the flight), standing and walking up. A flat
twin gives the clip's own ankle height. Per frame the planted ankle's height over the ground under it is held
against the twin's, scored only while that foot is down and the ground is in reach. It passes within 0.035 m, and
planting off must leave the pose exactly the clip's.

| | stand, off | stand, on | walk, off | walk, on |
|---|---|---|---|---|
| worst over the 11 planted Hunters | 0.157 m (Dredge) | 0.001 m | 0.245 m (Kael) | 0.030 m (Vex) |

`--rock-feet-check` (tools/rock_feet_check.gd): Tenzo (`legs_rigid`) in a real match stands on a Stone Row rock,
walks a cast Basalt Spine and steps between rocks 0.25 m and 0.8 m apart, while a twin of his model on flat ground
plays his exact animation state. The weight-bearing ankle (lowest within a stride) over the surface it stands on must
match the twin's within 0.04 m, and a step up must not pop the drawn body (under 0.1 m a frame) or drop the plant.
Worst: 0.000 m in every case (the weight-bearing foot follows at once). It also prints how far the crags' mesh (RockLook) lies under the
foot, not asserted: the stand surface is the rock's `top` (2.2 m, the main crag's peak) over its whole footprint,
while the crown's peaks and gaps put the mesh 0.02 m to 2.2 m under a planted foot.
Shot at gameplay zoom (`--breah-shots --breah-only=ridge`: standing on the ridge, then walking along it):
`docs/art/foot_plant/dolm_ridge.jpg` (xvfb software render on rpc6; the GPU jobs 20261111-102330-06262,
-102541-03323 and -102753-32355 were lost to GPU worker restarts).

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
