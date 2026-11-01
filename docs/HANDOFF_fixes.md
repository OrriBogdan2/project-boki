# Handoff: branch `ext/fixes` (owner fixes bundle)

Net version for this branch: 0.8.1 (after sync56 is merged; 0.6.5 until then).

## Status per item

| # | Item | Status | Where / checks |
|---|---|---|---|
| 1 | Incubator: 5 visible slots, parallel hatching, ember/warmer speed-up | done (already on main, nothing to add) | scripts/core/incubator.gd, scripts/home/home_incubator.gd; `--incubator-check`; shots incubator_cradles_farm.png, incubator_panel.png |
| 2 | Boss loot: fewer high-value drops, Rare Egg on its own spot with its own beam | done | match.gd / lairs.gd; `--lair-lock-check`; shot boss_loot_rare_egg_beam.png |
| 3 | Reload on swap and drop-to-reload exploit | done | hunter.gd, match.gd, Net "wdrop" carries put-down age; `--reload-swap-check` |
| 4 | Level readability: portrait number + XP ring, level-up flash and sound, R locked until 6 | done | hud.gd, tools/gen_level_sfx.py, audio/level_up.wav; `--level-hud-check`; shots level_hud_locked_r.png, level_up_flash.png |
| 5 | Boss lair lock-in (20 s) with inside lever | done | lairs.gd; `--lair-lock-check`; shot lair_locked_in.png |
| 6 | `--loop-tour=thief` end to end with the empty farm start | partial: farm part (builds house, crop patch, pot) done; tame and lair legs patched in the last WIP commit, not yet confirmed end to end | tools/loop_tour.gd |

## Still to do
- Run `--loop-tour=thief` to the end and fix what breaks.
- Merge sync56 once it lands on main (not there yet at the time of writing), bump Net to 0.8.1, `python3 tools/health.py --strict`, full suite, `--simtest --seed=5`.
