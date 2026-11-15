"""regate_carry: skip-regate helpers for regate-bot (stdlib only, no LLM, no worktree, no godot).

carry_check(head, gated, main)   a stale GATE GREEN PR whose merge with main cannot change any check's result:
                                 `git merge-tree` is clean, the PR's files and main's files since the green do not overlap,
                                 and suite_speed `select` (the engine's own file->check map) picks ZERO checks for main's
                                 delta. Then regate-run would only import + export, so the bot pushes the merge commit
                                 and posts "GATE GREEN <sha> (carried, no overlap)" itself.
cache_get/cache_put              suite verdict per (candidate tree, main tree): an identical pair never runs twice.
                                 ~/cj/regate-bot/cache/<key>.json; GREEN only (a RED may be a flake, it is re-gated).
train_plan(rows, main)           3+ stale PRs: one chain of merge commits (each merged into the previous tip); one gate of
                                 the tip tree covers all of them (see regate-bot, REGATE_TRAIN=1).
"""

import hashlib
import json
import os
import subprocess
import sys
from pathlib import Path

from regate_common import REPO, STATE_DIR, git, now, run

SUITE_SPEED = next((p for p in (os.environ.get("SUITE_SPEED", ""), str(Path(__file__).resolve().parent / "suite_speed.py"),
                                "/home/boki/coord/boki-tools/suite-speed/suite_speed.py", "/home/boki/coord/boki-tools/suite_speed.py")
                    if p and Path(p).is_file()), "")
CACHE = STATE_DIR / "cache"
ENV = {**os.environ, "GIT_AUTHOR_NAME": "regate-bot", "GIT_COMMITTER_NAME": "regate-bot",
       "GIT_AUTHOR_EMAIL": "regate-bot@localhost", "GIT_COMMITTER_EMAIL": "regate-bot@localhost"}


def merge_tree(a, b):
    """Tree of `a` merged with `b` when git merges it cleanly, else None (a conflict is regate-run's job)."""
    rc, out, _ = run(["git", "-C", REPO, "merge-tree", "--write-tree", a, b])
    return out.split()[0] if rc == 0 and out.strip() else None


def commit_merge(tree, first, second, msg):
    """Merge commit with `tree`, first parent = the PR side (like regate-run), -> sha or None."""
    rc, out, _ = run(["git", "-C", REPO, "commit-tree", tree, "-p", first, "-p", second, "-m", msg], env=ENV)
    return out.strip() if rc == 0 else None


def files(a, b):
    out = git("diff", "--name-only", a, b)
    return set(out.split("\n")) - {""} if out is not None else None


def selected(gated, commit):
    """suite_speed select on the merge commit vs the green: [] = no check reads anything main changed, else flags/ALL/None."""
    if not SUITE_SPEED:
        return None
    rc, out, err = run([sys.executable, "-I", SUITE_SPEED, "select", REPO, gated, commit], timeout=300)
    first = (out + err).strip().split("\n")[0] if rc == 0 else ""
    return [] if first.startswith("[]") else None


def carry_check(head, gated, main):
    """-> (ok, why, merge commit or None). Every doubt answers no (the PR is then re-gated as before)."""
    tree = merge_tree(head, main)
    if not tree:
        return False, "merge-tree conflicts", None
    base = git("merge-base", gated, main)
    pr, mn = (files(base, gated), files(base, main)) if base else (None, None)
    if pr is None or mn is None:
        return False, "cannot diff against the gated sha", None
    both = pr & mn
    if both:
        return False, f"{len(both)} files changed by both (e.g. {sorted(both)[0]})", None
    commit = commit_merge(tree, head, main, f"Merge origin/main {main[:10]} into PR (regate-bot, carried)")
    if not commit:
        return False, "commit-tree failed", None
    if selected(gated, commit) != []:
        return False, f"main's {len(mn)} new files feed a check", None
    return True, f"no overlap ({len(pr)} PR files, {len(mn)} main files, 0 checks selected)", commit


# ---- suite result cache
def cache_key(cand_tree, main_tree):
    return hashlib.sha256(f"{cand_tree} {main_tree}".encode()).hexdigest()[:24]


def keys_for(head, main):
    """(candidate tree, main tree) of the merge of head with main; head already holding main -> its own tree. None if unclean."""
    from regate_common import is_ancestor
    ct = git("rev-parse", f"{head}^{{tree}}") if is_ancestor(main, head) else merge_tree(head, main)
    mt = git("rev-parse", f"{main}^{{tree}}")
    return (ct, mt) if ct and mt else None


def cache_get(ct, mt):
    p = CACHE / f"{cache_key(ct, mt)}.json"
    try:
        return json.loads(p.read_text())
    except (OSError, ValueError):
        return None


def cache_put(ct, mt, result, **info):
    if result != "GREEN":
        return
    CACHE.mkdir(parents=True, exist_ok=True)
    (CACHE / f"{cache_key(ct, mt)}.json").write_text(json.dumps(dict(result=result, cand=ct, main=mt, at=now(), **info)))


# ---- train
def train_plan(rows, main):
    """Chain the rows (dicts with pr, branch, head) over main: -> [(row, chain commit, tree after this member)] for the longest
    prefix that merges cleanly (a PR that conflicts with the train so far is left out, it gates alone). Chain commit i has
    parents (head_i, previous chain commit or main)."""
    out, tip = [], main
    for r in rows:
        tree = merge_tree(r["head"], tip)
        c = tree and commit_merge(tree, r["head"], tip, f"Merge train: PR #{r['pr']} onto {tip[:10]} (regate-bot)")
        if not c:
            continue
        out.append((r, c, tree))
        tip = c
    return out
