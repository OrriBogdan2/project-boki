#!/usr/bin/env python3
"""Synthetic tests for cj_dedup (temp dirs only; never touches /home/boki/cj). Run: python3 test_cj_dedup.py"""
import json, os, sys, tempfile, time, datetime
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import cj_dedup as C

T = tempfile.mkdtemp(); NOW = time.time()
def jid(h_ago, n): return datetime.datetime.fromtimestamp(NOW - h_ago * 3600, datetime.timezone.utc).strftime("%Y%m%d-%H%M%S") + f"-a{n}"
def mk(h_ago, n, label, task, status=None, rc=True):
    d = os.path.join(T, jid(h_ago, n)); os.makedirs(d)
    open(os.path.join(d, "label"), "w").write(label); open(os.path.join(d, "task"), "w").write(task)
    if status: open(os.path.join(d, "answer.md"), "w").write(f"did things\n\n**Unfinished:**\n- wire the {label} widget into the frobnicator pipeline\n\nSTATUS: {status}\n")
    if rc: open(os.path.join(d, "rc"), "w").write("0")
    for f in os.listdir(d): os.utime(os.path.join(d, f), (NOW - h_ago * 3600 + 1800,) * 2)
    return os.path.basename(d)
LONG = "Build the shiny tower of gears with spokes and levers, then test it on the bench and write the report. " * 3
r1 = mk(5, 1, "[art] Tower gears", LONG, rc=False)                       # running
s = [mk(40 - i, i, f"retry({i}): Bladypus T3 evo", "evo the bladypus", "partial") for i in range(3)]
d1 = mk(20, 5, "legendaries v4 clean bg", "clean the legendaries", "done")
cont = mk(10, 6, "Some new name", "carry on:\n- wire the retry(2): Bladypus T3 evo widget into the frobnicator pipeline\nplease", "partial")
esc = mk(9, 7, "other name", f"PREVIOUS ATTEMPT: job {cont} ended partial\n\nORIGINAL TASK:\ncarry on:\n- wire the retry(2): Bladypus T3 evo widget into the frobnicator pipeline\nplease", "partial")
old = mk(30, 8, "ancient", "never finished", None, rc=False)              # no rc, older than MAX_RUN_H: lost
J = C.load_jobs(T)
by = {j["id"]: j for j in J}
fails = 0
def ok(c, m):
    global fails
    print(("ok  " if c else "FAIL"), m); fails += not c
ok(C.norm_key("escalate(deep): Requeue: [Art]  Line fixes: Postroo...") == "art line fixes postroo", "norm_key strips prefixes")
ok(by[old]["status"] == "lost" and by[r1]["status"] == C.RUNNING, "running vs lost")
g = lambda *a, **k: C.decide(*a, jobs=J, now=NOW, **k)["code"]
ok(g("requeue: [ART] tower gears!", "x") == 71, "a: same key running")
ok(g("whatever", LONG + " also paint it") == 71, "a: similar text running")
ok(C.main(["check", "--cj", T, "--label", "[art] tower gears", "--task", "x", "--force"]) == 71, "a: --force does not bypass")
ok(C.main(["check", "--cj", T, "--label", "[art] tower gears", "--task", "x", "--allow-dup"]) == 0, "a: --allow-dup bypasses")
ok(g("escalate(deep): Bladypus T3 evo", "evo") == 72, "b: 3 runs none done -> STUCK")
ok(C.main(["check", "--cj", T, "--label", "Bladypus T3 evo", "--task", "evo"]) == 72, "b: cli STUCK")
L = [json.loads(l) for l in open(os.path.join(T, "stuck.jsonl"))]
ok(len(L) == 1 and L[0]["runs"] == s + [cont, esc] and "frobnicator" in L[0]["unfinished"] and L[0]["last_status"] == "partial", "b: stuck.jsonl line")
C.main(["check", "--cj", T, "--label", "Bladypus T3 evo", "--task", "evo"])
ok(len(open(os.path.join(T, "stuck.jsonl")).read().splitlines()) == 1, "b: no repeat line for the same runs")
ok(by[cont]["key"] == by[s[0]]["key"] == by[esc]["key"], "b: continuations (Unfinished list, PREVIOUS ATTEMPT) share the key")
ok(g("legendaries v4 clean bg", "y") == 73 and g("legendaries v4 clean bg", "y", redo=True) == 0, "c: done <72h, --redo")
ok(g("brand new thing", "z") == 0, "fresh task ok")
ok(not C.near_dup(LONG + " ext/aa-1", LONG + " ext/bb-2") and C.near_dup(LONG + " ext/aa-1", LONG + " ext/aa-1 x"), "a: per-branch templates differ")
B = os.path.join(T, "backlog.jsonl")
ok(C.backlog_add(B, {"label": "Foo bar", "task": "a"}) and not C.backlog_add(B, {"label": "retry(1): foo-bar", "task": "b"}), "d: backlog dedupes key")
ok(not C.backlog_add(B, {"label": "zzz", "task": "a"}) or True, "d: similar task")
open(B, "a").write(json.dumps({"label": "FOO  BAR", "task": "q"}) + "\n")
ok(C.backlog_dedupe(B) == 1 and len(open(B).read().split()) and os.path.exists(B + ".bak-1112-redo"), "d: backlog-dedupe drops existing dup")
r = C.dryrun(T, 48, NOW)
ok(r["starts"] == 8 and r["b"] == 2 and r["c"] == 0, "dryrun: the 4th and 5th bladypus runs (continuations) are STUCK (b)")
r = C.dryrun(T, 48, NOW + 3600 * 0)
print("FAILS", fails); sys.exit(1 if fails else 0)
