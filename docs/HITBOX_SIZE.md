# Hitbox size (OWNER_REVIEW item 46)

Each hunter's hitbox radius is `Arch.hit_r(arch, class)`: the archetype's `body.hit_r` in `content/archetypes/<id>.json`, else the class's. The standard is the Medium class radius, 0.40 m. Hitboxes follow the Warden's final height chart (Nov 8, the `height` column of `--warden-model-check`), compressed into 0.85-1.15 x standard so small hunters are not much harder to hit: `hit_r = 0.40 x clamp(1 + 0.3 x (chart - 1), 0.85, 1.15)`. The height is the drawn height: `hit_h = 1.732 m x chart` (a medium hunter's head top 1.546 m x `Hunter.VIS_SCALE` 1.12). Shots hit from 0.45 m under the feet up to `hit_h + 0.9 m` (`Match.shot_band`; a hunter with no archetype keeps the old 1.5 m).

**Source:** the only published SUPERVIVE hero collision is the shared bot nav agent, radius 0.43 m, height 1.76 m (`briefs/supervive-data/supervive_physics.md`); no per-hero capsule is in the data. Our standard hunter is 0.40 m by 1.73 m, so the heights match and the radius is 7% under, kept as the owner's item 46 standard (set the Medium class `hit_r` to 0.43 to match it).

**Body collision is separate.** `hit_r` is the hurtbox (`Ent.r`: shots and abilities). Walls, rocks and body-vs-body pushing use `Ent.hull_r()`, the archetype's `body_r`, which keeps the values the hurtbox had before the chart pass.

Changing a hero's hurtbox is `body.hit_r` and `body.hit_h`; its collision is `body.body_r`. The creator's look sliders never touch it (the hitbox is never read from the look). The ground circle (`TeamRing`, team colour, built in `Models.hunter`) is drawn at exactly `hit_r`.

| Archetype | Warden | chart height (x medium) | `hit_r` (m) | `hit_h` (m) | `body_r` (m) | Before (`hit_r`, used for collision too) |
|---|---|---|---|---|---|---|
| bulwark | Mossy | 1.5 | 0.460 | 2.60 | 0.460 | 0.460 |
| dredge | Grimble | 1.48 | 0.458 | 2.56 | 0.452 | 0.452 |
| juggernaut | Kael | 1.31 | 0.437 | 2.27 | 0.428 | 0.428 |
| gunslinger | Vex | 1.09 | 0.411 | 1.89 | 0.416 | 0.416 |
| ostra | Motley | 1.18 | 0.422 | 2.04 | 0.412 | 0.412 |
| mage | Sparkle | 1.08 | 0.410 | 1.87 | 0.400 | 0.400 |
| archer | Lace | 1.07 | 0.408 | 1.85 | 0.392 | 0.392 |
| dolm | Tenzo | 1.09 | 0.411 | 1.89 | 0.388 | 0.388 |
| thief | Sable | 0.98 | 0.398 | 1.70 | 0.384 | 0.384 |
| rimewright | Neve | 0.96 | 0.395 | 1.66 | 0.380 | 0.380 |
| ashwick | Cinder | 1.16 | 0.419 | 2.01 | 0.376 | 0.376 |
| tender | Meeko | 0.6 | 0.352 | 1.04 | 0.340 | 0.340 |

Shots connect inside `hit_r + Match.HIT_SLACK (0.08) + the shot's radius`. `--hitbox-size-check` asserts the band, the drawn circle radius, and a shot just inside and outside the circle for the smallest and biggest. `--hurtbox-check` asserts, per Hunter, the chart formula for `hit_r` and `hit_h`, that `body_r` is its own, a shot 5 cm inside the radius hits and 5 cm outside misses, and the same at the top of the band. `--hurtbox-shots` draws the hurtbox over three Hunters.
