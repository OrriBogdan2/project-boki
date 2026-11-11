# 0061: The match flow as one state machine

- **Status:** accepted
- **Date:** 2026-11-11
- **Area:** match flow / UI

## Problem
The match phase (loading, planning the drop, dropping, playing, the closing minutes, ending, over) lives in flags
spread over the frozen match.gd: `over`, `result["ending"]`, `skydrop.planning`, the player's `dropping`/`riding`,
the Heart's state and the clock. The HUD derives its phase word from the clock, the Esc menu from `over` and
`ending`, the results from `over`; they disagree at the edges (briefs/STATE_MACHINES.md 2.11, M10).

## Options
1. Keep the flags, add a `phase()` helper that derives a word from them. Cheap, but a mirror: the flags can still
   say `ending` after `result` is replaced, and nothing refuses an illegal order.
2. One `Fsm` (scripts/core/fsm.gd, 0023 pattern) that owns the phase: LOADING > PLANNING > DROP > PLAY > CLOSING
   > ENDING > OVER, forward only, guarded edges, a logged history, and every reader asks it.

## Decision
Option 2, in scripts/match/match_flow.gd. ENDING and OVER are owned by the machine: `result["ending"]` is gone and
`Match.over` is a property that reads it (tools that set `over = true` to stop a match still work and are logged).
PLANNING/DROP/PLAY/CLOSING advance in `tick()` through guards that read the drop squad, the local player's drop and
the clock/Heart: Ways Out maps on as PLAY until the Heart's final seat (Heart FINAL/DONE) or the last
`FALLING_S` seconds, then CLOSING. No timing changes: the machine moves nothing the match did not already do.

## Consequences
match.gd: wiring only, net-negative (the dead `_finish_now` goes too). HUD phase word, Esc pause rule and the
results trigger read the machine. Local only: no Net.VERSION bump, no save change. Check: `--match-flow-check`.
The F7 readout shows the match machine's state and last transitions.
