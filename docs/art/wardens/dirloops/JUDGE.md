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
a loop, forward on top: `pelvis/vex_walk_strip.jpg`, `pelvis/vex_run_strip.jpg`, `pelvis/tarek_walk_strip.jpg`,
`pelvis/tarek_run_strip.jpg` (`--clip-shots --warden=dolm --yaw=90 --fps=16 --size=320`, frame round(i*len/8*16); the first
clip of a run catches the boot splash, so render a throwaway clip first: Tarek's walk_f row shows the splash in its
first five columns; the re-render, job 20261111-135126-08852, sat in the GPU queue over an hour). Tarek, read off the strips: every loop's hip
rides level with walk_f/run_f in the same column, no crouched frame; run_l/r read as a light bounding side step (the
short stance below), run_b/bl/br stand taller than the leaning run_f, as the band allows (it bounds under and over).

Cost: the stance gets short where the forward hip is tall and the step long. Tarek run_l/r stance 0.16-0.18 of the
cycle (a bounding side step); Vex walk_r 0.23 (a light, springy walk). Fix for both (ours, not built): a shorter stride
at loco speed needs a faster cadence, i.e. a shorter loop, which breaks the ring's one length; the alternative is
a lower, longer-legged forward walk (the forward loop sets the band).
