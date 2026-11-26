# Lace (hem) r30 tools

Run from the repo root with /home/boki/venv-img/bin/python. Shipped chain (candidate "C"):

    lin30.py r29.glb L.glb k=0.55            # lining = skirt29 x0.55 (uniform), image renamed skirt_lining30
    curtain30.py L.glb c.glb                 # drop the small godet prims, add the between-legs curtain skirt-godet30
    ../hem_r21/repack.py c.glb hem_meshy.glb # compact the buffer

- cross30.py GLB: per clip, the frames where godet/liner verts cross in front of the right thigh ("shards"). C: 0 in all clips.
- backpanel30.py: variant B (offset back panel behind the thigh). Rendered, not shipped (pale patch in dash_0).
- dark30.py: outer skirt x0.7 toward the reference wine. Rejected: the skirt went brown-grey and kept the salmon sheen
  (the pink at the game camera is shading, not texture colour).
- sheet30.py: owner sheets (border colour = verdict, letters only).

Renders, sheets, measures and the gate output: /home/boki/gens/hunter-round-1124/lace/r30 (RESULTS.md).
