#!/usr/bin/env bash
# One gate for the repo: health budgets + style ratchet, then the lint ratchet (gdlint, gdformat, ruff,
# vulture, glTF validation of every .glb/.gltf, Godot unused-code warnings). Called by the suite,
# merge-candidate.sh and .pre-commit-config.yaml. Old debt is baselined in tools/lint_baseline.json; new code must be clean.
#   tools/check.sh                 everything (needs godot: set GODOT=... if it is not `godot` on PATH)
#   tools/check.sh --files a b     only those files (what pre-commit passes; no Godot run, no health)
#   tools/check.sh --no-godot      skip the Godot warning count
#   tools/check.sh --changed       everything, and each .gd this branch changes must be gdformat clean (new branches)
#   (the full run also loads the golden saves, --save-compat-check, and checks the export size budget, tools/size_budget.py)
#   tools/check.sh --update        lower the baseline after cleaning a file up (it never raises a count)
set -euo pipefail
cd "$(dirname "$0")/.."
VENV="${BOKI_LINT_VENV:-$HOME/.cache/boki-lint/venv}"
if [ ! -x "$VENV/bin/ruff" ] || [ tools/lint-requirements.txt -nt "$VENV/.installed" ]; then
	python3 -m venv "$VENV"
	"$VENV/bin/pip" install -q -r tools/lint-requirements.txt
	touch "$VENV/.installed"
fi
export PATH="$VENV/bin:$PATH"
if [ "${1:-}" != "--files" ] && [ "${1:-}" != "--update" ]; then
	python3 tools/health.py --strict >/tmp/check-health.$$ || { cat /tmp/check-health.$$; rm -f /tmp/check-health.$$; exit 1; }
	tail -n 2 /tmp/check-health.$$; rm -f /tmp/check-health.$$
fi
if [ "${1:-}" != "--files" ] && [ "${1:-}" != "--update" ] && [ "${1:-}" != "--no-godot" ]; then
	GODOT_BIN="${GODOT:-godot}"
	XDG_DATA_HOME="$(mktemp -d)"; export XDG_DATA_HOME
	out=$("$GODOT_BIN" --headless -- --save-compat-check 2>&1 || true); rm -rf "$XDG_DATA_HOME"; unset XDG_DATA_HOME
	echo "$out" | grep "^SAVECOMPAT \(FAIL\|DONE\)" || true
	echo "$out" | grep -q "failures: 0" || { echo "FAILED: golden saves (docs/SAVES.md)"; exit 1; }
	python3 tools/size_budget.py --check || { echo "FAILED: size budget (docs/SIZE_BUDGET.md)"; exit 1; }
fi
exec "$VENV/bin/python" -I tools/lint_gate.py "$@"
