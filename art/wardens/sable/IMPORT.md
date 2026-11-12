# Sable (thief): import note

## v95 swap, appeal4 cand_6 (cand_2 + moth eyes + curvier, 2026-11-11, ext/sable-appeal4): the current sable.glb

Owner 11-10 ("looks kind of boyish, maybe bigger breasts and hair showing"). The mesh is the worker's pick of three candidates (the owner has not
picked): `~/meshy/v95/Sable/r2/appeal4/cand_2.glb` (pick.txt and cmp_fem.png beside it), the appeal3 body b with the bug eyes
(`cand_b_bugeye.glb`) plus: bust +2.2 cm forward, waist -7 % width, hips +3.5 %, shoulders softer and narrower, the braid re-pathed forward over her
right shoulder onto the chest, and a sly face painted into the base colour (lashes and liner, lopsided open smirk). Same vertices
and UVs as the bug-eye master. The portrait and splash eyes (v2) are not touched.

Eyes (owner correction 11-11: she is part moth, solid grey/black moth eyes as on the v2 portrait/splash, not cand_2's violet irises with
round pupils): `~/meshy/v95/Sable/r2/appeal4/cand_2_motheye.glb` is cand_2 with only the two eye openings repainted in its base colour
(`appeal4/tools/eye_moth.py`: a dark orb, a soft bounce low, a sheen and one crisp catchlight where cand_2's was; lashes, liner and lids
kept). The swap reused the cand_2 bake's mesh and UVs and re-baked just the changed texels (`appeal4/tools/eye_rebake.py`, then
`atlas_repack.py`), so the fit, weights and slots match the cand_2 swap (one eye triangle moved hair -> skin). The spec's master
is the moth-eye glb; a fresh WORK reproduces it. Curvier (owner 11-11: "all the girls a bit curvier, bigger boobs, tighter waist, not weird from
the side; sable's boobs exposed in the middle part curvy too"): `cand_6_motheye.glb` is the moth-eye glb with only positions and
normals moved (cj/20261111-025118-a5/scr/sdeform.py, the same rounded dome as Cinder's cand_5): each breast up to 3.4 cm forward with
zero slope at the chest wall and a fuller lower curve, the inner radius reaching into the jacket opening plus a soft centre cleft so the
exposed skin shows two rounded inner curves; the lapels, pendant, laces and braid ride the same field; arms masked; waist 5 % in
(saturating so the holsters only translate). Triangle area p95 1.28x. Eyes, face and texture untouched. Sheet:
~/art-review/cinder-bust-round-1111/cmp_bust_round.png (cand_4 is the milder no-cleft option). This one is a full re-fit. Checks: `--warden-glb-check` PASS, `--warden-model-check` PASS,
`--stretch-check --wardens=thief` 47 clips flagged as on cand_2 (worst 23.53x encore_dance, was 23.44x); wings re-applied (root 3 cm back,
cards tipped 26 deg). Shots: docs/shots/sable-appeal4/ (re-rendered; moth eyes intact). Candidates 1 (milder) and 3 (widest grin, bigger bust) are
drop-ins: change `master` in the spec.
`tools/art1/v95_swap.py` put it on her own skeleton, 47 clips and anchors with `art/wardens/src/sable_v95.json`
(docs/art/wardens/V95_SWAP.md):

    blender -b --factory-startup --python tools/art1/v95_swap.py -- art/wardens/src/sable_v95.json WORK art/wardens/sable/sable.glb
    python3 tools/art1/sable_wings.py art/wardens/sable/sable.glb      # the moth wings (docs/SABLE_WINGS.md), after every swap

13k triangles, one embedded 2048 atlas (Godot extracts it to `sable_atlas.jpg`), no normal map. The pistols are fused to her hands in the
master: rigid on hand.R / hand.L. The long ears, braid, coat tails and tail feathers are weighted by bone heat and the head box (the braid now
hangs on the chest, so it rides the head/hips rigidly). Slots by colour and box (first match wins): metal (pistols), hair, fur (ears, tail
feathers), skin (head), glow (gem), leather (boots, belts), cloth (coat, trousers). Shots: docs/shots/sable-appeal4/.
Lost against the v2 build below: the antenna, braid and coat-tail spring chains stay in the rig but carry no mesh, the hip knives and the
procedural pistols. The wing chains and cards are put back by `sable_wings.py`.

## Previous build: v2 (2026-11-06)

The owner's v2 redesign (2026-11-06; briefs/art-refs/sable_v2 on ext/agent-briefs; its index.md and "Notes for 3D" win). Built by script from sable_v2_turnaround.jpg, with sable_v2_master_sheet.jpg for detail; nothing is hand-edited in Blender.

    WT=$PWD M=~/meshy/sable_v2 bash tools/art1/sable_build.sh source   # plain (no "source"): finish + clips only

`sable_source.py` fits the scan to the rig, `sable_finish.py` joins it with `sable_pieces.py`, unwraps, bakes, paints (`sable_paint.py`), skins and exports, `sable_clips.py` keys the clips. Recipe and prompts: art/wardens/src/sable_recipe.json. Run log and credits: docs/art/wardens/PIPELINE.md "Sable v2". The raw run stays in ~/meshy/sable_v2 (never in git).

- **Budget:** 14,893 tris, 8 materials, one 2048 atlas, baked normal map. Shared armature, every FX point and anchor name, the 47 clips and the kit wiring are unchanged.
- **Scan:** Meshy multi-image of four edited turnaround crops. It keeps the body, coat, belt, gem and chain positions. The edits take out the antennae, braid, wings, coat tails, knives, keys and pistols, which `sable_pieces.py` rebuilds so they can move and stay in budget.
- **Canon choices:** ONE long white braid (the small sheet views wrongly draw two), on the existing spring chain, its lobes zigzagging with a shallow pinch and chevron creases painted on. Fuzzy moth antennae on a short spring replace the old head wings: feather plumes in a V, a thin dark stem with dusty lilac fuzz on both sides (two sheets back to back, 192 tris each). Top of the model about 1.97, so `height_3d` in tools/warden_model_check.gd is now 1.06 (the old wings stood taller still).
- **Coat:** the front edges are rigid to the torso (no chest bone, so "hips"), so the plunge holds in runs, dashes and shooting. Tails and moth wings are short bone chains; the wings are alpha cards projected from the turnaround's back view. The wings fold down at rest and are raised open now and then, procedurally (WardenWings). After a body swap, `python3 tools/art1/sable_wings.py NEW.glb art/wardens/sable/sable.glb` puts the chains and cards back on, fitted to the new back (docs/SABLE_WINGS.md).
- **Weapons:** twin flintlocks skinned to hand.R / hand.L, procedural silver and maroon wood with violet runes and a crystal, scaled up from v1 to the sheet (not projected from it). The silver and wood ramps sit a step under the sheet because the engine's toon light lifts them; the muzzle halos are small so the barrels keep their grey. Two moth-curved knives on each hip, from the turnaround's side view (the master shows two on her right). `anchor_bola` keeps its name on the hips; the kit needs the name.
- **Face and skin:** the scan's stitched mouth was removed in three places: the low mesh's crease smoothed (`sable_finish.py`), the normal bake flattened there, and a thin smile painted (`face_fix` in `sable_paint.py`). The same pass grades the skin toward the sheet's grey-lilac (tuned in the engine: a step below the hair, not the Blender preview), redraws the beauty mark, cleans collar violet off the neck and paints the cut buns back to hair.
- **The back of the skull:** the buns the scan grew are cut in `sable_source.py`; `hairback()` closes the hole with a fitted ellipsoid down to the nape.

## Body6 (2026-11-11, patch 0.24.6)
Re-swapped (`tools/art1/v95_swap.py`, spec `art/wardens/src/sable_v95.json`) onto the body6 pick cand_A from `~/meshy/v95/Sable/r2/body6/pick.txt` (positions and normals only, same UVs and vertex order as the body5 pick). Re-ran `tools/art1/sable_wings.py` after the swap.

Merge with main (ext/hunters3d-0246, 11-12): main's `--clip-check` seam test flagged this glb's `idle` (forearm.R seam 1.6x the limit after the Blender export). The idle's last key was set equal to its first on every track (glb data only, 0.01 rad at most; one quaternion was the sign-flipped twin).
