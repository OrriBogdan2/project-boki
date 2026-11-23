# regate-bot: install on hetzner (built on rpc7, which has no gh, no ssh to hetzner, no boki-install / cron-add)

Files (this dir, copied back to hetzner at /home/boki/meshy/regate-bot-1114/regate-bot/):
- `regate-bot` (hetzner cron): finds GATE GREEN PRs that main left behind, re-gates one at a time on a worker, posts the result.
- `regate-run` (runs on the worker over ssh; rsynced to worker:/home/boki/regate-bot/ on every start): merge main in, import, gate, push.
- `suite_speed.py` + `canary.txt`: copy of ops/suite-speed from ext/suite-gate-fast (the merge-candidate gate engine). If
  suite-speed is already in boki-tools, regate-run prefers ~/bin/suite_speed.py and the boki-tools copy on the worker.
- `gh-outbox-relay` (hetzner cron): posts comments that worker jobs wrote to ~/cj/<id>/{gh-outbox,comments}/pr<N>*.md.
- `regate-probe` (fleet-watch): prints ALERT lines for regate.lag / merge.stall / regate.dead.
- `regate_common.py`: shared helpers (gh or the public API, workers, ssh, job status).

## Steps (coordinator, on hetzner)

    mkdir -p /home/boki/coord/boki-tools/regate-bot
    cp /home/boki/meshy/regate-bot-1114/regate-bot/{regate-bot,regate-run,gh-outbox-relay,regate-probe,regate_common.py,suite_speed.py,canary.txt} /home/boki/coord/boki-tools/regate-bot/
    boki-install boki-tools/regate-bot
    regate-bot --dry                 # per-PR decision, changes nothing
    gh-outbox-relay --dry            # what it would post
    regate-probe --status
    cron-add '2-59/5 * * * * $HOME/bin/regate-bot >> $HOME/cj/regate-bot/cron.log 2>&1'
    cron-add '1-59/5 * * * * $HOME/bin/gh-outbox-relay >> $HOME/cj/gh-outbox-relay.log 2>&1'
    # merge-ready-watch every 5 min instead of 10 (its cron line: */10 -> */5)

regate-bot needs `~/.ssh/boki_s2_deploy` to reach the workers in `~/cj/workers` (only workers with `godot` on PATH are used;
`REGATE_WORKER=rpc7` pins one, `REGATE_WORKER=local` runs on hetzner itself). The regate-bot module imports regate_common.py
from its own dir: if boki-install symlinks only executables into ~/bin, keep the symlinks (resolve() follows them) or set
PYTHONPATH.

fleet-watch: add `~/bin/regate-probe` to its checks (it prints only ALERT lines, nothing when healthy).

TRACKERS.md line:

    - regate.lag (regate-probe, in fleet-watch): a WAITING PR in ~/cj/regate-bot/regate-state.txt or ~/cj/merge-ready-state.txt for > 60 min = red; merge.stall: no "Merge pull request" on main for 2 h while gated PRs are open = red; regate.dead: regate-bot state.json > 30 min old = red.

## Contract for worker jobs (no gh on workers)
Write the comment to `~/cj/<job id>/gh-outbox/pr<N>.md` (one file per comment; first line `GATE GREEN <full head sha>: ...`).
gh-outbox-relay posts it within 5 min if that sha is still the PR head; a GATE GREEN for an old head is never posted.
