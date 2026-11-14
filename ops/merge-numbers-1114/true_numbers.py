#!/usr/bin/env python3
"""True merge numbers from git (merge-numbers-fix-1114).

Per UTC day: new READY branches, landed branches, waiting branches at day end.

A READY branch = a name in a `READY ext/<name> <sha>` line of briefs/EXT_TO_MAIN.md on ext/agent-briefs
(post date = git blame commit date of that line). It LANDED on the first main first-parent commit whose
ancestry contains ANY of: a READY sha of it, or its current origin tip. A branch counts once, not once per post.

Usage (in a clone with origin fetched, plus `git fetch origin 'refs/tags/archive/*:refs/tags/archive/*'`):
  true_numbers.py BLAME_PORCELAIN [--pre BLAME_BEFORE_GUTTING] [--days 7] [--json] [--content]   (--content: merge-tree + patch-id check of the waiting tips)
"""

import collections
import datetime as dt
import re
import subprocess
import sys

READY = re.compile(r"^READY (ext/[\w./-]+) ([0-9a-f]{7,40})")


def git(*a, stdin=None):
    return subprocess.run(["git", *a], input=stdin, capture_output=True, text=True, check=False).stdout


def day(ts):
    return dt.datetime.fromtimestamp(int(ts), dt.timezone.utc).date().isoformat()


RESTORE = "5d0edcd40e988915315736f746f927dc4ced967d"  # 11-09 17:19 restore after gutting: its lines are older


def ready_posts(blame_path, pre_path=None):
    """[(branch, sha, utc day)] from `git blame --line-porcelain`. Lines blamed to the 11-09 restore commit take their
    date from PRE_PATH (blame of the file just before the gutting, f2bbcb34f9^)."""
    pre = {}
    if pre_path:
        for b, s, d in ready_posts(pre_path):
            pre.setdefault((b, s), d)
    posts, ctime = [], {}
    cur = None
    for line in open(blame_path, encoding="utf-8", errors="replace"):
        if re.match(r"^[0-9a-f]{40} \d+ \d+", line):
            cur = line.split()[0]
        elif line.startswith("committer-time "):
            ctime[cur] = line.split()[1]
        elif line.startswith("\t"):
            m = READY.match(line[1:])
            if m and m.group(1) != "ext/agent-briefs":
                b, s = m.group(1)[4:], m.group(2)
                d = pre.get((b, s), day(ctime[cur])) if cur == RESTORE else day(ctime[cur])
                posts.append((b, s, d))
    return posts


def landing_map(since):
    """commit sha -> utc day it entered origin/main's first-parent line (since `since`), plus base set."""
    landed = {}
    fp = git("log", "--first-parent", "--format=%H %ct", "origin/main", f"--since={since}").split("\n")
    fp = [x.split() for x in fp if x]
    for sha, ts in reversed(fp):
        for c in git("rev-list", f"{sha}^1..{sha}").split():
            landed.setdefault(c, day(ts))
    return landed, fp[-1][0] if fp else None


def main():
    days_n = int(sys.argv[sys.argv.index("--days") + 1]) if "--days" in sys.argv else 7
    posts = ready_posts(sys.argv[1], sys.argv[sys.argv.index("--pre") + 1] if "--pre" in sys.argv else None)
    today = dt.datetime.now(dt.timezone.utc).date()
    days = [(today - dt.timedelta(days=i)).isoformat() for i in range(days_n - 1, -1, -1)]
    first_post, shas = {}, collections.defaultdict(set)
    for b, s, d in posts:
        first_post[b] = min(first_post.get(b, d), d)
        shas[b].add(s)
    heads, tagged = {}, set()
    for line in git("ls-remote", "origin", "refs/heads/ext/*").splitlines():
        sha, ref = line.split("\t")
        heads[ref.removeprefix("refs/heads/ext/")] = sha
    for line in git("for-each-ref", "refs/tags/archive", "--format=%(refname:short) %(*objectname) %(objectname)").splitlines():
        p = line.split()
        tagged.update(p[1:])
    landed_at, _ = landing_map("2026-10-20")
    # full sha for each short READY sha
    allsha = {s for v in shas.values() for s in v} | set(heads.values())
    full = dict(zip(sorted(allsha), git("rev-parse", "--verify", "-q", *[f"{s}^{{commit}}" for s in sorted(allsha)]).split()))
    if len(full) != len(allsha):  # some short sha missing locally: resolve one by one
        full = {s: git("rev-parse", "--verify", "-q", f"{s}^{{commit}}").strip() for s in allsha}
    inmain = set(git("rev-list", "origin/main").split())
    land_day, how = {}, {}
    for b in first_post:
        cands = [(full.get(s), "ready") for s in shas[b]] + ([(heads[b], "tip")] if b in heads else [])
        best = None
        for c, kind in cands:
            if c and c in inmain:
                d = landed_at.get(c, "old")
                if best is None or d < best[0]:
                    best = (d, kind)
        if best:
            land_day[b], how[b] = best
    # waiting now = live on origin, READY, head not in main, not archive-tagged at head (merge_gap.py definition)
    live = {b for b in first_post if b in heads}
    waiting = sorted(b for b in live if b not in land_day and heads[b] not in tagged)
    gone_unlanded = sorted(b for b in first_post if b not in heads and b not in land_day)
    print(f"READY branches ever {len(first_post)}, posts {len(posts)}; live {len(live)}; landed {len(land_day)} "
          f"(via READY sha {sum(1 for v in how.values() if v == 'ready')}, via tip only {sum(1 for v in how.values() if v == 'tip')}); "
          f"deleted without landing {len(gone_unlanded)}")
    print(f"WAITING now (live, head not in main, not archive-tagged) {len(waiting)}; "
          f"live unlanded but archive-tagged {sum(1 for b in live if b not in land_day and heads[b] in tagged)}")
    newp = collections.Counter(d for _, _, d in posts)
    newb = collections.Counter(first_post.values())
    landc = collections.Counter(land_day.values())
    print("day         posts newREADY landed waiting_end(READY<=d, not landed<=d, branch still live & untagged now)")
    for d in days:
        w = sum(1 for b in live if first_post[b] <= d and not (b in land_day and land_day[b] <= d) and heads[b] not in tagged)
        print(f"{d}  {newp[d]:5d} {newb[d]:8d} {landc[d]:6d} {w:7d}")
    # dashboard numbers: one branch counts once; "landed" day = first main first-parent commit containing it
    w_now = len(waiting)
    wk = [(today - dt.timedelta(days=i)).isoformat() for i in range(6, -1, -1)]
    w_7ago = sum(1 for b in live if first_post[b] <= wk[0] and not (b in land_day and land_day[b] <= wk[0]) and heads[b] not in tagged)
    out = {
        "waiting": w_now,
        "merged_today": landc[today.isoformat()],
        "merged_per_day_7d": round(sum(landc[d] for d in wk) / 7, 1),
        "new_ready_per_day_7d": round(sum(newb[d] for d in wk) / 7, 1),
        "gap_per_day_7d": round((w_now - w_7ago) / 6, 1),
        "per_day": {d: {"new_ready": newb[d], "landed": landc[d]} for d in wk},
    }
    if "--json" in sys.argv:
        import json

        print("JSON " + json.dumps(out))
    with open("/tmp/mn1114/waiting.txt", "w") as f:
        f.write("\n".join(f"{b} {heads[b]} {first_post[b]}" for b in waiting) + "\n")
    with open("/tmp/mn1114/landed.txt", "w") as f:
        f.write("\n".join(f"{b} {land_day[b]} {how[b]}" for b in sorted(land_day)) + "\n")


if __name__ == "__main__":
    main()
