## Match the reference: lens, start arm, plates (11-26, `--ref-parity-shots`)

Owner 11-26: copy the reference's health bars, sizing and camera more accurately. Built on the hunter x1.10 size
(`1125-hunter-scale-110.md`) and the camera parity wheel (`1125-camera-parity.md`). Measured at 1920x1080, match start
(default style, the wheel's start notch), all 13 hunters, with `--ref-parity-shots` (prints REFCAM / REFH / REFHUD /
REFMEAN rows; `--stills` saves Kael, Vex, Motley and Neve with a squad mate and a Grimble rival beside them).

| Item | Reference | Before | After |
|---|---|---|---|
| Pitch | 66 deg | 66 | 66 |
| Lens (vertical at 16:9) | 35.3 (59 horizontal) | 32 | 35.3 |
| Arm at the start notch | 30.2 m | 33.5 m (23 x 1.4572, stretched to show the same ground through a narrower lens) | 30.2 m (23 x 1.3130) |
| Ground across at the focus | 34.2 m (data), ~34.4 (footage) | 34.2 | 34.2 |
| px per metre at the feet, 1080p | ~56 | 55.3 | 55.2 |
| Hunter height, mean of 13, 1080p | ~107 (one 1.76 m capsule) | 104 (72..160) | 104 (72..161) |
| Plate width (frame), 1080p | ~150 px (7.8%) | rivals 120, yours 168 | 150 for everyone |
| Plate health fill | yellow you / squad, red rivals | green you, blue squad, red rivals | yellow you / squad, red rivals |
| Level badge | left | left | left |
| Health per segment | fixed | 17 (doubles past 12 segments) | unchanged |
| Health numbers | "1,844 / 1,844" | "1844 / 1844" | "1,844 / 1,844" (`HudStyle.num`) |

- **Wheel:** the factors are now the data's arm over our 23 m (1 m of the data's arm = 1 m of ours): min 0.8783,
  max 1.3130, step 0.1087 (four notches of 2.5 m), the glider's +5.81 m and the abyss ramp +0.5..+15 m as the data has
  them. Ctrl's look keeps its factor (1.5372), the same 52.5 m of ground it showed. The farm range and its camera are
  untouched; the home keeps its framing (it divides by `style_across`).
- **Hunter size:** the lens change keeps the ground across, so heights hardly move (mean 104 px, in the 100-112 target);
  `match_hunter_scale` stays 1.10. A 1.13 would centre the mean on 107 but moves every #985 clearance for 3%.
- **Plates:** the loadout icons (`GripOverhead`, out of fights) moved from under the plate, where they sat on heads,
  to over the name (`HudStyle.PLATE_ICON_ROW` -38). Colour-vision palettes have no `plate_mate` and keep their own you /
  squad colours on the plates (a yellow next to the red-green palette's orange rivals would not read).
- **Plate clearance** (fix after the visual review): every plate (yours, squad, rival) hangs `HudPlate.CLEAR_M` = 1.5 m over
  the hunter's measured top (was 0.6 m, about 14 px at the start notch under a 25 px frame, so plates sat in heads).
  `body.top_h` was re-measured from the 13 in-game meshes at the x1.10 size (`--ref-parity-shots` prints it as
  `top_h`; Kael 1.52 -> 1.82, Grimble 2.70 -> 2.37, Gil 1.92 -> 1.32, Tender 1.38 -> 1.08, the rest within 0.03).
  `--hunter-zone-check` now asks for 8 px of air for all 13 (was 0). `HunterZone.PLATE_UP` 2.7 -> 3.2 so the camera's
  HUD keep-out matches the taller plates.
- **Bottom-centre labels:** the 8 px "through you" line over the C slot is gone (the order label already says DOWN / FUSED);
  the order (RETURN, FOLLOW...) and CARRY ON / OFF lines over the G slot are 14 px (`BokiHud.LABEL_PX`).
- **Check bands** (measured targets, not loosened): `source.fov_deg` 25..34 (footage estimate) -> 35.0..35.6 (the data);
  new `source.start_arm_m` 30.0..30.4 (`--cam-framing-check`); `--cam-zoom-check` pins the 30.2 m start arm, the 5.81 m
  glide and the data's abyss metres; `--move-feel-check` `view_across_m` 22..25 m at zoom 1 (no longer the view anyone
  plays at) -> 34.0..34.4 at the start notch, and `source_view_across_m` now reads the source_scale style's own lens
  (it used the default's: the lens change would have moved it with no change to that style).
- **Not matched:** the self HUD layout (portrait flush in the corner at x 0-12%, y 78-100%; the health bar with its
  numbers under it at y ~92%; ability squares at x 14-26%, y 91-96%; squad rows at y 37% / 44%). Ours keeps the safe-area
  margin and the vitals block's order (numbers over the bar, abilities under it): portrait x 6-15%, y 74-93%, bar
  x 16-41%, y 78-81%, abilities x 16-29%, y 85-93%. Moving them is a HUD layout change with its own checks
  (`--hud-groups-check`, SafeArea, the camera's HUD keep-out).
