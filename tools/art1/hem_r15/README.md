# Lace (hem) r15: left hand rebuilt from the mirrored right hand (in-place glb buffer edits, run from this folder's parent with tools/ = this folder)
Live left hand: 767 verts, 13 on finger bones (354 on LeftHandThumb3) = fused mitten; finger bones misplaced.
Chain (from the r14 k3 glb):
1. `python3 graft.py k3.glb p2.glb mirror 2 0.012` - drop the left hand past a plane 2.5 cm above the wrist joint; mirror the right hand
   (+1.2 cm forearm tube pushed 2 mm inside the left forearm, forearm weights) onto the left wrist by the hand bone frames, centred on the
   forearm section; UVs/colours/weights copied (Right*->Left*); left finger bone rests = mirrored right rests; left finger tracks = mirrored right tracks.
2. `python3 fistbow.py p2.glb k3.glb f70.glb 0.3 70 25 1.0` - fist grip: fingers 70 deg per joint (thumb 25) about the right hand's curl axes,
   +-30% of the right hand's per-clip finger motion; the bow subtree (Bow, StringMid: rest, translation tracks, IBMs, mesh) shifted by the knuckle move (3.7 cm) to keep the live hand-bow relation.
Result (r15): NOT shipped. Mechanically clean, but the fist reads as a ball and the bow sits beside it, not through it (live mitten wraps the bow). Next: a Meshy part pass of a hand gripping the bow handle, grafted with graft.py.
Checks: hands.py (verts per hand bone), fingeranim.py (finger curl per clip), bl_hands.py (Blender close-ups, inspection only).
