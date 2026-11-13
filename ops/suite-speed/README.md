# ops/suite-speed: faster, safer check-suite gates (11-13)

`suite_speed.py` is a stdlib-only gate engine for the release/merge check suite: every registered `-check` flag
run on the merge tree and the main (release-tag) tree, compared side by side. It was built on worker w2, where
`suite-fast.sh` and `check-map.py` (hetzner-only) cannot be read, so it is a drop-in engine plus shell hooks
(`INSTALL.md`), not a patch of those files. It is not game code.

## What it adds

1. **Canary / early abort.** `--canary=<flags>` runs those flags on both trees first.
   - ENV-BROKEN when a canary's rc disagrees with its own `failures: N` line.
   - ENV-BROKEN when at least half the canaries are red on both trees.
   - A mid-run guard (`--massred-min 24 --massred-frac 0.6`) also stops when most paired runs are red on both
     trees, or most merge runs are red at all.
   - ENV-BROKEN writes one line to `summary.txt`, writes the same line to `--alert-file` (a DISK_ALERT-style
     file the watcher reads), exits 3 and caches nothing.
2. **Main-side cache.** Results are keyed by the main tree's content, the Godot binary and the engine args:
   `<cache>/<HEAD^{tree}[-dirty<hash>]>/<sha256(godot)[:16]>-<args hash>/<flag>.json`. The next gate on the same
   tag runs only the merge side.
   - A cached red counts as red, exactly like a fresh one.
   - A gate writes to the cache only when it finished without ENV-BROKEN.
   - What is cached: greens, and reds the check judged itself (`failures: N` > 0).
   - What is re-run every time: crash, timeout, bad-launch and rc-mismatch reds, because those can be the
     environment rather than the code.
3. **Changed-files selection** (merge-candidate runs only; nightly and release stay full): `--select-base <sha>`
   (the last green run) or `select TREE BASE [HEAD]`.
   - Each check's inputs: the closure of its tool script over `res://` paths and `class_name` uses, at the head
     revision.
   - A changed registry entry selects only its own flag.
   - An asset loaded by a built path (`"res://art/" + id`) is tied to the scripts that name its closest
     `res://<dir>/`.
   - These select ALL: `project.godot`, `scripts/main.gd`, `tools/check.gd`, the registry outside `CHECKS`, and
     any game file nothing can be tied to.
   - These select nothing: docs, briefs, ops, `*.md`, `*.import`, `*.uid`, python/shell helpers.
4. **Longest-first order** from the secs history (`history.tsv`, or a directory of `<flag>.secs`): p90
   descending. Flags with no history are ordered as the overall p90, so they start early. `stats` prints the
   per-flag p50/p90 and the slowest 10. `simulate` gives the wall time of the given order against longest-first
   for N workers.

Each run gets its own `XDG_DATA_HOME`/`XDG_CONFIG_HOME`/`XDG_CACHE_HOME`, so parallel checks never share
`user://` saves.

## Usage

    suite_speed.py gate --main /path/main --merge /path/merge --out DIR --jobs 8 \
        --canary="$(paste -sd, canary.txt)" --alert-file /home/boki/coord/SUITE_ALERT
    suite_speed.py stats ~/.cache/boki-suite/history.tsv
    suite_speed.py select /path/merge <last-green-sha>
    suite_speed.py cache-get MAIN_TREE FLAG      # shell runners: a hit prints rc + log tail, exit 0
    suite_speed.py cache-put MAIN_TREE FLAG RC LOGFILE SECS

Outputs in DIR:
- `summary.txt`: NEW-RED, NEW-RED for new flags with no main result, red on both, fixed, RC-MISMATCH, wall time,
  number of runs and of cache hits.
- `rc`: 0 ok, 1 NEW-RED, 3 ENV-BROKEN.
- `main/` and `merge/`: `<flag>.log`, `.rc` and `.secs` for each flag.
- `history.tsv`.

`test_suite_speed.py` runs 19 synthetic checks against a fake godot binary: canary, mismatch, mass-red, cache
semantics, order and selection.
