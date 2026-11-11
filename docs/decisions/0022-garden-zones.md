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
Option 2, migration v13 -> v14 (`GardenZones.migrate`): Bramblebank open, every Boki in it. One scene
per zone through `Game.goto("home", {"zone": id})`, the same way a visit passes `{"visit": ...}`; only
the zone you are in is built. The hub is a fixed island (`HubLayout.island()`) shown through the visit
path, so the farm systems run there only for what you own: BaseLife walks your partner and, while an
unminded egg sits in the Nook, one Boki with the Ember knack that comes over to mind it
(`HubLayout.minder()`, it stays a resident of its zone); there are no side-isle bridges. Its fixtures (house, Nook with Incubator, Soul Shrine lot,
stall, Burrow, games board) are a template kept as `Save.d["hub_layout"]` (absent in older saves: built on
first use, so no migration); the Dash's showcase wall hangs by the games board (by the race post
before the hub opens) and the board lists this week's twist; build mode there offers only the Garden tab. With the garden on and the
first day's tutorial done, a plain `Game.goto("home")` lands in the hub (`GardenZones.landing`); before
that it lands in Bramblebank, where the tutorial runs. The garden's own house, Nook, stall and Burrow
stay until the zones are rebuilt (steps 7 and 11).

## Consequences
The visit snapshot is unchanged (visitors still see Bramblebank). Option 1 stays open: the move is a
later migration from `layout` to `zones["bramblebank"]["layout"]`. Step 5 adds no save keys: a
Boki moves by changing `rec["zone"]`; only that zone's Boki (and your partner) spawn, and the farm cap
(`KinBox.farm_room`) counts each zone on its own.
