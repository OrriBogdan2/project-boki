# 0061: Pick the lead and the second at the portal

- **Status:** accepted
- **Date:** 2026-11-11
- **Area:** save format, farm

## Problem
DECISIONS 2026-11-11 "carry 2 in, 1 extra out": a lead Boki (summon) and a second (passive on), a key swaps the lead, equal passives count once. The home half is who goes: at the expedition portal (rack) the player picks both. The save already holds `active` (partner) and `active2`, but `active2` auto-picked the most trusted Boki and the pick UI was gated off (`Match.TWO_KIN`).

## Options
1. A new `lead`/`second` pair in the save. Cons: a second system next to `active`/`active2`.
2. Reuse `active` as the lead and `active2` as the second; the second is empty unless picked.

## Decision
Option 2. `CarryPick` (scripts/home/carry_pick.gd) owns the rules and the portal cards: pick by arrows, picking the second as lead swaps them, the lead can't be the second, one selectable Boki shows no second slot. Each card has one line "Carry: <passive>" (`KinText.passives`); when both give the same stat the card adds "Both give X: it counts once". `Save.second_kin()` no longer auto-picks. Save v13 -> v14: `active2 = ""` (lead = the current partner). No Net change.

## Affects
Home portal and Boki page only. The match half (summon the lead, swap key, passives counted once via `CarryPick.shared`, carry-out slot, 4 wisps) stays on `Match.TWO_KIN`, still false: until it flips, a second is picked and saved but not brought.
