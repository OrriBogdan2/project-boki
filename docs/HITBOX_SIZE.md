# Hitbox size (OWNER_REVIEW item 46)

Each hunter's hitbox radius is `Arch.hit_r(arch, class)`: the archetype's `body.hit_r` in `content/archetypes/<id>.json`, else the class's. The standard is the Medium class radius, 0.40 m. Hitboxes follow the Warden's visual size, compressed into 0.85-1.15 x standard so small hunters are not much harder to hit. Size and build both count: broad Wardens sit higher than their height alone, thin ones lower. Source of the multipliers: the concept art pass, `docs/art/concepts/README.md` (ext/concepts), "Heights and recommended hitbox size".

Changing a hero's hit radius is one line (`body.hit_r`). The creator's look sliders never touch it (the hitbox is never read from the look). The ground circle (`TeamRing`, team colour, built in `Models.hunter`) is drawn at exactly `hit_r`.

| Archetype | Warden | x standard | `hit_r` (m) | Why |
|---|---|---|---|---|
| bulwark | Mossy | 1.15 | 0.460 | tallest and widest (band cap; the hull itself is 0.95 m) |
| dredge | Grimble | 1.13 | 0.452 | hulking |
| juggernaut | Kael | 1.07 | 0.428 | broad |
| gunslinger | Vex | 1.04 | 0.416 | broad |
| ostra | Motley | 1.03 | 0.412 | tall and thin; hitbox stays at ground level (item 18) |
| mage | Sparkle | 1.00 | 0.400 | average |
| archer | Lace | 0.98 | 0.392 | average, slim |
| dolm | Tenzo (Breah's base) | 0.97 | 0.388 | lean |
| thief | Sable | 0.96 | 0.384 | lean |
| rimewright | Neve | 0.95 | 0.380 | slight |
| ashwick | Cinder | 0.94 | 0.376 | low and hunched |
| tender | Meeko | 0.85 | 0.340 | smallest (at the band's floor: item 108 shrank her model, not this) |

Shots connect inside `hit_r + Match.HIT_SLACK (0.08) + the shot's radius`. `--hitbox-size-check` asserts the band, the drawn circle radius, and a shot just inside and outside the circle for the smallest and biggest.

## Body contact (ext/parity-body-collision)

Bodies are the same circles as the hitboxes. `Match._separate` pushes overlapping bodies apart once a step, mass-weighted (`Ent.mass()`: Hunters 1.0, Boki 0.8 x their giant scale, monsters 1 / 3 brute / 6 warden / 50 sentinel), never off an edge. The one pair that doesn't push is Hunter against Hunter: `hunter_move.json physics.hunter_push` is 0, so Hunters walk and dash through allies and foes alike.

| Pair | Ours | Source [D data, F footage] |
|---|---|---|
| Hunter walking into a Hunter | passes through, no shove | no Hunter-to-Hunter collision: Joule's Surge "153 dmg to enemies passed through" [D]; Meeko's Relay Step tracked through an ally at 735.9 s and 745.1 s [F]; Kaiju Grasp reels the foe "to your feet" [F] |
| A dash into a foe | passes through; the foe stays put | as above. A kit that stops on a body says so itself: Cinder's Soot Ram ends on the first foe [D], Kael's Lunge shoves |
| Hunter walking into a Boki | held off its body, pushes it along (mass-weighted) | ours (no source): the owner's Boki designs body-block ("walks beside you, body-blocks a chase") |
| Hunter walking into a monster | held off, pushes it; a sentinel barely moves | no source found in the data or footage; kept |
| Source body | hit_r 0.34-0.46 (table above) | one capsule for every hero, radius 0.43 m, height 1.76 m, Mass 100 [D]; ours keeps the per-Warden band and 1.0 mass |

`--hitbox-size-check` asserts the first three rows: two Hunters walking at each other cross with no sideways shove, a dash through a foe ends past it with the foe unmoved, and a Hunter walking into a dazed Boki never enters its circle and pushes it along.
