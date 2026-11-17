#!/bin/bash
b=$1; tot=0; hit=0; miss=""
while IFS=$'\t' read -r h s; do tot=$((tot+1)); k="${s:0:50}"
  if grep -qiF -- "$k" OUT/mainsubj.txt; then hit=$((hit+1)); else miss="$miss $h"; fi
done < <(git log --no-merges --right-only --cherry-pick --format='%h%x09%s' origin/main...origin/ext/$b)
echo "$b: $hit/$tot subjects on main; not:$miss"
