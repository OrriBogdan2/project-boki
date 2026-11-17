"""The real Launcher against fake_server.py: version probe, tokens file, ready/exit events, crashes."""
import json
import os
import sys
import tempfile
import time
import unittest

from helpers import FAKE_SERVER

from mm.launcher import Launcher

CMD = [sys.executable, FAKE_SERVER]


def wait_event(proc, kind: str, timeout: float = 10.0):
    end = time.time() + timeout
    while time.time() < end:
        event = proc.events.get(timeout=timeout)
        if event[0] == kind:
            return event
    raise AssertionError(f"no {kind} event")


class LauncherTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.launcher = Launcher(CMD, self.tmp.name)
        os.environ["FAKE_LIFETIME_S"] = "0.2"
        os.environ.pop("FAKE_CRASH", None)

    def tearDown(self):
        self.launcher.stop_all()
        self.tmp.cleanup()

    def test_version_probe(self):
        os.environ["FAKE_VERSION"] = "1.2.3"
        self.assertEqual(self.launcher.probe_version(), "1.2.3")
        silent = Launcher([sys.executable, "-c", "print('no version here')"], self.tmp.name)
        self.assertEqual(silent.probe_version(), "")
        self.assertEqual(Launcher(["/nonexistent/server"], self.tmp.name).probe_version(), "")

    def test_start_writes_tokens_and_reports_ready_joins_and_exit(self):
        os.environ["FAKE_JOIN_SLOTS"] = "1"
        tokens = {"tokA": {"name": "Ana", "slot": 0, "team": 0}, "tokB": {"name": "Ben", "slot": 1, "team": 1}}
        proc = self.launcher.start("duel-1", "duel", 27790, tokens, {"slots": 2})
        del os.environ["FAKE_JOIN_SLOTS"]
        with open(proc.tokens_path, encoding="utf-8") as f:
            written = json.load(f)
        self.assertEqual(written["tokens"], tokens)
        self.assertEqual((written["match_id"], written["mode"], written["slots"]), ("duel-1", "duel", 2))
        self.assertEqual(oct(os.stat(proc.tokens_path).st_mode & 0o777), "0o600")
        self.assertEqual(wait_event(proc, "ready"), ("ready", 27790))
        self.assertEqual(wait_event(proc, "joined"), ("joined", 1))
        self.assertEqual(wait_event(proc, "end"), ("end", "fake"))
        self.assertEqual(wait_event(proc, "exit"), ("exit", 0))
        self.launcher.forget(proc)
        self.assertFalse(os.path.exists(proc.tokens_path))
        self.assertEqual(self.launcher.running, {})

    def test_crash_shows_as_a_nonzero_exit_without_ready(self):
        os.environ["FAKE_CRASH"] = "1"
        proc = self.launcher.start("duel-2", "duel", 27791, {}, {})
        del os.environ["FAKE_CRASH"]
        self.assertEqual(wait_event(proc, "exit"), ("exit", 3))

    def test_terminate(self):
        os.environ["FAKE_LIFETIME_S"] = "30"
        proc = self.launcher.start("duel-3", "duel", 27792, {}, {})
        wait_event(proc, "ready")
        self.launcher.stop_all()
        self.assertNotEqual(wait_event(proc, "exit")[1], 0)


if __name__ == "__main__":
    unittest.main()
