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
