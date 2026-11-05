# Claire (rimewright), ART-1: import note

The owner's final design: `briefs/art-refs/claire_FINAL_sheet.png` (master), `claire_turnaround_apose.png`, `claire_weapons.png` (ext/agent-briefs). A grown woman on skates; sincere and shy.

Scan: the four A-pose views cropped, Meshy image-to-image (9 credits a view) with the horns, ears, wings, tail, bow and blades out and the neckline closed up to the collarbones, then one multi-image run (40 credits, 2x upscaled inputs). Work dir `~/meshy/claire_f`; `build.sh source` reruns everything.

- `tools/art1/claire_source.py`: the scan onto the rig. Head, hood and face stay the scan's sculpt on the head bone (2.2k tris on the face). The face is a little longer and slimmer below the eyes. The skirt is lengthened to mid-thigh, hung from the pelvis, its hem following the thighs a little. The capelet stays on the torso.
- `claire_pieces.py`: gloved hands, ears, ice horns, wings, tail, bow and ribbons, blades, the candy-striped spear (skinned to hand.R, item 76b).
- `claire_finish.py`, `claire_paint.py`: one 2048 atlas, 7 surfaces, texel-space paint; lids, slit-pupil glowing iris (hot-keyed), fur held under pure white so it survives the match camera. Bare thigh under the skirt is repainted as stocking and dark shorts.
- Face: the owner's `claire_head.png` (front, hood up) warped onto the sculpt's landmarks (`claire_paint.py` SHEET_X/Z), hair and inner hood in its ice blue, a soft blue slit in each iris. The skirt's side pits are covered by `skirt_panel`.
- `claire_clips.py`: 41 clips at 30 fps on the kit's tm_ timings.

Budget: S1's 15k tris including the spear, 7 surfaces, VRAM-compressed atlas, LODs on.
Rig: archetype body legs 2.04, torso 0.96, shoulder 0.84, neck -0.04, size 1.1, then `--warden-rig-json --warden=rimewright`.
