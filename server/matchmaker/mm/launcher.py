"""Game server processes: free UDP ports, the tokens file, spawning, reading the BOKI_SERVER status lines."""
import json
import os
import queue
import re
import secrets
import subprocess
import threading

from .log import log

STATUS_LINE = re.compile(r"^BOKI_SERVER (\w+)(.*)$")
VERSION_LINE = re.compile(r"version=(\S+)|^(\d+\.\d+\.\d+\S*)$")
PROBE_TIMEOUT_S = 30.0   # a Godot headless build can take a while to print its version and quit


class PortPool:
    """UDP match ports: the lowest free one is handed out, released when the process exits."""

    def __init__(self, lo: int, hi: int):
        self.free = list(range(lo, hi + 1))
        self.used = set()

    def acquire(self):
        if not self.free:
            return None
        port = self.free.pop(0)
        self.used.add(port)
        return port

    def release(self, port: int) -> None:
        if port in self.used:
            self.used.remove(port)
            self.free.append(port)
            self.free.sort()


class MatchProcess:
    """One running game server. Its stdout is read on a thread; parsed status lines land in `events`:
    ("ready", port) | ("joined", slot) | ("end", result) | ("exit", code)."""

    def __init__(self, match_id: str, port: int, proc: subprocess.Popen, tokens_path: str):
        self.match_id = match_id
        self.port = port
        self.proc = proc
        self.tokens_path = tokens_path
        self.events = queue.Queue()
        self.reader = threading.Thread(target=self._read, name=f"server-{match_id}", daemon=True)
        self.reader.start()

    def _read(self) -> None:
        for raw in self.proc.stdout:
            line = raw.rstrip("\n")
            m = STATUS_LINE.match(line)
            if not m:
                log("server_out", match=self.match_id, line=line)
                continue
            fields = dict(p.split("=", 1) for p in m.group(2).split() if "=" in p)
            kind = m.group(1)
            if kind == "ready":
                self.events.put(("ready", int(fields.get("port", self.port))))
            elif kind == "joined":
                self.events.put(("joined", int(fields.get("slot", -1))))
            elif kind == "end":
                self.events.put(("end", fields.get("result", "")))
            else:
                log("server_status", match=self.match_id, line=line)
        self.proc.stdout.close()
        self.events.put(("exit", self.proc.wait()))

    def terminate(self) -> None:
        if self.proc.poll() is None:
            self.proc.terminate()


def new_token() -> str:
    return secrets.token_urlsafe(24)


class Launcher:
    """Spawns `SERVER_CMD --server --port N --mode M --match-id ID --tokens-file P` and tracks the processes."""

    def __init__(self, server_cmd: list, tokens_dir: str):
        self.server_cmd = server_cmd
        self.tokens_dir = tokens_dir
        self.running = {}   # match_id -> MatchProcess
        os.makedirs(tokens_dir, exist_ok=True)

    def probe_version(self) -> str:
        """Run `SERVER_CMD --version`; expects `BOKI_SERVER version=<v>` (or a bare x.y.z line) on stdout."""
        try:
            done = subprocess.run(self.server_cmd + ["--version"], capture_output=True, text=True,
                                  timeout=PROBE_TIMEOUT_S, check=False)
        except (OSError, subprocess.TimeoutExpired) as e:
            log("version_probe_failed", error=e)
            return ""
        for line in done.stdout.splitlines():
            m = VERSION_LINE.search(line.strip())
            if m:
                return m.group(1) or m.group(2)
        log("version_probe_failed", exit=done.returncode, stdout=done.stdout[-200:])
        return ""

    def start(self, match_id: str, mode: str, port: int, tokens: dict, extra: dict) -> MatchProcess:
        """Write the tokens file and spawn the server. `tokens`: token -> {"name", "slot", "team"}."""
        path = os.path.join(self.tokens_dir, f"{match_id}.json")
        with open(path, "w", encoding="utf-8") as f:
            json.dump({"tokens": tokens, "match_id": match_id, "mode": mode, **extra}, f)
        os.chmod(path, 0o600)
        argv = self.server_cmd + ["--server", "--port", str(port), "--mode", mode,
                                  "--match-id", match_id, "--tokens-file", path]
        proc = subprocess.Popen(argv, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True,
                                stdin=subprocess.DEVNULL)
        log("server_spawn", match=match_id, mode=mode, port=port, pid=proc.pid)
        mp = MatchProcess(match_id, port, proc, path)
        self.running[match_id] = mp
        return mp

    def forget(self, mp: MatchProcess) -> None:
        """Drop a finished process and its tokens file."""
        self.running.pop(mp.match_id, None)
        try:
            os.remove(mp.tokens_path)
        except OSError:
            pass

    def stop_all(self) -> None:
        for mp in list(self.running.values()):
            mp.terminate()
