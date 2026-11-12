# pacer_rank: usage-pacer reset-aware policy (11-12, "optimize around resets")

Written on rpc4, where /home/boki/bin/usage-pacer and /home/boki/coord/boki-tools are NOT present, so this is
the policy as a standalone, tested module. It still has to be wired into usage-pacer on hetzner and installed
with boki-install. Nothing here is installed or enabled.

Install (on hetzner):
  git -C <repo> fetch origin ext/infra-usage-pacer-rank
  git -C <repo> show FETCH_HEAD:pacer_rank.py > /home/boki/coord/boki-tools/pacer_rank.py
  python3 -I /home/boki/coord/boki-tools/pacer_rank.py --selftest

Wire into usage-pacer:
  - build one `Acct(name, weekly, hours_to_reset, fiveh, hold_h, excluded)` per cswap account; hours_to_reset
    from cswap's weekly reset time (`cswap list --json`), never from pacer history. corybogdan: excluded=True.
  - replace the account pick with `pick_order(accts)` (first = start here), and gate every start with
    `may_start(acct, accts)`. Drop the "need 6h of history" skip: the fresh cap does that job now.
  - per-cycle start count: `allot(pick_order(accts), accts, free_slots)`.
  - usage report: append `summary_lines(accts)` once a day.
  - dry run first: dump the live accounts to the snapshot JSON format (see load_snapshot) and run
    `pacer_rank.py --dry-run snap.json`; enable after the owner/coordinator has seen it.

Knobs: SOON_H 24, SOON_CEIL 97, MID_CEIL 90 (set to usage-pacer's own ceiling), FRESH_H 72, FRESH_MULT 1.5,
FIVEH_STOP 85. A fresh account's cap lifts when no other account can take work now (all others either full,
fresh, or blocked by a 5h hold/guard), so the cap never strands work.

dryrun_1112_0330.txt: the ranking, slot allotment and before/after waste for the 03:30Z 11-12 facts.

# pacer_plan + pacer_backtest (owner addendum 11-12: "plan around their usage times more")

Written on rpc4 by job 20261112-035509-a1. **Not installed:** rpc4 has no usage-pacer, boki-install, snapshots.jsonl,
pacer.log or /usage page source, and rpc4's cswap reports no usage for any slot. Tests use the 11-12 task facts and
synthetic data only.

Files:
- `pacer_plan.py` (items 6-9): `build_plan(accts, now)` plans jobs per account per hour for 48h. Each 5h window is kept
  at or below 85%, and each account lands at 97% at its weekly reset. Near-reset accounts front-load, mid accounts pace
  to reset, and fresh accounts fill the gaps under the pace line x1.5. A held or full window gets 0 jobs until its 5h
  reset, then starts again in the first hour after it. Other functions: `merge_actual` (planned vs actual per hour),
  `write_plan` (`/home/boki/cj/usage-plan.json`), `alerts` (12h/4h before a weekly reset with >10% unused, plus 5h-limit
  hits; labels only, deduped through a state file) and `render_html` (/usage admin fragment, times in ET).
- `pacer_backtest.py` (item 10): measured % lost at resets, 5h-limit windows and kills from pacer.log, compared with
  a pacer_plan replay. The format reader is loose (see its docstring). Run it once on the real file and check the
  "rows skipped" count.
- `snapshot_1112_0400.json` / `dryrun_1112_0400.txt`: the plan for the 04:00Z facts (Outlook1 just reset).

Wire on hetzner (after the pacer_rank steps above):
  1. Copy pacer_rank.py, pacer_plan.py and pacer_backtest.py to boki-tools. Run `python3 -I pacer_plan.py --selftest`
     and `python3 -I pacer_backtest.py --selftest`.
  2. In each usage-pacer tick, build a `PlanAcct` per account from cswap: weekly, weekly reset, 5h %, 5h resets_at
     (`win_reset_h`), hold. Then `build_plan`, `merge_actual(plan, old, running_per_account, now)`, `write_plan`.
     Starts this hour = `plan_jobs[0]` minus jobs already running, gated by `pacer_rank.may_start` (85% 5h guard).
     Turn a fractional plan into whole starts with an accumulator.
  3. Alerts: pass each line from `alerts(plan, "/home/boki/cj/usage-plan.alerts.json")` to coord-tick / stall-watch.
  4. /usage admin page: include `render_html(plan)`, or the file from `pacer_plan.py snap.json --html`.
  5. `pacer_backtest.py /home/boki/usage/snapshots.jsonl --log <pacer.log> --days 3` gives the item 10 numbers.
  6. Dry run (`pacer_plan.py snap.json`) is print-only. Enable after one look.

Knobs: JOB_RATE 0.7 (weekly %-points per job-hour) and WINDOW 17 (weekly %-points one 5h window holds). Both are
estimated from Outlook2 on 11-12 (17% weekly when its 5h limit hit). Measure them per account from the snapshots and
pass them with --job-rate / --window. FLEET 12, MAX_PER_ACCT 6.
Alternative not taken: an LP/optimal schedule. Greedy hourly is simpler to read and keeps every rule visible.
