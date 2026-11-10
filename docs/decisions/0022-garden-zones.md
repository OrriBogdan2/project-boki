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

## Unlock pace (GARDEN.md 10.3)
GARDEN.md gives no day targets, so these are set here: a runner (3 expeditions a day from day 2) opens
the second zone on day 2 and a garden-only player (no extraction, gems only from garden games) on day 3;
all five are open by about day 10 to 14 for both (medians). `--garden-unlock-pace-check` plays both
forward day by day on the real GardenZones, BlackMarket, Evo.eat and Lairs rule and fails outside these
(model assumptions: the `pace` block of `garden_zones.json`). Tuned data only: Drift Trader Wayseed
300 gems / 7 days -> 110 / 3 days (`market.json`), lair Wayseed chance 1.0 -> 0.05 a run
(`wayseed_chance`). Lean is not the bottleneck (two meals of a zone's snack, 9 lean a meal, `lean_key`
12), so it stays. Before the tuning the runner reached the fifth zone on day 6 and a garden-only
player the second on day 12 and the third after day 28. A new save starts with 60 gems and the
garden brings about 20 a day plus 10 per extra open zone; the day-3 target depends on that (price 110
sits between day 2 and day 3 of income), so retune the price if those change.
