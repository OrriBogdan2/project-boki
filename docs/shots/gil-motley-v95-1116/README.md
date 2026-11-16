# Gil and Motley v95 upgrade (11-16)

- `gil_live_new_master.jpg`, `motley_live_new_master.jpg`: columns are LIVE (current main, grey border), NEW in game
  (green border; `--warden-shots` on the exported glb, software GL) and the master in Blender. Rows: full length
  (front + 3/4), head front, head 3/4.
- `motley_left_sleeve_live_new.jpg`: the 60k body alone at rest (Cycles), live on top, new below. Left four: his left
  forearm close (front, 3/4, side, back); right three: full body. Live's left sleeve has a fan of long welded spikes
  (one island with the body, so an island check misses them); the new one has none. Cause: `ostra_v95.json` had
  elbow.L / wrist.L 3-6 cm in front of the master's forearm axis (y 0.10 / 0.15, the axis is at 0.07 / 0.085), so the
  fit tore that sleeve. Longest face on that forearm 0.37 m -> 0.23 m (his right forearm: 0.20 m); faces over 0.15 m 36 -> 27 (right: 19).
