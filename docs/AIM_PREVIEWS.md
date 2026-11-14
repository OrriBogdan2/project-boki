# Aim previews: what the caster sees while aiming or holding

This audit compares, for all 12 Hunters and LMB / RMB / E / R, what the caster sees while aiming against
the source. The telegraph audits (ext/telegraph-audit-a/b/c) covered what foes see. Sources:
`briefs/hero-ref/<sheet>.md` [F], `briefs/supervive-data` [D], and owner notes (`briefs/DECISIONS.md`,
`OWNER_REVIEW_1103.md`), which win. The ours column was read at origin/main d255acbee. R is our ult
(`"x"` in the data).

**Plain line**: the shared weapon line (`Match._update_aim`). It runs to the cursor, clamped to the weapon's
`range`, or to full range for an `"aim": "max"` weapon. It hides when the kit's `own_aim_line()` is true.
Owner item 106b says this line ends at the reticle and that a kit's own aim visual replaces it. Reworking the
plain line is 106b's job, not this audit's.

Verdict: **ok** = the shape and size match the hit and the source. **note** = a small gap, left as is.
**FIXED** = fixed on this branch. **audit-a** = already fixed on ext/telegraph-audit-a (not on main yet).

| Hunter | Slot | Source aim and reticle [F] | Ours (AimKit id) | Size vs hit data | Clamps at max range | Verdict |
|---|---|---|---|---|---|---|
| Vex | LMB | direction, to max past the cursor; the plain reticle | plain line (quill_rifle `aim: max`) | 11 m = `range` | yes, fixed at max | ok |
| Vex | RMB | lane to max range while held | none: tap only (owner item 112); plain line 11 m | burr flies 10.5 m | n/a | note: owner chose tap only |
| Vex | E | fixed long line, thick, then narrowing | `e` lane 18 m, width → ×0.12 | `range` 18, `width` ×2 = beam | fixed | ok |
| Vex | R | thin line to the cursor, then a disc | plain line; disc `x%d` after the press | `radius` 3.4, `core_r` 1.2 | point clamped to 14 m | ok |
| Mossy | LMB tap | lands at the cursor (clamped); no line | **`aim` line to the landing point** (was the plain line, 2.4 m) | 2.5-9 m = `throw_min`..`throw_range` | yes | **FIXED** |
| Mossy | LMB hold | melee crescent; no ground mark | none | `smash_reach` 2.8 | n/a | ok |
| Mossy | RMB | shield faces the cursor | the aegis model; `aegis_push` lane in front | `shield.len` ×0.7 wide | n/a | ok |
| Mossy | E | at the planted hammer (or self) | `e` circle at the zone | `radius` 3.5 | n/a | ok |
| Mossy | R | rectangle about 2 × 8 h ahead | `x%d` cells | `cell_len` 4 × `width` 4.5 per cell | fixed | ok |
| Sparkle | LMB | line through the cursor to max range | `lmb` line, 13 m, **plus the plain line** (also 13 m) | `range` 13 | fixed | note: drawn twice, same length |
| Sparkle | RMB | double rail lane to max range | `rmb` lane, rails + chevrons | 13 m = `coil.range` | fixed | ok |
| Sparkle | E | at the cursor, then an arrow lane for the pull | `e%d` rim + `e_drag` lane | rim = `radius` 1.5; drag arrow 4 m vs `slide_dist` 3.4 | rim at the cursor | note: the arrow is 0.6 m long |
| Sparkle | R | gold range ring, crown at the cursor | `x_ring` + `x_aim` | ring 14.4 = `range`; crown `radius` ×0.5 | yes, inside the ring | ok |
| Kael | LMB | melee cone; hold = blast to max | hold: `lmb` lane grows | `wave_range` 7→14, `wave_size` ×2 | fixed | ok |
| Kael | RMB tap | slam lane in the aim | `slam` lane 4 × 1.9 | hit is a 4 m, 70° cone | n/a | audit-a (lane → cone) |
| Kael | RMB hold / air | lane / circle at the cursor | `rmb` lane grows; `drop_aim` circle | fling `dist` × feel; `drop.radius` 2.6 | drop clamped 5 m | ok |
| Kael | E | skillshot hook; no lane | none; plain line 3.4 m (greatsword) | chain `range` 13 | n/a | note: plain line short (106b) |
| Kael | R | self, forward strike rectangle | `ult` lane | `len` 3.6 × `width` 1.8 | fixed | ok |
| Lace | LMB | lands at the cursor (clamped); two lines → one | `draw_rest` / `draw` lines, **plus the plain line** | longbow `range` 12 | yes | **FIXED** (own line only) |
| Lace | RMB | thick bar about 2 bh along the aim | `rmb_bar` lane 0.3 → 3.6 m | the bar is a charge read (source too) | n/a | ok |
| Lace | E | curved wall at the cursor distance | `e` arc_wall | `rmin` 2..`reach` 9, `deg` 120, `width` 1.8 | yes | ok |
| Lace | R | none (a buff) | `x` lane + `x_ring` | `range` 18 × `width` 0.5 | fixed | ok |
| Cinder | LMB | full stream length regardless of the cursor | plain line to the cursor ≤ 7 m | `range` 7 | no (ends at the cursor, 106b) | note |
| Cinder | RMB | thin lane toward the cursor; may end at the cursor | `rmb` lane, fixed | 14 m = `range`; width 0.42 | fixed at max | note: the source may clamp |
| Cinder | E | self ring about 4.5 m | `e_ring` | `radius` 4.5 | n/a | ok |
| Cinder | R | flies forward along the aim | `x_steer` lane | flight left; `trail_w` 1.8 | n/a | ok |
| Grimble | LMB | two spread-edge lines to the slug stop; idle one line | `spread` cone edges / `spread_idle` line, plus the plain line | `range` 6.3, `fan_deg` + bloom | fixed | note: idle shows two lines |
| Grimble | RMB | the plain line to the cursor only | plain line ≤ 6.3 m (shotgun) | hand `range` 11.5 | n/a | note: plain line short (106b) |
| Grimble | E | none before the cast | `e_tell` cone (everyone) | `radius` 3, `angle` | n/a | ok |
| Grimble | R | fan about 3 bh while charging | `x_fan` cone | `range` 5.9, `fan_deg` 105 | fixed | ok |
| Meeko | LMB | to max past the cursor | plain line (`aim: max`) | 12 m = `range` | fixed | ok |
| Meeko | RMB | lane to max range | `rmb` dotted, 6 m | seed flies 14 m | n/a | note: owner item 118 asks for a short lane |
| Meeko | E | self, then thrown to the cursor | none | `reach` 9 | point clamped | ok |
| Meeko | R | an ally in a big radius | `x` dashed ring + `x_pick` | `range` 12.6 | yes | ok |
| Neve | LMB | homing darts toward the cursor | `aim` line to the cursor, **plus the plain line to 10 m** | `range` 10 | no | **FIXED** (own line only) |
| Neve | RMB | lands at the cursor | `rmb` circle at the cursor | `zone_r` 2.2 | yes, 12 m | ok |
| Neve | E | travels toward the cursor | `e` lane (everyone) | `reach` + travel, `length_max` 4.5 wide | travel clamped | ok |
| Neve | R | self | `x` circle | `radius` 7.2 | n/a | ok |
| Tenzo | LMB | tap: skillshot; hold: a short lane | plain line ≤ 11 m; hold `punch` lane | `punch.len` 4.2 × `width` 1.8 | n/a | ok |
| Tenzo | RMB | AoE a hop ahead | `rmb` sweet circle | `radius(k)`, `core` | n/a | ok |
| Tenzo | E | fixed distance ahead, across the aim | `e_tell%d` (everyone, after the press) | `dist` 3.4 | n/a | ok |
| Tenzo | R | wall at the press point, drag to turn | `x` span | `len` 12 | centre clamped 11 m | ok |
| Motley | LMB | permanent line to the cursor with an arrow | `aim` line, **plus the plain line to 14 m** | `range` 14 | no | **FIXED** (own line only) |
| Motley | RMB | two rails to the cursor (cluster width) | `snap` lane rails | 13 m = `snap.range`, `width` 0.7 | fixed at max | note: source rails end at the cursor |
| Motley | E | aim line + landing circle at the cursor | aim line; `seed` circle after the press | `rmax` 3.2 | `reach` 9 | note: no landing circle before the press |
| Motley | R | dome at the cursor | `x` circle (everyone) | `r` 3.6 / 5.1 | `range` 10 | ok |
| Sable | LMB | ends at the cursor (clamped) | `aim` line (own; plain hidden) | `range` 12 (×k empowered) | yes | ok |
| Sable | RMB | fixed lane about 6 bh × 1 bh | `rmb` lane | 10.8 m = `range` + `after`; a first catch only within 7 m | n/a | note: a miss stops at 7 m |
| Sable | E | skillshot toward the cursor | `aim` line; `knife` circle where it lies | `range` 14 | yes | ok |
| Sable | R | self ring about 3.5 bh | `ult` + `ult_rim` | `r0` 2.3 → `reach` 5.4 | n/a | ok |

## The fixes on this branch (ext/aim-preview-parity)
1. **Mossy LMB tap.** His only line was the plain one, clamped to the hammer's 2.4 m swing range, but the throw lands
   at the cursor, 2.5 to 9 m out. `BulwarkKit` now draws its own `aim` line out to `throw_dist()` (the same clamp
   the throw uses), only while the hammer is in hand and not swinging. `own_aim_line()` hides the plain line.
2. **Motley LMB.** Two lines, one ending at the cursor and one running on to 14 m. `own_aim_line()` keeps his own.
3. **Neve LMB.** The same: her line to the cursor plus the plain line to 10 m.
4. **Lace LMB.** The draw line and the plain line both showed. `own_aim_line()` is true while the bow draws.

Left as notes: Sparkle's and Grimble's doubled lines (the same length, or a line inside the cone), the plain line
ending short for Kael E and Grimble RMB (that is 106b's job), Sparkle's drag arrow, Sable's bola reach. Kael's slam
lane is already fixed on ext/telegraph-audit-a.

Checks: `--bulwark-combo-check` ("bjorn aim: the line ends where the hammer lands"), `--archer-combo-check`,
`--ostra-combo-check`, `--rimewright-combo-check` (each asserts `own_aim_line()` next to its own line).
