# Claire (rimewright), ART-1 v2: import note

The owner's v2 redesign: `briefs/art-refs/claire_v2/nivi_v2_turnaround.jpg` (master) and `nivi_v2_main_design.jpg` (ext/agent-briefs; index.md there). A youthful adult (18) on skates: real frost-white rabbit ears (her right one upright, her left one folded by the candy-cane bow), a white-to-ice braid over her left shoulder with a snowflake clasp, a small puff tail, lilac gloves. No horns, wings or devil tail. The older `explorations/old_claire_v2_turnaround.jpg` was not used.

Scan: the turnaround's four views cropped, Meshy image-to-image (nano-banana-pro, 9 credits a view) with the ears, braid, scarf ends, tail and blades out and the sheer skirt made opaque, then one multi-image run (meshy, ultra, 40 credits). Prompts in `art/wardens/src/claire_recipe.json`, task ids in PIPELINE.md's run log. Work dir `~/meshy/claire_v2`; `tools/art1/claire_build.sh source` reruns everything (`INSTALL=1` copies the glb here).

- `tools/art1/claire_source.py`: the scan onto the rig. Head, hair, face and scarf wrap stay the scan's sculpt on the head bone; the skirt hangs from the pelvis.
- `claire_pieces.py`: gloved hands, the two ears (rigid shells on 3-bone chains `spring_earR/L_*`), the puff tail (rigid on the root), the braid (`spring_scarftail_braid_0..4`, on the head) and its snowflake, blades, the candy-striped spear (skinned to hand.R).
- `claire_finish.py`, `claire_paint.py`: one 2048 atlas, 7 surfaces, texel-space paint; the face is the scan's own paint; lids; ears white with a pink front and frosted tips; fur held under pure white so it survives the match camera.
- `claire_clips.py`: 49 clips at 30 fps on the kit's tm_ timings.

Budget: 13.6k tris including the spear (S1 cap 15k), 7 surfaces, VRAM-compressed atlas, LODs on.
Rig: archetype body legs 2.04, torso 0.96, shoulder 0.84, neck -0.04, size 1.1, then `--warden-rig-json --warden=rimewright` (unchanged by v2).
Anchors kept by name: `anchor_tail_tip` now sits on the puff (its bloom dropped from warden_look.json), `anchor_clasp` on the braid's snowflake, `anchor_head_top` over the ears' base.
