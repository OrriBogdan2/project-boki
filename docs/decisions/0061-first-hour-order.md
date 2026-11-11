# 0061: One first hour (garden and eggs first, Relic at the portal)

- **Status:** accepted (owner call 2 in reviews/DESIGN_REVIEW_1110.md, default "built that way")
- **Date:** 2026-11-11
- **Area:** UI / farm

## Problem
A new save showed two menus before play (the egg pick, then the Relic pick) on the hatch island, and only then
the farm. Design review 11-10 change 2: garden first, the eggs are the opening beat, the Relic pick moves to the
portal, then the combat tutorial.

## Options
1. Hatch in the garden, Relic pick inside the farm with MaskBeat (as Hob's second Relic): one scene, but it drops
   the first-Relic moment (the Relic drifting from the crystal, the ability clips) the owner signed off.
2. Hatch in the garden (GardenHatch), and the portal takes you to the dais for the Relic pick and MaskMoment
   unchanged, then the combat tutorial. Keeps that moment; the dais reads as the far side of the portal.

## Decision
Option 2. New save: prologue, card, make yourself, farm with the three starter eggs in front of you and the
black egg in its basket at the back; hatch and name it; the farm tutorial runs. The portal, while
ClassUnlock.needs_starters(), opens Hatch: "Choose your first Relic." (Lace, Kael, Vex) with the one-line
Relic sentence and a ticked "Learn to fight first" box; unticked, the Relic is kept and you go home with
tutorial.match set, as the old "Skip the tutorial" did. The farm tutorial never locks the portal, so you can
leave it any time and it waits; its Skip button stays off by the owner's Nov 3 call (one line to turn on:
farm_tutorial.json options.skippable).

## Consequences
New scripts/home/garden_hatch.gd (the egg code moved out of scripts/ui/hatch.gd); home.gd +5 lines of wiring.
No save change (same keys: roster, tutorial.hatched, classes.picks), no Net change. Checks: --hunter-unlock-check
walks the whole order (shots with --shots-dir), --hatch-check and --mystery-egg-check follow the move.
