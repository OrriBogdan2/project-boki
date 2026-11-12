#!/usr/bin/env python3
"""Reformat old GDScript with gdformat a batch at a time, never a file an open branch is working on.

A one-shot reformat of the repo would conflict with every unmerged branch, so old files are cleaned in batches
that skip any file an unmerged ext/* branch with a commit in the last DAYS days touches ("busy" files).

Usage (from the repo root, with the lint venv that tools/check.sh sets up):
  ~/.cache/boki-lint/venv/bin/python tools/format_batch.py            format the next 50 free files
  ... tools/format_batch.py --size 30 --days 2                        smaller batch, shorter window
  ... tools/format_batch.py --dry-run                                 only list the batch
  ... tools/format_batch.py --list godot-shadow                       a lint_baseline check's files, free or busy
Then run `tools/check.sh --update` (and `python3 tools/style_lint.py --update`) to lock the lower counts in.
"""

import json, os, subprocess, sys, time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LINE_LENGTH = 120  # same as tools/lint_gate.py


def git(*args):
    return subprocess.run(["git", *args], cwd=ROOT, capture_output=True, text=True).stdout


def busy_files(days):
    """Files that an unmerged ext/* branch with a commit in the last `days` days changes (against origin/main)."""
    git("fetch", "-q", "origin", "main", "+refs/heads/ext/*:refs/remotes/origin/ext/*")
    since = time.time() - days * 86400
    recent = [
        line.split()[0]
        for line in git(
            "for-each-ref", "--format=%(refname) %(committerdate:unix)", "refs/remotes/origin/ext"
        ).splitlines()
        if int(line.split()[1]) >= since
    ]
    merged = set(
        git("for-each-ref", "--merged", "origin/main", "--format=%(refname)", "refs/remotes/origin/ext").split()
    )
    busy = set()
    for ref in recent:
        if ref not in merged:
            busy.update(git("diff", "--name-only", f"origin/main...{ref}").split())
    return busy


def main():
    args = sys.argv[1:]

    def opt(name, default):
        return type(default)(args[args.index(name) + 1]) if name in args else default

    days, size = opt("--days", 3), opt("--size", 50)
    baseline = json.load(open(os.path.join(ROOT, "tools", "lint_baseline.json"), encoding="utf-8"))
    busy = busy_files(days)
    if "--list" in args:
        check = opt("--list", "")
        for p, n in sorted(baseline[check].items()):
            print(f"{'busy' if p in busy else 'free'} {n:3d} {p}")
        return
    batch = [p for p in sorted(baseline["gdformat"]) if p not in busy][:size]
    print(f"{len(batch)} files to format ({len(busy)} files busy on unmerged branches of the last {days} days)")
    if "--dry-run" in args or not batch:
        print("\n".join(batch))
        return
    gdformat = os.path.join(os.path.dirname(sys.executable), "gdformat")
    # gdformat's own safety check refuses a file whose code would change; those stay in the baseline
    subprocess.run([gdformat, "--line-length", str(LINE_LENGTH), *batch], cwd=ROOT)


main()
