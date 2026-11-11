# 0022: Per-Hunter stats (the Stats tab)

- **Status:** accepted
- **Date:** 2026-11-11
- **Area:** save / UI

## Problem
Players can't see how they do with each Hunter. ClassUnlock already tallies every expedition per Hunter
(`classes.hunters[id]`: knocks, revives, extracts...) for mastery goals, but not matches played or damage.

## Options
1. A second per-Hunter stats block in the save. Duplicates the mastery tally.
2. Add `matches` and `damage` to the counts ClassUnlock already tallies (`match_counts`), and read the
   table from `classes.hunters`. One tally, two new keys.

## Decision
Option 2. Save v11 -> v12 (HunterStats.migrate): each Hunter an old save played gets `matches` = the
fewest it can have been (its get-outs, at least 1) and `old_matches` = the same, so damage per match
divides only by the matches whose damage was counted (old damage was never kept).

## Consequences
Save.VERSION 12 with a migration; no Net change. New: `scripts/core/hunter_stats.gd`,
`scripts/ui/hunter_stats_view.gd` (a Relics | Stats tab on the farm's Relics screen), `--hunter-stats-check`.
