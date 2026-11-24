#!/usr/bin/env python3
"""Redo/duplicate guard for claude-job (claude-job start, the pacer, backlog-refill and cj_routing call it).

  cj-guard check --label L (--task-file F | --task T) [--allow-dup] [--redo] [--force] [--dry] [--cj DIR]
        exit 0 ok
             71 REFUSED: same key or task similarity >= 0.8 is RUNNING (prints its id; --force never bypasses, --allow-dup does)
             72 STUCK: same key has 3+ finished runs, none done (one line appended to <cj>/stuck.jsonl; --dry: not)
             73 REFUSED: same key finished done in the last 72 h (prints id + answer.md/result.json; --redo bypasses)
  cj-guard backlog-add [--file backlog.jsonl] --json '{"label":..,"task":..}'   exit 0 added | 1 duplicate (not added)
  cj-guard backlog-dedupe [--file backlog.jsonl] [--dry]   drop duplicates already in the backlog
  cj-guard key --label L | --task T                          print the normalized key
  cj-redo-report [--hours 24] [--hourly-log /home/boki/cj/redo-report.log]
  cj-guard dryrun [--hours 24]    replay the last starts: how many a/b/c would have blocked (starts nothing)
Key: label without requeue/escalate(x)/retry(x) prefixes, lowercased, punctuation/whitespace collapsed (no label: the
first 250 chars of the original task). A continuation ('PREVIOUS ATTEMPT: job <id>' or a prior answer.md 'Unfinished'
list in the task) takes its previous run's key. Python callers: `from cj_dedup import guard, backlog_add`."""
import argparse, json, os, re, sys, time, glob, datetime, collections

RUNNING, DONE = "running", "done"
RC_RUNNING, RC_STUCK, RC_RECENT = 71, 72, 73
PREFIX = re.compile(r"^\s*(?:requeue|escalate|retry)\s*(?:\([^)]*\)|\[[^\]]*\])?\s*[:\-–—]?\s*", re.I)
BRANCH_RE = re.compile(r"\bext/[\w.-]*\w")
STUCK_RUNS, SIM_MIN, RECENT_H, SHINGLE_N, TEXT_CHARS = 3, 0.8, 72, 3, 1500


def norm_key(label):
    s = label or ""
    while True:
        t = PREFIX.sub("", s, count=1)
        if t == s: break
        s = t
    return " ".join(re.sub(r"[^\w]+", " ", s.lower()).split())


def shingles(text):
    w = re.sub(r"[^\w]+", " ", (text or "")[:TEXT_CHARS].lower()).split()
    if len(w) < SHINGLE_N: return {" ".join(w)} if w else set()
    return {" ".join(w[i:i + SHINGLE_N]) for i in range(len(w) - SHINGLE_N + 1)}


def similarity(a, b):
    A, B = shingles(a), shingles(b)
    return len(A & B) / len(A | B) if A and B else 0.0


def unfinished(answer):
    m = re.search(r"(?ims)^[#*\s]*unfinished[^\n]*\n(.*?)(?=^#{1,6}\s|^\*\*[^*\n]+\*\*\s*$|^STATUS:|\Z)", answer or "")
    return m.group(1).strip() if m else ""


def _ts(job_id):
    try: return datetime.datetime.strptime(job_id[:15], "%Y%m%d-%H%M%S").replace(tzinfo=datetime.timezone.utc).timestamp()
    except ValueError: return 0.0


def _read(p, n=None):
    try:
        with open(p, errors="replace") as f: return f.read() if n is None else f.read(n)
    except OSError: return ""


MAX_RUN_H = float(os.environ.get("CJ_MAX_RUN_H", "10"))  # no rc and no STATUS after this long: lost, not running
PREV_RE = re.compile(r"(?:PREVIOUS ATTEMPT: job|restart of job|RESTART NOTE:[^\n]{0,80}?job) (\d{8}-\d{6}-[A-Za-z0-9]+)")


WRAP_RE = re.compile(r"^(PREVIOUS ATTEMPT|RESTART NOTE|NOTE: restart|REQUEUED|TASK BRANCH|>)", re.I)
GUARD_RE = re.compile(r"^(Guard first|FIRST check)\b", re.I)


def task_body(task):
    """The original task text: after 'ORIGINAL TASK:' (escalations/restarts), without leading wrapper paragraphs
    (PREVIOUS ATTEMPT / RESTART NOTE / REQUEUED / quoted answer) and without a leading 'Guard first: ...' sentence."""
    t = (task or "").rsplit("ORIGINAL TASK:", 1)[-1].strip()
    paras = re.split(r"\n\s*\n", t)
    while len(paras) > 1 and WRAP_RE.match(paras[0].strip()): paras.pop(0)
    t = "\n\n".join(paras).strip()
    if GUARD_RE.match(t):
        i = t.find("STATUS: skipped", 0, 800)
        i = t.find(".", i) + 1 if i >= 0 else t.find(". ") + 1
        if 0 < i < len(t) - 40: t = t[i:].strip()
    return t


def text_key(task):
    """Key for a run without a label: the first 250 chars of the original task plus the ext/* branches it names."""
    b = task_body(task)
    return "t:" + norm_key(b[:250]) + "".join(" @" + x for x in sorted(set(BRANCH_RE.findall(b[:TEXT_CHARS]))))


def _mtime(*paths):
    ts = [os.path.getmtime(p) for p in paths if os.path.exists(p)]
    return max(ts) if ts else None


def load_jobs(cj, since=0.0, now=None):
    """claude-job records: <cj>/<id>/{label,task,answer.md,result.json,rc,log} (w2 copies: prompt instead of task).
    status = last 'STATUS: x' of answer.md (or result.json result); running = no rc, no STATUS, younger than MAX_RUN_H."""
    now = now or time.time()
    out = []
    for d in sorted(glob.glob(os.path.join(cj, "2???????-??????-*"))):
        jid = os.path.basename(d)
        t0 = _ts(jid)
        if t0 < since or not os.path.isdir(d): continue
        task = _read(os.path.join(d, "task"))
        if not task:
            prompt = _read(os.path.join(d, "prompt"))
            task = prompt.split("\nTASK:", 1)[1].strip() if "\nTASK:" in prompt else prompt
        meta = {}
        try: meta = json.loads(_read(os.path.join(d, "meta.json")) or "{}")
        except ValueError: pass
        label = (meta.get("label") or _read(os.path.join(d, "label"))).strip()
        ans = _read(os.path.join(d, "answer.md"))
        if not ans:
            try: ans = json.loads(_read(os.path.join(d, "result.json")) or "{}").get("result", "") or ""
            except (ValueError, AttributeError): ans = ""
        st = re.findall(r"STATUS:\s*(\w+)", ans[-600:])
        rcp = os.path.join(d, "rc")
        if st: status = st[-1].lower()
        elif os.path.exists(rcp): status = "failed"
        elif now - t0 < MAX_RUN_H * 3600: status = RUNNING
        else: status = "lost"
        end = None if status == RUNNING else (_mtime(rcp, os.path.join(d, "answer.md"), os.path.join(d, "result.json"),
                                                     os.path.join(d, "log")) or t0)
        pm = PREV_RE.search(task)
        out.append(dict(id=jid, dir=d, label=label, key=norm_key(label) if label else text_key(task), task=task,
                        body=task_body(task), answer=ans, status=status, start=t0, end=end,
                        prev=pm.group(1) if pm else None,
                        redo=bool(PREFIX.match(label) and PREFIX.sub("", label, count=1) != label) or bool(pm)
                             or "RESTART NOTE" in task[:300]))
    link_continuations(out)
    return out


def _unf_sig(answer):
    return " ".join(unfinished(answer).lower().split())[:80]


def resolve_key(label, task, prior, byid=None):
    """Key of a (new or loaded) run: its previous attempt's key when it names one ('PREVIOUS ATTEMPT: job <id>') or
    carries a prior run's answer.md 'Unfinished' list; else the label key (text key when there is no label)."""
    byid = byid if byid is not None else {p["id"]: p for p in prior}
    tx = " ".join((task or "").lower().split())
    pm = PREV_RE.search(task or "")
    if pm and pm.group(1) in byid:  # a restart/escalation of that run, not a fan-out child with its own scope
        p = byid[pm.group(1)]
        if near_dup(task_body(task), p["body"]) or (len(_unf_sig(p["answer"])) > 20 and _unf_sig(p["answer"]) in tx):
            return p["key"]
    for p in prior[-400:][::-1]:
        u = p.get("_unf")
        if u is None: u = p["_unf"] = _unf_sig(p["answer"])
        if len(u) > 20 and u in tx: return p["key"]
    return norm_key(label) if label else text_key(task)


def link_continuations(jobs):
    """A continuation (names its previous attempt, or carries its 'Unfinished' list) is the same key as that run."""
    byid = {}
    for i, j in enumerate(jobs):
        if i:
            j["key"] = resolve_key(j["label"], j["task"], jobs[:i], byid)
        byid[j["id"]] = j


def groups(jobs):
    g = collections.defaultdict(list)
    for j in jobs: g[j["key"]].append(j)
    return g


def near_dup(a, b):
    """Task similarity >= SIM_MIN, unless the two name different ext/* branches (templated per-branch tasks such as
    'branch ext/X was posted READY but conflicts' are 0.85-0.9 alike and are not duplicates)."""
    if similarity(a, b) < SIM_MIN: return False
    A, B = set(BRANCH_RE.findall(a[:TEXT_CHARS])), set(BRANCH_RE.findall(b[:TEXT_CHARS]))
    return not (A - B and B - A)  # each names a branch the other does not: different per-branch tasks


def match_running(key, task, jobs):
    body = task_body(task)
    return [j for j in jobs if j["status"] == RUNNING and (j["key"] == key or near_dup(body, j["body"]))]


def decide(label, task, jobs, now, allow_dup=False, redo=False, hours=RECENT_H, key=None):
    """Pure guard, checked in order a, b, c. jobs: records as from load_jobs. Returns dict(action, code, key, ...)."""
    key = key or resolve_key(label, task, jobs)
    run = match_running(key, task, jobs)
    if run and not allow_dup:
        return dict(action="dup_running", code=RC_RUNNING, key=key, running=[j["id"] for j in run])
    same = [j for j in jobs if j["key"] == key and j["status"] != RUNNING]
    if len(same) >= STUCK_RUNS and not any(j["status"] == DONE for j in same):
        last = same[-1]
        return dict(action="stuck", code=RC_STUCK, key=key, runs=[j["id"] for j in same], last_status=last["status"],
                    answer_tail=last["answer"][-400:], unfinished=unfinished(last["answer"]))
    done = [j for j in same if j["status"] == DONE and (j["end"] or j["start"]) >= now - hours * 3600]
    if done and not redo:
        return dict(action="recent_done", code=RC_RECENT, key=key,
                    done=[(j["id"], j["dir"] + "/answer.md", j["dir"] + "/result.json") for j in done])
    return dict(action="ok", code=0, key=key)


def log_stuck(path, d):
    ids = d["runs"]
    for line in _read(path).splitlines()[-200:]:
        try:
            o = json.loads(line)
            if o.get("key") == d["key"] and o.get("runs") == ids: return False
        except ValueError: pass
    with open(path, "a") as f:
        f.write(json.dumps(dict(ts=int(time.time()), key=d["key"], runs=ids, last_status=d["last_status"],
                                answer_tail=d["answer_tail"], unfinished=d["unfinished"])) + "\n")
    return True


def item_key(item):
    return norm_key(item.get("label", "")) if item.get("label") else text_key(item.get("task", ""))


def backlog_add(path, item):
    """Append item to the backlog unless an item with the same key (or task similarity >= SIM_MIN) is there."""
    import fcntl
    key, body = item_key(item), task_body(item.get("task", ""))
    with open(path, "a+") as f:
        fcntl.flock(f, fcntl.LOCK_EX)
        f.seek(0)
        for line in f.read().splitlines():
            try: o = json.loads(line)
            except ValueError: continue
            if item_key(o) == key or near_dup(body, task_body(o.get("task", ""))): return False
        f.seek(0, 2); f.write(json.dumps(item) + "\n")
    return True


def backlog_dedupe(path, dry=False):
    """Drop later duplicates (same key) already in the backlog; keeps a .bak-1112-redo copy first."""
    lines, seen, keep, drop = _read(path).splitlines(), set(), [], 0
    for line in lines:
        try: k = item_key(json.loads(line))
        except ValueError: keep.append(line); continue
        if k in seen: drop += 1; continue
        seen.add(k); keep.append(line)
    if drop and not dry:
        if not os.path.exists(path + ".bak-1112-redo"):
            with open(path + ".bak-1112-redo", "w") as f: f.write("\n".join(lines) + "\n")
        with open(path, "w") as f: f.write("\n".join(keep) + "\n")
    return drop


def stats(jobs):
    g = groups(jobs)
    never = {k: v for k, v in g.items() if not any(j["status"] == DONE for j in v)}
    top = sorted(g.items(), key=lambda kv: -len(kv[1]))[:15]
    bad_jobs = sum(len(v) for v in never.values())
    return dict(jobs=len(jobs), tasks=len(g), redo_runs=sum(1 for j in jobs if j["redo"]),
                three_plus_never=sum(1 for v in never.values() if len(v) >= 3),
                three_plus=sum(1 for v in g.values() if len(v) >= 3),
                never_done_jobs=bad_jobs, never_share=bad_jobs / len(jobs) if jobs else 0.0,
                top=[(k, len(v), v[-1]["status"], v[-1]["label"] or v[-1]["body"][:60]) for k, v in top])


def print_report(jobs, hours, out=sys.stdout):
    s = stats(jobs)
    print(f"redo-report {datetime.datetime.now(datetime.timezone.utc):%Y-%m-%d %H:%MZ} window {hours:g}h: jobs {s['jobs']} "
          f"| distinct tasks {s['tasks']} | redo runs {s['redo_runs']} | tasks 3+ runs {s['three_plus']} "
          f"(never done {s['three_plus_never']}) | jobs on never-done tasks {s['never_done_jobs']} ({s['never_share']:.0%})",
          file=out)
    for k, n, st, lab in s["top"]: print(f"  {n:3d}x {st:8s} {' '.join(lab.split())[:90]}", file=out)


def hourly(cj, hours, log):
    """For the pacer: append the report to log at most once an hour (call it every pacer tick)."""
    if time.time() - (_mtime(log) or 0) < 3300: return 0
    with open(log, "a") as f: print_report(load_jobs(cj, time.time() - hours * 3600), hours, f)
    return 0


def dryrun(cj, hours, now=None):
    """Replay the last `hours` of starts against the records as they stood at each start. No job is started."""
    now = now or time.time()
    allj = load_jobs(cj, now - (hours + 14 * 24) * 3600, now)
    starts = [j for j in allj if j["start"] >= now - hours * 3600]
    hit = {"a": [], "b": [], "c": []}; first = collections.Counter()
    for j in starts:
        snap = [dict(p, status=(RUNNING if (p["end"] is None or p["end"] > j["start"]) else p["status"]))
                for p in allj if p["start"] < j["start"]]
        key = j["key"]
        run = match_running(key, j["task"], [p for p in snap if p["id"] != j["prev"]])
        same = [p for p in snap if p["key"] == key and p["status"] != RUNNING]
        b = len(same) >= STUCK_RUNS and not any(p["status"] == DONE for p in same)
        c = any(p["status"] == DONE and (p["end"] or p["start"]) >= j["start"] - RECENT_H * 3600 for p in same)
        if run: hit["a"].append((j["id"], run[0]["id"]))
        if b: hit["b"].append((j["id"], len(same)))
        if c: hit["c"].append(j["id"])
        first["a" if run else "b" if b else "c" if c else "ok"] += 1
    blocked = len(starts) - first["ok"]
    print(f"dryrun {hours:g}h over {cj}: starts {len(starts)} | would block {blocked} "
          f"(first rule: a {first['a']} b {first['b']} c {first['c']}) | each rule alone: "
          f"(a) running dup {len(hit['a'])} (b) stuck 3+ none done {len(hit['b'])} (c) done <72h {len(hit['c'])}")
    for k, v in hit.items(): print(f"  {k} e.g. {v[:4]}")
    return dict(starts=len(starts), blocked=blocked, first=dict(first), **{k: len(v) for k, v in hit.items()})


def guard(label, task, cj="/home/boki/cj", allow_dup=False, redo=False, dry=False):
    """For Python callers (cj_routing requeue/escalate, backlog-refill, pacer): returns (code, message)."""
    d = decide(label, task, load_jobs(cj, time.time() - 14 * 86400), time.time(), allow_dup, redo)
    if d["action"] == "dup_running":
        return d["code"], f"REFUSED duplicate: already running {' '.join(d['running'])} (--allow-dup to bypass; --force does not)"
    if d["action"] == "stuck":
        if not dry: log_stuck(os.path.join(cj, "stuck.jsonl"), d)
        return d["code"], f"STUCK {d['key']!r}: {len(d['runs'])} runs, none done ({' '.join(d['runs'][-5:])}); see {cj}/stuck.jsonl"
    if d["action"] == "recent_done":
        return d["code"], f"REFUSED done <{RECENT_H}h: " + "; ".join(" ".join(x) for x in d["done"]) + " (--redo to run anyway)"
    return 0, "ok " + d["key"]


def main(argv=None):
    ap = argparse.ArgumentParser()
    ap.add_argument("cmd", choices=["check", "backlog-add", "backlog-dedupe", "report", "dryrun", "key"])
    ap.add_argument("--cj", default=os.environ.get("CJ_DIR", "/home/boki/cj"))
    ap.add_argument("--label", default=""); ap.add_argument("--task", default=""); ap.add_argument("--task-file")
    ap.add_argument("--allow-dup", action="store_true"); ap.add_argument("--redo", action="store_true")
    ap.add_argument("--force", action="store_true", help="accepted and ignored: --force never bypasses the guard")
    ap.add_argument("--dry", action="store_true", help="check: do not append to stuck.jsonl")
    ap.add_argument("--hours", type=float, default=24)
    ap.add_argument("--hourly-log", help="report: append to this log at most once an hour (pacer tick)")
    ap.add_argument("--file"); ap.add_argument("--json")
    a = ap.parse_args(argv)
    task = a.task or (_read(a.task_file) if a.task_file else "")
    if a.cmd == "key": print(norm_key(a.label) if a.label else text_key(task)); return 0
    if a.cmd == "backlog-add":
        added = backlog_add(a.file or os.path.join(a.cj, "backlog.jsonl"), json.loads(a.json))
        print("added" if added else "DUP (same key already in backlog)"); return 0 if added else 1
    if a.cmd == "backlog-dedupe":
        n = backlog_dedupe(a.file or os.path.join(a.cj, "backlog.jsonl"), a.dry); print(f"dropped {n} duplicate(s)"); return 0
    if a.cmd == "report":
        if a.hourly_log: return hourly(a.cj, a.hours, a.hourly_log)
        print_report(load_jobs(a.cj, time.time() - a.hours * 3600), a.hours); return 0
    if a.cmd == "dryrun": dryrun(a.cj, a.hours); return 0
    code, msg = guard(a.label, task, a.cj, a.allow_dup, a.redo, a.dry)
    print(msg, file=sys.stdout if code == 0 else sys.stderr)
    return code


if __name__ == "__main__":
    sys.exit(main())
