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
path, so none of the farm systems run there. Its fixtures (house, Nook with Incubator, Soul Shrine lot,
stall, Burrow, games board) are a template kept as `Save.d["hub_layout"]` (absent in older saves: built on
first use, so no migration); build mode there offers only the Garden tab. With the garden on and the
first day's tutorial done, a plain `Game.goto("home")` lands in the hub (`GardenZones.landing`); before
that it lands in Bramblebank, where the tutorial runs. The garden's own house, Nook, stall and Burrow
stay until the zones are rebuilt (steps 7 and 11).

## Consequences
Step 10: the profile doc gains "hub_layout" and "zones" ({id: layout} for each open zone that has one) and each
Boki its "zone" (`VisitZones`). A visitor lands in the friend's hub and hops through the same Waystone; an older
doc has neither and stays one island. Home is not synced through `Net`, so `Net.VERSION` stays. The away card
catches up the zone you arrive in (`Econ.catch_up_all(zone)`) and groups its journal lines by zone (`ZoneAway`). Option 1 stays open: the move is a
later migration from `layout` to `zones["bramblebank"]["layout"]`. Step 5 adds no save keys: a
Boki moves by changing `rec["zone"]`; only that zone's Boki (and your partner) spawn, and the farm cap
(`KinBox.farm_room`) counts each zone on its own.
