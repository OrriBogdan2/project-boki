# 0060: A closing zone

- **Status:** accepted
- **Date:** 2026-11-11
- **Area:** match flow

## Problem
Owner (11-11, "shrinking zone + map hazards"): a fixed match ended only when its clock ran out and every island fell at once, so nothing pushed squads together before that. The order: a seeded final area (the same for every player), the playable area closing toward it in 3-5 phases (wait, then shrink), shown on the drop map, the minimap and in the world, with a timer for the next close; damage outside that grows each phase; islands outside the last circle fall; the kin warns; the last exits inside the final area; bots keep inside; numbers in content.

## Options
1. Grow the Blight or the weather into a moving boundary. Cons: both are monster/visibility systems with their own pacing; folding a boundary in would tangle three systems.
2. A circle per phase, nested, generated from the shared seed and driven by the match clock alone. No Net traffic: every game computes the same circles and hurts only the bodies it owns.

## Decision
Option 2, in `scripts/match/shrink_zone.gd` (`ShrinkZone`, `Match.zone`), numbers in `content/rules/shrink_zone.json`. The final area is an outpost picked from the seed (HotZone's `hash([seed, ...])` pattern), its circle leaning into the exit's island, so an exit is always inside. Earlier circles are built backwards from it, each holding the next and drifting toward the map's middle; circle 0 covers the whole map. Times scale with the match length (612 s reference), radii with the map size (305 m). Hollow Crown: closes at 150-200, 280-325, 395-435 and 490-520 s to r 150, 95, 58 and 32 m; outside costs 1, 2, 4 and 7% of max health a second (through armor, no glider drain: src "zone"). At 520 s the islands with no ground in the final circle fall with whoever is on them; the clock's fall at 612 s stays. Off for the tutorial, training, duels, the arena and rolling sessions.

## Consequences
New: shrink_zone.gd, shrink_zone.json, tools/shrink_zone_check.gd (`--shrink-zone-check`). Wiring: match.gd (3 lines), hud.gd (minimap + clock row, 2), full_map.gd (2), bot.gd (goal override after the detour step, no fights while outside the edge), hunter.gd ("zone" joins the armor/glider exemptions), boki_lines.json ("zone" speaks the "storm" lines). No Net.VERSION bump (nothing new is sent), no save change. The falling islands have no animation yet (nor does the clock's fall).
