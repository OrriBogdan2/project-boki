# Grimble, the Scrap King (id and files stay `dredge`): import note, v2 (the owner's locked redesign, 2026-11-07)

`dredge.glb`: one Meshy scan of the v2 turnaround fitted to the rig (body, head, bone-hook arm, gauntlet), v1's sculpted hoard,
bells, lanterns, blunderbuss and junk ball on top, the loupe scripted, and 40 clips keyed as targets. Budget: <= 15k triangles
with everything (14.9k). One 2048 atlas, 6 slots: skin, cloth, leather, metal, brass, glow. Raw files in ~/meshy/grimble_v2 (never in git).

    godot --headless --path . --import                   # once in a fresh worktree
    godot --headless --path . -- --warden-rig-json --warden=dredge --out=res://art/wardens/src/dredge_rig.json
    # ~/meshy/grimble_v2: edit.sh (the turnaround's front, left and back with the hoard, blunderbuss, loupe and sludge edited out), then
    #   meshy_task.py create runA in/front.png in/left.png in/back.png --texture-refs (same)
    ~/meshy/grimble_v2/build.sh source                   # grimble_source.py -> grimble_art1.py -> grimble_clips.py; INSTALL=1 copies the glb here

- **Art:** briefs/art-refs/grimble_v2/ (ext/agent-briefs): grimble_v2_turnaround.jpg (FINAL) and grimble_v2_master_sheet.jpg; index.md's
  "Canon notes for 3D and animation" win, except the face: the owner's 11-09 turnaround gives him a short flat snub nose with two
  nostrils. A three-lens brass loupe over his right eye; the left eye a smug squint.
- **Scan fit (grimble_source.py):** the limbs keep the scan's spread and lean and take the rig's joint heights (moved onto the rig's narrow
  arms and wide hips, the hook hung through his right leg). Past a bone's ends the scan keeps its own scale, so the hook and the gauntlet
  keep their shape. The hunch stays: the head and neck keep the scan's lean ahead of the hips, and all of the head rides `head`.
- **Right arm:** the bone hook IS the arm. Everything past the right wrist rides bone `hook` (hand.R); the crescent, which curls in by his
  right shin, is split from the leg by place (a capsule round the leg's core). It reaches the ground at rest, as on the sheet (the crescent's lowest edge rides the right foot).
  anchor_claw and anchor_hook_tip sit on its tip: the kit's abyssal arm reaches out from there. While the kit's arm is stretched out, bone `hook` shrinks away (`hide_while_chain`): the kit draws the hook at the arm's end, so anchor_claw
  collapses to the wrist and the stretched arm grows from there; it is back when the arm snaps back.
- **Left hand:** the scan's gauntlet, rigid on hand.L; fingers.L, fingers2.L and thumb.L stay for the clips, unweighted. anchor_fist on its knuckles.
- **Face (grimble_paint.scan_face):** the snub nose is sculpted (grimble_sculpt nose(), rigid on `head`, painted with the face's
  own scan skin and two dark nostrils, grimble_paint.nose). The scan's blurred paint fixed: a heavy lid over the left eye (the squint), silver scrap-metal teeth,
  the gold tooth, purple gums. The loupe is scripted (sculpt monocle(), three glowing lens discs, the gold chain on spring_hangmono).
- **Veins:** found on the atlas by contrast (more purple than the skin round them) and painted VEIN_KEY; warden_look's skin paint_glow keys
  on that colour, so they glow. Bone spurs are the scan's. The sludge drips and puddles are not geometry.
- **Hoard:** v1's sculpt, moved onto v2's back by HOARD_SHIFT (bone `hoard` on hips, keyed for lag). Bells and lanterns hang on
  spring_hangbell*/spring_hanglamp*. Coins: scripts/arch/kits/dredge_coins.gd. The hoard's top is the size cap (height_3d 1.49).
- **Junk ball:** on bone `ball`, shrunk inside the sack at rest; dash clips scale it up round him.
- **FX points:** weapon_muzzle, anchor_gun_root, anchor_claw, anchor_hook_tip, anchor_fist, anchor_ball, anchor_coins, anchor_hoard_top,
  anchor_lamp_r/l, anchor_head_top, anchor_eye (the big lens), anchor_chest.
- **Import:** remove_immutable_tracks=false, LODs on, VRAM atlas with mipmaps.
