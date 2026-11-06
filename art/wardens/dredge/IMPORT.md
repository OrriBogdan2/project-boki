# Grimble, the Scrap King (id and files stay `dredge`): import note, ART-1 rebuild (2026-11-05, 76b folded in)

`dredge.glb`: Meshy body and head scans fitted to the rig, with the hoard, weapons and junk ball sculpted by script, and 33 clips keyed as targets. The friend's Dredge model and its 184 retargeted moves
are gone. Budget: <= 15k triangles with everything (S1's number). One 2048 atlas, 6 slots: skin, cloth, leather, metal, brass, glow. Raw scans in ~/meshy/grimble (never in git).

    godot --headless --path . --import                   # once in a fresh worktree
    godot --headless --path . -- --warden-rig-json --warden=dredge --out=res://art/wardens/src/dredge_rig.json
    ulimit -v 12000000; B=~/tools/blender-4.5.15-linux-x64/blender
    # ~/meshy/grimble: edit.sh (body, hoard and head edits of the sheets), run.sh (three multi-image scans)
    $B -b --factory-startup --python tools/art1/grimble_source.py -- ~/meshy/grimble     # scans -> Low meshes, paint sources; ONLY=head,body picks parts
    $B -b --factory-startup --python tools/art1/grimble_art1.py -- WORK                  # + grimble_sculpt.py, grimble_paint.py
    $B -b --python tools/art1/grimble_clips.py -- WORK/grimble_art1.blend WORK/dredge.glb  # clips on posekit.py, exports
    cp WORK/dredge.glb art/wardens/dredge/dredge.glb && godot --headless --path . --import

- **Scans:** Meshy splits vertices along UV seams: weld before decimating or the mesh comes apart in shards (grimble_source.dup). The body scan's own head and hump are cut, from the paint source too.
  The hoard was scanned too (runH), and lost to the sculpted hoard at the match camera (a speckled lump at 3k), so the sculpt stays.
- **Head:** grimble_head.png, the monocle edited out, the left eye sewn shut, a hollow on the right that the scripted eye fills. Mirrored front view, so the sewn eye is on his left. Neck and collar ride the head.
- **Art:** briefs/art-refs/grimble_FINAL_sheet (master), grimble_turnaround, grimble_weapons. One green eye behind the monocle, the other socket stitched shut.
- **Body:** archetype body: legs 1.5, torso 0.95, shoulder 0.76, neck -0.16, size 1.12. The rig's arms are a fixed length, so the art's long arms need a short neutral body.
  The head hangs ahead of the neck joint: that is the hunch, and it stays in the procedural poses. Head top 1.3x a medium hunter, the hoard's top 1.49x.
- **Weapons (76b):** the hook is on bone `hook` (hand.R), hidden while the kit flies and reels it (`hide_while_chain`, DredgeKit sets CHAIN_OUT). The blunderbuss is on `gun`, a swivel on
  root; the left fist slaps onto its stock to fire (`Lg` in the clips). Gun and Muzzle follow it (data `blade`, bone `gun`). No separate weapon mesh.
- **FX points:** weapon_muzzle, anchor_gun_root, anchor_claw (the kit throws from here), anchor_hook_tip, anchor_fist, anchor_ball, anchor_coins, anchor_hoard_top, anchor_lamp_r/l, anchor_head_top, anchor_chest.
- **Hoard:** bone `hoard` (hips), keyed for lag. Bells and lanterns hang on spring_hangbell*/spring_hanglamp*; the monocle chain on spring_hangmono. Coins: scripts/arch/kits/dredge_coins.gd.
- **Junk ball:** the mesh, brass window frame and chains on bone `ball` sits shrunk inside the sack at rest (so it never shows, clips or no clips); dash clips scale it up round him and spin only it. The root does not spin:
  a crossfade between spinning root poses threw him off his line.
- **Face:** bones jaw, lid, eye, brow. Hand: fingers.L, fingers2.L, thumb.L. Feet: foot.L/R.
- **Import:** remove_immutable_tracks=false, LODs on, VRAM atlas with mipmaps.
- `dredge_fit.json` belongs to the old pipeline and no longer builds this model.
