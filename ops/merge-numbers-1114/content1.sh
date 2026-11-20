#!/bin/bash
# content1.sh BRANCH TIP : files the tip changed since its merge-base with origin/main; how many already equal in main; git cherry +/- counts
b=$1; t=$2; mb=$(git merge-base origin/main "$t") || { echo "$b NOMB"; exit; }
n=0; same=0
while IFS= read -r f; do n=$((n+1))
  a=$(git rev-parse -q --verify "$t:$f" 2>/dev/null); m=$(git rev-parse -q --verify "origin/main:$f" 2>/dev/null)
  [ "$a" = "$m" ] && same=$((same+1))
done < <(git diff --name-only --no-renames "$mb" "$t")
ch=$(git cherry origin/main "$t" 2>/dev/null); plus=$(grep -c '^+' <<<"$ch"); minus=$(grep -c '^-' <<<"$ch")
echo "$b files=$n same=$same cherry_plus=$plus cherry_minus=$minus"
