# Stuck-integ 8a30c285 (job 20261117-195527-a6, worker rpc7, main 792f960826, 2026-11-17)

Same skipped-READY list as stuck-integ-e1b5e125 / 5d6d8248 (656 names; 539 still on the remote and not in main).
Earlier passes: ops/stuck-integ-62ec7ba9 (unlanded-line triage), ops/stuck-integ-e1b5e125 (class refresh).

Base: origin/main, not the newest mc. ext/mc-20261117-0950 is 785 commits behind main, conflicts with it in 16 files,
and its own report says NEW-RED 3, WORSE 29 (compare INVALID). A union on top of it would carry those reds.

triage.tsv: one row per branch, vs main 792f960826, using the newest READY sha in briefs/EXT_TO_MAIN.md (else the tip).
`unlanded_lines` = lines the branch adds (no images/imports) whose exact text is not in main's copy of that file;
`lines_in_deleted_files` = added lines in files main has since deleted.

- MERGED 6: drop from the list.
- UNRELATED-HISTORY 6 (creator-sex-distinct-shots, scrapking-lmb-clips, vfx-archer-strips, vfx-dolm-shots,
  vfx-mage-strips, vfx-strips-tender): no common history with main (pre-rewrite). Nothing to merge; retire.
- CLEAN 2: combat-neve-lmb-torn: main has the same torn-box corner fix (6be9db15c8). hero-portraits-a-1114:
  images only, so it goes through art-merge, not code integ.
- CONFLICT 525: unlanded 0 = 4, 1-20 = 42, 21-100 = 113, >100 = 366.

Checked by hand, 20 of the smallest (all superseded, nothing taken):
- parity-pin-kael-drop, combat-ostra-seed-burn, vfx-neve-rimelock-area, fix-ghost-shot-sfx-1113: main has the same
  numbers, shader and rows.
- tut-first-capture, cursor-confine, tut-first-knock-tip, tut-belt-hint-rebased, tut-first-visitor, no-hardcoded-keys,
  tut-first-games-port, tut-hints-blight-camp-box, tut-first-tumble, sfx-silence-audit, no-dash-bursts-audit:
  the feature is on main (FirstCapture, CursorMode, KnockTip, belt_tips, VisitorIntro, cue_log, move_fx_check);
  what's left is comment and wording differences.
- anim-idle-walk-gap-rebased: release.yml continue-on-error was reverted on purpose by 6f212ebed5 (the server
  preset now exists, so the server steps are required). net.gd VERSION is older than main's.
- tut-dive-hint: depends on FirstTimeHint / match_hints.gd / content/rules/hints.json, which main no longer has
  (hints moved to tutorial.json). That makes it a feature port, not a merge.
- combat-daze-status, stuck-integ-606e9a98, stretch-reds: only DEBT.md lines are left.

Found on main (not fixed here): docs/heroes/gunslinger.md "Per-slot table" has 6 LMB/RMB/E rows in 4-5 different
versions, from union merges that kept both sides. ashwick.md and dredge.md have 2 duplicate rows each. Each row
needs checking against content/archetypes before deleting any, so this needs its own docs job.

Next: the 366 rows with more than 100 unlanded lines are 9k-22k commits behind. Port them per area from the
original intent, not by merging. Retire the rest.
