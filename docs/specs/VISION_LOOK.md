# Sight wedge: how it looks (SPEC)

The owner's private reference (a match frame, kept off the repo) shows a wide lit wedge in front of a crouched
player with a soft cyan line on each side; everything else is a dim blue where the ground still reads and rivals
are hidden. This page holds the numbers measured from that frame and the numbers we use. Rule: `Match.sees`
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
| Wedge sides on screen | left side 18 deg above level, right side 23 deg below: ~185 deg of screen | 170 deg on the ground (`VIEW_COS` 0.087, `VIS_COS`) |
| Wedge at the player | the line runs straight through the player, no lit circle behind | 2.0 m lit circle (`NEAR_SENSE`, `VIS_NEAR`; was 3.2) |
| Edge line | ~3 px solid core, cyan peak about (45, 138, 180) on dim ground | `VIS_LINE` (0.32, 0.86, 1.0), solid to 0.0175 m and gone at 0.035 m (~3 px solid at 82 px/m) |
| Edge glow | 4-6 px into the lit side, none on the dim side | lit side only, 0.45 strength, 1/e at 0.083 m (~7 px) |
| Lit ground | about (78-89, 105-121, 157-174), luma ~105 | the ground's own colour x 1.05 |
| Dim ground (behind and out of range) | about (2-7, 34-37, 76-79), luma ~30-37: ~0.35 of lit; hue R:G:B ~0.02:0.47:1 | 75% toward a blue with little red (luma x 0.2, 0.75, 1.3), x `vis_dark` 0.7 (`RaidLook.VIS_DARK` clear; other weathers x7/6, ratios kept). GPU, clear, warm ground lit (212, 151, 141) luma 168: dim (21, 69, 150), luma 64, ~0.38 of lit, R:G:B 0.14:0.46:1 |
| Range circle | lit area ends ~520-550 px out; an ally marker labelled 27 m sits ~600 px out: ~22 px/m, circle ~23-25 m | `VIEW_RANGE` 24 m, soft edge over the last 3 m |
| Camera scale | ~22 px/m (~87 m of ground across: the sneak camera, zoomed out) | 82 px/m standing (23.5 m across), 56 px/m crouched (zoom 1.45) |
| Rival hiding in a bush | no plate, only a faint name tag on your own | rivals crouched / in grass / in smoke: no plate (name, level, bars, gloves) and no hover card; revealed, downed and teammates keep theirs |
| HUD | unchanged by hiding | unchanged |
| Revealed rival (second frame) | outside the wedge, lit to ~154 px round her, gone by ~197 px (~7-9 m at ~22 px/m; radius ~8-10% of the width); no edge line, no particles | lit to 2.0 m, soft to 2.6 m (`VIS_REVEAL_R`): 164-213 px at 82 px/m, the same share of the screen; no edge line |

## Where we differ, and why
- **Dim is a blue with the red mostly gone, tuned on GPU shots.** One GPU run tried eight tints on the same
  frame (clear, warm ground). The earlier grey-blue ((0.5, 0.74, 1.12), 75%, x0.6) went purple (57, 49, 112) on warm
  ground. A deep blue ((0.10, 0.46, 0.88), 85%, x0.6) went near black navy (0, 28, 106), luma 28, with the ground
  lost. The one kept, (21, 69, 150), matches the reference's ratio to lit (~0.38 vs ~0.35) and its green-to-blue
  balance (0.46 vs 0.47) and keeps the ground's spots readable. It holds a little more red than the reference
  (0.14 vs 0.02), so the dim side doesn't read as water. Our camera sits 2.5-3.7x closer, so the dim side
  fills most of the screen. `RaidLook.VIS_DARK` still darkens it at night.
- **The range circle is off screen.** Measured in the world it is the same size as ours (24 m), but our closer
  camera shows 11.8 m (standing) or 17 m (crouched) from the centre to the side, so the circle edge only shows when
  the camera pans. Bringing it on screen at the reference's screen proportion (radius ~26% of the width) would mean
  a 6-9 m sight range, which would hide every ranged fight. Owner call if wanted.
- **A small lit circle stays behind you (2.0 m).** Someone touching your back is still seen; it is drawn as lit so
  the screen never lies about who you can see.

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
