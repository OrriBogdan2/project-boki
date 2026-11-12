# 0024: Jump pads and updrafts open the glider by themselves

- **Status:** accepted
- **Date:** 2026-11-09
- **Area:** movement

## Problem
Parity pass on jump pads (briefs/DECISIONS.md: pad and updraft auto-glides are the one exception to "a held
Space never opens the glider"). Ours flew a map pad along a scripted arc to its landing: no gravity, no
steering, the glider only on a press, and the pocket Spring pad had its own ballistic launch in match.gd
with no glider at all. The playground kept a third pad in scripts/feel/jump_pad.gd. The source's data
(briefs/supervive-data/supervive_physics.md) names no pad launch and lists GlideUpdraftMinZVel among the
locked C++ defaults; the footage has one pad take (Ghost, ult clip f103) with no measurable arc.

## Options
1. Keep the scripted arc and open the glider at its midpoint. Cheap, but the arc is the thing that doesn't
   match: no gravity, no carried speed, no steering.
2. One `PadFlight` module: a ballistic throw under the source's gravity (14.7 m/s²), the glider opening by
   itself at the apex and keeping the launch's speed, steering as any glide. A map pad is aimed at its
   landing; a hands-off glide (or a bot) is carried onto the landing and folded over it, as a lair's escape
   updraft already does, so bots still cross and an idle player still arrives.
3. As 2, but let a hands-off flight drift. Players with their hands off and every bot would sail past the
   landing into the void beyond.

## Decision
Option 2. Launch speed 17 m/s up [est] (apex 9.8 m in 1.16 s on the source's gravity; the same height the
pocket pad and the playground pad already used, and the map arc's apex for a 55 m gap), raised to clear a
higher landing's lip by 2 m. An updraft entered while airborne opens the glider the same way and holds it
climbing at `updraft_vy` (9 m/s, the old inline constant, now under the source's name).

## Consequences
- `scripts/match/pad_flight.gd` (new); `hunter.gd` loses `pad_launch`, gains two wiring lines;
  `match.gd` loses the pocket pad's own launch; `scripts/feel/jump_pad.gd` and the playground's pad are
  deleted (the live pad never lived there; STATE_MACHINES M1 deletes the rest of scripts/feel/).
- Tunables `pad_vy`, `pad_clear`, `updraft_vy` in `content/rules/hunter_move.json`.
- `--pad-check` (new) flies every hunter off a pad: apex height and time, glider shut in the rise and open
  by itself at the apex, no steering in the rise and steering after, hands-off set down at the landing;
  plus the pocket pad and the updraft.
- Net.VERSION bump: no. The launch is velocity, which the snapshot carries; `auto_glide` was already local.
- The `pad` dictionary on Hunter now only holds scripted arcs (a ledge hop, a leap onto higher ground);
  its name stays until those arcs are next touched.
