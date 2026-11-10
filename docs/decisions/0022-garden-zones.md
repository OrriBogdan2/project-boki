# 0022: Garden zones and the hub

- **Status:** accepted
- **Date:** 2026-11-10
- **Area:** the save format, the farm

## Problem
GARDEN.md 10: the garden becomes a hub with a Waystone and five zones you open with two keys.
The save has to say which zones are open and where each Boki lives, and an old save must load.

## Options
1. Move the whole layout into `Save.d["zones"][id]` now (10.7 step 2 as written). Every reader of
   `Save.d["layout"]` (about 30 sites in 12 files) changes in the same step.
2. Add `Save.d["zones"] = {id: {"open": bool}}` and `rec["zone"]`; the current layout stays where it is
   and is Bramblebank's. A zone gets its own layout entry when its build (step 7) needs one.

## Decision
Option 2, migration v12 -> v13 (`GardenZones.migrate`): Bramblebank open, every Boki in it. One scene
per zone through `Game.goto("home", {"zone": id})`, the same way a visit passes `{"visit": ...}`; only
the zone you are in is built. The hub is a fixed island (`HubLayout.island()`) shown through the visit
path, so nothing in it is saved and none of the farm systems run there. Until the house, Nook and
stall move to the hub (step 3), a plain `Game.goto("home")` still lands in Bramblebank.

## Consequences
The visit snapshot is unchanged (visitors still see Bramblebank). Option 1 stays open: the move is a
later migration from `layout` to `zones["bramblebank"]["layout"]`. Step 5 adds no save keys: a
Boki moves by changing `rec["zone"]`; only that zone's Boki (and your partner) spawn, and the farm cap
(`KinBox.farm_room`) counts each zone on its own.

Step 7a (Glasswater) is the first zone with its own island. A zone with a `build` in `garden_zones.json`
is laid out from that data (`ZoneLayout`, theme `glasswater` in `HomeLayout.THEMES`) and, while its Home is
open, `HomeLayout.of(Save.d)` answers with it, so no reader of the layout changes. Nothing of it is saved
but the snack patch's ripening timer (`Save.d["zones"][id]["patch"]`, a key that is simply missing on an
older save); build mode is off there. `ZoneDress` adds the shallows and a MultiMesh scatter; `BaseVolley`
reads the zone's court from `base_volley.json`.
