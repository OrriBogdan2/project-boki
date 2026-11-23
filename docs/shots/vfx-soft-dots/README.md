# Soft effect edges (ext/vfx-soft-dots): before/after at match zoom

Cinder's reel (`--hero-vfx-reel --reel-hero=ashwick`), real GPU, Forward+, RTX 4090 (jobq): before = origin/main
fb360f614 (job 20261112-141641-30140, rp1-1), after = this branch (job 20261112-141027-07908, rp1-2).

- `lmb_before_after.jpg`: LMB held and swept (the hose flame, its tongues and scorch). Left before, right after.
- `dash_before_after.jpg`: Shift (the ram: jets, embers and the fx_dot dust at the feet). Left before, right after.
- `crops_before_top_after_bottom.jpg`: three frames, before on top, after below.

At the top-down match camera most puffs are seen from above, so the change is small: the lower edges where flame
puffs and dust dots meet the ground fade over 0.25 m instead of cutting a line into it.
