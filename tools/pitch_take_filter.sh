#!/bin/bash
# Runs one pitch-reel take: tools/pitch_take_filter.sh <movie> <stall_s> <log_lines> <cmd...>
# - output filter: the child's PITCH_ lines, and only the first <log_lines> of the rest (a movie child once printed 2 GB)
# - watchdog: the take's own child (only that pid) is killed when <movie> has not grown for <stall_s> s
#   (PITCH_STALL line, exit 124), so a hung take cannot hold the GPU slot; the caller marks it failed and goes on.
movie=$1; stall=$2; lines=$3; shift 3
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
{ "$@" 2>&1 & echo $! >"$tmp/pid"; wait $!; echo $? >"$tmp/rc"; } \
	| awk -v n_max="$lines" '/^PITCH_/ {print; next} n < n_max {n++; print} END {print "PITCH_LOG lines=" NR}' &
pipe=$!
last=-1; idle=0
while kill -0 "$pipe" 2>/dev/null; do
	sleep "${PITCH_POLL_S:-5}"
	size=$(stat -c %s "$movie" 2>/dev/null || echo 0)
	if [ "$size" != "$last" ]; then last=$size; idle=0; else idle=$((idle + ${PITCH_POLL_S:-5})); fi
	if [ "$idle" -ge "$stall" ] && [ -s "$tmp/pid" ]; then
		echo "PITCH_STALL no new frames for ${idle}s (movie $size bytes), take killed"
		kill "$(cat "$tmp/pid")" 2>/dev/null; sleep 3; kill -9 "$(cat "$tmp/pid")" 2>/dev/null
		touch "$tmp/stalled"
	fi
done
wait "$pipe"
[ -e "$tmp/stalled" ] && exit 124
exit "$(cat "$tmp/rc" 2>/dev/null || echo 1)"
