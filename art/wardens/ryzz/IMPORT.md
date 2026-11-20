# Ryzz (ART-1 rebuild): how this model is made

## LIVE v95 master in game (2026-11-12, ext/hunters-v95-ingame)
`~/meshy/v95/Sparkle/r2/prop1111/cand_A.glb` (CURRENT_OVERRIDES 11-12), on the rig before the underbust swap (95f0fef3e5^, so the move_bones deltas apply once). 13.2k tris, one 4096 atlas (head_uv 4), 45 clips.
Spec `art/wardens/src/ryzz_v95.json`; proof sheet ~/meshy/v95/_closeups/ingame-1112/sheet.jpg.

## v95 swap (2026-11-10, ext/sparkle-underbust2): the current ryzz.glb

The mesh is now the v95 master: Sparkle round 2, underbust variant c (owner pick) with the owner-approved round-2 face (r2/face_appeal2/cand_face.glb) merged in, kept on hetzner as ~/meshy/v95/Sparkle/r2/final/sparkle_final.glb. It was put on this rig with `tools/art1/v95_swap.py` and `art/wardens/src/ryzz_v95.json` (docs/art/wardens/V95_SWAP.md). The skeleton, the 38 clips and the anchors are unchanged; the anchors were moved through the fit, and the gum bone's rest is moved 3 cm up (`move_bones`) so the bubble sits on her lips. The model is 13.2k tris with one embedded 4096 atlas and no normal map. ryzz_atlas.jpg and ryzz_nrm.jpg belong to the build below. The first swap used a 2048 atlas with the face island at about 250 px, which smeared the round-2 face (lashes, freckles, heart); the redo uses `tex` 4096, `head_uv` 4.0 (about 850 px for the face) and `cage`/`ray` 0.02/0.06 (closes a bake miss on the forehead). Shots are in docs/shots/sparkle-appeal-final/.
Limits: the pigtails, rods and wire loops are rigid on their region's bone (spring_pig and the skirt bones are now unweighted). The rodlit tips are gone, so Kitefall's rod blaze is only the anchor_rod bloom. Lids, brows and fingers no longer move v95 geometry. The garter hoops stretch between the legs in run and dash.

## Previous build (ART-1)

Source art: briefs/art-refs/ryzz_FINAL_sheet.png (master), ryzz_turnaround_apose.png. Budget: 15k tris (14,368 here), a 2048 atlas + a 2048 relief normal map, 8 surfaces.

1. The turnaround's four views, Meshy image-to-image with the loose parts taken out (pigtails, rods, harness, wires, chain), then a multi-image scan: ~/meshy/ryzz_f (edit.sh, runA).
2. `tools/art1/ryzz_source.py`: scan -> contract rest pose; the head stays the scan's sculpt, the density on the face; hands cut at the wrist.
3. `tools/art1/ryzz_pieces.py`, `ryzz_paint.py`, `ryzz_finish.py`: rebuilt hair, pigtails on spring chains, hands (index/curl/thumb bones), harness, rods, wires, chain, gum, lids; atlas, skin, anchors.
4. `tools/art1/ryzz_clips.py`: 38 clips on the kit's timings (scripts/match/kmoves_vv.gd), content/rules/warden_anim/ryzz.json maps them.

The face and corset are projected from the art: the corset from the master (registered by its neon), the face from the first ryzz_head.png (git 3e988ae8 of ext/agent-briefs, her grin; kept as ~/meshy/ryzz_f/ryzz_head_nogum.png, because the later sheet paints the bubble and the bubble is geometry here).

Run it all with INSTALL=1 ~/meshy/ryzz_f/build.sh [source]. No weapon: fingertips carry the FX points (weapon_muzzle, anchor_finger_L); rods anchor_rod_0..3.

v95 swap 11-12 (ext/hunters-v95-ingame): re-baked with `fill_misses` (docs/art/wardens/V95_SWAP.md), which fills the
texels the bake missed (exact black where the decimation folded a triangle under) from their neighbours.

## Pigtail graft (2026-11-15, ext/sparkle-hair-1115): Meshy pigtails on the live model
Owner 11-15: the in-game hair "goes out too far and isn't wavy enough". Only the pigtails change: the live ones are cut from `Body`
(hair-atlas faces outside |x| > 0.085 or below z 1.56) and Meshy-made wavy ones (a multi-image-to-3d bust from four head crops of
the v2 turnaround) are grafted on by `tools/meshy/pigtail_graft.py` (`art/wardens/src/ryzz_pigtails.json`): aligned to the head, sheared in
toward the neck, graded to the live palette, remeshed to 1.5k tris a side, baked into free atlas rectangles, skinned to `head`. Face, body,
chest, backpack, rig and clips are untouched (the same file through Blender's glTF export); the pigtails stay rigid on the head bone.
13.9k tris (live 13.2k). `ryzz_atlas.jpg` is Godot's extract of the new embedded atlas.
Re-run 11-15 on main's glb (main moved at bfae359ad9: Sparkle's idle/clips): `pigtail_graft.py` on main's current ryzz.glb, then
`python3 tools/art1/glb_add_clips.py <graft.glb> <main ryzz.glb> =<every clip> <out.glb>` (Blender's export resamples the clips; this puts
main's 45 clips back byte for byte: same names, key counts and values) and `python3 tools/art1/glb_compact.py <out.glb> ryzz.glb` (drops the
resampled clips' leftover data). Nothing but the pigtails differs from main's glb.

Idle/run pilot (2026-11-11, ext/anim-pilot-four), licence for both: Meshy generated asset, our account. Sparkle's Meshy rig is 01a1c8ac-ed6a-7214-a6e0-3250ea3170f7, auto-rigged from her static mesh at height 1.9. `idle` is now animation-library action 89 (task 01a1c8ad-9df6-7391-bae2-a82e739cf522), retargeted with feet planted, 1.71 s played twice (3.42 s), seam 0.14 deg; blind judge 4.8 vs the old idle 2.8. `run_f` is now the rig's own running clip, retargeted at 1.11x with feet planted at 4.55 m/s and her arms carried from the old run_f, 0.62 s, seam 0.04 deg; judge 4.5 vs 4.0. The rig's walking candidate lost (3.0-3.2 vs 4.0), so walk_f is unchanged. Recipe: `python3 tools/art1/glb_pick_clip.py <candidate.glb> <clip> <name> <tile> /tmp/x.glb`, then `python3 tools/art1/glb_add_clips.py <this glb> /tmp/x.glb <name>`. Candidate GLBs and renders: ~/anim/four (glb/, renders/blind/).


Carried onto the v95 swap by `python3 tools/art1/glb_add_clips.py <this glb> <ext/anim-pilot-four 37d910944 glb> idle --hold-moved-rest` (2026-11-13, merge of origin/main 18402df5b): the core bones' rest is identical between the two builds and main's old idle matched the judged ones, so the clips are the judged ones; the spring bones the new model moved (spring_pig*, gum) hold this model's rest in them, as every other clip does.
`run_f`: Not carried (2026-11-13): the pilot run_f above; `--anim-audit` on the game rig reads run slide 97% (sole sweep 1.03 m/s at a 4.83 m/s run) (main's own clip 9%, limit 25%), so main's clip stays. The candidate is `run_f` in ext/anim-pilot-four 37d910944's ryzz.glb, to copy with `glb_add_clips.py --hold-moved-rest` once the in-game foot slide is fixed.

Merge 11-15 (ext/merge-lane-anim-hard2-1115): main's glb (45 clips, idle, pigtails) with only the key-pose-read `lmb_l` put back from the branch (`glb_add_clips.py <main ryzz.glb> <branch ryzz.glb> =lmb_l`, then `glb_compact.py`); the other 44 clips are main's byte for byte.

Doll pass A (2026-11-18, ext/sparkle-dollA-game-1118, owner pick): `/home/boki/meshy/sparkle-doll-1118/A_face_skin_bust_hips.glb` (new face with smirk, violet-magenta eyes, matte skin; bust -14%, thighs -7%, hips -3%; same tris/UVs as the v95 `cand_A.glb`) swapped in with `python3 tools/art1/v95_to_game.py` (keep_uv own-paint swap, spec `art/wardens/src/ryzz_v95.json`, 60k tris; work dir `~/meshy/v95/_ingame_doll1118/`). Rig, 49 clips and anchors kept from the previous glb; `ryzz_v95.jpg`, `ryzz_v95b.jpg`, `ryzz_v95c.jpg` are the new textures. Height unchanged (y -0.014..1.684 vs -0.014..1.685).

Gum onto the lips (2026-11-20, ext/ryzz-gum-mouth, owner 11-20 "why is sparkles gum still on her forehead?"): doll pass A
put a face ~12 cm lower than the old one onto the kept rig, and the kept bubble (bone `gum`, 138 vertices skinned whole to
it, child `anchor_gum`) stayed where the old lips were: on her hairline in every clip (it shows at 0.72 scale in idle/run,
grows to 1.25 in `gum`, the laugh emote and `mage_gum`). `python3 tools/art1/glb_prop_move.py ryzz.glb ryzz.glb Body gum
0 1.419 -0.119` puts the bone's head (glTF metres, Y up) just behind her lips (bubble from the lips, as on the splash); its
inverse bind and the 47 clips' gum translation keys shift with it, nothing else changes. v95_to_game keeps a fixed-offset
`move_bones` out of re-runs, so a re-swap keeps this spot; a new face needs the same step at its lips. The lid/brow/mouth
bones and `anchor_eye_glow` also sit at the old face's height, but no vertex is weighted to them and no look uses the anchor.

No-gum version (2026-11-20, ext/ryzz-gum-mouth, owner 11-20 "want TWO versions"): the look-only design variant
`ryzz_nogum` (`content/rules/warden_look.json` `"ryzz_nogum": {"hide_bones": ["gum"]}`, no .glb of its own) is this
same model with the `gum` bone shrunk away every frame (WardenSync), and no gum fidget (MageGum). Pick it with
`--warden-variant=ryzz_nogum`; shipping it as the default would move `hide_bones` onto `"ryzz"`.

Sparkle 3D repair (2026-11-20, ext/sparkle-3d-fix-1120, owner 11-20 "why does Sparkle look broken in game"): the same
doll pass A model (face, smirk, gum on the lips kept), rebuilt so it no longer shreds. Causes, measured on the live glb
with job tools (`diag.py`: sliver = 3D aspect > 12, smear = UV/3D area < 0.15x median):
- hair strands, ragged black collar, smeared patches: the keep_uv swap decimated Meshy's triangle soup to 60k and left
  slivers (14.4% of tris; F 0.4%) and smeared UVs (2.1%; F 0.2%). Fix in Meshy: quad remesh of the doll master
  (`meshy_task.py remesh --topology quad`, 30k quads, 5 credits) re-textured at 4k ->
  `/home/boki/meshy/sparkle-fix-1120/master_q30k_4k.glb`, swapped with `v95_to_game.py ryzz --weights meshy --remeshed`.
- stretched hands: bone-heat weights plus the spec's arm joints still being the 11-12 master's (wrists 7 cm wider and
  8 cm higher, arms 20 cm off their bones). Arm joints re-read with `tools/art1/v95_meshy_joints.py` (d065da3debd) and
  Meshy's auto-rig weights; hand edge stretch p99 over the clips 9.7-41.7x -> 1.2-1.5x.
- heads tall, crown to the game rig's head joint: live 7.8 -> 6.95 (2D pick 6.7; the brief's 5.1 used another head measure).
- not causes: LOD, shader, skin binds (inverse binds = rests, 0 deg), winding (live 0.5% flipped, F 0%).
Result: 59,948 tris, 49 clips and anchors kept, glb 12.1 MB (was 16.6), `ryzz_v95.jpg` 4k; `ryzz_v95b/c.jpg` dropped
(the remeshed model has one texture). The gum bone stays at its lips spot (`move_bones`).
Open after the repair (art-gate 11-20 FAIL on the owner sheet): magenta hair locks at both cheeks, eyes reading red
(the Meshy iris is magenta-violet under the warm grade), a dark patch at the left strap, and the hip hand close to the pack.
These are in the remeshed texture, not the look: the look's magenta paint_glow off and the eye bloom off (job variants
ryzz_g1/g2) render the same. Next step: a Meshy retexture of the face/hair region, not import work.

Retexture pass (2026-11-20, ext/sparkle-3d-fix-1120, job 20261120-065702-a4): the same quad-remesh body (30k quads,
same UVs), repainted by Meshy from the owner's 2D pick (turnaround r4 A: front, side and back crops,
`meshy_task.py retexture ... --original-uv --texture-res 4k`, 10 credits each). Work dir `~/meshy/sparkle-fix-1120/c2/`.
- Scale trap: a Meshy remesh/retexture .glb comes back normalised to 2 m tall. The spec's joints/regions/slots are in the doll
  master's frame (1.85 m), so the raw file swapped 8% too tall (1.819 vs 1.684 m: arms off their bones). Fit off Meshy's
  rig (`v95_meshy_joints.py`, 6 arm joints): x0.924, residual under 1.5 cm -> `glb_scale.py` before `v95_to_game.py`.
- 7 runs, ranked: A front+side+back (shipped here), B the previous repair (doll 11-18 face kept), C a second
  front+side+back run. Rejected: front only (painted the pack black), side view mirrored x2 (face bolt on the wrong
  cheek: the 2D pick's side view shows her left cheek), one more front+side+back (more stray flecks).
- A vs the previous repair: lavender doll eyes and freckles like the 2D pick (were magenta-red), a cleaner blue-to-pink
  hair fade, copper pack, the neon hem at the crop top's bottom. Same mesh, rig, 49 clips, gum spot. 59,948 tris,
  sliver 0.4%, smear 0.2% (live 14.4% / 2.1%); `ryzz_v95.jpg` re-encoded at q90 (`glb_image_swap.py`), glb 13.1 MB.
- Still open: small magenta flecks along her right hairline (paint where hair meets skin), and `--stretch-check`
  fails on every build incl. main's (max over clips: live 15.3, A 24.7, B 25.6; ceiling 7; worst at the hips/thighs).
- A design-variant .glb (art/wardens/ryzz_<tag>/) imports with mesh compression on; copy the shipped .import's
  `force_disable_compression=true` and `remove_immutable_tracks=false` before comparing variants.
