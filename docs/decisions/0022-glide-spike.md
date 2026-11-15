# 0022: Which hits spike a glider

- **Status:** accepted
- **Date:** 2026-11-09
- **Area:** movement

## Problem
Ours spiked a glider only when a hit ran its heat dry. Dunks (Primal Slam, Breah's dunk, `spike` bursts)
pushed a glider down through `Displace.spike` but never spiked it: there was no landing stun, and the
SpikeSlamForce* data names were unused. The spike numbers were inline in `hunter.gd`.

## Sources (owner > data > wiki > footage)
- Wiki Glossary "Spike": you are spiked when the glider is overheated and any player hits you, or when a
  player's hit fills the heat; "some attacks deal enough damage to bring you instantly to full heat".
- Wiki "Dunk": abilities that stun you and drive you downward. Over the abyss they work like a spike.
- Wiki Gliding: a spike over the ground does "additional damage" and a **0.7 s** stun. Monsters can't
  spike you. Spiking someone cools your own glider.
- Data (undecoded values): SpikeSlamForceZ, SpikeSlamForceStrengthThreshold, SpikeSlamForceAbsoluteThreshold.
  A downward slam force above a threshold spikes you.
- No source says a stun, knock-up or knockback spikes a glider by itself. Footage (5 fps) shows none.

## Options
1. Spike on any hard CC (stun, knock-up, big knockback). This has no source support and would make every
   stun a glider kill over the abyss.
2. Heat spikes as before, plus a **slam** spike: a hit that drives the glider down at `slam_min` or more
   spikes it at any heat and leaves the glider overheated. Other CC only heats the glider through its damage.

## Decision
Option 2, in `scripts/match/glide_spike.gd` (GlideSpike), with the numbers in `content/rules/hunter_move.json`
"glide_spike". A spike folds the glider, stuns you 0.35 s in the air and blocks the glider for 2.5 s. A heat
spike plunges at 6 m/s or faster; a slam keeps its own speed. Landing gives a 0.7 s stun [wiki] and 8 damage
[est]. Glider heat counts: a hit's damage heats the glider (unchanged), and a gliding spiker's own glider
cools by 0.5. The threshold and fall values are our estimates until the data values are decoded.

## Consequences
- `Displace.spike(e, vy, by)`: the owner's game runs `GlideSpike.slam` (local and over Net "vy"); the
  caster's game credits the spiker. `hunter.gd` loses `_shot_down` and the SPIKE_* consts.
- Net.VERSION: no bump. The "vy" message keeps its shape. The owner's game decides the spike, and the
  snapshot already carries `gliding` and position.
- Kin `spike` (kin_exec.gd) still sets vel.y directly (reserved file, DEBT Displace line), so a Boki dunk
  does not spike a glider yet.
- Checks: `--glider-heat-check` hits a gliding dummy with each kind; `--displace-net-check` spikes a gliding
  player on their own game.
- Alternative kept open: option 1, if the owner wants hard CC to spike.
