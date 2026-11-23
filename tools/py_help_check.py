#!/usr/bin/env python3
"""Checks that every Python tool with a command line answers `--help` without error.

A tool counts when it uses argparse and does not import bpy at module level (Blender-only scripts cannot start
outside Blender). A tool whose only failure is a missing third-party package (numpy, scipy, ...) is reported as
skipped, not failed. Prints one line per tool and exits 1 when any tool fails.

  python3 tools/py_help_check.py            check every tracked tool under tools/ and server/
  python3 tools/py_help_check.py --list     only list the tools that would be checked
"""
import argparse
import ast
import os
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TIMEOUT_S = 30  # one --help must answer in well under this; a tool that works at import time hits it


def tracked_python():
    out = subprocess.run(["git", "ls-files", "tools", "server", "*.py"], cwd=ROOT, capture_output=True, text=True, check=True).stdout
    return sorted(p for p in out.split() if p.endswith(".py") and not os.path.basename(p).startswith("test_"))


def imports_bpy(tree):
    for node in tree.body:
        if isinstance(node, ast.Import) and any(a.name.split(".")[0] == "bpy" for a in node.names):
            return True
        if isinstance(node, ast.ImportFrom) and (node.module or "").split(".")[0] == "bpy":
            return True
    return False


def has_cli(path):
    src = open(os.path.join(ROOT, path), encoding="utf-8").read()
    if "argparse" not in src:
        return False
    return not imports_bpy(ast.parse(src))


def check(path):
    """Return "ok", "skip: <package>" or "FAIL: <why>"."""
    try:
        r = subprocess.run([sys.executable, path, "--help"], cwd=ROOT, capture_output=True, text=True, timeout=TIMEOUT_S)
    except subprocess.TimeoutExpired:
        return "FAIL: --help took over %d s" % TIMEOUT_S
    if r.returncode == 0 and r.stdout.strip():
        return "ok"
    last = (r.stderr.strip().splitlines() or ["no output"])[-1]
    if "ModuleNotFoundError" in last:
        return "skip: " + last.split("'")[1]
    return "FAIL: " + last[:120]


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--list", action="store_true", help="only list the tools that would be checked")
    args = ap.parse_args()
    tools = [p for p in tracked_python() if has_cli(p)]
    if args.list:
        print("\n".join(tools))
        return
    bad = 0
    for p in tools:
        res = check(p)
        bad += res.startswith("FAIL")
        print("%-5s %s" % (res.split(":")[0].upper(), p) + ("" if res == "ok" else "  " + res))
    print("PYHELP %s: %d tools, %d failed" % ("FAIL" if bad else "OK", len(tools), bad))
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()
