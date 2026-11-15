"""Stall watchdog + bounded reaper of suite_speed.py (11-14: regate #57/#59 hung 155 min inside a run's cleanup).
Run: python3 ops/regate-bot/test_suite_speed_stall.py"""
import importlib.util
import os
import subprocess
import sys
import tempfile
import time
import types
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location("suite_speed", HERE / "suite_speed.py")
ss = importlib.util.module_from_spec(spec)
spec.loader.exec_module(ss)


def gate(out, jobs=2, stall_min=0.05):
    a = types.SimpleNamespace(main=out, merge=out, out=out, jobs=jobs, stall_min=stall_min, godot="godot", timeout=5,
                              godot_args="", alert_file=str(Path(out) / "ALERT"), main_lazy=False, no_cache=True,
                              timeout_strikes=2)
    return ss.Gate(a)


class StallTest(unittest.TestCase):
    def setUp(self):
        self._run_flag = ss.run_flag

    def tearDown(self):
        ss.run_flag = self._run_flag

    def test_hung_run_stops_the_gate_with_a_reason(self):
        with tempfile.TemporaryDirectory() as d:
            g = gate(d)
            ss.run_flag = lambda godot, tree, flag, timeout, extra, on_start=None: (
                {"flag": flag, "rc": 0, "secs": 0.1, "verdict": "green", "mismatch": False, "log": "ok"}
                if flag == "--fast" else time.sleep(600))
            t0 = time.time()
            with self.assertRaises(ss.GateStalled):
                g.run_many([("merge", d, "--fast"), ("merge", d, "--hangs")], "body-x")
            self.assertLess(time.time() - t0, 30)
            self.assertIn("STALLED", (Path(d) / "summary.txt").read_text())
            self.assertIn("python threads", (Path(d) / "stall.txt").read_text())
            self.assertIn("STALLED", (Path(d) / "ALERT").read_text())

    def test_healthy_gate_is_untouched(self):
        with tempfile.TemporaryDirectory() as d:
            g = gate(d)
            ss.run_flag = lambda godot, tree, flag, timeout, extra, on_start=None: (
                time.sleep(0.2) or {"flag": flag, "rc": 0, "secs": 0.2, "verdict": "green", "mismatch": False, "log": "ok"})
            g.run_many([("merge", d, f"--f{i}") for i in range(10)], "x")
            self.assertEqual(len(g.res["merge"]), 10)

    def test_reaper_kills_a_detached_leftover_and_is_bounded(self):
        mark = f"XDG_DATA_HOME=/tmp/suite-test-{os.getpid()}/data"
        env = dict(os.environ, XDG_DATA_HOME=mark.split("=", 1)[1])
        p = subprocess.Popen(["sleep", "300"], env=env, start_new_session=True)
        time.sleep(0.3)
        t0 = time.time()
        n = ss.reap_marked(mark.encode())
        p.wait(10)
        self.assertEqual(n, 1)
        self.assertLess(time.time() - t0, ss.REAP_S)

    def test_run_flag_with_a_stub_engine_and_helper_left_behind(self):
        with tempfile.TemporaryDirectory() as d:
            stub = Path(d) / "godot"  # "engine" that leaves a setsid'd helper holding its env, then runs past the timeout
            stub.write_text("#!/bin/sh\nsetsid sleep 300 &\nsleep 60\n")
            stub.chmod(0o755)
            t0 = time.time()
            r = ss.run_flag(str(stub), d, "--x-check", 2, [])
            self.assertEqual(r["rc"], 124)
            self.assertEqual(r["verdict"], "red")
            self.assertLess(time.time() - t0, 25)
            time.sleep(0.5)
            left = subprocess.run(["pgrep", "-f", "^sleep 300$"], capture_output=True, text=True).stdout.split()
            for pid in left:  # only ours: the helper carries this run's XDG_DATA_HOME; none may have survived the run
                self.assertNotIn(f"suite-", Path(f"/proc/{pid}/environ").read_text(errors="ignore")
                                 if Path(f"/proc/{pid}/environ").exists() else "")


if __name__ == "__main__":
    unittest.main()
