# 0016: Displacing another game's body (Displace)

- **Status:** accepted
- **Date:** 2026-11-03
- **Area:** networking / combat

## Problem
Kit audit item 1: abilities that move someone else's body skipped `remote` bodies (Cinder's cloak pull, Grimble's reel) or moved only this game's copy, which the owner's next snapshot puts back (Bjorn's push, Vireo's drag, Neve's wall carry, Tenzo's and Grimble's spikes, the glove pull/spike/swap). Online they never moved another player. Hits already go to the body's owner (`Match.net_send_hit`), but only as damage plus one impulse.

## Options
1. A per-kit net event for each ability: twelve paths that drift apart.
2. One module, `scripts/combat/displace.gd` (`Match.displace`): teleport, knock, spike and tows (step, haul, glide, push, slide). A body this game owns moves here; for a remote one the same call goes out as `["disp", ...]` and its owner's game runs the same code on its own body.

## Decision
Option 2. Kits keep their rules (who, when, how far) and hand the motion to Displace. A tow on a remote body keeps a mirror record on the caster's game that doesn't move anything (the copy follows snapshots) and ends when the owner's game sends `"end"` (arrived, walled, time), so a kit (Grimble's HAULED) reacts the same way to a bot and a player. Only the owner applies a move, as with hits; tow length and speed from Net are clamped (`MAX_T`, `MAX_SPD`). `Verbs.yank` on a remote body is run by its owner (`"yank"`), which also covers the Boki grammar's hooks.

## Consequences
- Sync shape changed: Net.VERSION needs a bump (main picks it). `["zone", "tp"]` is gone (it became `["disp", "tp"]`).
- Reserved files still move remote bodies on this game only: `kin_exec.gd` (pull impulse, spike, swap) and `merge_augment.gd` (shove); see docs/DEBT.md.
- A hit on a remote body now also carries `Displace.HIT_EXTRAS` (wall stun, steer, heavy, dr, burn time, slow strength, Blight) as a 14th field, so a knock lands the same on its owner's game. A tow's `unroll` ends the dash the body was in on the owner's game (Bjorn's push).
- World hazards (BiomeRun) run on every game: each hurts, pulls and slows only the bodies it owns (fields with `"own"`), so a player online is hit once.
- Check `--displace-net-check` (two games over the relay); the hero combo checks cover the bot side.
