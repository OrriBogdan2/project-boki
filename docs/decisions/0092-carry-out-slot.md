# 0092: The carry-out slot (one extra Boki out)

- **Status:** accepted
- **Date:** 2026-11-11
- **Area:** match flow, networking

## Problem
DECISIONS 2026-11-11 "carry 2 in, 1 extra out": a Boki claimed in the match rides home in one carry-out slot (no passive, no summon) and can be stolen when its carrier is downed; a hunter never holds more than 4 wisps (lead, second, carry-out, one stolen). Decision 0091 built the two in; the run box still held 3 capsules.

## Options
1. A new slot object next to `Hunter.caught`.
2. Keep `Hunter.caught` (it already spills into the deathbox, goes home on extraction and is synced by the "caught" and "spill" events) and cap it by slot kind.

## Decision
Option 2. `content/rules/capture.json`: `carry_out` 1 (claims), `stolen` 1 (another hunter's own Boki, `lost_from` set), `wisp_cap` 4. `Capture.room(h, rec)` checks the slot for that Boki and the cap; `Capture.mate_with_room` finds a teammate with a free slot (each hunter has their own, no team pool) and the toast and a ping point at them. Deathbox looting, loot rows and bots use the same `room`.

## Consequences
- Net: the hunter row ends with the slots in use (`HunterNet`: claimed, stolen) so a client knows a peer's slots (`Capture.slots`); it is part of 0.24.6 (comment in `Net.VERSION`). The host holds real records for everyone, the owner's game for itself.
- No save change: `Hunter.caught` was already saved into the run result and carried home as before.
- Checks: `--capture-check` (slots, cap, mate, snapshot round trip), `--kin-loss-check` row 11 (a downed hunter's claim is stolen, slots and cap for the taker).
