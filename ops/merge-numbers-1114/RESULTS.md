# Merge numbers fix 11-14 (job merge-numbers-fix-1114, worker rpc1, 2026-11-14 ~04:25 UTC, origin/main ba6b62f7a1)

## Before (owner /usage page) vs true (git)

| number | /usage page | true from git |
|---|---|---|
| Waiting to merge | 900 | **963** live READY branches, head not in main, no archive tag (= merge_gap.py rule). 961 if the 2 patch-id-in-main ones are dropped |
| Merged today | 1303 | **146** branches in UTC day 11-14 (PR #66 91 + PR #68 55); **760** in the rolling 24 h (PR #46..#68); 611 in UTC day 11-13 |
| A day this week | ~85 | **172** branches/day (1204 landed 11-08..11-14 / 7) |
| Gap per day | +124 growing | **shrinking now**: waiting 1444 at end of 11-12 -> 1000 end of 11-13 -> 963 now (-37 so far today). The 7-day average is +157/day only because of the 11-09..11-12 READY flood |

Per UTC day (branch counted once: first READY post day; landed = first main first-parent merge whose ancestry holds any READY sha of it or its tip):

| day | READY posts | new READY branches | landed | waiting at day end* |
|---|---|---|---|---|
| 11-08 | 147 | 138 | 43 | 18 |
| 11-09 | 584 | 513 | 0 | 194 |
| 11-10 | 515 | 455 | 0 | 379 |
| 11-11 | 962 | 855 | 251 | 1049 |
| 11-12 | 1499 | 521 | 153 | 1444 |
| 11-13 | 681 | 44 | 611 | 1000 |
| 11-14 (to 04:25) | 56 | 10 | 146 | 963 |

*Past waiting counts only branches still live and untagged today, so 11-09..11-12 are lower bounds (231 live READY branches got archive tags and 162 were deleted unlanded since).

## Root cause

1. **"Merged today" counts READY posts, not branches.** READY lines whose sha landed in the 24 h window PR #49..#68 = **1314** (760 distinct branches); the page said 1303 a few minutes earlier. Every retry / bulk-rebase re-post of the same branch (4474 posts for 2560 branches; 1499 posts on 11-12 alone, mostly `bulk-rebase`) counts again. It is also a rolling 24 h, not the UTC day.
2. **The gap stayed ~900-1000 because new READY branches really did arrive that fast**: 2344 new READY branches 11-09..11-12 (855 on 11-11), vs 1204 landed all week. Landing caught up only on 11-13 (611). merge-gap is not badly miscounting landed batch branches: of 1204 landed branches, 1203 landed with a READY sha in main; only 1 landed by tip only. It does overcount a little: 59 landed branches got new commits after landing (head not in main) and still count as waiting.
3. **History dates**: briefs/EXT_TO_MAIN.md was gutted and restored on 11-09 17:19 (5d0edcd40e). A tool that dates READY lines with git blame sees all ~720 older lines as posted 11-09; merge_numbers.py re-dates them from the blame of f2bbcb34f9^.
4. "~85 a day" and "+124" could not be traced: the hetzner source is not reachable (see Fix). Guesses only: 85 ~= 1204 landed / 14 days, +124 ~= (900 - ~30 waiting on 11-07) / 7.

## Waiting branches already in main by content

Of 963 waiting tips: **2** are in main by patch-id (`git cherry` shows no new commit: garden-balance-apply, garden-nook-preview); **0** have every changed file identical in main; 23 have 90-99 % of their changed files equal to main, 51 have 50-89 %, 352 have 1-49 % and 537 have 0 %. So ~961 really still have unmerged content (many carry stale integration trains: 311 tips have >10 commits not in main). List: waiting_1114.txt (name tip first-READY-day files same cherry+ cherry-).

## Re-run 11-14 04:38 UTC (job 20261114-043010-a3, rpc5, deep): `merge_numbers.py` (replaces true_numbers.py)

Self-contained (own fetch + blames, also reads briefs/archive/EXT_TO_MAIN-*.md like merge_gap.py), 21 s:

    Waiting 964 (shrinking, 1000 at end of yesterday) | merged today 146 (24 h: 757; READY posts of those: 1395)
    | 172.0 a day this week | new READY 362.4/day | gap per day +137.7 (reconstructed), today -36

Same as the table above (one new READY since). The 7-day gap is truly positive (the 11-09..11-12 flood), but the page must
not call it "growing": waiting fell 1444 -> 1000 -> 964 over the last two days. The page should show both numbers.

## Fix (NOT installed: merge_tracker.py, merge-gap and master-page exist only on hetzner)

Neither rpc1 nor rpc5 can reach hetzner (no ssh/DNS; the jobq relay runs only Godot/Blender jobs on rpc workers), and
no copy of those three files is in git, so they could not be patched here. Install on hetzner (coordinator, ~5 min):

    cd /home/boki/coord
    git -C /home/boki/project-boki fetch -q origin ext/merge-numbers-fix-1114
    git -C /home/boki/project-boki show origin/ext/merge-numbers-fix-1114:ops/merge-numbers-1114/merge_numbers.py > boki-tools/merge_numbers.py
    for f in merge_tracker.py merge-gap master-page; do cp -p boki-tools/$f boki-tools/$f.bak-1114; done
    boki-install boki-tools/merge_numbers.py
    # in master-page (or merge_tracker.py, wherever the 4 numbers are made), replace them with:
    #   j=$(merge_numbers.py --repo /home/boki/project-boki --json --history /home/boki/coord/merge-week/waiting_history.json | sed -n 's/^JSON //p')
    #   Waiting to merge      = .waiting            (+ "(.gap_today today)")
    #   Merged today          = .merged_today       (UTC day, branches; .merged_24h for rolling)
    #   ~N a day this week    = .merged_per_day_7d
    #   Gap per day           = .gap_per_day_7d, word from .trend (last day), not from the 7-day sign
    #   and in merge-gap: a branch whose READY sha is in main is landed even if its head moved later (46 now)
    boki-install boki-tools/master-page; boki-install boki-tools/merge-gap; master-page
    # check: page shows 964 +- new posts, 146 + today's landings, ~172/day, +138 (falls as the history file fills)

Fallback if the page code is hard to patch: call `merge_numbers.py --json` and render only its JSON line; the tool is the
single source for all four numbers, so merge_tracker.py's READY-post counting can be retired.
