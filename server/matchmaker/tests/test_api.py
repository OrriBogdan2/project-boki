"""The HTTP endpoints as the client sees them, on a fake launcher."""
import json
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
        cls.httpd = make_server(cls.core, "127.0.0.1", 0)
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
