# Eggs in 3D

Every egg in the game is one of 17 Meshy models in `art/eggs/<kind>.glb`, drawn by `EggModels`
(`scripts/match/egg_models.gd`) with the toon light and the house ink (the Boki's outline width).
Checked by `--egg-models-check`.

## The families

| Kind | Who wears it | Shell / seams / emblem |
|---|---|---|
| a kin type (15) | every kin's egg: the starters, nest eggs | the type's colours, glowing seams, a raised emblem on the front |
| `rare` | boss drops, the incubator, rare nest hatches | polished gold, armour bands, one glowing seam ring at the middle |
| `mystery` | the hatch scene's basket egg | void black-violet, oil-slick bands, a "?" cracked into the shell |

Type eggs: ember (charcoal / orange / flame), frost (ice blue / cyan / snowflake), venom (plum / acid
green / droplet), stone (granite / amber / mountain), spore (mushroom brown with cream spots / mint /
mushroom), shadow (black-violet / purple / crescent), titan (slate armour / gold / shield), gravity
(indigo / lilac / ringed planet), echo (cobalt / sky cyan / sound arcs), bloom (moss / pink / flower),
swarm (honey hexes / yellow / honeycomb), storm (slate / electric yellow / bolt), lunar (lavender white
/ gold / crescent moon), prism (pearly pink / aqua / gem), tempest (white and blue / cyan / spiral).

Rarity reads by family (type egg, then the gold Rare Egg, then the mystery egg). A type egg does not
show the roster rarity of the kin inside: the hatch stays a surprise, and docs/POSITIONING.md keeps
rarity on the Boki itself. The Rare Egg's seam ring is repainted in the kin's glow (toon `recolor` on
the teal hue band), which replaces the old coloured spots.

## In the game

- `EggHatch` (the hatch scene, nest and incubator hatches) splits the model's `Cap` and `Cup` at half
  height. Its zigzag crack, rim teeth (`EggModels.TINT`) and peek hole stay procedural. On a dark shell
  (luminance under `DARK_SHELL`) the crack glows warm instead of being drawn dark.
- `Models.nest_egg(kind)`, `Models.rare_egg_small(seam)` and `BossModels.rare_egg(col)` use
  `EggModels.shell()`, a "Shell" node that turns slowly and floats a little (PropAnim).

## Making one

1. Concept: 3 options per family (vertex-gen), pick one. The 11-11 sheet and picks are in
   `/home/boki/meshy/eggs-1111/concepts.jpg`.
2. Input: a volumetric 3/4 render of the pick (a flat cel drawing gave Meshy a disc), one egg, plain
   background.
3. Meshy image-to-3D (`tools/meshy/meshy_task.py create`, meshy-7.1, default geometry, 2k texture,
   6000 polys, no PBR): 35 credits.
4. Bake: `blender -b --factory-startup --python tools/meshy/bake_egg.py -- glb.glb art/eggs/<kind>.glb
   [--yaw=DEG]`. This gives a 1 m tall egg, 0.736 wide (EggHatch's shape), about 2.5k tris and a 512 px
   colour map, cut at half height into Cap and Cup. Check that the emblem faces the game's +Z (Blender's
   -Y). All 17 face it at yaw 0.
