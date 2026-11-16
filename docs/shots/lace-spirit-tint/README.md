# Lace's Spirit Walk body tint: before | after, against the footage

`--parity-strip --hero=archer --slot=dash --frames=349-366 --hold=1.4` at the match camera, 5 fps from the press:
ours on the top row of each pair, footage pin 0349-0366 below (the footage tints her dark while she phases,
pin.md frame 0360).

- `xvfb_before.jpg`: origin/main 53e2fe7f3. Her body keeps its crimson hair and violet dress through the roll and walk.
- `xvfb_after.jpg`: this branch. Her body darkens toward a deep orchid (PinFx.WASH_COL, 75% at full) from the roll to the
  end of the walk. No ring, burst or disc.
- `crop_before_after.png`: her at +2.0 s (top) and +2.4 s (bottom), before left, after right.

Software GL (xvfb, opengl3) on rpc7. The existing orchid shell around her lifts the tint, so it reads dark violet, not
the footage's near-black silhouette. GPU jobs 20261112-025659-32325 (after) and 20261112-025701-16401 (before) were
still queued after 37 minutes and are not seen.
