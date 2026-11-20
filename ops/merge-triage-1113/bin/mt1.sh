#!/bin/bash
# mt1.sh <branch> <sha> -> /tmp/mt/w2/<sanitized>.txt : status mtree conflictfiles...
b=$1; s=$2; o=/tmp/mt/w2/$(echo $b | tr / _).txt
out=$(git merge-tree --write-tree --name-only --no-messages origin/main $s 2>/dev/null); rc=$?
tree=$(echo "$out" | head -1); cf=$(echo "$out" | tail -n +2 | tr '\n' ' ')
mt=$(git rev-parse origin/main^{tree})
if [ $rc -eq 0 ]; then st=$([ "$tree" = "$mt" ] && echo inmain || echo clean); else st=conflict; fi
echo "$b $s $st $cf" > $o
