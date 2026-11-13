"""The HTTP endpoints as the client sees them, on a fake launcher."""
import json
import os
import tempfile
import threading
import unittest
from unittest import mock
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

    def call(self, method: str, path: str, body=None, raw: bytes = None, member: str = ""):
        data = raw if raw is not None else (json.dumps(body).encode() if body is not None else None)
        headers = {"Content-Type": "application/json"}
        if member:
            headers["X-Boki-Member"] = member
        req = urllib.request.Request(self.base + path, data=data, method=method, headers=headers)
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
        _, b = self.call("POST", "/queue", {"mode": "duel", "name": "Ben", "version": VERSION})
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
        self.assertEqual(self.call("GET", "/nope")[0], 404)
        self.assertEqual(self.call("POST", "/health")[0], 404)
        self.assertEqual(self.call("DELETE", "/queue/")[0], 404)
        self.assertEqual(self.call("GET", "/queue/unknown")[1], {"state": "gone"})
        self.assertEqual(self.call("DELETE", "/queue/unknown")[1], {"state": "gone"})
        self.assertEqual(self.call("POST", "/queue/unknown/pick", {"hunter": "mage"}), (404, {"error": "no_match"}))
        self.assertEqual(self.call("POST", "/queue/a.b/pick", {"hunter": "mage"})[0], 400)

    def test_party_routes_over_http(self):
        who = {"name": "Ana", "version": VERSION}
        status, made = self.call("POST", "/party", who)
        code, ana = made["code"], made["member"]
        self.assertEqual(status, 200)
        status, joined = self.call("POST", f"/party/{code.lower()}/join", {"name": "Ben", "version": VERSION})
        ben = joined["member"]
        self.assertEqual(status, 200)
        status, view = self.call("GET", f"/party/{code}", member=ben)
        self.assertEqual((status, view["state"], [m["name"] for m in view["members"]]), (200, "forming", ["Ana", "Ben"]))
        self.assertEqual(self.call("POST", f"/party/{code}/mode", {"mode": "arena"}, member=ben)[0], 403)
        self.assertEqual(self.call("POST", f"/party/{code}/mode", {"mode": "duel"}, member=ana)[0], 400)
        self.assertEqual(self.call("POST", f"/party/{code}/mode", {"mode": "arena"}, member=ana)[0], 200)
        self.assertEqual(self.call("POST", f"/party/{code}/ready", {"ready": "yes"}, member=ben)[0], 400)
        self.assertEqual(self.call("POST", f"/party/{code}/ready", {"ready": True}, member=ana)[0], 409)
        self.call("POST", f"/party/{code}/ready", {"ready": True}, member=ben)
        self.assertEqual(self.call("POST", f"/party/{code}/ready", {"ready": True}, member=ana)[1], {"state": "queued"})
        self.assertEqual(self.call("POST", f"/party/{code}/join", {"name": "Cid", "version": VERSION})[0], 409)
        _, view = self.call("GET", f"/party/{code}", member=ben)
        self.assertEqual(self.call("GET", f"/queue/{view['ticket']}")[1]["state"], "waiting")
        self.assertEqual(self.call("DELETE", f"/party/{code}/queue", member=ana)[1], {"state": "forming"})
        self.assertEqual(self.call("POST", f"/party/{code}/leave", member=ben)[1], {"state": "left"})
        self.assertEqual(self.call("POST", f"/party/{code}/leave", member=ana)[0], 200)
        self.assertEqual(self.call("GET", f"/party/{code}", member=ana), (404, {"error": "gone"}))

    def test_party_errors_over_http(self):
        _, made = self.call("POST", "/party", {"name": "Ana", "version": VERSION})
        code = made["code"]
        self.assertEqual(self.call("POST", "/party", {"name": "Old", "version": "0.0.1"})[0], 409)
        self.assertEqual(self.call("GET", f"/party/{code}", member="nope")[0], 403)
        self.assertEqual(self.call("GET", f"/party/{code}")[0], 403)
        self.assertEqual(self.call("POST", f"/party/{code}/join", raw=b"{nope")[0], 400)
        self.assertEqual(self.call("GET", "/party")[0], 404)
        self.assertEqual(self.call("POST", f"/party/{code}")[0], 404)
        self.assertEqual(self.call("POST", f"/party/{code}/nope", {})[0], 404)
        self.call("POST", f"/party/{code}/leave", member=made["member"])

    def test_member_secret_never_reaches_the_logged_path(self):
        logged = []
        with mock.patch("mm.api.log", lambda event, **kw: logged.append(kw)):
            _, made = self.call("POST", "/party", {"name": "Ana", "version": VERSION})
            self.call("GET", f"/party/{made['code']}", member=made["member"])
            self.call("POST", f"/party/{made['code']}/leave", member=made["member"])
        self.assertEqual(len(logged), 3)
        self.assertFalse(any(made["member"] in str(kw) for kw in logged))

    def test_wrong_codes_are_429_after_ten(self):
        self.core.parties.strikes.clear()   # every test here shares the loopback address
        statuses = [self.call("POST", "/party/ZZZZ9/join", {"name": "x", "version": VERSION})[0] for _ in range(11)]
        self.assertEqual(statuses, [404] * 10 + [429])
        self.core.parties.strikes.clear()


if __name__ == "__main__":
    unittest.main()
