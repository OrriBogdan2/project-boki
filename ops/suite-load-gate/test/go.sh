#!/bin/bash
# go.sh NAME SCRIPT: canary-only suite on this tree (both sides), pinned to cpus 0-15 (simulates 16-core hetzner)
n=$1; o=/tmp/slg/$n; mkdir -p $o; for f in --check --base-check --aimkit-check --ability-check --boki-wisp-check --cam-framing-check --nook-check --race-check --roster-check --evo-check; do echo -- $f; done | sed 's/^-- //' > $o/flags.txt
W=/home/boki/cj/20261115-130514-a1/tree
s=$(date +%s); l0=$(cut -d' ' -f1 /proc/loadavg)
OUT=$o GW=$W MW=$W SUITE_ALERT=/tmp/slg/ALERT SUITE_CACHE_DIR=/tmp/slg/cache SUITE_PTR=/tmp/slg/ptr SUITE_TREE_CACHE=0 SUITE_CACHE=0 SUITE_CANARY_ONLY=1 SUITE_PODS= \
  taskset -c 0-15 bash $2 6 > $o/run.log 2>&1; rc=$?
echo "$n rc=$rc load_start=$l0 load_end=$(cut -d' ' -f1 /proc/loadavg) total=$(( $(date +%s) - s ))s aimkit=$(cat $o/merge/__aimkit_check.secs $o/main/__aimkit_check.secs 2>/dev/null|tr '\n' /) rc124=$(grep -l '^124 ' $o/*/*.rc 2>/dev/null|wc -l)" | tee -a /tmp/slg/table.txt
