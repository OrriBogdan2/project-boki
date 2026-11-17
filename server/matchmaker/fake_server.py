#!/usr/bin/env python3
"""A stand-in for the game server (tests and --selftest): takes the same arguments, prints the same
BOKI_SERVER lines, exits after a few seconds. Behaviour via the environment:
  FAKE_VERSION      what `--version` reports (default 0.0.0-fake)
  FAKE_LIFETIME_S   seconds between ready and a clean exit (default 3)
  FAKE_READY_DELAY_S  seconds before the ready line (default 0)
  FAKE_CRASH=1      exit with code 3 before printing ready
  FAKE_CRASH_FILE   if that file exists, delete it and crash once (the next spawn runs normally)
  FAKE_JOIN_SLOTS   comma-separated slots to report as joined right after ready (e.g. "0,1")
"""
import argparse
import json
import os
import sys
import time


def main() -> int:
    if "--version" in sys.argv:
        print(f"BOKI_SERVER version={os.environ.get('FAKE_VERSION', '0.0.0-fake')}", flush=True)
        return 0
    ap = argparse.ArgumentParser()
    ap.add_argument("--server", action="store_true")
    ap.add_argument("--port", type=int, required=True)
    ap.add_argument("--mode", required=True)
    ap.add_argument("--match-id", required=True)
    ap.add_argument("--tokens-file", required=True)
    ap.add_argument("--seed", default="")
    args = ap.parse_args()
    with open(args.tokens_file, encoding="utf-8") as f:
        tokens = json.load(f)["tokens"]
    print(f"fake server: match {args.match_id} mode {args.mode} with {len(tokens)} tokens", flush=True)
    time.sleep(float(os.environ.get("FAKE_READY_DELAY_S", "0")))
    if _crash_wanted():
        print("fake server: crashing on purpose", flush=True)
        return 3
    print(f"BOKI_SERVER ready port={args.port}", flush=True)
    for slot in filter(None, os.environ.get("FAKE_JOIN_SLOTS", "").split(",")):
        print(f"BOKI_SERVER joined slot={int(slot)}", flush=True)
    time.sleep(float(os.environ.get("FAKE_LIFETIME_S", "3")))
    print("BOKI_SERVER end result=fake", flush=True)
    return 0


def _crash_wanted() -> bool:
    once = os.environ.get("FAKE_CRASH_FILE", "")
    if once and os.path.exists(once):
        os.remove(once)
        return True
    return os.environ.get("FAKE_CRASH") == "1"


if __name__ == "__main__":
    sys.exit(main())
