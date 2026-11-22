"""Absolute gate checks (tools/gate_absolute.txt): a red there fails the gate even when main is red too.
Run: python3 ops/regate-bot/test_suite_speed_absolute.py"""

import importlib.util
import tempfile
import types
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location("suite_speed", HERE / "suite_speed.py")
ss = importlib.util.module_from_spec(spec)
spec.loader.exec_module(ss)


def res(flag, verdict):
    return {"flag": flag, "rc": 0 if verdict == "green" else 1, "secs": 1.0, "verdict": verdict, "mismatch": False}


class AbsoluteTest(unittest.TestCase):
    def test_list_file_parsing(self):
        with tempfile.TemporaryDirectory() as d:
            self.assertEqual(ss.absolute_flags(d), [])
            (Path(d) / "tools").mkdir()
            (Path(d) / "tools/gate_absolute.txt").write_text("# note\n--a-check  # why\n\n--b-check\n")
            self.assertEqual(ss.absolute_flags(d), ["--a-check", "--b-check"])

    def test_red_on_both_is_a_fail_only_for_absolute(self):
        with tempfile.TemporaryDirectory() as d:
            a = types.SimpleNamespace(
                main=d,
                merge=d,
                out=d,
                jobs=1,
                stall_min=1,
                godot="godot",
                timeout=5,
                godot_args="",
                alert_file=str(Path(d) / "ALERT"),
                main_lazy=False,
                no_cache=True,
                timeout_strikes=2,
                order="registry",
            )
            g = ss.Gate(a)
            g.main_flags = {"--abs-check", "--other-check"}
            g.absolute = ["--abs-check"]
            g.cache = None
            for side in ("main", "merge"):
                g.res[side] = {"--abs-check": res("--abs-check", "red"), "--other-check": res("--other-check", "red")}
            self.assertEqual(g.summary(["--abs-check", "--other-check"], "full"), 1)
            text = (Path(d) / "summary.txt").read_text()
            self.assertIn("NEW-RED (absolute check, red on merge) 1: --abs-check", text)
            g.absolute = []
            self.assertEqual(g.summary(["--abs-check", "--other-check"], "full"), 0)


if __name__ == "__main__":
    unittest.main()
