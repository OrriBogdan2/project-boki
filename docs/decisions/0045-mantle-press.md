# 0045: A press during a mantle

- **Status:** accepted
- **Date:** 2026-11-10
- **Area:** movement / combat

## Problem
Nothing decided what LMB, RMB, E, R, dash or jump do while a hunter rises up a ledge (Hunter._ledge_rise,
MantleCarry). Abilities went off mid-climb by accident, and a dash ended the rise, so the hunter fell back off the
face (Kael, Motley). The rule (PARITY FIRST, 2026-11-07): every interaction chains and the source decides; where
the source is silent, buffer to the top and mark it [?], never guess a cancel.

## Options
1. One rule per kit, in each content/dash_flow/<hero>.json. Cons: 72 rows that all say the same thing, and the source
   has no per-hero mantle rule (supervive_physics.md: the mantle is one shared suction force).
2. One shared table that DashFlow, the press router every kit already uses, reads while the hunter mantles.
3. Wait for the Fsm loco machine (briefs/STATE_MACHINES.md M2b, ext/movement-unify, not on main) and put it there.

## Decision
Option 2: content/rules/mantle_press.json, one row per input. Dash fires mid-climb and the rise carries it over
(footage owner_mantle_clip 17.9-18.6 s); jump flings (owner's account of the source); LMB, RMB, E and R buffer to the
top [?]. Moving the routing into the loco Fsm when M2b lands is a move, not a rewrite.

## Consequences
scripts/arch/dash_flow.gd (routing), hunter.gd (a dash no longer ends the rise, no new lines), gen_wiki.py (the
table in docs/heroes/dash_interactions.md). Net.VERSION: no (local input routing). Check: --mantle-press-check.
