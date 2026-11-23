#!/usr/bin/env python3
"""Userspace stand-in for `tc netem delay` on loopback (no root needed): a UDP proxy that holds every
packet for DELAY_MS each way. Used by --online-feel-check (tools/online_feel_check.gd).
Usage: online_feel_proxy.py LISTEN_PORT TARGET_PORT DELAY_MS [--parent-pid PID] [--max-life SECONDS]
It exits by itself when PID is gone (or a zombie) and after SECONDS (default 1500), so a check that is killed
or times out never leaves it behind holding the caller's pipe (11-14: it hung a release gate for 1h40m)."""
import argparse
import asyncio
import os
import signal


class Leg(asyncio.DatagramProtocol):
    """The proxy's own socket toward the target for one client."""

    def __init__(self, front, client, delay):
        self.front, self.client, self.delay = front, client, delay

    def datagram_received(self, data, addr):
        asyncio.get_running_loop().call_later(self.delay, self.front.transport.sendto, data, self.client)


class Front(asyncio.DatagramProtocol):
    def __init__(self, target, delay):
        self.target, self.delay, self.legs, self.transport = target, delay, {}, None

    def connection_made(self, transport):
        self.transport = transport

    def datagram_received(self, data, addr):
        loop = asyncio.get_running_loop()
        if addr not in self.legs:
            self.legs[addr] = loop.create_task(loop.create_datagram_endpoint(
                lambda: Leg(self, addr, self.delay), remote_addr=self.target))
        loop.create_task(self._forward(addr, data))

    async def _forward(self, addr, data):
        leg, _ = await self.legs[addr]
        asyncio.get_running_loop().call_later(self.delay, leg.sendto, data)


async def main(listen, target, delay_ms):
    loop = asyncio.get_running_loop()
    await loop.create_datagram_endpoint(lambda: Front(("127.0.0.1", target), delay_ms / 1000.0),
                                        local_addr=("127.0.0.1", listen))
    await asyncio.Event().wait()


def alive(pid):
    """True while pid is a running process (a zombie counts as gone)."""
    try:
        with open("/proc/%d/stat" % pid) as f:
            return f.read().rsplit(")", 1)[1].split()[0] != "Z"
    except (OSError, IndexError):
        return False


async def watch(parent, max_life):
    """Return when the parent is gone or the cap is hit. Without --parent-pid: when we are re-parented."""
    ppid = os.getppid()
    waited = 0.0
    while waited < max_life and (alive(parent) if parent else os.getppid() == ppid):
        await asyncio.sleep(0.5)
        waited += 0.5
    os.kill(os.getpid(), signal.SIGTERM)


async def run(a):
    signal.signal(signal.SIGTERM, lambda *_: os._exit(0))
    asyncio.get_running_loop().create_task(watch(a.parent_pid, a.max_life))
    await main(a.listen, a.target, a.delay_ms)


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("listen", type=int)
    ap.add_argument("target", type=int)
    ap.add_argument("delay_ms", type=float)
    ap.add_argument("--parent-pid", type=int, default=0)
    ap.add_argument("--max-life", type=float, default=1500.0)
    asyncio.run(run(ap.parse_args()))
