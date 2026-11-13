#!/usr/bin/env bash
# One gate for the repo: health budgets + style ratchet, then the lint ratchet (gdlint, gdformat, ruff,
# vulture, glTF validation of every .glb/.gltf, Godot unused-code warnings). Called by the suite,
# merge-candidate.sh and .pre-commit-config.yaml. Old debt is baselined in tools/lint_baseline.json; new code must be clean.
#   tools/check.sh                 everything (needs godot: set GODOT=... if it is not `godot` on PATH)
#   tools/check.sh --files a b     only those files (what pre-commit passes; no Godot run, no health)
#   tools/check.sh --no-godot      skip the Godot warning count
#   tools/check.sh --changed       everything, and each .gd this branch changes must be gdformat clean (new branches)
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
exec "$VENV/bin/python" -I tools/lint_gate.py "$@"
