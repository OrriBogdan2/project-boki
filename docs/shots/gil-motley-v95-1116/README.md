# Gil and Motley v95 upgrade (11-16)

- `gil_live_new_master.jpg`, `motley_live_new_master.jpg`: columns LIVE (current main, grey border), NEW in game (green
  border; `--warden-shots` on the imported glb, xvfb opengl3) and the master in Blender (Cycles). Rows: front, 3/4.
- `motley_shards_live_new_front_34.jpg`: Blender close-ups of the 60k game glb at rest, upper body, live and new, front and 3/4.
  Live has long triangles sticking out at the collar / side; new has none. The small purple quads floating around him are
  his orbiting cards (design, kept).
- `motley_left_sleeve_live_new.jpg` (job 20261116-042354-a1 follow-up): the 60k body alone at rest, live on top, new below.
  Live's left sleeve has a fan of long welded spikes. Cause: `ostra_v95.json` had elbow.L / wrist.L 3-6 cm in front of the
  master's forearm axis (y 0.10 / 0.15, the axis is at 0.07 / 0.085), so the fit tore that sleeve. Fixed in the spec.
- Folded-over triangles (a triangle facing away from all its neighbours: a shard sticking out of the surface), 60k body,
  welded: Motley live 27 (4 of them 10-17 cm at the collar) -> new 0; Gil 4 -> 0. Both: 1 island, 0 non-manifold edges,
  60,000 tris. Fix: `bake_warden._unfold` (after the decimate and after the fit) moves those corners to their neighbours'
  mean; positions only, so no holes, loose bits or UV changes.
