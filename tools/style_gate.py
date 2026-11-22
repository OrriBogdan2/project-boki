#!/usr/bin/env python3
"""Gate step for the style ratchet (tools/style_lint.py) on a PR: candidate tree vs main's tree.

  python3 tools/style_gate.py MAIN_TREE CAND_TREE

A file/rule is worse when the candidate has more problems than main allows, where main allows
max(main's baseline, main's current count): main's own old regressions do not block a PR, and the
candidate's tools/style_baseline.json is ignored, so a PR cannot let new problems in by running --update.
New files start at 0. Prints every worse file/rule and exits 1; exits 0 when there are none.
The lint rules are the ones next to this script (run main's copy so a PR cannot change them for itself).
"""

import json, os, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import style_lint  # noqa: E402


def counts(tree):
    style_lint.ROOT = os.path.abspath(tree)
    return style_lint.counts()


def main():
    if len(sys.argv) != 3:
        print(__doc__.strip())
        return 2
    mt, ct = sys.argv[1:]
    bp = os.path.join(mt, "tools", "style_baseline.json")
    base = json.load(open(bp, encoding="utf-8")) if os.path.exists(bp) else {}
    main_now, cand = counts(mt), counts(ct)
    worse = []
    for p, c in cand.items():
        for k, v in c.items():
            allow = max(int(base.get(p, {}).get(k, 0)), main_now.get(p, {}).get(k, 0))
            if v > allow:
                worse.append(f"{p}: {k} {allow} -> {v}")
    for w in worse:
        print(w)
    return 1 if worse else 0


if __name__ == "__main__":
    sys.exit(main())
