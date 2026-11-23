#!/bin/bash
cd /tmp/slg; S=/home/boki/cj/20261115-130514-a1/tree/ops/suite-load-gate/suite-fast.sh
(./load.sh 26 400 &); sleep 75
SUITE_RUN_TIMEOUT=60 ./go.sh after-new $S
sleep 200   # let busy loops end and load settle
(./load.sh 26 240 &); sleep 75
# retry path: no start/per-run wait, so the canary starts loaded and times out; the retry waits for the load to drop
SUITE_RUN_TIMEOUT=60 SUITE_LOAD_WAIT=0 SUITE_RUN_LOAD_WAIT=0 SUITE_RETRY_LOAD_WAIT=900 ./go.sh retry-new $S
echo ALLDONE >> table.txt
