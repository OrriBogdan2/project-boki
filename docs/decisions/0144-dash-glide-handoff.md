# 0061: Shift into the glider without a hitch, and a dive that carries into the feather

- **Status:** accepted
- **Date:** 2026-11-11
- **Area:** movement

## Problem
Owner playtest 0.24.4: "a weird hitch when i shift->glider" and "momentum doesn't carry after going down in abyss and trying to feather up". Measured per frame (`--airdash-glide-check`): several air dashes end with a one-step cut (Shiv 14 to 4 m/s, Kingpin 20 to 3.5, Felix 24 to 12), Kingpin's and Felix's cut even an open glider, and a press just after Shift waited out the kit's wind-down (Oath 0.3 s), then popped the glider open late. Opening the glider under the lip threw the fall away: forward speed stayed at cruise (5 m/s) whatever the dive.

## Options
1. Edit each kit's dash end (13 kits, each with its own distances and source notes).
2. One focused module on the Hunter (`DashGlide`) that eases any kit's air-dash cut, keeps it for an open glider, and gives a short press grace; the pull-up in `GlideLift.open_kick`.

## Decision
Option 2. Tunables in `content/rules/tuning.json` `dash_glide` (ease_t 0.07 s, grace 0.15 s; Brall 0: the source's wind-down frames); `GlideLift.PULL_FWD` 0.6 / `PULL_RISE` 0.3 of the fall speed, in the abyss only (the high glide keeps the owner's 11-08 "the drop never turns into speed").

## Consequences
`scripts/match/dash_glide.gd` (new), 6 lines in `hunter.gd`, `Loco.dash_glide_*`, `GlideLift.open_kick`. A glide press that the state machine refuses no longer ends the dash (Joule's Wirerun). Air dashes that stop short slide 0.7-1.2 m further while the cut eases. Feathering covers ~45% more abyss per glider heat (`feather_m` 114 to 166 m). Net.VERSION: no (velocity is already synced). Saves: none. Checks: `--airdash-glide-check` rewritten (it measured a 0 m/s exit before), `--move-feel-check` rows `dive_feather_*`.
