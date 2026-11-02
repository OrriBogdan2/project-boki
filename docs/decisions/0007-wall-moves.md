# 0007: Wall kick, wall bounce, ledges from any airborne state, a springier abyss

- **Status:** accepted (owner request, movement pass)
- **Date:** 2026-11-02
- **Area:** movement

## Problem
The Cinder Steps plateau (4 terraces, 3.2m) was out of reach (jump + mantle ~2.85m). Hitting a wall at speed just stopped you. Ledges only caught you near a jump's apex, and a ledge lower than where you last stood never caught you at all, so gliding up to one near the top of the map failed. The abyss lift felt flat next to SUPERVIVE.

## Options
1. Raise the jump or the mantle reach: rejected, it changes every wall on every map.
2. Kick and bounce inside `hunter.gd`: rejected, it is a frozen god file.
3. Small per-hunter modules with one-line hooks (decided).

## Decision
- `WallMoves` (`scripts/match/wall_moves.gd`): one wall kick per airtime (into the wall: +0.9m on the jump you are on; away from it: the old push-off) and an airborne wall bounce (85% speed kept, head-on and slow hits don't bounce).
- `GlideLift` (`scripts/match/glide_lift.gd`): the abyss spring (once per lift, costs heat, capped), the low-gravity float at the top, and when a ledge counts as catchable.
- The ledge catch no longer needs a jump's apex, needs a tile sharing an edge with yours, and is blocked while stunned or rooted. Abyss and glide drag numbers are in `docs/MOVEMENT_FEEL.md`.

## Consequences
- Movement runs on the owning machine; nothing new on the wire.
- The light class's second wall kick is gone (one kick per airtime).
- `--mantle-check`'s steering-away window is 24 steps (a ledge now catches earlier). New check: `--wallmove-check`.
