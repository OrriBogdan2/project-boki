# 0061: AimKit "all" telegraphs online (Net event "tele")

- **Status:** accepted
- **Date:** 2026-11-12
- **Area:** networking

## Problem
A kit marks a telegraph `all` when foes must read it (a slam disc, a landing zone, a lane wind-up). Kits only
run on the game that owns the hunter, and AimKit was local, so online the foe the telegraph warns never saw it.
Before this, only a 0.35 s `net_ring` at some payoffs reached other games (docs/AIMKIT.md, the table).

## Options
1. One Net event per ability (like ext/combat-vex-cone-net's burr cone). Pros: tiny messages. Cons: about 40
   call sites in 20 kit files, each a sender and a receiver; every new `all` telegraph needs its own.
2. One event for AimKit itself: AimDraw sends each `all` entry it is given for a hunter this game runs, as the
   resolved entry AimShapes draws; other games put it under their copy of that hunter. Pros: every kit, present
   and future, with no kit edits; the remote draws exactly the caster's shape. Cons: a few hundred bytes per
   live telegraph per 0.1 s.

## Decision
Option 2 (`scripts/match/aim/aim_net.gd`), Net.VERSION 0.24.6. `["tele", nid, id, entry]` shows or refreshes,
`["tele", nid, id]` drops; through `Match.net_event` and `Net.event`, the "ev" topic. A refreshed telegraph is
sent at most every 0.1 s and lives 0.25 s past its keep on the receiver; the caster's game sends the drop when
it ends there. Aim reticles (`all: false`) and cursor states stay local.

## Consequences
AimDraw (`put` sends, `rebuild` sweeps drops), one routed line in match.gd. If ext/combat-vex-cone-net merges,
its burr-cone event duplicates this path for that cone (drop one). Checks: `--aimkit-check` (every shape kind
round-trips and draws on a remote copy), `--remote-anim-check` (every `all` telegraph of every kit's casts shows
on the other game, per kind), `--tele-net-shots` (two games, a GPU screenshot of a foe's view).
