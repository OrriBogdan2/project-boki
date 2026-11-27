# 0181: How a Boki is played with decides what it becomes

- **Status:** accepted
- **Date:** 2026-11-27
- **Area:** save / farm / match results

## Problem
Owner 2026-11-27: stats should come from doing lots of expeditions; how you play with a Boki should decide how it
evolves, which mutations it gets and which stats it focuses, not hand out raw stats. Today garden runs pay stat
bites without an expedition, and the four affinities only pick a form.

## Options
1. A new "playstyle" record next to the affinities: a second system that says the same thing.
2. The four affinities are the leaning (chosen): `PlayStyle` reads them, and every number is data.

## Decision
`content/rules/playstyle.json` + `scripts/core/play_style.gd`. Garden activities (care, toys, games, drills) give
affinity points only, at most `garden.day_cap` a Boki a day; expedition stats give most (`extraction`, moved out
of `Evo.learn`). The leaning is the affinity in the lead without worn path tokens; its tier is its lead over the
next one. The tier sets the stat focus of expedition growth (`run_growth`, paid in `Game._kin_after`), pips on a
path meter (`EvoPath` source "play") and the mutation odds and signature part (`Evo.on_level`). Free daily race and
drill runs go from 2 to 1 (`care.json` `train_runs.daily`); the alternative 0 is noted in the brief.

## Consequences
No save bump: `rec["style_day"]` and `rec["run_frac"]` are lazy (an older record starts from none). No Net
change (farm records, paid on the result the client already applies). `Evo.learn` is gone (one caller). Mutation
rolls keep their rng call order, but the stray chance now comes from the tier (0.3 for a Balanced Boki, as before, so wild Boki roll the same
stray draws and the match layouts the sweep checks stay as they were).
Checks: `--playstyle-check` (new), `--evo-path-check`, `--results-boki-line-check`, `--train-runs-check`.
