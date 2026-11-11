# 0078: The hub owns the house, Nook, stall and Burrow

- **Status:** accepted
- **Date:** 2026-11-11
- **Area:** the save format, the farm

## Problem
GARDEN.md 10.1: the house, the nest corner (Nesting Nook, Incubator), the stall and the one shared Burrow are the
hub's. Bramblebank (the save's own `layout`) still built its own too, so with the garden on there were two Nooks
showing the one egg, two Incubators and two stalls. The egg, the nest items and the Incubator are save-wide
(`Save.d["egg"]`, `nest_set`, `incubator`): only the fixtures and their tiers sit on a layout.

## Options
1. A `Save.VERSION` step that deletes Bramblebank's copies. Breaks the farm with the garden off (base_mode is
   still off on this line, farm_build.json: "saves are untouched either way"), and v14-v18 are taken on other
   0.24.5/0.24.6 branches, so the number would collide.
2. Keep the entries and skip them in every reader of the layout (about ten loops in HomeBuild alone).
3. A load-time migration with the garden on (`HubLayout.claim`, from `HomeLayout.ensure`, like
   `SnackPatch.grant` and `Incubator.migrate`): idempotent, no version number.

## Decision
Option 3. With base_mode on, each built house/Nook/stall/Burrow in `layout.deco` goes to that layout's storage
(`inv`, so base_mode off sets it down again) and its tier carries over to the hub's (the higher one); one still
going up is taken down and pays back (`FarmSites.cancel`). `hub_layout` is made then if missing. The egg and
nest state stay as they are: the hub's Nook is the only one that shows them. A zone never builds them: the
classic farm's fixed ones stand nowhere (`HubLayout.vacant`), the stall is not set down (`HomeStall`), build mode
does not offer them. The first-day "pair" line points at the hub's Nook.

## Consequences
No Net change. A save with the garden off is untouched. `--garden-zones-check` (claim part, old save file round
trip, Bramblebank has none), `--garden-first-day-check` (pairs in the hub). When base_mode is signed off, the
stored copies can be dropped with the farm's other base_mode-off paths (DEBT).
