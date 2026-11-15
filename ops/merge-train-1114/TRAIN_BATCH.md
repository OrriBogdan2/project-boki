# train-batch: stop GATE GREEN going stale

Main moves every 20-30 min, so a green that must have `behind_by 0` is stale before merge-ready-watch (one PR per run) reaches it.
`train-batch run` folds every green-but-behind PR into one `ext/merge-train-<MMDD>-<HHMM>` branch (main + each PR head, merge_batch.sh
conflict policy; conflicting or head-moved PRs are skipped and logged), gates it once with `gate-shard`, opens one PR listing the folded
PRs and posts `GATE GREEN <full sha>` on it. `train-batch finish` closes the folded PRs ("merged via #N") after the train merged.
Details: `train-batch` docstring. Test: `bash ops/merge-train-1114/train_batch_test.sh` (11 checks, local, no cluster).

## Install (coordinator, hetzner)
    cp ops/merge-train-1114/{train-batch,gate-shard,gate_shard_run.gd} /home/boki/coord/boki-tools/merge-train/ && boki-install boki-tools/merge-train
    cron-add '7-59/10 * * * * cd /home/boki/project-boki && $HOME/bin/train-batch finish >> $HOME/cj/merge-train/cron.log 2>&1'
    # start a train (cron or by hand; needs >= 2 greens behind, otherwise it logs and exits):
    cd /home/boki/project-boki && train-batch run

## The hold: merge-ready-watch must call it
`train-batch hold [--except <head ref>]` exits 0 (prints `HOLD <branch> <age>`) while a train is gating or waiting to merge, else 1.
The hold is the `$TRAIN_STATE/HOLD` file (written by `run`) or any unmerged remote `ext/merge-train-<MMDD>-<HHMM>` branch (so a train
run on a worker without gh still holds), and ends by itself after 90 min (`HOLD_MIN`), logged to `$TRAIN_STATE/train.log`.
In merge-ready-watch, before it merges a PR (`$head_ref` = that PR's head branch):

    if train-batch hold --except "$head_ref" > /dev/null; then echo "held for $(train-batch hold)"; continue; fi

so only the train PR (head ref `ext/merge-train-*`) passes while the hold is on. regate-bot should skip PRs while `train-batch hold` is 0.
