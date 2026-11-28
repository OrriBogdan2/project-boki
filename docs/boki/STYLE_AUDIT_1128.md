# Boki 2D style audit (11-28)

Decision 11-09: ONE Boki 2D style, anchored on Vespyx + Mycroll (the projectboki.com Boki wall). This is the measured audit; **no art was regenerated**. The ranked red list below is the input for a later art round.

## What was audited

- `art/kin` holds only 3D models and textures, no 2D portraits. The Boki 2D portrait is the site hero (`img/hero/<id>.webp`, cutout_v2 set, from `bokidex/d/data.json`). All 277 site heroes were audited, one per Boki; all 88 `art/kin` folders map to one of them through the dex alias map (`in kin` column).
- Tool: `tools/boki/style_audit.py` (subject cropped, scaled to 640 px tall). Sheets: `/home/boki/gens/boki-style-1128/` (hetzner path).

## Measures (anchor values: Vespyx / Mycroll; population median)

| trait | measure | Vespyx | Mycroll | all-Boki median |
|---|---|---|---|---|
| line | outline band width, px | 3.5 | 3.9 | 2.7 |
| line | outline-to-fill contrast | 0.39 | 0.55 | 0.43 |
| line | interior edge density | 0.082 | 0.119 | 0.126 |
| shading | luminance steps | 8 | 8 | 10 |
| shading | colours covering 90% | 9 | 11 | 9 |
| palette | mean saturation | 0.36 | 0.33 | 0.31 |
| palette | 90th pct saturation | 0.43 | 0.55 | 0.45 |
| eye (proxy) | top local-contrast spot, contrast | 0.88 | 0.78 | 0.87 |
| eye (proxy) | same spot, saturation | 0.23 | 0.24 | 0.26 |

Score = distance of a metric outside the band spanned by the two anchors (widened by 0.35 x the population IQR), in IQRs. Trait = mean over its metrics, total = mean of the four traits. **Red** = total > 0.40 or any trait > 1.0; green otherwise; anchors grey. The eye number is a proxy (it finds the highest local-contrast spot); eye *style* (large glossy iris with highlight, as on both anchors) was judged by eye on the sheets: the top reds mostly have small realistic eyes or none visible.

## Result: 54 red, 221 green, 2 anchors

Red by worst trait: shade 28, palette 13, eye 8, line 5. Reds that have an `art/kin` model: 16.

## Ranked red list (worst first)

Fix first the ones marked `kin` (they ship as in-game models). Column z = score per trait; `worst` = trait to fix.

| # | Boki | kin | total | line | shade | palette | eye | worst | line px | steps | sat |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | cindermaw |  | 1.52 | 1.19 | 3.94 | 0.52 | 0.44 | shade | 0.0 | 15 | 0.47 |
| 2 | hivara | kin | 1.31 | 0.62 | 1.32 | 1.74 | 1.56 | palette | 1.7 | 17 | 0.78 |
| 3 | maracoil |  | 1.30 | 0.38 | 3.15 | 0.83 | 0.84 | shade | 2.5 | 14 | 0.57 |
| 4 | carrousteed |  | 1.03 | 1.33 | 2.52 | 0.19 | 0.08 | shade | 1.6 | 17 | 0.43 |
| 5 | cetorgan |  | 0.99 | 1.17 | 2.77 | 0.00 | 0.00 | shade | 1.8 | 17 | 0.33 |
| 6 | stormit |  | 0.95 | 0.43 | 2.57 | 0.29 | 0.52 | shade | 2.2 | 15 | 0.47 |
| 7 | glaciammoth |  | 0.92 | 0.11 | 1.19 | 1.06 | 1.33 | eye | 2.7 | 15 | 0.66 |
| 8 | crofthollow | kin | 0.78 | 0.55 | 0.90 | 0.61 | 1.08 | eye | 2.7 | 14 | 0.53 |
| 9 | strobolin | kin | 0.77 | 0.81 | 0.82 | 0.72 | 0.71 | shade | 1.6 | 14 | 0.13 |
| 10 | emberlull |  | 0.75 | 0.00 | 1.98 | 0.34 | 0.67 | shade | 4.1 | 16 | 0.52 |
| 11 | calderoise |  | 0.75 | 0.36 | 0.00 | 0.61 | 2.02 | eye | 2.2 | 9 | 0.49 |
| 12 | wayshell |  | 0.69 | 0.42 | 0.98 | 0.21 | 1.15 | eye | 2.3 | 13 | 0.48 |
| 13 | tiltster3 |  | 0.67 | 0.88 | 1.40 | 0.00 | 0.39 | shade | 2.7 | 14 | 0.32 |
| 14 | mirrolin | kin | 0.60 | 0.49 | 0.82 | 0.60 | 0.49 | shade | 2.7 | 14 | 0.14 |
| 15 | spirevark | kin | 0.58 | 0.15 | 0.77 | 0.48 | 0.93 | eye | 2.3 | 5 | 0.56 |
| 16 | cairnback | kin | 0.58 | 0.43 | 0.32 | 0.00 | 1.57 | eye | 1.8 | 11 | 0.33 |
| 17 | furnacowary |  | 0.57 | 0.50 | 0.48 | 0.92 | 0.35 | palette | 1.7 | 10 | 0.10 |
| 18 | glassolotl | kin | 0.53 | 0.50 | 1.48 | 0.15 | 0.00 | shade | 3.1 | 13 | 0.23 |
| 19 | aurostag |  | 0.53 | 0.40 | 0.73 | 0.15 | 0.83 | eye | 5.1 | 6 | 0.46 |
| 20 | chandelotl |  | 0.51 | 0.55 | 1.40 | 0.07 | 0.00 | shade | 2.4 | 14 | 0.26 |
| 21 | tesselamb |  | 0.51 | 0.66 | 0.66 | 0.44 | 0.27 | line | 2.1 | 13 | 0.19 |
| 22 | wickapi |  | 0.50 | 0.08 | 0.65 | 0.95 | 0.33 | palette | 3.7 | 5 | 0.12 |
| 23 | blotlet |  | 0.49 | 0.26 | 1.23 | 0.00 | 0.48 | shade | 4.6 | 3 | 0.32 |
| 24 | pinster |  | 0.49 | 0.81 | 0.99 | 0.00 | 0.17 | shade | 6.1 | 15 | 0.31 |
| 25 | skidlet |  | 0.49 | 0.00 | 0.90 | 0.73 | 0.34 | shade | 3.4 | 5 | 0.17 |
| 26 | chainipede |  | 0.49 | 0.87 | 0.32 | 0.78 | 0.00 | line | 1.6 | 11 | 0.12 |
| 27 | blastopuff |  | 0.49 | 0.43 | 1.48 | 0.05 | 0.00 | shade | 1.8 | 13 | 0.31 |
| 28 | bonsolith |  | 0.48 | 0.47 | 0.32 | 0.73 | 0.40 | palette | 2.7 | 11 | 0.14 |
| 29 | canopony |  | 0.46 | 0.66 | 1.19 | 0.00 | 0.00 | shade | 1.8 | 12 | 0.32 |
| 30 | mortarfly |  | 0.46 | 0.96 | 0.82 | 0.00 | 0.07 | line | 2.1 | 14 | 0.32 |
| 31 | sphinxblight |  | 0.46 | 0.40 | 0.00 | 0.97 | 0.46 | palette | 1.7 | 8 | 0.59 |
| 32 | bullpole |  | 0.45 | 0.49 | 0.07 | 0.89 | 0.35 | palette | 6.4 | 9 | 0.62 |
| 33 | lodestaff | kin | 0.45 | 0.44 | 0.32 | 0.53 | 0.49 | palette | 1.7 | 7 | 0.20 |
| 34 | umbrakirin |  | 0.44 | 0.66 | 0.82 | 0.00 | 0.28 | shade | 1.5 | 14 | 0.37 |
| 35 | glintmole | kin | 0.44 | 0.01 | 1.52 | 0.02 | 0.22 | shade | 4.2 | 14 | 0.27 |
| 36 | duskirin |  | 0.43 | 0.34 | 0.82 | 0.00 | 0.57 | shade | 1.9 | 14 | 0.35 |
| 37 | oarter |  | 0.43 | 0.17 | 0.57 | 0.00 | 0.96 | eye | 2.3 | 7 | 0.33 |
| 38 | fizzlet |  | 0.43 | 0.31 | 1.16 | 0.17 | 0.07 | shade | 2.5 | 16 | 0.23 |
| 39 | barokit |  | 0.42 | 0.48 | 0.66 | 0.14 | 0.41 | shade | 6.2 | 13 | 0.24 |
| 40 | malletary |  | 0.42 | 0.23 | 0.66 | 0.77 | 0.00 | palette | 3.4 | 13 | 0.14 |
| 41 | boltstrich | kin | 0.42 | 0.53 | 0.66 | 0.46 | 0.02 | shade | 2.3 | 13 | 0.16 |
| 42 | bellowlet |  | 0.41 | 0.30 | 0.16 | 0.77 | 0.43 | palette | 2.7 | 10 | 0.12 |
| 43 | lanceron | kin | 0.41 | 0.73 | 0.82 | 0.10 | 0.00 | shade | 2.4 | 14 | 0.25 |
| 44 | rosedart |  | 0.41 | 0.91 | 0.16 | 0.00 | 0.57 | line | 1.6 | 10 | 0.34 |
| 45 | canvastross | kin | 0.41 | 0.68 | 0.40 | 0.44 | 0.11 | line | 3.2 | 11 | 0.16 |
| 46 | lunink |  | 0.41 | 0.23 | 0.36 | 0.80 | 0.24 | palette | 4.0 | 6 | 0.14 |
| 47 | crofthorn | kin | 0.41 | 0.01 | 0.00 | 0.98 | 0.64 | palette | 2.9 | 9 | 0.63 |
| 48 | glazolm |  | 0.41 | 0.49 | 0.57 | 0.35 | 0.22 | shade | 2.5 | 12 | 0.17 |
| 49 | frigatee | kin | 0.40 | 0.32 | 0.77 | 0.12 | 0.39 | shade | 3.2 | 11 | 0.24 |
| 50 | prowyak | kin | 0.40 | 0.42 | 0.00 | 0.66 | 0.52 | palette | 1.7 | 8 | 0.15 |
| 51 | luckhop |  | 0.40 | 0.00 | 1.36 | 0.00 | 0.24 | shade | 4.3 | 13 | 0.35 |
| 52 | ghoulamari |  | 0.40 | 0.30 | 0.00 | 1.24 | 0.05 | palette | 2.4 | 9 | 0.68 |
| 53 | scoopsy |  | 0.39 | 0.03 | 1.19 | 0.05 | 0.30 | shade | 3.3 | 12 | 0.26 |
| 54 | mossbastion | kin | 0.29 | 0.00 | 1.07 | 0.00 | 0.08 | shade | 3.9 | 4 | 0.36 |

## Notes for the art round
- Anchors share: outline ~3.5-3.9 px (a darker tone of the fill), 8 luminance steps (flat cel shading, 2-3 tones), mid saturation (0.33-0.36), big glossy eyes with a highlight.
- Reds cluster at the painterly end: 13-17 luminance steps, near-black or no outline, small realistic eyes. Fix means a masked style pass per the PLAYBOOK (keep the design, pose and colours), never a recolour.
- Borderline: the last ~10 reds sit just over the line (total 0.39-0.45) or are red on one trait only (mossbastion: flat 4-step shading, total 0.29); judge those on the sheets before spending a round. Pale or dark species (kerchick, strobolin) can score off on palette alone while looking on-style.
- Weak greens worth a look: morelossus, kitlet (see `green_closest_first_p17.png`).
- Sheets: `red_ranked_pNN.png` (worst first), `green_closest_first_pNN.png`, `overview_all_worst_last.png`; border green = on-style, red = off, grey = anchor.
