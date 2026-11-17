#!/bin/bash
# usage: try.sh <branch>  -> m/<b> from main, merge ext/<b> (no commit), list conflicts
b=$1; git checkout -q -f -B m/$b origin/main; git merge --no-ff --no-commit origin/ext/$b >/dev/null 2>&1
git status --short | grep -E '^(UU|AA|DU|UD|AU|UA|DD)' | awk '{print $1, $2}' | sed 's/\.glb$/.glb/' > OUT/c.$b.txt
echo "$b: $(wc -l < OUT/c.$b.txt) conflicts; code/text: $(grep -vE '\.(glb|jpg|png|import|md|uid|webp)$' OUT/c.$b.txt | wc -l)"
