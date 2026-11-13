#!/usr/bin/env python3
"""prior-work: has this concept already been built, or is it being built right now? (owner order 11-12: no job starts unchecked)

cj_dedup catches the same label or near-identical text. prior-work catches SEMANTIC overlap: different words, same system
("Boki control G->C" while ~20 ext/*wisp* branches reworked summoning). It scores a label + task against:
  ext/* branches (git ls-remote; tip dates from the local clone), READY/NOTE posts (agent-briefs EXT_TO_MAIN.md),
  claude-job labels + the first 2k chars of their tasks (last 14 days, with status), the pacer backlog,
  briefs/DECISIONS.md sections, and main's git log --since=14.days,
using the task's distinctive words (rarer = heavier, label words x2) plus concepts from concept-aliases.tsv.

HIGH = an ACTIVE item on the same system: a running job, a branch with a commit in the last 72 h, or a READY post (14 days)
whose branch still exists; the same concept in both titles (label / branch name / READY head), compatible lanes
([anim]/[vfx]/[sfx]/[ui]/[art] work never blocks a different lane), and score >= HIGH_SCORE. claude-job start refuses it
(exit 75) unless the task has a line "Builds on: <branch/job ids>" or "Not a dupe: <reason>". Items the task already names
(ext/<branch>, job ids, its own retry lineage) never count.

  prior-work [--label L] [--task T | --task-file F | TEXT...] [--top 8] [--json]   matches with score and why (exit 0)
  prior-work gate --label L --task-file F [--by WHO]     exit 75 + reason on HIGH; else prints the PRIOR WORK FOUND block (may be empty)
  prior-work dryrun [--hours 48] [--sample 30] [--seed 1112] [--job ID ...] [-v]   replay real starts against what was known then
Python: search(label, task) -> [match]; gate(label, task, by="") -> (code, refusal, prompt_block)
Env: CJ_DIR (~/cj), PW_REPO (~/project-boki), PW_ALIASES (concept-aliases.tsv beside this file or in coord/boki-tools)."""
import argparse, collections, hashlib, json, math, os, random, re, subprocess, sys, time

HERE = os.path.dirname(os.path.realpath(__file__)); sys.path.insert(0, HERE); sys.path.insert(0, "/home/boki/bin")
import cj_dedup as D

DAYS = 14; ACTIVE_H = 72; TASK_CHARS = 2000
HIGH_SCORE = 30; LOW_SCORE = 35; TOP = 5; REFUSE = 75
BROAD = set()   # concepts marked 'broad' in concept-aliases.tsv
AREA = {"tutorial", "bot", "camps", "boss", "mob", "farm", "net"}   # a label about one of these areas only matches items in that area too
LINEAGE_RX = re.compile(r"^\s*(?:(?:escalate|retry)\([\w-]+\)|requeue)\s+", re.I)
CACHE_VER = "2"   # bump when cached job features/lanes change meaning


def unprefix(label):
    """Strip the escalate(x) / retry(x) / requeue prefixes the pacer and escalation add."""
    s = label or ""
    while LINEAGE_RX.match(s): s = LINEAGE_RX.sub("", s, count=1)
    return s
REPO = os.environ.get("PW_REPO") or os.path.expanduser("~/project-boki")
EXEMPT_RX = re.compile(r"^(backlog planner|rebase |merge |stuck integ|login test|swap test|integ |mc |bulk rebase|infra coordinator daily retro|coordinator daily retro)")
OVERRIDE_RX = re.compile(r"(?im)^\s*(builds on|not a dupe)\s*:\s*(.+)$")
PRESENT_LANES = {"anim", "vfx", "sfx", "audio", "art", "ui"}   # presentation work: never blocks / is blocked by another lane
LANE_ALIAS = {"tut": "tutorial", "art3d": "art", "audio": "sfx", "early": "", "verify": "", "spec": ""}
LANES = {"combat", "feel", "anim", "vfx", "ui", "sfx", "farm", "tutorial", "tut", "extra", "art", "art3d", "infra", "perf", "match",
         "design", "bokidex", "move", "audio", "net", "garden"}
STOP = set("""the and for with that this from into onto your you are was were will has have had not but all any its our their them they
then than when what which who how why where there here each every one two three also only just more most less very much many some such same
other else over under after before again still yet now new old use used using make made keep kept add added get got set put see seen look
show run ran can could would should must may might need want does did done doing via per off out back like still both either never always
task branch ext job ready post posted origin main merge merged rebase rebased commit push pushed fetch check checked test tests owner
coordinator worker session report status skipped partial blocked fix fixed file line first last note wip claude godot jobq agent repo tree
worktree supersede supersedes superseded previous attempt candidate integ then""".split())
SHORT_OK = {"xp", "cc", "ui", "hp", "ai", "rmb", "lmb", "ult"}


def cj_dir(): return D.cj_dir()


def stem(w):
    if len(w) > 4 and w.endswith("ies"): return w[:-3] + "y"
    if len(w) > 4 and w.endswith("es") and w[-3] in "sxz": return w[:-2]
    if len(w) > 3 and w.endswith("s") and not w.endswith(("ss", "us", "is")): return w[:-1]
    return w


def toks(text):
    out = []
    for w in re.findall(r"[a-z][a-z0-9]*", (text or "").lower().replace("_", " ")):
        if re.fullmatch(r"[0-9a-f]{7,}", w) or sum(c.isdigit() for c in w) >= 3: continue
        out.append(stem(w))
    return out


# ---- concept aliases --------------------------------------------------------------------------------------------------
_AL = None
def aliases():
    """[(phrase as ' a b ', concept)], from concept-aliases.tsv (+ each concept's own name)."""
    global _AL
    if _AL is not None: return _AL
    p = os.environ.get("PW_ALIASES") or next((x for x in (os.path.join(HERE, "concept-aliases.tsv"), "/home/boki/coord/boki-tools/concept-aliases.tsv")
                                              if os.path.exists(x)), "")
    out = set()
    try:
        for l in open(p):
            if l.startswith("#") or "\t" not in l: continue
            ph, cs, *fl = l.rstrip("\n").split("\t"); cs = [c.strip() for c in cs.split(",") if c.strip()]
            if fl and fl[0].strip() == "broad": BROAD.update(cs)
            for c in cs: out.add((" " + " ".join(toks(c.replace("-", " "))) + " ", c))
            for x in ph.split("|"):
                t = " ".join(toks(x))
                if t:
                    for c in cs: out.add((f" {t} ", c))
    except OSError: pass
    _AL = sorted(out); return _AL


def concepts(tl):
    s = " " + " ".join(tl) + " "
    return {c for ph, c in aliases() if ph in s}


def feats(title, body=""):
    """feature -> 1.0 (in the title) | 0.5 (body only). Features: words, and 'c:<concept>'."""
    tt, bt = toks(title), toks(body)
    f = {}
    for t in bt:
        if len(t) >= 3 or t in SHORT_OK: f[t] = 0.5
    for c in concepts(bt): f["c:" + c] = 0.5
    for t in tt:
        if len(t) >= 3 or t in SHORT_OK: f[t] = 1.0
    for c in concepts(tt): f["c:" + c] = 1.0
    for s in STOP: f.pop(s, None)
    return f


def lane_of(s):
    s = (s or "").strip().lower()
    m = re.match(r"\[([a-z0-9]+)", s) or re.match(r"(?:ext/)?([a-z0-9]+)-", s)
    if not m or m.group(1) not in LANES: return ""
    l = m.group(1); return LANE_ALIAS.get(l, l)


def base_branch(b): return re.sub(r"(-rebased)+$", "", b.strip().rstrip(".,;:)").lower())
def refs_in(text):
    """Branches and job ids a text names."""
    t = text or ""
    return {"ext/" + base_branch(x) for x in re.findall(r"\bext/([A-Za-z0-9._/-]+[A-Za-z0-9])", t)} | set(re.findall(r"\b\d{8}-\d{6}-a\d+\b", t))


# ---- sources ----------------------------------------------------------------------------------------------------------
def _git(*a, timeout=30):
    try: return subprocess.run(["git", "-C", REPO, *a], capture_output=True, text=True, timeout=timeout).stdout
    except Exception: return ""


def src_branches(live=True):
    """ext/* branches: name, tip epoch. Names from git ls-remote (live), dates from the local clone's origin refs."""
    dates = {}
    for l in _git("for-each-ref", "refs/remotes/origin/ext", "--format=%(refname:short) %(committerdate:unix)").splitlines():
        n, _, d = l.partition(" ")
        if d.isdigit(): dates[n[len("origin/"):]] = int(d)
    names = None
    if live:
        o = _git("ls-remote", "origin", "refs/heads/ext/*", timeout=20)
        if o: names = [l.split("refs/heads/", 1)[1] for l in o.splitlines() if "refs/heads/" in l]
    if names is None: names = list(dates)
    out = []
    for n in names:
        if n == "ext/agent-briefs": continue
        out.append({"kind": "branch", "id": n, "title": n[4:].replace("-", " ").replace("/", " "), "body": "", "t": dates.get(n, time.time()),
                    "refs": {"ext/" + base_branch(n[4:])}, "lane": lane_of(n)})
    return out


def _ready_lines():
    """[(epoch, line)] of EXT_TO_MAIN.md, dated by git blame once and cached by blob (the file is append-only: new lines get the
    commit time of the newest commit)."""
    cp = os.path.join(cj_dir(), ".prior-work-ready.json")
    blob = _git("rev-parse", "origin/ext/agent-briefs:briefs/EXT_TO_MAIN.md").strip()
    try: c = json.load(open(cp))
    except Exception: c = {}
    if blob and c.get("blob") == blob: return c["lines"]
    text = _git("cat-file", "blob", blob) if blob else ""
    lines = text.splitlines(); old = c.get("lines") or []
    if old and len(old) <= len(lines) and all(old[i][1] == lines[i] for i in (0, len(old) // 2, len(old) - 1)):
        ct = int((_git("log", "-1", "--format=%ct", "origin/ext/agent-briefs").strip() or 0) or time.time())
        res = old + [[ct, l] for l in lines[len(old):]]
    else:
        res = []; t = 0
        for l in _git("blame", "--line-porcelain", "origin/ext/agent-briefs", "--", "briefs/EXT_TO_MAIN.md", timeout=120).splitlines():
            if l.startswith("committer-time "): t = int(l.split()[1])
            elif l.startswith("\t"): res.append([t, l[1:]])
        if not res: res = [[0, l] for l in lines]
    try:
        tmp = f"{cp}.{os.getpid()}"; json.dump({"blob": blob, "lines": res}, open(tmp, "w")); os.replace(tmp, cp)
    except OSError: pass
    return res


def src_ready(since, latest=True):
    """READY/NOTE posts since `since` (latest=True: the newest per branch; the replay keeps them all)."""
    by = {}; n = 0
    for t, l in _ready_lines():
        if t < since or not (l.startswith("READY ext/") or l.startswith("NOTE ")): continue
        m = re.match(r"(READY|NOTE)\s+(ext/[A-Za-z0-9._/-]+[A-Za-z0-9])", l)
        if not m: continue
        b = m.group(2); head = l[:170]
        n += 1
        by["ext/" + base_branch(b[4:]) if latest else n] = {"kind": "ready" if m.group(1) == "READY" else "note", "id": b, "t": t,
                                           "title": b[4:].replace("-", " "), "body": l[len(m.group(0)):600], "head": head,
                                           "refs": refs_in(l[:400]) | {"ext/" + base_branch(b[4:])}, "lane": lane_of(b)}
    return list(by.values())


def _job_text(J):
    return D.base_task(D._rd(J, "task", 12000))[:TASK_CHARS]


def src_jobs(since):
    """claude-job records since `since`: label, first 2k chars of the (original) task, status, start/finish, running. The feature
    sets of finished jobs are cached in $CJ_DIR/.prior-work-cache.json."""
    base = cj_dir(); cp = os.path.join(base, ".prior-work-cache.json"); cut = time.strftime("%Y%m%d", time.gmtime(since))
    aliases(); ver = hashlib.md5(repr((_AL, sorted(BROAD), CACHE_VER)).encode()).hexdigest()[:12]   # an alias edit re-features every job
    try: cache = json.load(open(cp)); cache = {k: v for k, v in cache.items() if k[:8] >= cut} if cache.get("_v") == ver else {}
    except Exception: cache = {}
    cache["_v"] = ver; out = []; new = 0
    for j in D.load_jobs(since):
        c = cache.get(j["id"])
        if c is None:
            J = os.path.join(base, j["id"]); task = _job_text(J)
            br = D._rd(J, "branch", 200)
            c = {"f": feats(j["label"], task), "refs": sorted(refs_in(task[:1500]) | ({"ext/" + base_branch(br[4:])} if br.startswith("ext/") else set())),
                 "br": br, "lane": lane_of(unprefix(j["label"]))}
            if j["fin"] is not None:
                cache[j["id"]] = c; new += 1
                if new % 300 == 0: _save_cache(cp, cache)   # a gate killed by claude-job's timeout keeps its progress
        out.append({"kind": "job", "id": j["id"], "title": j["label"], "body": "", "f": c["f"], "t": j["start"], "fin": j["fin"],
                    "status": j["status"] or ("running" if j["running"] else ""), "running_now": j["running"], "key": j["key"],
                    "refs": set(c["refs"]) | {j["id"]}, "br": c["br"], "lane": c["lane"]})
    if new: _save_cache(cp, cache)
    return out


def _save_cache(cp, cache):
    try: tmp = f"{cp}.{os.getpid()}"; json.dump(cache, open(tmp, "w")); os.replace(tmp, cp)
    except OSError: pass


def src_backlog():
    out = []
    for it in D._backlog():
        lab = str(it.get("label") or ""); task = D.base_task(str(it.get("task") or ""))[:TASK_CHARS]
        out.append({"kind": "backlog", "id": lab[:70], "title": lab, "body": task, "t": time.time(), "refs": refs_in(task[:1500]),
                    "lane": lane_of(lab), "raw": (lab, it.get("task"))})
    return out


def src_decisions():
    text = _git("show", "origin/ext/agent-briefs:briefs/DECISIONS.md")
    out = []; head = None; body = []
    for l in text.splitlines() + ["## end"]:
        if l.startswith("## "):
            if head: out.append({"kind": "decision", "id": head[:70], "title": head, "body": "\n".join(body)[:1500], "t": 0, "refs": set(), "lane": ""})
            head, body = l[3:], []
        else: body.append(l)
    return out


def src_mainlog(since):
    out = []; seen = set()
    for l in _git("log", "origin/main", f"--since=@{int(since)}", "--format=%ct%x09%h%x09%s").splitlines():
        try: t, h, s = l.split("\t", 2)
        except ValueError: continue
        if s.startswith("Merge main into") or s.startswith("Merge branch") or s.startswith("Merge remote") or s.startswith("Merge origin"): continue
        m = re.match(r"Merge pull request #(\d+) from \S+?/(ext/\S+)", s)
        k = m.group(2) if m else s[:80]
        if k in seen: continue
        seen.add(k)
        title = (m.group(2)[4:].replace("-", " ") if m else s)
        out.append({"kind": "main", "id": f"main {h}", "title": title, "body": "", "t": int(t), "refs": refs_in(s), "lane": lane_of(m.group(2) if m else ""),
                    "head": s[:120]})
    return out


def load_state(now=None, live=True):
    now = now or time.time(); since = now - DAYS * 86400
    items = src_branches(live) + src_ready(since, live) + src_jobs(since) + (src_backlog() if live else []) + src_decisions() + src_mainlog(since)
    for it in items:
        if "f" not in it: it["f"] = feats(it["title"], it["body"])
    df = collections.Counter()
    for it in items: df.update(it["f"].keys())
    return {"items": items, "df": df, "n": max(1, len(items)), "now": now}


# ---- scoring ----------------------------------------------------------------------------------------------------------
def qweights(label, task, st):
    """Query feature weights: idf x (2 in the label) x (1.5 concept); boilerplate (df > 4%) dropped; top 40."""
    title = unprefix(label or "")
    body = D.base_task(task or "")[:TASK_CHARS]
    body = OVERRIDE_RX.sub("", body)
    f = feats(title or body.split("\n", 1)[0][:200], body)
    n = st["n"]; w = {}
    for k, v in f.items():
        d = st["df"].get(k, 0)
        if d > 0.04 * n: continue
        w[k] = math.log(n / (1 + d)) * (2.0 if v == 1.0 else 1.0) * (1.5 if k.startswith("c:") else 1.0)
    return dict(sorted(w.items(), key=lambda x: -x[1])[:40])


def acknowledged(label, task, st, t):
    """Refs the task names (Builds on / ext names / job ids), plus its own lineage: earlier jobs with the same key and their branches."""
    ack = refs_in(task or "") | refs_in(label or "")
    k = D.norm_key(label)
    for it in st["items"]:
        if it["kind"] == "job" and it["t"] <= t and D.key_match(k, it.get("key", "")):
            ack.add(it["id"]); ack |= {r for r in it["refs"] if r.startswith("ext/")}
    for it in st["items"]:   # a named job id acknowledges the branch that job pushed
        if it["kind"] == "job" and it["id"] in ack and it.get("br", "").startswith("ext/"): ack.add("ext/" + base_branch(it["br"][4:]))
    return ack


def active(it, t, branch_names):
    if it["kind"] == "job": return it["t"] <= t and (it["fin"] is None and it["running_now"] or (it["fin"] is not None and it["fin"] > t))
    if it["kind"] == "branch": return t - ACTIVE_H * 3600 <= it["t"] <= t + 60
    if it["kind"] == "ready":
        b = base_branch(it["id"][4:]); mt = branch_names.get(b)
        return it["t"] <= t and b in branch_names and (mt is None or mt > t)
    return False


def search(label, task, st=None, t=None, exclude=(), top=TOP):
    """Scored matches, best first: dict(kind,id,score,why,high,active,status,title)."""
    st = st or load_state(); t = t or st["now"]
    qw = qweights(label, task, st)
    if not qw: return []
    denom = sum(sorted(qw.values(), reverse=True)[:6]) or 1.0
    qlane = lane_of(unprefix(label or ""))
    qtitle_c = {k for k, v in qw.items() if k.startswith("c:")}
    qf = feats(unprefix(label or ""), "")
    qtitle_c = {k for k in qtitle_c if qf.get(k) == 1.0} or {k for k in qtitle_c if not label}
    qarea = AREA & concepts(toks(re.sub(r"^(\s*\[[^\]]*\])+", "", unprefix(label))))
    ack = acknowledged(label, task, st, t)
    bnames = st.get("_bn")
    if bnames is None:   # branch family -> epoch it was merged into main (None = not merged); present now or merged since
        bnames = {base_branch(it["id"][4:]): None for it in st["items"] if it["kind"] == "branch"}
        for it in st["items"]:
            if it["kind"] == "main":
                for r in it["refs"]:
                    if r.startswith("ext/"): bnames[r[4:]] = it["t"]
        st["_bn"] = bnames
    k = D.norm_key(label); out = []
    for it in st["items"]:
        if it["t"] > t + 60 or it["id"] in exclude: continue
        if it["kind"] == "job" and (D.key_match(k, it.get("key", "")) or it["id"] in ack): continue
        if it["kind"] in ("branch", "ready", "note") and it["refs"] & ack: continue
        if it["kind"] == "main" and it["refs"] & ack: continue
        sh = [(f, qw[f] * v) for f, v in it["f"].items() if f in qw]
        if not sh: continue
        s = 100.0 * sum(x for _, x in sh) / denom
        if s < LOW_SCORE: continue
        sh.sort(key=lambda x: -x[1])
        sys_c = [f for f in qtitle_c if it["f"].get(f) == 1.0 and f[2:] not in BROAD]   # a broad area (boss, tutorial...) never refuses
        lane_ok = not (qlane and it["lane"] and qlane != it["lane"] and (qlane in PRESENT_LANES or it["lane"] in PRESENT_LANES)) \
            and not (qlane in PRESENT_LANES and not it["lane"]) and not (it["lane"] in PRESENT_LANES and not qlane)
        act = active(it, t, bnames)
        area_ok = not (qarea - {f[2:] for f in it["f"] if f.startswith("c:")})   # bot/tutorial/camp work on a system is not that system's rework
        high = bool(act and sys_c and lane_ok and area_ok and s >= HIGH_SCORE)
        why = "shares " + ", ".join((f[2:] + " (concept)") if f.startswith("c:") else f for f, _ in sh[:5])
        out.append({"kind": it["kind"], "id": it["id"], "score": round(min(s, 100)), "why": why, "high": high, "active": act,
                    "status": it.get("status") or ("running" if it["kind"] == "job" and act else ""), "title": (it.get("head") or it["title"])[:110],
                    "system": [f[2:] for f in sys_c]})
    out.sort(key=lambda m: (-m["high"], -m["score"]))
    seen = set(); res = []
    for m in out:   # one line per branch family (branch + its READY post + its -rebased copy)
        fam = base_branch(m["id"][4:]) if m["id"].startswith("ext/") else m["id"]
        if fam in seen: continue
        seen.add(fam); res.append(m)
    return res[:top] if top else res


def overrides(task):
    return [(m.group(1).lower(), m.group(2).strip()) for m in OVERRIDE_RX.finditer(task or "")]


def _desc(m):
    st = f", {m['status']}" if m["status"] else ""
    return f"{m['kind']} {m['id']} (score {m['score']}{st}{', ACTIVE' if m['active'] else ''}): {m['why']}"


def decide(label, task, st=None, t=None, exclude=()):
    """(code, refusal, prompt_block, matches). code 75 = HIGH overlap refused (no Builds on / Not a dupe line)."""
    if EXEMPT_RX.match(D.norm_key(label)): return 0, "", "", []
    ms = search(label, task, st, t, exclude=exclude)
    hi = [m for m in ms if m["high"]]
    ov = overrides(task)
    if hi and not ov:
        sysn = ", ".join(sorted({c for m in hi for c in m["system"]}))
        return REFUSE, (f"prior work on the same system ({sysn}): " + "; ".join(_desc(m) for m in hi[:3])
                        + ". Add a line 'Builds on: <ids>' or 'Not a dupe: <reason>' to the task, or claude-job start --redo \"<reason>\""), "", ms
    if not ms: return 0, "", "", ms
    block = ("PRIOR WORK FOUND (prior-work, score 0-100):\n" + "\n".join("- " + _desc(m) for m in ms[:TOP])
             + "\nCheck these first. Build on them; if your task is already done, stop with status skipped and name the branch (DUPE-OF <id>).\n")
    return 0, "", block, ms


def gate(label, task, by="", st=None, log=True, redo=""):
    """Live gate for claude-job start / pacer / refill / queue. Logs PRIORWORK lines to $CJ_DIR/dedup.log.
    redo: claude-job start --redo "<reason>": a refusal is logged as PRIORWORK REDO and the matches still go into the prompt."""
    try: code, why, block, ms = decide(label, task, st)
    except Exception as e: return 0, "", ""   # the gate never blocks a start by crashing
    if code and redo:
        if log: D.log(f"PRIORWORK REDO by={by or '?'} [{(label or '')[:70]}] reason: {redo[:200]} | {why[:300]}")
        block = ("PRIOR WORK FOUND (prior-work, score 0-100; started anyway with --redo: " + redo[:200] + "):\n"
                 + "\n".join("- " + _desc(m) for m in ms[:TOP]) + "\nRead these first and build on them; do not redo what they already did.\n")
        return 0, why, block
    if log:
        if code: D.log(f"PRIORWORK REFUSE {code} by={by or '?'} [{(label or '')[:70]}] {why[:400]}")
        elif block: D.log(f"PRIORWORK FOLD by={by or '?'} [{(label or '')[:70]}] {len(ms)} match(es), top {ms[0]['kind']} {ms[0]['id']} ({ms[0]['score']})"
                          + (f" override: {overrides(task)[0][0]}" if overrides(task) else ""))
    return code, why, block


# ---- dry-run ----------------------------------------------------------------------------------------------------------
def dryrun(hours, sample, seed, only=(), verbose=False, out=""):
    now = time.time(); st = load_state(now, live=False)
    starts = [it for it in st["items"] if it["kind"] == "job" and it["t"] >= now - hours * 3600]
    if only: starts = [it for it in starts if it["id"] in only]
    res = []
    for j in starts:
        J = os.path.join(cj_dir(), j["id"]); task = D._rd(J, "task", 12000)
        code, why, block, ms = decide(j["title"], task, st, j["t"] - 1, exclude={j["id"]})
        res.append((j, code, why, ms, EXEMPT_RX.match(D.norm_key(j["title"])) is not None))
    real = [r for r in res if not r[4]]
    if out:   # one JSON line per start, for offline tuning
        with open(out, "w") as f:
            for j, code, why, ms, ex in res:
                f.write(json.dumps({"id": j["id"], "label": j["title"], "status": j["status"], "exempt": ex, "code": code, "why": why[:400],
                                    "ms": [{k: m[k] for k in ("kind", "id", "score", "high", "active", "system", "why")} for m in ms[:4]]}) + "\n")
    ref = [r for r in real if r[1]]; fl = [r for r in real if not r[1] and r[3]]
    print(f"{len(res)} starts in {hours:g} h ({len(res) - len(real)} exempt chores); real {len(real)}: refused {len(ref)}, flagged (prompt block) {len(fl)}, clean {len(real) - len(ref) - len(fl)}")
    if only or verbose:
        for j, code, why, ms, ex in res:
            print(f"  {j['id']} [{j['title'][:60]}] -> {'REFUSE ' + why[:300] if code else 'exempt' if ex else ('flag: ' + '; '.join(_desc(m)[:120] for m in ms[:3])) if ms else 'clean'}")
    if sample:
        rnd = random.Random(seed); pick = rnd.sample(real, min(sample, len(real)))
        r2 = [r for r in pick if r[1]]
        print(f"sample of {len(pick)} random real starts (seed {seed}): refused {len(r2)}, flagged {sum(1 for r in pick if not r[1] and r[3])}")
        for j, code, why, ms, _ in pick:
            print(f"  {'REFUSE' if code else 'flag  ' if ms else 'clean '} {j['id']} {j['status'] or '':8} [{j['title'][:55]}]" + (f" -> {why[:220]}" if code else f" -> {_desc(ms[0])[:150]}" if ms else ""))
    return res


def main(argv):
    if argv and argv[0] in ("gate", "dryrun"): cmd, argv = argv[0], argv[1:]
    else: cmd = "search"
    ap = argparse.ArgumentParser(prog="prior-work", description=__doc__.split("\n")[0])
    ap.add_argument("--label", default=""); ap.add_argument("--task"); ap.add_argument("--task-file"); ap.add_argument("--by", default=""); ap.add_argument("--redo", default="")
    ap.add_argument("--top", type=int, default=8); ap.add_argument("--json", action="store_true")
    ap.add_argument("--hours", type=float, default=48); ap.add_argument("--sample", type=int, default=30); ap.add_argument("--seed", type=int, default=1112)
    ap.add_argument("--job", nargs="*", default=[]); ap.add_argument("-v", action="store_true"); ap.add_argument("--out", default=""); ap.add_argument("text", nargs="*")
    a = ap.parse_args(argv)
    if cmd == "dryrun": dryrun(a.hours, a.sample, a.seed, set(a.job), a.v, a.out); return 0
    task = a.task if a.task is not None else open(a.task_file).read() if a.task_file else " ".join(a.text)
    if cmd == "gate":
        code, why, block = gate(a.label, task, by=a.by, redo=a.redo)
        if a.redo and why: print(f"claude-job: --redo past the prior-work gate ({a.redo[:80]}): {why[:300]}", file=sys.stderr)
        if code: print(f"claude-job: prior work found, start refused (exit {code}): {why}", file=sys.stderr); return code
        sys.stdout.write(block); return 0
    ms = search(a.label or task.split("\n", 1)[0][:120], task, top=a.top)
    if a.json: print(json.dumps(ms, indent=1)); return 0
    if not ms: print("no prior work found"); return 0
    for m in ms: print(f"{m['score']:3d} {'HIGH ' if m['high'] else ''}{_desc(m)[:220]}")
    return 0


if __name__ == "__main__": sys.exit(main(sys.argv[1:]))
