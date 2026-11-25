# Kael (juggernaut): import note, v95 swap of Kael appeal3, body c (2026-11-10)

`kael.glb`: the owner's pick (11-10), Kael v95 r2 appeal3 `cand_c.glb` (body variant c with the new appeal3 face:
waist taper, arms and shawl 5 cm in per side), swapped onto juggernaut's own skeleton, clips and anchors by
`tools/art1/v95_swap.py` (docs/art/wardens/V95_SWAP.md) with `art/wardens/src/kael_v95.json`. Raw files in
~/meshy/v95/Kael/r2/appeal3 (never in git); the spec reads `kael_v95_c_body.glb`, which is `cand_c.glb` without its
own sword mesh (`kael_sword`): the game's skinned sword stays.

    blender -b --factory-startup --python tools/art1/v95_swap.py -- art/wardens/src/kael_v95.json WORK art/wardens/kael/kael.glb

Body: 13k triangles (head 2.6k), one 2048 atlas and the master's emission map baked beside it (`"emit": true`), both
embedded (Godot extracts them to `kael_atlas.jpg` and `kael_emit.jpg`). The curse veins are the emission map, tinted
by juggernaut.json `model_glow.core` as before. Slots by colour, bone and box (first match wins): leather (dark),
metal (grey), hair (white, in the head box), skin (chest, both arms, the face's warmer parts), cloth (the crimson
shawl, scarf and sash; the pale shawl; most of his pale face, which the cloth slot keeps warm where kael's skin slot,
with its cool shadow tint, turns it lilac). The face has one rule ahead of hair and skin (face box, s 0.04-0.4, v
0.35-0.95): its tones sit either side of the skin rule's s 0.08 and its ridge highlights took the hair slot, so the
skin and hair triangles drew a pale lilac-blue streak down the nose; the white hair (s < 0.04 or v > 0.95) stays hair.
Weights: bone heat from the spec's joints, limbs on the rig's own segments (`spread: "rig"`); the shawl rides the
hips box, its shoulder wings the pauldrons (minus the upper arms), the head box the head. The master's wrist cuffs and
chains ride the hands; the old spring chains (hangcuff, hangwarchain) stay in the rig, unweighted.

**Curse side:** the v2 build mirrored the scan so the curse sat on his right (sword) arm. The appeal3 master paints it
on his LEFT arm and chest, as the v2 turnaround does, and the swap keeps the master's paint: the bare veined arm and
crimson hand on the left, the black glove on the right (sword) hand. The arm blooms (warden_look `kael`, on
anchor_arm_up / _elbow / _fore) move with it: the spec's `anchor_bones` puts them on upper_arm.L / forearm.L.
Alternative not taken: mirror the master's texture to keep the curse on the sword arm.

Kept from the old build (`keep_mats`): the skinned sword (glow-sword, leather-grip, metal-sword, _dk, _edge; 0.9k
triangles, weighted to hand.R; `skinned_weapon` in content/rules/warden_anim/kael.json), with weapon_muzzle,
anchor_blade_mid and anchor_blade_root on hand.R along the blade, unchanged. Gone: the alpha cards and their sheet
`kael_cards.png` (the master models the torn hem and sash), the scripted wrist chains.

Clips: the 49 clips of the v2 build (the swap keeps the game rig). The swap ran on main's kael.glb, before the
docs/art/IDLE_AUDIT.md idle (6 s) and stance (8 s); the 0.24.4 merge put them back with `kael_retarget.py` (plain
numpy: `python3 tools/art1/kael_retarget.py -- <old kael.glb> <swapped kael.glb> <out>`, the old glb's 49 clips over
the swapped ones, rest rotation drift none), which also adds the `x_breath` leaf (3430 chest-band vertices) and prints
the sword point at the idle's first frame (0.8 cm under the ground, as before). `anchor_head_top` and `anchor_chest`
move onto the new mesh (the spec's `anchors`).

`kael.glb.import`: unchanged (`generate_lods=false`, `force_disable_compression=true`).

Shots on the game rig (`--warden-shots`): docs/shots/kael-appeal/.

Checks (2026-11-11): `--warden-glb-check` 183/0 failed, `--warden-model-check` 157/0 failed. `--stretch-check
--wardens=juggernaut` still flags all 49 clips (worst 7.45x in fusion, idle 2.56x, run_f 4.09x, mostly hips and
thighs), against 31.06x (death), idle 10.39x and run_f 16.72x for the old v2 build: better, but not under 1.3x. No
tearing or arm, chest or cape clipping shows in the turnaround, idle, run or kit poses.

**Anim slice3 (11-11), no change:** walk_f/run_f candidates retargeted from Meshy library actions (rig walk, rig run,
action 510; Meshy API output on the paid plan, commercial use under Meshy's terms), each held to Kael's hunched lean
(hips -22/-23 deg) with the arms carried from the current clips, planted at 2.2 / 4.6 m/s. The blind Fable 5.2 judge kept
the current clips: walk 4.00 vs 3.00 / 2.83, run 4.00 vs 3.00 / 3.00 (the candidates' stride reads narrow and light).
The judge noted that the current walk's sword tip may dip to the ground line. Idle is left to the pilot4 idle job. The judging ran on the v2 build's clips; the appeal3 swap keeps the same 49 clips, so the verdict stands.

walk and run b, l, r, fl, fr, bl, br (2026-11-11, ext/anim-dirloops-lace-kael): `blender -b --factory-startup --python tools/art1/hunter_dir_gait.py -- art/wardens/kael/kael.glb OUT.glb 1.62 4.35`,
then `python3 tools/art1/glb_add_clips.py art/wardens/kael/kael.glb OUT.glb walk_b,walk_l,walk_r,walk_fl,walk_fr,walk_bl,walk_br,run_b,run_l,run_r,run_fl,run_fr,run_bl,run_br`.
The speeds are the forward loops' `loco.foot_mps`, not the loco speeds: walk_f/run_f are the old clips and stay, so
the ring keeps `stride`/`foot_mps` and the game's rate and stride lift every direction to loco speed the way they lift
forward. The blind Fable judge kept the old walk_b, walk_r, run_l (tie or loss), so those are
the old clips put back with `glb_add_clips.py` (judge: docs/art/wardens/dirloops/JUDGE.md).

NOT APPLIED on main (11-16 merge): the diagonal and re-baked back/side loops (walk_/run_ fl fr bl br, b l r) described here were baked into the old model's glb with a walk_f/run_f of a different length than main's v95 clips, so main's glb and warden_anim json are kept. Re-bake: `blender -b --factory-startup --python tools/art1/hunter_dir_gait.py -- SRC.glb OUT.glb WALK RUN` on main's glb, then `glb_add_clips.py`, then restore the json map from ext/anim-dirloops-lace-kael.

**One sword (2026-11-17):** the e1 master carries its own swords as the materials `sword` and `sword.001` (two of them:
the body it was built on already had one), names the spec's `drop_mats` did not list, so the 11-17 port joined both
into the body mesh (10.4k triangles painted by `v95c`, weighted by bone heat over hand.R, shin.R, thigh.R and hips)
beside the game's skinned sword: three swords. `python3 tools/art1/glb_drop_mats.py kael.glb kael.glb '*-v95c'` took
them out (every other part, clip and image byte-identical; `kael_v95c.jpg` gone), and `own.drop_mats` now names
`sword` and `sword.001`, so the next `v95_to_game.py Kael` drops them itself. The game's skinned sword is the one sword.
Alternative not taken: the master's HD sword skinned to hand.R in place of the game's (anchors and blade FX follow the game's sword).

**Restore branch (2026-11-17, ext/hunter-glb-restore-1117):** the restored e1 mesh (ca32bd97252) carried the same master swords (2440 triangles on the `*-v95c` materials, blade-shaped slabs at x 0.26..0.37). `glb_drop_mats.py kael.glb kael.glb '*-v95c'` took them out, so the restored picked Kael has one sword (the game's skinned one), like main's. Every other part, skin and the 54 clips are unchanged.

Face pass (2026-11-18, ext/faces-ship-1118, owner "upload all of these"): face-kael-1118 cand A_s2_FevHair texture-only: `python3 -I tools/art1/face_swap.py art/wardens/kael/kael.glb /home/boki/meshy/face-kael-1118/cand/A_s2_FevHair.glb /home/boki/meshy/kael-sword-1117/cand/A_keep_new.glb OUT.glb` blends the changed pixels into the embedded 4096 `v95` image (sword, rig, clips untouched). Re-run the same command on the rig-weights glb (PR #284) if it merges first.

**Round 21 (2026-11-24, ext/hunter-round-kael-1124, plan /home/boki/gens/hunter-round-1124/kael/PLAN-1124o.md):**
- Sword (kael.glb, the native path's prop source): the 0.9k-tri skinned slab (metal-sword, _dk, _edge, glow-sword,
  leather-grip; flat colours on degenerate UVs, read as a black slab) is replaced by a Meshy image-to-3d sword (task
  01a20e74-0cd4-75e5-9b8c-fbe018d02bfd, input = the kael_v2 master sheet's sword crop): 5.9k tris, its own 1024 px
  texture (`kael_kael_sword_meshy.jpg`), one primitive `metal-sword` rigid on hand.R, fitted so guard face -> tip lies
  exactly on the old blade (1.052 m; anchors and blade FX unchanged), width 0.21 m (old 0.18), thickness squashed to
  0.05 m. Every other primitive, the skin, clips and images are byte-identical. Script:
  `/home/boki/gens/hunter-round-1124/kael/sword/splice_sword.py kael.glb gen_A/model.glb OUT.glb 1024 0.55`.
- Arms (kael_meshy.glb Image_0 only, built from main's texture, not from round 20's v3): the round-20 bone-segment mask
  now runs 20 cm past the wrist, so the sword fist is dark red too; veins are the 3D-noise field with a low along-arm
  frequency (s_along 3, s_round 60) so they run lengthwise and branch, 1.6 texels (orange, sword arm) / 1.3 (white,
  off arm), no halo. Scripts: `/home/boki/gens/hunter-round-1124/kael/hands/` (`rast4.py live.glb 0.20`,
  `edit12.py h1.jpg o_halo=0 o_hk=0 og=130 s_along=3 s_round=60 o_w=1.6 w_w=1.3`).

**Round 22 (2026-11-24, ext/hunter-round-kael-1124, hair):** the black flecks on Kael's mane at the match camera were
the painted ink shell (outline.gdshader): the raw Meshy glb has one material (`Material_0`) and no vertex colour, so the
whole mesh, every thin hair strand included, took the ink line. `kael_meshy.glb` now has two primitives on the SAME
vertex buffers: body (`Material_0`, 40,694 tris, unchanged) and hair (`hair-meshy`, 39,284 tris, same three images),
so the hair takes WardenGlb's `hair` slot (NO_INK, hair shading + warden_look.json `slots.hair`). Positions, UVs,
skin, clips and images are byte-identical; only the index buffer is split. Hair = neutral-white paint (luminance > 150,
saturation < 28) above 1.0 m, majority-smoothed over welded neighbours (cloak cream is warm, sat > 55; face skin out).
Scripts: `/home/boki/gens/hunter-round-1124/kael/hair/scripts/` (`hairmask.py GLB Image_0.png mask.npy`,
`split_hair.py GLB mask.npy OUT.glb`); re-run both on any new kael_meshy.glb.
- Hair grade (same round): only the hair texels of Image_0 (the hair triangles rasterised in UV, grown 3 px into their
  own padding) are graded to the kael_v2 turnaround's hair values: luminance median 212 -> 196, p5 177 -> 143,
  p95 242 -> 229, chroma kept (silver with grey strand shading as in the ref; game view clipped-white hair pixels
  20 % -> 0 %). `hair_grade.py r21.glb mask.npy Image_0.jpg`, then `set_image.py split.glb Image_0 Image_0.jpg OUT.glb`.

**Round 23 (2026-11-25, ext/kael-r23-veins-grip, plan /home/boki/gens/hunter-round-1124/kael/PLAN-1124o.md section 6):**
- Arms (kael_meshy.glb Image_0, arm texels only; hair grade kept): round 21's veins read as neon paint (Meshy's own
  forearm lines were recoloured orange; 1.6-texel hard lines at full saturation). Rebuilt from the pre-round-21 arm
  texels: no orange on Meshy's lines, anti-aliased trunk + fine veins whose width tapers along each vein, ember core
  (236,104,28) with a faint darker rim; off arm thin white veins. Sword arm median lum 32 vs off arm 122 (rule kept);
  arm texels at full saturation 991 -> 0. `r23/edit13.py live_Image_0.jpg OUT.jpg W=2.2 Wf=1.0 fa=0.9 tap=0.25 va=1.0 kL=1.2`,
  then `hair/scripts/set_image.py kael_meshy.glb Image_0 OUT.jpg OUT.glb`.
- Sword (kael.glb prop): the grip ran along the fingers (74 deg off the knuckle line), so the blade pointed where the
  fingers point (into the ground with the arm down) and the fist never closed on it. One rigid move in hand.R's bind
  space (the hand.R anchors moved with it) puts the grip across the fist, 20 deg off the knuckle line, the fist 7 cm
  under the guard: solved from `--live-audit --probe` (r23/grip/solve.py), applied by r23/grip/apply_grip.py.
  Over idle/run/dash/jump/attack/hit: blade tip lowest -0.49 m -> +0.16 m, blade samples within 3 cm of the body
  1036 -> 0, finger samples past the guard 5031 -> 414. Steel texels (neutral only): highlight roll-off, p95 lum 252 -> 216.
  The contract model (kael.glb, native off) holds the sword the same new way.
  Alternative not taken: warden_native.json "grip"/"turn" data (Gil's route); kept to the hunter's own files.

**Round 24 (2026-11-25, ext/kael-r24-cape, plan /home/boki/gens/hunter-round-1124/kael/PLAN-1124o.md section 7):**
- Ink room: kael_meshy.glb had no COLOR_0, so the game's ink shell (outline.gdshader ink_mask) drew the full line on
  every vertex; on the one-layer cape, sash and scarf tatters and the near-touching Meshy layers its back face showed
  as black slits. `python3 tools/meshy/native_ink.py OUT.glb IN.glb` (tool default rule, as Grimble) writes COLOR_0
  (rgb 1, alpha = ink room) on both primitives; 13.6 % of body verts get no line (open sheets), the rest a line no wider
  than half their free distance. Positions, UVs, skin, clips and Image_0 are unchanged. Near-black pixels vs round 23
  on current main: match camera 1856 -> 422, eye 87,657 -> 69,017, knee 69,390 -> 55,824 (18 frames each).
  Rejected: --full=0.0001 (open sheets only, full line elsewhere): match black 1716, the cape slits stayed.
- Sword-arm veins glow: an emission image (`Image_emit`, Material_0 only) = round 23's own sword-arm vein field x the
  ember colour x 2 (r24/emit13.py = edit13.py's R coverage; lines only, no halo, same widths), so the orange veins
  read at eye/knee view without the round-21 neon slab. No emission on the off arm's white veins (the juggernaut
  emit_tint would turn them crimson). Re-run: `emit13.py live_Image_0.jpg emit.jpg <r23 args> K=2.0`, then
  `r24/add_emit.py IN.glb Material_0 emit.jpg OUT.glb`, then native_ink.py.
