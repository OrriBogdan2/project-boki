# Skin stretch on the starter Masks (Lace, Kael, Vex), 2026-11-11

`--stretch-check` (tools/stretch_check.gd) skins every visible mesh of a Hero's .glb through each clip and reports the
worst edge length over its rest length. Grimble's bake re-weighs his skin (tools/art1/skin_relax.py `reweigh`, on
ext/grimble-stretch-v2-rebased: 2.2x to 5.3x per clip, "the Grimble band"). The three starter Masks new players see
(DECISIONS 11-10) are v95 swaps, and their swap inputs (the 60 MB masters, the swap's WORK/bake.blend) are not in git,
so the same rules run on the shipped .glb instead: **tools/art1/glb_reweigh.py**.

## What the tool does (and does not touch)
Blender reads the .glb only for the armature and its clips (the poses); the body is read from the glTF itself.
- It welds the body's seam copies (same point AND same weights: a swap `detach` cut stays open), so both copies of a
  seam vertex always get the same weights.
- `keep`: starts from the swap's own weights (bone heat, regions, smooth 12). Fresh bone heat (`heat`, reweigh's) was
  tried and was worse on all three (Lace 10.4 -> 31; the swap's regions matter).
- Rules, on the vertices of edges over `RULE_AT` in some clip (and a ring round them) only, so the parts the swap got
  right keep their weights: `part` = reweigh's keep_apart for any rig (no weight on a limb part apart from the
  vertex's own: arm vs leg, forearm vs torso); `band` = `part`, one joint per vertex, and a limb vertex shares weight
  with its bone's parent or child only within 30% of that end of the bone (no thigh weight half way down a shin). The
  rigs hang the thighs off `root`; the rules treat `hips` as their parent.
- `rip` (reweigh's): where faces of two apart parts meet (the scans fuse a hand to a thigh, a forearm to the waist),
  each side gets its own vertices. Nothing is deleted, no hole at rest.
- Then skin_relax's weight blend (no cuts) on the edges still over 1.3x, 600 passes, keeping the best state seen.
- Written back: only the body mesh's vertices, weights and triangles. Every clip's sampler data, the nodes (anchors,
  rests), the skin's inverse binds, the prop meshes (bow, arrow, sword, gun, coin) and the materials are the same
  bytes as before (checked accessor by accessor). The binary is repacked: Kael's file drops from 6.6 to 3.6 MB because
  ~5.9k accessors no clip or mesh used (old copies of replaced clips) are gone.

Run (each on the swap's output, i.e. the .glb of origin/main before this change, not on its own output):

    B=~/tools/blender-4.5.15-linux-x64/blender; G=tools/art1/glb_reweigh.py
    LIMIT=1.3 RIP=1 RULE=part RULE_AT=4 LEGS_APART=1 $B -b --factory-startup --python $G -- IN/hem.glb  art/wardens/hem/hem.glb   keep 600
    LIMIT=1.3 RIP=1 RULE=band RULE_AT=4 LEGS_APART=0 $B -b --factory-startup --python $G -- IN/kael.glb art/wardens/kael/kael.glb keep 600
    LIMIT=1.3 RIP=1 RULE=band RULE_AT=0 LEGS_APART=1 $B -b --factory-startup --python $G -- IN/vex.glb  art/wardens/vex/vex.glb   keep 600

then `godot --headless --path . --import` and `-- --stretch-check --wardens=archer,juggernaut,gunslinger`. Each
setting was the best of 3 to 6 tried per Hero on all clips (others: `part1`, `strict`, `near`, `armnear`, `partband`,
`heat`; logs not kept). ~10 min each on 6 cores.

## Result (worst edge ratio per clip; before = origin/main 88b06b9e7, after = `--stretch-check` on this branch)

| Hero | before worst | after worst | clips over 5.3 before -> after |
|---|---|---|---|
| Kael (juggernaut) | 7.94 downed | 4.81 haul_wind | 25 -> 0 of 49 |
| Vex (gunslinger) | 7.59 glide | 5.18 x | 5 -> 0 of 36 |
| Lace (archer, `hem`) | 10.36 hail | 6.62 draw | 33 -> 17 of 48 |

Kael and Vex are inside the Grimble band. **Lace is not**: her bow arm. The 17 clips over 5.3 are her archery clips
(draw, tap, loose, hail, ult_*), all at the right inner elbow, where the swap's weights mix hips and upper arm on
elbow vertices (her arm hangs against the waist at rest). Cutting the hips weight there (`band` on the arms,
`armnear`) moved the tear to the shoulder (9 to 21x), and her shoulder verts also carry hair (`head`) weight. Next:
re-run v95_swap for her with an `except_segs` round the right forearm in the hips region (the bake inputs are on
hetzner: ~/meshy/v95/lace/r2/appeal3/lace_v95_b_body.glb), then this tool.
Vex's trade: her worst falls 7.59 -> 5.18 but 16 lighter clips rise (lmb 2.74 -> 3.96, rmb 3.58 -> 5.01, crouch
4.1 -> 4.7), all under 5.3; `part` instead keeps those but leaves glide/crouch at 6.5.
The clip timing and the props are untouched (same bytes); the gun, bow and sword are separate meshes and not re-weighed.
The before column is measured in Blender on main's .glb (the same maths; it matches the check's numbers on every clip
the two share); the first `--stretch-check` here read a stale import of Vex with three garden clips that main's
vex.glb does not have (cheer 7.77, give, pet), so its table is not used.

Close-ups (GPU, `--anim-shots --close`: run and the first attack, side view at hip height), before and after:
jobq 20261111-143449-00831 (before, main glbs) and 20261111-150613-07773 (after, c0cbf72da), queued behind ~130 GPU jobs when this was written: copy their out/ to docs/shots/stretch-starters/{before,after}/.

### hem (archer): worst 10.36 -> 6.62, clips over 5.3: 33 -> 17 of 48

| clip | before | after |
|---|---|---|
| hail | 10.36 | 6.53 |
| super | 9.23 | 5.53 |
| ult_cast | 9.22 | 6.08 |
| ult_final | 9.13 | 5.92 |
| deadeye | 9.05 | 5.97 |
| ult_nock | 8.94 | 5.87 |
| ult_loose | 8.91 | 5.59 |
| draw | 8.91 | 6.62 |
| tap | 8.90 | 6.25 |
| over | 8.90 | 5.16 |
| loose | 8.89 | 6.38 |
| perfect | 8.89 | 6.38 |
| heavy | 8.88 | 6.20 |
| heavy_wind | 8.85 | 6.20 |
| over_loose | 8.78 | 5.35 |
| fusion | 8.39 | 5.55 |
| death | 8.31 | 5.36 |
| emote | 8.17 | 6.08 |
| roll | 7.17 | 4.94 |
| crouch_in | 6.90 | 4.80 |
| downed | 6.90 | 4.47 |
| crouch_f | 6.86 | 5.25 |
| crouch_idle | 6.85 | 4.77 |
| revive | 6.79 | 4.44 |
| crouch_out | 6.73 | 4.77 |
| run_b | 6.46 | 3.91 |
| run_l | 6.04 | 4.30 |
| run_f | 5.88 | 4.50 |
| crouch_l | 5.74 | 4.88 |
| crouch_b | 5.72 | 4.80 |
| run_r | 5.71 | 4.39 |
| crouch_r | 5.54 | 4.33 |
| flick | 5.53 | 4.49 |
| glide | 5.07 | 4.96 |
| walk_f | 4.89 | 3.63 |
| walk_l | 4.79 | 3.55 |
| fall | 4.66 | 4.66 |
| dive | 4.57 | 4.10 |
| walk_r | 4.55 | 3.34 |
| spirit | 4.52 | 3.91 |
| stance | 4.50 | 3.88 |
| walk_b | 4.39 | 3.08 |
| jump | 4.30 | 3.79 |
| land | 4.18 | 3.91 |
| idle | 4.07 | 3.93 |
| hit_b | 4.06 | 4.07 |
| hit_f | 4.03 | 4.48 (worse) |
| stun | 3.47 | 3.47 |

### kael (juggernaut): worst 7.94 -> 4.81, clips over 5.3: 25 -> 0 of 49

| clip | before | after |
|---|---|---|
| downed | 7.94 | 4.39 |
| revive | 7.93 | 4.39 |
| glide | 7.75 | 4.22 |
| death | 7.57 | 4.29 |
| fusion | 7.45 | 3.71 |
| chain | 7.23 | 3.95 |
| riposte | 7.18 | 3.48 |
| dash | 7.16 | 4.25 |
| haul_wind | 6.90 | 4.81 |
| reel | 6.90 | 4.05 |
| emote | 6.89 | 4.47 |
| slam | 6.82 | 3.76 |
| meteor_land | 6.75 | 3.60 |
| lunge_wind | 6.70 | 3.61 |
| lunge | 6.67 | 3.62 |
| spin | 6.67 | 3.90 |
| chainlunge | 6.58 | 4.07 |
| stance | 6.47 | 3.81 |
| haulslam | 6.20 | 4.80 |
| slash_r | 6.20 | 3.79 |
| slash_l | 6.12 | 3.94 |
| wave | 5.97 | 3.30 |
| meteor | 5.60 | 3.73 |
| idle | 5.48 | 3.39 |
| run_l | 5.33 | 3.44 |
| hit_b | 5.26 | 3.00 |
| roar | 5.19 | 3.41 |
| jump | 5.11 | 3.07 |
| land | 4.87 | 3.99 |
| wave_wind | 4.86 | 3.02 |
| crouch_f | 4.85 | 3.40 |
| guard | 4.79 | 2.84 |
| walk_l | 4.74 | 2.84 |
| crouch_idle | 4.70 | 3.32 |
| crouch_in | 4.70 | 3.26 |
| crouch_out | 4.70 | 3.19 |
| run_r | 4.66 | 3.91 |
| run_f | 4.61 | 3.55 |
| walk_f | 4.52 | 3.36 |
| exdash | 4.48 | 3.61 |
| run_b | 4.48 | 3.99 |
| walk_r | 4.40 | 3.43 |
| crouch_l | 4.28 | 3.17 |
| hit_f | 4.20 | 2.77 |
| fall | 4.19 | 4.10 |
| stun | 3.97 | 3.31 |
| crouch_b | 3.95 | 3.35 |
| walk_b | 3.88 | 3.06 |
| crouch_r | 3.37 | 3.03 |

### vex (gunslinger): worst 7.59 -> 5.18, clips over 5.3: 5 -> 0 of 36

| clip | before | after |
|---|---|---|
| glide | 7.59 | 4.82 |
| fusion | 6.24 | 4.65 |
| run_f | 5.66 | 4.50 |
| e | 5.46 | 4.54 |
| run_l | 5.46 | 4.13 |
| x | 5.06 | 5.18 (worse) |
| stance | 5.02 | 2.89 |
| run_r | 4.89 | 3.96 |
| emote | 4.83 | 3.33 |
| fall | 4.81 | 4.09 |
| run_b | 4.77 | 4.35 |
| crouch_l | 4.63 | 3.81 |
| crouch_r | 4.60 | 4.24 |
| crouch_f | 4.55 | 4.72 (worse) |
| crouch_b | 4.53 | 4.41 |
| dash | 4.42 | 4.13 |
| walk_l | 4.21 | 3.81 |
| revive | 4.15 | 3.99 |
| crouch_idle | 4.08 | 4.74 (worse) |
| crouch_in | 4.08 | 4.74 (worse) |
| crouch_out | 4.08 | 4.74 (worse) |
| hit_b | 4.06 | 4.40 (worse) |
| walk_f | 3.91 | 3.86 |
| walk_b | 3.81 | 3.54 |
| dash_ex | 3.76 | 4.70 (worse) |
| walk_r | 3.74 | 3.63 |
| hit_f | 3.65 | 3.25 |
| rmb | 3.58 | 5.01 (worse) |
| land | 3.48 | 3.80 (worse) |
| death | 3.43 | 4.60 (worse) |
| stun | 3.24 | 3.62 (worse) |
| downed | 3.22 | 4.49 (worse) |
| jump | 3.06 | 3.55 (worse) |
| lmb | 2.74 | 3.96 (worse) |
| idle | 2.49 | 2.55 (worse) |
| knock | 2.46 | 3.07 (worse) |
