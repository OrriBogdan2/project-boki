Hunter stretch diagnosis (job 20261119-145816-a5). numpy only (+scipy, matplotlib, PIL for the sheets); read-only on the glbs.
`python3 stretch.py <art names>` per-clip edge stretch (stretch_<h>.json, emax_<h>.npz, worst_<h>.npz); `analysis2.py` cause tests
(synthetic joint turns, centring, hand weights, clip swing); `sep.py` separating-bone pairs; `sheet.py <azimuth> <h>` contact sheets.
Scripts expect to run inside one work dir and ROOT in stretch.py points at the worktree. GPU renders: `--hunter-diag-shots`.
