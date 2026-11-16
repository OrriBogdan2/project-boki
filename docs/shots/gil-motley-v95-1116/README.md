# Gil and Motley v95 upgrade (11-16)

- `gil_live_new_master.jpg`, `motley_live_new_master.jpg`: columns LIVE (current main, grey border), NEW in game (green
  border; `--warden-shots` on the imported glb, xvfb opengl3) and the master in Blender (Cycles). Rows: front, 3/4.
- `motley_shards_live_new_front_34.jpg`: Blender close-ups of the 60k game glb at rest, upper body, live and new, front and 3/4.
  Live has a 10-17 cm triangle sticking out at the collar / side (3/4 view); new has none. The small purple quads floating
  around him are his orbiting cards (design, kept).
- Mesh check (60k body, welded): folded-over triangles (all neighbours facing the other way): Motley live 27 (4 of them
  2.4-5.2 cm2 at the collar) -> new 0; Gil 4 -> 0. Both: 1 island, 0 non-manifold edges, 60,000 tris.
  Fix: `bake_warden._unfold` (after the decimate and after the fit), positions only.
