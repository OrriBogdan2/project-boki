#!/bin/bash
# pv.sh branch [maxlines]: added lines (>=8 chars) of branch not present in main's file
cd /home/boki/cj/20261113-173508-a3/tree
b=origin/$1; mb=$(git merge-base origin/main $b)
git diff -U0 --no-renames $mb $b -- . ':!*.uid' ':!*.import' ':!briefs' ':!docs/DEBT.md' ':!docs/wiki/Rules.md' ':!tools/check_registry.gd' ':!tools/style_baseline.json' | awk -v B=$b '
/^\+\+\+ b\//{f=substr($0,7); next} /^\+\+\+/{f="";next}
/^\+/ && f!="" {l=substr($0,2); gsub(/^[ \t]+|[ \t]+$/,"",l); if(length(l)>=8){print f"\t"l}}' | while IFS=$'\t' read f l; do git show origin/main:"$f" 2>/dev/null | grep -qF -- "$l" || echo "$f: ${l:0:110}"; done | head -${2:-12}
