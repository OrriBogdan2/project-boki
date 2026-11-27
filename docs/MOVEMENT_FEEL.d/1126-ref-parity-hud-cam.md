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
- **Plate clearance** (second visual review, 11-27): a fixed height up the body axis (the old `CLEAR_M` over `top_h`)
  cleared your own plate but put squad and rival plates up to 28 px into heads: a crown reads higher on screen when
  the hunter stands lower in the view (nearer the camera) or turns away from it, and idle squash moves it ~5%. Now
  `HudPlate.screen_at` anchors every plate (yours, squad, rival) in screen px: never lower than the body's crown as
  drawn (`HudPlate.top_y`: `body.crown`, a point in the model's own space, through the model's live transform, so it
  turns, leans and squashes with the body) minus the plate's 21.5 px hang (frame + level badge) and `AIR` 6 px
  (9 px at 1080p). `body.crown` replaces `top_h` and is fitted by `--ref-parity-shots --plates` (headless): the hero
  and six copies as mates and rivals out to the view's sides, top and bottom, each at 8 headings; the crown is the
  top fifth of the body's height (head, hair, horns, back props; an arm or weapon reaching out lower down does not
  count). Result, 13 hunters x 7 spots x 8 headings: worst gap 8 px, most 9-30 px (REFGAP rows);
  `--hunter-zone-check` asks 8 px at 5 spots x 8 headings (worst 9).
- **Bottom-centre labels:** the 8 px "through you" line over the C slot is gone (the order label already says DOWN / FUSED);
  the order (RETURN, FOLLOW...) and CARRY ON / OFF lines over the G slot are 14 px (`BokiHud.LABEL_PX`).
- **Check bands** (measured targets, not loosened): `source.fov_deg` 25..34 (footage estimate) -> 35.0..35.6 (the data);
  new `source.start_arm_m` 30.0..30.4 (`--cam-framing-check`); `--cam-zoom-check` pins the 30.2 m start arm, the 5.81 m
  glide and the data's abyss metres; `--move-feel-check` `view_across_m` 22..25 m at zoom 1 (no longer the view anyone
  plays at) -> 34.0..34.4 at the start notch, and `source_view_across_m` now reads the source_scale style's own lens
  (it used the default's: the lens change would have moved it with no change to that style).
- **Self HUD layout** (11-27, `HudVitals`, `Hud._draw_abilities`): the reference's order. The portrait (80 x 92 px at
  1280 x 720, about the reference bust) sits in the bottom-left corner with the XP tracker on its top edge; under it the
  health bar (154 px, the reference's 230 of 1920) with the armour strip over it; health "1,844 / 1,844" under the bar
  with the armour number at its right; the resource bar and crowd-control line under that; the ability row to the right
  of the bars, its bottom level with theirs. Before: the bars beside the portrait (318 px), numbers over the bar, the
  ability row under it. The block is 148 px tall as before (portrait 92 + `HudVitals.VITALS_H` 56), so the left column
  keeps its room (`--hudref-check`: minimap growth at 130%, squad rows clear of the kin card). The tier name sits over
  the armour strip's right end, the merged form's SHELL number right of the portrait. The channel bar keeps its spot
  under the block. Still kept from before: the safe-area margin (the reference sits flush in the corner), so the
  block's left edge is at 6% and its bottom at 91%, not 1% and 97%; the squad rows stay under the minimap (the
  reference's 37% / 44% when nothing else stacks above them).
