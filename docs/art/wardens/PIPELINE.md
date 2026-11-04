# Warden 3D pipeline (Meshy image-to-3D -> Blender -> WardenSkeleton .glb)

Owner decision 2026-11-04 00:30 UTC: the scripted-primitive Blender meshes ("made of shapes") are replaced by Meshy image-to-3D. The skeleton contract (RIG_CONTRACT.md), retarget, WardenGlb loader and the Settings > Video > Warden models toggle stay.

## Secrets
- `MESHY_API_KEY` lives only in `~/.config/boki/secrets.env` (chmod 600) on the build box, or in the environment. Never in the repo, logs or shots. tools/meshy/meshy_task.py reads it and never prints it.

## Steps (per Warden; Vex first, the owner reviews before any other)
1. **Inputs:** crop the front, side and back views from docs/art/gen/wardens/<art>_turnaround.png (Vex = venatrix_*). Pad each to a square on the sheet's grey. Add the portrait for face detail if a 4th slot helps.
2. **Generate:** `python3 -I tools/meshy/meshy_task.py create ~/meshy/<hero>/run1 front.png side.png back.png [portrait.png] --polycount 30000`
   - Settings: multi-image-to-3D, `ai_model` latest (Meshy 7.1 as of Nov 2026), PBR on, 2k texture, remesh to triangles, A-pose, GLB.
   - Outputs: GLB, PBR maps, 4 view thumbnails and task.json (with consumed_credits). Raw downloads stay out of git under ~/meshy/.
3. **Blender clean-up** (`~/tools/blender-4.5.15-linux-x64/blender -b --python ...`):
   - Remove floaters and fix the mechanical arm side to match the art.
   - Split the rifle into the weapon slot per RIG_CONTRACT.
   - Decimate or retopo to about 8-15k tris and bake the textures onto the new UVs if needed.
   - Fit to the WardenSkeleton bone names, auto-weight and hand-fix the shoulders and hips.
   - Export to art/wardens/<hero>/<hero>.glb through the same loader.
4. **Shots** (to ext/hero-shots-s2 under warden-3d/<hero>/meshy_*): a gameplay zoom, a close-up, and a side-by-side with the turnaround.

## Commercial terms (checked 2026-11-04, meshy.ai/terms-of-use section 3.2)
- **Paid plans:** the customer owns the output ("to the extent possible under applicable law") and can keep it private.
- **Free plans:** CC BY 4.0 with attribution to Meshy. **Use the owner's paid key only.**
- **Training:** Meshy may train on inputs and outputs on non-Enterprise plans unless you opt out (email support@meshy.ai). This is the owner's call.
- Rigs and animations Meshy supplies are licensed only as part of the output. We use our own skeleton and animations.

## Run log
| Warden | Date (UTC) | Task id | ai_model | Settings | Credits | Result |
|---|---|---|---|---|---|---|
