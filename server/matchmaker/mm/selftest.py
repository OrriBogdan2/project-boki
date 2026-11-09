"""`matchmaker.py --selftest`: the real service in-process, over real HTTP, with fake_server.py as the game
server (ports 27777-27779, ~10 s). Prints one PASS/FAIL line per scenario; exit 1 on any failure."""
import json
import os
import tempfile
import threading
import time
import urllib.error
import urllib.request

from . import config
from .api import make_server, run_ticker
from .core import Matchmaker
from .launcher import Launcher
from .log import log

FAKE_VERSION = "0.0.0-selftest"


class Client:
    def __init__(self, base: str):
        self.base = base

    def call(self, method: str, path: str, body: dict = None):
        data = json.dumps(body).encode() if body is not None else None
        req = urllib.request.Request(self.base + path, data=data, method=method,
                                     headers={"Content-Type": "application/json"})
        try:
            with urllib.request.urlopen(req, timeout=5) as resp:
                return resp.status, json.loads(resp.read())
        except urllib.error.HTTPError as e:
            return e.code, json.loads(e.read())

    def queue(self, mode: str, name: str, version: str = FAKE_VERSION) -> str:
        return self.call("POST", "/queue", {"mode": mode, "name": name, "version": version})[1]["ticket"]

    def wait_ready(self, ticket: str, timeout: float = 8.0) -> dict:
        end = time.time() + timeout
        while time.time() < end:
            state = self.call("GET", f"/queue/{ticket}")[1]
            if state["state"] != "waiting":
                return state
            time.sleep(0.2)
        return {"state": "timeout"}


def _config(tokens_dir: str) -> config.Config:
    here = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    env = {"SERVER_CMD": f"python3 {os.path.join(here, 'fake_server.py')}", "REGION": "selftest",
           "HTTP_HOST": "127.0.0.1", "HTTP_PORT": "0", "PORT_MIN": "27777", "PORT_MAX": "27779",
           "FILL_TIMEOUT_DUEL": "1", "FILL_TIMEOUT_TRIO": "1", "TOKENS_DIR": tokens_dir, "TOKEN_TTL_S": "60"}
    return config.load(env_file="/nonexistent", environ=env)


def _scenarios(c: Client, core: Matchmaker) -> list:
    results = []

    def check(name: str, ok: bool, detail=""):
        results.append(ok)
        print(f"{'PASS' if ok else 'FAIL'} {name} {detail}".rstrip(), flush=True)

    status, health = c.call("GET", "/health")
    check("health", status == 200 and health["ok"] and health["version"] == FAKE_VERSION, health)
    status, out = c.call("POST", "/queue", {"mode": "duel", "name": "Old", "version": "0.0.0-old"})
    check("version rejected", status == 409 and out == {"error": "version", "server_version": FAKE_VERSION}, out)
    a, b = c.queue("duel", "Ana"), c.queue("duel", "Ben")
    ra, rb = c.wait_ready(a), c.wait_ready(b)
    both_ready = ra["state"] == "ready" and rb["state"] == "ready"
    check("duel 2 humans ready", both_ready and ra["port"] == rb["port"] and ra["token"] != rb["token"], (ra, rb))
    check("host handed out", both_ready and ra["host"] == core.cfg.public_host, ra.get("host"))
    t = c.queue("trio", "Solo")
    waiting = c.call("GET", f"/queue/{t}")[1]
    rt = c.wait_ready(t)
    check("trio fill timeout with bots", waiting["state"] == "waiting" and rt["state"] == "ready", (waiting, rt))
    x = c.queue("arena", "Leaver")
    status, out = c.call("DELETE", f"/queue/{x}")
    check("cancel", status == 200 and c.call("GET", f"/queue/{x}")[1] == {"state": "gone"}, out)
    crash_flag = os.path.join(core.cfg.tokens_dir, "crash-once")
    os.environ["FAKE_CRASH_FILE"] = crash_flag
    open(crash_flag, "w").close()
    p, q = c.queue("duel", "Pia"), c.queue("duel", "Quin")
    rp, rq = c.wait_ready(p), c.wait_ready(q)
    check("crash before ready: re-queued, then ready", rp["state"] == "ready" and rq["state"] == "ready", (rp, rq))
    end = time.time() + 8
    while time.time() < end and c.call("GET", "/health")[1]["matches"] > 0:
        time.sleep(0.3)
    matches = c.call("GET", "/health")[1]["matches"]
    check("servers reaped, ports freed", matches == 0 and len(core.ports.used) == 0, matches)
    check("tokens files removed", os.listdir(core.cfg.tokens_dir) == [], os.listdir(core.cfg.tokens_dir))
    return results


def run_selftest() -> int:
    os.environ["FAKE_VERSION"] = FAKE_VERSION
    os.environ["FAKE_LIFETIME_S"] = "2"
    with tempfile.TemporaryDirectory() as tokens_dir:
        cfg = _config(tokens_dir)
        launcher = Launcher(cfg.server_cmd, cfg.tokens_dir)
        core = Matchmaker(cfg, launcher, launcher.probe_version())
        httpd = make_server(core, cfg.http_host, cfg.http_port)
        stop = threading.Event()
        threading.Thread(target=run_ticker, args=(core, cfg.tick_s, stop), daemon=True).start()
        threading.Thread(target=httpd.serve_forever, daemon=True).start()
        log("selftest_up", http_port=httpd.server_address[1], version=core.version)
        try:
            results = _scenarios(Client(f"http://127.0.0.1:{httpd.server_address[1]}"), core)
        finally:
            stop.set()
            httpd.shutdown()
            core.shutdown()
    print(f"selftest: {sum(results)}/{len(results)} passed", flush=True)
    return 0 if all(results) else 1
