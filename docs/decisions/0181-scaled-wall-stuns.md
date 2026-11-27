# 0181: Wall stuns scale with the charge and the impact speed

- **Status:** accepted (kit-parity pass 11-27)
- **Date:** 2026-11-27
- **Area:** combat

## Problem
Every wall stun was one flat number: a plain knock's slam 0.9 s however hard it hit, the Heavy Shot 1.2 s and the Storm Rod 0.8 s at any charge. None of the three has a sourced length (docs/heroes/archer.md marks it [?]). The target feel uses 0.4-1.2 s, longer for a harder hit or a longer charge.

## Options
1. Keep flat numbers: there is no reason to charge longer or knock harder into a wall.
2. Scale each stun by what the player controls: the charge (Heavy Shot, Storm Rod) or the speed into the wall (a plain knock's slam).

## Decision
Option 2. Heavy Shot `pin.stun` [0.4, 1.2] and Storm Rod `coil.stun` [0.4, 1.0] lerp by the charge. The slam is `KnockWall.slam_stun`: 0.4 s at 8 m/s (where a slam starts) to 1.2 s at 16 m/s; a hit's own `wallstun` stays the floor.

Not changed: Grounded already exists (KitStatus "gnd": cords, plate badge, toast) on every catch the owner's data backs (Bola, Skycall, Dredge while reeling). The foe arriving off Deep Reach and Ostra's seed stay not Grounded: the data has no such rule (docs/heroes/dredge.md, ostra.md).

## Consequences
- No wire change, no save change. Monsters keep their flat 1.0 s. Crush, Burr and Tenzo's punch keep their own numbers.
- `--kit-cc-scale-check` asserts all three.
