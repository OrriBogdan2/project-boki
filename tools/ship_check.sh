#!/bin/bash
# The quick pre-ship checks (AGENTS.md section 6): compile, health, the golden saves, the build size.
# Usage: tools/ship_check.sh. Runs everything and exits 1 if any step failed. Needs `godot` on PATH.
cd "$(dirname "$0")/.." || exit 1
export XDG_DATA_HOME="$(mktemp -d)"
trap 'rm -rf "$XDG_DATA_HOME"' EXIT
fail=0
step() { echo "== $1"; shift; "$@" || { echo "FAILED: $1"; fail=1; }; }
step "scripts compile" bash -c 'godot --headless -- --check 2>&1 | grep -q "failures: 0"'
step "health" python3 tools/health.py --strict
step "golden saves" bash -c 'out=$(godot --headless -- --save-compat-check 2>&1); echo "$out" | grep "^SAVECOMPAT \(FAIL\|DONE\)"; echo "$out" | grep -q "failures: 0"'
step "size budget" python3 tools/size_budget.py --check
exit $fail
