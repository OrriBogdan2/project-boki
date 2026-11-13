# 0049: A higher drop with a dive you hold

- **Status:** accepted
- **Date:** 2026-11-10
- **Area:** movement / match flow

## Problem
The opening drop is over quickly and reads flat: the ship flies at 70 m, the fall is slow, and nothing on screen says "height". Its numbers are scattered as constants over `hunter.gd`, `match.gd`, `drop_launch.gd`, `drop_squad.gd` and `drop_feel.gd`. The early-camps spec (`EARLY_CAMPS_DROP.md` 3.1, 3.2, 3.4) wants a 110 m ship, a 7 s straight dive against a 15 to 22 s quiet glide, and a view that sells the fall.

## Options
1. Raise the numbers only. Cheap, but since item 163 the canopy opens when the 2.5 s launch ends, so the dive never happens in a real match: every landing would take about 15 s and the dive view would never show.
2. Keep diving after the launch; Space opens the canopy. Reaches the 7 s dive, but undoes item 163 (the glider opens when the launch ends) and bots would have to learn to open it.
3. Keep item 163 and add a held dive: under the open canopy of the opening drop, holding the dive key (crouch, the in-match glider dive's key) folds it into the dive; letting go opens it again; it opens by itself at 10 m. Bots hold it when their spot is well inside their reach.

## Decision
Option 3. It makes the spec's times real (about 7 s held, about 15 s not), matches the Hard Landing task's wording ("hold the dive key through the last 10 m"), keeps item 163 and the drops without a ship (those still start in the dive), and reuses a key players already know. All drop numbers move to `content/rules/drop.json`, read by `DropFeel`.

## Consequences
- New `content/rules/drop.json`; the drop constants in `hunter.gd`, `match.gd`, `drop_launch.gd`, `drop_squad.gd` and `drop_feel.gd` are deleted. `hunter.gd` and `match.gd` shrink.
- New `scripts/match/drop_view.gd` (local player only: dive view, cloud sheet, wind streaks, haze) and `shaders/drop_view.gdshader`; `DropFeel` gains the canopy rule and the dive ribbon.
- `AirLimits` lets crouch through in the drop. `GliderSfx` snaps when the drop's canopy opens and pitches the wind 0.8 to 1.3 in the drop.
- Soft landings lose their two rings (DECISIONS: a ground ring means gameplay) and drop to 14 dust particles.
- Net.VERSION: no bump. The dive flag is already in the state flags; every client times its own canopy.
- Checks: `--drop-feel-check` and `--drop-launch-check` extended. No save change. No debt.
