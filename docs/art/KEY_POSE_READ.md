# Key-pose readability at the match camera

Question: can a Hunter's LMB, RMB, E or R be told from its silhouette at the match zoom (23 m out, 66 degrees, fov 32) before
the VFX lands? Frames: `--clip-shots --true-cam --yaw=120`, 12 fps, cropped about the Hunter, strips in `docs/art/key_pose/before_<id>.jpg`
(rows: the four slot clips, columns: even steps through the clip). Change: `docs/art/key_pose/before_after.jpg` (before row, then after row).

## Score (1 = reads as idle, 5 = direction and weapon clear)
| Hunter | LMB | RMB | E | R | Note |
|---|---|---|---|---|---|
| Vex | 4 | 4 | 4 | 4 | gun always visible; LMB and RMB look alike |
| Kael | 3 | 3 | 3 | 4 | blade hides behind the body at the strike of slash_r and chain |
| Lace | 5 | 5 | 4 | 4 | bow and arrow clear |
| Cinder | **2** | 3 | 3 | 3 | lance arm low at the hip, no strike contrast (fixed) |
| Meeko | **1** | 1 | 1 | 1 | wings cover the hands; all four clips near idle (LMB fixed, others share it) |
| Tenzo | 3 | 4 | 3 | 4 | |
| Grimble | 3 | 3 | 3 | 3 | too large for the crop, read by hand |
| Neve | 5 | 5 | **1** | n/a | E recast (`freeze`) is the idle pose (fixed) |
| Motley | 4 | 4 | 4 | 4 | |
| Albert | 3 | 4 | 3 | 4 | metric only (reach 0.76-0.93 of height) |
| Sparkle | **2** | 3 | 2 | 4 | LMB arm hidden by the torso (fixed) |
| Sable | 4 | 4 | 4 | 4 | |

Not scored by eye: Albert and Motley were only measured (reach of the hands from the hips over the clip, in heights, from the
.glb by forward kinematics). R of Neve (`rime`) and Cinder's real R were not rendered; the R column for the others uses the
clip named after the kit move (Rimelock's clip is `tm_rime*`, not `freeze`).

## Fixes (re-keyed in the .glb with `tools/art1/glb_key_pose.py`, no Blender)
Swings are eased bumps toward a model-space direction, so every other key (elbow bend, twist, hands) stays.
| Clip | Change | Hand reach, peak / contrast (heights) |
|---|---|---|
| Meeko `shot_r` | wind: casting hand pulls to the hip; strike: straight arm and the torso leans into it (source beats: hand pulled back, straight-arm push) | 0.43 / 0.12 -> 0.72 / 0.41 |
| Cinder `lance` | thrust: arm reaches along the aim, torso leans in | 0.34 / 0.12 -> 0.44 / 0.22 |
| Neve `freeze` | wind: spear lifted; strike: spear driven forward and down, lean | spear tip now leaves the body |
| Sparkle `lmb_l` | punch arm straight out, torso twists in | 0.34 / 0.15 -> 0.44 / 0.25 |

Left for later (ideas, not parity): Kael's blade at the strike; Meeko's seed, hearth and call clips (same wings-over-hands
problem, same tool); a fixed fade-out of the first frames in `--clip-shots` (some strips come out washed).
