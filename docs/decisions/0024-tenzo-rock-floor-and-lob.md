# 0024: Tenzo's R rock floor and the Quakefall lob

- **Status:** proposed
- **Date:** 2026-11-08
- **Area:** combat / movement / networking

## Problem
Owner playtest 11-08. Item 21: Tenzo's R should raise rock ground under him on the press, the same frame, so it saves
him over the abyss. It must be ground for everyone (over_void, landing, mantles) and synced. Item 22: the held
Quakefall hop read as too fast and glitchy: no wind-up, an instant full-speed launch, and it shoved a body in its path.

## Options
1. Floor as a StoneStand rock (like the ridge's): already ground over the abyss for over_void, but it is a wall to foes
   (not walkable for everyone) and mantles read terrain tiles, not rocks.
2. Floor as terrain tiles through the existing `Verbs.add_bridge` / `HeroZones.bridge` (Rimewright's ice bridge):
   real ground for every system and already sent over Net; it needed a crumble warning instead of the flicker.
3. Hop driven along a fixed curve (kinematic): exact, but it would bypass the glider hand-off and the move-key nudge.

## Decision
Option 2 for the floor, with an optional `warn` (cracks and a smooth shake) and `rise` on bridges. The hop stays a
physics arc, adds a planted wind-up, eases its ground speed (its average is unchanged, so it lands on the circle),
falls under extra gravity, and a swept circle test each step stops it at the first foe body.

## Consequences
`verbs.gd`, `hero_zones.gd`, `breah_spine.gd`, `breah_slam.gd`, `dolm_kit.gd`, `kmoves_stone.gd`; feel numbers in
`content/rules/tuning.json` (`tenzo`). Net.VERSION 0.24.4 (the bridge event carries warn and rise; older events still
read). No save change. Check: `--tenzo-feel-check`.
