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

**Regen candidate A (2026-11-20, job 20261120-064603-a4, ext/hunter-regen-dredge-1120, draft until the owner looks):** owner 11-20 asked
for every Hunter rebuilt from the turnaround. Meshy multi-image-to-3d (meshy-7.1, A-pose) from the front/side/back crops of
`~/gens/v95-latest-ta-1119/grimble.png` (run H: a rerun of the first regen's run A recipe, the single goggle and one goo arm kept; 2 of 3 reruns
doubled the goggle), quad remesh to 60k, Meshy auto-rig weights (`v95_swap` `weights` meshy, spec `art/wardens/src/grimble_regen1120.json`)
with `meshy_smooth` 24: worst stretch (`--stretch-check`) 17.2x (first regen) -> 5.75x, live 8.52x; clips over 5x 45 -> 12, live 20; 34 of 54 clips stretch less than live.
The goo arm below the wrist rides `hook` (boxes plus goo-coloured paint low down); the right shin and foot are pinned back on the leg.
Open: the master fuses the goo tip to his right shin, so slabs of goo still tear off that shin in motion (needs a gen with the goo tip clear
of the leg). The gun is on his hip, as in the turnaround (live 11-17 pick: in the gauntlet). Raws, sheets, numbers: `~/gens/hunter-regen-1120/dredge/deep/`.

**Regen r2 (2026-11-20, job 20261120-103741-a6, same branch, replaces candidate A above, draft until the owner looks):** the
front/back crops were re-posed by Meshy image edits (nano-banana-pro, 32 tries, 4 pairs kept) so the goo arm hangs out from his side,
clear of the right leg; the original face is pasted back unedited, side crop unedited; 7 Meshy multi-image runs (2 kept: single goggle,
no extra hand on the goo), run R5 used. Root cause of the shin slabs (r1 too): `v95_swap`'s fit moves everything past the wrist with the
forearm segment, turned from the master forearm onto the rig's, which hangs straight down; a goo arm 39 deg out swung ~40 cm in across
his legs. The spec now declares the master wrist straight below the elbow (no turn), `meshy_smooth` 32, `meshy_reach` thigh [0.1, 0.16],
the goo below the wrist on `hook` by one box, a loose floor drip on `foot.R`. `--stretch-check`: worst 6.56x (ledge only; live 8.52x,
r1 5.75x), median 3.74 (live 4.36), clips over 5x 4 (live 20), 45 of 54 clips below live. Raws, logs, sheets: `~/gens/hunter-regen-1120/dredge/r2/`.
The gun is still on his hip (turnaround), not in the gauntlet.

**Regen r3 (2026-11-20, job 20261120-123155-a6, same branch, draft):** the art-gate failed r2 A (back views only, dark shard under the
loincloth, skin too magenta, goo arm short). Same Meshy master and rig as r2 (nothing re-generated); three `v95_swap` spec keys, new:
`grade` (skin hue 0.86-1.0 saturation x0.65, value x1.3: the toon pass lifts the scan's skin to a hotter magenta; game-render median
saturation 0.62 -> toward the turnaround's 0.41, goo/gold/wood/leather are other hues), `stretch` (the `hook` bone's vertices x1.15 along the
arm's reach by weight: the turnaround's goo arm is ~78% of body height, the scan's ~67%; hook tip/claw anchors moved with it),
`lift_normals` (hip/loincloth vertex normals lean 0.7 to straight up: the hem and its second layer hung face-down, the toon light missed
them and they drew black). `--stretch-check` unchanged from r2: worst 6.56x (ledge), median 3.74, 4 clips over 5x; the shin did not regress.
Still open: at a low side angle (~40 deg, knee height) a small dark gap shows between the hem and the thigh (a hollow under the cloth);
the kept junk ball floats free of the pack in run/crouch side views (no chain); the gun is on the hip (turnaround).
Views (front/3/4/side/back, eye+knee, head, crotch, idle/run/crouch), turntable and clip MP4s: `~/gens/hunter-regen-1120/dredge/r3/`.

**Regen r4 (2026-11-20, job 20261120-143656-a6, same branch, draft; no new Meshy gens):** same master, rig and weights as r3; three of
r3's open items fixed. (1) *Dark gap under the hem / dark patches at the back hip*: the loincloth is a thin one-sided shell and the
toon outline is an inverted hull, so from behind and low the inside of its far panel drew black (the mesh has no hole there; the
scan's pelvis is closed). New `v95_swap` spec key `lining`: every cloth face in a box (paint hue/value ranges) gets a twin wound
the other way, 4 mm inside, same paint and weights, ink room 0: +1840 tris (47.8k). (2) *Junk ball floating in run/crouch*: the
`ball` bone sat under the root and only the barge clips (lunge, lunge_out, pounce) key it, so a dipping body left it in the air. New
spec key `follow` {ball: head} runs `tools/art1/glb_follow.py` after the export: the ball node becomes a child of `head` (the bone
the pack's skin rides), its rest carried into that frame, the three barge clips keep their world track (keys re-expressed per
key). The game checks a variant bone's parent against `extra_bones` in `content/rules/warden_anim/dredge.json`, so that file now
says `"ball": "head"` (a glb and that file must change together, or the model falls back to the procedural one). The ball is also
the clip-sheet and in-game ball: it now hugs the pack in idle, walk, run and crouch. At the first frame of a pounce the ball is
still keyed at its old world rest point (unchanged from live). `--stretch-check` unchanged: worst 6.56 (ledge), median 3.74,
4 clips over 5x (r3 and r4 identical; live 8.52 / 4.36 / 20). Not changed: the master's goo arm hangs out from the side
(r2's re-pose to clear the leg) where the turnaround's hangs to the floor. Raws, logs, proof: `~/gens/hunter-regen-1120/dredge/r4/`.

**Regen r5 (2026-11-20, job 20261120-174139-a1, same branch, draft; no new Meshy gens):** same master, rig and weights as r4.
(1) *Ink room never reached the game*: the kept parts' materials read the vertex colour "Col" in their node tree, so Blender's
exporter wrote COLOR_0 as rgb for the whole mesh and dropped its alpha (the ink room): every vertex drew the full line and r4's
lining twins drew their own (inward) black shell. `v95_swap` now exports `export_vertex_color="NAME"` "Col" (rgba). (2) *The
remaining black crescent under the hem from behind*: the inside of the front panel is painted skin-coloured, missed r4's paint
rule and showed its back; a second `lining` rule lines every face in the crotch box but the thighs' own closed skin
(`skip_bones` thigh, new key): +2544 tris (50.3k). Stretch (54 clips): worst 6.56 (ledge, = r4) / median 3.76 (r4 3.74) /
5 clips over 5x (r4 4; revive 4.98 -> 5.23). Proof: `~/gens/hunter-regen-1120/dredge/r4/` (r5 work: `r5work/`, `r5/`).
