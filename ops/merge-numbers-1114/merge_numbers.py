#!/usr/bin/env python3
"""Merge-health numbers for the /usage page, from git only (merge-numbers-fix-1114).

Replaces the READY-post counting in merge_tracker.py / merge-gap / master-page. Rules:
- A READY branch is a name in a `READY ext/<name> <sha>` line of briefs/EXT_TO_MAIN.md or briefs/archive/EXT_TO_MAIN-*.md
  on ext/agent-briefs. It counts ONCE, however many times it was re-posted (retries, bulk-rebase re-posts).
- Its READY day = git blame date of its first post (lines re-added by the 11-09 restore commit take their pre-gutting date).
- It LANDED when the first origin/main first-parent commit whose ancestry holds ANY of its READY shas or its current tip
  was made (so a batch PR lands every branch it carries, and a branch rebased or re-posted after landing stays landed).
- WAITING = landed never, still a live origin branch, head not archive-tagged (merge_gap.py rule).
- merged_today = branches landed in the current UTC day; merged_24h = rolling 24 h; merged_per_day_7d = landed in the
  last 7 UTC days (today included) / 7; gap_per_day_7d = (waiting now - waiting 7 days ago) / 7, from --history snapshots
  when they reach back that far, else reconstructed (lower bound: branches deleted or archived since are not seen).

Usage: merge_numbers.py [--repo DIR] [--no-fetch] [--json] [--history FILE] [--lists DIR] [--days N]
  --json     print one line `JSON {...}` (the page reads it); without it a readable table
  --history  JSON file {utc day: waiting}; this run writes today's value (keep it next to merge_tracker's data)
  --lists    write waiting.txt and landed.txt there
Runtime ~30-60 s on the full repo (two git blames + one rev-list of main).
"""

import collections
import datetime as dt
import json
import os
import re
import subprocess
import sys

READY = re.compile(r"^READY (ext/[\w./-]+) ([0-9a-f]{7,40})")
BRIEFS = "origin/ext/agent-briefs"
LOG = "briefs/EXT_TO_MAIN.md"
RESTORE = "5d0edcd40e988915315736f746f927dc4ced967d"  # 11-09 17:19: restored the gutted log; its lines are older
GUTTED = "f2bbcb34f9"  # the gutting commit; blame its parent for the real dates of restored lines
REPO = "."


def git(*a: str) -> str:
    return subprocess.run(["git", "-C", REPO, *a], capture_output=True, text=True, check=False).stdout


def opt(name: str, default: str | None = None) -> str | None:
    return sys.argv[sys.argv.index(name) + 1] if name in sys.argv else default


def blame_posts(rev: str, path: str) -> list[tuple[str, str, int]]:
    """[(branch, short sha, post unix time, blamed commit)] for every READY line of REV:PATH."""
    posts, ctime, cur = [], {}, ""
    for line in git("blame", "--line-porcelain", rev, "--", path).splitlines():
        if re.match(r"^[0-9a-f]{40} \d+ \d+", line):
            cur = line.split()[0]
        elif line.startswith("committer-time "):
            ctime[cur] = int(line.split()[1])
        elif line.startswith("\t"):
            m = READY.match(line[1:])
            if m and m.group(1) != "ext/agent-briefs":
                posts.append((m.group(1)[4:], m.group(2), ctime[cur], cur))
    return posts


def ready_posts() -> list[tuple[str, str, int]]:
    pre = {}
    for b, s, t, _ in blame_posts(f"{GUTTED}^", LOG):
        pre.setdefault((b, s), t)
    posts = [(b, s, pre.get((b, s), t) if c == RESTORE else t) for b, s, t, c in blame_posts(BRIEFS, LOG)]
    for path in git("ls-tree", "-r", "--name-only", BRIEFS, "briefs/archive/").split():
        if "EXT_TO_MAIN-" in path:
            posts += [(b, s, t) for b, s, t, _ in blame_posts(BRIEFS, path)]
    return posts


def landing_times(since: str) -> dict[str, int]:
    """commit -> unix time of the first origin/main first-parent commit that brought it in (since SINCE)."""
    landed: dict[str, int] = {}
    fp = [
        x.split()
        for x in git("log", "--first-parent", "--format=%H %ct %P", "origin/main", f"--since={since}").splitlines()
    ]
    for row in reversed(fp):
        sha, ts, parents = row[0], int(row[1]), row[2:]
        landed.setdefault(sha, ts)
        if len(parents) > 1:
            for c in git("rev-list", f"{parents[0]}..{sha}").split():
                landed.setdefault(c, ts)
    return landed


def utc_day(ts: int) -> str:
    return dt.datetime.fromtimestamp(ts, dt.timezone.utc).date().isoformat()


def main() -> None:
    global REPO
    REPO = opt("--repo", ".") or "."
    days_n = int(opt("--days", "7") or 7)
    if "--no-fetch" not in sys.argv:
        git("fetch", "-q", "origin", "main", "ext/agent-briefs", "+refs/tags/archive/*:refs/tags/archive/*")
    now = int(dt.datetime.now(dt.timezone.utc).timestamp())
    today = dt.datetime.now(dt.timezone.utc).date()
    week = [(today - dt.timedelta(days=i)).isoformat() for i in range(days_n - 1, -1, -1)]

    posts = ready_posts()
    first, shas = {}, collections.defaultdict(set)
    for b, s, t in posts:
        first[b] = min(first.get(b, t), t)
        shas[b].add(s)
    heads = {}
    for line in git("ls-remote", "origin", "refs/heads/ext/*").splitlines():
        sha, ref = line.split("\t")
        heads[ref.removeprefix("refs/heads/ext/")] = sha
    tagged = set(git("for-each-ref", "refs/tags/archive", "--format=%(objectname) %(*objectname)").split())

    allsha = sorted({s for v in shas.values() for s in v})
    full = dict(zip(allsha, git("rev-parse", *[f"{s}^{{commit}}" for s in allsha]).split()))
    if len(full) != len(allsha):  # an unknown short sha breaks the batch: resolve one by one
        full = {s: git("rev-parse", "--verify", "-q", f"{s}^{{commit}}").strip() for s in allsha}
    inmain = set(git("rev-list", "origin/main").split())
    land_ts = landing_times((today - dt.timedelta(days=days_n + 21)).isoformat())

    landed, how = {}, {}
    for b in first:
        cands = [(full.get(s), "ready") for s in shas[b]] + ([(heads[b], "tip")] if b in heads else [])
        for c, kind in cands:
            if c and c in inmain:
                t = land_ts.get(c, 0)  # 0 = landed before the scanned window
                if b not in landed or t < landed[b]:
                    landed[b], how[b] = t, kind
    live = {b for b in first if b in heads}
    waiting = sorted(b for b in live if b not in landed and heads[b] not in tagged)
    moved_after_landing = sum(1 for b in live if b in landed and heads[b] not in inmain and heads[b] not in tagged)

    day_end = {d: int(dt.datetime.fromisoformat(d).replace(tzinfo=dt.timezone.utc).timestamp()) + 86400 for d in week}

    def waiting_at(t: int) -> int:  # lower bound: only branches still live and untagged now
        return sum(1 for b in live if first[b] < t and not (b in landed and landed[b] < t) and heads[b] not in tagged)

    new_by_day = collections.Counter(utc_day(t) for t in first.values())
    posts_by_day = collections.Counter(utc_day(t) for _, _, t in posts)
    land_by_day = collections.Counter(utc_day(t) for t in landed.values() if t)

    hist_path = opt("--history")
    hist = {}
    if hist_path and os.path.exists(hist_path):
        with open(hist_path, encoding="utf-8") as f:
            hist = json.load(f)
    base_day = (today - dt.timedelta(days=days_n)).isoformat()
    if base_day in hist:
        w_base, gap_src = int(hist[base_day]), "history"
    else:
        w_base, gap_src = waiting_at(day_end[week[0]] - 86400), "reconstructed"
    yesterday_end = waiting_at(day_end[today.isoformat()] - 86400)
    out = {
        "as_of_utc": dt.datetime.fromtimestamp(now, dt.timezone.utc).strftime("%Y-%m-%d %H:%M"),
        "main": git("rev-parse", "--short=10", "origin/main").strip(),
        "waiting": len(waiting),
        "waiting_yesterday_end": yesterday_end,
        "gap_today": len(waiting) - yesterday_end,
        "trend": "shrinking" if len(waiting) < yesterday_end else "growing" if len(waiting) > yesterday_end else "flat",
        "merged_today": land_by_day[today.isoformat()],
        "merged_24h": sum(1 for t in landed.values() if t > now - 86400),
        "merged_per_day_7d": round(sum(land_by_day[d] for d in week) / days_n, 1),
        "new_ready_per_day_7d": round(sum(new_by_day[d] for d in week) / days_n, 1),
        "gap_per_day_7d": round((len(waiting) - w_base) / days_n, 1),
        "gap_source": gap_src,
        "ready_posts_landed_24h": sum(1 for b, s, _ in posts if b in landed and landed[b] > now - 86400),
        "moved_after_landing": moved_after_landing,
        "per_day": {
            d: {
                "ready_posts": posts_by_day[d],
                "new_ready": new_by_day[d],
                "landed": land_by_day[d],
                "waiting_end": waiting_at(min(day_end[d], now)),
            }
            for d in week
        },
    }
    if hist_path:
        hist[today.isoformat()] = len(waiting)
        with open(hist_path + ".tmp", "w", encoding="utf-8") as f:
            json.dump(hist, f, indent=0, sort_keys=True)
        os.replace(hist_path + ".tmp", hist_path)
    lists = opt("--lists")
    if lists:
        os.makedirs(lists, exist_ok=True)
        with open(os.path.join(lists, "waiting.txt"), "w", encoding="utf-8") as f:
            f.write("".join(f"{b} {heads[b]} {utc_day(first[b])}\n" for b in waiting))
        with open(os.path.join(lists, "landed.txt"), "w", encoding="utf-8") as f:
            f.write("".join(f"{b} {utc_day(landed[b]) if landed[b] else 'old'} {how[b]}\n" for b in sorted(landed)))
    if "--json" in sys.argv:
        print("JSON " + json.dumps(out))
        return
    print(
        f"as of {out['as_of_utc']} UTC, main {out['main']}: READY branches ever {len(first)} ({len(posts)} posts), "
        f"live {len(live)}, landed {len(landed)} (by READY sha {sum(v == 'ready' for v in how.values())}, by tip only "
        f"{sum(v == 'tip' for v in how.values())}), moved after landing {moved_after_landing}"
    )
    print(
        f"Waiting {out['waiting']} ({out['trend']}, {yesterday_end} at end of yesterday) | merged today {out['merged_today']} "
        f"(24 h: {out['merged_24h']}; READY posts of those: {out['ready_posts_landed_24h']}) | {out['merged_per_day_7d']} a day "
        f"this week | new READY {out['new_ready_per_day_7d']}/day | gap per day {out['gap_per_day_7d']:+} ({gap_src}), "
        f"today {out['gap_today']:+}"
    )
    print("day         posts newREADY landed waiting_end")
    for d, r in out["per_day"].items():
        print(f"{d}  {r['ready_posts']:5d} {r['new_ready']:8d} {r['landed']:6d} {r['waiting_end']:7d}")


if __name__ == "__main__":
    main()
