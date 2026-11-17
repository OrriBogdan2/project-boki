# train-batch: stop GATE GREEN going stale

Main moves every 20-30 min, so a green that must have `behind_by 0` is stale before merge-ready-watch (one PR per run) reaches it.
`train-batch run` folds every green-but-behind PR into one `ext/merge-train-<MMDD>-<HHMM>` branch (main + each PR head, merge_batch.sh
conflict policy; conflicting or head-moved PRs are skipped and logged), gates it once with `gate-shard`, opens one PR listing the folded
PRs and posts `GATE GREEN <full sha>` on it. `train-batch finish` closes the folded PRs ("merged via #N") after the train merged.
Details: `train-batch` docstring. Test: `bash ops/merge-train-1114/train_batch_test.sh` (18 checks, local, no cluster).

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

## First real run (11-15, rpc4, #98 #82 #85)
Build 2 min; full gate 51 min (rpc4 under load: 253 flags red on both sides and re-run, 3 rounds) -> NEW-RED 1 (`--ability-card-check`, red on
main as well, a lost shard job on the candidate); main moved (#82 merged by merge-ready-watch, which has no hold yet) -> `regate-run` delta
gate 4 min -> GREEN, branch `ext/merge-train-1115-0201` behind main 0. rpc4 has no gh, so the PR and the GATE GREEN comment are the
coordinator's (texts: `pr-body.md`, `gate-comment.md`). A full gate is 10-50 min and main moves every 20-30, so the delta gate and the hold are what make a train land.

## Second look (11-15 04:15Z, w2, job 20261115-040516-a1)
- Train #108 (`ext/merge-train-1115-0201`) never merged: no hold in merge-ready-watch, no PR/GATE GREEN until 03:37Z, and main moved 27
  commits; it is now dirty (conflicts) and its hold auto-released at 134 min. Close #108 and delete its branch (coordinator, gh).
- The greens left behind are mostly not train material: of #86 #62 #51, #62 conflicts with main itself (net.gd, settings.gd, cam.gd ...)
  and #98 #85 went REGATE RED. `run` now tells the two kinds of skip apart: "conflicts with main itself: needs a conflict fix" (send to a
  fix job) vs "only with the others: next train".
- regate-bot moves heads (merges main in) without a new green yet; a bare `run 86` used to fold that ungated head. Bare ids now need
  their newest GATE GREEN at their head (`TRAIN_TRUST_IDS=1` to skip, tests only).
- Without a token, `select` reads comments of ~35 behind PRs (60 API calls/h): cached in `$TRAIN_STATE/comments-cache.json` by updated_at.
- The train only pays off once merge-ready-watch has the hold line above and the box that runs `run` can open the PR within minutes
  (hetzner, gh): a train published 90 min after its gate is as stale as the greens it folded.

## Third look (11-15 16Z, rpc7, job 20261115-155513-a1)
- Of 50 open PRs only 5 have a GATE GREEN at their head (#93 #87 #84 #91 #85); all 5 conflict with main d65f00de26 itself (#53 landed
  412 files). #93 was GATE GREEN 6 times today (07:27 to 15:07) and never merged: the one-by-one re-gate loses to main every time.
- Skip labels now come from a scratch merge with merge_batch's policy (git 2.34 has no `merge-tree --write-tree`, so every skip used to
  say "only with the others"). merge_batch takes ours on `.uid` conflicts: #87's only conflict was an add/add `.uid`.
- regate-bot: when >= 2 PRs are green-but-behind, start `train-batch run` instead of one regate-run each, and start nothing while
  `train-batch hold` is 0 (the hold line above in merge-ready-watch is still required; without it the train goes stale too).
