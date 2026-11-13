#!/usr/bin/env python3
"""Read-only: diff every Bokidex prev/next edge against content/rules/evolve.json.

The dex decides WHO evolves into whom; evolve.json decides how. Ids go through the dex's
aliases (game ids like cindle are dex ids like vespyx). Prints missing edges (in the dex, not the
game), extra edges (in the game, not the dex) and wrong parents (the game's parent differs from
the dex's). Exit 1 on any mismatch. Usage: tools/evo_dex_check.py [dex.json] [evolve.json]
"""
import json
import sys
from pathlib import Path

DEX = "/home/boki/coord/boki-tools/rating-room/dex/dex.json"
ROOT = Path(__file__).resolve().parent.parent
EVOLVE = ROOT / "content/rules/evolve.json"
BRANCH_FORMS = ROOT / "content/rules/branch_forms.json"


def main() -> int:
    dex = json.load(open(sys.argv[1] if len(sys.argv) > 1 else DEX))
    rules = json.load(open(sys.argv[2] if len(sys.argv) > 2 else EVOLVE))
    alias = dict(dex["aliases"])
    ids = {e["id"] for e in dex["entries"]}
    for pair in json.load(open(BRANCH_FORMS))["pairs"]:   # alternate forms of ONE dex entry
        main = next((alias.get(i, i) for i in pair if alias.get(i, i) in ids), pair[0])
        alias.update({i: main for i in pair})
    canon = lambda i: alias.get(i, i)  # noqa: E731
    dex_edges = {(canon(e["id"]), canon(n)) for e in dex["entries"] for n in e["next"]}
    dex_edges |= {(canon(p), canon(e["id"])) for e in dex["entries"] for p in e["prev"]}
    game_edges = {(canon(a), canon(o["id"])) for a, line in rules["lines"].items() for o in line["into"]}
    dex_parent = {}
    for a, b in dex_edges:
        dex_parent.setdefault(b, set()).add(a)
    rows = [("missing", a, b, "") for a, b in sorted(dex_edges - game_edges)]
    for a, b in sorted(game_edges - dex_edges):
        kind = "wrong parent" if b in dex_parent else "extra"
        rows.append((kind, a, b, "dex parent: " + ",".join(sorted(dex_parent.get(b, [])))))
    print("%-13s %-12s %-12s %s" % ("kind", "from", "into", "note"))
    for r in rows:
        print("%-13s %-12s %-12s %s" % r)
    print("%d dex edges, %d game edges, %d mismatches" % (len(dex_edges), len(game_edges), len(rows)))
    return 1 if rows else 0


if __name__ == "__main__":
    sys.exit(main())
