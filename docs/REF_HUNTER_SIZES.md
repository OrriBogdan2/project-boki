# Reference hunter sizes as the player sees them (11-27)

Numbers only, code names only (key in `docs/ARCHETYPES.md`; the labels with no archetype are role words). Source: private reference notes.

- **Runtime scale is 1.00 for all 25.** The model is drawn unscaled inside its capsule (feet = capsule bottom), so model metres are real metres. There is no hidden per-hunter scale.
- **Size = what is on screen**, not bind-pose height: `sqrt(on-screen height x sqrt(silhouette area))`, in-combat idle, game camera, mean of 8 facings. This is the measure `body.match_k` is set from (`docs/MOVEMENT_FEEL.d/1127-hunter-size-parity.md`).
- Standing crown height and on-screen size disagree for wide or low-stanced hunters: `ref-bulwark` is the biggest on screen (1st) yet only 8th by standing crown; `ref-sniper` is 18th on screen (above `ref-tender`, 24th) yet shorter by crown (1.65 vs 1.78 m).
- "Crown" is the head-bone top, so hats, ears and hair count; "tallest point" adds weapon and props. Idle = out-of-combat idle clip.

| rank | hunter | bind crown m | bind tallest m | runtime scale | capsule r x half-h m | standing crown m (idle) | combat crown m | tallest point m (idle) | on-screen h m | on-screen area m2 | on-screen size |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | ref-bulwark | 2.06 | 2.17 | 1.00 | 0.65 x 0.88 | 2.33 | 1.25 | 2.33 | 2.91 | 3.18 | **2.278** |
| 2 | ref-turret | 2.65 | 2.65 | 1.00 | 0.60 x 0.88 | 2.48 | 2.15 | 2.48 | 2.55 | 3.25 | **2.143** |
| 3 | ref-dredge | 2.58 | 2.58 | 1.00 | 0.65 x 0.92 | 2.47 | 1.86 | 2.47 | 2.66 | 2.99 | **2.143** |
| 4 | ref-reaper | 2.70 | 2.70 | 1.00 | 0.55 x 0.90 | 2.62 | 2.01 | 2.62 | 2.53 | 1.77 | **1.836** |
| 5 | ref-burst | 2.17 | 2.96 | 1.00 | 0.43 x 0.88 | 2.11 | 1.85 | 2.35 | 2.26 | 1.71 | **1.720** |
| 6 | ref-juggernaut | 2.13 | 2.22 | 1.00 | 0.43 x 0.88 | 2.04 | 1.70 | 2.17 | 2.36 | 1.51 | **1.702** |
| 7 | ref-ostra | 3.04 | 3.04 | 1.00 | 0.43 x 0.88 | 2.81 | 2.83 | 2.81 | 2.28 | 1.46 | **1.661** |
| 8 | ref-stalker | 2.21 | 2.25 | 1.00 | 0.43 x 0.88 | 2.13 | 1.52 | 2.13 | 2.44 | 1.17 | **1.624** |
| 9 | ref-alchemist | 2.22 | 2.42 | 1.00 | 0.43 x 0.88 | 1.96 | 1.92 | 2.17 | 2.08 | 1.59 | **1.619** |
| 10 | ref-archer | 2.24 | 2.30 | 1.00 | 0.43 x 0.88 | 2.18 | 1.80 | 2.22 | 2.12 | 1.43 | **1.593** |
| 11 | ref-staff | 2.46 | 2.46 | 1.00 | 0.43 x 0.88 | 1.89 | 1.89 | 1.97 | 2.20 | 1.33 | **1.593** |
| 12 | ref-drainer | 2.44 | 2.44 | 1.00 | 0.43 x 0.88 | 2.38 | 2.39 | 2.95 | 2.10 | 1.34 | **1.558** |
| 13 | ref-rocketeer | 2.54 | 2.54 | 1.00 | 0.55 x 0.90 | 2.48 | 2.30 | 2.48 | 1.90 | 1.48 | **1.521** |
| 14 | ref-bounty | 2.42 | 2.53 | 1.00 | 0.43 x 0.88 | 2.30 | 2.33 | 2.44 | 2.07 | 1.22 | **1.513** |
| 15 | ref-solar | 2.53 | 2.53 | 1.00 | 0.43 x 0.88 | 2.48 | 2.47 | 2.48 | 1.85 | 1.33 | **1.461** |
| 16 | ref-ashwick | 1.18 | 1.48 | 1.00 | 0.43 x 0.88 | 0.88 | 1.05 | 1.46 | 1.75 | 1.28 | **1.407** |
| 17 | ref-gunslinger | 2.34 | 2.34 | 1.00 | 0.43 x 0.88 | 2.31 | 1.85 | 2.31 | 1.71 | 1.27 | **1.389** |
| 18 | ref-sniper | 1.69 | 1.92 | 1.00 | 0.43 x 0.88 | 1.65 | 1.65 | 3.05 | 1.84 | 1.08 | **1.382** |
| 19 | ref-windhealer | 1.92 | 1.92 | 1.00 | 0.43 x 0.88 | 1.94 | 1.70 | 2.16 | 1.77 | 1.11 | **1.366** |
| 20 | ref-mage | 2.09 | 2.13 | 1.00 | 0.43 x 0.88 | 2.08 | 1.80 | 2.09 | 1.96 | 0.88 | **1.356** |
| 21 | ref-dolm | 2.18 | 2.42 | 1.00 | 0.55 x 0.88 | 2.10 | 1.71 | 2.39 | 1.72 | 1.09 | **1.341** |
| 22 | ref-rimewright | 2.36 | 2.50 | 1.00 | 0.43 x 0.88 | 2.29 | 1.68 | 2.42 | 1.84 | 0.91 | **1.325** |
| 23 | ref-thief | 2.32 | 2.35 | 1.00 | 0.43 x 0.88 | 2.27 | 1.82 | 2.29 | 1.68 | 0.98 | **1.292** |
| 24 | ref-tender | 1.80 | 2.36 | 1.00 | 0.43 x 0.88 | 1.78 | 1.67 | 2.35 | 1.47 | 0.89 | **1.176** |
| 25 | ref-gil | 1.61 | 1.93 | 1.00 | 0.43 x 0.88 | 1.54 | 1.54 | 1.82 | 1.15 | 0.74 | **0.994** |

Columns in metres unless noted. `match_k` for the 13 matched hunters is unchanged by this table (runtime scale is 1.00, so the on-screen sizes above are already the true ones).
