#!/usr/bin/env python3
"""Codebase health report for Project Boki (see AGENTS.md).

Usage: python3 tools/health.py [--strict]
Prints file sizes, god-file budgets, duplicate content folders, dynamic calls, checks registered inline
in main.gd, and docs/DEBT.md entries. Exit code 1 only when --strict and a god-file budget is exceeded
(ship.sh runs it in strict mode so god files can't grow). Budgets ratchet: lower them as files get split.
"""
import os, re, subprocess, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
# god files: current size is the ceiling (plus a little slack for wiring); lower these as refactors land
BUDGETS = {
    "scripts/match/match.gd": 6950,
    "scripts/home/home.gd": 5950,
    "scripts/main.gd": 4100,
    "scripts/ui/hud.gd": 3850,
    "scripts/match/models.gd": 3500,
    "scripts/match/hunter.gd": 3500,
    "scripts/match/world.gd": 2850,
}
SOFT_FILE = 800      # lines: a new file above this is flagged
SOFT_FUNC = 60       # lines: functions above this are counted

def lines(p):
    with open(os.path.join(ROOT, p), encoding="utf-8", errors="ignore") as f:
        return f.read().split("\n")

def gd_files():
    out = []
    for base in ("scripts", "tools"):
        for d, _, fs in os.walk(os.path.join(ROOT, base)):
            for f in fs:
                if f.endswith(".gd"):
                    out.append(os.path.relpath(os.path.join(d, f), ROOT))
    return sorted(out)

def long_funcs(src):
    n, start, name = 0, None, None
    for i, l in enumerate(src + ["func __end__():"]):
        if re.match(r"^(static )?func ", l):
            if start is not None and i - start > SOFT_FUNC:
                n += 1
            start = i
    return n

def main():
    strict = "--strict" in sys.argv
    bad = []
    files = gd_files()
    total = 0
    big = []
    funcs_over = 0
    dyn = 0
    for p in files:
        src = lines(p)
        total += len(src)
        funcs_over += long_funcs(src)
        dyn += sum(1 for l in src if re.search(r"has_method\(|get_script_method_list|\.call\(\"", l))
        if len(src) > SOFT_FILE and p not in BUDGETS:
            big.append((len(src), p))
    print("== Project Boki health ==")
    print(f"GDScript: {len(files)} files, {total} lines; functions over {SOFT_FUNC} lines: {funcs_over}; dynamic calls: {dyn}")
    print("God files (budget = max allowed lines):")
    for p, cap in BUDGETS.items():
        n = len(lines(p)) if os.path.exists(os.path.join(ROOT, p)) else 0
        flag = "OVER BUDGET" if n > cap else "ok"
        print(f"  {p}: {n} / {cap}  {flag}")
        if n > cap:
            bad.append(p)
    print(f"Other files over {SOFT_FILE} lines (split candidates):")
    for n, p in sorted(big, reverse=True)[:12]:
        print(f"  {p}: {n}")
    c = os.path.join(ROOT, "content")
    dups = [d for d in sorted(os.listdir(c)) if d.endswith("_v2") and os.path.isdir(os.path.join(c, d[:-3]))]
    print("Duplicate content versions (migrate + delete the old one):", ", ".join(f"{d[:-3]} + {d}" for d in dups) or "none")
    inline = len(re.findall(r'"--[a-z0-9-]+-check"', "\n".join(lines("scripts/main.gd"))))
    print(f"Checks hooked inline in main.gd: {inline} (target: a registry in tools/)")
    debt = os.path.join(ROOT, "docs", "DEBT.md")
    if os.path.exists(debt):
        n = sum(1 for l in open(debt, encoding="utf-8") if l.startswith("- "))
        print(f"Known debt entries (docs/DEBT.md): {n}")
    style = subprocess.run([sys.executable, os.path.join(ROOT, "tools", "style_lint.py")], capture_output=True, text=True).stdout
    print(style.rstrip())
    if "STYLE FAIL" in style:
        bad.append("style ratchet (docs/STYLE.md)")
    if bad:
        print("HEALTH FAIL: " + ", ".join(bad) + " (god files: move new logic into a focused module, see AGENTS.md; style: see docs/STYLE.md)")
        if strict:
            sys.exit(1)
    else:
        print("HEALTH OK")

if __name__ == "__main__":
    main()
