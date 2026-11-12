# Look ahead (the held far look)

Status: built (`scripts/match/scout_look.gd`, `CamRig` in `scripts/match/cam.gd`). Numbers: `content/rules/camera.json` "scout".

## What it does
Hold **Look ahead** (action `scout`, C by default; rebind in Settings > Controls > Moving):
- **Camera:** the view eases out toward the cursor, as far as the screen has room for with you (feet and head)
  still `lean_edge_m` inside the edge (`CamRig.scout_to`, the same room the cursor lean and an aimed cast use).
  Across a 1080p screen at the default style that is about 10 m (the cursor lean stops at 7.5 m). No zoom change.
  A cursor on you (under 0.5 m) gives it no way to look. Release eases back.
- **Sight:** while held you see x1.25 further inside a 30 degree cone along your aim (`ScoutLook.sight_mul` in
  `Match.sees`; it stacks with the sneak bonus). The lit wedge (`vis_scout`, shaders/vis.gdshaderinc) grows with the
  camera ease. The hold rides the hunter flags (`ScoutLook.BIT`, bit 25), so teammates share the longer sight online.
- **Walking:** unchanged. Bots never use it.

## Numbers and where they come from
| Rule | Value | Source |
|---|---|---|
| Sight in the cone | x1.25 | reference data |
| Cone | 30 deg | reference data |
| Walking speed | unchanged | the data gives no slow for it |
| Ease out (90%) | 0.35 s | our estimate: no reference footage of the hold was available to measure |
| Ease back (90%) | 0.25 s | our estimate, as above |
| Key | C | the data names no key; Mouse 4 is taken (a second glide button), C is free in a match (Details is home only) |

## Checks
`--scout-cam-check` (distance, ease, cone, walk, key); `--scout-cam-shots --shots-dir=<dir>` (GPU: off, held, just released).
