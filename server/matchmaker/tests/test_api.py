"""The HTTP endpoints as the client sees them, on a fake launcher."""
import json
import os
import tempfile
import threading
import unittest
import urllib.error
import urllib.request

from helpers import VERSION, Clock, make_core, ready_all

from mm.api import make_server


class ApiTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.clock = Clock()
        cls.core = make_core(cls.clock)
        cls.tmp = tempfile.mkdtemp()
        cls.fb = os.path.join(cls.tmp, "fb", "feedback.jsonl")
        cls.httpd = make_server(cls.core, "127.0.0.1", 0, cls.fb)
        threading.Thread(target=cls.httpd.serve_forever, daemon=True).start()
        cls.base = f"http://127.0.0.1:{cls.httpd.server_address[1]}"

    @classmethod
    def tearDownClass(cls):
        cls.httpd.shutdown()
        cls.httpd.server_close()

    def call(self, method: str, path: str, body=None, raw: bytes = None):
        data = raw if raw is not None else (json.dumps(body).encode() if body is not None else None)
        req = urllib.request.Request(self.base + path, data=data, method=method,
                                     headers={"Content-Type": "application/json"})
        try:
            with urllib.request.urlopen(req, timeout=5) as resp:
                return resp.status, json.loads(resp.read())
        except urllib.error.HTTPError as e:
            return e.code, json.loads(e.read())

    def test_feedback_stored_and_validated(self):
        ok = {"version": VERSION, "player": "Ana", "scores": {"combat": 7, "boki": 9, "onboarding": 4, "look": 10},
              "note": "fun", "minutes_played": 12.5}
        self.assertEqual(self.call("POST", "/feedback", ok), (200, {"ok": True}))
        with open(self.fb, encoding="utf-8") as f:
            lines = f.read().splitlines()
        self.assertEqual(json.loads(lines[-1])["scores"]["boki"], 9)
        bad = dict(ok, scores={"combat": 11, "boki": 1, "onboarding": 1, "look": 1})
        self.assertEqual(self.call("POST", "/feedback", bad)[0], 400)
        self.assertEqual(self.call("POST", "/feedback", raw=b"{nope")[0], 400)
        big = dict(ok, note="x" * 3000)
        self.assertEqual(self.call("POST", "/feedback", big)[0], 400)
        with open(self.fb, encoding="utf-8") as f:
            self.assertEqual(len(f.read().splitlines()), len(lines))   # rejects store nothing

    def test_quick_note_stored_and_validated(self):
        note = {"kind": "note", "version": VERSION, "player": "Ana", "note": "the jump felt late",
                "ctx": {"hunter": "vex", "t": 31.5, "pos": [1.0, 2.0]}, "shot": "abc"}
        self.assertEqual(self.call("POST", "/feedback", note), (200, {"ok": True}))
        with open(self.fb, encoding="utf-8") as f:
            rec = json.loads(f.read().splitlines()[-1])
        self.assertEqual((rec["kind"], rec["ctx"]["hunter"], rec["shot"]), ("note", "vex", "abc"))
        for bad in (dict(note, note=" "), dict(note, ctx="x"), dict(note, shot="x" * 6001)):
            self.assertEqual(self.call("POST", "/feedback", bad)[0], 400)

    def test_health(self):
        status, out = self.call("GET", "/health")
        self.assertEqual(status, 200)
        self.assertEqual(out, {"ok": True, "version": VERSION, "region": "test", "matches": 0})

    def test_queue_lifecycle_over_http(self):
        status, a = self.call("POST", "/queue", {"mode": "duel", "name": "Ana", "version": VERSION})
        self.assertEqual(status, 200)
        status, waiting = self.call("GET", f"/queue/{a['ticket']}")
        self.assertEqual((status, waiting["state"], waiting["position"]), (200, "waiting", 1))
        self.assertIn("eta_s", waiting)
        _, b = self.call("POST", "/queue", {"mode": "duel", "name": "Ben", "version": VERSION, "party": []})
        self.core.tick()
        ready_all(self.core)
        _, ready = self.call("GET", f"/queue/{b['ticket']}")
        self.assertEqual(ready["state"], "ready")
        self.assertEqual(set(ready), {"state", "host", "port", "token"})
        self.assertEqual(self.call("GET", "/health")[1]["matches"], 1)
        status, out = self.call("DELETE", f"/queue/{a['ticket']}")
        self.assertEqual((status, out), (200, {"state": "gone"}))
        self.assertEqual(self.call("GET", f"/queue/{a['ticket']}")[1], {"state": "gone"})

    def test_version_mismatch_is_409(self):
        status, out = self.call("POST", "/queue", {"mode": "duel", "name": "Old", "version": "0.0.1"})
        self.assertEqual((status, out), (409, {"error": "version", "server_version": VERSION}))

    def test_bad_requests(self):
        self.assertEqual(self.call("POST", "/queue", raw=b"{not json")[0], 400)
        self.assertEqual(self.call("POST", "/queue", {"mode": "coop", "name": "x", "version": VERSION})[0], 400)
        self.assertEqual(self.call("POST", "/queue", {"mode": "duel", "version": VERSION, "party": "Ben"})[0], 400)
        self.assertEqual(self.call("GET", "/nope")[0], 404)
        self.assertEqual(self.call("POST", "/health")[0], 404)
        self.assertEqual(self.call("DELETE", "/queue/")[0], 404)
        self.assertEqual(self.call("GET", "/queue/unknown")[1], {"state": "gone"})
        self.assertEqual(self.call("DELETE", "/queue/unknown")[1], {"state": "gone"})


if __name__ == "__main__":
    unittest.main()
