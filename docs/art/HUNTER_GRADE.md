# Hunter and ground saturation at the match camera

The reference game's Hunters read calmer than ours: lineup measured our median saturation at 0.31 against
0.21 (bind pose). In the match the desktop grade pushed it further, to a median of 0.49 on the 13 Hunters.

## Where it came from (measured, real GPU, match camera, 13 Hunters, same spot and light)
`tools/hunter_grade_shots.gd` (`--hunter-grade-shots`, through `jobq submit --needs gpu`) swaps one setting at a time:

| setting | median Hunter saturation |
|---|---|
| live (grade 1.14 x 1.65 desktop boost x 0.8 clear evening = 1.5) | 0.49 |
| grade 1.0 | 0.35 |
| no extra far-camera brightening (`far_lift` 0) | 0.47 |
| no bloom | 0.47 |
| contrast 1.0 | 0.43 |

The screen grade is the main source (about 0.14 of the 0.28 gap); the painted atlases bring the rest (bind pose 0.31).
The same grade lifts the ground (Arena ground 0.74).

## The change
`content/rules/match_grade.json` `desktop_saturation_boost`: 1.65 -> 0.75 (Look.environment `desktop_boost`; the home,
town and cards keep 1.65). Revert by setting it back to 1.65. Result: median Hunter saturation 0.22 (target
0.21 +-0.03), every Hunter's hue within 3 degrees except Albert 11 and Neve 20 (pale, low saturation).

Terrain is lower too in the one reference clip we have (ground-dominated centre of the screen: median 0.48,
lower quartile 0.33, 9 frames, a green biome), so the grade is global, not Hunters only. Ours before -> after,
median saturation of the screen centre over each biome's first island: meadow 0.61 -> 0.34, bloom 0.46 -> 0.24,
ember 0.48 -> 0.26, gloom 0.21 -> 0.11, storm 0.14 -> 0.06, frost 0.12 -> 0.06 (these three were already below the
clip; the clip shows one biome, so they are not proof either way).

Raid conditions (`RaidLook`) multiply on top of the grade (dusk 0.88, ash 0.7, night 0.62, fog 0.72), so those
matches are greyer than before: they were tuned against the old base.

## The four dark Hunters
Gap between a Hunter's brightness and the ground just outside it (edge: its outline pixels, body: all of it), clear
evening, before -> after: Vex edge -0.139 -> -0.061 body -0.171 -> -0.089; Albert -0.150 -> -0.070, -0.226 -> -0.107;
Cinder -0.144 -> -0.061, -0.188 -> -0.088; Motley -0.078 -> -0.047, -0.144 -> -0.084 (median of 13 after: -0.067,
-0.096). Done in `content/rules/warden_look.json`: `dark_lift` and `far_lift` (Cinder, Motley), a stronger
signature rim `rim_far` (Vex, Albert; Vex's body slots too).
There are no game-camera reference frames of the reference's Hunters, so the target for these four is the median of
the 13 after the grade.
