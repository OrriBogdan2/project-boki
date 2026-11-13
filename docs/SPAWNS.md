# Spawns: where, when, and what you see first

Core series principle 1 (DECISIONS 2026-11-11): no random enemy spawns. Every enemy, camp and boss
spawns at a fixed, learnable place on a predictable timer, telegraphed before it appears (a minimap
or world marker plus a countdown). This page lists every spawn path in `scripts/match/` on main
(audit of 2026-11-12, `ext/combat-spawn-audit`), what is random about it, and what the player sees
before it appears. `--spawn-clock-check` asserts the rows marked **fixed**.

Monster camps (first spawn `match.gd _spawn_mobs`, comebacks `rolling.gd _camp_respawns`) are
covered by `ext/predictable-camps-1111` (docs/CAMPS.md there) and are not repeated here.

| Spawner | File:line | Random (place / time / type) | Seen before it appears | Verdict |
|---|---|---|---|---|
| Glimmerkin (treasure kin) | `timed_spawns.gd:18` | none: a seeded outer-island wild spot / `at` 0.5 of the session / fixed | map ping at the spot + feed and toast countdown 30 s and 10 s before, ping and announce on arrival | **fixed** (was a random tile on a random outer island, called out only on arrival) |
| The Watcher at the Heart | `timed_spawns.gd:18` | none: the Heart / `at` 0.4 / fixed | ping at the Heart + countdown 30 s and 10 s before, then "The Watcher wakes" | **fixed** (was on time, no warning) |
| Uplink monster waves | `exits.gd:377`, posts `exits.gd:430` | place: none, six fixed posts per outpost / time: every 12 s while charging / type: cycles the biome list by wave and post | the posts glow on the ground (`fx.ring`) 2.5 s before each wave | **fixed** (was a random angle 7-13 m out, random type, burst on arrival) |
| Lair guards on a dial miss, rune or ward | `lairs.gd:478` | place: none, posts fanned away from the lair / time: your miss / type: cycles the pool | the miss chime, map ping and feed line (the guards are its answer) | **fixed** (was a random angle and type) |
| Boss lairs (which are live) | `spawn_plan.gd:170`, `lairs.gd:209` | which lairs: seeded pick of fixed lairs | the live lairs are shown on the full map from the start; the boss sleeps until you step in | ok |
| Lair gate guards | `lairs.gd:209` | none: a fixed line at the gate | standing there from the start | ok |
| Boss egg sacs (brood) | `boss.gd:607` | type: random of 2-4 | the egg and a ground telegraph circle for 2+ s | ok (a boss attack; type is DEBT) |
| Boss summon (brood) | `boss.gd:685` | none: fixed angles round the boss | the attack wind-up | ok |
| Blight Wardens | `blight_dir.gd:106`, `:126` | hand maps: seeded subset of authored posts; generated maps: random tiles / at the start / fixed | nothing until seen (hidden out of sight) | DEBT |
| Blight Skitter burrows | `blight_dir.gd:304`, `:350` | place: random 13-20 m off, out of sight / time: noise heat / pack size by strength | a dust puff on arrival, sound cues after | DEBT (core design) |
| Skitters from a Warden's shriek | `blight_dir.gd:231` | place: a ring round the Warden, jittered | the Warden's light and shriek (toast "the Blight is coming") | ok (answers your action) |
| Shrublings (key carriers) | `key_run.gd:138` | place: seeded pick of grass patches / at the start | nothing until found | ok (not a threat; they flee) |
| Wild Boki | `match.gd:1533` | which spots: seeded subset of fixed wild spots / at the start | standing there from the start | ok (not enemies) |
| Rare Boki | `spawn_plan.gd:214` | which spots: seeded pick of fixed candidates | a "?" at every candidate on the full map | ok (not enemies) |
| Dazed Boki dropped on a death | `match.gd:1983` | where the hunter fell | the knock | ok |
| Tutorial camps | `tutorial_camps.gd:71` | place: a random angle round the player | the tutorial step names the fight first | DEBT (low) |
| Training dummies | `match.gd:4538` | place: random ground on your island | none | exempt (training mode only) |
| Arena and duel dummies and bots | `arena.gd:88`, `:338`, `duel.gd:75` | fixed spots | standing there | exempt (practice modes) |
| Legendary Boki | not on main (`ext/legendary-spawns`) | one roll a match (20%), a remote rare point, 90 s in | none | DEBT when it merges |

How the fixed rows stay fixed: the place comes from the map (wild spots, outposts, lair geometry)
and the match seed, never from `Match.rng`, so every peer works out the same spot and no Net message
is needed for the warning; timers live in `content/rules/timed_spawns.json` (Glimmerkin, Watcher) and
named constants (`Exits.WAVE_EVERY`, `WAVE_WARN`, `WAVE_POSTS`; `Lairs.GUARD_R`, `GUARD_FAN`).
