# 0050: Hard Landing

- **Status:** accepted
- **Date:** 2026-11-11
- **Area:** movement / combat / networking

## Problem
Landing on a camp is not a play: every opening drop ends in the same soft touchdown, so dropping onto monsters costs nothing and gains nothing. The spec (EARLY_CAMPS_DROP 3.3, 3.4; owner call 2: monsters only) wants a risky landing that starts the camp fight.

## Options
1. A new stagger state on `Mob` and an area hit of its own. A second status and a second damage path for one move.
2. Reuse the stun status through `Ent.hurt` (the normal hit path, already forwarded to a body's owner on the `"hit"` topic) and show the landing with the effects that exist. Mob's own `_stagger` is the boss and elite break (bonus damage, its own meter), which is not this.

## Decision
Option 2. On the opening drop only, your own dive key held over ground keeps the canopy shut below 10 m (`DropFeel.holds_shut`) and the dive, which has no flare, lands at dive speed. `HardLanding.land` then stuns (1.5 s) and hurts (30) every camp and Blight monster within 6 m, never a lair boss, a Hunter or a Boki; the kill credit is the lander's, so it can be a camp's last kill. The lander is slowed to half speed and gated from attacks and abilities for 0.4 s (the `land_t` timer, the slow status, the drop's input gate). All numbers are the `hard_landing` block of `content/rules/drop.json`. Letting go above 10 m opens the canopy as before. In-match glider dives are untouched.

## Consequences
- New `scripts/match/hard_landing.gd` and `audio/hard_landing.wav` (`tools/gen_sfx_glider.py`, heard to 60 m). `hunter.gd` and `match.gd` get wiring lines only.
- The show reuses `Fx.ring` (at exactly the effect radius, team colour), `Fx.dust`, the breakables' debris pool and the cracked scorch decal; no light. Local player only: `CamRig.dip` (new, 0.5 m, back in 0.22 s) and a 60 ms hit-stop; no shake (item 50).
- `Match.note_sound` takes a reach, so a rival's Hard Landing pings the minimap from 60 m. As with gunfire, a Hunter you can see within 20 m draws no ping.
- A follower in formation never lands hard (they do what the leader's canopy does). Bots hold the dive to the ground half the time when `Camps.nearest_live` finds a camp within 8 m of their spot (`DropSquad.bot_dive`).
- Net.VERSION 0.24.5: one new `"ev"` event, `"hland"` (lander id, position), draws the ring and plays the boom on the other clients. The damage and stun ride the existing `"hit"` topic.
- Checks: `--drop-feel-check` extended (part 5). No save change. No debt.
