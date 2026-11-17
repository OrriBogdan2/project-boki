#!/bin/bash
# per unique commit of branch: does it cherry-pick cleanly onto origin/main?
b=$1
git checkout -q -f --detach origin/main
for c in $(git log --no-merges --right-only --cherry-pick --reverse --format=%h origin/main...origin/ext/$b); do
  out=$(git cherry-pick -n $c 2>&1); rc=$?
  nconf=$(git status --short | grep -cE '^(UU|AA|DU|UD|AU|UA)')
  nchg=$(git diff --cached --name-only | wc -l)
  echo "  $c rc=$rc conf=$nconf staged=$nchg $(git log -1 --format=%s $c | cut -c1-70)"
  git reset -q --hard origin/main
done
