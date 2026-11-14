# Tarek and Vex directional loops: rubric judge (2026-11-11, second pass)

walk and run for b, l, r and the four diagonals fl, fr, bl, br (14 clips a Hunter) are baked by
`tools/art1/hunter_dir_gait.py`. The pilot walk_f/run_f stay as shipped (see "Not passed"). Sheets, game renderer
(`--clip-shots`, 8 frames a loop, side view; l/r from the front): `tarek_loco_sheet.jpg`, `vex_loco_sheet.jpg`.

## Recipe (what changed against the first pass)

- **Stance**: the planted sole is pinned to a floor that passes at loco speed; soles sit on the floor from the skinned
  foot verts. Unchanged.
- **Reach**: a stance never travels more than 0.8 leg lengths (`REACH`). The loco speeds ask for steps longer than
  the legs (Tarek walk: 2.2 m/s x 1.083 s / 2 = 1.19 m on a 1.17 m leg), so the rest of each step is flown: duty
  0.26-0.39. The first pass kept duty 0.5 and paid with a crouch.
- **Height**: the hip rides a set share of leg length over the planted leg (`RIDE`: walk 0.985, run 0.95) and dips
  per key only where a stride end outreaches the leg. The first pass dropped the whole cycle.
- **In step**: each loop takes its length, right-foot strike key, lean and floor from the shipped forward loop. The
  first pass struck at key 0 while walk_f strikes at key 43 (Tarek) and 9 (Vex): its "in step" claim was wrong.
- **Diagonals**: real clips on the blend ring (`loco.walk/run.fl|fr|bl|br`), no half-speed blend of two neighbours;
  `loco.in_step` makes the blend space keep the ring's loops in time.

## Measured (skinned soles, game units; first pass -> now)

| loops | planted sole vs loco speed | pelvis dip, worst key | duty | seam (last key vs first) |
|---|---|---|---|---|
| Tarek walk x7 | 2.20 vs 2.2, 100% of planted keys within 5% | 0.25-0.34 m -> b 0.05, fl/fr 0.07, bl/br 0.05, l/r 0.11 | 0.39 | 0.0 deg, 0 mm |
| Tarek run x7 | 5.00 vs 5.0, 100% within 5% | b/bl/br 0, fl/fr 0.02, l/r 0.05 | 0.26 | 0.0 deg, 0 mm |
| Vex walk x7 | 2.10 vs 2.1, 100% within 5% | 0.31 m -> b/bl/br 0.02, fl/fr 0.04, l/r 0.06 | 0.30 | 0.0 deg, 0 mm |
| Vex run x7 | 4.55 vs 4.55, 100% within 5% (first pass l/r: toe-off drag, 3 cm sole dip) | 0, l/r 0.01 | 0.28 | 0.0 deg, 0 mm |

Every dip is 0 at mid stance. Worst ankle miss 0.002 m. `--clip-check`: 0 failures, each ring one length
(Tarek walk 1.083 s, run 0.708 s; Vex walk 1.083 s, run 0.542 s).

Pilot forward loops, same measure (kept, for reference):

| loop | planted sole m/s: median (p10-p90) vs loco | duty |
|---|---|---|
| Tarek walk_f | 2.19 (1.14-3.26) vs 2.2 | 0.54 |
| Tarek run_f | 7.58 (0.75-8.89) vs 5.0 | 0.29 |
| Vex walk_f | 1.87 (0.44-2.65) vs 2.1 | 0.50 |
| Vex run_f | 5.98 (0.54-7.19) vs 4.55 | 0.50 |

## Rubric (1-5: no foot slide / clean contact / weight shift / loop seam, then look = silhouette and personality)

Pass = no rubric point under 3. Judged from the measures above and the sheets (stills, not video).

| clip | slide | contact | weight | seam | look | verdict |
|---|---|---|---|---|---|---|
| Tarek walk_b, bl, br | 5 | 4 | 3 | 5 | 3 | pass; knees stay soft through the stride ends |
| Tarek walk_fl, fr | 5 | 4 | 3 | 5 | 3 | pass; 7 cm dip at the stride ends |
| Tarek walk_l, r | 5 | 4 | 3 | 5 | 3 | pass, the weakest walks: 11 cm dip on the crossing step |
| Tarek run_b, bl, br | 5 | 4 | 4 | 5 | 3 | pass |
| Tarek run_l, r | 5 | 4 | 3 | 5 | 3 | pass |
| Tarek run_fl, fr | 5 | 4 | 3 | 5 | 2 | pass on the four points; look under the pilot (below) |
| Vex walk_b, bl, br | 5 | 4 | 4 | 5 | 4 | pass; upright, the first pass' crouch is gone |
| Vex walk_fl, fr | 5 | 4 | 3 | 5 | 3 | pass |
| Vex walk_l, r | 5 | 4 | 3 | 5 | 3 | pass |
| Vex run_b, bl, br | 5 | 4 | 4 | 5 | 4 | pass |
| Vex run_l, r | 5 | 4 | 4 | 5 | 3 | pass; the toe-off drag and sole dip are gone |
| Vex run_fl, fr | 5 | 4 | 3 | 5 | 3 | pass; sits as low as run_f |
| Tarek walk_f, Vex walk_f (pilot) | 3 | 4 | 4 | 5 | 4 | pass; the planted sole speed wanders, the median is right |
| Tarek run_f (pilot) | 2 | 3 | 4 | 5 | 5 | FAIL on slide |
| Vex run_f (pilot) | 2 | 3 | 4 | 5 | 4 | FAIL on slide |

## Not passed, and why

- **run_f, both Hunters, slides**: the planted sole runs at 7.6 m/s (Tarek) and 6.0 m/s (Vex) under a body that
  moves 5.0 and 4.55. A generated run_f was baked and judged: no slide, but it loses the pilot's sprint (the lean, the
  heel kick) and reads as a shuffle, so by the pilot rule (ship only what beats current) the pilot loops stay.
- **Tarek run_fl/fr look**: upright, low swing feet, next to a leaning, heel-kicking run_f. The feet hold, the character
  changes across the f to fl blend. The generator has no heel recovery in its swing; that is the next thing to add.
- **Walks are flown steps**: at these speeds and this cycle length a duty-0.5 walk cannot reach (Vex walk at 2.1 m/s
  is a jog by leg length). They read as a brisk, bouncy walk. Open, not mine to pick: a shorter walk cycle for the
  whole ring (f too) or a lower `walk_speed` would let every walk plant both feet.
- **Walk to run blend**: the two rings have different lengths, so feet drift while the speed blends between them.
  As before; `in_step` only keeps one ring in time.

## Third pass: pelvis held to the forward loop (2026-11-11, ext/anim-dirloops-pelvis)

The hip no longer rides a set share of leg length (`RIDE`) less a dip: each key takes the forward loop's hip height
at the same phase. Where a stride end can't reach the floor from there, the stance shortens (`DUTY_STEP`, more of
the step flown) until the dip is under `DIP_OK` 0.025 m. Re-baked on main's models (Tarek v2, Vex appeal3 body b).
`--clip-check` now holds every loop of an `in_step` ring to the forward loop's hip band at the same phase (lowest
to highest within 1/16 cycle, give or take 0.03 m), so the dip can't come back.

| loops | pelvis under forward at the same phase, worst (2nd pass -> now) | duty | planted sole vs loco |
|---|---|---|---|
| Tarek walk b,l,r / fl,fr / bl,br | 0.08 / 0.12 / 0.10 m -> 0.010 / 0.016 / 0.013 | 0.27-0.30 / 0.39 / 0.27 | 2.20, 100% within 5% |
| Tarek run b,l,r / fl,fr / bl,br | 0.04-0.08 / 0.05 / 0 m -> 0.001-0.022 / 0.019 / 0.001 | 0.26, l/r 0.16-0.18 / 0.20 / 0.26 | 5.00, 100% |
| Vex walk b,l,r / fl,fr / bl,br | 0.03-0.08 / 0.07 / 0.045 m -> 0.023 / 0 / 0.024 | 0.23-0.26 / 0.30 / 0.26-0.30 | 2.10, 100% |
| Vex run all | 0.035 under, b/l/r 0.085 over -> 0.002 | 0.28 | 4.55, 100% |

Worst ankle miss 0.0025 m; every ring one length (clip-check). Strip, game renderer, side view, 8 phase-aligned frames
a loop, forward on top: `pelvis/vex_walk_strip.jpg`, `pelvis/vex_run_strip.jpg` (Tarek's strip job was lost by the GPU worker 4 times, rc 125: still to render with `--clip-shots --warden=dolm --yaw=90`).

Cost: the stance gets short where the forward hip is tall and the step long. Tarek run_l/r stance 0.16-0.18 of the
cycle (a bounding side step); Vex walk_r 0.23 (a light, springy walk). Fix for both (ours, not built): a shorter stride
at loco speed needs a faster cadence, i.e. a shorter loop, which breaks the ring's one length; the alternative is
a lower, longer-legged forward walk (the forward loop sets the band).

## Cinder (heavy) and Sable (light): blind judge (2026-11-11, ext/anim-dirloops-cinder-sable)

Baked with the same recipe plus one change: a swing sole now leaves and meets the floor at `SWING_V` 0.9 of the
stance speed (was 0.3 and 0.6). The old values made the foot scoot just above the floor at lift-off, which
`--anim-audit` counts as slide: Cinder run, probe at 90/135/180 deg went from 1.23/1.03/1.04 to 0.70/0.43/0.42 m/s.
Bake speeds come from each hero's playback rate, because the ring plays at speed / `foot_mps`:
- Cinder: her `foot_mps` 2.26 / 5.19, so the soles land at 2.2 / 4.6 in game.
- Sable: 1.39 / 2.9. Her forward loops plant at 0.9 / 2.8 m/s and need `stride` 1.5 and the 1.4 rate cap. Without
  them her run_f slides 45% (gate 25%), and a re-baked run_f still measured 40%, so her loco data stays as on main.

All loops are the forward loop's length and strike key (Cinder walk 0.667 s, run 0.708; Sable 0.938, 0.625). Soles are
100% within 5% of the bake speed, the worst pelvis dip is 0.024 m and the worst ankle miss 0.001 m.

The judge is a Fable subagent, blind. Each sheet shows the forward loop (REF) on top, then the current and the new
loop as rows A/B in seeded random order, 8 frames, 3/4 view. The frames are software renders (Xvfb llvmpipe),
because the GPU queue sat 60+ min. Scores are contact / weight / seam / look, 1-5:

| clip | new | current | winner |
|---|---|---|---|
| Cinder walk_b | 3/3/4/3 | 3/4/4/4 | current (new: stiff, narrow shuffle) |
| Cinder walk_l | 3/2/3/3 | 3/3/4/3 | current (new: splays wide, pelvis drops) |
| Cinder walk_r | 2/2/3/2 | 3/4/4/4 | current (new: straddle, legs intersect) |
| Cinder run_b | 3/3/4/3 | 3/4/4/4 | current (new: too upright, loses the heavy drive) |
| Cinder run_l | 2/2/3/2 | 3/3/3/3 | current (new: splits, hip sinks) |
| Cinder run_r | 2/2/3/2 | 3/4/4/4 | current |
| Sable walk_b | 3/3/4/3 | 3/4/4/4 | current |
| Sable walk_l | 3/3/4/3 | 3/4/4/4 | current |
| Sable walk_r | 3/3/3/3 | 3/4/4/4 | current |
| Sable run_b | 3/3/3/4 | 3/3/3/3 | tie: current kept |
| Sable run_l | 2/2/3/2 | 3/3/3/3 | current (new: full lunge split) |
| **Sable run_r** | 3/4/4/4 | 3/3/3/3 | **new** |

There is no current diagonal clip; the current diagonal is a blend of two neighbours, which the audit probe measures
at 3.0-3.5 m/s slide. A new diagonal is kept if it passes (no score under 3). Sheets are in `cinder_sable/`:

| ring | fl | fr | bl | br |
|---|---|---|---|---|
| Cinder walk | 3/4/4/4 pass | 2/2/3/2 FAIL | 2/2/3/2 FAIL | 3/4/4/4 pass |
| Cinder run | 3/4/4/4 pass | 2/2/3/2 FAIL | 2/2/3/2 FAIL | 3/4/4/4 pass |
| Sable walk | 3/4/4/4 pass | 3/4/4/4 pass | 3/3/3/3 pass | 3/4/4/4 pass |
| Sable run | 3/4/4/4 pass | 3/4/4/4 pass | 3/3/3/3 pass | 3/3/3/3 pass |

Shipped:
- Cinder: walk and run fl and br. fr and bl stay blends.
- Sable: all eight diagonals and run_r.
- Both rings are `in_step`, and the hand-keyed b/l/r loops are already the forward loop's length.

Gate (`--anim-audit`, run slide): Cinder 12% (main 13%), Sable 18% (main 17%). Diagonal probe on the shipped set
(temporary `--anim-audit` patch, not committed): Sable 45 deg 0.92 m/s (was 3.47), 135 deg 1.20 (2.78).

Not passed, and why:
- The recipe's side steps and Cinder's fr/bl read as a wide straddle or a lunge next to the hand-keyed loops. The
  turned pelvis plus `WIDEN` spreads the feet, and her heavy, low-duty run (stance 0.15) loses the drive.
- Stills at 150 px cap contact at 3. The judge could not see sinking or hovering.

## Cinder and Sable, second pass: restride, jets, blind judge again (2026-11-11, ext/anim-dirloops-cinder-sable-2)

The first pass lost every side and back step to the hand-keyed loops on look (straddle, lunge). So for b/l/r the
recipe now also offers **restride** (`b+`): the shipped loop as keyed, with only each ankle pushed along the move,
away from its own stance middle, until a planted sole travels at the bake speed. The leg is solved again with the
shipped knee direction and foot angle, and the pelvis dips (2.5 cm at most, `DIP_OK`) where the longer stance outreaches
the leg. Where even that leaves a planted ankle more than 1 cm short (`MISS_OK`), the stretch backs off.

| loop | planted sole, hand-keyed -> restride (bake speed) |
|---|---|
| Cinder walk_b / l / r | 2.23 / 1.79 / 1.80 -> 2.26 / 2.26 / 2.26 (2.26) |
| Cinder run_b / l / r | 4.72 / 3.79 / 3.83 -> 5.19 / 4.53 / 4.55 (5.19) |
| Sable walk_b / l / r | 0.60 / 0.56 / 0.58 -> 1.07 / 1.06 / 1.13 (1.39) |
| Sable run_b / l / r | 1.92 / 1.99 / 1.94 -> 2.59 / 2.70 / 2.78 (2.90) |

**Bug fixed: Cinder's foot jets.** Every hand-keyed loco clip scales her `jet.0`/`jet.1` bones to (0.25, 0.06, 0.25).
The recipe keyed only location and rotation, so its loops (incl. the first pass's shipped walk/run fl and br) showed the
jets full size, as blades under her feet. It now keys bone scale from the source clip.

**Sheets.** Blender Workbench on lavapipe (Vulkan, CPU), 360 px a frame, 8 frames a loop from key 0. The floor is a
0.25 m checker that scrolls at the bake speed, so a planted sole holds its tile. All rows are main's model plus the
clips (`glb_add_clips.py`): a model re-exported from Blender skins Cinder's feet wrong. The GPU queue was stuck (oldest
gpu job 7 h). The judge is a Fable subagent, blind (seeded A/B order). Its scores are contact / weight / seam / look:

| clip | restride | current | winner |
|---|---|---|---|
| Cinder walk_b | 3/3/4/3 | 3/3/4/3 | tie: current kept |
| Cinder walk_l | 3/3/4/3 | 3/3/4/4 | current (restride straddles wide) |
| Cinder walk_r | 3/3/4/3 | 3/3/4/3 | tie: current kept |
| **Cinder run_b** | 3/4/4/4 | 3/3/4/3 | **restride** (knee drive, compact scissor) |
| Cinder run_l | 3/3/4/2 | 3/4/4/4 | current (restride over-lunges) |
| Cinder run_r | 3/3/3/2 | 3/4/4/4 | current (legs tangle) |
| **Sable walk_b** | 4/4/4/4 | 4/3/4/3 | **restride** |
| Sable walk_l | 3/3/4/3 | 4/4/4/4 | current (overreaches sideways) |
| Sable walk_r | 3/3/3/2 | 4/4/4/4 | current (wide straddle) |
| **Sable run_b** | 4/4/4/4 | 4/3/4/3 | **restride** (run lean, push-off) |
| **Sable run_l** | 4/4/4/4 | 4/3/4/3 | **restride** (cleaner leg cross) |
| Sable run_r | 3/3/3/2 | 3/3/4/3 (first-pass recipe) | first pass kept |

Cinder's diagonals, re-baked with the jets fixed. There is no current clip, so a diagonal is kept if no score is under 3:

| ring | fl | fr | bl | br |
|---|---|---|---|---|
| Cinder walk | 3/3/4/3 pass | 3/3/4/3 pass | 3/3/4/3 pass | 3/3/4/3 pass |
| Cinder run | 3/4/4/3 pass | 3/4/4/3 pass | 3/3/4/3 pass | 3/3/3/2 FAIL (splits) |

Shipped:
- Cinder: run_b restride, plus walk fl/fr/bl/br and run fl/fr/bl. run_br goes back to the b+r blend; it was shipped in
  the first pass with the jet bug.
- Sable: walk_b, run_b and run_l restride, plus the first pass's diagonals and run_r.

Sheets: `cinder_sable/pass2_*.jpg`; the first pass's Cinder sheets are removed (they showed the jet bug). Contact
stays at 3 for every row, current or new: even with the scrolling floor, the stills don't let the judge tell a 20%
slide from none. The table above is the measure.

Gate on this tree:
- `--anim-audit`: ashwick (Cinder) 13% and thief (Sable) 18%, under the 25% limit. dolm and gunslinger fail, as in the
  stacked branch's NOTE. `gil` hits a SCRIPT ERROR because it has no Warden clips.
- `--clip-check`: 1 FAIL, Ostra's import flake (DEBT); every Cinder/Sable pelvis row is ok.
- `--ashwick-combo-check` 125/0, `--dancer-combo-check` 144/0.

Not passed: restride on side steps. Cinder's are already wide hand-keyed straddles, and a longer stance reads as a lunge.
The next try is a crossover side step, with the trail foot passing in front, and the stance shortened rather than stretched.

### Cinder after the 11-12 merge with main
Main re-keyed Cinder's run_* (ext/anim-cinder-rekey: a 0.333 s scurry, `foot_mps` 5.15). Only the four walk diagonals
(walk_fl/fr/bl/br, judged above) stay on her; the run_b restride and run_fl/fr/bl were baked on the old 0.7 s run_f and
are dropped. Run diagonals on the new run_f are open (needs Blender, not on this worker). Sable and Vex unchanged.
