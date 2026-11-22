# 0100: Merging only adds, every ability stays yours

- **Status:** accepted (owner rule of Nov 17 2026, after a tutorial and match playtest); finishes [0004](0004-merge-augments.md)
- **Date:** 2026-11-17
- **Area:** combat / input (the Merge, hunter kits)

## Problem
0004 made the merge an augment on your own kit, but old "the form owns the buttons" guards stayed behind. While
merged (and through the 0.7s transformation) several heroes could not fire LMB, their R (hunter ultimate) would not
cast, the Boki key was cut, a few kits cancelled E / flight / delayed hits, and the aim reticles were hidden.
The owner's playtest: "it stops letting me use abilities during it".

## Options
1. Keep the guards where a form "needs" them: rejected, every one is a lockout and the owner rule is nothing locked.
2. Remove every merge lockout and keep the bonuses (decided). The form ADDS: stats, look, shell, cooldown haste, the
   LMB rider, the RMB / E / dash add-ons and its own ultimate on the Merge key.

## Decision
- While merged, and during the transformation, LMB, RMB, E, R (hunter ultimate), Shift, jump, glide, crouch and the
  Boki key (C, cast through you at full power) go off exactly as unmerged. Deleted: `MergeAugment.route`, the per-frame
  hold drop in `ArchKit.tick`, `AimKit.blocked`, and the `KinMerge.active` / `transforming` checks in `HeroUlt`,
  `ult_glow`, `first_ult_hint`, and the Ashwick, Thief, Dolm, Juggernaut, Dredge, Gil and Bulwark kits.
- Kept on purpose (not abilities): pressing the Merge key starts the merge and drops whatever hold was in flight
  that instant (once, `KinMerge.press`), G and the order wheel stay inert while the Boki is inside you, the bond meter
  stops filling, and the merge's own ultimate stays on the Merge key (second press, after `ult_lock_s`).
- No move set replaces an ability any more, so nothing had to become an extra: the 0003 kit swap (`MergeHolds`, the form
  `lmb`/`rmb`/`e` blocks) was already gone, and the fusion-states revival dropped in the #126 split is not brought back.

## Consequences
- Files: the kits and modules above (net deletions), `tools/merge_keeps_check.gd` (new, `--merge-keeps-check`).
- `tools/merge_form_check.gd`: "its ability is off while merged" now asserts the Boki key works.
- Net.VERSION: no. Saves: no.
- Check: for every hero, each of LMB, RMB, E, R, Shift, C, jump, glide and crouch must go off merged whenever it goes
  off unmerged (a control run in a fresh match), and the shell, look, haste and LMB rider are still on.
