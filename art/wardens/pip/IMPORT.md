# Pip / Meeko (tender): import note, v95 swap of Meeko appeal3, body b (2026-11-10)

**11-13 (ext/showcase-1113):** `pip.glb` is now Meeko's current master (`~/meshy/v95/Meeko/r2/n95/best.glb`, current.json), the same recipe below on `best_nocomp.glb` (its body `Mesh_0` and wings `model_part0`/`model_part5`; the master's sun and cloud stripped). Its wings sit on their own textured material, which needed bake_warden's per-material colour bake. 14,293 tris.

`pip.glb`: the owner's pick (11-10), Meeko v95 r2 appeal3 `cand_b.glb` (the appeal3 face; body widened 7% at the torso and
hips), swapped onto Pip's own skeleton, 45 clips and anchors by `tools/art1/v95_swap.py` (docs/art/wardens/V95_SWAP.md) with
`art/wardens/src/pip_v95.json`, then the sun and raincloud put back by `tools/art1/pip_companions.py`. Raw files in
~/meshy/v95/Meeko/r2/appeal3 (never in git); the spec reads `meeko_v95_b_body.glb`: `cand_b.glb`'s body (`Mesh_0`) and its
two back wings (`model_part0`, `model_part5`), without the master's own sun and cloud (the game's are pip_companions.py's).

    B=~/tools/blender-4.5.15-linux-x64/blender
    $B -b --factory-startup --python tools/art1/v95_swap.py -- art/wardens/src/pip_v95.json WORK WORK/pip_swap.glb
    $B -b --factory-startup --python tools/art1/pip_companions.py -- WORK/pip_swap.glb art/wardens/pip/pip.glb art/wardens/pip/pip_faces.png

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
- **Imports:** pip.glb.import `remove_immutable_tracks=false`, `generate_lods=true`, `force_disable_compression=true`, `animation/fps=48` (the walk/run keys' rate); textures VRAM compressed high quality, mipmapped, at most 2048. Normal maps through hero_toon `use_nrm` (from ext/art1-hem).
- **Burrseed `seed` clip (ext/meeko-lane-picks, from ext/meeko-rmb-verify):** the release-hop `seed` (tools/art1/pip_clips.py)
  went onto this appeal3 glb Blender-free with `glb_add_clips.add`, exact name `seed` (the CLI matches by prefix and would
  also take `seed_aim`); the other 44 clips, meshes, skins and nodes are byte-identical.
  Re-applied 2026-11-14 (ext/fix-main-reds-1114) on the v95 master: the v95 swap (61515dc4fc) was built on the glb from
  before the hop went in and brought the flat `seed` back; same command, `=seed` from dd00ee939e's pip.glb.
  Merged into ext/merge-batch-10-1113 the same day: its walk/run glb with `=seed` from main's pip.glb on top (after the eight walk/run clips, re-run `=seed` the same way).
- **Paws, walk and run (2026-11-11):** the appeal3 bone heat left the heels on the shin (left) and the thigh (right);
  `tools/art1/pip_feet_weights.py` moves the 200 paw verts below the ankle onto foot.L/R (blending into the shin across
  the ankle). `tools/art1/pip_gait.py` (ext/anim-pilot-loops-cm-v2) then rebuilds the eight walk/run loops (f, b, l, r)
  on her old upper body with each stance sole pinned to a floor at loco speed, all on one 0.34 s period (16 keys at 48/s:
  0.333 s); warden_anim/pip.json `loco.cycle_s` 0.34 makes WardenClips' BlendSpace2D run them synced, so they stay in
  step at a diagonal and from the walk ring into the run ring. Her legs reach less behind and to the side, so those soles
  are down for less of the period (duty x0.8 back, x0.62 sideways: a longer float). Walk and run 5.9 steps/s, steps 0.37
  and 0.77 m; soles 2.2 and 4.55 m/s in Blender in every direction, ankle miss 0, hence `foot_mps` [2.2, 4.55] (no
  `stride` gain). Re-baked on main's v95 model (2026-11-13, ext/anim-meeko-loops-length): walk and run share one duty
  (0.25) and one heel-to-toe roll, each swing leaves and meets the floor at its speed, and the old clips' forward lean
  sits on the hips instead of the root (walk_f 7 deg, run_f 12 deg: the thighs hang from the root, so two leans put the
  hips in two places). All three keep the walk-run blend planted: --foot-slide-check worst 1.80 m/s (main's loops 2.46),
  --anim-audit run 13 % (main 12 %). At Godot's default 30 fps import the
  run's 80 ms stance kept 2 or 3 keys and the soles wobbled. Run `pip_feet_weights.py`, `pip_gait.py`, then
  `glb_add_clips.py` with the eight names (the lines at the top of pip_gait.py).

- **Idle pilot (ext/anim-pilot-four): NOT carried (2026-11-14).** The Meshy idle's tracks key `brow.R`, which main's v95 model does not have, so `glb_add_clips.py` refuses it; Meeko's `idle` stays main's.

**11-23 (ext/meeko-companions-1123): the sun and cloud of `pip_meshy.glb` (the live match model) were rebuilt.** The old ones were the
Meshy master's, cut by `native_hunters/decimate.py` to 124/164 tris: 12 px dots at the game camera, face decals sunk into the bodies,
the cloud on the tinted `skin` slot (pink on pink). Now (Blender builds, `graft_companions.py` swaps them in; the body is untouched):

    B=~/tools/blender-4.5.15-linux-x64/blender
    $B -b --factory-startup --python tools/art1/pip_companions_native.py -- WORK/comp.glb WORK/faces.png
    python3 tools/meshy/native_hunters/graft_companions.py art/wardens/pip/pip_meshy.glb art/wardens/pip/pip_meshy.glb WORK/comp.glb WORK/faces.png

Sun 0.50 m across (was 0.21), cloud 0.52 m (was 0.23), both leant back 50 deg toward the 66 deg match camera, faces 1.7x bolder
(eyes, mouth, blush, tears) on 8x8-quad patches the build asserts sit >= 2 mm off the body, the cloud on `cloth-cloud` (untinted,
inked), the sun on `glow-sun` (emissive + halo), two bigger rain drops hung clear of the cloud. 1.8k tris. WardenNative now runs
WardenMood (faces swap with her moves, blink). `pip.glb` (contract model) is not rebuilt. Orbit: radius [1.1, 1.05], trail_max 0.12,
head/wing/hand avoid spheres (`companions.avoid`; the push opens at once). Checks: `--meeko-orbit-check`, `--meeko-companions-clip-check`
(sun/cloud vs the CPU-skinned body in idle, walk, run, dash, crouch, jump, attack, ult), `--meeko-companions-shots` (GPU).

**11-24 (plan /home/boki/gens/meeko-comp-plan-1124/PLAN.md): sun and cloud bodies from Meshy, faces as the portrait.** Faceless refs of
the portrait's sun and cloud (`art/portraits/tender.jpg` crops, vertex-gen, 48 gens, raws + gen_log.tsv in
/home/boki/gens/meeko-comp-fix-1124/), then Meshy image-to-3D (meshy-7.1, 2k texture, no pose). Picked: sun `01a20cbd-4517-706a-83b8-55ae9c7a5d29`
(sun_q2_r2: a ball with 10 soft petals; its portrait-like side is Meshy's back, so `--sun-turn=180`), cloud
`01a20cb8-573a-75d8-b9fc-08eb7f29876b` (cloud_p4_r1: round lobes, smooth belly, lavender-white). Build:

    M=/home/boki/meshy/meeko-comp-1124     # (the two task folders: glb.glb + texture maps + task.json)
    $B -b --factory-startup --python tools/art1/pip_companions_native.py -- WORK/comp.glb WORK/faces.png \
        --sun-glb=$M/sun_q2_r2/glb.glb --sun-turn=180 --cloud-glb=$M/cloud_p4_r1/glb.glb
    python3 tools/meshy/native_hunters/graft_companions.py art/wardens/pip/pip_meshy.glb art/wardens/pip/pip_meshy.glb WORK/comp.glb WORK/faces.png
    cp WORK/faces.png art/wardens/pip/pip_meshy_faces.png

The builder welds Meshy's UV-seam splits (decimated apart they open as cracks), scales to 0.50 / 0.52 m, decimates to 700 / 800 tris
and keeps the albedo at 512 px; the graft carries that image + UVs (glow-sun, cloth-cloud). Atlas cells 0/1 (sun calm/happy) and 4/5
(cloud calm/happy) are the portrait's dot eyes, thin level brows, small closed smile, soft blush; cells 2, 3, 6, 7 are byte-identical.
Raindrops show only while the cloud cries (`warden_anim/pip.json` cloud `mood_only`). Look (`warden_look.json` pip): the sun's albedo
is a tint over the texture, low glow and no far-glow boost (the boost clipped the gold to lemon), the cloud lavender, uninked.
