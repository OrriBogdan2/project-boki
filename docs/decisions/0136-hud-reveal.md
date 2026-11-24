# 0052: Staged HUD (HudReveal) and its save field

- **Status:** accepted (owner DECISIONS 2026-11-08 "UI is too much for a new player"; design review 11-10 fix 8)
- **Date:** 2026-11-11
- **Area:** HUD / save format

## Problem
A new player sees about 13 HUD groups at the drop; the rule is about 5. New widgets (XP bar, seat pips, summon
ring, coloured plate names) landed all at once.

## Options
1. A save version bump with a migration that marks everything seen. Collides with the other branches bumping Save.VERSION.
2. A new save field `hud_reveal` (seen first events) that fresh saves carry; an older save has no field and keeps the full HUD (the FarmBuilder pattern).

## Choice
Option 2. One staging table in `content/rules/hud_reveal.json` (group -> first match, or 0 = first event only).
`HudReveal.on(m, key)` gates each draw call; Tab (the scoreboard key) and Settings "Show full HUD" show all;
duel, training, tutorial and arena are never staged. The match number is `Save.d.matches + 1`.

## Affects
`hud_panels.gd` (top counters, feed, gear, squad, perks), `hud.gd` (+2: weather chip), `hud_plate.gd` (name tint),
`ways_out_hud.gd` (seat pips), `save.gd` (+1 field), `settings.gd`/`overlay.gd` (+1 toggle). No Net change.
