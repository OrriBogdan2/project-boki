# 0022: No natural death for Boki

- **Status:** accepted
- **Date:** 2026-11-08
- **Area:** save / farm

## Problem
A Boki you forget for days starved to death and went to a grave. The owner does not want neglect to kill a Boki for now.

## Options
1. Delete the death path. Simple, but the owner wants to bring it back later.
2. One rule flag `natural_death` in `content/rules/neglect.json` (default false): the starve clock stops at "sick" (30 h), so a Boki gets hungry, weak, too weak to go out, then sick, and recovers with food and rest. (chosen)

## Decision
Option 2. `Care.starve_step` and the offline catch-up cap the clock at `Care.starve_cap_s()`, and `Care.starve_stage` never returns "dead" while the flag is false. Losing a Boki to another squad in a match is not neglect and is unchanged.
Boki that already died of neglect: `Econ.revive_neglected` runs from `Econ.ensure()` on every load and puts each grave with cause "starved" back on the roster as itself (level, memories, trust kept) in the weak state, then tells you once. No save version bump: it is idempotent and has nothing to migrate in the format. A grave that the Soul Shrine had kept also comes back, with no ember spent.

## Consequences
`care.gd`, `econ.gd`, `home_econ.gd` (one notice), `content/rules/neglect.json`, `--neglect-check`. No Net change. Graves from a lost Boki stay. The "dead" stage and its notices stay in the code for when the flag is turned on.
