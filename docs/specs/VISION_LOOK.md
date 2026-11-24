# Sight wedge: how it looks (SPEC)

The owner's private reference (a match frame, kept off the repo) shows a wide lit wedge in front of a crouched
player with a bright line on each side (we do not draw it: owner 11-17, the cone is a soft fade, not an outline); everything else is dim where the ground still reads and rivals
are hidden (the reference's dim was blue; ours is a slight dark grey fog that keeps some of the ground's colour, in every weather: owner 11-23). This page holds the numbers measured from that frame and the numbers we use. Rule: `Match.sees`
(docs/specs/VISION.md, decision 0022); look: `shaders/vis.gdshaderinc`; plates: `HudPlate.hidden`;
check: `--vision-check`; shots: `--vision-shots`. A rival who gives herself away is lit in her own soft circle
(`RevealLight`, section "Revealed rival" below).

## How it was measured
The frame is 2000x1299 with browser and video player bars. The game area is x 0-2000, y 44-1236 (2000x1192: black bar
above, player controls below, found by row brightness). Numbers below are scaled from the game area to 1920x1080
(x * 0.96, (y - 44) * 0.906). Colours are sRGB pixels from the frame.

| What | Reference (game area, then 1920x1080) | Ours |
|---|---|---|
| Player on screen | (985, 686) -> (946, 622): 49% across, 58% down | the match camera's own framing (camera.json) |
| Wedge sides on screen | left side 18 deg above level, right side 23 deg below: ~185 deg of screen | 120 deg on the ground (`VIEW_COS` 0.5, `VIS_COS`; was 170 until 11-18, 106 before 11-12): a wide cone like the target feel, not the half-plane |
| Wedge at the player | the line runs straight through the player, no lit circle behind | 2.0 m lit circle (`NEAR_SENSE`, `VIS_NEAR`; was 3.2) |
| Edge line | ~3 px solid core, cyan peak about (45, 138, 180) on dim ground | none: a cone, not an outline (owner 11-17) |
| Edge glow | 4-6 px into the lit side, none on the dim side | none: the lit side fades out over `VIS_SOFT` (1.6 m) inside the wedge's side |
| Lit ground | about (78-89, 105-121, 157-174), luma ~105 | the ground's own colour x 1.05 |
| Dim ground (behind and out of range) | about (2-7, 34-37, 76-79), luma ~30-37: ~0.35 of lit; hue R:G:B ~0.02:0.47:1 | **a slight dark fog, partly grey, never tinted** (owner 11-23: "in between the full grey and the flat dim; slight dark fog, grey not blue"; the cone lights it up to normal): the albedo is pulled `vis_greyness` (`RaidLook.VIS_GREY` 0.55) of the way to its luma-weighted grey and scaled by `vis_dark` (`RaidLook.VIS_DARK` 0.60); the light, shadow tint and ambient are greyed by the same share, the weather haze's colour is taken out in full. GPU numbers in "Where we differ" |
| Range circle | lit area ends ~520-550 px out; an ally marker labelled 27 m sits ~600 px out: ~22 px/m, circle ~23-25 m | `VIEW_RANGE` 24 m, soft edge over the last 3 m |
| Camera scale | ~22 px/m (~87 m of ground across: the sneak camera, zoomed out) | 82 px/m standing (23.5 m across), 56 px/m crouched (zoom 1.45) |
| Rival hiding in a bush | no plate, only a faint name tag on your own | rivals crouched / in grass / in smoke: no plate (name, level, bars, gloves) and no hover card; revealed, downed and teammates keep theirs |
| HUD | unchanged by hiding | unchanged |
| Revealed rival (second frame) | outside the wedge, lit to ~154 px round her, gone by ~197 px (~7-9 m at ~22 px/m; radius ~8-10% of the width); no edge line, no particles | lit to 2.0 m, soft to 2.6 m (`VIS_REVEAL_R`): 164-213 px at 82 px/m, the same share of the screen; no edge line |

## Where we differ, and why
- **Dim is a slight dark fog, partly grey, in every weather (owner 11-23).** The 11-20 fog was a full grey (the
  fogged ground sat at 0.37-0.63 of the lit luma and 32-156 degrees of hue from it); the first 11-23 answer, a flat
  0.82 dim, was too weak to read. The owner asked for something in between: "slight dark fog", grey not blue, like
  the reference. Two tunables, both in `RaidLook` and read by `vis_apply` (`shaders/vis.gdshaderinc`):
  `VIS_DARK` (albedo scale outside sight; 1 = no dimming) and `VIS_GREY` (share of the albedo pulled to its luma;
  0 = its own colours, 1 = full grey). The light's tint, the cool shadow side and the ambient are greyed by the same share
  as the albedo; the weather haze's colour is taken out in full; the cone is untouched. Default **B** (0.60 / 0.55).

  Measured on GPU, one camera frame with the sight fog off and on (`--fog-ab-shots`, seed 5101, expedition; ground
  4-16 m from you; inside = within 40 degrees of your aim, outside = more than 80 degrees; island void skipped).
  `--vis-dark=<x> --vis-grey=<x>` try other numbers on the same frame. Luma is on/off; "R-B shift" is the change in
  (R-B)/luma of the outside ground between fog off and on (negative = less warm; a blue cast would show as an R-B
  below the fog-off frame in a warm weather):

  | Weather | Variant (dark / grey) | outside luma | (R-B)/luma, fog off -> on | hue shift | inside luma |
  |---|---|---|---|---|---|
  | clear | MAIN full grey (11-20) | 0.63 | +0.37 -> +0.02 | 51 deg | 1.04 |
  | clear | A (0.70 / 0.40) | 0.77 | +0.37 -> +0.28 | 3 deg | 1.04 |
  | clear | **B (0.60 / 0.55), default** | 0.68 | +0.37 -> +0.22 | 4 deg | 1.04 |
  | clear | C (0.50 / 0.70) | 0.57 | +0.37 -> +0.15 | 4 deg | 1.04 |
  | night | MAIN full grey (11-20) | 0.36 | -0.43 -> +0.06 | 153 deg | 0.91 |
  | night | A (0.70 / 0.40) | 0.68 | -0.42 -> -0.28 | 0.5 deg | 0.98 |
  | night | **B (0.60 / 0.55), default** | 0.57 | -0.43 -> -0.22 | 0.1 deg | 0.96 |
  | night | C (0.50 / 0.70) | 0.47 | -0.43 -> -0.12 | 4 deg | 0.94 |

  Read the R-B column as "how far the ground is from neutral": clear ground is warm (+), night ground is blue (-); the
  fog moves both toward 0 and never past it, so it adds no blue. The flat 0.82 dim that was tried first (PR head
  0430b0f) read as too weak (outside luma 0.82-0.87). A part-grey albedo under a FULLY grey light was tried and came
  out blue (clear R-B -12 of 255): the ground's own albedo is lavender and the warm sun is what makes it pink, so the
  light's tint is pulled to grey by the same `VIS_GREY` share. Sheet: `fog_inbetween_sheet.png` (same expedition frame,
  clear and night, MAIN / A / B / C); a fading tip banner in some rows is the capture time, not the fog.
  `--vision-check` accepts this look and fails on any tint: `VIS_DARK` must be 0.45-0.80 and `VIS_GREY` 0.30-0.80,
  `vis_apply` may only scale by grey numbers, and each lit world shader greys its light, shadow tint, ambient and
  haze by the fog share. The tier-0 void art around the islands is blue-violet in itself and is not part of
  the fog.

- **The cone is 120 degrees.** Shots at 100, 120 and 140 on the same frame (`--vision-shots`, sheet in the job):
  see "Cone angle" below.
- **The range circle is off screen.** Measured in the world it is the same size as ours (24 m), but our closer
  camera shows 11.8 m (standing) or 17 m (crouched) from the centre to the side, so the circle edge only shows when
  the camera pans. Bringing it on screen at the reference's screen proportion (radius ~26% of the width) would mean
  a 6-9 m sight range, which would hide every ranged fight. Owner call if wanted.
- **A small lit circle stays behind you (2.0 m).** Someone touching your back is still seen; it is drawn as lit so
  the screen never lies about who you can see.
- **A first-time line explains the dim side.** The first time a rival is hidden only by the wedge, or you swing
  your aim 120 degrees within 0.6 s and the dim area sweeps, the hint lane says "You only see enemies in front of
  you and near you" (`VisionHint`, through `Match._tips`): once per save, never with tips off or in the tutorial
  course. `--first-time-hint-check`.

## Cone angle (owner 11-18)
Real-GPU shots on the same frame (stand, crouch, reveal, scout), `--vision-shots`: main before this change (170, blue
with cyan lines) against 100, 120 and 140 degrees with the grey fog. 100 reads as a narrow beam on the closer camera
(a rival 50 degrees off your aim is already hidden); 140 is close to the old half-plane, the grey only shows a
cone-shaped bite at the sides; 120 reads as a wide cone with a clear grey behind and beside you, and keeps the
sweep-to-spot play (the rival at 165 degrees is hidden until you turn about 105 degrees). 120 is the default
(`VIEW_COS` 0.5, `VIS_COS` 0.5). To change it set both together; `--vision-check` asserts they match.

## Revealed rival
A second owner frame, 4 s later, shows a rival past the wedge's side, drawn with her own soft lit circle while she
attacks. Only the still exists (no footage on disk, and the kit notes have no reveal times), so what reveals and how
long can't be measured; the rule we already had stays and is now drawn:
- **What reveals** (`Hunter.reveal_t`): your shot or strike 1.2 s, being hit 1.0 s, a glove 0.6 s, plus every kit and
  item reveal in docs/specs/VISION.md. While it runs `Match.sees` ignores the wedge, grass and crouching (range
  `VIEW_RANGE` + 2 m, walls still block).
- **The circle** (`RevealLight`, up to three rivals, `vis_reveal0..2`): round a rival who is seen and revealed, at full
  strength until the reveal's last 0.3 s, then fading out with it. Sized from the frame by screen share, not world
  size: the reference camera is ~3.7x further out, and its 7-9 m would light half our screen.
- **Net:** nothing new. A client gets the reveal with each rival's state (flag 4096, refreshed to 0.3 s), so the
  circle follows the same sight sync.
