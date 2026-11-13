# 0022: Branching finals count pips (path meter)

- **Status:** accepted
- **Date:** 2026-11-10
- **Area:** the farm (Boki growth, save fields)

## Problem
GAME_RULES_NOV8 section 3 picks a branching final (Mycroll, Vespyx, Prismander, Echolop) by the higher
trained stat alone, so the form and the build are one choice. GARDEN_MODERN section 3 asks that items,
lean, care and cups change the form too, visibly, and that the player presses Evolve.

## Options
1. Keep stats alone and add tokens as a tiebreak. Small, but every Ringrove stays a Guard Boki.
2. A pip meter per line: stat lead 3, element lean 1 at half / 2 at full, worn path tokens up to 3, care up
   to 2 (trait 0.6+, most-used toy trains the key stat), Cup Ribbons up to 2. Most pips wins; tie -> stat
   lead; still tied -> undecided, the Boki waits.

## Decision
Option 2. Changes GAME_RULES_NOV8 section 3: the stat lead becomes 3 pips (with nothing else it still
decides alone), and Curious finals (Chandelotl, Chimelop) use Focus, not Speed. Table in
`content/rules/evo_paths.json`, logic in `scripts/core/evo_path.gd`, the meter on the Growth tab
(`scripts/ui/evo_path_view.gd`). "Evolve now / Not yet" at the line's level; never into a form whose art
(`art/kin/<form>/<form>.glb`) is missing; a worn Stayleaf blocks. Inks (Minkee, Jarmit) only preview.

## Consequences
New lazy record fields, no migration: `rec.toy_use` (toy id -> plays, for the toy habit). `rec.ribbons` is read
as written by ext/garden-prizes-cups (empty until then).

On main's evolution by species (docs/decisions/0024, merged 11-11 as ext/garden-path-meter-rebased): the swap is
Evo's. Lines in `evo_paths.json` are keyed by the species that branches in `evolve.json` (Sporcupine, Vespox,
Glassolotl, Zapple), the level is that line's, and its two ends are the same two species. Such a line never
evolves by level alone: "Evolve now" calls `Evo.try_evolve(rec, "path")`, which takes the meter's winner instead
of the leading affinity. The Ink previews read `evolve.json`'s item options and the market goods. Today no
middle form or final has data and art, so only Zapple shows the meter, and every Boki at its level waits.
