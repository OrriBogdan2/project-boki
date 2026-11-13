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
path, so the farm systems run there only for what you own: BaseLife walks your partner and, while an
unminded egg sits in the Nook, one Boki with the Ember knack that comes over to mind it
(`HubLayout.minder()`, it stays a resident of its zone); there are no side-isle bridges. Its fixtures (house, Nook with Incubator, Soul Shrine lot,
stall, Burrow, games board) are a template kept as `Save.d["hub_layout"]` (absent in older saves: built on
first use, so no migration); the Dash's showcase wall hangs by the games board (by the race post
before the hub opens) and the board lists this week's twist; build mode there offers only the Garden tab. With the garden on and the
first day's tutorial done or skipped, a plain `Game.goto("home")` lands in the hub (`GardenZones.landing`);
before that it lands in Bramblebank, where the tutorial runs. One set (DECISIONS 2026-11-10, the hub at the
centre): with the garden on, the house, Nook (with its Incubator and the one egg, `Save.d["egg"]`), stall and
Burrow are the hub's. `HubLayout.holds` keeps Bramblebank from building them (a classic island's fixed set too:
`ClassicSet`): no nodes, blockers, build-mode tiles or auto-placed stall, so the first-day "pair two Boki in the Nook" and the Ember Boki's minding
happen at the hub's Nook. An older layout's entries stay on the save (the farm with the garden off still uses
them), so no migration.

## Consequences
Step 10: the profile doc gains "hub_layout" and "zones" ({id: layout} for each open zone that has one) and each
Boki its "zone" (`VisitZones`). A visitor lands in the friend's hub and hops through the same Waystone; an older
doc has neither and stays one island. Home is not synced through `Net`, so `Net.VERSION` stays. The away card
catches up the zone you arrive in (`Econ.catch_up_all(zone)`) and groups its journal lines by zone (`ZoneAway`). Option 1 stays open: the move is a
later migration from `layout` to `zones["bramblebank"]["layout"]`. Step 5 adds no save keys: a
Boki moves by changing `rec["zone"]`; only that zone's Boki (and your partner) spawn, and the farm cap
(`KinBox.farm_room`) counts each zone on its own.

Step 7a (Glasswater) is the first zone with its own island. A zone with a `build` in `garden_zones.json`
is laid out from that data (`ZoneLayout`, theme `glasswater` in `HomeLayout.THEMES`) and, while its Home is
open, `HomeLayout.of(Save.d)` answers with it, so no reader of the layout changes. Nothing of it is saved
but the snack patch's ripening timer (`Save.d["zones"][id]["patch"]`, a key that is simply missing on an
older save); build mode is off there. `ZoneDress` adds the shallows and a MultiMesh scatter; `BaseVolley`
reads the zone's court from `base_volley.json`.

Step 7b (Cinderstep) is the second, on the same system with no new code path: its `build` (theme
`cinderstep` with its own ground colours over the ember region, a warm stone, a climbing post, the snack patch) and a scatter of the slab kinds
`ZoneDress` gained (stepped terraces, glowing cracks; one batch and one material each). The Stump Shove
stump stands on the zone's own spot from `base_shove.json` `spots`, as Spark Volley's court does, with no
Training post.

Wild visitors (GARDEN_MODERN.md 5 rank 6, `GardenVisitor`) add one lazy key, `Save.d["visitor"]` (the wild
Boki's record, its zone, arrival time, favourite meals given, away-card notes and the earliest next
arrival); an older save simply lacks it and no version changes. The visitor is not on the roster: it joins
the zone's kins through `GardenZones.out_here()` for one garden day, and only becomes a roster Boki (or
leaves an egg) after three favourite meals. Suit data: `content/rules/garden_visitor.json`.

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

Hub hints (GARDEN.md 10): the hub shows three first-time hints through the message lane (`HubHints`, rules in
`garden_zones.json` "hub_hints"): the Waystone ring, the nest corner and a sleeping zone's two keys, one at a
time, once per save in `Save.d["tutorial"]["hub_hints"]` (an existing free-form dict, so no migration).
The garden tutorial's closing Waystone hint stays its own. `--hub-hints-check` covers it.
