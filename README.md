# VFX quality strips: Meeko (tender), not for merge

One sheet per part (3x3 frames): lmb, hold, dash, rmb, e, r. Captions: the reel's (`tools/vfx_reel/tender.gd`).

- `before_tender_<part>.png`: main d255acbee (jobq vfxq-before-tender 20261108-180332-18250, worker w2-2)
- `after_tender_<part>.png`: branch ext/vfx-tender (jobq vfxq-after-tender-meeko2 20261108-210202-06285, worker rp1-1)

The ground reads yellow on rp1-1 (that worker's renderer; Motley's rp1 strip shows the same), green on w2-2. The
effects are what to compare.

What changed: every part in leaf #5fdc6a (the palette also tints the dash stars); the LMB ember drawn at its 0.22 m hit
radius with a leaf hit flash; the Burrseed ring and disc as a lit, feathered rim over a faint inside; the burst sheds
petals; Hearthlight's ring in leaf with a 0.7 s afterglow on each heal pulse, thrown no longer an opaque cyan dome;
Hearth Call's swirl 2 m and a swirl under the healed one on every tick.
