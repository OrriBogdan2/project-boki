title: Integration lane bundle 11-15: 22 READY branches (anim timing, wisps, garden/kite, loco polish, parity, Sable wings)
head: ext/merge-lane-integ-1115
base: main

Bundle of integration-lane READY branches, built from main by cherry-pick (main wins on conflicts, intent re-applied by hand where hunks clashed). Branch tips in the unmerged list at 713 gap. Last merge of origin/main: 24a9d4bd01.

## Merged (unique commits taken / unique vs main)
anim-timing-ashwick 3/3, anim-timing-dredge 3/3, anim-timing-rimewright 1/1, anim-timing-juggernaut 4/6, anim-pilot-layers-verify 6/9, combat-hurtbox-parity 1/2, combat-ranks-b 1/1, combat-wisp-hit-rules 9/9, fix-strafe-cadence-1115 2/5, garden-kite-2 4/4, garden-seasons 2/2, hunter-loco-polish-1115 14/16, parity-bulwark-crush-rebased 3/3, parity-kael-cc-riders 1/1, parity-ttk-kael 1/1, remote-move-clear 2/2, sable-appeal4 2/13, sable-wings 3/4, split-kmoves-pin-bjorn 1/1, stuck-integ-b6204ee2 6/8, vfx-garden-games 13/14, vfx-garden-games-2 12/18.
(Counts by commit subject; the rest of each branch conflicted with main or was already there.)

## Skipped
- The big stuck-integ-* and *-integ-* branches (hundreds to 3800 commits each; not bundleable by hand): stuck-integ-11014837, -42241ff1, -86b7d6eb, -c2a69297, -7fc43430, -606e9a98, -f6bd2b7c, -d2f36c16, soul-link-integ-rebased, integ-1113-D2, mc-integ-1112d.
- Not touched this round (small, own review): stuck-integ-e28956f8, -09e533a4, -f11b417c, -cff77e31, -f60f9dd7, integ-ways-out-0245, integ-1113-D1, integ-1113-A1, stuck-integ-aeb8eb0f.
- wisp-summon-* tips (74-79 commits each).

## HARD
- sable-appeal4 (11 of 13 commits did not apply) and fix-strafe-cadence-1115 (3 of 5): need the author to re-base on current loco/anim rules.
- Overlap (same patches, both can land): sable-wings also in ext/merge-lane-misc3-1115, split-kmoves-pin-bjorn in merge-lane-hunters7-1114-b, garden-seasons in merge-lane-farm-1115, anim-garden-games in merge-lane-vfxsfx1-1115.
- gh is not installed on rpc7, so open PRs were checked by branch overlap only.

Resolved on the main merge: tools/check_registry.gd (union of rows), warden_anim sable.json (main's diagonals + bob_fix) and tarek.json (air_legs + upper).
