# 0177: a fed Boki always goes on the expedition

- **Status:** accepted
- **Date:** 2026-11-23
- **Area:** care

## Problem
Owner report 11-23 (v0.24.21): "X is too weak from hunger to come" although the Boki's food bar showed full.
The refusal read the hidden starve clock (`Care.starve_h >= STARVE.refuse`, 18 h), and a meal only takes 4 h off
it, so a kin starved for 40 h needed 6 meals before it could go, whatever the bar said.

## Options
1. Make a meal wipe the starve clock. Cures weak and sick stages with one kibble; guts the sick system.
2. Refuse only while the belly is empty: `Care.refuses_to_go` = clock over 18 h and food at 0.
3. Count meals since the refusal in the save. Needs a new saved field and a reset rule.

## Choice
Option 2. Owner rule: after feeding once or twice it must always let you go. Any meal that fills the bar
(over 0.5) lifts the refusal at once; the clock still heals over hours, and weak/sick pace, droop, trust loss
and death are unchanged. An empty belly with a high clock is refused again, and the message says to give it one
meal. The "refuse" card text no longer says "too weak to go out" for a fed kin. No save change.

## Affects
`Care.refuses_to_go`, `HomeEcon.refuse_reason`, `Care.STARVE_INFO["refuse"]`. Check: `--feed-check`
(40 h starved, one meal, the expedition opens its confirm instead of "Too hungry to go").
