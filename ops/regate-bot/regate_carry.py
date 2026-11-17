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
import re
import subprocess
import sys
import tempfile
from pathlib import Path

from regate_common import REPO, STATE_DIR, git, is_ancestor, now, run

SUITE_SPEED = next((p for p in (os.environ.get("SUITE_SPEED", ""), str(Path(__file__).resolve().parent / "suite_speed.py"),
                                "/home/boki/coord/boki-tools/suite-speed/suite_speed.py", "/home/boki/coord/boki-tools/suite_speed.py")
                    if p and Path(p).is_file()), "")
CACHE = STATE_DIR / "cache"
# suite_speed's INERT (files no check reads); kept in sync by hand, test_regate_carry checks it against the engine copy
INERT = re.compile(r"^(docs|briefs|ops|\.github|blender|art_src)/|\.(md|txt|import|uid)$|^[^/]+\.md$|^export_presets\.cfg$")
LAST = {}  # carry_check's last X (checks that see main's delta), for replay's old-rule column
ENV = {**os.environ, "GIT_AUTHOR_NAME": "regate-bot", "GIT_COMMITTER_NAME": "regate-bot",
       "GIT_AUTHOR_EMAIL": "regate-bot@localhost", "GIT_COMMITTER_EMAIL": "regate-bot@localhost"}


def merge_tree(a, b):
    """Tree of `a` merged with `b` when git merges it cleanly, else None (a conflict is regate-run's job).
    11-15: git < 2.38 (rpc6 has 2.34) has no `merge-tree --write-tree`; it failed as "conflicts", so carry/cache/train never
    fired there. Fallback: a 3-way read-tree in a scratch index; any path changed on both sides stays unmerged -> None."""
    rc, out, err = run(["git", "-C", REPO, "merge-tree", "--write-tree", a, b])
    if rc == 0 and out.strip():
        return out.split()[0]
    if "write-tree" not in err and "usage" not in err:
        return None  # a real conflict on a git that has --write-tree
    bases = (git("merge-base", "--all", a, b) or "").split()
    if len(bases) != 1:
        return None
    with tempfile.TemporaryDirectory() as d:
        env = {**os.environ, "GIT_INDEX_FILE": str(Path(d) / "index")}
        if run(["git", "-C", REPO, "read-tree", "-i", "-m", "--aggressive", bases[0], a, b], env=env)[0]:
            return None
        if not merge_unmerged(env, Path(d)):
            return None
        rc, out, _ = run(["git", "-C", REPO, "write-tree"], env=env)
    return out.strip() if rc == 0 and out.strip() else None


def merge_unmerged(env, tmp):
    """Content-merge each path left unmerged in the scratch index (changed on both sides) with `git merge-file`; a path
    without all 3 stages (add/delete, rename) or with a real conflict -> False."""
    rc, out, _ = run(["git", "-C", REPO, "ls-files", "-u", "-z"], env=env)
    if rc:
        return False
    stages = {}
    for ent in filter(None, out.split("\0")):
        meta, path = ent.split("\t", 1)
        mode, sha, st = meta.split()
        stages.setdefault(path, {})[st] = (mode, sha)
    for path, sv in stages.items():
        if set(sv) != {"1", "2", "3"} or len({m for m, _ in sv.values()}) != 1:
            return False
        fs = []
        for st in "213":
            f = tmp / f"s{st}"
            f.write_bytes(subprocess.run(["git", "-C", REPO, "cat-file", "blob", sv[st][1]], capture_output=True).stdout)
            fs.append(str(f))
        if run(["git", "-C", REPO, "merge-file", "-q", *fs])[0]:  # merges into fs[0] (ours); rc != 0 = conflicts
            return False
        rc, sha, _ = run(["git", "-C", REPO, "hash-object", "-w", fs[0]])
        if rc or run(["git", "-C", REPO, "update-index", "--force-remove", "--", path], env=env)[0] or \
                run(["git", "-C", REPO, "update-index", "--add", "--cacheinfo", f"{sv['2'][0]},{sha.strip()},{path}"], env=env)[0]:
            return False
    return True


def commit_merge(tree, first, second, msg):
    """Merge commit with `tree`, first parent = the PR side (like regate-run), -> sha or None."""
    rc, out, _ = run(["git", "-C", REPO, "commit-tree", tree, "-p", first, "-p", second, "-m", msg], env=ENV)
    return out.strip() if rc == 0 else None


def commit_merge1(tree, parent):
    rc, out, _ = run(["git", "-C", REPO, "commit-tree", tree, "-p", parent, "-m", "regate-bot tree diff"], env=ENV)
    return out.strip() if rc == 0 else None


def files(a, b):
    out = git("diff", "--name-only", a, b)
    return set(out.split("\n")) - {""} if out is not None else None


def selected(old, commit):
    """suite_speed select on `commit` vs `old` (dep graph read at commit): -> list of check flags whose inputs changed,
    [] = none, None = ALL (shared file / untied game file / no engine / error)."""
    if not SUITE_SPEED:
        return None
    if not is_ancestor(old, commit):
        # select diffs old...commit (from their merge-base); for a train member (old = train tip, not an ancestor) that
        # would miss files only the tip has. Re-parent commit's tree onto old so the diff is the plain tree diff.
        commit = commit_merge1(git("rev-parse", f"{commit}^{{tree}}"), old)
        if not commit:
            return None
    rc, out, err = run([sys.executable, "-I", SUITE_SPEED, "select", REPO, old, commit], timeout=300)
    lines = [ln.strip() for ln in out.strip().split("\n") if ln.strip()] if rc == 0 else []
    if not lines or not lines[0].startswith("#") or "ALL" in lines[1:]:
        return None
    return lines[1:]


def carry_check(head, gated, main):
    """-> (ok, why, merge commit or None). Every doubt answers no (the PR is then re-gated as before).
    Rule (11-15, per check): X = checks whose inputs changed between the green (gated) and the merge commit, Y = checks
    whose inputs differ between current main and the merge commit. A check outside X reads exactly what it read when the
    PR went GREEN; a check outside Y reads exactly what main reads (so it cannot be a NEW-RED vs main). X and Y disjoint
    -> every check's verdict is already known -> carried. (11-14 rule was X == [], which main's ~90 commits/h almost
    always broke.) Engine = suite_speed select, the same file->check map the merge-candidate gate trusts."""
    base = git("merge-base", gated, main)
    pr, mn = (files(base, gated), files(base, main)) if base else (None, None)
    if pr is None or mn is None:
        return False, "cannot diff against the gated sha", None
    both = {f for f in pr & mn if not INERT.search(f)}  # 11-15: docs/briefs/.md edited on both sides feed no check
    if both:
        return False, f"{len(both)} files changed by both (e.g. {sorted(both)[0]})", None
    tree = merge_tree(head, main)
    if not tree:
        return False, "merge-tree conflicts", None
    commit = commit_merge(tree, head, main, f"Merge origin/main {main[:10]} into PR (regate-bot, carried)")
    if not commit:
        return False, "commit-tree failed", None
    x = selected(gated, commit)
    LAST["x"] = x
    if x is None:
        return False, "main's delta feeds ALL checks (shared or untied file)", None
    y = selected(main, commit) if x else []
    if y is None:
        return False, "the PR's delta feeds ALL checks", None
    hit = sorted(set(x) & set(y))
    if hit:
        return False, f"{len(hit)} checks read both sides (e.g. {hit[0]})", None
    return True, f"no overlap ({len(pr)} PR files, {len(mn)} main files; {len(x)} checks see main, {len(y)} see the PR, 0 both)", commit


# ---- suite result cache
def cache_key(cand_tree, main_tree):
    return hashlib.sha256(f"{cand_tree} {main_tree}".encode()).hexdigest()[:24]


def keys_for(head, main):
    """(candidate tree, main tree) of the merge of head with main; head already holding main -> its own tree. None if unclean."""
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


# ---- replay: what carry + cache would have saved on past regate-run runs (no pushes, no posts)
def replay(runs_dir):
    rows, seen = [], {}
    pat = re.compile(r"PR #(\d+) (\S+) (\w+) \(gated (\w+)\) \+ main (\w+)")
    for d in sorted(Path(runs_dir).glob("pr*"), key=lambda d: d.name.rsplit("-", 1)[-1]):
        if not d.is_dir() or not (d / "run.log").is_file():
            continue
        log = (d / "run.log").read_text(errors="replace")
        m = pat.search(log)
        if not m:
            continue
        n, br, head, gated, main = m.groups()
        res = (re.search(r"result: ([A-Z]+)", log) or [None, "none"])[1]
        mins = float((re.search(r"result: \w+(?: \w+)? \((\d+) min\)", log) or re.search(r"wall ([\d.]+) min", log) or [0, 0])[1])
        head, gated, main = (git("rev-parse", "--verify", "-q", f"{x}^{{commit}}") for x in (head, gated, main))
        if not (head and gated and main):
            rows.append(dict(run=d.name, pr=n, res=res, mins=mins, why="sha not in repo"))
            continue
        r = dict(run=d.name, pr=n, res=res, mins=mins, stale=gated != main)
        keys = keys_for(head, main)
        r["cache"] = bool(keys) and keys in seen.values()
        if keys and res == "GREEN":
            seen[d.name] = keys
        if r["stale"]:
            LAST.clear()
            ok, why, _ = carry_check(head, gated, main)
            r.update(new=ok, old=ok and LAST.get("x") == [], why=why)
        else:
            r.update(new=False, old=False, why="first gate (never green)")
        rows.append(r)
    return rows


if __name__ == "__main__":
    import argparse
    ap = argparse.ArgumentParser()
    ap.add_argument("cmd", choices=["replay"])
    ap.add_argument("--runs", default=str(STATE_DIR / "runs"))
    a = ap.parse_args()
    rows = replay(a.runs)
    for r in rows:
        tag = "CARRY" if r.get("new") else ("CACHE" if r.get("cache") else "-")
        print(f"{r['run'][:28]:28} {r['res']:8} {r['mins']:4.0f}m old={'Y' if r.get('old') else 'n'} new={tag:5} {r['why'][:90]}")
    saved = [r for r in rows if r.get("new") or r.get("cache")]
    wrong = [r for r in saved if r["res"] == "RED"]
    print(f"replay: {len(rows)} runs, stale {sum(1 for r in rows if r.get('stale'))}, old rule carries "
          f"{sum(1 for r in rows if r.get('old'))}, new rule carries {sum(1 for r in rows if r.get('new'))}, cache hits "
          f"{sum(1 for r in rows if r.get('cache'))}; saved {len(saved)} runs / {sum(r['mins'] for r in saved):.0f} wall-min; "
          f"carried-but-RED {len(wrong)} {' '.join(r['run'] for r in wrong)}")
