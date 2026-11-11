# Skin stretch on the starter Masks (Lace, Kael, Vex), 2026-11-11

`--stretch-check` (tools/stretch_check.gd) skins every visible mesh of a Hero's .glb through each clip and reports the
worst edge length over its rest length. Grimble's bake relaxes his skin (tools/art1/skin_relax.py: 2.2x to 5.3x per
clip, "the Grimble band"). The three starter Masks new players see (DECISIONS 11-10) are v95 swaps whose swap inputs
are not in git, so their shipped .glb is relaxed in place, the way ext/anim-skin-relax-c did Mossy, Sparkle and Sable
(its skin_relax.py commit 866ad586d is cherry-picked here unchanged, so the two branches merge clean on the tool):

    B=~/tools/blender-4.5.15-linux-x64/blender
    for h in hem kael vex; do $B -b --factory-startup --python tools/art1/skin_relax.py -- art/wardens/$h/$h.glb art/wardens/$h/$h.glb CAP_LAST=true; done

Run once, on the 0.24.5 glbs (ext/release-integ-0245 272368589, which has the pet/give/cheer clips main 0.24.4 lacks).
About 10 min each on 4 threads. Then `godot --headless --path . --import`.

## What it does
- Weights: every vertex on an edge over 1.22x in some sampled frame (every frame of every clip), and a ring round it,
  blends toward its neighbours' weights, 60 passes.
- Cuts: the triangles on edges still over 1.26x (the welds the scans fused: hands resting on thighs, forearms on the
  waist) are deleted and each hole is capped on its own side with its rim's UVs and material, 3 rounds, the last capped
  too (CAP_LAST). Triangles cut: Lace 551 + 56 + 56, Kael 383 + 59 + 59, Vex 1192 + 111 + 111 (of 13.5k / 13.7k /
  12.1k). The caps' own edges are what is left over 1.3x; `--stretch-check` holds each Hero at a CEILING (its worst,
  rounded up): archer 1.85, juggernaut 1.85, gunslinger 2.15, so a worse glb fails.
- Unchanged (checked on the .glb): every clip's name, count and length; every node's rest (anchors, FX points); the
  textures (same bytes); the bow, arrow and gun meshes (not stretched, not cut). The file is re-exported by Blender with
  v95_swap.py's settings, so clip samplers are rewritten at the same 30 fps frames.

## Result (worst edge ratio; before = 272368589, after = this branch, both `--stretch-check`)

| Hero | before worst | after worst | ceiling | clips over 5.3 before -> after |
|---|---|---|---|---|
| Lace (archer, `hem`) | 10.36 hail | 1.83 hail | 1.85 | 36 -> 0 of 51 |
| Kael (juggernaut) | 7.94 downed | 1.84 crouch_f | 1.85 | 26 -> 0 of 52 |
| Vex (gunslinger) | 7.77 cheer | 2.11 e | 2.15 | 7 -> 0 of 39 |

All three are under the bottom of the Grimble band (2.2x).

Tried and not kept: first the numpy re-weigh of the earlier attempt (ext/anim-stretch-starters 558c262d7,
`glb_reweigh.py`: rules, rips, no cuts; Lace stopped at 6.62x), then this relax on its output: Lace 2.13x with 499
triangles cut, Vex 1.84x with 1443, Kael 1.82x with 465 (Blender's measure). Not better overall, and it needs a second tool, so
the one-command relax above is what ships.

## Close-ups (GPU, `--anim-shots --close`: run and the first attack, side view at hip height)
- before: jobq 20261111-143449-00831 (main 0.24.4 glbs: same body and weights as 0.24.5, fewer clips)
- after: jobq 20261111-161204-13081 (this branch's glbs)

Both were queued behind the GPU backlog when this was written: copy their out/shots to
docs/shots/stretch-starters/{before,after}/ and look at the elbows, shoulders and hips (the caps sit where hands met
thighs and forearms met the waist) before merging. jobq 20261111-150613-07773 is the earlier attempt's re-weigh, not
this one: ignore it.

### Lace (archer, `hem`): worst 10.36 -> 1.83, 51 clips

| clip | before | after |
|---|---|---|
| hail | 10.36 | 1.83 |
| cheer | 9.79 | 1.70 |
| super | 9.23 | 1.55 |
| ult_cast | 9.22 | 1.69 |
| ult_final | 9.13 | 1.55 |
| deadeye | 9.05 | 1.43 |
| ult_nock | 8.94 | 1.47 |
| draw | 8.92 | 1.48 |
| ult_loose | 8.91 | 1.53 |
| over | 8.90 | 1.48 |
| tap | 8.90 | 1.52 |
| loose | 8.89 | 1.52 |
| perfect | 8.89 | 1.52 |
| heavy | 8.88 | 1.48 |
| heavy_wind | 8.85 | 1.48 |
| over_loose | 8.78 | 1.53 |
| fusion | 8.39 | 1.67 |
| death | 8.31 | 1.52 |
| give | 8.18 | 1.69 |
| emote | 8.15 | 1.50 |
| pet | 7.73 | 1.74 |
| roll | 7.21 | 1.64 |
| crouch_in | 6.90 | 1.49 |
| downed | 6.89 | 1.50 |
| crouch_f | 6.86 | 1.51 |
| crouch_idle | 6.85 | 1.51 |
| revive | 6.79 | 1.48 |
| crouch_out | 6.73 | 1.49 |
| run_b | 6.46 | 1.51 |
| run_l | 6.04 | 1.42 |
| run_f | 5.88 | 1.53 |
| crouch_l | 5.74 | 1.50 |
| crouch_b | 5.72 | 1.67 |
| run_r | 5.71 | 1.37 |
| crouch_r | 5.54 | 1.46 |
| flick | 5.54 | 1.34 |
| glide | 5.07 | 1.47 |
| walk_f | 4.89 | 1.23 |
| walk_l | 4.78 | 1.27 |
| fall | 4.66 | 1.53 |
| dive | 4.57 | 1.33 |
| walk_r | 4.55 | 1.26 |
| spirit | 4.52 | 1.56 |
| stance | 4.50 | 1.32 |
| walk_b | 4.39 | 1.45 |
| jump | 4.30 | 1.32 |
| land | 4.18 | 1.34 |
| idle | 4.07 | 1.34 |
| hit_b | 4.06 | 1.34 |
| hit_f | 4.03 | 1.34 |
| stun | 3.46 | 1.31 |

### Kael (juggernaut): worst 7.94 -> 1.84, 52 clips

| clip | before | after |
|---|---|---|
| downed | 7.94 | 1.43 |
| revive | 7.93 | 1.44 |
| glide | 7.75 | 1.44 |
| death | 7.57 | 1.74 |
| fusion | 7.45 | 1.60 |
| chain | 7.23 | 1.39 |
| riposte | 7.18 | 1.49 |
| dash | 7.16 | 1.55 |
| cheer | 6.94 | 1.43 |
| haul_wind | 6.90 | 1.45 |
| reel | 6.90 | 1.35 |
| emote | 6.89 | 1.42 |
| slam | 6.82 | 1.40 |
| meteor_land | 6.75 | 1.48 |
| lunge_wind | 6.70 | 1.40 |
| lunge | 6.67 | 1.40 |
| spin | 6.67 | 1.42 |
| chainlunge | 6.58 | 1.43 |
| stance | 6.47 | 1.32 |
| haulslam | 6.20 | 1.47 |
| slash_r | 6.20 | 1.60 |
| slash_l | 6.12 | 1.73 |
| wave | 5.97 | 1.68 |
| meteor | 5.60 | 1.48 |
| idle | 5.48 | 1.31 |
| run_l | 5.33 | 1.57 |
| hit_b | 5.26 | 1.38 |
| roar | 5.19 | 1.42 |
| jump | 5.11 | 1.44 |
| give | 4.90 | 1.53 |
| pet | 4.90 | 1.53 |
| land | 4.87 | 1.50 |
| crouch_f | 4.86 | 1.84 |
| wave_wind | 4.85 | 1.68 |
| guard | 4.79 | 1.41 |
| walk_l | 4.74 | 1.52 |
| crouch_idle | 4.70 | 1.50 |
| crouch_in | 4.70 | 1.51 |
| crouch_out | 4.70 | 1.50 |
| run_r | 4.66 | 1.53 |
| run_f | 4.61 | 1.51 |
| walk_f | 4.52 | 1.49 |
| exdash | 4.48 | 1.45 |
| run_b | 4.48 | 1.77 |
| walk_r | 4.40 | 1.49 |
| crouch_l | 4.28 | 1.63 |
| hit_f | 4.21 | 1.47 |
| fall | 4.20 | 1.35 |
| stun | 3.97 | 1.59 |
| crouch_b | 3.95 | 1.82 |
| walk_b | 3.88 | 1.69 |
| crouch_r | 3.37 | 1.52 |

### Vex (gunslinger): worst 7.77 -> 2.11, 39 clips

| clip | before | after |
|---|---|---|
| cheer | 7.77 | 1.85 |
| glide | 7.59 | 1.56 |
| pet | 6.26 | 1.97 |
| fusion | 6.24 | 1.73 |
| run_f | 5.66 | 1.53 |
| e | 5.46 | 2.11 |
| run_l | 5.46 | 1.38 |
| give | 5.17 | 1.78 |
| x | 5.05 | 1.57 |
| stance | 5.03 | 1.34 |
| run_r | 4.90 | 1.56 |
| emote | 4.84 | 1.38 |
| fall | 4.81 | 1.66 |
| run_b | 4.77 | 1.48 |
| crouch_l | 4.63 | 1.51 |
| crouch_r | 4.60 | 1.52 |
| crouch_f | 4.55 | 1.57 |
| crouch_b | 4.53 | 1.57 |
| dash | 4.41 | 1.48 |
| walk_l | 4.21 | 1.34 |
| revive | 4.15 | 1.45 |
| crouch_idle | 4.08 | 1.56 |
| crouch_in | 4.08 | 1.62 |
| crouch_out | 4.08 | 1.56 |
| hit_b | 4.05 | 1.51 |
| walk_f | 3.91 | 1.38 |
| walk_b | 3.81 | 1.40 |
| dash_ex | 3.80 | 1.56 |
| walk_r | 3.74 | 1.34 |
| hit_f | 3.65 | 1.44 |
| rmb | 3.58 | 1.69 |
| land | 3.48 | 1.49 |
| death | 3.43 | 1.46 |
| stun | 3.24 | 1.37 |
| downed | 3.22 | 1.49 |
| jump | 3.06 | 1.41 |
| lmb | 2.74 | 1.43 |
| idle | 2.49 | 1.20 |
| knock | 2.46 | 1.36 |
