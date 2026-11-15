#!/bin/bash
# load.sh N SECS: N busy loops pinned to cpus 0-15 for SECS
for i in $(seq $1); do taskset -c 0-15 timeout $2 bash -c 'while :; do :; done' & done; wait
