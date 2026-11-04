# Warden 3D pipeline (Meshy image-to-3D -> bake -> Blender fit -> WardenSkeleton .glb)

**Start from docs/art/wardens/RECIPE_95.md** (2026-11-04: the golden recipe from Vex r3d, run by
`tools/meshy/recipe.py` from a per-Hunter spec). The sections below are the history and the details it builds on.

Owner decision 2026-11-04 00:30 UTC: the scripted-primitive Blender meshes ("made of shapes") are replaced by Meshy
image-to-3D. The skeleton contract (RIG_CONTRACT.md), retarget, WardenGlb loader and the Settings > Video > Warden
models toggle stay. Owner 05:00/05:15 UTC: Meshy only, at its best settings; Vex r3 (this recipe) is the bar.

## Per-Warden checklist (r3; Vex is the reference: art/wardens/src/vex_bake.json, vex_fit.json)
B = `~/tools/blender-4.5.15-linux-x64/blender -b --factory-startup --python`. T = `python3 -I tools/meshy/meshy_task.py`.
Raw files under ~/meshy/<name>/ (never in git). <id> is the archetype (gunslinger), <name> the art name (vex).
**Branch:** merge ext/warden-vex-r3 into your paused branch and keep your own generic fixes, which this branch does not
have: Cinder's Models.hunter bulky-folk `legs` fix (origin/ext/warden-meshy-cinder), Pin's own-Mag tag in
`--warden-glb-check` (ext/warden-meshy-pin), Zedran's weapon ground clearance and crack-glow (ext/warden-meshy-zedran),
Ryzz's emissive layer `use_emit`/`emit_tex` (ext/warden-meshy-ryzz). Already here: Cinder's `slot_rules` and
`fit_weights` (same code), Zedran's `--warden-rig-json` skip of an emptied Mag.

0. **Gate:** the owner approved the Warden's round-2 art and IMG has its turnaround and side view (02:40 rule).
1. **Art:** `git show origin/ext/imagegen:docs/art/gen/wardens_r2/<name>_turnaround_2k.webp` (and `_side`,
   `_portrait_2k`) into ~/meshy/<name>/art, `ffmpeg -i x.webp x.png`. Note the side of every asymmetric piece;
   **never mirror**. The turnaround wins over the side view and the portrait where they disagree.
2. **Crops:** copy tools/meshy/vex_inputs.py to `<name>_inputs.py`, set VIEWS (column ranges on the 1568 px sheet)
   and TOP/BOTTOM, run `B tools/meshy/<name>_inputs.py -- art/<name>_turnaround_2k.png ~/meshy/<name>/prep2k` (four
   square views, the sheet's ground line painted out: Meshy built a floor slab from it). Enlarge each 2x:
   `ffmpeg -i prep2k/view0.png -vf scale=1582:1582:flags=lanczos in/view0.png`.
3. **Pose fix (only if the art welds a limb to the body):** Vex's left hand on her hip came out fused to the hip and
   could not be posed. Meshy image-to-image redraws one view (nano-banana-pro, 9 credits):
   `T edit ~/meshy/<name>/edit_front prep2k/view0.png --prompt "Edit this character concept art. Keep everything
   exactly the same: <the outfit, colours, art style, framing, grey background> ... Change ONLY her left arm ...: make
   it hang straight down, relaxed, a little away from her body ... Nothing else changes."` Do front, 3/4 and back;
   compare each with the original side by side and redo any that changed something else.
4. **Body run** (40 credits, ~4 min): `T create ~/meshy/<name>/run1 front.png 34.png profile.png back.png
   --texture-refs front.png 34.png profile.png back.png --enhance off`. The defaults are Meshy's best: meshy-7.1,
   `should_remesh` false (~1.2M triangles, the bake source), Ultra `geometry_resolution` 2k, the meshy-7 texture
   model at 8k with PBR, A-pose. Front first, then the turnaround's own 3/4, near profile and back. Judge the four
   thumbnails and a flat (emission) render of the head: face, eyes, the signature pieces, the right sides.
   Budget: one run; a second only if a piece is missing or wrong.
5. **Bake** (credit-free, ~1 min): copy art/wardens/src/vex_bake.json to `<name>_bake.json` (high = the run's glb.glb,
   out, head centre and radius in the Meshy frame: +Z up, facing -Y), run `B tools/meshy/bake_warden.py --
   art/wardens/src/<name>_bake.json`. It decimates a welded copy to 40k triangles (10k on the head), unwraps it with
   flat projections of a smoothed copy (self-overlapping islands projected again, nearer the real surface; the head
   2.5x the texels) and bakes the dense mesh's 8k base colour onto a 4096 atlas (Cycles, selected to active,
   emission, 16 px margins). Look at bake/atlas.png and a head render of bake/low.glb beside the dense one.
6. **Proportions:** measure the joints on a gridded orthographic render (front and side) of bake/low.glb. Set the
   archetype `body` in content/archetypes/<id>.json (head, legs, neck, build, chest, size) so the rig's joints land
   on them and `--warden-model-check`'s width range passes, then `godot --headless -- --warden-rig-json --warden=<id>`.
7. **Fit spec:** copy art/wardens/src/vex_fit.json to `<name>_fit.json`; `body_glb` is the bake's low.glb.
   - `joints` (Meshy frame), `max_tris` 40000, `chunk` (head 1.12, free hand 1.25, girth 1.14: game proportions).
   - `slot_rules` + `slot_vote` 4: the toon slots by region and painted colour, then a neighbour vote (a baked mesh's
     UV islands are too big for Cinder's per-island vote). A small `glow` box for a lens or glowing eye.
   - `touch_up`: warm the skin slot toward the art's skin (`warm`, k 0.45); a lens or eye colour.
   - `cut_boxes` (Meshy frame): a strand Meshy floats in front of the face. `delete_boxes` (fitted frame: her right
     +X, front +Y, soles on 0): dangling pieces (Vex's feed belt behind her hip).
   - `fit_weights` true (weights from the A-pose, Cinder's fix); `weight_rules`: pieces bone heat gives to the wrong
     bone (Vex's back drum and belt to the hips; check the back in the stance shots).
   - `gun_arm` for a weapon fused to an arm: as r2, plus `trim_boxes` (Gun frame) for belt bits cut off with it and
     `slot` "metal". The forearm and hand weights left on the body go to the hips.
   - `cap_holes` 0.3 (only openings with a rim under 0.3 m: a long cut rim capped into a dark slab), `ink_room`
     0.02 (the ink shell's room per vertex, see Godot), `normal_smooth` 8, `lift` [0.9, 1.03, 1.12] (gamma, gain,
     saturation), `atlas_px` 2048.
   - Run `B tools/meshy/fit_warden.py -- art/wardens/src/<name>_fit.json`.
8. **Import:** `godot --headless --import`; `meshes/generate_lods=false` and `force_disable_compression=true` in the
   .glb's .import, import again; write art/wardens/<name>/IMPORT.md.
9. **Shots** (xvfb-run, opengl3, on a scratch branch with ext/warden-stance): `--warden-shots --wardens=<id>
   --shots-dir=<dir> --sheets=<dir with <id>.png>` (turnarounds, close-ups, front_34 and back_34, moves) and the
   clean match frame `--arena=<id> --record=2 --no-tips --arena-demo=pose --demo-zoom=1.0 --arena-shot=<png>` with a
   x4 crop. Composite with `B tools/meshy/compose.py`. Look at every one, the back too.
10. **Checks** (fresh XDG, real output only): `--warden-glb-check`, `--warden-model-check`, `--mantle-look-check`,
    `--move-feel-check`, `--<id>-combo-check`, `--weapon-clip-check`, `--warden-stance-check` (scratch branch),
    `python3 tools/health.py --strict`, style_lint.
11. **Log and commit:** every Meshy task in the run log below; `git grep` for the key's prefix finds nothing.

**Cost per Warden:** 40 credits for the body run, 27 more if a pose fix is needed, 40 for a spare run: about 70-110.

## How it works in the game (WardenGlb, shaders)
- A painted atlas is shaded by `WardenGlb.PAINTED`: soft, near-white toon light (no violet shadow tint, no warm
  terminator band, no sun self-shadow, no procedural brushwork), a light rim and top light, and `far_lift` (the hero
  shader brightens and saturates it from 8 to 18 m away, the match camera at ~23 m; close-ups keep the paint).
- The ink shell (outline.gdshader) is half the procedural heroes' width (`INK_WIDTH`) and, with `ink_mask`, never
  grows past the vertex colour's alpha x 2 cm: the fit writes how much room each vertex has before the shell would
  poke through a thin strand, a frayed hem or a fold (the r2 ragged fringe). Hair, eyes and glow have no shell.
- Meshy's metallic, roughness and normal maps are not used (they read as plastic under the toon ramp).

## What r1/r2 taught (kept in the recipe)
- Never filter or decimate across Meshy's UV crumbs (r2's patchy facets and smeared face): bake to new UVs instead.
- Projecting the 2000 px sheet onto the model is coarser than Meshy 7.1's 8k texture: r3 does not project; the
  touch-ups are by slot and box. A separate head run from the portrait doubled Vex's lens: not needed with 7.1.
- Meshy winds ~8% of its triangles inward (the fit turns them out; a cut piece that ends up inside out is turned
  over by its signed volume). Shading normals are neighbour-averaged, weighted so two sides of a thin strand never mix.

## Secrets
- `MESHY_API_KEY` lives only in `~/.config/boki/secrets.env` (chmod 600) on the build box, or in the environment.
  Never in the repo, logs or shots. tools/meshy/meshy_task.py reads it and never prints it.

## The reference recipe (Vex r3c, 2026-11-04; superseded by RECIPE_95.md)
Vex r3c is the model the owner reviews as the recipe; the others wait for his OK. Worktree on a branch of
ext/warden-vex-r3b. B = `~/tools/blender-4.5.15-linux-x64/blender -b --factory-startup --python`. Raw files in
~/meshy/<name>/ (never in git). Files: art/wardens/src/<name>_bake.json, <name>_fit.json; content/rules/
warden_look.json; content/archetypes/<id>.json `body`; content/rules/warden_stance.json (ext/warden-stance).
1. **Read the art and its kit note** (wardens_r3 or r2 on ext/imagegen: turnaround, side, portrait, KIT.md). Note the
   side of every asymmetric piece (never mirror) and everything that hangs loose: braids, tails, hoses, cords,
   capes, held props, a hand on the hip.
2. **Edit the inputs, not the mesh** (Meshy image-to-image, nano-banana-pro, 9 credits a view; `meshy_task.py edit`,
   `--aspect 9:16` on a 9:16 crop so the figure fills the frame):
   - take out what hangs loose (it fuses to the body; it is built as geometry in step 7) and free hands that rest on
     the body; say "hidden behind her body" for a limb a side view should not show;
   - look at every edit beside its crop; redo a view rather than accept a changed design; paint small invented
     details out by hand (Vex: a green lens on the back ring).
3. **Meshy** (`meshy_task.py create`, its defaults: meshy-7.1, geometry 2k, meshy-7 texture 8k, PBR, no remesh,
   a-pose): the four edited views, padded square, as images and texture refs. Two runs, enhancement off and on
   (80 credits); keep the one whose face is closest to the portrait. Log both in the run log.
4. **Bake** (`B tools/meshy/bake_warden.py -- <name>_bake.json`): ~36k triangles (9k on the head), a 4096 atlas.
5. **Measure** on gridded orthographic renders of the dense mesh (front and side): the joints (Meshy frame, +Z up,
   facing -Y) and, for a weapon fused to an arm, its elbow and tip. Body proportions:
   - `scale_joints: ["hip.L", "shoulder.L"]`: the torso keeps the art's size;
   - set the archetype's `body.legs` (and `size`, to keep the sheet height within 4%) so the rig's hips land near
     the art's: `godot --headless -- --warden-rig-json --warden=<id>`; the hit radius never changes.
6. **Fit** (`B tools/meshy/fit_warden.py -- <name>_fit.json`): `snap_y: false` with measured depths; a fused weapon cut
   by direction (`r_in` toward the body, `r_side`, `r` outward, `r_elbow`), `cap_flat`; slot rules that claim metal
   parts by box before the skin test; `fit_weights`, `chunk` (head ~1.12-1.16, hand 1.2, girth 1.06).
7. **Pieces as geometry** (tools/meshy/warden_parts.py, positions `rel` to a bone so they follow the rig):
   - braids / tails / cords: `braids` (woven strands, wraps, bolts, a tuft) on `spring_` chains that swing;
   - hoses and cables between body and weapon: `hoses`, weighted along their length from one bone to another
     (Vex: hips -> upper_arm.R -> forearm.R) so both ends stay on while the arm aims;
   - eyes, lenses, gems: `lens` (a glowing dome on the glow slot); cut the scan's own one first (`cut_r`).
8. **Paint-over, credit-free**:
   - `smooth` (edge-preserving, within UV islands), then `ramps` of the art's own colours per slot and texel hue
     (sample them from the art: hair, trims and tattoos, blacks, leather, skin, gunmetal, brass), `despeckle`;
   - the face: see **Face rules (r3d)** below (from the flat-lit face sheet, by landmarks); `project_late` also
     paints the chest and belly over the finished atlas from the edited front view,
     each with a registration measured on the mesh's own render (`tools: register.py`, ~20 px better than the
     figure-height guess); `keep_hue` keeps the scan's hair, `skip_art` keeps the art's hair shadows off the skin;
     the body's skin ramp uses the art's skin so there is no seam where the projection ends.
9. **Godot**: import; the extracted atlases lossless (`compress/mode=0`, `detect_3d/compress_to=0`); the .glb's
   `generate_lods=false`, `force_disable_compression=true`.
10. **Shading** (content/rules/warden_look.json, keyed by the art name): where the shared painted look washes a
    colour out (light skin under the top light and rim, dark metal under the rim), turn those down per slot; glow
    slots brighter for match-zoom reads.
11. **Stance** (content/rules/warden_stance.json on ext/warden-stance): the carry of the model's weapon, checked
    idle and in the run blend (`--warden-shots` poses_game, moves).
12. **Checks** (godot queue wrapper, fresh XDG, real output only): --warden-glb-check (incl. the spring chains),
    --warden-model-check, --mantle-look-check, --move-feel-check, --<id>-combo-check, --weapon-clip-check,
    --warden-stance-check (on the stance branch), `python3 tools/health.py --strict`, `python3 tools/style_lint.py
    --strict`.
13. **Shots** (`--warden-shots`, the Arena match frame `--arena=<id> --record=2 --arena-demo=pose --demo-zoom=1.0
    --arena-shot=<png>`), composited beside the turnaround and portrait; look at every one and redo what does not
    look like the art. Then the secret grep, commit, push; S2 reviews the shots before hero-shots-s2.

## Face rules (r3d, Vex face pass, 2026-11-04): for every Warden's face
The face is what the owner checks first. Paint it from the **flat-lit straight-on face sheet** (`<name>_face`, ext/imagegen
12:40; the portrait only if there is none: it is tilted and lit by its scene), never from the turnaround, with these
rules (fit spec `project_late`, the "face" entry of art/wardens/src/vex_fit.json; read the KIT/REFS note first for what
to ignore):
1. **One slot for the whole face.** Look at a flat slot map of the head first (tools/meshy/slot_map.py). Meshy's colours
   split a face between skin, cloth (pale highlights under the skin rule's saturation floor), hair (a green or
   blue iris) and metal (tan shading); each slot shades its own way, which reads as patches and as a "seam" along
   the jaw. Slot rules, in this order: the eye's box -> skin (before the hair rule), the hair rule, round parts
   by an ellipse (`circle` [x, z, rx, rz]: an eye plate) -> metal, then the face's front box -> skin.
2. **Align by landmarks, not by a scale.** A sheet has its own proportions (Vex's face sheet has a 22% longer
   lower face than the Meshy head; the portrait is also tilted 10 degrees). Read 12-16 landmarks on a gridded front
   render of the Meshy-frame mesh (tools/meshy/face_grid.py, a known px/m) and on the sheet (tools/meshy/grid_crop.py; read them on gridded
   crops, never on a downscaled whole image: those reads were 100 px off): both eyes (centre, inner and outer
   corners, the liner's wing), the brow (inner end, peak, outer end), the nose tip, the mouth's corners, the lips'
   parting, the lower lip, the chin, the jaw. `warp` fits a thin-plate spline through them (`smooth` 0.002; the
   logged residual should stay under a pixel). The paint then follows Meshy's sculpted eye, nose and mouth.
3. **Never project the art's outline.** The art's ink contour around the face, projected onto a mesh whose jaw is a
   little wider, is the dark jaw seam. `mask`: the face by exclusion (`exclude`: the hair, the sheet's grey ground)
   so plates and panels drawn on the face belong to it, closed over the features (`close` ~26 px fills the eyes
   and lips), eroded past the outline (`erode` 6 px on a 2000 px sheet).
4. **Carry the skin past the outline instead of stopping at it.** `inpaint: "outside"` fills everything outside the
   eroded face (and the art's own hair across the face, its plate and bracket: `skip_art`, `skip_art_box`) from the
   skin around it, fading to the skin's mid tone; the projection then fades only at the mask box's edge (`edge`
   ~28 px), so the blend into the body's skin happens under the hair, never on the cheek.
5. **Blend, don't overwrite.** `feather` [0.12, 0.5] on how much a face turns away; `slots` the face's own slots
   (Vex: skin, and metal for the eye plate the sheet draws: it paints the angular plate onto Meshy's round one;
   `exclude_circles` only for a part you keep as geometry). The body's skin ramp takes the sheet's own skin
   (sample its face, p5..p95), so the face and the neck, arms and belly are one tone. Then look for creases the
   projection could not reach (faces turned away: Meshy's dark paint there is a thin line) and lift them with a
   `touch_up_late` (`val_max`: dark texels only, flat to the mid skin tone).
6. **Eyes, lips, tattoos are the sheet's paint; the hair crossing the face is not.** With the warp the iris, the
   liner, the lids, the brow, the circuits and the lips land on Meshy's own eye and mouth. Hair of the same hue as a
   tattoo or trim (Vex's circuits are hair-green) is told apart by thickness, not colour: `hole_open` (~12 px) keeps
   only thick strands as holes, so thin lines and dots stay. Anything drawn on a part that turns away from the front
   (Vex's jaw panels on the jaw's sides) projects as a faint smeared line, the "seam": leave it out
   (`skip_art_poly`, filled from the skin) or build it as geometry; never let it half-project.
7. **A lens or eye that glows needs a halo to read at the match camera** (a 3 cm lens is a pixel at 23 m): an anchor
   on the lens (`anchor_<name>`, the fit exports it) and a `halos` entry in content/rules/warden_look.json (radius in
   screen pixels, `near_d` / `far_d` so close-ups keep the lens itself; a core whiter than the hair so it doesn't
   merge into it: Vex [0.62, 1.0, 0.66], strength 2.2, px 2.4). Don't make the lens bigger: compare its size to the
   eye spacing in the face sheet first.
8. **Check it like the owner does:** the front and 3/4 close-ups beside the portrait (r3d_closeup_vs_art,
   r3d_closeup_34_vs_art), the 3/4 for the jaw and the straps, the match frame for the halo.

## r3b (Vex redesign, 2026-11-04): what changed
(The owner picked r3b at 09:00: it ships as art/wardens/vex/vex.glb with vex_fit.json / vex_bake.json; r3c
is its polish pass, above.)
The owner-approved redesign (ext/imagegen wardens_r3: green braids, cyber eye, minigun forearm) built beside the
shipped Vex as the design variant `vex_r3b` (RIG_CONTRACT "Design variants"). Files: `art/wardens/src/vex_r3b_bake.json`,
`vex_r3b_fit.json`; raw files in ~/meshy/vex_r3b/.
1. **Inputs, edited before Meshy** (Meshy image-to-image, nano-banana-pro, 9 credits each, 9:16 crops of the turnaround
   so the figure fills the frame): her left hand comes off her hip and hangs (Meshy fuses a hand on a hip), and
   everything that hangs loose is taken out: **both braids** (built as geometry, step 5) and the hoses from the
   backpack to the gun (Meshy fuses them to the hip). The side view had to say "her left arm is hidden behind her
   body" (the first edit drew it hanging behind her back). A green lens the edit invented on the back ring was
   painted dark by hand. Then each view is padded square on its own grey.
2. **Meshy at max** (meshy-7.1, geometry 2k, meshy-7 texture 8k, PBR, should_remesh false, a-pose, the four views
   front / 3-4 / side / back as images and texture references). Two runs, image enhancement off and on: off kept
   (its face has the art's sultry smirk; on gave a rounder, cuter face and stringy hair cards).
3. **Bake** (bake_warden.py): 1.15M -> 36k triangles (head 9k), new UVs, 4096 atlas baked from the dense mesh.
4. **Fit** (fit_warden.py), new options:
   - `scale_joints`: the body is scaled so the hip-to-shoulder span is the rig's (the redesign is long-legged:
     scaling by the hips' height stretched her torso 30% and her upper arms 40%; now only the legs shorten, the
     chunkier game build). `snap_y: false` keeps the measured depths (hair behind the neck moved the neck 11 cm).
   - The gun-arm cut by direction: `r_in` toward her body, `r_side`, `r` on its outer side, `r_elbow` near the
     elbow (the hip is 9 cm from the gun's axis; one radius either left the housing on the body or cut her side).
   - `cap_flat`: a cut's cap takes one rim texel (rims across UV islands smeared unrelated paint over caps).
   - **Paint-over** (`smooth`, `ramps`): an edge-preserving filter within UV islands takes out Meshy's grain, then
     every texel is recoloured by a ramp of the art's colours by slot and by its own hue (hair, the green trim and
     tattoos, the blacks, leather, the body's skin, gunmetal, brass); the face keeps its own paint (smoothed).
   - Slot rules claim her mechanical side, the backpack and the collar as metal before the skin test (tan brass
     read as skin).
5. **Braids and eye as geometry** (tools/meshy/warden_parts.py, fit spec `braids`, `lens`):
   - Each braid: three strand tubes woven round a path that is draped against the body (never through it), copper
     wire wraps, steel bolts through some of them and a tuft of locks; its own small atlas (flat colours darkened by
     an AO bake where the strands cross). It rides a chain of `spring_braid_*` bones under the head, which the game
     swings (RIG_CONTRACT "Spring chains").
   - The cyber eye: a brass rim and a glowing lens dome (the `glow` slot) on the eye plate; the scan's own lens and
     the spike Meshy gave it are cut out first.
6. **Godot:** the extracted atlases imported lossless (compress/mode 0); generate_lods off.

## Stage 1 hybrids (S2 fan-out, 2026-11-04)
Stage 1 (WARDEN_STAGE1_BRIEF) is generation, bake, rig fit and first shots only: the fit spec keeps `lift` and the
slot rules but no `palette_from`, `smooth`, `ramps`, `project` or `touch_up` (the paint-over is stage 2, the Vex
r3c recipe). Pieces Meshy can't give cleanly are scripted (tools/meshy/hard_parts.py, fit spec `parts`):
- **Held pieces**, modelled in their rig node's space and exported unskinned: `weapon` (the Gun node's; a hammer
  in its `Hammer` pivot's, where WardenGlb seats it) and `shield` (the left hand's `Shield` node's). Their own
  small atlas of painted cells (ice, iron, oak, leather) on the toon slots.
- **Cards and tubes on spring chains:** wings cut out of the art's back view (outline and paint from the
  sheet's pixels, two layers), a spaded tail draped clear of the legs. Chains named `spring_wing*` fold back about
  their root while the Warden skates (root meta `wing_fold`, set by HunterAnim from the skate dash).
- **Split:** faces of some slots made their own mesh on one bone (Claire's horns).
- **feet_forward:** the fit fails if a foot points away from the body's forward (the backwards-skate catch).
- The `ice` toon slot: a cold fresnel rim and a little gloss, no real transparency (WardenGlb.ICE).

## Commercial terms (checked 2026-11-04, meshy.ai/terms-of-use section 3.2)
- **Paid plans:** the customer owns the output ("to the extent possible under applicable law") and can keep it private.
- **Free plans:** CC BY 4.0 with attribution to Meshy. **Use the owner's paid key only.**
- **Training:** Meshy may train on inputs and outputs on non-Enterprise plans unless you opt out (email support@meshy.ai). This is the owner's call.
- Rigs and animations Meshy supplies are licensed only as part of the output. We use our own skeleton and animations.

## Owner direction for the Warden runs (2026-11-04)
- Each Warden needs its approved round-2 art and the owner's "go for 3D" (02:40 gate; 04:15 approved all).
- Flat, clean, bright painted colour with no mottled grain; slightly chunkier game proportions (bigger head and
  hands, thicker silhouette); item 52's stance from content/rules/warden_stance.json at runtime (the fit keeps the
  A-pose rest).

## Run log
| Warden | Date (UTC) | Task id | ai_model | Settings | Credits | Result |
|---|---|---|---|---|---|---|
| Vex | 2026-11-04 01:07 | 01a1a418-55d6-76bf-86ce-cb71091a721c | latest | front/side/back (rifle painted out, body mirrored, head kept), 30k, PBR, A-pose | 30 | Dropped: mirrored by mistake (the art's mechanical arm is her RIGHT) |
| Vex rifle | 2026-11-04 01:11 | 01a1a41b-f6c9-7060-b540-a7135086d729 | latest | rifle alone, front + back views, 6k, no pose | 30 | Kept (r1): barrel, vented shroud, scope, strips |
| Vex | 2026-11-04 01:39 | 01a1a436-0c27-728b-a0dc-c691249a17aa | latest | front/side/back unmirrored (rifle painted out), 30k, PBR, A-pose | 30 | Kept (r1): the body |
| Vex head | 2026-11-04 01:39 | 01a1a436-0beb-73df-96db-5461affe02bf | latest | portrait head + profile head, 20k, no pose | 30 | Dropped: two lenses (the profile's lens on the other eye) |
| Vex head | 2026-11-04 01:44 | 01a1a43a-787d-7053-849c-5f8fb573eb1f | latest | portrait head only, 20k, no pose | 30 | Kept (r1): the portrait's face |
| Vex retexture | 2026-11-04 02:12 | 01a1a454-5cdc-703c-ab73-b40134e4661b | meshy-7 retexture | run-3 body, multiview front/side/back, original UVs, no PBR | 10 | Dropped: no clear gain |
| Vex r2 | 2026-11-04 03:29 | 01a1a49a-5239-71e0-9906-570cbfd9715e | latest | r2 turnaround (2x enlarged): front, 3/4, near profile, back; 30k remesh, PBR, A-pose | 30 | Kept (r2), superseded by r3 |
| Vex r3 A | 2026-11-04 05:18 | 01a1a4fe-3775-70b7-b5c0-e05bea79b631 | meshy-7.1 | 4 views (ground line out, Lanczos 2x) + the same 4 as texture refs; no remesh, geometry 2k, meshy-7 texture 8k, PBR, A-pose, enhancement on | 40 | Dropped for I: clean painted 8k texture, crisp face, monocle and streak; the left hand fused to the hip |
| Vex r3 B | 2026-11-04 05:18 | 01a1a4fe-3fd5-74c7-9f9a-e73b5a234406 | meshy-7.1 | as A, texture model meshy-n1 (2k, no PBR) | 35 | Dropped: N1's 2k base colour is softer than meshy-7's 8k (face, vest symbols) |
| Vex r3 C | 2026-11-04 05:18 | 01a1a4fe-4700-7489-b369-71f09d7307f5 | meshy-7.1 | front view only, image-to-3d, geometry 4k, 8k | 40 | Dropped: muddier back and gun, a dark lens |
| Vex r3 D | 2026-11-04 05:18 | 01a1a4fe-4ee9-74c5-bdf2-c78755ee814a | meshy-7.1 | front, OLD side view (ponytail), back, 3/4 | 40 | Dropped: no better than A |
| Vex r3 E | 2026-11-04 05:21 | 01a1a501-79ee-77ab-88d1-f8c97ded7247 | meshy-7.1 | front, NEW side view (bun), back, 3/4 | 40 | Dropped: lens half covered by a strand, no better than A |
| Vex r3 F | 2026-11-04 05:30 | 01a1a509-426e-7352-b3a4-7eaa453c160c | meshy-7.1 | as A, image_enhancement off | 40 | Dropped for I: a little closer to the art's colours than A |
| Vex r3 edits | 2026-11-04 06:05 | 01a1a529-b795-74db-ab31-a22fef29e8fc, 01a1a52b-d9ef-7228-a591-85ca6a73e202, 01a1a52b-d9d6-710d-8611-5af7fb429bf3 | nano-banana-pro (image-to-image) | front, 3/4 and back redrawn with her left arm hanging free | 27 | Kept: nothing else changed |
| Vex r3 G | 2026-11-04 06:09 | 01a1a52d-498d-75ba-a37f-23ec971e5162 | meshy-7.1 | edited front, NEW side, edited back, edited 3/4; enhancement off | 40 | Dropped: the side view's strands over the monocle |
| Vex r3 H | 2026-11-04 06:09 | 01a1a52d-53e5-76aa-82c5-a2cd17f0633d | meshy-7.1 | as G, enhancement on | 40 | Dropped: as G |
| Vex r3 I | 2026-11-04 06:15 | 01a1a532-a31e-7094-8165-4b6b53596bec | meshy-7.1 | edited front, edited 3/4, the turnaround's near profile, edited back; enhancement off | 40 | **Kept**: free left arm, clean face and monocle, the art's colours |

Vex total: 19 tasks, 572 credits (r3: 12 tasks, 382 credits; balance 5,500 before r3).

### Vex r3b (redesign) runs, 2026-11-04 (balance 5118 before, 4993 after: 125 credits)
| Warden | Date (UTC) | Task id | ai_model | Settings | Credits | Result |
|---|---|---|---|---|---|---|
| Vex r3b edit front | 06:41 | 01a1a54a-4297-7610-aaf7-f5f4946778bb | nano-banana-pro (image-to-image) | 9:16 crop; left arm down, both braids out | 9 | Kept |
| Vex r3b edit 3/4 | 06:41 | 01a1a54a-429a-762a-9fd6-9efd0c74b5b4 | nano-banana-pro | same | 9 | Kept |
| Vex r3b edit side | 06:41 | 01a1a54a-4285-77f9-b4cd-592d713874ab | nano-banana-pro | braid and hoses out, arm down | 9 | Dropped: drew her left sleeve hanging behind her back |
| Vex r3b edit back | 06:41 | 01a1a54a-42ac-71ee-afa0-70927fae1a0e | nano-banana-pro | arm down, braids and hoses out | 9 | Kept (a green lens it drew on the back ring painted dark) |
| Vex r3b edit side 2 | 06:44 | 01a1a54c-f974-7239-9ea4-5a714210e1a8 | nano-banana-pro | as side, "her left arm hidden behind her body" | 9 | Kept |
| Vex r3b A | 06:46 | 01a1a54f-35bf-734c-9ee7-55f81be998e5 | meshy-7.1 | 4 edited views (front, 3/4, side, back), geometry 2k, meshy-7 texture 8k, PBR, no remesh, a-pose, enhancement off | 40 | Kept: the face's smirk, chunky hair, eye plate on her right eye, gun-arm, backpack |
| Vex r3b B | 06:46 | 01a1a54f-35c4-73d2-9fd2-ab8f7e9f5bce | meshy-7.1 | as A, enhancement on | 40 | Dropped: rounder cuter face, stringy hair; a cleaner lens (A's is replaced by geometry) |

### Vex r3c and r3d (2026-11-04): credit-free
r3c (09:00-10:30) and r3d (11:25-13:30) used no Meshy credits: every change is in the fit spec, the parts tools, the
paint-over, the shared look (16c18b4f) and warden_look.json. Recipe: RECIPE_95.md.

### Breaker r3 (sea-ogre) stage 1, 2026-11-04 (balance 4993 at the start of the fan-out; 4327 after this agent's Breaker and Claire runs; other agents spent in between)
| Warden | Date (UTC) | Task id | ai_model | Settings | Credits | Result |
|---|---|---|---|---|---|---|
| Breaker edit front | 09:07 | 01a1a5d0-7eb7-7056-bb33-15be925aea42 | nano-banana-pro (image-to-image) | 9:16 crop; hammer and prow out, both arms hanging, two hands | 9 | Kept |
| Breaker edit 3/4 | 09:07 | 01a1a5d0-7eb7-736a-bb44-f7fc12c7da47 | nano-banana-pro | same | 9 | Kept |
| Breaker edit side | 09:07 | 01a1a5d0-7eaf-76de-bbbe-36f00aa1832a | nano-banana-pro | hammer and prow out (the back view's prow sliver painted out first) | 9 | Kept |
| Breaker edit back | 09:07 | 01a1a5d0-7ea7-727a-8ae1-5c47f6b50410 | nano-banana-pro | hammer and prow out, left arm hanging | 9 | Kept |
| Breaker A | 09:10 | 01a1a5d2-d333-731c-8775-3013c92661bd | meshy-7.1 | 4 edited views (front, 3/4, side, back) as images and texture refs; geometry 2k, meshy-7 texture 8k, PBR, no remesh, a-pose, enhancement off | 40 | Dropped: no right hand (the forearm ends in a stump under the fur cuff) |
| Breaker B | 09:19 | 01a1a5db-8178-73a6-b736-4e12d593b59b | meshy-7.1 | as A, enhancement on | 40 | **Kept**: both fists and bracers, two arms (no third hand), the face, beard braids, compass, mantle, teddy |

Breaker total: 6 tasks, 116 credits (the body's two attempts used).
