# 0027: Hunters pass through Hunters

- **Status:** accepted
- **Date:** 2026-11-09
- **Area:** movement

## Problem
PARITY FIRST (DECISIONS 2026-11-07). `Match._separate` pushed every pair of bodies apart, so two Hunters
blocked and shoved each other and a dash into a foe pushed it aside. The source has no Hunter-to-Hunter
collision: Joule's Surge deals damage "to enemies passed through" [D], Meeko's Relay Step is tracked
through an ally twice in the footage [F], Kaiju Grasp reels a foe "to your feet" [F]. Every hero shares one
capsule (radius 0.43 m, height 1.76 m) and Mass 100 [D]; nothing in the data or footage shows Hunters
walking into monsters.

## Options
1. Drop Hunter-to-Hunter pairs from `_separate` with an `is Hunter` test. Two lines, nothing in data.
2. The same, but the push share for a Hunter pair is a number in `content/rules/hunter_move.json`
   (`physics.hunter_push`, 0 = pass through, 1 = solid), read through `HunterMove`, so the rule sits
   with the other source-derived movement numbers and the check can name it.
3. Turn off `_separate` for everything. Monsters and Boki have no source rule; the owner's Boki designs
   rely on body-blocking ("walks beside you, body-blocks a chase").

## Decision
Option 2. Hunters walk and dash through allies and foes. Monsters and Boki stay solid, mass-weighted as
before. A kit that stops on a body keeps saying so itself (Cinder's Soot Ram ends on the first foe [D]).

## Consequences
- `match.gd` +4 lines in `_separate`, `HunterMove.hunter_push`, one number and its doc in `hunter_move.json`.
- Net: no shape change. Remote Hunters are no longer nudged locally by a Hunter's body, which can only
  reduce prediction drift.
- `--hitbox-size-check` asserts two Hunters walking into each other cross undeflected, a dash through a
  foe ends past it with the foe unmoved, and a Hunter walking into a Boki is held off and pushes it.
- Table in docs/HITBOX_SIZE.md (Body contact).
- Alternative not taken: monsters pass-through too. No source either way; left for the owner.
