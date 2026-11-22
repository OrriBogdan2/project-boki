#!/bin/bash
# Gate step for the style ratchet: style_lint.py --strict on the candidate tree vs main's tree.
# Usage: tools/style_gate.sh MAIN_TREE CAND_TREE
# Main has old regressions (tools/style_baseline.json), so only lines the candidate adds count: a file that got
# worse, or worse than main already was. Prints those lines and exits 1; exits 0 when there are none.
set -u
[ $# -eq 2 ] || { sed -n 2,5p "$0"; exit 2; }
worse() { (cd "$1" && python3 tools/style_lint.py --strict 2> /dev/null | grep -E '^  [^ ].*: [a-z_]+ [0-9]+ -> [0-9]+$' | sort); }
new=$(comm -13 <(worse "$1") <(worse "$2"))
[ -z "$new" ] && exit 0
printf '%s\n' "$new"
exit 1
