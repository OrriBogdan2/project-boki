"""Test doubles: a clock you move by hand and a launcher that spawns nothing but lets a test emit server events."""
import os
import queue
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
MM_DIR = os.path.dirname(HERE)
FAKE_SERVER = os.path.join(MM_DIR, "fake_server.py")
if MM_DIR not in sys.path:
    sys.path.insert(0, MM_DIR)

from mm import config  # noqa: E402
from mm.core import Matchmaker  # noqa: E402

VERSION = "9.9.9-test"


class Clock:
    def __init__(self, t: float = 1000.0):
        self.t = t

    def __call__(self) -> float:
        return self.t

    def advance(self, dt: float) -> None:
        self.t += dt


class FakeProcess:
    """Stands in for MatchProcess: the test pushes ("ready", port) / ("joined", slot) / ("exit", code)."""

    def __init__(self, match_id: str, port: int, tokens: dict, extra: dict):
        self.match_id = match_id
        self.port = port
        self.tokens = tokens
        self.extra = extra
        self.events = queue.Queue()
        self.terminated = False
        self.tokens_path = ""

    def terminate(self) -> None:
        self.terminated = True
        self.events.put(("exit", -15))


class FakeLauncher:
    def __init__(self):
        self.running = {}
        self.started = []    # every FakeProcess ever started, in order

    def start(self, match_id, mode, port, tokens, extra):
        proc = FakeProcess(match_id, port, tokens, extra)
        self.running[match_id] = proc
        self.started.append(proc)
        return proc

    def forget(self, proc):
        self.running.pop(proc.match_id, None)

    def stop_all(self):
        for proc in list(self.running.values()):
            proc.terminate()


def make_core(clock: Clock = None, **env) -> Matchmaker:
    """A Matchmaker on a FakeLauncher with test ports 27777-27799 unless the env says otherwise."""
    settings = {"PORT_MIN": "27777", "PORT_MAX": "27799", "PUBLIC_HOST": "203.0.113.5", "REGION": "test"}
    settings.update(env)
    cfg = config.load(env_file="/nonexistent", environ=settings)
    return Matchmaker(cfg, FakeLauncher(), VERSION, clock or Clock())


def ready_all(core: Matchmaker) -> None:
    """Every started process reports ready, then the core drains the events."""
    for proc in core.launcher.started:
        proc.events.put(("ready", proc.port))
    core.tick()
