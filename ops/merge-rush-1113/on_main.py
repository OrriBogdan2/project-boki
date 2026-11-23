#!/usr/bin/env python3
"""on_main.py LIST : per "ext/<b> <sha>" line, how much of the branch is already on origin/main.

Prints "<b> <sha> touched=<n> same=<k> left=<files>": touched = files the branch changed since its merge base with
main, same = those whose blob on main equals the branch's (or both deleted). "left" lists the rest, docs/ and
.import files excluded, since those are regenerated or only describe the change.
"""

import subprocess
import sys


def git(*args: str) -> str:
    return subprocess.run(["git", *args], capture_output=True, text=True, check=False).stdout


def blobs(rev: str, paths: list[str]) -> dict[str, str]:
    out = {}
    for i in range(0, len(paths), 500):
        for line in git("ls-tree", rev, "--", *paths[i : i + 500]).splitlines():
            meta, path = line.split("\t", 1)
            out[path] = meta.split()[2]
    return out


def main() -> None:
    for line in open(sys.argv[1]):
        name, sha = line.split()[:2]
        base = git("merge-base", "origin/main", sha).strip()
        touched = git("diff", "--name-only", "--no-renames", base, sha).split("\n")
        touched = [t for t in touched if t]
        ours, theirs = blobs("origin/main", touched), blobs(sha, touched)
        left = [t for t in touched if ours.get(t) != theirs.get(t)]
        real = [t for t in left if not t.startswith("docs/") and not t.endswith(".import")]
        print(f"{name} {sha} touched={len(touched)} same={len(touched) - len(left)} left={','.join(real[:8])}")


if __name__ == "__main__":
    main()
