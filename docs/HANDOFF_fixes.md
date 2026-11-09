# Handoff: branch `ext/fixes` (owner fixes bundle)

Net version for this branch: 0.12.0 (main was 0.11.0 at sync59; only the "wdrop" put-down age changed the sync shape).

## Status per item

| # | Item | Status | Where / checks |
|---|---|---|---|
| 1 | Incubator: 5 visible slots, parallel hatching, ember/warmer speed-up | done (already on main, nothing to add) | scripts/core/incubator.gd, scripts/home/home_incubator.gd; `--incubator-check`; shots incubator_cradles_farm.png, incubator_panel.png |
| 2 | Boss loot: fewer high-value drops, Rare Egg on its own spot with its own beam | done | match.gd / lairs.gd; `--lair-lock-check`; shot boss_loot_rare_egg_beam.png |
| 3 | Reload on swap and drop-to-reload exploit | done | hunter.gd, match.gd, Net "wdrop" carries put-down age; `--reload-swap-check` |
| 4 | Level readability: portrait number + XP ring, level-up flash and sound, R locked until 6 | done | hud.gd, tools/gen_level_sfx.py, audio/level_up.wav; `--level-hud-check`; shots level_hud_locked_r.png, level_up_flash.png |
| 5 | Boss lair lock-in (20 s) with inside lever | done | lairs.gd; `--lair-lock-check`; shot lair_locked_in.png |
| 6 | `--loop-tour=thief` end to end with the empty farm start | partial: ran to the results screen and back to the farm (84 shots); the last three failures it logged (scan timed out in real seconds, uplink lift walk-in, Boki-in-Burrow roster check) are fixed in tools/loop_tour.gd but not re-run, because the tour takes 22-40 min of a shared Godot slot | tools/loop_tour.gd |

## Still to do
- One more `--loop-tour=thief` run when a slot is free, to confirm bad=0.
