# Camera depth readability (job 20261107-123002-a4)

Owner feedback: height, ledges and drop depth are hard to read; Supervive reads well. Sources: the owner's
34 s mantle clip (contact sheet and frames in /home/boki/refs/supervive-mantle/), our captures from
`--depth-shots` (tools/depth_shots.gd, seed 77, GPU job), shots in briefs/camera_depth/.

## What Supervive does (from the clip)
1. **Value contrast between lit ground and everything below it.** Ground is bright and saturated (green
   or stone); the abyss and cliff faces are dark navy, a clearly lower value. The lit top reads as "up",
   the dark mass as "down".
2. **Cliff faces are dark and shaded toward their foot**, with the bright ground lip on top, so a
   drop's height is the size of the dark band.
3. **Heavy soft shadows** from walls and props fall on the ground, so height differences show as shadow.
4. Characters have a dark contact shadow; the camera is steep (about 65 deg) and narrow.

## What we already match (not the cause)
- Camera: 66 deg pitch, 32 deg FOV, calibrated from footage (cam.gd "camcal"). Pitch/FOV/zoom are not the
  gap, and changing them would move gameplay ranges, so they are left alone.
- Ground ring under the player, contact AO at terrace feet, rim light, directional shadows (high quality).

## What we lacked (before shots)
| Suspect | Finding | Cost |
|---|---|---|
| Abyss falloff | Beyond an edge is the same mid purple haze as the ground: no value drop (before_a_edge). NOT done: needs an environment/void colour change that touches every look; suggested next. | env tweak, free |
| Cliff-face contrast | Faces were only mid-toned (strata), sheer slate had no depth shading; at 66 deg faces are thin, so the drop read as a line. **Done.** | shader maths, no new draws |
| Lit cliff lip | Edge of the ground was not brighter than the field. **Done** (4 height taps on ground pixels). | shader |
| Blob shadow under characters | None; only the sun shadow (off on low/medium). A body at a ledge or airborne had no ground anchor. **Done**, DepthCues disc per hunter. | 1 quad per hunter, no allocation per frame |
| Height tint of tiers | Lower tiers are not darker (only AO at the foot). Not done: absolute y varies per island, needs per-island reference. | shader |
| Projectile drop shadows | Not done; same disc idea, one more quad per projectile. | per projectile |

## Built (setting Settings > Accessibility > Height cues, `depth_cues`, default on; applies from the next expedition)
Cliff faces: brightened at the lip, darkening toward the foot by drop height (full dark at 3.2 m).
Ground lip lit where it ends in a drop. A soft dark disc on the ground under every hunter, at the
ground's own height (hidden over void). Gameplay, camera, aim and ranges untouched.

Before/after, same seed and spot: briefs/camera_depth/{before,after}_{a_edge,b_step,c_low}.png
(a: at a cliff edge over the abyss, b: top of a terrace step with a hunter below, c: the step from below).
