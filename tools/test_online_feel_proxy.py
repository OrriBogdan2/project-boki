"""The online-feel proxy must never outlive the check that started it (11-14 orphans stuck gate jobs ~90 min).
Run: python3 tools/test_online_feel_proxy.py"""
import os
import signal
import subprocess
import sys
import time
import unittest
from pathlib import Path

PROXY = str(Path(__file__).resolve().parent / "online_feel_proxy.py")


def alive(pid):
    try:
        os.kill(pid, 0)
    except ProcessLookupError:
        return False
    try:  # a zombie counts as gone
        return Path(f"/proc/{pid}/stat").read_text().split(")")[-1].split()[0] != "Z"
    except OSError:
        return False


def wait_gone(pid, secs=6.0):
    t0 = time.time()
    while time.time() - t0 < secs:
        if not alive(pid):
            return True
        time.sleep(0.1)
    return False


def start(args, tmp_port):
    return subprocess.Popen([sys.executable, PROXY, str(tmp_port), str(tmp_port + 1), "100", *args])


class ProxyReap(unittest.TestCase):
    def test_dies_with_killed_parent(self):
        # a stand-in for the check's game: it starts the proxy, then is SIGKILLed (suite timeout, crash)
        code = ("import subprocess,sys;p=subprocess.Popen([sys.executable,%r,'47311','47312','100']);"
                "print(p.pid,flush=True);import time;time.sleep(60)" % PROXY)
        parent = subprocess.Popen([sys.executable, "-c", code], stdout=subprocess.PIPE, text=True)
        pid = int(parent.stdout.readline())
        time.sleep(1.0)
        self.assertTrue(alive(pid), "proxy should run while its parent lives")
        parent.kill()
        parent.wait()
        self.assertTrue(wait_gone(pid), "proxy outlived its killed parent")

    def test_dies_with_parent_pid(self):
        # the check's way: the proxy runs under sh, --parent-pid names the game, which is SIGKILLed
        game = subprocess.Popen(["sleep", "60"])
        p = start(["--parent-pid", str(game.pid)], 47341)
        time.sleep(1.0)
        self.assertTrue(alive(p.pid))
        game.kill()
        game.wait()
        self.assertTrue(wait_gone(p.pid), "proxy outlived --parent-pid")

    def test_dies_on_sigterm(self):
        p = start([], 47321)
        time.sleep(1.0)
        p.send_signal(signal.SIGTERM)
        self.assertEqual(p.wait(timeout=6), 0)

    def test_lifetime_cap(self):
        p = start(["--max-life", "1"], 47331)
        self.assertEqual(p.wait(timeout=6), 0, "proxy ignored --max-life")


if __name__ == "__main__":
    unittest.main()
