#!/bin/bash
# inmain1.sh <branch> <sha> <base-ref> <outdir>: per touched file: E=equal blob, R=hunks reverse-apply on base, B=binary differs, N=text not in base
b=$1; s=$2; base=$3; od=$4; o=$od/$(echo $b | tr / _).txt
mb=$(git merge-base $base $s)
export GIT_INDEX_FILE=$(mktemp -p /tmp/mt/w); git read-tree $base
declare -A bin; while IFS=$'\t' read a d f; do [ "$a" = "-" ] && bin[$f]=1; done < <(git diff --no-renames --numstat $mb $s)
diffm=$(git diff --no-renames --name-only $base $s)
res=""
while read f; do [ -z "$f" ] && continue
  if ! grep -qxF -- "$f" <<<"$diffm"; then res+="E:$f "
  elif [ -n "${bin[$f]}" ]; then res+="B:$f "
  elif git diff --no-renames $mb $s -- "$f" | git apply --cached -R --check 2>/dev/null; then res+="R:$f "
  else res+="N:$f "; fi
done < <(git diff --no-renames --name-only $mb $s)
rm -f $GIT_INDEX_FILE
echo "$b $s $res" > $o
