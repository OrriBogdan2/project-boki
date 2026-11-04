# Warden 3D pipeline (Meshy image-to-3D -> Blender -> WardenSkeleton .glb)

Owner decision 2026-11-04 00:30 UTC: the scripted-primitive Blender meshes ("made of shapes") are replaced by Meshy image-to-3D. The skeleton contract (RIG_CONTRACT.md), retarget, WardenGlb loader and the Settings > Video > Warden models toggle stay.

## Secrets
- `MESHY_API_KEY` lives only in `~/.config/boki/secrets.env` (chmod 600) on the build box, or in the environment. Never in the repo, logs or shots. tools/meshy/meshy_task.py reads it and never prints it.

## Steps (per Warden): what worked for Vex
Run everything from the worktree. Raw Meshy downloads and the prepared inputs stay under ~/meshy/<hero>/, out of git.

1. **Crops:** ~/meshy/<hero>/{front,side,back}.png, square, padded on the sheet's grey, cut from
   docs/art/gen/wardens/<art>_turnaround.png at the sheet's own scale (rows = the sheet's rows).
2. **Prepare the inputs** (`tools/meshy/<hero>_inputs.py`, Blender's Python because there is no PIL):
   `blender -b --factory-startup --python tools/meshy/vex_inputs.py -- ~/meshy/vex ~/meshy/vex/prep`
   - Paint the held weapon out of every view. List its polygons in sheet pixels and grid-check them on a 2x crop.
     Fill with the sheet's own grey, interpolated along each row from the grey pixels outside the holes.
     A flat fill leaves ghost shapes, and so does one sampled from inside the holes.
     The weapon also goes alone onto flat grey (`rifle_front/back.png`) for its own run.
   - Leave the hand gripping the stub of the grip. Meshy gives an open hand, which the game's hand pose closes on the weapon.
   - **Mirror the views** wherever the sheet puts an asymmetric piece on the wrong side. Vex's sheet draws the
     mechanical arm and plate on her right, but her block and splash put them on her left.
     Put the head back unmirrored in the front view so the mechanical eye stays on her right.
     Paint the lens over in the profile, which becomes her left side after the mirror.
3. **Generate the body:**
   `python3 -I tools/meshy/meshy_task.py create ~/meshy/vex/run1 prep/front.png prep/side.png prep/back.png --polycount 30000`
   - Settings: multi-image-to-3d, ai_model latest, PBR on, remesh to triangles, A-pose, GLB. It costs 30 credits and takes about 3 minutes.
   - Meshy textures the model from these same images, so the paint is the sheet's own.
   - Judge the four thumbnails against the sheet before anything else.
4. **Generate the weapon:** `... create ~/meshy/vex/run2_rifle prep/rifle_front.png prep/rifle_back.png --polycount 6000 --pose ""`.
   This also costs 30 credits. Meshy returns the stock the hand hid as a loose piece; the fit closes it up.
5. **Body proportions:** measure the Meshy mesh's joints on a gridded orthographic front render.
   Set the archetype's `body` (head, legs, neck, build) so the rig's joints land on them, then regenerate the rig JSON:
   `godot --headless -- --warden-rig-json --warden=<id>`.
   - Vex: legs 1.78, head 0.39, neck -0.04, build 0.86 (her art's 7.5-head build). size 1.04 then puts her at the sheet's 1.04x.
   - Write the measured joints (Meshy frame: Blender, +Z up, front -Y) into art/wardens/src/<name>_fit.json.
6. **Fit, skin, export:** `blender -b --factory-startup --python tools/meshy/fit_warden.py -- art/wardens/src/vex_fit.json`. It:
   - lifts Meshy's albedo (gamma 0.75, gain 1.08; it is darker than the art);
   - projects the art onto the faces turned to a view: the front view onto the face and beret, the profile onto
     the sigil plate. It registers on the figure's height and the head's silhouette, and keeps Meshy's paint where the sheet is grey;
   - turns her to face +Y and scales her onto the rig's hips;
   - poses her into the contract's rest pose: a fit armature on her own joints with auto weights, each bone turned onto the rig's joint, the pose applied;
   - decimates to 15k triangles with UV islands kept whole;
   - splits the faces into the toon slots by their painted colour;
   - skins to the contract armature with auto weights (root, skirt, scarf and the pauldrons don't deform);
   - fits the weapon to the Gun node's space, with the barrel end on the Muzzle and the strips hanging down;
   - adds the anchors and writes art/wardens/<name>/<name>.glb with JPEG textures.
7. **Godot:** run `godot --headless --import`; the loader does the rest.
   - The hero toon shader takes the base-colour atlas as albedo (`albedo_tex`), so she keeps STYLE.md's painted look.
   - Meshy's metallic, roughness and normal maps are not used: under the toon ramp they read as plastic, against the art's flat painted values.
   - Checks: --warden-glb-check, --warden-model-check, --mantle-look-check, --move-feel-check, health --strict.
8. **Shots** (`--warden-shots --wardens=<id> --shots-dir=<dir> --sheets=<dir with <id>.png>`), composited with `tools/meshy/compose.py`:
   - the turnaround over the close and match-camera turnarounds;
   - the portrait beside the front and 3/4 close-ups;
   - a match shot with a x4 crop;
   - the move strips.

## Commercial terms (checked 2026-11-04, meshy.ai/terms-of-use section 3.2)
- **Paid plans:** the customer owns the output ("to the extent possible under applicable law") and can keep it private.
- **Free plans:** CC BY 4.0 with attribution to Meshy. **Use the owner's paid key only.**
- **Training:** Meshy may train on inputs and outputs on non-Enterprise plans unless you opt out (email support@meshy.ai). This is the owner's call.
- Rigs and animations Meshy supplies are licensed only as part of the output. We use our own skeleton and animations.

## Run log
| Warden | Date (UTC) | Task id | ai_model | Settings | Credits | Result |
|---|---|---|---|---|---|---|
| Vex | 2026-11-04 01:07 | 01a1a418-55d6-76bf-86ce-cb71091a721c | latest | front/side/back (rifle painted out, body mirrored, head kept), 30k, PBR, A-pose | 30 | Kept: the design reads (beret, lens eye, mechanical left arm, sigil plate, scarf, bandolier, knee pads, boots); open right hand |
| Vex rifle | 2026-11-04 01:11 | 01a1a41b-f6c9-7060-b540-a7135086d729 | latest | rifle alone, front + back views, 6k, no pose | 30 | Kept: barrel, vented shroud, scope, strips; the stock came back as a loose piece (closed up in the fit) |

