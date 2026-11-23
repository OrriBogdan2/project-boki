#!/usr/bin/env python3
"""Reconstructed merge gap (merge rush 11-13) for workers without hetzner's `merge-gap`.

Counts READY branches (EXT_TO_MAIN.md + its archive on ext/agent-briefs) that are live on origin and whose
head is not in origin/main. A branch whose head carries an `archive/<name>` tag (any suffix) does not count:
that is the hetzner tool bug (it counted already archived branches).

Usage: merge_gap.py [--list] [--archived]   (run inside a clone with origin fetched)
"""

import re
import subprocess
import sys

READY = re.compile(r"^READY (ext/[\w./-]+) ([0-9a-f]{7,40})")
BRIEFS = "origin/ext/agent-briefs"


def git(*args: str, stdin: str | None = None) -> str:
    return subprocess.run(["git", *args], input=stdin, capture_output=True, text=True, check=False).stdout


def ready_branches() -> set[str]:
    names = git("ls-tree", "-r", "--name-only", BRIEFS, "briefs/").split()
    logs = [n for n in names if n.endswith("EXT_TO_MAIN.md") or "EXT_TO_MAIN-" in n]
    found = set()
    for path in logs:
        for line in git("show", f"{BRIEFS}:{path}").splitlines():
            match = READY.match(line)
            if match:
                found.add(match.group(1).removeprefix("ext/"))
    found.discard("agent-briefs")
    return found


def remote_refs() -> tuple[dict[str, str], set[str]]:
    heads, archived = {}, set()
    for line in git("ls-remote", "origin", "refs/heads/ext/*", "refs/tags/archive/*").splitlines():
        sha, ref = line.split("\t")
        if ref.startswith("refs/heads/ext/"):
            heads[ref.removeprefix("refs/heads/ext/")] = sha
        else:  # the tag object and its peeled ^{} commit
            archived.add(sha)
    return heads, archived


def main() -> None:
    heads, archived_shas = remote_refs()
    live = {b: heads[b] for b in ready_branches() if b in heads}
    shas = sorted(set(live.values()))
    git("fetch", "-q", "origin", "main")
    unmerged = set()
    for sha in shas:
        if subprocess.run(["git", "merge-base", "--is-ancestor", sha, "origin/main"], capture_output=True).returncode:
            unmerged.add(sha)
    gap = sorted(b for b, s in live.items() if s in unmerged and s not in archived_shas)
    tagged = sorted(b for b, s in live.items() if s in unmerged and s in archived_shas)
    print(f"merge gap {len(gap)} (live unmerged READY {len(gap) + len(tagged)}, archive-tagged at head {len(tagged)})")
    if "--list" in sys.argv:
        print("\n".join(gap))
    if "--archived" in sys.argv:
        print("\n".join(tagged))


if __name__ == "__main__":
    main()
