# 0022: Armour progress rules in content, set to the source

- **Status:** accepted
- **Date:** 2026-11-11
- **Area:** combat

## Problem
Armour progress (what fills it, how much per tier) sat in `Hunter.ARMOR_TIERS` and inline rates in
`Match.on_damage`: monsters counted a third, thresholds were hand-scaled. DECISIONS 2026-11-10 makes
hitting players build armour only (no level XP), and PARITY FIRST wants the source's numbers.

## Options
1. Keep the consts, retune by hand. Cheap, but the scale stays a guess and the rates stay in match.gd.
2. One focused module (`ArmorXp`) over content/rules/armor_xp.json: the source's thresholds and the
   two base-health figures, rates per target kind. match.gd shrinks to one wiring line.

## Decision
Option 2. Thresholds are the source's cumulative damage scaled by base health (Medium 145 over the
source's median 1,030); dealt and taken count point for point; monsters, Boki and downed rivals
build none; a knock adds a rules chunk (source amount unpublished).

## Consequences
New scripts/match/armor_xp.gd and content/rules/armor_xp.json; hunter.gd loses the progress column
and the knock const; match.gd -6 lines; main.gd loses the inline parity hook (registry). No save or
Net change. `--armor-parity-check` gains rate rows and a scripted duel at the TTK matrix's damage.
