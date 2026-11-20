# 0100: Camps own the early game

- **Status:** accepted
- **Date:** 2026-11-17 (port of ext/early-camps-bots-a3, owner decision 2026-11-10)
- **Area:** match flow

## Problem
A cleared camp paid nothing of its own: every monster rolled its own loot, and the comeback lived in
`Rolling`, so it only existed in rolling sessions. The early game felt random.

## Options
1. Pay a camp's whole reward once, on its last kill. Chosen: one bundle, where the last monster fell.
2. Keep per-monster loot on camp monsters. Rejected: loot is spread over the camp and a steal costs nothing.

## Decision
- `Camps` (`scripts/match/camps.gd`, numbers in `content/rules/camps.json`) replaces `Match._spawn_mobs` and
  the comeback `Rolling` owned. Each camp has a state (LIVE, CLEARED, RETURNING, SPENT) and a size from its
  spot's layout kind (light small, normal camp, heavy great), one size up in the hot zone.
- The last kill drops the camp's one bundle (armor, maybe a perk orb of source "camp", maybe a gear piece) and
  toasts the killer's squad. The camp's monsters pay XP on their own kills through `KillXp` (unchanged) and
  roll no loot or perk orb of their own.
- A cleared camp comes back once, one size up, 150 s later when no Hunter is within 30 m and the Blight is not
  due within 60 s, never after 7:00 and never past 85 camp monsters alive.
- Net: the host's new `"campclr"` event carries the toast to the clearing squad's machine (Net.VERSION 0.24.19).

## Not ported from the old branch
The 110 m drop with a held dive (main's drop is the squad rocket now), bot squads that pick camps
(`BotCamps`), the 28-camp layout on the 2x map, the per-Hunter XP readout (`XpRules`) and the Camp Chief
spots. They sit on `ext/early-camps-bots-a3` for later ports.

## Consequences
`--camps-check` asserts spawn, sizes, the bundle, a steal, the comeback and the hot-zone size.
`Rolling.after_setup` calls `Camps.picked_over`. `Camps.safe_for` is the one place the Blight zone redesign
replaces.
