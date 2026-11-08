# 0019: The knock dash refresh reaches assisters, multi-charge dashes get one charge

- **Status:** accepted
- **Date:** 2026-11-08
- **Area:** combat / movement

## Problem
Owner item 159: every hunter should get their dash back on a knock or an assist, and the source's patch rule
says a hero with several dash charges gets only one charge back. `DashReset.takedown()` gave the knocker
every charge and nobody else, and Vex's kit refilled Slipstep on its own as well.

## Options
1. Each kit listens for knocks and refreshes itself: twelve copies of one rule, easy to double-fire.
2. DashReset owns it: the victim keeps "who on the other side hurt or crowd-controlled me, and when", written
   once per landed hit (no per-frame work); on a takedown DashReset reads it for the knocker's teammates.

## Decision
Option 2. Recipients are the knocker plus every teammate whose damage or CC landed on the victim in the last
`ASSIST_WINDOW` (4 s). One-charge dash: full refill. Two or more charges: +1 charge (never past max). The
long-dash cooldown clears for each. Only the knocker heals (our 5%, unchanged). An assist plays the cue
`ASSIST_CUE_DB` quieter. A hero's `dash.knock_refresh: false` in content opts out (none do; default on).
Kills run the same rule as knocks, as before. Each game refreshes only the hunters it owns.

## Consequences
`scripts/match/dash_reset.gd` (the rule, `note()`), `Ent.hit_by` (one small dictionary per body), one
wiring line each in `Match.on_damage`, the net knock/out events, `Fields` (damage-free CC) and `Displace.tow`.
Vex's Hot Streak no longer refills Slipstep itself. No Net.VERSION bump (nothing new is synced), no save change.
`--kill-reset-check` covers knocker, assister, stale assister, the +1 rule and the opt-out.
