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

## Measured hit shapes (`--hit-shape-check`)

`godot --headless --path . -- --hit-shape-check` (tools/hit_shape_check.gd, about 35 s) stands each hunter on flat ground facing +X beside a grid of 70 training dummies (0.5 m apart, standard body radius 0.4 m + 0.08 m slack), fires each damaging input once aimed straight down +X (cursor 20 m out) and records which dummies lost health. Reach, width and arc below are recovered from that set: the dummy centre is corrected by its hit circle and half a grid cell, so every number is good to about +-0.5 m (and +-10 degrees of arc).

**Source column.** `briefs/supervive-data/supervive_kits.md` is read off in-game tooltips and carries no hit sizes at all (no uu values for any reach, width, radius or arc); it only says shapes in words: Heartpiercer and the Arcane Railgun are long beams or shots, Rain of Arrows is "a hail of arrows in a cone", Brall's slam is "in front" with edge hits doing more, Tetra's Rockwave is "a wall of three rocks in front of you". There is no 100 uu = 1 m number to put beside our content value for any row, so the comparison here is measured against our content JSON (`content/archetypes/<id>.json`, `content/weapons/*.json`). Where the source names a shape, it is quoted under the table.

**How to read a row.** `hit` = dummies damaged (out of 70). `reach` = farthest edge of the damage along the aim line. `width` = the widest lane across it. `arc` = the angle the damage spreads over, seen from the hero. `content` = the JSON number of the same kind (`range`/`reach`/`len`/`dist`, `width`, `deg`/`arc`), if there is one. A dash `–` is zero or nothing to compare. **FLAG** = the content number is more than 10% off the measurement; `~` = the gap is within the 0.5 m grid, so it is noise rather than a finding.

**Limits (read before trusting a row).**
- The grid covers x = 1.0 to 7.5 m and z = 0 to 2.0 m on one side (shapes aimed down +X are assumed mirror-symmetric). A row whose hits touch the grid edge is marked `+r` (reach) or `+w` (width) in the `how` column and is not flagged: the real shape is at least that big.
- A bullet stops at the first dummy it hits. When 1 or 2 dummies were hurt, the input is run again on an empty lane and the shot's own flight range and radius are recorded (`how` = `shot`; width is the shot's diameter, arc 0).
- Inputs that need a second press (the Archer's R shots, a recast) were pressed once, so they may read zero. Inputs that hurt nobody (supports, summons, shields) read zero too.
- The match steps at 20 Hz and every input is given about 0.5 to 1.5 s, so a delayed hit can fall outside the window.
- Melee swings are measured like everything else; the strike may stop at the first foe it hits (see follow-ups).


### bulwark

| Input | hit | how | reach m | width m | arc deg | content reach / width / arc | FLAG |
|---|---|---|---|---|---|---|---|
| LMB tap | 32 | grid+r | 7.3 | 2.5 | 31 | 3.0 / – / 120 | **arc -75%** |
| LMB full hold | 4 | grid | 2.9 | 1.5 | 37 | 3.0 / – / 120 | **arc -69%** |
| RMB | 0 | grid | – | – | – | – / – / – |  |
| RMB hold | 0 | grid | – | – | – | – / – / – |  |
| E | 0 | grid | – | – | – | – / – / – |  |
| R (hero ult) | 62 | grid+wr | 7.5 | 3.5 | 40 | – / 4.5 / – |  |
| Dash | 8 | grid | 2.3 | 2.5 | 113 | – / – / – |  |

### dredge

| Input | hit | how | reach m | width m | arc deg | content reach / width / arc | FLAG |
|---|---|---|---|---|---|---|---|
| LMB tap | 1 | shot | 16.7 | 0.3 | – | 7.8 / – / – | **reach +113%** |
| RMB | 1 | shot | 11.5 | 0.5 | – | 11.5 / – / – |  |
| E | 12 | grid+w | 2.6 | 3.5 | 90 | – / – / 110 |  |
| R (hero ult) | 1 | shot | 5.0 | 0.9 | – | 5.9 / – / – | **reach -15%** |
| Dash | 0 | grid | – | – | – | 3.2 / – / – |  |

### juggernaut

| Input | hit | how | reach m | width m | arc deg | content reach / width / arc | FLAG |
|---|---|---|---|---|---|---|---|
| LMB tap | 3 | grid | 1.6 | 2.5 | 113 | 3.4 / – / 160 | **reach -54%, arc -30%** |
| LMB full hold | 4 | grid | 1.4 | 0.5 | – | 3.4 / – / 160 | **reach -60%, arc -100%** |
| RMB | 0 | grid | – | – | – | – / – / – |  |
| RMB hold | 1 | grid | 0.8 | – | – | – / – / – |  |
| E | 1 | shot | 13.0 | 0.4 | – | 13.0 / – / – |  |
| R (hero ult) | 14 | grid | 3.3 | 1.5 | 44 | 3.6 / 1.8 / – | ~width -14% |
| Dash | 28 | grid+w | 5.5 | 3.5 | 53 | 4.5 / – / – | **reach +22%** |

### gunslinger

| Input | hit | how | reach m | width m | arc deg | content reach / width / arc | FLAG |
|---|---|---|---|---|---|---|---|
| LMB tap | 1 | shot | 11.0 | 0.3 | – | 11.0 / – / – |  |
| RMB | 1 | grid | 0.8 | – | – | – / – / – |  |
| E | 38 | grid+r | 7.3 | 2.5 | 33 | 18.0 / 0.9 / – | **width +182%** |
| R (hero ult) | 0 | grid | – | – | – | 14.0 / – / – |  |
| Dash | 0 | grid | – | – | – | 4.8 / – / – |  |

### ostra

| Input | hit | how | reach m | width m | arc deg | content reach / width / arc | FLAG |
|---|---|---|---|---|---|---|---|
| LMB tap | 1 | shot | 17.4 | 0.6 | – | 17.4 / – / – |  |
| RMB | 1 | shot | 13.0 | 0.7 | – | – / – / – |  |
| E | 0 | grid | – | – | – | 9.0 / – / – |  |
| R (hero ult) | 17 | grid+wr | 7.5 | 3.5 | 32 | 10.0 / – / – |  |
| Dash | 0 | grid | – | – | – | 12.0 / – / – |  |

### mage

| Input | hit | how | reach m | width m | arc deg | content reach / width / arc | FLAG |
|---|---|---|---|---|---|---|---|
| LMB tap | 15 | grid | 6.8 | 2.5 | 28 | 16.1 / – / – | **reach -58%** |
| RMB | 9 | grid | 6.8 | 2.5 | 31 | – / – / – |  |
| RMB hold | 2 | shot | 13.0 | 0.4 | – | – / – / – |  |
| E | 0 | grid | – | – | – | 11.0 / – / – |  |
| R (hero ult) | 0 | grid | – | – | – | 14.4 / – / – |  |
| Dash | 41 | grid+r | 7.4 | 2.5 | 33 | 13.0 / 0.9 / – | **width +182%** |
| Dash hold | 36 | grid+r | 7.3 | 2.5 | 33 | 13.0 / 0.9 / – | **width +182%** |

### archer

| Input | hit | how | reach m | width m | arc deg | content reach / width / arc | FLAG |
|---|---|---|---|---|---|---|---|
| LMB tap | 1 | shot | 14.9 | 0.4 | – | 14.9 / – / – |  |
| LMB full hold | 1 | shot | 16.0 | 0.4 | – | 14.9 / – / – |  |
| RMB | 0 | grid | – | – | – | – / – / – |  |
| RMB hold | 1 | shot | 15.6 | 0.6 | – | – / – / – |  |
| E | 8 | grid+wr | 7.5 | 3.5 | 34 | 9.0 / 1.8 / 120 |  |
| R (hero ult) | 0 | grid | – | – | – | 18.0 / 0.5 / – |  |
| Dash | 0 | grid | – | – | – | 3.5 / – / – |  |

### dolm

| Input | hit | how | reach m | width m | arc deg | content reach / width / arc | FLAG |
|---|---|---|---|---|---|---|---|
| LMB tap | 8 | grid | 1.8 | 1.5 | 90 | 13.6 / – / 120 | **reach -87%, arc -25%** |
| LMB full hold | 16 | grid | 5.0 | 2.5 | 37 | 13.6 / – / 120 | **reach -63%, arc -69%** |
| RMB | 48 | grid+w | 5.4 | 3.5 | 67 | – / – / – |  |
| RMB hold | 42 | grid+w | 5.5 | 3.5 | 67 | – / – / – |  |
| E | 0 | grid | – | – | – | 3.4 / – / – |  |
| R (hero ult) | 0 | grid | – | – | – | 12.0 / – / – |  |
| Dash | 0 | grid | – | – | – | 2.8 / – / – |  |

### thief

| Input | hit | how | reach m | width m | arc deg | content reach / width / arc | FLAG |
|---|---|---|---|---|---|---|---|
| LMB tap | 1 | shot | 14.3 | 0.3 | – | 14.9 / – / – |  |
| RMB | 2 | grid | 0.9 | 0.5 | – | – / – / – |  |
| E | 1 | shot | 14.0 | 0.4 | – | 14.0 / – / – |  |
| R (hero ult) | 45 | grid+w | 5.9 | 3.5 | 59 | 5.4 / – / – |  |
| Dash | 5 | grid | 4.4 | 2.5 | 62 | 4.5 / – / – |  |

### rimewright

| Input | hit | how | reach m | width m | arc deg | content reach / width / arc | FLAG |
|---|---|---|---|---|---|---|---|
| LMB tap | 1 | shot | 14.3 | 0.5 | – | 12.4 / – / – | **reach +15%** |
| RMB | 12 | grid | 2.5 | 1.5 | 67 | – / – / – |  |
| RMB hold | 11 | grid | 2.5 | 1.5 | 67 | – / – / – |  |
| E | 29 | grid | 6.0 | 2.5 | 33 | 1.8 / – / – | **reach +231%** |
| R (hero ult) | 25 | grid+w | 6.8 | 3.5 | 37 | – / – / – |  |
| Dash | 15 | grid | 6.8 | 2.5 | 33 | – / – / – |  |

### ashwick

| Input | hit | how | reach m | width m | arc deg | content reach / width / arc | FLAG |
|---|---|---|---|---|---|---|---|
| LMB tap | 0 | grid | – | – | – | 7.0 / – / – |  |
| RMB | 1 | shot | 14.0 | 0.6 | – | 14.0 / – / – |  |
| RMB hold | 1 | shot | 14.0 | 0.6 | – | 14.0 / – / – |  |
| E | 39 | grid+w | 4.5 | 3.5 | 77 | – / – / – |  |
| R (hero ult) | 38 | grid+wr | 7.3 | 3.5 | 40 | – / – / – |  |
| Dash | 1 | grid | 0.8 | – | – | 3.4 / – / – | **reach -77%** |

### tender

| Input | hit | how | reach m | width m | arc deg | content reach / width / arc | FLAG |
|---|---|---|---|---|---|---|---|
| LMB tap | 1 | shot | 14.9 | 0.4 | – | 14.9 / – / – |  |
| RMB | 0 | grid | – | – | – | – / – / – |  |
| E | 0 | grid | – | – | – | 9.0 / – / – |  |
| R (hero ult) | 0 | grid | – | – | – | 12.6 / – / – |  |
| Dash | 0 | grid | – | – | – | 4.2 / – / – |  |
### Mismatches over 10% (follow-ups; nothing was changed in kits)

Each is a row above flagged without `~`. Check the cause before changing a kit: some are the measurement (see Limits), some are the kit.

1. Zedran (`juggernaut`) LMB: the swing hurts only the nearest dummies, reach 1.4 to 1.6 m against `range` 3.4 and arc 113 degrees against `arc` 160.
2. Breah (`dolm`) LMB: tap reach 1.8 m and hold reach 5.0 m against `range` 13.6; arc 90 and 37 degrees against 120.
3. Bulwark LMB (the mace): tap arc 31 degrees and hold arc 37 degrees against `arc` 120; `range` 3.0.
4. Dredge LMB shot flies 16.7 m against `range` 7.8 (+113%); its R shot 5.0 m against 5.9.
5. Rimewright E reaches 6.0 m against `reach` 1.8 (+231%); LMB shot 14.3 m against 12.4 (+15%).
6. Sparkle (`mage`) LMB: the bolt hurts out to about 6.8 m against `range` 16.1; Wirerun (dash and hold) hurts a lane about 2.5 m wide against `width` 0.9.
7. Vex (`gunslinger`) E: a 2.5 m lane against `width` 0.9 (reach runs to the grid edge, 7.3 of 18 m).
8. Zedran dash hurts out to 5.5 m against `dist` 4.5 (+22%); Cinder (`ashwick`) dash hurts one dummy at 0.8 m against `dist` 3.4.
9. Rows that read zero hit (many: for example Vex R and dash, Sparkle E and R, Breah E and dash, Ostra E and dash, most of the support kit, Archer R) are gaps in the measurement, not kit findings: a second press, a delay past the window, a self-cast, or no damage by design.
10. The inputs read off a shot (gunslinger, tender, archer, ostra LMB, Cinder RMB, Zedran E) match their content `range` to the decimal, and the Thief's LMB is within 4%: that is the check that the method itself is sound.
