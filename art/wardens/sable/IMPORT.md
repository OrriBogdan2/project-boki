# Sable (thief), stage 1: import note

Stage 1 of the 3D fan-out (INBOX_S2 09:05/09:10): Meshy generation, bake, rig fit and first shots; no hand polish
yet (stage 2 applies the Vex r3c recipe). Art: ext/imagegen docs/art/gen/wardens_r2/sable_{turnaround,side,portrait}.
Built by script, nothing hand-edited in Blender; run log in docs/art/wardens/PIPELINE.md "Stage 1: Sable".

    # crops of the turnaround's front and back (padded 3:4) and sable_side, edited (Meshy image-to-image):
    # both crossbows, the wings and both braids out, hands empty; prompts in ~/meshy/sable_r2/edit_*/request.json
    python3 -I tools/meshy/meshy_task.py create ~/meshy/sable_r2/runA in/front.png in/side.png in/back.png --texture-refs in/front.png in/side.png in/back.png --enhance off
    blender -b --factory-startup --python tools/meshy/bake_warden.py -- art/wardens/src/sable_bake.json
    blender -b --factory-startup --python tools/meshy/fit_warden.py -- art/wardens/src/sable_fit.json

- **Reconciled art (the turnaround wins):** the jacket has ONE long sleeve, on her RIGHT arm; her left arm is bare
  (the turnaround's front and back both draw it so, and the side view, which shows her left side, agrees; only the
  portrait sleeves both arms). The collar is the white fur collar inside the jacket's standing purple collar (the
  front draws the fur, the back and side the standing collar, the portrait both). TWO braids, one from behind each
  ear, falling forward over the shoulders to the waist with two silver bands each (the front view; the back view
  and the side draw one). The side edit came back mirrored (facing right with a bare right arm); it was flipped
  back to the art's left side, which is the only mirroring and restores the original orientation.
- **Body:** Meshy meshy-7.1 (front, side, back edited views; 2k geometry, 8k texture, no remesh, enhancement off),
  baked to 36k triangles and a 4096 atlas, fitted at 34k with a 2048 atlas. Archetype body (thief.json): head
  0.78, legs 1.8, neck -0.04, size 1.02 (0.95 of a medium as the hero sheet asks; her long legs as the art draws
  them). Head x1.08, girth x1.04.
- **Braids:** real geometry (tools/meshy/warden_parts.py braid()), white strands with silver bands and a tuft, on
  `spring_braid_R_*` / `spring_braid_L_*` chains under the head (`sable_braid_atlas.jpg`).
- **Wings:** four alpha cards (tools/meshy/warden_props.py wings(): a long forewing and a shorter hindwing a side,
  pearly with lilac outlines, veins and the art's peacock eyespots, painted in `sable_wing_atlas.png`), each on a
  `spring_wing_*` chain under the hips. The `card` slot: WardenGlb.CARD (shaders/warden_card.gdshader), both sides,
  alpha, no ink, hit flash.
- **Crossbows:** scripted hard-surface (warden_props.py crossbows()): silver tiller and recurved limbs, a dark grip,
  a violet string, a bolt with a glowing violet head (`glow`). `weapon` in the Gun node's space with its grip on
  the twin hold's right grip (HunterAnim HOLDS["twin"].gr); its child `weapon_offhand` is the same crossbow
  placed at gl - gr, so `_setup_weapon` hands it to the Offhand (x < -0.04) with its grip on the left hand, as the
  procedural Arc Bolts' left ring blade. The Gun's Muzzle (bolts' origin) is unchanged.
- Imports: the extracted atlases lossless (`compress/mode=0`); `sable.glb.import`: `generate_lods=false`,
  `force_disable_compression=true`.
