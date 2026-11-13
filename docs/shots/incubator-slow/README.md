# Incubator: 20 minutes of play to hatch (owner 2026-11-11)

- `egg_stages.mp4`: 22 s. Five Rare Eggs in the hub Incubator, 20 minutes of play in 20 s of film (1 s = 1 min),
  then 2 s held at the end. The eggs warm at 100, 80, 60, 40 and 20 % of the pace (from the top left), so all
  stages show at once: cold, first cracks (30 %), more cracks (60 %), gold-lit cracks (85 %), ready (the rattle).
  The glow and the wobble grow the whole way. The caption is burned in by ffmpeg, not game UI.
- `egg_stages_sheet.jpg`: the film at 0, 7, 14 and 20 minutes.

Made with `--incubator-shots --shots-secs=20` under xvfb with software GL (llvmpipe, rpc7) because the GPU
queue was stalled; the GPU job 20261111-181535-14087 from the first try was still queued.
