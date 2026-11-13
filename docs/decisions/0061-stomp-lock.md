# 0061: Stomp lock

- **Status:** accepted
- **Date:** 2026-11-11
- **Area:** combat / networking

## Problem
Owner 2026-11-11 (briefs/DECISIONS.md "stomping"): a stomp locks stomper and wisp in place for an animation nobody can cancel. The stomper can be attacked; the only ways out are the finish (the wisp dies) or a stun or hard CC on the stomper (the wisp lives). Each Hunter has its own stomp, and other stomps are a cosmetic you buy. Before this, the wisp could drift out of a stomp, a bullet's shove broke it, and a wisp owned by another game could not be stomped at all.

## Options
1. Keep the stomp inside Life and patch it. Smallest change, but Life is about bleeding, reviving and boxes, and the online path and styles would make it bigger still.
2. Give the stomp its own module (`Stomp`) and keep its looks in data (`StompLook`, content/rules/stomps.json). The stomper's game decides how a stomp ends and tells the others with one event.

## Decision
Option 2. One fixed time for every style: 3.0 s from commit to kill, Supervive's "~3 s" execute (docs/SUPERVIVE_DATA.md, Execute, [wiki] + [footage]), after the 0.2 s hold that commits you. What breaks it is `Stomp.breaks`: a stun, a hex, a real knock or launch (Capture's hard knock), and (main's break sweep, 11-12) a root, Grounded or a tow; `--stomp-cc-check` sweeps KIT_PARITY's CC rows. Plain damage and small shoves don't. There is no immunity to a second stomp after a break, because the reference has none (SUPERVIVE_DATA.md: "no global CC immunity"). Styles are poses on the procedural rig (HunterAnim), one per Hunter plus "Thunder Stomp" for 300 gems, worn in the "stomp" slot (Save.d["look"]["stomp"]; bought ones are in Save.d["stomps"]).

## Consequences
- New: `scripts/match/stomp.gd`, `scripts/match/stomp_look.gd`, `content/rules/stomps.json`, `tools/stomp_check.gd`, `tools/stomp_film.gd`. Life loses its stomp code, and the "missed" and per-slam chip paths go.
- Net.VERSION 0.24.7 (0.24.6 on the branch before main took it for Trade): the "stomp" event `[stomper, wisp, "go" | "broken" | "done" | "gone" | "extract", style]`. The wisp's own game pins its wisp and executes it on "done". A stomp from a game that goes quiet is dropped 2 s past its time.
- Save: two optional keys, both read with defaults, so old saves load as "wearing your own, nothing bought". No migration is needed.
- Debt: no shop screen for stomp styles yet (`StompLook.buy`/`equip` exist, and the check exercises them).
