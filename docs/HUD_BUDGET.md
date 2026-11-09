# HUD budget: what a new player sees

Owner decision 2026-11-08 ("UI is too much"): a new player sees health, abilities with keys, the objective
and the timer. Everything else appears when it first matters, or while Tab is held, and there are never
more than 5 HUD groups at once. `scripts/ui/hud_budget.gd` (`HudBudget`, one on `hud.budget`) holds the
rule; every group asks `hud.budget.on(id)` before it draws. `--hud-budget-check` plays a fresh profile
through a first expedition and fails on more than 5 groups (`MAX_GROUPS`).

## The groups

| Group | What | When it shows (new player) |
|---|---|---|
| `vitals` | portrait, health, armour, level | always (core) |
| `abilities` | the ability row with key caps | always (core) |
| `objective` | the minimap | always (core) |
| `timer` | the clock bar: time left, phase, raid condition | always (core) |
| `squad` | teammate cards | a teammate is downed, out or under half health |
| `belt` | utility belt 1 2 3 | you are under 70% health |
| `kin` | Boki card and C throw/recall | your Boki is off your shoulder or hurt |
| `weapon` | weapon card, ammo, gems and backpack count | you fired, reloaded or swung |
| `grip` | gloves Q V and the Merge box | under 70% health with a glove on |
| `gear` | the worn-gear slots | your gear changed |
| `stats` | squads left, kills, knocks, gems | one of them changed |
| `feed` | the kill feed | a feed line is up |
| `perks` | perk badges | a perk was picked up |
| `kit` | the "Your kit" card | only while Tab is held (it used to cover the first 14 s) |

A contextual group stays 10 s (`HOLD_S`) after its trigger last held. When more than one wants a slot, the
order is the table's order (urgent first), and the rest wait. Not groups, so not counted: the world marks
(plates, crosshair, pings, waypoints), the message lane (toasts, alerts, prompts) and the boss bar, which
are events. The tutorial, training and the duel room keep their own screens (the budget is off there).

## Timeline of a first expedition

`--hud-budget-check`: a fresh profile, a trio, 20 hunters, bots, the player cannot die, a 10 s sample.
"Before" (measured to 90 s, then held) is what the old HUD drew (it had no gating: every group with content, plus the kit card for 14 s);
"after" is the core 4 plus what the budget lets in. This run ended at 170 s when the player's squad was out
(runs vary; `--hud-budget-check` goes to 360 s when they survive).

| t (s) | Before | After: extra | Waiting for a slot |
|---|---|---|---|
| 0 | 11 | 4 (-) | - |
| 10 | 12 | 5 (gear) | stats, perks |
| 20 | 11 | 4 (-) | - |
| 30 | 12 | 5 (squad) | stats, feed, perks |
| 40 | 12 | 5 (squad) | feed |
| 50 | 12 | 5 (squad) | feed, perks |
| 60 | 12 | 5 (squad) | feed |
| 70 | 12 | 5 (squad) | feed |
| 80 | 12 | 5 (squad) | feed |
| 90 | 12 | 5 (stats) | feed |
| 100 | 12 | 5 (stats) | feed |
| 110 | 12 | 5 (belt) | grip, stats, feed |
| 120 | 12 | 5 (squad) | belt, grip, feed, perks |
| 130 | 12 | 5 (squad) | belt, grip, stats, feed |
| 140 | 12 | 5 (squad) | belt, grip, gear, stats, feed |
| 150 | 12 | 5 (squad) | belt, feed |
| 160 | 12 | 5 (squad) | belt, feed |
| 170 | 12 | 5 (squad) | belt, feed |

Before, the HUD held 11-12 groups from the first second. Worst offenders, all fixed: the "Your kit" card
(covered the right side for 14 s), the gloves/belt/gear rows (empty slots before you owned anything), the
kills/knocks/gems bar, the weapon card and the squad cards while nothing had happened, and the kill feed
(every line, including fights you were not in).

## Debt and alternatives
- The cap is one const. If testers find 5 too tight in a fight, raise `MAX_GROUPS` and re-run the check.
- Health-driven groups (belt, grip) are verified by a direct assertion, since the bot hardly ever drops.
- Other screens in the decision (hunter pick, farm, pause, results) are not part of this change.
