"""Offline test of gh-outbox-relay: fake GH, temp ~/cj; posts only a current-head GATE GREEN, once."""
import importlib.machinery, importlib.util, sys, tempfile
from pathlib import Path
H = Path(__file__).resolve().parent; sys.path.insert(0, str(H))
import regate_common as rc
cj = Path(tempfile.mkdtemp()); rc.CJ = cj
ld = importlib.machinery.SourceFileLoader("rl", str(H / "gh-outbox-relay"))
rl = importlib.util.module_from_spec(importlib.util.spec_from_loader("rl", ld)); ld.exec_module(rl)
rl.CJ = cj; rl.POSTED = cj / "gh-outbox-posted.txt"; rl.pull = lambda jobs, dry: None
j = cj / "20261114-053513-a5"; (j / "comments").mkdir(parents=True); (j / "gh-outbox").mkdir()
(j / "prompt").write_text("started on worker rpc7 (x)")
(j / "comments/pr61.md").write_text("merge-driver-1114 owns this PR until merged.\n\nGATE GREEN d187062f44: x")
(j / "comments/pr59.md").write_text("GATE GREEN aaaaaaaaaa: old head")
(j / "gh-outbox/pr51-1.md").write_text("GATE GREEN " + "c" * 40 + ": new")
(j / "gh-outbox/pr51-2.md").write_text("just a draft")
class G:
    live = True; posted = []
    def pr(s, n): return {"state": "open", "head": {"sha": {61: "d187062f44" + "0" * 30, 59: "b" * 40, 51: "c" * 40}[n]}}
    def comments(s, n): return [{"body": "merge-driver-1114 owns this PR until merged.\n\nGATE GREEN d187062f44: x"}] if n == 61 else []
    def post(s, n, body, dry=False): s.posted.append(n); return "posted"
rl.GH = G
a = type("A", (), {"dry": False, "hours": 48})()
rl.main(a); rl.main(a)
print(rl.POSTED.read_text())
assert G.posted == [51], G.posted
print("relay offline test: OK")
