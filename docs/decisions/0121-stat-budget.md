# 0022: Stat budget (caps, bands, expedition clamp)

- **Status:** accepted
- **Date:** 2026-11-10
- **Area:** combat, saves, farm

## Problem
Care.stat_cap was 12 + 6 a level with no total, so at level cap 100 a stat could reach 612 and match_mods
grew without bound. GARDEN_MODERN.md 2.2-2.4 asks for a budget.

## Options
1. Hard-cap only (100 a stat). Simple, but grinding to 100 is as fast as to 50.
2. Cap plus total budget plus diminishing bands, and expeditions read only the first 25 points.
3. Leave expeditions reading the full stat (garden depth then leaks into combat balance).

## Decision
Option 2. Numbers in `content/rules/care.json` (stat_budget): stat cap min(100, 12 + 6 x level), total 240,
bands 1-50 full, 51-80 half, 81-100 quarter, loose (respec) points refill at 2x and skip bands,
`expedition_stat_points` 25. Fractional progress is stored per stat so "next point: N more plays" is exact.
Alternative if 25 feels low: raise expedition_stat_points (one number).

## Consequences
- `scripts/core/stat_budget.gd` (new) holds the maths; `Care.add_stat`, `stat_cap` and `match_mods` call it.
- Saves: new `rec.stat_frac` and `rec.loose`, defaulted in Care.ensure. A Boki over a cap keeps its points
  and gains nothing more; nothing is taken. Net.VERSION: no (match mods are computed locally from the roster).
- Minigames keep reading the full stat. Checked by `--stat-budget-check`.
