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
- Batch C pass (merge_batch.sh over all 1110 gap tips not in the #45/#43 list, on main 55533bf67c): 41 merged
  clean, 1069 skipped (real code conflicts). Full suite vs main: 9 branches caused new reds and were dropped
  (skip list below); rebuilt as 32 merges (ext/merge-rush-1113, batch C) and re-gated.
- Skip list (all, with conflicting files, sorted by conflict count): `skip_all.tsv` (1146 lines: 221 conflict in
  one file only, 165 in two; those are the cheapest hand-resolve lanes).
- Batch C drops (reason):
  - ext/anim-elim-beat-wisp: --wisp-check red (wisp_check.gd:288 reads `.r` on a Dictionary)
  - ext/ui-prematch-margin: --prematch-check parse error (prematch_check.gd:293 `labels` type)
  - ext/stuck-integ-b6204ee2: its relay.gd adds `held`, which lagcomp_check's RelayServer subclass also declares
  - ext/sfx-mask-puton: --mask-moment-check null instance
  - ext/combat-level-growth: its own --level-growth-check times out (300 s)
  - ext/friendly-bodies: its own --friendly-bodies-check, 6 script errors (`gap` on a Dictionary)
  - ext/feel-camera-lead: its own --cam-lead-check fails (view 0.89 m behind 0.5 s into a dash; main has trail 0050)
  - ext/farm-garden-soak: --garden-day-check script error (stat_meaning.gd:28, LanternMatch has no `run`)
  - ext/creator-sex-distinct: --home-gait-check fishing feet creep 14.6 cm on empty_f (unmasked.gd/stance; likely)
  - ext/combat-swept-hits: --duo-tutorial-check red 3/3 (main 0/3): "juggernaut: no beat passed by the stall skip
    [revive]"; bisected to this merge
- Batch C final: 31 merges (gated as C3). Flaky on main and branch alike, not counted: race, tutorial-idle,
  perf-budget, cc-exit-buffer (one abort under load), garden-whistle.
- Batch C gate (C3, 31 merges on main 55533bf67c): full suite 356+13 checks vs main side by side, 12 at a time;
  every red only on the branch was rerun 3 at a time on both trees: all green. Fixed vs main: 4. Import: 0 parse
  errors. health --strict OK. Export dry run: every preset packs, 652.4 MB (main 641.3 MB; baseline 471.5 MB is
  stale on main, not bumped here).
- ~22:00: main moved (PR #54 integ-1113-C3, ca96e707c5) and PR #55 went dirty: merged main in (warden_clips and
  clip_check: main's side, it already had the release snap). Re-gated vs the new main: two more drops, reverted
  in the branch:
  - ext/anim-timing-dolm: its tools/parity_pvb.gd calls plan() with 2 args; PR #54 made it 3 (--dolm-combo-check)
  - ext/tut-first-ult: its own --first-match-guide-check fails 3 asserts on the new main
  Batch C ships 29 branches.

## Next steps (gap <100)
1. Clean merges are used up: every other gap tip conflicts with main in code (`skip_all.tsv`, col 1 = files).
   Lanes for parallel workers, cheapest first: the 221 one-file conflicts, then 165 two-file ones. Per branch:
   merge main into it on its own ext/ branch (AGENTS.md section 7), resolve, run its checks, READY. Then a batch
   job runs `merge_batch.sh` over the READY ones, `dedupe_registry.py`, gen_wiki, `suite.sh` vs main, PR.
2. Owner calls that would cut the most: the stuck-integ tips (11014837 carries 141, 42241ff1 133, 86b7d6eb 115;
   docs/INTEG_b6204ee2.md suggests archiving 511), and old pre-11-10 lanes whose files main rewrote since
   (e.g. feel-camera-fast vs decision 0050, overlay-typed-calls). Archive = tag only, as `archived.log`.
3. Port the `merge_gap.py` archive filter into hetzner's merge-gap (boki-tools master, boki-install): rpc5
   cannot reach it.
4. Family candidates not archived (sibling merged but content differs, needs a look): dredge-auto-rebased,
   garden-hub-theme, grimble-stretch-v2-rebased, npc-hob-guide-1111-r2, sfx-boki-voices-3, sfx-garden-games-3,
   ui-void-masks-v3, vex-daze-rebased, vex-rmb-terrain-rebased (+10 big old-base -rebased branches).
- Final batch C gate (main ca96e707c5): full suite both trees, branch-only reds rerun at low load: race and
  drop-launch are red on main too; 10 checks fixed vs main; import 0 parse errors; health --strict OK.

## Batch D (job 20261113-225134-a3, rpc7; 11-13 23:00 to 11-14)
- Gap at start: **1124** (live unmerged READY 1374, 250 archive-tagged at head). Open PRs held 43 tips (left out);
  lane C2 (PR #58) 15 more.
- Candidates: the 186 gap tips that already contain main ca96e707c5 (the bulk-rebase lane merged main into them).
  First pass on main 96d778d036: 90 clean, 96 conflict. Main moved (PR #58, C2) during the gate; rebuilt on
  df5464db04 from the 88 kept: 81 clean, 7 now conflict (`skip_batchD.tsv`, 103 rows with conflicting files).
- Dropped by the gate (reverted in the branch, reason):
  - ext/feel-hold-stand: --ledge-walk-check (juggernaut and dolm LMB root the Hunter 15 s on the ledge)
  - ext/ui-match-phase: --panel-input-check (Esc pause menu no longer opens) and --demo-check
  - ext/sfx-mask-puton: deletes main's mask_moment_check.gd, registry keeps it (same as batch C)
  - ext/parity-downed-numbers: --bulwark-combo-check (Mending Ground revive 0.24 in 5 s, needs 0.3)
  - ext/feel-cast-into-cast-rest: its own --cast-into-cast-check, Tender rows, and over the 300 s cap
  - ext/fold-sfx-boki-1112: its own --boki-steps-check (TOUCH table vs the Boki clips, 20 rows)
  - lane D1 (PR #53) owns them: ext/ui-buff-stack, ext/ui-key-caps, ext/ui-quest-race-pips, ext/ui-wisp-picker
- Fixes in the batch: registry dedupe; hero_vfx.gdshader `band` redefinition (red on main too, 31 checks logged
  a shader error); SkyshipModel template as a PackedScene (15 orphan nodes, --match-repeat-check);
  hero_cat_fence_check Fx stub signature; stat_up_vfx_check FakeGame.find(); heart/side colour API drift.
- Archived (tag only): ext/vfx-cel-ring-bursts (head reverts its only commit).
- Batch D ships 73 branches (+ ui-ways-out-colourblind already in main via C2).
