# Prior-work gate (job 20261112-183603-a6), installed 11-12 with boki-install

## What changed
- `--force` now passes only the meter and Fable caps. Every forced start writes `FORCE by=start bypassed=meter|fable|none` to dedup.log, so forced starts show up there now (before, only blocked ones did).
- `--redo "<reason>"` (on start or queue) is the only way past cj_dedup (exits 71-74) and the new gate. It logs `REDO ... reason:` and `PRIORWORK REDO ... reason:` lines and saves the reason to the job's `redo` file.
- New tool `prior-work` (~/bin/prior_work.py, also importable). It ranks ext/* branches, READY posts, 14 days of jobs (label, task[:2k], status), the backlog, DECISIONS.md and 14 days of main's log, using keywords plus `concept-aliases.tsv`. A third column in that file marks broad areas (boss, hud, tutorial...), which never refuse a start.
- `claude-job start` runs the gate after cj_dedup:
  - It refuses with exit 75 on HIGH overlap: a running job, a branch that moved in the last 72 h, or a live READY post on the same specific system. The message names every overlapping item.
  - A task line `Builds on: <ids>` or `Not a dupe: <reason>` lets the start through.
  - Lower matches (top 5, score 35 or more) go into the prompt as "PRIOR WORK FOUND ... Check these first."
- Every preamble has a new step 0: run prior-work and ls-remote first. A task that is already done ends with STATUS: skipped plus `DUPE-OF <id>`, and that counts as a valid outcome.
- The pacer and backlog-refill (plus the planner prompt) run the same gate. The pacer moves refused items to `~/cj/backlog-parked.jsonl` instead of deleting them, and never re-queues guard exits 71-75.
- `cj-redo-report` adds a daily line: refused / folded / --redo / skipped-as-dupe / --force cap bypasses.
- Chores are exempt: rebase, merge, integ, planner, login/swap tests, daily retro.

## Dryrun: replay of the last 48 h of starts (`prior-work dryrun --hours 48`)
- 4070 starts. 620 are exempt chores, leaving 3450 real starts.
- First version: 502 refused (14.5%). Tuned (broad areas, area check, requeue/escalate prefixes stripped, alias fixes): **192 refused (5.6%)**, 3204 flagged in the prompt, 54 clean.
- **Wisp case 175723-a6: REFUSED (exit 75).** It names ready ext/feel-summon-press (score 41) and ext/feel-summon-on-g (36) on wisp-summon. A live search today also names running job 20261112-180059-a6 (86).
- 30 random real starts (seed 1112): 4 refused, 26 flagged or clean.
  - 2 true dupes, both of which later ended skipped: tutorial-skip vs ext/tut-try-relic, and stomp batch B vs anim-stomp-batch-a.
  - 2 were the same system but a different feature: hatch naming vs egg hatch timing, and online deathbox vs revive checks.
  - **False positives: 2 of 30 starts (about 7%), 0 of them unnamed.** For these cases the fix is a one-line `Not a dupe:`.
- Earlier, I hand-judged 15 refusals: 8 true, 3 borderline, 4 false. Those findings drove the area and requeue fixes; I did not re-judge all 15 afterwards.

## New syntax for the coordinator
```
claude-job start <acct> [--label T] [--role R] [--force] [--redo "<reason>"] -- "<task>"
    --force  = meter/Fable caps only;  --redo "<reason>" = past cj_dedup + prior-work (logged)
    task lines:  Builds on: <job ids / ext branches>   |   Not a dupe: <reason>
    exit 75 = prior-work refused (the message names the overlapping items)
claude-job queue [--redo "<reason>"] ... -- "<task>"     (--redo appends "Not a dupe: <reason>")
prior-work --label "<label>" "<concept words>"           # check before briefing
prior-work dryrun --hours 48 [--sample 30]               # replay
```
Code and tests: branch ext/prior-work-gate, ops/prior-work/ (masters.patch, test_prior_work.py). Backups of the masters: *.bak-1112-prior.
