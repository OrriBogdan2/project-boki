"""Unit test: regate-bot skips a re-gate when (PR head, main) equals the last gated pair. Run: python3 test_regate_pair.py"""
import importlib.machinery, importlib.util, os, sys, tempfile
from pathlib import Path
os.environ["REGATE_STATE"] = tempfile.mkdtemp()
HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
ld = importlib.machinery.SourceFileLoader("rb", str(HERE / "regate-bot"))
rb = importlib.util.module_from_spec(importlib.util.spec_from_loader("rb", ld)); ld.exec_module(rb)
H, M, M2 = "a" * 40, "b" * 40, "c" * 40
f = dict(pr=7, head=H, main=M)
st = {}
assert rb.pair_seen(st, 7, H, M, []) == "", "never gated -> gate"
rb.note_pair(st, f, "GREEN")
assert "already gated (GREEN)" in rb.pair_seen(st, 7, H, M, []), "same pair after GREEN -> skip"
assert rb.pair_seen(st, 7, H, M2, []) == "", "main moved -> gate"
assert rb.pair_seen(st, 7, "d" * 40, M, []) == "", "head moved -> gate"
assert rb.pair_seen(st, 8, H, M, []) == "", "other PR -> gate"
st = {}
rb.note_pair(st, f, "ERROR")
assert rb.pair_seen(st, 7, H, M, []) == "", "one error try -> retry allowed"
rb.note_pair(st, f, "TIMEOUT")
assert "tried 2x" in rb.pair_seen(st, 7, H, M, []), "2 tries -> stop"
rb.note_pair(st, dict(pr=7, head=H, main=M2), "ERROR")
assert rb.pair_seen(st, 7, H, M, []) == "", "pair replaced by the newer main"
st = {}
rb.note_pair(st, f, "MOVED"); rb.note_pair(st, dict(f, train=1), "RED")
assert not st.get("pairs"), "MOVED and train entries are not recorded"
tag = lambda h, m: {"body": f"REGATE RED x [regate-bot pr=7 head={h[:10]} main={m[:10]}]"}
assert "regate-bot comment" in rb.pair_seen({}, 7, H, M, [tag(H, M)]), "comment tag for the same pair -> skip"
assert rb.pair_seen({}, 7, H, M, [tag(H, M2)]) == "", "tag with another main -> gate"
print("regate pair test: OK")
