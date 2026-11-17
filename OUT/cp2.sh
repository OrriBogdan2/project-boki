#!/bin/bash
# $1 = branch, rest = commits (oldest first)
b=$1; shift
for c in "$@"; do git checkout -q -f --detach origin/main; git cherry-pick -n $c >/dev/null 2>&1
 echo "  $c conf=$(git status --short | grep -E '^(UU|AA|DU|UD|AU|UA)' | awk '{print $2}' | tr '\n' ' ')"; git reset -q --hard origin/main; done
