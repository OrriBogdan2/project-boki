# 0024: Evolution by species, with a level cap, Inks and an art gate

- **Status:** accepted
- **Date:** 2026-11-08
- **Area:** save format, raising

## Problem
The owner's 11-08 roster order: a Boki evolved into an affinity "form" every 4 levels with no cap.
It must evolve into the next species of its line at that species' own level, with an Ink, or by
trade, stop at level 100, and never take a shape that has no model yet.

## Options
1. An `evolve` key in each `content/kin_v2/<id>.json`. Clashes with the roster-109 branch adding
   the same files, and the entries for species without data would have nowhere to live.
2. One table, `content/rules/evolve.json`: species id -> `level` and `into` options (`path` by
   leading affinity, `item` an Ink, `trade`). Ids without data are the roster names in lower case.

## Decision
Option 2. `Evo.try_evolve` evolves only when `Evo.has_art(id)`: data, `art/kin/<id>/<id>.glb` and a
`BokiRig.FRAME` row. A Boki past its level waits; `Evo.catch_up` evolves it on load once the art
exists. Evolving sets `species`, appends the old id to `was` and the leading affinity to `forms`
(the next KinLib node). Mutations stay every 4 levels from 2. Inks are market goods (`kind: ink`):
a boss with `ink` in its def gives its Ink to the killer, and an extracted run finds one at 5%.

## Consequences
- Save v12: `Evo.migrate` keeps levels (over 100 come down to 100) and forms, adds `was`, and
  freezes the old generated form name ("Cindfang") in `form_name` until the Boki evolves.
- Today no line can evolve: every target lacks data or a model. Lines start as art lands.
- No line uses trade yet (the owner named none); the condition works and is tested.
- Inks are used from the Growth tab of a Boki's card (`EvoView`, `Evo.use_ink`).
- Every lair boss drops an Ink: the Sky Serpent its Wyrm Ink, the others (no Ink type) any Ink.

## Update 2026-11-09 (GAME_RULES_NOV8.md)
- Levels: the first form evolves at Grown (8), the second at Elder (16).
- `path` is gone: the four branching finals (Sporcupine, Vespox, Glassolotl, Echolop) carry `stat`
  (power/guard/speed). The higher trained stat at evolve time picks it; a tie goes by the affinity
  behind each stat (`Evo.STAT_AFF`). `Evo.lean` shows the pick on the Growth tab beforehand.
- Sex looks: roster `sex_forms: true` on the owner's 11 species; `BokiRig.model_path` loads
  `<id>_f.glb` for a female when it exists, else the male model. One special rule per line
  (a branch or sex looks) is enforced by `--evo-check`.
