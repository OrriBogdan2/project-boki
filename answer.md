Merge-gap triage 11-13 (1703 READY-but-unmerged ext/* branches, base origin/main 18402df5b3; no tests run per branch, git-level only).
Buckets: A already in main 8 | B superseded 8 | C stale/dead 218 | D conflicts 257 (D1 docs/tuning auto 17, D2 art/data 35, D3 gameplay code 205) | E clean but failing 25 | F clean 1187.
F split by a sequential batch simulation: F1 clean in one batch 325, F2a collides only on docs/registry (auto-resolvable) 171, F2b real overlap 691.
Answer to the owner: yes, mostly not in the game. 86% (1469) is real unique work; only 14% (234) is dupe/dead. 1396 of the 1469 are player-visible.
But it is not "stuck": 1187 merge cleanly alone; the real blocker is that they were never batched and they overlap each other (docs/DEBT.md, check_registry.gd, match.gd).
Plan: batch F1 (325) when release-hold lifts; add docs/registry union to merge-candidate (+171); archive A+B+C (234); rebase only the top D3 in hunters/kits, garden, UI, tutorial (7 rebase jobs already running).
Files: /home/boki/coord/merge-week/gap-triage-1113.md and .tsv (branch, bucket, area, reason, inflight). Tool: gap-triage (installed in /home/boki/bin).
Limits: E/F is a static proxy (merge-exclude "breaks" notes, dangling res:// refs); some F will go red in the merge-candidate gate. Area labels are heuristic.
