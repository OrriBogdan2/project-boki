# Tarek and Vex directional loops: rubric judge (2026-11-11)

walk_b/l/r and run_b/l/r rebuilt by `tools/art1/hunter_dir_gait.py`, the pilot gait recipe (closed L+R cycle, stance sole
pinned to a floor that passes at loco speed, soles on the floor from the skinned foot verts) driven by a direction, and
in step with the pilot walk_f/run_f (same length, right-foot strike, duty, bob, floor) so the blended diagonals do not drift.
Side steps turn the pelvis 40 deg into the move (the feet pass, never cross); the chest keeps the old clip's facing and
upper body (arms, head, weapon, springs), resampled and phased to the new legs. Sheets: `tarek_loco_sheet.jpg`,
`vex_loco_sheet.jpg` (game renderer, --clip-shots, 12 fps, rows walk f/b/l/r then run f/b/l/r).

Measured (skinned soles, game m/s; slip = planted-sole speed off its median; before -> after):

| clip | length s (f) | planted sole m/s vs loco | slip median | verdict |
|---|---|---|---|---|
| Tarek walk_b/l/r | 0.967 -> 1.083 (1.083) | 1.0/1.1/1.1 -> 2.20 vs 2.2 | 0.2-0.7 -> 0.00 | slide, contact, seam pass; weight shift 3/5: pelvis dips up to 0.34 m at the stride ends |
| Tarek run_b/l/r | 0.533 -> 0.708 (0.708) | 7.2/4.4/4.5 -> 5.00 vs 5.0 | 0.4-1.5 -> 0.03-0.06 | pass; run_l/r a few toe-off keys drag (p90 0.5-0.8) |
| Vex walk_b/l/r | 0.867 -> 1.083 (1.083) | 1.47 -> 2.10 vs 2.1 | 0.01 -> 0.01 | slide, contact, seam pass; reads crouched (dip up to 0.31 m) next to the upright walk_f: FAIL on posture |
| Vex run_b/l/r | 0.567 -> 0.542 (0.542) | 4.63 -> 4.55 vs 4.55 | 0.2 -> 0.01-0.03 | run_b pass; run_l/r toe-off drag (p90 2.9/4.4) and a 3 cm sole dip: borderline |

Loop seams: last key = first on every new clip (0 deg). Rubric (no slide / clean contact / weight shift / seam, 1-5):
Tarek walk 4.5/4/3/5, run 4.5/4/3.5/5; Vex walk 5/4.5/2.5/5, run_b 4.5/4.5/3.5/5, run_l/r 3.5/3/3.5/5.

Open, not mine to pick: the loco speeds against the f loop lengths ask for steps longer than the legs (Tarek walk:
2.2 m/s x 1.083 s = 1.19 m a step on a 1.17 m leg), so any non-forward loop must crouch or flight. A longer walk cycle
(f too) or a lower walk_speed would let b/l/r stand as tall as f. The pilot run_f loops themselves plant at 7.4 m/s
(Tarek, loco 5.0) and 6.0 m/s (Vex, 4.55): they slide in game and pull the run diagonals with them.

# Grimble (dredge) and Sparkle (ryzz) walk/run loops: rubric judge (2026-11-11)

All eight walk/run loops of each rebuilt with `tools/art1/hunter_dir_gait.py` (f too, own lengths: `... -- SRC OUT walk_f run_f b,l,r,f <walk s> <run s>`).
No Meshy: the poses are the characters' own (Grimble hunched under the hoard, hook arm; Sparkle's caster stride). Judged by the builder against
the rubric, no subagent. Strips (game renderer, --clip-shots --match, 12 fps, 6 evenly spaced frames per loop; rows per direction f/b/l/r, before then after):
`grimble_{walk,run}_before_after.jpg`, `sparkle_{walk,run}_before_after.jpg`. At match zoom the silhouettes are the same size and shape before and after;
the change is in where the feet are and when.

| clip | length s | planted sole m/s vs loco | pelvis dip | verdict |
|---|---|---|---|---|
| Grimble walk f/b/l/r | 1.000 -> 0.750 | 1.03 -> 2.20 vs 2.2 | 0 | keep: slide, contact, seam pass; weight 3/5 (hoard rides the hips) |
| Grimble run f/b/l/r | 0.625 -> 0.542 | 3.15 -> 4.40 vs 4.4 | 0 | keep |
| Sparkle walk f/b/l/r | 0.938 -> 0.792 | 1.17 -> 2.20 vs 2.2 | 0 / 0 / 4.1 / 4.6 cm | keep; l/r dip is a small knee give |
| Sparkle run f/b/l/r | 0.604 -> 0.542 | 3.73 -> 4.80 vs 4.8 | 0 | keep |

Both heroes' shipped loops skated at 47-78% of loco speed; every kept loop now plants at 100% of it. Seams: last key = first; `--clip-check` (0 failures,
walk loops one length per hero, ring-length assert). Upper layers (`--layer-verify --wardens=dredge,mage`, entries added to the tool): legs off the
unlayered run 0.000 m in every layer x gait x direction, recoil leftover 0.00 deg; the flinch's extra hand/head jump on the run (up to 0.32 m) is the flinch
itself, as for Vex and Tarek. `--dredge-combo-check` 95 checks, `--mage-combo-check` 129 checks, 0 failures. Alternative not taken: the shorter A build for Grimble
(walk 0.604 s, run 0.5 s): the cadence is too quick for a hunched sack carrier; B keeps the weight.
