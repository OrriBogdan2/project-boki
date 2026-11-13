# Installing suite-speed on hetzner (needs a hetzner session; w2 cannot reach the masters)

The masters live in `/home/boki/coord/boki-tools`, and `boki-install` installs them. Do not run
`ship-release.sh`, and do not touch a running merge-candidate (`/home/boki/mc`) or release suite while installing.

1. Copy the files into the master tree and install:

       cp ops/suite-speed/suite_speed.py /home/boki/coord/boki-tools/suite-speed/
       boki-install

   The canary list goes to `/home/boki/coord/boki-tools/suite-speed/canary.txt`. The default is the list below,
   picked on w2 from the 11-13 baseline: fast and green on both trees.

2. Choose one of two ways to wire it into `suite-fast.sh`.

   - **A: use the engine** (the simplest). Replace the per-flag loop with:

         suite_speed.py gate --main "$MAIN_TREE" --merge "$MERGE_TREE" --out "$OUT" --jobs "$JOBS" \
             --godot "$GODOT" --godot-args "$GODOT_ARGS" \
             --canary="$(paste -sd, canary.txt)" --alert-file /home/boki/coord/SUITE_ALERT \
             ${MERGE_CANDIDATE:+--select-base "$(cat /home/boki/mc/last-green.sha)"}
         rc=$?   # 0 ok, 1 NEW-RED, 3 ENV-BROKEN (summary.txt has the ENV-BROKEN line)

     It writes `summary.txt` with NEW-RED / red on both / fixed. It also writes `main|merge/<flag>.log|.rc|.secs`.
     After a green merge-candidate run, write `git -C "$MERGE_TREE" rev-parse HEAD` to `last-green.sha`.

   - **B: keep the loop and add four hooks.**

     1. Order: `suite_speed.py order flags.txt <secs dir or history.tsv> > flags.ordered`.
     2. Canary: before the loop, run
        `suite_speed.py gate ... --flags canary.txt --no-cache --massred-min 100000`.
        On rc 3, copy its ENV-BROKEN line into `summary.txt`, then `exit 3`.
     3. Main side:

            if out=$(suite_speed.py cache-get "$MAIN_TREE" "$flag" --godot "$GODOT" --godot-args "$GODOT_ARGS"); then
                rc=$(head -1 <<<"$out")    # a cached red stays red
            else
                (run it); suite_speed.py cache-put "$MAIN_TREE" "$flag" "$rc" "$log" "$secs" ...
            fi

        Only call cache-put when the gate is not ENV-BROKEN. cache-put already refuses crash, timeout and
        mismatch reds.
     4. Mass red: every 25 paired flags, if 60% or more are red on both trees, write
        `ENV-BROKEN: mass red ...` and stop.

3. Watcher: add `/home/boki/coord/SUITE_ALERT` to fleet-watch's alert files, next to DISK_ALERT. It holds one
   line, `ENV-BROKEN: <why> (gate <dir>, <time>)`. Remove the file once it has been acted on.

4. Timeouts: keep the per-flag timeout at 300 s. A timeout is a red that is never cached.

## Canary list (11-13, w2 baseline: green on both trees, among the fastest; see the job report)

See `canary.txt`.
