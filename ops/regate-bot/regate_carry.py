"""regate_carry: skip-regate helpers for regate-bot (stdlib only, no LLM, no worktree, no godot).

carry_check(head, gated, main)   a stale GATE GREEN PR whose merge with main cannot change any check's result:
                                 `git merge-tree` is clean, the PR's files and main's files since the green do not overlap,
                                 and suite_speed `select` (the engine's own file->check map) picks ZERO checks for main's
                                 delta. Then regate-run would only import + export, so the bot pushes the merge commit
                                 and posts "GATE GREEN <sha> (carried, no overlap)" itself.
                                 11-23 loose rule: when the per-check rule cannot prove it (ALL / checks read both sides) the
                                 PR is still carried if no file in its diff changed on main and the two code deltas are not
                                 coupled (coupled() = removed/changed defs or file names the other side's new lines use).
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

SUITE_SPEED = next(
    (
        p
        for p in (
            os.environ.get("SUITE_SPEED", ""),
            str(Path(__file__).resolve().parent / "suite_speed.py"),
            "/home/boki/coord/boki-tools/suite-speed/suite_speed.py",
            "/home/boki/coord/boki-tools/suite_speed.py",
        )
        if p and Path(p).is_file()
    ),
    "",
)
CACHE = STATE_DIR / "cache"
# suite_speed's INERT (files no check reads); kept in sync by hand, test_regate_carry checks it against the engine copy
INERT = re.compile(
    r"^(docs|briefs|ops|\.github|blender|art_src)/|\.(md|txt|import|uid)$|^[^/]+\.md$|^export_presets\.cfg$"
)
LAST = {}  # carry_check's last X (checks that see main's delta), for replay's old-rule column
ENV = {
    **os.environ,
    "GIT_AUTHOR_NAME": "regate-bot",
    "GIT_COMMITTER_NAME": "regate-bot",
    "GIT_AUTHOR_EMAIL": "regate-bot@localhost",
    "GIT_COMMITTER_EMAIL": "regate-bot@localhost",
}


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
            f.write_bytes(
                subprocess.run(["git", "-C", REPO, "cat-file", "blob", sv[st][1]], capture_output=True).stdout
            )
            fs.append(str(f))
        if run(["git", "-C", REPO, "merge-file", "-q", *fs])[0]:  # merges into fs[0] (ours); rc != 0 = conflicts
            return False
        rc, sha, _ = run(["git", "-C", REPO, "hash-object", "-w", fs[0]])
        if (
            rc
            or run(["git", "-C", REPO, "update-index", "--force-remove", "--", path], env=env)[0]
            or run(
                ["git", "-C", REPO, "update-index", "--add", "--cacheinfo", f"{sv['2'][0]},{sha.strip()},{path}"],
                env=env,
            )[0]
        ):
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


# 11-23 loose carry: a stale GREEN whose files are disjoint from main's delta is carried even when the per-check rule cannot
# prove it (main's delta feeds ALL checks, or a check reads both sides): 233 re-gates / 177 gate-h in 3 days re-tested a PR
# whose own files main never touched (focus-1122 BASELINE lane 1). Safety net = the coupling guard below (API/stem references
# across the two deltas). REGATE_CARRY_LOOSE=0 = off (strict per-check rule only).
LOOSE = os.environ.get("REGATE_CARRY_LOOSE", "1") != "0"
CODE_GLOBS = ("*.gd", "*.tscn", "*.tres", "*.gdshader")
# top-level defs only (no indent): a local `var out` inside a func is no API (11-23 replay: 'out', 'from', 'along' false hits)
DEF_RE = re.compile(r"^(?:@\w+(?:\([^)]*\))?\s+)*(?:static\s+)?(func|signal|const|var|enum|class_name|class)\s+(\w+)")
TOKEN_RE = re.compile(r"[A-Za-z]\w{2,}")
PATH_RE = re.compile(r"/(\w+)\.(?:gd|tscn|tres|gdshader)\b")
# registries of one-line entries ("--flag": [...]): both sides editing different keys is not an overlap
KEYED_REGISTRIES = ("tools/check_registry.gd",)
KEY_RE = re.compile(r'^\s*"([^"]+)"\s*:')


def _code(ln):
    """The line without its # comment (a # inside a string is kept)."""
    q = None
    for i, ch in enumerate(ln):
        if q:
            q = None if ch == q else q
        elif ch in "\"'":
            q = ch
        elif ch == "#":
            return ln[:i]
    return ln


def delta_symbols(a, b):
    """Code delta a..b -> dict(add=identifiers on added lines (comments left out), paths=file stems named by res:// paths
    on added lines, rem=names of top-level defs removed/changed, stems=stems of changed code files, cls=class_names
    added). Private (_x) names are left out."""
    out = git("diff", "-U0", "--no-color", "--no-ext-diff", "--no-renames", a, b, "--", *CODE_GLOBS, timeout=300)
    d = dict(add=set(), paths=set(), rem=set(), stems=set(), cls=set())
    if out is None:
        return None
    for ln in out.split("\n"):
        if ln.startswith("+++ ") or ln.startswith("--- "):
            if ln[4:] != "/dev/null":
                d["stems"].add(Path(ln[4:]).stem)
        elif ln[:1] == "+":
            d["add"].update(TOKEN_RE.findall(_code(ln[1:])))
            d["paths"].update(PATH_RE.findall(ln))
            m = DEF_RE.match(ln[1:])
            if m and m.group(1) == "class_name":
                d["cls"].add(m.group(2))
        elif ln[:1] == "-":
            m = DEF_RE.match(ln[1:])
            if m and not m.group(2).startswith("_"):
                d["rem"].add(m.group(2))
    return d


def coupled(base, gated, main):
    """-> (True, why) when the PR's code delta and main's code delta reference each other: one side removed/changed a
    top-level def whose name the other side's added code uses, or changed a file the other side's added lines load by
    path, or both added the same class_name."""
    pr, mn = delta_symbols(base, gated), delta_symbols(base, main)
    if pr is None or mn is None:
        return True, "cannot read the code deltas"
    for a, b, who in ((mn, pr, "main changed it, the PR uses it"), (pr, mn, "the PR changed it, main uses it")):
        hit = sorted((a["rem"] & b["add"]) | (a["stems"] & b["paths"]))
        if hit:
            return True, f"coupled: {hit[0]} ({who})"
    dup = sorted(pr["cls"] & mn["cls"])
    if dup:
        return True, f"coupled: class_name {dup[0]} added on both sides"
    return False, ""


def keys_disjoint(base, gated, main, f):
    """True when each side's edits to f (an KEYED_REGISTRIES registry) are entry lines or comments only and the two sides touch
    no common key (11-23 replay: moved/re-commented entries, not only appends)."""
    keys = []
    for tip in (gated, main):
        out = git("diff", "-U0", "--no-color", base, tip, "--", f)
        if out is None:
            return False
        ks = set()
        for ln in out.split("\n"):
            if ln[:1] not in "+-" or ln.startswith(("+++", "---")):
                continue
            body = ln[1:].strip()
            if not body or body.startswith("#"):
                continue
            m = KEY_RE.match(body)
            if not m:
                return False
            ks.add(m.group(1))
        keys.append(ks)
    return not (keys[0] & keys[1])


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
    if LOOSE:  # 11-23: two PRs each editing other check lines of the registry (40 of 177 same-head re-gates in 3 days)
        both = {f for f in both if f not in KEYED_REGISTRIES or not keys_disjoint(base, gated, main, f)}
    if both:
        return False, f"{len(both)} files changed by both (e.g. {sorted(both)[0]})", None
    tree = merge_tree(head, main)
    if not tree:
        return False, "merge-tree conflicts", None
    # head already holds main (a bulk rebase, a driver job): the head itself is the merge, no extra commit
    commit = (
        head
        if is_ancestor(main, head)
        else commit_merge(tree, head, main, f"Merge origin/main {main[:10]} into PR (regate-bot, carried)")
    )
    if not commit:
        return False, "commit-tree failed", None
    x = selected(gated, commit)
    LAST["x"] = x
    no = None
    if x is None:
        no = "main's delta feeds ALL checks (shared or untied file)"
    else:
        y = selected(main, commit) if x else []
        if y is None:
            no = "the PR's delta feeds ALL checks"
        else:
            hit = sorted(set(x) & set(y))
            if hit:
                no = f"{len(hit)} checks read both sides (e.g. {hit[0]})"
    if no is None:
        return (
            True,
            f"no overlap ({len(pr)} PR files, {len(mn)} main files; {len(x)} checks see main, {len(y)} see the PR, 0 both)",
            commit,
        )
    if LOOSE:
        bad, why = coupled(base, gated, main)
        if not bad:
            return (
                True,
                f"loose, no PR file changed on main ({len(pr)} PR files, {len(mn)} main files, code deltas not coupled; per-check rule said: {no})",
                commit,
            )
        no += "; " + why
    return False, no, None


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
    (CACHE / f"{cache_key(ct, mt)}.json").write_text(
        json.dumps(dict(result=result, cand=ct, main=mt, at=now(), **info))
    )


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
        mins = float(
            (re.search(r"result: \w+(?: \w+)? \((\d+) min\)", log) or re.search(r"wall ([\d.]+) min", log) or [0, 0])[1]
        )
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


def history(since, until, ref="origin/main"):
    """Replay from git alone (no bot logs needed): every regate-bot merge C reachable from ref in [since, until) is one
    re-gate; head = gated = C^1, main = C^2. same = C^1 is itself a regate-bot merge (the PR head surely did not change).
    Yields rows dict(c, same, strict, loose, why) one by one (a 3-day window is ~400 merges, ~1-3 s each)."""
    out = git("log", ref, f"--since={since}", f"--until={until}", "--grep=(regate-bot", "--format=%H %P|%s") or ""
    msg = dict((ln.split(" ", 1)[0], ln.split("|", 1)[1]) for ln in out.split("\n") if "|" in ln)
    for c, s in msg.items():
        if "carried" in s or "cached" in s:
            continue
        p1, p2 = (git("rev-parse", f"{c}^1"), git("rev-parse", f"{c}^2"))
        if not (p1 and p2):
            continue
        prev = git("log", "-1", "--format=%s", p1) or ""
        LAST.clear()
        ok, why, _ = carry_check(p1, p1, p2)
        yield dict(c=c, same="(regate-bot" in prev, loose=ok, strict=ok and not why.startswith("loose"), why=why)


if __name__ == "__main__":
    import argparse

    ap = argparse.ArgumentParser()
    ap.add_argument("cmd", choices=["replay", "history"])
    ap.add_argument("--runs", default=str(STATE_DIR / "runs"))
    ap.add_argument("--since", default="3 days ago")
    ap.add_argument("--until", default="now")
    a = ap.parse_args()
    if a.cmd == "history":
        rows = []
        for r in history(a.since, a.until):
            rows.append(r)
            print(
                f"{r['c'][:10]} same={'Y' if r['same'] else 'n'} strict={'Y' if r['strict'] else 'n'} "
                f"loose={'Y' if r['loose'] else 'n'} {r['why'][:100]}",
                flush=True,
            )
        for label, sub in (("all", rows), ("same-head", [r for r in rows if r["same"]])):
            n, st, lo = len(sub), sum(r["strict"] for r in sub), sum(r["loose"] for r in sub)
            print(f"history {label}: {n} re-gates, strict carries {st}, loose carries {lo}, left to run {n - lo}")
        sys.exit(0)
    rows = replay(a.runs)
    for r in rows:
        tag = "CARRY" if r.get("new") else ("CACHE" if r.get("cache") else "-")
        print(
            f"{r['run'][:28]:28} {r['res']:8} {r['mins']:4.0f}m old={'Y' if r.get('old') else 'n'} new={tag:5} {r['why'][:90]}"
        )
    saved = [r for r in rows if r.get("new") or r.get("cache")]
    wrong = [r for r in saved if r["res"] == "RED"]
    print(
        f"replay: {len(rows)} runs, stale {sum(1 for r in rows if r.get('stale'))}, old rule carries "
        f"{sum(1 for r in rows if r.get('old'))}, new rule carries {sum(1 for r in rows if r.get('new'))}, cache hits "
        f"{sum(1 for r in rows if r.get('cache'))}; saved {len(saved)} runs / {sum(r['mins'] for r in saved):.0f} wall-min; "
        f"carried-but-RED {len(wrong)} {' '.join(r['run'] for r in wrong)}"
    )
