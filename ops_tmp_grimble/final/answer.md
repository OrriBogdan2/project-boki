# Grimble: remove the shorter gold chain (viewer's right of the face) - 11-15

Result: `A2.glb` = promoted master `v95/Grimble/r5/cg3d1115/A.glb` minus that one chain. Sheet: `sheet.jpg` (grey = current A, green = A2). Turntable: `turntable.mp4`.

## What it was
The chain is NOT fused into the skin. It is a free-hanging rope tube (x +0.110..+0.126, y -0.380..-0.357, z +0.12..+0.29, 6.9k verts) about 4-5 cm in front of the lip/cheek, ending in a small ring. At z 0.13-0.26 nothing else is in that column, so it can be cut out cleanly. No Meshy/retexture needed.

## What I did (targeted mesh edit, Blender 4.5 on hetzner; `tools/del.py`)
1. Selected the chain by connected components of gold texture (strict + tan) in the column x 0.107..0.135, keeping only components that are >=30% strict gold, +1 ring.
2. Second pass: removed the strands still hanging in front of the lip at the mouth corner (strict gold, y < -0.362).
3. Deleted those faces, capped the 41 tiny boundary loops (fan fill, UV = nearest tooth/lip texel, smooth normals), repainted gold texels left on the 650 corner faces (Image_0 base colour + Image_1 metal/rough) by push-pull inpaint.
4. Everything else is byte-for-byte the same data: other chain, goggles, face, skin, pack, fist, hair, purple arm, all textures except those texels, same material. 1,882,128 -> 1,869,044 tris, GLB 71 MB.

(First try, a "flatten onto the face" edit, damaged the teeth; dropped. Lesson below.)

## Verification (renders from the exported A2.glb)
Face front, 3/4 from both sides, two mouth-side views, full body (`sheet.jpg`): one chain left (the long one, viewer's left, down to the chest), no chain on the viewer's right, no hole, no floating strand, no new colour. Turntable 72 frames.
Known limit: at 5x+ zoom on the mouth corner (3/4 from Grimble's left) a few tiny flat tooth/skin-colour patches show where the tube met the lip; invisible at game scale (face is ~6% of body height).

## Files
- /home/boki/meshy/grimble-chain-1115/A2.glb, sheet.jpg, turntable.mp4, tools/
- /home/boki/meshy/v95/Grimble/r5/cg3d1115/A2.glb; CURRENT_OVERRIDES: old A line commented, A2 line added.

IMPACT 3/10 (one of Grimble's two chains removed; no redesign).
HARD/BLOCKS: tiny mouth-corner patches at extreme zoom: HARD 4/10, BLOCKS 1/10. w2 copy of CURRENT_OVERRIDES: see status below.
FINDINGS: Grimble short gold chain is a detached 6.9k-vert rope tube 4-5 cm in front of the face (not fused), so removing it is a clean face delete + tiny cap, no Meshy needed; A2 = A minus that chain, 1.3% fewer tris.
LESSON: 3d-edit: "flatten fused accessory onto the face" (harmonic smooth of colour-selected verts) wrecks teeth/lips when the accessory hangs in front of a gap -> first slice the mesh (y-depth clusters per z) to see if it is detached, then delete the faces and cap, and select by connected components + x-column, never by hue alone (teeth are gold-hued).
