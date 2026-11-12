# 0060: Terrain hazard areas, countered by your Boki's type

- **Status:** accepted
- **Date:** 2026-11-11
- **Area:** match flow / movement / combat

## Problem
Owner 11-11: the distinctive map needs hazards (lava, water, ice...) that your Boki can mitigate. The biome traps (BiomeRun: lava vents, ice patches, spore pods, rods, rifts) are small timed traps on spots; nothing on the map is ground that changes your route, and a Boki's type does nothing outside fights.

## Options
1. Grow the traps: bigger circles. Cheap, but circles read as traps, not terrain, and there is no per-tile lookup for bots.
2. Authored hazard areas: outlines in the map JSON, rasterized once into a per-tile lookup, one shader quad each. The counter is the active Boki's theme (or a species list for swimmers, as no theme is water).
3. A new terrain tile kind in World. Touches world.gd (frozen), the mesher and the save of the layout.

## Decision
Option 2 (`scripts/match/terrain_hazards.gd`, owned by BiomeRun). Values in `content/rules/terrain_hazards.json`; areas in `tools/make_hollowcrown.py` HAZARD_AREAS, validated there. Effects use the existing statuses (burn, slow, haste, stun, hurt) and the ground grip; bots keep off what their Boki can't handle via the tile lookup in their grid path, line and edge checks, crossing only when there's no way round.

## Protection stacks as the best single source (owner DECISIONS 11-11: perks, items or Boki type protect)
A hunter can be protected from a hazard by a ward perk (Emberwalk, Sure Foot, Grounded, Spore Mask, Tidewader; see the update below), by the Boki that is out (its type or species counters the kind), or both. The rule, in `content/rules/terrain_hazards.json` `ward`: the best single protection applies, no doubling. Each source has a strength (1 = the hazard cannot touch you); the shield is the largest, never a sum, and a full shield means none of the kind's effect.
- Perk plus counter Boki: the same as either alone.
- A carried second Boki (carry two in) or one that is downed adds nothing; only the Boki out counts, so two frost Boki are one frost shield. This matches the carry-two-in rule that a stat both Boki give counts once, the stronger.
- A Fusion is its own Boki and keeps its type's counter while fused.
- `ward.traps` ties each biome trap kind (lava vent, ice patch, lightning rod, spore pod) to the ground kind it shares a ward with, so the one perk and the one counter cover both the area and the trap (`BiomeRun.warded` asks `TerrainHazards.guards`). A counter Boki now also keeps its hunter off those traps.
- Deep water's ward perk is Tidewader (no biome trap shares its ground).

## Consequences
New: terrain_hazards.gd, terrain_hazard.gdshader, ui/terrain_hud.gd, two BokiLines triggers, `--terrain-hazard-check`, `--terrain-hazard-reel`. Wiring: Match.ground_grip and Hunter pass the hunter (frost counter), Ent.hurt scales a deep-water wader's hits, HUD one call. No Net change (areas come from the map; each game applies them only to the bodies it owns, like the traps), no save change. Monsters and Boki ignore the areas (not asked for); the minimap doesn't draw them.

## Update 2026-11-11 (owner: hazards are big, perks give immunity)
Fields are big: an area is an outline minus `safe` circles and polygons (causeways, fords, stepping stones, a stone islet round every spot), so a region can be over half lava (Cinder 53%), a third ice or deep water, and squads route round it. The surface distance field takes the nearest safe shape's edge, so paths are edged like the field. Immunity also comes from the kind's ward perk: one perk system with the shop wards (`Data.PERKS` `ward` names the hazard kind: Emberwalk lava, Sure Foot ice, Grounded static, Spore Mask bramble, Tidewader deep water), so one perk covers a kind's big fields and its biome traps (`ward.traps`), and the best single source counts (`TerrainHazards.shield`). Wards are sold in the region's shop; a perk orb only rolls one within `hazard_near.m` of its field, at `hazard_near.weight`. Bots keep using `guards`, so a perk counts for them too; `Bot._grid_path` searches a wider window for a way round a field before it crosses one. Regions carry `hazard` and `share` tags. No Net or save change (perks are per expedition, as before).
