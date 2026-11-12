# cj-dedup: redo/duplicate guard for claude-job (install on hetzner)

Built on w2 (job 20261112-083508-a3). w2 has no copy of claude-job, cj_routing.py, usage-pacer, backlog-refill or
boki-install, and it cannot log in to hetzner, so the hooks below are written as patches to apply there. The tool
itself is complete and tested: `python3 test_cj_dedup.py` should print `FAILS 0`.

## 1. Install
    mkdir -p /home/boki/coord/boki-tools/cj-dedup && cd /home/boki/coord/boki-tools/cj-dedup
    for f in cj_dedup.py cj-guard cj-redo-report test_cj_dedup.py INSTALL.md; do
      git -C /home/boki/project-boki show origin/ext/cj-dedup-guard:ops/cj-dedup/$f > $f; done
    chmod +x cj-guard cj-redo-report; python3 test_cj_dedup.py | tail -1      # FAILS 0
    boki-install ...          # whatever boki-install takes to link cj-guard and cj-redo-report into ~/bin (never cp)
    cj-guard dryrun --hours 24                                                  # the real numbers (starts nothing)
Back up every file you patch below as `<file>.bak-1112-redo` first.

## 2. Exit codes (`cj-guard check --label L --task-file F [--allow-dup] [--redo] [--force]`)
0 ok · 71 same key or task similarity >= 0.8 RUNNING (`--force` does not bypass, `--allow-dup` does) ·
72 STUCK, 3+ finished runs of the key and none done (one line goes to /home/boki/cj/stuck.jsonl) ·
73 the key finished done in the last 72 h (prints id + answer.md; `--redo` bypasses). Any other code is a guard error:
log it and go on (fail open), so a guard bug never stops the fleet.

## 3. claude-job start (bash), before the worktree is made
Add `--allow-dup` and `--redo` to the option loop (`allow_dup=--allow-dup` / `redo=--redo`, passed through), then:

    tf=$(mktemp); printf '%s' "$task" > "$tf"
    cj-guard check --label "$label" --task-file "$tf" $allow_dup $redo; g=$?; rm -f "$tf"
    case $g in 0) ;; 71|72|73) exit $g ;; *) echo "claude-job: cj-guard error $g, starting anyway" >&2 ;; esac

## 4. cj_routing.py requeue/escalate paths (python), before the new start
    sys.path.insert(0, "/home/boki/coord/boki-tools/cj-dedup"); from cj_dedup import guard
    code, msg = guard(label, task)          # label WITH its requeue:/escalate(x): prefix is fine
    if code == 72: mark the item stuck (do not requeue again); if code in (71, 73): skip and log msg

## 5. backlog-refill
Insert with `cj-guard backlog-add --json "$item"` (exit 1 = same key or a near-identical task already there), or
`backlog_add(path, item)` from python. Once: `cj-guard backlog-dedupe` (keeps backlog.jsonl.bak-1112-redo).
When refill starts jobs, they go through claude-job start and are guarded there.

## 6. usage-pacer
Each tick: `cj-redo-report --hourly-log /home/boki/cj/redo-report.log` (writes at most once an hour).
Recurring jobs (backlog planner, fast suite, integration waves) are the same task each time: start them with `--redo`,
or rule c blocks them. Account pacing is not touched.

## 7. TRACKERS.md / stall-watch
    - redo-report: /home/boki/cj/redo-report.log (hourly, cj-redo-report); stuck tasks: /home/boki/cj/stuck.jsonl
stall-watch: alert when the last redo-report line is older than 2 h, or stuck.jsonl grew since the last look.

## Notes
- Records read: /home/boki/cj/<id>/{label,task,answer.md,result.json,rc,log} (w2 copies have prompt instead of task).
  Running = no rc, no STATUS line, younger than CJ_MAX_RUN_H (10). An older run with neither is "lost".
- Continuations take the previous run's key: a task naming `PREVIOUS ATTEMPT: job <id>` / `restart of job <id>`
  (when its original task matches that run) or carrying that run's answer.md "Unfinished" list.
- Templated per-branch tasks are 0.85-0.9 alike; they are not near-duplicates when each names an ext/* branch the
  other does not.
