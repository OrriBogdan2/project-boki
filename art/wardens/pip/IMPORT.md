# Pip / Meeko (tender): import note, v95 swap of Meeko appeal3, body b (2026-11-10)

`pip.glb`: the owner's pick (11-10), Meeko v95 r2 appeal3 `cand_b.glb` (the appeal3 face; body widened 7% at the torso and
hips), swapped onto Pip's own skeleton, 45 clips and anchors by `tools/art1/v95_swap.py` (docs/art/wardens/V95_SWAP.md) with
`art/wardens/src/pip_v95.json`, then the sun and raincloud put back by `tools/art1/pip_companions.py`. Raw files in
~/meshy/v95/Meeko/r2/appeal3 (never in git); the spec reads `meeko_v95_b_body.glb`: `cand_b.glb`'s body (`Mesh_0`) and its
two back wings (`model_part0`, `model_part5`), without the master's own sun and cloud (the game's are pip_companions.py's).

    B=~/tools/blender-4.5.15-linux-x64/blender
    $B -b --factory-startup --python tools/art1/v95_swap.py -- art/wardens/src/pip_v95.json WORK WORK/pip_swap.glb
    $B -b --factory-startup --python tools/art1/pip_companions.py -- WORK/pip_swap.glb art/wardens/pip/pip.glb art/wardens/pip/pip_faces.png

The crouch clips were re-baked into this glb on 11-11 (`blender -b --python tools/art1/pip_clips.py -- art/wardens/pip/pip.glb
OUT.glb crouch_idle,crouch_f,crouch_b,crouch_l,crouch_r,crouch_in,crouch_out`, then OUT.glb copied over pip.glb): the longer
TIPTOE stride that plants her sneak. The other clips, the meshes and the anchors come through unchanged.

14,293 triangles: the body 13k (head 4.4k) on one 2048 atlas (Godot extracts it to `pip_atlas.jpg`), the companions 1.3k on
flat colours and the 2048x1024 face atlas (`pip_faces.png`, unchanged). Materials: skin-atlas, skin-face-atlas (the head box:
warden_look's `skin-face` look), cloth-atlas (the wings, the capelet), leather-atlas (satchel, strap, pouch), brass-atlas
(the goggles), then cloth-sun, skin-cloud, ice-drop, eyes-mood_sun, eyes-mood_cloud.
Weights: bone heat from the spec's joints; the tail rides `tail` whole, each wing `wing.R`/`wing.L` (their keyed flutter),
the satchel and pouch `hips`, the head box `head`, the ear tips `ear.R`/`ear.L`. The arms stretch to the rig's arm length.

Lost from the v2 build (scans plus scripted arms, hands, lids and wings: replaced, not merged): the lids (blinks no longer
show; `lid` bones move nothing), the emission layers (the constellations are paint now; PipStars.pulse finds no emission
and stays still), the normal maps, and the alpha-card wings (the master's wings are solid: the opaque cloth slot, since the
card shader draws no depth and the baked atlas has no alpha). `jaw`, `apron`, `skirt`, the spring_tail, spring_capeback and
spring_wing chains and `fingers.L`/`thumb.L` carry no weight. The old textures (body/face colour, normal, emission, wing
atlas) are gone with it. `pip_fit.json`, `pip_bake.json`, `pip_recipe.json` belong to older pipelines.

Stretch: skin_relax ran with `CUTS` 0 (relax only, no cut-and-cap holes, like the other v95 swaps), so
`--stretch-check --wardens=tender` flags every clip over 1.3x (worst 6.2x in flare, idle 2.7x, run_f 4.9x; mostly
hips>hips at the belly and thighs, then head and upper_arm.R). The shots show no tear or clip at idle and run.

Rig unchanged (tender.json body: legs 0.98, torso 1.02, shoulder 1.12, neck -0.036; size 0.68, hit_r 0.34).
- **Companions (pip_v2/meeko_v2_companions_sheet):** the sun floats at her left shoulder (skinned to pauldron.L) and the raincloud at her right (pauldron.R), both rigid and thick (the sun 0.62 as deep as wide, the cloud 0.46), replacing the hand-held star lantern. The lantern's faces are gone from the body mesh; its spring_hanglantern bones stay (the shared armature). The FX points weapon_muzzle, anchor_hang_lantern and anchor_lantern_top (names kept) ride the sun on pauldron.L; `"skinned_weapon": true`, `blade` on anchor_lantern_top and weapon_muzzle with bone pauldron.L.
- **Orbit (runtime):** in the game the companions do not ride the pauldrons. At load scripts/heroes/warden_companions.gd cuts their surfaces (cloth-sun, skin-cloud, ice-drop, the two eyes-mood) out of the body mesh into one unskinned MeshInstance3D each, and every frame floats them round her on a mostly horizontal ellipse, 180 degrees apart, with a small Y bob at its own frequency and a slow ease behind her when she moves; the sun's FX points follow it. All numbers: content/rules/warden_anim/pip.json "companions". Checked by `--meeko-orbit-check`; frames by `--meeko-orbit-shots`. No re-bake: a rebuilt GLB with the same material names works unchanged.
  `pip_companions.py` edits the old glb in place (the clips, rig and body untouched; 30 fps, each clip's last key kept): `blender -b --factory-startup --python tools/art1/pip_companions.py -- <old pip.glb> art/wardens/pip/pip.glb <faces.png>`.
- **Expressions:** 8 faces drawn into one atlas, a decal patch on each companion's front: the sun happy / laugh / grumpy / sleep, the cloud shy / happy / sleep / cry. The game swaps cells (shaders/warden_mood_atlas.gdshader, WardenMood `faces`), driven by warden_anim/pip.json "mood": calm (sun happy, cloud shy), happy on emotes and Meeko's own moves, grumpy / cry on a hit, asleep when downed, a blink to the sleep cell.
  FX points are empties: weapon_muzzle, anchor_hang_lantern, anchor_lantern_top, anchor_palm_L, anchor_flower, anchor_tail_tip, anchor_chest, anchor_head_top.
- **Imports:** pip.glb.import `remove_immutable_tracks=false`, `generate_lods=true`, `force_disable_compression=true`; textures VRAM compressed high quality, mipmapped, at most 2048. Normal maps through hero_toon `use_nrm` (from ext/art1-hem).
