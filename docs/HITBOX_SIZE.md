# Hitbox size (OWNER_REVIEW item 46)

Each hunter's hitbox radius is `Arch.hit_r(arch, class)`: the archetype's `body.hit_r` in `content/archetypes/<id>.json`, else the class's. The standard is the Medium class radius, 0.40 m. Hitboxes follow the Warden's final height chart (Nov 8, the `height` column of `--warden-model-check`), compressed into 0.85-1.15 x standard so small hunters are not much harder to hit: `hit_r = 0.40 x clamp(1 + 0.3 x (chart - 1), 0.85, 1.15)`. The height is the drawn height: `hit_h = 1.732 m x chart` (a medium hunter's head top 1.546 m x `Hunter.VIS_SCALE` 1.12). Shots hit from 0.45 m under the feet up to `hit_h + 0.9 m` (`Match.shot_band`; a hunter with no archetype keeps the old 1.5 m).

**Source:** the only published reference hero collision is the shared bot nav agent, radius 0.43 m, height 1.76 m (`sv/physics.md`); no per-hero capsule is in the data. Our standard hunter is 0.40 m by 1.73 m, so the heights match and the radius is 7% under, kept as the owner's item 46 standard (set the Medium class `hit_r` to 0.43 to match it).

**Body collision is separate.** `hit_r` is the hurtbox (`Ent.r`: shots and abilities). Walls, rocks and body-vs-body pushing use `Ent.hull_r()`, the archetype's `body_r`, which keeps the values the hurtbox had before the chart pass.

Shots connect inside `hit_r + Match.HIT_SLACK (0.08) + the shot's radius`. `--hitbox-size-check` asserts the band, the drawn circle radius, and a shot just inside and outside the circle for the smallest and biggest.

**Where the impact spark spawns.** `HitContact` (`scripts/combat/hit_contact.gd`, called by `Juice._hit_point`) puts the spark at the hit's real contact point, clamped to the target's collider: inside its hurtbox circle (`Ent.r`) and between its feet and the top of its head (`Arch.hit_h`), so a tall Hunter is struck high and a small one low. A projectile or melee strike (melee strikes are short fast shots) and a blast pass the shot's point, a zone tick passes the zone's own point (low, on the ground), as `opts["at"]` of `Ent.hurt`; a direct kit `hurt` with no `at` lands on the near side at the attacker's mid-height. `--hit-shape-check` asserts a Vex shot, a Kael strike and a Cinder zone tick spark inside a 2.56 m and a 1.04 m collider.

Which hit paths pass a real contact point (`at`), audited 2026-11-20. Before HitContact every path sparked at the target's origin plus a fixed 0.95 m:

| Path | Kits | Contact passed |
|---|---|---|
| `Match._shot_apply` | every projectile and every melee strike (Vex, Kael, Albert...) | the shot's hit point |
| `Match._boom` | blasts, grenades, explosive shots | the blast centre |
| `Effects` `area` | data-driven bursts, slams, landings | the burst centre |
| `Fields.tick` | zones, patches, hazards (Cinder) | the zone point, low |
| `Effects` `cone`/`chain`, `Abilities`, direct `hurt` in `scripts/arch/kits/*` (dashes, grabs, tethers, ults) | the rest | no `at`: HitContact puts it on the near side at the attacker's mid-height, clamped to the target's collider |

## Measured hit shapes (`--hit-shape-check`)

`godot --headless --path . -- --hit-shape-check` (tools/hit_shape_check.gd, about 35 s) stands each hunter on flat ground facing +X beside a grid of 70 training dummies (0.5 m apart, standard body radius 0.4 m + 0.08 m slack), fires each damaging input once aimed straight down +X (cursor 20 m out) and records which dummies lost health. Reach, width and arc below are recovered from that set: the dummy centre is corrected by its hit circle and half a grid cell, so every number is good to about +-0.5 m (and +-10 degrees of arc).

**Source column.** `sv/briefs/kits.md` is read off in-game tooltips and carries no hit sizes at all (no uu values for any reach, width, radius or arc); it only says shapes in words: Heartpiercer and the Arcane Railgun are long beams or shots, Rain of Arrows is "a hail of arrows in a cone", ref-juggernaut's slam is "in front" with edge hits doing more, ref-dolm's Rockwave is "a wall of three rocks in front of you". There is no 100 uu = 1 m number to put beside our content value for any row, so the comparison here is measured against our content JSON (`content/archetypes/<id>.json`, `content/weapons/*.json`). Where the source names a shape, it is quoted under the table.

**How to read a row.** `hit` = dummies damaged (out of 70). `reach` = farthest edge of the damage along the aim line. `width` = the widest lane across it. `arc` = the angle the damage spreads over, seen from the hero. `content` = the JSON number of the same kind (`range`/`reach`/`len`/`dist`, `width`, `deg`/`arc`), if there is one. A dash `–` is zero or nothing to compare. **FLAG** = the content number is more than 10% off the measurement; `~` = the gap is within the 0.5 m grid, so it is noise rather than a finding.

**Limits (read before trusting a row).**
- The grid covers x = 1.0 to 7.5 m and z = 0 to 2.0 m on one side (shapes aimed down +X are assumed mirror-symmetric). A row whose hits touch the grid edge is marked `+r` (reach) or `+w` (width) in the `how` column and is not flagged: the real shape is at least that big.
- A bullet stops at the first dummy it hits. When 1 or 2 dummies were hurt (or the kit's shot bursts on the first dummy: Breah's boulder, Kael's Searing Wave), the input is run again on an empty lane and the shot's own reach and radius are recorded (`how` = `shot`; width is the shot's diameter, arc 0). Reach = where the shot starts (the muzzle, about 0.6 m ahead) + its flight; a slug that slows (`decel`, Grimble's shotgun) flies v^2 / 2a, not its life x its first speed.
- Inputs that need a second press (the Archer's R shots, a recast) were pressed once, so they may read zero. Inputs that hurt nobody (supports, summons, shields) read zero too.
- The match steps at 20 Hz and every input is given about 0.5 to 1.5 s, so a delayed hit can fall outside the window.
- A melee swing is a fan of rays that each stop at the first dummy they meet, so the grid reads it short and narrow: such rows are `how` = `swing` and never flagged. A dash that stops on the first foe (Cinder's Soot Ram) is `first`, never flagged. Their real sizes are the `--hit-shape-fine` rows (one lone dummy).
- Some kits hit with a number other than the generic one: the check reads those from `_content_kit` in tools/hit_shape_check.gd (Kael's sword `lmb.reach`/`arc`, not greatsword.json; Vex's needle `width` is a half-width; Albert's hammer throw `throw_range` + its 0.9 m sweep; Neve's wall `reach` + `travel`; Kael's dash `dist` + `tip_r`; Wirerun `width` + 0.6 + the body). The rows reconciled on 2026-11-21 (`RECONCILED` there) fail the check if they drift over 10% again.
- A lane's width has two edges on a 0.5 m grid, so `~` on a width means within 1.0 m.


### archer

| Input | hit | how | reach m | width m | arc deg | content reach / width / arc | FLAG |
|---|---|---|---|---|---|---|---|
| LMB tap | 0 | grid | – | – | – | 12.0 / – / – |  |
| LMB full hold | 1 | shot | 16.6 | 0.4 | – | 12.0 / – / – | **reach +38%** |
| RMB | 0 | grid | – | – | – | – / – / – |  |
| RMB hold | 1 | shot | 15.8 | 0.6 | – | – / – / – |  |
| E | 0 | grid | – | – | – | 10.8 / 1.8 / 120 |  |
| R (hero ult) | 29 | grid+r | 7.3 | 1.5 | 16 | 18.0 / 0.5 / – | **width +208%** |
| Dash | 0 | grid | – | – | – | 3.4 / – / – |  |

### juggernaut

| Input | hit | how | reach m | width m | arc deg | content reach / width / arc | FLAG |
|---|---|---|---|---|---|---|---|
| LMB tap | 3 | swing | 1.6 | 2.5 | 113 | 3.1 / – / 175 |  |
| LMB full hold | 4 | shot | 14.6 | 1.2 | – | 14.0 / 1.2 / – |  |
| RMB | 0 | grid | – | – | – | – / – / – |  |
| RMB hold | 1 | grid | 0.8 | – | – | – / – / – |  |
| E | 1 | shot | 13.6 | 0.4 | – | 13.0 / – / – |  |
| R (hero ult) | 14 | grid | 3.3 | 1.5 | 44 | 3.6 / 1.8 / – | ~width -14% |
| Dash | 36 | grid+w | 6.3 | 3.5 | 41 | 5.9 / – / – |  |

### gunslinger

| Input | hit | how | reach m | width m | arc deg | content reach / width / arc | FLAG |
|---|---|---|---|---|---|---|---|
| LMB tap | 1 | shot | 11.6 | 0.3 | – | 11.0 / – / – |  |
| RMB | 1 | grid | 0.8 | – | – | – / – / – |  |
| E | 38 | grid+r | 7.3 | 2.5 | 33 | 18.0 / 1.8 / – | ~width +41% |
| R (hero ult) | 0 | grid | – | – | – | 14.0 / – / – |  |
| Dash | 0 | grid | – | – | – | 4.8 / – / – |  |

### bulwark

| Input | hit | how | reach m | width m | arc deg | content reach / width / arc | FLAG |
|---|---|---|---|---|---|---|---|
| LMB tap | 39 | grid+r | 7.3 | 2.5 | 33 | 9.9 / 1.8 / – | ~width +41% |
| LMB full hold | 3 | swing | 1.2 | 1.5 | 90 | 2.8 / – / 180 |  |
| RMB | 0 | grid | – | – | – | – / – / – |  |
| RMB hold | 0 | grid | – | – | – | – / – / – |  |
| E | 0 | grid | – | – | – | – / – / – |  |
| R (hero ult) | 67 | grid+wr | 7.5 | 3.5 | 44 | – / 5.5 / – |  |
| Dash | 4 | swing | 5.5 | 2.5 | 33 | – / – / – |  |

### rimewright

| Input | hit | how | reach m | width m | arc deg | content reach / width / arc | FLAG |
|---|---|---|---|---|---|---|---|
| LMB tap | 1 | shot | 12.1 | 0.5 | – | 10.0 / – / – | **reach +21%** |
| RMB | 12 | grid | 2.5 | 1.5 | 67 | – / – / – |  |
| RMB hold | 11 | grid | 2.5 | 1.5 | 67 | – / – / – |  |
| E | 33 | grid+r | 7.4 | 2.5 | 31 | 18.0 / – / – |  |
| R (hero ult) | 0 | grid | – | – | – | – / – / – |  |
| Dash | 0 | grid | – | – | – | – / – / – |  |

### ashwick

| Input | hit | how | reach m | width m | arc deg | content reach / width / arc | FLAG |
|---|---|---|---|---|---|---|---|
| LMB tap | 0 | grid | – | – | – | 6.1 / – / – |  |
| RMB | 1 | shot | 14.6 | 0.6 | – | 14.0 / – / – |  |
| RMB hold | 1 | shot | 14.6 | 0.6 | – | 14.0 / – / – |  |
| E | 39 | grid+w | 4.5 | 3.5 | 77 | – / – / – |  |
| R (hero ult) | 37 | grid+r | 7.3 | 2.5 | 33 | – / – / – |  |
| Dash | 1 | first | 0.8 | – | – | 3.4 / – / – |  |

### dolm

| Input | hit | how | reach m | width m | arc deg | content reach / width / arc | FLAG |
|---|---|---|---|---|---|---|---|
| LMB tap | 5 | shot | 11.6 | 0.6 | – | 11.0 / 0.6 / – |  |
| LMB full hold | 16 | grid | 5.0 | 2.5 | 37 | 4.2 / 1.8 / – | **reach +19%**, ~width +41% |
| RMB | 48 | grid+w | 5.4 | 3.5 | 67 | – / – / – |  |
| RMB hold | 0 | grid | – | – | – | – / – / – |  |
| E | 0 | grid | – | – | – | 3.4 / – / – |  |
| R (hero ult) | 0 | grid | – | – | – | 21.0 / – / – |  |
| Dash | 0 | grid | – | – | – | 2.8 / – / – |  |

### mage

| Input | hit | how | reach m | width m | arc deg | content reach / width / arc | FLAG |
|---|---|---|---|---|---|---|---|
| LMB tap | 1 | shot | 13.6 | 0.4 | – | 13.0 / – / – |  |
| RMB | 2 | shot | 13.6 | 0.4 | – | – / – / – |  |
| RMB hold | 2 | shot | 13.6 | 0.4 | – | – / – / – |  |
| E | 0 | grid | – | – | – | 11.0 / – / – |  |
| R (hero ult) | 0 | grid | – | – | – | 14.4 / – / – |  |
| Dash | 50 | grid+wr | 7.3 | 3.5 | 40 | 10.5 / 2.3 / – |  |
| Dash hold | 40 | grid+r | 7.3 | 2.5 | 33 | 10.5 / 2.3 / – |  |

### dredge

| Input | hit | how | reach m | width m | arc deg | content reach / width / arc | FLAG |
|---|---|---|---|---|---|---|---|
| LMB tap | 1 | shot | 6.3 | 0.3 | – | 6.3 / – / – |  |
| RMB | 1 | shot | 12.1 | 0.5 | – | 11.5 / – / – |  |
| E | 12 | grid | 2.9 | 2.5 | 62 | – / – / 110 | **arc -44%** |
| R (hero ult) | 1 | shot | 5.9 | 0.9 | – | 5.9 / – / – |  |
| Dash | 5 | grid | 4.0 | 2.5 | 53 | 3.2 / – / – | **reach +26%** |

### tender

| Input | hit | how | reach m | width m | arc deg | content reach / width / arc | FLAG |
|---|---|---|---|---|---|---|---|
| LMB tap | 1 | shot | 7.4 | 0.4 | – | 6.8 / – / – |  |
| RMB | 0 | grid | – | – | – | – / – / – |  |
| E | 0 | grid | – | – | – | 9.0 / – / – |  |
| R (hero ult) | 0 | grid | – | – | – | 12.6 / – / – |  |
| Dash | 2 | grid | 3.9 | 1.5 | 32 | 3.1 / – / – | **reach +24%** |

### thief

| Input | hit | how | reach m | width m | arc deg | content reach / width / arc | FLAG |
|---|---|---|---|---|---|---|---|
| LMB tap | 1 | shot | 8.8 | 0.3 | – | 8.5 / – / – |  |
| RMB | 2 | grid | 0.9 | 0.5 | – | – / – / – |  |
| E | 1 | shot | 15.6 | 0.4 | – | 15.0 / – / – |  |
| R (hero ult) | 43 | grid+w | 5.5 | 3.5 | 67 | 5.4 / – / – |  |
| Dash | 0 | grid | – | – | – | 4.5 / – / – |  |

### ostra

| Input | hit | how | reach m | width m | arc deg | content reach / width / arc | FLAG |
|---|---|---|---|---|---|---|---|
| LMB tap | 1 | shot | 12.9 | 0.6 | – | 12.2 / – / – |  |
| RMB | 1 | shot | 13.6 | 0.7 | – | – / – / – |  |
| E | 0 | grid | – | – | – | 9.0 / – / – |  |
| R (hero ult) | 17 | grid+wr | 7.5 | 3.5 | 32 | 10.0 / – / – |  |
| Dash | 0 | grid | – | – | – | 12.0 / – / – |  |

### gil

| Input | hit | how | reach m | width m | arc deg | content reach / width / arc | FLAG |
|---|---|---|---|---|---|---|---|
| LMB tap | 1 | swing | 0.8 | – | – | 2.5 / – / 50 |  |
| RMB | 21 | grid+wr | 7.5 | 3.5 | 32 | 8.0 / – / – |  |
| E | 16 | grid+w | 2.3 | 3.5 | 127 | 11.0 / 2.2 / – | **reach -79%** |
| R (hero ult) | 62 | grid+wr | 7.5 | 3.5 | 44 | 14.0 / 3.6 / – |  |
| Dash | 27 | grid+w | 4.8 | 3.5 | 53 | 4.5 / – / – |  |
**Finer run.** `--hit-shape-fine` (one dummy moved around, game step 60 Hz, edges to about 0.1 m) first re-measured Vex, Kael, Lace and Cinder (11-12), now every hero plus the Kael, Cinder and Sparkle dashes (11-21, below): every area and lane matches its content number to 0.15 m, and the Kael LMB this grid reads short (1.6 m against 3.7 m fine) is a grid effect (each swing ray stops at the first dummy it meets); the same short reads on other heroes' swings (Breah, Bulwark) were not re-measured. Table and sources in docs/KIT_PARITY.md, "Hit shapes in game".

### Mismatches over 10%: re-checked 2026-11-21 (main afeb9cc4d5; no kit changed)

The eight rows from the first run were re-measured on current main, coarse (`--hit-shape-check`) and fine (`--hit-shape-fine`, one lone dummy, numbers are foe centres: take 0.40 m off an area's edge, about 0.5 m off a ray's or a bullet's). Every one is the measurement, not the kit: the game hits what the kit's own content number says, so the check was fixed and no kit changed (PARITY FIRST: the content numbers stand). Before = this table before the fix; after = the coarse run after it, then the fine read.

| # | Row | Before (coarse vs content) | Cause | After (coarse vs content) | Fine (lone dummy) |
|---|---|---|---|---|---|
| 1 | Kael (`juggernaut`) LMB | tap reach 1.6 / arc 113 vs 3.4 / 160; hold 1.4 vs 3.4 | read greatsword.json, not the kit's `lmb` (3.1 / 175); swing rays stop at the first grid dummy; the hold is the Searing Wave shot | tap `swing` vs 3.1 / 175, not flagged; hold `shot` 14.6 / 1.2 vs `wave_range` 14 / 1.2 | tap reach 4.0, arc 210 (3.1 + ray + circle; arc +30 by the ray fan); hold 14.2 |
| 2 | Breah (`dolm`) LMB | tap 1.8 m, hold 5.0 m vs `range` 13.6, arc 90 / 37 vs 120 | weapon numbers, not the kit's `boulder` / `punch`; the boulder bursts on the first dummy; the punch knocks dummies into the ones behind | tap `shot` 11.6 / 0.6 vs `boulder.range` 11 / 0.6; hold 3.8 to 5.0 (run to run) vs `punch.len` 4.2, not asserted | tap 12.8 (11 + start + blast); hold 4.6 / 2.6 = 4.2 x 1.8 net |
| 3 | Albert (`bulwark`) LMB | tap arc 31, hold arc 37 vs `arc` 120 | weapon numbers; the tap is a thrown hammer (a lane, no arc); the hold is a swing | tap `grid+r` 7.3 / ~2.5 vs `throw_range` + sweep 9.9 / 1.8; hold `swing` vs `smash_reach` 2.8 / 180 | tap 10.4 / 2.6 (asserted); hold 4.0, arc 215 (asserted) |
| 4 | Grimble (`dredge`) LMB, R | LMB shot 16.7 (13.5 on 11-21) vs 7.8 (now 6.3); R 5.0 vs 5.9 | flight read as life x first speed for a slug that slows; the R orbs start 0.9 m ahead | LMB 6.3 vs 6.3; R 5.9 vs 5.9 | LMB 6.8 (6.3 + circle); R 5.9, fan 112 |
| 5 | Neve (`rimewright`) E | reach 6.0 (6.3) vs `reach` 1.8 | `reach` is where the wall erupts; it then slides `travel` (to 16.2) toward the cursor, and the 1.2 s window cut the slide | `grid+r` 7.4 vs `reach` + `travel` 18.0 (window 3 s), not flagged | far 8.6 in its 1.5 s window, lane 4.2 |
| 6 | Sparkle (`mage`) Wirerun | lane 2.5 vs `width` 0.9 | the kit hurts what the body crosses padded by (`width` + 0.6) / 2 a side (`mage_kit.gd` `dash_pass`), so the lane is 0.9 + 0.6 + 2 x body 0.40 = 2.3 | dash 3.5 (`+w`), hold 2.5 vs 2.3, not flagged | hold: half lane 1.55 = body + 0.75 + circle (asserted, new) |
| 7 | Vex (`gunslinger`) E | lane 2.5 vs `width` 0.9 | `width` is the half-width (the beam is 1.8, owner item 68) | 2.5 vs 1.8: `~width`, within the grid | reach 18.4, lane 2.6 = 18.0 x 1.8 net (asserted) |
| 8 | Kael dash; Cinder (`ashwick`) dash | Kael 5.5 (6.3) vs `dist` 4.5; Cinder one dummy at 0.8 vs 3.4 | Kael's tip bursts `tip_r` 1.4 at the end; Cinder's ram stops on the first foe (the nearest dummy) | Kael 6.3 vs `dist` + `tip_r` 5.9; Cinder `first`, not flagged | Kael 6.2 (5.8 net vs 5.9, asserted, new); Cinder 4.6 (4.2 = 3.4 + body + circle, asserted, new) |

Sparkle's LMB (6.8 m vs 16.1 in the first run) no longer reads short: the bolt is now read as a shot, 13.6 vs `range` 13.0.

**Still flagged on the coarse grid, not part of the eight (follow-ups, unchecked):**
- Lace (`archer`) LMB full hold 16.6 vs 12.0 (the Supercharged shot's `range` 16 is a different key); R lane 1.5 vs `width` 0.5 at the grid's 0.5 m step.
- Neve LMB 12.1 vs 10.0: the darts grow with weapon level (fine: 10 x 1.24).
- Grimble E arc 62 vs 110 and dash 4.0 vs 3.2 (the dash "touches nobody" by its card, so the hits are the probe's), Meeko dash 3.9 vs 3.1, Gil LMB and E: not looked at.
- `--hit-shape-fine` on main had two reds: Kael's RMB slam row read `slam.radius`/`angle`, gone since the slam became a lane (fixed here: `len` 4.3, `width` 0.72, game 4.3 / 0.35 half); and Vex's RMB side-offset row hurts nothing (still red, not looked at). Kael's `rmb.card_range` still names `slam.radius`.
- Grimble RMB reads 20.5 m in the fine run against 11.5 (coarse 12.1): not looked at.

Rows that read zero hit (for example Vex R and dash, Sparkle E and R, Breah E and dash, Ostra E and dash, most of the support kit, Archer R) are gaps in the measurement, not kit findings: a second press, a delay past the window, a self-cast, or no damage by design. Shots read their content `range` + the 0.6 m muzzle start (Vex 11.6 vs 11, Cinder RMB 14.6 vs 14, Thief E 15.6 vs 15); the shotgun and Grimble's R count their range from the hero and read it to the decimal.
