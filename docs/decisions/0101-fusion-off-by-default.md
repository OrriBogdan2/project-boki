# 0101: Fusion off by default (11-18), code kept

- **Status:** accepted
- **Date:** 2026-11-18
- **Area:** match flow / UI

## Problem
The owner decided Fusion (merge with your Boki, key X: MergeForm, MergeAugment, content/merge_forms, content/merges_v2,
decisions 0003 and 0004) is not part of the game for now. It must be able to come back later without a rewrite.

## Options
1. Delete the fusion code and content: clean, but costly to bring back.
2. One rules flag, `fusion_enabled` in content/rules/merge_forms.json, default false: every start and every screen that
   talks about Fusion asks `MergeForm.enabled()`. All code, content and tests stay.

## Decision
Option 2. `KinMerge.ready` is false while the flag is off, so X, bots, the Boki's own leap-and-merge call and the
tutorial can never start a Fusion. `KinBond.add` does not fill the bond meter (no "Bond full" toast or tip), the X
input is skipped in Match, and `Hunter.can_level("ult")` is false. The Fusion HUD box, hover text, kit and class cards,
Boki move tiles, controls card, keybind list (the action stays defined: X is reserved), words page, loading tips, the
first-match and 2v2 tutorial steps all hide while it is off.

## Consequences
- Nothing is deleted. Flip `fusion_enabled` to true to bring everything back.
- Checks that exercise Fusion set the flag to true in their setup (`Content.rules("merge_forms")["fusion_enabled"]`);
  `--fusion-off-check` proves nothing starts and nothing is shown with it off, and that it still works with it on.
- A Boki ability with the trigger `on_bond_full` never fires while off (the meter never fills).
- No save or Net change: the form events stay in KinNet but are never sent.
