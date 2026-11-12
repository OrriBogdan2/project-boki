#!/usr/bin/env python3
"""Style ratchet for Project Boki (docs/STYLE.md).

Usage:
  python3 tools/style_lint.py            report counts per rule, and files that got worse
  python3 tools/style_lint.py --strict   exit 1 when any file is worse than tools/style_baseline.json
  python3 tools/style_lint.py --update   rewrite the baseline (only ever after cleaning up, never to let new problems in)
  python3 tools/style_lint.py --file scripts/x.gd   list every problem in one file, with line numbers

The old code has a lot of these, so the rule is a ratchet: a file may not get worse than its baseline,
and a new file starts at zero. Clean a file up, then run --update so it can't slip back.
"""
import json, os, re, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BASELINE = os.path.join(ROOT, "tools", "style_baseline.json")
MAX_LINE = 120      # characters, tabs counted as 4


def code_part(line: str) -> str:
    """The line without its comment and string contents (good enough for counting)."""
    out, q = [], None
    for ch in line:
        if q:
            if ch == q:
                q = None
            continue
        if ch in "\"'":
            q = ch
            out.append(ch)
            continue
        if ch == "#":
            break
        out.append(ch)
    return "".join(out)


def problems(path: str) -> dict:
    """Rule name -> list of line numbers."""
    found = {"long_line": [], "semicolon": [], "nested_ternary": [], "history_comment": []}
    with open(os.path.join(ROOT, path), encoding="utf-8", errors="ignore") as f:
        for i, raw in enumerate(f, 1):
            line = raw.rstrip("\n")
            code = code_part(line)
            if len(line.expandtabs(4)) > MAX_LINE:
                found["long_line"].append(i)
            if re.search(r";\s*\S", code):
                found["semicolon"].append(i)
            if code.count(" if ") >= 2 and code.count(" else ") >= 2:
                found["nested_ternary"].append(i)
            comment = line[len(code):]
            if re.search(r"\((was |owner[:, ]|movefeel|sync\d+)", comment):
                found["history_comment"].append(i)
    return found


def gd_files():
    out = []
    for base in ("scripts", "tools"):
        for d, _, fs in os.walk(os.path.join(ROOT, base)):
            out += [os.path.relpath(os.path.join(d, f), ROOT) for f in fs if f.endswith(".gd")]
    return sorted(out)


def counts():
    return {p: {k: len(v) for k, v in problems(p).items()} for p in gd_files()}


def main():
    args = sys.argv[1:]
    if "--file" in args:
        p = args[args.index("--file") + 1]
        for rule, ls in problems(p).items():
            if ls:
                print(f"{rule}: lines {', '.join(map(str, ls[:40]))}{' ...' if len(ls) > 40 else ''}")
        return
    now = counts()
    if "--update" in args:
        with open(BASELINE, "w", encoding="utf-8") as f:
            json.dump({p: {k: v for k, v in c.items() if v} for p, c in now.items() if any(c.values())}, f, indent=0, sort_keys=True)
        print(f"style baseline written for {len(now)} files")
        return
    base = json.load(open(BASELINE, encoding="utf-8")) if os.path.exists(BASELINE) else {}
    totals = {}
    worse = []
    for p, c in now.items():
        for k, v in c.items():
            totals[k] = totals.get(k, 0) + v
            if v > int(base.get(p, {}).get(k, 0)):
                worse.append(f"{p}: {k} {base.get(p, {}).get(k, 0)} -> {v}")
    print("Style (docs/STYLE.md): " + ", ".join(f"{k} {v}" for k, v in totals.items()))
    if worse:
        print("STYLE FAIL: files got worse than tools/style_baseline.json:")
        for w in worse[:30]:
            print("  " + w)
        print("  (run `python3 tools/style_lint.py --file <path>` for line numbers)")
        if "--strict" in args:
            sys.exit(1)
    else:
        print("STYLE OK")


if __name__ == "__main__":
    main()
