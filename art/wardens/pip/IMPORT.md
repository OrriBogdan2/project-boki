# Pip (tender; was Moosh Moosh / Burple), stage 1: import note

Stage 1 of the 3D fan-out (INBOX_S2 09:05/09:10): Meshy generation, bake, rig fit and first shots; no hand polish
yet (stage 2 applies the Vex r3c recipe). Art: ext/imagegen docs/art/gen/wardens_r2/pip_{turnaround,side,portrait}.
WardenGlb.ART: tender -> pip. Built by script, nothing hand-edited in Blender; run log in PIPELINE.md "Stage 1: Pip".

    # crops of the turnaround's front and back (padded 3:4) and pip_side, edited (Meshy image-to-image): the lantern,
    # the wings, the sparkles and glow out, paws empty and hanging; prompts in ~/meshy/pip_r2/edit_*/request.json
    python3 -I tools/meshy/meshy_task.py create ~/meshy/pip_r2/runA in/front.png in/side.png in/back.png --texture-refs in/front.png in/side.png in/back.png --enhance off
    blender -b --factory-startup --python tools/meshy/bake_warden.py -- art/wardens/src/pip_bake.json
    blender -b --factory-startup --python tools/meshy/fit_warden.py -- art/wardens/src/pip_fit.json

- **Body:** Meshy meshy-7.1 (front, side, back edited views; 2k geometry, 8k texture, no remesh, enhancement off),
  baked to 36k triangles and a 4096 atlas, fitted at 34k with a 2048 atlas; pink fur on the `skin` slot (the skin
  pick tints it), the cape and leaf `cloth`, the satchel, straps and bandages `leather`, the goggles `metal`.
- **Small:** archetype body (tender.json) head 0.78, legs 1.2, neck -0.1, size 0.84 (from 0.74: with the art's
  smaller head and longer legs she still stands 0.74 of a medium, the hero sheet's); the hit radius stays 0.34.
  Needs the Models.hunter bulky-folk legs fix (cherry-picked from ext/warden-meshy-cinder 6c97af01): a vulpin's
  body.legs was dropped.
- **Tail:** the scan's own fluffy tail re-skinned onto a 4-bone `spring_tail_*` chain under the contract `tail`
  bone (warden_props.py spring_region(): the vertices in a box behind her hips, by their nearest point on a path
  through the tail; a 6 cm blend at the root), so it swings on the springs and follows HunterAnim's tail.
- **Wings:** four fairy-wing alpha cards (an upper and a lower wing a side, pink, translucent, white veins and
  cells, `pip_wing_atlas.png`) on `spring_wing_*` chains under the hips; the `card` slot (WardenGlb.CARD).
- **Lantern:** the hearth lantern (her relic) as scripted hard-surface (a copper cage, roof, ring and foot round
  glowing amber panes on the `glow` slot, `pip_lantern_atlas.jpg`) hanging from her RIGHT paw, as the 3/4 and side
  views hold it, on a 2-joint `spring_lantern_*` chain under hand.R, so it swings. The procedural tender holds
  nothing (the palm hold: an empty Gun with an empty Mag; embers cast from both hands), so the lantern is not on
  the Gun: it rides the hand, and the Gun, its Muzzle and the hit ring are unchanged.
- Imports: the extracted atlases lossless (`compress/mode=0`); `pip.glb.import`: `generate_lods=false`,
  `force_disable_compression=true`.

## Stage 2 (the Vex r3c recipe, INBOX_S2 11:25; refs pip_front / pip_head_sheet / pip_lantern_sheet, 12:40)
- **Arms free (the stage-1 gap):** a new Meshy body (run B, 58 credits): the front and back edits redrawn with
  both arms out in an A-pose, a clear gap to the flanks and the cape hanging behind them (pip_front.webp), the
  side view as before; baked and refitted (new joints, the tail path and box). The arms swing clear of the flanks
  and cape; no skin flap.
- **Proportions:** body.legs 1.45 (was 1.2) so the rig's hips land on the new body's; size 0.84 keeps her 0.74 of
  a medium; hit radius 0.34.
- **Paint-over:** `smooth` and `ramps` of pip_front's colours (dusty pink fur, cream belly and tail tip, teal cape,
  brown leather, brass). The face is the scan's own (it matches the head sheet; no projection).
- **Lantern:** in her LEFT paw now (pip_front and the portrait), head-sized (1.75x), the portrait's look: a copper
  box whose four faces are pointed-arch windows round a warm flame (glow slot), and it casts light: an
  OmniLight3D on `anchor_lantern` (warden_look.json `pip` lights; WardenGlb._lights).
- **Wings:** more opaque cards with a stronger pink outline, white veins and rim, card glow 0.4, so they read on
  bright ground.
- **Look** (warden_look.json `pip`): skin and cloth rims and match-camera lift, glow 2.4, the lantern light.
- **Stance** (warden_stance.json tender): the left paw out, holding the lantern clear of her leg.
