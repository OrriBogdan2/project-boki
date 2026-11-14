#!/bin/bash
b=$1; s=$2; mb=$(git merge-base origin/main $s)
git diff --no-renames --name-only $mb $s > /tmp/mt/w/$$.f
git diff --no-renames --name-only origin/main $s > /tmp/mt/w/$$.m
neq=$(grep -cxFf /tmp/mt/w/$$.m /tmp/mt/w/$$.f)
ct=$(git log -1 --format=%ct $s)
python3 -c 'import json,sys;print(json.dumps(dict(b=sys.argv[1],sha=sys.argv[2],mb=sys.argv[3],files=open(sys.argv[4]).read().split(),neq=int(sys.argv[5]),ct=int(sys.argv[6]))))' "$b" "$s" "$mb" /tmp/mt/w/$$.f "$neq" "$ct" > /tmp/mt/w/out_$$.json
rm -f /tmp/mt/w/$$.f /tmp/mt/w/$$.m
