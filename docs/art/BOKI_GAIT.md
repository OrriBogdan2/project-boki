# Boki gait: do the feet keep still on the ground?

`--boki-gait-check` plays each rigged Boki's walk and run clip the way the game does (`BokiRig.play_scale`) and measures how
fast the feet that are down move back along the body, against how fast the Boki moves. **Slide** is how far that is off, in
percent of the move speed: 0% is a foot planted on the ground, 100% is a foot that skates (or, past it, a foot that
runs too fast). Under 25% reads as walking; the numbers below are all far over it.

- **Walk** is the farm wander pace, 2.4 m/s (`Home`, before a personality's pace).
- **Run** is the match speed, the `kin_speed` stat of the species at no points (5.4-8.0 m/s).
- **Stride** is the m/s the clip's feet cover at playback speed 1. The playback scale is `speed / stride`, kept between the
  row's `min` and `max` (`content/rules/boki_gait.json`; a species row replaces the default whole).
- **Steps/s** is the footfalls per second of the whole Boki (one per foot per cycle).
- Not measured: the Boki with no legs or that hover (zephyrak, gloamshell, selenfin, glomwort) and thrumbird, which flies
  in walk and run (its feet are tucked and never step).

## Ranking, worst first

Before: every species played at the old fixed scale 1.6. After: the five worst got their own stride and a scale cap of
3.5 cycles/s in the walk and 5 cycles/s in the run (faster looks like a flicker). Slide is walk, then run.

| # | Species | Walk slide | Run slide | Stride walk / run (m/s) | Scale walk / run now | Steps/s run now |
|---|---|---|---|---|---|---|
| 1 | mossgrade **fixed** | 93% → 79% | 84% → 64% | 0.11 / 0.60 | 4.70 / 3.60 | 39.3 |
| 2 | kestrike **fixed** | 83% → 73% | 91% → 85% | 0.25 / 0.41 | 2.60 / 2.70 | 10.1 |
| 3 | wisplet **fixed** | 75% → 67% | 90% → 84% | 0.37 / 0.48 | 2.10 / 2.70 | 10.1 |
| 4 | kindlewren **fixed** | 78% → 69% | 90% → 86% | 0.33 / 0.45 | 2.20 / 2.30 | 9.9 |
| 5 | lodestick **fixed** | 84% → 65% | 87% → 78% | 0.23 / 0.60 | 3.60 / 2.70 | 30.4 |
| 6 | cairnback | 83% | 79% | 0.26 / 0.72 | 1.60 / 1.60 | 12.0 |
| 7 | nettlynx | 73% | 80% | 0.41 / 0.84 | 1.60 / 1.60 | 13.7 |
| 8 | burrlet | 73% | 79% | 0.41 / 0.81 | 1.60 / 1.60 | 13.7 |
| 9 | rimeshrew | 70% | 79% | 0.44 / 0.98 | 1.60 / 1.60 | 16.0 |
| 10 | glintmole | 72% | 78% | 0.42 / 0.86 | 1.60 / 1.60 | 13.7 |
| 11 | puddlet | 73% | 75% | 0.41 / 0.95 | 1.60 / 1.60 | 13.7 |
| 12 | pebbit | 71% | 74% | 0.43 / 0.89 | 1.60 / 1.60 | 13.7 |
| 13 | hivara | 67% | 72% | 0.50 / 1.24 | 1.60 / 1.60 | 13.7 |
| 14 | cindle | 52% | 69% | 0.71 / 1.31 | 1.60 / 1.60 | 13.7 |
| 15 | marchleaf | 67% | 56% | 0.49 / 1.80 | 1.60 / 1.60 | 16.0 |
| 16 | zapple | 52% | 64% | 0.72 / 1.69 | 1.60 / 1.60 | 13.7 |

## Why the rest is not under 25%

The fix here is data only (stride and playback scale; no new clips). The clips do not cover the ground: a run cycle
carries the feet 0.4-1.8 m/s at speed 1 while the Boki runs at 5-8 m/s, and several walks carry them 0.1-0.4 m/s against
2.4 m/s. Reaching the speed by playing the clip faster would need 4-25x, which is a 15-40 Hz leg flicker, so the scale
is capped and the difference stays as slide. The check holds each species to `OVER` (its ceiling, percent) and asks
for under 25% for any that is not listed; a ceiling only ever comes down. To close the gap a species needs a longer
stride in its own clips (`tools/boki/*_anim.py`: legs that reach further in `walk` and `run`) and then a new `stride`
row here; `docs/DEBT.md` has the entry.

Strips of the five fixed, before and after (walk on top, run below; the lines on the ground are 0.25 m apart and the
camera follows the Boki, so a foot that stays down stays on its line): `docs/art/gait/<species>_before.png` and `_after.png` (made with `--boki-gait-shots`).
