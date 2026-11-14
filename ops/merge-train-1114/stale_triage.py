#!/usr/bin/env python3
"""stale_triage.py PR [PR ...]: evidence for "already in main / superseded / still needed" per open PR.

The PR's own change is `git diff merge-base head`. Per file, that change is tried on a scratch index of origin/main:
  in-main  the reverse patch applies, so main already holds the change (or its equivalent)
  clean    the patch applies forward, so a rebase of that file is free
  conflict neither: main edited the same lines (rebase cost)
"lines" is how many of the PR's added code lines (>= 20 chars) already sit, byte for byte, in the same file on main.
Needs the PR heads fetched as refs/remotes/pr/<n> and a git without merge-tree --write-tree (2.34 is fine).
Prints one tab-separated row per PR; the verdict column is left for the reader.
"""

import os
import re
import subprocess
import sys
import tempfile


def git(*args: str, env: dict | None = None, stdin: str | None = None) -> subprocess.CompletedProcess:
    return subprocess.run(["git", *args], input=stdin, capture_output=True, text=True, env=env)


def per_file(diff: str) -> dict[str, str]:
    parts = re.split(r"(?m)^(?=diff --git )", diff)
    return {re.match(r"diff --git a/(\S+)", p).group(1): p for p in parts if p.startswith("diff --git ")}


def classify(patch: str, env: dict) -> str:
    if git("apply", "--cached", "--check", "-R", env=env, stdin=patch).returncode == 0:
        return "in-main"
    if git("apply", "--cached", "--check", env=env, stdin=patch).returncode == 0:
        return "clean"
    return "conflict"


def surviving_lines(patches: dict[str, str], main: str) -> tuple[int, int]:
    found = total = 0
    for f, patch in patches.items():
        added = {ln[1:] for ln in patch.splitlines() if ln.startswith("+") and not ln.startswith("+++")}
        added = {ln for ln in added if len(ln.strip()) >= 20}
        if not added:
            continue
        on_main = set(git("show", f"{main}:{f}").stdout.splitlines())
        found += len(added & on_main)
        total += len(added)
    return found, total


def triage(n: str, main: str, env: dict) -> list[str]:
    head = git("rev-parse", f"pr/{n}").stdout.strip()
    base = git("merge-base", main, head).stdout.strip()
    patches = per_file(git("diff", "--binary", base, head).stdout)
    kinds = {f: classify(p, env) for f, p in patches.items()}
    count = {k: sum(v == k for v in kinds.values()) for k in ("in-main", "clean", "conflict")}
    bad = ",".join(sorted(f for f, v in kinds.items() if v == "conflict")[:4])
    found, total = surviving_lines(patches, main)
    own = git("rev-list", "--no-merges", "--count", f"{main}..{head}").stdout.strip()
    behind = git("rev-list", "--count", f"{head}..{main}").stdout.strip()
    date = git("log", "-1", "--format=%cs", head).stdout.strip()
    return [f"#{n}", date, f"{own} own", f"{len(kinds)} files", f"in-main {count['in-main']}",
            f"clean {count['clean']}", f"lines {found}/{total}", f"conflict {count['conflict']}:{bad}", f"behind {behind}"]


def main() -> None:
    main_rev = git("rev-parse", "origin/main").stdout.strip()
    with tempfile.TemporaryDirectory() as tmp:
        env = {**os.environ, "GIT_INDEX_FILE": os.path.join(tmp, "idx")}
        git("read-tree", main_rev, env=env)
        for n in sys.argv[1:]:
            print("\t".join(triage(n, main_rev, env)), flush=True)


if __name__ == "__main__":
    main()
