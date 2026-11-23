# jobq identical-job dedupe (hetzner install)

Goal (focus baseline 20261122-083514-a2): 259 of 1,186 GPU jobs in 35 h were identical re-runs (7.7 GPU-h).
`jobq submit` now prints the id of a done job instead of queueing a new one when all of these hold:
- the done job finished **rc 0**, and its id (its submit time) is less than `JOBQ_DEDUPE_H` (default 6) hours old;
- same tree path, and the same tree **state**: git HEAD plus a hash of uncommitted changes and untracked (non-ignored) files;
- same `--app`, `--needs`, `--out`, `--only`, and byte-identical app args. `--label` and `--timeout` are not compared.
A tree with no git HEAD is never deduped. Jobs submitted before the install have no TREESIG, so they never match.
Opt out: `--no-dedupe` or `JOBQ_DEDUPE=0`. Each hit adds a line to `$Q/dedupe/hits.log` (`epoch id label`).
`wait`/`result` on the returned id work as usual (it is already done), so callers need no change.

## Install (on hetzner, as boki)
    cp /home/boki/bin/jobq /home/boki/bin/jobq.bak-1123
    python3 ops/jobq-dedupe/apply_dedupe.py /home/boki/bin/jobq          # dry: writes jobq.dedupe.new
    ops/jobq-dedupe/selftest.sh /home/boki/bin/jobq.dedupe.new             # 11 ok lines, scratch queue only
    mv /home/boki/bin/jobq.dedupe.new /home/boki/bin/jobq                  # then also copy it to coord/boki-tools/jobq
The script makes anchored edits, so it also applies to a jobq newer than the 11-18 copy it was written on (the live one
has `submit --fill`). If an anchor is missing it stops and names it, with nothing written.

## Time-dependent callers: opt them out
    sed -i 's/\$J submit --tree "\$T" --needs gpu --no-fallback/$J submit --tree "$T" --needs gpu --no-fallback --no-dedupe/' coord/boki-tools/gpu-perf-report
    sed -i 's/\$J submit --tree \$WT --needs any/$J submit --tree $WT --needs any --no-dedupe/' coord/boki-tools/nightly-soak
(gpu-perf-report = perf samples; nightly-soak = repeats by design.) The `capture.sh` named in the earlier attempt
does not exist in boki-tools or the repo. Any random-seed render caller should pass `--no-dedupe` too.

## Check after a day
Re-run the lane 1 scoreboard: "identical reruns" should drop from 259/35 h to under 30. `wc -l $Q/dedupe/hits.log`
counts the jobs saved.
