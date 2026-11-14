#!/usr/bin/env python3
"""stale_triage.py PR [PR ...]: evidence for "already in main / superseded / still needed" per open PR.

The PR's own change is `git diff merge-base head`. Per file, that change is tried on a scratch index of origin/main:
  in-main  the reverse patch applies, so main already holds the change (or its equivalent)
  conflict a real three-way merge (read-tree -m, then merge-file per path; binary files conflict) of main and the head
           leaves the file unmerged: main edited it too (rebase cost)
  clean    the rest
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


def in_main(patch: str, env: dict) -> bool:
    return git("apply", "--cached", "--check", "-R", env=env, stdin=patch).returncode == 0


def conflicts(base: str, main: str, head: str, tmp: str) -> set[str]:
    """Paths a merge of head into main cannot resolve by itself."""
    env = {**os.environ, "GIT_INDEX_FILE": os.path.join(tmp, "merge-idx")}
    git("read-tree", "-m", "--aggressive", base, main, head, env=env)
    bad = set()
    for line in git("ls-files", "-u", env=env).stdout.splitlines():
        bad.add(line.split("\t", 1)[1])
    out = set()
    for path in bad:
        found = [git("rev-parse", "--verify", "-q", f"{r}:{path}") for r in (main, base, head)]
        if any(r.returncode for r in found):
            out.add(path)  # added or deleted on one side
            continue
        blobs = [r.stdout.strip() for r in found]
        files = []
        for i, b in enumerate(blobs):
            f = os.path.join(tmp, f"blob{i}")
            with open(f, "wb") as fh:
                fh.write(subprocess.run(["git", "cat-file", "blob", b], capture_output=True).stdout)
            files.append(f)
        if subprocess.run(["git", "merge-file", "-p", *files], capture_output=True).returncode != 0:
            out.add(path)
    return out


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


def triage(n: str, main: str, env: dict, tmp: str) -> list[str]:
    head = git("rev-parse", f"pr/{n}").stdout.strip()
    base = git("merge-base", main, head).stdout.strip()
    patches = per_file(git("diff", "--binary", base, head).stdout)
    bad_files = conflicts(base, main, head, tmp)
    kinds = {f: "in-main" if in_main(p, env) else "conflict" if f in bad_files else "clean" for f, p in patches.items()}
    count = {k: sum(v == k for v in kinds.values()) for k in ("in-main", "clean", "conflict")}
    bad = ",".join(sorted(bad_files)[:4])
    found, total = surviving_lines(patches, main)
    own = git("rev-list", "--no-merges", "--count", f"{main}..{head}").stdout.strip()
    behind = git("rev-list", "--count", f"{head}..{main}").stdout.strip()
    date = git("log", "-1", "--format=%cs", head).stdout.strip()
    return [f"#{n}", date, f"{own} own", f"{len(kinds)} files", f"in-main {count['in-main']}",
            f"clean {count['clean']}", f"lines {found}/{total}", f"conflict {len(bad_files)}:{bad}", f"behind {behind}"]


def main() -> None:
    main_rev = git("rev-parse", "origin/main").stdout.strip()
    with tempfile.TemporaryDirectory() as tmp:
        env = {**os.environ, "GIT_INDEX_FILE": os.path.join(tmp, "idx")}
        git("read-tree", main_rev, env=env)
        for n in sys.argv[1:]:
            print("\t".join(triage(n, main_rev, env, tmp)), flush=True)


if __name__ == "__main__":
    main()
