# 0018: Box revive and loud revive beacons

- **Status:** accepted (the repeat-revive curve: superseded by 0022)
- **Date:** 2026-11-05
- **Area:** match flow / networking / UI

## Problem
Owner items 101 and 101b: you can't tell a teammate's deathbox from a rival's, beacons don't show on
the map, and the revive rules should follow the source: a box revive is a ~7.5 s exposed channel
(extra damage taken like drinking a tonic, moving or a hit cancels it), and a beacon brings the whole
dead squad back, loudly, with every player told where it is going off. Nobody carries a body anywhere.

## Options
1. A new revive system beside Life. Duplicates the deathbox, soul window and beacon code.
2. Extend what exists: Life keeps the deathboxes; the box channel moves out of `Match._update_interact`
   into `BoxRevive` (reusing `Hunter.CONSUME_VULN` and the tonic's spill path); the beacon code moves
   out of Life into `Beacons`, which adds the alarm; one HUD helper (`ReviveHud`) draws the boxes,
   beacons, rings and the alarm on the world, the minimap and the full map.

## Decision
Option 2. Timings live in `content/rules/revive.json` (box channel, beacon channel, how far the beacon is heard). The beacon alarm is
one match-wide state per beacon, so every player's HUD reads the same thing; online it travels as a
new `"bcn"` event on the existing `"ev"` topic (lit / out / used).

## Consequences
- `life.gd` loses its beacon code; `match.gd`, `hud.gd`, `hunter.gd`, `full_map.gd` get wiring only.
- Net.VERSION bumps (new `"bcn"` event). No save change.
- `--box-revive-check` (tools/box_revive_check.gd) and `--box-revive-shots` (tools/box_revive_shots.gd) added; the
  box-revive part of main.gd's inline `--life-check` moves into the new check.
- Known limit kept: a box or beacon revive brings back only Hunters the reviving game owns (as before).
