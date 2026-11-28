# Mob GLB turnaround audit (11-28)

Every `art/mobs/*/*.glb` as the game builds it, shot on a GPU worker by `--mob-turnaround-shots`
(`tools/mob_turnaround_shots.gd`) and laid out by `tools/mob_turnaround_sheet.py`: front, 3/4, side, back, then the match
camera next to a Hunter, the real wind-up tell, and the death move. Sheets: `/home/boki/gens/mob-glb-turnaround/<mob>_turnaround.png`
(border colour only: green = reads fine, red = flagged). No model was edited. Heights are the skinned rest-pose box (Hunter 2.18 m).

## Red items
| Mob | Red tile | Why |
|---|---|---|
| bl_skitter, bl_warden | whole sheet | The Blight draws only on the live island: the free views frame the island, not the monster (bl_skitter box is 0 m). Needs a follow camera on the Blight body. |
| bomber | wind-up, death | No wind-up frame was caught (the fuse tell is shorter than a slow frame); the death frame reads as idle. |
| sentinel | wind-up | No frame caught (the crystal charge is brief). |
| skitter, spitter, glimmer | death | The death move at 0.8 of its length still reads as the idle pose. |
| brute, warden | death | Same arms-up pose as the wind-up: no collapse reads. |
| brute, warden | match | Scale: brute 2.26 m = 1.04 H (spec elite 1.15 to 1.3 H), warden 3.39 m = 1.55 H (spec champion 1.7 H and up). |
| brood, serpent | match | The match camera frame misses the boss (a lair wall fills it). |
| colossus | all four views | Speckled dark pits along the silhouette and texture seams on the stone. |
| serpent | side | Near-black body with a thin profile: the shape does not read. |

Green: skitter, spitter, bomber, glimmer, brute, warden, sentinel four views; spitter, skitter, brute, warden, colossus, brood, serpent wind-ups; boss deaths.
Normals and holes: no flipped normals or open holes seen in the 12 meshes at 512 px; colossus and serpent show the texture noise above.
The sentinel's body colour changes per island region (BiomeRun repaint): green here.

## Re-run
`jobq submit --tree <tree> --needs gpu --out shots -- --mob-turnaround-shots --shots-dir=shots [--kinds=a,b]`, then
`python3 tools/mob_turnaround_sheet.py shots out flags.tsv`.
