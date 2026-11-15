"""Offline test of regate_carry on a throwaway git repo (no network, no godot). Run: python3 test_regate_carry.py"""
import os, subprocess, sys, tempfile
from pathlib import Path
os.environ["REGATE_STATE"] = tempfile.mkdtemp()
sys.path.insert(0, str(Path(__file__).resolve().parent))
import regate_carry as rc

T = tempfile.mkdtemp()
import regate_common; rc.REPO = regate_common.REPO = T
def g(*a):
    return subprocess.run(["git", "-C", T, *a], capture_output=True, text=True, env=rc.ENV, check=True).stdout.strip()
def commit(name, text, msg):
    (Path(T) / name).write_text(text); g("add", name); g("commit", "-qm", msg); return g("rev-parse", "HEAD")
g("init", "-q", "-b", "main"); g("config", "user.email", "t@t"); g("config", "user.name", "t")
base = commit("a.txt", "a\n", "base"); commit("b.gd", "1\n2\n3\n4\n5\n6\n7\n8\n9\n", "base b"); base = g("rev-parse", "HEAD")
g("checkout", "-qb", "pr"); (Path(T) / "b.gd").write_text("X\n2\n3\n4\n5\n6\n7\n8\n9\n"); g("add", "b.gd"); pr = commit("pr.txt", "pr\n", "pr")
g("checkout", "-q", "main"); m1 = commit("m1.txt", "m1\n", "main 1")
rc.selected = lambda gated, commit: []                       # no check reads main's delta
ok, why, c = rc.carry_check(pr, pr, m1)
assert ok and c and g("rev-parse", c + "^1") == pr and g("rev-parse", c + "^2") == m1, (ok, why)
assert g("show", c + ":pr.txt") == "pr" and g("show", c + ":m1.txt") == "m1"
rc.selected = lambda gated, commit: None                     # a check is fed -> never carried
assert not rc.carry_check(pr, pr, m1)[0]
rc.selected = lambda gated, commit: []
m2 = commit("b.gd", "1\n2\n3\n4\n5\n6\n7\n8\nY\n", "main touches b.gd")   # same file, clean merge
ok, why, _ = rc.carry_check(pr, pr, m2); assert not ok and "both" in why, why
g("checkout", "-qb", "c1", base); (Path(T) / "x.txt").write_text("1\n"); g("add", "x.txt"); g("commit", "-qm", "c1"); c1 = g("rev-parse", "HEAD")
g("checkout", "-q", "main"); m3 = commit("x.txt", "2\n", "main x")                  # conflict
ok, why, _ = rc.carry_check(c1, c1, m3); assert not ok and ("conflict" in why or "both" in why), why
assert rc.merge_tree(c1, m3) is None
# 11-15 per-check rule: checks seeing main's delta (X) vs the PR's delta (Y)
sel = {}
rc.selected = lambda old, commit: sel[old == pr]
sel.update({True: ["--a-check"], False: ["--b-check"]}); assert rc.carry_check(pr, pr, m1)[0]
sel.update({True: ["--a-check"], False: ["--a-check", "--b-check"]}); ok, why, _ = rc.carry_check(pr, pr, m1)
assert not ok and "both" in why, why
sel.update({True: ["--a-check"], False: None}); assert not rc.carry_check(pr, pr, m1)[0]
sel.update({True: None, False: []}); assert not rc.carry_check(pr, pr, m1)[0]
# fallback merge (git < 2.38): same tree as --write-tree would give, conflicts -> None
real = rc.run
rc.run = lambda cmd, **kw: (129, "", "error: unknown option `write-tree'\nusage: git merge-tree") if "--write-tree" in cmd else real(cmd, **kw)
t = rc.merge_tree(pr, m1); assert t and g("ls-tree", "--name-only", t).split() == ["a.txt", "b.gd", "m1.txt", "pr.txt"], t
assert rc.merge_tree(c1, m3) is None
rc.run = real
# cache: key stable, GREEN only
ct, mt = rc.keys_for(pr, m1); assert ct and mt and rc.cache_get(ct, mt) is None
rc.cache_put(ct, mt, "RED"); assert rc.cache_get(ct, mt) is None
rc.cache_put(ct, mt, "GREEN", pr=1); assert rc.cache_get(ct, mt)["result"] == "GREEN"
assert rc.keys_for(c, m1)[0] == g("rev-parse", c + "^{tree}")  # head already holds main -> own tree
# train: chain keeps both PRs, drops a conflicting one
g("checkout", "-qb", "pr2", base); p2 = commit("pr2.txt", "2\n", "pr2")
g("checkout", "-q", "main"); g("checkout", "-qb", "m-old", m1)
plan = rc.train_plan([dict(pr=1, head=pr), dict(pr=2, head=p2), dict(pr=3, head=c1)], m3)
assert [r["pr"] for r, _, _ in plan] == [1, 2], plan
tip = plan[-1][1]
assert all(g("show", tip + ":" + f) for f in ("pr.txt", "pr2.txt", "m1.txt", "x.txt"))
import re as _re
eng = (Path(__file__).resolve().parent / "suite_speed.py").read_text()
assert rc.INERT.pattern in eng.replace("\\\\", "\\") or rc.INERT.pattern == _re.search(r'INERT = re.compile\(\s*r"(.*?)"', eng, _re.S).group(1), "INERT drifted from suite_speed.py"
print("test_regate_carry: ok")
