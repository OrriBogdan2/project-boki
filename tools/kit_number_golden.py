#!/usr/bin/env python3
"""Golden snapshot of every gameplay number in the kit data (owner concern 5: new changes break old ones).

Usage:
    python3 tools/kit_number_golden.py --check    # diff the live numbers against the snapshot (exit 1 on drift)
    python3 tools/kit_number_golden.py --bless    # rewrite the snapshot from the live files (a deliberate retune)

Snapshot: tools/goldens/kit_numbers.tsv, one sorted `key<TAB>value` row per number or flag in
content/archetypes/*.json and content/rules/kit_parity.json. Key = `<file>:<dotted.path>` with `[i]` for list items.
Only numbers and booleans count; text (names, card lines, evidence) is free to edit. health.py --strict runs --check.
See docs/ARCHETYPES.md, 'Kit number golden'.
"""
import glob, json, os, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SNAP = os.path.join(ROOT, "tools", "goldens", "kit_numbers.tsv")
SOURCES = ["content/archetypes/*.json", "content/rules/kit_parity.json"]


def flat(node, path, out):
    if isinstance(node, dict):
        for k, v in node.items():
            flat(v, f"{path}.{k}" if path else k, out)
    elif isinstance(node, list):
        for i, v in enumerate(node):
            flat(v, f"{path}[{i}]", out)
    elif isinstance(node, bool) or isinstance(node, (int, float)):
        out[path] = json.dumps(node)


def live():
    out = {}
    for pat in SOURCES:
        for f in sorted(glob.glob(os.path.join(ROOT, pat))):
            with open(f, encoding="utf-8") as fh:
                data = json.load(fh)
            sub = {}
            flat(data, "", sub)
            rel = os.path.relpath(f, os.path.join(ROOT, "content")).replace(os.sep, "/")
            for k, v in sub.items():
                out[f"{rel}:{k}"] = v
    return out


def read_snap():
    out = {}
    with open(SNAP, encoding="utf-8") as fh:
        for ln in fh:
            ln = ln.rstrip("\n")
            if ln:
                k, v = ln.split("\t")
                out[k] = v
    return out


def main():
    cur = live()
    if "--bless" in sys.argv:
        os.makedirs(os.path.dirname(SNAP), exist_ok=True)
        with open(SNAP, "w", encoding="utf-8", newline="\n") as fh:
            for k in sorted(cur):
                fh.write(f"{k}\t{cur[k]}\n")
        print(f"KIT GOLDEN blessed: {len(cur)} numbers -> {os.path.relpath(SNAP, ROOT)}")
        return 0
    if not os.path.exists(SNAP):
        print("KIT GOLDEN FAIL: no snapshot; run python3 tools/kit_number_golden.py --bless")
        return 1
    old = read_snap()
    changed = [f"  {k}: {old[k]} -> {cur[k]}" for k in sorted(old) if k in cur and old[k] != cur[k]]
    gone = [f"  {k}: {old[k]} -> (removed)" for k in sorted(old) if k not in cur]
    new = [f"  {k}: (new) -> {cur[k]}" for k in sorted(cur) if k not in old]
    if not (changed or gone or new):
        print(f"KIT GOLDEN OK: {len(cur)} kit numbers match tools/goldens/kit_numbers.tsv")
        return 0
    print(f"KIT GOLDEN FAIL: {len(changed)} changed, {len(gone)} removed, {len(new)} new kit numbers vs the snapshot:")
    print("\n".join((changed + gone + new)[:60]))
    if len(changed + gone + new) > 60:
        print(f"  ... and {len(changed + gone + new) - 60} more")
    print("If the change is deliberate, run python3 tools/kit_number_golden.py --bless and commit the TSV with it.")
    return 1


if __name__ == "__main__":
    sys.exit(main())
