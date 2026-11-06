"""The HTTP side: GET /health, POST /queue, GET/DELETE /queue/<ticket>. JSON in, JSON out."""
import json
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

from . import feedback
from .core import Matchmaker
from .log import log

MAX_BODY = 4096          # bytes; a queue request is a few names
STATUS = {"version": 409, "mode": 400, "bad_request": 400}


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
            self._reply(404, {"error": "not_found"})

        def do_POST(self):
            if self.path == "/feedback":
                return self._feedback()
            if self.path != "/queue":
                return self._reply(404, {"error": "not_found"})
            body = self._json_body()
            if body is None:
                return self._reply(400, {"error": "bad_request"})
            party = body.get("party") or []
            if not isinstance(party, list):
                return self._reply(400, {"error": "bad_request"})
            out = core.enqueue(str(body.get("mode", "")), str(body.get("name") or "Hunter"),
                               str(body.get("version", "")), party)
            self._reply(STATUS.get(out.get("error"), 200), out)

        def do_DELETE(self):
            ticket = _ticket_id(self.path)
            if not ticket:
                return self._reply(404, {"error": "not_found"})
            core.cancel(ticket)
            self._reply(200, {"state": "gone"})

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
            self.send_response(status)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(data)))
            self.end_headers()
            self.wfile.write(data)
            log("http", method=self.command, path=self.path, status=status, client=self.client_address[0])

        def log_message(self, *_):
            pass   # the structured line in _reply replaces the default stderr log

    return ThreadingHTTPServer((host, port), Handler)


def _ticket_id(path: str) -> str:
    prefix = "/queue/"
    if not path.startswith(prefix):
        return ""
    ticket = path[len(prefix):].split("?", 1)[0]
    return ticket if ticket.replace("-", "").replace("_", "").isalnum() else ""


def run_ticker(core: Matchmaker, tick_s: float, stop) -> None:
    """Call `core.tick()` every `tick_s` seconds until `stop` (a threading.Event) is set."""
    while not stop.is_set():
        try:
            core.tick()
        except Exception as e:   # noqa: BLE001 - a bug in one tick must not stop the service
            log("tick_error", error=repr(e))
        time.sleep(tick_s)
