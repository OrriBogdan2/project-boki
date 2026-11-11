# Which surfaces a wall stun counts

Parity first (briefs/DECISIONS.md 2026-11-07). One test, `KnockWall` (scripts/combat/knock_wall.gd), answers for every wall-stun source: Lace's Heavy Shot pin, Albert's Crush, Burr's cone, Tenzo's punch, the Storm Rod, and a plain knock's slam (Hunter, monsters, Blight). Proven by `--wall-stun-check` (48 checks).

## The rule
A wall is whatever stops a knocked body's walk and stands taller than a terrace step (0.85 m, the Hunter's step-up). Terrain cliffs, rocks, trees, placed barriers (Tenzo's rocks, the Rink Wall) and the train's engine stun. A tier step, a flat car deck, crates, pots, barrels, kegs and another Hunter do not. The Storm Rod alone also stuns on another Hunter.

## Sources
- Heartpiercer: "enemies that collide with terrain are Stunned" (supervive_kits.md, Myth).
- Valiant Strength: "knocking an enemy into a wall Stuns them"; Quake Punch: "punched into a wall"; Spike Grenade: "knocked into a wall ... Stunned" (supervive_kits.md, Oath, Tetra, Vex).
- Voltaic Spear: "a wall or another target = Stunned" (the only source row that names bodies; bulwark.md removed foe-into-foe for the others).
- Terraces of 0.8 m "are part of the ground, since they're walked up"; mantle ledges 1.5 m, walls 3 m (briefs/supervive-data/LAYOUT_RULES.md): a step is ground, not a wall.
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
