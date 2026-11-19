#!/bin/bash
# Self-test in a temp COORD_DIR (never touches the real coord dir). Kills only the PID it started itself.
set -u
T=$(mktemp -d); export COORD_DIR=$T SETTLE_SECS=1; B="$(dirname "$0")/coord-relaunch"; fail=0
ok() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
# a finished job and a running job must not be relaunched
"$B" wrap fin -- true; "$B" launch live -- sleep 30 >$T/l.out; LIVEID=$(grep -o " id=[0-9a-f]*" $T/l.out | cut -d= -f2)
# a job killed with no DONE line (SIGKILL of its wrapper group, by the PID we started)
"$B" launch victim -- sleep 300 >$T/v.out; VID=$(grep -o " id=[0-9a-f]*" $T/v.out | cut -d= -f2); VPID=$(sed 's/.*pid=//' $T/v.out)
sleep 1
ok "victim running" '"$B" list | grep -q "$VID.running"'
kill -KILL -- -$VPID; sleep 0.5
ok "victim DEAD" '"$B" list | grep -q "$VID.DEAD"'
ok "finished not dead" '"$B" list | grep fin | grep -q "DONE rc=0"'
COORD_FAKE_AVAIL_GB=5 "$B" run >$T/hold.out; ok "held below 10GB" 'grep -q "^hold" $T/hold.out && ! grep -q RELAUNCHED $T/LOG.md'
ok "lowmem logged top5" 'grep -q "LOWMEM avail=5.0GB.*top5 RSS" $T/LOG.md'
COORD_FAKE_AVAIL_GB=20 "$B" run >$T/go.out; ok "relaunched at 20GB" 'grep -q "RELAUNCHED victim" $T/LOG.md'
ok "old marked relaunched" '"$B" list | grep "$VID" | grep -q "RELAUNCHED as"'
COORD_FAKE_AVAIL_GB=20 "$B" run >$T/again.out; ok "no second relaunch" '[ $(grep -c RELAUNCHED $T/LOG.md) = 1 ]'
NEW=$("$B" list | grep victim | grep running | cut -f1); ok "new instance running" '[ -n "$NEW" ]'
# cleanup: only groups we started (pgids recorded in launches.tsv)
for p in $(awk -F'\t' '$1=="START"{print $5}' $T/launches.tsv); do kill -KILL -- -$p 2>/dev/null; done
rm -rf $T; [ $fail = 0 ] && echo ALL OK
exit $fail
