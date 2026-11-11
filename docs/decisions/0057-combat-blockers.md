# 0057: One rule for blockers vs crossers

- **Status:** accepted
- **Date:** 2026-11-10
- **Area:** combat

## Problem
Each kit decided on its own what stops it: the Abyssal Hand stopped at Tenzo's rocks (terrain in the source), the Longneedle and Faultline went through placed walls, and Cinder's pull and Grimble's grab dragged a Kael in his guard or an Albert behind his raised shield.

## Options
1. Fix each kit where it differs: small diffs, but the next kit drifts again.
2. One table (crosser class x blocker kind) in data, read by the few places that meet walls: shots, bodies, beams/lanes, pulls.

## Decision
Option 2: `content/rules/blockers.json` + `scripts/combat/blockers.gd`. Classes: solid (every shot, chain, pull, knock, Faultline), body (dashes), pierce (passes terrain and Tenzo's rocks, stopped by placed walls and body blockers: Hand, Longneedle), phase (Spirit Walk: through walls and objects), lob (Trade). Kinds: shield (any carried wall), rock, ice, wall, guard.

## Affects
`Verbs.shot_check` and `Verbs.wall_blocks` read the class; `World.occupy` passes it (no growth); Longneedle and Faultline cut at `Blockers.cut`; pulls ask `Blockers.body_stops` (`ArchKit.blocks_from`). No Net or save change. Check: `--blocker-check`; table in docs/ABILITIES.md.
