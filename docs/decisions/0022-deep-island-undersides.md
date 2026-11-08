# 0022: Deep island undersides you can climb

- **Status:** accepted
- **Date:** 2026-11-08
- **Area:** movement, world

## Problem
Owner playtest 11-08: the sky islands are thin, so a hunter falling past or gliding under one has almost
nothing to grab. The drawn underside was a 4-15 m cone (visual only, TerrainMesh), while the collision was
an infinite column under every tile and the abyss catch stopped 4.5 m below the lip: you could neither
glide under an island nor catch its side lower down.

## Options
1. Deepen only the mesh. Cheap, but the invisible column and the 4.5 m catch stay, so it changes nothing to play.
2. One underside height per tile (`IslandDepth`, from the tiles alone, so server and client agree) read by
   the mesh, the collision (`World.occupy`: solid from the underside to the top, open air below) and the
   catch (any island rock at your height, or just over your head, catches you down to `catch_depth_m`).
3. Separate climb handholds (extra collision objects up the sides). More data and a second system.

## Decision
Option 2. The underside is a tall near-sheer outer wall (`cliff_m`) then a taper to the middle, stepped
into shelves every `ledge_every_m` so it reads as climbable strata; the whole side is the handhold. Rising
up an overhang slides you out along it (`IslandDepth.unclip`), rising into an underside bumps your head.
Numbers in `content/rules/tuning.json` "islands". The abyss kill depth (17.5 m) is unchanged.

## Consequences
- New `scripts/match/island_depth.gd`; `TerrainMesh._fill_under` moved there (the mesh is unchanged in
  triangle count; only its heights are deeper). A few lines in `world.gd`, `hunter.gd`, `home.gd`, `ent.gd`.
- `Ent.over_void()` is true under an island's rock (only the abyss is below), so the abyss and glide lift
  work there. The farm's `MANTLE_ABYSS` (3.5 m) is gone: it uses the same catch depth.
- Net.VERSION: no bump; the snapshot shape is unchanged. Mixed versions would disagree about who is under an
  island, so ship server and clients together.
- Alternative kept open: a deeper abyss kill plane so more of the taper is in play.
