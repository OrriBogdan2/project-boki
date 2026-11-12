#!/bin/bash
# Runs one pitch-reel take: tools/pitch_take_filter.sh <movie> <stall_s> <log_lines> <cmd...>
# - output filter: the child's PITCH_ lines, and only the first <log_lines> of the rest (a movie child once printed 2 GB)
# - watchdog: the take's own child (only that pid) is killed when <movie> has not grown for <stall_s> s
#   (PITCH_STALL line, exit 124), so a hung take cannot hold the GPU slot; the caller marks it failed and goes on.
# - heartbeat: while the movie grows, a PITCH_BEAT line on stderr (the job's log) at most every BEAT_S s, so the job
#   log stops growing only when no frames come (the GPU queue requeues a pitch-reel job whose log is still for 20 min).
movie=$1; stall=$2; lines=$3; shift 3
poll=${PITCH_POLL_S:-5}   # s between looks at the movie's size
BEAT_S=60
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
{ "$@" 2>&1 & echo $! >"$tmp/pid"; wait $!; echo $? >"$tmp/rc"; } \
	| awk -v n_max="$lines" '/^PITCH_/ {print; next} n < n_max {n++; print} END {print "PITCH_LOG lines=" NR}' &
pipe=$!
last=-1; idle=0; beat=0
while kill -0 "$pipe" 2>/dev/null; do
	sleep "$poll"
	size=$(stat -c %s "$movie" 2>/dev/null || echo 0)
	beat=$((beat + poll))
	if [ "$size" != "$last" ]; then
		last=$size; idle=0
		[ "$beat" -ge "$BEAT_S" ] && beat=0 && echo "PITCH_BEAT $(basename "$movie") bytes=$size" >&2
	else
		idle=$((idle + poll))
	fi
	if [ "$idle" -ge "$stall" ] && [ ! -e "$tmp/stalled" ] && [ -s "$tmp/pid" ]; then
		touch "$tmp/stalled"
		echo "PITCH_STALL no new frames for ${idle}s (movie $size bytes), take killed"
		pid=$(cat "$tmp/pid")
		kill "$pid" 2>/dev/null
		for _ in 1 2 3; do kill -0 "$pid" 2>/dev/null && sleep 1; done
		kill -0 "$pid" 2>/dev/null && kill -9 "$pid"
	fi
done
wait "$pipe"
[ -e "$tmp/stalled" ] && exit 124
exit "$(cat "$tmp/rc" 2>/dev/null || echo 1)"
