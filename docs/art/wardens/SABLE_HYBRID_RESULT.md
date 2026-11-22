# Sable hybrid rig (job 20261121-214351-a2, 11-21 EST, branch ext/sable-hybrid-rig-1121)
Candidate sheet: /home/boki/gens/hybrid-rig-Sable-v3-1121/Sable_hybrid_sheet.jpg (also docs/art/wardens/sable_hybrid_sheet.jpg)
MP4: /home/boki/gens/hybrid-rig-Sable-v3-1121/Sable_hybrid_eye_clips.mp4 (6 clips, eye level), Sable_hybrid_ingame_states.mp4 (Godot, 6 game states)
PR: draft, see gh-outbox/new-pr.md (title "Sable: hybrid Meshy rig (78k tris)"), first body line "MODEL: needs owner visual check". No READY post.

## What was done
- Master decimated to 78,000 tris (limit 80,000) before rigging. Meshy auto-rig, fingers on. Meshy bones and clip names untouched (no retarget, no rename, no merge).
- Weights re-fixed by script (tools/meshy/sable_hybrid): pistol rigid on hand, arm/coat split, coat and armpit Laplacian, wrist band, wide contact bands (hand leaving the thigh).
- Coat tails hung by gravity with floor and thigh collision, baked into Meshy's coat-bone keys (chainhang.py).
- sable_meshy.glb on the native path (warden_native.json: sable on; ryzz and tarek stay off; no other hunter's glb touched).

## Numbers
Torn frames (glbstretch.py, 15 fps, torn = 10+ spike edges), raw Meshy -> final:
| clip | torn before | torn after |
|---|---|---|
| Idle | 0% | 0% |
| walk | 67% | 0% |
| run | 89% | 0% |
| Jump run | 93% | 0% |
| Attack | 100% | 0% |
| Crouch walk | 100% | 0% |

Coat verts (coathit.py), before hang -> after hang, mean per frame:
| clip | under floor | inside legs |
|---|---|---|
| Idle | 0 -> 0 | 31.8 -> 3.9 |
| Attack | 223.6 -> 0 | 5.3 -> 9.4 |
| Jump run | 15.0 -> 0 | 71.1 -> 40.4 |
| Crouch walk | 0 -> 0 | 6.4 -> 105.6 (WORSE, 13 of 17 frames have 50+ verts in the legs) |
| walk | 0 -> 0 | 37.5 -> 2.1 |
| run | 0 -> 0 | 126.0 -> 61.0 |

Per-region score, 1-10, eye level, my own read of the real-GPU Blender frames (not a tool metric):
| head | hair | hands | arms | torso | hips | legs | feet | outfit | props | MIN |
|---|---|---|---|---|---|---|---|---|---|---|
| 8.5 | 8 | 8 | 8 | 8 | 8 | 8 | 8 | 8 | 8 | 8 |

Sheet borders: grey = live contract Sable (Godot, same camera), green = hybrid better. All six rows green: the live model tears at the coat and
hip in all six states (idle, walk, run, jump, attack, crouch).

## Renders
Real GPU (jobq --needs gpu): Blender game, eye and knee views, 8 frames x 6 clips (3 jobs, RTX 4090); Godot in-game states (--clip-shots --warden=thief --states, game camera and side camera); live baseline, same Godot path on main.

## Not done / open
- 8 of the 11 game clips have no hybrid version. The hybrid has the 6 Meshy clips (idle walk run jump attack crouch). fall, land, glide, climb, mantle, hit, emote, aim_twist have no Meshy clip, and retargeting is forbidden, so they were not rendered for the hybrid. (The live model has them; I rendered the live ones as the baseline.)
- Crouch coat-in-legs is worse after the hang (above). Needs a chainhang.py tune.
- `--warden-glb-check`: 1 FAIL, gil "own look" (0 values). Not Sable, not from this diff; I did not check it against main.
- health.py --strict fails on the style ratchet in files I did not touch. ruff is not installed, so the new Python files are not ruff-formatted.
- Meshy credits used: rig 5 + animate 12.
- Jump row frame 1 in the Blender eye sheet has the figure partly out of frame (camera, not the model).

LESSON: glbstretch.py welds vertices by position, so unwelding the mesh does not change it. Do not try to game it. A hand fused to the thigh in the mesh needs wide contact-band weight smoothing, not a vertex split.
LESSON: after `godot --headless --import` in a fresh worktree, check that .import files exist. clip_shots takes the arch id (sable = thief), not the art name.
