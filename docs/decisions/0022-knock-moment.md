# 0022: The knock moment cuts every held and buffered input

- **Status:** accepted
- **Date:** 2026-11-11
- **Area:** combat / movement

## Problem
PARITY FIRST (briefs/DECISIONS.md 2026-11-07): the instant a Hunter is knocked must read like the source. Source data says a knock cancels a held channel outright and the knocked body moves under its own rule from that step. Ours released a held RMB into its cast on the knock (a charged shot or hold dash went off from the Wisp), let a dash in flight carry the Wisp to its end, and replayed presses parked during a dash as a deny buzz 0.15 s later.

## Options
1. Gate each path on `downed` where it fires (kit tick, dash flow, bow, buffers): scattered, and the hold still looks open for a tick.
2. One cut at the knock: `KnockMoment.cut` (scripts/match/knock_moment.gd), called from `Match.knock` in place of `cancel_abilities`, drops every hold and buffer on the knock step and ends a dash in flight.

## Decision
Option 2. The held RMB is dropped (never released), the bow draw, buffered swing, Shift and jump buffers and the dash-flow parking lot are cleared, and a dash in flight ends where the knock lands it (the hit's own knockback still carries). Glide, Wisp control (immediate, 0.4x speed) and the pop-in (0.25 s) already matched and are unchanged. The camera row is unseen in the footage and untouched.

## Consequences
match.gd: one line swapped. No Net or save change (the knock event is unchanged). Check: `--knock-moment-check` (12 Hunters, LMB/RMB/Shift held and re-tapped at the knock). Rows in docs/MOVEMENT_FEEL.md "The knock moment". Left for later: a stun still releases a held RMB into its cast (source cancels it); kit flights (`fly_t`) not audited.
