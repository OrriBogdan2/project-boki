# Stuck-integration triage 62ec7ba9 (job 20261115-201531-a1, main b9d6a0834e, 2026-11-15)

Input: 825 READY branches that merge-candidate keeps SKIPPING for conflicts. Each branch's newest READY sha
(briefs/EXT_TO_MAIN.md, else the tip) was classified against origin/main with `git merge-tree`; `triage.tsv` has one row each.

| class | n | what it means |
|---|---|---|
| CONFLICT | 785 | conflicts with main; most are thousands of commits behind (main moved ~14k commits) |
| CLEAN | 4 | merges clean: integ-1113-D1 (taken), sable-bola-instant-rebased (generated doc only; gen_wiki on main gives main's file: superseded), stuck-integ-b6204ee2 (registers tools/cast_predict_check.gd, which is in no tree on main: dropped), mantle-port-a (227 commits, 0.24.6 anim wave: needs its own gate) |
| MERGED | 3 | already in main |
| MISSING / GONE | 1 / 32 | READY sha not on the remote / branch deleted |

`landed_pct` = share of the branch's added lines (merge-base..READY sha) that are already present, as lines, in
main's copy of the same file. It overcounts unlanded work: main often fixed the same thing differently (spot checks:
combat-neve-lmb-torn's UiTorn corner fix and combat-ostra-seed-burn's burn band are both on main in another form).
Buckets over the 785 conflicts: >=95% landed 29, <=20 unlanded lines 21, 21-100 lines 111, 101-500 lines 266, >500 lines 358.

Ported on ext/stuck-integ-62ec7ba9: integ-1113-D1 (merge), combat-daze-status (hand port, 1a959429f0).
The rest needs per-area port jobs (sort triage.tsv by unlanded_lines and port smallest first; check each against
main's current code first: a red or a stale row here is often already solved).
