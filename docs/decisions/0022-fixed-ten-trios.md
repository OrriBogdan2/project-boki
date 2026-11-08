# 0022: Extraction is always 10 squads of 3

- **Status:** accepted
- **Date:** 2026-11-08
- **Area:** match flow

## Problem
The owner decided on 11-08 that every Extraction match has 10 trios (30 hunters). Before this, the
expedition panel had Solo (20 hunters), Duos (10x2) and Trios (7x3), the online lobby had the same
three modes, and rolling sessions sized each wave from a 24-40 population target.

## Options
1. **All 10 squads drop at the start, from one skyship.** This is the source game's format and the
   fixed-length match already works this way. A rolling session would then have nothing left to roll.
2. **The 10 squads spread over the drop waves.** Rolling sessions keep late joining, but each wave
   brings only about one squad.

## Decision
The expedition (the default, fixed-length match) drops all 10 trios at the start (option 1, closest
to the source game). The opt-in rolling session keeps its waves but brings exactly 10 trios in all,
spread evenly over them (option 2), so the 10x3 rule also holds there. If rolling should keep its
bigger waves, the alternative is to put all 10 into the first 3-4 waves and end late joining at
about 8 minutes.

## Consequences
- `Data.SQUADS`, `Data.SQUAD_SIZE` and `Data.squad_opts()` are the one source. Home's expedition,
  the lobby, the Demo match, `perf_probe` and the loading line all read from them.
- The Solo/Duos/Trios tabs, the lobby's mode buttons, `exp_mode`, `Rolling.POP`/`POP_MODE`/
  `WAVE_HUNTERS`/`squads_for`/`squads_total` and `--rolling-pop` are removed.
- No Net.VERSION bump: the lobby's start message has the same shape, only the values are fixed.
  No save change.
- Chests are laid out by the map, not the headcount: 25 on the tier-1 map is 2.5 a squad (the same
  as the old Duos) but 0.83 a hunter (it was 1.25 with 20 hunters).
- Checks: a new `--squad-format-check`. `--rolling-check` now asserts the fixed 10-squad split.
