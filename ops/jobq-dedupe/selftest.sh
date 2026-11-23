#!/bin/bash
# selftest.sh JOBQ: checks the dedupe in a scratch queue (JOBQ_ROOT in a temp dir; never touches the live queue).
set -u; J=$(readlink -f "${1:?path to jobq}"); T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
export JOBQ_ROOT=$T/q JOBQ_NO_VOL=1; mkdir "$T/tr"; cd "$T/tr" || exit 1
git init -q; echo a > f; git add f; git -c user.name=t -c user.email=t@t commit -qm a
fail=0; ok() { if [ "$2" = "$3" ]; then echo "ok   $1"; else echo "FAIL $1 ($2 vs $3)"; fail=1; fi; }
s() { "$J" submit --tree . "$@" 2>/dev/null; }
a=$(s -- --x 1); "$J" finish "$a" w 0 5
ok "same tree+args reuses done rc0 job" "$(s -- --x 1)" "$a"
ok "label does not matter" "$(s --label other -- --x 1)" "$a"
[ "$(s -- --x 2)" != "$a" ]; ok "different args queues" $? 0
[ "$(s --no-dedupe -- --x 1)" != "$a" ]; ok "--no-dedupe queues" $? 0
[ "$(JOBQ_DEDUPE=0 s -- --x 1)" != "$a" ]; ok "JOBQ_DEDUPE=0 queues" $? 0
[ "$(s --needs gpu -- --x 1)" != "$a" ]; ok "different --needs queues" $? 0
echo b > f; [ "$(s -- --x 1)" != "$a" ]; ok "uncommitted change queues" $? 0; git checkout -q f
echo n > new; [ "$(s -- --x 1)" != "$a" ]; ok "untracked file queues" $? 0; rm new
b=$(s --out o -- --x 3); "$J" finish "$b" w 1 5; [ "$(s --out o -- --x 3)" != "$b" ]; ok "rc!=0 job not reused" $? 0
old=$(date -d '-7 hours' +%Y%m%d-%H%M%S)-00001; mv "$JOBQ_ROOT/done/$a" "$JOBQ_ROOT/done/$old"
[ "$(s -- --x 1)" != "$old" ]; ok "job older than 6h not reused" $? 0
ok "hits logged" "$(wc -l < "$JOBQ_ROOT/dedupe/hits.log")" 2
exit $fail
