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

## Consequences
New: terrain_hazards.gd, terrain_hazard.gdshader, ui/terrain_hud.gd, two BokiLines triggers, `--terrain-hazard-check`, `--terrain-hazard-reel`. Wiring: Match.ground_grip and Hunter pass the hunter (frost counter), Ent.hurt scales a deep-water wader's hits, HUD one call. No Net change (areas come from the map; each game applies them only to the bodies it owns, like the traps), no save change. Monsters and Boki ignore the areas (not asked for); the maps draw them (`ui/hazard_map.gd`): each area's outline tinted by kind from the rules' `look`, a shield on the kinds your carried Boki counters, on the minimap as a detail kind (`hazard`: on a hold, or within 20 m of one) and on the full map always, with a row per kind, and a Safe shield row when your Boki counters one, in the full map's key (`MapKey`, main's corner key; the branch's own key strip was folded into it on the merge). `--hazard-map-shots` renders it.
