# Hem (archer; was Pin): import note, ART-1 rebuild (2026-11-05, owner item 108 + 76b)

`hem.glb`: two Meshy scans plus scripted parts, on the shared armature. Body and outfit: a scan of lisette_turnaround_apose. Head, hair, ponytail, tie and cowl: a scan of
hem_head.png, 6.6k of the budget, the face at about 2.7x the body's texel density with the painted plate projected over it. Scripted: hands, scarf tails, bow, arrows, spool, scissors,
needle pin. Raw files in ~/meshy/lisette and ~/meshy/lisette_head (never in git). 41 clips keyed as targets. Under 15k triangles with the bow (S1 perf), one 2048 atlas, one 2048
relief normal map. Slots: skin, hair, cloth, leather, metal, glow.

    ~/meshy/lisette/edit.sh; ~/meshy/lisette_head/edit2.sh     # Meshy edits (hair, scarf, mask, scissors out, corset closed high; needle out) and the multi-view runs
    B=~/tools/blender-4.5.15-linux-x64/blender; ulimit -v 12000000
    $B -b --factory-startup --python tools/art1/hem_source.py -- runA/glb.glb art/wardens/src/hem_rig.json stage/source.blend    # body fit
    $B -b --factory-startup --python tools/art1/hem_head_source.py -- runA/glb.glb stage/head.blend                             # head set on the neck
    $B -b --factory-startup --python tools/art1/hem_art1.py -- WORK source.blend scan_base.png head.blend head_base.png edit_face/image0.png
    $B -b --python tools/art1/hem_clips.py -- WORK/hem_art1.blend WORK/hem.glb

WORK is gone from the box (2026-11-08). The clips now bake from the last baked blend, with its textures packed:
`~/meshy/hem/w3/hem_anim.blend` (hem_clips.py drops the old actions first and adds `x_breath` if it is missing).

    $B -b --python tools/art1/hem_clips.py -- ~/meshy/hem/w3/hem_anim.blend stage/hem.glb

Traps this model hit: weld a scan in its own pose (fitted, the arms hang through the hips and get sewn to them); sample arm and body paint separately for the same reason; never ABF a scan
(a chart folds over itself and paints the wrong place; smart project does not); Meshy winds faces inward, and Cycles hides what the game culls; every vertex needs a weight in a Decimate group.
- **Design (owner, Nov 5; Lisette, the Red Stitch; id and files stay):** model briefs/art-refs/lisette_turnaround_apose.png, outfit and
  colour hem_FINAL_sheet.png (vivid green eyes, a darker warm tan, crisp reds, capris to mid-calf), weapons and props hem_v4_props.png:
  silver needle bow (needle eyes at the tips, slots by the grip, curve read off the sheet), red-wrapped grip, glowing thread string,
  fletched needle arrows, thread-spool quiver on her right hip, high ponytail tied in red thread and pinned with a needle, red scarf
  (the scan's cowl + two tails on spring_scarftailR/L_*), red-stitched eye mask, stitched corset, pauldrons, half-sleeves, bracers, tall laced boots,
  silver scissors on the belt. Extra red on the shoulders for the top-down read.
  Item 108 (tasteful): the reference's cleavage cut-out is closed; the corset runs up under the scarf. The midriff stays, as the sheet has it.
- **Weapon (76b):** the bow is skinned on bones `bow` (hand.L), `bow_t`, `bow_b` (limbs) and `bow_s` (the string's nock); `"skinned_weapon": true`.
  FX points are empties: `weapon_muzzle`, `anchor_bow_root`, `anchor_nock`, `halo_bow_top/mid/low`. The Gun follows them (Sync.apply_blade).
  The left hand is sculpted closed round the grip for good. The nocked arrow stays a separate piece, `arrow_mesh` on bone `arrow`: at
  rest it stands in the spool as one more arrow; `ar` in a clip puts it on the string.
- **Clips:** content/rules/warden_anim/hem.json maps the kit's kmoves. The draw clip is on the draw's own clock: one steady pull to
  1.15 s, no pose change at Empowered, so it reads with the 55b fill line. Springs: spring_tail, spring_scarftailR, spring_scarftailL (the shared rest ripple).
- `hem_fit.json`, `hem_bake.json`, `tools/meshy/bow_parts.py`, `hem_parts.py` belong to the old scan pipeline and no longer build this model.
