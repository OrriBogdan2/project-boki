# Lace (hem) r17: Meshy porcelain fist that grips the bow (replaces the live flat left mitten)
Inputs (/home/boki/gens/hunter-round-1124/lace/r17): refs = splash grip crop + 2 turnaround left-hand crops; 6 nano-banana-pro
images (img/e1-e6), 3 Meshy image-to-3d (mesh/e2,e5,e1); e2 picked (clean segmentation, left hand: thumb on the index side).
Chain (from the r16 glb ee73b942):
1. `blender -b -P dec.py -- mesh/e2/glb.glb e2_d8k.glb 8000` (decimate only; UVs and texture kept).
2. `python3 graft17.py R16.glb e2_d8k.glb w1.glb --sign 1 --width 0.085 --wfrac 1`:
   drops the live left hand past the r15 wrist plane (faces only, body verts byte-identical); Meshy hand scaled to 8.5 cm,
   forearm stub above the wrist ball cut, red cord wrap trimmed to the fist +-1.2 cm; handle axis laid on the bow grip axis,
   roll so the hand->wrist-ball direction follows the forearm, ball at the LeftHand joint; new prim, material 'body-hand17'
   (toon slot 'body', like body-retex), 1024 px texture, every vert rigid on LeftHand. The bow subtree is shifted 8.8 cm
   (rest, IBMs, verts, translation tracks) so the grip centre = the fist centre. Bow tracks that r13-r16's clip transplant
   wrote onto the 'Bow' MESH node (Idle, run, Jump_Run, Attack; live targets the bone) are moved back to the Bow bone.
   Attack: the bow's 50 deg tilt relative to the hand is moved onto LeftHand (the wrist turns, the bow stays in the fist).
3. `python3 stringfix.py w1.glb LIVE.glb r17a.glb`: Attack StringMid keys solved so the drawn string apex = live's
   (string-to-right-hand at full draw: live 1.5 cm, r16 53 cm (bone never turned), r17 1.5 cm).
Checks: fk.py (bow/string/head distances per Attack time), bl_lh.py + mont.py (Blender left-hand close-ups, inspection only).
