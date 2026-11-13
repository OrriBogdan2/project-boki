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
- Inks have no use button yet (`Evo.use_ink` is the API); it needs Ermink and Jarmit in data.
- Only the Sky Serpent has an Ink type (Wyrm); the Colossus and Brood Mother drop none.
