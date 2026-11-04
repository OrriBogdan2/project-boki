# Warden 3D pipeline (Meshy image-to-3D -> Blender -> WardenSkeleton .glb)

Owner decision 2026-11-04 00:30 UTC: the scripted-primitive Blender meshes ("made of shapes") are replaced by Meshy image-to-3D. The skeleton contract (RIG_CONTRACT.md), retarget, WardenGlb loader and the Settings > Video > Warden models toggle stay.

## Per-Warden checklist (follow end to end; details in "Steps" below)
Worktree on ext/warden-meshy. B = `~/tools/blender-4.5.15-linux-x64/blender -b --factory-startup --python`.
Raw files under ~/meshy/<name>/ (never in git). <id> is the archetype (gunslinger), <name> the art name (vex, `WardenGlb.ART`).
1. **Read the art.** Open `docs/art/gen/wardens/<art>_turnaround.png`, `_portrait.png` and `_splash.png`, plus `index.md` (known flaws).
   Note which side every asymmetric piece is on. **Never mirror**; follow the turnaround. If the portrait disagrees, mirror only the head model (step 6).
2. **Crops:** ~/meshy/<name>/{front,side,back}.png: square crops of the three views, padded on the sheet's grey.
3. **Inputs script:** copy `tools/meshy/vex_inputs.py` to `tools/meshy/<name>_inputs.py`.
   - Set RIFLE (weapon polygons in crop pixels per view; check them on a 2x gridded crop) and HEAD_CROPS (the portrait's head square).
   - Run `B tools/meshy/<name>_inputs.py -- ~/meshy/<name> ~/meshy/<name>/prep`.
   - Look at every output.
4. **Body run:** `python3 -I tools/meshy/meshy_task.py create ~/meshy/<name>/run1 prep/front.png prep/side.png prep/back.png --polycount 30000`
   (30 credits). Judge the thumb_*.png against the sheet and redo if a piece is missing or on the wrong side.
5. **Weapon run:** `... create ~/meshy/<name>/run2_weapon prep/rifle_front.png prep/rifle_back.png --polycount 6000 --pose ""` (30 credits).
   Skip it for a Warden whose weapon stays procedural.
6. **Head run:** `... create ~/meshy/<name>/run3_head prep/head_portrait.png --polycount 20000 --pose ""` (30 credits).
   Portrait only; adding the profile doubled Vex's lens.
7. **Proportions:**
   - Render the body front-on, orthographic and gridded. Measure shoulders, elbows, hands, fingers, hips, knees, ankles, neck and crown in the Meshy frame (+Z up, front -Y).
   - Set the archetype `body` (head, legs, neck, build, size) in `content/archetypes/<id>.json` so the rig's joints land on them.
   - Run `godot --headless -- --warden-rig-json --warden=<id>`.
8. **Fit spec:** copy `art/wardens/src/vex_fit.json` to `<name>_fit.json`.
   - Set the glb paths, the joints, palette_from (prep/front.png), the `project` boxes (plate, emblems), and the head `cut_z` / `r` / `axis` / `beret_h*` / `mirror`.
   - Run `B tools/meshy/fit_warden.py -- art/wardens/src/<name>_fit.json`.
9. **Import:**
   - Run `godot --headless --import`.
   - Set `meshes/generate_lods=false` in `art/wardens/<name>/<name>.glb.import`, then import again.
   - Write `art/wardens/<name>/IMPORT.md`.
10. **Checks** (godot queue wrapper, fresh XDG; real output only):
    - `--warden-glb-check`
    - `--warden-model-check`: add the Warden to WARDENS with its hit radius, sheet height and width range.
    - `--mantle-look-check`
    - `--move-feel-check`
    - `python3 tools/health.py --strict`
11. **Shots:**
    - Run `godot --rendering-driver opengl3 ... -- --warden-shots --wardens=<id> --shots-dir=<dir> --sheets=<dir holding <id>.png>`, plus a match shot (`--match --mates-demo --shot=... --shot-time=4`).
    - Composite with `B tools/meshy/compose.py -- OUT rows|cols IMG...`: the sheet over turnaround_close, the sheet over turnaround_game, the portrait beside closeup_front and closeup.
    - Save them as `/home/boki/shots-s2/warden-3d/<name>/meshy_*.png` with captions.txt.
    - Look at them. Anything that doesn't look like the image gets redone.
12. **Log and commit:**
    - Log every run (task id, settings, credits, kept or dropped) in the run log below.
    - Run the secret-leak grep from the brief (`git grep` for the key's prefix); it must find nothing.
    - Commit with the trailer.

## Secrets
- `MESHY_API_KEY` lives only in `~/.config/boki/secrets.env` (chmod 600) on the build box, or in the environment. Never in the repo, logs or shots. tools/meshy/meshy_task.py reads it and never prints it.

## Steps (per Warden): what worked for Vex
Run everything from the worktree. Raw Meshy downloads and prepared inputs stay under ~/meshy/<hero>/, out of git.
**Never mirror anything.** Match every asymmetric piece to the side the turnaround draws it (Vex: mechanical
RIGHT arm, sigil plate on the right shoulder, lens on the right eye). Check this against the front, back and
profile views before any run.

1. **Crops:** ~/meshy/<hero>/{front,side,back}.png: square, padded on the sheet's grey, cut from
   docs/art/gen/wardens/<art>_turnaround.png at the sheet's own scale.
2. **Prepare** (`tools/meshy/<hero>_inputs.py`, in Blender's Python because there is no PIL):
   `blender -b --factory-startup --python tools/meshy/vex_inputs.py -- ~/meshy/vex ~/meshy/vex/prep2`
   - **Paint the held weapon out of every view.**
     - List its polygons in sheet pixels, and check them on a 2x gridded crop.
     - Fill with the sheet's own grey, interpolated along each row from the grey pixels outside the holes. A flat fill leaves ghost shapes.
     - Write the weapon alone on flat grey (`rifle_front/back.png`) for its own run.
   - **Head inputs:** a square crop of the head from the portrait (`head_portrait.png`) for the head pass.
     The profile crop (`head_side.png`) is not used: with it, Meshy gave her two lenses.
3. **Body:**
   `python3 -I tools/meshy/meshy_task.py create ~/meshy/vex/run3 prep2/front.png prep2/side.png prep2/back.png --polycount 30000`
   - multi-image-to-3d, ai_model latest, PBR on, triangles, A-pose. 30 credits, about 3 min.
   - Meshy textures from the same images.
   - Judge the four thumbnails against the sheet first.
4. **Weapon:** `... create ~/meshy/vex/run2_rifle prep/rifle_front.png prep/rifle_back.png --polycount 6000 --pose ""`
   (30 credits). The stock the hand hid comes back loose; the fit closes it up.
   - (Tried for Vex: `meshy_task.py retexture OUT TASK_ID front side back` (meshy-7 retexture, original UVs, lighting
     removed, 10 credits). After the fit's flatten it was no better than the body run's own texture, so skip it.)
5. **Head pass:** `... create ~/meshy/vex/run5_head prep2/head_portrait.png --polycount 20000 --pose ""` (30 credits).
   The portrait alone gives the portrait's face, eye and expression.
   - Vex's portrait draws the lens over her LEFT eye, against the block and the turnaround. The fit mirrors the
     head model only (`head.mirror`) so the lens is on her right. Check this per Warden.
6. **Proportions:** measure the Meshy body's joints on a gridded orthographic front render. Then set the archetype's
   `body` (head, legs, neck, build, size) so the rig's joints land on them, and regenerate the rig:
   `godot --headless -- --warden-rig-json --warden=<id>`.
   - Vex: head 0.39, legs 1.78, neck -0.04, build 0.86, size 1.04 (the art's 7.5-head build).
   - The measured joints go into art/wardens/src/<name>_fit.json (Meshy frame: Blender, +Z up, front -Y).
7. **Fit, skin, export:** `blender -b --factory-startup --python tools/meshy/fit_warden.py -- art/wardens/src/vex_fit.json`.
   It does, in order:
   - **Flatten:** a 3x3 median takes out Meshy's grain. Each texel moves halfway (`snap`; 0.2 on the head) toward the
     nearest of 18 colours k-meansed from the sheet, keeping its own light and shade.
   - **Lift:** gamma 0.75, gain 1.08.
   - **Repaint the scarf:** high-value, saturated orange pulled to the sheet's orange (`repaint`; not on the head,
     whose skin shares the hue).
   - **Project the sheet:** the profile onto the sigil plate (`project`, view side, sign -1 for her right side).
     It registers on the figure's height and the head's silhouette, and keeps Meshy's paint where the sheet is grey.
   - **Head pass:** the body's head is cut above the chin. The head model is scaled so its beret's widest matches
     the body's, put on the body's beret, and cut below its chin and outside the head. The back view is projected
     onto its back (its own back came out as a metal plate). It rides the head bone rigidly.
   - **Pose:** face +Y, scale onto the rig's hips, then pose into the contract rest pose with a fit armature.
   - **Decimate:** to 15k triangles with the head included, keeping UV islands whole.
   - **Slots:** the toon slots by painted colour, one material per slot and texture (`<slot>-<tag>`).
   - **Skin:** auto weights for the body. Vertices that bone heat fails on take their nearest weighted neighbour's,
     or the nearest bone's.
   - **Normals:** shading normals from a smoothed copy, so Meshy's lumpy surface doesn't facet under the toon split.
   - **Weapon:** onto the Gun node's space.
   - **Export:** anchors, then the .glb with JPEG textures.
8. **Godot:** run `godot --headless --import`.
   - Set `meshes/generate_lods=false` in the .glb's .import (LODs collapse the face).
   - The hero toon shader takes the base colour as `albedo_tex`.
   - On a textured 3D model the loader turns off the shader's procedural brushwork (`surface`, `paint`): it is
     scaled per triangle and showed as facets on the scanned mesh.
   - Meshy's metallic, roughness and normal maps are not used (they read as plastic under the toon ramp).
   - Checks: --warden-glb-check, --warden-model-check, --mantle-look-check, --move-feel-check, health --strict.
9. **Shots:** `--warden-shots --wardens=<id> --shots-dir=<dir> --sheets=<dir with <id>.png>`, composited with
   `tools/meshy/compose.py` (rows / cols):
   - the turnaround over the close and match-camera turnarounds;
   - the portrait beside the front and 3/4 close-ups;
   - a match frame with a x4 crop;
   - the move strips.

## r2 additions (Vex, 2026-11-04): use these for the other 11
- **Crops:** a four-view turnaround goes in as all four views (front, 3/4, near profile, back), each padded square and
  enlarged to >= 1024 px (tools/meshy/vex_inputs.py takes the sheet and writes view0..3 plus views.json).
  The 2000 px sheet is for the texture projection.
- **Weapon fused to an arm** (`gun_arm` in the fit spec): elbow and tip points in the Meshy frame, radius r.
  The fit cuts it off the body into the `weapon` mesh in the Gun node's space. Its barrels past `spin` become
  `weapon_spin` (HunterAnim spins them while firing), and `glow_min` puts its vents on the glow slot.
- **Game proportions** (`chunk`): head x1.12 and the free hand x1.2 grown on the mesh, girth x1.06.
  The archetype body (head 0.72, legs 1.58, build 1.05, size 0.97) puts the rig's joints on them.
- **Texture:** never filter or project across Meshy's UV crumbs. The fit maps every UV island, filters within one
  island only, and pads islands into the gaps; v2's patchy facets were cross-island bleed. Turn Meshy's
  inward-wound triangles outward and neighbour-average the shading normals (`normal_smooth`). Don't use a
  smoothed copy: its normals flip on thin hair strands.
- **Godot shading of a painted atlas** (WardenGlb): soft and light toon ramp (`shade` 0.72, `ramp` 2.6), no
  self-shadow from the sun's shadow map (`self_shadow` 0), no vertex AO, no ink shell, no procedural brushwork.
- **Stance:** the Warden's carry in content/rules/warden_stance.json (ext/warden-stance) must suit the model:
  Vex r2's gun-arm hangs barrel-down at her right side.

## r3b (Vex redesign, 2026-11-04): what changed
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

## Commercial terms (checked 2026-11-04, meshy.ai/terms-of-use section 3.2)
- **Paid plans:** the customer owns the output ("to the extent possible under applicable law") and can keep it private.
- **Free plans:** CC BY 4.0 with attribution to Meshy. **Use the owner's paid key only.**
- **Training:** Meshy may train on inputs and outputs on non-Enterprise plans unless you opt out (email support@meshy.ai). This is the owner's call.
- Rigs and animations Meshy supplies are licensed only as part of the output. We use our own skeleton and animations.

## Run log
| Warden | Date (UTC) | Task id | ai_model | Settings | Credits | Result |
|---|---|---|---|---|---|---|
| Vex | 2026-11-04 01:07 | 01a1a418-55d6-76bf-86ce-cb71091a721c | latest | front/side/back (rifle painted out, body mirrored, head kept), 30k, PBR, A-pose | 30 | Dropped: mirrored by mistake (the art's mechanical arm is her RIGHT) |
| Vex rifle | 2026-11-04 01:11 | 01a1a41b-f6c9-7060-b540-a7135086d729 | latest | rifle alone, front + back views, 6k, no pose | 30 | Kept: barrel, vented shroud, scope, strips; the stock came back as a loose piece (closed up in the fit) |
| Vex | 2026-11-04 01:39 | 01a1a436-0c27-728b-a0dc-c691249a17aa | latest | front/side/back unmirrored (rifle painted out), 30k, PBR, A-pose | 30 | Kept: the body; mechanical right arm, plate and lens as drawn |
| Vex head | 2026-11-04 01:39 | 01a1a436-0beb-73df-96db-5461affe02bf | latest | portrait head + profile head, 20k, no pose | 30 | Dropped: two lenses (the profile's lens on the other eye) |
| Vex head | 2026-11-04 01:44 | 01a1a43a-787d-7053-849c-5f8fb573eb1f | latest | portrait head only, 20k, no pose | 30 | Kept: the portrait's face, eye, smile, beret badge; the back of the head came out a metal plate (the back view is projected on) |

| Vex retexture | 2026-11-04 02:12 | 01a1a454-5cdc-703c-ab73-b40134e4661b | meshy-7 retexture | run-3 body, multiview front/side/back (prep2), original UVs, remove_lighting, no PBR | 10 | Dropped: nearly identical to v2 after the fit's flatten; no clear gain on the vest or plate |



## Owner direction for the next Warden runs (2026-11-04 02:45 UTC)
- Wait for the improved base art: watch ext/imagegen IMG_STATUS.md. Each Warden also needs the owner's explicit "go for 3D" first (02:40 gate).
- Colour: aim for **flat, clean, bright painted colour with no mottled grain**. Vex v2's baked speckle was the main complaint.
- Proportions: use **slightly chunkier game proportions**: a bigger head and hands and a thicker silhouette, so each Warden reads at match zoom. Do this through the archetype `body` (step 7) and the fit, even where the art is slimmer.
- Pose: item 52 adds a signature stance and idle per Warden as data on the shared rig (content/rules/warden_stance.json). The fit keeps the A-pose rest; the stance is applied at runtime.
| Vex r2 | 2026-11-04 03:29 | 01a1a49a-5239-71e0-9906-570cbfd9715e | latest | r2 turnaround (2x enlarged): front, 3/4, near profile (her right), back; 30k, PBR, A-pose | 30 | Kept: one run; gun-arm, monocle, streak, bun and bolt, candles, vest, tights all came through. The later side view (ponytail) was not needed |

Vex total: 7 tasks, 190 credits (balance before r2: 940).


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
