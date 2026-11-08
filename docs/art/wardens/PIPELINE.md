# Warden 3D pipeline (Meshy image-to-3D -> bake -> Blender fit -> WardenSkeleton .glb)

**Game budget (item 94, overrides the per-Warden IMPORT.md notes below):** every .glb at most 15k triangles
(`tools/blender/decimate_warden.py` after the fit), imported with LODs; every texture VRAM-compressed, mipmapped,
at most 2048². See RIG_CONTRACT.md "Budget and checks".

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
Sparkle's emissive layer `use_emit`/`emit_tex` (ext/warden-meshy-ryzz). Already here: Cinder's `slot_rules` and
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
10. **Checks** (fresh XDG, real output only): `--warden-glb-check`, `--warden-rest-check` (after a procedural rig
    change run `-- --warden-rest-bake` and commit content/rules/warden_rest.json), `--warden-model-check`, `--mantle-look-check`,
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

## Claire b1 (Phase B, 2026-11-04): fit options added, credit-free
- `ankle_z` (fit spec): the rig ankle's height for a body standing on skates or heels (default 0.06). Claire's boot
  and blade are ~0.2 m below her ankle: at 0.06 they went 0.21 m through the ground and read as bare pointed feet.
  Raising the archetype's `legs` moves every absolute part coordinate (horns, wing roots, tail path, split boxes):
  shift them by the head bone's change.
- `weight_rules` for long hair: the hanging hair (dark hue, below the head) goes wholly to `hips`, else bone heat gives
  its ends to the hands and thighs and a raised hand drags the pigtails up into a bunch.
- `anchors` [{name, slot, side, z_min, bone}]: an anchor at the centre of one slot's faces on one side (her glowing
  irises), for warden_look.json `halos`.
- `tools/meshy/face_touch.py` (spec: Claire v1's claire_face_touch.json, in git history before the v2 rebuild): the face sheet softened before its
  projection (blush toward the skin, freckles deepened, eyes magnified with a soft lens and their iris lifted).
- hard_parts: `wings.scale`, `horns.slot`/`root`/`tipcol`/`crest`, `spear.blade_w`/`blade_t`/`shaft_r`/`pale`.

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
| Cinder r3 edit front | 13:30 | 01a1a6c1-060b-77b7-aa2e-e0720eb0e01b | nano-banana-pro | cinder_front: lance and hose out, left arm hangs, tail straight back | 9 | Dropped: the tail still curled out to the side |
| Cinder r3 edit side | 13:30 | 01a1a6c1-05d5-74c3-910d-8309d0bec4c7 | nano-banana-pro | cinder_side: as front, right arm hidden | 9 | Dropped: both arms drawn, the tail looped up |
| Cinder r3 edit back | 13:30 | 01a1a6c1-05e7-7718-ac85-0b7d6b15c44d | nano-banana-pro | cinder_back: as front | 9 | Dropped: the tail ran off the frame |
| Cinder r3 edit2 front | 13:38 | 01a1a6c3-b67c-7154-9c30-aa3b777b03a5 | nano-banana-pro | as edit, on the view padded to 1500 px on a 2000 px grey canvas (crop_pad) so the tail ends in frame; no floor or shadow | 9 | Kept (flat_ground.py flattens the padded rectangle) |
| Cinder r3 edit2 side | 13:38 | 01a1a6c3-b6db-7009-9395-b0694d0a01fe | nano-banana-pro | as edit2 front, ONE arm, the tail straight back to the ground | 9 | Kept |
| Cinder r3 edit2 back | 13:38 | 01a1a6c3-b712-76fd-857f-54e6f3e0ee09 | nano-banana-pro | as edit2 front | 9 | Kept |
| Cinder r3 A | 13:41 | 01a1a6c6-de62-7253-b0ea-05451a154e2d | meshy-7.1 | 3 edited views (front, side, back), geometry 2k, meshy-7 texture 8k, PBR, no remesh, a-pose, enhancement off | 40 | Dropped: squinting, mean face; small crest |
| Cinder r3 B | 13:41 | 01a1a6c6-de84-7676-b5c3-08ac066b2720 | meshy-7.1 | as A, enhancement on | 40 | Kept: big round amber slit-pupil eyes, rounded feminine face, bigger crest (mouth closed: the grin painted from the head sheet) |

### Ravel v2 (archer, ids stay hem), 2026-11-07 (103 credits)

| Step | Task | Tool | Note | Credits | Result |
|---|---|---|---|---|---|
| Edits, round 1 (front, 3/4, side, back) | 01a1b4dd-db36-7626-91f8-222edbec0ae3, 01a1b4dd-db35-7626-ace0-dfe30ab1308f, 01a1b4dd-db36-75ed-a90e-6bcb011b7e3f, 01a1b4dd-db26-7291-a190-e62a25f7be1a | nano-banana-pro | ravel_v2_turnaround views, props out | with round 2: 63 | Back kept |
| Edits, round 2 (front, 3/4, side) | 01a1b4df-6945-77bc-8768-d44a0b79612e, 01a1b4df-6936-743e-b5ba-506ac1a304a7, 01a1b4df-694c-752e-bb33-2586de65ac7a | nano-banana-pro | same, redone | | Kept |
| Scan | 01a1b4e1-2a92-70ea-8e4b-c3b45a8a9543 | meshy-7.1 | the four kept views | 40 | Kept |

### Hem (archer, was Pin) stage 1, 2026-11-04 (balance 4921 before; 76 credits)
| Warden | Date (UTC) | Task id | ai_model | Settings | Credits | Result |
|---|---|---|---|---|---|---|
| Hem edit front | 09:08 | 01a1a5d1-13fa-75ea-a82a-9a7c76eb0bbe | nano-banana-pro (image-to-image) | 9:16 crop; bow, string, spool and threads out, left hand hanging empty, ground line and VFX shadow out | 9 | Kept |
| Hem edit 3/4 | 09:08 | 01a1a5d1-1407-7614-b39f-38720b1bd208 | nano-banana-pro | same | 9 | Kept |
| Hem edit side | 09:08 | 01a1a5d1-1407-7050-b1dd-10efbfb9dc50 | nano-banana-pro | same, her left arm hidden behind her body | 9 | Kept |
| Hem edit back | 09:08 | 01a1a5d1-1406-776c-a6c5-797a2b85363e | nano-banana-pro | same | 9 | Kept |
| Hem A | 09:09 | 01a1a5d2-5a3a-759f-b819-13c6f8aa159d | meshy-7.1 | 4 edited views (front, 3/4, side, back) as images and texture refs, geometry 2k, meshy-7 texture 8k, PBR, no remesh, a-pose, enhancement off | 40 | **Kept** (first run): clean face and porcelain mask, bun and hair needles, coat tails, quiver, thimble claws |

### Tarek (dolm) stage 1 runs, 2026-11-04 (balance 4993 before the fan-out; 85 credits)
| Warden | Date (UTC) | Task id | ai_model | Settings | Credits | Result |
|---|---|---|---|---|---|---|
| Tarek edit front | 09:07 | 01a1a5cf-f284-72dc-9f40-fcfd21bee436 | nano-banana-pro (image-to-image) | 9:16 crop; right fist lowered; stones, shards, ripples and ground line out | 9 | Kept |
| Tarek edit 3/4 | 09:07 | 01a1a5cf-f279-714c-b8d1-bc7c41d2a765 | nano-banana-pro | same | 9 | Dropped: the lowered arm lost its stone bracer |
| Tarek edit side | 09:07 | 01a1a5cf-f222-72f3-ba19-4041e00d0d94 | nano-banana-pro | same, the far arm hanging behind his body | 9 | Kept |
| Tarek edit back | 09:07 | 01a1a5cf-f280-7465-ad2f-2aaf9ea36676 | nano-banana-pro | same | 9 | Kept |
| Tarek edit 3/4 2 | 09:09 | 01a1a5d1-c105-7402-acba-02323e255f37 | nano-banana-pro | as 3/4, "BOTH forearms wear stone bracers" | 9 | Dropped: kept the fist raised (the run went without a 3/4) |
| Tarek A | 09:10 | 01a1a5d2-9348-76b2-bd28-bb946e03b9b0 | meshy-7.1 | 3 edited views (front, side, back) as images and texture refs, geometry 2k, meshy-7 texture 8k, PBR, no remesh, a-pose, enhancement off | 40 | **Kept**: blindfold, grin, chunky locs with copper beads, vest, sash, harness, both bracers, wrapped feet (the bracers' glowing cracks not painted: added as an emission layer) |

### Tarek stage 2 (2026-11-04): no Meshy runs (0 credits); the r3c recipe on the stage 1 scan, see art/wardens/tarek/IMPORT.md.
### Tarek v2 runs, 2026-11-07 (briefs/art-refs/tarek_v2; balance 1246 before; 76 credits)
| Warden | Date (UTC) | Task id | ai_model | Settings | Credits | Result |
|---|---|---|---|---|---|---|
| Tarek v2 edit front | 14:03 | 01a1b652-093d-714f-99a2-8d093b662560 | nano-banana-pro (image-to-image) | turnaround crop to a clean A-pose sculpt render; eye stones, shards and ground out | 9 | Kept |
| Tarek v2 edit 3/4 | 14:03 | 01a1b652-09c6-7549-9407-7b30491ea3ba | nano-banana-pro | same | 9 | Kept |
| Tarek v2 edit side | 14:03 | 01a1b652-0972-74bc-9e5d-f18aa4fc9e84 | nano-banana-pro | same | 9 | Kept |
| Tarek v2 edit back | 14:03 | 01a1b652-094a-74ae-b46b-53cba08be326 | nano-banana-pro | same | 9 | Kept |
| Tarek v2 A | 14:04 | 01a1b652-f497-7289-b181-c5bcb2abfdae | meshy-7.1 | 4 edited views as images and texture refs, geometry 2k, texture 8k, PBR, no remesh, a-pose | 40 | **Kept** (first run): blindfold, locs with copper rings, huge stone left arm onto the chest, right gauntlet, prayer beads, cream wrap, orange sash, brown trousers, wrapped feet. The eye stones, shards, ground rings and jade glyph emission are scripted (tools/art1/tarek_scan.py) |

### Ostra stage 1 runs, 2026-11-04 (76 credits; balance 4327 after both Tarek and Ostra and the other fan-out agents)
| Warden | Date (UTC) | Task id | ai_model | Settings | Credits | Result |
|---|---|---|---|---|---|---|
| Ostra edit front | 09:10 | 01a1a5d2-f7ef-76ea-900a-ac22f8f9f546 | nano-banana-pro (image-to-image) | 9:16 crop; raised right hand lowered; halo, orb, strings, cards, shadow and ground line out | 9 | Kept |
| Ostra edit 3/4 | 09:10 | 01a1a5d2-f7ef-7670-8b06-404e1250c6c9 | nano-banana-pro | same | 9 | Dropped: the hand stayed raised (the run went without a 3/4) |
| Ostra edit side | 09:10 | 01a1a5d2-f7e4-7641-b263-ca781ba673fa | nano-banana-pro | same | 9 | Kept |
| Ostra edit back | 09:10 | 01a1a5d2-f7ec-7358-95c2-155f198baa71 | nano-banana-pro | same | 9 | Kept |
| Ostra A | 09:12 | 01a1a5d4-5e39-73a5-8395-ad7a5f79eddf | meshy-7.1 | 3 edited views (front, side, back) as images and texture refs, geometry 2k, meshy-7 texture 8k, PBR, no remesh, a-pose, enhancement off | 40 | **Kept**: the cracked porcelain mask with violet eyes and mouth, cap and bells, ruff, dagged coat with the starfield painted in its tears, clawed gloves. Meshy left out the wisp (the body ends at the hem): built as geometry |

### Ostra stage 2 (2026-11-04): no Meshy runs (0 credits); the r3c recipe on the stage 1 scan, see art/wardens/ostra/IMPORT.md.

### Claire stage 1, 2026-11-04
| Warden | Date (UTC) | Task id | ai_model | Settings | Credits | Result |
|---|---|---|---|---|---|---|
| Claire edit front | 09:12 | 01a1a5d4-724a-70c1-bfd3-f01683cb53ca | nano-banana-pro (image-to-image) | 9:16 crop; spear, wings and tail out, both arms hanging, skates forward | 9 | Kept |
| Claire edit side | 09:12 | 01a1a5d4-7267-7483-a529-b031274506af | nano-banana-pro | spear, wing and tail out, both skates pointing forward | 9 | Kept |
| Claire edit back | 09:12 | 01a1a5d4-7247-73c0-9feb-eaa1c3a86bc2 | nano-banana-pro | wings, spear and tail out, arms hanging | 9 | Kept |
| Claire A | 09:13 | 01a1a5d5-aa57-72df-95ba-a4926bd343d2 | meshy-7.1 | 3 edited views (front, side, back; no 3/4) as images and texture refs; geometry 2k, meshy-7 texture 8k, PBR, no remesh, a-pose, enhancement off | 40 | **Kept**: the face, horns, pigtails, ice costume, skates both forward |

Claire total: 4 tasks, 67 credits.

### Kael (juggernaut, was Zedran) stage 1, 2026-11-04 (76 credits)
Run on the zedran_* r3 art (09:20); the final kael_* art (10:15) is the same body and outfit with white-hot glow
instead of orange, so the body run is reused (no rerun): the glow colour comes from the archetype's `model_glow`
in game, and the blade, chains, hook and mane are scripted.
| Warden | Date (UTC) | Task id | ai_model | Settings | Credits | Result |
|---|---|---|---|---|---|---|
| Kael edit front | 09:12 | 01a1a5d3-2333-7482-a441-4a36831e5dd7 | nano-banana-pro (image-to-image) | 9:16 crop; greatsword, every chain and both hooks out, right hand hanging empty, the long mane cut to the nape | 9 | Kept |
| Kael edit 3/4 | 09:12 | 01a1a5d3-2346-73a9-ae0b-7f099ecc6b7e | nano-banana-pro | same | 9 | Kept |
| Kael edit side | 09:12 | 01a1a5d3-2359-70eb-9e32-74e30a939557 | nano-banana-pro | same | 9 | Kept (belt plate drawn as tally marks only) |
| Kael edit back | 09:12 | 01a1a5d3-2361-7357-b09f-45cc9d92e736 | nano-banana-pro | same; back and harness shown where the mane was | 9 | Kept (a gold collar ring added at the nape) |
| Kael A | 09:13 | 01a1a5d4-e913-74be-9dfd-20019f630127 | meshy-7.1 | 4 edited views as images and texture refs, geometry 2k, meshy-7 texture 8k, PBR, no remesh, a-pose, enhancement off | 40 | **Kept** (first run): build, scarf over the face, collar, harness, magma right arm only, skirt, greaves |
| Kael mane (stage 4) | 13:20 | 01a1a6a8-42c4-73c7-bbd5-d327f5d1b9fd | meshy-7.1 | kael_head_sheet front + side (padded square) as images and texture refs, geometry 2k, meshy-7 texture 8k, PBR, no remesh, no pose, enhancement off | 40 | **Kept**: its hair cut out and fitted on the body as the mane (kael_parts.meshy_mane) |

### Stage 1: Pip (tender), 2026-11-04 (85 credits; balance 4327 after both Sable and Pip, other agents spending too)
| Warden | Date (UTC) | Task id | ai_model | Settings | Credits | Result |
|---|---|---|---|---|---|---|
| Pip edit front | 09:13 | 01a1a5d5-b62f-723d-80e9-c89d469ca782 | nano-banana-pro (image-to-image) | 3:4 crop; lantern, wings, sparkles out; arms down | 9 | Kept |
| Pip edit side | 09:13 | 01a1a5d5-b62f-7131-83ab-d05cf57031b6 | nano-banana-pro | the same | 9 | Kept |
| Pip edit back | 09:13 | 01a1a5d5-b61e-74bf-80a3-67cde2a14edc | nano-banana-pro | the same, and the tail clear of the legs | 9 | Dropped: the tail still over the legs, a leaf clasp drawn on the back |
| Pip edit back 2 | 09:14 | 01a1a5d6-d524-74d8-851c-bc3b92eee529 | nano-banana-pro | back edit: the tail out to the side, no back leaf | 9 | Kept (the tail goes to her right here, to her left in the front view; Meshy followed the front) |
| Pip edit back 3 | 09:15 | 01a1a5d7-a0aa-77c4-821c-77445f689102 | nano-banana-pro | back edit 2: the tail to the other side | 9 | Dropped: unchanged |
| Pip A | 09:18 | 01a1a5da-06f4-75c9-9568-ec9702d633a6 | meshy-7.1 | edited front, side, back 2 (+ texture refs), geometry 2k, meshy-7 texture 8k, PBR, no remesh, a-pose, enhancement off | 40 | **Kept** |

### Stage 2: Pip (tender), 2026-11-04 (58 credits; balance 4233 before, 4130 after with other agents' spend)
| Warden | Date (UTC) | Task id | ai_model | Settings | Credits | Result |
|---|---|---|---|---|---|---|
| Pip edit front 2 | 11:21 | 01a1a64a-95d2-7529-9e37-9c7c911e62ce | nano-banana-pro (image-to-image) | the stage-1 front edit: arms out in an A-pose, clear of the flanks; the cape behind them | 9 | Kept |
| Pip edit back 2b | 11:21 | 01a1a64a-95c5-7404-a3ab-1bf17187f7a5 | nano-banana-pro | the stage-1 back edit 2, the same | 9 | Kept |
| Pip B | 11:23 | 01a1a64c-58ac-7471-8a83-4ef99eb35c66 | meshy-7.1 | edited front 2, the stage-1 side, edited back 2b (+ texture refs); as A | 40 | **Kept**: the arms free of the flanks and cape |
Then the r3c recipe: re-baked (art/wardens/src/pip_bake.json) and refitted (new joints, body.legs 1.45, size 0.78),
ramps of pip_front's colours, the lantern in her left paw with arched panes and a light, stronger wing cards,
warden_look.json `pip`, the tender stance's left paw out. IMPORT.md "Stage 2".

### Claire b3 (Phase B), 2026-11-04 (balance 3804 before, 3688 after: 116 credits)
| Warden | Date (UTC) | Task id | ai_model | Settings | Credits | Result |
|---|---|---|---|---|---|---|
| Claire b3 edit front | 15:19 | 01a1a724-7f04-7753-b255-e723662d89a4 | nano-banana-pro (image-to-image) | from the stage-1 front edit: horns and both front pigtails out | 9 | Hair still over the shoulders: edited again |
| Claire b3 edit side | 15:19 | 01a1a724-7f25-76a1-ada4-73ba1e51191c | nano-banana-pro | from the stage-1 side edit: horn and front pigtail out | 9 | Kept |
| Claire b3 edit back | 15:19 | 01a1a724-7f90-768e-9e37-54ec4828f78d | nano-banana-pro | from the stage-1 back edit: horns out | 9 | Kept |
| Claire b3 edit front 2 | 15:21 | 01a1a726-cb4f-7065-bcfa-bfd188419b67 | nano-banana-pro | the hair entirely behind her back, shoulders and upper arms clear | 9 | Kept |
| Claire B3 off | 15:23 | 01a1a728-1c2b-7750-92eb-9e34b9a3b54c | meshy-7.1 | 3 edited views (front, side, back) as images and texture refs; geometry 2k, meshy-7 texture 8k, PBR, no remesh, a-pose, enhancement off | 40 | **Kept**: a clean chest and shoulders, long wavy hair behind, skates |
| Claire B3 on | 15:23 | 01a1a728-1c2c-77d4-be29-f85cb8df23af | meshy-7.1 | as B3 off, enhancement on | 40 | Dropped: legs wide apart, arms flung out |


### Vex r3c and r3d (2026-11-04): credit-free
r3c (09:00-10:30) and r3d (11:25-13:30) used no Meshy credits: every change is in the fit spec, the parts tools, the
paint-over, the shared look (16c18b4f) and warden_look.json. Recipe: RECIPE_95.md.

### Sparkle (mage) stage 1 runs, 2026-11-04 (locked art: ext/imagegen 93a2757f wardens_r3/ryzz_* + RYZZ_KIT.md; 94 credits)
| Warden | Date (UTC) | Task id | ai_model | Settings | Credits | Result |
|---|---|---|---|---|---|---|
| Sparkle edit front | 11:04 | 01a1a63a-9e79-721b-beba-f3deb7492a53 | nano-banana-pro (image-to-image) | 9:16 crop of ryzz_front; pigtails, ties and back rods out (two small knots left) | 9 | Kept |
| Sparkle edit 3/4 | 11:04 | 01a1a63a-9e7c-7527-b013-d7921d97ef1e | nano-banana-pro | as front, plus hand off the hip and the gum bubble out | 9 | Dropped: the hand stayed on the hip |
| Sparkle edit side | 11:04 | 01a1a63a-9e8a-7453-a039-308472d82679 | nano-banana-pro | as front, plus the jacket off the shoulders (RYZZ_KIT), far arm hidden | 9 | Dropped for side 2: it opened the scarred eye |
| Sparkle edit back | 11:04 | 01a1a63a-9e78-7242-afc4-9b2c4cbf1d01 | nano-banana-pro | as front, floor shadow out | 9 | Kept (a small green bolt it drew on the corset painted out, tools/meshy/ryzz_prep.py) |
| Sparkle edit 3/4 b | 11:07 | 01a1a63c-7713-74fc-b16f-417e5e79d363 | nano-banana-pro | the 3/4 edit again: the arm down | 9 | Dropped: arm down, but it opened the scarred (right) eye; the run went without a 3/4 |
| Sparkle edit side 2 | 11:08 | 01a1a63e-4f65-738b-bed8-418d5d0d53ff | nano-banana-pro | the side edit: the scarred eye closed | 9 | Kept |
| Sparkle body A | 11:09 | 01a1a640-5b8c-7749-a3ef-7f535b835d75 | meshy-7.1 | edited front, side 2, back (padded square) as images and texture refs; geometry 2k, meshy-7 texture 8k, PBR, no remesh, a-pose, enhancement off | 40 | **Kept** (one body run): the wink and fern scar on her RIGHT eye, freckles, choker and bolt charm, the keyhole corset, off-shoulder jacket, chain belt, hazard bands |

Sparkle notes (stage 1, docs/art/wardens/PIPELINE.md recipe; no hand polish):
- **Pieces built by script** (tools/meshy/ryzz_parts.py, fit spec `scripted`, called by fit_warden.py through
  `build()`): the SHORT pigtails (owner: long twin tails read as a famous character) as chunky tapered locks with
  zigzag ends, blue to pink, out of a copper-coil tie on each of the scan's hair knots, on 3-bone `spring_pigtail_L/R`
  chains; exactly three copper rods in a riveted mount on her back, rigid on the hips, the middle one (her relic)
  scorched and bent. Both were taken out of the Meshy inputs.
- **Glow** (`emit_art`): Meshy paints the art's neon as plain pink, so the emission mask is projected from the edited
  front view (Meshy's frame, before the fit, so the A-pose arms still line up): the art's neon pixels light the scar,
  the charm, the corset piping and the forearm veins. The game colours that layer with the archetype's
  `model_glow.core` (hero_toon `emit_tint`), so the pink is a switch like Kael's, no rebake.
- **Proportions:** mage body head 0.74, legs 1.95, build 0.92, chest 1.0, neck -0.02, size 1.0 (was size 1.12,
  chest 1.15): 0.99x a medium's height as before, slimmer, the legs longer; hit radius unchanged (main's `body.hit_r` 0.4).
- **Stage 2 (rounds 2-3, credit-free):** round 3: the face painted from the head sheet (`paint_art`), the shared look fix (16c18b4f), curly pigtails, rods flush between the shoulder blades, right hand on hip; round 2: ramps of the art's colours per slot; mantle_look "mage" colours and a no-hue
  `tint` (the hair-pick pull was the violet cast); fuller S-fall pigtails, knots squashed under the ties; rods seated
  on the back's slope with straps; the charm's halo off the emission (`strict`); warden_look "ryzz"; the swagger
  stance. The stance commits (ext/warden-stance 7260bfda..aa3345b6) are cherry-picked, not merged: a merge of
  ext/warden-stance brings a diverged main (save v8 market vs v8 Mantle look, 16 conflicting files).
### Stage 1: Sable (thief), 2026-11-04 (balance 4921 before; 85 credits)
| Warden | Date (UTC) | Task id | ai_model | Settings | Credits | Result |
|---|---|---|---|---|---|---|
| Sable edit front | 09:08 | 01a1a5d1-7e41-7040-9f50-609ff1c60f5f | nano-banana-pro (image-to-image) | 3:4 crop; crossbows, wings, both braids, ground line out; hands empty | 9 | Kept |
| Sable edit back | 09:08 | 01a1a5d1-7e3a-728b-a2b1-09e9f433952f | nano-banana-pro | as front, plus both sleeves long | 9 | Dropped: drew the pendant on her back; the sleeves were wrong (the turnaround's left arm is bare) |
| Sable edit side | 09:08 | 01a1a5d1-7e5a-7775-a872-46e7339c4da9 | nano-banana-pro | crossbow, wing, braid out; long sleeves and fur collar | 9 | Dropped: no mask or plumes, a ground line |
| Sable edit back 2 | 09:10 | 01a1a5d3-47b8-72ca-b79b-67cde2de6c30 | nano-banana-pro | crossbows, wings, braid out; nothing else | 9 | Kept |
| Sable edit side 2 | 09:10 | 01a1a5d3-47c0-7739-a9b7-f67259a99aa6 | nano-banana-pro | crossbow, wing, braid out; fur collar in the standing collar; left arm bare | 9 | Kept (came back mirrored: flipped back to the art's side) |
| Sable A | 09:12 | 01a1a5d5-1d78-72f9-b867-a9bff45038eb | meshy-7.1 | edited front, side, back (+ texture refs), geometry 2k, meshy-7 texture 8k, PBR, no remesh, a-pose, enhancement off | 40 | **Kept** |

### Stage 2: Sable (thief), 2026-11-04: credit-free (0 Meshy tasks)
The r3c recipe on the stage-1 body: art ramps, sable_face.png projected over the face (registered on the eyes and
mouth, feathered: `project_late` `feather` / `feather_turn`), the mask on metal, a glowing pendant (warden_props
`gem`), bigger crossbows with a stirrup, the fur collar pulled in (fit `shrink`), warden_look.json `sable`, the
thief stance squared up. IMPORT.md "Stage 2".
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

### Breaker round 3, 2026-11-04 (owner sheets fb503983)
| Warden | Date (UTC) | Task id | ai_model | Settings | Credits | Result |
|---|---|---|---|---|---|---|
| Breaker r3 edits | 13:20-13:30 | edit_front (9:16, dropped: clipped arms), edit_front2, edit_side, edit_back, edit_tq (dropped: a copy of the front) | nano-banana-pro | breaker_front: hammer and shield out, arms down; the r3 side/back redrawn in the new outfit | 45 | front2, side (teddy painted out), back kept |
| Breaker C | 13:31 | 01a1a688-d08d-74e2-9e69-9015055e4130 | meshy-7.1 | front, side, back edited; texture refs the same; 2k, meshy-7 8k, PBR, no remesh, a-pose, enhancement off | 40 | **Kept**: the art's bare belly, sash, skirt, bare feet, braids, closed fists |
| Breaker D | 13:31 | 01a1a688-d0b4-738f-bed8-df735492629b | meshy-7.1 | as C, enhancement on | 40 | Dropped: open splayed hands |

### Vex v2 (owner redesign, briefs/art-refs/vex_v2/), 2026-11-06 (152 credits)
| Warden | Date (UTC) | Task id | ai_model | Settings | Credits | Result |
|---|---|---|---|---|---|---|
| Vex v2 edits | 2026-11-06 22:30 | 01a1b2f1-9b7c-76c2-9965-5dbb9d092ec8, 01a1b2f1-9b8c-72af-bc57-28fe07f1ad44, 01a1b2f1-9b7e-711a-b374-825bfdeed92d | nano-banana-pro (image-to-image) | turnaround front, left profile, back (1:1): bald, minigun and coin chain out, a plain right forearm | 27 | Kept (the back view swapped which forearm is brass: both forearms are cut, harmless) |
| Vex v2 head sheet | 22:30 | 01a1b2f1-9b7a-7456-bb3c-352dd6ee979c | nano-banana-pro | the turnaround's three heads + the sheet's smirk head -> a 4-view head turnaround (16:9) | 9 | Kept, then split per view |
| Vex v2 head views | 22:38 | 01a1b2f3-0b5c-7152-9017-d0750031fd4b, 01a1b2f3-0b39-7199-b772-db2031ff0596, 01a1b2f3-0b45-7313-af74-aec96bc55bd3, 01a1b2f3-0b6c-74b4-8f02-f0adb9ff2a14 | nano-banana-pro | each view of the head sheet redrawn alone at 1:1 (the sheet is 1376 px wide) | 36 | Kept |
| Vex v2 body | 22:38 | 01a1b2f3-0ba1-76e8-9810-46951086bee6 | meshy-7.1 | the 3 edited views + the same as texture refs; A-pose, defaults | 40 | **Kept** |
| Vex v2 head | 22:45 | 01a1b2f3-b897-7037-ac35-70264cddd250 | meshy-7.1 | the 4 head views, no pose | 40 | **Kept** |

### Cinder v2 (Flame Queen, titled the Ashen Kiss), 2026-11-07 (balance 1322 before; 76 credits)
| Task | Id | Model | Credits | Result |
|---|---|---|---:|---|
| edit front / side / back / 3-4 | 01a1b628-26fa-714e / 26b8-73d2 / 26e2-7241 / 26ef-728a | nano-banana-pro | 36 | No tank, hose, goggles: kept |
| scan | 01a1b62a-16b7-739b-81ce-e1fee79ab44c | multi-image-to-3d | 40 | Kept |

The scan welded her forearm shards to her hip plates (read as wings once the arms moved):
`cinder_source.py part_arms` cuts every face joining an arm to the body under the armpit and caps both sides. Raw files in
`~/meshy/cinder_v2`, rebuilt by `build.sh` there from `tools/art1/cinder_*.py`.
A tail near the floor: `Springs.FLOOR_UP` holds joints up from the *posed* root, so leave the stance's root drop as well.
The scan's horns came out as short wedges (cat ears from the front): `cinder_finish.py tuck_horns` presses them to the crown and
`cinder_pieces.py horns` sweeps the sheet's curved horns over them, rigid on the head, painted in their own strip under the atlas's flat
cells. The tail's molten cracks (the side view) are a seeded random walk painted into the tail strip of both the atlas and the emit map.

### Sable v2 (owner redesign: moth antennae, one braid, plunging coat, wing tails, twin flintlocks), 2026-11-07 (121 credits; balance 1170 -> 1049)
| Warden | Date (UTC) | Task id | ai_model | Settings | Credits | Result |
|---|---|---|---|---|---|---|
| Sable v2 edits, first try | ~14:30 | (try1, ~/meshy/sable_v2/try1) | nano-banana-pro (image-to-image) | 3 views of the turnaround; the gem and chains also removed | 27 | Dropped: invented a wider opening; the gem and three chains stay in the scan from here on |
| Sable v2 edit front | 14:34 | 01a1b66e-9287-7247-820c-3cb60762a99a | nano-banana-pro | sable_v2_turnaround crop; antennae, braid, wings, tails, knives, pistols out; gem and chains kept | 9 | Kept |
| Sable v2 edit 3/4 | 14:34 | 01a1b66e-9293-749d-89e1-c126284bec19 | nano-banana-pro | as front | 9 | Kept |
| Sable v2 edit side | 14:34 | 01a1b66e-92a8-727f-8336-3dc8448791fa | nano-banana-pro | as front, coat closed in this view | 9 | Dropped: bare midriff, long hem; fixed by side 2 |
| Sable v2 edit back | 14:32 | 01a1b66d-47b6-76ee-9168-f9d98fcbcd53 | nano-banana-pro | as front, back seams stay | 9 | Dropped: pale discs by the knees; fixed by back 2 |
| Sable v2 edit side 2 | 14:35 | 01a1b66f-5b51-75e4-8215-732eb9128fc4 | nano-banana-pro | on side: jacket to the belt, midriff covered | 9 | Kept |
| Sable v2 edit back 2 | 14:34 | 01a1b66e-928a-763c-8972-3c9e1c11c2ba | nano-banana-pro | on back: the discs out | 9 | Kept |
| Sable v2 A | 14:35 | 01a1b66f-cbed-7121-adf1-b345e7c627b9 | meshy-7.1 | edited front, 3/4, side, back (+ texture refs), geometry 2k, meshy-7 texture 8k, PBR, no remesh, enhancement off; 328,169 verts | 40 | Kept |

Prompts: art/wardens/src/sable_recipe.json. Build: tools/art1/sable_build.sh. Lessons: keep what must hold its place (the gem, the chains) in the scan and rebuild only what has to move. Previews lie close up: a 5x render of the mouth found the scan's stitches in three layers (paint, normal bake, the low mesh's folded crease) and only smoothing the mesh cleared them.

### Kael v2 (owner redesign, briefs/art-refs/kael_v2/), 2026-11-07 (116 credits; balance 1778 before, 1662 after)
| Warden | Date (UTC) | Task id | ai_model | Settings | Credits | Result |
|---|---|---|---|---|---|---|
| Kael v2 edits | 2026-11-07 00:33 | 01a1b36d-182c-749f-b0db-41b44d264551, 01a1b36d-183e-75bb-acc0-8b6a8b417638, 01a1b36d-1822-74e4-89ef-7c74be9c5e26, 01a1b36d-1824-7200-bc4a-793f3e037c46 | nano-banana-pro (image-to-image) | turnaround front, 3/4, left side, back (1:1): both wrist chains and the long sash tails out, nothing else | 36 | Kept |
| Kael v2 body A | 00:34 | 01a1b36d-e2f4-72b0-8e19-805ca49be6e4 | meshy-7.1 | the 4 edited views + the same as texture refs; A-pose | 40 | Not used: the A-pose opened his fists and gloved the cursed hand black |
| Kael v2 body B | 00:40 | 01a1b373-056a-72b0-823c-e82f2d1dd908 | meshy-7.1 | the same, no pose (`--pose ""`) | 40 | **Kept**: fists, the bare crimson hand, the scarf over the mouth |

### Ryzz v2 (owner redesign, briefs/art-refs/ryzz_v2/), 2026-11-07 (76 credits; balance 1662 before, 1586 after)
| Warden | Date (UTC) | Task id | ai_model | Settings | Credits | Result |
|---|---|---|---|---|---|---|
| Ryzz v2 edits | 2026-11-07 02:03 | 01a1b3be-8841-747d-bb1c-1de43c334ba5, 01a1b3be-8852-77ae-a033-6fa8f3789bbc, 01a1b3be-8843-718b-8706-843fe25430f9, 01a1b3be-8864-7710-a23f-6368f9ee53a0 | nano-banana-pro (image-to-image) | turnaround front, 3/4, left side, back (square, padded): both pigtails and ties, the backpack, its four rods and the cables out, nothing else | 36 | Kept (the back edit drew a bolt on the top's back; the pack covers it) |
| Ryzz v2 body A | 02:09 | 01a1b3c6-90cd-7085-afba-c79e7c229a5f | meshy-7.1 | the 4 edited views (2x lanczos) + the same as texture refs; A-pose | 40 | **Kept** |

Ryzz v2 notes: the v1 tools (ryzz_source/pieces/finish/clips) rebuilt for v2. Scripted: the long blue-to-pink pigtails on
the spring chains (crimson ties), the copper pack (a deep box, two low coil springs, the bolt painted as the glow key), the
four rods in sockets on its top, the black cables to the gloves, the hands, gum and nose ring. The pink arcs and the
lightning ball are VFX (the arc meshes and `arc.*` bones are gone). The fishnet is the scan's paint on her right leg. The face is
the turnaround's front view projected by its eyes and mouth (`~/meshy/ryzz_v2/ref/front_full.png`). The tied jacket hangs
from the pelvis as v1's skirt did; the thighs under it stay (the jacket is open at the front).

### Grimble v2 (owner redesign, briefs/art-refs/grimble_v2/), 2026-11-07 (76 credits; balance 1586 before, 1510 after)
| Warden | Date (UTC) | Task id | ai_model | Settings | Credits | Result |
|---|---|---|---|---|---|---|
| Grimble v2 edits | 2026-11-07 04:33 | 01a1b448-33c3-71c5-88e2-4498de4e57f0, 01a1b448-339e-773e-8604-2af0645042da, 01a1b448-33be-77c3-91ea-8a8c18b7962c | nano-banana-pro (image-to-image) | the FINAL turnaround's front, left side, back (square, padded, neighbours masked): the hoard, coins, straps, blunderbuss, loupe and all the sludge out | 27 | Front and back kept; the side drew his hidden right arm with a small hook |
| Grimble v2 side, again | 04:34 | 01a1b449-0e66-7513-a76f-f33b5af3b191 | nano-banana-pro | as above, "the right arm is hidden behind his body: do not draw it" | 9 | Kept |
| Grimble v2 body A | 04:34 | 01a1b449-7821-711a-949a-7959663e2266 | meshy-7.1 | the 3 edited views + the same as texture refs; A-pose | 40 | **Kept**: no nose, the bone hook to the ground, the gauntlet, the spurs and veins |

Grimble v2 notes: one body scan replaces v1's body, head and hoard scans. grimble_source.py fits it (the limbs keep the scan's spread,
the rig's joint heights; past a bone's ends the scan's own scale). The hoard, bells, lanterns, blunderbuss and junk ball are v1's sculpt;
the loupe is scripted; the face's squint, teeth and gums and the glowing veins are paint fixes (grimble_paint.scan_face, vein_key).

### Claire v2 (owner redesign: rabbit ears, braid, puff tail), 2026-11-07 (85 credits)
| Warden | Date (UTC) | Task id | ai_model | Settings | Credits | Result |
|---|---|---|---|---|---|---|
| Claire v2 edit front | 13:02 | 01a1b61a-8f75-7116-b432-5496b1cabe44 | nano-banana-pro (image-to-image) | nivi_v2_turnaround crop; ears, braid, scarf ends, tail and blades out, skirt opaque | 9 | Kept |
| Claire v2 edit 3/4 | 13:02 | 01a1b61a-8f6e-751a-8ac5-5ea408b53214 | nano-banana-pro | as front, 3/4 view | 9 | Dropped: redone |
| Claire v2 edit 3/4 b | 13:03 | 01a1b61b-63af-7744-9912-974dcd66e6eb | nano-banana-pro | the 3/4 again | 9 | Kept |
| Claire v2 edit side | 13:02 | 01a1b61a-8f85-7599-8580-5d05d1ce9c55 | nano-banana-pro | as front, right side | 9 | Kept |
| Claire v2 edit back | 13:02 | 01a1b61a-8f67-738a-b5d9-5bf863cb4f67 | nano-banana-pro | as front, back | 9 | Kept |
| Claire v2 A | 13:04 | 01a1b61c-3d74-7213-95c7-5b709948ce1d | meshy multi-image | front, 3/4, side, back edits; ultra, HD texture | 40 | Kept: ART-1 (tools/art1/claire_build.sh), 13.6k tris |

Claire v2 total: 6 tasks, 85 credits. Prompts in art/wardens/src/claire_recipe.json; built pieces (ears, braid, tail, spear) in art/wardens/claire/IMPORT.md.

## A hand-made, already rigged model (Dredge, 2026-11-04): tools/blender/fit_rigged.py
No Meshy. The model's own rigid skin and extra bones are kept; the script renames them onto the contract.
1. **Inspect** it in Blender: bones (names, parents, heads), each vertex group's bounds, loose parts, materials,
   the clip. Render front, 3/4, side and back (Workbench renders headless; EEVEE prints EGL errors here). Check the
   materials' base colours in the .glb itself: the friend's exports came out white (node colours don't export).
2. **Body:** set the archetype `body` so the rig's joints land on the model's own: `legs` from the hip height,
   the scale from the shoulder height (shoulders sit 0.5 above the hips in the rig), `build` from the shoulder
   and hip spacing, `neck` to put the head pivot where the head turns (Dredge: the hull's centre). Then `size` for
   the sheet height. Run `--warden-rig-json` after each change.
3. **Spec** (`art/wardens/src/<name>_fit.json`): `groups` (source group -> part), `split` (loose parts onto
   another bone by where they sit), `fit` (limbs turned and stretched joint to joint, or moved), `carry`, `skin`,
   `extra` (variant bones, also listed in `WardenGlb.EXTRA`), `weapon` (a group cut into the Gun's space with a
   `weapon_muzzle`), `materials` ("<slot>-<what>" and a colour from the art), `max_tris`, `anchors`.
   Give thin parts (rods, fingers, ropes) their own decimation share (`protect`): at the body's ratio they vanish.
4. `blender -b --factory-startup --python tools/blender/fit_rigged.py -- art/wardens/src/<name>_fit.json`, import,
   the checks, the shots: as steps 9 to 12 above.

| Warden | Date (UTC) | Source | Credits | Result |
|---|---|---|---|---|
| Dredge | 2026-11-04 07:30 | friend's Blender model (ext/imagegen ff552657), fit_rigged.py | 0 | Kept: 14.1k tris + 3.2k horn, contract + 11 variant bones, all checks pass |
| Dredge r2b | 2026-11-04 09:40 | the same + warden_paint.py: aged-brass atlas (2048, Cycles bake), orb eye, 24 tar drips | 0 | Kept: darker, patina, dents, glowing eye; all checks pass |
| Dredge r3 hull edits | 2026-11-04 13:20 | front 01a1a66a-ceec-75d1-96a8-dbb2b573f7d8, side 01a1a66a-ceff-7642-b000-0f167116e4a6, back 01a1a66a-cede-70a0-b459-b93ed0579a88 | nano-banana-pro image-to-image | the turnaround's front and back and the side sheet, edited to the hull alone | 27 | Front kept (projected); side dropped (turned to a 3/4 front view), back dropped (grew a porthole) |
| Dredge r3 hull edits 2 | 2026-11-04 13:25 | side2, back2 (meshy_task.py edit, view-locked prompts) | nano-banana-pro image-to-image | the same, the view and "no porthole on the back" spelled out | 18 | Kept: both projected onto the scripted hull |
| Dredge r3 hull | 2026-11-04 13:30 | none (the Meshy 3D run and a third front edit were not run: the session's auto-mode permission check refused the credit spend) | - | Blender fallback: warden_hull.py, a scripted dented sphere, plate bands and faceted lames, the three edits projected on it | 0 | Kept: r3 (balance 4,175 -> 4,130, 45 credits) |
| Dredge r3b | 2026-11-04 14:10 | none (credit-free) | - | modelled tears and peeled flaps, three big curved lames a shoulder, the doubled porthole masked, brass porthole rings | 0 | Kept |
| Dredge r3c | 2026-11-04 14:40 | none (credit-free) | - | the shared painted-look fix (16c18b4f) merged; the hull's projection lift x1.15 | 0 | Kept |
| Dredge r3d | 2026-11-04 15:20 | none (credit-free) | - | the stance; deeper dents and tears, flared lames, sharp lens cracks and a glint, tar strands and pool, red core | 0 | Kept |
| Dredge r3e | 2026-11-04 15:50 | none (credit-free) | - | tar runs over the hull, the back hatch and pipe as geometry, stronger lens cracks, a soft warm hull highlight | 0 | Kept |
| Dredge r3f | 2026-11-04 16:40 | none (credit-free) | - | ORCH's r3d review: one riveted brass helm and the grilled port, hairline lens cracks, thin crimson-sheened tar, glowing gashes, warm tarnished brass with rust streaks, the eye lifted; the match-zoom fix (f4b59cb3) | 0 | Kept |
| Dredge r3g | 2026-11-04 17:30 | none (credit-free) | - | ORCH's r3f review: tarnished bronze, rivet rows, a smaller cracked orb, helm drips, smoother hull, brass grille, upright stance | 0 | Kept |
| Dredge r3h | 2026-11-04 18:20 | none (credit-free) | - | ORCH's r3g review: no spec ovals, brighter eye and far rim, cracked glowing orb, bronze with seams and rivet rows, smoother lames, shards stripped | 0 | Kept |
| Dredge r3i | 2026-11-04 19:10 | none (credit-free) | - | ORCH's r3h review: a small orb in a wide brass ring, no flap shards, smoother pods, shoulder joints, the horn seated | 0 | Kept |
| Dredge r3i + v2 | 2026-11-04 19:40 | none (credit-free) | - | the shared match-zoom fix v2 ported by hand (outline + hero_toon from the branch, FAR_LOOK and _far_look in the loader) | 0 | Kept |
| Dredge r3j | 2026-11-04 20:30 | none (credit-free) | - | r3i limb loss fixed (per-part decimation budgets, `protect`), shards dropped, smaller pods, warm gold, darker pool | 0 | Kept |
| Dredge r3k | 2026-11-04 21:30 | none (credit-free) | - | a bigger hook, deeper dents, knee joints and bent knees, shoulder smoke, brighter brass and lighter limbs | 0 | Kept |
| Dredge r3l | 2026-11-04 23:30 | none (credit-free) | - | olive bronze hull, torn holes with peeled teeth breaking the outline, winch seated, a smoke ribbon off a stack, a cracked blue-grey porthole | 0 | Kept |
| Dredge r3m | 2026-11-05 00:30 | none (credit-free) | - | heavy tar runs with drops, three bigger torn holes, smoke over both shoulders, a pink-red pupil with a white heart, the grille, a softer hull top | 0 | Kept |

## Blender-driven modelling (vs Meshy)
The owner's friend made Dredge in Blender, probably by driving it through a Blender MCP server (an LLM sends bpy
code to a running Blender and looks at viewport screenshots). What his file shows:
- **How it was built:** 3,440 loose pieces joined into one mesh, every one a low-poly primitive (cylinders, UV
  spheres, tori, cones: rivets of 24 to 100 triangles, six stacked dome shells per shoulder, ten torus windings on
  the drum, tar drips as stretched cones). The skin is rigid, exactly one bone a vertex: each piece was parented to
  its bone as it was made, not weight-painted. Clean bone and material names (`Dredge_Brass`, `Claw2.1.L`), one
  hand-keyed 4 s showcase clip (two keys a channel). This is code, piece by piece: what an agent writing bpy produces.
- **Can we do it here:** yes, and without a GUI. Everything an MCP server does is bpy, and Blender 4.5 runs
  headless on this box. The "live viewport" becomes a render loop: one persistent `.blend`, each step a short script
  (`blender -b scene.blend --python step.py`, add or fix parts, save), then Workbench renders of the front, 3/4, side
  and back next to the turnaround crops, which the agent looks at (about 5 to 10 s a round). An MCP server is not
  needed (the common add-on is started from Blender's UI, which would need Blender under Xvfb; not tried here).
- **What it would take:** (1) extend tools/blender/warden_kit.py with part helpers that make a primitive already
  bevelled, named, on its slot material ("metal-brass", a colour from the sheet) and bound rigidly to its contract
  bone, so the model is built on the rig JSON from the start and needs no fit; (2) a per-Warden build script
  (`tools/blender/<name>.py`) and the render-beside-the-art harness above; (3) a detail pass: Dredge passes because
  of density (layered plates, rivet rows, drips, seaweed) and true proportions. Our earlier scripted-primitive
  Wardens were coarse, and the owner rejected them ("made of shapes", 00:30), so the bar is hundreds of parts, not tens.
- **Time:** an estimated 2 to 4 agent-hours a Warden (40 to 80 render rounds), against about 1 to 2 hours for a
  Meshy run plus the fit. Rigging is close to free (parts are bound as they are made), the budget is exact, and there
  are no credits.
- **Quality vs Meshy:** better on hard surfaces and machines: crisp silhouettes, flat clean colour (the owner's
  ask; Meshy's textures came out mottled), every asymmetric piece where we put it, no bone-heat failures. Worse on
  organic forms: faces, hair, cloth folds, muscle and fur come out toy-like from primitives. So use it for Dredge-like
  Wardens, armour, shields and weapons (Bjorn's prow, Zedran's blade, Cinder's pack), and Meshy (or a Meshy head on a
  scripted body) for faces and soft shapes (Vex, Moosh/Burple, Ostra's wisp).
- **Watch:** keep colours on the Principled base colour (the friend's node colours exported as white). A collapse
  decimate keeps primitives' shapes well (Dredge 43.7k -> 14.5k: no loss at match zoom, some faceting on the hull
  close up; the planar pass only took 300). Build to the budget instead of decimating where you can.
