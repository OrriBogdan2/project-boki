# 0061: A rare trait on the Boki, rolled once at hatch

- **Status:** accepted
- **Date:** 2026-11-13
- **Area:** save format, evolution

## Problem
Owner 11-13: a few percent of Marchleaf should evolve into the dark one (Shinobant), tied to a rare trait, never a coin flip at evolve time. The Boki needs a stored, visible trait that an evolve option can require.

## Options
1. Roll at evolve time: unreadable, ruled out by the series rule.
2. Reuse `Mutations` (inherited rare mutations): they are bred and have perks, a different system.
3. A `rec["rare"]` id rolled at hatch from the egg's seed, next to the sex roll (`BokiQuirks`).

## Decision
Option 3. `content/rules/boki_quirks.json` "rare_trait" lists the kinds (Marchleaf: nightmark, 4%). `BokiQuirks.set_rare_trait` runs where `set_sex` does (`Save.new_kin`, `Care.breed`). `rec["rare"]` is `"nightmark"` or `""`; kinds with no entry have no field. Evolve options take `"trait"`. No `Save.VERSION` bump: `BokiQuirks.migrate` (called in `Save.load`, like `Care.migrate_habits`) rolls once for a listed-kind Boki with no `rare` key and the next save keeps it, so it holds at any save version.

## Consequences
Save format gains one optional key. No Net change. Checks: `--boki-quirks-check` (rate, round trip, migration), `--evo-check` (gating, art wait).
