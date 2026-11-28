# Which surfaces a wall stun counts

Parity first (briefs/DECISIONS.md 2026-11-07). One test, `KnockWall` (scripts/combat/knock_wall.gd), answers for every wall-stun source: Lace's Heavy Shot pin, Albert's Crush, Burr's cone, Tenzo's punch, the Storm Rod, and a plain knock's slam (Hunter, monsters, Blight). Proven by `--wall-stun-check` (48 checks).

## The rule
A wall is whatever stops a knocked body's walk and stands taller than a terrace step (0.85 m, the Hunter's step-up). Terrain cliffs, rocks, trees, placed barriers (Tenzo's rocks, the Rink Wall) and the train's engine stun. A tier step, a flat car deck, crates, pots, barrels, kegs and another Hunter do not. The Storm Rod alone also stuns on another Hunter.

## Sources
- Heartpiercer: "enemies that collide with terrain are Stunned" (sv/briefs/kits.md, Myth).
- Valiant Strength: "knocking an enemy into a wall Stuns them"; Quake Punch: "punched into a wall"; Spike Grenade: "knocked into a wall ... Stunned" (sv/briefs/kits.md, Oath, Tetra, Vex).
- Voltaic Spear: "a wall or another target = Stunned" (the only source row that names bodies; bulwark.md removed foe-into-foe for the others).
- Terraces of 0.8 m "are part of the ground, since they're walked up"; mantle ledges 1.5 m, walls 3 m (sv/briefs/LAYOUT_RULES.md): a step is ground, not a wall.
- Crates, pots, barrels, kegs: "soft ... solid circles you're pushed round, never stood on; any hit breaks them" (LAYOUT_RULES.md): not terrain. The source has no rows for them or for the train (ours), so they follow how they move a body: the engine blocks, a deck is walked on.
- Rocks and barriers: "a wall of three rocks" (Tetra Rockwave), "wall that pushes enemies" (Frozen Barricade): walls.

## What it was (before) and is (now): stun / damage / start frame
Frame counts from the first damage of the knock. Same for every source unless noted.

| Surface | Before | Now |
|---|---|---|
| Terrain cliff | all stun | all stun |
| Tier step | slam stunned (0.9 s, 10 damage); Heavy Shot, Crush, Burr, Tenzo, Rod did not | none |
| Tenzo rock, Rink Wall | only the slam; Heavy Shot, Crush, Rod, Tenzo's own probe missed | all stun |
| Crate, pot, barrel, keg | none | none |
| Train car | none | none (deck) |
| Train engine | slam only | all (probe) |
| Another Hunter | Storm Rod only | Storm Rod only |

Now, per source on a cliff, rock or Rink Wall: Heavy Shot 1.2 s, 178 damage, frame 8 (the arrow's flight); Crush 0.5 s, 13, frame 0; Burr 0.68 s, 16, frame 0; Tenzo 0.9 s, 34, frame 0; Rod 0.78 s, frame 0; slam 0.9 s, 15, frame 0. Monsters: cliff and rock stun, a step does not.

## Not built (ideas of ours)
A stun when a knocked body hits a sky-train car's side, or a crate that survives the hit. Both have no source row.

## What it looks like
At the moment of a wall stun the wall shows where the body hit: a short crack decal on the surface and a small dust puff, about 0.6 s, stone-coloured with the attacker's hero colour on the rim (scripts/match/wall_impact.gd). No ring on the ground (the old slam ring and burst are gone). `KnockWall.hit` (kits) and `KnockWall.slammed` (the body slam) raise `CombatBus.wall_stunned` with the contact point; a second source stunning the same body within 0.5 s adds nothing. Six decals at most (the oldest is reused). `--wall-stun-check` asserts one decal per wall stun at the wall face and none on a step, crate or Hunter; `--wall-stun-shots` takes the pictures.

## Knock formula: the source's and ours (ext/knock-resist-formula, 2026-11-28)

physics-parity-1127 row 49 (traversal-1126) against `Hunter.impulse` (scripts/match/hunter.gd), side by side:

| | Source (traversal-1126) | Ours |
|---|---|---|
| Push | impulse x KnockbackCoefficient(instigator) / max(KnockbackResist(target), 0.5) / mass 100 | push (m/s, the kit's number) / max(1 + knockback_resist, 0.5) / class mass (light 0.85, medium 1.0, heavy 1.35) |
| Resist | a divisor, default 1, floored at 0.5 (a weakened target takes at most 2x) | **was** push x (1 - resist): 0.5 halved, 0.75 left a quarter. **Now** the divisor above with our stat as the bonus over 1: 0.5 leaves 2/3, 0.75 leaves 4/7 |
| Instigator | KnockbackCoefficient scales every knock the attacker deals | none: the kit's push is the number (no attacker stat) |
| Mass | 100 for every character | the class mass: a heavy takes 74% of a medium's speed, a light 118% |
| Input | x a directional-input factor (the target's held direction scales the impulse) | the knock replaces the flight (`Displace.knock_speed`); no steer for `knock_t` 0.12-0.35 s, then WASD bends it by `knock_steer` 0.3-0.5 |
| Lift | part of the impulse | lift / mass, resist does not touch it |

The data's resist values: kin carry passives 0.5 (Goliathite, Basaltoad, Gravitank and 25 more `content/kin/*.json`), the
Thornwake merge 0.5, the Titan merge 0.75 (`KinParts.OWNER_STATS` caps: carry 0.5, merge 0.75). At 0.5 the subtract form
left 50% of the source's 67%: 25% short, over the 15% line, so the resist now divides. At 0.75: 25% vs 57%, 56% short.
`KinText.owner_stat` says "-33% knockback" for 0.5 (was "half knockback").

Every knock in KIT_PARITY "Knock distances" on a standing medium Hunter carrying a 0.5 resist, both ways. Speeds after
resist and mass; rest distances off the shared knock curve (`tools/move_feel_knock.gd` sweep rows run at these speeds, main
a90587dfa9). Resist 0 does not change. Under 2.5 m/s (`Displace.KNOCK_MIN`) a push is a nudge.

| Knock | Push, lift | Resist 0 (unchanged) | Subtract (was): x0.5 | Divide (now): /1.5 | Divide vs subtract |
|---|---|---|---|---|---|
| Vex Burr Charge wall cone | 11 | 11.00 m/s, 4.43 m | 5.50 m/s, 1.32 m | 7.33 m/s, 2.15 m | +63% further (2.15 vs 1.32 m) |
| Vex Longneedle recoil (on herself) | 6 | 6.00 m/s, 1.56 m | 3.00 m/s, 0.47 m | 4.00 m/s, 0.76 m | +62% further (0.76 vs 0.47 m) |
| Kael Finishing Slam | 6 | 6.00 m/s, 1.56 m | 3.00 m/s, 0.47 m | 4.00 m/s, 0.76 m | +62% further (0.76 vs 0.47 m) |
| Lace Heavy Shot tap | 8 | 8.00 m/s, 2.52 m | 4.00 m/s, 0.76 m | 5.33 m/s, 1.26 m | +66% further (1.26 vs 0.76 m) |
| Lace Heavy Shot full | 12 | 12.00 m/s, 5.12 m | 6.00 m/s, 1.56 m | 8.00 m/s, 2.52 m | +62% further (2.52 vs 1.56 m) |
| Cinder Spark Leap hit | 7 | 7.00 m/s, 2.01 m | 3.50 m/s, 0.62 m | 4.67 m/s, 1.00 m | +61% further (1.00 vs 0.62 m) |
| Tenzo Quake Punch | 10, lift 2 | 10.00 m/s, 3.77 m | 5.00 m/s, 1.37 m | 6.67 m/s, 2.03 m | +48% further (2.03 vs 1.37 m) |
| Tenzo rock hit | 5 | 5.00 m/s, 1.15 m | 2.50 m/s, 0.36 m | 3.33 m/s, 0.54 m | +50% further (0.54 vs 0.36 m) |
| Tenzo rock splash | 4 | 4.00 m/s, 0.76 m | 2.00 m/s, nudge | 2.67 m/s, 0.39 m | a knock now (0.39 m), was a nudge |
| Tenzo Rock Hop hit | 8, lift 2 | 8.00 m/s, 2.60 m | 4.00 m/s, 1.02 m | 5.33 m/s, 1.50 m | +47% further (1.50 vs 1.02 m) |
| Tenzo Rock Hop shove | 3.5 | 3.50 m/s, 0.62 m | 1.75 m/s, nudge | 2.33 m/s, nudge | nudge both ways |
| Neve Rink Wall touch | 5 | 5.00 m/s, 1.15 m | 2.50 m/s, 0.36 m | 3.33 m/s, 0.54 m | +50% further (0.54 vs 0.36 m) |
| Albert Crushing Blow tap | 5 | 5.00 m/s, 1.15 m | 2.50 m/s, 0.36 m | 3.33 m/s, 0.54 m | +50% further (0.54 vs 0.36 m) |
| Albert Crushing Blow full | 13 | 13.00 m/s, 5.86 m | 6.50 m/s, 1.74 m | 8.67 m/s, 2.91 m | +67% further (2.91 vs 1.74 m) |
| Albert perfect release | 18.2 | 18.20 m/s, 9.11 m | 9.10 m/s, 3.11 m | 12.13 m/s, 5.20 m | +67% further (5.20 vs 3.11 m) |
| Albert Shield Charge | 11, lift 2.5 | 11.00 m/s, 4.52 m | 5.50 m/s, 1.80 m | 7.33 m/s, 2.63 m | +46% further (2.63 vs 1.80 m) |
| Albert Whirl | 7 | 7.00 m/s, 2.01 m | 3.50 m/s, 0.62 m | 4.67 m/s, 1.00 m | +61% further (1.00 vs 0.62 m) |
| Albert Shield Slam | 12 | 12.00 m/s, 5.12 m | 6.00 m/s, 1.56 m | 8.00 m/s, 2.52 m | +62% further (2.52 vs 1.56 m) |
| Sparkle Storm Rod tap | 4.4 | 4.40 m/s, 0.92 m | 2.20 m/s, nudge | 2.93 m/s, 0.46 m | a knock now (0.46 m), was a nudge |
| Sparkle Storm Rod full | 6.6 | 6.60 m/s, 1.78 m | 3.30 m/s, 0.54 m | 4.40 m/s, 0.92 m | +70% further (0.92 vs 0.54 m) |

Two pushes that a 0.5 resist turned into nudges (Tenzo's rock splash 4, Sparkle's Storm Rod tap 4.4) are knocks again,
under 0.5 m. `--knock-chain-check` asserts the form through the real hit path: Albert, Kael (heavy) and Meeko (medium)
carrying a Goliathite each take Lace's full Heavy Shot (push 12) at 12 / 1.5 / mass (5.93 m/s heavy, 8.00 medium), the
heavies land together (1.53 m) and Meeko lands at 2.52 m.

Not changed: the class mass. The source's mass is 100 for everyone, so there Albert and Kael fly as far as Meeko; ours
sends a heavy 74% as fast (Heavy Shot full: 12 vs 8.9 m/s, 5.12 vs about 3.1 m at rest). The weight class is an owner
design (Data.CLASSES: health, speed, dashes, mass), so it stays; this is the gap left in row 49.
