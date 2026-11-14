"""Offline test of regate-bot's scan + in-flight state machine: fake GH, real git objects of project-boki.
Run: python3 test_regate_bot.py (needs ~/project-boki with origin/main and PR #29's head 2183d5ae04 fetched)."""
import importlib.machinery, importlib.util, os, sys, tempfile, time
from pathlib import Path
os.environ["REGATE_STATE"] = tempfile.mkdtemp()
HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
ld = importlib.machinery.SourceFileLoader("rb", str(HERE / "regate-bot"))
rb = importlib.util.module_from_spec(importlib.util.spec_from_loader("rb", ld)); ld.exec_module(rb)
import regate_common as rc

MAIN = rc.git("rev-parse", "origin/main"); H29 = rc.git("rev-parse", "2183d5ae04")
P29 = rc.git("rev-parse", H29 + "~1")
old = lambda m: rc.iso(time.time() - m * 60)

def pr(n, head, branch="ext/x", created="2026-11-01T00:00:00Z"):
    r = {"full_name": rc.SLUG}
    return {"number": n, "head": {"ref": branch, "sha": head, "repo": r}, "base": {"repo": r}, "created_at": created}

def c(body, mins=60, user="OrriBogdan2"):
    return {"body": body, "created_at": old(mins), "user": {"login": user}}

class FakeGH:
    live = True
    def __init__(s, prs, cs): s.prs, s.cs, s.posted = prs, cs, []
    def login(s): return "OrriBogdan2"
    def open_prs(s): return s.prs
    def comments(s, n): return s.cs.get(n, [])
    def pr(s, n): return s.state
    def post(s, n, body, dry=False): s.posted.append((n, body)); return "posted"

rb.git = lambda *a, **k: H29 if a[:2] == ("rev-parse", "refs/regate/pr/1") or a[:2] == ("rev-parse", "refs/regate/pr/2") \
    or a[:2] == ("rev-parse", "refs/regate/pr/3") or a[:2] == ("rev-parse", "refs/regate/pr/4") or a[:2] == ("rev-parse", "refs/regate/pr/6") \
    else (MAIN if a[:2] == ("rev-parse", "refs/regate/pr/5") else ("" if a[0] == "fetch" else rc.git(*a, **k)))
rb.args = type("A", (), {"dry": False, "pr": 0, "ignore_owner": False})()
G = f"GATE GREEN {H29[:10]}: ok"
gh = FakeGH([pr(1, H29), pr(2, H29), pr(3, H29), pr(4, H29), pr(5, MAIN), pr(6, H29, "feature/x")], {
    1: [c(G, 90)],                                                          # -> regate
    2: [c("merge-driver-1114 owns this PR until merged.\n\n" + G, 90)],     # owner running (rpc7 has its prompt, no rc)
    3: [c(G, 90), c(f"REGATE RED {H29}: x [regate-bot pr=3 head={H29[:10]} main=abc]", 30)],
    4: [c(f"GATE GREEN {P29[:10]}: older head", 90)],                       # head has ungated commits
    5: [c(G, 90)],                                                          # contains main
})
main, rows = rb.scan(gh, {})
got = {r["pr"]: (r["verdict"], r["why"]) for r in rows}
for k, v in sorted(got.items()): print(k, v)
assert main == MAIN and got[1][0] == "regate" and "owned by merge-driver-1114" in got[2][1]
assert "already posted" in got[3][1] and "ungated commits" in got[4][1] and "contains origin/main" in got[5][1]
assert "not an ext/*" in got[6][1]
gh.cs[1].append(c("a human note", 5)); _, rows = rb.scan(gh, {})
assert [r for r in rows if r["pr"] == 1][0]["why"].startswith("live"), "20 min quiet rule"
# in-flight state machine with a local fake run dir
out = Path(tempfile.mkdtemp())
st = {"inflight": dict(pr=1, branch="ext/x", head=H29, gated=H29, main=MAIN, worker="local", ip=None, out=str(out),
                       phase="gating", started=time.time() - 600, main_time=time.time() - 1200)}
assert rb.step_inflight(gh, st) is True and not gh.posted, "no result yet -> keeps blocking"
(out / "comment.md").write_text(f"GATE GREEN {'b' * 40}: summary"); (out / "result").write_text(f"GREEN {'b' * 40}\n")
assert rb.step_inflight(gh, st) is True and gh.posted[-1][1].startswith("GATE GREEN bbbb") and st["inflight"]["phase"] == "awaiting_merge"
gh.state = {"merged_at": rc.iso(time.time()), "state": "closed", "head": {"sha": "b" * 40}}
assert rb.step_inflight(gh, st) is False and "inflight" not in st, "merged -> next PR may start"
st = {"inflight": dict(st_ := dict(pr=4, branch="ext/x", head=H29, gated=H29, main=MAIN, worker="local", ip=None, out=str(out),
                                   phase="gating", started=time.time(), main_time=time.time()))}
(out / "comment.md").write_text(f"REGATE CONFLICT {H29}: a.gd"); (out / "result").write_text("CONFLICT a.gd\n")
assert rb.step_inflight(gh, st) is False and gh.posted[-1][1].startswith("REGATE CONFLICT")
print("regate-bot offline test: OK")
