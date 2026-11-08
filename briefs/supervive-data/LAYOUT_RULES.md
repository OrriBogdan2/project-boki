# Layout rules (owner item 151)

How our maps should be shaped so movement never snags, after SUPERVIVE. Sources: supervive_physics.md (the game data) and the hero reference footage on `ext/hero-ref-footage`. Where a rule is enforced, the check is named.

## SUPERVIVE's numbers
- Nav step height 150 uu (1.5 m), and mantle suction up to 150 uu (MantleSuctionUpwardsForceHeightMax). Anything up to about 1.5 m is climbed without thinking; above that is a wall (Myth and Brall also climb tall ledges: bCanWallJump).
- bCanWalkOffLedges false: you never stroll off an edge by accident.
- The footage shows the same thing: flat play spaces, cliffs and plateaus with clear lips, tall rocks and walls as cover, grass and brush for vision, and very little in between.

## Our grid, in those terms
| Thing | Height | What it is |
|---|---|---|
| World.STEP | 0.32 m | Walked over without noticing |
| One terrace (World.LEVEL) | 0.8 m | Walking into it steps you up smoothly (no jump) |
| Two terraces | 1.6 m | A mantle (Hunter.MANTLE_REACH 1.5, walking rise LEVEL*2+0.1) |
| Rock, tree, wall, ruin, camp (T_BLOCK) | 3.0 m (World.BLOCK_H) | A wall: blocks movement and shots |
| Crates, pots, barrels, kegs (Breakables) | soft | Solid circles you're pushed round (Match._collide_breaks), never stood on; a jump clears them and any hit breaks them |
| Pebbles, flowers, ferns, cliff rocks, bush | none | Decor: walk and shoot through (bush hides you) |

## The rules
1. **Three height tiers:** ground (terraces of 0.8 m are part of the ground, since they're walked up), mantle ledges (1.5 to 1.6 m), and walls (3 m) or the abyss. Nothing that collides sits between a step and a mantle. Check: `--layout-check` (no colliding prop between 0.32 and 1.5 m).
2. **Cover is tall or nothing.** A blocker is a 3 m wall. There's no hop onto it and no standing on top (the old rock hop did that, and their tops were never ground). Check: `--layout-check` (a jump into a rock or wall never lifts you over it).
3. **Never stuck.** From any walkable spot, some key walks you away. No patch of ground is sealed in by blockers on every side (a body never fits through the corner gap between two diagonal blockers). Checks: `--layout-check` (probe grid, rock hops, landings on rocks and a test clump), `--wall-size-check` (no sealed pockets on any map).
4. **No tiny walls** (owner item 2, mapclean). No blocker group under 3 tiles (BlockPrune). Cover is placed with intent: wall runs with doorways, corners, pillar rows and keeps. Check: `--wall-size-check`.
5. **Small decor never collides.** It's walk-through, or it's big enough to be a wall. World._pack_prop is visual only; what blocks is the map data.
6. **Grass and brush are for vision, not collision.**
7. **Open lanes between POIs.** Chokepoints come from big shapes (walls, cliffs, the abyss), not clutter.
8. **Clean edges with a lip.** Islands keep their rim (World.lip / sheer), and the edge guard stops a walk off into the abyss, like bCanWalkOffLedges.
9. **Gameplay objects follow the same rule.** Tarek's rocks and ridge are climbable (StoneStand: their caster stands on them) or walls (item 134b).

## Applied (ext/phys-151-layout)
- The training area (the generated map, seed 4242): no stray random rocks any more. The deliberate stone walls, pillar rows and keeps stay, and so does the rest of the map (the draw is kept, so every check's map is unchanged).
- The stuck case, found: the rock hop threw you 3.4 m up over a clump of scattered rocks, and you came down in a one-tile hole of ground with rocks on all four sides. No key gets you out of that. Fixes:
  - The rock hop is gone: rocks, trees and walls are walls.
  - The generator fills any patch of ground sealed in by blockers (BlockPrune.fill_pockets), so a glide or knock can't land you in one either.
- Map generator audit: real expeditions are hand-made layouts (WideLayout, generate_authored). Their blockers are all 3 m T_BLOCK tiles, and every free-placed scatter (pebbles, under-growth, cliff rocks, sky decor) is visual only, so nothing there sits between a step and a mantle. `--wall-size-check` scans them for sealed pockets too.
