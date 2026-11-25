## Match Hunters 10% bigger (`match_hunter_scale`, 11-25)

Owner call from the pitch refilm: at the 66 degree pitch our Hunters read about 88 px tall at 1080p against about
107 px in the reference game (-18%). `content/rules/camera.json` `match_hunter_scale` (1.10) multiplies the match's
drawn size: `Hunter.VIS_SCALE` is now 1.12 x it (1.232), and the camera style's `hunter_scale` still stacks on top.
Visual only: hit radius, hurtbox heights, speeds and ranges keep their size, and the farm, Model Room and Bokidex
never read it. What follows the scale:
- Overhead plates, hover plates, emote bubbles and the HunterZone / CamRig plate lean read their anchor in metres
  times `match_hunter_scale` (`Hud._head`, `HunterZone.rect_of`, `CamRig`), so a plate keeps its gap over the head.
- Meshy-native run/walk/crouch clips take the longer stride (`WardenNative._stride_k`: the keyed speeds were measured
  at the old 1.12), so `--foot-slide-check` stays at its 11 old fails; weapon, glider and VFX that hang on the model
  scale with it.
- The `source_scale` test style's `hunter_scale` went 2.1 -> 1.91 (same 2.35x total), and
  `--move-feel-check`'s `hunter_screen_pct` band moved up 10% (6.0 to 7.3).

`--hunter-scale-shots --shots-dir=<dir>` (GPU) stands a Hunter on the same ground at 1.12 and at the rule's size and
prints each body's height in px at 1920x1080, with the plate's gap over the head.
