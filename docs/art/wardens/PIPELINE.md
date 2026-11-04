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
