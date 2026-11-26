"""Spend guard of meshy_task.py: floor refusal (exit 3) and one ledger line per paid submit.
Run: python3 tools/meshy/test_meshy_spend_guard.py"""

import os
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parent))
import meshy_task as mt  # noqa: E402


def fake_call(balance, calls):
    def call(method, url, body=None):
        calls.append((method, url.split("/v1/")[-1]))
        if url.endswith("balance"):
            return {"balance": balance}
        return {"result": "task123"}

    return call


class SpendGuard(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.led = os.path.join(self.tmp.name, "led.tsv")
        env = {"MESHY_LEDGER": self.led, "CLAUDE_JOB_LABEL": "job-x"}
        p = mock.patch.dict(os.environ, env)
        p.start()
        os.environ.pop("MESHY_FLOOR", None)
        self.addCleanup(p.stop)
        self.addCleanup(self.tmp.cleanup)

    def submit(self, balance):
        calls = []
        with mock.patch.object(mt, "call", fake_call(balance, calls)), mock.patch.object(mt, "fetch") as fetch:
            mt.post(os.path.join(self.tmp.name, "out"), "multi-image-to-3d", {"a": 1}, {})
        return calls, fetch

    def test_below_floor_refuses_exit_3_and_posts_nothing(self):
        calls = []
        with mock.patch.object(mt, "call", fake_call(399, calls)), mock.patch.object(mt, "fetch"):
            with self.assertRaises(SystemExit) as e:
                mt.post(os.path.join(self.tmp.name, "out"), "image-to-3d", {}, {})
        self.assertEqual(e.exception.code, 3)
        self.assertEqual(calls, [("GET", "balance")])
        self.assertFalse(os.path.exists(self.led))

    def test_ok_submit_appends_one_ledger_line(self):
        calls, fetch = self.submit(1500)
        self.assertEqual(calls, [("GET", "balance"), ("POST", "multi-image-to-3d")])
        fetch.assert_called_once()
        lines = open(self.led).read().splitlines()
        self.assertEqual(len(lines), 1)
        t, who, api, tid, bal = lines[0].split("\t")
        self.assertTrue(t.endswith("Z") and "T" in t)
        self.assertEqual((who, api, tid, bal), ("job-x", "multi-image-to-3d", "task123", "1500"))
        self.submit(1460)
        self.assertEqual(len(open(self.led).read().splitlines()), 2)

    def test_floor_env_and_exact_floor(self):
        self.submit(400)  # == default floor passes
        os.environ["MESHY_FLOOR"] = "1000"
        with self.assertRaises(SystemExit) as e:
            self.submit(999)
        self.assertEqual(e.exception.code, 3)
        os.environ["MESHY_FLOOR"] = "0"
        self.submit(5)

    def test_label_falls_back_to_hostname(self):
        del os.environ["CLAUDE_JOB_LABEL"]
        self.submit(900)
        self.assertEqual(open(self.led).read().split("\t")[1], mt.socket.gethostname())

    def test_ledger_write_failure_keeps_task(self):
        os.environ["MESHY_LEDGER"] = os.path.join(self.tmp.name, "no", "such", "dir", "led.tsv")
        calls, fetch = self.submit(900)
        fetch.assert_called_once()

    def test_unreadable_balance_refuses(self):
        with self.assertRaises(SystemExit):
            self.submit(None)


if __name__ == "__main__":
    unittest.main()
