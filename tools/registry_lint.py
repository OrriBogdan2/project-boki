#!/usr/bin/env python3
"""Check-registry lint (AGENTS.md section 2): the legacy tools/check_registry.gd only shrinks.

Usage: python3 tools/registry_lint.py [BASE]     BASE defaults to origin/main (skipped when it is not there)
Fails when
  - the branch adds a flag to the CHECKS dict of tools/check_registry.gd that BASE does not have (new checks go in
    tools/checks/<area>.gd; removals are fine), or
  - a flag is listed twice across check_registry.gd and tools/checks/*.gd (CheckRegistry.all() would fail at startup).
Run by tools/health.py --strict.
"""

import glob, os, re, subprocess, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FLAG = re.compile(r'^\s*"(--?[A-Za-z0-9_=.-]+)"\s*:\s*\[', re.M)
REG = "tools/check_registry.gd"


def legacy_flags(src):
    """Flags in the const CHECKS := { ... } block of check_registry.gd."""
    m = re.search(r"^const CHECKS := \{\n(.*?)^\}", src, re.M | re.S)
    return FLAG.findall(m.group(1)) if m else []


def main():
    base = sys.argv[1] if len(sys.argv) > 1 else "origin/main"
    bad = []
    here = open(os.path.join(ROOT, REG), encoding="utf-8").read()
    seen = {f: REG for f in legacy_flags(here)}
    for path in sorted(glob.glob(os.path.join(ROOT, "tools", "checks", "*.gd"))):
        rel = os.path.relpath(path, ROOT)
        for f in FLAG.findall(open(path, encoding="utf-8").read()):
            if f in seen:
                bad.append(f"{f} is in both {seen[f]} and {rel}")
            seen[f] = rel
    old = subprocess.run(["git", "show", f"{base}:{REG}"], cwd=ROOT, capture_output=True, text=True)
    if old.returncode == 0:
        added = sorted(set(legacy_flags(here)) - set(legacy_flags(old.stdout)))
        bad += [f"{f}: new entry in {REG} (put it in tools/checks/<area>.gd)" for f in added]
        note = f"vs {base}"
    else:
        note = f"{base} not found, only duplicates checked"
    if bad:
        print("REGISTRY FAIL: " + "; ".join(bad))
        print("New checks go in tools/checks/<area>.gd (AGENTS.md section 2); tools/check_registry.gd only shrinks.")
        sys.exit(1)
    print(f"REGISTRY OK: {len(seen)} flags, none added to {REG} ({note})")


if __name__ == "__main__":
    main()
