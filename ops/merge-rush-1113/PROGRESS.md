# Merge rush 11-13 (job 20261113-182745-a3, rpc5; resumes 20261113-153649-a4)

rpc5 has no gh, merge-gap, branch-archive, boki-install or hetzner coord. PRs go through the GitHub REST API with
the stored credential (merge commits, no bypass). The gap is counted by `merge_gap.py` here.

## Tools (this dir)
- `merge_gap.py [--list] [--archived]`: READY branches (EXT_TO_MAIN.md + archive) live on origin, head not in
  origin/main, **minus heads that carry an `archive/*` tag** (the hetzner merge-gap bug). Port this filter into the
  boki-tools `merge-gap` (skip a branch when `git ls-remote origin 'refs/tags/archive/*'` lists its head sha) and
  `boki-install` it on hetzner: rpc5 cannot reach the boki-tools master.
- `merge_batch.sh LIST SKIPS`: one `--no-ff` merge per branch; union-merges registry/hand-written docs, takes ours
  on generated files (wiki, baselines, .import, MERGE_REPORT.md); anything else is skipped with its files.
- `on_main.py LIST`: per branch, how many touched files are already blob-identical on main.
- `suite.sh TREE OUT [JOBS]`: every registered `-check` flag headless; compare a branch run with a main run.

## Log
- 18:45 UTC: corrected gap **1173** (1452 live unmerged READY, 279 already archive-tagged at their head).
- 18:50: PR #52 (ext/merge-rush-1113 batch A, 29 branches, gated on rpc4 by 20261113-173510-a5) merged
  -> main 55533bf67c. CI red only on "Wiki is current", same as main. Gap 1168.
- PR #45 (integ 1112d) and #43 (demo 1112): 339 branch merges, **262 are already in main**; the other 77 all
  conflict with main in code (skip list: `skip_pr45_pr43.txt`). Nothing of either PR merges cleanly any more;
  both PRs stay open as a record. Close them once the 77 are re-merged or archived.
- Archived (tag only, branch kept): `archived.log` (4).
