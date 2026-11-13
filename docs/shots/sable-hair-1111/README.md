# Sable's hair in game (owner 11-11: "Sable has pink hair")

`compare.jpg`, left to right: front at the match camera pulled in (before, after), from behind (before, after),
face from the front at head height (before, after). All with the pink hair pick (PlayerLook hair_col 7), in a real
match's world and "clear evening" light. Full frames in `before/` and `after/`: `hair_7` (match camera),
`hair_7_close`, `_head` and `_braid` crops, `hair_0_*` (the dark brown pick), `face` and `face_crop`.

Shots: `godot --rendering-driver opengl3 -- --sable-hair-shots --size=1600x900 --shots-dir=<dir>` under xvfb
(tools/sable_hair_shots.gd). Before = ext/release-integ-0245 272368589 (warden_glb.gd, warden_look.json and
mantle_look.json from there); after = this branch (ext/hunter-tint-1111 + the fix).

## Cause (three layers, all lilac/pink on a white-haired Hunter)
1. The hair paint itself: her .glb atlas (appeal3 cand_b_bugeye) paints the hair lilac, mean cab3d9 under the
   hair slot (HSV h 0.77, s 0.17). The v2 turnaround (docs/art/gen/wardens/sable_turnaround.png) is white with
   cool grey shading.
2. Her look lit the hair violet: hair and fur `shadow_tint` [0.86, 0.85, 0.97], `own_ambient` [0.5, 0.51, 0.58],
   and the signature `rim_far_color` [0.62, 0.32, 1.0] mixed into the hair band at the match camera.
3. The player's hair and eye picks tinted her (MantleLook `tint` -> WardenGlb._tint, up to +-35% per channel):
   a pink pick took d8d2c8 to e6ccc2 (a pink multiply on the hair slot).

ext/hunter-tint-1111 (the amber sun) does not change Sable's hair: her hair slot already had
`light_neutral_warm` 0.8; a render of hunter-tint alone looked the same as before.

## Fix (data only)
- content/rules/warden_look.json sable: hair `desat` 0.7, fur (head plumes) `desat` 0.5, both with a cool-white
  `rim_far_color` [0.9, 0.9, 1.0] and near-neutral `shadow_tint` [0.92, 0.92, 0.96] / `own_ambient` [0.53, 0.53, 0.56].
- content/rules/mantle_look.json thief: `tint` hair and eyes `pull` 0 (no pick moves them).

## Measured (rendered braid pixels, pink pick)
| | RGB | HSV h / s / v |
|---|---|---|
| before | 0.67 0.58 0.71 | 0.78 / 0.18 / 0.71 |
| after | 0.66 0.64 0.68 | 0.74 / 0.07 / 0.68 |
| v2 ref hair | white, cool grey shade | ~0.72 / ~0.05 |

## Eyes
Solid dark grey/black in both (`face_crop.jpg`). Her .glb has no `eyes` slot (the eyes are painted on the face
sheet), so the eye pick never reached the model; pull 0 also holds them on the procedural fallback.

## Not done
The model is still appeal3 cand_b_bugeye, not the approved body5 cand_3 pick (hunter-tint README "Stale models").
Swapping the .glb needs Blender and is out of this branch's scope; the new --warden-glb-check row holds whatever
model is in to white hair.
