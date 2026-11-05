# Hem (archer; was Pin): import note, ART-1 rebuild (2026-11-05, owner item 108 + 76b)

`hem.glb` is built by script in Blender, no scan: an SDF sculpt on the rig's own joints, a per-texel paint from the sculpt, and
41 clips keyed as targets. Budget: 19.4k triangles with the bow (under the 20k ART-1 budget). One 2048 atlas. Slots: skin, hair,
cloth, leather, metal, brass, glow.

    B=~/tools/blender-4.5.15-linux-x64/blender
    $B -b --factory-startup --python tools/art1/hem_art1.py -- WORK        # shapes hem_sculpt.py (hem_sdf.py), paint hem_paint.py -> WORK/hem_art1.blend, atlas.png
    $B -b --python tools/art1/hem_clips.py -- WORK/hem_art1.blend WORK/hem.glb     # the clips (posekit.py), exports
    cp WORK/hem.glb art/wardens/hem/hem.glb
    godot --headless --path . --import

- **Design (v4, owner's pick, briefs/art-refs/hem_v4_needlebow.png + hem_v4_props.png; replaces the r3 sheets, HEM_KIT.md):** giant
  silver needle bow, red-wrapped grip, needle eyes at the tips and slots by the grip (curve read off the props sheet), glowing thread
  string, fletched needle arrows, thread-spool quiver on her right hip, high ponytail tied in red thread and pinned with a needle, long
  red scarf (cowl + a tail on spring_scarf_*), red-stitched eye mask, green eyes, tanned skin, black-and-red stitched corset, pauldrons,
  half-sleeves, bracers, black capris, tall laced boots, silver scissors on the belt. Extra red on the shoulders for the top-down read.
  Item 108 (tasteful): the reference's cleavage cut-out is closed; the corset runs up under the scarf. The midriff stays, as the sheet has it.
- **Weapon (76b):** the bow is skinned on bones `bow` (hand.L), `bow_t`, `bow_b` (limbs) and `bow_s` (the string's nock); `"skinned_weapon": true`.
  FX points are empties: `weapon_muzzle`, `anchor_bow_root`, `anchor_nock`, `halo_bow_top/mid/low`. The Gun follows them (Sync.apply_blade).
  The left hand is sculpted closed round the grip for good. The nocked arrow stays a separate piece, `arrow_mesh` on bone `arrow`: at
  rest it stands in the spool as one more arrow; `ar` in a clip puts it on the string.
- **Clips:** content/rules/warden_anim/hem.json maps the kit's kmoves. The draw clip is on the draw's own clock: one steady pull to
  1.15 s, no pose change at Empowered, so it reads with the 55b fill line. Springs: spring_lockR, lockL, tail, scarf.
- `hem_fit.json`, `hem_bake.json`, `tools/meshy/bow_parts.py`, `hem_parts.py` belong to the old scan pipeline and no longer build this model.
