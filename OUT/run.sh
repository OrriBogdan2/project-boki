#!/bin/bash
# runs targeted checks, one result line each
cd "${RUNDIR:-$(dirname "$0")/..}"; OUTD=${OUTD:-OUT}
export XDG_DATA_HOME=$(mktemp -d)
for f in "$@"; do
  timeout 900 godot --headless --path . -- $f > $OUTD/chk$f.log 2>&1; rc=$?
  echo "$f rc=$rc $(grep -c -i -E 'FAIL|RED' $OUTD/chk$f.log) $(tail -n1 $OUTD/chk$f.log | cut -c1-120)" >> $OUTD/checks.txt
done
echo DONE >> $OUTD/checks.txt
