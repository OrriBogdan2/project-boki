#!/bin/bash
# runs targeted checks, one result line each
cd "$(dirname "$0")/.."
export XDG_DATA_HOME=$(mktemp -d)
for f in "$@"; do
  timeout 900 godot --headless --path . -- $f > OUT/chk$f.log 2>&1; rc=$?
  echo "$f rc=$rc $(grep -c -i -E 'FAIL|RED' OUT/chk$f.log) $(tail -n1 OUT/chk$f.log | cut -c1-120)" >> OUT/checks.txt
done
echo DONE >> OUT/checks.txt
