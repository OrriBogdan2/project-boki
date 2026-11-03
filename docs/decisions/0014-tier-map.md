# 0014: A bigger map for the top tier (the Riven Wilds), and the tier picks the map

- **Status:** accepted (owner direction of Nov 2 2026, 23:25 ET; the bigger-map notes in BIGGER_MAP.md)
- **Date:** 2026-11-03
- **Area:** match flow / map / performance

## Problem
The queued "bigger map" first meant growing the Hollow Crown 2-3x. The owner then asked to keep the Hollow Crown as the beginner map and give the harder tiers other maps with harder enemies. Every tier loads the Hollow Crown today (`World.layout_for_tier` ignores the tier), the sky train only runs a circle (Skyreach), and Skyreach's high perches are reached by jump pads, which the owner wants gone from new maps.

## Options
1. Grow the Hollow Crown: rejected by the owner (beginners keep the map they know).
2. Widen Skyreach for the top tier (as rolling sessions do): its perches and jump pads are what the owner asked to remove, and it is only 1.8x the area.
3. A new hand-made map built from the Hollow Crown's generator parts, picked by the tier (chosen).

## Decision
- **Tier -> map is data:** each entry of `Data.TIERS` names its `map`. The Meadow (0) and the Dusk Isles (1), where a Boki can't be lost, keep the Hollow Crown unchanged. The Hollow (2) gets the **Riven Wilds** (`content/maps/riven.json`). There are only three tiers and tiers 0-1 stay on the Hollow Crown, so Skyreach has no tier of its own; it stays for rolling sessions and `--map=skyreach` (owner question in the report). `--map=` still overrides every tier for tooling.
- **The Riven Wilds** (`tools/make_riven.py`; the shared parts of `make_hollowcrown.py` moved to `tools/mapkit.py`, and the Hollow Crown's JSON regenerates byte for byte): 336 x 336 tiles, 2.4x the Hollow Crown's area. A raised gloom core (the Sanctum plateau up two flights of stairs), a ring of six regions (one per biome, each with a plateau reached by stairs, five of them with a boss lair) and six low outer isles with the landings and most exits. Landmarks, chests, camps, key carriers (one per chest, as on every map), landings and exits scale with the ground. Cover uses the same per-biome shares as the Hollow Crown (`mapkit.COVER`, inside `keys.json` "cover"). No perches, no jump pads, no updraft chains: all high ground is terrain you walk up.
- **The sky train winds:** a train route may be a closed `path` of points (Skyreach's `center`/`r` circle still works and becomes the same kind of route). The Riven Wilds' loop weaves in and out between the region ring and the outer isles, close to the map's edge where it passes a region and in by the outer isles, stopping at each outer isle beside its landings and its exit. `TrainRoute` keeps a coarse grid of the track so "how far from the rails / where along the loop" stays a few lookups for bots and props.
- **Harder enemies are data on the map:** `"threat"` in the map JSON (the Riven Wilds: monsters x1.25 health and damage on top of the tier, rarity lifted one step toward rare and elite, one more monster per camp). `MapThreat` folds it into the match's tier table once at start, so every system that already reads `T["mob"]` follows.
- **Streaming and the perf budget:** the world is already drawn in chunks (ground 32 tiles, scatter 16-32, with draw distances), so the GPU only sees what is near the camera. What grows with the map is per-frame script work for things far from every player and the build at load. The minimum that keeps both flat is in the "Measured" section below, with the budget the check enforces.

## Consequences
- New: `tools/mapkit.py`, `tools/make_riven.py`, `content/maps/riven.json`, `scripts/match/map_threat.gd`, `tools/tier_map_check.gd` (`--tier-map-check`: tier -> map, threat, high ground, pads, camera at high spots, train stops; `--tier-map-perf`: the load and frame budget). Both in `CheckRegistry`.
- Changed: `Data.TIERS` (a `map` per tier), `World.layout_for_tier`, `TrainRoute` / `SkyTrain` (path routes), wiring lines in `match.gd` and `world.gd`, the full map's title.
- No save change, no `Net.VERSION` bump (the map id already travels with the match seed and tier).
