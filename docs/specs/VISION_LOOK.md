# Sight wedge: how it looks (SPEC)

The owner's private reference (a match frame, kept off the repo) shows a wide lit wedge in front of a crouched
player with a soft cyan line on each side; everything else is a dim blue where the ground still reads and rivals
are hidden. This page holds the numbers measured from that frame and the numbers we use. Rule: `Match.sees`
(docs/specs/VISION.md, decision 0022); look: `shaders/vis.gdshaderinc`; plates: `HudPlate.hidden`;
check: `--vision-check`; shots: `--vision-shots`.

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
| Dim ground (behind and out of range) | about (2-7, 34-37, 76-79), luma ~30: ~0.3 of lit, blue | 85% toward a deep blue with almost no red (luma x 0.10, 0.46, 0.88), x `vis_dark` 0.6 (`RaidLook.VIS_DARK`): snow map clear measured (8, 57, 110), luma ~48: ~0.25 of lit (was a grey-blue (57, 87, 125), luma ~83) |
| Range circle | lit area ends ~520-550 px out; an ally marker labelled 27 m sits ~600 px out: ~22 px/m, circle ~23-25 m | `VIEW_RANGE` 24 m, soft edge over the last 3 m |
| Camera scale | ~22 px/m (~87 m of ground across: the sneak camera, zoomed out) | 82 px/m standing (23.5 m across), 56 px/m crouched (zoom 1.45) |
| Rival hiding in a bush | no plate, only a faint name tag on your own | rivals crouched / in grass / in smoke: no plate (name, level, bars, gloves) and no hover card; revealed, downed and teammates keep theirs |
| HUD | unchanged by hiding | unchanged |

## Where we differ, and why
- **Dim follows the reference's hue: a deep blue with the red gone, not a grey-blue.** The reference's dim ground is
  about R:G:B 0.02:0.47:1; ours is about 0.07:0.52:1 (snow, clear). A brighter saturated blue read as water, so the
  blue is kept dark (luma ~48 on our brightest ground vs ~30 in the reference); the ground's own light and dark
  patches still show through. Our camera sits 2.5-3.7x closer, so the dim side fills most of the screen; the
  earlier grey-blue (~0.45 of lit) was dropped because it read as haze, not as "out of sight".
  `RaidLook.VIS_DARK` still darkens it at night.
- **The range circle is off screen.** Measured in the world it is the same size as ours (24 m), but our closer
  camera shows 11.8 m (standing) or 17 m (crouched) from the centre to the side, so the circle edge only shows when
  the camera pans. Bringing it on screen at the reference's screen proportion (radius ~26% of the width) would mean
  a 6-9 m sight range, which would hide every ranged fight. Owner call if wanted.
- **A small lit circle stays behind you (2.0 m).** Someone touching your back is still seen; it is drawn as lit so
  the screen never lies about who you can see.
