# 0049: Garden hub and zones

- **Status:** accepted
- **Date:** 2026-11-10
- **Area:** save / farm

## Problem
GARDEN.md 10 turns the one garden into a hub plus five zones you open (Bramblebank open at start). Today the garden is one
scene with one `Save.d["layout"]` and every farm Boki in it, plus bridged side isles (`Data.ISLES`, `Save.d["bridges"]`).

## Options
1. One big scene holding every zone. Simple travel, but it breaks the per-zone perf budget (10.6) and grows the save blob.
2. One scene per zone through `Game.goto("home", {"zone": id})`, only the loaded zone simulated. Chosen.

## Decision
- **Save shape (v13):** `Save.d["zones"] = {id: {"open": bool, "founder": uid, "opened": unix, "layout": {...}, "plots": [...]}}`;
  the hub keeps the shared house, nest corner and Burrow in today's keys. Each Boki gets `rec["zone"]` (a zone id; Burrow Boki keep theirs).
- **Migration 12 -> 13:** the current `layout` and snack plots move to `zones["bramblebank"]` (open); the other four start
  `{"open": false}`; every roster Boki gets `rec["zone"] = "bramblebank"`. Unknown zone ids load as Bramblebank.
- **Scenes:** home.gd reads the `zone` param (default `"hub"`) and builds the hub or that zone; wiring only, the logic lives
  in `garden_zones.gd`, `hub_layout.gd`, `hub_waystone.gd`. A visit passes `{"visit": ..., "zone": id}` the same way.
- **Visit snapshot:** `Social.clean_island` gains `zones` (open ones only: id, theme, layout, residents by uid), each layout
  cleaned like `decor`; a profile without `zones` reads as Bramblebank only, so old profile docs still load.
- **Side isles:** `Data.ISLES`, bridges, signs and isle music go behind `base_mode`, then are deleted after sign-off (10.7 step 11);
  `bridges` stays readable but unused until then. Gems spent on bridges are refunded once at deletion.

## Consequences
save.gd VERSION 12 -> 13 and one migration; new content/rules/garden_zones.json; social.gd clean_island; home.gd wiring only.
Net.VERSION: no (home is not synced through Net). Checks: new `--garden-zones-check`, the garden save round-trip, `--arrival-check`.
