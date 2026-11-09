# 0015: Combo flow (every ability with Shift and jump)

- **Status:** accepted (amends 0010)
- **Date:** 2026-11-03
- **Area:** movement / combat

## Problem
Owner review item 51: every ability combos with Shift and jump: holds and charges carry through a jump and a dash and let go in the air, any ability casts mid-jump, and a jump or Shift moves you out of any ability's recovery within 0.1 s. It supersedes item 30's "a dash ends Bjorn's hold" (a mantle still does). Today each kit decides on its own, mostly by ending holds whenever `Hunter.can_fire()` is false.

## Options
1. Per-kit flags: what item 30 grew; nothing to check across heroes.
2. Extend DashFlow (0010): the same per-hero file gets jump and hold rows, and kits ask DashFlow wherever a move used to end a hold.

## Decision
Option 2. New rows in `content/dash_flow/<hero>.json`, every one optional; a missing row means combine (`DashFlow.COMBINE`):
- `jump.<slot>`: a press mid-jump (in the air, not dashing). `fire` (default) or `buffer` (held for the landing).
- `into_jump.<slot>`: a jump pressed in the slot's wind-up or recovery; `into_dash.<slot>` (0010) is the same for Shift, with an optional `air` sub-row when the air dash differs. `fire` (default: the move goes, the ability runs on) and `cancel` (the move ends it) act at once; `buffer` (waits for the ability's end) and `lock` (refused while it runs) are exceptions.
- `hold.<slot>.<ground|air|jump|mantle>`: a held slot through a ground dash, an air dash, a jump or a mantle. `keep` (default: it keeps charging, or waits while the move stops the hunter acting, and lets go where you are) or `cancel` (it ends with nothing released).
Every row that doesn't combine (any mode but the default, except an into `cancel`, which also moves you at once) is an exception and carries `reason` and `source`. Rows seeded from today's measured behaviour carry the reason "today's behaviour, to review" for the hero agents to flip.

Kits ask `flow.ends_hold(slot[, move])` where a move used to end a hold, and `flow.pauses_hold(slot)` where a dash stops them acting (the hold waits and a release in it goes at the dash's end). Momentum out of an ability into a jump or glide keeps using `Hunter.glide_handoff`.

## Consequences
- `--dash-flow-check` walks every hero x slot x {ground dash, air dash, jump} x {cast mid, hold through, recovery out} and fails a missing reason or source on an exception; `docs/heroes/dash_interactions.md` lists the new rows (gen_wiki).
- Wired: the bow draw (`Hunter._trigger_bow`, one line), Bjorn's Crushing Blow (`on_dash`, `_hold_interrupted`), Zedran's Searing Wave (`lmb_override`), Breah's Quake Fist; the measured cancels today are exactly these. A mid-jump press with a `buffer` row is held by `DashFlow.route`. No Net or save change.
