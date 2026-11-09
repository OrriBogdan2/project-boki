#!/usr/bin/env python3
"""Project Boki matchmaker: queues (duel, arena, trio), one game server process per match, tokens.

  python3 matchmaker.py [--env-file /etc/boki/matchmaker.env]     run the service
  python3 matchmaker.py --selftest                                  exercise it against fake_server.py

Settings (env file, overridden by the environment): REGION, PUBLIC_HOST, HTTP_HOST, HTTP_PORT, SERVER_CMD,
SERVER_VERSION, PORT_MIN, PORT_MAX, FILL_TIMEOUT_DUEL/ARENA/TRIO, TRIO_SLOTS, TOKEN_TTL_S, READY_TIMEOUT_S,
TOKENS_DIR. See ../README.md.
"""
import argparse
import os
import signal
import sys
import threading

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from mm import config  # noqa: E402
from mm.api import make_server, run_ticker  # noqa: E402
from mm.core import Matchmaker  # noqa: E402
from mm.launcher import Launcher  # noqa: E402
from mm.log import log  # noqa: E402


def build(cfg: config.Config) -> Matchmaker:
    """Wire the launcher and the matchmaker; the served version comes from SERVER_VERSION or a --version probe."""
    if not cfg.server_cmd:
        sys.exit("SERVER_CMD is not set (the game server command, e.g. "
                 "/opt/boki/server/ProjectBoki.x86_64 --headless --)")
    launcher = Launcher(cfg.server_cmd, cfg.tokens_dir)
    version = cfg.server_version or launcher.probe_version()
    if not version:
        sys.exit("No server version: `SERVER_CMD --version` printed none and SERVER_VERSION is not set")
    return Matchmaker(cfg, launcher, version)


def serve(cfg: config.Config) -> None:
    core = build(cfg)
    httpd = make_server(core, cfg.http_host, cfg.http_port, cfg.feedback_path)
    stop = threading.Event()
    ticker = threading.Thread(target=run_ticker, args=(core, cfg.tick_s, stop), name="ticker", daemon=True)
    ticker.start()
    log("matchmaker_up", region=cfg.region, public_host=cfg.public_host, http_port=httpd.server_address[1],
        version=core.version, ports=f"{cfg.port_min}-{cfg.port_max}")

    def on_signal(signum, _frame):
        log("matchmaker_stop", signal=signum)
        threading.Thread(target=httpd.shutdown, daemon=True).start()

    signal.signal(signal.SIGTERM, on_signal)
    signal.signal(signal.SIGINT, on_signal)
    try:
        httpd.serve_forever()
    finally:
        stop.set()
        core.shutdown()


def main() -> int:
    ap = argparse.ArgumentParser(description="Project Boki matchmaker")
    ap.add_argument("--env-file", default=config.ENV_FILE)
    ap.add_argument("--selftest", action="store_true", help="run against fake_server.py and exit")
    args = ap.parse_args()
    if args.selftest:
        from mm.selftest import run_selftest
        return run_selftest()
    serve(config.load(args.env_file))
    return 0


if __name__ == "__main__":
    sys.exit(main())
