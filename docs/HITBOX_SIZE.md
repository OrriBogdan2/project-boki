# Hitbox size (OWNER_REVIEW item 46)

Each hunter's hitbox radius is `Arch.hit_r(arch, class)`: the archetype's `body.hit_r` in `content/archetypes/<id>.json`, else the class's. The standard is the Medium class radius, 0.40 m. Hitboxes follow the Warden's visual size, compressed into 0.85-1.15 x standard so small hunters are not much harder to hit. Size and build both count: broad Wardens sit higher than their height alone, thin ones lower. Source of the multipliers (revised by the parity pass, docs/ARCHETYPES.md "Body and hitbox parity"): the concept art pass, `docs/art/concepts/README.md` (ext/concepts), "Heights and recommended hitbox size".

Changing a hero's hit radius is one line (`body.hit_r`). The creator's look sliders never touch it (the hitbox is never read from the look). The ground circle (`TeamRing`, team colour, built in `Models.hunter`) is drawn at exactly `hit_r`.

| Archetype | Warden | x standard | `hit_r` (m) | Why |
|---|---|---|---|---|
| bulwark | Breaker | 1.25 | 0.500 | tallest and widest: the heavy class's 0.50 m (DECISIONS, owner Nov 4; past the 1.15 cap) |
| dredge | Grimble | 1.13 | 0.452 | hulking |
| juggernaut | Kael | 1.11 | 0.445 | broad |
| gunslinger | Vex | 1.00 | 0.400 | the source's medium |
| ostra | Motley | 1.03 | 0.412 | tall and thin; hitbox stays at ground level (item 18) |
| mage | Ryzz | 1.00 | 0.400 | average |
| archer | Lisette | 0.98 | 0.392 | average, slim |
| dolm | Tarek (Breah's base) | 1.03 | 0.412 | short and blocky in the source |
| thief | Sable | 0.96 | 0.384 | lean |
| rimewright | Claire | 0.91 | 0.362 | tall but half a medium's breadth |
| ashwick | Cinder | 0.94 | 0.376 | low and hunched |
| tender | Pip | 0.85 | 0.340 | smallest (at the band's floor: item 108 shrank her model, not this) |

Shots connect inside `hit_r + Match.HIT_SLACK (0.08) + the shot's radius`. `--hitbox-size-check` asserts the band, the drawn circle radius, and a shot just inside and outside the circle for the smallest and biggest.
