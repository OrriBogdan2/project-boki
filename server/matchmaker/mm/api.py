"""The HTTP side: GET /health, POST /queue, GET/DELETE /queue/<ticket>, POST /queue/<ticket>/pick, the /party routes. JSON in, JSON out."""
import json
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

from . import feedback
from .core import Matchmaker
from .log import log

MAX_BODY = 4096          # bytes; a queue request is a few names
MEMBER_HEADER = "X-Boki-Member"   # the party member secret: a header, because the logged path must not hold it
STATUS = {"version": 409, "mode": 400, "bad_request": 400, "no_match": 404, "unknown": 400, "loading": 409, "turn": 409,
          "taken": 409, "not_found": 404, "gone": 404, "full": 409, "busy": 409, "not_ready": 409, "not_member": 403,
          "not_leader": 403, "rate_limited": 429}


def make_server(core: Matchmaker, host: str, port: int, feedback_path: str = "/var/lib/boki/feedback.jsonl") -> ThreadingHTTPServer:
    """An HTTP server bound to host:port (port 0 picks a free one) answering with `core`."""

    class Handler(BaseHTTPRequestHandler):
        protocol_version = "HTTP/1.1"

        def do_GET(self):
            if self.path == "/health":
                return self._reply(200, core.health())
            ticket = _ticket_id(self.path)
            if ticket:
                return self._reply(200, core.status(ticket))
            if not self._party("GET"):
                self._reply(404, {"error": "not_found"})

        def do_POST(self):
            if self.path == "/feedback":
                return self._feedback()
            if self.path.endswith("/pick"):
                return self._pick()
            if self.path != "/queue":
                if not self._party("POST"):
                    self._reply(404, {"error": "not_found"})
                return
            body = self._json_body()
            if body is None:
                return self._reply(400, {"error": "bad_request"})
            out = core.enqueue(str(body.get("mode", "")), str(body.get("name") or "Hunter"), str(body.get("version", "")))
            self._reply(STATUS.get(out.get("error"), 200), out)

        def do_DELETE(self):
            ticket = _ticket_id(self.path)
            if ticket:
                core.cancel(ticket)
                return self._reply(200, {"state": "gone"})
            if not self._party("DELETE"):
                self._reply(404, {"error": "not_found"})

        def _party(self, method: str) -> bool:
            """Answer a /party route; False when the path is not one."""
            route = _party_route(self.path)
            if route is None or (method, bool(route[0]), route[1]) not in PARTY_ROUTES:
                return False
            body = self._json_body() if method == "POST" else {}
            if body is None:
                self._reply(400, {"error": "bad_request"})
                return True
            code = route[0]
            secret, client = self.headers.get(MEMBER_HEADER, ""), self.client_address[0]
            parties, name, version = core.parties, str(body.get("name") or "Hunter"), str(body.get("version", ""))
            action = route[1]
            if not code:
                out = parties.create(name, version)
            elif action == "join":
                out = parties.join(code, name, version, client)
            elif action == "mode":
                out = parties.set_mode(code, secret, str(body.get("mode", "")), client)
            elif action == "ready":
                if not isinstance(body.get("ready"), bool):
                    out = {"error": "bad_request"}
                else:
                    out = parties.set_ready(code, secret, body["ready"], client)
            elif action == "queue":
                out = parties.cancel_queue(code, secret, client)
            elif action == "leave":
                out = parties.leave(code, secret, client)
            else:
                out = parties.view(code, secret, client)
            self._reply(STATUS.get(out.get("error"), 200), out)
            return True

        def _pick(self):
            ticket = _ticket_id(self.path[:-len("/pick")])
            body = self._json_body()
            if not ticket or body is None:
                return self._reply(400, {"error": "bad_request"})
            out = core.pick(ticket, str(body.get("hunter", "")))
            self._reply(STATUS.get(out.get("error"), 200), out)

        def _feedback(self):
            body = self._json_body(feedback.MAX_FEEDBACK)
            reason = feedback.validate(body)
            if reason:
                return self._reply(400, {"error": "bad_request", "field": reason})
            try:
                feedback.store(feedback_path, body)
            except OSError as e:
                log("feedback_error", error=repr(e))
                return self._reply(500, {"error": "store_failed"})
            self._reply(200, {"ok": True})

        def _json_body(self, limit: int = MAX_BODY):
            try:
                n = int(self.headers.get("Content-Length", "0"))
                if n > limit:
                    return None
                body = json.loads(self.rfile.read(n) or b"{}")
                return body if isinstance(body, dict) else None
            except (ValueError, json.JSONDecodeError):
                return None

        def _reply(self, status: int, payload: dict) -> None:
            data = json.dumps(payload).encode()
            # logged before the write, so a client that has its answer also has its log line
            log("http", method=self.command, path=self.path, status=status, client=self.client_address[0])
            self.send_response(status)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(data)))
            self.end_headers()
            self.wfile.write(data)

        def log_message(self, *_):
            pass   # the structured line in _reply replaces the default stderr log

    return ThreadingHTTPServer((host, port), Handler)


def _ticket_id(path: str) -> str:
    prefix = "/queue/"
    if not path.startswith(prefix):
        return ""
    ticket = path[len(prefix):].split("?", 1)[0]
    return ticket if ticket.replace("-", "").replace("_", "").isalnum() else ""


PARTY_ROUTES = {("POST", False, ""), ("GET", True, ""), ("POST", True, "join"), ("POST", True, "mode"),
                ("POST", True, "ready"), ("DELETE", True, "queue"), ("POST", True, "leave")}


def _party_route(path: str):
    """`/party` -> ("", ""); `/party/<code>` -> (code, ""); `/party/<code>/<action>` -> (code, action);
    None when the path is not a party route."""
    parts = path.split("?", 1)[0].strip("/").split("/")
    if parts[0] != "party" or len(parts) > 3 or not all(p.isalnum() for p in parts[1:]):
        return None
    return (parts[1] if len(parts) > 1 else ""), (parts[2] if len(parts) > 2 else "")


def run_ticker(core: Matchmaker, tick_s: float, stop) -> None:
    """Call `core.tick()` every `tick_s` seconds until `stop` (a threading.Event) is set."""
    while not stop.is_set():
        try:
            core.tick()
        except Exception as e:   # noqa: BLE001 - a bug in one tick must not stop the service
            log("tick_error", error=repr(e))
        time.sleep(tick_s)
