# The garden (the farm at home)

## Pace: playable without extraction

DECISIONS 2026-11-09: the game must be playable without extraction. Before this, a Boki got XP only
from expeditions (`Game.apply_result`, plus the dojo's rest XP after a run), so a garden-only player
never reached a first form. Now the farm gives kin XP too: `content/rules/garden_xp.json`, applied by
`GardenXp.give` through `Game.gain_xp` (the same level table, forms and mutations as a run).

| Action | XP |
|---|---|
| Feed (favourite food) | 2 (5) |
| Pet, once per 20 s (favourite play) | 1 (2) |
| Fetch (favourite play) | 3 (6) |
| Training yard, per point scored | 1 |

Stat gains are unchanged. An expedition gives 40, +40 for a win, +10 a knock.

**Measured** with `--garden-pace-check` (a fixed play model on the real Care, Game and Evo code; the
assumptions are in the `pace` block of the rules file): time to the first form (level 4, 600 XP).

| Player | Minutes |
|---|---|
| Garden-only (feed, pet, fetch, drill; naps when worn out) | 229 |
| Also runs expeditions (12 min each, half won, 1 knock, 3 min of garden between) | 141 |
| Ratio | about 1.6 (limit 2.0, `pace.max_ratio`) |

With the first tuning (2x these XP values) the ratio was 1.32: garden XP per minute matched a run's,
so extraction stopped being the faster way. These values keep runs ahead without making the garden a
dead end. The check fails above 2.0x.

Default taken: "about 2x" is the limit. The alternative is a tighter limit (1.5x), which means
roughly 1.5x the XP above.

## Ghost laps on the Dash (no live netcode)

Every Dash lap at home is taped (`RaceGhost.Tape`: each runner's distance every 0.1 s). The fastest
lap on each course is kept in `Save.d["ghosts"]` (`RaceGhost.keep_best`); a course is the lap's
stretch layout, so the weekly "Two streams" loop has its own. A lap is about 0.5 KB of save (cm moved
per tick as base64 bytes; the longest kept, 120 s, is 1.7 KB). The visit snapshot carries the laps
(`Social.profile_doc`, cleaned by `RaceGhost.clean`). A visitor at the friend's race post runs their
partner against the faded ghost, the owner's name over it, cheering at the marks as in any Dash; a win
sends a `race` gift (`RaceGhost.beat_gift`) and the friend finds the winner pinned to their showcase
wall when they come home (`RaceGhost.take_gift`). Old saves and older snapshots have no key: no laps.
`--race-check` holds it: a replayed lap stays within 0.05 s of the real runner all the way round.
