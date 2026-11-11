# 0046: the merge works from the wisp

- **Status:** accepted (behind the boki_wisps setting)
- **Date:** 2026-11-10
- **Area:** combat, match flow

## Problem
With Boki riding as wisps (0038) and summoned out of them (0039), what does R (the bond merge, 0001, 0003) do?
briefs/boki-art/WISP_DESIGN_OPEN.md Q2 recommends: R stays the merge, independent of the summon, always from the wisp.
Today's path (KinMerge, Kin.merge_in) only needs the Boki on the shoulder, which a wisp is, but it kept the wisp
model: the form's armour, the giant mount and the xform spiral drew the little critter, and the end popped a walking
Boki out (or rested it) beside you.

## Decision
- Wisp + R: plan stays "merge". The wisp blooms into the full Boki (KinWisp.set_wisp, so the form and the giant
  mount have their body), spirals into you from where the wisp orbits, and the form goes live as today.
- Summoned + R: plan stays "leap". When it lands the window is over and the full cooldown starts, the same as
  sending it back early (KinSummon.fused). Nothing else about the summon changes.
- When the merge ends (time, ultimate, shell broken, knocked) the Boki is a wisp on your shoulder again
  (KinWisp.rewisp): no pop-out, no release rest (nothing to rest: it is a wisp; the hunter still gets the afterglow).
- A merge never adds to, resets or pauses a wisp's summon cooldown; it keeps counting down. Summon is refused while merged.
- A Boki that is already walking for another reason (left behind, guarding) merges and ends as today.
- No data, save or Net change (the merge state is local; remotes follow the kin snapshot's wisp flag).

## Consequences
- `--boki-system-check` (wisp_merge): merge from a wisp (3 species), with the summon cooling down, from a ready wisp,
  from a summoned Boki, the ultimate release.
- Edge not handled: a window running out in the 0.2-0.5 s of the leap itself.
