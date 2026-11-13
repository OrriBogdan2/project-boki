#!/bin/bash
# suite.sh TREE OUT [JOBS] : run every registered -check flag of TREE headless (temp XDG_DATA_HOME each, 300 s cap),
# JOBS at a time (default 12); FLAGS="--a-check --b-check" runs only those. OUT gets "<flag> <rc> <script_errors>"
# per check; red = rc != 0 or a SCRIPT ERROR.
# Compare two runs with: join <(sort A) <(sort B) | awk '($2!=0||$3>0) && $4==0 && $5==0' (red on A only).
set -u
TREE=$(realpath "$1") OUT=$2 JOBS=${3:-12}
LOGS=$OUT.logs; mkdir -p "$LOGS"; : > "$OUT"
[ -d "$TREE/.godot/imported" ] || godot --headless --path "$TREE" --import > "$LOGS/_import.log" 2>&1
one() {
	local flag=$1 x; x=$(mktemp -d)
	XDG_DATA_HOME=$x timeout 300 godot --headless --path "$TREE" -- "$flag" > "$LOGS/$flag.log" 2>&1
	local rc=$?; rm -rf "$x"
	echo "$flag $rc $(grep -c 'SCRIPT ERROR' "$LOGS/$flag.log")" >> "$OUT"
}
export -f one; export TREE OUT LOGS
{ [ -n "${FLAGS:-}" ] && tr ' ' '\n' <<< "$FLAGS" || grep -o '^\s*"--[a-z0-9-]*-check"' "$TREE/tools/check_registry.gd" | tr -d ' \t"' | sort -u; } | xargs -P "$JOBS" -I{} bash -c 'one {}'
