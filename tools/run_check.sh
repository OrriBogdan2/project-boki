#!/usr/bin/env bash
# Run ONE Godot check the way the gate must: its own temp XDG_DATA_HOME / XDG_CONFIG_HOME (removed afterwards, so two
# checks at once never share user:// settings, keybindings or saves), a per-check timeout (slow checks get longer),
# and a verdict from the check's own "failures: N" line, not from Godot's exit code (an exit-time core dump, rc 134/139,
# after "DONE, failures: 0" is a pass; "failures: 3" with exit 0 is a fail).
#   tools/run_check.sh --key-text-check [more godot user args]     log on stdout, verdict on stderr, rc = verdict
# Env: GODOT (default godot), RUN_CHECK_XVFB=0 to run --headless instead of xvfb-run, RUN_CHECK_TIMEOUT to force a
#      timeout in s, RUN_CHECK_LOG=<file> to also keep the log. Slow list: tools/check_timeouts.txt ("<flag> <seconds>").
set -uo pipefail
cd "$(dirname "$0")/.."
flag="${1:?usage: tools/run_check.sh --some-check [args]}"
GODOT_BIN="${GODOT:-godot}"
to="${RUN_CHECK_TIMEOUT:-$(awk -v f="$flag" '$1==f{print $2}' tools/check_timeouts.txt 2>/dev/null | head -1)}"
to="${to:-1200}"
X=$(mktemp -d /tmp/xdg.run_check.XXXXXX); L="$X/log"
trap 'rm -rf "$X"' EXIT
mkdir -p "$X/data" "$X/config"
if [ "${RUN_CHECK_XVFB:-1}" = 1 ] && command -v xvfb-run >/dev/null; then
	pre=(xvfb-run -a); gargs=(--rendering-driver opengl3 --audio-driver Dummy)
else pre=(); gargs=(--headless --audio-driver Dummy); fi
XDG_DATA_HOME="$X/data" XDG_CONFIG_HOME="$X/config" timeout -k 10 "$to" "${pre[@]}" "$GODOT_BIN" "${gargs[@]}" --path . -- "$@" >"$L" 2>&1
rc=$?
tail -c 20000000 "$L"
[ -n "${RUN_CHECK_LOG:-}" ] && cp "$L" "$RUN_CHECK_LOG"
last=$(grep -oE 'failures: [0-9]+' "$L" | tail -1); last=${last#failures: }
if [ "$rc" = 124 ] || [ "$rc" = 137 ]; then v=$rc; why="timeout after ${to}s"
elif [ -n "$last" ]; then
	if [ "$last" != 0 ]; then v=1; why="failures: $last"
	elif [ "$rc" = 0 ]; then v=0; why="failures: 0"
	elif [ "$rc" -ge 128 ]; then v=0; why="failures: 0 (godot exit $rc, a crash at exit, ignored)"
	else v=$rc; why="failures: 0 but the check itself exited $rc"; fi
else v=$rc; why="no failures line, godot exit $rc"; fi
echo "run_check $flag: rc=$v ($why)" >&2
exit "$v"
