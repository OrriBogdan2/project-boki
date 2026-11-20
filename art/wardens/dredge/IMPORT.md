# Grimble, the Scrap King (id and files stay `dredge`): import note, v2 (the owner's locked redesign, 2026-11-07)

**No floor puddle (2026-11-17, ext/grimble-puddle-1117):** the owner: "we can remove grimbles goo puddle if it helps.
can just have it drip off him a bit on that arm". The puddle's vertices were split between `hook` and `foot.R`, so it tore into
dark spikes when the arm moved. The master is now the 11-17 gun-hand pick minus the puddle
(~/meshy/grimble-puddle-1117/out/nopuddle.glb, scripts in w/): Meshy's faces deleted, nothing new modelled. Every goo-coloured face
(paint saturation > 0.45) under 4.5 cm on the arm side goes, and so does what is then cut off from the body. The goo strands now
end 4.5 cm above the floor in small pointed drip caps, and the crescent's base is filled flat. The foot.R box (and `hook`'s
matching except box) shrank to the foot: x >= 0.09, y <= 0.04. The strand tips and the crescent's base in front of the toes are
on `hook` now. Ported with `v95_to_game.py Grimble --master <that glb>`; 62.8k tris. Stretch: worst 12.64 -> 10.06 (ledge);
throw 10.28 -> 4.86, reel 10.31 -> 6.49, idle 5.43 -> 3.12, mean over 52 clips 7.20 -> 5.02.

**Gun in hand (2026-11-17, ext/grimble-gun-hand):** the master is the owner's 11-17 pick (CURRENT_OVERRIDES: weapons-fix-1116b/Grimble/hand/grip1117/final/cand.glb,
"grimble a seems fine"): the same body with the blunderbuss off the belt and in the iron fist, its own node. The swap
spec puts it rigid on `hand.L` (a region box round it), weapon_muzzle and anchor_gun_root sit on its muzzle and stock on
`hand.L` (`anchor_bones`), and the `gun` bone stays in the rig, unweighted. The left forearm and hand are detached from
the left thigh and hips (they touched once the gun box no longer covered them), and the patched belt keeps the old gun
boxes, now on `hips`. Stretch: worst 12.64 (ledge) against main's 8.37; main's own spec on this master gives 47.66.

**v95 (2026-11-11):** the mesh is the v95 master with the appeal3 face and calves (~/meshy/v95/Grimble/r2/appeal3/cand_b.glb: the face
repainted from the v2 art, with scrap-metal teeth, the gold tooth, a dark gap, purple lips and the smug squint; the calves 12% slimmer;
pick.txt beside it) put on this same skeleton, clips and anchors by tools/art1/v95_swap.py with art/wardens/src/grimble_v95.json
(docs/art/wardens/V95_SWAP.md; shots in docs/shots/grimble-appeal/, the first swap's in docs/shots/grimble-v95/).
14.9k triangles, one 2048 atlas, 5 slots (skin, leather, metal, brass, glow). No extra hand: the slime arm and bone crescent on
his right, the gauntlet on his left. What below differs: the hoard is v95's own (height_3d 1.5), the junk ball rides at its back,
the anchor_lamp_l halo is gone (one lantern), and skin_relax runs without cuts (no holes; worst stretch 2.2x to 5.3x per clip, so the
1.3x line in the Stretch note no longer holds). The notes below are v2's and still say how the rig, clips and kit work.
warden_look's `closeup` {fov 36, up -0.3} aims `--warden-shots`' two head shots at his face: the hunch carries it below and ahead of
HeadPivot, so without it they framed the hoard.

`dredge.glb`: one Meshy scan of the v2 turnaround fitted to the rig (body, head, bone-hook arm, gauntlet), v1's sculpted hoard,
bells, lanterns, blunderbuss and junk ball on top, the loupe scripted, and 40 clips keyed as targets. Budget: <= 15k triangles
with everything (14.9k). One 2048 atlas, 6 slots: skin, cloth, leather, metal, brass, glow. Raw files in ~/meshy/grimble_v2 (never in git).

    godot --headless --path . --import                   # once in a fresh worktree
    godot --headless --path . -- --warden-rig-json --warden=dredge --out=res://art/wardens/src/dredge_rig.json
    # ~/meshy/grimble_v2: edit.sh (the turnaround's front, left and back with the hoard, blunderbuss, loupe and sludge edited out), then
    #   meshy_task.py create runA in/front.png in/left.png in/back.png --texture-refs (same)
    ~/meshy/grimble_v2/build.sh source                   # grimble_source.py -> grimble_art1.py -> grimble_clips.py; INSTALL=1 copies the glb here

- **Art:** briefs/art-refs/grimble_v2/ (ext/agent-briefs): grimble_v2_turnaround.jpg (FINAL) and grimble_v2_master_sheet.jpg; index.md's
  "Canon notes for 3D and animation" win. No nose or nostrils; a three-lens brass loupe over his right eye; the left eye a smug squint.
- **Scan fit (grimble_source.py):** the limbs keep the scan's spread and lean and take the rig's joint heights (moved onto the rig's narrow
  arms and wide hips, the hook hung through his right leg). Past a bone's ends the scan keeps its own scale, so the hook and the gauntlet
  keep their shape. The hunch stays: the head and neck keep the scan's lean ahead of the hips, and all of the head rides `head`.
- **Right arm:** the bone hook IS the arm. Everything past the right wrist rides bone `hook` (hand.R); the crescent, which curls in by his
  right shin, is split from the leg by place (a capsule round the leg's core). It reaches the ground at rest, as on the sheet (the crescent's lowest edge rides the right foot).
  anchor_claw and anchor_hook_tip sit on its tip. The Abyssal Hand is this arm: while it is out, `WardenReach` (data `reach`) lays upper_arm.R and forearm.R on the line to the hook and stretches forearm.R, so the hand and everything on `hook` (the slime hand, the crescent) sit at the tip (owner playtest 11-11).
  collapses to the wrist and the stretched arm grows from there; it is back when the arm snaps back.
- **Left hand:** the scan's gauntlet, rigid on hand.L; fingers.L, fingers2.L and thumb.L stay for the clips, unweighted. anchor_fist on its knuckles.
- **Face (grimble_paint.scan_face):** the scan's blurred paint fixed: a heavy lid over the left eye (the squint), silver scrap-metal teeth,
  the gold tooth, purple gums. The loupe is scripted (sculpt monocle(), three glowing lens discs, the gold chain on spring_hangmono).
- **Veins:** found on the atlas by contrast (more purple than the skin round them) and painted VEIN_KEY; warden_look's skin paint_glow keys
  on that colour, so they glow. Bone spurs are the scan's. The sludge drips and puddles are not geometry.
- **Hoard:** v1's sculpt, moved onto v2's back by HOARD_SHIFT (bone `hoard` on hips, keyed for lag). Bells and lanterns hang on
  spring_hangbell*/spring_hanglamp*. Coins: scripts/arch/kits/dredge_coins.gd. The hoard's top is the size cap (height_3d 1.49).
- **Junk ball:** on bone `ball`, shrunk inside the sack at rest; dash clips scale it up round him.
- **FX points:** weapon_muzzle, anchor_gun_root, anchor_claw, anchor_hook_tip, anchor_fist, anchor_ball, anchor_coins, anchor_hoard_top,
  anchor_lamp_r/l, anchor_head_top, anchor_eye (the big lens), anchor_chest.
- **Import:** remove_immutable_tracks=false, LODs on, VRAM atlas with mipmaps.
- **Stretch (no edge past 1.3x its rest length in any clip; `--stretch-check --wardens=dredge`):** the source weights are near-hard capsules,
  so short edges stretched up to 25x (hook on thigh, wrist, waist). grimble_clips.py now calls tools/art1/skin_relax.py before the export:
  it blends the weights of stretched vertices toward their neighbours' (400 passes), then deletes the triangles still over 1.25x and caps the
  holes (about 2.4k of 14.9k triangles, mostly seams between the arms, hips and hook). Worst now 1.28. Spring chains and the junk ball's uniform growth are exempt.

**Barge clips (2026-11-12):** `lunge` is re-keyed (the ball stays closed from shove to shove) and `lunge_out` is new, by `tools/art1/grimble_barge_clips.py` run on the .glb with no Blender (the .blend is not needed); `tools/art1/grimble_clips.py` still has the old `lunge` keys, so a clip rebuild from the .blend must re-run that script. Why and how it plays: docs/heroes/dredge.md, "Animation timing".

**board1117 A colours (11-18, ext/hunter-picks-tcg-1117):** owner 11-17 "grimble your call", coordinator call A (masked grade of
the grip1117 master's 8k paint: grey-mauve skin, legs matched to the torso, darker pack/belt/loincloth, gun bell iron grey and
stock wood muted; goo, gold and goggle untouched). Master `~/meshy/v95/Grimble/board1117/A/cand.glb` has grip1117's mesh and
UVs, so only `v95` (body) and `v95c` (gun) were swapped with `tools/art1/glb_image_swap.py` (game image + resize(A) -
resize(live) at the game size, JPEG q92); the shard/puddle fixes, rig and clips are byte-equal.
