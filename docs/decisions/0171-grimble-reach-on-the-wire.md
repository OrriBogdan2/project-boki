# 0171: Grimble's reach on the wire

- **Status:** accepted
- **Date:** 2026-11-20
- **Area:** networking

## Problem
Grimble's Deep Reach is his own arm (WardenReach), laid by his kit from the hook's state, which only the caster's game
runs. Another player saw a plain cosmetic shot ball (the "s" event) and his arm never left his side (docs/DEBT.md).

## Options
1. The hook's shot id plus the grabbed body on the "s" event: the copy flies smoothly, but "s" has no caster or id
   today and a remote kit does not tick, so it needs a new link from a cosmetic shot to a hunter.
2. The reach on the hunter row (HunterNet's tagged tail): [] home, [nid] the body the reel holds, or the tip in flight.
   The other game lays the arm on the held body's smoothed copy, or chases the last tip at 1.5x the hook's speed
   (carrying it on along the hook's velocity overshot a caught body by 0.76 m in the check: the next row says "held").

## Decision
Option 2: one small field, no new event, and the reel (most of the reach's time) rides a body every game already
smooths. The hook is a "drawn" shot: no ball on any game, and no "s" copy.

## Consequences
Net.VERSION 0.24.20. HunterNet tail 5 -> 7 fields; DredgeKit.net_reach / net_reach_in, its sound_tick lays the
remote arm; spawn_shot's "drawn" flag (KinExec cx "drawn"). The "s" kind 2 (pierce_terrain: Motley's orb) stays; only
Grimble's hook, which the kit marks pierce_terrain after the send, never used it. Check: --remote-anim-check's Deep Reach rows. Film: --reach-net-film (GPU).
Not mirrored: the arm's silhouette through rock and its sludge drips (caster's game only).
